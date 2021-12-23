-- Has the main state tracking and handling logic for Managed Trains.

local TrainManager = {}
local Utils = require("utility/utils")
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local TrainManagerPlayerContainers = require("scripts/train-manager-player-containers")
local Common = require("scripts/common")
local TunnelSignalDirection, TunnelUsageChangeReason, TunnelUsageParts, PrimaryTrainState, TunnelUsageAction = Common.TunnelSignalDirection, Common.TunnelUsageChangeReason, Common.TunnelUsageParts, Common.PrimaryTrainState, Common.TunnelUsageAction
local TrainManagerRemote = require("scripts/train-manager-remote")

---@class ManagedTrain
---@field id Id @uniqiue id of this managed train passing through the tunnel.
---@field primaryTrainPartName PrimaryTrainState
---
---@field enteringTrain LuaTrain
---@field enteringTrainId Id @The enteringTrain LuaTrain id.
---@field enteringTrainForwards boolean @If the train is moving forwards or backwards from its viewpoint.
---
---@field undergroundTrainHasPlayersRiding boolean @if there are players riding in the underground train.
---@field tempEnteringSpeed double @the speed the train was going when entering and we maintain at for whole tunnel approach and transversal in intiial code version.
---@field traversalTotalTicks int @the time in ticks it will take for the train to have travelled from the tunnel entering point to when we set it as leaving.
---@field traversalStartingTick int @the tick the train entered the tunnel.
---@field traversalArrivalTick int @the tick the train reaches the far end of the tunnel and is restarted.
---
---@field leavingTrain LuaTrain @The train created leaving the tunnel on the world surface.
---@field leavingTrainId Id @The LuaTrain ID of the leaving train.
---
---@field portalTrackTrain LuaTrain @The train thats on the portal track and reserved the tunnel.
---@field portalTrackTrainId Id @The LuaTrain ID of the portalTrackTrain.
---@field portalTrackTrainInitiallyForwards boolean @If the train is moving forwards or backwards from its viewpoint when it initially triggers the portal track usage detection.
---@field portalTrackTrainBySignal boolean @If we are tracking the train by the entrance entry signal or if we haven't got to that point yet.
---
---@field dummyTrain LuaTrain @The dummy train used to keep the train stop reservation alive
---@field dummyTrainId Id @The LuaTrain ID of the dummy train.
---@field trainTravelDirection defines.direction @The cardinal direction the train is heading in. Uses the more granular defines.direction to allow natural comparison to Factorio entity direction attributes.
---@field trainTravelOrientation TrainTravelOrientation @The orientation of the trainTravelDirection.
---@field targetTrainStop LuaEntity @The target train stop entity of this train, needed in case the path gets lost as we only have the station name then. Used when checking bad train states and reversing trains.
---
---@field surface LuaSurface @The main world surface that this managed train is on.
---@field entrancePortal Portal @The portal global object of the entrance portal for this tunnel usage instance.
---@field entrancePortalTransitionSignal PortalTransitionSignal @The transitionSignal global object of the rail signal at the transition point of the entrance portal track (forced closed signal).
---@field exitPortal Portal @Ref to the portal global object of the exit portal for this tunnel usage instance.
---@field exitPortalTransitionSignal PortalTransitionSignal @Ref to the transitionSignal global object of the rail signal at the end of the exit portal track (forced closed signal).
---@field exitPortalEntrySignalOut PortalEntrySignal @Ref to the transitionSignal global object on the rail signal at the entrance of the exit portal for leaving trains.
---@field tunnel Tunnel @Ref to the global tunnel object.

---@class TrainLeadCarriageCache
---@field trainForwards boolean @If the train was forwards when the cache was last updated.
---@field carriage LuaEntity @Cached ref to the lead carriage entity.

---@alias TrainTravelOrientation "0"|"0.25"|"0.5"|"0.75"

---@class TrainIdToManagedTrain
---@field trainId Id @the LuaTrain id, used as Id.
---@field managedTrain ManagedTrain
---@field tunnelUsagePart TunnelUsageParts

TrainManager.CreateGlobals = function()
    global.trainManager = global.trainManager or {}
    global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId or 1 ---@type Id
    global.trainManager.managedTrains = global.trainManager.managedTrains or {} ---@type table<Id, ManagedTrain>
    global.trainManager.trainIdToManagedTrain = global.trainManager.trainIdToManagedTrain or {} ---@type table<Id, TrainIdToManagedTrain> @Used to track trainIds to managedTrainEntries. When the trainId is detected as changing via event the global object is updated to stay up to date.
end

TrainManager.OnLoad = function()
    Interfaces.RegisterInterface(
        "TrainManager.RegisterTrainApproachingPortalSignal",
        function(...)
            if global.debugRelease then
                Logging.RunFunctionAndCatchErrors(TrainManager.RegisterTrainApproachingPortalSignal, ...)
            else
                TrainManager.RegisterTrainApproachingPortalSignal(...)
            end
        end
    )
    Interfaces.RegisterInterface(
        "TrainManager.RegisterTrainOnPortalTrack",
        function(...)
            if global.debugRelease then
                Logging.RunFunctionAndCatchErrors(TrainManager.RegisterTrainOnPortalTrack, ...)
            else
                TrainManager.RegisterTrainOnPortalTrack(...)
            end
        end
    )
    Interfaces.RegisterInterface(
        "TrainManager.TrainEnterTunnel",
        function(...)
            if global.debugRelease then
                Logging.RunFunctionAndCatchErrors(TrainManager.TrainEnterTunnel, ...)
            else
                TrainManager.TrainEnterTunnel(...)
            end
        end
    )
    Events.RegisterHandlerEvent(defines.events.on_tick, "TrainManager.ProcessManagedTrains", TrainManager.ProcessManagedTrains)
    Interfaces.RegisterInterface("TrainManager.On_TunnelRemoved", TrainManager.On_TunnelRemoved)
    Interfaces.RegisterInterface("TrainManager.On_PortalReplaced", TrainManager.On_PortalReplaced)
    Interfaces.RegisterInterface("TrainManager.GetTrainIdsManagedTrainDetails", TrainManager.GetTrainIdsManagedTrainDetails)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainUndergroundCompleted_Scheduled", TrainManager.TrainUndergroundCompleted_Scheduled)
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--------------------          CORE LOGIC FUNCTIONS          -------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

