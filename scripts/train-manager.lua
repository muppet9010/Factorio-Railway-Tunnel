local TrainManager = {}
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")
local Utils = require("utility/utils")
local TrainManagerFuncs = require("scripts/train-manager-functions") -- Stateless functions that don't directly use global objects.
local PlayerContainers = require("scripts/player-containers") -- Uses this file directly, rather than via interface. Details in the sub files notes.
local Logging = require("utility/logging")
local UndergroundSetUndergroundExitSignalStateFunction  -- Cache the function reference during OnLoad. Saves using Interfaces every tick.

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
            leavingTrainStoppingSchedule = the LuaRail that the leaving train is currently stopping at beyond the portal, or nil.
            leavingTrainExpectedBadState = if the leaving train is in a bad state and it can't be corrected. Avoids any repeating checks or trying bad actions, and just waits for the train to naturally path itself.
            leavingTrainAtEndOfPortalTrack = if the leaving train is in a bad state and has reached the end of the portal track. It still needs to be checked for rear paths every tick via the mod.

            leftTrain = LuaTrain of the train thats left the tunnel.
            leftTrainId = The LuaTrain ID of the leftTrain.

            dummyTrain = LuaTrain of the dummy train used to keep the train stop reservation alive
            dummyTrainId = the LuaTrain ID of the dummy train.
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
            leavingCarriageIdToUndergroundCarriageEntity = Table of the leaving carriage unit number to the underground carriage entity for each carriage in the train. Currently used for supporting reversal of train and populating new trainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity.
        }
    ]]
    global.trainManager.trainIdToManagedTrain = global.trainManager.trainIdToManagedTrain or {}
    --[[
        Used to track trainIds to managedTrainEntries. When the trainId is detected as changing via event the global object is updated to stay up to date.
        [trainId] = {
            trainId = the LuaTrain id, same as key.
            trainManagerEntry = the global.trainManager.managedTrains object.
            tunnelUsagePart = the part of the tunnel usage: enteringTrain, dummyTrain, UndergroundTrain, leavingTrain
        }
    ]]
    global.trainManager.eventsToRaise = global.trainManager.eventsToRaise or {} -- Events are raised at end of tick to avoid other mods interupting this mod's process and breaking things.
end

TrainManager.OnLoad = function()
    UndergroundSetUndergroundExitSignalStateFunction = Interfaces.GetNamedFunction("Underground.SetUndergroundExitSignalState")
    Interfaces.RegisterInterface(
        "TrainManager.RegisterTrainApproaching",
        function(...)
            TrainManagerFuncs.RunFunctionAndCatchErrors(TrainManager.RegisterTrainApproaching, ...)
        end
    )
    Events.RegisterHandlerEvent(defines.events.on_tick, "TrainManager.ProcessManagedTrains", TrainManager.ProcessManagedTrains)
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
    -- Check if this train is already using the tunnel to leave. Happens if the train doesn't fully leave the exit portal signal block before coming back in.
    local existingTrainIDTrackedObject, trainLeftEntry = global.trainManager.trainIdToManagedTrain[enteringTrain.id], nil
    if existingTrainIDTrackedObject ~= nil and existingTrainIDTrackedObject.tunnelUsagePart == "leftTrain" then
        trainLeftEntry = existingTrainIDTrackedObject.trainManagerEntry
        -- Terminate the old tunnel usage that was delayed until this point. Don't try to reverse the tunnel usage as this event has naturally happened and the old tunnel usage was effectively over anyways.
        TrainManager.TerminateTunnelTrip(trainLeftEntry, TrainManager.TunnelUsageChangeReason.reversedAfterLeft)
    end

    local trainManagerEntry = TrainManager.CreateTrainManagerEntryObject(enteringTrain, aboveEntrancePortalEndSignal)
    trainManagerEntry.primaryTrainPartName, trainManagerEntry.enteringTrainState, trainManagerEntry.undergroundTrainState, trainManagerEntry.leavingTrainState = PrimaryTrainPartNames.approaching, EnteringTrainStates.approaching, UndergroundTrainStates.travelling, LeavingTrainStates.pre
    TrainManager.CreateUndergroundTrainObject(trainManagerEntry)
    Interfaces.Call("Tunnel.TrainReservedTunnel", trainManagerEntry)

    if trainLeftEntry ~= nil then
        -- Include in the new train approaching event the old leftTrain entry id that has been stopped.
        TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.startApproaching, nil, trainLeftEntry.id)
    else
        TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.startApproaching)
    end
end

TrainManager.ProcessManagedTrains = function()
    -- Loop over each train and process it.
    for _, trainManagerEntry in pairs(global.trainManager.managedTrains) do
        TrainManagerFuncs.RunFunctionAndCatchErrors(TrainManager.ProcessManagedTrain, trainManagerEntry)
    end

    -- Raise any events from this tick for external listener mods to react to.
    for _, eventData in pairs(global.trainManager.eventsToRaise) do
        TrainManager.Remote_PopulateTableWithTunnelUsageEntryObjectAttributes(eventData, eventData.tunnelUsageId)
        -- Populate the leavingTrain attribute with the leftTrain value when the leavingTrain value isn't valid. Makes handling the events nicer by hiding this internal code oddity.
        if (eventData.leavingTrain == nil or not eventData.leavingTrain.valid) and (eventData.leftTrain ~= nil and eventData.leftTrain.valid) then
            eventData.leavingTrain = eventData.leftTrain
            eventData.leftTrain = nil
        end
        Events.RaiseEvent(eventData)
    end
    global.trainManager.eventsToRaise = {}
end

TrainManager.ProcessManagedTrain = function(trainManagerEntry)
    local skipThisTick = false -- Used to provide a "continue" ability as some actions could leave the trains in a weird state this tick and thus error on later functions in the process.

    -- Check dummy train state is valid if it exists. Used in a lot of states so sits outside of them.
    if not skipThisTick and trainManagerEntry.dummyTrain ~= nil and not TrainManagerFuncs.IsTrainHealthlyState(trainManagerEntry.dummyTrain) then
        TrainManager.HandleLeavingTrainBadState(trainManagerEntry, trainManagerEntry.dummyTrain)
        skipThisTick = true
    end

    if not skipThisTick and trainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.approaching then
        -- Check whether the train is still approaching the tunnel portal as its not committed yet and so can turn away.
        if trainManagerEntry.enteringTrain.state ~= defines.train_state.arrive_signal or trainManagerEntry.enteringTrain.signal ~= trainManagerEntry.aboveEntrancePortalEndSignal.entity then
            TrainManager.TerminateTunnelTrip(trainManagerEntry, TrainManager.TunnelUsageChangeReason.abortedApproach)
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
            -- Check the leaving trains state and react accordingly
            if trainManagerEntry.leavingTrainExpectedBadState then
                -- The train is known to have reached a bad state and is staying in it. We need to monitor the leaving train returning to a healthy state with a path, rather than try to fix the bad state.
                if TrainManagerFuncs.IsTrainHealthlyState(trainManagerEntry.leavingTrain) and trainManagerEntry.leavingTrain.has_path then
                    -- Leaving train is healthy again with a path so return everything to active.
                    trainManagerEntry.undergroundTrainSetsSpeed = true
                    trainManagerEntry.undergroundTrain.manual_mode = false
                    trainManagerEntry.leavingTrainExpectedBadState = false
                    trainManagerEntry.leavingTrainAtEndOfPortalTrack = false
                end
            elseif not TrainManagerFuncs.IsTrainHealthlyState(trainManagerEntry.leavingTrain) then
                -- Check if the leaving train is in a good state before we check to add any new wagons to it.
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

