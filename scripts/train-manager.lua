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
            enteringTrainForwards = boolean if the train is moving forwards or backwards from its viewpoint.

            undergroundTrainState = The current underground train's state (UndergroundTrainStates).
            undergroundTrain = LuaTrain of the train created in the underground surface.
            undergroundTrainSetsSpeed = If the underground train sets the overall speed or if the leading part does (Boolean).
            undergroundTrainForwards = boolean if the train is moving forwards or backwards from its viewpoint.

            leavingTrainState = The current leaving train's state (LeavingTrainStates).
            leavingTrain = LuaTrain of the train created leaving the tunnel on the world surface.
            leavingTrainId = The LuaTrain ID of the above Train Leaving.
            leavingTrainForwards = boolean if the train is moving forwards or backwards from its viewpoint.
            leavingTrainCarriagesPlaced = count of how many carriages placed so far in the above train while its leaving.
            leavingTrainPushingLoco = Locomotive entity pushing the leaving train if it donesn't have a forwards facing locomotive yet, otherwise Nil.
            leavingTrainStoppingSignal = the LuaSignal that the leaving train is currently stopping at beyond the portal, or nil.
            leavingTrainStoppingStation = the LuaStation that the leaving train is currently stopping at beyond the portal, or nil.

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
            aboveExitPortalEntrySignalOut = the endSignal global object on the rail signal at the entrance of the exit portal for leaving trains.
            tunnel = ref to the global tunnel object.
            undergroundTunnel = ref to the global tunnel's underground tunnel object.
            undergroundLeavingPortalEntrancePosition = The underground position equivilent to the portal entrance that the underground train is measured against to decide when it starts leaving.

            enteringCarriageIdToUndergroundCarriageEntity = Table of the entering carriage unit number to the underground carriage entity for each carriage in the train. Currently used for tracking players riding in a train when it enters.
        }
    ]]
    -- Used to track trainIds to managedTrainEntries. When the trainId is detected as changing via event the global object is updated to stay up to date.
    global.trainManager.enteringTrainIdToManagedTrain = global.trainManager.enteringTrainIdToManagedTrain or {}
    global.trainManager.dummyTrainIdToManagedTrain = global.trainManager.dummyTrainIdToManagedTrain or {}
    global.trainManager.leavingTrainIdToManagedTrain = global.trainManager.leavingTrainIdToManagedTrain or {}
    global.trainManager.trainLeftTunnelTrainIdToManagedTrain = global.trainManager.trainLeftTunnelTrainIdToManagedTrain or {}

    global.trainManager.eventsToRaise = global.trainManager.eventsToRaise or {} -- Events are raised at end of tick to avoid other mods interupting this mod's process and breaking things.
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
            get_tunnel_usage_entry = function(trainManagerEntryId)
                return TrainManager.Remote_GetTunnelUsageEntry(trainManagerEntryId)
            end,
            get_a_trains_tunnel_usage_entry = function(trainId)
                return TrainManager.Remote_GetATrainsTunnelUsageEntry(trainId)
            end,
            get_temporary_carriage_names = function()
                return TrainManager.Remote_GetTemporaryCarriageNames()
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

    -- Check if this train is already using the tunnel to leave. Happens if the train doesn't fully leave the exit portal signal block before coming back in.
    local trainLeftEntry = global.trainManager.trainLeftTunnelTrainIdToManagedTrain[trainManagerEntry.enteringTrain.id]
    if trainLeftEntry ~= nil then
        -- Terminate the old tunnel usage that was delayed until this point. Don't try to reverse the tunnel usage as this event has naturally happened and the old tunnel usage was effectively over anyways.
        TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.StartApproaching, nil, trainLeftEntry.id)
        TrainManager.TerminateTunnelTrip(trainLeftEntry, TrainManager.TunnelUsageChangeReason.ReversedAfterLeft)
    else
        TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.StartApproaching)
    end
end

TrainManager.ProcessManagedTrains = function()
    for _, trainManagerEntry in pairs(global.trainManager.managedTrains) do
        local skipThisTick = false -- Used to provide a "continue" ability as some actions could leave the trains in a weird state this tick and thus error on later functions in the process.

        -- Check dummy train state is valid if it exists. Used in a lot of states so sits outside of them.
        if not skipThisTick and trainManagerEntry.dummyTrain ~= nil and not TrainManagerFuncs.IsTrainHealthlyState(trainManagerEntry.dummyTrain) then
            TrainManager.HandleLeavingTrainBadState(trainManagerEntry, trainManagerEntry.dummyTrain)
            skipThisTick = true
        end

        if not skipThisTick and trainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.approaching then
            -- Check whether the train is still approaching the tunnel portal as its not committed yet and so can turn away.
            if trainManagerEntry.enteringTrain.state ~= defines.train_state.arrive_signal or trainManagerEntry.enteringTrain.signal ~= trainManagerEntry.aboveEntrancePortalEndSignal.entity then
                TrainManager.TerminateTunnelTrip(trainManagerEntry, TrainManager.TunnelUsageChangeReason.AbortedApproach)
                skipThisTick = true
            else
                -- Keep on running until the train is committed to entering the tunnel.
                TrainManager.TrainApproachingOngoing(trainManagerEntry)
            end
        end

        if not skipThisTick and trainManagerEntry.enteringTrainState == EnteringTrainStates.entering then
            -- Keep on running until the entire train has entered the tunnel. Ignores primary state.
            TrainManager.TrainEnteringOngoing(trainManagerEntry)
        end

        if not skipThisTick and trainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.underground then
            -- Run just while the underground train is the primary train part. Detects when the train can start leaving.
            TrainManager.TrainUndergroundOngoing(trainManagerEntry)
        end

        if not skipThisTick and trainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.leaving then
            if trainManagerEntry.leavingTrainState == LeavingTrainStates.leavingFirstCarriage then
                -- Only runs for the first carriage and then changes to the ongoing for the remainder.
                TrainManager.TrainLeavingFirstCarriage(trainManagerEntry)
            elseif trainManagerEntry.leavingTrainState == LeavingTrainStates.leaving then
                -- Check if the leaving train is in a good state before we check to add any new wagons to it.
                if not TrainManagerFuncs.IsTrainHealthlyState(trainManagerEntry.leavingTrain) then
                    TrainManager.HandleLeavingTrainBadState(trainManagerEntry, trainManagerEntry.leavingTrain)
                    skipThisTick = true
                else
                    -- Keep on running until the entire train has left the tunnel.
                    TrainManager.TrainLeavingOngoing(trainManagerEntry)
                end
            end
        end

        if not skipThisTick and trainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.leaving and trainManagerEntry.leavingTrainState == LeavingTrainStates.trainLeftTunnel then
            -- Keep on running until the entire train has left the tunnel's exit rail segment.
            TrainManager.TrainLeftTunnelOngoing(trainManagerEntry)
        end
    end

    -- Raise any events from this tick for external listener mods to react to.
    for _, eventData in pairs(global.trainManager.eventsToRaise) do
        eventData = Utils.TableMerge({eventData, TrainManager.Remote_GetTunnelUsageEntryObjectAttributes(eventData.tunnelUsageId)})
        -- Populate the leavingTrain attribute with the leftTrain value when the leavingTrain value isn't valid. Makes handling the events nicer by hiding this internal code oddity.
        if (eventData.leavingTrain == nil or not eventData.leavingTrain.valid) and (eventData.leftTrain ~= nil and eventData.leftTrain.valid) then
            eventData.leavingTrain = eventData.leftTrain
            eventData.leftTrain = nil
        end
        Events.RaiseEvent(eventData)
    end
    global.trainManager.eventsToRaise = {}
