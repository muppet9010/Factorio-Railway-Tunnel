--[[
    When the train going from right (Station "Reset") to left (Station "Target") reaches the circuit connected set of signals, an RS latch triggers and the train limit on the target station is set to zero. Train should continue through the tunnel and to the target station as the existing slot reservation that it has is transferred across.
    When the train returns to the reset station, the RS latch resets and the train limit on target station is set to 1 again. Ready for another test loop.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString =
    "0eNq9Wttu4zYQ/Rc9y4EpiTcDLVCgj0UfdvetWAiyTTsEZEmgJKdu4H8vafmSyHQywxWyD1noNjyaM2c0Q89rtCx71RhdddHiNdKrumqjxT+vUau3VVG6c92hUdEi0p3aRXFUFTt3ZApdvhSHvOurSpWz4b+8qU1XlHnbm02xUrOmtH93ypo+xpGu1urfaEGOP+PIntKdVsNKp4NDXvW7pTL2husanV2kmrVd3dh1m7q1j9SVQ2TNzEhibzxEi4xY22tt1Gq4yuLIvkNn6jJfqudir2vjHmlVtc67Oj/ZjBabomxVPKyQuxUatc7vXnmvTdfbM1dEwx2zH+59WtUN1tq81Dtt3deZ/mLzfA5u8q/oeDwhr4YXad0zxP0xav3WTdoeibm9VZtVb1dwx8nxp3u67YrBB9GPwmyV8/qdd5MABtce99N08H565/19YfQZB/EASD8B0Kqti5jPESQ8EEE2GQIaiIBOhiCUBTYZAhKIgE+FgMhABGIyBKGRKCdDEBqJZD4ZhNBQJGQyCKGxSJKpIITGIpksLYbGIpksLQbH4mRpMTgUJ0uLwZE4VVoMBjBVVgzmYKqkGBqGyVQpMVSJyVQJMTQZJVOlw+CEnKTTlKmpn4PkcwDvs+HsXMffLcDY0znOyBO9W8TXiFzq9lVZt+raH5z7kctFo4pbOzK0FbYNyOu+a3pPU3FqzezqW6NU9cld8C4joa6t8DmHAp0jv8o5tSmqrfpq/2RvfHNqy5L3bRl55L/bZ6Z13eL2uZs5R37U5Y4j2GeWw80+KJq9ZgXCLIeblQizFGw2nSPMpnCzBGEWTlmawM3O4ZSlKcIsnLI0Q5hFUEYRZhGUIVQ2R1AGV5lEMAYXmUQQBteYhPOVwSUm4XRlcIVJOFsZXGACzlYG15eAs5XB5SUQbMHVJRBswcUlEGzBtcURbIG1xRAOAEuLwbmiYGUxeFhRsLAY3KcUrCsOp5+CZcXhRFGwqjiCKLCoOIKom6bKelXv6k7v1b1FkTwRyt7uPddGW1Pnbmb+5N7D1bKn4rXqV6UqzGzTK1vrpr5ylIJVhxAdBYsOkR8oWHSIVMbAokNkXXYT3aow23r2Umztvfcm5Sdkuku62ttTtbG3VH1Z+pYDyxHxPWJgOSI+nQwsR8RXnlGYtyWbxtvgjx+i/mFgFSJKNQZWIaKqZGAVIgpgPgclP9sAQChEZD8O/jxiugSewK3CY4SncKvwIOEZ3Co8SjiFW0WECVh6mDacc+xuXzbe0GI+swK7TwYzK0ETElcHwLbe/AMSw17beT7ifOnNmAN+dOIbZodNpuPBhm+q9c81iFv+WKuVXiszs1lkqavCpvKPNtb4ncv9/jlbze21tb4i32jTIqY8vkfDy9sXcvM2boyj3jWFOYFcRL/ZBx7tTn4wOOKsNAeLrK+6fGPqXa4ra+NMImauhNzPlcRR8uDuR9ubgiCpuGxGfj0VrXI2UNE7ouz3AMq+T0lZ6uapThvbv8bmeKaIgO0+jIPbN7AwunveqU6vPgwFVwR4A+FBzrqZ/bVYOKiyrF9CAsI50tUgjTKXFPXH33+GxQT2p5nHXMqHlNwKiKXezlRp1zKWlKYulTdJngmR4TmEjH8koUNOr5T9eC/r3rghQEF/+tDeCpMrUlUpsz3MdNWp009/3nwibqjfZ5Nlv9nYxNHq/5SrO67/fItTnKsuRYxEaXfkG+bzTRoL5nUPQyEUAVzSMUDuJS8W3AuQowDSAIBsDFD4ALJYCC9AgQIYogY+Bih9AHkspBegxAAkAfjECJ+c+/CJWM59+OQcgy8LwCfH+IgPn4wl8eIjGHw8AF8y/sbeuXN0IvHgt26UiRd/guMf/wJynJ8vNfd7gCSWqRcg6oNybUkQALkEedC6z9Yr7epZrfvyPFh+20hwx5TFfP7mnmHK3dNZ3I9Rn2yfxgMWb8bl42ivTDvUJ4JkXCY85ZySeXY8/g/HNfVz"

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    local train = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive").train

    local stationTarget
    for _, stationEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "train-stop", true, false)) do
        if stationEntity.backer_name == "Target" then
            stationTarget = stationEntity
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.train = train
    testData.trainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.stationTarget = stationTarget

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local stationTargetTrain = testData.stationTarget.get_stopped_train()

    if stationTargetTrain ~= nil then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationTargetTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.trainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train has differences after tunnel use")
            return
        end
        game.print("train reached target station")
        TestFunctions.TestCompleted(testName)
    end
end

return Test
