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
        trainTravelOrientation = the orientation of the trainTravelDirection.
        trainTravellingForwards = boolean if the train is moving forwards or backwards from its viewpoint.
        surfaceEntrancePortal = the portal global object of the entrance portal for this tunnel usage instance.
        surfaceEntrancePortalEndSignal = the endSignal global object of the rail signal at the end of the entrance portal track (forced closed signal).
        surfaceExitPortal = the portal global object of the exit portal for this tunnel usage instance.
        surfaceExitPortalEndSignal = the endSignal global object of the rail signal at the end of the exit portal track (forced closed signal).
        tunnel = ref to the global tunnel object.
        origTrainSchedule = copy of the origional train schedule table made when triggered the managed train process.
        undergroundTrain = LuaTrain of the train created in the underground surface.
        aboveSurface = LuaSurface of the main world surface.
        undergroundSurface = LuaSurface of the specific underground surface.
        aboveTrainLeavingCarriagesPlaced = count of how many carriages placed so far in the above train while its leaving.
        undergroundOffsetFromSurface = position offset of the underground entities from the surface entities.
    ]]
    global.trainManager.enteringTrainIdToManagedTrain = global.trainManager.enteringTrainIdToManagedTrain or {}
    global.trainManager.leavingTrainIdToManagedTrain = global.trainManager.leavingTrainIdToManagedTrain or {}
end

TrainManager.OnLoad = function()
    Interfaces.RegisterInterface("TrainManager.TrainEnteringInitial", TrainManager.TrainEnteringInitial)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainEnteringOngoing", TrainManager.TrainEnteringOngoing)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainUndergroundOngoing", TrainManager.TrainUndergroundOngoing)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainLeavingOngoing", TrainManager.TrainLeavingOngoing)
    Events.RegisterHandlerEvent(defines.events.on_train_created, "TrainManager.TrainEnteringOngoing_OnTrainCreated", TrainManager.TrainEnteringOngoing_OnTrainCreated)
    Events.RegisterHandlerEvent(defines.events.on_train_created, "TrainManager.TrainLeavingOngoing_OnTrainCreated", TrainManager.TrainLeavingOngoing_OnTrainCreated)
end

TrainManager.TrainEnteringInitial = function(trainEntering, surfaceEntrancePortalEndSignal)
    local trainManagerId = #global.trainManager.managedTrains + 1
    global.trainManager.managedTrains[trainManagerId] = {
        id = trainManagerId,
        aboveTrainEntering = trainEntering,
        aboveTrainEnteringId = trainEntering.id,
        surfaceEntrancePortalEndSignal = surfaceEntrancePortalEndSignal,
        surfaceEntrancePortal = surfaceEntrancePortalEndSignal.portal,
        tunnel = surfaceEntrancePortalEndSignal.portal.tunnel,
        origTrainSchedule = Utils.DeepCopy(trainEntering.schedule),
        trainTravelDirection = Utils.LoopDirectionValue(surfaceEntrancePortalEndSignal.entity.direction + 4)
    }
    local trainManagerEntry = global.trainManager.managedTrains[trainManagerId]
    local tunnel = trainManagerEntry.tunnel
    trainManagerEntry.aboveSurface = tunnel.aboveSurface
    trainManagerEntry.undergroundSurface = tunnel.undergroundSurface
    if trainManagerEntry.aboveTrainEntering.speed > 0 then
        trainManagerEntry.trainTravellingForwards = true
    else
        trainManagerEntry.trainTravellingForwards = false
    end
    trainManagerEntry.trainTravelOrientation = trainManagerEntry.trainTravelDirection / 8
    global.trainManager.enteringTrainIdToManagedTrain[trainEntering.id] = trainManagerEntry

    -- Get the exit end signal on the other portal so we know when to bring the train back in.
    for _, portal in pairs(tunnel.portals) do
        if portal.id ~= surfaceEntrancePortalEndSignal.portal.id then
            for _, endSignal in pairs(portal.endSignals) do
                if endSignal.entity.direction ~= surfaceEntrancePortalEndSignal.entity.direction then
                    trainManagerEntry.surfaceExitPortalEndSignal = endSignal
                    trainManagerEntry.surfaceExitPortal = endSignal.portal
                    break
                end
            end
            break
        end
    end

    -- Copy the above train underground and set it running.
    local sourceTrain = trainManagerEntry.aboveTrainEntering
    local undergroundTrain = TrainManager.CopyTrainToUnderground(trainManagerEntry)
    undergroundTrain.speed = sourceTrain.speed
    trainManagerEntry.undergroundTrain = undergroundTrain
    local tunnelSetupValues = Interfaces.Call("Tunnel.GetSetupValues")
    local undergroundTrainEndScheduleTargetPos =
        Utils.ApplyOffsetToPosition(
        Utils.RotatePositionAround0(
            tunnel.alignmentOrientation,
            {
                x = tunnel.undergroundModifiers.tunnelInstanceValue + 1,
                y = 0
            }
        ),
        Utils.RotatePositionAround0(
            trainManagerEntry.trainTravelOrientation,
            {
                x = 0,
                y = 0 - (tunnelSetupValues.undergroundLeadInTiles - 1)
            }
        )
    )
    undergroundTrain.schedule = {
        current = 1,
        records = {
            {
                rail = tunnel.undergroundSurface.find_entity("straight-rail", undergroundTrainEndScheduleTargetPos)
            }
        }
    }
    undergroundTrain.manual_mode = false

    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEnteringOngoing", trainManagerId)
    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainUndergroundOngoing", trainManagerId)
