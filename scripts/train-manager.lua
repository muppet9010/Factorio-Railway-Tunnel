-- Has the main state tracking and handling logic for Managed Trains.

local TrainManager = {}
local Utils = require("utility/utils")
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")
local TrainManagerFuncs = require("scripts/train-manager-functions")
local TrainManagerPlayerContainers = require("scripts/train-manager-player-containers")
local Common = require("scripts/common")
local TunnelSignalDirection, TunnelUsageChangeReason, TunnelUsageParts, PrimaryTrainState, TunnelUsageAction = Common.TunnelSignalDirection, Common.TunnelUsageChangeReason, Common.TunnelUsageParts, Common.PrimaryTrainState, Common.TunnelUsageAction
local TrainManagerRemote = require("scripts/train-manager-remote")

---@class ManagedTrain
---@field id Id @uniqiue id of this managed train passing through the tunnel.
---@field primaryTrainPartName PrimaryTrainState
---
---@field tempEnteringSpeed double @the speed the train was going when entering and we maintain at for whole tunnel approach and transversal in intiial code version.
---@field traversalTotalTicks int @the time in ticks it will take for the train to have travelled from the tunnel entering point to when we set it as leaving.
---@field traversalStartingTick int @the tick the train entered the tunnel.
---@field traversalArrivalTick int @the tick the train reaches the far end of the tunnel and is restarted.
---
---@field enteringTrain LuaTrain
---@field enteringTrainId Id @The enteringTrain LuaTrain id.
---@field enteringTrainForwards boolean @If the train is moving forwards or backwards from its viewpoint.
---
---@field leavingTrain LuaTrain @The train created leaving the tunnel on the world surface.
---@field leavingTrainId Id @The LuaTrain ID of the above Train Leaving.
---@field leavingTrainForwards boolean @If the train is moving forwards or backwards from its viewpoint.
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
---@field aboveSurface LuaSurface @The main world surface.
---@field aboveEntrancePortal Portal @The portal global object of the entrance portal for this tunnel usage instance.
---@field aboveEntrancePortalEndSignal PortalEndSignal @The endSignal global object of the rail signal at the end of the entrance portal track (forced closed signal).
---@field aboveExitPortal Portal @Ref to the portal global object of the exit portal for this tunnel usage instance.
---@field aboveExitPortalEndSignal PortalEndSignal @Ref to the endSignal global object of the rail signal at the end of the exit portal track (forced closed signal).
---@field aboveExitPortalEntrySignalOut PortalEntrySignal @Ref to the endSignal global object on the rail signal at the entrance of the exit portal for leaving trains.
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
            TrainManagerFuncs.RunFunctionAndCatchErrors(TrainManager.RegisterTrainApproachingPortalSignal, ...)
        end
    )
    Interfaces.RegisterInterface(
        "TrainManager.RegisterTrainOnPortalTrack",
        function(...)
            TrainManagerFuncs.RunFunctionAndCatchErrors(TrainManager.RegisterTrainOnPortalTrack, ...)
        end
    )
    Interfaces.RegisterInterface(
        "TrainManager.TrainEnterTunnel",
        function(...)
            TrainManagerFuncs.RunFunctionAndCatchErrors(TrainManager.TrainEnterTunnel, ...)
        end
    )
    Events.RegisterHandlerEvent(defines.events.on_tick, "TrainManager.ProcessManagedTrains", TrainManager.ProcessManagedTrains)
    Interfaces.RegisterInterface("TrainManager.On_TunnelRemoved", TrainManager.On_TunnelRemoved)
    Interfaces.RegisterInterface("TrainManager.On_PortalReplaced", TrainManager.On_PortalReplaced)
    Interfaces.RegisterInterface("TrainManager.GetTrainIdsManagedTrainDetails", TrainManager.GetTrainIdsManagedTrainDetails)
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--------------------          CORE LOGIC FUNCTIONS          -------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- Light - Assume it can come back in as shouldn't have any cost on regular running of through trains and would require making the tunnel 1 direction otherwise.
---@param enteringTrain LuaTrain
---@param aboveEntrancePortalEndSignal PortalEndSignal
TrainManager.RegisterTrainApproachingPortalSignal = function(enteringTrain, aboveEntrancePortalEndSignal)
    -- Check if this train is already using the tunnel in some way.
    -- TODO - OVERHAUL - must check train length isn't more than tunnel allowed max length. If it is reject.
    local existingTrainIDTrackedObject = global.trainManager.trainIdToManagedTrain[enteringTrain.id]
    local replacedManagedTrain, upgradeManagedTrain = nil, nil
    if existingTrainIDTrackedObject ~= nil then
        if existingTrainIDTrackedObject.tunnelUsagePart == TunnelUsageParts.leavingTrain then
            -- Train was in left state, but is now re-entering. Happens if the train doesn't fully leave the exit portal signal block before coming back in.
            replacedManagedTrain = existingTrainIDTrackedObject.managedTrain
            -- Terminate the old tunnel reservation, but don't release the tunnel as we will just overwrite its user.
            TrainManager.TerminateTunnelTrip(replacedManagedTrain, TunnelUsageChangeReason.reversedAfterLeft, false)
        elseif existingTrainIDTrackedObject.tunnelUsagePart == TunnelUsageParts.portalTrackTrain then
            -- Train was using the portal track and is now entering the tunnel.
            upgradeManagedTrain = existingTrainIDTrackedObject.managedTrain
            -- Just tidy up the managedTrain's entities its related globals before the new one overwrites it. No tunnel trip to be dealt with.
            TrainManager.RemoveManagedTrainEntry(upgradeManagedTrain)
        else
            error("Unsupported situation")
        end
    end

    local managedTrain = TrainManager.CreateManagedTrainObject(enteringTrain, aboveEntrancePortalEndSignal, true, upgradeManagedTrain)
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
    -- TODO - OVERHAUL - must check train length isn't more than tunnel allowed max length. If it is reject.
    local managedTrain = TrainManager.CreateManagedTrainObject(trainOnPortalTrack, portal.endSignals[TunnelSignalDirection.inSignal], false)
    TrainManager.UpdateScheduleForTargetRailBeingTunnelRail(managedTrain, trainOnPortalTrack)
    managedTrain.primaryTrainPartName = PrimaryTrainState.portalTrack
    TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.onPortalTrack)
