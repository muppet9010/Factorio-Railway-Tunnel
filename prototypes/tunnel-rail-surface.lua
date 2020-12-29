local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local tunnelRailSurfaceCollisionLayer = CollisionMaskUtil.get_first_unused_layer()

THIS NEEDS IMPLIMENTING
-- This needs a placment entity with 2 or 4 orientations.
-- It should have the collision boxes and graphics for the tunnel placement piece on the surface.
-- Once placed it can be checked for valid connection to a portal on one end.
-- It can have the invisible rail and hidden signals added within it. The rails will sit 1 tile within it until another one is placed next to it and then a cross piece of rail will be added. Same with the tunnel portal, being 1 tile longer than its internal rails.
-- FUTURE: Should have a tunnel crossing entity that is fast replaceable with the tunnel placement piece. Would need to be same size as the tunnel track placement entity.

local tunnelRailSurfacePlacement = {
    type = "furnace",
    name = "railway_tunnel-tunnel_rail_surface-placement",
    collision_box = {{-1.9, -1.9}, {1.9, 1.9}},
    collision_mask = {"item-layer", "object-layer", "player-layer", "water-tile"},
    idle_animation = {
        north = {
            filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-placement-northsouth.png",
            height = 128,
            width = 128
        },
        east = {
            filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-placement-eastwest.png",
            height = 128,
            width = 128
        },
        south = {
            filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-placement-northsouth.png",
            height = 128,
            width = 128
        },
        west = {
            filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-placement-eastwest.png",
            height = 128,
            width = 128
        }
    },
    crafting_categories = {"crafting"},
    crafting_speed = 1,
    energy_source = {type = "void"},
    energy_usage = "1W",
    result_inventory_size = 0,
    source_inventory_size = 0
}
data:extend({tunnelRailSurfacePlacement})

local function MakeTunnelRailSurfacePlaced(direction)
    data:extend(
        {
            {
                type = "simple-entity",
                name = "railway_tunnel-tunnel_rail_surface-placed-" .. direction,
                collision_box = tunnelRailSurfacePlacement.collision_box,
                collision_mask = tunnelRailSurfacePlacement.collision_mask,
                selection_box = tunnelRailSurfacePlacement.collision_box,
                picture = {
                    filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-base-" .. direction .. ".png",
                    height = 128,
                    width = 128
                },
                render_layer = "ground-tile"
            }
        }
    )
end
MakeTunnelRailSurfacePlaced("northsouth")
MakeTunnelRailSurfacePlaced("eastwest")
