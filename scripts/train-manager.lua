-- Has the main state tracking and handling logic for Managed Trains.

local TrainManager = {}
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")
local Utils = require("utility/utils")
local TrainManagerStateFuncs = require("scripts/train-manager-stateful-functions")
local TrainManagerFuncs = require("scripts/train-manager-functions")
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
---@field enteringTrainLeadCarriageCache TrainLeadCarriageCache  @Cached details of the lead carriage of the entering train. Is only used and updated during TrainManager.TrainEnteringOngoing() and TrainManager.TrainApproachingOngoing().
---
---@field leavingTrain LuaTrain @The train created leaving the tunnel on the world surface.
---@field leavingTrainId Id @The LuaTrain ID of the above Train Leaving.
---@field leavingTrainForwards boolean @If the train is moving forwards or backwards from its viewpoint.
---@field leavingTrainCarriagesPlaced uint @Count of how many carriages placed so far in the above train while its leaving.
---@field leavingTrainPushingLoco LuaEntity @Locomotive entity pushing the leaving train if it donesn't have a forwards facing locomotive yet, otherwise Nil.
---@field leavingTrainStoppingSignal LuaEntity @The signal entity the leaving train is currently stopping at beyond the portal, or nil.
---@field leavingTrainStoppingSchedule LuaEntity @The rail entity that the leaving train is currently stopping at beyond the portal, or nil.
---@field leavingTrainExpectedBadState boolean @If the leaving train is in a bad state and it can't be corrected. Avoids any repeating checks or trying bad actions, and just waits for the train to naturally path itself.
---@field leavingTrainAtEndOfPortalTrack boolean @If the leaving train is in a bad state and has reached the end of the portal track. It still needs to be checked for rear paths every tick via the mod.
---
---@field leftTrain LuaTrain @The train thats left the tunnel.
---@field leftTrainId Id @The LuaTrain ID of the leftTrain.
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
    Events.RegisterHandlerEvent(defines.events.on_tick, "TrainManager.ProcessManagedTrains", TrainManager.ProcessManagedTrains)
end

-- Light - Assume it can come back in as shouldn't have any cost on regular running of through trains and would require making the tunnel 1 direction otherwise.
---@param enteringTrain LuaTrain
---@param aboveEntrancePortalEndSignal PortalEndSignal
TrainManager.RegisterTrainApproachingPortalSignal = function(enteringTrain, aboveEntrancePortalEndSignal)
    -- Check if this train is already using the tunnel in some way.
    local existingTrainIDTrackedObject = global.trainManager.trainIdToManagedTrain[enteringTrain.id]
    local replacedManagedTrain, upgradeManagedTrain = nil, nil
    if existingTrainIDTrackedObject ~= nil then
        if existingTrainIDTrackedObject.tunnelUsagePart == TunnelUsageParts.leftTrain then
            -- Train was in left state, but is now re-entering. Happens if the train doesn't fully leave the exit portal signal block before coming back in.
            replacedManagedTrain = existingTrainIDTrackedObject.managedTrain
            -- Terminate the old tunnel reservation, but don't release the tunnel as we will just overwrite its user.
            TrainManagerStateFuncs.TerminateTunnelTrip(replacedManagedTrain, TunnelUsageChangeReason.reversedAfterLeft, false)
        elseif existingTrainIDTrackedObject.tunnelUsagePart == TunnelUsageParts.portalTrackTrain then
            -- Train was using the portal track and is now entering the tunnel.
            upgradeManagedTrain = existingTrainIDTrackedObject.managedTrain
            -- Just tidy up the managedTrain's entities its related globals before the new one overwrites it. No tunnel trip to be dealt with.
            TrainManagerStateFuncs.RemoveManagedTrainEntry(upgradeManagedTrain)
        else
            error("Unsupported situation")
        end
    end

    local managedTrain = TrainManagerStateFuncs.CreateManagedTrainObject(enteringTrain, aboveEntrancePortalEndSignal, true, upgradeManagedTrain)
    managedTrain.primaryTrainPartName = PrimaryTrainState.approaching
    Interfaces.Call("Tunnel.TrainReservedTunnel", managedTrain)
    if replacedManagedTrain ~= nil then
        -- Include in the new train approaching event the old leftTrain entry id that has been stopped.
        TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.startApproaching, nil, replacedManagedTrain.id)
    else
        TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.startApproaching)
    end
end

