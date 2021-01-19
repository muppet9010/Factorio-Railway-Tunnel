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
        aboveTrainEnteringForwards = boolean if the train is moving forwards or backwards from its viewpoint.
        trainTravelDirection = defines.direction the train is heading in.
        trainTravelOrientation = the orientation of the trainTravelDirection.
        surfaceEntrancePortal = the portal global object of the entrance portal for this tunnel usage instance.
        surfaceEntrancePortalEndSignal = the endSignal global object of the rail signal at the end of the entrance portal track (forced closed signal).
        surfaceExitPortal = the portal global object of the exit portal for this tunnel usage instance.
        surfaceExitPortalEndSignal = the endSignal global object of the rail signal at the end of the exit portal track (forced closed signal).
        tunnel = ref to the global tunnel object.
        origTrainSchedule = copy of the origional train schedule table made when triggered the managed train process.
        undergroundTrain = LuaTrain of the train created in the underground surface.
        undergroundLeavingEntrySignalPosition = The underground position equivilent to the entry signal that the underground train starts leaving when it approaches.
        aboveSurface = LuaSurface of the main world surface.
        undergroundSurface = LuaSurface of the specific underground surface.
        aboveTrainLeavingCarriagesPlaced = count of how many carriages placed so far in the above train while its leaving.
        aboveLeavingSignalPosition = The above ground position that the rear leaving carriage should trigger the next carriage at.
        committed = boolean if train is already fully committed to going through tunnel
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
    Interfaces.RegisterInterface("TrainManager.IsTunnelInUse", TrainManager.IsTunnelInUse)
    Interfaces.RegisterInterface("TrainManager.TunnelRemoved", TrainManager.TunnelRemoved)
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
        origTrainScheduleStopEntity = trainEntering.path_end_stop,
        trainTravelDirection = Utils.LoopDirectionValue(surfaceEntrancePortalEndSignal.entity.direction + 4),
        committed = false
    }
    local trainManagerEntry = global.trainManager.managedTrains[trainManagerId]
    local tunnel = trainManagerEntry.tunnel
    trainManagerEntry.aboveSurface = tunnel.aboveSurface
    trainManagerEntry.undergroundSurface = tunnel.undergroundSurface
    if trainManagerEntry.aboveTrainEntering.speed > 0 then
        trainManagerEntry.aboveTrainEnteringForwards = true
    else
        trainManagerEntry.aboveTrainEnteringForwards = false
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
                y = 0 - (tunnel.undergroundModifiers.undergroundLeadInTiles - 1)
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
    trainManagerEntry.undergroundTrain = undergroundTrain
    TrainManager.SetUndergroundTrainSpeed(trainManagerEntry, math.abs(sourceTrain.speed))

    trainManagerEntry.undergroundLeavingEntrySignalPosition = Utils.ApplyOffsetToPosition(trainManagerEntry.surfaceExitPortal.entrySignals["out"].entity.position, trainManagerEntry.tunnel.undergroundModifiers.undergroundOffsetFromSurface)

    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEnteringOngoing", trainManagerId)
    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainUndergroundOngoing", trainManagerId)
end