end

TrainManager.ProcessManagedTrains = function(eventData)
    local currentTick = eventData.tick
    -- Loop over each train and process it.
    for _, managedTrain in pairs(global.trainManager.managedTrains) do
        TrainManagerFuncs.RunFunctionAndCatchErrors(TrainManager.ProcessManagedTrain, managedTrain, currentTick)
    end

    TrainManagerRemote.ProcessTicksEvents()
end

---@param managedTrain ManagedTrain
TrainManager.ProcessManagedTrain = function(managedTrain, currentTick)
    local skipThisTick = false -- Used to provide a "continue" ability as some actions could leave the trains in a weird state this tick and thus error on later functions in the process.

    -- Handle managed trains that are just using portal track first as this just returns.
    if managedTrain.primaryTrainPartName == PrimaryTrainState.portalTrack then
        -- Keep on running until either the train triggers the END signal or the train leaves the portal tracks.
        TrainManager.TrainOnPortalTrackOngoing(managedTrain)
        return
    end

    -- Check dummy train state is valid if it exists. Used in a lot of states so sits outside of them.
    -- OVERHAUL staying with Dummy train usage for now, notes on the CreateDummyTrain().
    if not skipThisTick and managedTrain.dummyTrain ~= nil and not TrainManagerFuncs.IsTrainHealthlyState(managedTrain.dummyTrain) then
        TrainManager.HandleLeavingTrainBadState("dummyTrain", managedTrain)
        skipThisTick = true
    end

    if not skipThisTick and managedTrain.primaryTrainPartName == PrimaryTrainState.approaching then
        -- Check whether the train is still approaching the tunnel portal as its not committed yet and so can turn away.
        if managedTrain.enteringTrain.state ~= defines.train_state.arrive_signal or managedTrain.enteringTrain.signal ~= managedTrain.aboveEntrancePortalEndSignal.entity then
            TrainManager.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.abortedApproach)
            skipThisTick = true
        else
            TrainManager.TrainApproachingOngoing(managedTrain)
        end
    end

    if not skipThisTick and managedTrain.primaryTrainPartName == PrimaryTrainState.underground then
        TrainManager.TrainUndergroundOngoing(managedTrain, currentTick)
    end

    if not skipThisTick and managedTrain.primaryTrainPartName == PrimaryTrainState.leaving then
        TrainManager.TrainLeavingOngoing(managedTrain)
    end
end

