local TrainManager = {}
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local TrainManagerFuncs = require("scripts/train-manager-functions") -- Stateless functions that don't directly use global objects.
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
    leavingFirstCarriage = "leavingFirstCarriage",
    leaving = "leaving",
    trainLeftTunnel = "trainLeftTunnel",
    finished = "finished"
}
local PrimaryTrainPartNames = {approaching = "approaching", underground = "underground", leaving = "leaving", finished = "finished"}

TrainManager.CreateGlobals = function()
    global.trainManager = global.trainManager or {}
    global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId or 1
    global.trainManager.managedTrains = global.trainManager.managedTrains or {}
    --[[
        [id] = {
            id = uniqiue id of this managed train passing through the tunnel.
            primaryTrainPartName = The primary real train part name (PrimaryTrainPartName) that dictates the trains primary monitored object. Finished is for when the tunnel trip is completed.

            enteringTrainState = The current entering train's state (EnteringTrainStates).
            enteringTrain = LuaTrain of the entering train on the world surface.
            enteringTrainId = The LuaTrain ID of the above Train Entering.
            enteringTrainFowards = boolean if the train is moving forwards or backwards from its viewpoint.

            undergroundTrainState = The current underground train's state (UndergroundTrainStates).
            undergroundTrain = LuaTrain of the train created in the underground surface.

            leavingTrainState = The current leaving train's state (LeavingTrainStates).
            leavingTrain = LuaTrain of the train created leaving the tunnel on the world surface.
            leavingTrainId = The LuaTrain ID of the above Train Leaving.
            leavingTrainCarriagesPlaced = count of how many carriages placed so far in the above train while its leaving.
            leavingTrainPushingLoco = Locomotive entity pushing the leaving train if it donesn't have a forwards facing locomotive yet, otherwise Nil.

            leftTrain = LuaTrain of the train thats left the tunnel.
            leftTrainId = The LuaTrain ID of the leftTrain.

            dummyTrain = LuaTrain of the dummy train used to keep the train stop reservation alive
            trainTravelDirection = defines.direction the train is heading in.
            trainTravelOrientation = the orientation of the trainTravelDirection.
            scheduleTarget = the target stop entity of this train, needed in case the path gets lost as we only have the station name then.

            aboveSurface = LuaSurface of the main world surface.
            aboveEntrancePortal = the portal global object of the entrance portal for this tunnel usage instance.
            aboveEntrancePortalEndSignal = the endSignal global object of the rail signal at the end of the entrance portal track (forced closed signal).
            aboveExitPortal = the portal global object of the exit portal for this tunnel usage instance.
            aboveExitPortalEndSignal = the endSignal global object of the rail signal at the end of the exit portal track (forced closed signal).
            tunnel = ref to the global tunnel object.
            undergroundTunnel = ref to the global tunnel's underground tunnel object.
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
    Interfaces.RegisterInterface("TrainManager.RegisterTrainApproaching", TrainManager.RegisterTrainApproaching)
    EventScheduler.RegisterScheduledEventType("TrainManager.ProcessManagedTrains", TrainManager.ProcessManagedTrains)
    Events.RegisterHandlerEvent(defines.events.on_train_created, "TrainManager.TrainTracking_OnTrainCreated", TrainManager.TrainTracking_OnTrainCreated)
    Interfaces.RegisterInterface("TrainManager.IsTunnelInUse", TrainManager.IsTunnelInUse)
    Interfaces.RegisterInterface("TrainManager.On_TunnelRemoved", TrainManager.On_TunnelRemoved)

    local tunnelUsageChangedEventId = Events.RegisterCustomEventName("RailwayTunnel.TunnelUsageChanged")
    remote.add_interface(
        "railway_tunnel",
        {
            get_tunnel_usage_changed_event_id = function()
                return tunnelUsageChangedEventId
            end,
            get_train_tunnel_usage_details = function(trainManagerEntryId)
                return TrainManager.GetTrainTunnelUsageRemote(trainManagerEntryId)
            end
        }
    )
end

TrainManager.OnStartup = function()
    -- Always run the ProcessManagedTrains check each tick regardless of if theres any registered trains yet. No real UPS impact.
    if not EventScheduler.IsEventScheduledEachTick("TrainManager.ProcessManagedTrains") then
        EventScheduler.ScheduleEventEachTick("TrainManager.ProcessManagedTrains")
    end
end

----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
--
--                                  State handling section
--
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------

TrainManager.RegisterTrainApproaching = function(enteringTrain, aboveEntrancePortalEndSignal)
    local trainManagerEntry = TrainManager.CreateTrainManagerEntryObject(enteringTrain, aboveEntrancePortalEndSignal)
    trainManagerEntry.primaryTrainPartName, trainManagerEntry.enteringTrainState, trainManagerEntry.undergroundTrainState, trainManagerEntry.leavingTrainState = PrimaryTrainPartNames.approaching, EnteringTrainStates.approaching, UndergroundTrainStates.travelling, LeavingTrainStates.pre
    TrainManager.CreateUndergroundTrainObject(trainManagerEntry)
    Interfaces.Call("Tunnel.TrainReservedTunnel", trainManagerEntry)
    TrainManager.TunnelUsageChangedRemote(trainManagerEntry.id, TrainManager.TunnelUsageAction.StartApproaching)

    -- Check if this train is already using the tunnel to leave. Happens if the train doesn't fully leave the exit portal signal block before coming back in.
    local trainLeftEntry = global.trainManager.trainLeftTunnelTrainIdToManagedTrain[trainManagerEntry.enteringTrain.id]
    if trainLeftEntry ~= nil then
        -- Terminate the old tunnel usage that was delayed until this point.
        -- TODO: should this be a tunnel reverse instead now for neatness ?
        TrainManager.TerminateTunnelTrip(trainLeftEntry, TrainManager.TunnelUsageChangeReason.ReversedAfterLeft)
    end
end

TrainManager.ProcessManagedTrains = function()
    for _, trainManagerEntry in pairs(global.trainManager.managedTrains) do
        -- Check dummy train state is valid if it exists. Used in a lot of states so sits outside of them.
        if trainManagerEntry.dummyTrain ~= nil and not TrainManagerFuncs.IsTrainHealthlyState(trainManagerEntry.dummyTrain) then
            TrainManager.HandleLeavingTrainBadState(trainManagerEntry, trainManagerEntry.dummyTrain)
            return
        end

        if trainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.approaching then
            -- Check whether the train is still approaching the tunnel portal as its not committed yet and so can turn away.
            if trainManagerEntry.enteringTrain.state ~= defines.train_state.arrive_signal or trainManagerEntry.enteringTrain.signal ~= trainManagerEntry.aboveEntrancePortalEndSignal.entity then
                TrainManager.TerminateTunnelTrip(trainManagerEntry, TrainManager.TunnelUsageChangeReason.AbortedApproach)
                return
            end

            -- Keep on running until the train is committed to entering the tunnel.
            TrainManager.TrainApproachingOngoing(trainManagerEntry)
        end

        if trainManagerEntry.enteringTrainState == EnteringTrainStates.entering then
            -- Keep on running until the entire train has entered the tunnel. Ignores primary state.
            TrainManager.TrainEnteringOngoing(trainManagerEntry)
        end

        if trainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.underground then
            -- Run just while the underground train is the primary train part. Detects when the train can start leaving.
            TrainManager.TrainUndergroundOngoing(trainManagerEntry)
        end

        if trainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.leaving then
            if trainManagerEntry.leavingTrainState == LeavingTrainStates.leavingFirstCarriage then
                -- Only runs for the first carriage and then changes to the ongoing for the remainder.
                TrainManager.TrainLeavingFirstCarriage(trainManagerEntry)
            elseif trainManagerEntry.leavingTrainState == LeavingTrainStates.leaving then
                -- Check if the leaving train is in a good state before we check to add any new wagons to it.
                if not TrainManagerFuncs.IsTrainHealthlyState(trainManagerEntry.leavingTrain) then
                    TrainManager.HandleLeavingTrainBadState(trainManagerEntry, trainManagerEntry.leavingTrain)
                else
                    -- Keep on running until the entire train has left the tunnel.
                    TrainManager.TrainLeavingOngoing(trainManagerEntry)
                end
            end
        end

        if trainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.leaving and trainManagerEntry.leavingTrainState == LeavingTrainStates.trainLeftTunnel then
            -- Keep on running until the entire train has left the tunnel's exit rail segment.
            TrainManager.TrainLeftTunnelOngoing(trainManagerEntry)
        end
    end
end

TrainManager.HandleLeavingTrainBadState = function(trainManagerEntry, trainWithBadState)
    -- TODO: if there's trainManagerEntry.leavingTrain.locomotives.back_movers > 0 then the leaving train tries to path backwards on its own. We need to detect/handle this. Not catered for currently. At this function call in this case they are now front_movers though.

    if #trainManagerEntry.undergroundTrain.locomotives.back_movers > 0 then
        local canPathBackwards, enteringTrain = false, trainManagerEntry.enteringTrain
        local schedule, isManual, targetStop = trainWithBadState.schedule, trainWithBadState.manual_mode, trainManagerEntry.scheduleTarget
        local oldEnteringSchedule, oldEnteringIsManual, oldEnteringSpeed
        if trainManagerEntry.enteringTrainState == EnteringTrainStates.entering then
            -- See if the entering train can path to where it wants to go. Has to be the remaining train and not a dummy train at the entrance portal as the entering train may be long and over running the track splitit needs for its backwards path.

            -- Capture these values before they are affected by pathing tests.
            oldEnteringSchedule, oldEnteringIsManual, oldEnteringSpeed = enteringTrain.schedule, enteringTrain.manual_mode, enteringTrain.speed

            -- Add a reverse loco to the entering train if needed to test the path.
            -- At this point the trainManageEntry object's data is from before the reversal; so we have to handle the remaining entering train and work out its new direction before seeing if we need to add temporary pathing loco.
            local enteringTrainReversePushingLoco, reverseLocoListName
            if enteringTrain.speed > 0 then
                reverseLocoListName = "back_movers"
            else
                reverseLocoListName = "front_movers"
            end
            if #enteringTrain.locomotives[reverseLocoListName] == 0 then
                --TODO: front/rear stock needs to be worked out. The orientation needs to be from the train and tunnel travel direction as there are unknwon carriage count with unknown direction each.
                enteringTrainReversePushingLoco = TrainManagerFuncs.AddPushingLocoToEndOfTrain(enteringTrain.front_stock, enteringTrain.front_stock.orientation + 0.5)
                enteringTrain = trainManagerEntry.enteringTrain -- Update as the reference will have been broken.
            end

            -- Set a path with the new train
            TrainManagerFuncs.TrainSetSchedule(enteringTrain, schedule, isManual, targetStop, true)
            if enteringTrain.has_path then
                canPathBackwards = true
            end

            -- Remove temp reversing loco if added.
            if enteringTrainReversePushingLoco ~= nil then
                enteringTrainReversePushingLoco.destroy()
                enteringTrain = trainManagerEntry.enteringTrain -- Update as the reference will have been broken.
            end
        else
            -- Handle trains that have fully entered the tunnel.
            local pathTestTrain = TrainManagerFuncs.CreateDummyTrain(trainManagerEntry.aboveEntrancePortal.entity, enteringTrain, true)
            TrainManagerFuncs.TrainSetSchedule(pathTestTrain, schedule, isManual, targetStop, true)
            if pathTestTrain.has_path then
                canPathBackwards = true
            end
            TrainManagerFuncs.DestroyTrain(nil, nil, pathTestTrain)
        end

        if canPathBackwards then
            TrainManager.ReverseManagedTrainTunnelTrip(trainManagerEntry)
            return
        else
            if trainManagerEntry.enteringTrainState == EnteringTrainStates.entering then
                -- Set the enteringTrain schedule, state and speed back to what it was before the repath attempt. This preserves the enteringTrain travel direction.
                TrainManagerFuncs.TrainSetSchedule(enteringTrain, oldEnteringSchedule, oldEnteringIsManual, targetStop, true)
                enteringTrain.speed = oldEnteringSpeed
            end
        end
    end

    -- Handle train that can't go backwards so just pull the train forwards to the end of the tunnel, nothing else can be done.
    TrainManagerFuncs.MoveLeavingTrainToFallbackPosition(trainWithBadState, trainManagerEntry.aboveExitPortal.entrySignals["out"].entity.get_connected_rails()[1])
end

TrainManager.TrainApproachingOngoing = function(trainManagerEntry)
    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry)
    local enteringTrain = trainManagerEntry.enteringTrain

    TrainManager.SetEnteringTrainSpeed(trainManagerEntry, math.abs(trainManagerEntry.undergroundTrain.speed))
    -- trainManagerEntry.enteringTrainFowards has been updated for us by SetEnteringTrainSpeed().
    local nextCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(enteringTrain, trainManagerEntry.enteringTrainFowards)

    if Utils.GetDistanceSingleAxis(nextCarriage.position, trainManagerEntry.aboveEntrancePortalEndSignal.entity.position, trainManagerEntry.tunnel.railAlignmentAxis) < 14 then
        -- Train is now committed to use the tunnel.
        trainManagerEntry.enteringTrainState = EnteringTrainStates.entering
        trainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.underground
        trainManagerEntry.dummyTrain = TrainManagerFuncs.CreateDummyTrain(trainManagerEntry.aboveExitPortal.entity, enteringTrain)
        trainManagerEntry.scheduleTarget = enteringTrain.path_end_stop
        -- Schedule has been transferred to dummy train.
        enteringTrain.schedule = nil
        TrainManager.TunnelUsageChangedRemote(trainManagerEntry.id, TrainManager.TunnelUsageAction.CommittedToTunnel)
    end
end

TrainManager.TrainEnteringOngoing = function(trainManagerEntry)
    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry)
    local enteringTrain = trainManagerEntry.enteringTrain

    -- Force an entering train to stay in manual mode.
    enteringTrain.manual_mode = true

    TrainManager.SetEnteringTrainSpeed(trainManagerEntry, math.abs(trainManagerEntry.undergroundTrain.speed))
    -- trainManagerEntry.enteringTrainFowards has been updated for us by SetEnteringTrainSpeed().
    local nextCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(enteringTrain, trainManagerEntry.enteringTrainFowards)

    if Utils.GetDistanceSingleAxis(nextCarriage.position, trainManagerEntry.aboveEntrancePortalEndSignal.entity.position, trainManagerEntry.tunnel.railAlignmentAxis) < 14 then
        -- Handle any player in the train carriage.
        local driver = nextCarriage.get_driver()
        if driver ~= nil then
            PlayerContainers.PlayerInCarriageEnteringTunnel(trainManagerEntry, driver, nextCarriage)
        end

        nextCarriage.destroy()
        -- Update local variable as new train number after removing carriage.
        enteringTrain = trainManagerEntry.enteringTrain

        TrainManager.TunnelUsageChangedRemote(trainManagerEntry.id, TrainManager.TunnelUsageAction.EnteringCarriageRemoved)
    end

    if not enteringTrain.valid then
        -- Train has completed entering.
        trainManagerEntry.enteringTrainState = EnteringTrainStates.finished
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.enteringTrainId] = nil
        trainManagerEntry.enteringTrain = nil
        trainManagerEntry.enteringTrainId = nil
        trainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity = nil
        Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", trainManagerEntry)
        TrainManager.TunnelUsageChangedRemote(trainManagerEntry.id, TrainManager.TunnelUsageAction.FullyEntered)
    end
