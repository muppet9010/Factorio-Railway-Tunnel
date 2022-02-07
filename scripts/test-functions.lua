local TestFunctions = {}
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Events = require("utility/events")
local Colors = require("utility/colors")
local Common = require("scripts/common")

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
---@param testName TestManager_TestName
---@return TestManager_TestData
TestFunctions.GetTestDataObject = function(testName)
    return global.testManager.testData[testName]
end

--- Gets the test manager's test object reference. Persists across tests.
---@param testName TestManager_TestName
---@return TestManager_Test
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

--- Complete the current test.
---@param testName TestManager_TestName
TestFunctions.TestCompleted = function(testName)
    game.print("Completed Test", Colors.lightgreen)
    MOD.Interfaces.TestManager.LogTestOutcome("Test Completed")
    local testManagerData = global.testManager.testsToRun[testName]
    MOD.Interfaces.TestManager.GetTestScript(testName).Stop(testName)
    if testManagerData.runLoopsCount == testManagerData.runLoopsMax then
        testManagerData.finished = true
        testManagerData.success = true
    end
    EventScheduler.RemoveScheduledOnceEvents("TestManager.WaitForPlayerThenRunTests_Scheduled")
    if not global.testManager.keepRunningTest then
        local delay = 1 + global.testManager.continueTestAfterCompletioTicks
        EventScheduler.ScheduleEventOnce(game.tick + delay, "TestManager.WaitForPlayerThenRunTests_Scheduled")
    end
end

--- Fail the current test.
---@param testName TestManager_TestName
---@param errorText string
TestFunctions.TestFailed = function(testName, errorText)
    game.print("Failure Message: " .. errorText, Colors.red)
    MOD.Interfaces.TestManager.LogTestOutcome("Test Failed: " .. errorText)
    local testManagerData = global.testManager.testsToRun[testName]
    MOD.Interfaces.TestManager.GetTestScript(testName).Stop(testName)
    if not global.testManager.justLogAllTests then
        testManagerData.finished = true
        testManagerData.success = false
        game.tick_paused = true
    end
    EventScheduler.RemoveScheduledOnceEvents("TestManager.WaitForPlayerThenRunTests_Scheduled")
    if global.testManager.justLogAllTests then
        -- Continue with scheduling next test when running all tests.
        EventScheduler.ScheduleEventOnce(game.tick + 1, "TestManager.WaitForPlayerThenRunTests_Scheduled")
    end
end
--- Goes in to the test log file after the equals sign on the current row. For rare cases a test wants to inject log data in for doign full test runs to file.
--- Can be called in all cases and will only write if "justLogAllTests" is enabled.
---@param text string
TestFunctions.LogTestDataToTestRow = function(text)
    MOD.Interfaces.TestManager.LogTestDataToTestRow(text)
end

--- Register a unique name and function for future event scheduling. Must be called from a test's OnLoad() and is a pre-requisite for any events to be scheduled during a test Start().
---@param testName TestManager_TestName
---@param eventName string @ Name of the event, used when triggering it.
---@param testFunction function @ Function thats called when the event is triggered.
TestFunctions.RegisterTestsScheduledEventType = function(testName, eventName, testFunction)
    local completeName = "Test." .. testName .. "." .. eventName
    EventScheduler.RegisterScheduledEventType(completeName, testFunction)
end

--- Schedule an event named function once at a given tick. To be called from Start().
--- When the event fires the registered function recieves a single UtilityScheduledEvent_CallbackObject argument.
---@param tick Tick
---@param testName TestManager_TestName
---@param eventName string @ Name of the event to trigger.
---@param instanceId? string|null @ Unique id for this scheduled once event. Uses testName if not provided.
---@param eventData? table|null @ Data table passed back in to the handler function when triggered.
TestFunctions.ScheduleTestsOnceEvent = function(tick, testName, eventName, instanceId, eventData)
    local completeName = "Test." .. testName .. "." .. eventName
    if instanceId == nil then
        instanceId = testName
    end
    EventScheduler.ScheduleEventOnce(tick, completeName, instanceId, eventData)
end