---@param enteringTrain LuaTrain
---@param entrancePortalTransitionSignal PortalTransitionSignal
TrainManager.RegisterTrainApproachingPortalSignal = function(enteringTrain, entrancePortalTransitionSignal)
    -- Check if this train is already using the tunnel in some way.
    -- OVERHAUL - must check train length isn't more than tunnel allowed max length. If it is reject.
    local existingTrainIDTrackedObject = global.trainManager.trainIdToManagedTrain[enteringTrain.id]
    local replacedManagedTrain, upgradeManagedTrain = nil, nil
    if existingTrainIDTrackedObject ~= nil then
        if existingTrainIDTrackedObject.tunnelUsagePart == TunnelUsageParts.leavingTrain then
            -- Train was in left state, but is now re-entering. Happens if the train doesn't fully leave the exit portal signal block before coming back in.
            replacedManagedTrain = existingTrainIDTrackedObject.managedTrain
            -- Terminate the old tunnel reservation, but don't release the tunnel as we will just overwrite its user.
            TrainManager.TerminateTunnelTrip(replacedManagedTrain, TunnelUsageChangeReason.reversedAfterLeft, false)
        elseif existingTrainIDTrackedObject.tunnelUsagePart == TunnelUsageParts.portalTrackTrain then
            -- OVERHAUL - is this removal and re-creation needed, or can we just overwrite some data and let it continue. Seems quite wasteful.
            -- Train was using the portal track and is now entering the tunnel.
            upgradeManagedTrain = existingTrainIDTrackedObject.managedTrain
            -- Just tidy up the managedTrain's entities its related globals before the new one overwrites it. No tunnel trip to be dealt with.
            TrainManager.RemoveManagedTrainEntry(upgradeManagedTrain)
        else
            error("Unsupported situation")
        end
    end

    local managedTrain = TrainManager.CreateManagedTrainObject(enteringTrain, entrancePortalTransitionSignal, true, upgradeManagedTrain)
    managedTrain.primaryTrainPartName = PrimaryTrainState.approaching
    Interfaces.Call("Tunnel.TrainReservedTunnel", managedTrain)
    if replacedManagedTrain ~= nil then
        -- Include in the new train approaching event the old leavingTrain entry id that has been stopped.
        TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.startApproaching, nil, replacedManagedTrain.id)
    else
        TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.startApproaching)
    end
end

--- Used when a train is claiming a portals track (and thus the tunnel), but not planning to actively use the tunnel yet. Is like the opposite to a leavingTrain monitoring. Only reached by pathing trains that enter the portal track before their breaking distance is the stopping signal or when driven manually.
---@param trainOnPortalTrack LuaTrain
---@param portal Portal
TrainManager.RegisterTrainOnPortalTrack = function(trainOnPortalTrack, portal)
    -- OVERHAUL - must check train length isn't more than tunnel allowed max length. If it is reject.
    local managedTrain = TrainManager.CreateManagedTrainObject(trainOnPortalTrack, portal.transitionSignals[TunnelSignalDirection.inSignal], false)
    managedTrain.primaryTrainPartName = PrimaryTrainState.portalTrack
    TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.onPortalTrack)
end

TrainManager.ProcessManagedTrains = function(eventData)
    local currentTick = eventData.tick

    -- Loop over each train and process it.
    for _, managedTrain in pairs(global.trainManager.managedTrains) do
        if global.debugRelease then
            Logging.RunFunctionAndCatchErrors(TrainManager.ProcessManagedTrain, managedTrain, currentTick)
        else
            TrainManager.ProcessManagedTrain(managedTrain, currentTick)
        end
    end

    TrainManagerRemote.ProcessTicksEvents()
end

---@param managedTrain ManagedTrain
TrainManager.ProcessManagedTrain = function(managedTrain, currentTick)
    -- We only need to handle one of these per tick as the transition between these states is either triggered externally or requires no immediate checking of the next state in the same tick as the transition.
    -- These are ordered on frequency of use to reduce per tick check costs.
    if managedTrain.primaryTrainPartName == PrimaryTrainState.portalTrack then
        -- Keep on running until either the train triggers the Transition signal or the train leaves the portal tracks.
        TrainManager.TrainOnPortalTrackOngoing(managedTrain)
        return
    elseif managedTrain.primaryTrainPartName == PrimaryTrainState.approaching then
        -- Check whether the train is still approaching the tunnel portal as its not committed yet and so can turn away.
        if managedTrain.enteringTrain.state ~= defines.train_state.arrive_signal or managedTrain.enteringTrain.signal ~= managedTrain.entrancePortalTransitionSignal.entity then
            TrainManager.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.abortedApproach)
            return
        else
            TrainManager.TrainApproachingOngoing(managedTrain)
        end
    elseif managedTrain.primaryTrainPartName == PrimaryTrainState.underground then
        if managedTrain.undergroundTrainHasPlayersRiding then
            -- Only reason we have to update per tick while travelling underground currently.
            TrainManager.TrainUndergroundOngoing(managedTrain, currentTick)
        else
            -- Nothing to do, the arrival is scheduled.
            return
        end
    elseif managedTrain.primaryTrainPartName == PrimaryTrainState.leaving then
        TrainManager.TrainLeavingOngoing(managedTrain)
    end
