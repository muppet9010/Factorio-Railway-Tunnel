local Test = {}
local Utils = require("utility/utils")

local yRailValue = 5

Test.Start = function()
    Test.TunnelEastWest()
    Test.Loop()
end

Test.TunnelEastWest = function()
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]

    local nauvisEntitiesToPlace = {}

    -- West side
    for x = -140, -71, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {x, yRailValue}, direction = defines.direction.west})
    end
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {-45, yRailValue}, direction = defines.direction.west})

    -- Tunnel Segments
    for x = -19, 19, 2 do
        local segmentName = "railway_tunnel-tunnel_segment_surface-placement"
        if x == -11 or x == 11 then
            segmentName = "railway_tunnel-tunnel_segment_surface_rail_crossing-placement"
        end
        table.insert(nauvisEntitiesToPlace, {name = segmentName, position = {x, yRailValue}, direction = defines.direction.west})
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
    local trainStopEast = nauvisSurface.create_entity {name = "train-stop", position = {130, yRailValue + 2}, force = playerForce, direction = defines.direction.east}
    local loco1 = nauvisSurface.create_entity {name = "locomotive", position = {95, yRailValue}, force = playerForce, direction = defines.direction.west}
    loco1.insert({name = "rocket-fuel", count = 15})
    local wagon1 = nauvisSurface.create_entity {name = "cargo-wagon", position = {102, yRailValue}, force = playerForce, direction = defines.direction.west}
    local wagon1Inventory = wagon1.get_inventory(defines.inventory.cargo_wagon)
    wagon1Inventory.set_filter(2, "raw-fish")
    wagon1.insert({name = "iron-plate", count = 165})
    wagon1Inventory.set_bar(25)
    local loco2 = nauvisSurface.create_entity {name = "locomotive", position = {109, yRailValue}, force = playerForce, direction = defines.direction.east}
    loco2.insert({name = "coal", count = 100})
    -- Loco3 makes the train face backwards and so it drives backwards on its orders.
    local loco3 = nauvisSurface.create_entity {name = "locomotive", position = {116, yRailValue}, force = playerForce, direction = defines.direction.east}
    loco3.insert({name = "coal", count = 100})
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

Test.Loop = function()
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]

    local nauvisEntitiesToPlace = {}
    for y = -19, 19, 2 do
        if y < yRailValue - 2 or y > yRailValue + 2 then
            table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-11, y}, direction = defines.direction.north})
            table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {11, y}, direction = defines.direction.north})
        end
    end
    Utils.PushToList(
        nauvisEntitiesToPlace,
        {
            {name = "curved-rail", position = {-10, -24}, direction = defines.direction.northeast},
            {name = "straight-rail", position = {-7, -27}, direction = defines.direction.northwest},
            {name = "curved-rail", position = {-4, -30}, direction = defines.direction.west},
            {name = "curved-rail", position = {4, -30}, direction = defines.direction.southeast},
            {name = "straight-rail", position = {7, -27}, direction = defines.direction.northeast},
            {name = "curved-rail", position = {10, -24}, direction = defines.direction.north},
            {name = "curved-rail", position = {10, 24}, direction = defines.direction.southwest},
            {name = "straight-rail", position = {7, 27}, direction = defines.direction.southeast},
            {name = "curved-rail", position = {4, 30}, direction = defines.direction.east},
            {name = "curved-rail", position = {-4, 30}, direction = defines.direction.northwest},
            {name = "straight-rail", position = {-7, 27}, direction = defines.direction.southwest},
            {name = "curved-rail", position = {-10, 24}, direction = defines.direction.south},
            {name = "rail-signal", position = {-0.5, -29.5}, direction = defines.direction.west},
            {name = "rail-signal", position = {0.5, 29.5}, direction = defines.direction.east}
        }
    )
    for y = -15.5, 15.5, 10 do
        if y < yRailValue - 2 or y > yRailValue + 2 then
            table.insert(nauvisEntitiesToPlace, {name = "rail-signal", position = {-9.5, y}, direction = defines.direction.south})
            table.insert(nauvisEntitiesToPlace, {name = "rail-signal", position = {9.5, y}, direction = defines.direction.north})
        end
    end
    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction}
    end

    local trainStop1 = nauvisSurface.create_entity {name = "train-stop", position = {-9, -19}, force = playerForce, direction = defines.direction.north}
    local trainStop2 = nauvisSurface.create_entity {name = "train-stop", position = {9, 19}, force = playerForce, direction = defines.direction.south}

    local loco = nauvisSurface.create_entity {name = "locomotive", position = {-11, -16}, force = playerForce, direction = defines.direction.north}
    loco.insert("rocket-fuel")
    loco.train.schedule = {
        current = 1,
        records = {
            {
                station = trainStop1.backer_name
            },
            {
                station = trainStop2.backer_name
            }
        }
    }
    loco.train.manual_mode = false
end

return Test
