--[[
    The shuttle train initially tries to go through the tunnel, but when it reaches the signal before the siding the stations switch so that it repathes and decides to not go through the tunnel after all.
    The loop train is there to test that the tunnel is properly cleared for the next crossing when a train already on the approach repathes away from the tunnel.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString =
    "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"

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations placed by name.
    local stationRepaths, stationRepathEndViaTunnel, startionRepathEndNotTunnel, stationLoopEnd = {}
    for _, stationEntityIndex in pairs(Utils.GetTableKeysWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        local stationEntity = builtEntities[stationEntityIndex]
        if stationEntity.backer_name == "Repathed-End" then
            table.insert(stationRepaths, stationEntity)
        elseif stationEntity.backer_name == "Loop-2" then
            stationLoopEnd = stationEntity
        end
    end
    if stationRepaths[1].position.x < stationRepaths[2].position.x then
        stationRepathEndViaTunnel = stationRepaths[1]
        startionRepathEndNotTunnel = stationRepaths[2]
    else
        stationRepathEndViaTunnel = stationRepaths[2]
        startionRepathEndNotTunnel = stationRepaths[1]
    end

    -- Get the repathing train - its the most east one in the BP.
    local eastMostLoco, eastMostLocoXPos, westMostLoco, westMostLocoXPos = nil, -100000, nil, 100000
    for _, locoEntityIndex in pairs(Utils.GetTableKeysWithInnerKeyValue(builtEntities, "name", "locomotive")) do
        local locoEntity = builtEntities[locoEntityIndex]
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
    testData.startionRepathEndNotTunnelReached = false
    testData.repathTrain = repathTrain
    testData.loopTrainSnapshot = TestFunctions.GetSnapshotOfTrain(loopTrain)
    testData.stationRepathEndViaTunnel = stationRepathEndViaTunnel
    testData.startionRepathEndNotTunnel = startionRepathEndNotTunnel
    testData.stationLoopEnd = stationLoopEnd
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local repathTrain, stationRepathEndViaTunnelTrain, startionRepathEndNotTunnelTrain, stationLoopEndTrain = testData.repathTrain, testData.stationRepathEndViaTunnel.get_stopped_train(), testData.startionRepathEndNotTunnel.get_stopped_train(), testData.stationLoopEnd.get_stopped_train()

    if repathTrain == nil or not repathTrain.valid then
        -- The train should never change as it shouldn't use the tunnel.
        TestFunctions.TestFailed(testName, "train changed/removed")
        return
    end

    if startionRepathEndNotTunnelTrain ~= nil and not testData.startionRepathEndNotTunnelReached then
        game.print("repathed train reached non tunnel usage end station")
        testData.startionRepathEndNotTunnelReached = true
    end
    if stationRepathEndViaTunnelTrain ~= nil then
        -- The train should never reach this specific station as it shouldn't use the tunnel. The loop train doesn't stop at this station.
        TestFunctions.TestFailed(testName, "train used tunnel and reached wrong station")
        return
    end
    if stationLoopEndTrain ~= nil and not testData.stationLoopEndReached then
        game.print("loop train reached post tunnel station")
        testData.stationLoopEndReached = true
    end

    if testData.startionRepathEndNotTunnelReached and testData.stationLoopEndReached then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
