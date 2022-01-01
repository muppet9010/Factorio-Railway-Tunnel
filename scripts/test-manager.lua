--[[
    Notes
    -------------
        - Tests don't load if a dedicated server makes the game and saves the map, then loads the save to run the game. It must be created by the player, saved and then uploaded to the server for running tests in MP.
--]]
local TestManager = {}
local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")
local Interfaces = require("utility/interfaces")
local Colors = require("utility/colors")

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
--
--                                          TESTING OPTIONS CONFIGURATION
--
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------

-- If DoTests is enabled the map is replaced with a test science lab tile world and the tests placed and run. Otherwise the testing framework is disabled and the world unchanged.
local DoTests = true -- Enable test mode and does the enabled tests below if TRUE.
local AllTests = false -- Does all the tests regardless of their enabled state below if TRUE.
local ForceTestsFullSuite = false -- If true each test will do their full range, ignoring the tests "DoMinimalTests" setting. If false then each test just will honour their other settings.

local WaitForPlayerAtEndOfEachTest = false -- The game will be paused when each test is completed before the map is cleared if TRUE. Otherwise the tests will run from one to the next. On a test erroring the map will still pause regardless of this setting.
local JustLogAllTests = false -- Rather than stopping at a failed test, run all tests and log the output to script-output folder. No pausing will ever occur between tests if enabled, even for failures.

local PlayerStartingZoom = 0.1 -- Sets players starting zoom level. 1 is default Factorio, 0.1 is a good view for most tests.
local TestGameSpeed = 1 -- The game speed to run the tests at. Default is 1.
local ContinueTestAfterCompletionSeconds = 3 -- How many seconds each test continues to run after it successfully completes before the next one starts. Intended to make sure the mod has reached a stable state in each test. nil, 0 or greater
local KeepRunningTest = false -- If enabled the first test run will not stop when successfully completed. Intended for benchmarking or demo loops.

-- Add any new tests in to the table; set "enabled" true/false and the "testScript" path.
local TestsToRun = {
    ShortTunnelSingleLocoEastToWest = {enabled = false, testScript = require("tests/short-tunnel-single-loco-east-to-west")},
    --ShortTunnelShortTrainEastToWestWithPlayerRides = {enabled = false, testScript = require("tests/short-tunnel-short-train-east-to-west-with-player-rides")}, -- Player container not done yet.
    --ShortTunnelShortTrainNorthToSouthWithPlayerRides = {enabled = false, testScript = require("tests/short-tunnel-short-train-north-to-south-with-player-rides")}, -- Player container not done yet.
    repathOnApproach = {enabled = false, testScript = require("tests/repath-on-approach")},
    DoubleRepathOnApproach = {enabled = false, testScript = require("tests/double-repath-on-approach")},
    PathingKeepReservation = {enabled = false, testScript = require("tests/pathing-keep-reservation")},
    PathingKeepReservationNoGap = {enabled = false, testScript = require("tests/pathing-keep-reservation-no-gap")},
    TunnelInUseNotLeavePortalTrackBeforeReturning = {enabled = false, testScript = require("tests/tunnel-in-use-not-leave-portal-track-before-returning.lua")},
    --TunnelInUseWaitingTrains = {enabled = false, testScript = require("tests/tunnel-in-use-waiting-trains")} -- hits known issue where tunnel signals have 1 tick open at transition point.
    --PathfinderWeightings = {enabled = false, testScript = require("tests/pathfinder-weightings")}, -- hits known issue where tunnel signals have 1 tick open at transition point.
    InwardFacingTrainBlockedExitLeaveTunnel = {enabled = false, testScript = require("tests/inward-facing-train-blocked-exit-leave-tunnel")},
    PostExitSignalBlockedExitRailSegmentsLongTrain = {enabled = false, testScript = require("tests/post-exit-signal-blocked-exit-rail-segments-long-train")},
    PostExitMultipleStationsWhenInTunnelLongTrain = {enabled = false, testScript = require("tests/post-exit-multiple-stations-when-in-tunnel-long-train")},
    PathToRail = {enabled = false, testScript = require("tests/path-to-rail")},
    TrainCoastingToTunnel = {enabled = false, testScript = require("tests/train-coasting-to-tunnel")},
    --ForceRepathBackThroughTunnelTests = {enabled = false, testScript = require("tests/force-repath-back-through-tunnel-tests")} -- DONT USE - test needs major overhaul as was designed for complex logic we don;t have to handle any more.
    --MineDestroyTunnelTests = {enabled = false, testScript = require("tests/mine-destroy-tunnel-tests")}, -- DONT USE - test needs updating to new tunnel logic.
    PathToTunnelRailTests = {enabled = true, testScript = require("tests/path-to-tunnel-rail-tests")}
    --RemoveTargetStopRail = {enabled = false, testScript = require("tests/remove-target-stop-rail")} -- DONT USE - test needs updating to new tunnel logic.
    --RunOutOfFuelTests = {enabled = false, testScript = require("tests/run-out-of-fuel-tests")}, -- DONT USE - this logic doesn't exist any more
    --ChangeTrainOrders = {enabled = false, testScript = require("tests/change-train-orders")} -- DONT USE - test needs updating to new tunnel logic.
}

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