TrainManager.HandleLeavingTrainBadState = function(trainManagerEntry, trainWithBadState)
    -- Check if the full train can reverse in concept.
    local undergroundTrainReverseLocoListName
    local undergroundTrainSpeed = trainManagerEntry.undergroundTrain.speed
    if undergroundTrainSpeed > 0 then
        undergroundTrainReverseLocoListName = "back_movers"
    elseif undergroundTrainSpeed < 0 then
        undergroundTrainReverseLocoListName = "front_movers"
    elseif trainManagerEntry.undergroundTrainForwards then
        undergroundTrainReverseLocoListName = "back_movers"
    elseif not trainManagerEntry.undergroundTrainForwards then
        undergroundTrainReverseLocoListName = "front_movers"
    else
        error("TrainManager.HandleLeavingTrainBadState() doesn't support 0 speed underground train\nundergroundTrain id: " .. trainManagerEntry.undergroundTrain.id)
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
            local enteringTrainReversePushingLoco, reverseLocoListName, enteringTrainFrontCarriage
            if oldEnteringSpeed > 0 then
                reverseLocoListName = "back_movers"
                enteringTrainFrontCarriage = enteringTrain.front_stock
            elseif oldEnteringSpeed < 0 then
                reverseLocoListName = "front_movers"
                enteringTrainFrontCarriage = enteringTrain.back_stock
            else
                error("TrainManager.HandleLeavingTrainBadState() doesn't support 0 speed entering train\nenteringTrain id: " .. enteringTrain.id)
            end
            if #enteringTrain.locomotives[reverseLocoListName] == 0 then
                -- Put the loco at the front of the leaving train backwards to the trains current orientation. As we want to test reversing the trains current direction.
                enteringTrainReversePushingLoco = TrainManagerFuncs.AddPushingLocoToAfterCarriage(enteringTrainFrontCarriage, Utils.BoundFloatValueWithinRange(trainManagerEntry.trainTravelOrientation + 0.5, 0, 1))
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
            local pathTestTrain = TrainManagerFuncs.CreateDummyTrain(trainManagerEntry.aboveEntrancePortal.entity, nil, nil, true)
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

    if trainManagerEntry.leavingTrainAtEndOfPortalTrack then
        -- Train is already at end of track so don't change its schedule.
        return
    end

    -- Handle train that can't go backwards, so just pull the train forwards to the end of the tunnel (signal segment) and then return to its preivous schedule. Makes the situation more obvious for the player and easier to access the train. The train has already lost any station reservation it had.
    local newSchedule = trainWithBadState.schedule
    local fallbackTargetRail = trainManagerEntry.aboveExitPortalEntrySignalOut.entity.get_connected_rails()[1]
    local endOfTunnelScheduleRecord = {rail = fallbackTargetRail, temporary = true}
    table.insert(newSchedule.records, newSchedule.current, endOfTunnelScheduleRecord)
    trainWithBadState.schedule = newSchedule

    local movingToEndOfPortal = true
    if not trainWithBadState.has_path then
        -- Check if the train can reach the end of the tunnel portal track. If it can't then the train is past the target track point. In this case the train should just stop where it is and wait.

        -- Reset the above schedule and the train will go in to no-path or destination full states until it can move off some time in the future.
        table.remove(newSchedule.records, 1)
        trainWithBadState.schedule = newSchedule
        movingToEndOfPortal = false
    elseif trainWithBadState.path.total_distance - trainWithBadState.path.travelled_distance <= 4 then
        -- Train has reached end of portal already and if its hit this it can't reverse, so don't try and schedule it anywhere.
        movingToEndOfPortal = false
    end

    -- Not moving to end of portal so do some more tagging of the trains state for future ticks usage.
    if not movingToEndOfPortal then
        -- Set the above ground train as setting the speed. Underground needs to stay still until the above train reactivates it.
        trainManagerEntry.undergroundTrainSetsSpeed = false
        trainManagerEntry.undergroundTrain.manual_mode = true
        trainManagerEntry.undergroundTrain.speed = 0

        -- Work out the correct persistent state to tag the train as. Will affect what repathing checks are done per tick going forwards.
        if #trainManagerEntry.undergroundTrain.locomotives[undergroundTrainReverseLocoListName] > 0 then
            -- Train can conceptually repath backwards so let this modded backwards path check keep on trying.
            trainManagerEntry.leavingTrainExpectedBadState = false
            trainManagerEntry.leavingTrainAtEndOfPortalTrack = true
        else
            -- Train can't repath backwards, so just wait for a natural path to be found.
            trainManagerEntry.leavingTrainExpectedBadState = true
            trainManagerEntry.leavingTrainAtEndOfPortalTrack = false
        end
    end
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
        trainManagerEntry.scheduleTarget = enteringTrain.path_end_stop
        trainManagerEntry.dummyTrain = TrainManagerFuncs.CreateDummyTrain(trainManagerEntry.aboveExitPortal.entity, enteringTrain.schedule, trainManagerEntry.scheduleTarget, false)
        local dummyTrainId = trainManagerEntry.dummyTrain.id
        trainManagerEntry.dummyTrainId = dummyTrainId
        global.trainManager.trainIdToManagedTrain[dummyTrainId] = {
            trainId = dummyTrainId,
            trainManagerEntry = trainManagerEntry,
            tunnelUsagePart = "dummyTrain"
        }
        -- Schedule has been transferred to dummy train.
        enteringTrain.schedule = nil
    -- The same tick the first carriage will be removed by TrainManager.TrainEnteringOngoing() and this will fire an event.
    end
end

TrainManager.TrainEnteringOngoing = function(trainManagerEntry)
    -- Only update the exit signal when we aren't leaving. As a very long train can be entering and leaving at the same time.
    if trainManagerEntry.leavingTrainState == LeavingTrainStates.pre then
        TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry)
    end

    local enteringTrain = trainManagerEntry.enteringTrain

    -- Force an entering train to stay in manual mode.
    enteringTrain.manual_mode = true

    TrainManager.SetAbsoluteTrainSpeed(trainManagerEntry, "enteringTrain", math.abs(trainManagerEntry.undergroundTrain.speed))
    -- trainManagerEntry.enteringTrainForwards has been updated for us by SetAbsoluteTrainSpeed().
    local nextCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(enteringTrain, trainManagerEntry.enteringTrainForwards)

    -- Only try to remove a carriage if there is a speed. A 0 speed entering train can occur when a leaving train reverses.
    if enteringTrain.speed ~= 0 and Utils.GetDistanceSingleAxis(nextCarriage.position, trainManagerEntry.aboveEntrancePortalEndSignal.entity.position, trainManagerEntry.tunnel.railAlignmentAxis) < 14 then
        -- Handle any player in the train carriage.
        local driver = nextCarriage.get_driver()
        if driver ~= nil then
            PlayerContainers.PlayerInCarriageEnteringTunnel(trainManagerEntry, driver, nextCarriage)
        end

        nextCarriage.destroy()
        -- Update local variable as new train number after removing carriage.
        enteringTrain = trainManagerEntry.enteringTrain

        -- Removing a carriage can flip the trains direction. Only detect if there is a non 0 speed.
        if enteringTrain ~= nil and enteringTrain.valid and enteringTrain.speed ~= 0 then
            local positiveSpeed = enteringTrain.speed > 0
            if positiveSpeed ~= trainManagerEntry.enteringTrainForwards then
                -- Speed and cached forwards state don't match, so flip cached forwards state.
                trainManagerEntry.enteringTrainForwards = not trainManagerEntry.enteringTrainForwards
            end
        end

        TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.enteringCarriageRemoved)
    end

    if not enteringTrain.valid then
        -- Train has completed entering.
        trainManagerEntry.enteringTrainState = EnteringTrainStates.finished
        global.trainManager.trainIdToManagedTrain[trainManagerEntry.enteringTrainId] = nil
        trainManagerEntry.enteringTrain = nil
        trainManagerEntry.enteringTrainId = nil
        trainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity = nil
        Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", trainManagerEntry)
        TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.fullyEntered)
    end
