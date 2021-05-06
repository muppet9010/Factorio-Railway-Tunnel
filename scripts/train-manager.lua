local TrainManager = {}
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local TrainManagerFuncs = require("scripts/train-manager-functions")
local PlayerContainers = require("scripts/player-containers") -- Uses this file directly, rather than via interface. Details in the sub files notes.

local EnteringTrainStates = {
    approaching = "approaching", -- Train is approaching the tunnel, but can still turn back.
    entering = "entering", -- Train is committed to entering the tunnel.
    finished = "finished" -- Train has fully completed entering the tunnel.
}
local UndergroundTrainStates = {
    travelling = "travelling",
    finished = "finished"
}
local LeavingTrainStates = {
    pre = "pre",
    leaving = "leaving",
    trainLeftTunnel = "trainLeftTunnel",
    finished = "finished"
}
local PrimaryTrainPartNames = {entering = "entering", underground = "underground", leaving = "leaving"}

TrainManager.CreateGlobals = function()
    global.trainManager = global.trainManager or {}
    global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId or 1
    global.trainManager.managedTrains = global.trainManager.managedTrains or {}
    --[[
        [id] = {
            id = uniqiue id of this managed train passing through the tunnel.
            primaryTrainPartName = The primary real train part name (PrimaryTrainPartName) that dictates the trains primary monitored object.

            aboveTrainEnteringState = The current entering train's state (EnteringTrainStates).
            aboveTrainEntering = LuaTrain of the entering train on the world surface.
            aboveTrainEnteringId = The LuaTrain ID of the above Train Entering.
            aboveTrainEnteringForwards = boolean if the train is moving forwards or backwards from its viewpoint.

            undergroundTrainState = The current underground train's state (UndergroundTrainStates).
            undergroundTrain = LuaTrain of the train created in the underground surface.

            aboveTrainLeavingState = The current leaving train's state (LeavingTrainStates).
            aboveTrainLeaving = LuaTrain of the train created leaving the tunnel on the world surface.
            aboveTrainLeavingId = The LuaTrain ID of the above Train Leaving.
            aboveTrainLeavingCarriagesPlaced = count of how many carriages placed so far in the above train while its leaving.
            aboveTrainLeavingPushingLoco = Locomotive entity pushing the leaving train if it donesn't have a forwards facing locomotive yet, otherwise Nil.

            aboveTrainLeft = LuaTrain of the train thats left the tunnel.
            aboveTrainLeftId = The LuaTrain ID of the aboveTrainLeft.

            dummyTrain = LuaTrain of the dummy train used to keep the train stop reservation alive
            trainTravelDirection = defines.direction the train is heading in.
            trainTravelOrientation = the orientation of the trainTravelDirection.

            aboveSurface = LuaSurface of the main world surface.
            surfaceEntrancePortal = the portal global object of the entrance portal for this tunnel usage instance.
            surfaceEntrancePortalEndSignal = the endSignal global object of the rail signal at the end of the entrance portal track (forced closed signal).
            surfaceExitPortal = the portal global object of the exit portal for this tunnel usage instance.
            surfaceExitPortalEndSignal = the endSignal global object of the rail signal at the end of the exit portal track (forced closed signal).
            tunnel = ref to the global tunnel object.
            undergroundLeavingPortalEntrancePosition = The underground position equivilent to the portal entrance that the underground train is measured against to decide when it starts leaving.

            enteringCarriageIdToUndergroundCarriageEntity = Table of the entering carriage unit number to the underground carriage entity for each carriage in the train. Currently used for tracking players riding in a train when it enters.
        }
    ]]
    -- Used to track trainIds to managedTrainEntries. When the trainId is detected as changing via event the global object is updated to stay up to date. -- TODO: make in to a single list with attributes for the "type". Low priority and just to make code neater.
    global.trainManager.enteringTrainIdToManagedTrain = global.trainManager.enteringTrainIdToManagedTrain or {}
    global.trainManager.leavingTrainIdToManagedTrain = global.trainManager.leavingTrainIdToManagedTrain or {}
    global.trainManager.trainLeftTunnelTrainIdToManagedTrain = global.trainManager.trainLeftTunnelTrainIdToManagedTrain or {}