end

TrainManager.HandleLeavingTrainBadState = function(trainManagerEntry, trainWithBadState)
    -- Check if the full train can reverse in concept.
    local undergroundTrainReverseLocoListName
    if trainManagerEntry.undergroundTrain.speed > 0 then
        undergroundTrainReverseLocoListName = "back_movers"
    elseif trainManagerEntry.undergroundTrain.speed < 0 then
        undergroundTrainReverseLocoListName = "front_movers"
    else
        error("TrainManager.HandleLeavingTrainBadState() doesn't support 0 speed underground train")
    end
    if #trainManagerEntry.undergroundTrain.locomotives[undergroundTrainReverseLocoListName] > 0 then
        local canPathBackwards, enteringTrain = false, trainManagerEntry.enteringTrain
        local schedule, isManual, targetStop = trainWithBadState.schedule, trainWithBadState.manual_mode, trainManagerEntry.scheduleTarget
        local oldEnteringSchedule, oldEnteringIsManual, oldEnteringSpeed
        if trainManagerEntry.enteringTrainState == EnteringTrainStates.entering then
            -- See if the entering train can path to where it wants to go. Has to be the remaining train and not a dummy train at the entrance portal as the entering train may be long and over running the track splitit needs for its backwards path.

            -- Capture these values before they are affected by pathing tests.
            oldEnteringSchedule, oldEnteringIsManual, oldEnteringSpeed = enteringTrain.schedule, enteringTrain.manual_mode, enteringTrain.speed

            -- Add a reverse loco to the entering train if needed to test the path.
            -- At this point the trainManageEntry object's data is from before the reversal; so we have to handle the remaining entering train and work out its new direction before seeing if we need to add temporary pathing loco.
            local enteringTrainReversePushingLoco, reverseLocoListName, enteringTrainRearCarriage
            if enteringTrain.speed > 0 then
                reverseLocoListName = "back_movers"
                enteringTrainRearCarriage = enteringTrain.back_stock
            elseif enteringTrain.speed < 0 then
                reverseLocoListName = "front_movers"
                enteringTrainRearCarriage = enteringTrain.front_stock
            else
                error("TrainManager.HandleLeavingTrainBadState() doesn't support 0 speed entering train")
            end
            if #enteringTrain.locomotives[reverseLocoListName] == 0 then
                enteringTrainReversePushingLoco = TrainManagerFuncs.AddPushingLocoToAfterCarriage(enteringTrainRearCarriage, Utils.BoundFloatValueWithinRange(enteringTrain.front_stock.orientation + 0.5, 0, 1))
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
            local pathTestTrain = TrainManagerFuncs.CreateDummyTrain(trainManagerEntry.aboveEntrancePortal.entity, enteringTrain, true, nil)
            TrainManagerFuncs.TrainSetSchedule(pathTestTrain, schedule, isManual, targetStop, true)
            if pathTestTrain.has_path then
                canPathBackwards = true
            end
            TrainManagerFuncs.DestroyTrainsCarriages(pathTestTrain)
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
    TrainManagerFuncs.MoveLeavingTrainToFallbackPosition(trainWithBadState, trainManagerEntry.aboveExitPortalEntrySignalOut.entity.get_connected_rails()[1])
end

TrainManager.TrainApproachingOngoing = function(trainManagerEntry)
    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry)
    local enteringTrain = trainManagerEntry.enteringTrain

    TrainManager.SetAbsoluteTrainSpeed(trainManagerEntry, "enteringTrain", math.abs(trainManagerEntry.undergroundTrain.speed))
    -- trainManagerEntry.enteringTrainForwards has been updated for us by SetAbsoluteTrainSpeed().
    local nextCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(enteringTrain, trainManagerEntry.enteringTrainForwards)

    if Utils.GetDistanceSingleAxis(nextCarriage.position, trainManagerEntry.aboveEntrancePortalEndSignal.entity.position, trainManagerEntry.tunnel.railAlignmentAxis) < 14 then
        -- Train is now committed to use the tunnel so prepare for the entering loop.
        trainManagerEntry.enteringTrainState = EnteringTrainStates.entering
        trainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.underground
        trainManagerEntry.dummyTrain = TrainManagerFuncs.CreateDummyTrain(trainManagerEntry.aboveExitPortal.entity, enteringTrain, false, nil)
        global.trainManager.dummyTrainIdToManagedTrain[trainManagerEntry.dummyTrain.id] = trainManagerEntry
        trainManagerEntry.scheduleTarget = enteringTrain.path_end_stop
        -- Schedule has been transferred to dummy train.
        enteringTrain.schedule = nil
    -- The same tick the first carriage will be removed by TrainManager.TrainEnteringOngoing() and this will fire an event.
    end
end

TrainManager.TrainEnteringOngoing = function(trainManagerEntry)
    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry)
    local enteringTrain = trainManagerEntry.enteringTrain

    -- Force an entering train to stay in manual mode.
    enteringTrain.manual_mode = true

    TrainManager.SetAbsoluteTrainSpeed(trainManagerEntry, "enteringTrain", math.abs(trainManagerEntry.undergroundTrain.speed))
    -- trainManagerEntry.enteringTrainForwards has been updated for us by SetAbsoluteTrainSpeed().
    local nextCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(enteringTrain, trainManagerEntry.enteringTrainForwards)

    if Utils.GetDistanceSingleAxis(nextCarriage.position, trainManagerEntry.aboveEntrancePortalEndSignal.entity.position, trainManagerEntry.tunnel.railAlignmentAxis) < 14 then
        -- Handle any player in the train carriage.
        local driver = nextCarriage.get_driver()
        if driver ~= nil then
            PlayerContainers.PlayerInCarriageEnteringTunnel(trainManagerEntry, driver, nextCarriage)
        end

        nextCarriage.destroy()
        -- Update local variable as new train number after removing carriage.
        enteringTrain = trainManagerEntry.enteringTrain

        TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.EnteringCarriageRemoved)
    end

    if not enteringTrain.valid then
        -- Train has completed entering.
        trainManagerEntry.enteringTrainState = EnteringTrainStates.finished
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.enteringTrainId] = nil
        trainManagerEntry.enteringTrain = nil
        trainManagerEntry.enteringTrainId = nil
        trainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity = nil
        Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", trainManagerEntry)
        TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.FullyEntered)
    end
end

TrainManager.TrainUndergroundOngoing = function(trainManagerEntry)
    PlayerContainers.MoveTrainsPlayerContainers(trainManagerEntry)
    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry)

    -- Check if the lead carriage is close enough to the exit portal's entry signal to be safely in the leaving tunnel area.
    local leadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(trainManagerEntry.undergroundTrain, trainManagerEntry.undergroundTrainForwards)
    if Utils.GetDistanceSingleAxis(leadCarriage.position, trainManagerEntry.undergroundLeavingPortalEntrancePosition, trainManagerEntry.tunnel.railAlignmentAxis) <= 30 then
        trainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.leaving
        trainManagerEntry.leavingTrainState = LeavingTrainStates.leavingFirstCarriage
    end
