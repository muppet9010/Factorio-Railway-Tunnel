local TestFunctions = {}
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")
local Colors = require("utility/colors")

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

--- Gets the test's internal data object reference. Recrated each test start.
---@param testName TestName
---@return TestData
TestFunctions.GetTestDataObject = function(testName)
    return global.testManager.testData[testName]
end

--- Gets the test manager's test object reference. Persists across tests.
---@param testName TestName
---@return Test
TestFunctions.GetTestMangaerObject = function(testName)
    return global.testManager.testsToRun[testName]
end

--- Get the test surface's LuaSurface reference.
---@return LuaSurface
TestFunctions.GetTestSurface = function()
    return global.testManager.testSurface
end

--- Get the test entities force's LuaForce reference.
---@return LuaForce
TestFunctions.GetTestForce = function()
    return global.testManager.playerForce
end

--- Complete the current test. arguments: the test name.
---@param testName TestName
TestFunctions.TestCompleted = function(testName)
    game.print("Completed Test", Colors.lightgreen)
    Interfaces.Call("TestManager.LogTestOutcome", "Test Completed")
    local testManagerData = global.testManager.testsToRun[testName]
    Interfaces.Call("TestManager.GetTestScript", testName).Stop(testName)
    if testManagerData.runLoopsCount == testManagerData.runLoopsMax then
        testManagerData.finished = true
        testManagerData.success = true
    end
    EventScheduler.RemoveScheduledOnceEvents("TestManager.WaitForPlayerThenRunTests")
    if not global.testManager.keepRunningTest then
        local delay = 1 + global.testManager.continueTestAfterCompletioTicks
        EventScheduler.ScheduleEventOnce(game.tick + delay, "TestManager.WaitForPlayerThenRunTests")
    end
end

--- Fail the current test. arguments: the test name, the text reason that is shown on screen.
---@param testName TestName
---@param errorText string
TestFunctions.TestFailed = function(testName, errorText)
    game.print("Failure Message: " .. errorText, Colors.red)
    Interfaces.Call("TestManager.LogTestOutcome", "Test Failed: " .. errorText)
    local testManagerData = global.testManager.testsToRun[testName]
    Interfaces.Call("TestManager.GetTestScript", testName).Stop(testName)
    if not global.testManager.justLogAllTests then
        testManagerData.finished = true
        testManagerData.success = false
        game.tick_paused = true
    end
    EventScheduler.RemoveScheduledOnceEvents("TestManager.WaitForPlayerThenRunTests")
    if global.testManager.justLogAllTests then
        -- Continue with scheduling next test when running all tests.
        EventScheduler.ScheduleEventOnce(game.tick + 1, "TestManager.WaitForPlayerThenRunTests")
    end
end

--- Register a unique name and function for future event scheduling. Must be called from a test's OnLoad() and is a pre-requisite for any events to be scheduled during a test Start().
---@param testName TestName
---@param eventName string @Name of the event, used when triggering it.
---@param testFunction function @Function thats called when the event is triggered.
TestFunctions.RegisterTestsScheduledEventType = function(testName, eventName, testFunction)
    local completeName = "Test." .. testName .. "." .. eventName
    EventScheduler.RegisterScheduledEventType(completeName, testFunction)
end

--- Schedule an event named function once at a given tick. To be called from Start().
---@param tick Ticks
---@param testName TestName
---@param eventName string @Name of the event to trigger.
---@param instanceId string @OPTIONAL - Unique id for this scheduled once event. Uses testName if not provided.
---@param eventData table @OPTIONAL - data table passed back in to the handler function when triggered.
TestFunctions.ScheduleTestsOnceEvent = function(tick, testName, eventName, instanceId, eventData)
    -- instanceId and eventData are optional.
    local completeName = "Test." .. testName .. "." .. eventName
    if instanceId == nil then
        instanceId = testName
    end
    EventScheduler.ScheduleEventOnce(tick, completeName, instanceId, eventData)
end

--- Schedule an event named function to run every tick until cancelled. To be called from Start().
---@param testName TestName
---@param eventName string @Name of the event to trigger.
---@param instanceId string @OPTIONAL - Unique id for this scheduled once event. Uses testName if not provided.
---@param eventData table @OPTIONAL - data table passed back in to the handler function when triggered.
TestFunctions.ScheduleTestsEveryTickEvent = function(testName, eventName, instanceId, eventData)
    local completeName = "Test." .. testName .. "." .. eventName
    if instanceId == nil then
        instanceId = testName
    end
    EventScheduler.ScheduleEventEachTick(completeName, instanceId, eventData)
