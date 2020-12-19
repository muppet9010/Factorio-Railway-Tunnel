local Utils = require("utility/utils")

local tunnelPortalSurfacePlacement = {
    type = "furnace",
    name = "railway_tunnel-tunnel_portal_surface-placement",
    collision_box = {{-2, -25}, {2, 25}},
    collision_mask = {"item-layer", "object-layer", "player-layer", "water-tile"},
    idle_animation = data.raw["pump"]["pump"].animations,
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
                    filename = "__base__/graphics/terrain/stone-path/stone-path-4.png",
                    count = 16,
                    size = 4
                }
            }
        }
    )
end
MakeTunnelPortalSurfacePlaced("north", 0)
MakeTunnelPortalSurfacePlaced("east", 0.25)
MakeTunnelPortalSurfacePlaced("south", 0.5)
MakeTunnelPortalSurfacePlaced("west", 0.75)
