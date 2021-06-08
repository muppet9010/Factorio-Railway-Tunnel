local Utils = require("utility/utils")
--[[
    The entities shouldn't appear twice in any player list. Placements shouldn't appear in decon or upgrade planner lists (primary selected entity in first column). As the placed is always the selected entity by the player.
    The placed and placement are in different fast_replaceable_group to stop players from building the same type over itself. The base game only blocks the same entity name from being fast replaced over itself.
]]
local tunnelSegmentSurfacePlacementEntity = {
    type = "simple-entity-with-owner",
    name = "railway_tunnel-tunnel_segment_surface_tunnel_crossing-placement",
    icon = "__railway_tunnel__/graphics/icon/tunnel_segment_surface_tunnel_crossing/railway_tunnel-tunnel_segment_surface_tunnel_crossing-placement.png",
    icon_size = 64,
    localised_name = {"item-name.railway_tunnel-tunnel_segment_surface_tunnel_crossing-placement"},
    localised_description = {"item-description.railway_tunnel-tunnel_segment_surface_tunnel_crossing-placement"},
    collision_box = {{-2.9, -2.9}, {2.9, 2.9}},
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
        filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_tunnel_crossing/tunnel_segment_surface_tunnel_crossing-base.png",
        height = 192,
        width = 192
        --[[north = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_tunnel_crossing/tunnel_segment_surface_tunnel_crossing-placement-northsouth.png",
            height = 192,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_tunnel_crossing/tunnel_segment_surface_tunnel_crossing-placement-eastwest.png",
            height = 192,
            width = 192
        },
        south = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_tunnel_crossing/tunnel_segment_surface_tunnel_crossing-placement-northsouth.png",
            height = 192,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_tunnel_crossing/tunnel_segment_surface_tunnel_crossing-placement-eastwest.png",
            height = 192,
            width = 192
        }]]
    },
    minable = {
        mining_time = 5,
        result = "railway_tunnel-tunnel_segment_surface_tunnel_crossing-placement",
        count = 1
    },
    placeable_by = {
        item = "railway_tunnel-tunnel_segment_surface_tunnel_crossing-placement",
        count = 1
    }
}

local tunnelSegmentSurfacePlacedEntity = Utils.DeepCopy(tunnelSegmentSurfacePlacementEntity)
tunnelSegmentSurfacePlacedEntity.name = "railway_tunnel-tunnel_segment_surface_tunnel_crossing-placed"
tunnelSegmentSurfacePlacedEntity.flags = {"player-creation", "not-on-map"}
tunnelSegmentSurfacePlacedEntity.fast_replaceable_group = "railway_tunnel-tunnel_segment_surface_from_crossing"
tunnelSegmentSurfacePlacedEntity.picture = {
    filename = "__railway_tunnel__/graphics/entity/tunnel_segment_surface_tunnel_crossing/tunnel_segment_surface_tunnel_crossing-base.png",
    height = 192,
    width = 192
}
tunnelSegmentSurfacePlacedEntity.render_layer = "ground-tile"
tunnelSegmentSurfacePlacedEntity.selection_box = tunnelSegmentSurfacePlacedEntity.collision_box

local tunnelSegmentSurfaceUpgradePlacementEntity = Utils.DeepCopy(tunnelSegmentSurfacePlacementEntity)
tunnelSegmentSurfaceUpgradePlacementEntity.name = "railway_tunnel-tunnel_segment_surface_tunnel_crossing_upgrade-placement"
tunnelSegmentSurfaceUpgradePlacementEntity.collision_box = {{-0.9, -0.9}, {0.9, 0.9}} -- Just so we have to center over an existing segment, avoids any direction rotation requirements.

local tunnelSegmentSurfacePlacementItem = {
    type = "item",
    name = "railway_tunnel-tunnel_segment_surface_tunnel_crossing-placement",
    icon = "__railway_tunnel__/graphics/icon/tunnel_segment_surface_tunnel_crossing/railway_tunnel-tunnel_segment_surface_tunnel_crossing-placement.png",
    icon_size = 64,
    subgroup = "train-transport",
    order = "a[train-system]-a[rail]b",
    stack_size = 10,
    place_result = "railway_tunnel-tunnel_segment_surface_tunnel_crossing-placement"
}

local tunnelSegmentSurfaceUpgradePlacementItem = Utils.DeepCopy(tunnelSegmentSurfacePlacementItem)
tunnelSegmentSurfaceUpgradePlacementItem.name = "railway_tunnel-tunnel_segment_surface_tunnel_crossing_upgrade-placement"
tunnelSegmentSurfaceUpgradePlacementItem.place_result = "railway_tunnel-tunnel_segment_surface_tunnel_crossing_upgrade-placement"

data:extend(
    {
        tunnelSegmentSurfacePlacementEntity,
        tunnelSegmentSurfacePlacementItem,
        tunnelSegmentSurfacePlacedEntity,
        tunnelSegmentSurfaceUpgradePlacementEntity,
        tunnelSegmentSurfaceUpgradePlacementItem
    }
)
