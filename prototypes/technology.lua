data:extend(
    {
        {
            type = "technology",
            name = "railway_tunnel",
            icon = "__railway_tunnel__/graphics/icon/tunnel_portal_surface/railway_tunnel-tunnel_portal_surface-placement.png",
            icon_size = 32,
            effects = {
                {
                    type = "unlock-recipe",
                    recipe = "railway_tunnel-tunnel_portal"
                },
                {
                    type = "unlock-recipe",
                    recipe = "railway_tunnel-tunnel_segment"
                },
                {
                    type = "unlock-recipe",
                    recipe = "railway_tunnel-tunnel_segment_rail_crossing"
                }
            },
            prerequisites = {"rail-signals"},
            unit = {
                count = 100,
                ingredients = {
                    {"automation-science-pack", 1},
                    {"logistic-science-pack", 1}
                },
                time = 30
            },
            order = "c-g-d"
        }
    }
)
