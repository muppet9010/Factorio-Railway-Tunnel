local Test = {}

Test.Start = function()
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]

    local yRailValue = 5
    local nauvisEntitiesToPlace = {}

    -- West side
    for x = -140, -71, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {x, yRailValue}, direction = defines.direction.west})
    end
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {-45, yRailValue}, direction = defines.direction.west})

    -- Tunnel Segments
    for x = -19, 19, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_segment_surface-placement", position = {x, yRailValue}, direction = defines.direction.west})
    end

    -- East Side
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {45, yRailValue}, direction = defines.direction.east})
    for x = 71, 140, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {x, yRailValue}, direction = defines.direction.west})
    end

    -- Place All track bis
    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction, raise_built = true}
    end

    -- Place Train and setup
    local trainStopWest = nauvisSurface.create_entity {name = "train-stop", position = {-95, yRailValue - 2}, force = playerForce, direction = defines.direction.west}
    local wagon1 = nauvisSurface.create_entity {name = "cargo-wagon", position = {102, yRailValue}, force = playerForce, direction = defines.direction.west}
    wagon1.insert("iron-plate")
    local loco1 = nauvisSurface.create_entity {name = "locomotive", position = {95, yRailValue}, force = playerForce, direction = defines.direction.west}
    loco1.insert("rocket-fuel")
    loco1.train.schedule = {
        current = 1,
        records = {
            {
                station = trainStopWest.backer_name
            },
            {
                station = trainStopEast.backer_name
            }
        }
    }
    loco1.train.manual_mode = false
end

return Test
