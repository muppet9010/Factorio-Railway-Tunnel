local Utils = require("utility/utils")
--[[
    The entities shouldn't appear twice in any player list. Placements shouldn't appear in decon or upgrade planner lists (primary selected entity in first column). As the placed is always the selected entity by the player.
]]
local undergroundSegmentStraightPlacement = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-underground_segment-straight-placement",
    icon = "__railway_tunnel__/graphics/icon/underground_segment-straight/railway_tunnel-underground_segment-straight-placement.png",
    icon_size = 32,
    localised_name = {"item-name.railway_tunnel-underground_segment-straight-placement"},
    localised_description = {"item-description.railway_tunnel-underground_segment-straight-placement"},
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
    fast_replaceable_group = "railway_tunnel-underground_segment-straight-from_crossing",
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-placement-northsouth.png",
            height = 64,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-placement-eastwest.png",
            height = 192,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-placement-northsouth.png",
            height = 64,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-placement-eastwest.png",
            height = 192,
            width = 64
        }
    },
    minable = {
        mining_time = 1,
        result = "railway_tunnel-underground_segment-straight-placement",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-underground_segment-straight-placement",
        count = 1
    }
}

local undergroundSegmentStraightPlaced = Utils.DeepCopy(undergroundSegmentStraightPlacement)
undergroundSegmentStraightPlaced.name = "railway_tunnel-underground_segment-straight-placed"
undergroundSegmentStraightPlaced.flags = {"player-creation", "not-on-map"}
undergroundSegmentStraightPlaced.fast_replaceable_group = "railway_tunnel-underground_segment-straight-to_crossing"
undergroundSegmentStraightPlaced.picture = {
    north = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-base-northsouth.png",
        height = 64,
        width = 192
    },
    east = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-base-eastwest.png",
        height = 192,
        width = 64
    },
    south = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-base-northsouth.png",
        height = 64,
        width = 192
    },
    west = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-base-eastwest.png",
        height = 192,
        width = 64
    }
}
undergroundSegmentStraightPlaced.render_layer = "ground-tile"
undergroundSegmentStraightPlaced.selection_box = undergroundSegmentStraightPlaced.collision_box
undergroundSegmentStraightPlaced.corpse = "railway_tunnel-underground_segment-straight-remnant"

local undergroundSegmentStraightPlacementRemnant = {
    type = "corpse",
    name = "railway_tunnel-underground_segment-straight-remnant",
    icon = undergroundSegmentStraightPlacement.icon,
    icon_size = undergroundSegmentStraightPlacement.icon_size,
    icon_mipmaps = undergroundSegmentStraightPlacement.icon_mipmaps,
    flags = {"placeable-neutral", "not-on-map"},
    subgroup = "remnants",
    order = "d[remnants]-b[rail]-z[portal]",
    selection_box = undergroundSegmentStraightPlacement.selection_box,
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-remnant.png",
        line_length = 1,
        width = 192,
        height = 192,
        frame_count = 1,
        direction_count = 2
    }
}

local undergroundSegmentStraightPlacementItem = {
    type = "item",
    name = "railway_tunnel-underground_segment-straight-placement",
    icon = "__railway_tunnel__/graphics/icon/underground_segment-straight/railway_tunnel-underground_segment-straight-placement.png",
    icon_size = 32,
    subgroup = "train-transport",
    order = "a[train-system]-a[rail]b",
    stack_size = 50,
    place_result = "railway_tunnel-underground_segment-straight-placement"
}

data:extend(
    {
        undergroundSegmentStraightPlacement,
        undergroundSegmentStraightPlaced,
        undergroundSegmentStraightPlacementRemnant,
        undergroundSegmentStraightPlacementItem
    }
)
