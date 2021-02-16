local EventScheduler = require("utility/event-scheduler")
local TrainManager = {}
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")
local Utils = require("utility/utils")

local ForceValidPathLeavingTunnel = false -- defaults false - DEBUG SETTING when true to make a leaving train have a valid path.

TrainManager.CreateGlobals = function()
    global.trainManager = global.trainManager or {}
    global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId or 1
    global.trainManager.managedTrains = global.trainManager.managedTrains or {}
    --[[
        [id] = {
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
            undergroundLeavingPortalEntrancePosition = The underground position equivilent to the portal entrance that the underground train is measured against to decide when it starts leaving.
            aboveSurface = LuaSurface of the main world surface.
            underground = Underground object of this tunnel used by this train manager instance.
            aboveLeavingSignalPosition = The above ground position that the rear leaving carriage should trigger the next carriage at.
            aboveTrainLeavingCarriagesPlaced = count of how many carriages placed so far in the above train while its leaving.
            aboveTrainLeavingTunnelRailSegment = LuaTrain of the train leaving the tunnel's exit portal rail segment on the world surface.
            aboveTrainLeavingTunnelRailSegmentId = The LuaTrain ID of the above Train Leaving Tunnel Rail Segment.
            aboveTrainLeavingPushingLoco = Locomotive entity pushing the leaving train if it donesn't have a forwards facing locomotive yet, otherwise Nil.
            committed = boolean if train is already fully committed to going through tunnel
            enteringCarriageIdToUndergroundCarriageEntity = Table of the entering carriage unit number to the underground carriage entity for each carriage in the train.
            undergroundCarriageIdToLeavingCarriageId = Table of the underground carriage unit number to the leaving carriage unit number for each carriage in the train.
            undergroudCarriageIdsToPlayerContainer = Table for each underground carriage in this train with a player container related to it. Key'd by underground carraige unit number.
        }
    ]]
    global.trainManager.enteringTrainIdToManagedTrain = global.trainManager.enteringTrainIdToManagedTrain or {}
    global.trainManager.leavingTrainIdToManagedTrain = global.trainManager.leavingTrainIdToManagedTrain or {}
    global.trainManager.leavingTunnelRailSegmentTrainIdToManagedTrain = global.trainManager.leavingTunnelRailSegmentTrainIdToManagedTrain or {}
    global.trainManager.playerContainers = global.trainManager.playerContainers or {}
    --[[
        [id] = {
            id = unit_number of the player container entity.
            entity = the player container entity the player is sitting in.
            player = LuaPlayer.
            undergroundCarriageEntity = the underground carriage entity this container is related to.
            undergroundCarriageId = the unit_number of the underground carriage entity this container is related to.
            trainManagerEntry = trainManagerEntry globla object this is owned by.
        }
    ]]
    global.trainManager.playerIdToPlayerContainer = global.trainManager.playerIdToPlayerContainer or {}
    global.trainManager.playerTryLeaveVehicle = global.trainManager.playerTryLeaveVehicle or {}
    --[[
        [id] = {
            id = player index.
            oldVehicle = the vehicle entity the player was in before they hit the enter/exit vehicle button.
        }
    ]]
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
    Events.RegisterHandlerCustomInput("railway_tunnel-toggle_driving", "TrainManager.OnToggleDrivingInput", TrainManager.OnToggleDrivingInput)
    Events.RegisterHandlerEvent(defines.events.on_player_driving_changed_state, "TrainManager.OnPlayerDrivingChangedState", TrainManager.OnPlayerDrivingChangedState)
    EventScheduler.RegisterScheduledEventType("TrainManager.OnToggleDrivingInputAfterChangedState", TrainManager.OnToggleDrivingInputAfterChangedState)
end

