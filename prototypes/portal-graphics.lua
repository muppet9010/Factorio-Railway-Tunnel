-- Use render_layer "higher-object-above" on the sprites wanted over the top of train caraiges. Has to be this specific layer to go over artillery wagon's cannons.
-- Use render_layer "lower-object" on the sprites wanted under the train carriages, as the position of the render position is techncially closer to the player and so we need to use a lower render_layer than the carraiges in order to appear behind them.

data:extend(
    {
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-closed_end-0_25",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-closed_end-0_25.png",
            height = 206,
            width = 192,
            shift = {0, -0.8}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-closed_end-0_75",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-closed_end-0_75.png",
            height = 206,
            width = 192,
            shift = {0, -0.8}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-near-0_25",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-near-0_25.png",
            height = 206,
            width = 192,
            shift = {0, -0.8}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-near-0_75",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-near-0_75.png",
            height = 206,
            width = 192,
            shift = {0, -0.8}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-far-0_25",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-far-0_25.png",
            height = 206,
            width = 192,
            shift = {0, -0.8}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-far-0_75",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-far-0_75.png",
            height = 206,
            width = 192,
            shift = {0, -0.8}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-middle-0_25",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-middle-0_25.png",
            height = 206,
            width = 64,
            shift = {0, -0.8}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-middle-0_75",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-middle-0_75.png",
            height = 206,
            width = 64,
            shift = {0, -0.8}
        }
    }
)
