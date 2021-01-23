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
        dummyTrain = LuaTrain of the dummy train used to keep the train stop reservation alive
        trainTravelDirection = defines.direction the train is heading in.
        trainTravelOrientation = the orientation of the trainTravelDirection.
        surfaceEntrancePortal = the portal global object of the entrance portal for this tunnel usage instance.
        surfaceEntrancePortalEndSignal = the endSignal global object of the rail signal at the end of the entrance portal track (forced closed signal).
        surfaceExitPortal = the portal global object of the exit portal for this tunnel usage instance.
        surfaceExitPortalEndSignal = the endSignal global object of the rail signal at the end of the exit portal track (forced closed signal).
        tunnel = ref to the global tunnel object.
        undergroundTrain = LuaTrain of the train created in the underground surface.
        undergroundLeavingEntrySignalPosition = The underground position equivilent to the entry signal that the underground train starts leaving when it approaches.
        aboveSurface = LuaSurface of the main world surface.
        undergroundSurface = LuaSurface of the specific underground surface.
        aboveTrainLeavingCarriagesPlaced = count of how many carriages placed so far in the above train while its leaving.
        aboveLeavingSignalPosition = The above ground position that the rear leaving carriage should trigger the next carriage at.
        committed = boolean if train is already fully committed to going through tunnel
        aboveTrainLeavingTunnelRailSegment = LuaTrain of the train leaving the tunnel's exit portal rail segment on the world surface.
        aboveTrainLeavingTunnelRailSegmentId= The LuaTrain ID of the above Train Leaving Tunnel Rail Segment.
    ]]
    global.trainManager.enteringTrainIdToManagedTrain = global.trainManager.enteringTrainIdToManagedTrain or {}
    global.trainManager.leavingTrainIdToManagedTrain = global.trainManager.leavingTrainIdToManagedTrain or {}
    global.trainManager.leavingTunnelRailSegmentTrainIdToManagedTrain = global.trainManager.leavingTunnelRailSegmentTrainIdToManagedTrain or {}
end