TrainManager.TrainEnteringInitial = function(trainEntering, surfaceEntrancePortalEndSignal)
    local trainManagerEntry = {
        id = global.trainManager.nextManagedTrainId,
        aboveTrainEntering = trainEntering,
        aboveTrainEnteringId = trainEntering.id,
        surfaceEntrancePortalEndSignal = surfaceEntrancePortalEndSignal,
        surfaceEntrancePortal = surfaceEntrancePortalEndSignal.portal,
        tunnel = surfaceEntrancePortalEndSignal.portal.tunnel,
        trainTravelDirection = Utils.LoopDirectionValue(surfaceEntrancePortalEndSignal.entity.direction + 4),
        committed = false,
        undergroudCarriageIdsToPlayerContainer = {}
    }
    global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId + 1
    global.trainManager.managedTrains[trainManagerEntry.id] = trainManagerEntry
    local tunnel = trainManagerEntry.tunnel
    trainManagerEntry.aboveSurface = tunnel.aboveSurface
    trainManagerEntry.undergroundTunnel = tunnel.undergroundTunnel
    if trainManagerEntry.aboveTrainEntering.speed > 0 then
        trainManagerEntry.aboveTrainEnteringForwards = true
    else
        trainManagerEntry.aboveTrainEnteringForwards = false
    end
    trainManagerEntry.trainTravelOrientation = Utils.DirectionToOrientation(trainManagerEntry.trainTravelDirection)
    global.trainManager.enteringTrainIdToManagedTrain[trainEntering.id] = trainManagerEntry

    -- Get the exit end signal on the other portal so we know when to bring the train back in.
    for _, portal in pairs(tunnel.portals) do
        if portal.id ~= surfaceEntrancePortalEndSignal.portal.id then
            trainManagerEntry.surfaceExitPortalEndSignal = portal.endSignals["out"]
            trainManagerEntry.surfaceExitPortal = portal
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
                x = tunnel.undergroundTunnel.tunnelInstanceValue + 1,
                y = 0
            }
        ),
        Utils.RotatePositionAround0(
            trainManagerEntry.trainTravelOrientation,
            {
                x = 0,
                y = 0 - (tunnel.undergroundTunnel.undergroundLeadInTiles - 1)
            }
        )
    )
    undergroundTrain.schedule = {
        current = 1,
        records = {
            {
                rail = tunnel.undergroundTunnel.undergroundSurface.surface.find_entity("straight-rail", undergroundTrainEndScheduleTargetPos)
            }
        }
    }
    trainManagerEntry.undergroundTrain = undergroundTrain
    TrainManager.SetUndergroundTrainSpeed(trainManagerEntry, math.abs(sourceTrain.speed))

    trainManagerEntry.undergroundLeavingPortalEntrancePosition = Utils.ApplyOffsetToPosition(trainManagerEntry.surfaceExitPortal.portalEntrancePosition, trainManagerEntry.undergroundTunnel.undergroundOffsetFromSurface)

    Interfaces.Call("Tunnel.TrainReservedTunnel", trainManagerEntry)
    EventScheduler.ScheduleEventEachTick("TrainManager.TrainEnteringOngoing", trainManagerEntry.id)
    EventScheduler.ScheduleEventEachTick("TrainManager.TrainUndergroundOngoing", trainManagerEntry.id)
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

    local nextCarriage
    -- aboveTrainEnteringForwards has been updated for us by SetAboveTrainEnteringSpeed()
    if trainManagerEntry.aboveTrainEnteringForwards then
        nextCarriage = aboveTrainEntering.front_stock
    else
        nextCarriage = aboveTrainEntering.back_stock
    end

    if Utils.GetDistanceSingleAxis(nextCarriage.position, trainManagerEntry.surfaceEntrancePortalEndSignal.entity.position, trainManagerEntry.tunnel.railAlignmentAxis) < 14 then
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

        -- Handle any player in the train carriage.
        local driver = nextCarriage.get_driver()
        if driver ~= nil then
            TrainManager.PlayerInCarriageEnteringTunnel(trainManagerEntry, driver, nextCarriage)
        end

        nextCarriage.destroy()

        -- Update local variable as new train Id after removing carriage.
        if trainManagerEntry.aboveTrainEntering.valid then
            aboveTrainEntering = trainManagerEntry.aboveTrainEntering
        else
            aboveTrainEntering = nil --set to nil if not valid as easier/cheaper to check later than valid.
        end
    end
    if aboveTrainEntering == nil or (not aboveTrainEntering.valid) then
        -- Train has completed entering.
        EventScheduler.RemoveScheduledEventFromEachTick("TrainManager.TrainEnteringOngoing", trainManagerEntry.id)
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.aboveTrainEnteringId] = nil
        trainManagerEntry.aboveTrainEntering = nil
        trainManagerEntry.aboveTrainEnteringId = nil
        trainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity = nil
        Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", trainManagerEntry)
    end
end