end

TrainManager.OnLoad = function()
    Interfaces.RegisterInterface("TrainManager.TrainApproachingInitial", TrainManager.TrainApproachingInitial)
    EventScheduler.RegisterScheduledEventType("TrainManager.ProcessManagedTrains", TrainManager.ProcessManagedTrains)
    Events.RegisterHandlerEvent(defines.events.on_train_created, "TrainManager.TrainTracking_OnTrainCreated", TrainManager.TrainTracking_OnTrainCreated)
    Interfaces.RegisterInterface("TrainManager.IsTunnelInUse", TrainManager.IsTunnelInUse)
    Interfaces.RegisterInterface("TrainManager.TunnelRemoved", TrainManager.TunnelRemoved)
end

TrainManager.OnStartup = function()
    -- Always run the ProcessManagedTrains check each tick regardless of if theres any registered trains yet. No real UPS impact.
    if not EventScheduler.IsEventScheduledEachTick("TrainManager.ProcessManagedTrains") then
        EventScheduler.ScheduleEventEachTick("TrainManager.ProcessManagedTrains")
    end
end

TrainManager.ProcessManagedTrains = function()
    -- If the tunnel trip is terminated mid processing the trainManagerEntry will become nil.
    for _, trainManagerEntry in pairs(global.trainManager.managedTrains) do
        if trainManagerEntry ~= nil and trainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.entering and trainManagerEntry.aboveTrainEnteringState == EnteringTrainStates.approaching then
            -- Keep on running until the train is committed to entering the tunnel while approaching is primary.
            TrainManager.TrainApproachingOngoing(trainManagerEntry)
        end
        if trainManagerEntry ~= nil and trainManagerEntry.aboveTrainEnteringState == EnteringTrainStates.entering then
            -- Keep on running now the train is committed until the entire train has entered the tunnel.
            TrainManager.TrainEnteringOngoing(trainManagerEntry)
        end
        if trainManagerEntry ~= nil and trainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.underground then
            -- Run just while the underground train is the primary train part.
            TrainManager.TrainUndergroundOngoing(trainManagerEntry)
        end
        if trainManagerEntry ~= nil and trainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.leaving and trainManagerEntry.aboveTrainLeavingState == LeavingTrainStates.leaving then
            -- Keep on running until the entire train has left the tunnel.
            TrainManager.TrainLeavingOngoing(trainManagerEntry)
        end
        if trainManagerEntry ~= nil and trainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.leaving and trainManagerEntry.aboveTrainLeavingState == LeavingTrainStates.trainLeftTunnel then
            -- Keep on running until the entire train has left the tunnel's exit rail segment.
            TrainManager.TrainLeftTunnelOngoing(trainManagerEntry)
        end
    end
end

