local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local tunnelRailSurfaceCollisionLayer = CollisionMaskUtil.get_first_unused_layer()

-- This needs a placment entity with 2 or 4 orientations.
-- It should have the collision boxes and graphics for the tunnel placement piece on the surface.
-- It can only be placed against the special tiles that should go at the end of itself or tunnel portals.
-- It can have the invisible rail and hidden signals added within it. The rails will sit 1 tile within it until another one is placed next to it and then a cross piece of rail will be added. Same with the tunnel portal, being 1 tile longer than its internal rails.
-- FUTURE: Should have a tunnel crossing entity that is fast replaceable with the tunnel placement piece. Would need to be same size as the tunnel track placement entity.

local tunnelSurfacerailEndConnectionTileCollisionMask = data.raw["tile"]["railway_tunnel-tunnel_surface_rail_end_connection_tile"].collision_mask[1]
local tunnelRailSurfacePlacement = {
    type = "offshore-pump",
    name = "railway_tunnel-tunnel_rail_surface-placement",
    collision_box = {{-1.9, -1.9}, {1.9, 1.9}},
    collision_mask = {"item-layer", "object-layer", "water-tile"},
    fluid_box_tile_collision_test = nil,
    adjacent_tile_collision_test = {tunnelSurfacerailEndConnectionTileCollisionMask},
    adjacent_tile_collision_mask = nil,
    adjacent_tile_collision_box = {{-0.9, -2.9}, {0.9, -2.1}},
    graphics_set = {
        animation = {
            north = {
                filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-placement-north.png",
                height = 128,
                width = 128
            },
            east = {
                filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-placement-east.png",
                height = 128,
                width = 128
            },
            south = {
                filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-placement-south.png",
                height = 128,
                width = 128
            },
            west = {
                filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-placement-west.png",
                height = 128,
                width = 128
            }
        }
    },
    fluid_box = {
        pipe_connections = {}
    },
    pumping_speed = 1,
    fluid = "water",
    placeable_position_visualization = {
        filename = "__core__/graphics/cursor-boxes-32x32.png",
        priority = "extra-high-no-scale",
        width = 64,
        height = 64,
        scale = 0.5,
        x = 3 * 64
    }
}
data:extend({tunnelRailSurfacePlacement})

local function MakeTunnelRailSurfacePlaced(direction)
    data:extend(
        {
            {
                type = "simple-entity",
                name = "railway_tunnel-tunnel_rail_surface-placed-" .. direction,
                collision_box = tunnelRailSurfacePlacement.collision_box,
                collision_mask = tunnelRailSurfacePlacement.collision_mask,
                selection_box = tunnelRailSurfacePlacement.collision_box,
                picture = {
                    filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-base-" .. direction .. ".png",
                    height = 128,
                    width = 128
                },
                render_layer = "ground-tile"
            }
        }
    )
end
MakeTunnelRailSurfacePlaced("northsouth")
MakeTunnelRailSurfacePlaced("eastwest")