--- Schedule an event named function to run every tick until cancelled. To be called from Start().
--- When the event fires the registered function recieves a single UtilityScheduledEvent_CallbackObject argument.
---@param testName TestManager_TestName
---@param eventName string @ Name of the event to trigger.
---@param instanceId? string|null @ Unique id for this scheduled once event. Uses testName if not provided.
---@param eventData? table|null @ Data table passed back in to the handler function when triggered.
TestFunctions.ScheduleTestsEveryTickEvent = function(testName, eventName, instanceId, eventData)
    local completeName = "Test." .. testName .. "." .. eventName
    if instanceId == nil then
        instanceId = testName
    end
    EventScheduler.ScheduleEventEachTick(completeName, instanceId, eventData)
end

--- Remove any instances of future scheduled once events. To be called from Stop().
---@param testName TestManager_TestName
---@param eventName string @ Name of the event to remove the schedule of.
---@param instanceId? string|null @ Unique id for this scheduled once event. Uses testName if not provided.
TestFunctions.RemoveTestsOnceEvent = function(testName, eventName, instanceId)
    local completeName = "Test." .. testName .. "." .. eventName
    EventScheduler.RemoveScheduledOnceEvents(completeName, instanceId)
end

--- Remove any instances of future scheduled every tick events. To be called from Stop().
---@param testName TestManager_TestName
---@param eventName string @ Name of the event to remove the schedule of.
---@param instanceId? string|null @ Unique id for this scheduled once event. Uses testName if not provided.
TestFunctions.RemoveTestsEveryTickEvent = function(testName, eventName, instanceId)
    local completeName = "Test." .. testName .. "." .. eventName
    EventScheduler.RemoveScheduledEventFromEachTick(completeName, instanceId)
end

--- Register a unique name and function to react to a named event. Will only trigger when this test is active. Must be called from OnLoad() and Start().
---@param testName TestManager_TestName
---@param eventName defines.events @ The Factorio event to react to.
---@param testFunctionName string @ Unique name of this event function handler.
---@param testFunction function @ Function to be triggered when the event occurs.
---@param filterData? EventFilter|null @ Factorio event filter to be used.
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

--- Used to apply an optional filter list of keys against a full list of key/values. Includes error catching for passing in bad (empty) filter list.
---@param fullList table
---@param filterList? table|null
---@return table
TestFunctions.ApplySpecificFilterToListByKeyName = function(fullList, filterList)
    if Utils.IsTableEmpty(fullList) then
        error("empty/nil list provided to TestFunctions.ApplySpecificFilterToListByKeyName()")
    end
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
        error("blank list output from TestFunctions.ApplySpecificFilterToListByKeyName(). Check input arguments.")
    end
    return listToTest
end

--- Registers for tunnel usage change notifications to be recorded in the Test Data object's tunnelUsageChanges field. To be called from Start().
--- Used when a test will check tunnel usage events once per tick.
--- Doesn't distinguish between different tunnels or usage entries, so only suitable for tests with a single tunnel.
--- If multiple actions occur in the same tick only the last one is visible in the "lastAction" and "lastChangeReason" fields which shouldn't be an issue for normal tests. All the events are in the "actions" field.
--- If a test needs to react to each train state change in turn then the TestFunctions.RegisterTunnelUsageChangesToTestFunction() function should be used instead.
---@param testName string
TestFunctions.RegisterRecordTunnelUsageChanges = function(testName)
    TestFunctions.RegisterTestsEventHandler(testName, remote.call("railway_tunnel", "get_tunnel_usage_changed_event_id"), "TestFunctions._RecordTunnelUsageChanges", TestFunctions._RecordTunnelUsageChanges)
end

--- Registers for tunnel usage change notifications to be passed to a test function for processing sequentially. To be called from Start().
--- Used when a tests needs to react to each event in turn. In most use cases tests only need to check the lastest tunnel usage event per tick and the TestFunctions.RegisterRecordTunnelUsageChanges() function is more approperiate.
---@param testName string
---@param testCallbackFunction function @ When called recieves a single argument "event" of type TestFunctions_RemoteTunnelUsageChangedEvent.
TestFunctions.RegisterTunnelUsageChangesToTestFunction = function(testName, testCallbackFunction)
    TestFunctions.RegisterTestsEventHandler(testName, remote.call("railway_tunnel", "get_tunnel_usage_changed_event_id"), "TestFunctions.RegisterTunnelUsageChangesToTestFunction", testCallbackFunction)
