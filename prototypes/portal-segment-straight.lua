local portalSegmentStraight = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-portal_segment-straight",
    icon = "__railway_tunnel__/graphics/icon/portal_segment-straight/railway_tunnel-portal_segment-straight.png",
    icon_size = 32,
    localised_name = {"item-name.railway_tunnel-portal_segment-straight"},
    localised_description = {"item-description.railway_tunnel-portal_segment-straight"},
    collision_box = {{-2.9, -0.9}, {2.9, 0.9}},
    collision_mask = {"item-layer", "object-layer", "player-layer", "water-tile"},
    selection_box = {{-2.9, -0.9}, {2.9, 0.9}},
    max_health = 1000,
    resistances = data.raw["wall"]["stone-wall"].resistances,
    flags = {"player-creation", "not-on-map"},
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/portal_segment-straight/portal_segment-straight-northsouth.png",
            height = 64,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/portal_segment-straight/portal_segment-straight-eastwest.png",
            height = 192,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/portal_segment-straight/portal_segment-straight-northsouth.png",
            height = 64,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/portal_segment-straight/portal_segment-straight-eastwest.png",
            height = 192,
            width = 64
        }
    },
    render_layer = "ground-tile",
    minable = {
        mining_time = 0.5,
        result = "railway_tunnel-portal_segment-straight",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-portal_segment-straight",
        count = 1
    },
    corpse = "railway_tunnel-portal_segment-straight-remnant"
}

local portalSegmentRemnant = {
    type = "corpse",
    name = "railway_tunnel-portal_segment-straight-remnant",
    icon = portalSegmentStraight.icon,
    icon_size = portalSegmentStraight.icon_size,
    flags = {"placeable-neutral", "not-on-map"},
    subgroup = "remnants",
    order = "d[remnants]-b[rail]-z[portal]",
    selection_box = portalSegmentStraight.selection_box,
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = {
        filename = "__railway_tunnel__/graphics/entity/portal_segment-straight/portal_segment-straight-remnant.png",
        line_length = 1,
        width = 192,
        height = 192,
        frame_count = 1,
        direction_count = 4
    }
}

local portalSegmentStraightItem = {
    type = "item",
    name = "railway_tunnel-portal_segment-straight",
    icon = portalSegmentStraight.icon,
    icon_size = portalSegmentStraight.icon_size,
    subgroup = "train-transport",
    order = "a[train-system]-a[rail]a",
    stack_size = 50,
    place_result = "railway_tunnel-portal_segment-straight"
}

data:extend(
    {
        portalSegmentStraight,
        portalSegmentRemnant,
        portalSegmentStraightItem
    }
)