TrainManager.TrainEnteringOngoing = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    local aboveTrainEntering = trainManagerEntry.aboveTrainEntering

    if not trainManagerEntry.committed then
        -- check whether the train is still approaching the tunnel portal
        if aboveTrainEntering.state ~= defines.train_state.arrive_signal or aboveTrainEntering.signal ~= trainManagerEntry.surfaceEntrancePortalEndSignal.entity then
            TrainManager.TerminateTunnelTrip(trainManagerEntry)
            return
        end
    else
        -- force a committed train to stay in manual mode
        aboveTrainEntering.manual_mode = true
    end

    TrainManager.SetAboveTrainEnteringSpeed(trainManagerEntry, TrainManager.GetTrainSpeed(trainManagerEntry))

    local nextStockAttributeName = "front_stock"
    -- aboveTrainEnteringForwards has been updated for us by SetAboveTrainEnteringSpeed()
    if not trainManagerEntry.aboveTrainEnteringForwards then
        nextStockAttributeName = "back_stock"
    end

    if Utils.GetDistance(aboveTrainEntering[nextStockAttributeName].position, trainManagerEntry.surfaceEntrancePortalEndSignal.entity.position) < 14 then
        if not trainManagerEntry.committed then
            -- we now start destroying entering train carriages, so train can't be allowed to turn back from the tunnel now
            trainManagerEntry.committed = true
            --Need to create a dummy leaving train at this point to reserve the train limit.
            aboveTrainEntering.manual_mode = true
        end
        trainManagerEntry.aboveTrainEntering[nextStockAttributeName].destroy()
    end
    if trainManagerEntry.aboveTrainEntering ~= nil and trainManagerEntry.aboveTrainEntering.valid and #trainManagerEntry.aboveTrainEntering[nextStockAttributeName] ~= nil then
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEnteringOngoing", trainManagerEntry.id)
    else
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.aboveTrainEnteringId] = nil
        trainManagerEntry.aboveTrainEntering = nil
        trainManagerEntry.aboveTrainEnteringId = nil
    end
end

TrainManager.TrainUndergroundOngoing = function(event)
    local trainManagerEntry, leadCarriage = global.trainManager.managedTrains[event.instanceId]
    if trainManagerEntry == nil then
        -- tunnel trip has been aborted
        return
    end
    if (trainManagerEntry.undergroundTrain.speed > 0) then
        leadCarriage = trainManagerEntry.undergroundTrain["front_stock"]
    else
        leadCarriage = trainManagerEntry.undergroundTrain["back_stock"]
    end
    if Utils.GetDistance(leadCarriage.position, trainManagerEntry.undergroundLeavingEntrySignalPosition) > 30 then
        --The lead carriage isn't close enough to the exit portal's entry signal to be safely in the leaving tunnel area.
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainUndergroundOngoing", trainManagerEntry.id)
    else
        TrainManager.TrainLeavingInitial(trainManagerEntry)
    end
end

TrainManager.TrainLeavingInitial = function(trainManagerEntry)
    local sourceTrain, leadCarriage = trainManagerEntry.undergroundTrain
    if (sourceTrain.speed > 0) then
        leadCarriage = sourceTrain["front_stock"]
    else
        leadCarriage = sourceTrain["back_stock"]
    end

    local placementPosition = Utils.ApplyOffsetToPosition(leadCarriage.position, trainManagerEntry.tunnel.undergroundModifiers.surfaceOffsetFromUnderground)
    local placedCarriage = leadCarriage.clone {position = placementPosition, surface = trainManagerEntry.aboveSurface}
    trainManagerEntry.aboveTrainLeavingCarriagesPlaced = 1

    local aboveTrainLeaving = placedCarriage.train
    trainManagerEntry.aboveTrainLeaving, trainManagerEntry.aboveTrainLeavingId = aboveTrainLeaving, aboveTrainLeaving.id
    global.trainManager.leavingTrainIdToManagedTrain[aboveTrainLeaving.id] = trainManagerEntry
    aboveTrainLeaving.schedule = trainManagerEntry.origTrainSchedule
    aboveTrainLeaving.manual_mode = false
    if placedCarriage.orientation == leadCarriage.orientation then
        -- As theres only 1 placed carriage we can set the speed based on the refCarriage. New train will have a direciton that matches the single placed carriage.
        aboveTrainLeaving.speed = leadCarriage.speed
    else
        aboveTrainLeaving.speed = 0 - leadCarriage.speed
    end
    if trainManagerEntry.origTrainScheduleStopEntity.trains_limit ~= Utils.MaxTrainStopLimit then
        trainManagerEntry.origTrainScheduleStopEntity.trains_limit = trainManagerEntry.origTrainScheduleStopEntity.trains_limit + 1
        aboveTrainLeaving.recalculate_path()
        trainManagerEntry.origTrainScheduleStopEntity.trains_limit = trainManagerEntry.origTrainScheduleStopEntity.trains_limit - 1
    else
        aboveTrainLeaving.recalculate_path()
    end

    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainLeavingOngoing", trainManagerEntry.id)
