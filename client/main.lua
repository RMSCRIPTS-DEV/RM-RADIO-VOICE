local config = require 'config.client'
local sharedConfig = require 'config.shared'
local radioMenu = false
local onRadio = false
local onChannel = false
local radioChannel = 0
local radioVolume = 50
local Radios = {}
local micClicks = config.defaultMicClicks
local radioMuted = false
local radioDeafened = false
local volumeBeforeDeafen = nil
local isTalkingOnRadio = false
local membersList = {}
local activeRadioId = nil
local syncingRadioInventory = false
local radioInventoryTimer

CreateThread(function()
    pcall(function()
        exports.ox_inventory:displayMetadata({
            frequency = 'Frequency',
        })
    end)
end)

RegisterNetEvent('at-radio:client:openRadioStorage', function(stashId)
    if type(stashId) ~= 'string' or stashId == '' then return end
    exports.ox_inventory:openInventory('stash', stashId)
end)

local function getPlayerRadios()
    local slots = exports.ox_inventory:Search('slots', 'radio')
    if type(slots) ~= 'table' then return {} end

    local list = {}
    for _, item in pairs(slots) do
        if item and item.slot then
            list[#list + 1] = item
        end
    end
    return list
end

local function parseRadioFrequency(metadata)
    if type(metadata) ~= 'table' then return end

    local value = tonumber(metadata.frequencyValue)
    if value and value > 0 then
        return value
    end

    if type(metadata.frequency) == 'string' then
        value = tonumber(metadata.frequency:match('([%d%.]+)'))
        if value and value > 0 then
            return value
        end
    end
end

local function radioStillOwned(radioId)
    if not radioId then return false end
    for _, radio in ipairs(getPlayerRadios()) do
        if radio.metadata and radio.metadata.id == radioId then
            return true
        end
    end
    return false
end

local function pickActiveRadioId()
    if activeRadioId and radioStillOwned(activeRadioId) then
        return activeRadioId
    end

    local radios = getPlayerRadios()
    for i = 1, #radios do
        local id = radios[i].metadata and radios[i].metadata.id
        if id then
            activeRadioId = id
            return id
        end
    end

    activeRadioId = nil
    return nil
end

RegisterNetEvent('at-radio:client:setActiveRadio', function(radioId)
    if type(radioId) == 'string' and radioId ~= '' then
        activeRadioId = radioId
    end
end)

local RADIO_ANIM_DICT = 'random@arrests'
local RADIO_ANIM_CLIP = 'generic_radio_chatter'
local MENU_ANIM_DICT = 'random@arrests'
local MENU_ANIM_CLIP = 'generic_radio_enter'
local RADIO_BONE = 18905

local function getPlayerName()
    local playerData = QBX and QBX.PlayerData
    if playerData and playerData.charinfo then
        return ('%s %s'):format(playerData.charinfo.firstname or 'Player', playerData.charinfo.lastname or '')
    end
    return GetPlayerName(cache.playerId) or 'Player'
end

local function setHoldingRadio(state)
    TriggerServerEvent('qbx_radio:server:setHoldingRadio', state == true)
end

local function applyRadioHearing()
    if radioDeafened then
        exports['pma-voice']:setRadioVolume(0)
    else
        exports['pma-voice']:setRadioVolume(radioVolume)
    end
end

local function playMenuAnim()
    lib.requestAnimDict(MENU_ANIM_DICT)
    TaskPlayAnim(cache.ped, MENU_ANIM_DICT, MENU_ANIM_CLIP, 2.0, 2.0, -1, 51, 0.0, false, false, false)
end

local function playTalkAnim()
    lib.requestAnimDict(RADIO_ANIM_DICT)
    TaskPlayAnim(cache.ped, RADIO_ANIM_DICT, RADIO_ANIM_CLIP, 8.0, -8.0, -1, 49, 0.0, false, false, false)
end

local function stopTalkAnim()
    if IsEntityPlayingAnim(cache.ped, RADIO_ANIM_DICT, RADIO_ANIM_CLIP, 3) then
        StopAnimTask(cache.ped, RADIO_ANIM_DICT, RADIO_ANIM_CLIP, 2.0)
    end
end

local function syncRadioChannelState()
    LocalPlayer.state:set('radioChannel', radioChannel or 0, true)
end

local function getMembersForUi()
    if not onChannel then
        return {}
    end

    if #membersList > 0 then
        local list = {}
        for i = 1, #membersList do
            local member = membersList[i]
            list[i] = {
                id = member.id,
                name = member.name,
                tag = member.tag or 'Member',
                self = member.self == true,
                talking = member.self and isTalkingOnRadio or member.talking == true,
            }
        end
        return list
    end

    return {
        {
            id = 'self',
            name = getPlayerName(),
            tag = 'Member',
            self = true,
            talking = isTalkingOnRadio,
        }
    }
end

local function syncRadioState()
    syncRadioChannelState()
    SendNUIMessage({
        action = 'SET_RADIO_STATE',
        data = {
            onRadio = onRadio,
            channel = radioChannel,
            volume = radioVolume,
            micClicks = micClicks,
            muted = radioMuted,
            deafened = radioDeafened,
            profile = {
                name = getPlayerName(),
                tag = 'Member',
            },
            members = getMembersForUi(),
            shadowEligible = LocalPlayer.state.radioShadowEligible == true,
            shadowEnabled = LocalPlayer.state.radioShadow == true,
        }
    })
end

RegisterNetEvent('at-radio:client:setMembers', function(members)
    membersList = type(members) == 'table' and members or {}
    syncRadioState()
end)

local function hasRadioItem()
    local count = exports.ox_inventory:GetItemCount('radio')
    return (count or 0) > 0
end

local favoritesPromise

RegisterNUICallback('returnFavorites', function(data, cb)
    if favoritesPromise then
        favoritesPromise:resolve(type(data) == 'table' and data or {})
        favoritesPromise = nil
    end
    cb({ ok = true })
end)

local function requestFavoritesFromNui()
    if favoritesPromise then
        favoritesPromise:resolve({})
        favoritesPromise = nil
    end

    favoritesPromise = promise.new()
    SendNUIMessage({ action = 'GET_FAVORITES' })

    SetTimeout(2500, function()
        if favoritesPromise then
            favoritesPromise:resolve({})
            favoritesPromise = nil
        end
    end)

    return Citizen.Await(favoritesPromise)
end

lib.callback.register('at-radio:client:getFavorites', function()
    return requestFavoritesFromNui()
end)

lib.callback.register('at-radio:client:getCurrentChannel', function()
    return {
        channel = radioChannel or 0,
        onChannel = onChannel == true,
        name = getPlayerName(),
    }
end)

CreateThread(function()
    pcall(function()
        exports['pma-voice']:setRadioTalkAnim(RADIO_ANIM_DICT, RADIO_ANIM_CLIP)
        exports['pma-voice']:setDisableRadioAnim(true)
    end)
end)

AddEventHandler('pma-voice:radioActive', function(active)
    if active then
        if radioMuted or not onChannel or radioChannel == 0 then
            ExecuteCommand('-radiotalk')
            return
        end

        isTalkingOnRadio = true
        TriggerServerEvent('at-radio:server:setTalking', true)
        setHoldingRadio(true)
        playTalkAnim()
        syncRadioState()

        CreateThread(function()
            while isTalkingOnRadio do
                if not IsEntityPlayingAnim(cache.ped, RADIO_ANIM_DICT, RADIO_ANIM_CLIP, 3) then
                    playTalkAnim()
                end
                Wait(400)
            end
        end)
        return
    end

    isTalkingOnRadio = false
    TriggerServerEvent('at-radio:server:setTalking', false)
    stopTalkAnim()

    if radioMenu then
        setHoldingRadio(true)
        playMenuAnim()
    else
        setHoldingRadio(false)
        ClearPedSecondaryTask(cache.ped)
    end

    syncRadioState()
end)

local function connectToRadio(channel)
    radioChannel = channel
    onChannel = true
    onRadio = true

    qbx.playAudio({
        audioName = 'Start_Squelch',
        audioRef = 'CB_RADIO_SFX',
        source = cache.ped
    })
    exports['pma-voice']:setRadioChannel(channel)
    exports['pma-voice']:setVoiceProperty('radioEnabled', true)
    pcall(function()
        exports['pma-voice']:removeRadioDisableBit(1)
    end)
    applyRadioHearing()
    if channel % 1 > 0 then
        exports.qbx_core:Notify(locale('joined_radio') .. channel .. ' MHz', 'success')
    else
        exports.qbx_core:Notify(locale('joined_radio') .. channel .. '.00 MHz', 'success')
    end
    TriggerServerEvent('at-radio:server:joinedChannel', channel, getPlayerName(), pickActiveRadioId())
    syncRadioState()
end

local function tryJoinFrequency(rchannel, saveFavorite, silent)
    if not hasRadioItem() then
        if not silent then
            exports.qbx_core:Notify(locale('no_radio'), 'error')
        end
        return false
    end

    rchannel = tonumber(rchannel)
    if not rchannel or type(rchannel) ~= 'number' or rchannel > config.maxFrequency or rchannel < 1 then
        if not silent then
            exports.qbx_core:Notify(locale('invalid_channel'), 'error')
        end
        return false
    end

    rchannel = qbx.math.round(rchannel, config.decimalPlaces)

    local frequency = not sharedConfig.whitelistSubChannels and math.floor(rchannel) or rchannel
    if sharedConfig.restrictedChannels[frequency] and (not sharedConfig.restrictedChannels[frequency][QBX.PlayerData.job.name] or not QBX.PlayerData.job.onduty) then
        if not silent then
            exports.qbx_core:Notify(locale('restricted_channel'), 'error')
        end
        return false
    end

    if not onRadio then
        onRadio = true
    end

    if rchannel ~= radioChannel then
        connectToRadio(rchannel)
    elseif not saveFavorite and not silent then
        exports.qbx_core:Notify(locale('on_channel'), 'error')
        return false
    elseif silent then
        TriggerServerEvent('at-radio:server:joinedChannel', rchannel, getPlayerName(), pickActiveRadioId())
    end

    if saveFavorite then
        SendNUIMessage({
            action = 'QUICK_SAVE_FREQUENCY',
            data = { channel = rchannel },
        })
    end

    return true
end

RegisterNetEvent('at-radio:client:quickJoin', function(frequency)
    tryJoinFrequency(frequency, true)
end)

local function leaveChannel(opts)
    opts = opts or {}
    local clearFrequency = opts.clearFrequency ~= false
    local notify = opts.notify ~= false
    local radioId = activeRadioId

    if isTalkingOnRadio then
        ExecuteCommand('-radiotalk')
        isTalkingOnRadio = false
        stopTalkAnim()
    end

    if onChannel then
        qbx.playAudio({
            audioName = 'End_Squelch',
            audioRef = 'CB_RADIO_SFX',
            source = cache.ped
        })
        if notify then
            exports.qbx_core:Notify(locale('left_channel'), 'error')
        end
    end
    radioChannel = 0
    onChannel = false
    membersList = {}
    exports['pma-voice']:setRadioChannel(0)
    exports['pma-voice']:setVoiceProperty('radioEnabled', false)
    TriggerServerEvent('at-radio:server:leftChannel', radioId, clearFrequency)

    if clearFrequency then
        activeRadioId = nil
    end

    if not radioMenu then
        setHoldingRadio(false)
    end

    syncRadioState()
end

local function handleRadioInventoryChange()
    if syncingRadioInventory then return end
    syncingRadioInventory = true

    local radios = getPlayerRadios()

    if #radios == 0 then
        if onChannel or radioChannel ~= 0 then
            activeRadioId = nil
            leaveChannel({ clearFrequency = false, notify = true })
        else
            activeRadioId = nil
        end
        syncingRadioInventory = false
        return
    end

    local activeExists = radioStillOwned(activeRadioId)

    if (onChannel or radioChannel ~= 0) and activeRadioId and not activeExists then
        local fallback, fallbackFreq
        for i = 1, #radios do
            local freq = parseRadioFrequency(radios[i].metadata)
            if freq then
                fallback = radios[i]
                fallbackFreq = freq
                break
            end
        end

        if fallback and fallbackFreq then
            activeRadioId = fallback.metadata and fallback.metadata.id or nil
            tryJoinFrequency(fallbackFreq, false, true)
        else
            activeRadioId = nil
            leaveChannel({ clearFrequency = false, notify = true })
        end

        syncingRadioInventory = false
        return
    end

    if not onChannel or radioChannel == 0 then
        for i = 1, #radios do
            local freq = parseRadioFrequency(radios[i].metadata)
            if freq then
                activeRadioId = radios[i].metadata and radios[i].metadata.id or nil
                tryJoinFrequency(freq, false, true)
                break
            end
        end
    end

    syncingRadioInventory = false
end

local function queueRadioInventorySync()
    if radioInventoryTimer then return end
    radioInventoryTimer = SetTimeout(150, function()
        radioInventoryTimer = nil
        handleRadioInventoryChange()
    end)
end

local function adjustRadioChannel(increment)
    if not onRadio then
        return false
    end

    local rchannel = radioChannel + increment

    while sharedConfig.restrictedChannels[rchannel] do
        rchannel += increment
    end
    rchannel = math.min(math.max(rchannel, 1), config.maxFrequency)
    if not rchannel or type(rchannel) ~= "number" or rchannel > config.maxFrequency or rchannel < 1 then
        exports.qbx_core:Notify(locale('invalid_channel'), 'error')
        return false
    end

    rchannel = qbx.math.round(rchannel, config.decimalPlaces)

    if rchannel == radioChannel then
        exports.qbx_core:Notify(locale('on_channel'), 'error')
        return false
    end

    local frequency = sharedConfig.whitelistSubChannels and rchannel or math.floor(rchannel)
    if sharedConfig.restrictedChannels[frequency] then
        local isJobAllowed = sharedConfig.restrictedChannels[frequency][QBX.PlayerData.job.name]
        if not (isJobAllowed and QBX.PlayerData.job.onduty) then
            exports.qbx_core:Notify(locale('restricted_channel'), 'error')
            return false
        end
    end

    radioChannel = rchannel
    return true
end

local function toggleRadio(toggle)
    radioMenu = toggle
    SetNuiFocus(radioMenu, radioMenu)
    SetNuiFocusKeepInput(false)

    if radioMenu then
        onRadio = true
        if isTalkingOnRadio then
            ExecuteCommand('-radiotalk')
            isTalkingOnRadio = false
            stopTalkAnim()
        end
        setHoldingRadio(true)
        playMenuAnim()
        SendNUIMessage({
            action = 'UPDATE_VISIBILITY',
            data = true
        })
        syncRadioState()
    else
        if not isTalkingOnRadio then
            ClearPedTasks(cache.ped)
            setHoldingRadio(false)
        end
        SendNUIMessage({
            action = 'UPDATE_VISIBILITY',
            data = false
        })
    end
end

local function cleanupRadioProp(serverId)
    if not Radios[serverId] then return end
    SetEntityAsMissionEntity(Radios[serverId], true, true)
    DeleteEntity(Radios[serverId])
    Radios[serverId] = nil
end

AddStateBagChangeHandler('isHoldingRadio', '', function(bagName, _, value)
    local player = GetPlayerFromStateBagName(bagName)
    if not player or player == 0 then return end

    local serverId = GetPlayerServerId(player)

    if value then
        if Radios[serverId] and DoesEntityExist(Radios[serverId]) then return end

        local model = lib.requestModel(`prop_cs_hand_radio`)
        if not model then return end

        local ped = lib.waitFor(function()
            local playerPed = GetPlayerPed(player)
            if playerPed > 0 then return playerPed end
        end, locale('failed_spawn'), 3000)

        if not ped then
            SetModelAsNoLongerNeeded(model)
            return
        end

        cleanupRadioProp(serverId)

        local coords = GetEntityCoords(ped)
        Radios[serverId] = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
        AttachEntityToEntity(
            Radios[serverId],
            ped,
            GetPedBoneIndex(ped, RADIO_BONE),
            0.14, 0.03, 0.03,
            -105.877, -10.943, -33.721,
            true, true, false, true, 1, true
        )
        SetModelAsNoLongerNeeded(model)
    else
        cleanupRadioProp(serverId)
    end
end)

RegisterNetEvent('onPlayerDropped', function(serverId)
    cleanupRadioProp(serverId)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for serverId in pairs(Radios) do
        cleanupRadioProp(serverId)
    end
end)

local function powerButton()
    onRadio = not onRadio

    if not onRadio then
        leaveChannel()
        toggleRadio(false)
    else
        syncRadioState()
    end
end

local function isRadioOn()
    return onRadio
end

exports('IsRadioOn', isRadioOn)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    exports['pma-voice']:setVoiceProperty("micClicks", config.defaultMicClicks)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if onRadio or onChannel or radioMenu then
        onRadio = false
        if isTalkingOnRadio then
            ExecuteCommand('-radiotalk')
            isTalkingOnRadio = false
        end
        leaveChannel()
        if radioMenu then
            toggleRadio(false)
        end
    end
    syncRadioChannelState()
end)