end

---@alias TestFunctions_TrainSnapshot TestFunctions_CarriageSnapshot[]

---@class TestFunctions_CarriageSnapshot
---@field name string @ Entity prototype name
---@field health float @ How much health the carriage has.
---@field facingForwards boolean @ If the carriage is facing forwards relative to the train's front carriage orientation.
---@field cargoInventory string @ The cargo of non-locomotives as a JSON string.
---@field color string @ Color attribute as a JSON string.

--- Returns an abstract view of a train purely for the purpose of being compared before and after using a tunnel. Either the expected forwards orientation parameter must be provided or the train must be moving when snapshot taken. Its not valid to compare snapshots if the train has changed direction (forwards/backwards) between snapshots.
---@param train LuaTrain
---@param forwardsOrientation RealOrientation @ The forwards orientation of this train. If provided the function can be used for a 0 speed train.
---@return TestFunctions_TrainSnapshot
TestFunctions.GetSnapshotOfTrain = function(train, forwardsOrientation)
    -- Gets a snapshot of a train carriages details. Allows comparing train carriages without having to use their unit_number, so supports post cloning, etc.
    -- Doesn't check fuel as this can be used up between snapshots.
    -- Any table values for comparing should be converted to JSON to make them simple to compare later.

    ---@type TestFunctions_TrainSnapshot
    local trainSnapshot = {}

    -- Work out initial orientation and facing values. If forwardsOrientation of the train is given then use that, otherwise have to use the trains speed.
    local previousCarriageOrientation  ---@type RealOrientation
    local previousCarriageFacingFowards  ---@type boolean
    if forwardsOrientation ~= nil then
        previousCarriageOrientation = forwardsOrientation
        previousCarriageFacingFowards = true
    else
        if train.speed == 0 then
            error("TestFunctions.GetSnapshotOfTrain() called for 0 speed train and no forwardsOrientation provided")
        end
        previousCarriageOrientation = train.carriages[1].orientation
        if train.speed == train.carriages[1].speed then
            previousCarriageFacingFowards = true
        else
            previousCarriageFacingFowards = false
        end
    end

    -- Iterate over the trian carriages and work out their facing details.
    for _, realCarriage in pairs(train.carriages) do
        ---@type TestFunctions_CarriageSnapshot
        local snapshotCarriage = {
            name = realCarriage.name,
            health = realCarriage.health
        }

        -- A train on a curve will have the same facing carriages roughly on the same orientation as the ones each side.
        -- Handle the number wraping within 1 and 0. If its closer < 0.25 either way then its facing same direction, > 0.25 and < 0.75 then its facing away.
        if (realCarriage.orientation > previousCarriageOrientation - 0.25 and realCarriage.orientation < previousCarriageOrientation + 0.25) or realCarriage.orientation > previousCarriageOrientation + 0.75 or realCarriage.orientation < previousCarriageOrientation - 0.75 then
            snapshotCarriage.facingForwards = previousCarriageFacingFowards
        else
            snapshotCarriage.facingForwards = not previousCarriageFacingFowards
        end

        if realCarriage.type ~= "locomotive" then
            -- Exclude locomotives as we don't want to track their fuel amounts, as they'll be used as the train moves.
            snapshotCarriage.cargoInventory = game.table_to_json(realCarriage.get_inventory(defines.inventory.cargo_wagon).get_contents())
        end
        table.insert(trainSnapshot, snapshotCarriage)

        if realCarriage.color ~= nil then
            snapshotCarriage.color = game.table_to_json(realCarriage.color)
        end

        previousCarriageOrientation, previousCarriageFacingFowards = realCarriage.orientation, snapshotCarriage.facingForwards
    end
    return trainSnapshot
end

