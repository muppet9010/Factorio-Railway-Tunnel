local EventScheduler = require("utility/event-scheduler")
local TrainManager = {}
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")
local Utils = require("utility/utils")

TrainManager.CreateGlobals = function()
    global.trainManager = global.trainManager or {}
    global.trainManager.managedTrains = global.trainManager.managedTrains or {} --[[
        id = uniqiue id of this managed train passing through the tunnel.
        aboveTrainEntering = LuaTrain of the entering train on the world surface.
        aboveTrainEnteringId = The LuaTrain ID of the above Train Entering.
        aboveTrainLeaving = LuaTrain of the train created leaving the tunnel on the world surface.
        aboveTrainLeavingId = The LuaTrain ID of the above Train Leaving.
        trainTravelDirection = defines.direction the train is heading in.
        trainTravellingForwards = boolean if the train is moving forwards or backwards from its viewpoint.
        surfaceEntrancePortalEndSignal = the endSignal global object of the rail signal at the end of the entrance portal track (forced closed signal).
        surfaceExitPortalEndSignal = the endSignal global object of the rail signal at the end of the exit portal track (forced closed signal).
        tunnel = ref to the global tunnel object.
        origTrainSchedule = copy of the origional train schedule table made when triggered the managed train process.
        undergroundTrain = LuaTrain of the train created in the underground surface.
        aboveSurface = LuaSurface of the main world surface.
        undergroundSurface = LuaSurface of the specific underground surface.
        aboveTrainLeavingCarriagesPlaced = count of how many carriages placed so far in the above train while its leaving.
    ]]
    global.trainManager.enteringTrainIdToManagedTrain = global.trainManager.enteringTrainIdToManagedTrain or {}
    global.trainManager.leavingTrainIdToManagedTrain = global.trainManager.leavingTrainIdToManagedTrain or {}
end

TrainManager.OnLoad = function()
    Interfaces.RegisterInterface("TrainManager.TrainEnteringInitial", TrainManager.TrainEnteringInitial)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainEnteringOngoing", TrainManager.TrainEnteringOngoing)
    Events.RegisterHandlerEvent(defines.events.on_train_created, "TrainManager.TrainEnteringOngoing_OnTrainCreated", TrainManager.TrainEnteringOngoing_OnTrainCreated)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainUndergroundOngoing", TrainManager.TrainUndergroundOngoing)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainLeavingInitial", TrainManager.TrainLeavingInitial)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainLeavingOngoing", TrainManager.TrainLeavingOngoing)
    Events.RegisterHandlerEvent(defines.events.on_train_created, "TrainManager.TrainLeavingOngoing_OnTrainCreated", TrainManager.TrainLeavingOngoing_OnTrainCreated)
end

