local Test = {}
local Utils = require("utility/utils")

Test.Start = function()
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]

    local nauvisEntitiesToPlace = {}

    for y = -10, 10, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-1, y}, direction = defines.direction.north})
    end
    Utils.PushToList(
        nauvisEntitiesToPlace,
        {
            {name = "rail-signal", position = {-2.5, -3.5}, direction = defines.direction.north},
            {name = "rail-signal", position = {0.5, -3.5}, direction = defines.direction.south},
            {name = "rail-signal", position = {-2.5, 5.5}, direction = defines.direction.north},
            {name = "rail-signal", position = {0.5, 5.5}, direction = defines.direction.south}
        }
    )
    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction}
    end
end

return Test