TrainManager.TrainUndergroundOngoing = function(event)
    local trainManagerEntry, leadCarriage = global.trainManager.managedTrains[event.instanceId]
    if trainManagerEntry == nil then
        -- Tunnel trip has been aborted.
        return
    end

    TrainManager.MoveTrainsPlayerContainers(trainManagerEntry)

    -- Close the underground Exit signal if the aboveground Exit signal isn't open, otherwise open it.
    local exitPortalOutSignal = trainManagerEntry.surfaceExitPortal.entrySignals["out"]
    Interfaces.Call("Underground.SetUndergroundExitSignalState", exitPortalOutSignal.undergroundSignalPaired, exitPortalOutSignal.entity.signal_state)

    -- Track underground train's lead carriage.
    if (trainManagerEntry.undergroundTrain.speed > 0) then
        leadCarriage = trainManagerEntry.undergroundTrain["front_stock"]
    else
        leadCarriage = trainManagerEntry.undergroundTrain["back_stock"]
    end
    if Utils.GetDistanceSingleAxis(leadCarriage.position, trainManagerEntry.undergroundLeavingPortalEntrancePosition, trainManagerEntry.tunnel.railAlignmentAxis) <= 30 then
        --The lead carriage is close enough to the exit portal's entry signal to be safely in the leaving tunnel area.
        EventScheduler.RemoveScheduledEventFromEachTick("TrainManager.TrainUndergroundOngoing", trainManagerEntry.id)
        Interfaces.Call("Underground.SetUndergroundExitSignalState", exitPortalOutSignal.undergroundSignalPaired, defines.signal_state.open) -- Reset the underground Exit signal to open for the next train. As this train will be path & speed controlled by the above train.
        TrainManager.TrainLeavingInitial(trainManagerEntry)
    end
end

TrainManager.TrainLeavingInitial = function(trainManagerEntry)
    -- cleanup dummy train to make room for the reemerging train, preserving schedule and target stop for later.
    local schedule, isManual, targetStop = trainManagerEntry.dummyTrain.schedule, trainManagerEntry.dummyTrain.manual_mode, trainManagerEntry.dummyTrain.path_end_stop
    TrainManager.DestroyDummyTrain(trainManagerEntry)

    local sourceTrain, undergroundLeadCarriage = trainManagerEntry.undergroundTrain
    if (sourceTrain.speed > 0) then
        undergroundLeadCarriage = sourceTrain["front_stock"]
    else
        undergroundLeadCarriage = sourceTrain["back_stock"]
    end

    local placementPosition = Utils.ApplyOffsetToPosition(undergroundLeadCarriage.position, trainManagerEntry.undergroundTunnel.surfaceOffsetFromUnderground)
    local placedCarriage = undergroundLeadCarriage.clone {position = placementPosition, surface = trainManagerEntry.aboveSurface, create_build_effect_smoke = false}
    placedCarriage.train.speed = undergroundLeadCarriage.speed -- Set the speed when its a train of 1. Before a pushing locomotive may be added and make working out speed direction harder.
    trainManagerEntry.aboveTrainLeavingCarriagesPlaced = 1

    -- Add a pushing loco if needed.
    if not TrainManager.CarriageIsAPushingLoco(placedCarriage, trainManagerEntry.trainTravelOrientation) then
        trainManagerEntry.aboveTrainLeavingPushingLoco = TrainManager.AddPushingLocoToEndOfTrain(placedCarriage, trainManagerEntry.trainTravelOrientation)
    end

    local aboveTrainLeaving = placedCarriage.train
    trainManagerEntry.aboveTrainLeaving, trainManagerEntry.aboveTrainLeavingId = aboveTrainLeaving, aboveTrainLeaving.id
    global.trainManager.leavingTrainIdToManagedTrain[aboveTrainLeaving.id] = trainManagerEntry

    -- Restore train schedule.
    TrainManager.LeavingTrainSetScheduleCheckState(trainManagerEntry, aboveTrainLeaving, schedule, isManual, targetStop)

    TrainManager.TransferPlayerFromContainerForClonedUndergroundCarriage(trainManagerEntry, undergroundLeadCarriage, placedCarriage)
    Interfaces.Call("Tunnel.TrainStartedExitingTunnel", trainManagerEntry)
    EventScheduler.ScheduleEventEachTick("TrainManager.TrainLeavingOngoing", trainManagerEntry.id)
end