end

TrainManager.TrainUndergroundOngoing = function(trainManagerEntry)
    PlayerContainers.MoveATrainsPlayerContainers(trainManagerEntry)
    if trainManagerEntry.enteringTrainState == EnteringTrainStates.finished then
        -- If the train is still entering then that is doing the updating. This function isn't looping once the train is leaving.
        TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry)
    end

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
    TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.startedLeaving)
    TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.leavingCarriageAdded)
    TrainManager.UpdatePortalExitSignalPerTick(trainManagerEntry, defines.signal_state.open) -- Reset the underground Exit signal state as the leaving train will now detect any signals.
    trainManagerEntry.undergroundTrainSetsSpeed = true

    -- Check if all train wagons placed and train fully left the tunnel, otherwise set state for future carriages with the ongoing state.
    if trainManagerEntry.leavingTrainCarriagesPlaced == #trainManagerEntry.undergroundTrain.carriages then
        TrainManager.TrainLeavingCompleted(trainManagerEntry, nil)
    else
        trainManagerEntry.leavingTrainState = LeavingTrainStates.leaving
    end
end

TrainManager.TrainLeavingOngoing = function(trainManagerEntry)
    -- Handle if the train is stopping at a signal or scheduled stop (train-stop or rail). Updates trainManagerEntry.undergroundTrainSetsSpeed and the underground train path if required.
    TrainManager.HandleLeavingTrainStoppingAtSignalSchedule(trainManagerEntry, "signal")
    TrainManager.HandleLeavingTrainStoppingAtSignalSchedule(trainManagerEntry, "schedule")

    -- Get the desired speed for this tick.
    local desiredSpeed
    if trainManagerEntry.undergroundTrainSetsSpeed then
        desiredSpeed = math.abs(trainManagerEntry.undergroundTrain.speed)
    else
        desiredSpeed = math.abs(trainManagerEntry.leavingTrain.speed)
    end

    -- Check if the leaving train has stopped, but the underground train is moving. This should only occur when the leaving train has lost its path and naturally is pathing back through the tunnel. As otherwise the state check would have caught it already this tick.
    if desiredSpeed ~= 0 and trainManagerEntry.leavingTrain.speed == 0 then
        -- Theres nothing broken with the state, but the mod doesn't expect it so we need to identify if the train is reversing on its own accord.

        -- The test will affect the trains schedule so take a backup first. We have to do this rather than a front/rear stock check as theres no train composition change to test around here. Its just waht the base game thinks the train is doing.
        local scheduleBackup, isManualBackup, targetStop = trainManagerEntry.leavingTrain.schedule, trainManagerEntry.leavingTrain.manual_mode, trainManagerEntry.leavingTrain.path_end_stop
        -- Carefully set the speed and schedule to see if the train is pointing in the expected direction when it wants to path or not.
        -- The leaving train is moving opposite to the underground train (desiredSpeed). So handle the reversal and stop processing. If the speed isn't lost then this is the more normal usage case and so can just be left as is. We just double set the speed this 1 tick, no harm done.
        local isTrainGoingExpectedDirection = TrainManager.Check0SpeedTrainWithLocoGoingExpectedDirection(trainManagerEntry, "leavingTrain", desiredSpeed, scheduleBackup, isManualBackup, targetStop)
        if not isTrainGoingExpectedDirection then
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

            -- Follow up items post leaving train carriage addition.
            PlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage(nextSourceCarriageEntity, placedCarriage)
            TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.leavingCarriageAdded)

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
        PlayerContainers.MoveATrainsPlayerContainers(trainManagerEntry)
    end

    -- Update which ever train isn't setting the desired speed.
    if trainManagerEntry.undergroundTrainSetsSpeed then
        TrainManager.SetAbsoluteTrainSpeed(trainManagerEntry, "leavingTrain", desiredSpeed)
    else
        TrainManager.SetAbsoluteTrainSpeed(trainManagerEntry, "undergroundTrain", desiredSpeed)
    end
end

