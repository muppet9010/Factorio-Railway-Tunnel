-- Has the main state tracking and handling logic for Managed Trains.

local TrainManager = {}
local Utils = require("utility/utils")
local Events = require("utility/events")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local PlayerContainer = require("scripts/player-container")
local Common = require("scripts/common")
local TunnelSignalDirection, TunnelUsageChangeReason, TunnelUsageParts, PrimaryTrainState, TunnelUsageAction = Common.TunnelSignalDirection, Common.TunnelUsageChangeReason, Common.TunnelUsageParts, Common.PrimaryTrainState, Common.TunnelUsageAction
local TrainManagerRemote = require("scripts/train-manager-remote")
local PrototypeAttributes = require("utility/prototype-attributes")

---@class ManagedTrain
---@field id Id @ uniqiue id of this managed train passing through the tunnel.
---@field primaryTrainPartName PrimaryTrainState
---
---@field enteringTrain? LuaTrain|null
---@field enteringTrainId? Id|null @ The enteringTrain LuaTrain id.
---@field enteringTrainForwards? boolean|null @ If the train is moving forwards or backwards from its viewpoint.
---@field enteringTrainExpectedSpeed double @ The speed the train should have been going this tick while entering the tunnel if it wasn't breaking.
---
---@field trainWeight double @ The total weight of the train.
---@field trainFrictionForce double @ The total friction force of the train.
---@field trainWeightedFrictionForce double @ The train's friction force divided by train weight.
---@field locomotiveAccelerationPower double @ The max raw acceleration power per tick the train can add.
---@field trainAirResistanceReductionMultiplier double @ The air resistance of the train (lead carriage in current direction).
---@field maxSpeed double @ The max speed the train can achieve.
---
---@field undergroundTrainHasPlayersRiding boolean @ if there are players riding in the underground train.
---@field traversalTotalTicks int @ the time in ticks it will take for the train to have travelled from the tunnel entering point to when we set it as leaving.
---@field traversalStartingTick int @ the tick the train entered the tunnel.
---@field traversalArrivalTick int @ the tick the train reaches the far end of the tunnel and is restarted.
---@field trainLeavingSpeed double @ the speed the train will be set too at the moment it starts leaving the tunnel.
---
---@field leavingTrain? LuaTrain|null @ The train created leaving the tunnel on the world surface.
---@field leavingTrainId? Id|null @ The LuaTrain ID of the leaving train.
---
---@field portalTrackTrain? LuaTrain|null @ The train thats on the portal track and reserved the tunnel.
---@field portalTrackTrainId? Id|null @ The LuaTrain ID of the portalTrackTrain.
---@field portalTrackTrainInitiallyForwards? boolean|null @ If the train is moving forwards or backwards from its viewpoint when it initially triggers the portal track usage detection.
---@field portalTrackTrainBySignal? boolean|null @ If we are tracking the train by the entrance entry signal or if we haven't got to that point yet.
---
---@field dummyTrain? LuaTrain|null @ The dummy train used to keep the train stop reservation alive
---@field dummyTrainId? Id|null @ The LuaTrain ID of the dummy train.
---
---@field trainTravelDirection defines.direction @ The cardinal direction the train is heading in. Uses the more granular defines.direction to allow natural comparison to Factorio entity direction attributes. Is the direction in relation to the entry portal. -- OVERHAUL - not used by anything any more other than in its populating function.
---@field trainTravelOrientation TrainTravelOrientation @ The orientation of the trainTravelDirection.
---@field targetTrainStop LuaEntity @ The target train stop entity of this train, needed in case the path gets lost as we only have the station name then. Used when checking bad train states and reversing trains.
---
---@field surface LuaSurface @ The main world surface that this managed train is on.
---@field entrancePortal Portal @ The portal global object of the entrance portal for this tunnel usage instance.
---@field entrancePortalTransitionSignal PortalTransitionSignal @ The transitionSignal global object of the rail signal at the transition point of the entrance portal track (forced closed signal).
---@field exitPortal Portal @ Ref to the portal global object of the exit portal for this tunnel usage instance.
---@field exitPortalTransitionSignal PortalTransitionSignal @ Ref to the transitionSignal global object of the rail signal at the end of the exit portal track (forced closed signal).
---@field exitPortalEntrySignalOut PortalEntrySignal @ Ref to the transitionSignal global object on the rail signal at the entrance of the exit portal for leaving trains.
---@field tunnel Tunnel @ Ref to the global tunnel object.

