local undergroundSegmentStraight = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-underground_segment-straight",
    icon = "__railway_tunnel__/graphics/icon/underground_segment-straight/railway_tunnel-underground_segment-straight.png",
    icon_size = 32,
    localised_name = {"item-name.railway_tunnel-underground_segment-straight"},
    localised_description = {"item-description.railway_tunnel-underground_segment-straight"},
    collision_box = {{-2.9, -0.9}, {2.9, 0.9}},
    collision_mask = {"item-layer", "object-layer", "water-tile"},
    selection_box = {{-2.9, -0.9}, {2.9, 0.9}},
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
    flags = {"player-creation", "not-on-map"},
    fast_replaceable_group = "railway_tunnel-underground_segment-straight",
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-northsouth.png",
            height = 64,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-eastwest.png",
            height = 192,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-northsouth.png",
            height = 64,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-eastwest.png",
            height = 192,
            width = 64
        }
    },
    render_layer = "ground-tile",
    minable = {
        mining_time = 1,
        result = "railway_tunnel-underground_segment-straight",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-underground_segment-straight",
        count = 1
    },
    corpse = "railway_tunnel-underground_segment-straight-remnant"
}

local undergroundSegmentStraightRemnant = {
    type = "corpse",
    name = "railway_tunnel-underground_segment-straight-remnant",
    icon = undergroundSegmentStraight.icon,
    icon_size = undergroundSegmentStraight.icon_size,
    icon_mipmaps = undergroundSegmentStraight.icon_mipmaps,
    flags = {"placeable-neutral", "not-on-map"},
    subgroup = "remnants",
    order = "d[remnants]-b[rail]-z[portal]",
    selection_box = undergroundSegmentStraight.selection_box,
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
        direction_count = 4
    }
}

local undergroundSegmentStraightItem = {
    type = "item",
    name = "railway_tunnel-underground_segment-straight",
    icon = "__railway_tunnel__/graphics/icon/underground_segment-straight/railway_tunnel-underground_segment-straight.png",
    icon_size = 32,
    subgroup = "train-transport",
    order = "a[train-system]-a[rail]b",
    stack_size = 50,
    place_result = "railway_tunnel-underground_segment-straight"
}

local undergroundSegmentStraightTopLayer = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-underground_segment-straight-top_layer",
    icon = "__railway_tunnel__/graphics/icon/underground_segment-straight/railway_tunnel-underground_segment-straight.png",
    icon_size = 32,
    subgroup = "railway_tunnel-other",
    collision_box = nil,
    collision_mask = {},
    selection_box = nil,
    flags = {"not-on-map"},
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-northsouth-top_layer.png",
            height = 64,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-eastwest-top_layer.png",
            height = 192,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-northsouth-top_layer.png",
            height = 64,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight/underground_segment-straight-eastwest-top_layer.png",
            height = 192,
            width = 64
        }
    },
    render_layer = "tile-transition"
}

data:extend(
    {
        undergroundSegmentStraight,
        undergroundSegmentStraightRemnant,
        undergroundSegmentStraightItem,
        undergroundSegmentStraightTopLayer
    }
)
