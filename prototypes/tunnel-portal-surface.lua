local Utils = require("utility/utils")
local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local tunnelPortalCollisionLayer = CollisionMaskUtil.get_first_unused_layer()

local giantTrainStop = Utils.DeepCopy(data.raw["train-stop"]["train-stop"])
giantTrainStop.name = "railway_tunnel-tunnel_portal_surface"
giantTrainStop.collision_box = {{-4, 0}, {0, 50}}
giantTrainStop.collision_mask = {"player-layer", tunnelPortalCollisionLayer}
data:extend({giantTrainStop})

-- Add our tunnel portal collision mask to all other things we should conflict with
for _, prototypeTypeName in pairs({"rail-signal", "rail-chain-signal", "loader-1x1", "loader", "splitter", "underground-belt", "transport-belt", "heat-pipe", "land-mine"}) do
    for _, prototype in pairs(data.raw[prototypeTypeName]) do
        local newMask = CollisionMaskUtil.get_mask(prototype)
        CollisionMaskUtil.add_layer(newMask, tunnelPortalCollisionLayer)
        prototype.collision_mask = newMask
    end
end