---@class TrainLeadCarriageCache
---@field trainForwards boolean @ If the train was forwards when the cache was last updated.
---@field carriage LuaEntity @ Cached ref to the lead carriage entity.

---@alias TrainTravelOrientation "0"|"0.25"|"0.5"|"0.75"

---@class TrainIdToManagedTrain
---@field trainId Id @ the LuaTrain id.
---@field managedTrain ManagedTrain
---@field tunnelUsagePart TunnelUsageParts

TrainManager.CreateGlobals = function()
    global.trainManager = global.trainManager or {}
    global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId or 1 ---@type Id
    global.trainManager.managedTrains = global.trainManager.managedTrains or {} ---@type table<Id, ManagedTrain>
    global.trainManager.trainIdToManagedTrain = global.trainManager.trainIdToManagedTrain or {} ---@type table<Id, TrainIdToManagedTrain> @ Used to track trainIds to managedTrainEntries. When the trainId is detected as changing via event the global object is updated to stay up to date.
end

TrainManager.OnLoad = function()
    MOD.Interfaces.TrainManager = MOD.Interfaces.TrainManager or {}
    MOD.Interfaces.TrainManager.RegisterTrainApproachingPortalSignal = TrainManager.RegisterTrainApproachingPortalSignal
    MOD.Interfaces.TrainManager.RegisterTrainOnPortalTrack = TrainManager.RegisterTrainOnPortalTrack
    MOD.Interfaces.TrainManager.TrainEnterTunnel = TrainManager.TrainEnterTunnel
    MOD.Interfaces.TrainManager.On_TunnelRemoved = TrainManager.On_TunnelRemoved
    MOD.Interfaces.TrainManager.GetTrainIdsManagedTrainDetails = TrainManager.GetTrainIdsManagedTrainDetails

    Events.RegisterHandlerEvent(defines.events.on_tick, "TrainManager.ProcessManagedTrains", TrainManager.ProcessManagedTrains)
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
    if global.debugRelease then
        Logging.RunFunctionAndCatchErrors(TrainManager._RegisterTrainApproachingPortalSignal_Internal, enteringTrain, entrancePortalTransitionSignal)
    else
        TrainManager._RegisterTrainApproachingPortalSignal_Internal(enteringTrain, entrancePortalTransitionSignal)
    end
end
---@param enteringTrain LuaTrain
---@param entrancePortalTransitionSignal PortalTransitionSignal
TrainManager._RegisterTrainApproachingPortalSignal_Internal = function(enteringTrain, entrancePortalTransitionSignal)
    -- Check if this train is already using the tunnel in some way.
    local existingTrainIDTrackedObject = global.trainManager.trainIdToManagedTrain[enteringTrain.id]
    local reversedManagedTrain, committedManagedTrain = nil, nil
    if existingTrainIDTrackedObject ~= nil then
        if existingTrainIDTrackedObject.tunnelUsagePart == TunnelUsageParts.leavingTrain then
            -- Train was in left state, but is now re-entering. Happens if the train doesn't fully leave the exit portal signal block before coming back in.
            reversedManagedTrain = existingTrainIDTrackedObject.managedTrain
            -- Terminate the old tunnel reservation, but don't release the tunnel as we will just overwrite its user.
            TrainManager.TerminateTunnelTrip(reversedManagedTrain, TunnelUsageChangeReason.reversedAfterLeft, true)
        elseif existingTrainIDTrackedObject.tunnelUsagePart == TunnelUsageParts.portalTrackTrain then
            -- OVERHAUL - is this removal and re-creation needed, or can we just overwrite some data and let it continue. Seems quite wasteful. Note check what in CreateManagedTrainObject() is only done on traversal as we will need to include an upgrade path through the function.
            -- Train was using the portal track and is now entering the tunnel.
            committedManagedTrain = existingTrainIDTrackedObject.managedTrain
            -- Just tidy up the managedTrain's entities and its related globals before the new one overwrites it. No tunnel trip to be dealt with.
            TrainManager.RemoveManagedTrainEntry(committedManagedTrain)
        else
            error("Unsupported situation")
        end
    end

    local managedTrain = TrainManager.CreateManagedTrainObject(enteringTrain, entrancePortalTransitionSignal, true, committedManagedTrain)
    managedTrain.primaryTrainPartName = PrimaryTrainState.approaching
    MOD.Interfaces.Tunnel.TrainReservedTunnel(managedTrain)
    if reversedManagedTrain ~= nil then
        -- Include in the new train approaching event the old leavingTrain entry id that has been stopped.
        TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.startApproaching, nil, reversedManagedTrain.id)
    else
        TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.startApproaching)
    end
