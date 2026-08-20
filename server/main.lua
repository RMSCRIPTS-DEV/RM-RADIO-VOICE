lib.versionCheck('Qbox-project/qbx_radio')

local config = require 'config.shared'
local restrictedChannels = config.restrictedChannels
local earpieceItem = config.earpieceItem or 'earpiece'
local shadowItem = config.shadowItem or 'shadow_module'
local radioStash = config.radioStash or { slots = 5, weight = 1000 }
local ox_inventory = exports.ox_inventory

---@type table<string, true>
local registeredStashes = {}

---@type table<number, { channel: number, name: string, invisible: boolean, talking: boolean }>
local radioPlayers = {}

---Players who are eligible to be shadow-hidden (job or item) but chose to be visible anyway.
---@type table<number, true>
local shadowOptOut = {}

local function chatMsg(src, message)
    TriggerClientEvent('chat:addMessage', src, {
        color = { 90, 180, 255 },
        multiline = true,
        args = { 'Radio', message },
    })
end

local function formatFrequency(channel)
    channel = tonumber(channel) or 0
    if channel <= 0 then return 'none' end
    -- Use %d / %.2f only — ('%s.00'):format(55.0) becomes "55.0.00 MHz" in Lua.
    if channel % 1 > 0 then
        return ('%.2f MHz'):format(channel)
    end
    return ('%d.00 MHz'):format(math.floor(channel))
end

local function getTargetName(target)
    local player = exports.qbx_core:GetPlayer(target)
    if player and player.PlayerData and player.PlayerData.charinfo then
        local info = player.PlayerData.charinfo
        return ('%s %s'):format(info.firstname or 'Player', info.lastname or '')
    end
    return GetPlayerName(target) or ('ID %s'):format(target)
end

local function uuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return template:gsub('[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return ('%x'):format(v)
    end)
end

local function stashIdFor(radioId)
    return ('at_radio_%s'):format(radioId)
end

local function registerRadioStash(radioId)
    -- Always re-register so opens still work after ox_inventory restarts.
    ox_inventory:RegisterStash(
        stashIdFor(radioId),
        'Radio Storage',
        radioStash.slots or 5,
        radioStash.weight or 1000
    )
    registeredStashes[radioId] = true
end

AddEventHandler('onResourceStart', function(resource)
    if resource == 'ox_inventory' then
        table.wipe(registeredStashes)
    end
end)

local function ensureRadioId(invId, slot)
    local item = ox_inventory:GetSlot(invId, slot)
    if not item or item.name ~= 'radio' then return end

    local metadata = item.metadata or {}
    if not metadata.id then
        metadata.id = uuid()
        ox_inventory:SetMetadata(invId, slot, metadata)
        item.metadata = metadata
    end

    registerRadioStash(metadata.id)
    return item
end

local function hasShadowModuleInRadios(src)
    local slots = ox_inventory:Search(src, 'slots', 'radio')
    if type(slots) ~= 'table' then return false end

    for _, item in pairs(slots) do
        local radioId = item.metadata and item.metadata.id
        if not radioId and item.slot then
            local ensured = ensureRadioId(src, item.slot)
            radioId = ensured and ensured.metadata and ensured.metadata.id
        end

        if radioId then
            registerRadioStash(radioId)
            local count = ox_inventory:GetItemCount(stashIdFor(radioId), shadowItem) or 0
            if count > 0 then
                return true
            end
        end
    end

    return false
end

local function hasAutoJobShadow(src)
    local autoJobs = config.shadowAutoJobs
    if autoJobs == false or type(autoJobs) ~= 'table' then
        return false
    end

    local player = exports.qbx_core:GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.job then
        return false
    end

    return autoJobs[player.PlayerData.job.name] == true
end

---@param src number
---@return boolean eligible True if src qualifies for shadow mode (job or shadow_module item), regardless of opt-out.
local function isShadowEligible(src)
    return hasAutoJobShadow(src) or hasShadowModuleInRadios(src)
end

---@param src number
---@return boolean invisible True if src should actually be hidden right now.
local function isRadioInvisible(src)
    if shadowOptOut[src] then return false end
    return isShadowEligible(src)