end

TrainManager.TrainLeavingFirstCarriage = function(trainManagerEntry)
    -- Cleanup dummy train to make room for the reemerging train, preserving schedule and target stop for later.
    local schedule, isManual, targetStop = trainManagerEntry.dummyTrain.schedule, trainManagerEntry.dummyTrain.manual_mode, trainManagerEntry.dummyTrain.path_end_stop
    TrainManager.DestroyDummyTrain(trainManagerEntry)

    -- Place initial leaving train carriage and set schedule and speed back.
    local placedCarriage, undergroundLeadCarriage = TrainManager.CreateFirstCarriageForLeavingTrain(trainManagerEntry)
    TrainManagerFuncs.TrainSetSchedule(trainManagerEntry.leavingTrain, schedule, isManual, targetStop)

    -- Follow up items post train creation.
    PlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage(undergroundLeadCarriage, placedCarriage)
    Interfaces.Call("Tunnel.TrainStartedExitingTunnel", trainManagerEntry)
    TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.StartedLeaving)
    TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.LeavingCarriageAdded)
    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry)
    trainManagerEntry.undergroundTrainSetsSpeed = true

    -- Check if all train wagons placed and train fully left the tunnel, otherwise set state for future carriages with the ongoing state.
    if trainManagerEntry.leavingTrainCarriagesPlaced == #trainManagerEntry.undergroundTrain.carriages then
        TrainManager.TrainLeavingCompleted(trainManagerEntry, nil)
    else
        trainManagerEntry.leavingTrainState = LeavingTrainStates.leaving
    end
end

TrainManager.TrainLeavingOngoing = function(trainManagerEntry)
    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry)

    -- Handle if the train is stopping at a signal or station. Updates trainManagerEntry.undergroundTrainSetsSpeed and the underground train path if required.
    TrainManager.HandleLeavingTrainStoppingAtSignalStation(trainManagerEntry, "signal")
    TrainManager.HandleLeavingTrainStoppingAtSignalStation(trainManagerEntry, "station")

    -- Get the desired speed for this tick.
    local desiredSpeed
    if trainManagerEntry.undergroundTrainSetsSpeed then
        desiredSpeed = math.abs(trainManagerEntry.undergroundTrain.speed)
    else
        desiredSpeed = math.abs(trainManagerEntry.leavingTrain.speed)
    end

    -- Check if the leaving train has stopped, but the underground train is moving. This should only occur when the leaving train has lost its path and naturally is pathing back through the tunnel. As otherwise the state check would have caught it already this tick.
    if desiredSpeed ~= 0 and trainManagerEntry.leavingTrain.speed == 0 then
        -- Theres nothing broken with the state, but the mod doesn't expect it so we need to correct this.
        local scheduleBackup, isManualBackup, targetStopBackup = trainManagerEntry.leavingTrain.schedule, trainManagerEntry.leavingTrain.manual_mode, trainManagerEntry.leavingTrain.path_end_stop

        -- Carefully set the speed and track the results to confirm the situation.
        trainManagerEntry.leavingTrain.manual_mode = true
        TrainManager.SetAbsoluteTrainSpeed(trainManagerEntry, "leavingTrain", desiredSpeed)
        TrainManagerFuncs.TrainSetSchedule(trainManagerEntry.leavingTrain, scheduleBackup, isManualBackup, targetStopBackup)
        -- If the speed is undone (0) by setting to automatic then the entering train is moving opposite to the underground train (desiredSpeed). So handle the reversal and stop processing. If the speed isn't lost then this is the more normal usage case and so can just be left as is. We just double set the speed this 1 tick, no harm done.
        if trainManagerEntry.leavingTrain.speed == 0 then
            TrainManager.ReverseManagedTrainTunnelTrip(trainManagerEntry)
            return
        end
    end
    -- Unless the underground and leaving train are both moving we never want to add a carriage.
    if desiredSpeed ~= 0 and trainManagerEntry.leavingTrain.speed ~= 0 then
        local leavingTrainRearCarriage = TrainManagerFuncs.GetRearCarriageOfLeavingTrain(trainManagerEntry.leavingTrain, trainManagerEntry.leavingTrainPushingLoco)

        if Utils.GetDistanceSingleAxis(leavingTrainRearCarriage.position, trainManagerEntry.aboveExitPortalEndSignal.entity.position, trainManagerEntry.tunnel.railAlignmentAxis) > 20 then
            -- Reattaching next carriage can clobber speed, schedule and will set train to manual, so preserve state.
            local scheduleBeforeCarriageAttachment, isManualBeforeCarriageAttachment, targetStopBeforeCarriageAttachment, leavingAbsoluteSpeedBeforeCarriageAttachment = trainManagerEntry.leavingTrain.schedule, trainManagerEntry.leavingTrain.manual_mode, trainManagerEntry.leavingTrain.path_end_stop, math.abs(trainManagerEntry.leavingTrain.speed)

            -- Place new leaving train carriage and set schedule back.
            local nextSourceCarriageEntity = TrainManagerFuncs.GetCarriageToAddToLeavingTrain(trainManagerEntry.undergroundTrain, trainManagerEntry.leavingTrainCarriagesPlaced)
            local placedCarriage = TrainManager.AddCarriageToLeavingTrain(trainManagerEntry, nextSourceCarriageEntity, leavingTrainRearCarriage)
            TrainManagerFuncs.TrainSetSchedule(trainManagerEntry.leavingTrain, scheduleBeforeCarriageAttachment, isManualBeforeCarriageAttachment, targetStopBeforeCarriageAttachment)

            -- Follow up items post leaving train carriatge addition.
            PlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage(nextSourceCarriageEntity, placedCarriage)
            TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.LeavingCarriageAdded)

            -- Set the trains speed back to what it was before we added the carriage. This will update the global facing forwards state and correct any speed loss when the carriage was added (base Factorio behavour).
            TrainManager.SetAbsoluteTrainSpeed(trainManagerEntry, "leavingTrain", leavingAbsoluteSpeedBeforeCarriageAttachment)

            -- Check if all train wagons placed and train fully left the tunnel.
            if trainManagerEntry.leavingTrainCarriagesPlaced == #trainManagerEntry.undergroundTrain.carriages then
                TrainManager.SetAbsoluteTrainSpeed(trainManagerEntry, "leavingTrain", desiredSpeed)
                TrainManager.TrainLeavingCompleted(trainManagerEntry)
                return
            end
        end

        -- Follow up items for the ontick, rather than related to a carriage being added.
        PlayerContainers.MoveTrainsPlayerContainers(trainManagerEntry)
    end

    -- Update which ever train isn't setting the desired speed.
    if trainManagerEntry.undergroundTrainSetsSpeed then
        TrainManager.SetAbsoluteTrainSpeed(trainManagerEntry, "leavingTrain", desiredSpeed)
    else
        TrainManager.SetAbsoluteTrainSpeed(trainManagerEntry, "undergroundTrain", desiredSpeed)
    end
end

