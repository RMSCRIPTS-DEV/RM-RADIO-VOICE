-- rm-radios — ox_inventory items
--
-- Copy these three entries into your ox_inventory/data/items.lua `return {}` table.
-- Copy install/images/*.png into ox_inventory/web/images/ (filenames must match the item names below).
--
-- If you rename this resource's folder away from "at-radio", update the `export`
-- string on the radio item below to match (e.g. "rm-radios.use").

["radio"] = {
    label = "Radio",
    weight = 100,
    width = 1,
    height = 1,
    metadata = {
        rarity = "common",
    },
    stack = false,
    close = true,
    consume = 0,
    description = "Portable radio. Open storage to install a Shadow Module.",
    model = "prop_cs_hand_radio",
    client = {
        export = "at-radio.use",
    },
    buttons = {
        {
            label = "Open storage",
            action = function(slot)
                TriggerServerEvent("ox_inventory:openItemStorage", slot, "radio")
            end,
        },
    },
},

["earpiece"] = {
    label = "Earpiece",
    description = "Hands-free communication device.",
    weight = 0,
    width = 1,
    height = 1,
    stackSize = 15,
    stack = true,
},

["shadow_module"] = {
    label = "Shadow Module",
    weight = 0,
    width = 1,
    height = 1,
    stack = false,
    description = "Install in a radio's storage to stay hidden from channel member lists.",
},
