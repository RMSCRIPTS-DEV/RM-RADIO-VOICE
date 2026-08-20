return {
    -- Makes radio private: no speaker leak to nearby players
    earpieceItem = 'earpiece',

    -- Hides you from the channel member list
    shadowItem = 'shadow_module',

    -- Opened from the inventory "Open storage" button
    radioStash = {
        slots = 5,
        weight = 1000,
    },

    -- Radio-invisible without needing shadow_module. Set to false to require the item for everyone.
    shadowAutoJobs = {
        police = true,
        ambulance = true,
    },

    -- false = restrictedChannels blocks all decimals of a channel; true = only the exact subchannels listed (e.g. 100.01, 100.02)
    whitelistSubChannels = false,

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
