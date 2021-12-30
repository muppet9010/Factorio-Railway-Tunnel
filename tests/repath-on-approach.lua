--[[
    The shuttle train initially tries to go through the tunnel, but when it reaches the signal before the siding the stations switch so that it repathes and decides to not go through the tunnel after all.
    The loop train is there to test that the tunnel is properly cleared for the next crossing when a train already on the approach repathes away from the tunnel.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString = "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"

Test.Start = function(testName)
    local _, placedEntitiesByType, placedEntitiesByType = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 60, y = 60}, testName)

    -- Get the stations placed by name. There are 2 stations with the same name "Repathed-End" that are sorted by relative map position.
    local stationRepaths, stationLoopEnd = {}, nil
    for _, stationEntity in pairs(placedEntitiesByType["train-stop"]) do
        if stationEntity.backer_name == "Repathed-End" then
            table.insert(stationRepaths, stationEntity)
        elseif stationEntity.backer_name == "Loop-2" then
            stationLoopEnd = stationEntity
        end
    end
    local stationRepathEndViaTunnel, stationRepathEndNotTunnel
    if stationRepaths[1].position.x < stationRepaths[2].position.x then
        stationRepathEndViaTunnel = stationRepaths[1]
        stationRepathEndNotTunnel = stationRepaths[2]
    else
        stationRepathEndViaTunnel = stationRepaths[2]
        stationRepathEndNotTunnel = stationRepaths[1]
    end

    -- Get the trains - Repath train is most east in BP - Loop train is most west in BP.
    local eastMostLoco, eastMostLocoXPos, westMostLoco, westMostLocoXPos = nil, -100000, nil, 100000
    for _, locoEntity in pairs(placedEntitiesByType["locomotive"]) do
        if locoEntity.position.x > eastMostLocoXPos then
            eastMostLoco = locoEntity
            eastMostLocoXPos = locoEntity.position.x
        end
        if locoEntity.position.x < westMostLocoXPos then
            westMostLoco = locoEntity
            westMostLocoXPos = locoEntity.position.x
        end
    end
    local repathTrain, loopTrain = eastMostLoco.train, westMostLoco.train

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationLoopEndReached = false
    testData.stationRepathEndNotTunnelReached = false
    testData.repathTrain = repathTrain
    testData.loopTrainSnapshot = TestFunctions.GetSnapshotOfTrain(loopTrain)
    testData.stationRepathEndViaTunnel = stationRepathEndViaTunnel
    testData.stationRepathEndNotTunnel = stationRepathEndNotTunnel
    testData.stationLoopEnd = stationLoopEnd

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local repathTrain, stationRepathEndViaTunnelTrain, stationRepathEndNotTunnelTrain, stationLoopEndTrain = testData.repathTrain, testData.stationRepathEndViaTunnel.get_stopped_train(), testData.stationRepathEndNotTunnel.get_stopped_train(), testData.stationLoopEnd.get_stopped_train()

    if repathTrain == nil or not repathTrain.valid then
        -- The train should never change as it shouldn't use the tunnel.
        TestFunctions.TestFailed(testName, "train changed/removed")
        return
    end

    if stationRepathEndNotTunnelTrain ~= nil and not testData.stationRepathEndNotTunnelReached then
        game.print("repathed train reached non tunnel usage end station")
        testData.stationRepathEndNotTunnelReached = true
    end
    if stationRepathEndViaTunnelTrain ~= nil then
        -- The train should never reach this specific station as it shouldn't use the tunnel. The loop train doesn't stop at this station.
        TestFunctions.TestFailed(testName, "repathed train used tunnel and reached wrong station")
        return
    end
    if stationLoopEndTrain ~= nil and not testData.stationLoopEndReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationLoopEndTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.loopTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "loop train has differences after tunnel use")
            return
        end
        game.print("loop train reached post tunnel station")
        testData.stationLoopEndReached = true
    end

    if testData.stationRepathEndNotTunnelReached and testData.stationLoopEndReached then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
