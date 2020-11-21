local Test = {}
local Utils = require("utility/utils")

Test.Start = function()
    local nauvisSurface = game.surfaces[1]
    local playerForce = game.forces[1]

    local nauvisEntitiesToPlace = {}
    for x = -100, 100, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {x, 0}, direction = defines.direction.west})
    end
    Utils.PushToList(
        nauvisEntitiesToPlace,
        {
            {name = "rail-signal", position = {60, -0.5}, direction = defines.direction.east}
        }
    )

    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction}
    end

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