end

TrainManager.TrainEnteringOngoing = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    trainManagerEntry.aboveTrainEntering.manual_mode = true
    local nextStockAttributeName = "front_stock"
    if (trainManagerEntry.aboveTrainEntering.speed < 0) then
        nextStockAttributeName = "back_stock"
    end
    if (trainManagerEntry.undergroundTrain.speed > 0 and trainManagerEntry.aboveTrainEntering.speed > 0) or (trainManagerEntry.undergroundTrain.speed < 0 and trainManagerEntry.aboveTrainEntering.speed < 0) then
        trainManagerEntry.aboveTrainEntering.speed = trainManagerEntry.undergroundTrain.speed
    else
        trainManagerEntry.aboveTrainEntering.speed = 0 - trainManagerEntry.undergroundTrain.speed
    end

    if Utils.GetDistance(trainManagerEntry.aboveTrainEntering[nextStockAttributeName].position, trainManagerEntry.surfaceEntrancePortalEndSignal.entity.position) < 10 then
        trainManagerEntry.aboveTrainEntering[nextStockAttributeName].destroy()
    end
    if trainManagerEntry.aboveTrainEntering ~= nil and trainManagerEntry.aboveTrainEntering.valid and #trainManagerEntry.aboveTrainEntering[nextStockAttributeName] ~= nil then
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEnteringOngoing", trainManagerEntry.id)
    else
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.aboveTrainEnteringId] = nil
        trainManagerEntry.aboveTrainEntering = nil
    end
end

TrainManager.TrainUndergroundOngoing = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    -- TODO: set dynamic distance check - 1 of 2
    -- TODO: this is very wrong on a track 200 tiles from 0,0. Affects both horizontal and vertical.
    local startingLeavingPosition = Utils.ApplyOffsetToPosition(trainManagerEntry.surfaceExitPortal.entrySignals["out"].entity.position, trainManagerEntry.undergroundOffsetFromSurface)
    local nextStockAttributeName = "front_stock"
    if (trainManagerEntry.undergroundTrain.speed < 0) then
        nextStockAttributeName = "back_stock"
    end
    if Utils.GetDistance(trainManagerEntry.undergroundTrain[nextStockAttributeName].position, startingLeavingPosition) > 35 then
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainUndergroundOngoing", trainManagerEntry.id)
    else
        TrainManager.TrainLeavingInitial(trainManagerEntry)
    end
end