end

--- Used when a train is claiming a portals track (and thus the tunnel), but not planning to actively use the tunnel yet. Is like the opposite to a leavingTrain monitoring. Only reached by trains that enter the portal track before their breaking distance is the stopping signal or when driven manually.
---@param trainOnPortalTrack LuaTrain
---@param portal Portal
TrainManager.RegisterTrainOnPortalTrack = function(trainOnPortalTrack, portal)
    if global.debugRelease then
        Logging.RunFunctionAndCatchErrors(TrainManager._RegisterTrainOnPortalTrack_Internal, trainOnPortalTrack, portal)
    else
        TrainManager._RegisterTrainOnPortalTrack_Internal(trainOnPortalTrack, portal)
    end
end
---@param trainOnPortalTrack LuaTrain
---@param portal Portal
TrainManager._RegisterTrainOnPortalTrack_Internal = function(trainOnPortalTrack, portal)
    local managedTrain = TrainManager.CreateManagedTrainObject(trainOnPortalTrack, portal.transitionSignals[TunnelSignalDirection.inSignal], false)
    managedTrain.primaryTrainPartName = PrimaryTrainState.portalTrack
    MOD.Interfaces.Tunnel.TrainReservedTunnel(managedTrain)
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
        -- Keep on running until either the train reaches the Transition train detector or the train's target stops being the transition signal.
        TrainManager.TrainApproachingOngoing(managedTrain)
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

-- This tracks a train once it triggers the entry train detector, until it reserves the Transition signal of the Entrance portal or leaves the portal track (turn around and leave). Turning around could be caused by either manaul driving or from an extreme edge case of track removal ahead as the train is entering and there being a path backwards available. No state change or control of the train is required or applied at this stage.
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
                local placedDetectionEntity = MOD.Interfaces.Portal.AddEnteringTrainUsageDetectionEntityToPortal(managedTrain.entrancePortal, false)
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

-- The train is approaching the transition signal so maintain its speed.
---@param managedTrain ManagedTrain
TrainManager.TrainApproachingOngoing = function(managedTrain)
    local enteringTrain = managedTrain.enteringTrain ---@type LuaTrain

    -- Check whether the train is still approaching the tunnel portal as its not committed yet and so can turn away.
    if enteringTrain.state ~= defines.train_state.arrive_signal or enteringTrain.signal ~= managedTrain.entrancePortalTransitionSignal.entity then
        TrainManager.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.abortedApproach)
        -- TODO: If the train has entered the tracks (triggered the portal tracks train detector) we need to return to that state as the train is still on portal tracks now. If it didn't trigger the portal tracks detector we can just stop as its having no impact on the tunnel or portals.
        return
    end

    -- This won't keep the train exactly at this speed as it will try and brake increasingly as it appraoches the blocker signal. But will stay reasonably close to its desired speed, as most of the ticks its 5% or less below target. See https://wiki.factorio.com/Locomotive
    local cruisingSpeed = math.max(0, (math.abs(managedTrain.enteringTrainExpectedSpeed) - managedTrain.trainWeightedFrictionForce))
    local accelerationRawSpeed = cruisingSpeed + managedTrain.locomotiveAccelerationPower
    local accelerationWindSpeed = accelerationRawSpeed * managedTrain.trainAirResistanceReductionMultiplier
    local newSpeed = math.min(accelerationWindSpeed, managedTrain.maxSpeed)
    if not managedTrain.enteringTrainForwards then
        newSpeed = 0 - newSpeed
    end
    managedTrain.enteringTrainExpectedSpeed = newSpeed
    enteringTrain.speed = newSpeed

    -- Theres a transition portal track detector to flag when a train reaches the end of the portal track and is ready to enter the tunnel. So need to check in here.
end

