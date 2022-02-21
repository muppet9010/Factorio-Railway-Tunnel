-- A test that tries ejecting a player from a train as its using a tunnel throughouts its use. Tests as normal player and as God (editor mode).
-- The first test run will always be to record timings of the tunnel's usage state changes.
-- We test a few ticks both sides of the state change to make sure any edge cases are found.

local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")
local PlayerContainer = require("scripts.player-container")
local Utils = require("utility.utils")
local EventScheduler = require("utility.event-scheduler")

---@class Tests_PRTET_PlayerController
local PlayerController = {
    character = "character",
    editor = "editor"
}
---@class Tests_PRTET_TunnelState
local TunnelState = {
    recordTicks = "recordTicks", -- A special state that just records the ticks of when the other events occur for use in their own calculations.
    before = "before", -- When the train hasn't started using the tunnel at all.
    onPortalTrack = Common.TunnelUsageAction.onPortalTrack, -- Test train starts at 0 speed so this is first event.
    startApproaching = Common.TunnelUsageAction.startApproaching,
    entered = Common.TunnelUsageAction.entered,
    leaving = Common.TunnelUsageAction.leaving,
    terminated = Common.TunnelUsageAction.terminated,
    after = "after" -- When the train reaches the far end station and so is fully out of the tunnel.
}
---@class Tests_PRTET_TickOffset
local TickOffset = {
    [-2] = -2,
    [-1] = -1,
    [0] = 0,
    [1] = 1
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificPlayerControllerFilter = {} -- Pass in an array of PlayerController keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificTunnelStateFilter = {} -- Pass in an array of PlayerController keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificTickOffsetFilter = {} -- Pass in an array of TickOffset keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 3600
Test.RunLoopsMax = 0

---@type Tests_PRTET_TestScenario[]
Test.TestScenarios = {}

--- Any scheduled event types for the test must be Registered here.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick) -- Register for enabling during Start().
    Test.GenerateTestScenarios(testName)
    TestFunctions.RegisterRecordTunnelUsageChanges(testName) -- Have tunnel usage changes being added to the test's TestData object.
end

--- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      PlayerController: " .. testScenario.playerController .. "    -    TunnelState: " .. testScenario.tunnelState .. "    - TickOffset: " .. testScenario.tickOffset
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = Test.GetThisTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local blueprint = "0eNq1Wd2SmjAYfZdca4fky6/3fYZedHYcFlOXKYIDuK2z47s3EbvaQqfH4HojkHjOR07OIYY39lwd/L4t656t3lhZNHXHVl/fWFdu67yK1/rj3rMVK3u/YwtW57t41uZl9SM/rvtDXftquW/aPq/Wnd/ufN0vuz60b196dlqwst74n2zFT4tEUF9vbnDE6WnBAkfZl36o9HxyXNeH3bNvA9E7XCyiDrU0+0Cxb7rwk6aO5AFmqd2CHdmKAvKmbH0xtOkF6/p8OGZffBfvYMQggILHhGIgVCPC17wtL5R8go3uHfMJapVGLR9ATWnU6gHUPI1az6fmiVqbB1CbKWrxX2r7AGqVRu0eQE1p1DxL8rJLZOP/YjuEcGu3bRO+R7e7jH3XRdt0XVlvJ6pJHHYuUqqZ4E8de3oQP0/klx+hRmoxKmUiJuY6nx9xiQHH5yccT4x1Pj/heOLDjM9PuNRsFdl86sQniuDzqRODVojZ1KmrB0EpRk5doYlrhv0RUP9e8P49llOgCgc1MKjGQRUManBQgkEtDsphUAeDKlgoynBQWCjiOCgsFAkcFBaKCAeFhSLcURIXCneUxIXCHSVxoXBHSVwo3FESFwp3FMFCSdxRBAslcUcRLJTEHUWwUBJ2lMCHFDYUwdpL2E933DtspztEgt10x2yCzXTHtL96qWqKZtf05asfA944vmnLgHFZmWSfTBiSoqmaNvZs4xXuBFfaah0OLDfaGmdtOIqLi23sILUwUvEsE8oZm1lLxrpMx/bnM6QRSrqMiGsZOwhDkiJPHluzjAYCqxxpq7TQzpKWQpnIEfcLe7/rzuU0xXffL78dfBVrn9psgl2Px5OCTY/nqII9jwe+Ikj6OETT0ouR9IrOH825DKpKIawKSr0LL5zkYUIE3SgL0mWSuyClNb+FF4O0hpMhR05xyXV2AfgA7eF4wp/MCo4nfAmh4HjC1zoKjid8UaYstP9+ATSjf3bX7ffPedx+fwqXihe/OVSX7f7rLI3nYQAV3fQZ3l2Mt/BHsBH4/PZhdfMGJPzf8m03lGK5NE6YMHU56ex0+gUxZmAo"
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Get the train stops.
    ---@typelist LuaEntity, LuaEntity
    local westTrainStop, eastTrainStop
    if placedEntitiesByGroup["train-stop"][1].backer_name == "West" then
        westTrainStop = placedEntitiesByGroup["train-stop"][1]
        eastTrainStop = placedEntitiesByGroup["train-stop"][2]
    else
        westTrainStop = placedEntitiesByGroup["train-stop"][2]
        eastTrainStop = placedEntitiesByGroup["train-stop"][1]
    end

    -- Get the player.
    local player = game.connected_players[1]
    if player == nil then
        error("No player 1 found to set as driver")
    end

    -- Set the player in the right mode so they have a character as required.
    if (testScenario.playerController == PlayerController.character and player.controller_type ~= defines.controllers.character) or (testScenario.playerController == PlayerController.editor and player.controller_type ~= defines.controllers.editor) then
        player.toggle_map_editor()
    end

    -- Put the player in the train.
    placedEntitiesByGroup["locomotive"][1].set_driver(player)

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_PRTET_TestScenarioBespokeData
    local testDataBespoke = {
        westTrainStop = westTrainStop, ---@type LuaEntity
        eastTrainStop = eastTrainStop, ---@type LuaEntity
        lastHandledTunnelAction = nil, ---@type TunnelUsageAction @ Used by the "recordTicks" instance.
        testStartTick = game.tick, ---@type uint
        actionTick = nil ---@type uint
    }
    testData.bespoke = testDataBespoke

    -- Set the action tick for all test instacnes other than the "recordTicks" instance.
    if testScenario.tunnelState ~= TunnelState.recordTicks then
        testDataBespoke.actionTick = testDataBespoke.testStartTick + testManagerEntry.actionDelayTicks[testScenario.tunnelState] + testScenario.tickOffset
    end

    -- Schedule the EveryTick() to run each game tick.
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

