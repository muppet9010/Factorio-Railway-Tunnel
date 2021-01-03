local refStraightRail = data.raw["straight-rail"]["straight-rail"]

data:extend(
    {
        {
            type = "straight-rail",
            name = "railway_tunnel-internal_rail-on_map",
            flags = {"not-repairable", "not-blueprintable", "not-deconstructable", "no-copy-paste", "not-upgradable", "player-creation"}, -- We want it to show on the map to help tunnels look better.
            selectable_in_game = false,
            collision_mask = {"rail-layer"}, -- Just collide with other rails.
            pictures = refStraightRail.pictures
        }
    }
)
