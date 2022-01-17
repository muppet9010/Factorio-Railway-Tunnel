--[[
    Notes
    -------------
        - Tests don't load if a dedicated server makes the game and saves the map, then loads the save to run the game. It must be created by the player, saved and then uploaded to the server for running tests in MP.
--]]
local TestManager = {}
local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")
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
local EnableDebugMode = true -- Enables debug mode when tests are run. Enables "railway_tunnel_toggle_debug_state" command.

local WaitForPlayerAtEndOfEachTest = false -- The game will be paused when each test is completed before the map is cleared if TRUE. Otherwise the tests will run from one to the next. On a test erroring the map will still pause regardless of this setting.
local JustLogAllTests = false -- Rather than stopping at a failed test, run all tests and log the output to script-output folder. No pausing will ever occur between tests if enabled, even for failures. Results written to a text file in: script-output/RailwayTunnel_Tests.txt

local PlayerStartingZoom = 0.1 -- Sets players starting zoom level. 1 is default Factorio, 0.1 is a good view for most tests.
local TestGameSpeed = 1 -- The game speed to run the tests at. Default is 1.
local ContinueTestAfterCompletionSeconds = 3 -- How many seconds each test continues to run after it successfully completes before the next one starts. Intended to make sure the mod has reached a stable state in each test. nil, 0 or greater
local KeepRunningTest = false -- If enabled the first test run will not stop when successfully completed. Intended for benchmarking or demo loops.

-- Add any new tests in to the table, set "enabled" true/false and the "testScript" path.
---@type table<TestManager_TestName, TestManager_TestToRun>
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
    PathToRail = {enabled = false, testScript = require("tests/path-to-rail")},
    TrainCoastingToTunnel = {enabled = false, testScript = require("tests/train-coasting-to-tunnel")},
    --ForceRepathBackThroughTunnelTests = {enabled = false, testScript = require("tests/force-repath-back-through-tunnel-tests")} -- DONT USE - test needs major overhaul as was designed for complex logic we don't have to handle any more.
    MineDestroyTunnelTests = {enabled = false, testScript = require("tests/mine-destroy-tunnel-tests")},
    PathToTunnelRailTests = {enabled = false, testScript = require("tests/path-to-tunnel-rail-tests")},
    RemoveTargetStopRail = {enabled = false, testScript = require("tests/remove-target-stop-rail")},
    RunOutOfFuelTests = {enabled = false, testScript = require("tests/run-out-of-fuel-tests")},
    TrainTooLong = {enabled = false, testScript = require("tests/train-too-long")},
    LeavingTrainSpeedDurationChangeTests = {enabled = false, testScript = require("tests/leaving-train-speed-duration-change-tests")},
    UpsManyShortTrains = {enabled = false, testScript = require("tests/ups_many_small_trains"), notInAllTests = true},
    TemplateSingleInstance = {enabled = false, testScript = require("tests/__template_single_instance"), notInAllTests = true},
    TemplateMultiInstance = {enabled = false, testScript = require("tests/__template_multi_instance"), notInAllTests = true}
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

---@class TestManager_Test
---@field testName TestManager_TestName
---@field enabled boolean
---@field notInAllTests boolean
---@field runTime Tick
---@field runLoopsMax uint
---@field runLoopsCount uint
---@field finished boolean
---@field success boolean

---@class TestManager_TestName:string

--- A configuration object to define which tests should be run.
---@class TestManager_TestToRun
---@field enabled boolean @ If the test will be run.
---@field notInAllTests? boolean|null @ If TRUE then this test is not automatically included when the "AllTests" global option is enabled. For use by adhoc/non standard test scripts or demo scripts.
---@field testScript TestManager_TestScript

--- The test's script file as a table of interface and internal functions of this specific test.
---@class TestManager_TestScript
---@field RunTime? int|null @ How long the test runs for (ticks) before being failed as un-completed. A nil value will never end unless the test logic completes or fails it. A non ending test is generally only used for demo/ups tests as a normal test will want a desired timeout in case of non action.
---@field RunLoopsMax? int|null @ How many times this tests will be run. For use by tests that have different setups per iteration. If not provided then the test is run 1 time.
---@field OnLoad function @ Anything the test needs registering OnLoad of the mod.
---@field GetTestDisplayName? function|null @ Let the test define its test name per run. For use when RunLoopsMax > 1. If not set then the TestName in the TestToRun object is used from Test Manager configuration.
---@field Start function @ Called to start the test.
---@field Stop function @ Called when the test is being stopped for any reason.

