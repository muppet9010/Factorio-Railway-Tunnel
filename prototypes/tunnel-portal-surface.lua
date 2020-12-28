local Utils = require("utility/utils")

local tunnelPortalSurfacePlacement = {
    type = "furnace",
    name = "railway_tunnel-tunnel_portal_surface-placement",
    collision_box = {{-1.9, -24.9}, {1.9, 24.9}},
    collision_mask = {"item-layer", "object-layer", "player-layer", "water-tile"},
    idle_animation = {
        north = {
            filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-placement-north.png",
            height = 1600,
            width = 128
        },
        east = {
            filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-placement-east.png",
            height = 128,
            width = 1600
        },
        south = {
            filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-placement-south.png",
            height = 1600,
            width = 128
        },
        west = {
            filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-placement-west.png",
            height = 128,
            width = 1600
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
    local filenameDirection, height, width
    if direction == "north" or direction == "south" then
        filenameDirection = "northsouth"
        height = 1600
        width = 128
    else
        filenameDirection = "eastwest"
        height = 128
        width = 1600
    end
    data:extend(
        {
            {
                type = "simple-entity",
                name = "railway_tunnel-tunnel_portal_surface-placed-" .. direction,
                collision_box = rotatedCollisionBox,
                collision_mask = tunnelPortalSurfacePlacement.collision_mask,
                selection_box = rotatedCollisionBox,
                flags = {},
                picture = {
                    filename = "__railway_tunnel__/graphics/tunnel_portal_surface/tunnel_portal_surface-base-" .. filenameDirection .. ".png",
                    height = height,
                    width = width
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
