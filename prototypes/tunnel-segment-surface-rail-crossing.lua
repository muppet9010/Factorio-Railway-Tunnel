local Utils = require("utility/utils")

--[[
    The entities shouldn't appear twice in any player ist. Placements shouldn't appear in decon or upgrade planner lists (primary selected entity in first column). As the placed is always the selected entity by the player.
]]
local tunnelSegmentSurfaceRailCrossingPlacement = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-tunnel_segment_surface_rail_crossing-placement",
    icon = "__railway_tunnel__/graphics/icon/tunnel_segment_surface_rail_crossing/railway_tunnel-tunnel_segment_surface_rail_crossing-placement.png",
    icon_size = 32,
    localised_name = {"item-name.railway_tunnel-tunnel_segment_surface_rail_crossing-placement"},
    localised_description = {"item-description.railway_tunnel-tunnel_segment_surface_rail_crossing-placement"},
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
    fast_replaceable_group = "railway_tunnel-tunnel_segment_surface_to_crossing",
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_rail_crossing/tunnel_segment_surface_rail_crossing-placement-northsouth.png",
            height = 64,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_rail_crossing/tunnel_segment_surface_rail_crossing-placement-eastwest.png",
            height = 192,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_rail_crossing/tunnel_segment_surface_rail_crossing-placement-northsouth.png",
            height = 64,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_rail_crossing/tunnel_segment_surface_rail_crossing-placement-eastwest.png",
            height = 192,
            width = 64
        }
    },
    minable = {
        mining_time = 0.5,
        result = "railway_tunnel-tunnel_segment_surface_rail_crossing-placement",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-tunnel_segment_surface_rail_crossing-placement",
        count = 1
    }
}

local tunnelSegmentSurfaceRailCrossingPlaced = Utils.DeepCopy(tunnelSegmentSurfaceRailCrossingPlacement)
tunnelSegmentSurfaceRailCrossingPlaced.name = "railway_tunnel-tunnel_segment_surface_rail_crossing-placed"
tunnelSegmentSurfaceRailCrossingPlaced.flags = {"player-creation", "not-on-map"}
tunnelSegmentSurfaceRailCrossingPlaced.fast_replaceable_group = "railway_tunnel-tunnel_segment_surface_from_crossing"
tunnelSegmentSurfaceRailCrossingPlaced.picture = {
    north = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_rail_crossing/tunnel_segment_surface_rail_crossing-base-northsouth.png",
        height = 64,
        width = 192
    },
    east = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_rail_crossing/tunnel_segment_surface_rail_crossing-base-eastwest.png",
        height = 192,
        width = 64
    },
    south = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_rail_crossing/tunnel_segment_surface_rail_crossing-base-northsouth.png",
        height = 64,
        width = 192
    },
    west = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_rail_crossing/tunnel_segment_surface_rail_crossing-base-eastwest.png",
        height = 192,
        width = 64
    }
}
tunnelSegmentSurfaceRailCrossingPlaced.render_layer = "ground-tile"
tunnelSegmentSurfaceRailCrossingPlaced.selection_box = tunnelSegmentSurfaceRailCrossingPlaced.collision_box
tunnelSegmentSurfaceRailCrossingPlaced.corpse = "railway_tunnel-tunnel_segment_surface_rail_crossing-remnant"

local tunnelSegmentSurfaceRailCrossingRemnant = {
    type = "corpse",
    name = "railway_tunnel-tunnel_segment_surface_rail_crossing-remnant",
    icon = tunnelSegmentSurfaceRailCrossingPlacement.icon,
    icon_size = tunnelSegmentSurfaceRailCrossingPlacement.icon_size,
    icon_mipmaps = tunnelSegmentSurfaceRailCrossingPlacement.icon_mipmaps,
    flags = {"placeable-neutral", "not-on-map"},
    subgroup = "remnants",
    order = "d[remnants]-b[rail]-z[portal]",
    selection_box = tunnelSegmentSurfaceRailCrossingPlacement.selection_box,
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = {
        filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_rail_crossing/tunnel_segment_surface_rail_crossing-remnant.png",
        line_length = 1,
        width = 192,
        height = 192,
        frame_count = 1,
        direction_count = 2
    }
}

local tunnelSegmentSurfaceRailCrossingPlacementItem = {
    type = "item",
    name = "railway_tunnel-tunnel_segment_surface_rail_crossing-placement",
    icon = "__railway_tunnel__/graphics/icon/tunnel_segment_surface_rail_crossing/railway_tunnel-tunnel_segment_surface_rail_crossing-placement.png",
    icon_size = 32,
    subgroup = "train-transport",
    order = "a[train-system]-a[rail]c",
    stack_size = 50,
    place_result = "railway_tunnel-tunnel_segment_surface_rail_crossing-placement"
}

data:extend(
    {
        tunnelSegmentSurfaceRailCrossingPlacement,
        tunnelSegmentSurfaceRailCrossingPlaced,
        tunnelSegmentSurfaceRailCrossingRemnant,
        tunnelSegmentSurfaceRailCrossingPlacementItem
    }
)
