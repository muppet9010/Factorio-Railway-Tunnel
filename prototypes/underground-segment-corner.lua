local undergroundSegmentCorner = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-underground_segment-corner",
    icon = "__railway_tunnel__/graphics/icon/underground_segment-corner/railway_tunnel-underground_segment-corner.png",
    icon_size = 32,
    localised_name = {"item-name.railway_tunnel-underground_segment-corner"},
    localised_description = {"item-description.railway_tunnel-underground_segment-corner"},
    collision_box = {{-2.9, -2.9}, {2.9, 2.9}},
    collision_mask = {"item-layer", "object-layer", "water-tile"},
    selection_box = {{-2.9, -2.9}, {2.9, 2.9}},
    max_health = 3000,
    resistances = data.raw["wall"]["stone-wall"].resistances,
    flags = {"player-creation", "not-on-map"},
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-corner/underground_segment-corner-north.png",
            height = 192,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-corner/underground_segment-corner-east.png",
            height = 192,
            width = 192
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-corner/underground_segment-corner-south.png",
            height = 192,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-corner/underground_segment-corner-west.png",
            height = 192,
            width = 192
        }
    },
    render_layer = "ground-tile",
    minable = {
        mining_time = 1,
        result = "railway_tunnel-underground_segment-corner",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-underground_segment-corner",
        count = 1
    },
    corpse = "railway_tunnel-underground_segment-corner-remnant"
}

local undergroundSegmentCornerRemnant = {
    type = "corpse",
    name = "railway_tunnel-underground_segment-corner-remnant",
    icon = undergroundSegmentCorner.icon,
    icon_size = undergroundSegmentCorner.icon_size,
    flags = {"placeable-neutral", "not-on-map"},
    subgroup = "remnants",
    order = "d[remnants]-b[rail]-z[portal]",
    selection_box = undergroundSegmentCorner.selection_box,
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-corner/underground_segment-corner-remnant.png",
        line_length = 1,
        width = 192,
        height = 192,
        frame_count = 1,
        direction_count = 1
    }
}

local undergroundSegmentCornerItem = {
    type = "item",
    name = "railway_tunnel-underground_segment-corner",
    icon = undergroundSegmentCorner.icon,
    icon_size = undergroundSegmentCorner.icon_size,
    subgroup = "train-transport",
    order = "a[train-system]-a[rail]f",
    stack_size = 50,
    place_result = "railway_tunnel-underground_segment-corner",
    flags = {} -- Fake copy adds to it.
}

local undergroundSegmentCornerTopLayer = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-underground_segment-corner-top_layer",
    icon = undergroundSegmentCorner.icon,
    icon_size = undergroundSegmentCorner.icon_size,
    subgroup = "railway_tunnel-other",
    collision_box = nil,
    collision_mask = {},
    selection_box = nil,
    flags = {"not-on-map", "not-repairable", "not-blueprintable", "not-deconstructable", "no-copy-paste", "not-upgradable"},
    picture = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-corner/underground_segment-corner-top_layer.png",
        height = 192,
        width = 192
    },
    render_layer = "tile-transition"
}

if settings.startup["railway_tunnel-show_curved_tunnel_parts"].value then
    data:extend(
        {
            undergroundSegmentCorner,
            undergroundSegmentCornerRemnant,
            undergroundSegmentCornerItem,
            undergroundSegmentCornerTopLayer
        }
    )
end