end

TrainManager.TrainUndergroundOngoing = function(trainManagerEntry)
    PlayerContainers.MoveTrainsPlayerContainers(trainManagerEntry)
    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry)

    -- Check if the lead carriage is close enough to the exit portal's entry signal to be safely in the leaving tunnel area.
    local leadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(trainManagerEntry.undergroundTrain, trainManagerEntry.undergroundTrain.speed > 0)

    if Utils.GetDistanceSingleAxis(leadCarriage.position, trainManagerEntry.undergroundLeavingPortalEntrancePosition, trainManagerEntry.tunnel.railAlignmentAxis) <= 30 then
        trainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.leaving
        trainManagerEntry.leavingTrainState = LeavingTrainStates.leavingFirstCarriage
        TrainManager.TunnelUsageChangedRemote(trainManagerEntry.id, TrainManager.TunnelUsageAction.StartedLeaving)
    end
end

TrainManager.TrainLeavingFirstCarriage = function(trainManagerEntry)
    -- Cleanup dummy train to make room for the reemerging train, preserving schedule and target stop for later.
    local schedule, isManual, targetStop = trainManagerEntry.dummyTrain.schedule, trainManagerEntry.dummyTrain.manual_mode, trainManagerEntry.dummyTrain.path_end_stop
    TrainManagerFuncs.DestroyTrain(trainManagerEntry, "dummyTrain")

    -- Place initial leaving train carriage and set schedule and speed back.
    local placedCarriage, undergroundLeadCarriage = TrainManager.CreateFirstCarriageForLeavingTrain(trainManagerEntry)
    TrainManagerFuncs.TrainSetSchedule(trainManagerEntry.leavingTrain, schedule, isManual, targetStop)

    -- Follow up items post train creation.
    PlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage(undergroundLeadCarriage, placedCarriage)
    Interfaces.Call("Tunnel.TrainStartedExitingTunnel", trainManagerEntry)
    TrainManager.TunnelUsageChangedRemote(trainManagerEntry.id, TrainManager.TunnelUsageAction.LeavingCarriageAdded)
    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry)

    -- Check if all train wagons placed and train fully left the tunnel, otherwise set state for future carriages with the ongoing state.
    if trainManagerEntry.leavingTrainCarriagesPlaced == #trainManagerEntry.undergroundTrain.carriages then
        TrainManager.TrainLeavingCompleted(trainManagerEntry, nil)
    else
        trainManagerEntry.leavingTrainState = LeavingTrainStates.leaving
    end
