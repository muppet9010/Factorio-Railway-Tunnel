-- A test where a train with artillery wagons goes underground near an enemy worm. The test confirms that the artillery train doesn't shoot the worm while traversing underground.

local Test = {}
local TestFunctions = require("scripts.test-functions")

Test.RunTime = 3600

--- Any scheduled event types for the test must be Registered here. Most tests will want an event every tick to check the test progress.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick) -- Register for enabling during Start().
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local surface = TestFunctions.GetTestSurface()

    -- The artillery wagons will have unique ammo count each as part of their being built, so all have ammo.
    local blueprint = "0eNq1Wtty2jAU/Bc9Q8e6S/xIHzqZjENU6qmxGdskZTL8eyXIlDZx2vWR+pIEbHZt79k9R0Qv7KE9hsPQdBPbvLBm23cj23x5YWOz6+o2vTedDoFtWDOFPVuxrt6nV0PdtM/16X46dl1o14d+mOr2fgy7feim9TjF47tvEzuvWNM9hh9sw893KxaPNVMTrgyXF6f77rh/CEM84Rd2+nAXMfpD5Dv0Y/xI36UriTBrzu2KndIfEfuxGcL2etSs2DjV17/Z5zAm7ncc4h/XH7rHGUpzZXxDGLGe6qF5peQzbHLp05qhlnPU5p/UqgA1p1HrfGrtadSmALWlUdsC1JpWZq4AtaRR+wLUnEbNq3xuRawzzgtwEwuNiwLcmshdINEUMdF4gUhT1ForkGnSE7kLhJokNjBeINUktdYKxJqk1lqBXJPE9ikK5Jog5pookGuCWGuiQK4JYgcVBXJNEFuoUKSZlBPjRHwYZcc4pw+7oY+/393vOp17vx36cWy63dzlEF0uDOVy5i6AaHVhS10A1e/uvwhCTQBPqkai+rJA1hEfu8yPOipzftARa13mxxwxYGX+8EZdg+ePbsSklfmDGyfOqzJ/bqPmqcwf26i9ROZPbZy4KFP5QUZt6Co/yASxzFR+klGnJpUfZdRhUeVnmaCWWX6YUZcGKj/NqCsilZ9mklpm+WkmqWWWn2bUZb/OTzPqtx2aU+ZP6ndK+hZgfwzWf/m3w9s7mkOVC1A1jKoWoEoYVS9A5TCqwVErD6PaBai4Wm4BKq6WX4AKq2WqBaiwWobDqB4Wy+DW8rBWBneWh6UyuLE8rhTuK48LhdvK4ULhrnK4ULipHC4U7ikHC2VxSzlYKIs7ysJCWdxRFhbK4o6ysFAWd5TFhcIdZXGhYEcp/JHeDNX2237fT81TmPkm5XaR/dBEjNc5pfqU7nTbt/2QzhzSO9pV0gvuuLNSCq7jj0rytIDZxcMr9pBOcsIqXXlfGWuc9c4JdzmlvpKk7RtjQtz2aVtHmmyHfvs9TOuvxxDf0Oe5e4F9rPA6hm2sYR0d7GINF5y7mbgepqZtw3BaP9e7eP57VPexmHPQsJU1bDoHO1nDpexgI2tYfgf72ODyG1wqo5dJBbdHg1cW7CqDyw+7ysDy+wp/rKk7LXisHu6QBq4sD7sKbxAedhXeyTzsKrzler1AKr9MKrhH4mOHh12Fz0cedhU+yHkP9fKUP/NPVOjZrUtwu8IH2cuCDwTVOCjsKXxxcFnwgqAfqH+3YuP2W3g8tq97SW/qpNexEL3/7ZzrhtY3u0PvEsplU+vmtz2wK/YUhvFK47iyXlgtnFBSnM8/AYcXoAI="
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Get the "South" train stop of the 2 train stops we know are in the BP.
    local westTrainStop = placedEntitiesByGroup["train-stop"][1]
    if westTrainStop.backer_name ~= "West" then
        westTrainStop = placedEntitiesByGroup["train-stop"][2]
    end

    -- Put an enemy worm near by, but out of the worms shooting range. Its so far over to the left and up to make sure the artillery carriages have plently of time to shoot at it before the train starts moving again.
    local worm = surface.create_entity {name = "small-worm-turret", position = {x = -120, y = 30}, force = game.forces.enemy}

    local testData = TestFunctions.GetTestDataObject(testName)
    ---@class Tests_UAT_TestScenarioBespokeData
    local testDataBespoke = {
        westTrainStop = westTrainStop, ---@type LuaEntity
        worm = worm ---@type LuaEntity
    }
    testData.bespoke = testDataBespoke

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

--- Any scheduled events for the test must be Removed here so they stop running. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

--- Scheduled event function to check test state each tick.
---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(testName)
    local testDataBespoke = testData.bespoke ---@type Tests_UAT_TestScenarioBespokeData

    -- If the worm dies (isn't valid) then the artillery train shot it.
    if not testDataBespoke.worm.valid then
        TestFunctions.TestFailed(testName, "Worm was shot by artillery")
        return
    end

    -- If the train reaches the west station then its completed its journey.
    if testDataBespoke.westTrainStop.get_stopped_train() ~= nil then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