TrainManager.TrainEnteringInitial = function(trainEntering, surfaceEntrancePortalEndSignal)
    local trainManagerId = #global.trainManager.managedTrains
    global.trainManager.managedTrains[trainManagerId] = {
        id = trainManagerId,
        aboveTrainEntering = trainEntering,
        aboveTrainEnteringId = trainEntering.id,
        surfaceEntrancePortalEndSignal = surfaceEntrancePortalEndSignal,
        tunnel = surfaceEntrancePortalEndSignal.portal.tunnel,
        origTrainSchedule = Utils.DeepCopy(trainEntering.schedule),
        trainTravelDirection = Utils.LoopDirectionValue(surfaceEntrancePortalEndSignal.entity.direction + 4)
    }
    local trainManagerEntry = global.trainManager.managedTrains[trainManagerId]
    trainManagerEntry.aboveSurface = trainManagerEntry.tunnel.aboveSurface
    trainManagerEntry.undergroundSurface = trainManagerEntry.tunnel.undergroundSurface
    if trainManagerEntry.aboveTrainEntering.speed > 0 then
        trainManagerEntry.trainTravellingForwards = true
    else
        trainManagerEntry.trainTravellingForwards = false
    end
    global.trainManager.enteringTrainIdToManagedTrain[trainEntering.id] = trainManagerEntry

    -- Get the exit end signal on the other portal so we know when to bring the train back in.
    for _, portal in pairs(trainManagerEntry.tunnel.portals) do
        if portal.id ~= surfaceEntrancePortalEndSignal.portal.id then
            for _, endSignal in pairs(portal.endSignals) do
                if endSignal.entity.direction ~= surfaceEntrancePortalEndSignal.entity.direction then
                    trainManagerEntry.surfaceExitPortalEndSignal = endSignal
                    break
                end
            end
            break
        end
    end

    -- Copy the train initially to the underground and run it to the end of the underground track. As each carriage dissapears we can clone the carriage while its straight in the portal to be stationary in the underground and then clone this back to the surface. Means we don;t have to worry about part fuel, health, etc being lost by the copy process.
    --TODO: may not need to clone as I can do te exact partial fuel in the burners.
    local sourceTrain = trainManagerEntry.aboveTrainEntering
    local undergroundTrain = TrainManager.CopyTrainToUnderground(trainManagerEntry)
    undergroundTrain.speed = sourceTrain.speed
    trainManagerEntry.undergroundTrain = undergroundTrain
    local tunnelSetupValues = Interfaces.Call("Tunnel.GetSetupValues")
    undergroundTrain.schedule = {
        current = 1,
        records = {
            {
                --TODO: needs to handle orientation.
                rail = trainManagerEntry.tunnel.undergroundSurface.find_entity("straight-rail", {x = 0 - (tunnelSetupValues.undergroundLeadInTiles - 1), y = trainManagerEntry.tunnel.undergroundModifiers.tunnelInstanceValue + 1})
            }
        }
    }
    undergroundTrain.manual_mode = false

    --EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEnteringOngoing", trainManagerId)
    --EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainUndergroundOngoing", trainManagerId)
end

TrainManager.CopyTrainToUnderground = function(trainManagerEntry)
    local placedCarriage, refTrain, tunnel, targetSurface, undergroundModifiers = nil, trainManagerEntry.aboveTrainEntering, trainManagerEntry.tunnel, trainManagerEntry.tunnel.undergroundSurface, trainManagerEntry.tunnel.undergroundModifiers

    --TODO: this needs to calculate the start of the train the right distance from the entrance portal end signal if its on curved track.
    local firstCarriageDistanceFromEndSignal = Utils.GetDistanceSingleAxis(trainManagerEntry.surfaceEntrancePortalEndSignal.entity.position, refTrain.front_stock.position, undergroundModifiers.railAlignmentAxis)
    local firstCarriageDistanceFrom0
    if trainManagerEntry.trainTravelDirection == defines.direction.north or trainManagerEntry.trainTravelDirection == defines.direction.west then
        firstCarriageDistanceFrom0 = 0 + (tunnel.undergroundModifiers.distanceFromCenterToPortalEndSignals + firstCarriageDistanceFromEndSignal)
    else
        firstCarriageDistanceFrom0 = 0 - (tunnel.undergroundModifiers.distanceFromCenterToPortalEndSignals + firstCarriageDistanceFromEndSignal)
    end
    --TODO: this may not handle all orientations correctly
    local firstCarriagePosition = {
        [undergroundModifiers.tunnelInstanceAxis] = undergroundModifiers.tunnelInstanceValue,
        [undergroundModifiers.railAlignmentAxis] = firstCarriageDistanceFrom0
    }

    local carraigeRailAlignmentIteratorManipulator
    if trainManagerEntry.trainTravelDirection == defines.direction.north or trainManagerEntry.trainTravelDirection == defines.direction.west then
        if trainManagerEntry.trainTravellingForwards then
            carraigeRailAlignmentIteratorManipulator = 1
        else
            carraigeRailAlignmentIteratorManipulator = -1
        end
    else
        if trainManagerEntry.trainTravellingForwards then
            carraigeRailAlignmentIteratorManipulator = -1
        else
            carraigeRailAlignmentIteratorManipulator = 1
        end
    end

    local position = firstCarriagePosition
    for _, refCarriage in pairs(refTrain.carriages) do
        -- TODO: placed direction needs to be calculated from the wagons direction in relation to the overall train. Train being copied may be on a loop back or similar when referenced, but we need it all placed straight to make sure it joins up. Just extend the rails under the wagons if neeeded.
        placedCarriage = targetSurface.create_entity {name = refCarriage.name, position = position, force = refCarriage.force, direction = Utils.OrientationToDirection(refCarriage.orientation)}

        local refFuelInventory = refCarriage.get_fuel_inventory()
        if refFuelInventory ~= nil then
            local placedFuelInventory = placedCarriage.get_fuel_inventory()
            for fuelName, fuelCount in pairs(refFuelInventory.get_contents()) do
                placedFuelInventory.insert({name = fuelName, count = fuelCount})
            end
        --TODO: do the burner contents copy as well.
        end

        -- TODO: hard coded for carriages to be placed 7 tiles apart.
        position =
            Utils.ApplyOffsetToPosition(
            position,
            {
                [undergroundModifiers.tunnelInstanceAxis] = 0,
                [undergroundModifiers.railAlignmentAxis] = 7 * carraigeRailAlignmentIteratorManipulator
            }
        )
    end
    return placedCarriage.train
