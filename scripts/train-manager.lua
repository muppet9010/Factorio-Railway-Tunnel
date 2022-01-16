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

---@class ManagedTrain
---@field id Id @ uniqiue id of this managed train passing through the tunnel.
---@field primaryTrainPartName PrimaryTrainState
---
---@field enteringTrain? LuaTrain|null
---@field enteringTrainId? Id|null @ The enteringTrain LuaTrain id.
---@field enteringTrainForwards? boolean|null @ If the train is moving forwards or backwards from its viewpoint.
---@field enteringTrainExpectedSpeed? double|null @ The speed the train should have been going this tick while entering the tunnel if it wasn't breaking.
---@field enteringTrainReachdFullSpeed? boolean|null @ If the entering train has reached its full speed already.
---@field enteringTrainCarriagesCachedData? Utils_TrainCarriageData[]|null @ The cached carriage details of the entering train as we obtain them.
---
---@field trainSpeedCalculationData? Utils_TrainSpeedCalculationData|null @ Data on the train used to calcualte its future speed and time to cover a distance.
---@field undergroundTrainHasPlayersRiding boolean @ If there are players riding in the underground train.
---@field traversalTravelDistance double|null @ The length of tunnel the train is travelling through on this traversal. This is entering position to leaving position.
---@field traversalInitialDuration? Tick|null @ The number of tick's the train takes to traverse the tunnel.
---@field traversalArrivalTick? Tick|null @ The tick the train reaches the far end of the tunnel and is restarted.
---@field trainLeavingSpeedAbsolute? double|null @ The absolute speed the train will be set too at the moment it starts leaving the tunnel.
---@field traversalInitialSpeedAbsolute? double|null @ The absolute speed the train was going at when it started its traversal.
---
---@field leavingTrain? LuaTrain|null @ The train created leaving the tunnel on the world surface.
---@field leavingTrainId? Id|null @ The LuaTrain ID of the leaving train.
---@field leavingTrainForwards? boolean|null @ If the leaving train is travelling forwards or not. Populated on first setting of the leaving trains speed. Can be returned to nil if when setting the trains speed its found the train isn't in a state to know its direction any more.
---
---@field portalTrackTrain? LuaTrain|null @ The train thats on the portal track and reserved the tunnel.
---@field portalTrackTrainId? Id|null @ The LuaTrain ID of the portalTrackTrain.
---@field portalTrackTrainInitiallyForwards? boolean|null @ If the train is moving forwards or backwards from its viewpoint when it initially triggers the portal track usage detection.
---@field portalTrackTrainBySignal? boolean|null @ If we are tracking the train by the entrance entry signal or if we haven't got to that point yet.
---
---@field dummyTrain? LuaTrain|null @ The dummy train used to keep the train stop reservation alive
---@field dummyTrainId? Id|null @ The LuaTrain ID of the dummy train.
---
---@field trainTravelDirection defines.direction @ The cardinal direction the train is heading in. Uses the more granular defines.direction to allow natural comparison to Factorio entity direction attributes. Is the direction in relation to the entry portal. -- OVERHAUL - not used by anything any more other than in its populating function. Remove in any final tidyup if still not used.
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
    EventScheduler.RegisterScheduledEventType(
        "TrainManager.TrainUndergroundCompleted_Scheduled",
        function(event)
            if global.debugRelease then
                Logging.RunFunctionAndCatchErrors(TrainManager.TrainUndergroundCompleted_Scheduled, event)
            else
                TrainManager.TrainUndergroundCompleted_Scheduled(event)
            end
        end
    )
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

--- This is run within a debug logging wrapper when called by TrainManager.ProcessManagedTrains().
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
--- This is run within a debug logging wrapper when called by TrainManager.ProcessManagedTrain().
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

