local Utils = require("utility/utils")

--TODO: replace with custom entity later
local hiddenRailSignal = Utils.DeepCopy(data.raw["rail-signal"]["rail-signal"])
hiddenRailSignal.name = "grade_separated_rail_junction-hidden_rail_signal"
--hiddenRailSignal.selection_box = nil -- TODO: Just make selectable for while testing.
hiddenRailSignal.collision_mask = {"layer-13"}
hiddenRailSignal.fast_replaceable_group = nil

data:extend({hiddenRailSignal})

-- Add our hidden rail signal collision mask to all other rail signals as required by 1.1
for _, prototypeType in pairs({data.raw["rail-signal"], data.raw["rail-chain-signal"]}) do
    for _, prototype in pairs(prototypeType) do
        prototype.collision_mask = prototype.collision_mask or {"item-layer", "floor-layer"} -- Default - 1.1 needs additional rail-layer
        table.insert(prototype.collision_mask, "layer-13")
    end
end