--- Used when a train is claiming a portals track (and thus the tunnel), but not plannign to actively use the tunnel yet. Is like the opposite to a leftTrain monitoring. Only reached by pathing trains that enter the portal track before their breaking distance is the stopping signal or when driven manually.
---@param trainOnPortalTrack LuaTrain
---@param portal Portal
TrainManager.RegisterTrainOnPortalTrack = function(trainOnPortalTrack, portal)
    local managedTrain = TrainManagerStateFuncs.CreateManagedTrainObject(trainOnPortalTrack, portal.endSignals[TunnelSignalDirection.inSignal], false)
    TrainManagerStateFuncs.UpdateScheduleForTargetRailBeingTunnelRail(managedTrain, trainOnPortalTrack)
    managedTrain.primaryTrainPartName = PrimaryTrainState.portalTrack
    TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.onPortalTrack)
end

TrainManager.ProcessManagedTrains = function()
    -- Loop over each train and process it.
    for _, managedTrain in pairs(global.trainManager.managedTrains) do
        TrainManagerFuncs.RunFunctionAndCatchErrors(TrainManager.ProcessManagedTrain, managedTrain)
    end

    TrainManagerRemote.ProcessTicksEvents()
end

---@param managedTrain ManagedTrain
TrainManager.ProcessManagedTrain = function(managedTrain)
    local skipThisTick = false -- Used to provide a "continue" ability as some actions could leave the trains in a weird state this tick and thus error on later functions in the process.

    -- Handle managed trains that are just using portal track first as this just returns.
    if managedTrain.primaryTrainPartName == PrimaryTrainState.portalTrack then
        -- Keep on running until either the train triggers the END signal or the train leaves the portal tracks.
        TrainManager.TrainOnPortalTrackOngoing(managedTrain)
        return
    end

    -- Check dummy train state is valid if it exists. Used in a lot of states so sits outside of them.
    -- OVERHAUL - do we need a dummy train any more ?
    if not skipThisTick and managedTrain.dummyTrain ~= nil and not TrainManagerFuncs.IsTrainHealthlyState(managedTrain.dummyTrain) then
        TrainManager.HandleLeavingTrainBadState("dummyTrain", managedTrain)
        skipThisTick = true
    end

    if not skipThisTick and managedTrain.primaryTrainPartName == PrimaryTrainState.approaching then
        -- Check whether the train is still approaching the tunnel portal as its not committed yet and so can turn away.
        if managedTrain.enteringTrain.state ~= defines.train_state.arrive_signal or managedTrain.enteringTrain.signal ~= managedTrain.aboveEntrancePortalEndSignal.entity then
            TrainManagerStateFuncs.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.abortedApproach)
            skipThisTick = true
        else
            -- Keep on running until the train is committed to entering the tunnel.
            TrainManager.TrainApproachingOngoing(managedTrain)
        end
    end

    if not skipThisTick and managedTrain.primaryTrainPartName == PrimaryTrainState.underground then
        TrainManager.TrainEnteringOngoing(managedTrain)
        TrainManager.TrainUndergroundOngoing(managedTrain)
    -- TODO - OVERHAUL - this is now just train travelling, train already created, just waiting to restart it on leaving time.
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
    -- managedTrain.enteringTrainForwards is updated by SetAbsoluteTrainSpeed().
    local newTrainSpeed = 1 -- OVERHAUL - this should be calculated programatically.
    TrainManagerStateFuncs.SetAbsoluteTrainSpeed(managedTrain, "enteringTrain", math.abs(newTrainSpeed))
    local nextCarriage = TrainManagerStateFuncs.GetEnteringTrainLeadCarriageCache(managedTrain, enteringTrain, managedTrain.enteringTrainForwards)

    -- Check the train is on the same axis as the tunnel and then measure its distance along the rail alignment axis.
    if nextCarriage.position[managedTrain.tunnel.tunnelAlignmentAxis] == managedTrain.aboveEntrancePortal.entity.position[managedTrain.tunnel.tunnelAlignmentAxis] and Utils.GetDistanceSingleAxis(nextCarriage.position, managedTrain.aboveEntrancePortalEndSignal.entity.position, managedTrain.tunnel.railAlignmentAxis) < 14 then
        --TODO: OVERHAUL - need to clone the train to the exit here and take note of metrics we need for calculating the journey. Then remove the entering train entirely.
        -- Use as reference TrainManagerStateFuncs.CreateUndergroundTrainObject()

        -- Train is now committed to use the tunnel so prepare for the entering loop.
        managedTrain.primaryTrainPartName = PrimaryTrainState.underground
        managedTrain.targetTrainStop = enteringTrain.path_end_stop
        managedTrain.dummyTrain = TrainManagerFuncs.CreateDummyTrain(managedTrain.aboveExitPortal.entity, enteringTrain.schedule, managedTrain.targetTrainStop, false)
        local dummyTrainId = managedTrain.dummyTrain.id
        managedTrain.dummyTrainId = dummyTrainId
        global.trainManager.trainIdToManagedTrain[dummyTrainId] = {
            trainId = dummyTrainId,
            managedTrain = managedTrain,
            tunnelUsagePart = TunnelUsageParts.dummyTrain
        }
    end
