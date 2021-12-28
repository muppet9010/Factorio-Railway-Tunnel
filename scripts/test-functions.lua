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
---@param eventName string @ Name of the event, used when triggering it.
---@param testFunction function @ Function thats called when the event is triggered.
TestFunctions.RegisterTestsScheduledEventType = function(testName, eventName, testFunction)
    local completeName = "Test." .. testName .. "." .. eventName
    EventScheduler.RegisterScheduledEventType(completeName, testFunction)
end

--- Schedule an event named function once at a given tick. To be called from Start().
---@param tick Tick
---@param testName TestName
---@param eventName string @ Name of the event to trigger.
---@param instanceId string @ OPTIONAL - Unique id for this scheduled once event. Uses testName if not provided.
---@param eventData table @ OPTIONAL - data table passed back in to the handler function when triggered.
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
---@param eventName string @ Name of the event to trigger.
---@param instanceId string @ OPTIONAL - Unique id for this scheduled once event. Uses testName if not provided.
---@param eventData table @ OPTIONAL - data table passed back in to the handler function when triggered.
TestFunctions.ScheduleTestsEveryTickEvent = function(testName, eventName, instanceId, eventData)
    local completeName = "Test." .. testName .. "." .. eventName
    if instanceId == nil then
        instanceId = testName
    end
    EventScheduler.ScheduleEventEachTick(completeName, instanceId, eventData)
end

--- Remove any instances of future scheduled once events. To be called from Stop().
---@param testName TestName
---@param eventName string @ Name of the event to remove the schedule of.
---@param instanceId string @ OPTIONAL - Unique id for this scheduled once event. Uses testName if not provided.
TestFunctions.RemoveTestsOnceEvent = function(testName, eventName, instanceId)
    local completeName = "Test." .. testName .. "." .. eventName
    EventScheduler.RemoveScheduledOnceEvents(completeName, instanceId)
end

--- Remove any instances of future scheduled every tick events. To be called from Stop().
---@param testName TestName
---@param eventName string @ Name of the event to remove the schedule of.
---@param instanceId string @ OPTIONAL - Unique id for this scheduled once event. Uses testName if not provided.
TestFunctions.RemoveTestsEveryTickEvent = function(testName, eventName, instanceId)
    local completeName = "Test." .. testName .. "." .. eventName
    EventScheduler.RemoveScheduledEventFromEachTick(completeName, instanceId)
end

--- Register a unique name and function to react to a named event. Will only trigger when this test is active. Must be called from OnLoad() and Start().
---@param testName TestName
---@param eventName defines.events @ The Factorio event to react to.
---@param testFunctionName string @ Unique name of this event function handler.
---@param testFunction function @ Function to be triggered when the event occurs.
---@param filterData EventFilter @ OPTIONAL - Factorio event filter to be used.
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
---@field carriageCount uint @ how many carriages are in this train.
---@field carriages CarriageSnapshot[]

---@class CarriageSnapshot
---@field name string @ Entity prototype name
---@field health float @ How much health the carriage has.
---@field facingForwards boolean @ If the carriage is facing forwards relative to the train's front.
---@field cargoInventory string @ The cargo of non-locomotives as a JSON string.
---@field color string @ Color attribute as a JSON string.

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
        for _, currentCarriageIterator in pairs({"iterateCarriagesForwards", "iterateCarriagesBackwards"}) do
            local difference
            for carriageNumber = 1, currentTrainSnapshot.carriageCount do
                local currentCarriageCount
                if currentCarriageIterator == "iterateCarriagesForwards" then
                    currentCarriageCount = carriageNumber
                else
                    currentCarriageCount = (carriageNumber - #currentSnapshotCarriages) + 1
                end
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

--- Builds a given blueprint string centered on the given position. Handles train fuel requests and placing train carriages on rails. Any placed trains set to automatic mode in the blueprint will automatically start running. To aid train comparison the locomotives are given a random color and train wagons (cargo, fluid, artillery) have random items put in them so they are each unique.
---@param blueprintString string
---@param position Position
---@param testName TestName
---@return LuaEntity[] placedEntities @ all build entities
---@return table<string, LuaEntity[]> placedEntitiesByType @ the key entities built grouped on their prototype type.
TestFunctions.BuildBlueprintFromString = function(blueprintString, position, testName)
    -- This is the list of entity types that will be unique tracked and returned for easy accessing by test functions. Adding rare types is fine, but anything really generic could be obtained within the test by Utils.GetTableValueWithInnerKeyValue() and may be lower UPS.
    ---@type table<string, LuaEntity[]>
    local placedEntitiesByType = {["locomotive"] = {}, ["cargo-wagon"] = {}, ["fluid-wagon"] = {}, ["artillery-wagon"] = {}, ["train-stop"] = {}}

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
        by_player = player,
        skip_fog_of_war = true
    }
    if #ghosts == 0 then
        error("Blueprint in test failed to place, likely outside of generated/revealed area. Test: " .. testName)
    end
    itemStack.clear()

    ---@typelist table<number, LuaEntity>, table<number, LuaEntity>, table<number, LuaEntity>
    local pass2Ghosts, fuelProxies, placedEntities = {}, {}, {}

    -- Try to revive all the ghosts. Some may fail and we will try these again as a second pass.
    for _, ghost in pairs(ghosts) do
        TestFunctions._ReviveGhost(ghost, pass2Ghosts, fuelProxies, placedEntities, testName, placedEntitiesByType)
    end

    -- Try to revive then ghosts that failed the first time. This is generally carriages that try to be revived before the rails they are on.
    for _, ghost in pairs(pass2Ghosts) do
        TestFunctions._ReviveGhost(ghost, nil, fuelProxies, placedEntities, testName, placedEntitiesByType)
    end

    for _, fuelProxy in pairs(fuelProxies) do
        for item, count in pairs(fuelProxy.item_requests) do
            fuelProxy.proxy_target.insert({name = item, count = count})
        end
        fuelProxy.destroy()
    end

    TestFunctions.MakeCarriagesUnique(placedEntitiesByType["locomotive"], placedEntitiesByType["cargo-wagon"], placedEntitiesByType["fluid-wagon"], placedEntitiesByType["artillery-wagon"])

    return placedEntities, placedEntitiesByType