TrainManager.TrainLeavingInitial = function(trainManagerEntry)
    local sourceTrain, nextStockAttributeName = trainManagerEntry.undergroundTrain
    if (sourceTrain.speed > 0) then
        nextStockAttributeName = "front_stock"
    else
        nextStockAttributeName = "back_stock"
    end

    local refCarriage = sourceTrain[nextStockAttributeName]
    local placedCarriage = refCarriage.clone {position = Utils.ApplyOffsetToPosition(refCarriage.position, trainManagerEntry.undergroundOffsetFromSurface), surface = trainManagerEntry.aboveSurface}
    trainManagerEntry.aboveTrainLeavingCarriagesPlaced = 1

    local aboveTrainLeaving, speed = placedCarriage.train
    trainManagerEntry.aboveTrainLeaving, trainManagerEntry.aboveTrainLeavingId = aboveTrainLeaving, aboveTrainLeaving.id
    global.trainManager.leavingTrainIdToManagedTrain[aboveTrainLeaving.id] = trainManagerEntry
    if aboveTrainLeaving[nextStockAttributeName].orientation == trainManagerEntry.trainTravelDirection * (1 / 8) then
        speed = sourceTrain.speed
    else
        speed = 0 - sourceTrain.speed
    end
    aboveTrainLeaving.manual_mode = false
    aboveTrainLeaving.speed = speed
    aboveTrainLeaving.schedule = trainManagerEntry.origTrainSchedule
    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainLeavingOngoing", trainManagerEntry.id)
end

TrainManager.TrainLeavingOngoing = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    local aboveTrainLeaving, sourceTrain = trainManagerEntry.aboveTrainLeaving, trainManagerEntry.undergroundTrain

    local currentSourceTrainCarriageIndex = trainManagerEntry.aboveTrainLeavingCarriagesPlaced
    local nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex + 1
    if (sourceTrain.speed < 0) then
        currentSourceTrainCarriageIndex = #sourceTrain.carriages - trainManagerEntry.aboveTrainLeavingCarriagesPlaced
        nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex
    end

    local currentSourceCarriageEntity, nextSourceCarriageEntity = sourceTrain.carriages[currentSourceTrainCarriageIndex], sourceTrain.carriages[nextSourceTrainCarriageIndex]
    if nextSourceCarriageEntity == nil then
        -- All wagons placed so tidy up
        TrainManager.TrainLeavingCompleted(trainManagerEntry)
        return
    end
    -- TODO: set dynamic distance check - 2 of 2
    if Utils.GetDistance(currentSourceCarriageEntity.position, trainManagerEntry.surfaceExitPortalEndSignal.entity.position) > 15 then
        local nextCarriagePosition = Utils.ApplyOffsetToPosition(nextSourceCarriageEntity.position, trainManagerEntry.undergroundOffsetFromSurface)
        nextSourceCarriageEntity.clone {position = nextCarriagePosition, surface = trainManagerEntry.aboveSurface}
        trainManagerEntry.aboveTrainLeavingCarriagesPlaced = trainManagerEntry.aboveTrainLeavingCarriagesPlaced + 1
        aboveTrainLeaving = trainManagerEntry.aboveTrainLeaving -- LuaTrain has been replaced and updated by adding a wagon, so obtain a local reference to it again.
    end

    if (sourceTrain.speed > 0 and aboveTrainLeaving.speed > 0) or (sourceTrain.speed < 0 and aboveTrainLeaving.speed < 0) then
        aboveTrainLeaving.speed = sourceTrain.speed
    else
        aboveTrainLeaving.speed = 0 - sourceTrain.speed
    end
    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainLeavingOngoing", trainManagerEntry.id)
end

TrainManager.TrainLeavingCompleted = function(trainManagerEntry)
    trainManagerEntry.aboveTrainLeaving.schedule = trainManagerEntry.origTrainSchedule
    trainManagerEntry.aboveTrainLeaving.manual_mode = false

    for _, carriage in pairs(trainManagerEntry.undergroundTrain.carriages) do
        carriage.destroy()
    end
    trainManagerEntry.undergroundTrain = nil

    global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.aboveTrainLeaving.id] = nil
    global.trainManager.managedTrains[trainManagerEntry.id] = nil
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