TrainManager.HandleLeavingTrainStoppingAtSignalSchedule = function(trainManagerEntry, arriveAtName)
    -- Handles a train leaving a tunnel arriving at a station/signal based on input. Updated global state data that impacts TrainManager.TrainLeavingOngoing(): trainManagerEntry.undergroundTrainSetsSpeed and underground train path target.
    local leavingTrain, trainStoppingEntityAttributeName, stoppingTargetEntityAttributeName, arriveAtReleventStoppingTarget = trainManagerEntry.leavingTrain, nil, nil, nil
    if arriveAtName == "signal" then
        trainStoppingEntityAttributeName = "signal"
        stoppingTargetEntityAttributeName = "leavingTrainStoppingSignal"
        arriveAtReleventStoppingTarget = leavingTrain.state == defines.train_state.arrive_signal
    elseif arriveAtName == "schedule" then
        -- Type of schedule includes both train-stop's and rail's. But we can always just use the end rail attribute for both.
        trainStoppingEntityAttributeName = "path_end_rail"
        stoppingTargetEntityAttributeName = "leavingTrainStoppingSchedule"
        arriveAtReleventStoppingTarget = leavingTrain.state == defines.train_state.arrive_station
    else
        error("TrainManager.HandleLeavingTrainStoppingAtSignalSchedule() unsuported arriveAtName: " .. arriveAtName)
    end

    -- 1: If leaving train is now arriving at a relvent stopping target (station or signal) check state in detail as we may need to update the underground train stop point.
    -- 2: Once the leaving train is stopped at a relevent stopping target, clear out stopping target arriving state.
    -- 3: Otherwise check for moving away states and if there was a preivous stopping state to be finished.
    if arriveAtReleventStoppingTarget then
        -- If a known stopping target was set, make sure it still exists.
        if trainManagerEntry[stoppingTargetEntityAttributeName] ~= nil and not trainManagerEntry[stoppingTargetEntityAttributeName].valid then
            trainManagerEntry[stoppingTargetEntityAttributeName] = nil
            trainManagerEntry.undergroundTrainSetsSpeed = true
        end

        -- Check the stopping target is the expected one, if not reset state to detect new stopping target.
        if trainManagerEntry[stoppingTargetEntityAttributeName] ~= nil and leavingTrain[trainStoppingEntityAttributeName].unit_number ~= trainManagerEntry[stoppingTargetEntityAttributeName].unit_number then
            trainManagerEntry[stoppingTargetEntityAttributeName] = nil
            trainManagerEntry.undergroundTrainSetsSpeed = true
        end

        -- 1: If there's no expected stopping target then record state and update leaving and underground trains activities.
        -- 2: Otherwise its the same stopping target as previously, so if the underground train is setting the speed need to check distance from stopping target and hand over control to leaving train if close.
        if trainManagerEntry[stoppingTargetEntityAttributeName] == nil then
            -- The above ground and underground trains will never be exactly relational to one another as they change speed each tick differently before they are re-aligned. So the underground train should be targetted as an offset from its current location and when the above train is very near the stopping target the above train can take over setting speed to manage the final pulling up.
            trainManagerEntry[stoppingTargetEntityAttributeName] = leavingTrain[trainStoppingEntityAttributeName]
            local exactDistanceFromTrainToTarget = TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTarget(leavingTrain, leavingTrain[trainStoppingEntityAttributeName], trainManagerEntry.leavingTrainForwards) - 1 -- The -1 is to avoid any slight over reaching on to the next rail. Better to be short than long.
            local undergroundTrainTargetPosition = TrainManagerFuncs.GetForwardPositionFromCurrentForDistance(trainManagerEntry.undergroundTrain, exactDistanceFromTrainToTarget)

            -- Avoid looking for a rail exactly on the deviding line between 2 tracks.
            if undergroundTrainTargetPosition[trainManagerEntry.tunnel.railAlignmentAxis] % 1 < 0.1 then
                undergroundTrainTargetPosition[trainManagerEntry.tunnel.railAlignmentAxis] = math.floor(undergroundTrainTargetPosition[trainManagerEntry.tunnel.railAlignmentAxis]) + 0.1
            elseif undergroundTrainTargetPosition[trainManagerEntry.tunnel.railAlignmentAxis] % 1 > 0.9 then
                undergroundTrainTargetPosition[trainManagerEntry.tunnel.railAlignmentAxis] = math.floor(undergroundTrainTargetPosition[trainManagerEntry.tunnel.railAlignmentAxis]) + 0.9
            end

            TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition(trainManagerEntry.undergroundTrain, undergroundTrainTargetPosition)
            trainManagerEntry.undergroundTrainSetsSpeed = true
        elseif trainManagerEntry.undergroundTrainSetsSpeed then
            -- Is the same stopping target as last tick, so check if the leaving train is close to the stopping target and give it speed control if so.
            local leadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(leavingTrain, trainManagerEntry.leavingTrainForwards)
            local leadCarriageDistanceFromStoppingEntity = Utils.GetDistance(leadCarriage.position, trainManagerEntry[stoppingTargetEntityAttributeName].position)
            local leavingTrainCloseToStoppingEntityDistance = TrainManagerFuncs.GetCarriagePlacementDistance(leadCarriage.name) + 4 -- This is the length of the leading carriage plus 4 tiles leaway so the speed handover isn't too abrupt. May be a bit abrupt if leaving train is lacking loco's to carriages though, compared to full underground train.
            if leadCarriageDistanceFromStoppingEntity < leavingTrainCloseToStoppingEntityDistance then
                trainManagerEntry.undergroundTrainSetsSpeed = false
            end
        end
    elseif trainManagerEntry[stoppingTargetEntityAttributeName] ~= nil and leavingTrain.state == defines.train_state.on_the_path then
        -- If the train was stopped/stopping at a stopping target and now is back on the path, return to underground train setting speed and assume everything is back to normal.
        trainManagerEntry[stoppingTargetEntityAttributeName] = nil
        trainManagerEntry.undergroundTrainSetsSpeed = true
        trainManagerEntry.undergroundTrain.manual_mode = false
        local undergroundTrainEndScheduleTargetPos = Interfaces.Call("Underground.GetForwardsEndOfRailPosition", trainManagerEntry.tunnel.undergroundTunnel, trainManagerEntry.trainTravelOrientation)
        TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition(trainManagerEntry.undergroundTrain, undergroundTrainEndScheduleTargetPos)
    end
end

TrainManager.TrainLeavingCompleted = function(trainManagerEntry)
    TrainManager.DestroyUndergroundTrain(trainManagerEntry)

    trainManagerEntry.leftTrain, trainManagerEntry.leftTrainId = trainManagerEntry.leavingTrain, trainManagerEntry.leavingTrainId
    global.trainManager.trainIdToManagedTrain[trainManagerEntry.leavingTrainId].tunnelUsagePart = "leftTrain" -- Keep the table, just update its state, as same train id, etc between the leaving and left train at this state change point.
    trainManagerEntry.leavingTrainState = LeavingTrainStates.trainLeftTunnel
    trainManagerEntry.undergroundTrainState = UndergroundTrainStates.finished
    trainManagerEntry.leavingTrainId = nil
    trainManagerEntry.leavingTrain = nil

    TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.fullyLeft)
end

TrainManager.TrainLeftTunnelOngoing = function(trainManagerEntry)
    -- Track the tunnel's exit portal entry rail signal so we can mark the tunnel as open for the next train when the current train has left. We are assuming that no train gets in to the portal rail segment before our main train gets out. This is far more UPS effecient than checking the trains last carriage and seeing if its end rail signal is our portal entrance one.
    local exitPortalEntranceSignalEntity = trainManagerEntry.aboveExitPortal.entrySignals["in"].entity
    if exitPortalEntranceSignalEntity.signal_state ~= defines.signal_state.closed then
        -- No train in the block so our one must have left.
        global.trainManager.trainIdToManagedTrain[trainManagerEntry.leftTrainId] = nil
        trainManagerEntry.leftTrain = nil
        trainManagerEntry.leftTrainId = nil
        TrainManager.TerminateTunnelTrip(trainManagerEntry, TrainManager.TunnelUsageChangeReason.completedTunnelUsage)
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
        global.trainManager.trainIdToManagedTrain[trainManagerEntry.dummyTrain.id] = nil
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

    local trackedTrainIdObject = global.trainManager.trainIdToManagedTrain[event.old_train_id_1] or global.trainManager.trainIdToManagedTrain[event.old_train_id_2]
    if trackedTrainIdObject == nil then
        return
    end

    -- Get the correct variables for this tunnel usage part.
    local trainAttributeName, trainIdAttributeName
    if trackedTrainIdObject.tunnelUsagePart == "enteringTrain" then
        trainAttributeName = "enteringTrain"
        trainIdAttributeName = "enteringTrainId"
    elseif trackedTrainIdObject.tunnelUsagePart == "dummyTrain" then
        trainAttributeName = "leftTrain"
        trainIdAttributeName = "leftTrainId"
    elseif trackedTrainIdObject.tunnelUsagePart == "leavingTrain" then
        trainAttributeName = "leavingTrain"
        trainIdAttributeName = "leavingTrainId"
    elseif trackedTrainIdObject.tunnelUsagePart == "leftTrain" then
        trainAttributeName = "leftTrain"
        trainIdAttributeName = "leftTrainId"
    else
        error("unrecognised global.trainManager.trainIdToManagedTrain tunnelUsagePart: " .. tostring(trackedTrainIdObject.tunnelUsagePart))
    end

    -- Update the object and globals for the change of train and train id.
    local newTrain, newTrainId = event.train, event.train.id
    trackedTrainIdObject.trainManagerEntry[trainAttributeName] = newTrain
    trackedTrainIdObject.trainManagerEntry[trainIdAttributeName] = newTrainId
    trackedTrainIdObject.trainId = newTrainId
    if event.old_train_id_1 ~= nil then
        global.trainManager.trainIdToManagedTrain[event.old_train_id_1] = nil
    end
    if event.old_train_id_2 ~= nil then
        global.trainManager.trainIdToManagedTrain[event.old_train_id_2] = nil
    end
    global.trainManager.trainIdToManagedTrain[newTrainId] = trackedTrainIdObject
end