-- Light - OVERHAUL - may still be needed by the dummy train checking, but I hope we don't need to check anything any more. Now we only have full trains ever I think it will just work naturally. May need the pull forwards mechanic still.
---@param trainWithBadStateName LuaTrain
---@param managedTrain ManagedTrain
TrainManager.HandleLeavingTrainBadState = function(trainWithBadStateName, managedTrain)
    local trainWithBadState = managedTrain[trainWithBadStateName] ---@type LuaTrain

    -- Check if the train can just path now as trains don't try and repath every tick. So sometimes they can path forwards on their own, they just haven't realised yet.
    if trainWithBadState.recalculate_path() then
        if trainWithBadStateName == "dummyTrain" then
            -- Just return as the dummy train doesn't handle reversing itself.
            return
        else
            error("TrainManager.HandleLeavingTrainBadState() unsupported trainWithBadStateName:" .. tostring(trainWithBadStateName))
        end
    end

    -- Handle train that can't go backwards, so just pull the train forwards to the end of the tunnel (signal segment) and then return to its preivous schedule. Makes the situation more obvious for the player and easier to access the train. The train has already lost any station reservation it had.
    local newSchedule = trainWithBadState.schedule
    local exitPortalEntryRail = managedTrain.aboveExitPortalEntrySignalOut.entity.get_connected_rails()[1] ---@type LuaEntity
    local endOfTunnelScheduleRecord = {rail = exitPortalEntryRail, temporary = true}
    table.insert(newSchedule.records, newSchedule.current, endOfTunnelScheduleRecord)
    trainWithBadState.schedule = newSchedule
    if not trainWithBadState.has_path then
        -- Check if the train can reach the end of the tunnel portal track. If it can't then the train is past the target track point. In this case the train should just stop where it is and wait.

        -- Reset the above schedule and the train will go in to no-path or destination full states until it can move off some time in the future.
        table.remove(newSchedule.records, 1)
        trainWithBadState.schedule = newSchedule
    end
end

---@param managedTrain ManagedTrain
TrainManager.TrainApproachingOngoing = function(managedTrain)
    local enteringTrain = managedTrain.enteringTrain ---@type LuaTrain
    -- This won't keep the train exactly at this speed as it will try and brake its max amount each tick off this speed. But will stay reasonably close to its desired speed.
    enteringTrain.speed = managedTrain.tempEnteringSpeed -- OVERHAUL - this should be calculated programatically.

    -- Theres an end of portal track detector to flag when a train reaches the end of the portal track and is ready to enter the tunnel.
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
    -- OVERHAUL: We haven't removed the leaving train's schedule, but it will be in manual mode. Also want to lock it down from being manipulated or damaged.

    -- OVERHAUL staying with Dummy train usage for now, notes on the CreateDummyTrain().
    -- Set up DummyTrain to maintain station requests.
    managedTrain.primaryTrainPartName = PrimaryTrainState.underground
    managedTrain.targetTrainStop = enteringTrain.path_end_stop
    --TODO: put the dummy train behind the end trian detector.
    managedTrain.dummyTrain = TrainManagerFuncs.CreateDummyTrain(managedTrain.aboveExitPortal.entity, enteringTrain.schedule, managedTrain.targetTrainStop, false)
    local dummyTrainId = managedTrain.dummyTrain.id
    managedTrain.dummyTrainId = dummyTrainId
    global.trainManager.trainIdToManagedTrain[dummyTrainId] = {
        trainId = dummyTrainId,
        managedTrain = managedTrain,
        tunnelUsagePart = TunnelUsageParts.dummyTrain
    }

    -- Work out how long it will take to reach the far end at current speed from leading carriages current forward tip.
    local travelDistance = managedTrain.tunnel.tunnelLength
    -- hard coded portal area values for now - Just assume the entering train was at the detector entity. Measured from current setup so good enough for now.
    travelDistance = travelDistance + 71.5
    -- Just assume the speed stays constant at the entering speed for the whole duration for now.
    managedTrain.traversalTotalTicks = travelDistance / managedTrain.tempEnteringSpeed
    managedTrain.traversalStartingTick = game.tick
    managedTrain.traversalArrivalTick = managedTrain.traversalStartingTick + managedTrain.traversalTotalTicks

    -- Destroy entering train's entities as we have finished with them.
    TrainManagerFuncs.DestroyTrainsCarriages(nil, enteringTrain_carriages)
    global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrainId] = nil
    managedTrain.enteringTrain = nil
    managedTrain.enteringTrainId = nil

    -- Complete the state transition.
    Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", managedTrain)
    TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.entered)
end

