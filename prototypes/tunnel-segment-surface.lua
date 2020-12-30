local Utils = require("utility/utils")

-- This needs a placment entity with 2 or 4 orientations.
-- It should have the collision boxes and graphics for the tunnel placement piece on the surface.
-- It will have the invisible rail and hidden signals added within it once the tunnel is confrimed end to end. The rails will sit 1 tile over its edge when added, same with the tunnel portal.
-- FUTURE: Should have a tunnel crossing entity that is fast replaceable with the tunnel placement piece. Would need to be same size as the tunnel track placement entity.

local tunnelSegmentSurfacePlacement = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-tunnel_segment_surface-placement",
    collision_box = {{-2.9, -0.9}, {2.9, 0.9}},
    collision_mask = {"item-layer", "object-layer", "water-tile"},
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/tunnel_segment_surface/tunnel_segment_surface-placement-northsouth.png",
            height = 64,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/tunnel_segment_surface/tunnel_segment_surface-placement-eastwest.png",
            height = 192,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/tunnel_segment_surface/tunnel_segment_surface-placement-northsouth.png",
            height = 64,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/tunnel_segment_surface/tunnel_segment_surface-placement-eastwest.png",
            height = 192,
            width = 64
        }
    }
}
data:extend({tunnelSegmentSurfacePlacement})

local tunnelSegmentSurfacePlaced = Utils.DeepCopy(tunnelSegmentSurfacePlacement)
tunnelSegmentSurfacePlaced.name = "railway_tunnel-tunnel_segment_surface-placed"
tunnelSegmentSurfacePlaced.picture = {
    north = {
        filename = "__railway_tunnel__/graphics/tunnel_segment_surface/tunnel_segment_surface-base-northsouth.png",
        height = 64,
        width = 192
    },
    east = {
        filename = "__railway_tunnel__/graphics/tunnel_segment_surface/tunnel_segment_surface-base-eastwest.png",
        height = 192,
        width = 64
    },
    south = {
        filename = "__railway_tunnel__/graphics/tunnel_segment_surface/tunnel_segment_surface-base-northsouth.png",
        height = 64,
        width = 192
    },
    west = {
        filename = "__railway_tunnel__/graphics/tunnel_segment_surface/tunnel_segment_surface-base-eastwest.png",
        height = 192,
        width = 64
    }
}
tunnelSegmentSurfacePlaced.render_layer = "ground-tile"
tunnelSegmentSurfacePlaced.selection_box = tunnelSegmentSurfacePlaced.collision_box
data:extend({tunnelSegmentSurfacePlaced})
