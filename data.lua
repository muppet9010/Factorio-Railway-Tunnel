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

require("prototypes/internal-rails")
require("prototypes/invisible-rails")
require("prototypes/internal-signal-not-on-map")(tunnelSignalSurfaceCollisionLayer)
require("prototypes/invisible-signal-not-on-map")(tunnelSignalSurfaceCollisionLayer)

require("prototypes/tunnel-portal-surface")
require("prototypes/tunnel-portal-blocking-locomotive")
require("prototypes/tunnel-exit-dummy-locomotive")

require("prototypes/tunnel-segment-surface")
require("prototypes/tunnel-segment-surface-rail-crossing")

require("prototypes/item-groups")
require("prototypes/custom-inputs")
require("prototypes/technology")
require("prototypes/recipe")
require("prototypes/player-container")
require("prototypes/character-placement-leave-tunnel")
require("prototypes/placement-highlights")
require("prototypes/train-blocker")
require("prototypes/temporary-fuel")