---@class Test
---@field testName TestName
---@field enabled boolean
---@field notInAllTests boolean
---@field runTime Tick
---@field runLoopsMax uint
---@field runLoopsCount uint
---@field finished boolean
---@field success boolean

---@class TestName:string

---@alias TestData table

TestManager.CreateGlobals = function()
    global.testManager = global.testManager or {}
    global.testManager.testProcessStarted = global.testManager.testProcessStarted or false ---@type boolean @ Used to flag when a save was started with tests already.
    global.testManager.testSurface = global.testManager.testSurface or nil ---@type LuaSurface
    global.testManager.playerForce = global.testManager.playerForce or nil ---@type LuaForce
    global.testManager.testData = global.testManager.testData or {} ---@type table<TestName, TestData> @ Used by tests to store their local data.
    global.testManager.testsToRun = global.testManager.testsToRun or {} ---@type table<TestName, Test> @ Holds management state data on the test, but the test scripts always have to be obtained from the TestsToRun local object. Can't store lua functions in global data.
    global.testManager.justLogAllTests = JustLogAllTests ---@type boolean
    global.testManager.keepRunningTest = KeepRunningTest ---@type boolean
    global.testManager.continueTestAfterCompletioTicks = (ContinueTestAfterCompletionSeconds or 0) * 60 ---@type Tick
    global.testManager.forceTestsFullSuite = ForceTestsFullSuite ---@type boolean
end

TestManager.OnLoad = function()
    if not DoTests then
        return
    end
    EventScheduler.RegisterScheduledEventType("TestManager.RunTests", TestManager.RunTests)
    EventScheduler.RegisterScheduledEventType("TestManager.WaitForPlayerThenRunTests", TestManager.WaitForPlayerThenRunTests)
    EventScheduler.RegisterScheduledEventType("TestManager.ClearMap", TestManager.ClearMap)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "TestManager.OnPlayerCreated", TestManager.OnPlayerCreated)
    EventScheduler.RegisterScheduledEventType("TestManager.OnPlayerCreatedMakeCharacter", TestManager.OnPlayerCreatedMakeCharacter)
    Interfaces.RegisterInterface("TestManager.GetTestScript", TestManager.GetTestScript)
    Interfaces.RegisterInterface("TestManager.LogTestOutcome", TestManager.LogTestOutcome)

    -- Run any active tests OnLoad function.
    for testName, test in pairs(TestsToRun) do
        if ((AllTests and not test.notInAllTests) or test.enabled) and test.testScript.OnLoad ~= nil then
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
        if test.enabled or (AllTests and not test.notInAllTests) then
            global.testManager.testsToRun[testName] = {
                testName = testName,
                enabled = test.enabled,
                notInAllTests = test.notInAllTests,
                runTime = test.testScript.RunTime,
                runLoopsMax = test.testScript.RunLoopsMax or 1,
                runLoopsCount = 0,
                finished = false,
                success = nil
            }
        end
    end

    -- If logging tests clear out any old file.
    if global.testManager.justLogAllTests then
        game.write_file("RailwayTunnel_Tests.txt", "", false)
        WaitForPlayerAtEndOfEachTest = false -- We don't want to pause in this mode.
    end

    if not Utils.IsTableEmpty(global.testManager.testsToRun) then
        -- Only if there are tests do we need to start this loop. Otherwise test world setup is complete.
        EventScheduler.ScheduleEventOnce(game.tick + 120, "TestManager.WaitForPlayerThenRunTests", nil, {firstLoad = true}) -- Have to give it time to chart the revealed area.
    end
end

