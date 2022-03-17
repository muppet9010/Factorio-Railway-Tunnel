local undergroundSegmentStraightTunnelCrossing = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-underground_segment-straight-tunnel_crossing",
    icon = "__railway_tunnel__/graphics/icon/underground_segment-straight-tunnel_crossing/railway_tunnel-underground_segment-straight-tunnel_crossing.png",
    icon_size = 32,
    localised_name = {"item-name.railway_tunnel-underground_segment-straight-tunnel_crossing"},
    localised_description = {"item-description.railway_tunnel-underground_segment-straight-tunnel_crossing"},
    collision_box = {{-2.9, -0.9}, {2.9, 0.9}},
    collision_mask = {"item-layer", "object-layer", "water-tile"},
    selection_box = {{-2.9, -0.9}, {2.9, 0.9}},
    max_health = 1000,
    resistances = data.raw["wall"]["stone-wall"].resistances,
    flags = {"player-creation", "not-on-map"},
    fast_replaceable_group = "railway_tunnel-underground_segment-straight",
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-tunnel_crossing/underground_segment-straight-tunnel_crossing-northsouth.png",
            height = 64,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-tunnel_crossing/underground_segment-straight-tunnel_crossing-eastwest.png",
            height = 192,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-tunnel_crossing/underground_segment-straight-tunnel_crossing-northsouth.png",
            height = 64,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-tunnel_crossing/underground_segment-straight-tunnel_crossing-eastwest.png",
            height = 192,
            width = 64
        }
    },
    render_layer = "ground-tile",
    minable = {
        mining_time = 1,
        result = "railway_tunnel-underground_segment-straight-tunnel_crossing",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-underground_segment-straight-tunnel_crossing",
        count = 1
    },
    corpse = "railway_tunnel-underground_segment-straight-tunnel_crossing-remnant"
}

local undergroundSegmentStraightTunnelCrossingRemnant = {
    type = "corpse",
    name = "railway_tunnel-underground_segment-straight-tunnel_crossing-remnant",
    icon = undergroundSegmentStraightTunnelCrossing.icon,
    icon_size = undergroundSegmentStraightTunnelCrossing.icon_size,
    icon_mipmaps = undergroundSegmentStraightTunnelCrossing.icon_mipmaps,
    flags = {"placeable-neutral", "not-on-map"},
    subgroup = "remnants",
    order = "d[remnants]-b[rail]-z[portal]",
    selection_box = undergroundSegmentStraightTunnelCrossing.selection_box,
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-tunnel_crossing/underground_segment-straight-tunnel_crossing-remnant.png",
        line_length = 1,
        width = 192,
        height = 192,
        frame_count = 1,
        direction_count = 4
    }
}

local undergroundSegmentStraightTunnelCrossingItem = {
    type = "item",
    name = "railway_tunnel-underground_segment-straight-tunnel_crossing",
    icon = "__railway_tunnel__/graphics/icon/underground_segment-straight-tunnel_crossing/railway_tunnel-underground_segment-straight-tunnel_crossing.png",
    icon_size = 32,
    subgroup = "train-transport",
    order = "a[train-system]-a[rail]d",
    stack_size = 50,
    place_result = "railway_tunnel-underground_segment-straight-tunnel_crossing"
}

local undergroundSegmentStraightTunnelCrossingTopLayer = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-underground_segment-straight-tunnel_crossing-top_layer",
    icon = "__railway_tunnel__/graphics/icon/underground_segment-straight-tunnel_crossing/railway_tunnel-underground_segment-straight-tunnel_crossing.png",
    icon_size = 32,
    subgroup = "railway_tunnel-other",
    collision_box = nil,
    collision_mask = {},
    selection_box = nil,
    flags = {"not-on-map"},
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-tunnel_crossing/underground_segment-straight-tunnel_crossing-northsouth-top_layer.png",
            height = 64,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-tunnel_crossing/underground_segment-straight-tunnel_crossing-eastwest-top_layer.png",
            height = 192,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-tunnel_crossing/underground_segment-straight-tunnel_crossing-northsouth-top_layer.png",
            height = 64,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-tunnel_crossing/underground_segment-straight-tunnel_crossing-eastwest-top_layer.png",
            height = 192,
            width = 64
        }
    },
    render_layer = "tile-transition"
}

-- We render this sprite orientated to the segment entity and its flat on the ground so can freely rotate as required. So it can be used for all 4 cardinal direction rotations.
local undergroundSegmentStraightTunnelCrossing_crossingArrowLayer = {
    type = "sprite",
    name = "railway_tunnel-underground_segment-straight-tunnel_crossing-crossing_arrow",
    filename = "__railway_tunnel__/graphics/entity/underground_segment-straight-tunnel_crossing/underground_segment-straight-tunnel_crossing-northsouth-crossing_tunnel_arrow.png",
    height = 64,
    width = 192
}

data:extend(
    {
        undergroundSegmentStraightTunnelCrossing,
        undergroundSegmentStraightTunnelCrossingRemnant,
        undergroundSegmentStraightTunnelCrossingItem,
        undergroundSegmentStraightTunnelCrossingTopLayer,
        undergroundSegmentStraightTunnelCrossing_crossingArrowLayer
    }
)
