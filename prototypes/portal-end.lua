local Utils = require("utility/utils")

--[[
    The entities shouldn't appear twice in any player list. Placements shouldn't appear in decon planner lists. As the placed is always the selected entity by the player.
]]
local portalEndPlacement = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-portal_end-placement",
    icon = "__railway_tunnel__/graphics/icon/portal_end/railway_tunnel-portal_end-placement.png",
    icon_size = 32,
    localised_name = {"item-name.railway_tunnel-portal_end-placement"},
    localised_description = {"item-description.railway_tunnel-portal_end-placement"},
    collision_box = {{-2.9, -2.9}, {2.9, 2.9}},
    collision_mask = {"item-layer", "object-layer", "player-layer", "water-tile"},
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
    flags = {"player-creation", "not-on-map", "not-deconstructable"},
    picture = {
        north = {
            filename = "__railway_tunnel__/graphics/entity/portal_end/portal_end-placement-northsouth.png",
            height = 192,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/portal_end/portal_end-placement-eastwest.png",
            height = 192,
            width = 192
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/portal_end/portal_end-placement-northsouth.png",
            height = 192,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/portal_end/portal_end-placement-eastwest.png",
            height = 192,
            width = 192
        }
    },
    minable = {
        mining_time = 0.5,
        result = "railway_tunnel-portal_end-placement",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-portal_end-placement",
        count = 1
    }
}

local portalEndPlaced = Utils.DeepCopy(portalEndPlacement)
portalEndPlaced.name = "railway_tunnel-portal_end-placed"
portalEndPlaced.flags = {"player-creation", "not-on-map"}
portalEndPlaced.render_layer = "ground-tile"
portalEndPlaced.selection_box = portalEndPlaced.collision_box
portalEndPlaced.corpse = "railway_tunnel-portal_end-remnant"

local portalEndRemnant = {
    type = "corpse",
    name = "railway_tunnel-portal_end-remnant",
    icon = portalEndPlacement.icon,
    icon_size = portalEndPlacement.icon_size,
    icon_mipmaps = portalEndPlacement.icon_mipmaps,
    flags = {"placeable-neutral", "not-on-map"},
    subgroup = "remnants",
    order = "d[remnants]-b[rail]-z[portal]",
    selection_box = portalEndPlacement.selection_box,
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = {
        filename = "__railway_tunnel__/graphics/entity/portal_end/portal_end-remnant.png",
        line_length = 1,
        width = 192,
        height = 192,
        frame_count = 1,
        direction_count = 2
    }
}

local portalEndPlacementItem = {
    type = "item",
    name = "railway_tunnel-portal_end-placement",
    icon = "__railway_tunnel__/graphics/icon/portal_end/railway_tunnel-portal_end-placement.png",
    icon_size = 32,
    subgroup = "train-transport",
    order = "a[train-system]-a[rail]a",
    stack_size = 10,
    place_result = "railway_tunnel-portal_end-placement"
}

data:extend(
    {
        portalEndPlacement,
        portalEndPlaced,
        portalEndRemnant,
        portalEndPlacementItem
    }
)
