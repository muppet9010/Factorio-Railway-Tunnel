local TestManager = {}
local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")

local doDemo = false -- Does the demo rather than any enabled tests.
local doTests = true -- Does the enabled tests below.
local doAllTests = false -- Does all the tests regardless of their enabled state below.

local testsToDo
if doTests then
    testsToDo = {
        shortTunnelShortTrainEastToWest = {enabled = false, testScript = require("tests/short-tunnel-short-train-east-to-west")},
        shortTunnelShortTrainWestToEast = {enabled = false, testScript = require("tests/short-tunnel-short-train-west-to-east")},
        shortTunnelShortTrainNorthToSouth = {enabled = false, testScript = require("tests/short-tunnel-short-train-north-to-south")},
        shortTunnelLongTrainWestToEastCurvedApproach = {enabled = false, testScript = require("tests/short-tunnel-long-train-west-to-east-curved-approach")},
        repathOnApproach = {enabled = false, testScript = require("tests/repath-on-approach")},
        doubleRepathOnApproach = {enabled = false, testScript = require("tests/double-repath-on-approach")},
        pathingKeepReservation = {enabled = false, testScript = require("tests/pathing-keep-reservation")},
        pathingKeepReservationNoGap = {enabled = false, testScript = require("tests/pathing-keep-reservation-no-gap")},
        tunnelInUseNotLeavePortal = {enabled = true, testScript = require("tests/tunnel-in-use-not-leave-portal")},
        tunnelInUseWaitingTrains = {enabled = false, testScript = require("tests/tunnel-in-use-waiting-trains")}
    }
end

TestManager.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("TestManager.RunTests", TestManager.RunTests)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "TestManager.OnPlayerCreated", TestManager.OnPlayerCreated)
end

TestManager.OnStartup = function()
    if ((not doTests) and (not doDemo)) or global.testsRun then
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

    EventScheduler.ScheduleEvent(game.tick + 60, "TestManager.RunTests")
end

TestManager.RunTests = function()
    game.tick_paused = true

    -- Do the demo and not any tests if it is enabled.
    if doDemo then
        testsToDo = {
            demo = {enabled = true, testScript = require("tests/demo")}
        }
    end

    for _, test in pairs(testsToDo) do
        if test.enabled or doAllTests then
            test.testScript.Start(TestManager)
        end
    end
end

TestManager.OnPlayerCreated = function(event)
    if ((not doTests) and (not doDemo)) then
        return
    end
    local player = game.get_player(event.player_index)
    player.exit_cutscene()
    player.set_controller {type = defines.controllers.editor}
end

TestManager.BuildBlueprintFromString = function(blueprintString, position)
    -- Utility function to build a blueprint from a string on the test surface.
    -- Makes sure that trains in the blueprint are properly built, their fuel requests are fulfilled and the trains are set to automatic.
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]
    local player = game.connected_players[1]
    local itemStack = player.cursor_stack

    itemStack.clear()
    if itemStack.import_stack(blueprintString) ~= 0 then
        error "Error importing blueprint string"
    end

    local ghosts =
        itemStack.build_blueprint {
        surface = nauvisSurface,
        force = playerForce,
        position = position,
        by_player = player
    }
    itemStack.clear()

    local pass2Ghosts = {}
    local fuelProxies = {}

    for _, ghost in pairs(ghosts) do
        local r, _, fuelProxy = ghost.silent_revive({raise_revive = true, return_item_request_proxy = true})
        if r == nil then
            -- train ghosts can't be revived before the rail underneath
            -- them, so save failed ghosts for a second pass
            table.insert(pass2Ghosts, ghost)
        end
        if fuelProxy ~= nil then
            table.insert(fuelProxies, fuelProxy)
        end
    end

    for _, ghost in pairs(pass2Ghosts) do
        local r, _, fuelProxy = ghost.silent_revive({raise_revive = true, return_item_request_proxy = true})
        if r == nil then
            error("only 2 rounds of ghost reviving supported")
        end
        if fuelProxy ~= nil then
            table.insert(fuelProxies, fuelProxy)
        end
    end

    for _, fuelProxy in pairs(fuelProxies) do
        for item, count in pairs(fuelProxy.item_requests) do
            fuelProxy.proxy_target.insert({name = item, count = count})
        end
        fuelProxy.destroy()
    end

    for _, train in pairs(nauvisSurface.get_trains()) do
        train.manual_mode = false
    end
end

return TestManager