TrainManager.SetAbsoluteTrainSpeed = function(trainManagerEntry, trainAttributeName, speed)
    local train = trainManagerEntry[trainAttributeName]

    -- Only update train's global forwards if speed ~= 0. As the last train direction needs to be preserved in global data for if the train stops while using the tunnel.
    local trainSpeed = train.speed
    if trainSpeed > 0 then
        trainManagerEntry[trainAttributeName .. "Forwards"] = true
        train.speed = speed
    elseif trainSpeed < 0 then
        trainManagerEntry[trainAttributeName .. "Forwards"] = false
        train.speed = -1 * speed
    else
        if trainManagerEntry[trainAttributeName .. "Forwards"] == true then
            train.speed = speed
        elseif trainManagerEntry[trainAttributeName .. "Forwards"] == false then
            train.speed = -1 * speed
        else
            error("TrainManager.SetAbsoluteTrainSpeed() for '" .. trainAttributeName .. "' doesn't support train with current 0 speed and no 'Forwards' cached value.\n" .. trainAttributeName .. " id: " .. trainManagerEntry[trainAttributeName].id)
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
                global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrainId] = nil
                if managedTrain.enteringTrain ~= nil and managedTrain.enteringTrain.valid then
                    managedTrain.enteringTrain.manual_mode = true
                    managedTrain.enteringTrain.speed = 0

                    -- Try to recover a schedule to the entering train.
                    if managedTrain.dummyTrain ~= nil and managedTrain.dummyTrain.valid then
                        managedTrain.enteringTrain.schedule = managedTrain.dummyTrain.schedule
                    elseif managedTrain.leavingTrain ~= nil and managedTrain.leavingTrain.valid then
                        managedTrain.enteringTrain.schedule = managedTrain.leavingTrain.schedule
                    end
                end
            end
            if managedTrain.leavingTrainId ~= nil then
                global.trainManager.trainIdToManagedTrain[managedTrain.leavingTrainId] = nil
                if managedTrain.leavingTrain ~= nil and managedTrain.leavingTrain.valid then
                    managedTrain.leavingTrain.manual_mode = true
                    managedTrain.leavingTrain.speed = 0
                end
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
    if placedCarriage == nil then
        error("failed to clone carriage:" .. "\nsurface name: " .. trainManagerEntry.aboveSurface.name .. "\nposition: " .. Logging.PositionToString(placementPosition) .. "\nsource carriage unit_number: " .. undergroundLeadCarriage.unit_number)
    end
    placedCarriage.train.speed = undergroundLeadCarriage.speed -- Set the speed when its a train of 1. Before a pushing locomotive may be added and make working out speed direction harder.
    trainManagerEntry.leavingTrainCarriagesPlaced = 1
    trainManagerEntry.leavingTrain, trainManagerEntry.leavingTrainId = placedCarriage.train, placedCarriage.train.id
    global.trainManager.trainIdToManagedTrain[trainManagerEntry.leavingTrainId] = {
        trainId = trainManagerEntry.leavingTrainId,
        trainManagerEntry = trainManagerEntry,
        tunnelUsagePart = "leavingTrain"
    }
    trainManagerEntry.leavingCarriageIdToUndergroundCarriageEntity[placedCarriage.unit_number] = undergroundLeadCarriage

    -- Add a pushing loco if needed.
    if not TrainManagerFuncs.CarriageIsAForwardsLoco(placedCarriage, trainManagerEntry.trainTravelOrientation) then
        trainManagerEntry.leavingTrainPushingLoco = TrainManagerFuncs.AddPushingLocoToAfterCarriage(placedCarriage, trainManagerEntry.trainTravelOrientation)
    end

    local leavingTrainSpeed = trainManagerEntry.leavingTrain.speed
    if leavingTrainSpeed > 0 then
        trainManagerEntry.leavingTrainForwards = true
    elseif leavingTrainSpeed < 0 then
        trainManagerEntry.leavingTrainForwards = true
    else
        error("TrainManager.CreateFirstCarriageForLeavingTrain() doesn't support 0 speed leaving train.\nleavingTrain id: " .. trainManagerEntry.leavingTrain.id)
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
        error("failed to clone carriage:" .. "\nsurface name: " .. trainManagerEntry.aboveSurface.name .. "\nposition: " .. Logging.PositionToString(nextCarriagePosition) .. "\nsource carriage unit_number: " .. nextSourceCarriageEntity.unit_number)
    end
    trainManagerEntry.leavingTrainCarriagesPlaced = trainManagerEntry.leavingTrainCarriagesPlaced + 1
    if #placedCarriage.train.carriages ~= aboveTrainOldCarriageCount + 1 then
        error("Placed carriage not part of leaving train as expected carriage count not right.\nleavingTrain id: " .. trainManagerEntry.leavingTrain.id)
    end
    trainManagerEntry.leavingCarriageIdToUndergroundCarriageEntity[placedCarriage.unit_number] = nextSourceCarriageEntity

    -- If train had a pushing loco before and still needs one, add one back.
    if hadPushingLoco and (not TrainManagerFuncs.CarriageIsAForwardsLoco(placedCarriage, trainManagerEntry.trainTravelOrientation)) then
        trainManagerEntry.leavingTrainPushingLoco = TrainManagerFuncs.AddPushingLocoToAfterCarriage(placedCarriage, trainManagerEntry.trainTravelOrientation)
    end

    return placedCarriage
end

TrainManager.CreateTrainManagerEntryObject = function(enteringTrain, aboveEntrancePortalEndSignal)
    local enteringTrainId = enteringTrain.id
    local trainManagerEntry = {
        id = global.trainManager.nextManagedTrainId,
        enteringTrain = enteringTrain,
        enteringTrainId = enteringTrainId,
        aboveEntrancePortalEndSignal = aboveEntrancePortalEndSignal,
        aboveEntrancePortal = aboveEntrancePortalEndSignal.portal,
        tunnel = aboveEntrancePortalEndSignal.portal.tunnel,
        trainTravelDirection = Utils.LoopDirectionValue(aboveEntrancePortalEndSignal.entity.direction + 4),
        enteringCarriageIdToUndergroundCarriageEntity = {},
        leavingCarriageIdToUndergroundCarriageEntity = {},
        leavingTrainExpectedBadState = false,
        leavingTrainAtEndOfPortalTrack = false
    }
    global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId + 1
    global.trainManager.managedTrains[trainManagerEntry.id] = trainManagerEntry
    trainManagerEntry.aboveSurface = trainManagerEntry.tunnel.aboveSurface
    local enteringTrainSpeed = trainManagerEntry.enteringTrain.speed
    if enteringTrainSpeed > 0 then
        trainManagerEntry.enteringTrainForwards = true
    elseif enteringTrainSpeed < 0 then
        trainManagerEntry.enteringTrainForwards = false
    else
        error("TrainManager.CreateTrainManagerEntryObject() doesn't support 0 speed\nenteringTrain id: " .. trainManagerEntry.enteringTrainId)
    end
    trainManagerEntry.trainTravelOrientation = Utils.DirectionToOrientation(trainManagerEntry.trainTravelDirection)
    global.trainManager.trainIdToManagedTrain[enteringTrainId] = {
        trainId = enteringTrainId,
        trainManagerEntry = trainManagerEntry,
        tunnelUsagePart = "enteringTrain"
    }

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
    local enteringTrainSpeed = trainManagerEntry.enteringTrain.speed
    trainManagerEntry.undergroundTrain.speed = enteringTrainSpeed
    if enteringTrainSpeed > 0 then
        trainManagerEntry.undergroundTrainForwards = true
    elseif enteringTrainSpeed < 0 then
        trainManagerEntry.undergroundTrainForwards = false
    else
        error("TrainManager.CreateUndergroundTrainObject() doesn't support 0 speed undergroundTrain.\nundergroundTrain id: " .. trainManagerEntry.undergroundTrain.id)
    end
    trainManagerEntry.undergroundTrain.manual_mode = false
    if trainManagerEntry.undergroundTrain.speed == 0 then
        -- If the speed is undone (0) by setting to automatic then the underground train is moving opposite to the entering train. Simple way to handle the underground train being an unknown "forwards".
        trainManagerEntry.undergroundTrainForwards = not trainManagerEntry.undergroundTrainForwards
        trainManagerEntry.undergroundTrain.speed = -1 * enteringTrainSpeed
    end

    trainManagerEntry.undergroundLeavingPortalEntrancePosition = Utils.ApplyOffsetToPosition(trainManagerEntry.aboveExitPortal.portalEntrancePosition, trainManagerEntry.tunnel.undergroundTunnel.undergroundOffsetFromSurface)