TrainManager.TrainApproachingInitial = function(trainEntering, surfaceEntrancePortalEndSignal)
    local trainManagerEntry = {
        id = global.trainManager.nextManagedTrainId,
        primaryTrainPartName = PrimaryTrainPartNames.entering,
        aboveTrainEnteringState = EnteringTrainStates.approaching,
        undergroundTrainState = UndergroundTrainStates.travelling,
        aboveTrainLeavingState = LeavingTrainStates.pre,
        aboveTrainEntering = trainEntering,
        aboveTrainEnteringId = trainEntering.id,
        surfaceEntrancePortalEndSignal = surfaceEntrancePortalEndSignal,
        surfaceEntrancePortal = surfaceEntrancePortalEndSignal.portal,
        tunnel = surfaceEntrancePortalEndSignal.portal.tunnel,
        trainTravelDirection = Utils.LoopDirectionValue(surfaceEntrancePortalEndSignal.entity.direction + 4)
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
    local firstCarriagePosition =
        TrainManagerFuncs.GetFutureCopiedTrainToUndergroundFirstWagonPosition(
        sourceTrain,
        trainManagerEntry.tunnel.alignmentOrientation,
        trainManagerEntry.undergroundTunnel.tunnelInstanceValue,
        trainManagerEntry.trainTravelOrientation,
        trainManagerEntry.tunnel.portals[1].entranceDistanceFromCenter,
        trainManagerEntry.surfaceEntrancePortalEndSignal.entity.get_connected_rails()[1].unit_number
    )
    local undergroundTrain, carriageIdToEntityList = TrainManagerFuncs.CopyTrain(sourceTrain, trainManagerEntry.undergroundTunnel.undergroundSurface.surface, trainManagerEntry.trainTravelOrientation, trainManagerEntry.aboveTrainEnteringForwards, trainManagerEntry.trainTravelDirection, firstCarriagePosition)
    trainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity = carriageIdToEntityList

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
end

TrainManager.TrainApproachingOngoing = function(trainManagerEntry)
    local aboveTrainEntering = trainManagerEntry.aboveTrainEntering

    -- Check whether the train is still approaching the tunnel portal as its not committed yet.
    if aboveTrainEntering.state ~= defines.train_state.arrive_signal or aboveTrainEntering.signal ~= trainManagerEntry.surfaceEntrancePortalEndSignal.entity then
        TrainManager.TerminateTunnelTrip(trainManagerEntry)
        return
    end

    TrainManager.SetAboveTrainEnteringSpeed(trainManagerEntry, TrainManagerFuncs.GetTrainSpeed(trainManagerEntry.aboveTrainLeaving, trainManagerEntry.undergroundTrain))
    -- trainManagerEntry.aboveTrainEnteringForwards has been updated for us by SetAboveTrainEnteringSpeed().
    local nextCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(aboveTrainEntering, trainManagerEntry.aboveTrainEnteringForwards)

    if Utils.GetDistanceSingleAxis(nextCarriage.position, trainManagerEntry.surfaceEntrancePortalEndSignal.entity.position, trainManagerEntry.tunnel.railAlignmentAxis) < 14 then
        trainManagerEntry.aboveTrainEnteringState = EnteringTrainStates.entering
        trainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.underground
        trainManagerEntry.dummyTrain = TrainManagerFuncs.CreateDummyTrain(trainManagerEntry.surfaceExitPortal.entity, aboveTrainEntering)
        -- Schedule has been transferred to dummy train.
        aboveTrainEntering.schedule = nil

        -- Check if this train is already using the tunnel to leave. Happens if the train doesn't fully leave the exit portal signal block before coming back in.
        if global.trainManager.trainLeftTunnelTrainIdToManagedTrain[aboveTrainEntering.id] ~= nil then
            -- Terminate the old tunnel usage that was delayed until this point.
            TrainManager.TerminateTunnelTrip(global.trainManager.trainLeftTunnelTrainIdToManagedTrain[aboveTrainEntering.id])
        end
    end
end

TrainManager.TrainEnteringOngoing = function(trainManagerEntry)
    local aboveTrainEntering = trainManagerEntry.aboveTrainEntering

    -- Force an entering train to stay in manual mode.
    aboveTrainEntering.manual_mode = true

    TrainManager.SetAboveTrainEnteringSpeed(trainManagerEntry, TrainManagerFuncs.GetTrainSpeed(trainManagerEntry.aboveTrainLeaving, trainManagerEntry.undergroundTrain))
    -- trainManagerEntry.aboveTrainEnteringForwards has been updated for us by SetAboveTrainEnteringSpeed().
    local nextCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(aboveTrainEntering, trainManagerEntry.aboveTrainEnteringForwards)

    if Utils.GetDistanceSingleAxis(nextCarriage.position, trainManagerEntry.surfaceEntrancePortalEndSignal.entity.position, trainManagerEntry.tunnel.railAlignmentAxis) < 14 then
        -- Handle any player in the train carriage.
        local driver = nextCarriage.get_driver()
        if driver ~= nil then
            PlayerContainers.PlayerInCarriageEnteringTunnel(trainManagerEntry, driver, nextCarriage)
        end

        nextCarriage.destroy()

        -- Update local variable as new train Id after removing carriage.
        if trainManagerEntry.aboveTrainEntering.valid then
            aboveTrainEntering = trainManagerEntry.aboveTrainEntering
        else
            aboveTrainEntering = nil
        end
    end

    if aboveTrainEntering == nil or (not aboveTrainEntering.valid) then
        -- Train has completed entering.
        trainManagerEntry.aboveTrainEnteringState = EnteringTrainStates.finished
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.aboveTrainEnteringId] = nil
        trainManagerEntry.aboveTrainEntering = nil
        trainManagerEntry.aboveTrainEnteringId = nil
        trainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity = nil
        Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", trainManagerEntry)
    end