end

---Pushes both the eligibility and active-state statebags so the NUI settings toggle can react live.
---@param src number
---@param invisible boolean
local function setShadowState(src, invisible)
    Player(src).state:set('radioShadowEligible', isShadowEligible(src), true)
    Player(src).state:set('radioShadow', invisible, true)
end

local function buildMemberList(viewerSrc, channel)
    local list = {}

    for src, data in pairs(radioPlayers) do
        if data.channel == channel then
            local isSelf = src == viewerSrc
            if isSelf or not data.invisible then
                list[#list + 1] = {
                    id = isSelf and 'self' or tostring(src),
                    name = data.name,
                    tag = 'Member',
                    self = isSelf,
                    talking = data.talking == true,
                }
            end
        end
    end

    table.sort(list, function(a, b)
        if a.self ~= b.self then
            return a.self == true
        end
        return tostring(a.name) < tostring(b.name)
    end)

    return list
end

local function broadcastChannelMembers(channel)
    if not channel or channel == 0 then return end

    for src, data in pairs(radioPlayers) do
        if data.channel == channel then
            TriggerClientEvent('at-radio:client:setMembers', src, buildMemberList(src, channel))
        end
    end
end

---Update frequency metadata on one radio only (never wipe other radios).
---@param src number
---@param channel number
---@param radioId? string
---@return string|nil appliedRadioId
local function setRadioItemFrequency(src, channel, radioId)
    local slots = ox_inventory:Search(src, 'slots', 'radio')
    if type(slots) ~= 'table' then return nil end

    channel = tonumber(channel) or 0
    local frequencyLabel = channel > 0 and formatFrequency(channel) or nil
    local frequencyValue = channel > 0 and channel or nil

    local function apply(item)
        local metadata = item.metadata or {}
        if not metadata.id then
            metadata.id = uuid()
            registerRadioStash(metadata.id)
        end

        if metadata.frequency ~= frequencyLabel or metadata.frequencyValue ~= frequencyValue then
            metadata.frequency = frequencyLabel
            metadata.frequencyValue = frequencyValue
            ox_inventory:SetMetadata(src, item.slot, metadata)
        end

        return metadata.id
    end

    if radioId then
        for _, item in pairs(slots) do
            if item.slot and item.metadata and item.metadata.id == radioId then
                return apply(item)
            end
        end
        return nil
    end

    -- Joining without a specific radio: bind the first radio only
    if channel > 0 then
        for _, item in pairs(slots) do
            if item.slot then
                return apply(item)
            end
        end
    end

    return nil
end

local function clearPlayerRadio(src, radioId, clearFrequency)
    local previous = radioPlayers[src]
    radioPlayers[src] = nil

    if clearFrequency then
        local id = radioId or (previous and previous.radioId) or nil
        if id then
            setRadioItemFrequency(src, 0, id)
        end
    end

    if previous and previous.channel and previous.channel ~= 0 then
        broadcastChannelMembers(previous.channel)
    end
end

local function setPlayerChannel(src, channel, radioId)
    channel = tonumber(channel) or 0

    local previous = radioPlayers[src]
    local previousChannel = previous and previous.channel or 0

    if channel <= 0 then
        clearPlayerRadio(src, radioId, true)
        setShadowState(src, false)
        return nil
    end

    local appliedId = setRadioItemFrequency(src, channel, radioId)
    local invisible = isRadioInvisible(src)
    radioPlayers[src] = {
        channel = channel,
        radioId = appliedId or radioId,
        name = getTargetName(src),
        invisible = invisible,
        talking = previous and previous.talking or false,
    }

    setShadowState(src, invisible)

    if previousChannel ~= 0 and previousChannel ~= channel then
        broadcastChannelMembers(previousChannel)
    end
    broadcastChannelMembers(channel)

    return radioPlayers[src].radioId
end

local function refreshPlayerShadow(src)
    local data = radioPlayers[src]
    local invisible = isRadioInvisible(src)

    if not data then
        setShadowState(src, invisible)
        return
    end

    -- Always refresh (eligibility can flip independently of invisible, e.g. an
    -- opted-out player picking up/dropping the shadow module).
    setShadowState(src, invisible)

    if data.invisible == invisible then return end

    data.invisible = invisible
    data.name = getTargetName(src)
    broadcastChannelMembers(data.channel)