end

---@param managedTrain ManagedTrain
TrainManager.TrainEnteringOngoing = function(managedTrain)
    local enteringTrain = managedTrain.enteringTrain
    local newTrainSpeed = 1 -- OVERHAUL - this should be calculated programatically.

    -- Force an entering train to stay in manual mode.
    enteringTrain.manual_mode = true

    -- managedTrain.enteringTrainForwards is updated by SetAbsoluteTrainSpeed().
    TrainManagerStateFuncs.SetAbsoluteTrainSpeed(managedTrain, "enteringTrain", math.abs(newTrainSpeed))
    local nextCarriage = TrainManagerStateFuncs.GetEnteringTrainLeadCarriageCache(managedTrain, enteringTrain, managedTrain.enteringTrainForwards)

    -- Only try to remove a carriage if there is a speed. A 0 speed train can occur when a leaving train reverses.
    -- Check the train is on the same axis as the portal and then measure its distance along the rail alignment axis.
    -- OVERHAUL - TODO - this nedes to work out if the entering trian is in position to be committed and then the whole train moved.
    if 1 == 0 then
        -- Handle any player in the train carriage.
        local driver = nextCarriage.get_driver()
        if driver ~= nil then
            TrainManagerPlayerContainers.PlayerInCarriageEnteringTunnel(managedTrain, driver, nextCarriage)
        end

        global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrainId] = nil
        managedTrain.enteringTrain = nil
        managedTrain.enteringTrainId = nil
        Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", managedTrain)
        TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.fullyEntered)
    end
end

---@param managedTrain ManagedTrain
TrainManager.TrainUndergroundOngoing = function(managedTrain)
    TrainManagerPlayerContainers.MoveATrainsPlayerContainers(managedTrain)

    --OVERHAUL - should calculate if the train would be at the end pos yet.
    if 1 == 0 then
        --TODO: OVERHAUL - this should trigger when the train has arrived.
        managedTrain.primaryTrainPartName = PrimaryTrainState.leaving

        TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.fullyLeft)
    end
end

---@param managedTrain ManagedTrain
TrainManager.TrainLeavingOngoing = function(managedTrain)
    -- Track the tunnel's exit portal entry rail signal so we can mark the tunnel as open for the next train when the current train has left. We are assuming that no train gets in to the portal rail segment before our main train gets out. This is far more UPS effecient than checking the trains last carriage and seeing if its end rail signal is our portal entrance one. Must be closed rather than reserved as this is how we cleanly detect it having left (avoids any overlap with other train reserving it same tick this train leaves it).
    local exitPortalEntrySignalEntity = managedTrain.aboveExitPortal.entrySignals[TunnelSignalDirection.inSignal].entity
    if exitPortalEntrySignalEntity.signal_state ~= defines.signal_state.closed then
        -- No train in the block so our one must have left.
        global.trainManager.trainIdToManagedTrain[managedTrain.leftTrainId] = nil
        managedTrain.leftTrain = nil
        managedTrain.leftTrainId = nil
        TrainManagerStateFuncs.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.completedTunnelUsage)
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
                    TrainManagerStateFuncs.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.portalTrackReleased)
                end
            end
        end
    else
        -- Track the tunnel's entrance portal entry rail signal so we can mark the tunnel as open for the next train if the current train leaves the portal track. Should the train trigger tunnel usage via the END signal this managed train entry will be terminated by that event. We are assuming that no train gets in to the portal rail segment before our main train gets out. This is far more UPS effecient than checking the trains last carriage and seeing if its end rail signal is our portal entrance one.
        if entrancePortalEntrySignalEntity.signal_state ~= defines.signal_state.closed then
            -- No train in the block so our one must have left.
            TrainManagerStateFuncs.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.portalTrackReleased)
        end
    end
end

return TrainManager