---@param managedTrain ManagedTrain
TrainManager.TrainEnterTunnel = function(managedTrain)
    if global.debugRelease then
        Logging.RunFunctionAndCatchErrors(TrainManager._TrainEnterTunnel_Internal, managedTrain)
    else
        TrainManager._TrainEnterTunnel_Internal(managedTrain)
    end
end
---@param managedTrain ManagedTrain
TrainManager._TrainEnterTunnel_Internal = function(managedTrain)
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

    -- Work out how long it will take to reach the leaving position assuming the train will have a path and be acelerating/full speed on the far side of the tunnel.
    -- Its the underground distance, portal train waiting length and 17 tiles (3 tiles in to the entry protal part, the 2 blocked portals, 2 tiles to get to the first blocked portal).
    local travelDistance = managedTrain.tunnel.underground.tilesLength + managedTrain.exitPortal.trainWaitingAreaTilesLength + 17
    -- TODO: work out travel time.
    managedTrain.traversalTotalTicks = travelDistance / math.abs(managedTrain.tempEnteringSpeed)
    managedTrain.traversalStartingTick = game.tick
    managedTrain.traversalArrivalTick = managedTrain.traversalStartingTick + math.ceil(managedTrain.traversalTotalTicks)
    -- TODO: needs to set trainLeavingSpeed assuming the train will have a path on the far side

    -- Destroy entering train's entities as we have finished with them.
    for _, carriage in pairs(enteringTrain_carriages) do
        carriage.destroy()
    end
    global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrainId] = nil
    managedTrain.enteringTrain = nil
    managedTrain.enteringTrainId = nil
    managedTrain.enteringTrainForwards = nil
    managedTrain.portalTrackTrain = nil
    managedTrain.portalTrackTrainId = nil
    managedTrain.portalTrackTrainInitiallyForwards = nil
    managedTrain.portalTrackTrainBySignal = nil

    -- Complete the state transition.
    MOD.Interfaces.Tunnel.TrainFinishedEnteringTunnel(managedTrain)
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
            PlayerContainer.MoveATrainsPlayerContainer(managedTrain)
        end
    else
        -- Train arrival time has come.
        TrainManager.TrainUndergroundCompleted(managedTrain)
    end
end

---@param event UtilityScheduledEventCallbackObject
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
    leavingTrain.speed = managedTrain.trainLeavingSpeed
    TrainManager.SetTrainToAuto(leavingTrain, managedTrain.dummyTrain.path_end_stop)
    if leavingTrain.speed == 0 then
        leavingTrain.speed = -1 * managedTrain.trainLeavingSpeed
    end

    -- Check the target isn't part of this tunnel once
    TrainManager.UpdateScheduleForTargetRailBeingTunnelRail(managedTrain, leavingTrain)

    if managedTrain.undergroundTrainHasPlayersRiding then
        PlayerContainer.TransferPlayerFromContainerForClonedUndergroundCarriage(nil, nil)
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
        managedTrain.dummyTrain.front_stock.destroy()
    elseif managedTrain.dummyTrainId ~= nil then
        global.trainManager.trainIdToManagedTrain[managedTrain.dummyTrainId] = nil
    end
    managedTrain.dummyTrain = nil
    managedTrain.dummyTrainId = nil
end

---@param tunnelRemoved Tunnel
---@param killForce? LuaForce @ Populated if the tunnel is being removed due to an entity being killed, otherwise nil.
---@param killerCauseEntity? LuaEntity @ Populated if the tunnel is being removed due to an entity being killed, otherwise nil.
TrainManager.On_TunnelRemoved = function(tunnelRemoved, killForce, killerCauseEntity)
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
                PlayerContainer.On_TunnelRemoved(managedTrain, killForce, killerCauseEntity)
            end

            TrainManager.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.tunnelRemoved)
        end
    end
end