TrainManager.LeavingTrainSetScheduleCheckState = function(trainManagerEntry, aboveTrainLeaving, schedule, isManual, targetStop)
    aboveTrainLeaving.schedule = schedule
    if not isManual then
        TrainManager.SetTrainToAuto(aboveTrainLeaving, targetStop)

        -- Handle if the train doesn't have the desired state of moving away from tunnel
        if not TrainManager.ConfirmMovingLeavingTrainState(aboveTrainLeaving) then
            if ForceValidPathLeavingTunnel then
                -- In strict debug mode so flag undesired state.
                error("reemerging train should have positive movement state")
            end
            -- Set the train to move to the end of the tunnel (signal segment) as chance it can auto turn around and is far clearer whats happened.
            local newSchedule = Utils.DeepCopy(aboveTrainLeaving.schedule)
            local endOfTunnelScheduleRecord = {rail = trainManagerEntry.surfaceExitPortal.entrySignals["out"].entity.get_connected_rails()[1], temporary = true}
            table.insert(newSchedule.records, newSchedule.current, endOfTunnelScheduleRecord)
            aboveTrainLeaving.schedule = newSchedule
        end
    end
end

TrainManager.TrainLeavingOngoing = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    local aboveTrainLeaving, sourceTrain = trainManagerEntry.aboveTrainLeaving, trainManagerEntry.undergroundTrain
    local desiredSpeed = TrainManager.GetTrainSpeed(trainManagerEntry)

    if desiredSpeed ~= 0 then
        local currentSourceTrainCarriageIndex = trainManagerEntry.aboveTrainLeavingCarriagesPlaced
        local nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex + 1
        if (sourceTrain.speed < 0) then
            currentSourceTrainCarriageIndex = #sourceTrain.carriages - trainManagerEntry.aboveTrainLeavingCarriagesPlaced
            nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex
        end

        local nextSourceCarriageEntity = sourceTrain.carriages[nextSourceTrainCarriageIndex]
        if nextSourceCarriageEntity == nil then
            -- All wagons placed so tidy up.
            EventScheduler.RemoveScheduledEventFromEachTick("TrainManager.TrainLeavingOngoing", trainManagerEntry.id)
            TrainManager.TrainLeavingCompleted(trainManagerEntry, desiredSpeed)
            return
        end

        local aboveTrainLeavingRearCarriage, aboveTrainLeavingRearCarriageIndex, aboveTrainLeavingRearCarriagePushingIndexMod
        if (aboveTrainLeaving.speed > 0) then
            aboveTrainLeavingRearCarriageIndex = #aboveTrainLeaving.carriages
            aboveTrainLeavingRearCarriagePushingIndexMod = -1
        else
            aboveTrainLeavingRearCarriageIndex = 1
            aboveTrainLeavingRearCarriagePushingIndexMod = 1
        end
        if trainManagerEntry.aboveTrainLeavingPushingLoco ~= nil then
            aboveTrainLeavingRearCarriageIndex = aboveTrainLeavingRearCarriageIndex + aboveTrainLeavingRearCarriagePushingIndexMod
        end
        aboveTrainLeavingRearCarriage = aboveTrainLeaving.carriages[aboveTrainLeavingRearCarriageIndex]

        if Utils.GetDistanceSingleAxis(aboveTrainLeavingRearCarriage.position, trainManagerEntry.surfaceExitPortalEndSignal.entity.position, trainManagerEntry.tunnel.railAlignmentAxis) > 20 then
            -- Reattaching next carriage can clobber schedule and will set train to manual, so preserve state.
            local schedule, isManual, targetStop = aboveTrainLeaving.schedule, aboveTrainLeaving.manual_mode, aboveTrainLeaving.path_end_stop

            -- Remove the pushing loco if present before the next carriage is placed.
            local hadPushingLoco = trainManagerEntry.aboveTrainLeavingPushingLoco ~= nil
            if trainManagerEntry.aboveTrainLeavingPushingLoco ~= nil then
                trainManagerEntry.aboveTrainLeavingPushingLoco.destroy()
                trainManagerEntry.aboveTrainLeavingPushingLoco = nil
            end

            local aboveTrainOldCarriageCount = #aboveTrainLeavingRearCarriage.train.carriages
            local nextCarriagePosition = Utils.ApplyOffsetToPosition(nextSourceCarriageEntity.position, trainManagerEntry.undergroundTunnel.surfaceOffsetFromUnderground)
            local placedCarriage = nextSourceCarriageEntity.clone {position = nextCarriagePosition, surface = trainManagerEntry.aboveSurface, create_build_effect_smoke = false}
            trainManagerEntry.aboveTrainLeavingCarriagesPlaced = trainManagerEntry.aboveTrainLeavingCarriagesPlaced + 1
            if #placedCarriage.train.carriages ~= aboveTrainOldCarriageCount + 1 then
                error("Placed carriage not part of train as expected carriage count not right")
            end

            -- If train had a pushing loco before and still needs one, add one back.
            if hadPushingLoco and (not TrainManager.CarriageIsAPushingLoco(placedCarriage, trainManagerEntry.trainTravelOrientation)) then
                trainManagerEntry.aboveTrainLeavingPushingLoco = TrainManager.AddPushingLocoToEndOfTrain(placedCarriage, trainManagerEntry.trainTravelOrientation)
            end

            -- LuaTrain has been replaced and updated by adding a wagon, so obtain a local reference to it again.
            aboveTrainLeaving = trainManagerEntry.aboveTrainLeaving

            -- Restore schedule and state.
            TrainManager.LeavingTrainSetScheduleCheckState(trainManagerEntry, aboveTrainLeaving, schedule, isManual, targetStop)

            TrainManager.TransferPlayerFromContainerForClonedUndergroundCarriage(trainManagerEntry, nextSourceCarriageEntity, placedCarriage)
        end

        TrainManager.MoveTrainsPlayerContainers(trainManagerEntry)
    end

    TrainManager.SetTrainAbsoluteSpeed(aboveTrainLeaving, desiredSpeed)
    TrainManager.SetUndergroundTrainSpeed(trainManagerEntry, desiredSpeed)
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
    EventScheduler.ScheduleEventEachTick("TrainManager.TrainLeavingTunnelRailSegmentOngoing", trainManagerEntry.id)
