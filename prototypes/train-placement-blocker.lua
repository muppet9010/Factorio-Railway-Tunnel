--[[
    Simple entity that only collides with the train layer to block trains placement and passing (if indestructible). Doesn't trigger signals.
]]
local Utils = require("utility/utils")

data:extend(
    {
        {
            type = "simple-entity",
            name = "railway_tunnel-train_placement_blocker_2x2",
            icons = {
                {
                    icon = "__base__/graphics/icons/locomotive.png",
                    icon_size = 64,
                    icon_mipmaps = 4
                },
                {
                    icon = "__core__/graphics/cancel.png",
                    icon_size = 64,
                    scale = 0.5,
                    icon_mipmaps = 0
                }
            },
            subgroup = "railway_tunnel-train_placement_blockers",
            collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
            flags = {"not-repairable", "not-blueprintable", "not-deconstructable", "no-copy-paste", "not-upgradable"},
            selectable_in_game = false,
            collision_mask = {"train-layer"}, -- Just collide with trains.
            picture = Utils.EmptyRotatedSprite()
            --selection_box = {{-0.5, -0.5}, {0.5, 0.5}} -- For testing when we need to select them
        }
    }
)