--- Compares 2 train snapshots to see if they are the same train structure for when a train enters and then leaves a tunnel. Snpshots can not be compared between tunnel uses if the train has reversed its movement direction. This limitation is required as otherwise some malformed trains can't be distinguished from valid trains.
---@param origionalTrainSnapshot TestFunctions_TrainSnapshot @ Origional train's snapshot as obtained by TestFunctions.TESTGetSnapshotOfTrain().
---@param currentTrainSnapshot TestFunctions_TrainSnapshot @ New train's snapshot as obtained by TestFunctions.TESTGetSnapshotOfTrain().
---@param allowPartialCurrentSnapshot? boolean|null @ Defaults to false. if TRUE the current snapshot can be one end of the origonal train.
---@return boolean ifSnapshotsAreIdentical.
TestFunctions.AreTrainSnapshotsIdentical = function(origionalTrainSnapshot, currentTrainSnapshot, allowPartialCurrentSnapshot)
    -- If we don't allow partial trains then check the carriage counts are the same, as is a simple failure.
    allowPartialCurrentSnapshot = allowPartialCurrentSnapshot or false
    if not allowPartialCurrentSnapshot and #origionalTrainSnapshot ~= #currentTrainSnapshot then
        return false
    end

    -- Check the 2 trains in the 2 valid forms to see if they match in either of them and are thus the same train. Check the trains in the same iteration & facing first to see if they just match, and then check them in reverse iteration & reverse facing to see if they are just "flipped".
    for _, comparisonType in pairs({"same", "reversed"}) do
        local difference
        -- Loop over each carriage in the train for this comparison setup looking for differences.
        for origionalCarriageNumber = 1, #origionalTrainSnapshot do
            local reverseCurrentCarriage, currentCarriageNumber
            if comparisonType == "same" then
                reverseCurrentCarriage = false
                currentCarriageNumber = origionalCarriageNumber
            else
                reverseCurrentCarriage = true
                currentCarriageNumber = #origionalTrainSnapshot - (origionalCarriageNumber - 1)
            end
            difference = TestFunctions._DifferenceBetween2CarriageSnapshots(origionalTrainSnapshot[origionalCarriageNumber], currentTrainSnapshot[currentCarriageNumber], reverseCurrentCarriage)
            if difference ~= nil then
                -- A difference found in this train's carriage so stop checking this comparison setup.

                if not allowPartialCurrentSnapshot then
                    -- If the function was called not allowing partial train compare then a mismatch of carriage counts here is a code bug in this compare function.
                    if difference == "carriage1 is nil" or difference == "carriage2 is nil" then
                        error("Comparing train snapshots went wrong on working out carriages to compare")
                    end
                end

                -- Stop checking this train.
                break
            end
        end

        -- If no difference is found across the entire train then it must match in this configuration, thus is the same train snapshot.
        if difference == nil then
            return true
        end
    end
    --end

    -- All combinations tested and none had no differences, so train snapshots don't match.
    return false
end

--- Used to specify a train carriage type as a human readable text string. The orientation of "Forwards" is defined at the building stage.
---    carriageSymbols:
---    <   forwards loco
---    >   rear loco
---    -   forwards cargo wagon
---    =   rear cargo wagon
---@alias TestFunctions_CarriageTextualRepresentation "<"|">"|"-"|"="

---@class TestFunctions_TrainSpecifiction @ used to specify a trains details in short-hand. Is parsed for usage in to full table by TestFunctions.GetTrainCompositionFromTextualRepresentation().
---@field composition TestFunctions_CarriageTextualRepresentation[] @ Ordered front to back of the train.
---@field startingSpeed? double|null @ The speed the train starts at, defaults to 0. This is in relation to the orientation of "Forwards" as defined at the building stage.

