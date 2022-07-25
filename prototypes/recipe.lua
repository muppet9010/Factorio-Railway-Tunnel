data:extend(
    {
        {
            type = "recipe",
            name = "railway_tunnel-portal_end",
            enabled = false,
            ingredients = {
                {"concrete", 30},
                {"steel-plate", 30},
                {"rail", 3},
                {"rail-signal", 2}
            },
            energy_required = 10,
            result = "railway_tunnel-portal_end",
            result_count = 1
        },
        {
            type = "recipe",
            name = "railway_tunnel-portal_segment-straight",
            enabled = false,
            ingredients = {
                {"concrete", 10},
                {"steel-plate", 10},
                {"rail", 1}
            },
            energy_required = 5,
            result = "railway_tunnel-portal_segment-straight",
            result_count = 1
        },
        {
            type = "recipe",
            name = "railway_tunnel-underground_segment-straight",
            enabled = false,
            ingredients = {
                {"concrete", 10},
                {"steel-plate", 10},
                {"rail", 1}
            },
            energy_required = 5,
            result = "railway_tunnel-underground_segment-straight",
            result_count = 1
        },
        {
            type = "recipe",
            name = "railway_tunnel-underground_segment-straight-rail_crossing",
            enabled = false,
            ingredients = {
                {"rail", 3},
                {"railway_tunnel-underground_segment-straight", 1}
            },
            energy_required = 5,
            result = "railway_tunnel-underground_segment-straight-rail_crossing",
            result_count = 1
        },
        {
            type = "recipe",
            name = "railway_tunnel-underground_segment-straight-tunnel_crossing",
            enabled = false,
            ingredients = {
                {"railway_tunnel-underground_segment-straight", 2}
            },
            energy_required = 5,
            result = "railway_tunnel-underground_segment-straight-tunnel_crossing",
            result_count = 1
        }
    }
)

if settings.startup["railway_tunnel-show_curved_tunnel_parts"].value then
    data:extend(
        {
            {
                type = "recipe",
                name = "railway_tunnel-underground_segment-corner",
                enabled = false,
                ingredients = {
                    {"concrete", 10},
                    {"steel-plate", 10},
                    {"rail", 1}
                },
                energy_required = 5,
                result = "railway_tunnel-underground_segment-corner",
                result_count = 1
            },
            {
                type = "recipe",
                name = "railway_tunnel-underground_segment-curved-regular",
                enabled = false,
                ingredients = {
                    {"concrete", 30},
                    {"steel-plate", 30},
                    {"rail", 3}
                },
                energy_required = 10,
                result = "railway_tunnel-underground_segment-curved-regular",
                result_count = 1
            },
            {
                type = "recipe",
                name = "railway_tunnel-underground_segment-diagonal-regular",
                enabled = false,
                ingredients = {
                    {"concrete", 10},
                    {"steel-plate", 10},
                    {"rail", 1}
                },
                energy_required = 5,
                result = "railway_tunnel-underground_segment-diagonal-regular",
                result_count = 1
            }
        }
    )
end
