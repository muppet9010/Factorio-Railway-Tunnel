data:extend(
    {
        -- Press key to get in/out of vehicle
        {
            type = "custom-input",
            name = "railway_tunnel-toggle_driving",
            key_sequence = "",
            linked_game_control = "toggle-driving",
            action = "lua"
        },
        -- Left click on an entity to try and open its gui.
        {
            type = "custom-input",
            name = "railway_tunnel-open_gui",
            key_sequence = "",
            linked_game_control = "open-gui",
            action = "lua",
            include_selected_prototype = true
        }
    }
)
