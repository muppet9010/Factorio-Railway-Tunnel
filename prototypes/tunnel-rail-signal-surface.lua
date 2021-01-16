local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")

return function(tunnelSignalSurfaceCollisionLayer)
    data:extend(
        {
            {
                type = "rail-signal",
                name = "railway_tunnel-tunnel_rail_signal_surface",
                animation = {
                    direction_count = 1,
                    filename = "__core__/graphics/empty.png",
                    size = 1
                },
                collision_mask = {tunnelSignalSurfaceCollisionLayer},
                collision_box = {{-0.2, -0.2}, {0.2, 0.2}}
                --selection_box = {{-0.5, -0.5}, {0.5, 0.5}}, -- For testing when we need to select them
            }
        }
    )
end