--- The base object for storing test data during a test iteration run between ticks. It will have additional test specific fields set within it by the script.
---@class TestManager_TestData
---@field bespoke table<string, any> @ The bespoke test data for only this test will be registered under here.
---@field actions table<TunnelUsageAction, TestManager_TunnelUsageChangeAction> @ A list of the tunnel usage change actions and some meta data on them.
---@field lastAction? TunnelUsageAction|null @ The last tunnel usage change action reported or nil if none.
---@field tunnelUsageEntry? TestManager_TunnelUsageTrains|null @ The current LuaTrains using the tunnel by their usage state.
---@field testScenario? table<string, any>|null @ In a multi iteration test its a reference to this test iterations specific TestScenario object. In a single iteration test it will be nil.

---@class TestManager_TunnelUsageChangeAction
---@field name TunnelUsageAction @ The action name string, same as the key in the table.
---@field count uint @ How many times the event has occured.
---@field recentChangeReason TunnelUsageChangeReason @ The last change reason text for this action if there was one. Only occurs on single fire actions.

---@class TestManager_TunnelUsageTrains @ A list of the tunnel usage train types and a referecne to the LuaTrain they refer to. For quick access of the train and checking on its high level state.
---@field enteringTrain? LuaTrain
---@field leavingTrain? LuaTrain

TestManager.CreateGlobals = function()
    global.testManager = global.testManager or {}
    global.testManager.testProcessStarted = global.testManager.testProcessStarted or false ---@type boolean @ Used to flag when a save was started with tests already.
    global.testManager.testSurface = global.testManager.testSurface or nil ---@type LuaSurface
    global.testManager.playerForce = global.testManager.playerForce or nil ---@type LuaForce
    global.testManager.testData = global.testManager.testData or {} ---@type table<TestManager_TestName, TestManager_TestData> @ Used by tests to store their local data.
    global.testManager.testsToRun = global.testManager.testsToRun or {} ---@type table<TestManager_TestName, TestManager_Test> @ Holds management state data on the test, but the test scripts always have to be obtained from the TestsToRun local object. Can't store lua functions in global data.
    global.testManager.justLogAllTests = JustLogAllTests ---@type boolean
    global.testManager.keepRunningTest = KeepRunningTest ---@type boolean
    global.testManager.continueTestAfterCompletioTicks = (ContinueTestAfterCompletionSeconds or 0) * 60 ---@type Tick
    global.testManager.forceTestsFullSuite = ForceTestsFullSuite ---@type boolean
end

TestManager.OnLoad = function()
    if not DoTests then
        return
    end
    EventScheduler.RegisterScheduledEventType("TestManager.RunTests_Scheduled", TestManager.RunTests_Scheduled)
    EventScheduler.RegisterScheduledEventType("TestManager.WaitForPlayerThenRunTests_Scheduled", TestManager.WaitForPlayerThenRunTests_Scheduled)
    EventScheduler.RegisterScheduledEventType("TestManager.ClearMap_Scheduled", TestManager.ClearMap_Scheduled)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "TestManager.OnPlayerCreated", TestManager.OnPlayerCreated)
    EventScheduler.RegisterScheduledEventType("TestManager.OnPlayerCreatedMakeCharacter_Scheduled", TestManager.OnPlayerCreatedMakeCharacter_Scheduled)

    MOD.Interfaces.TestManager = MOD.Interfaces.TestManager or {}
    MOD.Interfaces.TestManager.GetTestScript = TestManager.GetTestScript
    MOD.Interfaces.TestManager.LogTestOutcome = TestManager.LogTestOutcome
    MOD.Interfaces.TestManager.LogTestDataToTestRow = TestManager.LogTestDataToTestRow

    -- Run any active tests OnLoad function.
    for testName, testToRun in pairs(TestsToRun) do
        if ((AllTests and not testToRun.notInAllTests) or testToRun.enabled) and testToRun.testScript.OnLoad ~= nil then
            testToRun.testScript.OnLoad(testName)
        end
    end
end

TestManager.OnStartup = function()
    if not DoTests or global.testManager.testProcessStarted then
        return
    end
    global.testManager.testProcessStarted = true

    -- Enable debug mode within the mod.
    if EnableDebugMode then
        global.debugRelease = true
    end

    local playerForce = game.forces["player"]
    playerForce.character_running_speed_modifier = 10
    playerForce.character_build_distance_bonus = 100
    playerForce.character_reach_distance_bonus = 100
    global.testManager.playerForce = playerForce

    local testSurface = game.surfaces[1]
    testSurface.generate_with_lab_tiles = true
    testSurface.always_day = true
    testSurface.freeze_daytime = true
    testSurface.show_clouds = false
    global.testManager.testSurface = testSurface

    -- Remove the default map so the lab tile map chunks appear.
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
        EventScheduler.ScheduleEventOnce(game.tick + 120, "TestManager.WaitForPlayerThenRunTests_Scheduled", nil, {firstLoad = true}) -- Have to give it time to chart the revealed area.
    end