--- The train is approaching the transition signal so maintain its speed.
--- This is run within a debug logging wrapper when called by TrainManager.ProcessManagedTrain().
---@param managedTrain ManagedTrain
TrainManager.TrainApproachingOngoing = function(managedTrain)
    local enteringTrain = managedTrain.enteringTrain ---@type LuaTrain

    -- Check whether the train is still approaching the tunnel portal as its not committed yet and so can turn away.
    if enteringTrain.state ~= defines.train_state.arrive_signal or enteringTrain.signal ~= managedTrain.entrancePortalTransitionSignal.entity then
        TrainManager.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.abortedApproach)
        return
    end

    -- This won't keep the train exactly at this speed as it will try and brake increasingly as it appraoches the blocker signal. But will stay reasonably close to its desired speed, as most of the ticks its 5% or less below target, with just the last few ticks it climbing significantly as a % of current speed.
    if not managedTrain.enteringTrainReachdFullSpeed then
        -- If the train hasn't yet reached its full speed then work out the new speed.
        local newAbsSpeed = Utils.CalculateAcceleratingTrainSpeedForSingleTick(managedTrain.trainSpeedCalculationData, math.abs(managedTrain.enteringTrainExpectedSpeed))
        if managedTrain.enteringTrainExpectedSpeed == newAbsSpeed then
            -- If the new expected speed is equal to the old expected speed then the train has reached its max speed.
            managedTrain.enteringTrainReachdFullSpeed = true
        end
        local newSpeed
        if managedTrain.enteringTrainForwards then
            newSpeed = newAbsSpeed
        else
            newSpeed = -newAbsSpeed
        end

        managedTrain.enteringTrainExpectedSpeed = newSpeed
        enteringTrain.speed = newSpeed
    else
        -- Train is at full speed so just maintain it.
        enteringTrain.speed = managedTrain.enteringTrainExpectedSpeed
    end

    -- Theres a transition portal track detector to flag when a train reaches the end of the portal track and is ready to enter the tunnel. So need to check in here.
end

---@param managedTrain ManagedTrain
---@param tick Tick
TrainManager.TrainEnterTunnel = function(managedTrain, tick)
    if global.debugRelease then
        Logging.RunFunctionAndCatchErrors(TrainManager._TrainEnterTunnel_Internal, managedTrain, tick)
    else
        TrainManager._TrainEnterTunnel_Internal(managedTrain, tick)
    end
end
---@param managedTrain ManagedTrain
---@param tick Tick
TrainManager._TrainEnterTunnel_Internal = function(managedTrain, tick)
    local enteringTrain = managedTrain.enteringTrain

    -- Check the target isn't part of this tunnel once
    TrainManager.UpdateScheduleForTargetRailBeingTunnelRail(managedTrain, enteringTrain)

    -- Clone the entering train to the exit position.
    local leavingTrain = TrainManager.CloneEnteringTrainToExit(managedTrain)
    local leavingTrainId = leavingTrain.id
    global.trainManager.trainIdToManagedTrain[leavingTrainId] = {
        trainId = leavingTrainId,
        managedTrain = managedTrain,
        tunnelUsagePart = TunnelUsageParts.leavingTrain
    }
    managedTrain.leavingTrain = leavingTrain
    managedTrain.leavingTrainId = leavingTrainId
    local currentAbsSpeed = math.abs(managedTrain.enteringTrainExpectedSpeed)
    managedTrain.traversalInitialSpeedAbsolute = currentAbsSpeed

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
    local traversalTravelDistance = managedTrain.tunnel.underground.tilesLength + managedTrain.exitPortal.trainWaitingAreaTilesLength + 17
    -- Estimate how long it will take to complete the distance and then final speed.
    local estimatedTicks = Utils.EstimateAcceleratingTrainTicksToCoverDistance(managedTrain.trainSpeedCalculationData, currentAbsSpeed, traversalTravelDistance)
    local estimatedSpeedAbsolute, _ = Utils.EstimateAcceleratingTrainSpeedAndDistanceForTicks(managedTrain.trainSpeedCalculationData, currentAbsSpeed, estimatedTicks)
    managedTrain.traversalTravelDistance = traversalTravelDistance
    managedTrain.traversalInitialDuration = estimatedTicks
    managedTrain.traversalArrivalTick = tick + estimatedTicks
    managedTrain.trainLeavingSpeedAbsolute = estimatedSpeedAbsolute

    -- Destroy entering train's entities as we have finished with them.
    for _, carriage in pairs(enteringTrain.carriages) do
        carriage.destroy()
    end
    global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrainId] = nil
    managedTrain.enteringTrain = nil
    managedTrain.enteringTrainId = nil
    managedTrain.enteringTrainForwards = nil
    managedTrain.enteringTrainExpectedSpeed = nil
    managedTrain.enteringTrainReachdFullSpeed = nil
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