end

TrainManager.GetUndergroundFirstWagonPosition = function(trainManagerEntry)
    -- Work out the distance in rail tracks between the train and the portal's end signal's rail. This accounts for curves/U-bends and gives us a straight line distance as an output.
    local firstCarriageDistanceFromPortalEndSignalsRail = TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTarget(trainManagerEntry.enteringTrain, trainManagerEntry.aboveEntrancePortalEndSignal.entity, trainManagerEntry.enteringTrainForwards)

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
    local trainCarriagesForwardOrientation = trainManagerEntry.trainTravelOrientation
    if not trainManagerEntry.enteringTrainForwards then
        trainCarriagesForwardOrientation = Utils.BoundFloatValueWithinRangeMaxExclusive(trainCarriagesForwardOrientation + 0.5, 0, 1)
    end

    local minCarriageIndex, maxCarriageIndex, carriageIterator
    local refTrainSpeed, refTrainCarriages = refTrain.speed, refTrain.carriages
    if (refTrainSpeed > 0) then
        minCarriageIndex, maxCarriageIndex, carriageIterator = 1, #refTrainCarriages, 1
    elseif (refTrainSpeed < 0) then
        minCarriageIndex, maxCarriageIndex, carriageIterator = #refTrainCarriages, 1, -1
    else
        error("TrainManager.CopyEnteringTrainUnderground() doesn't support 0 speed refTrain.\nrefTrain id: " .. refTrain.id)
    end
    local placedCarriage
    for currentSourceTrainCarriageIndex = minCarriageIndex, maxCarriageIndex, carriageIterator do
        local refCarriage = refTrainCarriages[currentSourceTrainCarriageIndex]
        local carriageOrientation, refCarriageSpeed = trainCarriagesForwardOrientation, refCarriage.speed
        if refCarriageSpeed ~= refTrainSpeed then
            carriageOrientation = Utils.BoundFloatValueWithinRangeMaxExclusive(carriageOrientation + 0.5, 0, 1)
        end

        local safeCarriageFlipPosition
        if currentSourceTrainCarriageIndex ~= minCarriageIndex then
            -- The first carriage in the train doesn't need incrementing.
            nextCarriagePosition = TrainManagerFuncs.GetNextCarriagePlacementPosition(trainManagerEntry.trainTravelOrientation, placedCarriage, refCarriage.name)
            safeCarriageFlipPosition = Utils.ApplyOffsetToPosition(nextCarriagePosition, TrainManagerFuncs.GetNextCarriagePlacementOffset(trainManagerEntry.trainTravelOrientation, placedCarriage.name, refCarriage.name, 20))
        else
            safeCarriageFlipPosition = Utils.ApplyOffsetToPosition(nextCarriagePosition, TrainManagerFuncs.GetNextCarriagePlacementOffset(trainManagerEntry.trainTravelOrientation, refCarriage.name, refCarriage.name, 20))
        end

        placedCarriage = TrainManagerFuncs.CopyCarriage(targetSurface, refCarriage, nextCarriagePosition, safeCarriageFlipPosition, carriageOrientation)
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
    TrainManager.Remote_TunnelUsageChanged(trainManagerEntry.id, TrainManager.TunnelUsageAction.terminated, tunnelUsageChangeReason)
end

TrainManager.TidyManagedTrainGlobals = function(trainManagerEntry)
    -- Only remove the global if it points to this trainManagerEntry. The reversal process will have overwritten this already, so much be careful.
    if trainManagerEntry.enteringTrain and global.trainManager.trainIdToManagedTrain[trainManagerEntry.enteringTrainId].trainManagerEntry.id == trainManagerEntry.id then
        global.trainManager.trainIdToManagedTrain[trainManagerEntry.enteringTrainId] = nil
    end
    if trainManagerEntry.leavingTrain and global.trainManager.trainIdToManagedTrain[trainManagerEntry.leavingTrainId].trainManagerEntry.id == trainManagerEntry.id then
        global.trainManager.trainIdToManagedTrain[trainManagerEntry.leavingTrainId] = nil
    end
    if trainManagerEntry.leftTrain and global.trainManager.trainIdToManagedTrain[trainManagerEntry.leftTrainId].trainManagerEntry.id == trainManagerEntry.id then
        global.trainManager.trainIdToManagedTrain[trainManagerEntry.leftTrainId] = nil
    end

    if trainManagerEntry.dummyTrain then
        TrainManager.DestroyDummyTrain(trainManagerEntry)
    end

    global.trainManager.managedTrains[trainManagerEntry.id] = nil
end

TrainManager.Check0SpeedTrainWithLocoGoingExpectedDirection = function(trainManagerEntry, trainAttributeName, desiredSpeed, scheduleBackup, isManualBackup, targetStop)
    -- This requires the train to have a locomotive so that it can be given a path.
    -- This is the only known way to check which way a train with 0 speed and makign no carriage changes is really wanting to go. As the LuaTrain attributes only update when the train has a speed or a carriage is added/removed.
    -- This may end up with the train having a 0 speed if its pointing the wrong way. So the calling function needs to correct the train state if FALSE is returned.
    trainManagerEntry[trainAttributeName].manual_mode = true
    TrainManager.SetAbsoluteTrainSpeed(trainManagerEntry, trainAttributeName, desiredSpeed)
    TrainManagerFuncs.TrainSetSchedule(trainManagerEntry[trainAttributeName], scheduleBackup, isManualBackup, targetStop, true) -- Don't force validation.
    if trainManagerEntry[trainAttributeName].speed == 0 then
        return false
    else
        return true
    end
end

