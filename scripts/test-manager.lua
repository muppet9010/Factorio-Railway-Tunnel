local TestManager = {}
local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")
local Interfaces = require("utility/interfaces")

-- If tests or demo are done the map is replaced with a test science lab tile world and the tests placed/run.
local DoTests = true -- Does the enabled tests below if TRUE.
local AllTests = false -- Does all the tests regardless of their enabled state below if TRUE.

local PlayerStartingZoom = 0.1 -- Sets players starting zoom level. 1 is default Factorio, 0.1 is a good view for most tests.
local TestGameSpeed = 4 -- The game speed to run the tests at. Default is 1.
local WaitForPlayerAtEndOfEachTest = true -- The game will be paused when each test is completed before the map is cleared if TRUE. Otherwise the tests will run from one to the next.
local DoDemoInsteadOfTests = false -- Does the demo rather than any enabled tests if TRUE.

-- Add any new tests in to the table and set enable true/false as desired.
local TestsToRun
if DoTests then
    TestsToRun = {
        --ShortTunnelShortTrainEastToWest = {enabled = true, testScript = require("tests/short-tunnel-short-train-east-to-west")},
        --ShortTunnelShortTrainNorthToSouth = {enabled = true, testScript = require("tests/short-tunnel-short-train-north-to-south")},
        --ShortTunnelLongTrainWestToEastCurvedApproach = {enabled = true, testScript = require("tests/short-tunnel-long-train-west-to-east-curved-approach")},
        --repathOnApproach = {enabled = true, testScript = require("tests/repath-on-approach")},
        --DoubleRepathOnApproach = {enabled = true, testScript = require("tests/double-repath-on-approach")},
        --PathingKeepReservation = {enabled = true, testScript = require("tests/pathing-keep-reservation")},
        --PathingKeepReservationNoGap = {enabled = true, testScript = require("tests/pathing-keep-reservation-no-gap")},
        --TunnelInUseNotLeavePortalTrackBeforeReturning = {enabled = true, testScript = require("tests/tunnel-in-use-not-leave-portal-track-before-returning.lua")},
        --TunnelInUseWaitingTrains = {enabled = true, testScript = require("tests/tunnel-in-use-waiting-trains")},
        PathfinderWeightings = {enabled = false, testScript = require("tests/pathfinder-weightings")},
        InwardFacingTrain = {enabled = false, testScript = require("tests/inward-facing-train")}
        --InwardFacingTrainBlockedExitLeaveTunnel = {enabled = true, testScript = require("tests/inward-facing-train-blocked-exit-leave-tunnel")},
        --InwardFacingTrainBlockedExitDoesntLeaveTunnel = {enabled = true, testScript = require("tests/inward-facing-train-blocked-exit-doesnt-leave-tunnel")}
        --ForceRepathBackThroughTunnelShortDualEnded = {enabled = false, testScript = require("tests/force-repath-back-through-tunnel-short-dual-ended")},
        --ForceRepathBackThroughTunnelShortSingleEnded = {enabled = false, testScript = require("tests/force-repath-back-through-tunnel-short-single-ended")},
        --ForceRepathBackThroughTunnelLongDualEnded = {enabled = false, testScript = require("tests/force-repath-back-through-tunnel-long-dual-ended")}
        --ForceRepathBackThroughTunnelTests = {enabled = true, testScript = require("tests/force-repath-back-through-tunnel-tests"), multipleTests = true} -- WIP
    }
end

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
--
--                                          DONT CHANGE BELOW HERE WHEN JUST ADDING TESTS
--
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------

if DoDemoInsteadOfTests then
    -- Do just the demo if it is enabled, no tests.
    TestsToRun = {
        demo = {enabled = true, testScript = require("tests/demo")}
    }
end

TestManager.CreateGlobals = function()
    global.testManager = global.testManager or {}
    global.testManager.testProcessStarted = global.testManager.testProcessStarted or false -- Used to flag when a save was started with tests already.
    global.testManager.testSurface = global.testManager.testSurface or nil
    global.testManager.playerForce = global.testManager.playerForce or nil
    global.testManager.testData = global.testManager.testData or {} -- Used by tests to store their local data. Key'd by testName.
    global.testManager.testsToRun = global.testManager.testsToRun or {} -- Holds management state data on the test, but the test scripts always have to be obtained from the TestsToRun local object. Can't store lua functions in global data.
end

TestManager.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("TestManager.RunTests", TestManager.RunTests)
    EventScheduler.RegisterScheduledEventType("TestManager.WaitForPlayerThenRunTests", TestManager.WaitForPlayerThenRunTests)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "TestManager.OnPlayerCreated", TestManager.OnPlayerCreated)
    EventScheduler.RegisterScheduledEventType("TestManager.OnPlayerCreatedMakeCharacter", TestManager.OnPlayerCreatedMakeCharacter)
    Interfaces.RegisterInterface("TestManager.GetTestScript", TestManager.GetTestScript)

    -- Run any active tests OnLoad function.
    for testName, test in pairs(TestsToRun) do
        if (AllTests or test.enabled) and test.testScript.OnLoad ~= nil then
            test.testScript.OnLoad(testName)
        end
    end
