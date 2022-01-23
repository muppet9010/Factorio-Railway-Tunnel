-- Signal that doesn't appear on the map and has a heavily shifted graphics position so its visible around the portal structure.

local CommonPrototypeFunctions = require("prototypes/common-prototype-functions")

local tunnelSignalSurfaceCollisionLayer = MODDATA.railway_tunnel.tunnelSignalSurfaceCollisionLayer

local portalEntranceSignals = {
    type = "rail-signal",
    name = "railway_tunnel-portal_entry_signal",
    icon = "__base__/graphics/icons/rail-signal.png",
    icon_size = 64,
    icon_mipmaps = 4,
    subgroup = "railway_tunnel-hidden_rail_signals",
    animation = {
        layers = {
            {
                filename = "__railway_tunnel__/graphics/entity/portal_entry_signal/portal_entry_signal-hr-rail_signal.png",
                priority = "high",
                width = 192,
                height = 192,
                frame_count = 3,
                direction_count = 4,
                scale = 0.5
            },
            {
                filename = "__railway_tunnel__/graphics/entity/portal_entry_signal/portal_entry_signal-hr-rail_signal_light.png",
                priority = "low",
                blend_mode = "additive",
                draw_as_light = true,
                width = 192,
                height = 192,
                frame_count = 3,
                direction_count = 4,
                scale = 0.5
            }
        }
    },
    collision_mask = {tunnelSignalSurfaceCollisionLayer}, -- Just collide with other signals, doesn't let the rails be damaged by weapons.
    collision_box = {{-0.2, -0.2}, {0.2, 0.2}},
    draw_circuit_wires = false,
    circuit_wire_max_distance = 1000000,
    circuit_wire_connection_points = CommonPrototypeFunctions.GetBlankCircuitWireConnectionPoints(4),
    circuit_connector_sprites = CommonPrototypeFunctions.GetBlankCircuitConnectorSprites(4)
}

data:extend(
    {
        portalEntranceSignals
    }
)