--- Runs each tick for when we need to track a train while underground in detail.
--- Only need to track an ongoing underground train if there's a player riding in the train and we need to update their position each tick.
--- This is run within a debug logging wrapper when called by TrainManager.ProcessManagedTrain().
---@param managedTrain ManagedTrain
---@param currentTick Tick
TrainManager.TrainUndergroundOngoing = function(managedTrain, currentTick)
    -- OVERHAUL: use of managedTrain.traversalArrivalTick doesn't handle if the train is delayed. Will mean the player goes at full speed through the tunnel and then sits still for the delayed arrival from the train having to brake. Will also need to store the movement per tick so we can move te player container by that much.
    if currentTick < managedTrain.traversalArrivalTick then
        -- Train still waiting on its arrival time.
        if managedTrain.undergroundTrainHasPlayersRiding then
            PlayerContainer.MoveATrainsPlayerContainer(managedTrain)
        end
    else
        -- Train arrival time has come.

        -- Set the leaving trains speed and handle the unknown direction element. Updates managedTrain.leavingTrainForwards for later use.
        local leavingTrain = managedTrain.leavingTrain
        TrainManager.SetTrainSpeedInCorrectDirection(leavingTrain, managedTrain.trainLeavingSpeedAbsolute, managedTrain, "leavingTrainForwards", managedTrain.dummyTrain.path_end_stop)

        TrainManager.TrainUndergroundCompleted(managedTrain)
    end
end

