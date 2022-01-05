local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local Common = require("scripts/common")
MODDATA = MODDATA or {}
MODDATA.railway_tunnel = MODDATA.railway_tunnel or {}

-- Make a new rail signal only collision layer. As then we can place our hidden rail signals without blocking any other game entity.
local tunnelSignalSurfaceCollisionLayer = CollisionMaskUtil.get_first_unused_layer()
-- Add our hidden rail signal collision mask to all other rail signals.
for _, prototypeTypeName in pairs({"rail-signal", "rail-chain-signal"}) do
    for _, prototype in pairs(data.raw[prototypeTypeName]) do
        local newMask = CollisionMaskUtil.get_mask(prototype)
        CollisionMaskUtil.add_layer(newMask, tunnelSignalSurfaceCollisionLayer)
        prototype.collision_mask = newMask
    end
end
MODDATA.railway_tunnel.tunnelSignalSurfaceCollisionLayer = tunnelSignalSurfaceCollisionLayer

-- Make a new train only collision layer. As then we can detect/block trains without blocking any other game entity.
local tunnelTrainCollisionLayer = CollisionMaskUtil.get_first_unused_layer()
-- Add our train collision mask to all train carriage types.
for _, prototypeTypeName in pairs(Common.RollingStockTypes) do
    for _, prototype in pairs(data.raw[prototypeTypeName]) do
        local newMask = CollisionMaskUtil.get_mask(prototype)
        CollisionMaskUtil.add_layer(newMask, tunnelTrainCollisionLayer)
        prototype.collision_mask = newMask
    end
end
MODDATA.railway_tunnel.tunnelTrainCollisionLayer = tunnelTrainCollisionLayer

require("prototypes/internal-rails")
require("prototypes/invisible-rails")
require("prototypes/internal-signal-not-on-map")
require("prototypes/invisible-signal-not-on-map")

require("prototypes/portal-end")
require("prototypes/portal-segment")
require("prototypes/tunnel-portal-blocking-locomotive")
require("prototypes/tunnel-exit-dummy-locomotive")

require("prototypes/underground-segment")
require("prototypes/underground-segment-rail-crossing")

require("prototypes/item-groups")
require("prototypes/custom-inputs")
require("prototypes/technology")
require("prototypes/recipe")
require("prototypes/player-container")
require("prototypes/character-placement-leave-tunnel")
require("prototypes/placement-highlights")
require("prototypes/train-blocker")
require("prototypes/temporary-fuel")
require("prototypes/virtual-signals")
