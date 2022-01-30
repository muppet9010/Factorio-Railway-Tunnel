-- Tests a lot of variations of trains against the snap shot comparison Test Function. Needed to ensure its accuracy as a lot of other tests rely upon it. Train comparison has a lot of reversal combinations that make the function logic surprisingly complicated.

local Test = {}
local TestFunctions = require("scripts/test-functions")

---@class Tests_TCT_ExpectedOutcome
local ExpectedOutcome = {
    same = "same",
    different = "different"
}

---@class Tests_TCT_CombinationToTest
---@field train1Carriages Tests_TCT_TrainCarriageShorthand[]
---@field train2Carriages Tests_TCT_TrainCarriageShorthand[]
---@field expectedResult Tests_TCT_ExpectedOutcome

---@alias Tests_TCT_TrainCarriageShorthand table @ First value = carriage type       Second value = unique color number

--TODO: generate the variations programatically as theres more than first thought. Valid ones are identical and then the carriages are all in reverse order (colors stay with carriage) and the carriages all face reverse. Invalid combinations are reverse order, face reverse, color swapped in any combination other than the valid one listed.
---@type Tests_TCT_CombinationToTest[]
local CombinationsToTest = {
    ["<>1"] = {
        train1Carriages = {
            {"<", 1},
            {">", 2}
        },
        train2Carriages = {
            {"<", 1},
            {">", 2}
        },
        expectedResult = ExpectedOutcome.same
    },
    ["<>2"] = {
        train1Carriages = {
            {"<", 1},
            {">", 2}
        },
        train2Carriages = {
            {"<", 2},
            {">", 1}
        },
        expectedResult = ExpectedOutcome.same
    },
    ["<>3"] = {
        train1Carriages = {
            {"<", 1},
            {">", 2}
        },
        train2Carriages = {
            {">", 1},
            {"<", 2}
        },
        expectedResult = ExpectedOutcome.different
    },
    ["<>4"] = {
        train1Carriages = {
            {"<", 1},
            {">", 2}
        },
        train2Carriages = {
            {">", 2},
            {"<", 1}
        },
        expectedResult = ExpectedOutcome.different
    },
    ["<>5"] = {
        train1Carriages = {
            {"<", 1},
            {">", 2}
        },
        train2Carriages = {
            {">", 1},
            {"<", 2}
        },
        expectedResult = ExpectedOutcome.different
    },
    ["<--1"] = {
        train1Carriages = {
            {"<", 1},
            {"-", 2},
            {"-", 3}
        },
        train2Carriages = {
            {"<", 1},
            {"-", 2},
            {"-", 3}
        },
        expectedResult = ExpectedOutcome.same
    },
    ["<--2"] = {
        train1Carriages = {
            {"<", 1},
            {"-", 2},
            {"-", 3}
        },
        train2Carriages = {
            {"=", 3},
            {"=", 2},
            {">", 1}
        },
        expectedResult = ExpectedOutcome.same
    },
    ["<--3"] = {
        train1Carriages = {
            {"<", 1},
            {"-", 2},
            {"-", 3}
        },
        train2Carriages = {
            {"-", 3},
            {"-", 2},
            {"<", 1}
        },
        expectedResult = ExpectedOutcome.different
    },
    ["<--4"] = {
        train1Carriages = {
            {"<", 1},
            {"-", 2},
            {"-", 3}
        },
        train2Carriages = {
            {">", 1},
            {"-", 2},
            {"-", 3}
        },
        expectedResult = ExpectedOutcome.different
    },
    ["<--5"] = {
        train1Carriages = {
            {"<", 1},
            {"-", 2},
            {"-", 3}
        },
        train2Carriages = {
            {"=", 3},
            {"=", 2},
            {">", 1}
        },
        expectedResult = ExpectedOutcome.same
    },
    ["<--6"] = {
        train1Carriages = {
            {"<", 1},
            {"-", 2},
            {"-", 3}
        },
        train2Carriages = {
            {"=", 3},
            {"=", 2},
            {"<", 1}
        },
        expectedResult = ExpectedOutcome.different
    },
    ["color1"] = {
        train1Carriages = {
            {"-", 1},
            {"<", 2},
            {"-", 3}
        },
        train2Carriages = {
            {"-", 1},
            {"<", 4},
            {"-", 3}
        },
        expectedResult = ExpectedOutcome.different
    },
    ["color2"] = {
        train1Carriages = {
            {"-", 1},
            {"<", 2},
            {"-", 3}
        },
        train2Carriages = {
            {"-", 3},
            {">", 4},
            {"-", 1}
        },
        expectedResult = ExpectedOutcome.different
    },
    ["color3"] = {
        train1Carriages = {
            {"-", 1},
            {"<", 2},
            {"-", 3}
        },
        train2Carriages = {
            {"=", 3},
            {">", 2},
            {"=", 1}
        },
        expectedResult = ExpectedOutcome.same
    },
    ["color4"] = {
        train1Carriages = {
            {"-", 1},
            {"<", 2},
            {"-", 3}
        },
        train2Carriages = {
            {"=", 3},
            {">", 4},
            {"=", 1}
        },
        expectedResult = ExpectedOutcome.different
    }
    --[[
        ,{
            train1Carriages = {},
            train2Carriages = {},
            expectedResult = ExpectedOutcome.x
        }
        ]]
}