end

TrainManager.TrainLeavingOngoing = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    local aboveTrainLeaving, sourceTrain = trainManagerEntry.aboveTrainLeaving, trainManagerEntry.undergroundTrain
    local desiredSpeed = TrainManager.GetTrainSpeed(trainManagerEntry)

    if sourceTrain.speed ~= 0 then
        local currentSourceTrainCarriageIndex = trainManagerEntry.aboveTrainLeavingCarriagesPlaced
        local nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex + 1
        if (sourceTrain.speed < 0) then
            currentSourceTrainCarriageIndex = #sourceTrain.carriages - trainManagerEntry.aboveTrainLeavingCarriagesPlaced
            nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex
        end

        local nextSourceCarriageEntity = sourceTrain.carriages[nextSourceTrainCarriageIndex]
        if nextSourceCarriageEntity == nil then
            -- All wagons placed so tidy up
            TrainManager.TrainLeavingCompleted(trainManagerEntry, desiredSpeed)
            return
        end

        local aboveTrainLeavingRearCarriage
        if (aboveTrainLeaving.speed > 0) then
            aboveTrainLeavingRearCarriage = aboveTrainLeaving["back_stock"]
        else
            aboveTrainLeavingRearCarriage = aboveTrainLeaving["front_stock"]
        end
        if Utils.GetDistance(aboveTrainLeavingRearCarriage.position, trainManagerEntry.surfaceExitPortalEndSignal.entity.position) > 20 then
            local aboveTrainOldCarriageCount = #aboveTrainLeaving.carriages
            local nextCarriagePosition = Utils.ApplyOffsetToPosition(nextSourceCarriageEntity.position, trainManagerEntry.tunnel.undergroundModifiers.surfaceOffsetFromUnderground)
            nextSourceCarriageEntity.clone {position = nextCarriagePosition, surface = trainManagerEntry.aboveSurface}
            trainManagerEntry.aboveTrainLeavingCarriagesPlaced = trainManagerEntry.aboveTrainLeavingCarriagesPlaced + 1
            aboveTrainLeaving = trainManagerEntry.aboveTrainLeaving -- LuaTrain has been replaced and updated by adding a wagon, so obtain a local reference to it again.
            if #aboveTrainLeaving.carriages ~= aboveTrainOldCarriageCount + 1 then
                error("Placed carriage not part of train as expected carriage count not right")
            end
        end
    end

    TrainManager.SetTrainAbsoluteSpeed(aboveTrainLeaving, desiredSpeed)
    TrainManager.SetUndergroundTrainSpeed(trainManagerEntry, desiredSpeed)

    aboveTrainLeaving.schedule = trainManagerEntry.origTrainSchedule
    aboveTrainLeaving.manual_mode = false
    if trainManagerEntry.origTrainScheduleStopEntity.trains_limit ~= Utils.MaxTrainStopLimit then
        trainManagerEntry.origTrainScheduleStopEntity.trains_limit = trainManagerEntry.origTrainScheduleStopEntity.trains_limit + 1
        aboveTrainLeaving.recalculate_path() -- TODO: Seem to be overally calling this since it was added.
        trainManagerEntry.origTrainScheduleStopEntity.trains_limit = trainManagerEntry.origTrainScheduleStopEntity.trains_limit - 1
    else
        aboveTrainLeaving.recalculate_path() -- TODO: Seem to be overally calling this since it was added.
    end

    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainLeavingOngoing", trainManagerEntry.id)
