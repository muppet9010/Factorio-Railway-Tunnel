local Utils = require("utility/utils")
local CommonPrototypeFunctions = {}

CommonPrototypeFunctions.GetBlankAnimations = function(rotations)
    local animation = {
        direction_count = rotations,
        filenames = {},
        size = 1,
        slice = 1,
        lines_per_file = 1
    }
    for _ = 1, rotations do
        table.insert(animation.filenames, "__core__/graphics/empty.png")
    end
    return animation
end

CommonPrototypeFunctions.GetBlankCircuitWireConnectionPoints = function(rotations)
    local points = {}
    for _ = 1, rotations do
        table.insert(points, {wire = {copper = {0, 0}, red = {0, 0}, green = {0, 0}}, shadow = {copper = {0, 0}, red = {0, 0}, green = {0, 0}}})
    end
    return points
end

CommonPrototypeFunctions.GetBlankCircuitConnectorSprites = function(rotations)
    local sprites = {}
    for _ = 1, rotations do
        table.insert(sprites, {led_red = Utils.EmptyRotatedSprite(), led_green = Utils.EmptyRotatedSprite(), led_blue = Utils.EmptyRotatedSprite(), led_light = {type = "basic", intensity = 0, size = 0}})
    end
    return sprites
end

return CommonPrototypeFunctions