end

TrainManager.TrainUndergroundOngoing = function(trainManagerEntry)
    PlayerContainers.MoveTrainsPlayerContainers(trainManagerEntry)

    -- Mirror above exit signal underground so primary train (underground) honours stopping points. Close the underground Exit signal if the aboveground Exit signal isn't open, otherwise open it.
    local exitPortalOutSignal = trainManagerEntry.surfaceExitPortal.entrySignals["out"]
    Interfaces.Call("Underground.SetUndergroundExitSignalState", exitPortalOutSignal.undergroundSignalPaired, exitPortalOutSignal.entity.signal_state)

    -- Check if the lead carriage is close enough to the exit portal's entry signal to be safely in the leaving tunnel area.
    local leadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(trainManagerEntry.undergroundTrain, trainManagerEntry.undergroundTrain.speed > 0)

    if Utils.GetDistanceSingleAxis(leadCarriage.position, trainManagerEntry.undergroundLeavingPortalEntrancePosition, trainManagerEntry.tunnel.railAlignmentAxis) <= 30 then
        -- Reset the underground Exit signal to open for the next train. As the underground train will now be path & speed controlled by the above train.
        Interfaces.Call("Underground.SetUndergroundExitSignalState", exitPortalOutSignal.undergroundSignalPaired, defines.signal_state.open)

        TrainManager.TrainLeavingInitial(trainManagerEntry)
    end
end

TrainManager.TrainLeavingInitial = function(trainManagerEntry)
    -- Cleanup dummy train to make room for the reemerging train, preserving schedule and target stop for later.
    local schedule, isManual, targetStop = trainManagerEntry.dummyTrain.schedule, trainManagerEntry.dummyTrain.manual_mode, trainManagerEntry.dummyTrain.path_end_stop
    TrainManagerFuncs.DestroyTrain(trainManagerEntry, "dummyTrain")

    local undergroundLeadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(trainManagerEntry.undergroundTrain, trainManagerEntry.undergroundTrain.speed > 0)
    local placementPosition = Utils.ApplyOffsetToPosition(undergroundLeadCarriage.position, trainManagerEntry.undergroundTunnel.surfaceOffsetFromUnderground)
    local placedCarriage = undergroundLeadCarriage.clone {position = placementPosition, surface = trainManagerEntry.aboveSurface, create_build_effect_smoke = false}
    placedCarriage.train.speed = undergroundLeadCarriage.speed -- Set the speed when its a train of 1. Before a pushing locomotive may be added and make working out speed direction harder.
    trainManagerEntry.aboveTrainLeavingCarriagesPlaced = 1

    -- Add a pushing loco if needed.
    if not TrainManagerFuncs.CarriageIsAPushingLoco(placedCarriage, trainManagerEntry.trainTravelOrientation) then
        trainManagerEntry.aboveTrainLeavingPushingLoco = TrainManagerFuncs.AddPushingLocoToEndOfTrain(placedCarriage, trainManagerEntry.trainTravelOrientation)
    end

    local aboveTrainLeaving = placedCarriage.train
    trainManagerEntry.aboveTrainLeaving, trainManagerEntry.aboveTrainLeavingId = aboveTrainLeaving, aboveTrainLeaving.id
    global.trainManager.leavingTrainIdToManagedTrain[aboveTrainLeaving.id] = trainManagerEntry

    -- Restore train schedule.
    TrainManagerFuncs.LeavingTrainSetSchedule(aboveTrainLeaving, schedule, isManual, targetStop, trainManagerEntry.surfaceExitPortal.entrySignals["out"].entity.get_connected_rails()[1])

    PlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage(undergroundLeadCarriage, placedCarriage)
    Interfaces.Call("Tunnel.TrainStartedExitingTunnel", trainManagerEntry)
    trainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.leaving
    trainManagerEntry.aboveTrainLeavingState = LeavingTrainStates.leaving