TrainManager.ReverseManagedTrainTunnelTrip = function(oldTrainManagerEntry)
    -- The managed train is going to reverse and go out of the tunnel the way it came in. Will be lodged as a new managed train so that old managed trains logic can be closed off.
    -- This function can't be reached if the train isn't committed, so no need to handle EnteringTrainStates.approaching.

    -- Release the tunnel from the old train manager. Later in this function it will be reclaimed accordingly.
    Interfaces.Call("Tunnel.TrainReleasedTunnel", oldTrainManagerEntry)

    local newTrainManagerEntry = {
        id = global.trainManager.nextManagedTrainId
    }
    global.trainManager.managedTrains[newTrainManagerEntry.id] = newTrainManagerEntry
    global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId + 1

    newTrainManagerEntry.undergroundTrainState = oldTrainManagerEntry.undergroundTrainState
    newTrainManagerEntry.undergroundTrain = oldTrainManagerEntry.undergroundTrain
    newTrainManagerEntry.undergroundTrainSetsSpeed = true -- Intentionally reset this value.
    newTrainManagerEntry.undergroundTrain.manual_mode = false -- Start the underground train running if it was stopped.
    newTrainManagerEntry.undergroundTrainForwards = not oldTrainManagerEntry.undergroundTrainForwards

    newTrainManagerEntry.trainTravelDirection = Utils.LoopDirectionValue(oldTrainManagerEntry.trainTravelDirection + 4)
    newTrainManagerEntry.trainTravelOrientation = Utils.DirectionToOrientation(newTrainManagerEntry.trainTravelDirection)
    newTrainManagerEntry.scheduleTarget = oldTrainManagerEntry.scheduleTarget
    newTrainManagerEntry.leavingTrainExpectedBadState = false
    newTrainManagerEntry.leavingTrainAtEndOfPortalTrack = false

    newTrainManagerEntry.aboveSurface = oldTrainManagerEntry.aboveSurface
    newTrainManagerEntry.aboveEntrancePortal = oldTrainManagerEntry.aboveExitPortal
    newTrainManagerEntry.aboveEntrancePortalEndSignal = oldTrainManagerEntry.aboveExitPortalEndSignal
    newTrainManagerEntry.aboveExitPortal = oldTrainManagerEntry.aboveEntrancePortal
    newTrainManagerEntry.aboveExitPortalEndSignal = oldTrainManagerEntry.aboveEntrancePortalEndSignal
    newTrainManagerEntry.aboveExitPortalEntrySignalOut = oldTrainManagerEntry.aboveEntrancePortal.entrySignals["out"]
    newTrainManagerEntry.tunnel = oldTrainManagerEntry.tunnel
    newTrainManagerEntry.undergroundTunnel = oldTrainManagerEntry.undergroundTunnel
    newTrainManagerEntry.undergroundLeavingPortalEntrancePosition = Utils.ApplyOffsetToPosition(newTrainManagerEntry.aboveExitPortal.portalEntrancePosition, newTrainManagerEntry.tunnel.undergroundTunnel.undergroundOffsetFromSurface)

    -- Get the schedule from what ever old train there was.
    local newTrainSchedule
    if oldTrainManagerEntry.dummyTrain ~= nil then
        newTrainSchedule = oldTrainManagerEntry.dummyTrain.schedule
    elseif oldTrainManagerEntry.leavingTrain ~= nil then
        newTrainSchedule = oldTrainManagerEntry.leavingTrain.schedule
    end

    -- Handle new entering train now all pre-req data set up.
    if oldTrainManagerEntry.leavingTrainState == LeavingTrainStates.leavingFirstCarriage or oldTrainManagerEntry.leavingTrainState == LeavingTrainStates.leaving then
        newTrainManagerEntry.enteringTrainState = EnteringTrainStates.entering
        newTrainManagerEntry.enteringTrain = oldTrainManagerEntry.leavingTrain
        newTrainManagerEntry.enteringTrain.speed = 0 -- We don't want to change the cached forwards state we have just generated. This was most liekly set to 0 already by the train reversing, but force it to be safe.
        newTrainManagerEntry.enteringTrain.schedule = nil -- Set to no scheule like a fresh enterign train would be.
        newTrainManagerEntry.enteringTrainId = oldTrainManagerEntry.leavingTrainId
        global.trainManager.trainIdToManagedTrain[newTrainManagerEntry.enteringTrainId] = {
            trainId = newTrainManagerEntry.enteringTrainId,
            trainManagerEntry = newTrainManagerEntry,
            tunnelUsagePart = "enteringTrain"
        }
        newTrainManagerEntry.enteringTrainForwards = not oldTrainManagerEntry.leavingTrainForwards

        -- Old leaving train has an exiting pushing loco. We need to
        if oldTrainManagerEntry.leavingTrainPushingLoco ~= nil then
            -- When pushing loco's are removed they may corrupt out cached Forwards state. So check if the trains idea of its front and back is changed and update accordingly.
            local oldFrontCarriageUnitNumber, oldBackCarriageUnitNumber = newTrainManagerEntry.enteringTrain.front_stock.unit_number, newTrainManagerEntry.enteringTrain.back_stock.unit_number
            TrainManagerFuncs.RemoveAnyPushingLocosFromTrain(newTrainManagerEntry.enteringTrain)
            local trainGoingExpectedDirection = TrainManagerFuncs.TrainStillFacingSameDirectionAfterCarriageChange(newTrainManagerEntry.enteringTrain, newTrainManagerEntry.trainTravelOrientation, oldFrontCarriageUnitNumber, oldBackCarriageUnitNumber, newTrainManagerEntry.enteringTrainForwards)
            if not trainGoingExpectedDirection then
                newTrainManagerEntry.enteringTrainForwards = not newTrainManagerEntry.enteringTrainForwards
            end
        end
    else
        newTrainManagerEntry.enteringTrainState = EnteringTrainStates.finished
        Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", newTrainManagerEntry)
    end

    -- Handle new leaving train now all pre-req data set up.
    if oldTrainManagerEntry.enteringTrainState == EnteringTrainStates.entering then
        newTrainManagerEntry.leavingTrainState = LeavingTrainStates.leaving
        newTrainManagerEntry.leavingTrain = oldTrainManagerEntry.enteringTrain
        newTrainManagerEntry.leavingTrain.speed = 0 -- We don't want to change the cached forwards state we have just generated. This was most liekly set to 0 already by the train reversing, but force it to be safe.
        newTrainManagerEntry.leavingTrainId = oldTrainManagerEntry.enteringTrainId
        newTrainManagerEntry.leavingTrainForwards = not oldTrainManagerEntry.enteringTrainForwards
        newTrainManagerEntry.leavingTrainCarriagesPlaced = #newTrainManagerEntry.leavingTrain.carriages
        global.trainManager.trainIdToManagedTrain[newTrainManagerEntry.leavingTrainId] = {
            trainId = newTrainManagerEntry.leavingTrainId,
            trainManagerEntry = newTrainManagerEntry,
            tunnelUsagePart = "leavingTrain"
        }
        if not TrainManagerFuncs.DoesTrainHaveAForwardsLoco(newTrainManagerEntry.leavingTrain, newTrainManagerEntry.trainTravelOrientation) then
            local rearCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(newTrainManagerEntry.leavingTrain, not newTrainManagerEntry.leavingTrainForwards)
            -- When pushing loco is added it may corrupt out cached Forwards state. So check if the trains idea of its front and back is changed and update accordingly.
            local oldFrontCarriageUnitNumber, oldBackCarriageUnitNumber = newTrainManagerEntry.leavingTrain.front_stock.unit_number, newTrainManagerEntry.leavingTrain.back_stock.unit_number
            newTrainManagerEntry.leavingTrainPushingLoco = TrainManagerFuncs.AddPushingLocoToAfterCarriage(rearCarriage, newTrainManagerEntry.trainTravelOrientation)
            local trainGoingExpectedDirection = TrainManagerFuncs.TrainStillFacingSameDirectionAfterCarriageChange(newTrainManagerEntry.leavingTrain, newTrainManagerEntry.trainTravelOrientation, oldFrontCarriageUnitNumber, oldBackCarriageUnitNumber, newTrainManagerEntry.leavingTrainForwards)
            if not trainGoingExpectedDirection then
                newTrainManagerEntry.leavingTrainForwards = not newTrainManagerEntry.leavingTrainForwards
            end
        end
        newTrainManagerEntry.leavingTrainStoppingSignal = nil -- Intentionally reset this value.
        newTrainManagerEntry.leavingTrainStoppingSchedule = nil -- Intentionally reset this value.
        TrainManagerFuncs.TrainSetSchedule(newTrainManagerEntry.leavingTrain, newTrainSchedule, false, newTrainManagerEntry.scheduleTarget, false)
        Interfaces.Call("Tunnel.TrainStartedExitingTunnel", newTrainManagerEntry)
    elseif oldTrainManagerEntry.enteringTrainState == EnteringTrainStates.finished then
        Interfaces.Call("Tunnel.TrainReservedTunnel", newTrainManagerEntry) -- Claim the exit portal as no train leaving yet.
        newTrainManagerEntry.leavingTrainState = LeavingTrainStates.pre
        newTrainManagerEntry.dummyTrain = TrainManagerFuncs.CreateDummyTrain(newTrainManagerEntry.aboveExitPortal.entity, newTrainSchedule, newTrainManagerEntry.scheduleTarget, false)
        local dummyTrainId = newTrainManagerEntry.dummyTrain.id
        newTrainManagerEntry.dummyTrainId = dummyTrainId
        global.trainManager.trainIdToManagedTrain[dummyTrainId] = {
            trainId = dummyTrainId,
            trainManagerEntry = newTrainManagerEntry,
            tunnelUsagePart = "dummyTrain"
        }
    end

    -- An approaching train (not entering) is handled by the main termianted logic and thus never reversed. The main portal signal link handles when to unlock the tunnel in the scenario of the train being on portal tracks.
    newTrainManagerEntry.leftTrain = nil
    newTrainManagerEntry.leftTrainId = nil
    -- global.trainManager.trainIdToManagedTrain[leftTrainId] - Nothing to set or nil, but included for ease of checking all global objects included in reversal.

    if oldTrainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.leaving then
        if oldTrainManagerEntry.enteringTrainState == EnteringTrainStates.finished then
            newTrainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.underground
        elseif oldTrainManagerEntry.enteringTrainState == EnteringTrainStates.entering then
            newTrainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.leaving
        end
    elseif oldTrainManagerEntry.primaryTrainPartName == PrimaryTrainPartNames.underground then
        if newTrainManagerEntry.leavingTrainCarriagesPlaced == nil then
            newTrainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.underground
        else
            newTrainManagerEntry.primaryTrainPartName = PrimaryTrainPartNames.leaving
        end
    else
        error("Unexpected reversed old managed train primaryTrainPartName: " .. oldTrainManagerEntry.primaryTrainPartName)
    end

    -- Player Container updating as required. Only scenario that needs detailed updating is when a player was in a leaving carriage that has become an entering carriage.
    newTrainManagerEntry.leavingCarriageIdToUndergroundCarriageEntity = {}
    newTrainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity = {}
    if newTrainManagerEntry.enteringTrainState == EnteringTrainStates.entering then
        -- Populate the new enteringCarriageId to undergroundCarriageEntity table from the old left carraige list. Any players in carriages still underground at this point are fine.
        for leavingCarriageId, undergroundCarriageEntity in pairs(oldTrainManagerEntry.leavingCarriageIdToUndergroundCarriageEntity) do
            newTrainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity[leavingCarriageId] = undergroundCarriageEntity
        end
    end
    PlayerContainers.On_TrainManagerReversed(oldTrainManagerEntry, newTrainManagerEntry)

    -- Update underground trains path and speed. Variable state done previously.
    local undergroundTrainEndScheduleTargetPos = Interfaces.Call("Underground.GetForwardsEndOfRailPosition", newTrainManagerEntry.tunnel.undergroundTunnel, newTrainManagerEntry.trainTravelOrientation)
    TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition(newTrainManagerEntry.undergroundTrain, undergroundTrainEndScheduleTargetPos)
    newTrainManagerEntry.undergroundTrain.speed = 0 -- We don't want to change the cached forwards state we have just generated. This was most liekly set to 0 already by the train reversing, but force it to be safe.

    TrainManager.Remote_TunnelUsageChanged(newTrainManagerEntry.id, TrainManager.TunnelUsageAction.reversedDuringUse, TrainManager.TunnelUsageChangeReason.forwardPathLost, oldTrainManagerEntry.id)

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
    -- Mirror aboveground exit signal state to underground signal so primary train (underground) honours stopping points. Primary speed limiter before leaving train has got to a significant size and escaped the portal signals as a very small leaving/dummy train will have low breaking distance and thus very short signal block reservation/detecting distances.
    -- Close the underground Exit signal if the aboveground Exit signal isn't open, otherwise open it.
    -- forceSignalState is optional and when set will be applied rather than the aboveground exit signal state.
    if forceSignalState ~= nil then
        UndergroundSetUndergroundExitSignalStateFunction(trainManagerEntry.aboveExitPortalEntrySignalOut.undergroundSignalPaired, forceSignalState)
    else
        UndergroundSetUndergroundExitSignalStateFunction(trainManagerEntry.aboveExitPortalEntrySignalOut.undergroundSignalPaired, trainManagerEntry.aboveExitPortalEntrySignalOut.entity.signal_state)
    end
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
    startApproaching = "startApproaching",
    terminated = "terminated",
    reversedDuringUse = "reversedDuringUse",
    enteringCarriageRemoved = "enteringCarriageRemoved",
    fullyEntered = "fullyEntered",
    startedLeaving = "startedLeaving",
    leavingCarriageAdded = "leavingCarriageAdded",
    fullyLeft = "fullyLeft"
}