---@param event ScheduledEvent
TestManager.WaitForPlayerThenRunTests = function(event)
    local currentTestName = event.data.currentTestName -- Only populated if this event was scheduled with the tests RunTime attribute.
    if currentTestName ~= nil then
        TestManager.GetTestScript(currentTestName).Stop(currentTestName)
        game.print("Test NOT Completed: " .. TestManager.GetTestDisplayName(currentTestName), Colors.red)
        TestManager.LogTestOutcome("Test NOT Completed")
        local testObject = global.testManager.testsToRun[currentTestName]
        if not global.testManager.justLogAllTests then
            testObject.finished = true
            testObject.success = false
            game.tick_paused = true
            return
        end
    end
    if WaitForPlayerAtEndOfEachTest or event.data.firstLoad then
        if event.data.firstLoad then
            if WaitForPlayerAtEndOfEachTest then
                game.print("Testing started paused in editor mode - will pause at the end of each test")
            else
                game.print("Testing started paused in editor mode")
            end
        end
        game.tick_paused = true
        EventScheduler.ScheduleEventOnce(game.tick + 1, "TestManager.ClearMap")
    else
        TestManager.ClearMap()
    end
end

TestManager.ClearMap = function()
    -- Clean any previous entities off the map. Remove any trains first and then everything else; to avoid triggering tunnel removal destroying trains alerts.
    for _, entityTypeFilter in pairs({{"cargo-wagon", "locomotive", "fluid-wagon"}, {}}) do
        for _, entity in pairs(global.testManager.testSurface.find_entities_filtered({name = entityTypeFilter})) do
            entity.destroy({raise_destroy = true})
        end
    end

    -- Clear any previous console messages to make it easy to track each test.
    for _, player in pairs(game.connected_players) do
        player.clear_console()
    end

    -- Wait 1 tick so any end of tick mod events from the mpa clearing are raised and ignored, before we start the next test.
    EventScheduler.ScheduleEventOnce(game.tick + 1, "TestManager.RunTests")
end

TestManager.RunTests = function()
    for testName, test in pairs(global.testManager.testsToRun) do
        if ((AllTests and not test.notInAllTests) or test.enabled) and test.runLoopsCount < test.runLoopsMax then
            TestManager.PrepPlayersForNextTest()
            test.runLoopsCount = test.runLoopsCount + 1
            game.print("Starting Test:   " .. TestManager.GetTestDisplayName(testName), Colors.cyan)
            if global.testManager.justLogAllTests then
                game.write_file("RailwayTunnel_Tests.txt", TestManager.GetTestDisplayName(testName) .. "   =   ", true)
            end
            global.testManager.testData[testName] = {} -- Reset for every test run as this is the test's internal data object.
            TestManager.GetTestScript(testName).Start(testName)
            if test.runTime ~= nil then
                EventScheduler.ScheduleEventOnce(game.tick + test.runTime, "TestManager.WaitForPlayerThenRunTests", nil, {currentTestName = testName})
            end
            global.testManager.playerForce.chart_all(global.testManager.testSurface)

            -- Only start 1 test at a time.
            return
        end
    end

    -- Clear any previous console messages to make it easy to track each test.
    for _, player in pairs(game.connected_players) do
        player.clear_console()
    end
    game.print("All Tests Done", Colors.lightgreen)
end

--- Gets the test's internally generated display name.
---@param testName TestName
---@return string
TestManager.GetTestDisplayName = function(testName)
    local displayTestName = testName
    if TestManager.GetTestScript(testName).GetTestDisplayName ~= nil then
        displayTestName = TestManager.GetTestScript(testName).GetTestDisplayName(testName)
    end
    return displayTestName
end

---@param event on_player_created
TestManager.OnPlayerCreated = function(event)
    local player = game.get_player(event.player_index)
    if player.controller_type == defines.controllers.cutscene then
        player.exit_cutscene()
    end

    TestManager.OnPlayerCreatedMakeCharacter({instanceId = player.index})
end

---@param event ScheduledEvent
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

--- Called when the test script needs to be referenced as it can't be stored in global data.
---@param testName TestName
---@return table @ The script lua file of this test.
TestManager.GetTestScript = function(testName)
    return TestsToRun[testName].testScript
end

---@param text string
TestManager.LogTestOutcome = function(text)
    if global.testManager.justLogAllTests then
        game.write_file("RailwayTunnel_Tests.txt", text .. "\r\n", true)
    end
end

TestManager.PrepPlayersForNextTest = function()
    for _, player in pairs(game.connected_players) do
        -- Put the player back to 0,0 before each test. They can get left in odd places after riding trains.
        local playerWasInEditor = player.controller_type == defines.controllers.editor
        if playerWasInEditor then
            player.toggle_map_editor()
        end
        if player.character then
            player.character.teleport({0, 0})
        else
            player.create_character()
            player.character.teleport({0, 0})
        end
        if playerWasInEditor then
            player.toggle_map_editor()
        end

        if PlayerStartingZoom ~= nil then
            -- Set zoom on every test start. Makes loading a save before a test easier.
            player.zoom = PlayerStartingZoom
        end
    end
end

return TestManager