TrainManager.CopyTrainToUnderground = function(trainManagerEntry)
    local placedCarriage, refTrain, tunnel, targetSurface, undergroundModifiers = nil, trainManagerEntry.aboveTrainEntering, trainManagerEntry.tunnel, trainManagerEntry.tunnel.undergroundSurface, trainManagerEntry.tunnel.undergroundModifiers

    -- TODO: this needs to calculate the start of the train the right distance from the entrance portal end signal if its on curved track. At higher speeds with long trains going backwards the front of the train could be a long way from the portal. May be easiest to get the leading wagon and then copy from there, possibly in reverse of the carriage list.
    local firstCarriageDistanceFromEndSignal = Utils.GetDistanceSingleAxis(trainManagerEntry.surfaceEntrancePortalEndSignal.entity.position, refTrain.front_stock.position, undergroundModifiers.railAlignmentAxis)
    local tunnelInitialPosition =
        Utils.RotatePositionAround0(
        tunnel.alignmentOrientation,
        {
            x = 1 + tunnel.undergroundModifiers.tunnelInstanceValue,
            y = 0
        }
    )
    local nextCarriagePosition =
        Utils.ApplyOffsetToPosition(
        tunnelInitialPosition,
        Utils.RotatePositionAround0(
            trainManagerEntry.trainTravelOrientation,
            {
                x = 0,
                y = tunnel.undergroundModifiers.distanceFromCenterToPortalEndSignals + firstCarriageDistanceFromEndSignal
            }
        )
    )
    trainManagerEntry.undergroundOffsetFromSurface = Utils.GetPositionOffsetFromPosition(nextCarriagePosition, refTrain.front_stock.position)
    local carriageIteractionOrientation = trainManagerEntry.trainTravelOrientation
    if not trainManagerEntry.trainTravellingForwards then
        carriageIteractionOrientation = Utils.LoopDirectionValue(trainManagerEntry.trainTravelDirection + 4) / 8
    end

    for _, refCarriage in pairs(refTrain.carriages) do
        -- TODO: placed direction needs to be calculated from the wagons direction in relation to the overall train. Train being copied may be on a loop back or similar when referenced, but we need it all placed straight to make sure it joins up.
        placedCarriage = TrainManager.CopyCarriage(targetSurface, refCarriage, nextCarriagePosition, Utils.OrientationToDirection(refCarriage.orientation))

        nextCarriagePosition = Utils.ApplyOffsetToPosition(nextCarriagePosition, Utils.RotatePositionAround0(carriageIteractionOrientation, {x = 0, y = 7}))
    end
    return placedCarriage.train
end

TrainManager.CopyCarriage = function(targetSurface, refCarriage, newPosition, newDirection)
    local placedCarriage = targetSurface.create_entity {name = refCarriage.name, position = newPosition, force = refCarriage.force, direction = newDirection}

    local refBurner = refCarriage.burner
    if refBurner ~= nil then
        local placedBurner = placedCarriage.burner
        for fuelName, fuelCount in pairs(refBurner.burnt_result_inventory.get_contents()) do
            placedBurner.burnt_result_inventory.insert({name = fuelName, count = fuelCount})
        end
        placedBurner.heat = refBurner.heat
        placedBurner.currently_burning = refBurner.currently_burning
        placedBurner.remaining_burning_fuel = refBurner.remaining_burning_fuel
    end

    if refCarriage.backer_name ~= nil then
        placedCarriage.backer_name = refCarriage.backer_name
    end
    placedCarriage.health = refCarriage.health
    if refCarriage.color ~= nil then
        placedCarriage.color = refCarriage.color
    end

    -- Finds cargo wagon and locomotives main inventories.
    local refCargoWagonInventory = refCarriage.get_inventory(defines.inventory.cargo_wagon)
    if refCargoWagonInventory ~= nil then
        local placedCargoWagonInventory, refCargoWagonInventoryIsFiltered = placedCarriage.get_inventory(defines.inventory.cargo_wagon), refCargoWagonInventory.is_filtered()
        for i = 1, #refCargoWagonInventory do
            if refCargoWagonInventory[i].valid_for_read then
                placedCargoWagonInventory[i].set_stack(refCargoWagonInventory[i])
            end
            if refCargoWagonInventoryIsFiltered then
                local filter = refCargoWagonInventory.get_filter(i)
                if filter ~= nil then
                    placedCargoWagonInventory.set_filter(i, filter)
                end
            end
        end
        if refCargoWagonInventory.supports_bar() then
            placedCargoWagonInventory.set_bar(refCargoWagonInventory.get_bar())
        end
    end

    return placedCarriage
end

return TrainManager
