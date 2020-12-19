local Utils = require("utility/utils")
local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local tunnelPortalCollisionLayer = CollisionMaskUtil.get_first_unused_layer()

local tunnelPortalSurfacePlacement = Utils.DeepCopy(data.raw["train-stop"]["train-stop"])
tunnelPortalSurfacePlacement.name = "railway_tunnel-tunnel_portal_surface_placement"
tunnelPortalSurfacePlacement.collision_box = {{-4, -49}, {0, 1}}
tunnelPortalSurfacePlacement.collision_mask = {"player-layer", tunnelPortalCollisionLayer}
data:extend({tunnelPortalSurfacePlacement})

local function MakeTunnelPortalSurfacePlaced(direction, orientation)
    local rotatedCollisionBox = Utils.ApplyBoundingBoxToPosition({x = 0, y = 0}, Utils.DeepCopy(tunnelPortalSurfacePlacement.collision_box), orientation)
    data:extend(
        {
            {
                type = "simple-entity",
                name = "railway_tunnel-tunnel_portal_surface_placed_" .. direction,
                collision_box = rotatedCollisionBox,
                collision_mask = CollisionMaskUtil.get_default_mask("straight-rail"),
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

-- Add our tunnel portal collision mask to all other things we should conflict with
for _, prototypeTypeName in pairs({"rail-signal", "rail-chain-signal", "loader-1x1", "loader", "splitter", "underground-belt", "transport-belt", "heat-pipe", "land-mine"}) do
    for _, prototype in pairs(data.raw[prototypeTypeName]) do
        local newMask = CollisionMaskUtil.get_mask(prototype)
        CollisionMaskUtil.add_layer(newMask, tunnelPortalCollisionLayer)
        prototype.collision_mask = newMask
    end
end