--- Any scheduled events for the test must be Removed here so they stop running. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)

    -- Put the player back in to editor mode.
    local player = game.connected_players[1]
    if player.controller_type ~= defines.controllers.editor then
        player.toggle_map_editor()
    end
end

--- Scheduled event function to check test state each tick.
---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    -- Get testData object and testName from the event data.
    local testName = event.instanceId
    local testManagerEntry = Test.GetThisTestManagerObject(testName)
    local testData = TestFunctions.GetTestDataObject(testName)
    local testScenario = testData.testScenario ---@type Tests_PRTET_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_PRTET_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    -- If its the special discovery test run then just do its logic.
    if testScenario.tunnelState == TunnelState.recordTicks then
        -- First run so populate the starting data.
        if testManagerEntry.actionDelayTicks == nil then
            testManagerEntry.actionDelayTicks = {
                before = 5 -- So when we start with a few ticks offset it just works. At this point there is no risk of the train having engaged with the tunnel as it starts at 0.
            }
        end

        if testDataBespoke.lastHandledTunnelAction ~= tunnelUsageChanges.lastAction then
            -- New action has just occured so capture the time in to the test instance data.
            testManagerEntry.actionDelayTicks[tunnelUsageChanges.lastAction] = event.tick - testDataBespoke.testStartTick

            -- Just track the actions handled in the local test data.
            testDataBespoke.lastHandledTunnelAction = tunnelUsageChanges.lastAction
        end

        -- End the test instance once the train reaches the west station.
        if testDataBespoke.westTrainStop.get_stopped_train() ~= nil then
            testManagerEntry.actionDelayTicks["after"] = event.tick - testDataBespoke.testStartTick - 5 -- Make sure there's enough time for the offset to run before it reaches the west station.
            TestFunctions.TestCompleted(testName)
        end

        return
    end

    -- Code for the main tests below here.

    -- Check if our tick has arrived.
    if event.tick < testDataBespoke.actionTick then
        -- Before our tick so do nothing.
        return
    elseif event.tick == testDataBespoke.actionTick then
        -- Is our tick so eject the player.
        game.print("player ejected")
        local player = game.get_player(1)
        PlayerContainer.OnToggleDrivingInput({player_index = 1})
        player.driving = false

        -- Check if there is still a scheduled function for this tick or if it was removd when we tried to set the player driving to false.
        local followupCheckToBeCalled = EventScheduler.IsEventScheduledOnce("PlayerContainer.OnToggleDrivingInputAfterChangedState_Scheduled", player.index, game.tick)
        if followupCheckToBeCalled then
            -- As this ejection attempt wasn't done mid tick by the player pressing a key input, but instead within our mod's on_tick we have to call the follow up function ourselves, as the default scheduled function will have been for in the past.
            PlayerContainer.OnToggleDrivingInputAfterChangedState_Scheduled({data = {playerIndex = 1}})
        end

        -- Check its gone as expected.
        if player.vehicle ~= nil then
            TestFunctions.TestFailed(testName, "Player didn't leave vehicle when expected.")
            return
        end
    else
        -- Is after the action tick. We will put the player back in the train when it arrives in the station and check they can ride the train back to the east station without issue.
        local player = game.get_player(1)

        -- Put player back in train if its reached the west stop.
        local westStoppedTrain = testDataBespoke.westTrainStop.get_stopped_train()
        if westStoppedTrain ~= nil then
            westStoppedTrain.front_stock.set_driver(player)
        end

        -- Check the player is still riding the train whne it reaches the east side.
        local eastStoppedTrain = testDataBespoke.eastTrainStop.get_stopped_train()
        if eastStoppedTrain ~= nil then
            if player.vehicle == nil or not player.vehicle.valid then
                TestFunctions.TestFailed(testName, "Player wasn't in a valid vehicle when the train reached the east side.")
                return
            end
            if player.vehicle.train == nil or player.vehicle.train.id ~= eastStoppedTrain.id then
                TestFunctions.TestFailed(testName, "Player wasn't in the right train when the train reached the east side.")
                return
            end
            TestFunctions.TestCompleted(testName)
            return
        end
    end