end

TrainManager.TrainLeavingTunnelRailSegmentOngoing = function(event)
    -- Track the tunnel portal's entrance rail signal so we can mark the tunnel as open for the next train when the current train has left. -- We are assuming that no train gets in to the portal rail segment before our main train gets out.
    -- This is far more UPS effecient than checking the trains last carriage and seeing if its end rail signal is our portal entrance one.
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    local exitPortalEntranceSignalEntity = trainManagerEntry.surfaceExitPortal.entrySignals["in"].entity
    if exitPortalEntranceSignalEntity.signal_state ~= defines.signal_state.closed then
        -- No train in the block so our one must have left.
        EventScheduler.RemoveScheduledEventFromEachTick("TrainManager.TrainLeavingTunnelRailSegmentOngoing", trainManagerEntry.id)
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
    EventScheduler.RemoveScheduledEventFromEachTick("TrainManager.TrainEnteringOngoing", trainManagerEntry.id)
    EventScheduler.RemoveScheduledEventFromEachTick("TrainManager.TrainUndergroundOngoing", trainManagerEntry.id)
    EventScheduler.RemoveScheduledEventFromEachTick("TrainManager.TrainLeavingOngoing", trainManagerEntry.id)
    EventScheduler.RemoveScheduledEventFromEachTick("TrainManager.TrainLeavingTunnelRailSegmentOngoing", trainManagerEntry.id)
    TrainManager.RemoveUndergroundTrain(trainManagerEntry)
    if trainManagerEntry.aboveTrainEntering then
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.aboveTrainEnteringId] = nil
    end
    if trainManagerEntry.aboveTrainLeaving then
        global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.aboveTrainLeavingId] = nil
    end
    if trainManagerEntry.aboveTrainLeavingTunnelRailSegment then
        global.trainManager.leavingTunnelRailSegmentTrainIdToManagedTrain[trainManagerEntry.aboveTrainLeavingTunnelRailSegmentId] = nil
    end
    for _, playerContainer in pairs(trainManagerEntry.undergroudCarriageIdsToPlayerContainer) do
        TrainManager.RemovePlayerContainer(playerContainer)
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
    locomotive.destructible = false
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

TrainManager.IsSpeedGovernedByLeavingTrain = function(trainManagerEntry)
    local aboveTrainLeaving = trainManagerEntry.aboveTrainLeaving
    if aboveTrainLeaving and aboveTrainLeaving.valid and aboveTrainLeaving.state ~= defines.train_state.on_the_path then
        return true
    else
        return false
    end
end

