local Utils = require("utility/utils")

--[[
    The entities shouldn't appear twice in any player list. Placements shouldn't appear in decon planner lists. As the placed is always the selected entity by the player.
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
    max_health = 1000,
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
        mining_time = 0.5,
        result = "railway_tunnel-tunnel_portal_surface-placement",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-tunnel_portal_surface-placement",
        count = 1
    }
}

local tunnelPortalSurfacePlaced = Utils.DeepCopy(tunnelPortalSurfacePlacement)
tunnelPortalSurfacePlaced.name = "railway_tunnel-tunnel_portal_surface-placed"
tunnelPortalSurfacePlaced.flags = {"player-creation", "not-on-map"}
tunnelPortalSurfacePlaced.render_layer = "ground-tile"
tunnelPortalSurfacePlaced.selection_box = tunnelPortalSurfacePlaced.collision_box
tunnelPortalSurfacePlaced.corpse = "railway_tunnel-tunnel_portal_surface-remnant"

local tunnelPortalSurfaceRemnant = {
    type = "corpse",
    name = "railway_tunnel-tunnel_portal_surface-remnant",
    icon = tunnelPortalSurfacePlacement.icon,
    icon_size = tunnelPortalSurfacePlacement.icon_size,
    icon_mipmaps = tunnelPortalSurfacePlacement.icon_mipmaps,
    flags = {"placeable-neutral", "not-on-map"},
    subgroup = "remnants",
    order = "d[remnants]-b[rail]-z[portal]",
    selection_box = tunnelPortalSurfacePlacement.selection_box,
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_portal_surface/tunnel_portal_surface-remnant.png",
        line_length = 1,
        width = 1600,
        height = 1600,
        frame_count = 1,
        direction_count = 4
    }
}

local tunnelPortalSurfacePlacementItem = {
    type = "item",
    name = "railway_tunnel-tunnel_portal_surface-placement",
    icon = "__railway_tunnel__/graphics/icon/tunnel_portal_surface/railway_tunnel-tunnel_portal_surface-placement.png",
    icon_size = 32,
    subgroup = "train-transport",
    order = "a[train-system]-a[rail]a",
    stack_size = 10,
    place_result = "railway_tunnel-tunnel_portal_surface-placement"
}

data:extend(
    {
        tunnelPortalSurfacePlacement,
        tunnelPortalSurfacePlaced,
        tunnelPortalSurfaceRemnant,
        tunnelPortalSurfacePlacementItem
    }
)
