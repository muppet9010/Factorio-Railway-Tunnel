local TestFunctions = {}
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Interfaces = require("utility/interfaces")

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
--
--                                          PUBLIC FUNCTIONS
--
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------

-- Gets the test's data object reference.
TestFunctions.GetTestDataObject = function(testName)
    return global.testManager.testData[testName]
end

-- Get the test surface's LuaSurface reference.
TestFunctions.GetTestSurface = function()
    return global.testManager.testSurface
end

-- Get the test entities force's LuaForce reference.
TestFunctions.GetTestForce = function()
    return global.testManager.playerForce
end

-- Complete the current test. arguments: the test name.
TestFunctions.TestCompleted = function(testName)
    game.print("Completed Test: " .. testName, {0, 1, 0, 1})
    local test = global.testManager.testsToRun[testName]
    Interfaces.Call("TestManager.GetTestScript", testName).Stop(testName)
    test.finished = true
    test.success = true
    EventScheduler.RemoveScheduledOnceEvents("TestManager.WaitForPlayerThenRunTests")
    EventScheduler.ScheduleEventOnce(game.tick + 1, "TestManager.WaitForPlayerThenRunTests")
end

-- Fail the current test. arguments: the test name, the text reason that is shown on screen.
TestFunctions.TestFailed = function(testName, errorText)
    game.print("Failure Message: " .. errorText, {1, 0, 0, 1})
    local test = global.testManager.testsToRun[testName]
    Interfaces.Call("TestManager.GetTestScript", testName).Stop(testName)
    test.finished = true
    test.success = false
    EventScheduler.RemoveScheduledOnceEvents("TestManager.WaitForPlayerThenRunTests")
    game.tick_paused = true
end

-- Register a unique name and function for future event scheduling.
TestFunctions.RegisterTestsScheduledEventType = function(testName, eventName, testFunction)
    -- Called by tests to register a test event without having to hard code details in the test.
    local completeName = "Test." .. testName .. "." .. eventName
    EventScheduler.RegisterScheduledEventType(completeName, testFunction)
end

-- Schedule an event named function once at a given tick.
TestFunctions.ScheduleTestsOnceEvent = function(tick, testName, eventName, instanceId, eventData)
    -- Called by tests to schedule a test once event without having to hard code details in the test.
    -- instanceId and eventData are optional
    local completeName = "Test." .. testName .. "." .. eventName
    if instanceId == nil then
        instanceId = testName
    end
    EventScheduler.ScheduleEventOnce(tick, completeName, instanceId, eventData)
end

-- Schedule an event named function to run every tick until cancelled.
TestFunctions.ScheduleTestsEveryTickEvent = function(testName, eventName, instanceId, eventData)
    -- Called by tests to schedule a test every tick event without having to hard code details in the test.
    -- instanceId and eventData are optional
    local completeName = "Test." .. testName .. "." .. eventName
    if instanceId == nil then
        instanceId = testName
    end
    EventScheduler.ScheduleEventEachTick(completeName, instanceId, eventData)
end

-- Remove any instances of future scheduled once events.
TestFunctions.RemoveTestsOnceEvent = function(testName, eventName, instanceId)
    -- Called by tests to remove a test once event without having to hard code details in the test.
    -- instanceId is optional
    local completeName = "Test." .. testName .. "." .. eventName
    EventScheduler.RemoveScheduledOnceEvents(completeName, instanceId)
end

-- Remove any instances of future scheduled every tick events.
TestFunctions.RemoveTestsEveryTickEvent = function(testName, eventName, instanceId)
    -- Called by tests to schedule a test every tick event without having to hard code details in the test.
    -- instanceId is optional
    local completeName = "Test." .. testName .. "." .. eventName
    EventScheduler.RemoveScheduledEventFromEachTick(completeName, instanceId)
end

-- Returns an abstract meta data of a train to be compared later.
TestFunctions.GetSnapshotOfTrain = function(train)
    -- Gets a snapshot of a train carriages details. Allows comparing train carriages without having to use their unit_number, so supports post cloning, etc.
    -- Doesn't check fuel as this can be used up between snapshots.
    local snapshot = {
        carriageCount = #train.carriages,
        carriages = {}
    }
    local previousCarriageOrientation, previousCarriageFacingFowards = train.front_stock.orientation, true
    for _, realCarriage in pairs(train.carriages) do
        local snapCarriage = {
            name = realCarriage.name,
            health = realCarriage.health
        }

        -- A train on a curve will have the same facing carriages roughly on the same orientation as the ones each side.
        if (realCarriage.orientation > previousCarriageOrientation - 0.25 and realCarriage.orientation < previousCarriageOrientation + 0.25) then
            snapCarriage.facingForwards = previousCarriageFacingFowards
        else
            snapCarriage.facingForwards = not previousCarriageFacingFowards
        end

        if realCarriage.type == "cargo-wagon" or realCarriage.type == "fluid-wagon" then
            snapCarriage.cargoInventory = game.table_to_json(realCarriage.get_inventory(defines.inventory.cargo_wagon).get_contents())
        end
        table.insert(snapshot.carriages, snapCarriage)

        previousCarriageOrientation, previousCarriageFacingFowards = realCarriage.orientation, snapCarriage.facingForwards
    end
    return snapshot
