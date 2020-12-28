local Test = {}

Test.Start = function()
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]

    local nauvisEntitiesToPlace = {}
    for x = -121, -71, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {x, 1}, direction = defines.direction.west})
    end
    nauvisSurface.create_entity {name = "railway_tunnel-tunnel_portal_surface-placement", position = {-45, 1}, force = playerForce, direction = defines.direction.west, raise_built = true}

    local tiles = {}
    for x = -20, 19 do
        for y = -1, 2 do
            table.insert(tiles, {name = "hazard-concrete-left", position = {x, y}})
        end
    end
    nauvisSurface.set_tiles(tiles)
    for x = -19, 19, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-invisible_rail", position = {x, 1}, direction = defines.direction.west})
    end
    for x = -18, 18, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_rail_signal_surface", position = {x, -0.5}, direction = defines.direction.east})
        table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_rail_signal_surface", position = {x, 2.5}, direction = defines.direction.west})
    end

    nauvisSurface.create_entity {name = "railway_tunnel-tunnel_portal_surface-placement", position = {45, 1}, force = playerForce, direction = defines.direction.east, raise_built = true}
    for x = 71, 121, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {x, 1}, direction = defines.direction.west})
    end

    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction}
    end

    return
    UP TO HERE
    --[[
    local tunnel = Interfaces.Call("Tunnel.RegisterTunnel", nauvisSurface, "horizontal", {eastern = easternEndSignals, western = westernEndSignals}, {eastern = easternEntrySignals, western = westernEntrySignals})

    local trainStop = nauvisSurface.create_entity {name = "train-stop", position = {-95, -1}, force = playerForce, direction = defines.direction.west}

    local loco1 = nauvisSurface.create_entity {name = "locomotive", position = {95, 1}, force = playerForce, direction = defines.direction.west}
    loco1.insert("rocket-fuel")
    local wagon1 = nauvisSurface.create_entity {name = "cargo-wagon", position = {102, 1}, force = playerForce, direction = defines.direction.west}
    wagon1.insert("iron-plate")
    local loco2 = nauvisSurface.create_entity {name = "locomotive", position = {109, 1}, force = playerForce, direction = defines.direction.east}
    loco2.insert("coal")
    loco1.train.schedule = {
        current = 1,
        records = {
            {
                station = trainStop.backer_name
            }
        }
    }
    loco1.train.manual_mode = false

    local undergroundSurface = tunnel.undergroundSurface
    local undergroundEntitiesToPlace = {}
    for x = -100, 100, 2 do
        table.insert(undergroundEntitiesToPlace, {name = "straight-rail", position = {x, 0}, direction = defines.direction.west})
    end
    for _, details in pairs(undergroundEntitiesToPlace) do
        undergroundSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction}
    end]]
end

return Test