---@param managedTrain ManagedTrain
---@param currentTick Tick
TrainManager.TrainUndergroundOngoing = function(managedTrain, currentTick)
    -- If the train hasn;t yet reached the exit of the tunnel do required actions and wait.
    if currentTick < managedTrain.traversalArrivalTick then
        TrainManagerPlayerContainers.MoveATrainsPlayerContainers(managedTrain)
        return
    end

    -- Train has arrived and should be activated.
    local leavingTrain = managedTrain.leavingTrain
    TrainManagerFuncs.SetTrainToAuto(leavingTrain, managedTrain.dummyTrain.path_end_stop)
    --OVERHAUL: this may not be safe if the train post recreation is viewed to be facing the other way to when it entered. Just short term hard coded.
    -- should update leavingTrainForwards with the result just incase we need it later.
    leavingTrain.speed = managedTrain.tempEnteringSpeed
    TrainManager.DestroyDummyTrain(managedTrain)

    -- TODO: player needs moving from the container back to the real carriage.
    managedTrain.primaryTrainPartName = PrimaryTrainState.leaving
    TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.leaving)
end

---@param managedTrain ManagedTrain
TrainManager.TrainLeavingOngoing = function(managedTrain)
    -- Track the tunnel's exit portal entry rail signal so we can mark the tunnel as open for the next train when the current train has left. We are assuming that no train gets in to the portal rail segment before our main train gets out. This is far more UPS effecient than checking the trains last carriage and seeing if its end rail signal is our portal entrance one. Must be closed rather than reserved as this is how we cleanly detect it having left (avoids any overlap with other train reserving it same tick this train leaves it).
    local exitPortalEntrySignalEntity = managedTrain.aboveExitPortal.entrySignals[TunnelSignalDirection.inSignal].entity
    if exitPortalEntrySignalEntity.signal_state ~= defines.signal_state.closed then
        -- No train in the block so our one must have left.
        global.trainManager.trainIdToManagedTrain[managedTrain.leavingTrainId] = nil
        managedTrain.leavingTrain = nil
        managedTrain.leavingTrainId = nil
        TrainManager.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.completedTunnelUsage)
    end
end

---@param managedTrain ManagedTrain
TrainManager.TrainOnPortalTrackOngoing = function(managedTrain)
    local entrancePortalEntrySignalEntity = managedTrain.aboveEntrancePortal.entrySignals[TunnelSignalDirection.inSignal].entity

    if not managedTrain.portalTrackTrainBySignal then
        -- Not tracking by singal yet. Initially we have to track the trains speed (direction) to confirm that its still entering until it triggers the Entry signal.
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
                local placedDetectionEntity = Interfaces.Call("TunnelPortals.AddEntranceUsageDetectionEntityToPortal", managedTrain.aboveEntrancePortal, false)
                if placedDetectionEntity then
                    TrainManager.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.portalTrackReleased)
                end
            end
        end
    else
        -- Track the tunnel's entrance portal entry rail signal so we can mark the tunnel as open for the next train if the current train leaves the portal track. Should the train trigger tunnel usage via the END signal this managed train entry will be terminated by that event. We are assuming that no train gets in to the portal rail segment before our main train gets out. This is far more UPS effecient than checking the trains last carriage and seeing if its end rail signal is our portal entrance one.
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

--- Update the passed in train schedule if the train is currently heading for an underground tunnel rail. If so change the target rail to be the end of the portal. Avoids the train infinite loop pathing through the tunnel trying to reach a tunnel rail it never can.
---@param managedTrain ManagedTrain
---@param train LuaTrain
TrainManager.UpdateScheduleForTargetRailBeingTunnelRail = function(managedTrain, train)
    local targetTrainStop, targetRail = train.path_end_stop, train.path_end_rail
    if targetTrainStop == nil and targetRail ~= nil then
        if targetRail.name == "railway_tunnel-invisible_rail-on_map_tunnel" or targetRail.name == "railway_tunnel-invisible_rail-on_map_tunnel" then
            -- The target rail is the type used by a portal/segment for underground rail, so check if it belongs to the just used tunnel.
            if managedTrain.tunnel.tunnelRailEntities[targetRail.unit_number] ~= nil then
                -- The target rail is part of the tunnel, so update the schedule rail to be the one at the end of the portal and just leave the train to do its thing from there.
                local schedule = train.schedule
                local currentScheduleRecord = schedule.records[schedule.current]
                local exitPortalEntryRail = managedTrain.aboveExitPortalEntrySignalOut.entity.get_connected_rails()[1]
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
        TrainManagerFuncs.DestroyTrainsCarriages(managedTrain.dummyTrain)
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

            TrainManagerPlayerContainers.On_TunnelRemoved(managedTrain)

            TrainManager.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.tunnelRemoved)
        end
    end
end

