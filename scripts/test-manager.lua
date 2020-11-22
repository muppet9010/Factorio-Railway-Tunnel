local TestManager = {}
local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")

local doTests = true
local testsToDo = {
    tunnelSingleLoco = {enabled = true, testScript = require("tests/tunnel-single-loco")},
    surfaceSingleLoop = {enabled = true, testScript = require("tests/surface-single-loop")},
    surfaceMiddleLine = {enabled = true, testScript = require("tests/surface-middle-line")}
}

TestManager.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("TestManager.RunTests", TestManager.RunTests)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "TestManager.OnPlayerCreated", TestManager.OnPlayerCreated)
end

TestManager.OnStartup = function()
    if not doTests then
        return
    end

    local nauvisSurface = game.surfaces[1]
    nauvisSurface.generate_with_lab_tiles = true
    nauvisSurface.always_day = true
    nauvisSurface.freeze_daytime = true
    nauvisSurface.show_clouds = false

    for chunk in nauvisSurface.get_chunks() do
        nauvisSurface.delete_chunk({x = chunk.x, y = chunk.y})
    end

    EventScheduler.ScheduleEvent(game.tick + 30, "TestManager.RunTests")
end

TestManager.RunTests = function()
    game.tick_paused = true
    for _, test in pairs(testsToDo) do
        if test.enabled then
            test.testScript.Start()
        end
    end
end

TestManager.OnPlayerCreated = function(event)
    if not doTests then
        return
    end
    local player = game.get_player(event.player_index)
    player.exit_cutscene()
    player.set_controller {type = defines.controllers.editor}
end

return TestManager