end

TrainManager.TrainLeavingOngoing = function(trainManagerEntry)
    local desiredSpeed = math.abs(trainManagerEntry.undergroundTrain.speed)
    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry)

    -- Unless the underground and leaving train are both moving we never want to add a carriage.
    if desiredSpeed ~= 0 and trainManagerEntry.leavingTrain.speed ~= 0 then
        local leavingTrainRearCarriage = TrainManagerFuncs.GetRearCarriageOfLeavingTrain(trainManagerEntry.leavingTrain, trainManagerEntry.leavingTrainPushingLoco)

        if Utils.GetDistanceSingleAxis(leavingTrainRearCarriage.position, trainManagerEntry.aboveExitPortalEndSignal.entity.position, trainManagerEntry.tunnel.railAlignmentAxis) > 20 then
            -- Reattaching next carriage can clobber schedule and will set train to manual, so preserve state.
            local schedule, isManual, targetStop = trainManagerEntry.leavingTrain.schedule, trainManagerEntry.leavingTrain.manual_mode, trainManagerEntry.leavingTrain.path_end_stop

            -- Place new leaving train carriage and set schedule back.
            local nextSourceCarriageEntity = TrainManagerFuncs.GetCarriageToAddToLeavingTrain(trainManagerEntry.undergroundTrain, trainManagerEntry.leavingTrainCarriagesPlaced)
            local placedCarriage = TrainManager.AddCarraigeToLeavingTrain(trainManagerEntry, nextSourceCarriageEntity, leavingTrainRearCarriage)
            TrainManagerFuncs.TrainSetSchedule(trainManagerEntry.leavingTrain, schedule, isManual, targetStop)

            -- Follow up items post leaving train carriatge addition.
            PlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage(nextSourceCarriageEntity, placedCarriage)
            TrainManager.TunnelUsageChangedRemote(trainManagerEntry.id, TrainManager.TunnelUsageAction.LeavingCarriageAdded)

            -- Check if all train wagons placed and train fully left the tunnel.
            if trainManagerEntry.leavingTrainCarriagesPlaced == #trainManagerEntry.undergroundTrain.carriages then
                TrainManagerFuncs.SetTrainAbsoluteSpeed(trainManagerEntry.leavingTrain, desiredSpeed)
                TrainManager.TrainLeavingCompleted(trainManagerEntry)
                return
            end
        end

        -- Follow up items for the ontick, rather than related to a carriage being added.
        PlayerContainers.MoveTrainsPlayerContainers(trainManagerEntry)
    end

    TrainManagerFuncs.SetTrainAbsoluteSpeed(trainManagerEntry.leavingTrain, desiredSpeed)
