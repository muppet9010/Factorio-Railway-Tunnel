local Utils = require("utility/utils")

-- The tunnel portal goes up to the end of the entry rail, but stops mid tunnel end rail. This is to stop regualr track being connected and the tunnel rail surface when placed next to a tunnel portal will detect it and place the overlapping rail.
-- Temp graphics are from when the portal was 50 tiles long, so end 1 tile (32 pixels) are chopped off by design and shifted.

local tunnelPortalSurfacePlacement = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-tunnel_portal_surface-placement",
    collision_box = {{-2.9, -24.9}, {2.9, 24.9}},
    collision_mask = {"item-layer", "object-layer", "player-layer", "water-tile"},
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-placement-north.png",
            height = 1600,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-placement-east.png",
            height = 192,
            width = 1600
        },
        south = {
            filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-placement-south.png",
            height = 1600,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-placement-west.png",
            height = 192,
            width = 1600
        }
    }
}
data:extend({tunnelPortalSurfacePlacement})

local tunnelPortalSurfacePlaced = Utils.DeepCopy(tunnelPortalSurfacePlacement)
tunnelPortalSurfacePlaced.name = "railway_tunnel-tunnel_portal_surface-placed"
tunnelPortalSurfacePlaced.picture = {
    north = {
        filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-base-northsouth.png",
        height = 1600,
        width = 192
    },
    east = {
        filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-base-eastwest.png",
        height = 192,
        width = 1600
    },
    south = {
        filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-base-northsouth.png",
        height = 1600,
        width = 192
    },
    west = {
        filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-base-eastwest.png",
        height = 192,
        width = 1600
    }
}
tunnelPortalSurfacePlaced.render_layer = "ground-tile"
tunnelPortalSurfacePlaced.selection_box = tunnelPortalSurfacePlaced.collision_box
data:extend({tunnelPortalSurfacePlaced})