end

---@param event UtilityScheduledEvent_CallbackObject
TestManager.WaitForPlayerThenRunTests_Scheduled = function(event)
    local currentTestName = event.data.currentTestName -- Only populated if this event was scheduled with the tests RunTime attribute.
    if currentTestName ~= nil then
        TestManager.GetTestScript(currentTestName).Stop(currentTestName)
        game.print("Test timed out: " .. TestManager.GetTestDisplayName(currentTestName), Colors.red)
        TestManager.LogTestOutcome("Test timed out")
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
        EventScheduler.ScheduleEventOnce(game.tick + 1, "TestManager.ClearMap_Scheduled")
    else
        TestManager.ClearMap_Scheduled()
    end
end

-- Clean any previous entities off the map.
TestManager.ClearMap_Scheduled = function()
    -- Remove any trains first and then everything else, to avoid triggering tunnel removal destroying trains alerts.
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
    EventScheduler.ScheduleEventOnce(game.tick + 1, "TestManager.RunTests_Scheduled")
end

TestManager.RunTests_Scheduled = function()
    for testName, test in pairs(global.testManager.testsToRun) do
        if ((AllTests and not test.notInAllTests) or test.enabled) and test.runLoopsCount < test.runLoopsMax then
            TestManager.PrepPlayersForNextTest()
            test.runLoopsCount = test.runLoopsCount + 1
            game.print("Starting Test:   " .. TestManager.GetTestDisplayName(testName), Colors.cyan)
            if global.testManager.justLogAllTests then
                game.write_file("RailwayTunnel_Tests.txt", TestManager.GetTestDisplayName(testName) .. "   =   ", true)
            end
            global.testManager.testData[testName] = TestManager.CreateTestDataObject() -- Reset for every test iteration as this is the test's internal data object.
            TestManager.GetTestScript(testName).Start(testName)
            if test.runTime ~= nil then
                EventScheduler.ScheduleEventOnce(game.tick + test.runTime, "TestManager.WaitForPlayerThenRunTests_Scheduled", nil, {currentTestName = testName})
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
---@param testName TestManager_TestName
---@return string
TestManager.GetTestDisplayName = function(testName)
    local testScript = TestManager.GetTestScript(testName)
    if testScript.GetTestDisplayName ~= nil then
        return testScript.GetTestDisplayName(testName)
    else
        return testName
    end
end

---@param event on_player_created
TestManager.OnPlayerCreated = function(event)
    local player = game.get_player(event.player_index)
    if player.controller_type == defines.controllers.cutscene then
        player.exit_cutscene()
    end

    TestManager.OnPlayerCreatedMakeCharacter_Scheduled({instanceId = player.index})
end

---@param event UtilityScheduledEvent_CallbackObject
TestManager.OnPlayerCreatedMakeCharacter_Scheduled = function(event)
    -- Add a character since it was lost in surface destruction. Then go to Map Editor, that way if we leave map editor we have a character to return to.
    local player = game.get_player(event.instanceId)
    if player.character == nil then
        local characterCreated = player.create_character()
        if characterCreated == false then
            -- Character can't create yet, try again later.
            EventScheduler.ScheduleEventOnce(game.tick + 1, "TestManager.OnPlayerCreatedMakeCharacter_Scheduled", player.index)
            return
        end
    end
    local tickWasPaused = game.tick_paused
    player.toggle_map_editor()
    game.tick_paused = tickWasPaused
end

--- Called when the test script needs to be referenced as it can't be stored in global data.
---@param testName TestManager_TestName
---@return TestManager_TestScript @ The script lua file of this test.
TestManager.GetTestScript = function(testName)
    return TestsToRun[testName].testScript
end

--- Goes in to the test log file after the equals sign on the current row.
---@param text string
TestManager.LogTestDataToTestRow = function(text)
    if global.testManager.justLogAllTests then
        game.write_file("RailwayTunnel_Tests.txt", "   " .. text .. "   -   ", true)
    end
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

---@return TestManager_TestData
TestManager.CreateTestDataObject = function()
    ---@type TestManager_TestData
    local testData = {
        actions = {}
    }
    return testData
end

return TestManager
