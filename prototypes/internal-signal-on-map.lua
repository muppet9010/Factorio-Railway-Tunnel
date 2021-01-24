local CommonPrototypeFunctions = require("prototypes/common-prototype-functions")

local refSignal = data.raw["rail-signal"]["rail-signal"]

return function(tunnelSignalSurfaceCollisionLayer)
    data:extend(
        {
            {
                type = "rail-signal",
                name = "railway_tunnel-internal_signal-on_map",
                flags = {"not-repairable", "not-blueprintable", "not-deconstructable", "no-copy-paste", "not-upgradable", "player-creation"}, -- We want it to show on the map to help tunnels look better.
                animation = refSignal.animation,
                collision_mask = {tunnelSignalSurfaceCollisionLayer},
                collision_box = {{-0.2, -0.2}, {0.2, 0.2}},
                draw_circuit_wires = false,
                circuit_wire_max_distance = 1000000,
                circuit_wire_connection_points = CommonPrototypeFunctions.GetBlankCircuitWireConnectionPoints(8),
                circuit_connector_sprites = CommonPrototypeFunctions.GetBlankCircuitConnectorSprites(8),
                selection_box = {{-0.5, -0.5}, {0.5, 0.5}} -- For testing when we need to select them
            }
        }
    )
end