CreateThread(function()
    syncRadioChannelState()
end)

AddEventHandler('ox_inventory:itemCount', function(itemName)
    if itemName ~= 'radio' then return end
    queueRadioInventorySync()
end)

AddEventHandler('ox_inventory:updateInventory', function(changes)
    if type(changes) ~= 'table' then return end
    for _, change in pairs(changes) do
        if change == false or (type(change) == 'table' and change.name == 'radio') then
            queueRadioInventorySync()
            return
        end
    end
end)

RegisterNetEvent('qbx_radio:client:use', function()
    toggleRadio(not radioMenu)
end)

exports('use', function()
    toggleRadio(not radioMenu)
end)

RegisterNetEvent('qbx_radio:client:onRadioDrop', function()
    queueRadioInventorySync()
end)

RegisterNUICallback('joinRadio', function(data, cb)
    if not onRadio then
        onRadio = true
    end
    local rchannel = tonumber(data.channel)
    if not rchannel or type(rchannel) ~= "number" or rchannel > config.maxFrequency or rchannel < 1 then
        exports.qbx_core:Notify(locale('invalid_channel'), 'error')
        cb({ ok = false })
        return
    end
    rchannel = qbx.math.round(rchannel, config.decimalPlaces)

    if rchannel == radioChannel then
        exports.qbx_core:Notify(locale('on_channel'), 'error')
        cb({ ok = false })
        return
    end

    local frequency = not sharedConfig.whitelistSubChannels and math.floor(rchannel) or rchannel
    if sharedConfig.restrictedChannels[frequency] and (not sharedConfig.restrictedChannels[frequency][QBX.PlayerData.job.name] or not QBX.PlayerData.job.onduty) then
        exports.qbx_core:Notify(locale('restricted_channel'), 'error')
        cb({ ok = false })
        return
    end

    connectToRadio(rchannel)
    cb({ ok = true, channel = radioChannel })
end)

