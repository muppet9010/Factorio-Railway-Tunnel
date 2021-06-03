data:extend(
    {
        {
            type = "recipe",
            name = "railway_tunnel-tunnel_portal",
            enabled = false,
            ingredients = {
                {"concrete", 200},
                {"steel-plate", 200},
                {"rail", 25},
                {"rail-signal", 2}
            },
            result = "railway_tunnel-tunnel_portal_surface-placement",
            result_count = 1
        },
        {
            type = "recipe",
            name = "railway_tunnel-tunnel_segment",
            enabled = false,
            ingredients = {
                {"concrete", 10},
                {"steel-plate", 10},
                {"rail", 1}
            },
            result = "railway_tunnel-tunnel_segment_surface-placement",
            result_count = 1
        },
        {
            type = "recipe",
            name = "railway_tunnel-tunnel_segment_rail_crossing",
            enabled = false,
            ingredients = {
                {"concrete", 10},
                {"rail", 3},
                {"railway_tunnel-tunnel_segment_surface-placement", 1}
            },
            result = "railway_tunnel-tunnel_segment_surface_rail_crossing-placement",
            result_count = 1
        }
    }
)