TrainManager.HandleLeavingTrainStoppingAtSignalStation = function(trainManagerEntry, arriveAtName)
    -- Handles a train leaving a tunnel arriving at a station/signal based on input. Updated global state data that impacts TrainManager.TrainLeavingOngoing(): trainManagerEntry.undergroundTrainSetsSpeed and underground train path target. Is a black box to calling functions otherwise.

    local trainStoppingEntityAttributeName, stoppingTargetEntityAttributeName, arriveAtReleventStoppingTarget
    if arriveAtName == "signal" then
        trainStoppingEntityAttributeName = "signal"
        stoppingTargetEntityAttributeName = "leavingTrainStoppingSignal"
        arriveAtReleventStoppingTarget = trainManagerEntry.leavingTrain.state == defines.train_state.arrive_signal and trainManagerEntry.leavingTrain[trainStoppingEntityAttributeName].unit_number ~= trainManagerEntry.aboveExitPortalEntrySignalOut.entity.unit_number
    elseif arriveAtName == "station" then
        trainStoppingEntityAttributeName = "path_end_stop"
        stoppingTargetEntityAttributeName = "leavingTrainStoppingStation"
        arriveAtReleventStoppingTarget = trainManagerEntry.leavingTrain.state == defines.train_state.arrive_station
    else
        error("TrainManager.HandleLeavingTrainStoppingAtSignalStation() unsuported arriveAtName: " .. arriveAtName)
    end

    -- 1: If leaving train is now arriving at a relvent stopping target. Relevent target is either any station or a signal other than the entrance out signal on the current exit portal. If relevent then check state in detail as we may need to update the underground train stop point.
    -- 2: Once the leaving train is stopped at a relevent stopping target, clear out stopping target arriving state.
    -- 3: Otherwise check for moving away states and if there was a preivous stopping state to be finished.
    if arriveAtReleventStoppingTarget then
        -- If a known stopping target was set, make sure it still exists.
        if trainManagerEntry[stoppingTargetEntityAttributeName] ~= nil and not trainManagerEntry[stoppingTargetEntityAttributeName].valid then
            trainManagerEntry[stoppingTargetEntityAttributeName] = nil
            trainManagerEntry.undergroundTrainSetsSpeed = true
        end

        -- Check the stopping target is the expected one, if not reset state to detect new stopping target.
        if trainManagerEntry[stoppingTargetEntityAttributeName] ~= nil and trainManagerEntry.leavingTrain[trainStoppingEntityAttributeName].unit_number ~= trainManagerEntry[stoppingTargetEntityAttributeName].unit_number then
            trainManagerEntry[stoppingTargetEntityAttributeName] = nil
            trainManagerEntry.undergroundTrainSetsSpeed = true
        end

        -- 1: If there's no expected stopping target then record state and update leaving and underground trains activities.
        -- 2: Otherwise its the same stopping target as previously, so if the underground train is setting the speed need to check distance from stopping target and hand over control to leaving train if close.
        if trainManagerEntry[stoppingTargetEntityAttributeName] == nil then
            -- The above ground and underground trains will never be exactly relational to one another as they change speed each tick differently before they are re-aligned. So the underground train should be targetted as an offset from its current location and when the above train is very near the stopping target the above train can take over setting speed to manage the final pulling up.
            trainManagerEntry[stoppingTargetEntityAttributeName] = trainManagerEntry.leavingTrain[trainStoppingEntityAttributeName]
            local exactDistanceFromTrainToTarget = TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTargetsRail(trainManagerEntry.leavingTrain, trainManagerEntry.leavingTrain[trainStoppingEntityAttributeName], trainManagerEntry.leavingTrainForwards) - 1 -- The -1 is to avoid any slight over reaching on to the next rail. Better to be short than long.
            local undergroundTrainTargetPosition = TrainManagerFuncs.GetForwardPositionFromCurrentForDistance(trainManagerEntry.undergroundTrain, exactDistanceFromTrainToTarget)
            TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition(trainManagerEntry.undergroundTrain, undergroundTrainTargetPosition)
            trainManagerEntry.undergroundTrainSetsSpeed = true
        elseif trainManagerEntry.undergroundTrainSetsSpeed then
            -- Is the same stopping target as last tick, so check if the leaving train is close to the stopping target and give it speed control if so.
            local leadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(trainManagerEntry.leavingTrain, trainManagerEntry.leavingTrainForwards)
            local leadCarriageDistanceFromStoppingEntity = Utils.GetDistance(leadCarriage.position, trainManagerEntry[stoppingTargetEntityAttributeName].position)
            local leavingTrainCloseToStoppingEntityDistance = TrainManagerFuncs.GetCarriagePlacementDistance(leadCarriage.name) + 4 -- This is the length of the leading carriage plus 4 tiles leaway so the speed handover isn't too abrupt. May be a bit abrupt if leaving train is lacking loco's to carriages though, compared to full underground train.
            if leadCarriageDistanceFromStoppingEntity < leavingTrainCloseToStoppingEntityDistance then
                trainManagerEntry.undergroundTrainSetsSpeed = false
            end
        end
    elseif trainManagerEntry[stoppingTargetEntityAttributeName] ~= nil and trainManagerEntry.leavingTrain.state == defines.train_state.on_the_path then
        -- If the train was stopped/stopping at a stopping target and now is back on the path, return to underground train setting speed and assume everything is back to normal.
        trainManagerEntry[stoppingTargetEntityAttributeName] = nil
        trainManagerEntry.undergroundTrainSetsSpeed = true
        local undergroundTrainEndScheduleTargetPos = Interfaces.Call("Underground.GetForwardsEndOfRailPosition", trainManagerEntry.tunnel.undergroundTunnel, trainManagerEntry.trainTravelOrientation)
        TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition(trainManagerEntry.undergroundTrain, undergroundTrainEndScheduleTargetPos)
    end
end

TrainManager.TrainLeavingCompleted = function(trainManagerEntry)
    TrainManager.DestroyUndergroundTrain(trainManagerEntry)

    trainManagerEntry.leftTrain, trainManagerEntry.leftTrainId = trainManagerEntry.leavingTrain, trainManagerEntry.leavingTrainId
    global.trainManager.trainLeftTunnelTrainIdToManagedTrain[trainManagerEntry.leftTrainId] = trainManagerEntry
    trainManagerEntry.leavingTrainState = LeavingTrainStates.trainLeftTunnel
    trainManagerEntry.undergroundTrainState = UndergroundTrainStates.finished

    global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.leavingTrainId] = nil
    trainManagerEntry.leavingTrainId = nil
    trainManagerEntry.leavingTrain = nil

    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry, defines.signal_state.open) -- Reset the underground Exit signal state to open for the next train.

    TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.FullyLeft)
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

TrainManager.DestroyDummyTrain = function(trainManagerEntry)
    if trainManagerEntry.dummyTrain ~= nil then
        global.trainManager.dummyTrainIdToManagedTrain[trainManagerEntry.dummyTrain.id] = nil
        TrainManagerFuncs.DestroyTrainsCarriages(trainManagerEntry.dummyTrain)
        trainManagerEntry.dummyTrain = nil
    end
end

TrainManager.DestroyUndergroundTrain = function(trainManagerEntry)
    if trainManagerEntry.undergroundTrain ~= nil then
        TrainManagerFuncs.DestroyTrainsCarriages(trainManagerEntry.undergroundTrain)
        trainManagerEntry.undergroundTrain = nil
    end
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

