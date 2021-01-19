local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")

local tunnelSignalSurfaceCollisionLayer = CollisionMaskUtil.get_first_unused_layer()
-- Add our hidden rail signal collision mask to all other rail signals
for _, prototypeTypeName in pairs({"rail-signal", "rail-chain-signal"}) do
    for _, prototype in pairs(data.raw[prototypeTypeName]) do
        local newMask = CollisionMaskUtil.get_mask(prototype)
        CollisionMaskUtil.add_layer(newMask, tunnelSignalSurfaceCollisionLayer)
        prototype.collision_mask = newMask
    end
end

require("prototypes/internal-rail-on-map")
require("prototypes/invisible-rail")
require("prototypes/internal-signal-on-map")(tunnelSignalSurfaceCollisionLayer)

require("prototypes/tunnel-portal-surface")
require("prototypes/tunnel-portal-end-rail-signal")(tunnelSignalSurfaceCollisionLayer)
require("prototypes/tunnel-portal-red-signal-locomotive")

require("prototypes/tunnel-segment-surface")
require("prototypes/tunnel-segment-surface-rail-crossing")
require("prototypes/tunnel-rail-signal-surface")(tunnelSignalSurfaceCollisionLayer)
