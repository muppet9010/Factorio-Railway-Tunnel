local Utils = require("utility/utils")

--[[
    The entities shouldn't appear twice in any player ist. Placements shouldn't appear in decon planner lists. As the placed is always the selected entity by the player.
]]
local tunnelPortalSurfacePlacement = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-tunnel_portal_surface-placement",
    icon = "__railway_tunnel__/graphics/icon/tunnel_portal_surface/railway_tunnel-tunnel_portal_surface-placement.png",
    icon_size = 32,
    localised_name = {"item-name.railway_tunnel-tunnel_portal_surface-placement"},
    localised_description = {"item-description.railway_tunnel-tunnel_portal_surface-placement"},
    collision_box = {{-2.9, -24.9}, {2.9, 24.9}},
    collision_mask = {"item-layer", "object-layer", "player-layer", "water-tile"},
    max_health = 10000,
    resistances = {
        {
            type = "fire",
            percent = 100
        },
        {
            type = "acid",
            percent = 100
        }
    },
    flags = {"player-creation", "not-on-map", "not-deconstructable"},
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_portal_surface/tunnel_portal_surface-placement-north.png",
            height = 1600,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_portal_surface/tunnel_portal_surface-placement-east.png",
            height = 192,
            width = 1600
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_portal_surface/tunnel_portal_surface-placement-south.png",
            height = 1600,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_portal_surface/tunnel_portal_surface-placement-west.png",
            height = 192,
            width = 1600
        }
    },
    minable = {
        mining_time = 5,
        result = "railway_tunnel-tunnel_portal_surface-placement",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-tunnel_portal_surface-placement",
        count = 1
    }
}
data:extend({tunnelPortalSurfacePlacement})

local tunnelPortalSurfacePlaced = Utils.DeepCopy(tunnelPortalSurfacePlacement)
tunnelPortalSurfacePlaced.name = "railway_tunnel-tunnel_portal_surface-placed"
tunnelPortalSurfacePlaced.flags = {"player-creation", "not-on-map"}
tunnelPortalSurfacePlaced.picture = {
    north = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_portal_surface/tunnel_portal_surface-base-northsouth.png",
        height = 1600,
        width = 192
    },
    east = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_portal_surface/tunnel_portal_surface-base-eastwest.png",
        height = 192,
        width = 1600
    },
    south = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_portal_surface/tunnel_portal_surface-base-northsouth.png",
        height = 1600,
        width = 192
    },
    west = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_portal_surface/tunnel_portal_surface-base-eastwest.png",
        height = 192,
        width = 1600
    }
}
tunnelPortalSurfacePlaced.render_layer = "ground-tile"
tunnelPortalSurfacePlaced.selection_box = tunnelPortalSurfacePlaced.collision_box
data:extend({tunnelPortalSurfacePlaced})

data:extend(
    {
        {
            type = "item",
            name = "railway_tunnel-tunnel_portal_surface-placement",
            icon = "__railway_tunnel__/graphics/icon/tunnel_portal_surface/railway_tunnel-tunnel_portal_surface-placement.png",
            icon_size = 32,
            subgroup = "train-transport",
            order = "a[train-system]-a[rail]a",
            stack_size = 10,
            place_result = "railway_tunnel-tunnel_portal_surface-placement"
        }
    }
)