-- determine the current speed of the train passing through the tunnel
TrainManager.GetTrainSpeed = function(trainManagerEntry)
    if TrainManager.IsSpeedGovernedByLeavingTrain(trainManagerEntry) then
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

    if speed ~= 0 or not TrainManager.IsSpeedGovernedByLeavingTrain(trainManagerEntry) then
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
    local placedCarriage, refTrain, targetSurface = nil, trainManagerEntry.aboveTrainEntering, trainManagerEntry.undergroundTunnel.undergroundSurface.surface

    local endSignalRailUnitNumber = trainManagerEntry.surfaceEntrancePortalEndSignal.entity.get_connected_rails()[1].unit_number
    local firstCarriageDistanceFromPortalEntrance = 0
    for _, railEntity in pairs(refTrain.path.rails) do
        -- This doesn't account for where on the current rail entity the carriage is, but should be accurate enough. Does cause up to half a wcarriage difference in train on both sides of a tunnel.
        local thisRailLength = 2
        if railEntity.type == "curved-rail" then
            thisRailLength = 7 -- Estimate
        end
        firstCarriageDistanceFromPortalEntrance = firstCarriageDistanceFromPortalEntrance + thisRailLength
        if railEntity.unit_number == endSignalRailUnitNumber then
            break
        end
    end

    local tunnelInitialPosition = Utils.RotatePositionAround0(trainManagerEntry.tunnel.alignmentOrientation, {x = 1 + trainManagerEntry.undergroundTunnel.tunnelInstanceValue, y = 0})
    local firstCarriageDistanceFromPortalCenter = Utils.RotatePositionAround0(trainManagerEntry.trainTravelOrientation, {x = 0, y = firstCarriageDistanceFromPortalEntrance + trainManagerEntry.tunnel.portals[1].entranceDistanceFromCenter})
    local nextCarriagePosition = Utils.ApplyOffsetToPosition(tunnelInitialPosition, firstCarriageDistanceFromPortalCenter)
    local trainCarriagesOffset = Utils.RotatePositionAround0(trainManagerEntry.trainTravelOrientation, {x = 0, y = 7})
    local trainCarriagesForwardDirection = trainManagerEntry.trainTravelDirection
    if not trainManagerEntry.aboveTrainEnteringForwards then
        trainCarriagesForwardDirection = Utils.LoopDirectionValue(trainCarriagesForwardDirection + 4)
    end

    local minCarriageIndex, maxCarriageIndex, carriageIterator = 1, #refTrain.carriages, 1
    if (refTrain.speed < 0) then
        minCarriageIndex, maxCarriageIndex, carriageIterator = #refTrain.carriages, 1, -1
    end
    trainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity = {}
    for currentSourceTrainCarriageIndex = minCarriageIndex, maxCarriageIndex, carriageIterator do
        local refCarriage = refTrain.carriages[currentSourceTrainCarriageIndex]
        local carriageDirection = trainCarriagesForwardDirection
        if refCarriage.speed ~= refTrain.speed then
            carriageDirection = Utils.LoopDirectionValue(carriageDirection + 4)
        end
        local refCarriageGoingForwards = true
        if refCarriage.speed < 0 then
            refCarriageGoingForwards = false
        end
        placedCarriage = TrainManager.CopyCarriage(targetSurface, refCarriage, nextCarriagePosition, carriageDirection, refCarriageGoingForwards)
        trainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity[refCarriage.unit_number] = placedCarriage

        nextCarriagePosition = Utils.ApplyOffsetToPosition(nextCarriagePosition, trainCarriagesOffset)
    end
    return placedCarriage.train
end

TrainManager.CopyCarriage = function(targetSurface, refCarriage, newPosition, newDirection, refCarriageGoingForwards)
    local placedCarriage = refCarriage.clone {position = newPosition, surface = targetSurface, create_build_effect_smoke = false}
    if Utils.OrientationToDirection(placedCarriage.orientation) ~= newDirection then
        local wrongFrontOfTrain, correctFrontOfTrain
        if refCarriageGoingForwards then
            wrongFrontOfTrain, correctFrontOfTrain = defines.rail_direction.back, defines.rail_direction.front
        else
            wrongFrontOfTrain, correctFrontOfTrain = defines.rail_direction.front, defines.rail_direction.back
        end
        placedCarriage.disconnect_rolling_stock(wrongFrontOfTrain)
        placedCarriage.rotate()
        placedCarriage.connect_rolling_stock(correctFrontOfTrain)
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
            EventScheduler.RemoveScheduledOnceEvents("TrainManager.TrainEnteringOngoing", managedTrain.id)
            EventScheduler.RemoveScheduledOnceEvents("TrainManager.TrainUndergroundOngoing", managedTrain.id)
            EventScheduler.RemoveScheduledOnceEvents("TrainManager.TrainLeavingOngoing", managedTrain.id)
            EventScheduler.RemoveScheduledOnceEvents("TrainManager.TrainLeavingTunnelRailSegmentOngoing", managedTrain.id)
            global.trainManager.managedTrains[managedTrain.id] = nil

            for _, playerContainer in pairs(managedTrain.undergroudCarriageIdsToPlayerContainer) do
                playerContainer.player.destroy()
                TrainManager.RemovePlayerContainer(playerContainer)
            end
        end
    end