TrainManager.OnLoad = function()
    Interfaces.RegisterInterface("TrainManager.TrainEnteringInitial", TrainManager.TrainEnteringInitial)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainEnteringOngoing", TrainManager.TrainEnteringOngoing)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainUndergroundOngoing", TrainManager.TrainUndergroundOngoing)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainLeavingOngoing", TrainManager.TrainLeavingOngoing)
    Events.RegisterHandlerEvent(defines.events.on_train_created, "TrainManager.TrainTracking_OnTrainCreated", TrainManager.TrainTracking_OnTrainCreated)
    Interfaces.RegisterInterface("TrainManager.IsTunnelInUse", TrainManager.IsTunnelInUse)
    Interfaces.RegisterInterface("TrainManager.TunnelRemoved", TrainManager.TunnelRemoved)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainLeavingTunnelRailSegmentOngoing", TrainManager.TrainLeavingTunnelRailSegmentOngoing)
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
    Interfaces.Call("Tunnel.TrainReservedTunnel", trainManagerEntry)

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
            TrainManager.CreateDummyTrain(trainManagerEntry, aboveTrainEntering)
            aboveTrainEntering.manual_mode = true
            -- schedule has been transferred to dummy train
            aboveTrainEntering.schedule = nil

            -- Check if this train is alrady using the tunnel to leave. Happens if the train doesn't fully leave the exit portal signal block before coming back in.
            if global.trainManager.leavingTunnelRailSegmentTrainIdToManagedTrain[aboveTrainEntering.id] ~= nil then
                -- Terminate the old tunnel usage that was delayed until this point.
                TrainManager.TerminateTunnelTrip(global.trainManager.leavingTunnelRailSegmentTrainIdToManagedTrain[aboveTrainEntering.id])
            end
        end
        trainManagerEntry.aboveTrainEntering[nextStockAttributeName].destroy()
    end
    if trainManagerEntry.aboveTrainEntering ~= nil and trainManagerEntry.aboveTrainEntering.valid and #trainManagerEntry.aboveTrainEntering[nextStockAttributeName] ~= nil then
        -- Train is still entering, continue loop.
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEnteringOngoing", trainManagerEntry.id)
    else
        -- Train has completed entering.
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.aboveTrainEnteringId] = nil
        trainManagerEntry.aboveTrainEntering = nil
        trainManagerEntry.aboveTrainEnteringId = nil
        Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", trainManagerEntry)
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
    -- cleanup dummy train to make room for the reemerging train, preserving schedule and target stop for later
    local schedule, isManual, targetStop = trainManagerEntry.dummyTrain.schedule, trainManagerEntry.dummyTrain.manual_mode, trainManagerEntry.dummyTrain.path_end_stop
    local dummyTrainState = trainManagerEntry.dummyTrain.state
    TrainManager.DestroyDummyTrain(trainManagerEntry)

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

    -- restore train schedule
    aboveTrainLeaving.schedule = schedule
    if not isManual then
        TrainManager.SetTrainToAuto(aboveTrainLeaving, targetStop)
    end
    if aboveTrainLeaving.state ~= dummyTrainState then
        error "reemerging train should have same state as dummy train"
    end

    if placedCarriage.orientation == leadCarriage.orientation then
        -- As theres only 1 placed carriage we can set the speed based on the refCarriage. New train will have a direciton that matches the single placed carriage.
        aboveTrainLeaving.speed = leadCarriage.speed
    else
        aboveTrainLeaving.speed = 0 - leadCarriage.speed
    end

    Interfaces.Call("Tunnel.TrainStartedExitingTunnel", trainManagerEntry)
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
            -- reattaching next carriage can clobber schedule and will set train to manual, so preserve state
            local schedule, isManual, targetStop = aboveTrainLeaving.schedule, aboveTrainLeaving.manual_mode, aboveTrainLeaving.path_end_stop

            local aboveTrainOldCarriageCount = #aboveTrainLeaving.carriages
            local nextCarriagePosition = Utils.ApplyOffsetToPosition(nextSourceCarriageEntity.position, trainManagerEntry.tunnel.undergroundModifiers.surfaceOffsetFromUnderground)
            nextSourceCarriageEntity.clone {position = nextCarriagePosition, surface = trainManagerEntry.aboveSurface}
            trainManagerEntry.aboveTrainLeavingCarriagesPlaced = trainManagerEntry.aboveTrainLeavingCarriagesPlaced + 1
            aboveTrainLeaving = trainManagerEntry.aboveTrainLeaving -- LuaTrain has been replaced and updated by adding a wagon, so obtain a local reference to it again.
            if #aboveTrainLeaving.carriages ~= aboveTrainOldCarriageCount + 1 then
                error("Placed carriage not part of train as expected carriage count not right")
            end

            -- restore schedule and state
            aboveTrainLeaving.schedule = schedule
            if not isManual then
                TrainManager.SetTrainToAuto(aboveTrainLeaving, targetStop)
            end
        end
    end

    TrainManager.SetTrainAbsoluteSpeed(aboveTrainLeaving, desiredSpeed)
    TrainManager.SetUndergroundTrainSpeed(trainManagerEntry, desiredSpeed)

    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainLeavingOngoing", trainManagerEntry.id)
end

TrainManager.TrainLeavingCompleted = function(trainManagerEntry, speed)
    TrainManager.SetTrainAbsoluteSpeed(trainManagerEntry.aboveTrainLeaving, speed)
    TrainManager.RemoveUndergroundTrain(trainManagerEntry)
    TrainManager.TrainLeavingTunnelRailSegmentInitial(trainManagerEntry)

    global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.aboveTrainLeavingId] = nil
    trainManagerEntry.aboveTrainLeavingId = nil
    trainManagerEntry.aboveTrainLeaving = nil
end

