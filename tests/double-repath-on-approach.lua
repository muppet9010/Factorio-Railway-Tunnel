--[[
    The train approaches the tunnel and when it passes and triggers the first circuit connected signal to red, the active target station changes. The station after the tunnel is turned off and the station on the siding below is activated, both with the same name.
    Then when the train passes in to (triggers) the second circuit connected signal the stations switch back, routing the train back through the tunnel.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")

Test.RunTime = 1800

---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString = "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"

---@param testName string
Test.Start = function(testName)
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 50, y = 60}, testName)

    -- Get the stations placed by name.
    local stationSouths, stationNorth = {}, nil
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "South" then
            table.insert(stationSouths, stationEntity)
        elseif stationEntity.backer_name == "North" then
            stationNorth = stationEntity
        end
    end
    local stationSouthEndViaTunnel, stationSouthEndNotTunnel
    if stationSouths[1].position.x < stationSouths[2].position.x then
        stationSouthEndViaTunnel = stationSouths[1]
        stationSouthEndNotTunnel = stationSouths[2]
    else
        stationSouthEndViaTunnel = stationSouths[2]
        stationSouthEndNotTunnel = stationSouths[1]
    end

    local repathTrain = placedEntitiesByGroup["locomotive"][1].train

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.bespoke = {
        stationSouthReached = false,
        stationNorthReached = false,
        repathTrain = repathTrain,
        repathTrainSnapshot = TestFunctions.GetSnapshotOfTrain(repathTrain),
        stationSouthEndViaTunnel = stationSouthEndViaTunnel,
        stationSouthEndNotTunnel = stationSouthEndNotTunnel,
        stationNorth = stationNorth
    }

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

---@param testName string
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(event.instanceId)
    local testDataBespoke = testData.bespoke
    local stationSouthEndViaTunnelTrain, stationSouthEndNotTunnelTrain, stationNorthTrain = testDataBespoke.stationSouthEndViaTunnel.get_stopped_train(), testDataBespoke.stationSouthEndNotTunnel.get_stopped_train(), testDataBespoke.stationNorth.get_stopped_train()

    if stationSouthEndViaTunnelTrain ~= nil and not testDataBespoke.stationSouthReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationSouthEndViaTunnelTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.repathTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train at south station has differences")
            return
        end
        game.print("train reached tunnel usage south station")
        testDataBespoke.stationSouthReached = true
    end
    if stationSouthEndNotTunnelTrain ~= nil then
        -- The train should never reach this specific station as it should use the tunnel.
        TestFunctions.TestFailed(testName, "train didn't use tunnel and reached wrong south station")
        return
    end
    if stationNorthTrain ~= nil and not testDataBespoke.stationNorthReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationNorthTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.repathTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train at north station has differences")
            return
        end
        game.print("train reached north station")
        testDataBespoke.stationNorthReached = true
    end

    if testDataBespoke.stationSouthReached and testDataBespoke.stationNorthReached then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
