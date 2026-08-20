local config = require 'config.client'
local sharedConfig = require 'config.shared'

local overhearing = {} ---@type table<number, boolean>
local activeTalkers = {} ---@type table<number, number> talkerServerId -> radioChannel
local blockedProximityForEarpiece = false

local function hasEarpiece()
    return LocalPlayer.state.hasEarpiece == true
end

local function setProximityBlocked(blocked)
    if blocked == blockedProximityForEarpiece then return end
    blockedProximityForEarpiece = blocked
    LocalPlayer.state:set('disableProximity', blocked and true or nil, true)
end

--- Earpiece: radio PTT is private (nearby players cannot hear your mic).
--- No earpiece: leave proximity alone so people next to you hear you talk into the radio.
AddEventHandler('pma-voice:radioActive', function(active)
    if active and hasEarpiece() then
        setProximityBlocked(true)
    else
        setProximityBlocked(false)
    end
end)

-- Track who is transmitting on which channel (works even if talker is far away)
AddStateBagChangeHandler('radioActive', '', function(bagName, _, value)
    local serverId = tonumber(bagName:match('player:(%d+)'))
    if not serverId or serverId == cache.serverId then return end

    if value then
        activeTalkers[serverId] = Player(serverId).state.radioChannel or 0
    else
        activeTalkers[serverId] = nil
    end
end)

AddStateBagChangeHandler('radioChannel', '', function(bagName, _, value)
    local serverId = tonumber(bagName:match('player:(%d+)'))
    if not serverId or not activeTalkers[serverId] then return end
    activeTalkers[serverId] = value or 0
end)

local function startOverhear(serverId)
    local channel = MumbleGetVoiceChannelFromServerId(serverId)
    if channel and channel ~= -1 then
        MumbleAddVoiceChannelListen(channel)
    end
    MumbleSetVolumeOverrideByServerId(serverId, config.overhearVolume or 0.35)
end

local function stopOverhear(serverId)
    local channel = MumbleGetVoiceChannelFromServerId(serverId)
    if channel and channel ~= -1 then
        MumbleRemoveVoiceChannelListen(channel)
    end
    MumbleSetVolumeOverrideByServerId(serverId, -1.0)
end

local function clearAllOverhear()
    for serverId in pairs(overhearing) do
        stopOverhear(serverId)
    end
    overhearing = {}
end

-- Stand near someone on radio without an earpiece → hear their channel through their speaker.
CreateThread(function()
    local range = config.overhearRange or 3.0

    while true do
        if not MumbleIsConnected() then
            clearAllOverhear()
            Wait(500)
        else
            local myServerId = cache.serverId
            local myCoords = GetEntityCoords(cache.ped)
            local myChannel = LocalPlayer.state.radioChannel or 0
            local openChannels = {} ---@type table<number, boolean>

            local players = GetActivePlayers()
            for i = 1, #players do
                local ply = players[i]
                local serverId = GetPlayerServerId(ply)
                if serverId ~= myServerId then
                    local ped = GetPlayerPed(ply)
                    if ped > 0 and #(myCoords - GetEntityCoords(ped)) <= range then
                        local state = Player(serverId).state
                        local theirChannel = state.radioChannel or 0
                        if theirChannel > 0 and state.hasEarpiece ~= true and myChannel ~= theirChannel then
                            openChannels[theirChannel] = true
                        end
                    end
                end
            end

            local shouldHear = {}
            for talkerId, talkerChannel in pairs(activeTalkers) do
                if talkerChannel > 0 and openChannels[talkerChannel] then
                    shouldHear[talkerId] = true
                end
            end

            for talkerId in pairs(shouldHear) do
                if not overhearing[talkerId] then
                    startOverhear(talkerId)
                    overhearing[talkerId] = true
                else
                    -- refresh volume / listen in case mumble reconnected
                    startOverhear(talkerId)
                end
            end

            for talkerId in pairs(overhearing) do
                if not shouldHear[talkerId] then
                    stopOverhear(talkerId)
                    overhearing[talkerId] = nil
                end
            end

            Wait(200)
        end
    end
end)

AddEventHandler('ox_inventory:itemCount', function(itemName, totalCount)
    if itemName ~= sharedConfig.earpieceItem then return end
    TriggerServerEvent('qbx_radio:server:syncEarpiece')

    if totalCount > 0 and LocalPlayer.state.radioActive then
        setProximityBlocked(true)
    elseif totalCount <= 0 then
        setProximityBlocked(false)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('qbx_radio:server:syncEarpiece')
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    TriggerServerEvent('qbx_radio:server:syncEarpiece')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    clearAllOverhear()
    setProximityBlocked(false)
end)