TrainManager.SetAbsoluteTrainSpeed = function(trainManagerEntry, trainAttributeName, speed)
    local train = trainManagerEntry[trainAttributeName]

    -- Only update train's global forwards if speed ~= 0. As the last train direction needs to be preserved in global data for if the train stops while using the tunnel.
    if train.speed > 0 then
        trainManagerEntry[trainAttributeName .. "Forwards"] = true
        train.speed = speed
    elseif train.speed < 0 then
        trainManagerEntry[trainAttributeName .. "Forwards"] = false
        train.speed = -1 * speed
    else
        if trainManagerEntry[trainAttributeName .. "Forwards"] == true then
            train.speed = speed
        elseif trainManagerEntry[trainAttributeName .. "Forwards"] == false then
            train.speed = -1 * speed
        else
            error("TrainManager.SetAbsoluteTrainSpeed() for '" .. trainAttributeName .. "' doesn't support train with current 0 speed and no 'Forwards' cached value.")
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
            TrainManager.DestroyDummyTrain(managedTrain)

            PlayerContainers.On_TunnelRemoved(managedTrain.undergroundTrain)
            TrainManager.DestroyUndergroundTrain(managedTrain)
            global.trainManager.managedTrains[managedTrain.id] = nil
        end
    end
end

TrainManager.CreateFirstCarriageForLeavingTrain = function(trainManagerEntry)
    local undergroundLeadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(trainManagerEntry.undergroundTrain, trainManagerEntry.undergroundTrainForwards)
    local placementPosition = Utils.ApplyOffsetToPosition(undergroundLeadCarriage.position, trainManagerEntry.tunnel.undergroundTunnel.surfaceOffsetFromUnderground)
    local placedCarriage = undergroundLeadCarriage.clone {position = placementPosition, surface = trainManagerEntry.aboveSurface, create_build_effect_smoke = false}
    placedCarriage.train.speed = undergroundLeadCarriage.speed -- Set the speed when its a train of 1. Before a pushing locomotive may be added and make working out speed direction harder.
    trainManagerEntry.leavingTrainCarriagesPlaced = 1
    trainManagerEntry.leavingTrain, trainManagerEntry.leavingTrainId = placedCarriage.train, placedCarriage.train.id
    global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.leavingTrain.id] = trainManagerEntry

    -- Add a pushing loco if needed.
    if not TrainManagerFuncs.CarriageIsAForwardsLoco(placedCarriage, trainManagerEntry.trainTravelOrientation) then
        trainManagerEntry.leavingTrainPushingLoco = TrainManagerFuncs.AddPushingLocoToAfterCarriage(placedCarriage, trainManagerEntry.trainTravelOrientation)
    end

    if trainManagerEntry.leavingTrain.speed > 0 then
        trainManagerEntry.leavingTrainForwards = true
    elseif trainManagerEntry.leavingTrain.speed < 0 then
        trainManagerEntry.leavingTrainForwards = true
    else
        error("TrainManager.CreateFirstCarriageForLeavingTrain() doesn't support 0 speed leaving train")
    end

    return placedCarriage, undergroundLeadCarriage
end

TrainManager.AddCarriageToLeavingTrain = function(trainManagerEntry, nextSourceCarriageEntity, leavingTrainRearCarriage)
    -- Remove the pushing loco if present before the next carriage is placed.
    local hadPushingLoco = trainManagerEntry.leavingTrainPushingLoco ~= nil
    if trainManagerEntry.leavingTrainPushingLoco ~= nil then
        trainManagerEntry.leavingTrainPushingLoco.destroy()
        trainManagerEntry.leavingTrainPushingLoco = nil
    end

    local aboveTrainOldCarriageCount = #leavingTrainRearCarriage.train.carriages
    local nextCarriagePosition = TrainManagerFuncs.GetNextCarriagePlacementPosition(trainManagerEntry.trainTravelOrientation, leavingTrainRearCarriage, nextSourceCarriageEntity.name)
    local placedCarriage = nextSourceCarriageEntity.clone {position = nextCarriagePosition, surface = trainManagerEntry.aboveSurface, create_build_effect_smoke = false}
    if placedCarriage == nil then
        error("Failed placing carriage at rear of leaving train.")
    end
    trainManagerEntry.leavingTrainCarriagesPlaced = trainManagerEntry.leavingTrainCarriagesPlaced + 1
    if #placedCarriage.train.carriages ~= aboveTrainOldCarriageCount + 1 then
        error("Placed carriage not part of leaving train as expected carriage count not right.")
    end

    -- If train had a pushing loco before and still needs one, add one back.
    if hadPushingLoco and (not TrainManagerFuncs.CarriageIsAForwardsLoco(placedCarriage, trainManagerEntry.trainTravelOrientation)) then
        trainManagerEntry.leavingTrainPushingLoco = TrainManagerFuncs.AddPushingLocoToAfterCarriage(placedCarriage, trainManagerEntry.trainTravelOrientation)
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
        trainManagerEntry.enteringTrainForwards = true
    elseif trainManagerEntry.enteringTrain.speed < 0 then
        trainManagerEntry.enteringTrainForwards = false
    else
        error("TrainManager.CreateTrainManagerEntryObject() doesn't support 0 speed")
    end
    trainManagerEntry.trainTravelOrientation = Utils.DirectionToOrientation(trainManagerEntry.trainTravelDirection)
    global.trainManager.enteringTrainIdToManagedTrain[enteringTrain.id] = trainManagerEntry

    -- Get the exit end signal on the other portal so we know when to bring the train back in.
    for _, portal in pairs(trainManagerEntry.tunnel.portals) do
        if portal.id ~= aboveEntrancePortalEndSignal.portal.id then
            trainManagerEntry.aboveExitPortalEndSignal = portal.endSignals["out"]
            trainManagerEntry.aboveExitPortal = portal
            trainManagerEntry.aboveExitPortalEntrySignalOut = portal.entrySignals["out"]
        end
    end

    return trainManagerEntry
end

TrainManager.CreateUndergroundTrainObject = function(trainManagerEntry)
    -- Copy the above train underground and set it running.
    -- The above ground and underground trains will never be exactly relational to one another, but should be within half a tile correctly aligned.
    local firstCarriagePosition = TrainManager.GetUndergroundFirstWagonPosition(trainManagerEntry)
    TrainManager.CopyEnteringTrainUnderground(trainManagerEntry, firstCarriagePosition)

    local undergroundTrainEndScheduleTargetPos = Interfaces.Call("Underground.GetForwardsEndOfRailPosition", trainManagerEntry.tunnel.undergroundTunnel, trainManagerEntry.trainTravelOrientation)
    TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition(trainManagerEntry.undergroundTrain, undergroundTrainEndScheduleTargetPos)

    -- Set speed and cached 'Forwards' value manually so future use of TrainManager.SetAbsoluteTrainSpeed() works.
    trainManagerEntry.undergroundTrain.speed = trainManagerEntry.enteringTrain.speed
    if trainManagerEntry.undergroundTrain.speed > 0 then
        trainManagerEntry.undergroundTrainForwards = true
    elseif trainManagerEntry.undergroundTrain.speed < 0 then
        trainManagerEntry.undergroundTrainForwards = false
    else
        error("TrainManager.CreateUndergroundTrainObject() doesn't support 0 speed enteringTrain.")
    end
    trainManagerEntry.undergroundTrain.manual_mode = false
    if trainManagerEntry.undergroundTrain.speed == 0 then
        -- If the speed is undone (0) by setting to automatic then the underground train is moving opposite to the entering train. Simple way to handle the underground train being an unknown "forwards".
        trainManagerEntry.undergroundTrainForwards = not trainManagerEntry.undergroundTrainForwards
        trainManagerEntry.undergroundTrain.speed = -1 * trainManagerEntry.enteringTrain.speed
    end

    trainManagerEntry.undergroundLeavingPortalEntrancePosition = Utils.ApplyOffsetToPosition(trainManagerEntry.aboveExitPortal.portalEntrancePosition, trainManagerEntry.tunnel.undergroundTunnel.undergroundOffsetFromSurface)