---@param train LuaTrain
---@param aboveEntrancePortalEndSignal PortalEndSignal
---@param traversingTunnel boolean
---@param upgradeManagedTrain ManagedTrain @An existing ManagedTrain object that is being updated/overwritten with fresh data.
---@return ManagedTrain
TrainManager.CreateManagedTrainObject = function(train, aboveEntrancePortalEndSignal, traversingTunnel, upgradeManagedTrain)
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
        aboveEntrancePortalEndSignal = aboveEntrancePortalEndSignal,
        aboveEntrancePortal = aboveEntrancePortalEndSignal.portal,
        tunnel = aboveEntrancePortalEndSignal.portal.tunnel,
        trainTravelDirection = Utils.LoopDirectionValue(aboveEntrancePortalEndSignal.entity.direction + 4),
        tempEnteringSpeed = trainSpeed
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
    managedTrain.aboveSurface = managedTrain.tunnel.aboveSurface
    managedTrain.trainTravelOrientation = Utils.DirectionToOrientation(managedTrain.trainTravelDirection)

    -- Get the exit end signal on the other portal so we know when to bring the train back in.
    for _, portal in pairs(managedTrain.tunnel.portals) do
        if portal.id ~= aboveEntrancePortalEndSignal.portal.id then
            managedTrain.aboveExitPortalEndSignal = portal.endSignals[TunnelSignalDirection.outSignal]
            managedTrain.aboveExitPortal = portal
            managedTrain.aboveExitPortalEntrySignalOut = portal.entrySignals[TunnelSignalDirection.outSignal]
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
            if newPortal.endSignals[managedTrain.aboveEntrancePortalEndSignal.direction].id == managedTrain.aboveEntrancePortalEndSignal.id then
                -- Is entrance portal of this tunnel usage.
                managedTrain.aboveEntrancePortal = newPortal
            elseif newPortal.endSignals[managedTrain.aboveExitPortalEndSignal.direction].id == managedTrain.aboveExitPortalEndSignal.id then
                -- Is exit portal of this tunnel usage.
                managedTrain.aboveExitPortal = newPortal
            else
                error("Portal replaced for tunnel and used by managedTrain, but endSignal not matched\n tunnel id: " .. tunnel.id .. "\nmanagedTrain id: " .. managedTrain.id .. "\nnewPortal id: " .. newPortal.id)
            end
        end
    end
end

---@param managedTrain ManagedTrain
---@param tunnelUsageChangeReason TunnelUsageChangeReason
---@param releaseTunnel boolean|nil @If nil then tunnel is released (true).
TrainManager.TerminateTunnelTrip = function(managedTrain, tunnelUsageChangeReason, releaseTunnel)
    TrainManagerPlayerContainers.On_TerminateTunnelTrip(managedTrain) --OVERHAUL - was conditional on underground train before. May need fixing up.
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

-- Clone the entering train to the front of the end portal. This will minimise any tracking of the train when leaving.
---@param managedTrain ManagedTrain
---@param enteringTrain_carriages LuaEntity[]
---@return LuaTrain
TrainManager.CloneEnteringTrainToExit = function(managedTrain, enteringTrain_carriages)
    -- This currently assumes the portals are in a stright line of each other and that the portal areas are straight.
    local enteringTrain, trainCarriagesForwardOrientation = managedTrain.enteringTrain, managedTrain.trainTravelOrientation
    local targetSurface = managedTrain.aboveSurface
    if not managedTrain.enteringTrainForwards then
        trainCarriagesForwardOrientation = Utils.BoundFloatValueWithinRangeMaxExclusive(trainCarriagesForwardOrientation + 0.5, 0, 1)
    end

    -- Get the position for the front of the lead carriage; 2.5 tiles back from the entry signal. This means the front 3 tiles of the portal area graphics can show the train, with further back needing to be covered to hide the train graphics.
    local exitPortalEntrySignalOutPosition = managedTrain.aboveExitPortalEntrySignalOut.entity.position
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
            carriageOrientation = Utils.BoundFloatValueWithinRangeMaxExclusive(carriageOrientation + 0.5, 0, 1)
        end

        nextCarriagePosition = TrainManagerFuncs.GetNextCarriagePlacementPosition(managedTrain.trainTravelOrientation, nextCarriagePosition, lastPlacedCarriage_name, refCarriage_name)
        lastPlacedCarriage = TrainManagerFuncs.CopyCarriage(targetSurface, refCarriage, nextCarriagePosition, nil, carriageOrientation)
        lastPlacedCarriage_name = refCarriage_name

        -- Handle any players in the train carriage.
        local driver = refCarriage.get_driver()
        if driver ~= nil then
            TrainManagerPlayerContainers.PlayerInCarriageEnteringTunnel(managedTrain, driver, lastPlacedCarriage)
        end
    end

    return lastPlacedCarriage.train
end

return TrainManager