end

---@param managedTrain ManagedTrain
TrainManager.TrainApproachingOngoing = function(managedTrain)
    local enteringTrain = managedTrain.enteringTrain ---@type LuaTrain
    -- This won't keep the train exactly at this speed as it will try and brake its max amount each tick off this speed. But will stay reasonably close to its desired speed.
    enteringTrain.speed = managedTrain.tempEnteringSpeed -- OVERHAUL - this should be calculated programatically.

    -- Theres a transition portal track detector to flag when a train reaches the end of the portal track and is ready to enter the tunnel.
end

---@param managedTrain ManagedTrain
TrainManager.TrainEnterTunnel = function(managedTrain)
    local enteringTrain = managedTrain.enteringTrain
    local enteringTrain_carriages = enteringTrain.carriages

    -- Clone the entering train to the exit position.
    local leavingTrain = TrainManager.CloneEnteringTrainToExit(managedTrain, enteringTrain_carriages)
    local leavingTrainId = leavingTrain.id
    global.trainManager.trainIdToManagedTrain[leavingTrainId] = {
        trainId = leavingTrainId,
        managedTrain = managedTrain,
        tunnelUsagePart = TunnelUsageParts.leavingTrain
    }
    managedTrain.leavingTrain = leavingTrain
    managedTrain.leavingTrainId = leavingTrainId

    -- OVERHAUL staying with Dummy train usage for now, notes on the CreateDummyTrain().
    -- Set up DummyTrain to maintain station requests.
    managedTrain.primaryTrainPartName = PrimaryTrainState.underground
    managedTrain.targetTrainStop = enteringTrain.path_end_stop
    managedTrain.dummyTrain = TrainManager.CreateDummyTrain(managedTrain.exitPortal, enteringTrain.schedule, managedTrain.targetTrainStop, false)
    local dummyTrainId = managedTrain.dummyTrain.id
    managedTrain.dummyTrainId = dummyTrainId
    global.trainManager.trainIdToManagedTrain[dummyTrainId] = {
        trainId = dummyTrainId,
        managedTrain = managedTrain,
        tunnelUsagePart = TunnelUsageParts.dummyTrain
    }

    -- Work out how long it will take to reach the far end at current speed from leading carriages current forward tip.
    local travelDistance = managedTrain.tunnel.underground.tilesLength
    -- hard coded portal area values for now - Just assume the entering train was at the detector entity. Measured from current setup so good enough for now.
    -- TODO: need to work out distances properly now with modular portals.
    travelDistance = travelDistance + 71.5
    -- Just assume the speed stays constant at the entering speed for the whole duration for now.
    managedTrain.traversalTotalTicks = travelDistance / math.abs(managedTrain.tempEnteringSpeed)
    managedTrain.traversalStartingTick = game.tick
    managedTrain.traversalArrivalTick = managedTrain.traversalStartingTick + math.ceil(managedTrain.traversalTotalTicks)

    -- Destroy entering train's entities as we have finished with them.
    for _, carriage in pairs(enteringTrain_carriages) do
        carriage.destroy()
    end
    global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrainId] = nil
    managedTrain.enteringTrain = nil
    managedTrain.enteringTrainId = nil
    --TODO: for 1 tick the entrance entry signal goes to green as theres no entering train there and the circuit controlled source signal from the leaving exit signal takes a tick to update. I think we need to put in an entity in the entrance portal earlier to prevent this. It shows on the PathfinderWeightings test. This was an issue before as well, the timing just never triggered in the test. If we decide to commit the train to using the tunnel once it triggers the entry train detector then we can clone the train 1 tick before we destroy the old train, thus resolving this in passing.

    -- Complete the state transition.
    Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", managedTrain)
    TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.entered)

    -- If theres no player in the train we can just forward schedule the arrival. If there is a player then the tick check will pick this up and deal with it.
    if not managedTrain.undergroundTrainHasPlayersRiding then
        EventScheduler.ScheduleEventOnce(managedTrain.traversalArrivalTick, "TrainManager.TrainUndergroundCompleted_Scheduled", managedTrain.id, {managedTrain = managedTrain})
    end
end

-- Only need to track an ongoing underground train if there's a player riding in the train and we need to update their position each tick.
---@param managedTrain ManagedTrain
---@param currentTick Tick
TrainManager.TrainUndergroundOngoing = function(managedTrain, currentTick)
    if currentTick < managedTrain.traversalArrivalTick then
        -- Train still waiting on its arrival time.
        if managedTrain.undergroundTrainHasPlayersRiding then
            TrainManagerPlayerContainers.MoveATrainsPlayerContainers(managedTrain)
        end
    else
        -- Train arrival time has come.
        TrainManager.TrainUndergroundCompleted(managedTrain)
    end
end

---@param event ScheduledEvent
TrainManager.TrainUndergroundCompleted_Scheduled = function(event)
    local managedTrain = event.data.managedTrain
    if managedTrain == nil or managedTrain.primaryTrainPartName ~= PrimaryTrainState.underground then
        -- Something has happened to the train/tunnel being managed while this has been scheduled, so just give up.
        return
    end
    TrainManager.TrainUndergroundCompleted(managedTrain)
