return {
    -- Inventory item that makes radio private (no speaker leak to nearby players)
    earpieceItem = 'earpiece',

    -- Item placed inside radio storage that hides you from channel member lists
    shadowItem = 'shadow_module',

    -- Radio storage (opened from inventory "Open storage" button, same idea as fd_laptop)
    -- 5 slots → ox_inventory grid renders as 5x1
    radioStash = {
        slots = 5,
        weight = 1000,
    },

    -- Jobs that are radio-invisible without needing shadow_module.
    -- Set to false so everyone (including these jobs) must have the item in radio storage.
    shadowAutoJobs = {
        police = true,
        ambulance = true,
    },

    -- If false restrictedChannels restricts all decimals, if true you need to manually add each subchannel (100.01, 100.02 etc)
    whitelistSubChannels = false,
    
    ---@alias channelNumber number
    ---@type table<channelNumber, {jobName: boolean, jobName2: boolean}>
    restrictedChannels = {
        [1] = {
            police = true,
            ambulance = true
        },
        [2] = {
            police = true,
            ambulance = true
        },
        [3] = {
            police = true,
            ambulance = true
        },
        [4] = {
            police = true,
            ambulance = true
        },
        [5] = {
            police = true,
            ambulance = true
        },
        [6] = {
            police = true,
            ambulance = true
        },
        [7] = {
            police = true,
            ambulance = true
        },
        [8] = {
            police = true,
            ambulance = true
        },
        [9] = {
            police = true,
            ambulance = true
        },
        [10] = {
            police = true,
            ambulance = true
        }
    }
}