RegisterNUICallback('leaveChannel', function(_, cb)
    if not onRadio then
        cb({ ok = false })
        return
    end
    if radioChannel == 0 then
        exports.qbx_core:Notify(locale('not_on_channel'), 'error')
    else
        leaveChannel()
    end
    cb({ ok = true })
end)

RegisterNUICallback('volumeUp', function(_, cb)
    if not onRadio then
        cb({ ok = false, volume = radioVolume })
        return
    end
    if radioVolume > 95 then
        exports.qbx_core:Notify(locale('max_volume'), 'error')
        cb({ ok = false, volume = radioVolume })
        return
    end

    radioVolume += 5
    if radioDeafened then
        volumeBeforeDeafen = radioVolume
    else
        exports['pma-voice']:setRadioVolume(radioVolume)
    end
    exports.qbx_core:Notify(locale('new_volume') .. radioVolume, 'success')
    syncRadioState()
    cb({ ok = true, volume = radioVolume })
end)

RegisterNUICallback('volumeDown', function(_, cb)
    if not onRadio then
        cb({ ok = false, volume = radioVolume })
        return
    end
    if radioVolume < 10 then
        exports.qbx_core:Notify(locale('min_volume'), 'error')
        cb({ ok = false, volume = radioVolume })
        return
    end

    radioVolume -= 5
    if radioDeafened then
        volumeBeforeDeafen = radioVolume
    else
        exports['pma-voice']:setRadioVolume(radioVolume)
    end
    exports.qbx_core:Notify(locale('new_volume') .. radioVolume, 'success')
    syncRadioState()
    cb({ ok = true, volume = radioVolume })
end)

