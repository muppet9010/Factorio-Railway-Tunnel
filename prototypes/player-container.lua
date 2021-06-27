local Utils = require("utility/utils")

--[[
    Use a spidertron as it can only have 1 player in it. So no worry about another player trying to get in accidently.
    We teleport the vehicle and so it has 0 speed itself so the player can't have any movement control.
]]
data:extend(
    {
        {
            type = "spider-vehicle",
            name = "railway_tunnel-player_container",
            icon = "__railway_tunnel__/graphics/icon/tunnel_portal_surface/railway_tunnel-tunnel_portal_surface-placement.png",
            icon_size = 32,
            icon_mipmaps = 4,
            subgroup = "railway_tunnel-hidden_cars",
            collision_mask = {},
            flags = {"not-on-map", "placeable-off-grid", "not-selectable-in-game"},
            weight = 1,
            braking_force = 1,
            friction_force = 1,
            energy_per_hit_point = 1,
            animation = Utils.EmptyRotatedSprite(),
            automatic_weapon_cycling = false,
            chain_shooting_cooldown_modifier = 0,
            chunk_exploration_radius = 0,
            graphics_set = {},
            spider_engine = {
                legs = {
                    leg = "railway_tunnel-player_container-leg",
                    mount_position = {0, 0},
                    ground_position = {0, 0},
                    blocking_legs = {}
                },
                military_target = "railway_tunnel-player_container-military_target"
            },
            height = 0,
            movement_energy_consumption = "1W",
            energy_source = {
                type = "void"
            },
            inventory_size = 0
        },
        {
            type = "spider-leg",
            name = "railway_tunnel-player_container-leg",
            flags = {"not-on-map", "placeable-off-grid", "not-selectable-in-game"},
            graphics_set = {},
            initial_movement_speed = 0,
            minimal_step_size = 0,
            movement_acceleration = 0,
            movement_based_position_selection_distance = 0,
            part_length = 1,
            target_position_randomisation_distance = 0
        },
        {
            type = "simple-entity-with-force",
            name = "railway_tunnel-player_container-military_target",
            subgroup = "railway_tunnel-hidden_cars",
            picture = Utils.EmptyRotatedSprite()
        }
    }
)
