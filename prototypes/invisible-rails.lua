local Utils = require("utility.utils")
local CommonPrototypeFunctions = require("prototypes.common-prototype-functions")

local MakeEmptyRailImages = function()
    return {
        metals = Utils.EmptyRotatedSprite(),
        backplates = Utils.EmptyRotatedSprite(),
        ties = Utils.EmptyRotatedSprite(),
        stone_path = Utils.EmptyRotatedSprite()
    }
end

local invisibleStraightRailBase = {
    type = "straight-rail",
    icon = "__base__/graphics/icons/rail.png",
    icon_size = 64,
    icon_mipmaps = 4,
    subgroup = "railway_tunnel-hidden_rails",
    flags = {"not-repairable", "not-blueprintable", "not-deconstructable", "no-copy-paste", "not-upgradable", "building-direction-8-way"},
    selectable_in_game = false,
    collision_mask = {"rail-layer"}, -- Just collide with other rails.
    pictures = {
        straight_rail_horizontal = MakeEmptyRailImages(),
        straight_rail_vertical = MakeEmptyRailImages(),
        straight_rail_diagonal_left_top = MakeEmptyRailImages(),
        straight_rail_diagonal_right_top = MakeEmptyRailImages(),
        straight_rail_diagonal_right_bottom = MakeEmptyRailImages(),
        straight_rail_diagonal_left_bottom = MakeEmptyRailImages(),
        curved_rail_vertical_left_top = MakeEmptyRailImages(),
        curved_rail_vertical_right_top = MakeEmptyRailImages(),
        curved_rail_vertical_right_bottom = MakeEmptyRailImages(),
        curved_rail_vertical_left_bottom = MakeEmptyRailImages(),
        curved_rail_horizontal_left_top = MakeEmptyRailImages(),
        curved_rail_horizontal_right_top = MakeEmptyRailImages(),
        curved_rail_horizontal_right_bottom = MakeEmptyRailImages(),
        curved_rail_horizontal_left_bottom = MakeEmptyRailImages(),
        rail_endings = {
            north = Utils.EmptyRotatedSprite(),
            north_east = Utils.EmptyRotatedSprite(),
            east = Utils.EmptyRotatedSprite(),
            south_east = Utils.EmptyRotatedSprite(),
            south = Utils.EmptyRotatedSprite(),
            south_west = Utils.EmptyRotatedSprite(),
            west = Utils.EmptyRotatedSprite(),
            north_west = Utils.EmptyRotatedSprite()
        }
    }
}

-- Used for the non-entry parts of tunnel portals and for underground tunnel tracks.
local invisibleStraightRailOnMapTunnel = Utils.DeepCopy(invisibleStraightRailBase)
invisibleStraightRailOnMapTunnel.name = "railway_tunnel-invisible_rail-straight-on_map_tunnel"
invisibleStraightRailOnMapTunnel.map_color = CommonPrototypeFunctions.TunnelMapColor

local invisibleCurvedRailBase = Utils.DeepCopy(invisibleStraightRailBase)
invisibleCurvedRailBase.type = "curved-rail"
invisibleCurvedRailBase.icon = "__base__/graphics/icons/curved-rail.png"

-- Used for the non-entry parts of tunnel portals and for underground tunnel tracks.
local invisibleCurvedRailOnMapTunnel = Utils.DeepCopy(invisibleCurvedRailBase)
invisibleCurvedRailOnMapTunnel.name = "railway_tunnel-invisible_rail-curved-on_map_tunnel"
invisibleCurvedRailOnMapTunnel.map_color = CommonPrototypeFunctions.TunnelMapColor

data:extend(
    {
        invisibleStraightRailOnMapTunnel,
        invisibleCurvedRailOnMapTunnel
    }
)
