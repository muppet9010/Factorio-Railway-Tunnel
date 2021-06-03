-- Sends a short train across a tunnel pathign to a rail, rather than station.

local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 1800
Test.RunLoopsMax = 1

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString =
    "0eNqtmu1u2jAUhu/Fv2HC3za3MlUopRmLFhIUAh2quPc5YxLVlq0Pnv+0Shq9x+R9n5Pj0Dfx3J7qw9B0o1i/iWbbd0ex/vwmjs2uq9rp3Hg51GItmrHei4Xoqv10NFRN+1pdNuOp6+p2efu1OfTDWLWb42n4Um3r5aFNP/d1kr4uRNO91N/FWl6fFiKdasamvlX6eXDZdKf9cz2kCzJqvKSFHfpj0uy7acmpzlLGhbiItU2lX5qh3t7+5hbiXA1NdTuS18Uf9dUH9Y/1bvpIHy7A55XXhcpnfnpTqLyUefVtqfo6r74rVd/m1fel6mfGL5Sqn5m/WKi+ysyfXJVaQGYApSy1gMwEylINUGVGUJZqgSozg7JUE9S5ISzVBXVuCEu1QZ0bwlJ9UOeGsFQj1LkhLNUJTWYIValOaDJDqEp1QpMZQqXKjKJ+1gH1cf17IzyOaQW7r+NyWsjcsDs/76g5VfOAqsSqlquuIlZ1D6h6rOofULVYNTygyt2KD6hit/QKq0ZslpZcFHulFRfFVmkOVsROac5V5EZxrAI3ilMVuFEcqsCN4kwFbhRHKmCjDCfKY6MMJ8pjowwnymOjDCfKY6MMJ8pzozhRjhvFiXLcKE6U40Zxohw3ihPlsFGWE2WxUZYTZbFRlhNlsVGWE2WxUZYTZblRnCjDjeJEGW4UJ8pwozBRfOqxGCg+njnM0wODpJNcFKfUKS6KbXKai2KfnOGi3CjM0wP7M+e4KDfKc1FuVOCi3Kg7UG2/7ff92JzrGcV3r437oUkiv7bnq0/TLDR9BXacLh367bd6XH451W1C8Dr3Hp/TJnEyPKdN4WR4TpvCyfB32rbVsOuXr9UuXTsjGf55w7tzOtUP6Yru1LZzhTiBCkfQcwIVjqDnBCqeCE6g5okIDJZ3L3d/8069h2XbT98j29UsJpGvH4cvcPY0zkTg7GmciaDYnZ72bP95pwN//mkcv8DpMzh+gdNneCY4fXz0C5w+PqQG/vzj43TgnPHBP3LO+BYlcs74ZiryZxzf9kVOFN+gRk4U30pHThTf9EdO1N9eTzzdeldSuP8T0kKc6+F4uyAkbKLyOq6c9O56/QFNSE4l"

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 45, y = 70}, testName)

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

    local train = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive").train
    train.schedule = {
        current = 1,
        records = {
            {rail = farWestRail},
            {rail = farEastRail}
        }
    }

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.farWestRailReached = false
    testData.farEastRailReached = false
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.farWestRail = farWestRail
    testData.farEastRail = farEastRail

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local westTrain = TestFunctions.GetTrainAtPosition(Utils.ApplyOffsetToPosition(testData.farWestRail.position, {x = 2, y = 0})) -- Loco's don't pull up to center of rail position, so look inwards slightly.
    local eastTrain = TestFunctions.GetTrainAtPosition(Utils.ApplyOffsetToPosition(testData.farEastRail.position, {x = -2, y = 0})) -- Loco's don't pull up to center of rail position, so look inwards slightly.
    if westTrain ~= nil and not testData.farWestRailReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(westTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached west rail, but with train differences")
            return
        end
        game.print("train reached west rail")
        testData.farWestRailReached = true
    end
    if eastTrain ~= nil and not testData.farEastRailReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(eastTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached east rail, but with train differences")
            return
        end
        game.print("train reached east rail")
        testData.farEastRailReached = true
    end
    if testData.farWestRailReached and testData.farEastRailReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