end

TrainManager.TrainLeavingCompleted = function(trainManagerEntry)
    TrainManagerFuncs.DestroyTrain(trainManagerEntry, "undergroundTrain")

    trainManagerEntry.leftTrain, trainManagerEntry.leftTrainId = trainManagerEntry.leavingTrain, trainManagerEntry.leavingTrainId
    global.trainManager.trainLeftTunnelTrainIdToManagedTrain[trainManagerEntry.leftTrainId] = trainManagerEntry
    trainManagerEntry.leavingTrainState = LeavingTrainStates.trainLeftTunnel
    trainManagerEntry.undergroundTrainState = UndergroundTrainStates.finished

    global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.leavingTrainId] = nil
    trainManagerEntry.leavingTrainId = nil
    trainManagerEntry.leavingTrain = nil

    TrainManager.TunnelUsageChangedRemote(trainManagerEntry.id, TrainManager.TunnelUsageAction.FullyLeft)
end

TrainManager.TrainLeftTunnelOngoing = function(trainManagerEntry)
    -- Track the tunnel's exit portal entry rail signal so we can mark the tunnel as open for the next train when the current train has left. We are assuming that no train gets in to the portal rail segment before our main train gets out. This is far more UPS effecient than checking the trains last carriage and seeing if its end rail signal is our portal entrance one.
    local exitPortalEntranceSignalEntity = trainManagerEntry.aboveExitPortal.entrySignals["in"].entity
    if exitPortalEntranceSignalEntity.signal_state ~= defines.signal_state.closed then
        -- No train in the block so our one must have left.
        TrainManager.TerminateTunnelTrip(trainManagerEntry, TrainManager.TunnelUsageChangeReason.CompletedTunnelUsage)
    end