end

---@param managedTrain ManagedTrain
TrainManager.TrainUndergroundCompleted = function(managedTrain)
    -- Train has arrived and should be activated.
    local leavingTrain = managedTrain.leavingTrain
    -- Set the speed, then set to automatic. If the speed becomes 0 then the train is facing backwards to what we expect, so reverse the speed. As the trian has 0 speed we can't tell its facing.
    leavingTrain.speed = managedTrain.tempEnteringSpeed
    TrainManager.SetTrainToAuto(leavingTrain, managedTrain.dummyTrain.path_end_stop)
    if leavingTrain.speed == 0 then
        leavingTrain.speed = -1 * managedTrain.tempEnteringSpeed
    end

    -- Check the target isn't part of this tunnel once
    TrainManager.UpdateScheduleForTargetRailBeingTunnelRail(managedTrain, leavingTrain)

    if managedTrain.undergroundTrainHasPlayersRiding then
        TrainManagerPlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage(nil, nil)
    end

    -- Tidy up for the leaving train and propigate state updates.
    TrainManager.DestroyDummyTrain(managedTrain)
    managedTrain.primaryTrainPartName = PrimaryTrainState.leaving
    TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.leaving)
end

---@param managedTrain ManagedTrain
TrainManager.TrainLeavingOngoing = function(managedTrain)
    -- Track the tunnel's exit portal entry rail signal so we can mark the tunnel as open for the next train when the current train has left. We are assuming that no train gets in to the portal rail segment before our main train gets out. This is far more UPS effecient than checking the trains last carriage and seeing if its rear rail signal is our portal entrance one. Must be closed rather than reserved as this is how we cleanly detect it having left (avoids any overlap with other train reserving it same tick this train leaves it).
    local exitPortalEntrySignalEntity = managedTrain.exitPortal.entrySignals[TunnelSignalDirection.inSignal].entity
    if exitPortalEntrySignalEntity.signal_state ~= defines.signal_state.closed then
        -- No train in the block so our one must have left.
        global.trainManager.trainIdToManagedTrain[managedTrain.leavingTrainId] = nil
        managedTrain.leavingTrain = nil
        managedTrain.leavingTrainId = nil
        TrainManager.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.completedTunnelUsage)
    end
end

-- OVERHAUL - Once the entry train detector is triggered do we want to commit the train to enter the tunnel rather than have to track it and use UPS?  Ignore manual driving for now, just worry about scheduled trains and if their path/station changes during approach. Uses a small fraction of per train tunnel usage UPS cost.
-- This tracks a train once it triggers the entry train detector if it hasn't reserved the Transition signal of the Entrance portal. It is to detect and then handle trains that enter the portal track and then turn around and leave. Could be caused by either manaul driving or from an extreme edge case of track removal ahead as the train is entering and there being a path backwards available.
---@param managedTrain ManagedTrain
TrainManager.TrainOnPortalTrackOngoing = function(managedTrain)
    local entrancePortalEntrySignalEntity = managedTrain.entrancePortal.entrySignals[TunnelSignalDirection.inSignal].entity

    if not managedTrain.portalTrackTrainBySignal then
        -- Not tracking by singal yet. Initially we have to track the trains speed (direction) to confirm that its still entering until it triggers the Entry signal. Tracking by speed is less UPS effecient than using the entry signal.
        if entrancePortalEntrySignalEntity.signal_state == defines.signal_state.closed then
            -- The signal state is now closed, so we can start tracking by signal in the future. Must be closed rather than reserved as this is how we cleanly detect it having left (avoids any overlap with other train reserving it same tick this train leaves it).
            managedTrain.portalTrackTrainBySignal = true
        else
            -- Continue to track by speed until we can start tracking by signal.
            local trainSpeed = managedTrain.portalTrackTrain.speed
            if trainSpeed == 0 then
                -- If the train isn't moving we don't need to check for any state change this tick.
                return
            end
            local trainForwards = trainSpeed > 0
            if trainForwards ~= managedTrain.portalTrackTrainInitiallyForwards then
                -- Train is moving away from the portal track. Try to put the detection entity back to work out if the train has left the portal tracks.
                local placedDetectionEntity = Interfaces.Call("TunnelPortals.AddEnteringTrainUsageDetectionEntityToPortal", managedTrain.entrancePortal, false)
                if placedDetectionEntity then
                    TrainManager.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.portalTrackReleased)
                end
            end
        end
    else
        -- Track the tunnel's entrance portal entry rail signal so we can mark the tunnel as open for the next train if the current train leaves the portal track. Should the train trigger tunnel usage via the Transition signal this managed train entry will be terminated by that event. We are assuming that no train gets in to the portal rail segment before our main train gets out. This is far more UPS effecient than checking the trains last carriage and seeing if its rear rail signal is our portal entrance one.
        if entrancePortalEntrySignalEntity.signal_state ~= defines.signal_state.closed then
            -- No train in the block so our one must have left.
            TrainManager.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.portalTrackReleased)
        end
    end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-----------------------          MINOR FUNCTIONS          ---------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

