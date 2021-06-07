local CommonPrototypeFunctions = require("prototypes/common-prototype-functions")

local testing = false

return function(tunnelSignalSurfaceCollisionLayer)
    local newSignal = {
        type = "rail-signal",
        name = "railway_tunnel-invisible_signal-not_on_map",
        icon = "__base__/graphics/icons/rail-signal.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "railway_tunnel-hidden_rail_signals",
        animation = CommonPrototypeFunctions.GetBlankAnimations(1),
        collision_mask = {tunnelSignalSurfaceCollisionLayer}, -- Just collide with other signals, doesn't let the rails be daged by weapons.
        collision_box = {{-0.2, -0.2}, {0.2, 0.2}},
        draw_circuit_wires = false,
        circuit_wire_max_distance = 10,
        circuit_wire_connection_points = CommonPrototypeFunctions.GetBlankCircuitWireConnectionPoints(1),
        circuit_connector_sprites = CommonPrototypeFunctions.GetBlankCircuitConnectorSprites(1)
    }
    if testing then
        local refSignal = data.raw["rail-signal"]["rail-signal"]
        newSignal.animation = refSignal.animation
        newSignal.circuit_wire_connection_points = CommonPrototypeFunctions.GetBlankCircuitWireConnectionPoints(8)
        newSignal.circuit_connector_sprites = CommonPrototypeFunctions.GetBlankCircuitConnectorSprites(8)
        newSignal.selection_box = {{-0.5, -0.5}, {0.5, 0.5}}
    end
    data:extend(
        {
            newSignal
        }
    )
end
