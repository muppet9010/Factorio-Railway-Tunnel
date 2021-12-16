local Utils = require("utility/utils")

--[[
    The entities shouldn't appear twice in any player ist. Placements shouldn't appear in decon or upgrade planner lists (primary selected entity in first column). As the placed is always the selected entity by the player.
]]
local undergroundSegmentRailCrossingPlacement = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-underground_segment-straight_rail_crossing-placement",
    icon = "__railway_tunnel__/graphics/icon/underground_segment_rail_crossing/railway_tunnel-underground_segment-straight_rail_crossing-placement.png",
    icon_size = 32,
    localised_name = {"item-name.railway_tunnel-underground_segment-straight_rail_crossing-placement"},
    localised_description = {"item-description.railway_tunnel-underground_segment-straight_rail_crossing-placement"},
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
    fast_replaceable_group = "railway_tunnel-underground_segment-straight_to_crossing",
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment_rail_crossing/underground_segment_rail_crossing-placement-northsouth.png",
            height = 64,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment_rail_crossing/underground_segment_rail_crossing-placement-eastwest.png",
            height = 192,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment_rail_crossing/underground_segment_rail_crossing-placement-northsouth.png",
            height = 64,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment_rail_crossing/underground_segment_rail_crossing-placement-eastwest.png",
            height = 192,
            width = 64
        }
    },
    minable = {
        mining_time = 0.5,
        result = "railway_tunnel-underground_segment-straight_rail_crossing-placement",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-underground_segment-straight_rail_crossing-placement",
        count = 1
    }
}

local undergroundSegmentRailCrossingPlaced = Utils.DeepCopy(undergroundSegmentRailCrossingPlacement)
undergroundSegmentRailCrossingPlaced.name = "railway_tunnel-underground_segment-straight_rail_crossing-placed"
undergroundSegmentRailCrossingPlaced.flags = {"player-creation", "not-on-map"}
undergroundSegmentRailCrossingPlaced.fast_replaceable_group = "railway_tunnel-underground_segment-straight_from_crossing"
undergroundSegmentRailCrossingPlaced.picture = {
    north = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment_rail_crossing/underground_segment_rail_crossing-base-northsouth.png",
        height = 64,
        width = 192
    },
    east = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment_rail_crossing/underground_segment_rail_crossing-base-eastwest.png",
        height = 192,
        width = 64
    },
    south = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment_rail_crossing/underground_segment_rail_crossing-base-northsouth.png",
        height = 64,
        width = 192
    },
    west = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment_rail_crossing/underground_segment_rail_crossing-base-eastwest.png",
        height = 192,
        width = 64
    }
}
undergroundSegmentRailCrossingPlaced.render_layer = "ground-tile"
undergroundSegmentRailCrossingPlaced.selection_box = undergroundSegmentRailCrossingPlaced.collision_box
undergroundSegmentRailCrossingPlaced.corpse = "railway_tunnel-underground_segment-straight_rail_crossing-remnant"

local undergroundSegmentRailCrossingRemnant = {
    type = "corpse",
    name = "railway_tunnel-underground_segment-straight_rail_crossing-remnant",
    icon = undergroundSegmentRailCrossingPlacement.icon,
    icon_size = undergroundSegmentRailCrossingPlacement.icon_size,
    icon_mipmaps = undergroundSegmentRailCrossingPlacement.icon_mipmaps,
    flags = {"placeable-neutral", "not-on-map"},
    subgroup = "remnants",
    order = "d[remnants]-b[rail]-z[portal]",
    selection_box = undergroundSegmentRailCrossingPlacement.selection_box,
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment_rail_crossing/underground_segment_rail_crossing-remnant.png",
        line_length = 1,
        width = 192,
        height = 192,
        frame_count = 1,
        direction_count = 2
    }
}

local undergroundSegmentRailCrossingPlacementItem = {
    type = "item",
    name = "railway_tunnel-underground_segment-straight_rail_crossing-placement",
    icon = "__railway_tunnel__/graphics/icon/underground_segment_rail_crossing/railway_tunnel-underground_segment-straight_rail_crossing-placement.png",
    icon_size = 32,
    subgroup = "train-transport",
    order = "a[train-system]-a[rail]c",
    stack_size = 50,
    place_result = "railway_tunnel-underground_segment-straight_rail_crossing-placement"
}

data:extend(
    {
        undergroundSegmentRailCrossingPlacement,
        undergroundSegmentRailCrossingPlaced,
        undergroundSegmentRailCrossingRemnant,
        undergroundSegmentRailCrossingPlacementItem
    }
)
