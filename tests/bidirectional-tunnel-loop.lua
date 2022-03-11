-- Tests that a train can do a figure of 8 smoothly through a single tunnel at speed a few times. Uses some different train compositions to get different tunnel signals being triggered at different speeds. We don't support reserving the same tunnel you are leaving and so the leaving train is just massively slowed down in this edge case. The number of times the train reaches the stations are tracked to make sure thye are doing a figure of 8 and not just flip/flopping in/out of the tunnel.

local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")
local Utils = require("utility.utils")

---@class Tests_BTL_TrainCompositions
local TrainCompositions = {
    ["<"] = {composition = "<"},
    ["<>"] = {composition = "<>"},
    ["><"] = {composition = "><"}
}
---@class Tests_BTL_StartingSpeeds
local StartingSpeeds = {
    none = 0,
    half = 0.7, -- half max speed.
    full = 1.4 -- 1.4 speed is the max of this train type and fuel type in the BP.
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTrainCompositionsFilter = {} -- Pass in an array of TrainCompositions keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificStartingSpeedsFilter = {} -- Pass in an array of StartingSpeeds keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 3600
Test.RunLoopsMax = 0

---@type Tests_BTL_TestScenario[]
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
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):        " .. testScenario.trainComposition.composition .. "      speed: " .. testScenario.startingSpeed
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    --Place the tracls, tunnel, stations, etc.
    local blueprint = "0eNq1WcuO2kAQ/Jc5G8nztvmIXHKMIuSFEWsJbGSbTdCKf88Yb8guaXBXdnJCYFHVM64uT5dfxdPuGA5d3Qxi+Srqddv0YvntVfT1tql242/D6RDEUtRD2ItMNNV+/NZV9U6cM1E3m/BTLOU5Y/3lR3VaDcemCbvFoe2Garfqw3YfmmHRD/H69nl4B6rO3zMRr9VDHaaiLl9Oq+a4fwpdZL1ir4/dS9gsLlVl4tD28T9tM5YScRYuE6f44VXE3tRdWE8X3Vj0DaTiQSoaUROI+or4e4n3yiwnUFd+BPUEqOGCWhpTEpiWuZvybfHOzWM6HmZxRSQwPHsDpX7DkRROAdVii4+rswRiCVdmS6oymV+BRpwmNkN7oFDkFSWLlNV0TXyJnfQsKFyJF+jJAhUOZEkgDfWXvekvRUGivRArm21aafEFa3LBDgci1Ss9ZnY2nzc7WcDFGVrAJWpyxs+bnMrx8kj5KglamzHz1qbwnjBkTyiNA5FaUwYHIrWmcPVrUhcKV7+m7yD+END0Zhcz55HQbB6Byo/CiDv+UnV19UAmJXoAus+uPMqu84Tso2/O8cmEfJrBpxLySQafTscnS/humoTsuJZsQnYLs7tPNa6EG1f7e4THOJ50266Nn3+t+eJKq3XX9n3dbB8U5BliK/6lgkcnCwZnmZiT0cQm/687zWhrIz8jLs4S0/kUQzgmnUuVDLZ0riQ59yqdDUmNmoJx6chhCzQ+HTns/qZIRw4/+Ez5mf5U8G228OShyGOrhQdwRZ6jLTxraPJgb+FRQ5OThoUnDfo0buFBgx4PrOMOeOaCYtR8uGPhkYOegSw8ZNNDmYXTJnpKdDlzr8bxe0Qp5jMYB+jcT6iMEMbBqqcHbAerno4RnOHu3JQhciIYB3cAncA4/qStpxTR6vkExsE9QIdXjpm9LvTUn5YTLcP9QCd0HvZ6Otr0sNfTWauHVU+Hyp6vej0lo3Rs7mGvv4Nj4Xro++WYYfkV5Pbh/yc5/9oe6eTcw8K/UywofHdjtobCLLGHnWO8yShy1D68ZKBKzDC9mbekQmGPr1tM6vFVaPTxdbt6Pb6qvLzuXL57oRrPmaHrJ9pCGl8qb6WV2uXn8y834NEm"
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- North station.
    local northStation, southStation
    if placedEntitiesByGroup["train-stop"][1].backer_name == "North" then
        northStation = placedEntitiesByGroup["train-stop"][1]
        southStation = placedEntitiesByGroup["train-stop"][2]
    else
        northStation = placedEntitiesByGroup["train-stop"][2]
        southStation = placedEntitiesByGroup["train-stop"][1]
    end

    -- Add the train.
    local carriageLength = #testScenario.trainDetails * 7
    local frontOfTrainPosition = {x = northStation.position.x - 2, y = northStation.position.y + carriageLength}
    local train = TestFunctions.BuildTrain(frontOfTrainPosition, testScenario.trainDetails, defines.direction.south, nil, testScenario.startingSpeed, {name = "rocket-fuel", count = 50})
    train.schedule = {
        current = 1,
        records = {
            {station = "South"},
            {station = "North"}
        }
    }
    train.manual_mode = false

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_BTL_TestScenarioBespokeData
    local testDataBespoke = {
        leavingStateshandled = 0, ---@type uint
        northStationPositionCheck = {x = northStation.position.x - 2, y = northStation.position.y}, ---@type MapPosition
        southStationPositionCheck = {x = southStation.position.x + 2, y = southStation.position.y}, ---@type MapPosition
        northStationTrainIds = {}, ---@type Id[]
        southStationTrainIds = {} ---@type Id[]
    }
    testData.bespoke = testDataBespoke

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

