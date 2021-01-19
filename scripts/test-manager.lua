local TestManager = {}
local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")

local doTests = true

local testsToDo
if doTests then
    testsToDo = {
        demo = {enabled = false, testScript = require("tests/demo")},
        shortTunnelShortTrainEastToWest = {enabled = true, testScript = require("tests/short-tunnel-short-train-east-to-west")},
        shortTunnelShortTrainEastToWest2Tunnels = {enabled = true, testScript = require("tests/short-tunnel-short-train-east-to-west-2-tunnels")},
        shortTunnelShortTrainWestToEast = {enabled = true, testScript = require("tests/short-tunnel-short-train-west-to-east")},
        shortTunnelShortTrainNorthToSouth = {enabled = true, testScript = require("tests/short-tunnel-short-train-north-to-south")},
        shortTunnelShortTrainNorthToSouth2Tunnels = {enabled = true, testScript = require("tests/short-tunnel-short-train-north-to-south-2-tunnels")},
        shortTunnelLongTrainWestToEastCurvedApproach = {enabled = true, testScript = require("tests/short-tunnel-long-train-west-to-east-curved-approach")}
    }
end

TestManager.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("TestManager.RunTests", TestManager.RunTests)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "TestManager.OnPlayerCreated", TestManager.OnPlayerCreated)
end

TestManager.OnStartup = function()
    if not doTests or global.testsRun then
        return
    end
    global.testsRun = true

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