--- Update the passed in train schedule if the train is currently heading for a tunnel or portal rail. If so change the target rail to be the end of the portal. Avoids the train infinite loop pathing through the tunnel trying to reach a tunnel or portal rail it never can.
---@param managedTrain ManagedTrain
---@param train LuaTrain
TrainManager.UpdateScheduleForTargetRailBeingTunnelRail = function(managedTrain, train)
    local targetTrainStop, targetRail = train.path_end_stop, train.path_end_rail
    if targetTrainStop == nil and targetRail ~= nil then
        local targetRail_name = targetRail.name
        if targetRail_name == "railway_tunnel-invisible_rail-on_map_tunnel" or targetRail_name == "railway_tunnel-portal_rail-on_map" then
            -- The target rail is the type used by a portal/segment for underground rail, so check if it belongs to the just used tunnel.
            local targetRail_unitNumber = targetRail.unit_number
            if managedTrain.tunnel.tunnelRailEntities[targetRail_unitNumber] ~= nil or managedTrain.tunnel.portalRailEntities[targetRail_unitNumber] ~= nil then
                -- The target rail is part of the currently used tunnel, so update the schedule rail to be the one at the end of the portal and just leave the train to do its thing from there.
                local schedule = train.schedule
                local currentScheduleRecord = schedule.records[schedule.current]
                local exitPortalEntryRail = managedTrain.exitPortalEntrySignalOut.entity.get_connected_rails()[1]
                currentScheduleRecord.rail = exitPortalEntryRail
                schedule.records[schedule.current] = currentScheduleRecord
                train.schedule = schedule
            end
        end
    end
end

---@param managedTrain ManagedTrain
TrainManager.DestroyDummyTrain = function(managedTrain)
    -- Dummy trains are never passed between trainManagerEntries, so don't have to check the global trainIdToManagedTrain's managedTrain id.
    if managedTrain.dummyTrain ~= nil and managedTrain.dummyTrain.valid then
        global.trainManager.trainIdToManagedTrain[managedTrain.dummyTrainId] = nil
        for _, carriage in pairs(managedTrain.dummyTrain.carriages) do
            carriage.destroy()
        end
        managedTrain.dummyTrain, managedTrain.dummyTrainId = nil, nil
    elseif managedTrain.dummyTrainId ~= nil then
        global.trainManager.trainIdToManagedTrain[managedTrain.dummyTrainId] = nil
    end
end

---@param tunnelRemoved Tunnel
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

            if managedTrain.undergroundTrainHasPlayersRiding then
                TrainManagerPlayerContainers.On_TunnelRemoved(managedTrain)
            end

            TrainManager.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.tunnelRemoved)
        end
    end
end

---@param train LuaTrain
---@param entrancePortalTransitionSignal PortalTransitionSignal
---@param traversingTunnel boolean
---@param upgradeManagedTrain ManagedTrain @An existing ManagedTrain object that is being updated/overwritten with fresh data.
---@return ManagedTrain
TrainManager.CreateManagedTrainObject = function(train, entrancePortalTransitionSignal, traversingTunnel, upgradeManagedTrain)
    ---@typelist Id, double
    local trainId, trainSpeed = train.id, train.speed
    local managedTrainId
    if upgradeManagedTrain then
        managedTrainId = upgradeManagedTrain.id
    else
        managedTrainId = global.trainManager.nextManagedTrainId
        global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId + 1 ---@type Id
    end
    ---@type ManagedTrain
    local managedTrain = {
        id = managedTrainId,
        entrancePortalTransitionSignal = entrancePortalTransitionSignal,
        entrancePortal = entrancePortalTransitionSignal.portal,
        tunnel = entrancePortalTransitionSignal.portal.tunnel,
        trainTravelDirection = Utils.LoopDirectionValue(entrancePortalTransitionSignal.entity.direction + 4),
        tempEnteringSpeed = trainSpeed, -- TODO: this is temp and will need calculating at a later point properly.
        undergroundTrainHasPlayersRiding = false
    }
    if trainSpeed == 0 then
        error("TrainManager.CreateManagedTrainObject() doesn't support 0 speed\ntrain id: " .. trainId)
    end
    local trainForwards = trainSpeed > 0

    if traversingTunnel then
        -- Normal tunnel usage.
        managedTrain.enteringTrain = train
        managedTrain.enteringTrainId = trainId

        global.trainManager.trainIdToManagedTrain[trainId] = {
            trainId = trainId,
            managedTrain = managedTrain,
            tunnelUsagePart = TunnelUsageParts.enteringTrain
        }
        managedTrain.enteringTrainForwards = trainForwards
    else
        -- Reserved tunnel, but not using it.
        managedTrain.portalTrackTrain = train
        managedTrain.portalTrackTrainId = trainId
        global.trainManager.trainIdToManagedTrain[trainId] = {
            trainId = trainId,
            managedTrain = managedTrain,
            tunnelUsagePart = TunnelUsageParts.portalTrackTrain
        }
        managedTrain.portalTrackTrainInitiallyForwards = trainForwards
        managedTrain.portalTrackTrainBySignal = false
    end

    global.trainManager.managedTrains[managedTrain.id] = managedTrain
    managedTrain.surface = managedTrain.tunnel.surface
    managedTrain.trainTravelOrientation = Utils.DirectionToOrientation(managedTrain.trainTravelDirection)

    -- Get the exit transition signal on the other portal so we know when to bring the train back in.
    for _, portal in pairs(managedTrain.tunnel.portals) do
        if portal.id ~= entrancePortalTransitionSignal.portal.id then
            managedTrain.exitPortalTransitionSignal = portal.transitionSignals[TunnelSignalDirection.outSignal]
            managedTrain.exitPortal = portal
            managedTrain.exitPortalEntrySignalOut = portal.entrySignals[TunnelSignalDirection.outSignal]
        end
    end

    return managedTrain