end

TrainManager.TrainLeavingOngoing = function(trainManagerEntry)
    local aboveTrainLeaving, sourceTrain = trainManagerEntry.aboveTrainLeaving, trainManagerEntry.undergroundTrain
    local desiredSpeed = TrainManagerFuncs.GetTrainSpeed(trainManagerEntry.aboveTrainLeaving, trainManagerEntry.undergroundTrain)

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
            if hadPushingLoco and (not TrainManagerFuncs.CarriageIsAPushingLoco(placedCarriage, trainManagerEntry.trainTravelOrientation)) then
                trainManagerEntry.aboveTrainLeavingPushingLoco = TrainManagerFuncs.AddPushingLocoToEndOfTrain(placedCarriage, trainManagerEntry.trainTravelOrientation)
            end

            -- LuaTrain has been replaced and updated by adding a wagon, so obtain a local reference to it again.
            aboveTrainLeaving = trainManagerEntry.aboveTrainLeaving

            -- Restore schedule and state.
            TrainManagerFuncs.LeavingTrainSetSchedule(aboveTrainLeaving, schedule, isManual, targetStop, trainManagerEntry.surfaceExitPortal.entrySignals["out"].entity.get_connected_rails()[1])

            PlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage(nextSourceCarriageEntity, placedCarriage)
        end

        PlayerContainers.MoveTrainsPlayerContainers(trainManagerEntry)
    end

    TrainManagerFuncs.SetTrainAbsoluteSpeed(aboveTrainLeaving, desiredSpeed)
    TrainManager.SetUndergroundTrainSpeed(trainManagerEntry, desiredSpeed)
end

TrainManager.TrainLeavingCompleted = function(trainManagerEntry, speed)
    TrainManagerFuncs.SetTrainAbsoluteSpeed(trainManagerEntry.aboveTrainLeaving, speed)
    TrainManagerFuncs.DestroyTrain(trainManagerEntry, "undergroundTrain")

    trainManagerEntry.aboveTrainLeft, trainManagerEntry.aboveTrainLeftId = trainManagerEntry.aboveTrainLeaving, trainManagerEntry.aboveTrainLeavingId
    global.trainManager.trainLeftTunnelTrainIdToManagedTrain[trainManagerEntry.aboveTrainLeftId] = trainManagerEntry
    trainManagerEntry.aboveTrainLeavingState = LeavingTrainStates.trainLeftTunnel

    global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.aboveTrainLeavingId] = nil
    trainManagerEntry.aboveTrainLeavingId = nil
    trainManagerEntry.aboveTrainLeaving = nil
end

