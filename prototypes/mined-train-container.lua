local TableUtils = require("utility.table-utils")

local minedTunnelContainer = TableUtils.DeepCopy(data.raw["character"]["character"])
minedTunnelContainer.name = "railway_tunnel-mined_train_container"
minedTunnelContainer.subgroup = "railway_tunnel-tunnel_bits"
minedTunnelContainer.icon = "__base__/graphics/icons/locomotive.png"
minedTunnelContainer.icon_size = 64
minedTunnelContainer.icon_mipmaps = 4
minedTunnelContainer.picture = {
    filename = "__base__/graphics/icons/locomotive.png",
    size = 64
}
minedTunnelContainer.collision_box = nil
minedTunnelContainer.collision_mask = {}
minedTunnelContainer.selection_box = {{-1, -1}, {1, 1}}
minedTunnelContainer.selection_priority = 100 -- 0-255 value with 255 being on-top of everything else
minedTunnelContainer.inventory_size = 65535
minedTunnelContainer.flags = {"not-deconstructable", "not-upgradable", "not-blueprintable", "placeable-off-grid", "not-selectable-in-game"}
minedTunnelContainer.character_corpse = "railway_tunnel-mined_train_container-corpse"

data:extend(
    {
        minedTunnelContainer,
        {
            type = "character-corpse",
            name = "railway_tunnel-mined_train_container-corpse",
            subgroup = "railway_tunnel-tunnel_bits",
            icon = "__base__/graphics/icons/locomotive.png",
            icon_size = 64,
            icon_mipmaps = 4,
            picture = {
                filename = "__base__/graphics/icons/locomotive.png",
                size = 64
            },
            time_to_live = 4294967295, -- Max value.
            minable = {mining_time = 2},
            selection_box = {{-1, -1}, {1, 1}},
            selection_priority = 100, -- 0-255 value with 255 being on-top of everything else
            flags = {"not-deconstructable", "not-upgradable", "not-blueprintable", "placeable-off-grid"}
        }
    }
)
