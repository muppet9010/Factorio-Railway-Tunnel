data:extend(
    {
        {
            type = "custom-input",
            name = "railway_tunnel-toggle_driving",
            key_sequence = "",
            linked_game_control = "toggle-driving",
            consuming = "game-only", -- Intercept the request to get out of a vehicle as then we can check if it works or not as we add edge cases that need to be handled.
            action = "lua"
        }
    }
)
