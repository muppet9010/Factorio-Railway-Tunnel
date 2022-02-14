data:extend(
    {
        {
            type = "container",
            name = "railway_tunnel-tunnel_fuel_chest",
            icons = {
                {
                    icon = "__base__/graphics/icons/wooden-chest.png",
                    icon_size = 64,
                    icon_mipmaps = 4,
                    scale = 1
                },
                {
                    icon = "__base__/graphics/icons/locomotive.png",
                    icon_size = 64,
                    icon_mipmaps = 4,
                    scale = 0.75
                }
            },
            flags = {"not-deconstructable", "not-upgradable", "not-blueprintable", "placeable-off-grid", "not-selectable-in-game"},
            subgroup = "railway_tunnel-tunnel_bits",
            collision_box = nil,
            collision_mask = {},
            inventory_size = 10,
            picture = {
                layers = {
                    {
                        filename = "__base__/graphics/icons/wooden-chest.png",
                        size = 64
                    },
                    {
                        filename = "__base__/graphics/icons/locomotive.png",
                        size = 64,
                        scale = 0.75
                    }
                }
            }
        }
    }
)