end

--- Makes all the train carriages in the provided entity lists unique via color or cargo. Helps make train snapshot comparison easier if every carriage is unique.
--- Only needs calling if trains are being built manually/scripted, as TestFunctions.BuildBlueprintFromString() includes it.
---@param locomotives LuaEntity[]|null
---@param cargoWagons LuaEntity[]|null
---@param fluidWagons LuaEntity[]|null
---@param artilleryWagons LuaEntity[]|null
TestFunctions.MakeCarriagesUnique = function(locomotives, cargoWagons, fluidWagons, artilleryWagons)
    local cargoWagonCount, fluidWagonCount, artilleryWagonCount = 0, 0, 0
    if locomotives ~= nil then
        for _, carriage in pairs(locomotives) do
            carriage.train.manual_mode = false
            carriage.color = {math.random(0, 255), math.random(0, 255), math.random(0, 255), 1}
        end
    end
    if cargoWagons ~= nil then
        for _, carriage in pairs(cargoWagons) do
            cargoWagonCount = cargoWagonCount + 1
            carriage.insert({name = "iron-plate", count = cargoWagonCount})
        end
    end
    if fluidWagons ~= nil then
        for _, carriage in pairs(fluidWagons) do
            fluidWagonCount = fluidWagonCount + 1
            carriage.insert({name = "water", count = fluidWagonCount})
        end
    end
    if artilleryWagons ~= nil then
        for _, carriage in pairs(artilleryWagons) do
            artilleryWagonCount = artilleryWagonCount + 1
            carriage.insert({name = "artillery-shell", count = artilleryWagonCount})
        end
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

-- The function called to revive the ghosts on the first and second attempt. It populates a bunch of passed in tables, rather than returning anything itself.
---@param ghost LuaEntity
---@param pass2GhostsTableToPopulate table<number, LuaEntity> @ table passed in that is populated for use by the calling function.
---@param fuelProxiesTableToPopulate table<number, LuaEntity> @ table passed in that is populated for use by the calling function.
---@param placedEntitiesTableToPopulate table<number, LuaEntity> @ table passed in that is populated for use by the calling function.
---@param testName string
---@param placedEntitiesByTypeTableToPopulate table<string, LuaEntity[]> @ table passed in that is populated for use by the calling function.
TestFunctions._ReviveGhost = function(ghost, pass2GhostsTableToPopulate, fuelProxiesTableToPopulate, placedEntitiesTableToPopulate, testName, placedEntitiesByTypeTableToPopulate)
    local ghostType = ghost.ghost_type

    -- Revive the ghost and handle the outcome.
    local revivedOutcome, revivedGhostEntity, fuelProxy = ghost.silent_revive({raise_revive = true, return_item_request_proxy = true})
    if revivedOutcome == nil then
        if pass2GhostsTableToPopulate ~= nil then
            -- Train ghosts can't be revived before the rail underneath them, so save failed ghosts for a second pass.
            table.insert(pass2GhostsTableToPopulate, ghost)
        else
            error("only 2 rounds of ghost reviving supported. Test: " .. testName)
        end
    elseif revivedGhostEntity ~= nil and revivedGhostEntity.valid then
        -- Only record valid entities, anything else is passed help.
        table.insert(placedEntitiesTableToPopulate, revivedGhostEntity)
        if placedEntitiesByTypeTableToPopulate[ghostType] ~= nil then
            table.insert(placedEntitiesByTypeTableToPopulate[ghostType], revivedGhostEntity)
        end
    elseif #revivedOutcome == 0 then
        -- Entity was revived and instantly removed by a script event.
        error("this shouldn't be hit any more")
    end

    -- Add fuel if its in the blueprint for this entity.
    if fuelProxy ~= nil then
        table.insert(fuelProxiesTableToPopulate, fuelProxy)
    end
end

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
