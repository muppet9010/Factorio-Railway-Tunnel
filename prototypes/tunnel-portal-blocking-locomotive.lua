local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local Utils = require("utility/utils")

data:extend(
    {
        {
            type = "locomotive",
            name = "railway_tunnel-tunnel_portal_blocking_locomotive",
            collision_box = {{-0.3, -2}, {0.3, 2}},
            collision_mask = CollisionMaskUtil.get_default_mask("locomotive"),
            --selection_box = {{-1, -2}, {1, 2}}, -- For testing when we need to select them
            weight = 1,
            braking_force = 1,
            friction_force = 1,
            energy_per_hit_point = 0,
            max_speed = 9999,
            air_resistance = 0,
            joint_distance = 0.1,
            connection_distance = 0,
            pictures = Utils.EmptyRotatedSprite(),
            vertical_selection_shift = 0,
            max_power = "600kW",
            reversing_power_modifier = 1,
            energy_source = {
                type = "burner",
                render_no_power_icon = false,
                render_no_network_icon = false,
                fuel_inventory_size = 0
            }
        }
    }
)