end

TrainManager.GetUndergroundFirstWagonPosition = function(trainManagerEntry)
    -- Work out the distance in rail tracks between the train and the portal's end signal's rail. This accounts for curves/U-bends and gives us a straight line distance as an output.
    local firstCarriageDistanceFromPortalEndSignalsRail = TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTargetsRail(trainManagerEntry.enteringTrain, trainManagerEntry.aboveEntrancePortalEndSignal.entity, trainManagerEntry.enteringTrainForwards)

    -- Apply the straight line distance to the above portal's end signal's rail. Account for the distance being from rail edge, rather than rail center (but rail is always straight in portal so easy).
    local firstCarriageOffsetFromEndSignalsRail = Utils.RotatePositionAround0(trainManagerEntry.trainTravelOrientation, {x = 0, y = firstCarriageDistanceFromPortalEndSignalsRail})
    local signalsRailEdgePosition = Utils.ApplyOffsetToPosition(trainManagerEntry.aboveEntrancePortalEndSignal.entity.get_connected_rails()[1].position, Utils.RotatePositionAround0(trainManagerEntry.trainTravelOrientation, {x = 0, y = 1})) -- Theres only ever 1 rail connected to the signal as its in the portal. + 1 for the difference in signals rail edge and its center position.
    local firstCarriageAbovegroundPosition = Utils.ApplyOffsetToPosition(signalsRailEdgePosition, firstCarriageOffsetFromEndSignalsRail)

    -- Get the underground position for this above ground spot.
    local firstCarriageUndergroundPosition = Utils.ApplyOffsetToPosition(firstCarriageAbovegroundPosition, trainManagerEntry.tunnel.undergroundTunnel.undergroundOffsetFromSurface)
    return firstCarriageUndergroundPosition
end

TrainManager.CopyEnteringTrainUnderground = function(trainManagerEntry, firstCarriagePosition)
    local nextCarriagePosition, refTrain, targetSurface = firstCarriagePosition, trainManagerEntry.enteringTrain, trainManagerEntry.tunnel.undergroundTunnel.undergroundSurface.surface
    local trainCarriagesForwardDirection = trainManagerEntry.trainTravelDirection
    if not trainManagerEntry.enteringTrainForwards then
        trainCarriagesForwardDirection = Utils.LoopDirectionValue(trainCarriagesForwardDirection + 4)
    end

    local minCarriageIndex, maxCarriageIndex, carriageIterator
    if (refTrain.speed > 0) then
        minCarriageIndex, maxCarriageIndex, carriageIterator = 1, #refTrain.carriages, 1
    elseif (refTrain.speed < 0) then
        minCarriageIndex, maxCarriageIndex, carriageIterator = #refTrain.carriages, 1, -1
    else
        error("TrainManager.CopyEnteringTrainUnderground() doesn't support 0 speed refTrain")
    end
    trainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity = {}
    local placedCarriage
    for currentSourceTrainCarriageIndex = minCarriageIndex, maxCarriageIndex, carriageIterator do
        local refCarriage = refTrain.carriages[currentSourceTrainCarriageIndex]
        local carriageDirection = trainCarriagesForwardDirection
        if refCarriage.speed ~= refTrain.speed then
            carriageDirection = Utils.LoopDirectionValue(carriageDirection + 4)
        end

        local refCarriageGoingForwards
        if refCarriage.speed > 0 then
            refCarriageGoingForwards = true
        elseif refCarriage.speed < 0 then
            refCarriageGoingForwards = false
        else
            error("TrainManager.CopyEnteringTrainUnderground() doesn't support 0 speed refCarriage")
        end

        if currentSourceTrainCarriageIndex ~= minCarriageIndex then
            -- The first carriage in the train doesn't need incrementing.
            nextCarriagePosition = TrainManagerFuncs.GetNextCarriagePlacementPosition(trainManagerEntry.trainTravelOrientation, placedCarriage, refCarriage.name)
        end

        placedCarriage = TrainManagerFuncs.CopyCarriage(targetSurface, refCarriage, nextCarriagePosition, carriageDirection, refCarriageGoingForwards)
        trainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity[refCarriage.unit_number] = placedCarriage
    end

    trainManagerEntry.undergroundTrain = placedCarriage.train
end

TrainManager.TerminateTunnelTrip = function(trainManagerEntry, tunnelUsageChangeReason)
    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry, defines.signal_state.open) -- Reset the underground Exit signal state to open for the next train.
    if trainManagerEntry.undergroundTrain then
        PlayerContainers.On_TerminateTunnelTrip(trainManagerEntry.undergroundTrain)
        TrainManager.DestroyUndergroundTrain(trainManagerEntry)
    end
    TrainManager.TidyManagedTrainGlobals(trainManagerEntry)

    -- Set all states to finished so that the TrainManager.ProcessManagedTrains() loop won't execute anything further this tick.
    trainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.finished
    trainManagerEntry.enteringTrainState = EnteringTrainStates.finished
    trainManagerEntry.undergroundTrainState = UndergroundTrainStates.finished
    trainManagerEntry.leavingTrainState = LeavingTrainStates.finished

    Interfaces.Call("Tunnel.TrainReleasedTunnel", trainManagerEntry)
    TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.Terminated, tunnelUsageChangeReason)
end