end

TrainManager.CarriageIsAPushingLoco = function(carriage, trainDirection)
    return carriage.type == "locomotive" and carriage.orientation == trainDirection
end

TrainManager.AddPushingLocoToEndOfTrain = function(lastCarriage, trainOrientation)
    local pushingLocoPlacementPosition = Utils.ApplyOffsetToPosition(lastCarriage.position, Utils.RotatePositionAround0(trainOrientation, {x = 0, y = 4}))
    local pushingLocomotiveEntity = lastCarriage.surface.create_entity {name = "railway_tunnel-tunnel_portal_pushing_locomotive", position = pushingLocoPlacementPosition, force = lastCarriage.force, direction = Utils.OrientationToDirection(trainOrientation)}
    pushingLocomotiveEntity.destructible = false
    return pushingLocomotiveEntity
end

-- Check a moving trains (non 0 speed) got a happy state. For use after manipulating the train and so assumes the train was in a happy state before we did this.
TrainManager.ConfirmMovingLeavingTrainState = function(train)
    if train.state == defines.train_state.on_the_path or train.state == defines.train_state.arrive_signal or train.state == defines.train_state.arrive_station then
        return true
    else
        return false
    end
end

TrainManager.OnToggleDrivingInput = function(event)
    -- Called before the game tries to change driving state. So the player.vehicle is the players state before the change. Let the game do its natural thing and then correct the outcome if needed.
    -- Function is called before this tick's on_tick event runs and so we can safely schedule tick events for the same tick in this case.
    local player = game.get_player(event.player_index)
    local playerVehicle = player.vehicle
    if playerVehicle == nil then
        return
    elseif playerVehicle.name == "railway_tunnel-player_container" or playerVehicle.type == "locomotive" or playerVehicle.type == "cargo-wagon" or playerVehicle.type == "fluid-wagon" or playerVehicle.type == "artillery-wagon" then
        global.trainManager.playerTryLeaveVehicle[player.index] = {id = player.index, oldVehicle = playerVehicle}
        EventScheduler.ScheduleEventOnce(game.tick, "TrainManager.OnToggleDrivingInputAfterChangedState", player.index)
    end
end

TrainManager.OnPlayerDrivingChangedState = function(event)
    local player = game.get_player(event.player_index)
    local details = global.trainManager.playerTryLeaveVehicle[player.index]
    if details == nil then
        return
    end
    if details.oldVehicle.name == "railway_tunnel-player_container" then
        -- In a player container so always handle the player as they will have jumped out of the tunnel mid length.
        TrainManager.PlayerLeaveTunnelVehicle(player, nil, details.oldVehicle)
    else
        -- Driving state changed from a non player_container so is base game working correctly.
        TrainManager.CancelPlayerTryLeaveTrain(player)
    end
end

TrainManager.OnToggleDrivingInputAfterChangedState = function(event)
    -- Triggers after the OnPlayerDrivingChangedState() has run for this if it is going to.
    local player = game.get_player(event.instanceId)
    local details = global.trainManager.playerTryLeaveVehicle[player.index]
    if details == nil then
        return
    end
    if details.oldVehicle.name == "railway_tunnel-player_container" then
        -- In a player container so always handle the player.
        TrainManager.PlayerLeaveTunnelVehicle(player, nil, details.oldVehicle)
    elseif player.vehicle ~= nil then
        -- Was in a train carriage before trying to get out and still is, so check if its on a portal entity (blocks player getting out).
        local portalEntitiesFound = player.vehicle.surface.find_entities_filtered {position = player.vehicle.position, name = "railway_tunnel-tunnel_portal_surface-placed", limit = 1}
        if #portalEntitiesFound == 1 then
            TrainManager.PlayerLeaveTunnelVehicle(player, portalEntitiesFound[1], nil)
        end
    end
end