RegisterNUICallback('increaseradiochannel', function(_, cb)
    if not onRadio then
        cb(radioChannel)
        return
    end

    if adjustRadioChannel(1) then
        connectToRadio(radioChannel)
        cb(radioChannel)
        return
    end
    cb(radioChannel)
end)

RegisterNUICallback('decreaseradiochannel', function(_, cb)
    if not onRadio then
        cb(radioChannel)
        return
    end

    if adjustRadioChannel(-1) then
        connectToRadio(radioChannel)
        cb(radioChannel)
        return
    end
    cb(radioChannel)
end)

RegisterNUICallback('toggleClicks', function(_, cb)
    if not onRadio then
        cb({ ok = false, micClicks = micClicks })
        return
    end
    micClicks = not micClicks
    exports['pma-voice']:setVoiceProperty("micClicks", micClicks)
    qbx.playAudio({
        audioName = "Off_High",
        audioRef = 'MP_RADIO_SFX',
        source = cache.ped
    })
    exports.qbx_core:Notify(locale('clicks' .. (micClicks and 'On' or 'Off')), micClicks and 'success' or 'error')
    syncRadioState()
    cb({ ok = true, micClicks = micClicks })
end)

RegisterNUICallback('powerButton', function(_, cb)
    qbx.playAudio({
        audioName = "On_High",
        audioRef = 'MP_RADIO_SFX',
        source = cache.ped
    })
    powerButton()
    cb(onRadio and 'on' or 'off')
end)

