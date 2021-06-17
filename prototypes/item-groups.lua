data:extend(
    {
        {
            type = "item-group",
            name = "railway_tunnel-hidden",
            order = "zzzzzzz",
            icons = {
                {
                    icon = "__railway_tunnel__/graphics/icon/tunnel_portal_surface/railway_tunnel-tunnel_portal_surface-placement.png",
                    icon_size = 32
                },
                {
                    icon = "__core__/graphics/no-recipe.png",
                    icon_size = 101,
                    scale = 0.3
                }
            }
        },
        {
            type = "item-subgroup",
            name = "railway_tunnel-hidden_locomotives",
            group = "railway_tunnel-hidden",
            order = "a"
        },
        {
            type = "item-subgroup",
            name = "railway_tunnel-hidden_rails",
            group = "railway_tunnel-hidden",
            order = "b"
        },
        {
            type = "item-subgroup",
            name = "railway_tunnel-hidden_rail_signals",
            group = "railway_tunnel-hidden",
            order = "c"
        },
        {
            type = "item-subgroup",
            name = "railway_tunnel-hidden_cars",
            group = "railway_tunnel-hidden",
            order = "d"
        },
        {
            type = "item-subgroup",
            name = "railway_tunnel-hidden_placement_tests",
            group = "railway_tunnel-hidden",
            order = "e"
        },
        {
            type = "item-subgroup",
            name = "railway_tunnel-train_blockers",
            group = "railway_tunnel-hidden",
            order = "f"
        },
        {
            type = "item-subgroup",
            name = "railway_tunnel-other",
            group = "railway_tunnel-hidden",
            order = "z"
        }
    }
)
