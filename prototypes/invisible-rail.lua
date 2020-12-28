local Utils = require("utility/utils")

local MakeEmptyRailImages = function()
    return {
        metals = Utils.EmptyRotatedSprite(),
        backplates = Utils.EmptyRotatedSprite(),
        ties = Utils.EmptyRotatedSprite(),
        stone_path = Utils.EmptyRotatedSprite()
    }
end

data:extend(
    {
        {
            type = "straight-rail",
            name = "railway_tunnel-invisible_rail",
            flags = {"not-repairable", "not-on-map", "not-blueprintable", "not-deconstructable", "no-copy-paste", "not-upgradable"},
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
    }
)
