--[[
    A series of tests that manually drives a train and does various actions during tunnel usage. Uses a short tunnel so longest train can be using both ends of it at once. Can't test for exact final outcome, but can alteast confirm it doesn't crash and steering works in all cases.
    Tests the various combinations:
        - Train types: one of the local TrainTypes variable train type texts.
        - Player inputs (up to 3 "bursts" per test):
            - start state (per carraige): beginning, carriageEntering, fullyEntered, carriageLeaving, fullyLeft.
            - stop state (per carriage): carriageEntering, fullyEntered, carriageLeaving, fullyLeft, tunnelUsageCompleted.
            - acceleration (from players viewpoint pre tunnel): forwards, backwards, nothing
            - direction: left, right, straight
        - Player riding in: 1st and last carriage and locomotive per train.
        - Train starting speed (tiles per tick): 0, 0.5, 1
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

local DoMinimalTests = false -- If TRUE does minimal tests just to check the general manual driving behavior. Intended for regular use as part of all tests. If FALSE does the whole test suite and follows DoSpecificTests.

local DoSpecificTests = false -- If enabled does the below specific train tests, rather than the main test suite. Used for adhock testing.
local SpecificTrainTypesFilter = {} -- Pass in array of TrainTypes text (---<---) to do just those. Leave as nil or empty table for all train types. Only used when DoSpecificTrainTests is TRUE.
local SpecificPlayerInput1StartStatesFilter = {} -- Pass in array of StartStates keys to do just those. Leave as nil or empty table for all player input types. Only used when DoSpecificTrainTests is TRUE.
local SpecificPlayerInput1StopStatesFilter = {} -- Pass in array of StopStates keys to do just those. Leave as nil or empty table for all player input types. Only used when DoSpecificTrainTests is TRUE.
local SpecificPlayerInput1AccelerationActionsFilter = {} -- Pass in array of AccelerationActions keys to do just those. Leave as nil or empty table for all player input types. Only used when DoSpecificTrainTests is TRUE.
local SpecificPlayerInput1DirectionActionsFilter = {} -- Pass in array of DirectionActions keys to do just those. Leave as nil or empty table for all player input types. Only used when DoSpecificTrainTests is TRUE.
local SpecificPlayerInput2StartStatesFilter = {} -- Pass in array of StartStates keys to do just those. Leave as nil or empty table for all player input types. Only used when DoSpecificTrainTests is TRUE.
local SpecificPlayerInput2StopStatesFilter = {} -- Pass in array of StopStates keys to do just those. Leave as nil or empty table for all player input types. Only used when DoSpecificTrainTests is TRUE.
local SpecificPlayerInput2AccelerationActionsFilter = {} -- Pass in array of AccelerationActions keys to do just those. Leave as nil or empty table for all player input types. Only used when DoSpecificTrainTests is TRUE.
local SpecificPlayerInput2DirectionActionsFilter = {} -- Pass in array of DirectionActions keys to do just those. Leave as nil or empty table for all player input types. Only used when DoSpecificTrainTests is TRUE.
local SpecificPlayerInput3StartStatesFilter = {} -- Pass in array of StartStates keys to do just those. Leave as nil or empty table for all player input types. Only used when DoSpecificTrainTests is TRUE.
local SpecificPlayerInput3StopStatesFilter = {} -- Pass in array of StopStates keys to do just those. Leave as nil or empty table for all player input types. Only used when DoSpecificTrainTests is TRUE.
local SpecificPlayerInput3AccelerationActionsFilter = {} -- Pass in array of AccelerationActions keys to do just those. Leave as nil or empty table for all player input types. Only used when DoSpecificTrainTests is TRUE.
local SpecificPlayerInput3DirectionActionsFilter = {} -- Pass in array of DirectionActions keys to do just those. Leave as nil or empty table for all player input types. Only used when DoSpecificTrainTests is TRUE.
local SpecificPlayerRidingInCarriageTypesFilter = {} -- Pass in an array of PlayerRidingInCarriageTypes to do just those specific carriage type tests. Leave as nil or empty table for all carriages in train. Only used when DoSpecificTrainTests is TRUE. Setting to a carriage type that isn't present on the specified train will throw an intentional error.
local SpecificPlayerRidingInCarriagePositionsFilter = {} -- Pass in an array of PlayerRidingInCarriagePositions to do just those specific carriage position tests. Leave as nil or empty table for all carriages in train. Only used when DoSpecificTrainTests is TRUE. Setting to "last" with only 1 of that carriage type will throw an intentional error.
local SpecificStartingTrainSpeedsFilter = {} -- Pass in array of any train speed values to do just those specific forwards pathing option tests. Leave as nil or empty table for all forwards pathing tests. Only used when DoSpecificTrainTests is TRUE. Speed value is blindly applied, doesn't have to be on the StartingTrainSpeeds variable list.

local DebugOutputTestScenarioDetails = true -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 1800
Test.RunLoopsMax = 0 -- Populated when script loaded.
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        trainTypeText = human readable text of the trains makeup.
        trainTypeCarriages = array of Test_TrainTypeCarriageDetails (buildable).
        playerInput1 = {
            startState = the StartStates for when this input starts in this test.
            stopState = the StopStates for when this input stops in this test.
            accelerationAction = the AccelerationActions for during this input period in this test.
            directionActions = the DirectionActions for during this input period in this test.
        }
        playerInput2 = same structure as playerInput1 or nil.
        playerInput3 = same structure as playerInput1 or nil.
        playerRidingInCarriageType = the PlayerRidingInCarriageTypes for this test.
        playerRidingInCarriagePositions = the PlayerRidingInCarriagePositions for this test.
        trainStartingSpeed = the speed of the train at test start.
        expectedTrainState = the FinalTrainStates of this test. Will be updated during the test in many cases as may not be predictable.
    }
]]
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName) -- Call here so its always populated.
    TestFunctions.RegisterTestsEventHandler(testName, remote.call("railway_tunnel", "get_tunnel_usage_changed_event_id"), "Test.TunnelUsageChanged", Test.TunnelUsageChanged)