--- Just creates the managed train object for the approaching/on-portal-track train.
---@param train LuaTrain
---@param entrancePortalTransitionSignal PortalTransitionSignal
---@param traversingTunnel boolean
---@param upgradeManagedTrain ManagedTrain @ An existing ManagedTrain object that is being updated/overwritten with fresh data.
---@return ManagedTrain
TrainManager.CreateManagedTrainObject = function(train, entrancePortalTransitionSignal, traversingTunnel, upgradeManagedTrain)
    ---@typelist Id, double
    local train_id, train_speed = train.id, train.speed
    if train_speed == 0 then
        error("TrainManager.CreateManagedTrainObject() doesn't support 0 speed\ntrain id: " .. train_id)
    end

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
        undergroundTrainHasPlayersRiding = false
    }
    local trainForwards = train_speed > 0

    -- Cache the trains attributes for working out each speed. Only needed if its traversing the tunnel. See https://wiki.factorio.com/Locomotive
    if traversingTunnel then
        managedTrain.enteringTrainExpectedSpeed = train_speed

        managedTrain.trainWeight = train.weight
        local trainFrictionForce, forwardFacingLocoCount, fuelAccelerationBonus = 0, 0, nil
        local train_carriages = train.carriages

        -- Work out which way to iterate down the train's carriage array. Starting with the lead carriage.
        local minCarriageIndex, maxCarriageIndex, carriageIterator
        if (train_speed > 0) then
            minCarriageIndex, maxCarriageIndex, carriageIterator = 1, #train_carriages, 1
        elseif (train_speed < 0) then
            minCarriageIndex, maxCarriageIndex, carriageIterator = #train_carriages, 1, -1
        end

        local firstCarriage = true
        for currentSourceTrainCarriageIndex = minCarriageIndex, maxCarriageIndex, carriageIterator do
            local carriage = train_carriages[currentSourceTrainCarriageIndex]
            local carriage_name, carriage_speed = carriage.name, carriage.speed

            trainFrictionForce = trainFrictionForce + PrototypeAttributes.GetAttribute(PrototypeAttributes.PrototypeTypes.entity, carriage_name, "friction_force")

            if firstCarriage then
                firstCarriage = false
                managedTrain.trainAirResistanceReductionMultiplier = 1 - (PrototypeAttributes.GetAttribute(PrototypeAttributes.PrototypeTypes.entity, carriage_name, "air_resistance") / (managedTrain.trainWeight / 1000))
                -- Have to get the right max speed as they're not identical at runtime even if the train is symetrical.
                if trainForwards then
                    managedTrain.maxSpeed = train.max_forward_speed
                elseif not trainForwards then
                    managedTrain.maxSpeed = train.max_backward_speed
                end
            end

            if carriage_speed == train_speed and carriage.type == "locomotive" then
                -- Just check one forward facing loco for fuel type. Have to check the inventory as the train ill be breaking for the signal theres no currently burning.
                if fuelAccelerationBonus == nil then
                    local currentFuel = carriage.burner.inventory[1] ---@type LuaItemStack
                    if currentFuel ~= nil then
                        fuelAccelerationBonus = currentFuel.prototype.fuel_acceleration_multiplier
                    else
                        -- OVERHAUL: add some robust resolution for this....
                        error("don't support loco with non simply identified fuel")
                    end
                end

                forwardFacingLocoCount = forwardFacingLocoCount + 1
            end
        end

        managedTrain.trainFrictionForce = trainFrictionForce
        managedTrain.trainWeightedFrictionForce = (managedTrain.trainFrictionForce / managedTrain.trainWeight)
        managedTrain.locomotiveAccelerationPower = 10 * forwardFacingLocoCount * (fuelAccelerationBonus / managedTrain.trainWeight)
    end

    if traversingTunnel then
        -- Normal tunnel usage.
        managedTrain.enteringTrain = train
        managedTrain.enteringTrainId = train_id

        global.trainManager.trainIdToManagedTrain[train_id] = {
            trainId = train_id,
            managedTrain = managedTrain,
            tunnelUsagePart = TunnelUsageParts.enteringTrain
        }
        managedTrain.enteringTrainForwards = trainForwards
    else
        -- Reserved tunnel, but not using it.
        managedTrain.portalTrackTrain = train
        managedTrain.portalTrackTrainId = train_id
        global.trainManager.trainIdToManagedTrain[train_id] = {
            trainId = train_id,
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

---@param managedTrain ManagedTrain
---@param tunnelUsageChangeReason TunnelUsageChangeReason
---@param dontReleaseTunnel? boolean @ If true any tunnel reservation isn't released. If false or nil then tunnel is released.
TrainManager.TerminateTunnelTrip = function(managedTrain, tunnelUsageChangeReason, dontReleaseTunnel)
    if managedTrain.undergroundTrainHasPlayersRiding then
        PlayerContainer.On_TerminateTunnelTrip(managedTrain)
    end
    TrainManager.RemoveManagedTrainEntry(managedTrain)

    if not dontReleaseTunnel then
        MOD.Interfaces.Tunnel.TrainReleasedTunnel(managedTrain)
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
---@return TrainIdToManagedTrain
TrainManager.GetTrainIdsManagedTrainDetails = function(trainId)
    return global.trainManager.trainIdToManagedTrain[trainId]
end

-- Clone the entering train to the front of the exit portal. This will minimise any tracking of the train when leaving.
---@param managedTrain ManagedTrain
---@param enteringTrain_carriages LuaEntity[]
---@return LuaTrain @ Leaving train
TrainManager.CloneEnteringTrainToExit = function(managedTrain, enteringTrain_carriages)
    -- TODO: make use of the fact we have to get some of the carriage values when calculating speed now. So cache what we need against the managedTrain.
    -- This currently assumes the portals are in a straight line of each other and that the portal areas are straight.
    local enteringTrain, trainCarriagesForwardOrientation = managedTrain.enteringTrain, managedTrain.trainTravelOrientation
    local targetSurface = managedTrain.surface
    if not managedTrain.enteringTrainForwards then
        trainCarriagesForwardOrientation = Utils.LoopOrientationValue(trainCarriagesForwardOrientation + 0.5)
    end

    -- Get the position for the front of the lead carriage; 1.5 tiles back from the entry signal. This means the front 2.5 tiles of the portal area graphics can show the train, with further back needing to be covered to hide the train graphics while the train is underground. Also this allows the train to just fit in without hitting the transition usage detector entity at the back of the exit portal.
    local exitPortalEntrySignalOutPosition = managedTrain.exitPortalEntrySignalOut.entity.position
    local nextCarriagePosition = Utils.RotateOffsetAroundPosition(managedTrain.trainTravelOrientation, {x = -1.5, y = 1.5}, exitPortalEntrySignalOutPosition)

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

    -- Iterate over the carriages and clone them.
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
            PlayerContainer.PlayerInCarriageEnteringTunnel(managedTrain, driver, lastPlacedCarriage)
        end
    end

    return lastPlacedCarriage.train
end

---@param targetSurface LuaSurface
---@param refCarriage LuaEntity
---@param newPosition Position
---@param safeCarriageFlipPosition Position @ Not used until we need to support corners.
---@param requiredOrientation RealOrientation @ Not used until we need to support corners.
---@return LuaEntity
TrainManager.CopyCarriage = function(targetSurface, refCarriage, newPosition, safeCarriageFlipPosition, requiredOrientation)
    -- until we add support for corners or non straight tunnel portal areas we never need to flip a carriage.
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
    return Utils.RotateOffsetAroundPosition(trainOrientation, {x = 0, y = carriagesDistance}, lastPosition)
end

-- Dummy train keeps the train stop reservation as it has near 0 power and so while actively moving, it will never actaully move any distance.
---@param exitPortal Portal
---@param trainSchedule TrainSchedule
---@param targetTrainStop LuaEntity
---@param skipScheduling boolean
---@return LuaTrain
TrainManager.CreateDummyTrain = function(exitPortal, trainSchedule, targetTrainStop, skipScheduling)
    skipScheduling = skipScheduling or false
    local locomotive =
        exitPortal.surface.create_entity {
        name = "railway_tunnel-tunnel_exit_dummy_locomotive",
        position = exitPortal.dummyLocomotivePosition,
        direction = exitPortal.leavingDirection,
        force = exitPortal.force,
        raise_built = false,
        create_build_effect_smoke = false
    }
    locomotive.destructible = false
    local dummyTrain = locomotive.train
    if not skipScheduling then
        TrainManager.TrainSetSchedule(dummyTrain, trainSchedule, false, targetTrainStop)
        if global.debugRelease and dummyTrain.state == defines.train_state.destination_full then
            -- If the train ends up in one of those states something has gone wrong.
            error("dummy train has unexpected state :" .. tonumber(dummyTrain.state) .. "\nexitPortal position: " .. Logging.PositionToString(exitPortal.blockedPortalEnd.entity_position))
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
