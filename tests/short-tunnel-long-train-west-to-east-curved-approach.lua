local Test = {}

Test.Start = function()
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]

    local yRailValue = -149
    local xRailValue = 8
    local startRunUp = 100
    local nauvisEntitiesToPlace = {}

    -- NorthWest side
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-71 + xRailValue, yRailValue}, direction = defines.direction.west})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-76 + xRailValue, yRailValue - 1}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-79 + xRailValue, yRailValue - 4}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-82 + xRailValue, yRailValue - 7}, direction = defines.direction.south})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-82 + xRailValue, yRailValue - 15}, direction = defines.direction.northeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-79 + xRailValue, yRailValue - 18}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-76 + xRailValue, yRailValue - 21}, direction = defines.direction.west})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-68 + xRailValue, yRailValue - 21}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-65 + xRailValue, yRailValue - 18}, direction = defines.direction.northeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-63 + xRailValue, yRailValue - 18}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-63 + xRailValue, yRailValue - 16}, direction = defines.direction.northeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-61 + xRailValue, yRailValue - 16}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-61 + xRailValue, yRailValue - 14}, direction = defines.direction.northeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-59 + xRailValue, yRailValue - 14}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-59 + xRailValue, yRailValue - 12}, direction = defines.direction.northeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-57 + xRailValue, yRailValue - 12}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-54 + xRailValue, yRailValue - 9}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-46 + xRailValue, yRailValue - 9}, direction = defines.direction.east})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-43 + xRailValue, yRailValue - 12}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-40 + xRailValue, yRailValue - 15}, direction = defines.direction.southwest})
    for y = (-188 - startRunUp), -20, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-39 + xRailValue, yRailValue + y}, direction = defines.direction.north})
    end
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {-45 + xRailValue, yRailValue}, direction = defines.direction.west})

    -- Tunnel Segments
    for x = -19, 19, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_segment_surface-placement", position = {x + xRailValue, yRailValue}, direction = defines.direction.west})
    end

    -- SouthEast Side
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {71 + xRailValue, yRailValue}, direction = defines.direction.west})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {76 + xRailValue, yRailValue - 1}, direction = defines.direction.east})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {79 + xRailValue, yRailValue - 4}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {82 + xRailValue, yRailValue - 7}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {82 + xRailValue, yRailValue - 15}, direction = defines.direction.north})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {79 + xRailValue, yRailValue - 18}, direction = defines.direction.northeast})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {76 + xRailValue, yRailValue - 21}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {68 + xRailValue, yRailValue - 21}, direction = defines.direction.west})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {65 + xRailValue, yRailValue - 18}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {63 + xRailValue, yRailValue - 18}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {63 + xRailValue, yRailValue - 16}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {61 + xRailValue, yRailValue - 16}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {61 + xRailValue, yRailValue - 14}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {59 + xRailValue, yRailValue - 14}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {59 + xRailValue, yRailValue - 12}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {57 + xRailValue, yRailValue - 12}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {54 + xRailValue, yRailValue - 9}, direction = defines.direction.east})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {46 + xRailValue, yRailValue - 9}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {43 + xRailValue, yRailValue - 12}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {40 + xRailValue, yRailValue - 15}, direction = defines.direction.south})
    for y = (-188 - startRunUp), -20, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {39 + xRailValue, yRailValue + y}, direction = defines.direction.north})
    end
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {45 + xRailValue, yRailValue}, direction = defines.direction.east})

    -- Place All track bis
    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction, raise_built = true}
    end

    -- Place Train and setup
    local trainStopNorthWest = nauvisSurface.create_entity {name = "train-stop", position = {-37 + xRailValue, yRailValue - 188}, force = playerForce, direction = defines.direction.north}
    local trainStopSouthEast = nauvisSurface.create_entity {name = "train-stop", position = {41 + xRailValue, yRailValue - 188}, force = playerForce, direction = defines.direction.north}
    local yPos, train = yRailValue - (185 + startRunUp)
    for i = 1, 4 do
        local loco = nauvisSurface.create_entity {name = "locomotive", position = {-39 + xRailValue, yPos}, force = playerForce, direction = defines.direction.north}
        loco.insert("rocket-fuel")
        yPos = yPos + 7
    end
    for i = 1, 16 do
        local wagon = nauvisSurface.create_entity {name = "cargo-wagon", position = {-39 + xRailValue, yPos}, force = playerForce, direction = defines.direction.north}
        wagon.insert("iron-plate")
        yPos = yPos + 7
    end
    for i = 1, 4 do
        local loco = nauvisSurface.create_entity {name = "locomotive", position = {-39 + xRailValue, yPos}, force = playerForce, direction = defines.direction.south}
        loco.insert("coal")
        yPos = yPos + 7
        train = loco.train
    end
    train.schedule = {
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
    train.manual_mode = false
end

return Test
