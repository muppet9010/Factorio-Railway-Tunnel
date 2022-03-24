local undergroundSegmentRailCrossing = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-underground_segment-straight-rail_crossing",
    icon = "__railway_tunnel__/graphics/icon/underground_segment-straight-rail_crossing/railway_tunnel-underground_segment-straight-rail_crossing.png",
    icon_size = 32,
    localised_name = {"item-name.railway_tunnel-underground_segment-straight-rail_crossing"},
    localised_description = {"item-description.railway_tunnel-underground_segment-straight-rail_crossing"},
    collision_box = {{-2.9, -0.9}, {2.9, 0.9}},
    collision_mask = {"item-layer", "object-layer", "water-tile"},
    selection_box = {{-2.9, -0.9}, {2.9, 0.9}},
    max_health = 1000,
    resistances = data.raw["wall"]["stone-wall"].resistances,
    flags = {"player-creation", "not-on-map"},
    fast_replaceable_group = "railway_tunnel-underground_segment-straight",
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-rail_crossing/underground_segment-straight-rail_crossing-northsouth.png",
            height = 64,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-rail_crossing/underground_segment-straight-rail_crossing-eastwest.png",
            height = 192,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-rail_crossing/underground_segment-straight-rail_crossing-northsouth.png",
            height = 64,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-rail_crossing/underground_segment-straight-rail_crossing-eastwest.png",
            height = 192,
            width = 64
        }
    },
    render_layer = "ground-tile",
    minable = {
        mining_time = 0.5,
        result = "railway_tunnel-underground_segment-straight-rail_crossing",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-underground_segment-straight-rail_crossing",
        count = 1
    },
    corpse = "railway_tunnel-underground_segment-straight-rail_crossing-remnant"
}

local undergroundSegmentRailCrossingRemnant = {
    type = "corpse",
    name = "railway_tunnel-underground_segment-straight-rail_crossing-remnant",
    icon = undergroundSegmentRailCrossing.icon,
    icon_size = undergroundSegmentRailCrossing.icon_size,
    flags = {"placeable-neutral", "not-on-map"},
    subgroup = "remnants",
    order = "d[remnants]-b[rail]-z[portal]",
    selection_box = undergroundSegmentRailCrossing.selection_box,
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-rail_crossing/underground_segment-straight-rail_crossing-remnant.png",
        line_length = 1,
        width = 192,
        height = 192,
        frame_count = 1,
        direction_count = 4
    }
}

local undergroundSegmentRailCrossingItem = {
    type = "item",
    name = "railway_tunnel-underground_segment-straight-rail_crossing",
    icon = undergroundSegmentRailCrossing.icon,
    icon_size = undergroundSegmentRailCrossing.icon_size,
    subgroup = "train-transport",
    order = "a[train-system]-a[rail]c",
    stack_size = 50,
    place_result = "railway_tunnel-underground_segment-straight-rail_crossing"
}

data:extend(
    {
        undergroundSegmentRailCrossing,
        undergroundSegmentRailCrossingRemnant,
        undergroundSegmentRailCrossingItem
    }
)