end

TrainManager.TrainLeavingCompleted = function(trainManagerEntry, speed)
    trainManagerEntry.aboveTrainLeaving.schedule = trainManagerEntry.origTrainSchedule
    trainManagerEntry.aboveTrainLeaving.manual_mode = false
    TrainManager.SetTrainAbsoluteSpeed(trainManagerEntry.aboveTrainLeaving, speed)
    TrainManager.TerminateTunnelTrip(trainManagerEntry)
end

TrainManager.TerminateTunnelTrip = function(trainManagerEntry)
    for _, carriage in pairs(trainManagerEntry.undergroundTrain.carriages) do
        carriage.destroy()
    end
    trainManagerEntry.undergroundTrain = nil

    if trainManagerEntry.aboveTrainLeaving then
        global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.aboveTrainLeaving.id] = nil
    end
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

TrainManager.SpeedGovernedByLeavingTrain = function(trainManagerEntry)
    local train = trainManagerEntry.aboveTrainLeaving
    if train and train.valid and train.state ~= defines.train_state.on_the_path then
        return true
    else
        return false
    end
end

-- determine the current speed of the train passing through the tunnel
TrainManager.GetTrainSpeed = function(trainManagerEntry)
    if TrainManager.SpeedGovernedByLeavingTrain(trainManagerEntry) then
        return math.abs(trainManagerEntry.aboveTrainLeaving.speed)
    else
        return math.abs(trainManagerEntry.undergroundTrain.speed)
    end
end

-- set speed of train while preserving direction
TrainManager.SetTrainAbsoluteSpeed = function(train, speed)
    if train.speed > 0 then
        train.speed = speed
    elseif train.speed < 0 then
        train.speed = -1 * speed
    elseif speed ~= 0 then
        -- this shouldn't be possible to reach, so throw an error for now
        error "unable to determine train direction"
    end
end

TrainManager.SetAboveTrainEnteringSpeed = function(trainManagerEntry, speed)
    local train = trainManagerEntry.aboveTrainEntering

    -- for the entering train the direction needs to be preserved in
    -- global data, because it would otherwise get lost when the train
    -- stops while entering the tunnel
    if train.speed > 0 then
        trainManagerEntry.aboveTrainEnteringForwards = true
    elseif train.speed < 0 then
        trainManagerEntry.aboveTrainEnteringForwards = false
    end

    if trainManagerEntry.aboveTrainEnteringForwards then
        train.speed = speed
    else
        train.speed = -1 * speed
    end
end

-- set the speed of the underground train
-- train needs to be switched to manual if it is supposed to stop (speed=0)
TrainManager.SetUndergroundTrainSpeed = function(trainManagerEntry, speed)
    local train = trainManagerEntry.undergroundTrain

    if speed ~= 0 or not TrainManager.SpeedGovernedByLeavingTrain(trainManagerEntry) then
        if not train.manual_mode then
            TrainManager.SetTrainAbsoluteSpeed(train, speed)
        else
            train.speed = speed
            train.manual_mode = false
            if train.speed == 0 then
                train.speed = -1 * speed
            end
        end
    else
        train.manual_mode = true
        train.speed = 0
    end
end

