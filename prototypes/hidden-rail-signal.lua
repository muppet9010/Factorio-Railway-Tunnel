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
            collision_mask = {"layer-14"},
            collision_box = {{-0.2, -0.2}, {0.2, 0.2}}
            --selection_box = {{-0.5, -0.5}, {0.5, 0.5}} -- For testing when we need to select them
        }
    }
)

-- Add our hidden rail signal collision mask to all other rail signals
for _, prototypeType in pairs({"rail-signal", "rail-chain-signal"}) do
    for _, prototype in pairs(data.raw[prototypeType]) do
        prototype.collision_mask = prototype.collision_mask or {"item-layer", "floor-layer"} -- Default - 1.1 needs additional rail-layer
        table.insert(prototype.collision_mask, "layer-14")
    end
end
