-- Sends a short train across a tunnel pathing to a rail, rather than station.

local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 1800

---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString = "0eNqtW9tu4zYQ/Rc924V4J/MrxSJQHK4rrCwZspxtEPjfS8VbJNs46RzOvESwLJyhdC7iMPRL8zCc83Hux6W5e2n63TSemrs/X5pTvx+7YT23PB9zc9f0Sz40m+ah2/04H8vnueuHn93z/XIexzxsr4f74zQv3XB/Os/fu13eHofy95AL+GXT9ONj/ru5U5dvm6ac6pc+X2u9fni+H8+HhzyXCzbN2B3yxxq/wPP4WAZynE4FYRrXIRbUrU2b5rkcVWtKrcd+zrvr13rTPHVz310/qcvmQ0H9PwVPeb/ew/a0lO/3fy23qrvq6kaguqmubgWqq+rqjl/d1PPuBaqH6upBoHq96qJA9XrVJYHq9apTLb+8rpedUgLl63WnBOJO1wtPCeSdrleeEgg8zZCeQOIphvQEIk8xpCeQeYohPYHQUwzpCaSeqpeeFkg9xhxLIPTqhad11Zyynmv9acqdyyx43s9TORLumUG3lRkB4xk4mRHUG157mREwhBdkRsAwXhRSIkOKSWgI9Vo0rdAQGH2eEhpCvRqNFhpCvRyNUDAy5mBGKBkZs1AjFI2MebgRykZGJ2KEwpHRixmhdGR0o0YoHRntuBVKR8Z6hK1a9WMs/lh+G8xZduN3wYwlR8tvgm297S2/B2Ys9lp+C+zqzW75HbBjqI7fADuG6vj9r6tXneO3v65edY7f/nrGMjs/63y96hw/63y96hw/6zxDdfys8wzV8bMuMFTHz7rAUB0/6wJDdfysC/Wq8/ysC4x/q/GzLtarzlct9cV6qv1bvP17Q9u18q3V28+71lvAlg78eUd+C9gBwAEB9gCwQ4ADAGwQ4AgAQ+QlOnCLkBdaABghLygAGCEvaAAYIS8AzmsR8gLdeQnijm68BFFH912CmKPbLkHE0V2XIN7oposIb5HuuYjwFumWiwhvke64iPAW6YaLCG+R7rcA8Ub3W4B4o/stQLzR/RYg3uh+CxBvdL95hLdE95tHeEt0v3mEt0T3m0d4S3S/eYS3RPebg3ij+81BvNH95iDe6H5zEG9kv0GvoUS2G/TWVC3ZbtBb/nXORcR1EC7ZbtAs6nXyScRNEC7Zbtg09XUaTgXGmPN0YIy6QAfGuIt0YIy8N9MN0246TEv/lG9tj/jtAU9zX4B+rRq0f6yzgHUD/Wm9ep52P/Ky/X7OQ1HS5eYOUbIjsa5UKUUHhhSjNB0YUsy7/aK7bt5P25/dvlz8EXbd3/Y1AeNTOTXN5aLxPAw3i9GdCi2MKEV3KrSUoxTdqRpTCt2pGlNKpBnq940F/+FTvzfUblp/qeLa21ZK9PuAhKnpHtWQVjTdoxrSyrtdkF8++XWDjMCT1+TXqTKQNDXdpQaSpqa71GBaobvUYFqhu9RgWqG/Ty1GHt2PFiLP0P1oIfIM3Y8WIs/Q35kWIs/Qnecg8gzdeQ4jj+48h5FHd94XLem3a+YVkLefS26apzyfrhfEwnzSwSZngzOXyz+o2C/i"

---@param testName string
Test.Start = function(testName)
    local builtEntities, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the end rails.
    local farWestRail, farEastRail
    for _, railEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "straight-rail", true, false)) do
        if farWestRail == nil or railEntity.position.x < farWestRail.position.x then
            farWestRail = railEntity
        end
        if farEastRail == nil or railEntity.position.x > farEastRail.position.x then
            farEastRail = railEntity
        end
    end

    local train = placedEntitiesByGroup["locomotive"][1].train
    train.schedule = {
        current = 1,
        records = {
            {rail = farWestRail, temporay = true},
            {rail = farEastRail, temporay = true}
        }
    }

    local testData = TestFunctions.GetTestDataObject(testName)
    ---@class Tests_PTR_TestScenarioBespokeData
    local testDataBespoke = {
        farWestRailReached = false, ---@type boolean
        farEastRailReached = false, ---@type boolean
        preFirstTunnelTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train, 0.75), ---@type TestFunctions_TrainSnapshot
        preSecondTunnelTrainSnapshot = nil, ---@type TestFunctions_TrainSnapshot
        farWestRail = farWestRail, ---@type LuaEntity
        farEastRail = farEastRail ---@type LuaEntity
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
    local testData = TestFunctions.GetTestDataObject(event.instanceId)
    local testDataBespoke = testData.bespoke ---@type Tests_PTR_TestScenarioBespokeData

    local westTrain = TestFunctions.GetTrainAtPosition(Utils.ApplyOffsetToPosition(testDataBespoke.farWestRail.position, {x = 2, y = 0})) -- Loco's don't pull up to center of rail position, so look inwards slightly.
    local eastTrain = TestFunctions.GetTrainAtPosition(Utils.ApplyOffsetToPosition(testDataBespoke.farEastRail.position, {x = -2, y = 0})) -- Loco's don't pull up to center of rail position, so look inwards slightly.

    if westTrain ~= nil and not testDataBespoke.farWestRailReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(westTrain, 0.75)
        if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.preFirstTunnelTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached west rail, but with train differences")
            return
        end
        game.print("train reached west rail")
        testDataBespoke.farWestRailReached = true
        testDataBespoke.preSecondTunnelTrainSnapshot = TestFunctions.GetSnapshotOfTrain(westTrain, 0.25)
    end
    if eastTrain ~= nil and not testDataBespoke.farEastRailReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(eastTrain, 0.25)
        if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.preSecondTunnelTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached east rail, but with train differences")
            return
        end
        game.print("train reached east rail")
        testDataBespoke.farEastRailReached = true
    end
    if testDataBespoke.farWestRailReached and testDataBespoke.farEastRailReached then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