end

TrainManager.TrainEnteringOngoing = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    trainManagerEntry.aboveTrainEntering.manual_mode = true
    local nextStockAttributeName
    if (trainManagerEntry.undergroundTrain.speed > 0 and trainManagerEntry.aboveTrainEntering.speed > 0) or (trainManagerEntry.undergroundTrain.speed < 0 and trainManagerEntry.aboveTrainEntering.speed < 0) then
        trainManagerEntry.aboveTrainEntering.speed = trainManagerEntry.undergroundTrain.speed
        nextStockAttributeName = "front_stock"
    else
        trainManagerEntry.aboveTrainEntering.speed = 0 - trainManagerEntry.undergroundTrain.speed
        nextStockAttributeName = "back_stock"
    end

    if Utils.GetDistance(trainManagerEntry.aboveTrainEntering[nextStockAttributeName].position, trainManagerEntry.surfaceEntrancePortalEndSignal.entity.position) < 10 then
        --TODO: clone the wagon about to be destoryed to the underground on the second track.
        trainManagerEntry.aboveTrainEntering[nextStockAttributeName].destroy()
    end
    if trainManagerEntry.aboveTrainEntering ~= nil and trainManagerEntry.aboveTrainEntering.valid and #trainManagerEntry.aboveTrainEntering[nextStockAttributeName] ~= nil then
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEnteringOngoing", trainManagerEntry.id)
    else
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.aboveTrainEnteringId] = nil
        trainManagerEntry.aboveTrainEntering = nil
    end
end

TrainManager.TrainEnteringOngoing_OnTrainCreated = function(event)
    if event.old_train_id_1 == nil then
        return
    end
    local managedTrain = global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_1] or global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_2]
    if managedTrain == nil then
        return
    end
    managedTrain.aboveTrainEntering = event.train
    managedTrain.aboveTrainEnteringId = event.train.id
    if global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_1] ~= nil then
        global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_1] = nil
    end
    if global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_2] ~= nil then
        global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_2] = nil
    end
    global.trainManager.enteringTrainIdToManagedTrain[event.train.id] = managedTrain
end

TrainManager.TrainUndergroundOngoing = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    if Utils.GetDistance(trainManagerEntry.undergroundTrain.front_stock.position, {-40, 1}) > 10 then
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainUndergroundOngoing", trainManagerEntry.id)
    else
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainLeavingInitial", trainManagerEntry.id)
    end
end

