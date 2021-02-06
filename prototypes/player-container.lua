local Utils = require("utility/utils")

data:extend(
    {
        {
            type = "car",
            name = "railway_tunnel-player_container",
            icon = "__base__/graphics/icons/car.png",
            icon_size = 64,
            icon_mipmaps = 4,
            subgroup = "railway_tunnel-hidden_cars",
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