TrainManager.PlayerLeaveTunnelVehicle = function(player, portalEntity, vehicle)
    local portalObject
    vehicle = vehicle or player.vehicle
    local playerContainer = global.trainManager.playerContainers[vehicle.unit_number]

    if portalEntity == nil then
        -- Find nearest portal
        local trainManagerEntry = playerContainer.trainManagerEntry
        if Utils.GetDistanceSingleAxis(trainManagerEntry.surfaceEntrancePortal.entity.position, player.position, trainManagerEntry.tunnel.railAlignmentAxis) < Utils.GetDistanceSingleAxis(trainManagerEntry.surfaceExitPortal.entity.position, player.position, trainManagerEntry.tunnel.railAlignmentAxis) then
            portalObject = trainManagerEntry.surfaceEntrancePortal
        else
            portalObject = trainManagerEntry.surfaceExitPortal
        end
    else
        portalObject = global.tunnelPortals.portals[portalEntity.unit_number]
    end
    local playerPosition = player.surface.find_non_colliding_position("railway_tunnel-character_placement_leave_tunnel", portalObject.portalEntrancePosition, 0, 0.2) -- Use a rail signal to test place as it collides with rails and so we never get placed on the track.
    TrainManager.CancelPlayerTryLeaveTrain(player)
    vehicle.set_driver(nil)
    player.teleport(playerPosition)
    TrainManager.RemovePlayerContainer(global.trainManager.playerIdToPlayerContainer[player.index])
end

TrainManager.CancelPlayerTryLeaveTrain = function(player)
    global.trainManager.playerTryLeaveVehicle[player.index] = nil
    EventScheduler.RemoveScheduledOnceEvents("TrainManager.OnToggleDrivingInputAfterChangedState", player.index, game.tick)
end

TrainManager.PlayerInCarriageEnteringTunnel = function(trainManagerEntry, driver, playersCarriage)
    local player
    if not driver.is_player() then
        -- Is a character player driving.
        player = driver.player
    else
        player = driver
    end
    local playerContainerEntity = trainManagerEntry.aboveSurface.create_entity {name = "railway_tunnel-player_container", position = driver.position, force = driver.force}
    playerContainerEntity.destructible = false
    playerContainerEntity.set_driver(player)

    -- Record state for future updating.
    local playersUndergroundCarriage = trainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity[playersCarriage.unit_number]
    local playerContainer = {
        id = playerContainerEntity.unit_number,
        player = player,
        entity = playerContainerEntity,
        undergroundCarriageEntity = playersUndergroundCarriage,
        undergroundCarriageId = playersUndergroundCarriage.unit_number,
        trainManagerEntry = trainManagerEntry
    }
    trainManagerEntry.undergroudCarriageIdsToPlayerContainer[playersUndergroundCarriage.unit_number] = playerContainer
    global.trainManager.playerIdToPlayerContainer[playerContainer.player.index] = playerContainer
    global.trainManager.playerContainers[playerContainer.id] = playerContainer
end

TrainManager.MoveTrainsPlayerContainers = function(trainManagerEntry)
    -- Update any player containers for the train.
    for _, playerContainer in pairs(trainManagerEntry.undergroudCarriageIdsToPlayerContainer) do
        local playerContainerPosition = Utils.ApplyOffsetToPosition(playerContainer.undergroundCarriageEntity.position, trainManagerEntry.undergroundTunnel.surfaceOffsetFromUnderground)
        playerContainer.entity.teleport(playerContainerPosition)
    end
end

TrainManager.TransferPlayerFromContainerForClonedUndergroundCarriage = function(trainManagerEntry, undergroundCarriage, placedCarriage)
    -- Handle any players riding in this placed carriage.
    if trainManagerEntry.undergroudCarriageIdsToPlayerContainer[undergroundCarriage.unit_number] ~= nil then
        local playerContainer = trainManagerEntry.undergroudCarriageIdsToPlayerContainer[undergroundCarriage.unit_number]
        placedCarriage.set_driver(playerContainer.player)
        TrainManager.RemovePlayerContainer(playerContainer)
    end
end

TrainManager.RemovePlayerContainer = function(playerContainer)
    if playerContainer == nil then
        -- If the carriage hasn't entered the tunnel, but the carriage is in the portal theres no PlayerContainer yet.
        return
    end
    playerContainer.entity.destroy()
    playerContainer.trainManagerEntry.undergroudCarriageIdsToPlayerContainer[playerContainer.undergroundCarriageId] = nil
    global.trainManager.playerIdToPlayerContainer[playerContainer.player.index] = nil
    global.trainManager.playerContainers[playerContainer.id] = nil
end

return TrainManager