TrainManager.TrainLeavingInitial = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]

    local sourceTrain, nextStockAttributeName = trainManagerEntry.undergroundTrain
    if (sourceTrain.speed > 0) then
        nextStockAttributeName = "front_stock"
    else
        nextStockAttributeName = "back_stock"
    end

    --TODO: clone the stationary wagon from the cloned train, not the copied train.
    trainManagerEntry.undergroundSurface.clone_entities {entities = {sourceTrain[nextStockAttributeName]}, destination_offset = {0, 0}, destination_surface = trainManagerEntry.aboveSurface}
    trainManagerEntry.aboveTrainLeavingCarriagesPlaced = 1

    local trains = sourceTrain[nextStockAttributeName].force.get_trains(trainManagerEntry.aboveSurface)
    local aboveTrainLeaving, speed = trains[#trains]
    trainManagerEntry.aboveTrainLeaving, trainManagerEntry.aboveTrainLeavingId = aboveTrainLeaving, aboveTrainLeaving.id
    global.trainManager.leavingTrainIdToManagedTrain[aboveTrainLeaving.id] = trainManagerEntry
    if aboveTrainLeaving[nextStockAttributeName].orientation == trainManagerEntry.trainTravelDirection * (1 / 8) then
        speed = sourceTrain.speed
    else
        speed = 0 - sourceTrain.speed
    end
    aboveTrainLeaving.speed = speed
    aboveTrainLeaving.schedule = trainManagerEntry.origTrainSchedule
    aboveTrainLeaving.manual_mode = false

    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainLeavingOngoing", trainManagerEntry.id)
end

TrainManager.TrainLeavingOngoing = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    local aboveTrainLeaving, sourceTrain, nextSourceTrainCarriageIndex, currentSourceTrainCarriageIndex, speed = trainManagerEntry.aboveTrainLeaving, trainManagerEntry.undergroundTrain
    if (trainManagerEntry.undergroundTrain.speed > 0 and aboveTrainLeaving.speed > 0) or (trainManagerEntry.undergroundTrain.speed < 0 and aboveTrainLeaving.speed < 0) then
        speed = trainManagerEntry.undergroundTrain.speed
        currentSourceTrainCarriageIndex = trainManagerEntry.aboveTrainLeavingCarriagesPlaced
        nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex + 1
    else
        speed = 0 - trainManagerEntry.undergroundTrain.speed
        currentSourceTrainCarriageIndex = #sourceTrain.carraiges - trainManagerEntry.aboveTrainLeavingCarriagesPlaced
        nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex - 1
    end

    local currentSourceCarriageEntity, nextSourceCarriageEntity = sourceTrain.carriages[currentSourceTrainCarriageIndex], sourceTrain.carriages[nextSourceTrainCarriageIndex]
    if nextSourceCarriageEntity == nil then
        -- All wagons placed so remove the underground train

        -- TODO: This won't handle long trains or ones with wrong facing loco's, etc.
        aboveTrainLeaving.schedule = trainManagerEntry.origTrainSchedule
        aboveTrainLeaving.manual_mode = false

        for _, carriage in pairs(trainManagerEntry.undergroundTrain.carriages) do
            carriage.destroy()
        end
        trainManagerEntry.undergroundTrain = nil
        return
    end
    if Utils.GetDistance(currentSourceCarriageEntity.position, trainManagerEntry.surfaceExitPortalEndSignal.entity.position) > 15 then
        --TODO: this is hard coded in direction and distance
        local nextCarriagePosition = Utils.ApplyOffsetToPosition(currentSourceCarriageEntity.position, {x = 7, y = 0})
        --TODO: clone the stationary wagon from the cloned train, not the copied train.
        nextSourceCarriageEntity.clone {position = nextCarriagePosition, surface = trainManagerEntry.aboveSurface}
        trainManagerEntry.aboveTrainLeavingCarriagesPlaced = trainManagerEntry.aboveTrainLeavingCarriagesPlaced + 1

        -- LuaTrain has been replaced and updated by adding a wagon, so obtain it again.
        aboveTrainLeaving = trainManagerEntry.aboveTrainLeaving
    end
    aboveTrainLeaving.speed = speed

    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainLeavingOngoing", trainManagerEntry.id)
end

TrainManager.TrainLeavingOngoing_OnTrainCreated = function(event)
    if event.old_train_id_1 == nil then
        return
    end
    local managedTrain = global.trainManager.leavingTrainIdToManagedTrain[event.old_train_id_1] or global.trainManager.leavingTrainIdToManagedTrain[event.old_train_id_2]
    if managedTrain == nil then
        return
    end
    managedTrain.aboveTrainLeaving = event.train
    managedTrain.aboveTrainLeavingId = event.train.id
    if global.trainManager.leavingTrainIdToManagedTrain[event.old_train_id_1] ~= nil then
        global.trainManager.leavingTrainIdToManagedTrain[event.old_train_id_1] = nil
    end
    if global.trainManager.leavingTrainIdToManagedTrain[event.old_train_id_2] ~= nil then
        global.trainManager.leavingTrainIdToManagedTrain[event.old_train_id_2] = nil
    end
    global.trainManager.leavingTrainIdToManagedTrain[event.train.id] = managedTrain
end

return TrainManager