TrainManager.TrainLeavingTunnelRailSegmentInitial = function(trainManagerEntry)
    trainManagerEntry.aboveTrainLeavingTunnelRailSegment, trainManagerEntry.aboveTrainLeavingTunnelRailSegmentId = trainManagerEntry.aboveTrainLeaving, trainManagerEntry.aboveTrainLeavingId
    global.trainManager.leavingTunnelRailSegmentTrainIdToManagedTrain[trainManagerEntry.aboveTrainLeavingTunnelRailSegmentId] = trainManagerEntry
    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainLeavingTunnelRailSegmentOngoing", trainManagerEntry.id)
end

TrainManager.TrainLeavingTunnelRailSegmentOngoing = function(event)
    -- Track the tunnel portal's entrance rail signal so we can mark the tunnel as open for the next train when the current train has left. -- We are assuming that no train gets in to the portal rail segment before our main train gets out.
    -- This is far more UPS effecient than checking the trains last carriage and seeing if its end rail signal is our portal entrance one.
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    local exitPortalEntranceSignalEntity = trainManagerEntry.surfaceExitPortal.entrySignals["in"].entity
    if exitPortalEntranceSignalEntity.signal_state == defines.signal_state.closed then
        -- A train is still in this block so check next tick.
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainLeavingTunnelRailSegmentOngoing", trainManagerEntry.id)
    else
        -- No train in the block so our one must have left.
        TrainManager.TerminateTunnelTrip(trainManagerEntry)
    end
end

TrainManager.RemoveUndergroundTrain = function(trainManagerEntry)
    if trainManagerEntry.undergroundTrain ~= nil then
        for _, carriage in pairs(trainManagerEntry.undergroundTrain.carriages) do
            carriage.destroy()
        end
        trainManagerEntry.undergroundTrain = nil
    end
end

TrainManager.TerminateTunnelTrip = function(trainManagerEntry)
    TrainManager.RemoveUndergroundTrain(trainManagerEntry)
    if trainManagerEntry.aboveTrainEntering then
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.aboveTrainEnteringId] = nil
    end
    if trainManagerEntry.aboveTrainLeaving then
        global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.aboveTrainLeavingId] = nil
    end
    if trainManagerEntry.aboveTrainLeavingTunnelRailSegment then
        global.trainManager.leavingTunnelRailSegmentTrainIdToManagedTrain[trainManagerEntry.aboveTrainLeavingTunnelRailSegmentId] = nil
        EventScheduler.RemoveScheduledEvents("TrainManager.TrainLeavingTunnelRailSegmentOngoing", trainManagerEntry.id)
    end
    Interfaces.Call("Tunnel.TrainReleasedTunnel", trainManagerEntry)
    global.trainManager.managedTrains[trainManagerEntry.id] = nil
end

TrainManager.TrainTracking_OnTrainCreated = function(event)
    if event.old_train_id_1 == nil then
        return
    end
    for _, trainTracking in pairs(
        {
            {
                list = global.trainManager.enteringTrainIdToManagedTrain,
                trainAttributeName = "aboveTrainEntering",
                trainIdAttributeName = "aboveTrainEnteringId"
            },
            {
                list = global.trainManager.leavingTrainIdToManagedTrain,
                trainAttributeName = "aboveTrainLeaving",
                trainIdAttributeName = "aboveTrainLeavingId"
            },
            {
                list = global.trainManager.leavingTunnelRailSegmentTrainIdToManagedTrain,
                trainAttributeName = "aboveTrainLeavingTunnelRailSegment",
                trainIdAttributeName = "aboveTrainLeavingTunnelRailSegmentId"
            }
        }
    ) do
        TrainManager.TrainTrackingCheckList(event, trainTracking.list, trainTracking.trainAttributeName, trainTracking.trainIdAttributeName)
    end
end

TrainManager.TrainTrackingCheckList = function(event, list, trainAttributeName, trainIdAttributeName)
    local managedTrain = list[event.old_train_id_1] or list[event.old_train_id_2]
    if managedTrain == nil then
        return
    end
    managedTrain[trainAttributeName] = event.train
    managedTrain[trainIdAttributeName] = event.train.id
    if list[event.old_train_id_1] ~= nil then
        list[event.old_train_id_1] = nil
    end
    if list[event.old_train_id_2] ~= nil then
        list[event.old_train_id_2] = nil
    end
    list[event.train.id] = managedTrain