TrainManager.TidyManagedTrainGlobals = function(trainManagerEntry)
    -- Only remove the global if it points to this trainManagerEntry. The reversal process will have overwritten this already, so much be careful.
    if trainManagerEntry.enteringTrain and global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.enteringTrainId].id == trainManagerEntry.id then
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.enteringTrainId] = nil
    end
    if trainManagerEntry.leavingTrain and global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.leavingTrainId].id == trainManagerEntry.id then
        global.trainManager.leavingTrainIdToManagedTrain[trainManagerEntry.leavingTrainId] = nil
    end
    if trainManagerEntry.leftTrain and global.trainManager.trainLeftTunnelTrainIdToManagedTrain[trainManagerEntry.leftTrainId].id == trainManagerEntry.id then
        global.trainManager.trainLeftTunnelTrainIdToManagedTrain[trainManagerEntry.leftTrainId] = nil
    end

    if trainManagerEntry.dummyTrain then
        TrainManager.DestroyDummyTrain(trainManagerEntry)
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
    newTrainManagerEntry.undergroundTrainSetsSpeed = true -- Intentionally reset this value.
    newTrainManagerEntry.undergroundTrainForwards = not oldTrainManagerEntry.undergroundTrainForwards

    newTrainManagerEntry.trainTravelDirection = Utils.LoopDirectionValue(oldTrainManagerEntry.trainTravelDirection + 4)
    newTrainManagerEntry.trainTravelOrientation = Utils.DirectionToOrientation(newTrainManagerEntry.trainTravelDirection)
    newTrainManagerEntry.scheduleTarget = oldTrainManagerEntry.scheduleTarget

    newTrainManagerEntry.aboveSurface = oldTrainManagerEntry.aboveSurface
    newTrainManagerEntry.aboveEntrancePortal = oldTrainManagerEntry.aboveExitPortal
    newTrainManagerEntry.aboveEntrancePortalEndSignal = oldTrainManagerEntry.aboveExitPortalEndSignal
    newTrainManagerEntry.aboveExitPortal = oldTrainManagerEntry.aboveEntrancePortal
    newTrainManagerEntry.aboveExitPortalEndSignal = oldTrainManagerEntry.aboveEntrancePortalEndSignal
    newTrainManagerEntry.aboveExitPortalEntrySignalOut = oldTrainManagerEntry.aboveEntrancePortal.entrySignals["out"]
    newTrainManagerEntry.tunnel = oldTrainManagerEntry.tunnel
    newTrainManagerEntry.undergroundTunnel = oldTrainManagerEntry.undergroundTunnel
    newTrainManagerEntry.undergroundLeavingPortalEntrancePosition = Utils.ApplyOffsetToPosition(newTrainManagerEntry.aboveExitPortal.portalEntrancePosition, newTrainManagerEntry.tunnel.undergroundTunnel.undergroundOffsetFromSurface)

    -- Release the tunnel from the old train manager and set it to be claimed by new train before anything state related is applied on top.
    Interfaces.Call("Tunnel.TrainReleasedTunnel", oldTrainManagerEntry)
    Interfaces.Call("Tunnel.TrainReservedTunnel", newTrainManagerEntry)

    -- Handle new entering train now all pre-req data set up.
    if oldTrainManagerEntry.leavingTrainState == LeavingTrainStates.leavingFirstCarriage or oldTrainManagerEntry.leavingTrainState == LeavingTrainStates.leaving then
        newTrainManagerEntry.enteringTrainState = EnteringTrainStates.entering
        newTrainManagerEntry.enteringTrain = oldTrainManagerEntry.leavingTrain
        newTrainManagerEntry.enteringTrainId = oldTrainManagerEntry.leavingTrainId
        global.trainManager.enteringTrainIdToManagedTrain[newTrainManagerEntry.enteringTrainId] = newTrainManagerEntry

        -- If pushing loco's are removed they may corrupt out cached Forwards state. So check if this has happened. It will corrupt the train schedule so back this up first incase we need to re-apply it.
        local scheduleBackup, isManualBackup, targetStopBackup = newTrainManagerEntry.enteringTrain.schedule, newTrainManagerEntry.enteringTrain.manual_mode, newTrainManagerEntry.enteringTrain.path_end_stop
        local aPushingLocoWasRemoved = TrainManagerFuncs.RemoveAnyPushingLocosFromTrain(newTrainManagerEntry.enteringTrain)
        newTrainManagerEntry.enteringTrainForwards = not oldTrainManagerEntry.leavingTrainForwards
        if aPushingLocoWasRemoved then
            -- Pushing loco was removed so need to do tests to confirm if forwards was just reversed.
            -- Carefully set the speed and track the results to confirm the situation.
            newTrainManagerEntry.enteringTrain.manual_mode = true
            TrainManager.SetAbsoluteTrainSpeed(newTrainManagerEntry, "enteringTrain", 1)
            TrainManagerFuncs.TrainSetSchedule(newTrainManagerEntry.enteringTrain, scheduleBackup, isManualBackup, targetStopBackup)
            if newTrainManagerEntry.enteringTrain.speed == 0 then
                newTrainManagerEntry.enteringTrainForwards = not newTrainManagerEntry.enteringTrainForwards
            end
            TrainManager.SetAbsoluteTrainSpeed(newTrainManagerEntry, "enteringTrain", 0)
        end
    else
        newTrainManagerEntry.enteringTrainState = EnteringTrainStates.finished
        Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", newTrainManagerEntry)
    end

    --TODO: enteringTrain approaching may unlock the tunnel if reversed when it shouldn't. As we don't handle this state currently check exactly when the tunnel is locked and if we need to convert this to a trainLeft scenario?
    -- Handle new leaving train now all pre-req data set up.
    if oldTrainManagerEntry.enteringTrainState == EnteringTrainStates.entering then
        newTrainManagerEntry.leavingTrainState = LeavingTrainStates.leaving
        newTrainManagerEntry.leavingTrain = oldTrainManagerEntry.enteringTrain
        newTrainManagerEntry.leavingTrainId = oldTrainManagerEntry.enteringTrainId
        newTrainManagerEntry.leavingTrainForwards = not oldTrainManagerEntry.enteringTrainForwards
        newTrainManagerEntry.leavingTrainCarriagesPlaced = #newTrainManagerEntry.leavingTrain.carriages
        global.trainManager.leavingTrainIdToManagedTrain[newTrainManagerEntry.leavingTrainId] = newTrainManagerEntry
        if not TrainManagerFuncs.DoesTrainHaveAForwardsLoco(newTrainManagerEntry.leavingTrain, newTrainManagerEntry.trainTravelOrientation) then
            local rearCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(newTrainManagerEntry.leavingTrain, not newTrainManagerEntry.leavingTrainForwards)
            newTrainManagerEntry.leavingTrainPushingLoco = TrainManagerFuncs.AddPushingLocoToAfterCarriage(rearCarriage, newTrainManagerEntry.trainTravelOrientation)
        -- TODO: this might have reversed the leaving trains forwards. See if we ever hit an error around it or add a sepcific test to confirm if badness has happened.
        end
        newTrainManagerEntry.leavingTrainStoppingSignal = nil -- Intentionally reset this value.
        newTrainManagerEntry.leavingTrainStoppingStation = nil -- Intentionally reset this value.
        Interfaces.Call("Tunnel.TrainStartedExitingTunnel", newTrainManagerEntry)

        -- If the old dummy train had the schedule then apply it to the new leaving train. If the old entering train had the schedule then the new leaving train already has it.
        if oldTrainManagerEntry.dummyTrain ~= nil then
            TrainManagerFuncs.TrainSetSchedule(newTrainManagerEntry.leavingTrain, oldTrainManagerEntry.dummyTrain.schedule, false, newTrainManagerEntry.scheduleTarget, false)
        end
    elseif oldTrainManagerEntry.enteringTrainState == EnteringTrainStates.finished then
        newTrainManagerEntry.leavingTrainState = LeavingTrainStates.pre
        local scheduleSourceTrain
        if oldTrainManagerEntry.leavingTrain ~= nil then
            scheduleSourceTrain = oldTrainManagerEntry.leavingTrain
        elseif oldTrainManagerEntry.dummyTrain ~= nil then
            scheduleSourceTrain = oldTrainManagerEntry.dummyTrain
        else
            error("no schedule source train for train reversal")
        end
        newTrainManagerEntry.dummyTrain = TrainManagerFuncs.CreateDummyTrain(newTrainManagerEntry.aboveExitPortal.entity, scheduleSourceTrain, false, newTrainManagerEntry.scheduleTarget)
        global.trainManager.dummyTrainIdToManagedTrain[newTrainManagerEntry.dummyTrain.id] = newTrainManagerEntry
    end

    -- Don't need to handle any leftTrain as the termination of old tunnel trip will tidy it up. We don't need to create a leaving train entry for the reversed train.
    newTrainManagerEntry.leftTrain = nil
    newTrainManagerEntry.leftTrainId = nil
    -- global.trainManager.trainLeftTunnelTrainIdToManagedTrain -- TODO: left train should be handled - work through all combinations, above comment may be wrong.

    if oldTrainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.approaching then
        newTrainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.leaving -- TODO: not sure on this or if the reversed train will be in the left state ?
        error("alert if state reached")
    elseif oldTrainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.leaving then
        newTrainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.underground
    elseif oldTrainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.underground then
        if newTrainManagerEntry.leavingTrainCarriagesPlaced == nil then
            newTrainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.underground
        else
            newTrainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.leaving
        end
    else
        error("Unexpected reversed managed train primaryTrainPartName")
    end

    --[[
        --TODO: PlayerContainers globals needs handling in addition to the below list in the trainManagerEntry.
    enteringCarriageIdToUndergroundCarriageEntity = Table of the entering carriage unit number to the underground carriage entity for each carriage in the train. Currently used for tracking players riding in a train when it enters.
    ]]
    -- Update underground trains path and speed. Variable state done previously.
    local undergroundTrainEndScheduleTargetPos = Interfaces.Call("Underground.GetForwardsEndOfRailPosition", newTrainManagerEntry.tunnel.undergroundTunnel, newTrainManagerEntry.trainTravelOrientation)
    TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition(newTrainManagerEntry.undergroundTrain, undergroundTrainEndScheduleTargetPos)
    TrainManager.SetAbsoluteTrainSpeed(newTrainManagerEntry, "undergroundTrain", 0)

    TrainManager.Remote_TunnelUsageChanged(newTrainManagerEntry.id, TrainManager.TunnelUsageAction.ReversedDuringUse, TrainManager.TunnelUsageChangeReason.ForwardPathLost, oldTrainManagerEntry.id)

    -- Check if another train has grabbed out reservation when the path was lost. If so reset their reservation claim.
    -- We can't avoid this path lost even if we react to the event, the other train will have already bene given the path and stated.
    local targetStation = newTrainManagerEntry.scheduleTarget
    if targetStation.trains_count > targetStation.trains_limit then
        local trainsHeadingToStation = targetStation.get_train_stop_trains()
        for index = #trainsHeadingToStation, 1, -1 do
            local otherTrain = trainsHeadingToStation[index]
            -- Ignore any train that isn't currently pathing (reservation) to this specific train stop entity. Also ignore any train thats related to this tunnel usage. Our usurper train will have a speed of 0 as it hasn't moved yet this tick.
            if otherTrain.path_end_stop ~= nil and otherTrain.path_end_stop.unit_number == targetStation.unit_number and otherTrain.has_path and otherTrain.speed == 0 then
                if (newTrainManagerEntry.dummyTrain == nil or (newTrainManagerEntry.dummyTrain ~= nil and otherTrain.id ~= newTrainManagerEntry.dummyTrain.id)) and (newTrainManagerEntry.leavingTrain == nil or (newTrainManagerEntry.leavingTrain ~= nil and otherTrain.id ~= newTrainManagerEntry.leavingTrain.id)) then
                    -- Just do the first train found
                    otherTrain.manual_mode = true
                    otherTrain.manual_mode = false
                    break
                end
            end
        end
    end

    -- Remove any left over bits of the oldTrainManagerEntry
    TrainManager.TidyManagedTrainGlobals(oldTrainManagerEntry)
