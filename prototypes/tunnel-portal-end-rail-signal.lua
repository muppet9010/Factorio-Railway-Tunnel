local Utils = require("utility/utils")

-- Have to do this 4 rotations to keep it happy and avoid crashing on connecting rail signals via wires.
-- This bug causes the need of 4 rotations: https://forums.factorio.com/viewtopic.php?f=30&t=93681

local GetBlankAnimations = function()
    local animation = {
        direction_count = 4,
        filenames = {},
        size = 1,
        slice = 1,
        lines_per_file = 1
    }
    for _ = 1, 4 do
        table.insert(animation.filenames, "__core__/graphics/empty.png")
    end
    return animation
end

local GetBlankCircuitWireConnectionPoints = function()
    local points = {}
    for _ = 1, 4 do
        table.insert(points, {wire = {copper = {0, 0}, red = {0, 0}, green = {0, 0}}, shadow = {copper = {0, 0}, red = {0, 0}, green = {0, 0}}})
    end
    return points
end

local GetBlankCircuitConnectorSprites = function()
    local sprites = {}
    for _ = 1, 4 do
        table.insert(sprites, {led_red = Utils.EmptyRotatedSprite(), led_green = Utils.EmptyRotatedSprite(), led_blue = Utils.EmptyRotatedSprite(), led_light = {type = "basic", intensity = 0, size = 0}})
    end
    return sprites
end

data:extend(
    {
        {
            type = "rail-signal",
            name = "railway_tunnel-tunnel_portal_end_rail_signal",
            animation = GetBlankAnimations(),
            collision_mask = data.raw["rail-signal"]["railway_tunnel-tunnel_rail_signal_surface"].collision_mask,
            collision_box = {{-0.2, -0.2}, {0.2, 0.2}},
            draw_circuit_wires = false,
            circuit_wire_max_distance = 10,
            circuit_wire_connection_points = GetBlankCircuitWireConnectionPoints(),
            circuit_connector_sprites = GetBlankCircuitConnectorSprites()
            --selection_box = {{-0.5, -0.5}, {0.5, 0.5}} -- For testing when we need to select them
        }
    }
)