end

--- Remove any instances of future scheduled once events. To be called from Stop().
---@param testName TestName
---@param eventName string @Name of the event to remove the schedule of.
---@param instanceId string @OPTIONAL - Unique id for this scheduled once event. Uses testName if not provided.
TestFunctions.RemoveTestsOnceEvent = function(testName, eventName, instanceId)
    local completeName = "Test." .. testName .. "." .. eventName
    EventScheduler.RemoveScheduledOnceEvents(completeName, instanceId)
end

--- Remove any instances of future scheduled every tick events. To be called from Stop().
---@param testName TestName
---@param eventName string @Name of the event to remove the schedule of.
---@param instanceId string @OPTIONAL - Unique id for this scheduled once event. Uses testName if not provided.
TestFunctions.RemoveTestsEveryTickEvent = function(testName, eventName, instanceId)
    local completeName = "Test." .. testName .. "." .. eventName
    EventScheduler.RemoveScheduledEventFromEachTick(completeName, instanceId)
end

--- Register a unique name and function to react to a named event. Will only trigger when this test is active. Must be called from OnLoad() and Start().
---@param testName TestName
---@param eventName defines.events @The Factorio event to react to.
---@param testFunctionName string @Unique name of this event function handler.
---@param testFunction function @Function to be triggered when the event occurs.
---@param filterData EventFilter @OPTIONAL - Factorio event filter to be used.
TestFunctions.RegisterTestsEventHandler = function(testName, eventName, testFunctionName, testFunction, filterData)
    -- Injects the testName as an attribute on the event data response for use in getting testData within the test function.
    local completeHandlerName = "Test." .. testName .. "." .. testFunctionName
    local activeTestCheckFunc = function(event)
        local testManagerData = global.testManager.testsToRun[testName]
        -- Each test that registered an event handler has a unique reaction (this) function that checks that test's own state data for. So an instance per test's OnLoad() which each watching for its own test beign the currently active test and ignoring it otherwise.
        if testManagerData.runLoopsCount > 0 and not testManagerData.finished then
            event.testName = testName
            testFunction(event)
        end
    end
    Events.RegisterHandlerEvent(eventName, completeHandlerName, activeTestCheckFunc, filterData)
end

--- Used to apply an optional filter list of keys against a full list. Includes error catching for passing in bad (empty) filter list.
---@param fullList table
---@param filterList table
---@return table
TestFunctions.ApplySpecificFilterToListByKeyName = function(fullList, filterList)
    local listToTest
    if Utils.IsTableEmpty(filterList) then
        listToTest = fullList
    else
        listToTest = {}
        for _, entry in pairs(filterList) do
            listToTest[entry] = fullList[entry]
        end
    end
    if Utils.IsTableEmpty(listToTest) then
        error("blank list output from TestFunctions.ApplySpecificFilterToListByKeyName()")
    end
    return listToTest
end

---@class TrainSnapshot
---@field public carriageCount uint @how many carriages are in this train.
---@field public carriages CarriageSnapshot[]

---@class CarriageSnapshot
---@field public name string @Entity prototype name
---@field public health float @How much health the carriage has.
---@field public facingForwards boolean @If the carriage is facing forwards relative to the train's front.
---@field public cargoInventory string @The cargo of non-locomotives as a JSON string.
---@field public color string @Color attribute as a JSON string.

--- Returns an abstract meta data of a train to be compared later.
---@param train LuaTrain
---@return TrainSnapshot
TestFunctions.GetSnapshotOfTrain = function(train)
    -- Gets a snapshot of a train carriages details. Allows comparing train carriages without having to use their unit_number, so supports post cloning, etc.
    -- Doesn't check fuel as this can be used up between snapshots.
    -- Any table values for comparing should be converted to JSON to make them simple to compare later.

    ---@type TrainSnapshot
    local snapshot = {
        carriageCount = #train.carriages,
        carriages = {} ---@type CarriageSnapshot[]
    }
    local previousCarriageOrientation, previousCarriageFacingFowards = train.front_stock.orientation, true
    for _, realCarriage in pairs(train.carriages) do
        ---@type CarriageSnapshot
        local snapCarriage = {
            name = realCarriage.name,
            health = realCarriage.health
        }

        -- A train on a curve will have the same facing carriages roughly on the same orientation as the ones each side.
        -- Handle the number wraping within 1 and 0. If its closer < 0.25 either way then its facing same direction, > 0.25 and < 0.75 then its facing away.
        if (realCarriage.orientation > previousCarriageOrientation - 0.25 and realCarriage.orientation < previousCarriageOrientation + 0.25) or realCarriage.orientation > previousCarriageOrientation + 0.75 or realCarriage.orientation < previousCarriageOrientation - 0.75 then
            snapCarriage.facingForwards = previousCarriageFacingFowards
        else
            snapCarriage.facingForwards = not previousCarriageFacingFowards
        end

        if realCarriage.type ~= "locomotive" then
            -- Exclude locomotives as we don't want to track their fuel amounts, as they'll be used as the train moves.
            snapCarriage.cargoInventory = game.table_to_json(realCarriage.get_inventory(defines.inventory.cargo_wagon).get_contents())
        end
        table.insert(snapshot.carriages, snapCarriage)

        if realCarriage.color ~= nil then
            snapCarriage.color = game.table_to_json(realCarriage.color)
        end

        previousCarriageOrientation, previousCarriageFacingFowards = realCarriage.orientation, snapCarriage.facingForwards
    end
    return snapshot