--- Works out the train carriage details to be placed from the compositon text.
---@param trainSpecification TestFunctions_TrainSpecifiction
---@return TestFunctions_TrainCarriageDetailsForBulding[] trainCarriageDetailsForBulding
TestFunctions.GetTrainCompositionFromTextualRepresentation = function(trainSpecification)
    local trainCarriageDetailsForBulding = {}
    for i = 1, #trainSpecification.composition do
        local text = string.sub(trainSpecification.composition, i, i)
        local prototypeName, facingForwards
        if text == "<" then
            prototypeName = "locomotive"
            facingForwards = true
        elseif text == ">" then
            prototypeName = "locomotive"
            facingForwards = false
        elseif text == "-" then
            prototypeName = "cargo-wagon"
            facingForwards = true
        elseif text == "=" then
            prototypeName = "cargo-wagon"
            facingForwards = false
        else
            error("TestFunctions.GetTrainCompositionFromTextualRepresentation - unrecognised textual representation: '" .. tostring(text) .. "'")
        end
        table.insert(
            trainCarriageDetailsForBulding,
            {
                prototypeName = prototypeName,
                facingForwards = facingForwards
            }
        )
    end
    return trainCarriageDetailsForBulding
end

---@class TestFunctions_TrainCarriageDetailsForBulding
---@field prototypeName string
---@field facingForwards boolean