--- Run when the train is scheduled to arrive at the end of the tunnel.
--- This is run within a debug logging wrapper when called by the event scheduler.
---@param event UtilityScheduledEvent_CallbackObject
TrainManager.TrainUndergroundCompleted_Scheduled = function(event)
    local managedTrain = event.data.managedTrain ---@type ManagedTrain
    local previousBrakingTargetEntityId = event.data.brakingTargetEntityId ---@type LuaEntity
    if managedTrain == nil or managedTrain.primaryTrainPartName ~= PrimaryTrainState.underground then
        -- Something has happened to the train/tunnel being managed while this has been scheduled, so just give up.
        return
    end

    -- Set the leaving trains speed and handle the unknown direction element. Updates managedTrain.leavingTrainForwards for later use.
    local leavingTrain = managedTrain.leavingTrain
    TrainManager.SetTrainSpeedInCorrectDirection(leavingTrain, managedTrain.trainLeavingSpeedAbsolute, managedTrain, "leavingTrainForwards", managedTrain.dummyTrain.path_end_stop)

    -- Check if the train can just leave at its current speed and if so release it here.
    local leavingTrain_state = leavingTrain.state
    if leavingTrain_state == defines.train_state.on_the_path then
        -- Train can leave at full speed.
        TrainManager.TrainUndergroundCompleted(managedTrain)
        return
    end

    -- Train can't just leave at its current speed blindly, so work out how to proceed based on its state.
    local crawlAbsSpeed = 0.03 -- The speed for the train if its going to crawl forwards to the end of the portal.
    local distanceBeyondTrainLeavingPosition, leavingTrainNewAbsoluteSpeed, scheduleFutureArrival, brakingTargetEntityId = 0, nil, nil, nil
    if leavingTrain_state == defines.train_state.path_lost or leavingTrain_state == defines.train_state.no_schedule or leavingTrain_state == defines.train_state.no_path or leavingTrain_state == defines.train_state.destination_full then
        -- Train has no where to go so just pull to the end of the tunnel and then return to its regular broken state.

        local exitPortalEntryRail = managedTrain.exitPortalEntrySignalOut.railEntity
        local schedule = leavingTrain.schedule
        table.insert(
            schedule.records,
            schedule.current,
            {
                rail = exitPortalEntryRail,
                temporary = true
            }
        )
        leavingTrain.schedule = schedule

        leavingTrainNewAbsoluteSpeed = crawlAbsSpeed
        scheduleFutureArrival = false
    elseif leavingTrain_state == defines.train_state.arrive_station then
        -- Train needs to have been braking as its pulling up to its station/rail target, but we can easily get the distance from its path data.
        local leavingTrain_pathEndStop, leavingTrain_pathEndRail = leavingTrain.path_end_stop, leavingTrain.path_end_rail

        -- Handle the end of portal rail differently to a rail on the main network..
        if leavingTrain_pathEndStop == nil and leavingTrain_pathEndRail ~= nil and leavingTrain_pathEndRail.unit_number == managedTrain.exitPortalEntrySignalOut.railEntity_unitNumber then
            -- Its the end of portal rail so just crawl forwards.
            leavingTrainNewAbsoluteSpeed = crawlAbsSpeed
            scheduleFutureArrival = false
        else
            -- Check this isn't a second loop for the same target due to some bug in the braking maths.
            local brakingTargetEntity = leavingTrain_pathEndStop or leavingTrain_pathEndRail
            brakingTargetEntityId = brakingTargetEntity.unit_number
            local skipProcessingForDelay = false
            if previousBrakingTargetEntityId == brakingTargetEntityId then
                -- Is a repeat.
                if global.debugRelease then
                    error("Looped on leaving train for same target station.")
                else
                    -- Just let the mod continue to run, its not the end of the world. As npo main variables are changed from default the train will leave now.
                    skipProcessingForDelay = true
                end
            end

            -- Do the processing assuming this isn't a repeat loop (it shouldn't be a repeat if maths works correctly).
            if not skipProcessingForDelay then
                local leavingTrain_path = leavingTrain.path
                local leavingTrain_path_rails = leavingTrain_path.rails
                distanceBeyondTrainLeavingPosition = leavingTrain_path.total_distance
                distanceBeyondTrainLeavingPosition = distanceBeyondTrainLeavingPosition - Utils.GetRailEntityLength(leavingTrain_path_rails[#leavingTrain_path_rails].type) -- Remove the last rail's length as we want to stop before this.
                scheduleFutureArrival = true
            end
        end
    elseif leavingTrain_state == defines.train_state.arrive_signal then
        -- Train needs to have been braking as its pulling up to its signal.
        local leavingTrain_signal = leavingTrain.signal
        local leavingTrain_signal_unitNumber = leavingTrain_signal.unit_number
        brakingTargetEntityId = leavingTrain_signal_unitNumber

        -- Handle the end of portal signal differently to a signal on the main rail network.
        if leavingTrain_signal_unitNumber == managedTrain.exitPortalEntrySignalOut.id then
            -- Its the end of portal signal so just crawl forwards.
            leavingTrainNewAbsoluteSpeed = crawlAbsSpeed
            scheduleFutureArrival = false
        else
            -- Signal on main rail network so need to work out the rough distance.

            -- Check this isn't a second loop for the same target due to some bug in the braking maths.
            local skipProcessingForDelay = false
            if previousBrakingTargetEntityId == brakingTargetEntityId then
                -- Is a repeat.
                if global.debugRelease then
                    error("Looped on leaving train for same signal.")
                else
                    -- Just let the mod continue to run, its not the end of the world. As npo main variables are changed from default the train will leave now.
                    skipProcessingForDelay = true
                end
            end

            -- Do the processing assuming this isn't a repeat loop (it shouldn't be a repeat if maths works correctly).
            if not skipProcessingForDelay then
                -- Create a temporary schedule to the signals rail, get the distance and then remove the schedule entry.
                local signalRail = leavingTrain_signal.get_connected_rails()[1]
                local schedule = leavingTrain.schedule
                -- Make the new schedule have a wait condition so we path to this signal rail and not through it towards the real target. Its going to be remvoed before being acted upon anyways.
                table.insert(
                    schedule.records,
                    schedule.current,
                    {
                        rail = signalRail,
                        temporary = true,
                        wait_conditions = {
                            {
                                type = "time",
                                compare_type = "and",
                                ticks = 1
                            }
                        }
                    }
                )
                leavingTrain.schedule = schedule
                leavingTrain.recalculate_path(true)
                leavingTrain.manual_mode = false
                distanceBeyondTrainLeavingPosition = leavingTrain.path.total_distance
                distanceBeyondTrainLeavingPosition = distanceBeyondTrainLeavingPosition - Utils.GetRailEntityLength(signalRail.type) -- Remove the last rail's length as we want to stop before this.
                table.remove(schedule.records, schedule.current)
                -- Restore the train to its origional state.
                TrainManager.SetTrainToAuto(leavingTrain, managedTrain.dummyTrain.path_end_stop)

                scheduleFutureArrival = true
            end
        end
    else
        error("unsupported train state for leaving tunnel: " .. leavingTrain_state)
    end

    -- Handle the next steps based on the processing.
    if scheduleFutureArrival then
        -- Calculate the delayed arrival time and delay the schedule to this. This will account for the full speed change and will account for if the train entered the tunnel overly fast, making the total duration and leaving speed correct.

        local currentForcesBrakingBonus = managedTrain.tunnel.force.train_braking_force_bonus
        distanceBeyondTrainLeavingPosition = distanceBeyondTrainLeavingPosition - 6 -- Remove the 3 rails at the end of the portal that are listed in train's path. The train is already on these and so they can't be braked over.

        -- Work out the speed we should be going when leaving the tunnel to stop at the required location.
        local requiredSpeedAbsoluteAtPortalEnd = Utils.CalculateBrakingTrainInitialSpeedWhenStoppedOverDistance(managedTrain.trainSpeedCalculationData, distanceBeyondTrainLeavingPosition, currentForcesBrakingBonus)
        managedTrain.trainLeavingSpeedAbsolute = requiredSpeedAbsoluteAtPortalEnd

        -- Work out how much time and distance in the tunnel it takes to change speed to the required leaving speed.
        local ticksSpentMatchingSpeed, distanceSpentMatchingSpeed
        if managedTrain.traversalInitialSpeedAbsolute < requiredSpeedAbsoluteAtPortalEnd then
            -- Need to accelerate within tunnel up to required speed.
            ticksSpentMatchingSpeed, distanceSpentMatchingSpeed = Utils.EstimateAcceleratingTrainTicksAndDistanceFromInitialToFinalSpeed(managedTrain.trainSpeedCalculationData, managedTrain.traversalInitialSpeedAbsolute, requiredSpeedAbsoluteAtPortalEnd)
        else
            -- Need to brake within tunnel up to required speed.
            ticksSpentMatchingSpeed, distanceSpentMatchingSpeed = Utils.CalculateBrakingTrainDistanceAndTimeFromInitialToFinalSpeed(managedTrain.trainSpeedCalculationData, managedTrain.traversalInitialSpeedAbsolute, requiredSpeedAbsoluteAtPortalEnd, currentForcesBrakingBonus)
        end
        local remainingTunnelDistanceToCover = managedTrain.traversalTravelDistance - distanceSpentMatchingSpeed

        -- Work out how many ticks within the tunnel it takes to cover the distance gap. We must start and end at the same speed over this distance, so accelerate and brake during it.
        local ticksTraversingRemaingDistance
        if remainingTunnelDistanceToCover > 0 then
            -- Tunnel distance still to cover.
            ticksTraversingRemaingDistance = Utils.EstimateTrainTicksToCoverDistanceWithSameStartAndEndSpeed(managedTrain.trainSpeedCalculationData, requiredSpeedAbsoluteAtPortalEnd, remainingTunnelDistanceToCover, currentForcesBrakingBonus)
        else
            -- Train has to break longer than the tunnel is. The time spent breaking covers the full amount and we will just ignore the fact that the train was accelerating in to the tunnel when it shouldn't have been.
            ticksTraversingRemaingDistance = 0
        end

        -- Work out the delay for leaving the tunnel.
        local delayTicks = math.ceil(ticksSpentMatchingSpeed + ticksTraversingRemaingDistance - managedTrain.traversalInitialDuration)
        if delayTicks < 0 then
            error("leaving train shouldn't be able to be rescheduled with negative delay compared to previous computing")
        end

        -- If the new time is not the same as the old then we need to reschedule, this is the expected situation. However if the arrival times are the same then just let the code flow in to releasing the train now.
        if delayTicks > 0 then
            -- Schedule the next attempt at releasing the train.
            managedTrain.traversalArrivalTick = managedTrain.traversalArrivalTick + delayTicks
            EventScheduler.ScheduleEventOnce(managedTrain.traversalArrivalTick, "TrainManager.TrainUndergroundCompleted_Scheduled", managedTrain.id, {managedTrain = managedTrain, brakingTargetEntityId = brakingTargetEntityId})

            -- Reset the leaving trains speed and state as we don't want it to do anything yet.
            leavingTrain.speed = 0
            leavingTrain.manual_mode = true
            return
        end
    end

    -- Set the new leaving speed to the train and release it.
    local leavingSpeedAbsolute = leavingTrainNewAbsoluteSpeed or managedTrain.trainLeavingSpeedAbsolute
    if managedTrain.leavingTrainForwards == true then
        leavingTrain.speed = leavingSpeedAbsolute
    elseif managedTrain.leavingTrainForwards == false then
        leavingTrain.speed = -leavingSpeedAbsolute
    else
        -- Train facing not resolvable at previous setting time so have to do it again now from a possibly weird train state.
        leavingTrain.manual_mode = true -- Set train back to a safe state that we can test applying the speed as it will still have a state that errors on backwards speeds.
        TrainManager.SetTrainSpeedInCorrectDirection(leavingTrain, leavingSpeedAbsolute, managedTrain, "leavingTrainForwards", leavingTrain.path_end_stop)
        if managedTrain.leavingTrainForwards == nil then
            -- Train facing neededed to have been fixed by now.
            error("unknown leaving train facing when trying to set its speed to release it from the tunnel")
        end
    end
    TrainManager.TrainUndergroundCompleted(managedTrain)
end

---@param managedTrain ManagedTrain
TrainManager.TrainUndergroundCompleted = function(managedTrain)
    -- Train has arrived and needs tidying up.

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
        if Common.TunnelRailEntityNames[targetRail_name] ~= nil then
            -- The target rail is the type used by a portal/segment for rail, so check if it belongs to the just used tunnel.
            local targetRail_unitNumber = targetRail.unit_number
            if managedTrain.tunnel.tunnelRailEntities[targetRail_unitNumber] ~= nil or managedTrain.tunnel.portalRailEntities[targetRail_unitNumber] ~= nil then
                -- The target rail is part of the currently used tunnel, so update the schedule rail to be the one at the end of the portal and just leave the train to do its thing from there.
                local schedule = train.schedule
                local currentScheduleRecord = schedule.records[schedule.current]
                local exitPortalEntryRail = managedTrain.exitPortalEntrySignalOut.railEntity
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
---@param killForce? LuaForce|null @ Populated if the tunnel is being removed due to an entity being killed, otherwise nil.
---@param killerCauseEntity? LuaEntity|null @ Populated if the tunnel is being removed due to an entity being killed, otherwise nil.
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
    local train_id = train.id ---@type Id
    local train_speed = train.speed ---@type double
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

    if traversingTunnel then
        -- Normal tunnel usage.
        managedTrain.enteringTrain = train
        managedTrain.enteringTrainId = train_id

        -- Cache the trains attributes for working out each speed. Only needed if its traversing the tunnel.
        managedTrain.enteringTrainExpectedSpeed = train_speed
        managedTrain.enteringTrainReachdFullSpeed = false
        -- Start building up the carriage data cache for later use.
        ---@type Utils_TrainCarriageData[]
        local enteringTrainCarriagesCachedData = {}
        for i, carriage in pairs(train.carriages) do
            enteringTrainCarriagesCachedData[i] = {entity = carriage}
        end
        managedTrain.trainSpeedCalculationData = Utils.GetTrainsSpeedCalculationData(train, train_speed, nil, enteringTrainCarriagesCachedData)
        managedTrain.enteringTrainCarriagesCachedData = enteringTrainCarriagesCachedData

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
---@param dontReleaseTunnel? boolean|null @ If true any tunnel reservation isn't released. If false or nil then tunnel is released.
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

--- Clone the entering train to the front of the exit portal. This will minimise any tracking of the train when leaving.
--- This happens to duplicate the train schedule as a by product of using the entity clone feature.
---@param managedTrain ManagedTrain
---@return LuaTrain @ Leaving train
TrainManager.CloneEnteringTrainToExit = function(managedTrain)
    -- This currently assumes the portals are in a straight line of each other and that the portal areas are straight.
    local enteringTrain, trainCarriagesForwardOrientation = managedTrain.enteringTrain, managedTrain.trainTravelOrientation
    local targetSurface = managedTrain.surface
    if not managedTrain.enteringTrainForwards then
        trainCarriagesForwardOrientation = Utils.LoopOrientationValue(trainCarriagesForwardOrientation + 0.5)
    end

    -- Get the position for the front of the lead carriage, 1.5 tiles back from the entry signal. This means the front 2.5 tiles of the portal area graphics can show the train, with further back needing to be covered to hide the train graphics while the train is underground. Also this allows the train to just fit in without hitting the transition usage detector entity at the back of the exit portal.
    local exitPortalEntrySignalOutPosition = managedTrain.exitPortalEntrySignalOut.entity_position
    local nextCarriagePosition = Utils.RotateOffsetAroundPosition(managedTrain.trainTravelOrientation, {x = -1.5, y = 1.5}, exitPortalEntrySignalOutPosition)

    -- Work out which way to iterate down the train's carriage array. Starting with the lead carriage.
    local minCarriageIndex, maxCarriageIndex, carriageIterator
    if (managedTrain.enteringTrainExpectedSpeed > 0) then
        minCarriageIndex, maxCarriageIndex, carriageIterator = 1, #managedTrain.enteringTrainCarriagesCachedData, 1
    elseif (managedTrain.enteringTrainExpectedSpeed < 0) then
        minCarriageIndex, maxCarriageIndex, carriageIterator = #managedTrain.enteringTrainCarriagesCachedData, 1, -1
    else
        error("TrainManager.CopyEnteringTrainUnderground() doesn't support 0 speed refTrain.\nrefTrain id: " .. enteringTrain.id)
    end

    -- Iterate over the carriages and clone them.
    local refCarriageData, refCarriageData_name
    local lastPlacedCarriage, lastPlacedCarriage_name
    for currentSourceTrainCarriageIndex = minCarriageIndex, maxCarriageIndex, carriageIterator do
        refCarriageData = managedTrain.enteringTrainCarriagesCachedData[currentSourceTrainCarriageIndex]

        refCarriageData_name = refCarriageData.prototypeName
        if refCarriageData_name == nil then
            refCarriageData_name = refCarriageData.entity.name
            refCarriageData.name = refCarriageData_name
        end
        local refCarriageData_speed = refCarriageData.speed
        if refCarriageData_speed == nil then
            refCarriageData_speed = refCarriageData.entity.speed
            refCarriageData.speed = refCarriageData_speed
        end

        local carriageOrientation = trainCarriagesForwardOrientation
        if refCarriageData_speed ~= managedTrain.enteringTrainExpectedSpeed then
            carriageOrientation = Utils.LoopOrientationValue(carriageOrientation + 0.5)
        end

        nextCarriagePosition = TrainManager.GetNextCarriagePlacementPosition(managedTrain.trainTravelOrientation, nextCarriagePosition, lastPlacedCarriage_name, refCarriageData_name)
        lastPlacedCarriage = TrainManager.CopyCarriage(targetSurface, refCarriageData.entity, nextCarriagePosition, nil, carriageOrientation)
        lastPlacedCarriage_name = refCarriageData_name

        -- Handle any players in the train carriage.
        local driver = refCarriageData.entity.get_driver()
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
    local tempCarriage ---@type LuaEntity
    local sourceCarriage ---@type LuaEntity
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

--- Sets a trains schedule and returns it to automatic, while handling if the train should be in manual mode.
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

--- Check if a train has a healthy state (not a pathing failure state).
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

--- Sets the train to automatic and forces the train within a train stops limited train count if required.
---@param train LuaTrain
---@param targetTrainStop LuaEntity
TrainManager.SetTrainToAuto = function(train, targetTrainStop)
    --- Train limits on the original target train stop of the train going through the tunnel might prevent the exiting (dummy or real) train from pathing there, so we have to ensure that the original target stop has a slot open before setting the train to auto. The trains on route to a station count don't update in real time and so during the tick both the deleted train and our new train will both be heading for the station
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

--- Sets a trains speed correctly when we are unsure of the trains direction. Utilises and updates the train facing forwards ManagedTrain field for quicker simplier usage.
---@param train LuaTrain
---@param absoluteSpeed double
---@param facingForwardsFieldContainer table @ is the train's ManagedTrain object in these use cases, but left generic intentionally.
---@param facingForwardsFieldName string @ i.e. leavingTrainForwards
---@param schedulePathEndStop? LuaEntity|null @ Just pass through the targeted schedule end stop value and it will be handled.
TrainManager.SetTrainSpeedInCorrectDirection = function(train, absoluteSpeed, facingForwardsFieldContainer, facingForwardsFieldName, schedulePathEndStop)
    if facingForwardsFieldContainer[facingForwardsFieldName] == nil or facingForwardsFieldContainer[facingForwardsFieldName] then
        train.speed = absoluteSpeed
    else
        train.speed = -absoluteSpeed
    end
    TrainManager.SetTrainToAuto(train, schedulePathEndStop)
    if facingForwardsFieldContainer[facingForwardsFieldName] == nil then
        -- Train hasn't tried to leave before so we don't actually know which way it is facing.
        if train.speed ~= 0 then
            facingForwardsFieldContainer[facingForwardsFieldName] = true
        else
            train.speed = -absoluteSpeed
            facingForwardsFieldContainer[facingForwardsFieldName] = false
            train.manual_mode = false -- Have to do after setting speed again to get the train state to update right now.
            if train.speed == 0 then
                -- Train state not suitable to hold speed in either direction. Set facing back to unknown and it will be handled by the main process functions.
                facingForwardsFieldContainer[facingForwardsFieldName] = nil
            end
        end
    end
end

return TrainManager