end

---@class TestManager_Test_PRTET : TestManager_Test
---@field actionDelayTicks table<TunnelUsageAction, Tick> @ How long after a test starts each tunnel usage action state will be reached. To be populated on first test run as "recordTicks".

--- Returns the bespoke TestManager object for this test with its custom extra fields.
---@param testName string
---@return TestManager_Test_PRTET
Test.GetThisTestManagerObject = function(testName)
    return TestFunctions.GetTestManagerObject(testName)
end

--- Generate the combinations of different tests required.
---@param testName string
Test.GenerateTestScenarios = function(testName)
    -- Global test setting used for when wanting to do all variations of lots of test files.
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    -- Work out what specific instances of each type to do.
    local playerControllerToTest  ---@type Tests_PRTET_PlayerController[]
    local tunnelStateToTest  ---@type Tests_PRTET_TunnelState[]
    local tickOffsetToTest  ---@type Tests_PRTET_TickOffset[]
    if DoSpecificTests then
        -- Adhock testing option.
        playerControllerToTest = TestFunctions.ApplySpecificFilterToListByKeyName(PlayerController, SpecificPlayerControllerFilter)
        tunnelStateToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TunnelState, SpecificTunnelStateFilter)
        tickOffsetToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TickOffset, SpecificTickOffsetFilter)
    elseif DoMinimalTests then
        playerControllerToTest = PlayerController
        tunnelStateToTest = {TunnelState.before, TunnelState.onPortalTrack, TunnelState.entered, TunnelState.leaving}
        tickOffsetToTest = {TickOffset[-1], TickOffset[1]}
    else
        -- Do whole test suite.
        playerControllerToTest = PlayerController
        tunnelStateToTest = Utils.DeepCopy(TunnelState) -- Has to be a copy as we will remove some values from it.
        tickOffsetToTest = TickOffset
    end

    -- Remove the special discovery test from the planned loops. As we will just add it in once at the start.
    tunnelStateToTest[TunnelState.recordTicks] = nil

    -- Add the special tick discovery test.
    ---@class Tests_PRTET_TestScenario
    local scenario = {
        playerController = PlayerController.editor,
        tunnelState = TunnelState.recordTicks,
        tickOffset = TickOffset[0]
    }
    table.insert(Test.TestScenarios, scenario)
    Test.RunLoopsMax = Test.RunLoopsMax + 1

    -- Work out the combinations of the various types that we will do a test for.
    for _, playerController in pairs(playerControllerToTest) do
        for _, tunnelState in pairs(tunnelStateToTest) do
            for _, tickOffset in pairs(tickOffsetToTest) do
                ---@class Tests_PRTET_TestScenario
                local scenario = {
                    playerController = playerController,
                    tunnelState = tunnelState,
                    tickOffset = tickOffset
                }
                table.insert(Test.TestScenarios, scenario)
                Test.RunLoopsMax = Test.RunLoopsMax + 1
            end
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

return Test
