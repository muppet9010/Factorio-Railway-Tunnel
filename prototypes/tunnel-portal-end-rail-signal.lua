local CommonPrototypeFunctions = require("prototypes/common-prototype-functions")

-- Have to do this 4 rotations to keep it happy and avoid crashing on connecting rail signals via wires.
-- This bug causes the need of 4 rotations: https://forums.factorio.com/viewtopic.php?f=30&t=93681

return function(tunnelSignalSurfaceCollisionLayer)
    data:extend(
        {
            {
                type = "rail-signal",
                name = "railway_tunnel-tunnel_portal_end_rail_signal",
                animation = CommonPrototypeFunctions.GetBlankAnimations(1),
                collision_mask = {tunnelSignalSurfaceCollisionLayer},
                collision_box = {{-0.2, -0.2}, {0.2, 0.2}},
                draw_circuit_wires = false,
                circuit_wire_max_distance = 10,
                circuit_wire_connection_points = CommonPrototypeFunctions.GetBlankCircuitWireConnectionPoints(1),
                circuit_connector_sprites = CommonPrototypeFunctions.GetBlankCircuitConnectorSprites(1)
                --selection_box = {{-0.5, -0.5}, {0.5, 0.5}} -- For testing when we need to select them
            }
        }
    )
end
