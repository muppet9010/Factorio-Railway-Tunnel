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
        },
        -- Press the flip blueprint horizontally key (F).
        {
            type = "custom-input",
            name = "railway_tunnel-flip_blueprint_horizontal",
            key_sequence = "",
            linked_game_control = "flip-blueprint-horizontal",
            action = "lua",
            include_selected_prototype = true
        },
        -- Press the flip blueprint vertically key (G).
        {
            type = "custom-input",
            name = "railway_tunnel-flip_blueprint_vertical",
            key_sequence = "",
            linked_game_control = "flip-blueprint-vertical",
            action = "lua",
            include_selected_prototype = true
        },
        -- Use the smart-pipette (Q).
        {
            type = "custom-input",
            name = "railway_tunnel-smart_pipette",
            key_sequence = "",
            linked_game_control = "smart-pipette",
            action = "lua",
            include_selected_prototype = true
        }
    }
)
