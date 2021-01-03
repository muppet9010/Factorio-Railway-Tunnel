local Test = {}

Test.Start = function()
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]

    local xRailValue = 201

    -- north side
    local nauvisEntitiesToPlace = {}
    for y = -140, -71, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {xRailValue, y}, direction = defines.direction.north})
    end
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {xRailValue, -45}, direction = defines.direction.north})

    -- Tunnel Segments
    for y = -19, 19, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_segment_surface-placement", position = {xRailValue, y}, direction = defines.direction.north})
    end

    -- South Side
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {xRailValue, 45}, direction = defines.direction.south})
    for y = 71, 140, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {xRailValue, y}, direction = defines.direction.north})
    end

    -- Place All track bis
    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction, raise_built = true}
    end

    -- Place Train and setup
    local trainStopNorth = nauvisSurface.create_entity {name = "train-stop", position = {xRailValue + 2, -95}, force = playerForce, direction = defines.direction.north}
    local trainStopSouth = nauvisSurface.create_entity {name = "train-stop", position = {xRailValue - 2, 131}, force = playerForce, direction = defines.direction.south}
    local loco1 = nauvisSurface.create_entity {name = "locomotive", position = {xRailValue, 95}, force = playerForce, direction = defines.direction.north}
    loco1.insert("rocket-fuel")
    local wagon1 = nauvisSurface.create_entity {name = "cargo-wagon", position = {xRailValue, 102}, force = playerForce, direction = defines.direction.north}
    wagon1.insert("iron-plate")
    local loco2 = nauvisSurface.create_entity {name = "locomotive", position = {xRailValue, 109}, force = playerForce, direction = defines.direction.south}
    loco2.insert("coal")
    -- Loco3 makes the train face backwards and so it drives backwards on its orders.
    local loco3 = nauvisSurface.create_entity {name = "locomotive", position = {xRailValue, 116}, force = playerForce, direction = defines.direction.south}
    loco3.insert("coal")
    loco1.train.schedule = {
        current = 1,
        records = {
            {
                station = trainStopNorth.backer_name
            },
            {
                station = trainStopSouth.backer_name
            }
        }
    }
    loco1.train.manual_mode = false
end

return Test
