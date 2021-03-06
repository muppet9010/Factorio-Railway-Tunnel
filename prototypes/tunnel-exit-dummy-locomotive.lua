local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local Utils = require("utility/utils")

data:extend(
    {
        {
            type = "locomotive",
            name = "railway_tunnel-tunnel_exit_dummy_locomotive",
            icon = "__base__/graphics/icons/locomotive.png",
            icon_size = 64,
            icon_mipmaps = 4,
            flags = {"not-deconstructable", "not-upgradable", "not-blueprintable"},
            subgroup = "railway_tunnel-hidden_locomotives",
            collision_box = {{-0.3, -2}, {0.3, 2}},
            collision_mask = CollisionMaskUtil.get_default_mask("locomotive"),
            --selection_box = {{-1, -2}, {1, 2}}, -- For testing when we need to select them
            weight = 1,
            braking_force = 1,
            friction_force = 1,
            energy_per_hit_point = 0,
            max_speed = 0,
            air_resistance = 0,
            joint_distance = 0.1,
            connection_distance = 0,
            pictures = Utils.EmptyRotatedSprite(),
            vertical_selection_shift = 0,
            max_power = "0.0001W",
            reversing_power_modifier = 1,
            energy_source = {
                type = "burner",
                render_no_power_icon = false,
                render_no_network_icon = false,
                fuel_inventory_size = 0
            },
            allow_passengers = false
        }
    }
)