end

----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
--
--                                  Functions using global objects section
--
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------

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
                trainAttributeName = "enteringTrain",
                trainIdAttributeName = "enteringTrainId"
            },
            {
                list = global.trainManager.leavingTrainIdToManagedTrain,
                trainAttributeName = "leavingTrain",
                trainIdAttributeName = "leavingTrainId"
            },
            {
                list = global.trainManager.trainLeftTunnelTrainIdToManagedTrain,
                trainAttributeName = "leftTrain",
                trainIdAttributeName = "leftTrainId"
            }
        }
    ) do
        TrainTrackingCheckListOfTrainIds(trainTracking.list, trainTracking.trainAttributeName, trainTracking.trainIdAttributeName)
    end
end

TrainManager.SetEnteringTrainSpeed = function(trainManagerEntry, speed)
    local enteringTrain = trainManagerEntry.enteringTrain

    -- Only update enteringTrainFowards if speed ~= 0. As the last entering train direction needs to be preserved in global data if the train stops while entering the tunnel.
    if enteringTrain.speed > 0 then
        trainManagerEntry.enteringTrainFowards = true
        enteringTrain.speed = speed
    elseif enteringTrain.speed < 0 then
        trainManagerEntry.enteringTrainFowards = false
        enteringTrain.speed = -1 * speed
    else
        if trainManagerEntry.enteringTrainFowards then
            enteringTrain.speed = speed
        else
            enteringTrain.speed = -1 * speed
        end
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

TrainManager.On_TunnelRemoved = function(tunnelRemoved)
    for _, managedTrain in pairs(global.trainManager.managedTrains) do
        if managedTrain.tunnel.id == tunnelRemoved.id then
            if managedTrain.enteringTrainId ~= nil then
                global.trainManager.enteringTrainIdToManagedTrain[managedTrain.enteringTrainId] = nil
                managedTrain.enteringTrain.manual_mode = true
                managedTrain.enteringTrain.speed = 0
                if managedTrain.dummyTrain ~= nil then
                    managedTrain.enteringTrain.schedule = managedTrain.dummyTrain.schedule
                elseif managedTrain.leavingTrain ~= nil then
                    managedTrain.enteringTrain.schedule = managedTrain.leavingTrain.schedule
                end
            end
            if managedTrain.leavingTrainId ~= nil then
                global.trainManager.leavingTrainIdToManagedTrain[managedTrain.leavingTrainId] = nil
                managedTrain.leavingTrain.manual_mode = true
                managedTrain.leavingTrain.speed = 0
            end
            TrainManagerFuncs.DestroyTrain(managedTrain, "dummyTrain")

            PlayerContainers.On_TunnelRemoved(managedTrain.undergroundTrain)
            TrainManagerFuncs.DestroyTrain(managedTrain, "undergroundTrain")
            global.trainManager.managedTrains[managedTrain.id] = nil
        end
    end
end

TrainManager.CreateFirstCarriageForLeavingTrain = function(trainManagerEntry)
    local undergroundLeadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(trainManagerEntry.undergroundTrain, trainManagerEntry.undergroundTrain.speed > 0)
    local placementPosition = Utils.ApplyOffsetToPosition(undergroundLeadCarriage.position, trainManagerEntry.tunnel.undergroundTunnel.surfaceOffsetFromUnderground)
    local placedCarriage = undergroundLeadCarriage.clone {position = placementPosition, surface = trainManagerEntry.aboveSurface, create_build_effect_smoke = false}
    placedCarriage.train.speed = undergroundLeadCarriage.speed -- Set the speed when its a train of 1. Before a pushing locomotive may be added and make working out speed direction harder.
    trainManagerEntry.leavingTrainCarriagesPlaced = 1
    trainManagerEntry.leavingTrain, trainManagerEntry.leavingTrainId = placedCarriage.train, placedCarriage.train.id
    global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.leavingTrain.id] = trainManagerEntry

    -- Add a pushing loco if needed.
    if not TrainManagerFuncs.CarriageIsAPushingLoco(placedCarriage, trainManagerEntry.trainTravelOrientation) then
        trainManagerEntry.leavingTrainPushingLoco = TrainManagerFuncs.AddPushingLocoToEndOfTrain(placedCarriage, trainManagerEntry.trainTravelOrientation)
    end

    return placedCarriage, undergroundLeadCarriage
end