--- Builds a train from a set starting position away from the "forwards" direction. Locomotives are randomly colored.
---@param firstCarriageFrontLocation Position @ The front tip of the lead carriages collision box.
---@param carriagesDetails TestFunctions_TrainCarriageDetailsForBulding[] @ The carriages to be built, listed front to back.
---@param trainForwardsDirection defines.direction @ Only supports cardinal points.
---@param playerInCarriageNumber? uint|null
---@param startingSpeed? double|null @ This is in relation to the orientation of forwards.
---@param locomotiveFuel? ItemStackIdentification|null @ Fuel put in all "locomotive" typed entities.
---@return LuaTrain
TestFunctions.BuildTrain = function(firstCarriageFrontLocation, carriagesDetails, trainForwardsDirection, playerInCarriageNumber, startingSpeed, locomotiveFuel)
    local placedCarriage  ---@type LuaEntity
    local surface, force = TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()
    local placementPosition = firstCarriageFrontLocation
    local locomotivesBuilt, cargoWagonsBuilt = {}, {}
    local trainReverseDirection = Utils.LoopDirectionValue(trainForwardsDirection + 4)
    local trainForwardsOrientation = trainForwardsDirection / 8
    for carriageNumber, carriageDetails in pairs(carriagesDetails) do
        local carriageEndPositionOffset = Utils.RotatePositionAround0(trainForwardsOrientation, {x = 0, y = Common.CarriagePlacementDistances[carriageDetails.prototypeName]})
        -- Move placement position on by the front distance of the carriage to be placed, prior to its placement.
        placementPosition = Utils.ApplyOffsetToPosition(placementPosition, carriageEndPositionOffset)
        local carriageBuildDirection
        if carriageDetails.facingForwards then
            carriageBuildDirection = trainForwardsDirection
        else
            carriageBuildDirection = trainReverseDirection
        end
        placedCarriage = surface.create_entity {name = carriageDetails.prototypeName, position = placementPosition, direction = carriageBuildDirection, force = force, raise_built = false, create_build_effect_smoke = false}
        local placedCarriage_type = placedCarriage.type
        -- Move placement position on by the back distance of the carriage thats just been placed. Then ready for the next carriage and its unique distance.
        placementPosition = Utils.ApplyOffsetToPosition(placementPosition, carriageEndPositionOffset)

        -- Store what we built by type for use later.
        if placedCarriage_type == "locomotive" then
            table.insert(locomotivesBuilt, placedCarriage)
        elseif placedCarriage_type == "cargo-wagon" then
            table.insert(cargoWagonsBuilt, placedCarriage)
        else
            error("TestFunctions.BuildTrain - unsupported carriage type built: " .. placedCarriage_type)
        end

        -- Insert the fuel if approperiate.
        if placedCarriage_type == "locomotive" and locomotiveFuel ~= nil then
            placedCarriage.insert(locomotiveFuel)
        end

        -- Place the player in this carriage if set. Done here as we know the exact build order at this point.
        if playerInCarriageNumber ~= nil and playerInCarriageNumber == carriageNumber then
            local player = game.connected_players[1]
            if player ~= nil then
                placedCarriage.set_driver(player)
            else
                game.print("No player found to set as driver, test continuing regardless")
            end
        end
    end

    local train = placedCarriage.train

    -- Set the speed on the last carriage.
    if startingSpeed ~= nil and startingSpeed ~= 0 then
        train.speed = startingSpeed
        local expectedSpeed
        if carriagesDetails[#carriagesDetails].facingForwards then
            expectedSpeed = startingSpeed
        else
            expectedSpeed = -startingSpeed
        end
        if placedCarriage.speed ~= expectedSpeed then
            train.speed = -startingSpeed
        end
    end

    TestFunctions.MakeCarriagesUnique(locomotivesBuilt, cargoWagonsBuilt)

    return train
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

---@class TestFunctions_PlacedEntitiesByGroup @ The key entities built by TestFunctions.BuildBlueprintFromString() grouped on their prototype type or prototype name.
---@field locomotive LuaEntity[]
---@field cargo-wagon LuaEntity[]
---@field fluid-wagon LuaEntity[]
---@field artillery-wagon LuaEntity[]
---@field train-stop LuaEntity[]
---@field railway_tunnel-portal_end LuaEntity[]
---@field railway_tunnel-underground_segment-straight LuaEntity[]

--- Builds a given blueprint string centered on the given position. Handles train fuel requests and placing train carriages on rails. Any placed trains set to automatic mode in the blueprint will automatically start running. To aid train comparison the locomotives are given a random color and train wagons (cargo, fluid, artillery) have random items put in them so they are each unique.
---@param blueprintString string
---@param position Position
---@param testName TestManager_TestName
---@return LuaEntity[] placedEntities @ all build entities
---@return TestFunctions_PlacedEntitiesByGroup placedEntitiesByGroup @ the key entities built grouped on their prototype type or prototype name.
TestFunctions.BuildBlueprintFromString = function(blueprintString, position, testName)
    -- This is the lists of entity types that will be unique tracked and returned for easy accessing by test functions. Adding low instance types per BP is fine if multiple test needs them, but anything thats in a BP in high quantity (ie. rail) should be obtained within the test by Utils.GetTableValueWithInnerKeyValue() and may be lower UPS.
    ---@type table<string, LuaEntity[]>
    local placedEntitiesByType = {["locomotive"] = {}, ["cargo-wagon"] = {}, ["fluid-wagon"] = {}, ["artillery-wagon"] = {}, ["train-stop"] = {}}
    -- This is the entity types that will have their name checked against the placedEntitiesByName list. As most entity types don't need checking for inclusion in the list. Key is the entity type and value is if it should be checked. Defaults to not checked if not included in the list.
    ---@type table<string, boolean>
    local entityTypesToCheckNameOn = {["simple-entity-with-owner"] = true}
    -- List of entity names that will be recorded if the built entity is of a type in the entityTypesToCheckNameOn list. This is just to save checking entities we don't need too.
    ---@type table<string, LuaEntity[]>
    local placedEntitiesByName = {["railway_tunnel-portal_end"] = {}, ["railway_tunnel-underground_segment-straight"] = {}}

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

    local pass2Ghosts = {} ---@type table<number, LuaEntity>
    local fuelProxies = {} ---@type table<number, LuaEntity>
    local placedEntities = {} ---@type table<number, LuaEntity>

    -- Try to revive all the ghosts. Some may fail and we will try these again as a second pass.
    for _, ghost in pairs(ghosts) do
        TestFunctions._ReviveGhost(ghost, pass2Ghosts, fuelProxies, placedEntities, testName, placedEntitiesByType, placedEntitiesByName, entityTypesToCheckNameOn)
    end

    -- Try to revive then ghosts that failed the first time. This is generally carriages that try to be revived before the rails they are on.
    for _, ghost in pairs(pass2Ghosts) do
        TestFunctions._ReviveGhost(ghost, nil, fuelProxies, placedEntities, testName, placedEntitiesByType, placedEntitiesByName, entityTypesToCheckNameOn)
    end

    for _, fuelProxy in pairs(fuelProxies) do
        for item, count in pairs(fuelProxy.item_requests) do
            fuelProxy.proxy_target.insert({name = item, count = count})
        end
        fuelProxy.destroy()
    end

    TestFunctions.MakeCarriagesUnique(placedEntitiesByType["locomotive"], placedEntitiesByType["cargo-wagon"], placedEntitiesByType["fluid-wagon"], placedEntitiesByType["artillery-wagon"])

    return placedEntities, Utils.TableMergeCopies({placedEntitiesByType, placedEntitiesByName})
end

--- Makes all the train carriages in the provided entity lists unique via color or cargo. Helps make train snapshot comparison easier if every carriage is unique.
--- Only needs calling if trains are being built manually/scripted, as TestFunctions.BuildBlueprintFromString() includes it.
---@param locomotives? LuaEntity[]|null
---@param cargoWagons? LuaEntity[]|null
---@param fluidWagons? LuaEntity[]|null
---@param artilleryWagons? LuaEntity[]|null
TestFunctions.MakeCarriagesUnique = function(locomotives, cargoWagons, fluidWagons, artilleryWagons)
    local cargoWagonCount, fluidWagonCount, artilleryWagonCount = 0, 0, 0
    if locomotives ~= nil then
        local color, colorId, secondaryColorsRemaining
        local primaryColorsRemaining = Utils.DeepCopy(TestFunctions.PrimaryLocomotiveColors)
        local currentColorRange, colorLoops = primaryColorsRemaining, 0
        for _, carriage in pairs(locomotives) do
            carriage.train.manual_mode = false

            -- Do preset colors to avoid 2 colors being very close to each other and don't repeat within the same train.

            -- If theres no current colors left then nede to look for more.
            if #currentColorRange == 0 then
                if secondaryColorsRemaining == nil then
                    -- Secondary colors not initialised so get them and switch to them.
                    secondaryColorsRemaining = Utils.DeepCopy(TestFunctions.SecondaryLocomotiveColors)
                    currentColorRange = secondaryColorsRemaining
                else
                    -- Second colors have all been used up so repopulate the primary and clear the secondary in case later use needs them.
                    secondaryColorsRemaining = nil
                    primaryColorsRemaining = Utils.DeepCopy(TestFunctions.PrimaryLocomotiveColors)
                    currentColorRange = primaryColorsRemaining
                    colorLoops = colorLoops + 1
                end
            end

            -- Get a random color and apply it.
            colorId = math.random(1, #currentColorRange)
            color = currentColorRange[colorId]
            color[4] = 255 - colorLoops -- This ensures that the color is techncially unique as on the full usage of all primary and secondary colors the alpha will be 1 lower for all colors in the new range usage.
            carriage.color = color

            -- Remove the color from the current range.
            table.remove(currentColorRange, colorId)
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

--- A debug function to write out the test's testScenario's details to a csv for manually checking in excel.
---@param testName string @ Used in the file name and appended with "-TestScenarios.csv".
---@param testScenarios table @ The test scenario table.
TestFunctions.WriteTestScenariosToFile = function(testName, testScenarios)
    -- game will be nil on loading a save.
    if game == nil then
        return
    end

    -- Get all the keys across all of the test scenario's as some scenarios may have different keys to others.
    local keysToRecord = {}
    for _, test in pairs(testScenarios) do
        for key in pairs(test) do
            if keysToRecord[key] == nil then
                keysToRecord[key] = key
            end
        end
    end

    -- Add the headers.
    local logText = "#, " .. Utils.TableValueToCommaString(keysToRecord) .. "\r\n"
    -- Add the test's keys
    for testIndex, test in pairs(testScenarios) do
        logText = logText .. tostring(testIndex)
        for key in pairs(keysToRecord) do
            logText = logText .. ", " .. tostring(test[key])
        end
        logText = logText .. "\r\n"
    end
    -- Write out the file.
    local fileName = testName .. "-TestScenarios.csv"
    game.write_file(fileName, logText, false)
end

--- A primary list of unique colors for use on locomotives.
TestFunctions.PrimaryLocomotiveColors = {
    Colors.red,
    Colors.darkorange,
    Colors.yellow,
    Colors.lime,
    Colors.cyan,
    Colors.blue,
    Colors.darkviolet,
    Colors.black,
    Colors.lavender
}

--- A secondary list of less unique colors for use on locomotives.
TestFunctions.SecondaryLocomotiveColors = {
    Colors.grey,
    Colors.teal,
    Colors.lightblue,
    Colors.green,
    Colors.brown,
    Colors.wheat,
    Colors.deeppink,
    Colors.olive,
    Colors.pink,
    Colors.darkred,
    Colors.salmon,
    Colors.slateblue,
    Colors.orchid,
    Colors.goldenrod
}

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

---@class TestFunctions_RemoteTunnelUsageChangedEvent : RemoteTunnelUsageChanged
---@field testName string

--- Records the tunnel usage change event's details to the test's Test Data object for usage within the test script in once per tick test processing. In most tests its limitations are fine.
---@param event TestFunctions_RemoteTunnelUsageChangedEvent
TestFunctions._RecordTunnelUsageChanges = function(event)
    local testData = TestFunctions.GetTestDataObject(event.testName)
    local tunnelUsageChanges = testData.tunnelUsageChanges

    -- Record the action for later reference.
    local actionListEntry = tunnelUsageChanges.actions[event.action]
    if actionListEntry then
        actionListEntry.count = actionListEntry.count + 1
        actionListEntry.recentChangeReason = event.changeReason
    else
        tunnelUsageChanges.actions[event.action] = {
            name = event.action,
            count = 1,
            recentChangeReason = event.changeReason
        }
    end

    tunnelUsageChanges.lastAction = event.action
    tunnelUsageChanges.lastChangeReason = event.changeReason
    tunnelUsageChanges.train = event.train
end

-- The function called to revive the ghosts on the first and second attempt. It populates a bunch of passed in tables, rather than returning anything itself.
---@param ghost LuaEntity
---@param pass2GhostsTableToPopulate table<number, LuaEntity> @ table passed in that is populated for use by the calling function.
---@param fuelProxiesTableToPopulate table<number, LuaEntity> @ table passed in that is populated for use by the calling function.
---@param placedEntitiesTableToPopulate table<number, LuaEntity> @ table passed in that is populated for use by the calling function.
---@param testName string
---@param placedEntitiesByTypeTableToPopulate table<string, LuaEntity[]> @ table passed in that is populated for use by the calling function.
---@param placedEntitiesByNameTableToPopulate table<string, LuaEntity[]> @ table passed in that is populated for use by the calling function.
---@param entityTypesToCheckNameOn table<string, boolean> @ table of entity types that should be checked to see if they're on the Name list. Key is the entity type and value is if it should be checked. Defaults to not checked if not included in the list.
TestFunctions._ReviveGhost = function(ghost, pass2GhostsTableToPopulate, fuelProxiesTableToPopulate, placedEntitiesTableToPopulate, testName, placedEntitiesByTypeTableToPopulate, placedEntitiesByNameTableToPopulate, entityTypesToCheckNameOn)
    local ghostType, ghostName = ghost.ghost_type, ghost.ghost_name

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
        -- Only check a few entity types to save getting the name of every entity we place.
        if entityTypesToCheckNameOn[ghostType] and placedEntitiesByNameTableToPopulate[ghostName] ~= nil then
            table.insert(placedEntitiesByNameTableToPopulate[ghostName], revivedGhostEntity)
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

--- Checks if 2 carriages are equal allowing for if the 2nd carriage is from reversed train. Returns the first difference attribute if one is found, or nil if they are the same.
---@param carriage1 TestFunctions_CarriageSnapshot
---@param carriage2 TestFunctions_CarriageSnapshot
---@param reversedCarriage2 boolean
---@return string|null differenceFound @ First difference found or nil if the same.
TestFunctions._DifferenceBetween2CarriageSnapshots = function(carriage1, carriage2, reversedCarriage2)
    if carriage1 == nil then
        return "carriage1 is nil"
    elseif carriage2 == nil then
        return "carriage2 is nil"
    end
    for _, attribute in pairs({"name", "health", "facingForwards", "cargoInventory", "color"}) do
        if attribute == "facingForwards" and reversedCarriage2 == true then
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
