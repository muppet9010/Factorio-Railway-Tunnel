data:extend(
    {
        {
            type = "custom-input",
            name = "railway_tunnel-toggle_driving",
            key_sequence = "",
            linked_game_control = "toggle-driving",
            consuming = "game-only", -- Intercept the request so base game doesn't get it.
            action = "lua"
        }
    }
)
