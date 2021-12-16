data:extend(
    {
        {
            type = "technology",
            name = "railway_tunnel",
            icon = "__railway_tunnel__/graphics/icon/railway_tunnel.png",
            icon_size = 32,
            effects = {
                {
                    type = "unlock-recipe",
                    recipe = "railway_tunnel-portal_end"
                },
                {
                    type = "unlock-recipe",
                    recipe = "railway_tunnel-portal_segment-straight"
                },
                {
                    type = "unlock-recipe",
                    recipe = "railway_tunnel-underground_segment-straight"
                },
                {
                    type = "unlock-recipe",
                    recipe = "railway_tunnel-underground_segment-straight-rail_crossing"
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
