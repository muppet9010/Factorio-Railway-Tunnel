-- Test runs a train through a tunnel multiple times to ensure the cached data behaves correctly. The train does different train direction and train compositions multiple times to cover all angles.

-- Requires and this tests class object.
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Common = require("scripts/common")

---@class Tests_CTD_TrackShapes
local TrackShapes = {
    straight = "straight", -- Shuttle through the tunnel (bi-directional).
    loop = "loop", -- Go through the tunnel in 1 direction with the train maintaining its orientation each loop.
    loopShunt = "loopShunt" -- Go through the tunnel in 1 direction with the train doing a loop back to the starting station, approaching it from the oppositea direction and using it as a shunt before returning to the tunnel. This flips the train on each loop.
}
--- Max tunnel train length is 4 carriages.
---@alias Tests_CTD_TrainCompositions TestFunctions_TrainSpecifiction
local TrainCompositions = {
    ["<>"] = {composition = "<>"},
    ["<<>"] = {composition = "<<>"},
    ["<>>"] = {composition = "<>>"},
    ["><"] = {composition = "><"},
    ["><<"] = {composition = "><<"},
    [">><"] = {composition = ">><"},
    ["<>--"] = {composition = "<>--"},
    ["--<>"] = {composition = "--<>"},
    ["><--"] = {composition = "><--"},
    ["--><"] = {composition = "--><"},
    ["<>=-"] = {composition = "<>=-"},
    ["-=><"] = {composition = "-=><"},
    ["<>-="] = {composition = "<>-="},
    ["=-><"] = {composition = "=-><"},
    ["<->"] = {composition = "<->"},
    ["<=>"] = {composition = "<=>"},
    ["<-->"] = {composition = "<-->"},
    ["<==>"] = {composition = "<==>"},
    [">-<"] = {composition = ">-<"},
    [">=<"] = {composition = ">=<"},
    [">--<"] = {composition = ">--<"},
    [">==<"] = {composition = ">==<"}
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTrackShapesFilter = {} -- Pass in an array of TrackShapes keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificTrainCompositionsFilter = {} -- Pass in an array of TrainCompositions keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 7200
Test.RunLoopsMax = 0
---@type Tests_CTD_TestScenario[]
Test.TestScenarios = {}

--- Any scheduled event types for the test must be Registered here.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName)
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

--- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trackShape .. "    -    " .. testScenario.trainComposition.composition
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local blueprint = "0eNq1WsGO2jAU/Befg4Tt2E5y7zf0UK1QFixqCRyUhLYI8e9NCupuG9rOe3ZPu8Ay42Q88yYrX8Xr4exPfYijaK4ibLs4iObTVQxhH9vD/N54OXnRiDD6oyhEbI/zq74Nh6/tZTOeY/SH1anrx/awGfz+6OO4Gsbp8/3nUdwKEeLOfxONvBVMUB9373DU7aUQE0cYg7+v9MeLyyaej6++n4h+ws2LiNNautNEceqG6StdnMknmFWtC3ERTeUm6F3o/fb+oS3EMLb338VHP8yXsKBQwIqXjObBWC8Yv7R9eHDKJ3SaeteX3GXN5C4zcDsmt8nAbZjcNgM3V2+XgVs+5Vb/5K7SuXXN5K4zcDsmt1xnIOduNikzkHN3m1QZyCWXPEO2KW62yQzhptgbLkO6KcMlzxBvSnPJHWt8Sm6syD9m2nmqFP2+76afiytezX+72fbdMIS4f7Ye9s2vOet5tgKuAmqdawXcMaPkf9GEu0UUs9Exg0dlSD1u4qr00GNTp0ced8ip9MDj2l2l1znujFHpbY7tqPQyJ7n7TKd3Ocl+VkuvcpIbKzq9yUnus5pOjzT2gNfpkaa4g0ynZxq7SOn0UFPsvcYqceyqrt+S7Jcy8Jd/7Px+O5+h1jiqhFHLNYxa1TiqxFEdjqpwVIOjahwVV6sscVSCWgZGdQS1LI5KUMvhqAS1cG85glq4txyulsG9ZXG1DO4ti6tlcG9ZXC2De8viahncW5agFu4tQ1AL95YhqAV7SxNuK2wtTdgBsLM0fvkWNpbGlbKwr0p8U1nYViUulIVdVeJCWdhUJUEo2FMlQSjYUoYgFOwoQxAKdpQhCAU7ihAoDnYUIfsc7ChCTDvYUYSJ4mBHEYafgx1FmNMOdhShUjjYUYT242BHEYqagx1F6JQOdhSh/lawowhNvcLOCzwQa7l4SH87LvChnY8LvBT3Uw3Nu5MV0/Ot74f7NypZulo5I43Udn27fQeXPVbb"
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Test track shape specific extras.
    if testScenario.trackShape == TrackShapes.loop then
        -- Adds a loop back from west to east on the ends of the existing rails making a full circle. Also a second east train station for the new loop direction and a signal to prevent the train reversing from west to east via the tunnel.
        local extraBlueprint = "0eNqVmttu2kAURf9lnk3E3Me85yuqqiJgpZaIQdiJGiH+veZSWhJHXfspIYk3E5bXeOacOZinzWuz27fdYBYH0662XW8W3w6mb5+75eb0s+F915iFaYfmxVSmW76cXu2X7cYcK9N26+aXWdjj98o03dAObXO5/vzi/Uf3+vLU7Mc/uF25et2/NevZOaAyu20/XrPtTm805szqeWXex6/OjeHrdt+sLr9Nx+pTprtl9sMY9/xz+Cq1xGuqv091E6mep3qeGniq5akRp+aapyaemnlq5qkCrcJTBVo1TxVo2TmOTQIua3mswMtyvZIAzHK/kkDMcsGSgowbFhVkXLGoIOOORQUZlywqyLhlUUDmuGVBQOa4ZUFA5rhlQUDmuGVBQOa4ZUFBxi3zCjJumVeQccu8goxb5hVk3DIvIPPcMicg89wyJyDz3DKnLBW5ZU5A5rllTkHGLbMKMm6ZVZBxy6yCjFtmFWTcMisgC9wygVjgkgnAAndM4BW4YspujBum0MKCKaFYL+X/x3IpqLBayl2FxRIEiFgrRdaItVJmloi1UqbBiLVS5uyItVIeMBFrpTwNI/ZKeXRHLJayzojYLGVRFLFaygouYbeU5WbCbilr44TdUhbyCbul7DoSdkvZIiXslrKfS9gtZfOZsFvKTjlht5RtfcJuKTWIjN1SCiYZu6VUdzJ2SylFZeyWUjfL2C2lyJexW0pFMmO3lPJpxm4ptd6M3VIK0xm7pVTRC3ZLKfkX7JbSnijYLamVgt1S2j4Fu6W0qAp2S2mnFeyW0vor2C2lTVmwW0WhVbM+be2m27R+qpkmFDGuH6ut72PzVCxWq47TqXYq1dFGdbqGJhDq4adabplTKUEcWrkfWZjKjNrIPkTGqcgk444gNasHCMAdVMSbHTSOa/WmjP8XyM7nd+cuZtezGZ+fd/OHPzPIQyT96L8KnQbbzfphu/t6Avkwf4yc+2F5+d48LvvBnA6BnI+JLP45VVKZt2bfXwZRbMi1y9FG69P8ePwNsWNCiQ=="
        TestFunctions.BuildBlueprintFromString(extraBlueprint, {x = 0, y = -10}, testName)
    elseif testScenario.trackShape == TrackShapes.loopShunt then
        -- Adds a loop back from west to east, but approaching from the tunnel side. Also a signal to prevent the train reversing from west to east via the tunnel.
        local extraBlueprint = "0eNqVmduOokAUAP+ln9Fw+sIBfmWy2ThKZkkUDeJkjfHf1wtOVpfN1HnUkZrWoqC7Obn39aHZ9W03uPrk2uW227v67eT27Ue3WF/fG467xtWuHZqNy1y32Fxf9Yt27c6Za7tV89vVcv6RuaYb2qFt7sffXhx/dofNe9NfPvB15PLQfzar2Q2Qud12fzlm213/0YUzq8rMHV1d+At71fbN8v7H4pz9g/RfyP1woX38Gv4LDXeoPEP9BDRwqGBoxNCywtDEoYqhBYcmDFUO5aJKDuWiKgxVLkpyTuWmRDiVqxIelXJXwqtSLkt4VoXBFu+qMNjiYRUGW7yswmCLp1UYbPG2ErfleVuJ2/K8rcRted5W4rY8bytxW563FQ22eFvRYIu3FQ22eFvRYIu3FQ22eFuB2wq8rcBtBd5W4LYCbysYJoO8rcBtBd6WN9jibXmDLd6WN9jibXmDLd6WN9jibQm3FXlbwm1F3pZwW5G3JdxW5G2JYaXF2zLI4mkZXPGyDKp4WAZTvCuDKJwVZyYcFf/yCSfFLSUcFD+dEs7JsMOAYzIUmhLbCbqumCY2gsIUkqck+TjS9IzVKaw+7XbNxh2xiVVQnI/y/Tx9v2+VcE+PG8oLVKagFdxgkzzeoeX30AIH5ad/1jQFFStUwUhxUo8JhYKRBiu0AiPFUT0mVBUYaTJCVcBIcVbjhPIVOjlStUIDGGlpPPm1eIbGKSi+Q42z9NeRTn19za1Q0L7iosZVioJM1VuhIFMN7JIa8vGKqjoHV2rFTY2LPwX1a7JCQf1qv1Up6F/V9nil9OBHxbepcZ2OBgpvU4GPs8zhORXGc6qU13PKX59e3Z5v1X89DsvcZ9Pv7x8oJWrlNUmSUOTn8x/wKeqN"
        TestFunctions.BuildBlueprintFromString(extraBlueprint, {x = -24, y = -10}, testName)
    end

    -- Get the 2 train stops.
    local eastTrainStop, westTrainStop
    if placedEntitiesByGroup["train-stop"][1].backer_name == "East" then
        eastTrainStop = placedEntitiesByGroup["train-stop"][1]
        westTrainStop = placedEntitiesByGroup["train-stop"][2]
    else
        eastTrainStop = placedEntitiesByGroup["train-stop"][2]
        westTrainStop = placedEntitiesByGroup["train-stop"][1]
    end

    -- Build the train.
    local trainCarriageDetails = TestFunctions.GetTrainCompositionFromTextualRepresentation(testScenario.trainComposition)
    local leadCarriageFrontPosition = {x = eastTrainStop.position.x - (#trainCarriageDetails * 7), y = eastTrainStop.position.y - 2}
    local train = TestFunctions.BuildTrain(leadCarriageFrontPosition, trainCarriageDetails, defines.direction.west, nil, nil, {name = "rocket-fuel", count = 10})

    -- Set the train running on its schedule.
    train.schedule = {
        current = 1,
        records = {
            {
                station = westTrainStop.backer_name,
                wait_conditions = {
                    {type = "time", compare_type = "or", ticks = 1}
                }
            },
            {
                station = eastTrainStop.backer_name,
                wait_conditions = {
                    {type = "time", compare_type = "or", ticks = 1}
                }
            }
        }
    }
    train.manual_mode = false

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_CTD_TestScenarioBespokeData
    local testDataBespoke = {
        lastActionTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train, 0.75), ---@type TestFunctions_TrainSnapshot
        loopsDone = 0, ---@type uint
        nextAction = Common.TunnelUsageAction.startApproaching, ---@type TunnelUsageAction
        testFinished = false ---@type boolean
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
    --local testScenario = testData.testScenario ---@type Tests_CTD_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_CTD_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    -- Don't react to tunnel usage changes after the test is completed.
    if testDataBespoke.testFinished then
        return
    end

    -- Train has completed the next action.
    if tunnelUsageChanges.lastAction == testDataBespoke.nextAction then
        -- Check trains are the same before and after tunnel usage.

        -- Handle the action and set the next action to react to.
        if tunnelUsageChanges.lastAction == Common.TunnelUsageAction.startApproaching then
            -- Train has started approaching so take a snapshot prior to tunnel usage and wait for the train to leave the tunnel again.
            testDataBespoke.nextAction = Common.TunnelUsageAction.leaving
            testDataBespoke.lastActionTrainSnapshot = TestFunctions.GetSnapshotOfTrain(tunnelUsageChanges.train)
        else
            -- Train has left the tunnel so check its correct structure and then wait for the train to start entering next tunnel.
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(tunnelUsageChanges.train)
            if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.lastActionTrainSnapshot, currentTrainSnapshot, false) then
                TestFunctions.TestFailed(testName, "train snapshots not the same")
                return
            end
            testDataBespoke.nextAction = Common.TunnelUsageAction.startApproaching

            -- Tunnel loop complete, done after 6 cycles as this is 3 times in each direction. First is no cache, second onwards is loading from cache.
            testDataBespoke.loopsDone = testDataBespoke.loopsDone + 1
            if testDataBespoke.loopsDone == 6 then
                TestFunctions.TestCompleted(testName)
                testDataBespoke.testFinished = true
                return
            end
        end
    end
end

--- Generate the combinations of different tests required.
---@param testName string
Test.GenerateTestScenarios = function(testName)
    -- Global test setting used for when wanting to do all variations of lots of test files.
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    -- Work out what specific instances of each type to do.
    local trackShapesToTest  ---@type Tests_CTD_TrackShapes[]
    local trainCompositionsToTest  ---@type Tests_CTD_TrainCompositions[]
    if DoMinimalTests then
        trackShapesToTest = TrackShapes
        trainCompositionsToTest = {TrainCompositions["<>"]}
    elseif DoSpecificTests then
        -- Adhock testing option.
        trackShapesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrackShapes, SpecificTrackShapesFilter)
        trainCompositionsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainCompositions, SpecificTrainCompositionsFilter)
    else
        -- Do whole test suite.
        trackShapesToTest = TrackShapes
        trainCompositionsToTest = TrainCompositions
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, trackShape in pairs(trackShapesToTest) do
        for _, trainComposition in pairs(trainCompositionsToTest) do
            ---@class Tests_CTD_TestScenario
            local scenario = {
                trackShape = trackShape,
                trainComposition = trainComposition
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