-- Test configuration.
local DoSpecificTests = true -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificCombinationsToTestIndexFilter = {} -- Pass in an array of CombinationsToTest index keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.

Test.RunTime = 3600
Test.RunLoopsMax = 0
---@type Tests_TCT_TestScenario[]
Test.TestScenarios = {}

--- Any scheduled event types for the test must be Registered here.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick) -- Register for enabling during Start().
    Test.GenerateTestScenarios()
end

--- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):     " .. testScenario.trainsComparedString .. "     expected result: " .. testScenario.expectedResult
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_TCT_TestScenarioBespokeData
    local testDataBespoke = {
        testFinished = false ---@type boolean
    }
    testData.bespoke = testDataBespoke

    -- Schedule the EveryTick() to run each game tick.
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
    local testScenario = testData.testScenario ---@type Tests_TCT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_TCT_TestScenarioBespokeData

    -- Check if test finished already.
    if testDataBespoke.testFinished then
        return
    end

    -- Checking if comparison matches the expected outcome.
    local train1Snapshot = Test.MakeTrainSnapshotFromShorthand(testScenario.train1Carriages)
    local train2Shanpshot = Test.MakeTrainSnapshotFromShorthand(testScenario.train2Carriages)
    local comparisonResult = TestFunctions.AreTrainSnapshotsIdentical(train1Snapshot, train2Shanpshot, false)
    local expectedSame = testScenario.expectedResult == ExpectedOutcome.same
    if comparisonResult == expectedSame then
        TestFunctions.TestCompleted(testName)
    else
        local comparisonResultText
        if comparisonResult then
            comparisonResultText = ExpectedOutcome.same
        else
            comparisonResultText = ExpectedOutcome.different
        end
        TestFunctions.TestFailed(testName, "expected '" .. testScenario.expectedResult .. "'    but got '" .. comparisonResultText .. "'")
    end
    testDataBespoke.testFinished = true
end

--- Generate the combinations of different tests required.
Test.GenerateTestScenarios = function()
    -- Work out what specific instances of each type to do.
    local combinationToTest  ---@type Tests_TCT_CombinationToTest[]
    if DoSpecificTests then
        -- Adhock testing option.
        combinationToTest = TestFunctions.ApplySpecificFilterToListByKeyName(CombinationsToTest, SpecificCombinationsToTestIndexFilter)
    else
        -- Do whole test suite.
        combinationToTest = CombinationsToTest
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, combination in pairs(combinationToTest) do
        local trainsComparedString = ""
        for _, carriageDetails in pairs(combination.train1Carriages) do
            trainsComparedString = trainsComparedString .. carriageDetails[1] .. tostring(carriageDetails[2]) .. " "
        end
        trainsComparedString = trainsComparedString .. "  vs   "
        for _, carriageDetails in pairs(combination.train2Carriages) do
            trainsComparedString = trainsComparedString .. carriageDetails[1] .. tostring(carriageDetails[2]) .. " "
        end

        ---@class Tests_TCT_TestScenario
        local scenario = {
            train1Carriages = combination.train1Carriages,
            train2Carriages = combination.train2Carriages,
            expectedResult = combination.expectedResult,
            trainsComparedString = trainsComparedString
        }
        table.insert(Test.TestScenarios, scenario)
        Test.RunLoopsMax = Test.RunLoopsMax + 1
    end
end

--- Converts shorthand in to a valid train snapshot for comparison.
--- This can't be run during OnStartup as it references "game" so has to be called from OnTick.
---@param trainCarriagesShorthand Tests_TCT_TrainCarriageShorthand[]
---@return TestFunctions_TrainSnapshot trainSnapshot
Test.MakeTrainSnapshotFromShorthand = function(trainCarriagesShorthand)
    local trainSnapshot = {carriages = {}}

    for _, carriageShorthand in pairs(trainCarriagesShorthand) do
        local carriageName
        if carriageShorthand[1] == "<" or carriageShorthand[1] == ">" then
            carriageName = "locomotive"
        else
            carriageName = "cargo-wagon"
        end

        local facingForwards
        if carriageShorthand[1] == "<" or carriageShorthand[1] == "-" then
            facingForwards = true
        else
            facingForwards = false
        end

        table.insert(
            trainSnapshot.carriages,
            {
                name = carriageName,
                facingForwards = facingForwards,
                color = game.table_to_json({r = carriageShorthand[2], g = carriageShorthand[2], b = carriageShorthand[2], a = carriageShorthand[2]})
            }
        )
    end

    trainSnapshot.carriageCount = #trainSnapshot.carriages

    return trainSnapshot
end

return Test