RegisterNUICallback('escape', function(_, cb)
    toggleRadio(false)
    cb('ok')
end)

-- Opens the active radio's storage (5-slot stash - shadow_module goes here to hide from the
-- channel member list) straight from the radio app itself, instead of making the player back
-- out to their inventory and use the item's own "Open storage" context button. Reuses the exact
-- same server-side flow as that button (at-radio:server:openRadioStorage) - the only new part
-- is looking up which inventory slot the active radio is currently in, client-side, the same
-- way pickActiveRadioId's ownership check already does.
RegisterNUICallback('openStorage', function(_, cb)
    local radioId = pickActiveRadioId()
    if not radioId then cb('no_radio') return end

    local slot
    for _, radio in ipairs(getPlayerRadios()) do
        if radio.metadata and radio.metadata.id == radioId then
            slot = radio.slot
            break
        end
    end

    if not slot then cb('no_radio') return end

    TriggerServerEvent('at-radio:server:openRadioStorage', slot)
    cb('ok')
end)

RegisterNUICallback('getRadioState', function(_, cb)
    cb({
        onRadio = onRadio,
        channel = radioChannel,
        volume = radioVolume,
        micClicks = micClicks,
        profile = {
            name = getPlayerName(),
            tag = 'Member',
        },
        shadowEligible = LocalPlayer.state.radioShadowEligible == true,
        shadowEnabled = LocalPlayer.state.radioShadow == true,
    })
end)

