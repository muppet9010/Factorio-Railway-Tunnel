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

local blueprintString = "0eNqtWu2OojAUfZf+hon9pr7KZmIQOy4ZBFPAWWN89y3rbMxGzd7b2z9DBOac0nvO6S16Ydtu9sfQ9hNbX1jbDP3I1j8ubGz3fd0t56bz0bM1ayd/YAXb1s3nfIyfQ912X/V5M81977vydtgchzDV3Wacw0fd+PLYxb8HH8GvBWv7nf/F1vz6XrB4qp1af+P68+G86efD1od4Q8H6+uAfOb7Bfb+LAzkOY0QY+mWIEbU0umDneORWR65dG3xzuywKdqpDW98+8WvxQCj+Qzj6/fIM5TjF6/uf0zN2nswu6ezaJbOrDOw2mV1nYE+vu8nALpPZbQb2dNVVdHaVrjqXgT1ddXyVgT5ddpxnoE/XHc8QdypdeDxD3sl05fEMgScJ0suQeJIgvQyRJwnSy5B5kiC9DKEnCNLLkHoiXXoiQ+oJQpOVIfVEuvSESOoqeXq5xcugm2MjHPZhiEfIU3PCpKtcYyDMvM41hnTnC5NpDAQ52ExDICRAleQBQunpiUfYV9HzLv3JJT3t0l0v6R1eusgkvb9LN5mkd3eElJH05o6Qs5Le2xFWGklv7ThBdPTOjrDSS3rMiXTVKXrOEfoqRQ86QlOp6ElH6KgVPeoI2wlFzzrCXkrRs46wkVT0rCPsohU96wivEBQ96wjvT5RL6SEJr6v0Pd7+PlC5MD9pVKuXk/oMl8NxNQZXwHElBlfCcTkGV4FxrcPgajguqm4Gjouqm4XjoupWwXFRdXNgXIOpmwH7TWHKZsB2U6jRgt2mMZNrwGbTGC0YsNc0RroGbDWNKhnYaRpVMrDRDKpkYJ8ZVMnANjOYklmwywymZBbsMlQmWLDLUBFmwS5DJa4Fuwy1QFiwy1DrmQW7DLX82rvLuqEZDsPUnvwjZiXenPx3GobQRqzvjmz1tlxcfvsxLv8RhubTT+XH7Lvla9TrM2KwD1FtigX7ENVVVWAfoprA6u7Dpg77ofyq9/HeR1AHmv7+FE8NId7Uz133jA9sUFSPXIENWmG0WYEN6jASqcAGdSiJGFgtnclUS/D66FCSBPvSoSQC9qXDSMSBfclXGI04Dsd9LZL3WyRGkPuv5+JG1ofxdkPFlXXCKqeV1fJ6/Q0is0Ty"

---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trainScheduleState
end

---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
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
