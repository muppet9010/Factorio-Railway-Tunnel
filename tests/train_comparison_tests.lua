-- Tests a lot of variations of trains against the snap shot comparison Test Function. Needed to ensure its accuracy as a lot of other tests rely upon it. Train comparison has a lot of reversal combinations that make the function logic surprisingly complicated.
-- Test with the flipped colors proves limitations with the TestFunctions.AreTrainSnapshotsProbablyIdentical() function not able to distinguish between reversed trains and trains with odd single attributes (color) as the train snapshot is taken with "facingForwards" in relation to the lead carriage in the train.

local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

---@class Tests_TCT_FirstTrain
local FirstTrain = {
    ["<>"] = "<>",
    ["<->"] = "<->",
    ["<=>"] = "<=>",
    ["<--"] = "<--",
    ["--<"] = "--<",
    ["<=="] = "<==",
    ["==<"] = "==<",
    ["><"] = "><",
    [">-<"] = ">-<",
    [">=<"] = ">=<",
    [">--"] = ">--",
    ["-->"] = "-->",
    [">=="] = ">==",
    ["==>"] = "==>"
}

---@class Tests_TCT_SecondTrainCarriageOrder
local SecondTrainCarriageOrder = {
    forward = "forward", -- No change.
    reverse = "reverse" -- Carriages are in reverse order within the train. Like its going backwards.
}

---@class Tests_TCT_SecondTrainCarriageFacing
local SecondTrainCarriageFacing = {
    regular = "regular", -- No change.
    flipped = "flipped" -- Carriages are facing the opposite direction individually.
}

---@class Tests_TCT_SecondTrainCarriageColors
local SecondTrainCarriageColors = {
    followCarriage = "followCarriage" -- Color will stay with the carriage when its position in the train is re-arranged.
    --oppositeCarriage = "oppositeCarriage" -- Color will switch to the opposite to the current carriage's color. - DONT USE as it proves the limitations to the test functions ability to check flipped and mutilated trains.
}

-- Test configuration.
local DoMinimalTests = false -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificFirstTrainFilter = {} -- Pass in an array of FirstTrain keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificSecondTrainCarriageOrderFilter = {} -- Pass in an array of SecondTrainCarriageOrder keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificSecondTrainCarriageFacingFilter = {} -- Pass in an array of SecondTrainCarriageFacing keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificSecondTrainCarriageColorsFilter = {} -- Pass in an array of SecondTrainCarriageColors keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

---@class Tests_TCT_ExpectedOutcome
local ExpectedOutcome = {
    same = "same",
    different = "different"
}

Test.RunTime = 3600
Test.RunLoopsMax = 0
---@type Tests_TCT_TestScenario[]
Test.TestScenarios = {}

--- Any scheduled event types for the test must be Registered here.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick) -- Register for enabling during Start().
    Test.GenerateTestScenarios(testName)
end

--- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):     " .. testScenario.firstTrainString .. "     order: " .. testScenario.secondTrainCarriageOrder .. "     facing: " .. testScenario.secondTrainCarriageFacing .. "     color: " .. testScenario.secondTrainCarriageColors .. "     expected result: " .. testScenario.expectedResult
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
        testFinished = false, ---@type boolean
        doActionTick = nil ---@type uint
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

    -- Wait for 10 ticks before fdoing the test so the onscreen text can appear.
    if testDataBespoke.doActionTick == nil then
        testDataBespoke.doActionTick = event.tick + 10
        return
    end
    if event.tick < testDataBespoke.doActionTick then
        return
    end

    -- Checking if comparison matches the expected outcome.
    local train1Snapshot = Test.MakeTrainSnapshotFromShorthand(testScenario.firstTrainShorthand)
    local train2Shanpshot = Test.MakeTrainSnapshotFromShorthand(testScenario.secondTrainShorthand)
    local comparisonResult = TestFunctions.AreTrainSnapshotsProbablyIdentical(train1Snapshot, train2Shanpshot, false)
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
        TestFunctions.TestFailed(testName, "got: " .. comparisonResultText)
    end
    testDataBespoke.testFinished = true