end

exports.qbx_core:CreateUseableItem('radio', function(source)
    TriggerClientEvent('qbx_radio:client:use', source)
end)

if not config.whitelistSubChannels then
    for channel, v in ipairs(restrictedChannels) do
        for i = 1, 99 do
            restrictedChannels[channel + (i / 100)] = v
        end
    end
end

for channel, jobs in pairs(restrictedChannels) do
    exports['pma-voice']:addChannelCheck(channel, function(source)
        local player = exports.qbx_core:GetPlayer(source)
        return jobs[player.PlayerData.job.name] and player.PlayerData.job.onduty
    end)
end

local function syncEarpiece(src)
    local count = ox_inventory:GetItemCount(src, earpieceItem) or 0
    Player(src).state:set('hasEarpiece', count > 0, true)
end

ox_inventory:registerHook('createItem', function(payload)
    local metadata = payload.metadata or {}
    if not metadata.id then
        metadata.id = uuid()
    end
    return metadata
end, {
    itemFilter = {
        radio = true,
    }
})

ox_inventory:registerHook('swapItems', function(payload)
    local toInventory = payload.toInventory
    if type(toInventory) ~= 'string' or not toInventory:find('^at_radio_') then
        return true
    end

    local fromSlot = payload.fromSlot
    if type(fromSlot) ~= 'table' or fromSlot.name ~= shadowItem then
        return false
    end

    local count = ox_inventory:Search(toInventory, 'count', shadowItem) or 0
    if count > 0 then
        return false
    end

    return true
end, {
    inventoryFilter = {
        '^at_radio_[%w%-]+',
    }
})

ox_inventory:registerHook('swapItems', function(payload)
    local src = payload.source
    if not src then return end

    SetTimeout(0, function()
        if GetPlayerPing(src) > 0 then
            refreshPlayerShadow(src)
        end
    end)
end, {
    inventoryFilter = {
        '^at_radio_[%w%-]+',
    }
})

RegisterNetEvent('at-radio:server:openRadioStorage', function(slot)
    local src = source
    slot = tonumber(slot)
    if not slot then return end

    local item = ensureRadioId(src, slot)
    if not item or not item.metadata?.id then return end

    local stashId = stashIdFor(item.metadata.id)
    registerRadioStash(item.metadata.id)

    local opened = ox_inventory:forceOpenInventory(src, 'stash', stashId)
    if not opened then
        -- Match fd_laptop's fallback when the inventory is already focused or
        -- forceOpenInventory loses a close/open race.
        TriggerClientEvent('at-radio:client:openRadioStorage', src, stashId)
    end
end)

RegisterNetEvent('qbx_radio:server:setHoldingRadio', function(bool)
    local src = source
    if type(bool) ~= 'boolean' then return end
    Player(src).state:set('isHoldingRadio', bool, true)
end)

RegisterNetEvent('qbx_radio:server:syncEarpiece', function()
    syncEarpiece(source)
end)

RegisterNetEvent('at-radio:server:setTalking', function(talking)
    local src = source
    local data = radioPlayers[src]
    if not data then return end

    talking = talking == true
    if data.talking == talking then return end

    data.talking = talking
    if not data.invisible then
        broadcastChannelMembers(data.channel)
    else
        -- Invisible talkers still update their own UI
        TriggerClientEvent('at-radio:client:setMembers', src, buildMemberList(src, data.channel))
    end
end)

RegisterNetEvent('at-radio:server:joinedChannel', function(channel, name, radioId)
    local src = source
    channel = tonumber(channel) or 0
    if channel <= 0 then
        clearPlayerRadio(src, radioId, true)
        setShadowState(src, false)
        return
    end

    local appliedId = setPlayerChannel(src, channel, type(radioId) == 'string' and radioId or nil)
    if radioPlayers[src] and type(name) == 'string' and name ~= '' then
        radioPlayers[src].name = name
        broadcastChannelMembers(channel)
    end

    if appliedId then
        TriggerClientEvent('at-radio:client:setActiveRadio', src, appliedId)
    end
end)

