-- Sends a single short train coasting in to a tunnel portal entrance while it is in the differnt schedule states. All should be stopped with the loco at the entrance portal entry point.

local Test = {}
local TestFunctions = require("scripts.test-functions")

---@class Tests_TCTT_TrainScheduleStates
local TrainScheduleStates = {
    manualMode = "manualMode",
    automaticNoSchedule = "automaticNoSchedule"
}

Test.RunTime = 600
Test.RunLoopsMax = 0 -- Populated when script loaded.
---@type Tests_TCTT_TestScenario[]
Test.TestScenarios = {} -- Populated when script loaded.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios() -- Call here so its always populated.
end

local blueprintString = "0eNqtWu2O2jAQfBf/hhP+dniVqkI5sGik4KAkcEWId69ztOKkA3W82V8oJMw4npn1Yvkq3ttTPPZNGsX6Kpptlwax/nEVQ7NPdTt9N16OUaxFM8aDWIhUH6arvm7aj/qyGU8pxXZ57PqxbjdD3B9iGpfDmO/vf43ithBN2sXfYi1vPxci32vGJt4ZPi8um3Q6vMc+P/Af7Jh2mf7YDRmhS9PAMmrIv7qItbWZaNf0cXu/pxbiXPdNfb+St8U3NlX6Jt+pLZFaz6f2RGozn7oiUtvZ1BVVazefWhOp/Xxqqs3CfGqqzar51FSbydVsbrmiGk1KBnKq1aRiIKeaTWoGcqrdpGEgJxtufmGTkmw4x0BONpxnICcbLjCQkw1XMZBTDacYKpwit00MFU5RDacUpUWUiiqzelnUTrmn7fd9lz+RN9bk6TZcIyDPueUaATXpynGNgOwDzzUCcuYDyfmGrDpDgTPU6dYMBc5QZ1ozFDhLjbtmaOEsVXPN0MJZ8n9ihhbOkg3H0MJZsuEYWjhHNhxDC+fIhmNo4RzZcAwVzpG3YRgqnKMazjBUOE81nGGocJ5qOMNQ4TzVcIahwnmy4RgqnCcbjqHCkfd5DUOFC2TDMVQ48jazqUg9I32D91HU/r3OciL+zvFqrXwGKlHQV2vgM1AFg2ocVMOgFgc1MKjHQS0MWiCUQ0F9gVAeBi0QKsCgBUJVMCgulIMTJSv8/Z3EUfEJcApHLZgBjaPiXnVwqtQKN6uzOGqBWg5HLVDL46gFagUctUAtOFpK4mr5FY6Kq+Uljoqr5RWOiqvlNY6Kq+XxbKkCtfBsqQK18GypArUe2Wq7bXfoxuYcn0GGt0p/XWK6vslQfzus1dt0azpzMUw/2HbTWQy7uj0jxGOnCuyBx07h9gh47DRuj/CI3bbu993yo97nZ59gWmDO0zl/1fX5kXRq22d0eB417saA51Hjbgx4HjVujoDnUReYw4EyGsUiI74ImgIv4mk0BebA02hwc1R4Gg1ujgpfBF9t009nxT7Pm62/HE/L/0BjP9wfCNL4SnmrQp5Fdbv9AW8wJEg="

---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trainScheduleState
end

---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the blueprinted entities.
    local train = placedEntitiesByGroup["locomotive"][1].train ---@type LuaTrain
    train.speed = 1.4 -- Max locomotive speed.
    if testScenario.trainScheduleState == "manualMode" then
        train.manual_mode = true
    elseif testScenario.trainScheduleState == "automaticNoSchedule" then
        train.manual_mode = false
        train.schedule = nil
    else
        error("Unsupported trainScheduleState: " .. testScenario.trainScheduleState)
    end

    -- Get the east portal's entry portal end entity.
    local entrancePortalEntryPortalEnd, entrancePortalEntryPortalEndXPos = nil, -100000
    for _, portalEntity in pairs(placedEntitiesByGroup["railway_tunnel-portal_end"]) do
        if portalEntity.position.x > entrancePortalEntryPortalEndXPos then
            entrancePortalEntryPortalEnd = portalEntity
            entrancePortalEntryPortalEndXPos = portalEntity.position.x
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    ---@class Tests_TCTT_TestScenarioBespokeData
    local testDataBespoke = {
        train = train, ---@type LuaTrain
        entrancePortalEntryPortalEnd = entrancePortalEntryPortalEnd ---@type LuaEntity
    }
    testData.bespoke = testDataBespoke

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

---@param testName string
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(testName)
    local testDataBespoke = testData.bespoke ---@type Tests_TCTT_TestScenarioBespokeData

    local train = testDataBespoke.train ---@type LuaTrain
    local entrancePortalEntryPortalEnd = testDataBespoke.entrancePortalEntryPortalEnd ---@type LuaEntity
    if not train.valid then
        TestFunctions.TestFailed(testName, "Train entered the tunnel which it never should")
        return
    end
    local trainFoundAtPortalEntrance = TestFunctions.GetTrainInArea({left_top = {x = entrancePortalEntryPortalEnd.position.x + 3, y = entrancePortalEntryPortalEnd.position.y}, right_bottom = {x = entrancePortalEntryPortalEnd.position.x + 4, y = entrancePortalEntryPortalEnd.position.y}})
    if trainFoundAtPortalEntrance ~= nil and trainFoundAtPortalEntrance.speed == 0 then
        game.print("Train stopped")
        TestFunctions.TestCompleted(testName)
        return
    end
end

Test.GenerateTestScenarios = function()
    local trainScheduleStatesToTest = TrainScheduleStates ---@type Tests_TCTT_TrainScheduleStates
    for _, trainScheduleState in pairs(trainScheduleStatesToTest) do
        ---@class Tests_TCTT_TestScenario
        local scenario = {
            trainScheduleState = trainScheduleState
        }
        Test.RunLoopsMax = Test.RunLoopsMax + 1
        table.insert(Test.TestScenarios, scenario)
    end
end

return Test
