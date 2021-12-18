-- Sends a single short train coasting in to a tunnel portal entrance while it is in the differnt mod handled schedule states. All should be stopped at portal entrance.

local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 600
Test.RunLoopsMax = 0 -- Populated when script loaded.
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        trainScheduleState = the TrainScheduleStates of this test.
    }
]]
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios() -- Call here so its always populated.
end

local blueprintString = "0eNqtl91u4yAUhN+Fa7sKPzaxX2UVRdShKVoMFsbpRpHfvbiumkp11WHVm0RgNOeEmS+YG3m0kx6CcZG0N2I670bS/rmR0ZydsstcvA6atMRE3ZOCONUvo6CMfVHXY5yc07Zcv46DD1HZ4ziFJ9XpcrDps9dJei6IcSf9j7R0PhQkTZlo9FrpbXA9uql/1CEt+I8ap9TY4Mek6d3ScqpTVrIgV9LyJtU+maC79WFdkIsKRq0jOhdfGmC/1MB2ffZjff5Rf4ypg/NzLJdGNirQHd2usaEqYNWmgUUrXFTCojUuWsGiEhflsOgeF8WNamDRPW4U3eGquFOU4qq4VZThqrhXFMaKZmwrTBXDA0BhqljGz4epYhlOwVSxjFDBVLEMo2CqOG4Ug6HiuFEMZorjRjEYKY4bxWCiOG4Ug4kSGUbBRIkMo2CiRIZRMFEiwyiYKJFhFExUhRvF70RZ3/neR3PRG4rioeHy0676YJLS+zvV7mF5tLyujsv64Lu/OpZPk7bLOThvlYWZq/B8cJi5Cs8Hh5mr8HzwO3OdCmdfvqhzWvtFsqbAtrtLmvIhLXGTtVvVYBgrPI0chrHOSCMMY50RCxjGOiMWDejg/jccFPC5V+MhFDCDNR4LATMoM25SMIMSj4WAzz35XSwO659eUrhf6dNlU4dxXbCnQjZM8kZSSfk8vwI4d0jv"

local TrainScheduleStates = {
    manualMode = "manualMode",
    automaticNoSchedule = "automaticNoSchedule"
}

Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trainScheduleState
end

Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 40, y = 70}, testName)

    -- Get the blueprinted entities.
    local train = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive", false, false).train ---@type LuaTrain
    train.speed = 2
    if testScenario.trainScheduleState == "manualMode" then
        train.manual_mode = true
    elseif testScenario.trainScheduleState == "automaticNoSchedule" then
        train.manual_mode = false
        train.schedule = nil
    else
        error("Unsupported trainScheduleState: " .. testScenario.trainScheduleState)
    end

    -- Get the portals.
    local entrancePortal, entrancePortalXPos = nil, -100000
    ---@typelist uint, LuaEntity
    for _, portalEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "railway_tunnel-tunnel_portal_surface", true, false)) do
        if portalEntity.position.x > entrancePortalXPos then
            entrancePortal = portalEntity
            entrancePortalXPos = portalEntity.position.x
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.train = train
    testData.entrancePortal = entrancePortal

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    ---@typelist LuaTrain, LuaEntity
    local train, entrancePortal = testData.train, testData.entrancePortal
    if not train.valid then
        TestFunctions.TestFailed(testName, "Train entered the tunnel which it never should")
        return
    end
    local trainFoundAtPortalEntrance = TestFunctions.GetTrainInArea({left_top = {x = entrancePortal.position.x + 27, y = entrancePortal.position.y}, right_bottom = {x = entrancePortal.position.x + 28, y = entrancePortal.position.y}})
    if trainFoundAtPortalEntrance ~= nil and trainFoundAtPortalEntrance.speed == 0 then
        game.print("Train stopped")
        TestFunctions.TestCompleted(testName)
    end
end

Test.GenerateTestScenarios = function()
    for _, trainScheduleState in pairs(TrainScheduleStates) do
        local scenario = {
            trainScheduleState = trainScheduleState
        }
        Test.RunLoopsMax = Test.RunLoopsMax + 1
        table.insert(Test.TestScenarios, scenario)
    end
end

return Test