end

TrainManager.CreateDummyTrain = function(trainManagerEntry, sourceTrain)
    local exitPortalEntity = trainManagerEntry.surfaceExitPortal.entity
    local locomotive =
        exitPortalEntity.surface.create_entity {
        name = "railway_tunnel-tunnel_exit_dummy_locomotive",
        position = exitPortalEntity.position,
        direction = exitPortalEntity.direction,
        force = exitPortalEntity.force,
        raise_built = false,
        create_build_effect_smoke = false
    }
    locomotive.burner.currently_burning = "coal"
    locomotive.burner.remaining_burning_fuel = 4000000
    trainManagerEntry.dummyTrain = locomotive.train
    trainManagerEntry.dummyTrain.schedule = sourceTrain.schedule
    TrainManager.SetTrainToAuto(trainManagerEntry.dummyTrain, sourceTrain.path_end_stop)
    if (trainManagerEntry.dummyTrain.state == defines.train_state.path_lost or trainManagerEntry.dummyTrain.state == defines.train_state.no_path or trainManagerEntry.dummyTrain.state == defines.train_state.destination_full) then
        -- If the train ends up in one of those states something has gone wrong.
        error("dummy train has unexpected state " .. tonumber(trainManagerEntry.dummyTrain.state))
    end
end

TrainManager.DestroyDummyTrain = function(trainManagerEntry)
    if trainManagerEntry.dummyTrain ~= nil and trainManagerEntry.dummyTrain.valid then
        for _, carriage in pairs(trainManagerEntry.dummyTrain.carriages) do
            carriage.destroy()
        end
    end
    trainManagerEntry.dummyTrain = nil
end

TrainManager.SetTrainToAuto = function(train, targetStop)
    if targetStop ~= nil and targetStop.valid then
        -- Train limits on the original target train stop of the train going through the tunnel might prevent
        -- the exiting (dummy or real) train from pathing there, so we have to ensure that the original target stop
        -- has a slot open before setting the train to auto.
        local oldLimit = targetStop.trains_limit
        targetStop.trains_limit = targetStop.trains_count + 1
        train.manual_mode = false
        targetStop.trains_limit = oldLimit
    else
        -- There was no target stop, so no special handling needed
        train.manual_mode = false
    end
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
                managedTrain.aboveTrainEntering.manual_mode = true
                managedTrain.aboveTrainEntering.speed = 0
                if managedTrain.dummyTrain ~= nil then
                    managedTrain.aboveTrainEntering.schedule = managedTrain.dummyTrain.schedule
                elseif managedTrain.aboveTrainLeaving ~= nil then
                    managedTrain.aboveTrainEntering.schedule = managedTrain.aboveTrainLeaving.schedule
                end
            end
            if managedTrain.aboveTrainLeavingId ~= nil then
                global.trainManager.leavingTrainIdToManagedTrain[managedTrain.aboveTrainLeavingId] = nil
                managedTrain.aboveTrainLeaving.manual_mode = true
                managedTrain.aboveTrainLeaving.speed = 0
            end
            TrainManager.DestroyDummyTrain(managedTrain)
            local undergroundCarriages = Utils.DeepCopy(managedTrain.undergroundTrain.carriages)
            for _, carriage in pairs(undergroundCarriages) do
                carriage.destroy()
            end
            EventScheduler.RemoveScheduledEvents("TrainManager.TrainEnteringOngoing", managedTrain.id)
            EventScheduler.RemoveScheduledEvents("TrainManager.TrainUndergroundOngoing", managedTrain.id)
            EventScheduler.RemoveScheduledEvents("TrainManager.TrainLeavingOngoing", managedTrain.id)
            EventScheduler.RemoveScheduledEvents("TrainManager.TrainLeavingTunnelRailSegmentOngoing", managedTrain.id)
            global.trainManager.managedTrains[managedTrain.id] = nil
        end
    end
end

return TrainManager
