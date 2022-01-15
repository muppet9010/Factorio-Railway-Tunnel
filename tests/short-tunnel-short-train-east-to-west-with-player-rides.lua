-- Sends a short train from the east to the west. First loop player watches, second loop player rides the train.
-- Note the player being in the train after the tunnel traversal isn't checked by the test.

local Test = {}
local TestFunctions = require("scripts/test-functions")

Test.RunTime = 1800
Test.RunLoopsMax = 2

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString = "0eNqtW11z4jgQ/C9+hiuPZFkS7/cb7uFqK+UQL+taY1P+yF4qxX8/OXAbNnhz0yO9hACmR1ZPtzSS9Zo9tnN9GppuynavWbPvuzHb/f2ajc2hq9rls+nlVGe7rJnqY7bJHqv99/kU3g9V0/6oXh6muevqdnt5eTj1w1S1D+M8fK329fbUhr/HOoCfN1nTPdX/ZDs6f9lk4aNmaupLrLc3Lw/dfHysh3DBJuuq4xJzCkG67Tj1pxD51I/hJ323tCnAbKkIF74s/+gA/tQM9f7ydbnJxqm6/J/9VY9L8Lsg6meQDzdyvYO6e1qJWfprSPo1ZEB7robmGpRW4un/iTfWh6Wfws2G7w/fprXgRhq8SBBcS4ObBMFJGryMD27EnNsEwa00uEsQXJxwPkFwccJRniC6OOOI4qMX4pQjlSC6OOcogcsV4qSjBDZXyLMugc8V8qxLYHRannUJnE7Lsy6B1Wl51iXwOi3OOpXA67Q461QCr1PirFMJvE6Js05p0QxSyan+rb3NYWI9HIY+vHLumeQ9blI1Qd7tZaomiBWvbKomyHPBpWqCXPs+URPkJVWeqAXiZNSUqAXiXNQqUQvEqah1qlQUtyCRMcobkMgW5RwkMkV5GiayRLkSExmi3IwS2aHckItEdigflYpEdigfmgvRsp58QlTEF7zyCWERX+8qeU/Hl7vyuXcRX+3Ky44ivtiVV1xFfK0rLzaL+FJXXmeb+EpXvsRg4gtd+eqKia9z5QtLJt7h5GtqJt7h5MuJJt7h5CupJt7h5IvIJt7h5OvnJt7h5FsHJt7h5JsmZbzDybeLyniHk2+UlfEOF7FFKFrIk2/Glu+m9t/tbJfAn25xf4yyhmv4uL8djNZwSwDXArgWwDUArgNwNYDrAVyAN5vzcRXAmyUAF+DNKgAX4M1qABfgzQJ6UwhvgN4I4Q3QGyG8AXojhDdAb4TwBuiNAN4coLcc4M0BessB3hygtxzgzQF6ywHeHKC3HOGNrzeP0MaXm0dY46vNI6TxxeYRzvha8wBlni81B1Dm+UpzAGWeLzQHUOb5OnMAZZ4vM4dQxleZRSjjq8wilPFVZhHK+CqzCGVslZVA11LOVpklBJatMqQPKGerDGHsbYRiwloElq0yC1HGVpmDKGOrzEGUsVXmIMrYKnMQZWyVIWMO3TxV2vb7/thPzXO9soF427H90ASY61pA/seS0Mtj9ONy7dDvv9fT9utct+FX59WQbAUigzIRW4HIFIKIrUBkwkM3T3Xuq+HQb39Uh3Dx/SbeYoOf9nz3HD7qh3BNN7ftaiy2LJGpIBFblh7KSLYsoXk2kePjQgniWQr6tTj6QKS6ldC+X06omHxVPCrn3wWSj4r4uEiSKMXHRbLk5jnFT3t90VmCXmePl1DNTsrwcZGcVCUfF8oSvjYJyhK+NgnKEvagCa2RkearEFnTI81XIbIGSZqvQmTNlLTm4yK8ab7eNMQbX28a4o2vNw3xxtebhnhzrMOIP0H93W7Q+1HEP6vlKOKX8NH+W/00t9fTj++uvLxf5pmLdIMcbq68HMm8P9R4B77Av53U3N0c7Nxkz/UwXhrkqLBe2cKbwhp9Pv8L26V33w=="

Test.Start = function(testName)
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 45, y = 70}, testName)

    -- Get the stations placed by name.
    local trainStopWest, trainStopEast
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "West" then
            trainStopWest = stationEntity
        elseif stationEntity.backer_name == "East" then
            trainStopEast = stationEntity
        end
    end

    local train = placedEntitiesByGroup["locomotive"][1].train

    -- Put the player in a carriage on the 2nd loop.
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    if testManagerEntry.runLoopsCount == 2 then
        local player = game.connected_players[1]
        if player ~= nil then
            train.carriages[2].set_driver(player)
        else
            game.print("No player found to set as driver, test continuing regardless")
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.bespoke = {
        westStationReached = false,
        eastStationReached = false,
        origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train),
        trainStopWest = trainStopWest,
        trainStopEast = trainStopEast
    }

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(event.instanceId)
    local testDataBespoke = testData.bespoke
    local westTrain, eastTrain = testDataBespoke.trainStopWest.get_stopped_train(), testDataBespoke.trainStopEast.get_stopped_train()
    if westTrain ~= nil and not testDataBespoke.westStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(westTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached west station, but with train differences")
            return
        end
        game.print("train reached west station")
        testDataBespoke.westStationReached = true
    end
    if eastTrain ~= nil and not testDataBespoke.eastStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(eastTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached east station, but with train differences")
            return
        end
        game.print("train reached east station")
        testDataBespoke.eastStationReached = true
    end
    if testDataBespoke.westStationReached and testDataBespoke.eastStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
