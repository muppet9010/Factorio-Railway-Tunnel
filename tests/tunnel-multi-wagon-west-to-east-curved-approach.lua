local Test = {}

Test.Start = function()
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]

    local yRailValue = -725
    local xRailValue = 820
    local nauvisEntitiesToPlace = {}

    -- NorthWest side
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-71 + xRailValue, yRailValue}, direction = defines.direction.west})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-76 + xRailValue, yRailValue - 1}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-79 + xRailValue, yRailValue - 4}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-82 + xRailValue, yRailValue - 7}, direction = defines.direction.south})
    for y = -80, -12, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-83 + xRailValue, yRailValue + y}, direction = defines.direction.north})
    end
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {-45 + xRailValue, yRailValue}, direction = defines.direction.west})

    -- Tunnel Segments
    for x = -19, 19, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_segment_surface-placement", position = {x + xRailValue, yRailValue}, direction = defines.direction.west})
    end

    -- SouthEast Side
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {71 + xRailValue, yRailValue}, direction = defines.direction.west})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {76 + xRailValue, yRailValue + 1}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {79 + xRailValue, yRailValue + 4}, direction = defines.direction.northeast})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {82 + xRailValue, yRailValue + 7}, direction = defines.direction.north})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {82 + xRailValue, yRailValue + 15}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {79 + xRailValue, yRailValue + 18}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {76 + xRailValue, yRailValue + 21}, direction = defines.direction.east})
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {45 + xRailValue, yRailValue}, direction = defines.direction.east})
    for x = -107, 71, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {x + xRailValue, yRailValue + 22}, direction = defines.direction.west})
    end

    -- Place All track bis
    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction, raise_built = true}
    end

    -- Place Train and setup
    local trainStopNorthWest = nauvisSurface.create_entity {name = "train-stop", position = {-81 + xRailValue, yRailValue - 78}, force = playerForce, direction = defines.direction.north}
    local trainStopSouthEast = nauvisSurface.create_entity {name = "train-stop", position = {-105 + xRailValue, yRailValue + 20}, force = playerForce, direction = defines.direction.west}
    local loco1 = nauvisSurface.create_entity {name = "locomotive", position = {-83 + xRailValue, yRailValue - 75}, force = playerForce, direction = defines.direction.north}
    loco1.insert("rocket-fuel")
    local wagon1 = nauvisSurface.create_entity {name = "cargo-wagon", position = {-83 + xRailValue, yRailValue - 68}, force = playerForce, direction = defines.direction.north}
    wagon1.insert("iron-plate")
    local loco2 = nauvisSurface.create_entity {name = "locomotive", position = {-83 + xRailValue, yRailValue - 61}, force = playerForce, direction = defines.direction.south}
    loco2.insert("coal")
    -- Loco3 makes the train face backwards and so it drives backwards on its orders.
    local loco3 = nauvisSurface.create_entity {name = "locomotive", position = {-83 + xRailValue, yRailValue - 54}, force = playerForce, direction = defines.direction.south}
    loco3.insert("coal")
    loco1.train.schedule = {
        current = 1,
        records = {
            {
                station = trainStopSouthEast.backer_name
            },
            {
                station = trainStopNorthWest.backer_name
            }
        }
    }
    loco1.train.manual_mode = false
end

return Test