end

--- Compares 2 train snapshots to see if they are the same train structure. If Optional "allowPartialCurrentSnapshot" argument is true then the current snapshot can be one end of the origonal train.
---@param origionalTrainSnapshot TrainSnapshot
---@param currentTrainSnapshot TrainSnapshot
---@param allowPartialCurrentSnapshot boolean
---@return boolean
TestFunctions.AreTrainSnapshotsIdentical = function(origionalTrainSnapshot, currentTrainSnapshot, allowPartialCurrentSnapshot)
    -- Handles if the "front" of the train has reversed as when trains are placed Factorio can flip the "front" compared to before. Does mean that this function won't detect if a symetrical train has been flipped.
    allowPartialCurrentSnapshot = allowPartialCurrentSnapshot or false

    local wagonsToIgnore = remote.call("railway_tunnel", "get_temporary_carriage_names")
    local currentSnapshotCarriages = currentTrainSnapshot.carriages

    -- If dummy/pushing locos are allowed then check the train ends and remove them if found, so they don't trigger a fail in comparison. Don't remove any from within the train as they shouldn't be there.
    if allowPartialCurrentSnapshot then
        for _, currentCarriageCount in pairs({1, currentTrainSnapshot.carriageCount}) do
            if wagonsToIgnore[currentSnapshotCarriages[currentCarriageCount].name] ~= nil then
                table.remove(currentSnapshotCarriages, currentCarriageCount)
                currentTrainSnapshot.carriageCount = currentTrainSnapshot.carriageCount - 1
            end
        end
    end

    -- If we don't allow partial trains then check the carriage counts are the same, as is a simple failure.
    if not allowPartialCurrentSnapshot and origionalTrainSnapshot.carriageCount ~= currentTrainSnapshot.carriageCount then
        return false
    end

    -- Check the 2 trains starting in the same order and facingForwards as this is most likely scenario (perfect copy). Then check combinations of facing backwards (new train is declared backwards due to build order by Factorio magic) and iterate the carriage list backwards (new train is generally running backwards).
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
            for carriageNumber = 1, currentTrainSnapshot.carriageCount do
                local currentCarriageCount = currentCarriageIteratorFunc(carriageNumber, #currentSnapshotCarriages)
                difference = TestFunctions._CarriageSnapshotsMatch(origionalTrainSnapshot.carriages[carriageNumber], currentSnapshotCarriages[currentCarriageCount], reverseFacingFowards)
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

--- Searches the test surface for the first train found within the search bounding box.
---@param searchBoundingBox BoundingBox
---@return LuaTrain
TestFunctions.GetTrainInArea = function(searchBoundingBox)
    local carriagesInInspectionArea = TestFunctions.GetTestSurface().find_entities_filtered {area = searchBoundingBox, name = {"locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon"}, limit = 1}
    local carriageFound = carriagesInInspectionArea[1]
    if carriageFound ~= nil then
        return carriageFound.train
    else
        return nil
    end
end

--- Searches the test surface for the first train found at the search position.
---@param searchPosition Position
---@return LuaTrain
TestFunctions.GetTrainAtPosition = function(searchPosition)
    local carriagesInInspectionArea = TestFunctions.GetTestSurface().find_entities_filtered {position = searchPosition, name = {"locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon"}, limit = 1}
    local carriageFound = carriagesInInspectionArea[1]
    if carriageFound ~= nil then
        return carriageFound.train
    else
        return nil
    end
end

--- Builds a given blueprint string centered on the given position and returns a list of all build entities. Also starts any placed trains (set to automatic mode). To aid train comparison locomotives are given a random color and train wagons (cargo, fluid, artillery) have random items put in them so they are each unique.
---@param blueprintString string
---@param position Position
---@param testName TestName
---@return LuaEntity[]
TestFunctions.BuildBlueprintFromString = function(blueprintString, position, testName)
    -- Utility function to build a blueprint from a string on the test surface.
    -- Makes sure that trains in the blueprint are properly built, their fuel requests are fulfilled and the trains are set to automatic.
    -- Returns the list of directly placed entities and scripted player interactable tunnel entities. Any other script reaction to entities being revived will lead to invalid entity references in the returned result.
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

    local pass2Ghosts, fuelProxies, placedEntities = {}, {}, {}

    for _, ghost in pairs(ghosts) do
        -- Special cases where the placed entity will be removed by other scripts.
        local tunnelPortalPosition, tunnelSegmentPosition
        if ghost.ghost_name == "railway_tunnel-tunnel_portal_surface-placed" then
            tunnelPortalPosition = ghost.position
        elseif ghost.ghost_name == "railway_tunnel-tunnel_segment_surface-placed" then
            tunnelSegmentPosition = ghost.position
        end

        -- Revive the ghost and handle the outcome.
        local revivedOutcome, revivedGhostEntity, fuelProxy = ghost.silent_revive({raise_revive = true, return_item_request_proxy = true})
        if revivedOutcome == nil then
            -- Train ghosts can't be revived before the rail underneath them, so save failed ghosts for a second pass.
            table.insert(pass2Ghosts, ghost)
        elseif revivedGhostEntity ~= nil and revivedGhostEntity.valid then
            -- Only record valid entities, anything else is passed help.
            table.insert(placedEntities, revivedGhostEntity)
        elseif #revivedOutcome == 0 then
            -- Entity was revived and instantly removed by a script event.
            if tunnelPortalPosition ~= nil then
                -- Tunnel Portal was revived.
                local tunnelEntity = testSurface.find_entity("railway_tunnel-tunnel_portal_surface-placed", tunnelPortalPosition)
                table.insert(placedEntities, tunnelEntity)
            elseif tunnelSegmentPosition ~= nil then
                -- Tunnel Segment was revived.
                local tunnelEntity = testSurface.find_entity("railway_tunnel-tunnel_segment_surface-placed", tunnelSegmentPosition)
                table.insert(placedEntities, tunnelEntity)
            end
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

    TestFunctions.MakeCarriagesUnique(placedEntities)

    return placedEntities
end

--- Makes all the train carriages in the provided entity list unique via color or cargo. Can take a random list of entities safely. Helps make train snapshot comparison easier if every carriage is unique.
--- Only needed if trains are being built manually/scripted and not via TestFunctions.BuildBlueprintFromString().
---@param entities LuaEntity[]
TestFunctions.MakeCarriagesUnique = function(entities)
    local cargoWagonCount, fluidWagonCount, artilleryWagonCount = 0, 0, 0
    for _, carriage in pairs(Utils.GetTableValueWithInnerKeyValue(entities, "type", "locomotive", true, false)) do
        carriage.train.manual_mode = false
        carriage.color = {math.random(0, 255), math.random(0, 255), math.random(0, 255), 1}
    end
    for _, carriage in pairs(Utils.GetTableValueWithInnerKeyValue(entities, "type", "cargo-wagon", true, false)) do
        cargoWagonCount = cargoWagonCount + 1
        carriage.insert({name = "iron-plate", count = cargoWagonCount})
    end
    for _, carriage in pairs(Utils.GetTableValueWithInnerKeyValue(entities, "type", "fluid-wagon", true, false)) do
        fluidWagonCount = fluidWagonCount + 1
        carriage.insert({name = "water", count = fluidWagonCount})
    end
    for _, carriage in pairs(Utils.GetTableValueWithInnerKeyValue(entities, "type", "artillery-wagon", true, false)) do
        artilleryWagonCount = artilleryWagonCount + 1
        carriage.insert({name = "artillery-shell", count = artilleryWagonCount})
    end
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

---@param carriage1 CarriageSnapshot
---@param carriage2 CarriageSnapshot
---@param reverseFacingForwardsCarriage2 boolean
---@return string
TestFunctions._CarriageSnapshotsMatch = function(carriage1, carriage2, reverseFacingForwardsCarriage2)
    if carriage1 == nil then
        return "carriage1 is nil"
    elseif carriage2 == nil then
        return "carriage2 is nil"
    end
    for _, attribute in pairs({"name", "health", "facingForwards", "cargoInventory", "color"}) do
        if attribute == "facingForwards" and reverseFacingForwardsCarriage2 then
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
