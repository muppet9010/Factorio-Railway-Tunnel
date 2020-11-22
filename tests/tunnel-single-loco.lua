local Test = {}
local Interfaces = require("utility/interfaces")

local function SetRailSignalRed(signal)
    local controlBehavour = signal.get_or_create_control_behavior()
    controlBehavour.read_signal = false
    controlBehavour.close_signal = true
    controlBehavour.circuit_condition = {condition = {first_signal = {type = "virtual", name = "signal-red"}, comparator = "="}, constant = 0}
end

Test.Start = function()
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]

    local nauvisEntitiesToPlace = {}
    for x = -100, 100, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {x, 0}, direction = defines.direction.west})
    end
    for x = -18, 18, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-hidden_rail_signal", position = {x, -0.5}, direction = defines.direction.east})
        table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-hidden_rail_signal", position = {x, 2.5}, direction = defines.direction.west})
    end
    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction}
    end

    local tiles = {}
    for x = -70, -20 do
        for y = -1, 2 do
            table.insert(tiles, {name = "stone-path", position = {x, y}})
        end
    end
    for x = -20, 20 do
        for y = -1, 2 do
            table.insert(tiles, {name = "hazard-concrete-left", position = {x, y}})
        end
    end
    for x = 20, 70 do
        for y = -1, 2 do
            table.insert(tiles, {name = "stone-path", position = {x, y}})
        end
    end
    nauvisSurface.set_tiles(tiles)

    local easternEntrySignals = {
        east = nauvisSurface.create_entity {name = "rail-signal", position = {70, -0.5}, direction = defines.direction.east},
        west = nauvisSurface.create_entity {name = "rail-signal", position = {70, 2.5}, direction = defines.direction.west}
    }
    local easternEndSignals = {
        east = nauvisSurface.create_entity {name = "rail-signal", position = {20, -0.5}, direction = defines.direction.east},
        west = nauvisSurface.create_entity {name = "rail-signal", position = {20, 2.5}, direction = defines.direction.west}
    }
    easternEndSignals.east.connect_neighbour {wire = defines.wire_type.red, target_entity = easternEndSignals.west}
    SetRailSignalRed(easternEndSignals.east)
    SetRailSignalRed(easternEndSignals.west)

    local westernEndSignals = {
        east = nauvisSurface.create_entity {name = "rail-signal", position = {-20, -0.5}, direction = defines.direction.east},
        west = nauvisSurface.create_entity {name = "rail-signal", position = {-20, 2.5}, direction = defines.direction.west}
    }
    westernEndSignals.east.connect_neighbour {wire = defines.wire_type.red, target_entity = westernEndSignals.west}
    SetRailSignalRed(westernEndSignals.east)
    SetRailSignalRed(westernEndSignals.west)
    local westernEntrySignals = {
        east = nauvisSurface.create_entity {name = "rail-signal", position = {-70, -0.5}, direction = defines.direction.east},
        west = nauvisSurface.create_entity {name = "rail-signal", position = {-70, 2.5}, direction = defines.direction.west}
    }

    local tunnel = Interfaces.Call("Tunnel.RegisterTunnel", nauvisSurface, "horizontal", {eastern = easternEndSignals, western = westernEndSignals}, {eastern = easternEntrySignals, western = westernEntrySignals})

    local trainStop = nauvisSurface.create_entity {name = "train-stop", position = {-95, -1}, direction = defines.direction.west}

    local loco = nauvisSurface.create_entity {name = "locomotive", position = {95, 0}, direction = defines.direction.west}
    loco.insert("rocket-fuel")
    loco.train.schedule = {
        current = 1,
        records = {
            {
                station = trainStop.backer_name
            }
        }
    }
    loco.train.manual_mode = false

    local undergroundSurface = tunnel.undergroundSurface
    local undergroundEntitiesToPlace = {}
    for x = -100, 100, 2 do
        table.insert(undergroundEntitiesToPlace, {name = "straight-rail", position = {x, 0}, direction = defines.direction.west})
    end
    for _, details in pairs(undergroundEntitiesToPlace) do
        undergroundSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction}
    end
end

return Test
