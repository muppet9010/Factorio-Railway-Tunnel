local Utils = require("utility/utils")
local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local tunnelRailSurfacePlacementCollisionLayer = CollisionMaskUtil.get_first_unused_layer()

-- The tunnel portal goes up to the end of the entry rail, but stops mid tunnel end rail. This is to stop regualr track being connected and the tunnel rail surface when placed next to a tunnel portal will detect it and place the overlapping rail.
-- Temp graphics are from when the portal was 50 tiles long, so end 1 tile (32 pixels) are chopped off by design and shifted.

local tunnelPortalSurfacePlacement = {
    type = "furnace",
    name = "railway_tunnel-tunnel_portal_surface-placement",
    collision_box = {{-1.9, -24.9}, {1.9, 23.9}},
    tile_height = 2,
    collision_mask = {"item-layer", "object-layer", "player-layer", "water-tile"},
    idle_animation = {
        north = {
            filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-placement-north.png",
            height = 1568,
            width = 128,
            shift = {0, -0.5}
        },
        east = {
            filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-placement-east.png",
            height = 128,
            width = 1568,
            shift = {0.5, 0}
        },
        south = {
            filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-placement-south.png",
            height = 1568,
            width = 128,
            shift = {0, 0.5}
        },
        west = {
            filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-placement-west.png",
            height = 128,
            width = 1568,
            shift = {-0.5, 0}
        }
    },
    crafting_categories = {"crafting"},
    crafting_speed = 1,
    energy_source = {type = "void"},
    energy_usage = "1W",
    result_inventory_size = 0,
    source_inventory_size = 0
}
data:extend({tunnelPortalSurfacePlacement})

local function MakeTunnelPortalSurfacePlaced(direction, orientation)
    local rotatedCollisionBox = Utils.ApplyBoundingBoxToPosition({x = 0, y = 0}, Utils.DeepCopy(tunnelPortalSurfacePlacement.collision_box), orientation)
    local filenameDirection, height, width, tile_height, tile_width, shift
    if direction == "north" or direction == "south" then
        filenameDirection = "northsouth"
        height = 1568
        width = 128
        tile_height = 2
    else
        filenameDirection = "eastwest"
        height = 128
        width = 1568
        tile_width = 2
    end
    if direction == "north" then
        shift = {0, -0.5}
    elseif direction == "south" then
        shift = {0, 0.5}
    elseif direction == "east" then
        shift = {0.5, 0}
    elseif direction == "west" then
        shift = {-0.5, 0}
    end
    data:extend(
        {
            {
                type = "simple-entity",
                name = "railway_tunnel-tunnel_portal_surface-placed-" .. direction,
                collision_box = rotatedCollisionBox,
                tile_height = tile_height,
                tile_width = tile_width,
                collision_mask = tunnelPortalSurfacePlacement.collision_mask,
                selection_box = rotatedCollisionBox,
                picture = {
                    filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-base-" .. filenameDirection .. ".png",
                    height = height,
                    width = width,
                    shift = shift
                },
                render_layer = "ground-tile"
            }
        }
    )
end
MakeTunnelPortalSurfacePlaced("north", 0)
MakeTunnelPortalSurfacePlaced("east", 0.25)
MakeTunnelPortalSurfacePlaced("south", 0.5)
MakeTunnelPortalSurfacePlaced("west", 0.75)

data:extend(
    {
        {
            type = "tile",
            name = "railway_tunnel-tunnel_surface_rail_end_connection_tile",
            collision_mask = {tunnelRailSurfacePlacementCollisionLayer, "ground-tile"},
            needs_correction = false,
            layer = 64,
            map_color = {r = 0, g = 0, b = 0, a = 0},
            pollution_absorption_per_second = 0,
            variants = {
                main = {
                    {
                        picture = "__core__/graphics/editor-selection.png", -- is a 32 pixel white square
                        count = 1,
                        size = 1
                    }
                },
                empty_transitions = true
            },
            can_be_part_of_blueprint = false
        }
    }
)