end

---@param tunnel Tunnel
---@param newPortal Portal
TrainManager.On_PortalReplaced = function(tunnel, newPortal)
    if tunnel == nil then
        return
    end
    -- Updated the cached portal object reference as they have bene recreated.
    for _, managedTrain in pairs(global.trainManager.managedTrains) do
        if managedTrain.tunnel.id == tunnel.id then
            -- Only entity invalid is the portal entity reference itself. None of the portal's signal entities or objects are affected. So can use the signal entities to identify which local reference Entrance/Exit this changed portal was before.
            if newPortal.transitionSignals[managedTrain.entrancePortalTransitionSignal.direction].id == managedTrain.entrancePortalTransitionSignal.id then
                -- Is entrance portal of this tunnel usage.
                managedTrain.entrancePortal = newPortal
            elseif newPortal.transitionSignals[managedTrain.exitPortalTransitionSignal.direction].id == managedTrain.exitPortalTransitionSignal.id then
                -- Is exit portal of this tunnel usage.
                managedTrain.exitPortal = newPortal
            else
                error("Portal replaced for tunnel and used by managedTrain, but transitionSignal not matched\n tunnel id: " .. tunnel.id .. "\nmanagedTrain id: " .. managedTrain.id .. "\nnewPortal id: " .. newPortal.id)
            end
        end
    end
end

---@param managedTrain ManagedTrain
---@param tunnelUsageChangeReason TunnelUsageChangeReason
---@param releaseTunnel boolean|null @If nil then tunnel is released (true).
TrainManager.TerminateTunnelTrip = function(managedTrain, tunnelUsageChangeReason, releaseTunnel)
    if managedTrain.undergroundTrainHasPlayersRiding then
        TrainManagerPlayerContainers.On_TerminateTunnelTrip(managedTrain)
    end
    TrainManager.RemoveManagedTrainEntry(managedTrain)

    if releaseTunnel == nil or releaseTunnel == true then
        Interfaces.Call("Tunnel.TrainReleasedTunnel", managedTrain)
    end
    TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.terminated, tunnelUsageChangeReason)
end

---@param managedTrain ManagedTrain
TrainManager.RemoveManagedTrainEntry = function(managedTrain)
    -- Only remove the global if it points to this managedTrain. The reversal process can have made the enteringTrain references invalid, and MAY have overwritten them, so check before removing.
    if managedTrain.enteringTrain and managedTrain.enteringTrain.valid and global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrain.id] and global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrain.id].managedTrain.id == managedTrain.id then
        global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrain.id] = nil
    elseif managedTrain.enteringTrainId and global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrainId] and global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrainId].managedTrain.id == managedTrain.id then
        global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrain.id] = nil
    end

    if managedTrain.leavingTrain and managedTrain.leavingTrain.valid and global.trainManager.trainIdToManagedTrain[managedTrain.leavingTrain.id] and global.trainManager.trainIdToManagedTrain[managedTrain.leavingTrain.id].managedTrain.id == managedTrain.id then
        global.trainManager.trainIdToManagedTrain[managedTrain.leavingTrain.id] = nil
    elseif managedTrain.leavingTrainId and global.trainManager.trainIdToManagedTrain[managedTrain.leavingTrainId] and global.trainManager.trainIdToManagedTrain[managedTrain.leavingTrainId].managedTrain.id == managedTrain.id then
        global.trainManager.trainIdToManagedTrain[managedTrain.leavingTrainId] = nil
    end

    TrainManager.DestroyDummyTrain(managedTrain)

    if managedTrain.portalTrackTrain and managedTrain.portalTrackTrain.valid and global.trainManager.trainIdToManagedTrain[managedTrain.portalTrackTrain.id] and global.trainManager.trainIdToManagedTrain[managedTrain.portalTrackTrain.id].managedTrain.id == managedTrain.id then
        global.trainManager.trainIdToManagedTrain[managedTrain.portalTrackTrain.id] = nil
    elseif managedTrain.portalTrackTrainId and global.trainManager.trainIdToManagedTrain[managedTrain.portalTrackTrainId] and global.trainManager.trainIdToManagedTrain[managedTrain.portalTrackTrainId].managedTrain.id == managedTrain.id then
        global.trainManager.trainIdToManagedTrain[managedTrain.portalTrackTrainId] = nil
    end

    -- Set all states to finished so that the TrainManager.ProcessManagedTrains() loop won't execute anything further this tick.
    managedTrain.primaryTrainPartName = PrimaryTrainState.finished

    global.trainManager.managedTrains[managedTrain.id] = nil
end

---@param trainId Id
---@return ManagedTrain
TrainManager.GetTrainIdsManagedTrainDetails = function(trainId)
    return global.trainManager.trainIdToManagedTrain[trainId]
end