end

-- Compares 2 train snapshots to see if they are the same train structure.
TestFunctions.AreTrainSnapshotsIdentical = function(origionalSnapshot, currentSnapshot)
    -- Handles if the "front" of the train has reversed as when trains are placed Factorio can flip the "front" compared to before. Does mean that this function won't detect if a symetrical train has been flipped.

    if origionalSnapshot.carriageCount ~= currentSnapshot.carriageCount then
        return false
    end

    -- Check the 2 trains starting in the same order and facingForwards as this is most likely sceanrio (perfect copy). Then check combinations of  reversed facingForwards and iterate the carraige list backwards.
    for _, reverseFacingFowards in pairs({false, true}) do
        for _, currentCarriageIteratorFunc in pairs(
            {
                function(origCarriageCount)
                    return origCarriageCount
                end,
                function(origCarriageCount, carriageMax)
                    return (carriageMax - origCarriageCount) + 1
                end
            }
        ) do
            local difference
            for carriageNumber = 1, origionalSnapshot.carriageCount do
                local currentCarriageCount = currentCarriageIteratorFunc(carriageNumber, #origionalSnapshot.carriages)
                difference = TestFunctions._CarriageSnapshotsMatch(origionalSnapshot.carriages[carriageNumber], currentSnapshot.carriages[currentCarriageCount], reverseFacingFowards)
                if difference then
                    break
                end
            end
            if difference == nil then
                return true
            end
        end
    end

    -- All combinations tested and none have 0 differences, so train snapshots don't match.
    return false
end

-- Builds a given blueprint string centered on the given position and returns a list of all build entities. Also starts any placed trains (set to automatic mode).
TestFunctions.BuildBlueprintFromString = function(blueprintString, position, testName)
    -- Utility function to build a blueprint from a string on the test surface.
    -- Makes sure that trains in the blueprint are properly built, their fuel requests are fulfilled and the trains are set to automatic.
    -- Returns the list of directly placed entities. Any script reaction to entities being revived will lead to invalid entity references in the returned result.
    local testSurface = global.testManager.testSurface
    local player = game.connected_players[1]
    local itemStack = player.cursor_stack

    itemStack.clear()
    if itemStack.import_stack(blueprintString) ~= 0 then
        error("Error importing blueprint string for test: " .. testName)
    end
    if Utils.IsTableEmpty(itemStack.cost_to_build) then
        error("Blank blueprint used in test: " .. testName)
    end

    local ghosts =
        itemStack.build_blueprint {
        surface = testSurface,
        force = global.testManager.playerForce,
        position = position,
        by_player = player
    }
    if #ghosts == 0 then
        error("Blueprint in test failed to place, likely outside of generated/revealed area. Test: " .. testName)
    end
    itemStack.clear()

    local pass2Ghosts = {}
    local fuelProxies = {}
    local placedEntities = {}

    for _, ghost in pairs(ghosts) do
        local revivedOutcome, revivedGhostEntity, fuelProxy = ghost.silent_revive({raise_revive = true, return_item_request_proxy = true})
        if revivedOutcome == nil then
            -- Train ghosts can't be revived before the rail underneath them, so save failed ghosts for a second pass.
            table.insert(pass2Ghosts, ghost)
        elseif revivedGhostEntity ~= nil and revivedGhostEntity.valid then
            -- Only record valid entities, anythng else is passed help.
            table.insert(placedEntities, revivedGhostEntity)
        end
        if fuelProxy ~= nil then
            table.insert(fuelProxies, fuelProxy)
        end
    end

    for _, ghost in pairs(pass2Ghosts) do
        local revivedOutcome, revivedGhostEntity, fuelProxy = ghost.silent_revive({raise_revive = true, return_item_request_proxy = true})
        if revivedOutcome == nil then
            error("only 2 rounds of ghost reviving supported. Test: " .. testName)
        elseif revivedGhostEntity ~= nil and revivedGhostEntity.valid then
            -- Only record valid entities, anythng else is passed help.
            table.insert(placedEntities, revivedGhostEntity)
        end
        if fuelProxy ~= nil then
            table.insert(fuelProxies, fuelProxy)
        end
    end

    for _, fuelProxy in pairs(fuelProxies) do
        for item, count in pairs(fuelProxy.item_requests) do
            fuelProxy.proxy_target.insert({name = item, count = count})
        end
        fuelProxy.destroy()
    end

    for _, train in pairs(testSurface.get_trains()) do
        train.manual_mode = false
    end

    return placedEntities
end

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
--
--                                          PRIVATE FUNCTIONS
--
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------

TestFunctions._CarriageSnapshotsMatch = function(carriage1, carriage2, reverseFacingForwardsCarriage2)
    for _, attribute in pairs({"name", "health", "facingForwards", "cargoInventory"}) do
        if reverseFacingForwardsCarriage2 and attribute == "facingForwards" then
            -- Reverse the expected attribute value and so if they equal its really a difference.
            if carriage1[attribute] == carriage2[attribute] then
                return attribute
            end
        else
            -- Standard attribute test for differences.
            if carriage1[attribute] ~= carriage2[attribute] then
                return attribute
            end
        end
    end
    return nil
end

return TestFunctions