end

--- Generate the combinations of different tests required.
---@param testName string
Test.GenerateTestScenarios = function(testName)
    -- Global test setting used for when wanting to do all variations of lots of test files.
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    -- Work out what specific instances of each type to do.
    local firstTrainToTest  ---@type Tests_TCT_FirstTrain[]
    local secondTrainCarriageOrderToTest  ---@type Tests_TCT_SecondTrainCarriageOrder[]
    local secondTrainCarriageFacingToTest  ---@type Tests_TCT_SecondTrainCarriageFacing[]
    local secondTrainCarriageColorsToTest  ---@type Tests_TCT_SecondTrainCarriageColors[]
    if DoMinimalTests then
        -- Do all combinations as this working is so critical and really quick.
        firstTrainToTest = FirstTrain
        secondTrainCarriageOrderToTest = SecondTrainCarriageOrder
        secondTrainCarriageFacingToTest = SecondTrainCarriageFacing
        secondTrainCarriageColorsToTest = SecondTrainCarriageColors
    elseif DoSpecificTests then
        -- Adhock testing option.
        firstTrainToTest = TestFunctions.ApplySpecificFilterToListByKeyName(FirstTrain, SpecificFirstTrainFilter)
        secondTrainCarriageOrderToTest = TestFunctions.ApplySpecificFilterToListByKeyName(SecondTrainCarriageOrder, SpecificSecondTrainCarriageOrderFilter)
        secondTrainCarriageFacingToTest = TestFunctions.ApplySpecificFilterToListByKeyName(SecondTrainCarriageFacing, SpecificSecondTrainCarriageFacingFilter)
        secondTrainCarriageColorsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(SecondTrainCarriageColors, SpecificSecondTrainCarriageColorsFilter)
    else
        -- Do whole test suite.
        firstTrainToTest = FirstTrain
        secondTrainCarriageOrderToTest = SecondTrainCarriageOrder
        secondTrainCarriageFacingToTest = SecondTrainCarriageFacing
        secondTrainCarriageColorsToTest = SecondTrainCarriageColors
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, firstTrain in pairs(firstTrainToTest) do
        -- Make the first train shorthand from the composition.
        ---@type Tests_TCT_TrainCarriageShorthand[]
        local firstTrainShorthand = {}
        for i = 1, #firstTrain do
            local text = string.sub(firstTrain, i, i)
            ---@type Tests_TCT_TrainCarriageShorthand
            local firstTrainCarriageShorthand = {
                typeChar = text,
                colorNumber = i
            }
            table.insert(firstTrainShorthand, firstTrainCarriageShorthand)
        end

        -- Loop over the other settings.
        for _, secondTrainCarriageOrder in pairs(secondTrainCarriageOrderToTest) do
            for _, secondTrainCarriageFacing in pairs(secondTrainCarriageFacingToTest) do
                for _, secondTrainCarriageColors in pairs(secondTrainCarriageColorsToTest) do
                    -- Work out the second train from the first and the manipulation settings.
                    ---@type Tests_TCT_TrainCarriageShorthand[]
                    local secondTrainShorthand = Utils.DeepCopy(firstTrainShorthand) -- Start with a clone of the first trains data.
                    if secondTrainCarriageOrder == SecondTrainCarriageOrder.reverse then
                        local newSecondTrain = {}
                        for i, carriage in pairs(secondTrainShorthand) do
                            local newI = (#secondTrainShorthand - i) + 1
                            newSecondTrain[newI] = carriage
                        end
                        secondTrainShorthand = newSecondTrain
                    end
                    if secondTrainCarriageFacing == SecondTrainCarriageFacing.flipped then
                        for i, carriage in pairs(secondTrainShorthand) do
                            if carriage.typeChar == "<" then
                                carriage.typeChar = ">"
                            elseif carriage.typeChar == ">" then
                                carriage.typeChar = "<"
                            elseif carriage.typeChar == "-" then
                                carriage.typeChar = "="
                            elseif carriage.typeChar == "=" then
                                carriage.typeChar = "-"
                            else
                                error("unsupported carriage.typeChar: " .. tostring(carriage.typeChar))
                            end
                        end
                    end
                    -- Code not used due to limitations in trian snapshot handling manipulated individual values, see comment at top of file.
                    --[[if secondTrainCarriageColors == SecondTrainCarriageColors.oppositeCarriage then
                        for i, carriage in pairs(secondTrainShorthand) do
                            carriage.colorNumber = (#secondTrainShorthand - i) + 1
                        end
                    end]]
                    -- Work out the expected result for each combination. Same ones are identical and when the carriages are all in reverse order (colors stay with carriage) and the carriages all face reverse.
                    ---@type Tests_TCT_ExpectedOutcome
                    local expectedResult
                    if secondTrainCarriageOrder == SecondTrainCarriageOrder.forward and secondTrainCarriageFacing == SecondTrainCarriageFacing.regular and secondTrainCarriageColors == SecondTrainCarriageColors.followCarriage then
                        -- All teh same as first train.
                        expectedResult = ExpectedOutcome.same
                    elseif secondTrainCarriageOrder == SecondTrainCarriageOrder.reverse and secondTrainCarriageFacing == SecondTrainCarriageFacing.flipped and secondTrainCarriageColors == SecondTrainCarriageColors.followCarriage then
                        -- Train carriage order reversed and backwards facing, but colors remain with carriages.
                        expectedResult = ExpectedOutcome.same
                    else
                        -- All of manipulations in any combination.
                        expectedResult = ExpectedOutcome.different
                    end

                    ---@class Tests_TCT_TestScenario
                    local scenario = {
                        firstTrainString = firstTrain,
                        firstTrainShorthand = firstTrainShorthand,
                        secondTrainShorthand = secondTrainShorthand,
                        secondTrainCarriageOrder = secondTrainCarriageOrder,
                        secondTrainCarriageFacing = secondTrainCarriageFacing,
                        secondTrainCarriageColors = secondTrainCarriageColors,
                        expectedResult = expectedResult
                    }
                    table.insert(Test.TestScenarios, scenario)
                    Test.RunLoopsMax = Test.RunLoopsMax + 1
                end
            end
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

---@class Tests_TCT_TrainCarriageShorthand
---@field typeChar "<"|">"|"-"|"="
---@field colorNumber uint @ Color is just its order in the first train. As this is saved in to the carriage it will follow the carraige when the second trian has its carriages moved around.

--- Converts shorthand in to a valid train snapshot for comparison.
--- This can't be run during OnStartup as it references "game" so has to be called from OnTick.
---@param trainCarriagesShorthand Tests_TCT_TrainCarriageShorthand[]
---@return TestFunctions_TrainSnapshot trainSnapshot
Test.MakeTrainSnapshotFromShorthand = function(trainCarriagesShorthand)
    local trainSnapshot = {carriages = {}}

    for _, carriageShorthand in pairs(trainCarriagesShorthand) do
        local carriageName
        if carriageShorthand.typeChar == "<" or carriageShorthand.typeChar == ">" then
            carriageName = "locomotive"
        elseif carriageShorthand.typeChar == "-" or carriageShorthand.typeChar == "=" then
            carriageName = "cargo-wagon"
        else
            error("unsupported carriageShorthand.typeChar: " .. tostring(carriageShorthand.typeChar))
        end

        local facingForwards
        if carriageShorthand.typeChar == "<" or carriageShorthand.typeChar == "-" then
            facingForwards = true
        elseif carriageShorthand.typeChar == ">" or carriageShorthand.typeChar == "=" then
            facingForwards = false
        else
            error("unsupported carriageShorthand.typeChar: " .. tostring(carriageShorthand.typeChar))
        end

        table.insert(
            trainSnapshot.carriages,
            {
                name = carriageName,
                facingForwards = facingForwards,
                color = game.table_to_json({r = carriageShorthand.colorNumber, g = carriageShorthand.colorNumber, b = carriageShorthand.colorNumber, a = carriageShorthand.colorNumber})
            }
        )
    end

    return trainSnapshot
end

return Test
