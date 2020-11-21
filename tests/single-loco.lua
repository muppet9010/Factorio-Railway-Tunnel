local Test = {}
local Utils = require("utility/utils")

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
    --[[Utils.PushToList(
        nauvisEntitiesToPlace,
        {

        }
    )]]
    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction}
    end

    -- This should be part of placing a tunnel.
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

    -- This should be part of placing a tunnel.
    local easternEntrySignals = {
        east = nauvisSurface.create_entity {name = "rail-signal", position = {50, -0.5}, direction = defines.direction.east},
        west = nauvisSurface.create_entity {name = "rail-signal", position = {50, 2.5}, direction = defines.direction.west}
    }
    local easternEndSignals = {
        east = nauvisSurface.create_entity {name = "rail-signal", position = {20, -0.5}, direction = defines.direction.east},
        west = nauvisSurface.create_entity {name = "rail-signal", position = {20, 2.5}, direction = defines.direction.west}
    }
    global.tunnel.entrySignals[easternEndSignals.east.unit_number] = easternEndSignals.east
    easternEndSignals.east.connect_neighbour {wire = defines.wire_type.red, target_entity = easternEndSignals.west}
    SetRailSignalRed(easternEndSignals.east)
    SetRailSignalRed(easternEndSignals.west)

    local westernEndSignals = {
        east = nauvisSurface.create_entity {name = "rail-signal", position = {-20, -0.5}, direction = defines.direction.east},
        west = nauvisSurface.create_entity {name = "rail-signal", position = {-20, 2.5}, direction = defines.direction.west}
    }
    global.tunnel.entrySignals[westernEndSignals.west.unit_number] = westernEndSignals.west
    westernEndSignals.east.connect_neighbour {wire = defines.wire_type.red, target_entity = westernEndSignals.west}
    SetRailSignalRed(westernEndSignals.east)
    SetRailSignalRed(westernEndSignals.west)
    local westernEntrySignals = {
        east = nauvisSurface.create_entity {name = "rail-signal", position = {-50, -0.5}, direction = defines.direction.east},
        west = nauvisSurface.create_entity {name = "rail-signal", position = {-50, 2.5}, direction = defines.direction.west}
    }

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
end

return Test
