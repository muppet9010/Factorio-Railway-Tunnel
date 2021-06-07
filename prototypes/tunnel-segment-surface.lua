local Utils = require("utility/utils")
--[[
    The entities shouldn't appear twice in any player list. Placements shouldn't appear in decon or upgrade planner lists (primary selected entity in first column). As the placed is always the selected entity by the player.
    The placed and placement are in different fast_replaceable_group to stop players from building the same type over itself. The base game only blocks the same entity name from being fast replaced over itself.
]]
local tunnelSegmentSurfacePlacement = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-tunnel_segment_surface-placement",
    icon = "__railway_tunnel__/graphics/icon/tunnel_segment_surface/railway_tunnel-tunnel_segment_surface-placement.png",
    icon_size = 32,
    localised_name = {"item-name.railway_tunnel-tunnel_segment_surface-placement"},
    localised_description = {"item-description.railway_tunnel-tunnel_segment_surface-placement"},
    collision_box = {{-2.9, -0.9}, {2.9, 0.9}},
    collision_mask = {"item-layer", "object-layer", "water-tile"},
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
    flags = {"player-creation", "not-on-map", "not-deconstructable", "not-upgradable"},
    fast_replaceable_group = "railway_tunnel-tunnel_segment_surface_from_crossing",
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface/tunnel_segment_surface-placement-northsouth.png",
            height = 64,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface/tunnel_segment_surface-placement-eastwest.png",
            height = 192,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface/tunnel_segment_surface-placement-northsouth.png",
            height = 64,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface/tunnel_segment_surface-placement-eastwest.png",
            height = 192,
            width = 64
        }
    },
    minable = {
        mining_time = 5,
        result = "railway_tunnel-tunnel_segment_surface-placement",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-tunnel_segment_surface-placement",
        count = 1
    }
}
data:extend({tunnelSegmentSurfacePlacement})

local tunnelSegmentSurfacePlaced = Utils.DeepCopy(tunnelSegmentSurfacePlacement)
tunnelSegmentSurfacePlaced.name = "railway_tunnel-tunnel_segment_surface-placed"
tunnelSegmentSurfacePlaced.flags = {"player-creation", "not-on-map"}
tunnelSegmentSurfacePlaced.fast_replaceable_group = "railway_tunnel-tunnel_segment_surface_to_crossing"
tunnelSegmentSurfacePlaced.picture = {
    north = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface/tunnel_segment_surface-base-northsouth.png",
        height = 64,
        width = 192
    },
    east = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface/tunnel_segment_surface-base-eastwest.png",
        height = 192,
        width = 64
    },
    south = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface/tunnel_segment_surface-base-northsouth.png",
        height = 64,
        width = 192
    },
    west = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface/tunnel_segment_surface-base-eastwest.png",
        height = 192,
        width = 64
    }
}
tunnelSegmentSurfacePlaced.render_layer = "ground-tile"
tunnelSegmentSurfacePlaced.selection_box = tunnelSegmentSurfacePlaced.collision_box
data:extend({tunnelSegmentSurfacePlaced})

data:extend(
    {
        {
            type = "item",
            name = "railway_tunnel-tunnel_segment_surface-placement",
            icon = "__railway_tunnel__/graphics/icon/tunnel_segment_surface/railway_tunnel-tunnel_segment_surface-placement.png",
            icon_size = 32,
            subgroup = "train-transport",
            order = "a[train-system]-a[rail]b",
            stack_size = 50,
            place_result = "railway_tunnel-tunnel_segment_surface-placement"
        }
    }
)
