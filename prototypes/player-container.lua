local Utils = require("utility/utils")

data:extend(
    {
        {
            type = "car",
            name = "railway_tunnel-player_container",
            collision_mask = {},
            flags = {"not-on-map", "placeable-off-grid"},
            weight = 1,
            braking_force = 1,
            friction_force = 1,
            energy_per_hit_point = 1,
            animation = Utils.EmptyRotatedSprite(),
            effectivity = 0,
            consumption = "0W",
            rotation_speed = 0,
            energy_source = {
                type = "void"
            },
            inventory_size = 0
        }
    }
)
