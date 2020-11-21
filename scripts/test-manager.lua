local TestManager = {}
local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")

local doTests = true
local testsToDo = {
    singleLoco = {enabled = true, testScript = require("tests/single-loco")}
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

    EventScheduler.ScheduleEvent(game.tick + 1, "TestManager.RunTests")
end

TestManager.RunTests = function()
    -- Only supports doing 1 test per run.
    game.tick_paused = true
    for testName, test in pairs(testsToDo) do
        if test.enabled then
            game.print("Doing Test: " .. testName)
            test.testScript.Start()
            return
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
