local Utils = require("utility.utils")

local undergroundSegmentDiagonalRegular = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-underground_segment-diagonal-regular",
    icon = "__railway_tunnel__/graphics/icon/underground_segment-diagonal/railway_tunnel-underground_segment-diagonal.png",
    icon_size = 32,
    localised_name = {"item-name.railway_tunnel-underground_segment-diagonal"},
    localised_description = {"item-description.railway_tunnel-underground_segment-diagonal"},
    collision_box = {{-3.9, -0.9}, {3.9, 0.9}},
    collision_mask = {"item-layer", "object-layer", "water-tile"},
    selection_box = {{-3.9, -0.9}, {3.9, 0.9}},
    max_health = 1000,
    resistances = data.raw["wall"]["stone-wall"].resistances,
    flags = {"player-creation", "not-on-map"},
    picture = {
        -- These are set to work nicely for the user when coupled with regular (non flipped) curves.
        north = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-south.png",
            height = 64,
            width = 256
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-west.png",
            height = 256,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-south.png",
            height = 64,
            width = 256
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-west.png",
            height = 256,
            width = 64
        }
    },
    render_layer = "ground-tile",
    minable = {
        mining_time = 1,
        result = "railway_tunnel-underground_segment-diagonal-regular",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-underground_segment-diagonal-regular",
        count = 1
    },
    corpse = "railway_tunnel-underground_segment-diagonal-remnant"
}

local undergroundSegmentDiagonalRemnant = {
    type = "corpse",
    name = "railway_tunnel-underground_segment-diagonal-remnant",
    icon = undergroundSegmentDiagonalRegular.icon,
    icon_size = undergroundSegmentDiagonalRegular.icon_size,
    flags = {"placeable-neutral", "not-on-map"},
    subgroup = "remnants",
    order = "d[remnants]-b[rail]-z[portal]",
    selection_box = undergroundSegmentDiagonalRegular.selection_box,
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-remnant.png",
        line_length = 1,
        width = 256,
        height = 256,
        frame_count = 1,
        direction_count = 4
    }
}

local undergroundSegmentDiagonalRegularItem = {
    type = "item",
    name = "railway_tunnel-underground_segment-diagonal-regular",
    icon = undergroundSegmentDiagonalRegular.icon,
    icon_size = undergroundSegmentDiagonalRegular.icon_size,
    subgroup = "train-transport",
    order = "a[train-system]-a[rail]f",
    stack_size = 50,
    place_result = "railway_tunnel-underground_segment-diagonal-regular",
    flags = {} -- Fake copy adds to it.
}

local undergroundSegmentDiagonalRegularTopLayer = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-underground_segment-diagonal-regular-top_layer",
    icon = undergroundSegmentDiagonalRegular.icon,
    icon_size = undergroundSegmentDiagonalRegular.icon_size,
    subgroup = "railway_tunnel-other",
    collision_box = nil,
    collision_mask = {},
    selection_box = nil,
    flags = {"not-on-map", "not-repairable", "not-blueprintable", "not-deconstructable", "no-copy-paste", "not-upgradable"},
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-northsouth-top_layer.png",
            height = 64,
            width = 256
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-eastwest-top_layer.png",
            height = 256,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-northsouth-top_layer.png",
            height = 64,
            width = 256
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-eastwest-top_layer.png",
            height = 256,
            width = 64
        }
    },
    render_layer = "tile-transition"
}

-- Second set of 4 rotations entity.

-- The minining of the flipped part intentionally gives the regular part item as we want the player to only ever have the regular item in their inventory.

local undergroundSegmentDiagonalFlipped = Utils.DeepCopy(undergroundSegmentDiagonalRegular)
undergroundSegmentDiagonalFlipped.name = "railway_tunnel-underground_segment-diagonal-flipped"
undergroundSegmentDiagonalFlipped.placeable_by = {
    -- The order seems irrelevent in which is returned by Q (smart-pipette) as the item's place_result seems to take priority and thus gives regular part. Can react to the smart-pipette action and give the correct item via script.
    {
        item = "railway_tunnel-underground_segment-diagonal-flipped",
        count = 1
    },
    {
        item = "railway_tunnel-underground_segment-diagonal-regular",
        count = 1
    }
}
undergroundSegmentDiagonalFlipped.picture = {
    north = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-north.png",
        height = 64,
        width = 256
    },
    east = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-east.png",
        height = 256,
        width = 64
    },
    south = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-north.png",
        height = 64,
        width = 256
    },
    west = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-east.png",
        height = 256,
        width = 64
    }
}

local undergroundSegmentDiagonalFlippedItem = Utils.DeepCopy(undergroundSegmentDiagonalRegularItem)
undergroundSegmentDiagonalFlippedItem.name = "railway_tunnel-underground_segment-diagonal-flipped"
undergroundSegmentDiagonalFlippedItem.icon = nil
undergroundSegmentDiagonalFlippedItem.icons = {
    {icon = undergroundSegmentDiagonalRegularItem.icon},
    {icon = "__railway_tunnel__/graphics/icon/flipped_f_letter/railway_tunnel-flipped_f_letter.png"}
}
undergroundSegmentDiagonalFlippedItem.place_result = "railway_tunnel-underground_segment-diagonal-flipped"
undergroundSegmentDiagonalFlippedItem.subgroup = "railway_tunnel-other"
undergroundSegmentDiagonalFlippedItem.order = "a[train-system]-a[rail]f"
undergroundSegmentDiagonalFlippedItem.localised_name = {"item-name.railway_tunnel-underground_segment-diagonal-flipped"}
undergroundSegmentDiagonalFlippedItem.localised_description = {"item-description.railway_tunnel-underground_segment-diagonal-flipped"}
table.insert(undergroundSegmentDiagonalFlippedItem.flags, "only-in-cursor")
table.insert(undergroundSegmentDiagonalFlippedItem.flags, "hidden") -- Not in filter lists.

local undergroundSegmentDiagonalFlippedTopLayer = Utils.DeepCopy(undergroundSegmentDiagonalRegularTopLayer)
undergroundSegmentDiagonalFlippedTopLayer.name = "railway_tunnel-underground_segment-diagonal-flipped-top_layer"
undergroundSegmentDiagonalFlippedTopLayer.picture = {
    north = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-northsouth-top_layer.png",
        height = 64,
        width = 256
    },
    east = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-eastwest-top_layer.png",
        height = 256,
        width = 64
    },
    south = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-northsouth-top_layer.png",
        height = 64,
        width = 256
    },
    west = {
        filename = "__railway_tunnel__/graphics/entity/underground_segment-diagonal/underground_segment-diagonal-eastwest-top_layer.png",
        height = 256,
        width = 64
    }
}

data:extend(
    {
        undergroundSegmentDiagonalRegular,
        undergroundSegmentDiagonalRemnant,
        undergroundSegmentDiagonalRegularItem,
        undergroundSegmentDiagonalRegularTopLayer,
        undergroundSegmentDiagonalFlipped,
        undergroundSegmentDiagonalFlippedItem,
        undergroundSegmentDiagonalFlippedTopLayer
    }
)
