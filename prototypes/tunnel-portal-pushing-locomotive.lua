local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local Utils = require("utility/utils")

--[[
    An invisible locomotive that can connect to regular wagons with a position 4 tiles from the regular wagon.
    It won't connect to the blocking locomotive or the dummy locomotive.
]]
local refLoco = data.raw["locomotive"]["locomotive"]

data:extend(
    {
        {
            type = "locomotive",
            name = "railway_tunnel-tunnel_portal_pushing_locomotive",
            collision_box = {{-0.3, -0.7}, {0.3, 0.7}},
            collision_mask = CollisionMaskUtil.get_default_mask("locomotive"),
            --selection_box = {{-1, -2}, {1, 2}}, -- For testing when we need to select them
            weight = 1,
            braking_force = 1,
            friction_force = 1,
            energy_per_hit_point = 0,
            max_speed = 99999,
            air_resistance = 0,
            joint_distance = 1,
            connection_distance = 0,
            pictures = Utils.EmptyRotatedSprite(),
            vertical_selection_shift = 0,
            max_power = refLoco.max_power,
            reversing_power_modifier = 1,
            energy_source = {
                type = "void"
            }
        }
    }
)
