--local Utils = require("utility/utils")

local testing_makeSelectable = true

--[[local hiddenRailSignal = Utils.DeepCopy(data.raw["rail-signal"]["rail-signal"])
hiddenRailSignal.name = "railway_tunnel-hidden_rail_signal"
--hiddenRailSignal.selection_box = nil -- TODO: Just make selectable for while testing.
hiddenRailSignal.collision_mask = {"layer-13"}
hiddenRailSignal.fast_replaceable_group = nil
data:extend({hiddenRailSignal})--]]
data:extend(
    {
        {
            type = "rail-signal",
            name = "railway_tunnel-hidden_rail_signal",
            animation = {
                direction_count = 1,
                filename = "__core__/graphics/empty.png",
                size = 1
            },
            collision_mask = {"layer-13"},
            collision_box = {{-0.2, -0.2}, {0.2, 0.2}}
        }
    }
)
if testing_makeSelectable then
    data.raw["rail-signal"]["railway_tunnel-hidden_rail_signal"].selection_box = {{-0.5, -0.5}, {0.5, 0.5}}
end

-- Add our hidden rail signal collision mask to all other rail signals as required by 1.1
for _, prototypeType in pairs({data.raw["rail-signal"], data.raw["rail-chain-signal"]}) do
    for _, prototype in pairs(prototypeType) do
        prototype.collision_mask = prototype.collision_mask or {"item-layer", "floor-layer"} -- Default - 1.1 needs additional rail-layer
        table.insert(prototype.collision_mask, "layer-13")
    end
end