TrainManager.TunnelUsageChangeReason = {
    reversedAfterLeft = "reversedAfterLeft",
    abortedApproach = "abortedApproach",
    forwardPathLost = "forwardPathLost",
    completedTunnelUsage = "completedTunnelUsage"
}

TrainManager.Remote_PopulateTableWithTunnelUsageEntryObjectAttributes = function(tableToPopulate, trainManagerEntryId)
    local trainManagerEntry = global.trainManager.managedTrains[trainManagerEntryId]
    tableToPopulate.tunnelUsageId = trainManagerEntryId
    if trainManagerEntry == nil then
        tableToPopulate.valid = false
    else
        -- Only return valid LuaTrains as otherwise the events are dropped by Factorio.
        tableToPopulate.valid = true
        tableToPopulate.primaryState = trainManagerEntry.primaryTrainPartName
        tableToPopulate.enteringTrain = Utils.ReturnValidLuaObjectOrNil(trainManagerEntry.enteringTrain)
        tableToPopulate.undergroundTrain = Utils.ReturnValidLuaObjectOrNil(trainManagerEntry.undergroundTrain)
        tableToPopulate.leavingTrain = Utils.ReturnValidLuaObjectOrNil(trainManagerEntry.leavingTrain)
        tableToPopulate.leftTrain = Utils.ReturnValidLuaObjectOrNil(trainManagerEntry.leftTrain)
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
    local tunnelUsageEntry = {}
    return TrainManager.Remote_PopulateTableWithTunnelUsageEntryObjectAttributes(tunnelUsageEntry, trainManagerEntryId)
end

TrainManager.Remote_GetATrainsTunnelUsageEntry = function(trainId)
    local trackedTrainIdObject = global.trainManager.trainIdToManagedTrain[trainId]
    if trackedTrainIdObject == nil then
        return nil
    end
    local trainManagerEntry = trackedTrainIdObject.trainManagerEntry
    if trainManagerEntry ~= nil then
        local tunnelUsageEntry = {}
        return TrainManager.Remote_PopulateTableWithTunnelUsageEntryObjectAttributes(tunnelUsageEntry, trainManagerEntry.id)
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