-- Clone the entering train to the front of the exit portal. This will minimise any tracking of the train when leaving.
---@param managedTrain ManagedTrain
---@param enteringTrain_carriages LuaEntity[]
---@return LuaTrain @Leaving train
TrainManager.CloneEnteringTrainToExit = function(managedTrain, enteringTrain_carriages)
    -- This currently assumes the portals are in a straight line of each other and that the portal areas are straight.
    local enteringTrain, trainCarriagesForwardOrientation = managedTrain.enteringTrain, managedTrain.trainTravelOrientation
    local targetSurface = managedTrain.surface
    if not managedTrain.enteringTrainForwards then
        trainCarriagesForwardOrientation = Utils.LoopOrientationValue(trainCarriagesForwardOrientation + 0.5)
    end

    -- Get the position for the front of the lead carriage; 2.5 tiles back from the entry signal. This means the front 3 tiles of the portal area graphics can show the train, with further back needing to be covered to hide the train graphics.
    local exitPortalEntrySignalOutPosition = managedTrain.exitPortalEntrySignalOut.entity.position
    local trainFrontOffsetFromSignal = Utils.RotatePositionAround0(managedTrain.trainTravelOrientation, {x = -1.5, y = 2.5})
    local nextCarriagePosition = Utils.ApplyOffsetToPosition(exitPortalEntrySignalOutPosition, trainFrontOffsetFromSignal)

    -- Work out which way to iterate down the train's carriage array. Starting with the lead carriage.
    local minCarriageIndex, maxCarriageIndex, carriageIterator
    local enteringTrainSpeed = enteringTrain.speed
    if (enteringTrainSpeed > 0) then
        minCarriageIndex, maxCarriageIndex, carriageIterator = 1, #enteringTrain_carriages, 1
    elseif (enteringTrainSpeed < 0) then
        minCarriageIndex, maxCarriageIndex, carriageIterator = #enteringTrain_carriages, 1, -1
    else
        error("TrainManager.CopyEnteringTrainUnderground() doesn't support 0 speed refTrain.\nrefTrain id: " .. enteringTrain.id)
    end

    --Iterate over the carriages and clone them.
    local refCarriage, refCarriage_name
    local lastPlacedCarriage, lastPlacedCarriage_name
    for currentSourceTrainCarriageIndex = minCarriageIndex, maxCarriageIndex, carriageIterator do
        refCarriage = enteringTrain_carriages[currentSourceTrainCarriageIndex]
        refCarriage_name = refCarriage.name
        local carriageOrientation = trainCarriagesForwardOrientation
        if refCarriage.speed ~= enteringTrainSpeed then
            carriageOrientation = Utils.LoopOrientationValue(carriageOrientation + 0.5)
        end

        nextCarriagePosition = TrainManager.GetNextCarriagePlacementPosition(managedTrain.trainTravelOrientation, nextCarriagePosition, lastPlacedCarriage_name, refCarriage_name)
        lastPlacedCarriage = TrainManager.CopyCarriage(targetSurface, refCarriage, nextCarriagePosition, nil, carriageOrientation)
        lastPlacedCarriage_name = refCarriage_name

        -- Handle any players in the train carriage.
        local driver = refCarriage.get_driver()
        if driver ~= nil then
            managedTrain.undergroundTrainHasPlayersRiding = true
            TrainManagerPlayerContainers.PlayerInCarriageEnteringTunnel(managedTrain, driver, lastPlacedCarriage)
        end
    end

    return lastPlacedCarriage.train
end

---@param targetSurface LuaSurface
---@param refCarriage LuaEntity
---@param newPosition Position
---@param safeCarriageFlipPosition Position @Not used until we need to support corners.
---@param requiredOrientation RealOrientation @Not used until we need to support corners.
---@return LuaEntity
TrainManager.CopyCarriage = function(targetSurface, refCarriage, newPosition, safeCarriageFlipPosition, requiredOrientation)
    -- OVERHAUL - until we add support for corners or non straight tunnel portal areas we never need to flip a carraige.
    local sourceCarriage = refCarriage
    if 1 == 0 then
        game.print(safeCarriageFlipPosition, requiredOrientation)
    end

    -- Work out if we will need to flip the cloned carriage or not.
    --[[local orientationDif = math.abs(refCarriage.orientation - requiredOrientation)
    local haveToFlipCarriage = false
    if orientationDif > 0.25 and orientationDif < 0.75 then
        -- Will need to flip the carriage.
        haveToFlipCarriage = true
    elseif orientationDif == 0.25 or orientationDif == 0.75 then
        -- May end up the correct way, depending on what rotation we want. Factorio rotates positive orientation when equally close.
        if Utils.LoopOrientationValue(refCarriage.orientation + 0.25) ~= requiredOrientation then
            -- After a positive rounding the carriage isn't going to be facing the right way.
            haveToFlipCarriage = true
        end
    end

    -- Create an intial clone of the carriage away from the train, flip its orientation, then clone the carriage to the right place. Saves having to disconnect the train and reconnect it.
    ---@typelist LuaEntity, LuaEntity
    local tempCarriage, sourceCarriage
    if haveToFlipCarriage then
        tempCarriage = refCarriage.clone {position = safeCarriageFlipPosition, surface = targetSurface, create_build_effect_smoke = false}
        if tempCarriage.orientation == requiredOrientation then
            error("underground carriage flipping not needed, but predicted. \nrequiredOrientation: " .. tostring(requiredOrientation) .. "\ntempCarriage.orientation: " .. tostring(tempCarriage.orientation) .. "\nrefCarriage.orientation: " .. tostring(refCarriage.orientation))
        end
        tempCarriage.rotate()
        sourceCarriage = tempCarriage
    else
        sourceCarriage = refCarriage
    end--]]
    local placedCarriage = sourceCarriage.clone {position = newPosition, surface = targetSurface, create_build_effect_smoke = false}
    if placedCarriage == nil then
        error("failed to clone carriage:" .. "\nsurface name: " .. targetSurface.name .. "\nposition: " .. Logging.PositionToString(newPosition) .. "\nsource carriage unit_number: " .. refCarriage.unit_number)
    end

    --[[if haveToFlipCarriage then
        tempCarriage.destroy()
    end
    if placedCarriage.orientation ~= requiredOrientation then
        error("placed underground carriage isn't correct orientation.\nrequiredOrientation: " .. tostring(requiredOrientation) .. "\nplacedCarriage.orientation: " .. tostring(placedCarriage.orientation) .. "\nrefCarriage.orientation: " .. tostring(refCarriage.orientation))
    end]]
    return placedCarriage