end

TrainManager.UpdatePortalExitSignalPerTick = function(trainManagerEntry, forceSignalState)
    -- Mirror aboveground exit signal state to underground signal so primary train (underground) honours stopping points. Primary speed limiter before leaving train has got to a significant size and escaped the portal signals as  a very small leaving/dummy train will have low breaking distance and thus very short signal block reservation/detecting distances.
    -- Close the underground Exit signal if the aboveground Exit signal isn't open, otherwise open it.
    -- forceSignalState is optional and when set will be applied rather than the aboveground exit signal state.
    local exitPortalOutSignal = trainManagerEntry.aboveExitPortalEntrySignalOut
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

TrainManager.Remote_GetTunnelUsageEntryObjectAttributes = function(trainManagerEntryId)
    local trainManagerEntry = global.trainManager.managedTrains[trainManagerEntryId]
    if trainManagerEntry == nil then
        return {
            tunnelUsageId = trainManagerEntryId,
            valid = false
        }
    else
        -- Only return valid LuaTrains as otherwise the events are dropped by Factorio.
        return {
            tunnelUsageId = trainManagerEntryId,
            valid = true,
            primaryState = trainManagerEntry.primaryTrainPartName,
            enteringTrain = Utils.ReturnValidLuaObjectOrNil(trainManagerEntry.enteringTrain),
            undergroundTrain = Utils.ReturnValidLuaObjectOrNil(trainManagerEntry.undergroundTrain),
            leavingTrain = Utils.ReturnValidLuaObjectOrNil(trainManagerEntry.leavingTrain),
            leftTrain = Utils.ReturnValidLuaObjectOrNil(trainManagerEntry.leftTrain)
        }
    end
end

TrainManager.Remote_TunnelUsageChanged = function(trainManagerEntryId, action, changeReason, replacedtunnelUsageId)
    -- Schedule the event to be raised after all trains are handled for this tick. Otherwise events can interupt the mods processes and cause errors.
    -- Don't put the Factorio Lua object references in here yet as they may become invalid by send time and then the event is dropped.
    local data = {
        tunnelUsageId = trainManagerEntryId,
        name = "RailwayTunnel.TunnelUsageChanged",
        action = action,
        changeReason = changeReason,
        replacedtunnelUsageId = replacedtunnelUsageId
    }
    table.insert(global.trainManager.eventsToRaise, data)
end

TrainManager.Remote_GetTunnelUsageEntry = function(trainManagerEntryId)
    return TrainManager.Remote_GetTunnelUsageEntryObjectAttributes(trainManagerEntryId)
end

TrainManager.Remote_GetATrainsTunnelUsageEntry = function(trainId)
    local trainManagerEntry = global.trainManager.enteringTrainIdToManagedTrain[trainId] or global.trainManager.dummyTrainIdToManagedTrain[trainId] or global.trainManager.leavingTrainIdToManagedTrain[trainId] or global.trainManager.trainLeftTunnelTrainIdToManagedTrain[trainId]
    if trainManagerEntry ~= nil then
        return TrainManager.Remote_GetTunnelUsageEntryObjectAttributes(trainManagerEntry.id)
    else
        return nil
    end
end

TrainManager.Remote_GetTemporaryCarriageNames = function()
    return {
        ["railway_tunnel-tunnel_portal_pushing_locomotive"] = "railway_tunnel-tunnel_portal_pushing_locomotive",
        ["railway_tunnel-tunnel_exit_dummy_locomotive"] = "railway_tunnel-tunnel_exit_dummy_locomotive",
        ["railway_tunnel-tunnel_portal_blocking_locomotive"] = "railway_tunnel-tunnel_portal_blocking_locomotive"
    }
end

return TrainManager