TrainManager.AddCarraigeToLeavingTrain = function(trainManagerEntry, nextSourceCarriageEntity, leavingTrainRearCarriage)
    -- Remove the pushing loco if present before the next carriage is placed.
    local hadPushingLoco = trainManagerEntry.leavingTrainPushingLoco ~= nil
    if trainManagerEntry.leavingTrainPushingLoco ~= nil then
        trainManagerEntry.leavingTrainPushingLoco.destroy()
        trainManagerEntry.leavingTrainPushingLoco = nil
    end

    local aboveTrainOldCarriageCount = #leavingTrainRearCarriage.train.carriages
    local nextCarriagePosition = Utils.ApplyOffsetToPosition(nextSourceCarriageEntity.position, trainManagerEntry.tunnel.undergroundTunnel.surfaceOffsetFromUnderground)
    local placedCarriage = nextSourceCarriageEntity.clone {position = nextCarriagePosition, surface = trainManagerEntry.aboveSurface, create_build_effect_smoke = false}
    if placedCarriage == nil then
        error("Can't placed carriage on end of leaving train.")
    end
    trainManagerEntry.leavingTrainCarriagesPlaced = trainManagerEntry.leavingTrainCarriagesPlaced + 1
    if #placedCarriage.train.carriages ~= aboveTrainOldCarriageCount + 1 then
        error("Placed carriage not part of leaving train as expected carriage count not right.")
    end

    -- If train had a pushing loco before and still needs one, add one back.
    if hadPushingLoco and (not TrainManagerFuncs.CarriageIsAPushingLoco(placedCarriage, trainManagerEntry.trainTravelOrientation)) then
        trainManagerEntry.leavingTrainPushingLoco = TrainManagerFuncs.AddPushingLocoToEndOfTrain(placedCarriage, trainManagerEntry.trainTravelOrientation)
    end

    return placedCarriage
end

TrainManager.CreateTrainManagerEntryObject = function(enteringTrain, aboveEntrancePortalEndSignal)
    local trainManagerEntry = {
        id = global.trainManager.nextManagedTrainId,
        enteringTrain = enteringTrain,
        enteringTrainId = enteringTrain.id,
        aboveEntrancePortalEndSignal = aboveEntrancePortalEndSignal,
        aboveEntrancePortal = aboveEntrancePortalEndSignal.portal,
        tunnel = aboveEntrancePortalEndSignal.portal.tunnel,
        trainTravelDirection = Utils.LoopDirectionValue(aboveEntrancePortalEndSignal.entity.direction + 4)
    }
    global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId + 1
    global.trainManager.managedTrains[trainManagerEntry.id] = trainManagerEntry
    trainManagerEntry.aboveSurface = trainManagerEntry.tunnel.aboveSurface
    if trainManagerEntry.enteringTrain.speed > 0 then
        trainManagerEntry.enteringTrainFowards = true
    else
        trainManagerEntry.enteringTrainFowards = false
    end
    trainManagerEntry.trainTravelOrientation = Utils.DirectionToOrientation(trainManagerEntry.trainTravelDirection)
    global.trainManager.enteringTrainIdToManagedTrain[enteringTrain.id] = trainManagerEntry

    -- Get the exit end signal on the other portal so we know when to bring the train back in.
    for _, portal in pairs(trainManagerEntry.tunnel.portals) do
        if portal.id ~= aboveEntrancePortalEndSignal.portal.id then
            trainManagerEntry.aboveExitPortalEndSignal = portal.endSignals["out"]
            trainManagerEntry.aboveExitPortal = portal
        end
    end

    return trainManagerEntry
end

TrainManager.CreateUndergroundTrainObject = function(trainManagerEntry)
    -- Copy the above train underground and set it running.
    local firstCarriagePosition =
        TrainManagerFuncs.GetFutureCopiedTrainToUndergroundFirstWagonPosition(
        trainManagerEntry.enteringTrain,
        trainManagerEntry.tunnel.alignmentOrientation,
        trainManagerEntry.tunnel.undergroundTunnel.tunnelInstanceValue,
        trainManagerEntry.trainTravelOrientation,
        trainManagerEntry.tunnel.portals[1].entranceDistanceFromCenter,
        trainManagerEntry.aboveEntrancePortalEndSignal.entity.get_connected_rails()[1].unit_number
    )
    trainManagerEntry.undergroundTrain, trainManagerEntry.carriageIdToEntityList = TrainManagerFuncs.CopyTrain(trainManagerEntry.enteringTrain, trainManagerEntry.tunnel.undergroundTunnel.undergroundSurface.surface, trainManagerEntry.trainTravelOrientation, trainManagerEntry.enteringTrainFowards, trainManagerEntry.trainTravelDirection, firstCarriagePosition)

    TrainManager.SetUndergroundTrainScheduleAndEndPosition(trainManagerEntry)
    trainManagerEntry.undergroundTrain.manual_mode = false
    trainManagerEntry.undergroundTrain.speed = trainManagerEntry.enteringTrain.speed
    if trainManagerEntry.undergroundTrain.speed == 0 then
        -- If setting the speed fails then set the reverse. Simple way to handle the underground train being an unknown "forwards".
        trainManagerEntry.undergroundTrain.speed = -1 * trainManagerEntry.enteringTrain.speed
    end
end

