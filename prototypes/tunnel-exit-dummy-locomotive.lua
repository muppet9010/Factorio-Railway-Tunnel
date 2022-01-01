local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local Utils = require("utility/utils")

-- Has a collision box, joint distance and connection distance that will make connecting vanilla train carriages impossible to it.
data:extend(
    {
        {
            type = "locomotive",
            name = "railway_tunnel-tunnel_exit_dummy_locomotive",
            icon = "__base__/graphics/icons/locomotive.png",
            icon_size = 64,
            icon_mipmaps = 4,
            flags = {"not-deconstructable", "not-upgradable", "not-blueprintable", "placeable-off-grid"},
            subgroup = "railway_tunnel-hidden_locomotives",
            collision_box = {{-0.3, -1.5}, {0.3, 1.5}}, -- Minimum size that doesn't connect to vanilla railway carriages is 1.1 each side.
            collision_mask = CollisionMaskUtil.get_default_mask("locomotive"),
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