end

TestManager.OnStartup = function()
    if not DoTests or global.testManager.testProcessStarted then
        return
    end
    global.testManager.testProcessStarted = true

    global.testManager.testSurface = game.surfaces[1]
    global.testManager.playerForce = game.forces["player"]
    local playerForce = global.testManager.playerForce

    playerForce.character_running_speed_modifier = 10
    playerForce.character_build_distance_bonus = 100
    playerForce.character_reach_distance_bonus = 100

    local testSurface = global.testManager.testSurface
    testSurface.generate_with_lab_tiles = true
    testSurface.always_day = true
    testSurface.freeze_daytime = true
    testSurface.show_clouds = false

    for chunk in testSurface.get_chunks() do
        testSurface.delete_chunk({x = chunk.x, y = chunk.y})
    end

    game.speed = TestGameSpeed
    Utils.SetStartingMapReveal(500) --Generate tiles around spawn, needed for blueprints to be placed in this area.

    -- Create the global test management state data. Lua script funcctions can't be included in to global object.
    for testName, test in pairs(TestsToRun) do
        global.testManager.testsToRun[testName] = {
            enabled = test.enabled,
            runTime = test.testScript.Runtime,
            started = false,
            finished = false,
            success = nil
        }
    end

    EventScheduler.ScheduleEventOnce(game.tick + 120, "TestManager.WaitForPlayerThenRunTests", nil, {firstLoad = true}) -- Have to give it time to chart the revealed area.
end

TestManager.WaitForPlayerThenRunTests = function(event)
    if event.data.firstLoad then
        for _, player in pairs(game.connected_players) do
            player.zoom = PlayerStartingZoom
        end
    end

    local currentTestName = event.data.currentTestName -- Only populated if this event was scheduled with the tests RunTime attribute.
    if currentTestName ~= nil then
        TestManager.GetTestScript(currentTestName).Stop(currentTestName)
        game.print("Test NOT Completed:" .. currentTestName, {1, 0, 0, 1})
        local testObject = global.testManager.testsToRun[currentTestName]
        testObject.finished = true
        testObject.success = false
        game.tick_paused = true
        return
    end
    if WaitForPlayerAtEndOfEachTest then
        if event.data.firstLoad then
            game.print("Testing started paused in editor mode - will pause at the end of each test")
        end
        game.tick_paused = true
        EventScheduler.ScheduleEventOnce(game.tick + 1, "TestManager.RunTests")
    else
        TestManager.RunTests()
    end
end

TestManager.RunTests = function()
    -- Clean any previous entities off the map. Run twice to catch any rails with trains on them that get missed first attempt.
    for i = 1, 2 do
        for _, entity in pairs(global.testManager.testSurface.find_entities()) do
            entity.destroy({raise_destroy = true})
        end
    end

    -- Clear any previous console messages to make it easy to track each test.
    for _, player in pairs(game.connected_players) do
        player.clear_console()
    end

    for testName, test in pairs(global.testManager.testsToRun) do
        if (test.enabled or AllTests) and not test.started then
            game.print("Starting Test:   " .. testName)
            global.testManager.testData[testName] = {}
            TestManager.GetTestScript(testName).Start(testName)
            test.started = true
            if test.runTime ~= nil then
                EventScheduler.ScheduleEventOnce(game.tick + test.runTime, "TestManager.WaitForPlayerThenRunTests", nil, {currentTestName = testName})
            end
            global.testManager.playerForce.chart_all(global.testManager.testSurface)
            return
        end
    end

    game.print("All Tests Done", {0, 0, 1, 1})
end

TestManager.OnPlayerCreated = function(event)
    if not DoTests then
        return
    end
    local player = game.get_player(event.player_index)
    if player.controller_type == defines.controllers.cutscene then
        player.exit_cutscene()
    end

    TestManager.OnPlayerCreatedMakeCharacter({instanceId = player.index})
end

TestManager.OnPlayerCreatedMakeCharacter = function(event)
    -- Add a character since it was lost in surface destruction. Then go to Map Editor, that way if we leave map editor we have a character to return to.
    local player = game.get_player(event.instanceId)
    if player.character == nil then
        local characterCreated = player.create_character()
        if characterCreated == false then
            -- Character can't create yet, try again later.
            EventScheduler.ScheduleEventOnce(game.tick + 1, "TestManager.OnPlayerCreatedMakeCharacter", player.index)
            return
        end
    end
    local tickWasPaused = game.tick_paused
    player.toggle_map_editor()
    game.tick_paused = tickWasPaused
end

-- Called when the test script needs to be referenced as it can't be stored in global data.
TestManager.GetTestScript = function(testName)
    return TestsToRun[testName].testScript
end

return TestManager
