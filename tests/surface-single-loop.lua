local Test = {}
local Utils = require("utility/utils")

-- OLD TUNNEL CODE - NO LONGER WORKS

Test.Start = function()
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]

    local nauvisEntitiesToPlace = {}
    for y = -19, 19, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-11, y}, direction = defines.direction.north})
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {11, y}, direction = defines.direction.north})
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
        table.insert(nauvisEntitiesToPlace, {name = "rail-signal", position = {-9.5, y}, direction = defines.direction.south})
        table.insert(nauvisEntitiesToPlace, {name = "rail-signal", position = {9.5, y}, direction = defines.direction.north})
    end
    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction}
    end

    local trainStop1 = nauvisSurface.create_entity {name = "train-stop", position = {-9, -19}, direction = defines.direction.north}
    local trainStop2 = nauvisSurface.create_entity {name = "train-stop", position = {9, 19}, direction = defines.direction.south}

    local loco = nauvisSurface.create_entity {name = "locomotive", position = {-11, -16}, direction = defines.direction.north}
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