end

local blueprintString = "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"

local TrainTypes = {
    {
        text = "<"
    },
    {
        text = ">"
    },
    {
        text = "-<-"
    },
    {
        text = "~<~"
    },
    {
        text = "->-"
    },
    {
        text = "~>~"
    },
    {
        text = "----<"
    },
    {
        text = "~~~~<"
    },
    {
        text = "---->"
    },
    {
        text = "~~~~>"
    },
    {
        text = "<<-------->>"
    },
    {
        text = "<<~~~~~~~~>>"
    }
}
local StartStates = {
    beginning = "beginning",
    carriageEntering = "carriageEntering",
    fullyEntered = "fullyEntered",
    carriageLeaving = "carriageLeaving",
    fullyLeft = "fullyLeft"
}
local StopStates = {
    carriageEntering = "carriageEntering",
    fullyEntered = "fullyEntered",
    carriageLeaving = "carriageLeaving",
    fullyLeft = "fullyLeft",
    tunnelUsageCompleted = "tunnelUsageCompleted"
}
local AccelerationActions = {
    forwards = "forwards",
    backwards = "backwards",
    nothing = "nothing"
}
local DirectionActions = {
    left = "left",
    right = "right",
    straight = "straight"
}
local PlayerRidingInCarriageTypes = {
    locomotive = "locomotive",
    ["cargo-wagon"] = "cargo-wagon"
}
local PlayerRidingInCarriagePositions = {
    first = "first",
    last = "last"
}
local StartingTrainSpeeds = {
    0,
    0.5,
    1
}
local FinalTrainStates = {} --TODO

Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    local GeneratePlayerInputText = function(playerInput)
        if playerInput == nil then
            return ""
        else
            return "\nInput 1: " .. playerInput.startState .. " to " .. playerInput.stopState .. " - " .. playerInput.accelerationAction .. " - " .. playerInput.directionAction
        end
    end
    local playerInput1, playerInput2, playerInput3 = GeneratePlayerInputText(testScenario.playerInput1), GeneratePlayerInputText(testScenario.playerInput2), GeneratePlayerInputText(testScenario.playerInput3)
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trainTypeText .. "     " .. testScenario.playerRidingInCarriagePositions .. " " .. testScenario.playerRidingInCarriageType .. "     " .. testScenario.trainStartingSpeed .. "speed       Expected result: " .. testScenario.expectedTrainState .. playerInput1 .. playerInput2 .. playerInput3
end

Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 40}, testName)

    -- Get the stations from the blueprint
    local stationEastTop, stationEastMiddle, stationEastBottom, stationWestTop, stationWestMiddle, stationWestBottom
    for _, stationEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "train-stop", true, false)) do
        if stationEntity.backer_name == "EastTop" then
            stationEastTop = stationEntity
        elseif stationEntity.backer_name == "EastMiddle" then
            stationEastMiddle = stationEntity
        elseif stationEntity.backer_name == "EastBottom" then
            stationEastBottom = stationEntity
        elseif stationEntity.backer_name == "WestTop" then
            stationWestTop = stationEntity
        elseif stationEntity.backer_name == "WestMiddle" then
            stationWestMiddle = stationEntity
        elseif stationEntity.backer_name == "WestBottom" then
            stationWestBottom = stationEntity
        end
    end

    -- Get the portals.
    local westPortal, westPortalXPos, eastPortal, eastPortalXPos = nil, -100000, nil, 100000
    for _, portalEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "railway_tunnel-tunnel_portal_surface-placed", true, false)) do
        if portalEntity.position.x > westPortalXPos then
            westPortal = portalEntity
            westPortalXPos = portalEntity.position.x
        end
        if portalEntity.position.x < eastPortalXPos then
            eastPortal = portalEntity
            eastPortalXPos = portalEntity.position.x
        end
    end

    -- Place train so it ends safely to the left of the east middle station (don't just build it backwards from the station).
    local firstCarriagePosition = Utils.ApplyOffsetToPosition(stationEastMiddle.position, {x = (#testScenario.trainTypeCarriages * 7) + 4, y = -0.5})
    local train = TestFunctions.BuildTrain(firstCarriagePosition, testScenario.trainTypeCarriages, 0.75, {name = "rocket-fuel", count = 10})

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationEastTop = stationEastTop
    testData.stationEastMiddle = stationEastMiddle
    testData.stationEastBottom = stationEastBottom
    testData.stationWestTop = stationWestTop
    testData.stationWestMiddle = stationWestMiddle
    testData.stationWestBottom = stationWestBottom
    testData.eastPortal = eastPortal
    testData.westPortal = westPortal
    testData.train = train
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.testScenario = testScenario
    testData.actions = {}
    --[[
        A list of actions and how many times they have occured. Populated as the events come in.
        [actionName] = {
            name = the action name string, same as the key in the table.
            count = how many times the event has occured.
            recentChangeReason = the last change reason text for this action if there was one. Only occurs on single fire actions.
        }
    --]]
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.TunnelUsageChanged = function(event)
    local testData = TestFunctions.GetTestDataObject(event.testName)

    -- Record the action for later reference.
    local actionListEntry = testData.actions[event.action]
    if actionListEntry then
        actionListEntry.count = actionListEntry.count + 1
        actionListEntry.recentChangeReason = event.changeReason
    else
        testData.actions[event.action] = {
            name = event.action,
            count = 1,
            recentChangeReason = event.changeReason
        }
    end
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local testScenario = testData.testScenario

    --TODO
end

Test.GenerateTestScenarios = function(testName)
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    local trainStatesToTest, tunnelPartsToTest, removalActionsToTest
    if DoMinimalTests then
        -- Minimal tests.
        trainStatesToTest = {[TrainStates.none] = TrainStates.none, [TrainStates.enteringCarriageRemoved] = TrainStates.enteringCarriageRemoved}
        tunnelPartsToTest = {TunnelParts.entrancePortal}
        removalActionsToTest = RemovalActions
    elseif DoSpecificTests then
        -- Adhock testing option.
        trainStatesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainStates, SpecificTrainStateFilter)
        tunnelPartsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TunnelParts, SpecificTunnelPartFilter)
        removalActionsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(RemovalActions, SpecificRemovalActionFilter)
    else
        -- Do whole test suite.
        trainStatesToTest = TrainStates
        tunnelPartsToTest = TunnelParts
        removalActionsToTest = RemovalActions
    end

    for _, trainState in pairs(trainStatesToTest) do
        for _, tunnelPart in pairs(tunnelPartsToTest) do
            for _, removalAction in pairs(removalActionsToTest) do
                local scenario = {
                    trainState = trainState,
                    tunnelPart = tunnelPart,
                    removalAction = removalAction
                }
                scenario.expectedTrainState = Test.CalculateExpectedResults(scenario)
                Test.RunLoopsMax = Test.RunLoopsMax + 1
                table.insert(Test.TestScenarios, scenario)
            end
        end
    end

    -- Write out all tests to csv as debug.
    Test.WriteTestScenariosToFile(testName)
end

Test.CalculateExpectedResults = function(testScenario)
    local expectedTrainState

    -- TODO

    return expectedTrainState
end

Test.WriteTestScenariosToFile = function(testName)
    -- A debug function to write out the tests list to a csv for checking in excel.
    if not DebugOutputTestScenarioDetails or game == nil then
        -- game will be nil on loading a save.
        return
    end

    local fileName = testName .. "-TestScenarios.csv"
    game.write_file(fileName, "#,trainTypeText,playerInput1StartState,playerInput1StopState,playerInput1AccelerationAction,playerInput1DirectionAction,playerInput2StartState,playerInput2StopState,playerInput2AccelerationAction,playerInput2DirectionAction,playerInput3StartState,playerInput3StopState,playerInput3AccelerationAction,playerInput3DirectionAction,playerRidingInCarriageType, playerRidingInCarriagePosition,trainStartingSpeed,expectedTrainState" .. "\r\n", false)

    for testIndex, test in pairs(Test.TestScenarios) do
        game.write_file(fileName, tostring(testIndex) .. "," .. tostring(test.trainTypeText) .. "," .. tostring(test.playerInput1StartState) .. "," .. tostring(test.playerInput1StopState) .. "," .. tostring(test.playerInput1AccelerationAction) .. "," .. tostring(test.playerInput1DirectionAction) .. "," .. tostring(test.playerInput2StartState) .. "," .. tostring(test.playerInput2StopState) .. "," .. tostring(test.playerInput2AccelerationAction) .. "," .. tostring(test.playerInput2DirectionAction) .. "," .. tostring(test.playerInput3StartState) .. "," .. tostring(test.playerInput3StopState) .. "," .. tostring(test.playerInput3AccelerationAction) .. "," .. tostring(test.playerInput3DirectionAction) .. "," .. tostring(test.playerRidingInCarriageType) .. "," .. tostring(test.playerRidingInCarriagePosition) .. "," .. tostring(test.trainStartingSpeed) .. "," .. tostring(test.expectedTrainState) .. "\r\n", true)
    end
end

return Test