TrainManager.TrainLeftTunnelOngoing = function(trainManagerEntry)
    -- Track the tunnel's exit portal entry rail signal so we can mark the tunnel as open for the next train when the current train has left.  We are assuming that no train gets in to the portal rail segment before our main train gets out. This is far more UPS effecient than checking the trains last carriage and seeing if its end rail signal is our portal entrance one.
    local exitPortalEntranceSignalEntity = trainManagerEntry.surfaceExitPortal.entrySignals["in"].entity
    if exitPortalEntranceSignalEntity.signal_state ~= defines.signal_state.closed then
        -- No train in the block so our one must have left.
        TrainManager.TerminateTunnelTrip(trainManagerEntry)
    end
end

TrainManager.TerminateTunnelTrip = function(trainManagerEntry)
    if trainManagerEntry.aboveTrainEntering then
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.aboveTrainEnteringId] = nil
    end
    if trainManagerEntry.aboveTrainLeaving then
        global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.aboveTrainLeavingId] = nil
    end
    if trainManagerEntry.aboveTrainLeft then
        global.trainManager.trainLeftTunnelTrainIdToManagedTrain[trainManagerEntry.aboveTrainLeftId] = nil
    end

    if trainManagerEntry.undergroundTrain then
        PlayerContainers.TerminateTunnelTrip(trainManagerEntry.undergroundTrain)
        TrainManagerFuncs.DestroyTrain(trainManagerEntry, "undergroundTrain")
    end

    Interfaces.Call("Tunnel.TrainReleasedTunnel", trainManagerEntry)
    global.trainManager.managedTrains[trainManagerEntry.id] = nil
end

TrainManager.TrainTracking_OnTrainCreated = function(event)
    if event.old_train_id_1 == nil then
        return
    end

    local TrainTrackingCheckListOfTrainIds = function(list, trainAttributeName, trainIdAttributeName)
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
                list = global.trainManager.trainLeftTunnelTrainIdToManagedTrain,
                trainAttributeName = "aboveTrainLeft",
                trainIdAttributeName = "aboveTrainLeftId"
            }
        }
    ) do
        TrainTrackingCheckListOfTrainIds(trainTracking.list, trainTracking.trainAttributeName, trainTracking.trainIdAttributeName)
    end
end

TrainManager.SetAboveTrainEnteringSpeed = function(trainManagerEntry, speed)
    local train = trainManagerEntry.aboveTrainEntering

    if train.speed > 0 then
        trainManagerEntry.aboveTrainEnteringForwards = true
        train.speed = speed
    elseif train.speed < 0 then
        trainManagerEntry.aboveTrainEnteringForwards = false
        train.speed = -1 * speed
    else
        -- Only update aboveTrainEnteringForwards if speed is <> 0. As the last entering train direction needs to be preserved in global data if the train stops while entering the tunnel.
        train.speed = 0
    end
end

TrainManager.SetUndergroundTrainSpeed = function(trainManagerEntry, speed)
    local train = trainManagerEntry.undergroundTrain

    if speed ~= 0 or not TrainManagerFuncs.IsSpeedGovernedByLeavingTrain(trainManagerEntry.aboveTrainLeaving) then
        if not train.manual_mode then
            TrainManagerFuncs.SetTrainAbsoluteSpeed(train, speed)
        else
            train.speed = speed
            train.manual_mode = false
            if train.speed == 0 then
                -- TODO: this looks like a hack to detect a mismatch on order and train speed. If so should be replaced by something stateful.
                train.speed = -1 * speed
            end
        end
    else
        -- Train needs to be switched to manual if it is supposed to stop (speed=0).
        train.manual_mode = true
        train.speed = 0
    end
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
                -- If the rail can't be destroyed then theres a train carriage on it.
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
            TrainManagerFuncs.DestroyTrain(managedTrain, "dummyTrain")

            PlayerContainers.TunnelRemoved(managedTrain.undergroundTrain)
            TrainManagerFuncs.DestroyTrain(managedTrain, "undergroundTrain")
            global.trainManager.managedTrains[managedTrain.id] = nil
        end
    end
end

return TrainManager
