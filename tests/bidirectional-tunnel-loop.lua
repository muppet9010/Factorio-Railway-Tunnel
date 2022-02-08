-- Tests that a train can do a figure of 8 smoothly through a single tunnel at speed a few times. Uses some different train compositions to get different tunnel signals being triggered at different speeds. We don't support reserving the same tunnel you are leaving and so the leavng train is just massively slowed down in this edge case.

local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")

---@class Tests_BTL_TrainCompositions
local TrainCompositions = {
    ["<"] = {composition = "<"},
    ["<>"] = {composition = "<>"},
    ["><"] = {composition = "><"}
}
---@class Tests_BTL_StartingSpeeds
local StartingSpeeds = {
    none = 0,
    half = 0.6,
    full = 1.4
}

-- Test configuration.
local DoMinimalTests = false -- The minimal test to prove the concept.

local DoSpecificTests = true -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTrainCompositionsFilter = {"<>"} -- Pass in an array of TrainCompositions keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificStartingSpeedsFilter = {} -- Pass in an array of StartingSpeeds keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.

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
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):        " .. testScenario.trainComposition.composition .. "      speed: " .. testScenario.startingSpeed
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    --Place the tracls, tunnel, stations, etc.
    local blueprint = "0eNq1WcuO2kAQ/Jc5G8nztvmIXHKMIuSFEWsJbGSbTdCKf88Yb8guaXBXdnJCYFHVM64uT5dfxdPuGA5d3Qxi+Srqddv0YvntVfT1tql242/D6RDEUtRD2ItMNNV+/NZV9U6cM1E3m/BTLOU5Y/3lR3VaDcemCbvFoe2Garfqw3YfmmHRD/H69nl4B6rO3zMRr9VDHaaiLl9Oq+a4fwpdZL1ir4/dS9gsLlVl4tD28T9tM5YScRYuE6f44VXE3tRdWE8X3Vj0DaTiQSoaUROI+or4e4n3yiwnUFd+BPUEqOGCWhpTEpiWuZvybfHOzWM6HmZxRSQwPHsDpX7DkRROAdVii4+rswRiCVdmS6oymV+BRpwmNkN7oFDkFSWLlNV0TXyJnfQsKFyJF+jJAhUOZEkgDfWXvekvRUGivRArm21aafEFa3LBDgci1Ss9ZnY2nzc7WcDFGVrAJWpyxs+bnMrx8kj5KglamzHz1qbwnjBkTyiNA5FaUwYHIrWmcPVrUhcKV7+m7yD+END0Zhcz55HQbB6Byo/CiDv+UnV19UAmJXoAus+uPMqu84Tso2/O8cmEfJrBpxLySQafTscnS/humoTsuJZsQnYLs7tPNa6EG1f7e4THOJ50266Nn3+t+eJKq3XX9n3dbB8U5BliK/6lgkcnCwZnmZiT0cQm/687zWhrIz8jLs4S0/kUQzgmnUuVDLZ0riQ59yqdDUmNmoJx6chhCzQ+HTns/qZIRw4/+Ez5mf5U8G228OShyGOrhQdwRZ6jLTxraPJgb+FRQ5OThoUnDfo0buFBgx4PrOMOeOaCYtR8uGPhkYOegSw8ZNNDmYXTJnpKdDlzr8bxe0Qp5jMYB+jcT6iMEMbBqqcHbAerno4RnOHu3JQhciIYB3cAncA4/qStpxTR6vkExsE9QIdXjpm9LvTUn5YTLcP9QCd0HvZ6Otr0sNfTWauHVU+Hyp6vej0lo3Rs7mGvv4Nj4Xro++WYYfkV5Pbh/yc5/9oe6eTcw8K/UywofHdjtobCLLGHnWO8yShy1D68ZKBKzDC9mbekQmGPr1tM6vFVaPTxdbt6Pb6qvLzuXL57oRrPmaHrJ9pCGl8qb6WV2uXn8y834NEm"
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- North station.
    local northStation
    if placedEntitiesByGroup["train-stop"][1].backer_name == "North" then
        northStation = placedEntitiesByGroup["train-stop"][1]
    else
        northStation = placedEntitiesByGroup["train-stop"][2]
    end

    -- Add the train.
    local carriageLength = #testScenario.trainDetails * 7
    local frontOfTrainPosition = {x = northStation.position.x - 2, y = northStation.position.y + carriageLength}
    local train = TestFunctions.BuildTrain(frontOfTrainPosition, testScenario.trainDetails, defines.direction.south, nil, testScenario.startingSpeed, {name = "rocket-fuel", count = 10})
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
        leavingStateshandled = 0 ---@type uint
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

    -- Check that the train does 6 tunnel transitions without issues.
    if tunnelUsageChanges.actions[Common.TunnelUsageAction.leaving] ~= nil and tunnelUsageChanges.actions[Common.TunnelUsageAction.leaving].count > testDataBespoke.leavingStateshandled then
        testDataBespoke.leavingStateshandled = testDataBespoke.leavingStateshandled + 1

        if testDataBespoke.leavingStateshandled >= 6 then
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