TrainManager.CopyTrainToUnderground = function(trainManagerEntry)
    local placedCarriage, refTrain, tunnel, targetSurface = nil, trainManagerEntry.aboveTrainEntering, trainManagerEntry.tunnel, trainManagerEntry.tunnel.undergroundSurface

    local endSignalRailUnitNumber = trainManagerEntry.surfaceEntrancePortalEndSignal.entity.get_connected_rails()[1].unit_number
    local firstCarriageDistanceFromEndSignal = 0
    for _, railEntity in pairs(refTrain.path.rails) do
        -- TODO: this doesn't account for where on the current rail entity the carriage is, but hopefully is accurate enough.
        local thisRailLength = 2
        if railEntity.type == "curved-rail" then
            thisRailLength = 7 -- Estimate
        end
        firstCarriageDistanceFromEndSignal = firstCarriageDistanceFromEndSignal + thisRailLength
        if railEntity.unit_number == endSignalRailUnitNumber then
            break
        end
    end

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
    local trainCarriagesOffset = Utils.RotatePositionAround0(trainManagerEntry.trainTravelOrientation, {x = 0, y = 7})
    local trainCarriagesForwardDirection = trainManagerEntry.trainTravelDirection
    if not trainManagerEntry.aboveTrainEnteringForwards then
        trainCarriagesForwardDirection = Utils.LoopDirectionValue(trainCarriagesForwardDirection + 4)
    end

    local minCarriageIndex, maxCarriageIndex, carriageIterator = 1, #refTrain.carriages, 1
    if (refTrain.speed < 0) then
        minCarriageIndex, maxCarriageIndex, carriageIterator = #refTrain.carriages, 1, -1
    end
    for currentSourceTrainCarriageIndex = minCarriageIndex, maxCarriageIndex, carriageIterator do
        local refCarriage = refTrain.carriages[currentSourceTrainCarriageIndex]
        local carriageDirection = trainCarriagesForwardDirection
        if refCarriage.speed ~= refTrain.speed then
            carriageDirection = Utils.LoopDirectionValue(carriageDirection + 4)
        end
        --Utils.OrientationToDirection(refCarriage.orientation)
        placedCarriage = TrainManager.CopyCarriage(targetSurface, refCarriage, nextCarriagePosition, carriageDirection)

        nextCarriagePosition = Utils.ApplyOffsetToPosition(nextCarriagePosition, trainCarriagesOffset)
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

TrainManager.IsTunnelInUse = function(tunnelToCheck)
    for _, managedTrain in pairs(global.trainManager.managedTrains) do
        if managedTrain.tunnel.id == tunnelToCheck.id then
            return true
        end
    end

    for _, portal in pairs(tunnelToCheck.portals) do
        for _, railEntity in pairs(portal.portalRailEntities) do
            if not railEntity.can_be_destroyed() then
                --If the rail can't be destroyed then theres a train carriage on it.
                return true
            end
        end
    end

    return false
end

TrainManager.TunnelRemoved = function(tunnelRemoved)
    for _, managedTrain in pairs(global.trainManager.managedTrains) do
        if managedTrain.tunnel.id == tunnelRemoved.id then
            if managedTrain.aboveTrainEnteringId ~= nil then
                global.trainManager.enteringTrainIdToManagedTrain[managedTrain.aboveTrainEnteringId] = nil
                managedTrain.aboveTrainEntering.schedule = managedTrain.origTrainSchedule
                managedTrain.aboveTrainEntering.manual_mode = true
                managedTrain.aboveTrainEntering.speed = 0
            end
            if managedTrain.aboveTrainLeavingId ~= nil then
                global.trainManager.leavingTrainIdToManagedTrain[managedTrain.aboveTrainLeavingId] = nil
                managedTrain.aboveTrainLeaving.schedule = managedTrain.origTrainSchedule
                managedTrain.aboveTrainLeaving.manual_mode = true
                managedTrain.aboveTrainLeaving.speed = 0
            end
            local undergroundCarriages = Utils.DeepCopy(managedTrain.undergroundTrain.carriages)
            for _, carriage in pairs(undergroundCarriages) do
                carriage.destroy()
            end
            EventScheduler.RemoveScheduledEvents("TrainManager.TrainEnteringOngoing", managedTrain.id)
            EventScheduler.RemoveScheduledEvents("TrainManager.TrainUndergroundOngoing", managedTrain.id)
            EventScheduler.RemoveScheduledEvents("TrainManager.TrainLeavingOngoing", managedTrain.id)
            global.trainManager.managedTrains[managedTrain.id] = nil
        end
    end
end

return TrainManager
