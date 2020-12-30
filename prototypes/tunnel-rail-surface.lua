local Utils = require("utility/utils")

-- This needs a placment entity with 2 or 4 orientations.
-- It should have the collision boxes and graphics for the tunnel placement piece on the surface.
-- It will have the invisible rail and hidden signals added within it once the tunnel is confrimed end to end. The rails will sit 1 tile over its edge when added, same with the tunnel portal.
-- FUTURE: Should have a tunnel crossing entity that is fast replaceable with the tunnel placement piece. Would need to be same size as the tunnel track placement entity.

local tunnelRailSurfacePlacement = {
    type = "furnace",
    name = "railway_tunnel-tunnel_rail_surface-placement",
    collision_box = {{-2.9, -0.9}, {2.9, 0.9}},
    collision_mask = {"item-layer", "object-layer", "water-tile"},
    idle_animation = {
        north = {
            filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-placement-northsouth.png",
            height = 64,
            width = 192
        },
        east = {
            filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-placement-eastwest.png",
            height = 192,
            width = 64
        },
        south = {
            filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-placement-northsouth.png",
            height = 64,
            width = 192
        },
        west = {
            filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-placement-eastwest.png",
            height = 192,
            width = 64
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

local function MakeTunnelRailSurfacePlaced(alignment, orientation)
    local rotatedCollisionBox = Utils.ApplyBoundingBoxToPosition({x = 0, y = 0}, Utils.DeepCopy(tunnelRailSurfacePlacement.collision_box), orientation)
    local height, width
    if alignment == "northsouth" then
        height = 64
        width = 192
    else
        height = 192
        width = 64
    end
    data:extend(
        {
            {
                type = "simple-entity",
                name = "railway_tunnel-tunnel_rail_surface-placed-" .. alignment,
                collision_box = rotatedCollisionBox,
                collision_mask = tunnelRailSurfacePlacement.collision_mask,
                selection_box = rotatedCollisionBox,
                picture = {
                    filename = "__railway_tunnel__/graphics/tunnel_rail_surface/tunnel_rail_surface-base-" .. alignment .. ".png",
                    height = height,
                    width = width
                },
                render_layer = "ground-tile"
            }
        }
    )
end
MakeTunnelRailSurfacePlaced("northsouth", 0)
MakeTunnelRailSurfacePlaced("eastwest", 0.25)
