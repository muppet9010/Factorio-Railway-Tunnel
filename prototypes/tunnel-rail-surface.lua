local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local tunnelRailSurfaceCollisionLayer = CollisionMaskUtil.get_first_unused_layer()

-- This needs a placment entity with 2 or 4 orientations.
-- Once placed it can be have a tunnel rail surface and have the hidden signals added.
-- The placement entity should collide with curved rail so you can't join regular track on to it easily. Maybe should collide with straight rail and have a tunnel crossing entity that is fast replaceable with the tunnel track. Would need to be same size as the tunnel track placement entity.

--[[
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
            collision_mask = {tunnelRailSurfaceCollisionLayer},
            collision_box = {{-0.2, -0.2}, {0.2, 0.2}}
            --selection_box = {{-0.5, -0.5}, {0.5, 0.5}} -- For testing when we need to select them
        }
    }
)

-- Add our hidden rail signal collision mask to all other rail signals
for _, prototypeTypeName in pairs({"rail-signal", "rail-chain-signal"}) do
    for _, prototype in pairs(data.raw[prototypeTypeName]) do
        local newMask = CollisionMaskUtil.get_mask(prototype)
        CollisionMaskUtil.add_layer(newMask, tunnelRailSurfaceCollisionLayer)
        prototype.collision_mask = newMask
    end
end
]]
