-- Use render_layer "higher-object-above" on the sprites wanted over the top of train caraiges. Has to be this specific layer to go over artillery wagon's cannons.
-- Use render_layer "lower-object" on the sprites wanted under the train carriages, as the position of the render position is techncially closer to the player and so we need to use a lower render_layer than the carriages in order to appear behind them.

-- East Images 0.25
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
            name = "railway_tunnel-portal_graphics-portal_complete-closed_end-shadow-0_25",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-closed_end-shadow-0_25.png",
            height = 206,
            width = 192,
            shift = {0, -0.8},
            draw_as_shadow = true
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
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-far-0_25",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-far-0_25.png",
            height = 206,
            width = 192,
            shift = {0, -0.8}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-shadow-near-0_25",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-shadow-near-0_25.png",
            height = 206,
            width = 192,
            shift = {0, -0.8},
            draw_as_shadow = true
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-shadow-far-0_25",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-shadow-far-0_25.png",
            height = 206,
            width = 192,
            shift = {0, -0.8},
            draw_as_shadow = true
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
            name = "railway_tunnel-portal_graphics-portal_complete-middle-shadow-0_25",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-middle-shadow-0_25.png",
            height = 206,
            width = 194,
            shift = {0, -0.8},
            draw_as_shadow = true
        }
    }
)

-- West Images 0.75
data:extend(
    {
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
            name = "railway_tunnel-portal_graphics-portal_complete-closed_end-shadow-0_75",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-closed_end-shadow-0_75.png",
            height = 206,
            width = 327,
            shift = {0, -0.8},
            draw_as_shadow = true
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
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-far-0_75",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-far-0_75.png",
            height = 206,
            width = 192,
            shift = {0, -0.8}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-shadow-near-0_75",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-shadow-near-0_75.png",
            height = 206,
            width = 323,
            shift = {0, -0.8},
            draw_as_shadow = true
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-shadow-far-0_75",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-shadow-far-0_75.png",
            height = 206,
            width = 323,
            shift = {0, -0.8},
            draw_as_shadow = true
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-middle-0_75",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-middle-0_75.png",
            height = 206,
            width = 64,
            shift = {0, -0.8}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-middle-shadow-0_75",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-middle-shadow-0_75.png",
            height = 206,
            width = 194,
            shift = {0, -0.8},
            draw_as_shadow = true
        }
    }
)

-- North Images 0.0
data:extend(
    {
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-closed_end-0_0",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-closed_end-0_0.png",
            height = 192,
            width = 128,
            shift = {0, 0}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-closed_end-shadow-0_0",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-closed_end-shadow-0_0.png",
            height = 268,
            width = 258,
            shift = {0, 0},
            draw_as_shadow = true
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-near-0_0",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-near-0_0.png",
            height = 160,
            width = 128,
            shift = {0, -1}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-far-0_0",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-far-0_0.png",
            height = 160,
            width = 128,
            shift = {0, -1}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-shadow-near-0_0",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-shadow-near-0_0.png",
            height = 364,
            width = 258,
            shift = {0, -1},
            draw_as_shadow = true
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-shadow-far-0_0",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-shadow-far-0_0.png",
            height = 364,
            width = 258,
            shift = {0, -1},
            draw_as_shadow = true
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-middle-0_0",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-middle-0_0.png",
            height = 128,
            width = 128,
            shift = {0, -1}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-middle-shadow-0_0",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-middle-shadow-0_0.png",
            height = 202,
            width = 258,
            shift = {0, -1},
            draw_as_shadow = true
        }
    }
)

-- South Images 0.5
data:extend(
    {
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-closed_end-0_50",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-closed_end-0_50.png",
            height = 256,
            width = 128,
            shift = {0, -1}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-closed_end-shadow-0_50",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-closed_end-shadow-0_50.png",
            height = 256,
            width = 258,
            shift = {0, -1},
            draw_as_shadow = true
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-near-0_50",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-near-0_50.png",
            height = 256,
            width = 128,
            shift = {0, -1}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-far-0_50",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-far-0_50.png",
            height = 256,
            width = 128,
            shift = {0, -1}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-shadow-near-0_50",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-shadow-near-0_50.png",
            height = 268,
            width = 258,
            shift = {0, -1},
            draw_as_shadow = true
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-open_end-shadow-far-0_50",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-open_end-shadow-far-0_50.png",
            height = 268,
            width = 258,
            shift = {0, -1},
            draw_as_shadow = true
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-middle-0_50",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-middle-0_50.png",
            height = 128,
            width = 128,
            shift = {0, -1}
        },
        {
            type = "sprite",
            name = "railway_tunnel-portal_graphics-portal_complete-middle-shadow-0_50",
            filename = "__railway_tunnel__/graphics/entity/portal_complete/portal_complete-middle-shadow-0_50.png",
            height = 202,
            width = 258,
            shift = {0, -1},
            draw_as_shadow = true
        }
    }
)
