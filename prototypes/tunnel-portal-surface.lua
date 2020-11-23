local Utils = require("utility/utils")

local giantTrainStop = Utils.DeepCopy(data.raw["train-stop"]["train-stop"])
giantTrainStop.name = "railway_tunnel-tunnel_portal_surface"
giantTrainStop.collision_box = {{-4, 0}, {0, 50}}
giantTrainStop.collision_mask = {"player-layer", "layer-15"}
data:extend({giantTrainStop})

-- Add our tunnel portal collision mask to all other things we should conflict with
for _, prototypeType in pairs({"rail-signal", "rail-chain-signal"}) do
    for _, prototype in pairs(data.raw[prototypeType]) do
        prototype.collision_mask = prototype.collision_mask or {"item-layer", "floor-layer"} -- Default - 1.1 needs additional rail-layer
        table.insert(prototype.collision_mask, "layer-15")
    end
end
for _, prototypeType in pairs({"splitter", "underground-belt", "loader-1x1", "loader"}) do
    for _, prototype in pairs(data.raw[prototypeType]) do
        prototype.collision_mask = prototype.collision_mask or {"object-layer", "item-layer", "water-tile"}
        table.insert(prototype.collision_mask, "layer-15")
    end
end
for _, prototypeType in pairs({"transport-belt", "heat-pipe"}) do
    for _, prototype in pairs(data.raw[prototypeType]) do
        prototype.collision_mask = prototype.collision_mask or {"object-layer", "floor-layer", "water-tile"}
        table.insert(prototype.collision_mask, "layer-15")
    end
end
for _, prototypeType in pairs({"land-mine"}) do
    for _, prototype in pairs(data.raw[prototypeType]) do
        prototype.collision_mask = prototype.collision_mask or {"object-layer", "water-tile"}
        table.insert(prototype.collision_mask, "layer-15")
    end
end