TrainManager.SetUndergroundTrainScheduleAndEndPosition = function(trainManagerEntry)
    local undergroundTrainEndScheduleTargetPos =
        Utils.ApplyOffsetToPosition(
        Utils.RotatePositionAround0(
            trainManagerEntry.tunnel.alignmentOrientation,
            {
                x = trainManagerEntry.tunnel.undergroundTunnel.tunnelInstanceValue + 1,
                y = 0
            }
        ),
        Utils.RotatePositionAround0(
            trainManagerEntry.trainTravelOrientation,
            {
                x = 0,
                y = 0 - (trainManagerEntry.tunnel.undergroundTunnel.undergroundLeadInTiles - 1)
            }
        )
    )
    trainManagerEntry.undergroundTrain.schedule = {
        current = 1,
        records = {
            {
                rail = trainManagerEntry.tunnel.undergroundTunnel.undergroundSurface.surface.find_entity("straight-rail", undergroundTrainEndScheduleTargetPos)
            }
        }
    }

    trainManagerEntry.undergroundLeavingPortalEntrancePosition = Utils.ApplyOffsetToPosition(trainManagerEntry.aboveExitPortal.portalEntrancePosition, trainManagerEntry.tunnel.undergroundTunnel.undergroundOffsetFromSurface)
end

TrainManager.TerminateTunnelTrip = function(trainManagerEntry, tunnelUsageChangeReason)
    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry, defines.signal_state.open) -- Reset the underground Exit signal state to open for the next train.
    if trainManagerEntry.undergroundTrain then
        PlayerContainers.On_TerminateTunnelTrip(trainManagerEntry.undergroundTrain)
        TrainManagerFuncs.DestroyTrain(trainManagerEntry, "undergroundTrain")
    end
    TrainManager.ReversingTunnelTripTidyOldManagedTrain(trainManagerEntry)
    Interfaces.Call("Tunnel.TrainReleasedTunnel", trainManagerEntry)
    TrainManager.TunnelUsageChangedRemote(trainManagerEntry.id, TrainManager.TunnelUsageAction.Terminated, tunnelUsageChangeReason)
end

TrainManager.ReversingTunnelTripTidyOldManagedTrain = function(trainManagerEntry)
    trainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.finished -- used by local object references to know the trip has been completed.

    if trainManagerEntry.enteringTrain then
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.enteringTrainId] = nil
    end
    if trainManagerEntry.leavingTrain then
        global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.leavingTrainId] = nil
    end
    if trainManagerEntry.leftTrain then
        global.trainManager.trainLeftTunnelTrainIdToManagedTrain[trainManagerEntry.leftTrainId] = nil
    end

    if trainManagerEntry.dummyTrain then
        TrainManagerFuncs.DestroyTrain(trainManagerEntry, "dummyTrain")
    end

    global.trainManager.managedTrains[trainManagerEntry.id] = nil
end

TrainManager.ReverseManagedTrainTunnelTrip = function(oldTrainManagerEntry)
    -- The managed train is going to reverse and go out of the tunnel the way it came in. Will be lodged as a new managed train so that old managed trains logic can be closed off.
    -- This function can't be reached if the train isn't committed, so no need to handle EnteringTrainStates.approaching.

    local newTrainManagerEntry = {
        id = global.trainManager.nextManagedTrainId
    }
    global.trainManager.managedTrains[newTrainManagerEntry.id] = newTrainManagerEntry
    global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId + 1

    newTrainManagerEntry.undergroundTrainState = oldTrainManagerEntry.undergroundTrainState
    newTrainManagerEntry.undergroundTrain = oldTrainManagerEntry.undergroundTrain

    --dummyTrain = LuaTrain of the dummy train used to keep the train stop reservation alive -- TODO: will need generating in some cases.
    newTrainManagerEntry.trainTravelDirection = Utils.LoopDirectionValue(oldTrainManagerEntry.trainTravelDirection + 4)
    newTrainManagerEntry.trainTravelOrientation = Utils.DirectionToOrientation(newTrainManagerEntry.trainTravelDirection)
    newTrainManagerEntry.scheduleTarget = oldTrainManagerEntry.scheduleTarget

    newTrainManagerEntry.aboveSurface = oldTrainManagerEntry.aboveSurface
    newTrainManagerEntry.aboveEntrancePortal = oldTrainManagerEntry.aboveExitPortal
    newTrainManagerEntry.aboveEntrancePortalEndSignal = oldTrainManagerEntry.aboveExitPortalEndSignal
    newTrainManagerEntry.aboveExitPortal = oldTrainManagerEntry.aboveEntrancePortal
    newTrainManagerEntry.aboveExitPortalEndSignal = oldTrainManagerEntry.aboveEntrancePortalEndSignal
    newTrainManagerEntry.tunnel = oldTrainManagerEntry.tunnel

    if oldTrainManagerEntry.leavingTrainState == LeavingTrainStates.leavingFirstCarriage or oldTrainManagerEntry.leavingTrainState == LeavingTrainStates.leaving then
        newTrainManagerEntry.enteringTrainState = EnteringTrainStates.entering
        newTrainManagerEntry.enteringTrain = oldTrainManagerEntry.leavingTrain
        newTrainManagerEntry.enteringTrainId = oldTrainManagerEntry.leavingTrainId
        newTrainManagerEntry.enteringTrainFowards = not oldTrainManagerEntry.enteringTrainFowards
    end

    --TODO: enteringTrain approaching may unlock the tunnel if reversed when it shouldn't, check exactly when its locked.
    if oldTrainManagerEntry.enteringTrainState == EnteringTrainStates.entering then
        newTrainManagerEntry.leavingTrainState = LeavingTrainStates.leaving
        newTrainManagerEntry.leavingTrain = oldTrainManagerEntry.enteringTrain
        newTrainManagerEntry.leavingTrainId = oldTrainManagerEntry.enteringTrainId
        newTrainManagerEntry.leavingTrainCarriagesPlaced = #newTrainManagerEntry.leavingTrain.carriages
        newTrainManagerEntry.leavingTrainPushingLoco = nil -- TODO: needs adding if required and recording. As we are jumping in to the leaving mid way through.
    end

    -- Don't need to handle any leftTrain as the terminate of old tunnel trip will tidy it up. We don't need to create a leaving train entry for the reversed train.

    if oldTrainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.approaching then
        newTrainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.leaving -- TODO: not sure on this or if the reversed train will be in the left state ?
    elseif oldTrainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.leaving then
        newTrainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.approaching
    elseif oldTrainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.underground then
        if newTrainManagerEntry.leavingTrainCarriagesPlaced > 0 then
            newTrainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.leaving
        else
            newTrainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.underground
        end
    else
        error("Unexpected reversed managed train primaryTrainPartName")
    end

    --[[
        --TODO: PlayerContainers globals needs handling in addition to the below list in the trainManagerEntry.
    enteringCarriageIdToUndergroundCarriageEntity = Table of the entering carriage unit number to the underground carriage entity for each carriage in the train. Currently used for tracking players riding in a train when it enters.
    ]]
    if newTrainManagerEntry.enteringTrain then
        global.trainManager.enteringTrainIdToManagedTrain[newTrainManagerEntry.enteringTrainId] = newTrainManagerEntry
    end
    if newTrainManagerEntry.leavingTrain then
        global.trainManager.leavingTrainIdToManagedTrain[newTrainManagerEntry.leavingTrainId] = newTrainManagerEntry
    end

    TrainManager.SetUndergroundTrainScheduleAndEndPosition(newTrainManagerEntry)
    newTrainManagerEntry.undergroundTrain.speed = 0
    TrainManager.ReversingTunnelTripTidyOldManagedTrain(oldTrainManagerEntry)

    TrainManager.TunnelUsageChangedRemote(newTrainManagerEntry.id, TrainManager.TunnelUsageAction.ReversedDuringUse, TrainManager.TunnelUsageChangeReason.ForwardPathLost, oldTrainManagerEntry.id)
