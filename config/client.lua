return {
    maxFrequency = 500, -- Max amount of available channel frequencies to use

    -- Should the radio turn off when the player is dead (Talking is disabled anyway)
    leaveOnDeath = true,

    ---@type number
    -- How many decimal places to use for the subchannel.
    decimalPlaces = 2,

    -- Should the mic clicks be enabled by default
    defaultMicClicks = true,

    -- How close you must be to hear radio traffic leaking from someone's speaker (no earpiece)
    overhearRange = 3.0,

    -- Volume for overheard radio (0.0–1.0). Lower than normal radio so it feels like a speaker.
    overhearVolume = 0.35,
}