--- Any scheduled events for the test must be Removed here so they stop running. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

--- Scheduled event function to check test state each tick.
---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    -- Get testData object and testName from the event data.
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(testName)
    local testDataBespoke = testData.bespoke ---@type Tests_BTL_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    -- Check that the right number of trains actually went via the stations and didn't just get stuck flipping back and fourth via the tunnel.
    -- Add by train Id as key, then it doesn't matter how many times the same train is detected.
    local northStationTrain = TestFunctions.GetTrainAtPosition(testDataBespoke.northStationPositionCheck)
    if northStationTrain ~= nil then
        testDataBespoke.northStationTrainIds[northStationTrain.id] = true
    end
    local southStationTrain = TestFunctions.GetTrainAtPosition(testDataBespoke.southStationPositionCheck)
    if southStationTrain ~= nil then
        testDataBespoke.southStationTrainIds[southStationTrain.id] = true
    end

    -- Count how many times the train has used the tunnel.
    if tunnelUsageChanges.actions[Common.TunnelUsageAction.leaving] ~= nil and tunnelUsageChanges.actions[Common.TunnelUsageAction.leaving].count > testDataBespoke.leavingStateshandled then
        testDataBespoke.leavingStateshandled = testDataBespoke.leavingStateshandled + 1

        -- See if the test should be over.
        local loopCountNeeded = 7
        if testDataBespoke.leavingStateshandled >= loopCountNeeded then
            -- Check if the required number of trains went through the 2 stations.
            -- We have to do one more tunnel usage than stations reached as we start and end with a tunnel usage, rather than a station visit.
            if Utils.GetTableNonNilLength(testDataBespoke.northStationTrainIds) ~= math.floor(loopCountNeeded / 2) then
                TestFunctions.TestFailed(testName, "train dodn't go through the north station the required count")
                return
            end
            if Utils.GetTableNonNilLength(testDataBespoke.southStationTrainIds) ~= math.floor(loopCountNeeded / 2) then
                TestFunctions.TestFailed(testName, "train dodn't go through the south station the required count")
                return
            end

            TestFunctions.TestCompleted(testName)
            return
        end
    end
end

--- Generate the combinations of different tests required.
---@param testName string
Test.GenerateTestScenarios = function(testName)
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    -- Work out what specific instances of each type to do.
    local trainCompositionsToTest  ---@type Tests_BTL_TrainCompositions
    local startingSpeedsToTest  ---@type Tests_BTL_StartingSpeeds
    if DoSpecificTests then
        -- Adhock testing option.
        trainCompositionsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainCompositions, SpecificTrainCompositionsFilter)
        startingSpeedsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(StartingSpeeds, SpecificStartingSpeedsFilter)
    elseif DoMinimalTests then
        trainCompositionsToTest = {TrainCompositions["<"], TrainCompositions["<>"]}
        startingSpeedsToTest = {StartingSpeeds.full}
    else
        -- Do whole test suite.
        trainCompositionsToTest = TrainCompositions
        startingSpeedsToTest = StartingSpeeds
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, trainComposition in pairs(trainCompositionsToTest) do
        for _, startingSpeed in pairs(startingSpeedsToTest) do
            ---@class Tests_BTL_TestScenario
            local scenario = {
                trainComposition = trainComposition,
                trainDetails = TestFunctions.GetTrainCompositionFromTextualRepresentation(trainComposition),
                startingSpeed = startingSpeed
            }
            table.insert(Test.TestScenarios, scenario)
            Test.RunLoopsMax = Test.RunLoopsMax + 1
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

return Test