end

---@param trainOrientation RealOrientation
---@param lastPosition Position
---@param lastCarriageEntityName string
---@param nextCarriageEntityName string
---@return Position
TrainManager.GetNextCarriagePlacementPosition = function(trainOrientation, lastPosition, lastCarriageEntityName, nextCarriageEntityName)
    --This assumes the next carriage is in a striaght direction from the previous carriage.
    local carriagesDistance = Common.GetCarriagePlacementDistance(nextCarriageEntityName)
    if lastCarriageEntityName ~= nil then
        carriagesDistance = carriagesDistance + Common.GetCarriagePlacementDistance(lastCarriageEntityName)
    end
    local nextCarriageOffset = Utils.RotatePositionAround0(trainOrientation, {x = 0, y = carriagesDistance})
    return Utils.ApplyOffsetToPosition(lastPosition, nextCarriageOffset)
end

-- Dummy train keeps the train stop reservation as it has near 0 power and so while actively moving, it will never actaully move any distance.
-- OVERHAUL - REMOVAL OF DUMMY TRAIN MUST BE DONE IN OWN BRANCH TO ENABLE ROLLBACK - possible alternative is to add a carriage to the cloned train that has max speed of 0 (or max friction force and weight). This should mean the real train can replace the dummy train. This would mean that the leaving train uses fuel for the duration of the tunnel trip and so has to have this monitored and refilled to get it out of the tunnel, or have an option when a player opens the tunnel GUI that if a train is in it and run out of fuel, an inventory slot is available and anything put in it will be put in the loco's of the currently using train. This fuel issue is very much an edge case. If dummy train gets an unhealthy state not sure what we should do. I think nothing and we just let the train appear at the end of the tunnel and it can then try to path natually.
---@param exitPortal Portal
---@param trainSchedule TrainSchedule
---@param targetTrainStop LuaEntity
---@param skipScheduling boolean
---@return LuaTrain
TrainManager.CreateDummyTrain = function(exitPortal, trainSchedule, targetTrainStop, skipScheduling)
    skipScheduling = skipScheduling or false
    --TODO: update this 'exitPortalEntity'
    local exitPortalEntity = exitPortal.entity
    local locomotive =
        exitPortalEntity.surface.create_entity {
        name = "railway_tunnel-tunnel_exit_dummy_locomotive",
        position = exitPortal.dummyLocomotivePosition,
        direction = exitPortalEntity.direction,
        force = exitPortalEntity.force,
        raise_built = false,
        create_build_effect_smoke = false
    }
    locomotive.destructible = false
    locomotive.burner.currently_burning = "coal"
    locomotive.burner.remaining_burning_fuel = 4000000
    local dummyTrain = locomotive.train
    if not skipScheduling then
        TrainManager.TrainSetSchedule(dummyTrain, trainSchedule, false, targetTrainStop)
        if global.debugRelease and dummyTrain.state == defines.train_state.destination_full then
            -- If the train ends up in one of those states something has gone wrong.
            error("dummy train has unexpected state :" .. tonumber(dummyTrain.state) .. "\nexitPortalEntity position: " .. Logging.PositionToString(exitPortalEntity.position))
        end
    end
    return dummyTrain
end

---@param train LuaTrain
---@param schedule TrainSchedule
---@param isManual boolean
---@param targetTrainStop LuaEntity
---@param skipStateCheck boolean
TrainManager.TrainSetSchedule = function(train, schedule, isManual, targetTrainStop, skipStateCheck)
    train.schedule, skipStateCheck = schedule, skipStateCheck or false
    if not isManual then
        TrainManager.SetTrainToAuto(train, targetTrainStop)
        if global.debugRelease and not skipStateCheck and not TrainManager.IsTrainHealthlyState(train) then
            -- Any issue on the train from the previous tick should be detected by the state check. So this should only trigger after misplaced wagons.
            error("train doesn't have positive state after setting schedule.\ntrain id: " .. train.id .. "\nstate: " .. train.state)
        end
    else
        train.manual_mode = true
    end
end

---@param train LuaTrain
---@return boolean
TrainManager.IsTrainHealthlyState = function(train)
    -- Uses state and not LuaTrain.has_path, as a train waiting at a station doesn't have a path, but is a healthy state.
    local trainState = train.state
    if trainState == defines.train_state.no_path or trainState == defines.train_state.path_lost then
        return false
    else
        return true
    end
end

-- Train limits on the original target train stop of the train going through the tunnel might prevent the exiting (dummy or real) train from pathing there, so we have to ensure that the original target stop has a slot open before setting the train to auto. The trains on route to a station count don't update in real time and so during the tick both the deleted train and our new train will both be heading for the station
---@param train LuaTrain
---@param targetTrainStop LuaEntity
TrainManager.SetTrainToAuto = function(train, targetTrainStop)
    if targetTrainStop ~= nil and targetTrainStop.valid then
        local oldLimit = targetTrainStop.trains_limit
        targetTrainStop.trains_limit = targetTrainStop.trains_count + 1
        train.manual_mode = false
        targetTrainStop.trains_limit = oldLimit
    else
        -- There was no target train stop, so no special handling needed.
        train.manual_mode = false
    end
end

return TrainManager