RegisterNUICallback('setAnonymous', function(data, cb)
    local enabled = type(data) == 'table' and data.enabled == true
    TriggerServerEvent('at-radio:server:setShadowOptOut', not enabled)
    cb({ ok = true })
end)

AddStateBagChangeHandler('radioShadowEligible', ('player:%s'):format(cache.serverId), function()
    if radioMenu then syncRadioState() end
end)
AddStateBagChangeHandler('radioShadow', ('player:%s'):format(cache.serverId), function()
    if radioMenu then syncRadioState() end
end)

RegisterNUICallback('sendChatMessage', function(data, cb)
    if not onRadio or radioChannel == 0 then
        cb({ ok = false })
        return
    end

    local message = type(data) == 'table' and data.message or nil
    if type(message) ~= 'string' or message:gsub('%s+', '') == '' then
        cb({ ok = false })
        return
    end

    message = message:sub(1, 180)
    cb({ ok = true })
end)

RegisterNUICallback('toggleMute', function(data, cb)
    radioMuted = type(data) == 'table' and data.muted == true
    if radioMuted and isTalkingOnRadio then
        ExecuteCommand('-radiotalk')
        isTalkingOnRadio = false
        stopTalkAnim()
        if not radioMenu then
            setHoldingRadio(false)
        end
    end
    syncRadioState()
    cb({ ok = true, muted = radioMuted })
end)

RegisterNUICallback('toggleDeafen', function(data, cb)
    radioDeafened = type(data) == 'table' and data.deafened == true
    if radioDeafened then
        volumeBeforeDeafen = radioVolume
        exports['pma-voice']:setRadioVolume(0)
    else
        if volumeBeforeDeafen then
            radioVolume = volumeBeforeDeafen
            volumeBeforeDeafen = nil
        end
        exports['pma-voice']:setRadioVolume(radioVolume)
    end
    syncRadioState()
    cb({ ok = true, deafened = radioDeafened, volume = radioVolume })
end)

if config.leaveOnDeath then
    AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), function(_, _, value)
        if value and onRadio and radioChannel ~= 0 then
            leaveChannel()
        end
    end)
end