RegisterNetEvent('at-radio:server:leftChannel', function(radioId, clearFrequency)
    local src = source
    clearPlayerRadio(src, type(radioId) == 'string' and radioId or nil, clearFrequency ~= false)
    setShadowState(src, false)
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    SetTimeout(1000, function()
        if GetPlayerPing(src) > 0 then
            syncEarpiece(src)
            refreshPlayerShadow(src)
        end
    end)
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(src)
    refreshPlayerShadow(src)
end)

---Lets an eligible player (job or shadow_module item) choose to be visible anyway.
RegisterNetEvent('at-radio:server:setShadowOptOut', function(optOut)
    local src = source
    shadowOptOut[src] = optOut == true or nil
    refreshPlayerShadow(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    clearPlayerRadio(src)
    Player(src).state:set('hasEarpiece', false, true)
    Player(src).state:set('isHoldingRadio', false, true)
    setShadowState(src, false)
    shadowOptOut[src] = nil
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        syncEarpiece(src)
        refreshPlayerShadow(src)
    end
end)

local function resolveTarget(source, targetId)
    targetId = tonumber(targetId)
    if not targetId or GetPlayerPing(targetId) <= 0 then
        chatMsg(source, 'Player is not online.')
        return
    end
    return targetId
end

lib.addCommand({ 'getradio', 'geradio' }, {
    help = 'Get a player\'s current radio frequency',
    params = {
        { name = 'id', type = 'playerId', help = 'Player server ID' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local target = resolveTarget(source, args.id)
    if not target then return end

    local info = lib.callback.await('at-radio:client:getCurrentChannel', target)
    local name = (info and info.name) or getTargetName(target)
    local channel = info and tonumber(info.channel) or tonumber(Player(target).state.radioChannel) or 0
    local shadowed = Player(target).state.radioShadow == true

    if channel > 0 then
        chatMsg(source, ('%s (%s) is on %s%s'):format(
            name,
            target,
            formatFrequency(channel),
            shadowed and ' [shadow]' or ''
        ))
    else
        chatMsg(source, ('%s (%s) is not on a radio channel.'):format(name, target))
    end
end)

lib.addCommand('getradioall', {
    help = 'List all saved radio frequencies for a player',
    params = {
        { name = 'id', type = 'playerId', help = 'Player server ID' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local target = resolveTarget(source, args.id)
    if not target then return end

    local favorites = lib.callback.await('at-radio:client:getFavorites', target) or {}
    local name = getTargetName(target)
    local current = lib.callback.await('at-radio:client:getCurrentChannel', target)
    local currentChannel = current and tonumber(current.channel) or 0
    local shadowed = Player(target).state.radioShadow == true

    local lines = {
        ('%s (%s) current: %s%s'):format(
            name,
            target,
            currentChannel > 0 and formatFrequency(currentChannel) or 'not on a channel',
            shadowed and ' [shadow]' or ''
        ),
    }

    if type(favorites) ~= 'table' or #favorites == 0 then
        lines[#lines + 1] = 'No saved radios.'
    else
        lines[#lines + 1] = ('Saved radios (%s):'):format(#favorites)
        for i, fav in ipairs(favorites) do
            local label = type(fav.label) == 'string' and fav.label ~= '' and fav.label or 'Unnamed'
            local category = type(fav.category) == 'string' and fav.category ~= '' and fav.category or 'Saved'
            lines[#lines + 1] = ('%s. %s - %s [%s]'):format(i, label, formatFrequency(fav.channel), category)
        end
    end

    chatMsg(source, table.concat(lines, '\n'))
end)

lib.addCommand('r', {
    help = 'Quick join a radio frequency (saves it if needed)',
    params = {
        { name = 'frequency', type = 'number', help = 'Frequency to join (e.g. 101 or 101.5)' },
    },
}, function(source, args)
    local frequency = tonumber(args.frequency)
    if not frequency then
        chatMsg(source, 'Usage: /r [frequency]')
        return
    end

    TriggerClientEvent('at-radio:client:quickJoin', source, frequency)
end)