end

TrainManager.UpdatePortalExitSignalPerTick = function(trainManagerEntry, forceSignalState)
    -- Mirror aboveground exit signal state to underground signal so primary train (underground) honours stopping points. Close the underground Exit signal if the aboveground Exit signal isn't open, otherwise open it.
    -- forceSignalState is optional and when set will be applied rather than the aboveground exit signal state.
    local exitPortalOutSignal = trainManagerEntry.aboveExitPortal.entrySignals["out"]
    local desiredSignalState
    if forceSignalState ~= nil then
        desiredSignalState = forceSignalState
    else
        desiredSignalState = exitPortalOutSignal.entity.signal_state
    end
    Interfaces.Call("Underground.SetUndergroundExitSignalState", exitPortalOutSignal.undergroundSignalPaired, desiredSignalState)
end

----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
--
--                                  REMOTE INTERFACES
--
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------

TrainManager.TunnelUsageAction = {
    StartApproaching = "StartApproaching",
    Terminated = "Terminated",
    ReversedDuringUse = "ReversedDuringUse",
    CommittedToTunnel = "CommittedToTunnel",
    EnteringCarriageRemoved = "EnteringCarriageRemoved",
    FullyEntered = "FullyEntered",
    StartedLeaving = "StartedLeaving",
    LeavingCarriageAdded = "LeavingCarriageAdded",
    FullyLeft = "FullyLeft"
}

TrainManager.TunnelUsageChangeReason = {
    ReversedAfterLeft = "ReversedAfterLeft",
    AbortedApproach = "AbortedApproach",
    ForwardPathLost = "ForwardPathLost",
    CompletedTunnelUsage = "CompletedTunnelUsage"
}

TrainManager.TunnelUsageChangedRemote = function(trainManagerEntryId, action, changeReason, replacedTrainTunnelUsageId)
    local data = TrainManager.GetTrainTunnelUsageRemote(trainManagerEntryId)
    data.name = "RailwayTunnel.TunnelUsageChanged"
    data.action = action
    data.changeReason = changeReason
    data.replacedTrainTunnelUsageId = replacedTrainTunnelUsageId
    Events.RaiseEvent(data)
end

TrainManager.GetTrainTunnelUsageRemote = function(trainManagerEntryId)
    local trainManagerEntry = global.trainManager.managedTrains[trainManagerEntryId]
    if trainManagerEntry == nil then
        return {
            trainTunnelUsageId = trainManagerEntryId,
            valid = false
        }
    else
        -- Only return valid LuaTrains as otherwise the events are dropped by Factorio.
        return {
            trainTunnelUsageId = trainManagerEntryId,
            valid = true,
            primaryState = trainManagerEntry.primaryTrainPartName,
            enteringTrain = Utils.ReturnValidLuaObjectOrNil(trainManagerEntry.enteringTrain),
            undergroundTrain = Utils.ReturnValidLuaObjectOrNil(trainManagerEntry.undergroundTrain),
            leavingTrain = Utils.ReturnValidLuaObjectOrNil(trainManagerEntry.leavingTrain),
            leftTrain = Utils.ReturnValidLuaObjectOrNil(trainManagerEntry.leftTrain)
        }
    end
end

return TrainManager
