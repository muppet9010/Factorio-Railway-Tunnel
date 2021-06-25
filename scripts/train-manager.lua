-- Has the main state tracking and handling logic for Managed Trains.

local TrainManager = {}
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")
local Utils = require("utility/utils")
local TrainManagerStateFuncs = require("scripts/train-manager-stateful-functions")
local TrainManagerFuncs = require("scripts/train-manager-functions")
local TrainManagerPlayerContainers = require("scripts/train-manager-player-containers")
local Common = require("scripts/common")
local TunnelSignalDirection, TunnelUsageChangeReason, LeavingTrainStoppingAtType, TunnelUsageParts, PrimaryTrainPartNames, LeavingTrainStates, UndergroundTrainStates, EnteringTrainStates, TunnelUsageAction = Common.TunnelSignalDirection, Common.TunnelUsageChangeReason, Common.LeavingTrainStoppingAtType, Common.TunnelUsageParts, Common.PrimaryTrainPartNames, Common.LeavingTrainStates, Common.UndergroundTrainStates, Common.EnteringTrainStates, Common.TunnelUsageAction
local TrainManagerRemote = require("scripts/train-manager-remote")

---@class ManagedTrain
---@field id Id @uniqiue id of this managed train passing through the tunnel.
---@field primaryTrainPartName PrimaryTrainPartNames @The primary real train part name that dictates the trains primary monitored object. Finished is for when the tunnel trip is completed.
---
---@field enteringTrainState EnteringTrainStates @The current entering train's state.
---@field enteringTrain LuaTrain
---@field enteringTrainId Id @The enteringTrain LuaTrain id.
---@field enteringTrainForwards boolean @If the train is moving forwards or backwards from its viewpoint.
---@field enteringTrainLeadCarriageCache TrainLeadCarriageCache  @Cached details of the lead carriage of the entering train. Is only used and updated during TrainManager.TrainEnteringOngoing() and TrainManager.TrainApproachingOngoing().
---
---@field undergroundTrainState UndergroundTrainStates @The current underground train's state.
---@field undergroundTrain LuaTrain @The train created in the underground surface.
---@field undergroundTrainSetsSpeed boolean @If the underground train sets the overall speed or if the leading part does.
---@field undergroundTrainForwards boolean @If the train is moving forwards or backwards from its viewpoint.
---@field undergroundTrainCarriageCount uint @Cache of the total underground train carriage count.
---@field undergroundTrainLeadCarriageCache TrainLeadCarriageCache @Cached details of the lead carriage of the underground train. Is only used and updated during TrainManager.TrainUndergroundOngoing().
---@field undergroundTrainOldAbsoluteSpeed double @The absolute speed of the underground train last tick. Updated once enteringStarted up untill fullLeft.
---@field undergroundTrainAForwardsLocoCache LuaEntity @A loco facing forwards in the underground train, no specific one. Populated if the train runs out of fuel, not updated apart from a reversal clears it.
---@field undergroundTrainAForwardsLocoBurnerCache LuaBurner @The cached loco facing forward's burner in the underground train. Populated if the train runs out of fuel, not updated apart from a reversal clears it.
---
---@field leavingTrainState LeavingTrainStates @The current leaving train's state.
---@field leavingTrain LuaTrain @The train created leaving the tunnel on the world surface.
---@field leavingTrainId Id @The LuaTrain ID of the above Train Leaving.
---@field leavingTrainForwards boolean @If the train is moving forwards or backwards from its viewpoint.
---@field leavingTrainCarriagesPlaced uint @Count of how many carriages placed so far in the above train while its leaving.
---@field leavingTrainPushingLoco LuaEntity @Locomotive entity pushing the leaving train if it donesn't have a forwards facing locomotive yet, otherwise Nil.
---@field leavingTrainStoppingSignal LuaEntity @The signal entity the leaving train is currently stopping at beyond the portal, or nil.
---@field leavingTrainStoppingSchedule LuaEntity @The rail entity that the leaving train is currently stopping at beyond the portal, or nil.
---@field leavingTrainExpectedBadState boolean @If the leaving train is in a bad state and it can't be corrected. Avoids any repeating checks or trying bad actions, and just waits for the train to naturally path itself.
---@field leavingTrainAtEndOfPortalTrack boolean @If the leaving train is in a bad state and has reached the end of the portal track. It still needs to be checked for rear paths every tick via the mod.
---@field leavingTrainRearCarriageCache LeavingTrainRearCarriageCache @Cache of the rear carriage of the leaving train. Is only used and updated during TrainManager.TrainLeavingOngoing().
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
---@field undergroundTunnel UndergroundTunnel @Ref to the global tunnel's underground tunnel object.
---@field undergroundLeavingPortalEntrancePosition Position @The underground position equivilent to the portal entrance that the underground train is measured against to decide when it starts leaving.
---
---@field enteringCarriageIdToUndergroundCarriageEntity table<UnitNumber, LuaEntity> @Each entering carriage's unit number to the corrisponding underground carriage entity in the train. Currently used for tracking players riding in a train when it enters.
---@field leavingCarriageIdToUndergroundCarriageEntity table<UnitNumber, LuaEntity> @Each leaving carriage's unit number to the corrisponding underground carriage entity in the train. Currently used for supporting reversal of train and populating new managedTrain.

---@class TrainLeadCarriageCache
---@field trainForwards boolean @If the train was forwards when the cache was last updated.
---@field carriage LuaEntity @Cached ref to the lead carriage entity.

---@class LeavingTrainRearCarriageCache
---@field speedPositive boolean @If the leaving train's speed was positive when the cache was last updated.
---@field carriage LuaEntity @Cached ref to the rear carriage entity

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

---@param enteringTrain LuaTrain
---@param aboveEntrancePortalEndSignal PortalEndSignal
TrainManager.RegisterTrainApproachingPortalSignal = function(enteringTrain, aboveEntrancePortalEndSignal)
    -- Check if this train is already using the tunnel in some way.
    local existingTrainIDTrackedObject, oldManagedTrainEntry, overwriteTunnelReservation = global.trainManager.trainIdToManagedTrain[enteringTrain.id], nil, false
    if existingTrainIDTrackedObject ~= nil then
        if existingTrainIDTrackedObject.tunnelUsagePart == TunnelUsageParts.leftTrain then
            -- Train was in left state, but is now re-entering. Happens if the train doesn't fully leave the exit portal signal block before coming back in.
            oldManagedTrainEntry = existingTrainIDTrackedObject.managedTrain
            -- Terminate the old tunnel usage that was delayed until this point. Don't try to reverse the tunnel usage as this event has naturally happened and the old tunnel usage was effectively over anyways.
            TrainManagerStateFuncs.TerminateTunnelTrip(oldManagedTrainEntry, TunnelUsageChangeReason.reversedAfterLeft)
        elseif existingTrainIDTrackedObject.tunnelUsagePart == TunnelUsageParts.portalTrack then
            -- Train was using the portal track and is now entering the tunnel.
            oldManagedTrainEntry = existingTrainIDTrackedObject.managedTrain
            overwriteTunnelReservation = true
            -- Remove the portalTrack ManagedTrain before the new one is added. The new ManagedTrain will silently take over the reservations.
            TrainManagerStateFuncs.RemoveManagedTrainEntry(oldManagedTrainEntry)
            TrainManagerRemote.TunnelUsageChanged(oldManagedTrainEntry.id, TunnelUsageAction.terminated, TunnelUsageChangeReason.enteringFromPortalTrack)
        else
            error("Unsupported situation")
        end
    end

    local managedTrain = TrainManagerStateFuncs.CreateManagedTrainObject(enteringTrain, aboveEntrancePortalEndSignal, true)
    managedTrain.primaryTrainPartName, managedTrain.enteringTrainState, managedTrain.undergroundTrainState, managedTrain.leavingTrainState = PrimaryTrainPartNames.approaching, EnteringTrainStates.approaching, UndergroundTrainStates.travelling, LeavingTrainStates.pre
    TrainManagerStateFuncs.CreateUndergroundTrainObject(managedTrain)
    if not overwriteTunnelReservation then
        Interfaces.Call("Tunnel.TrainReservedTunnel", managedTrain)
    else
        -- Silently update the tunnel reservation without changing the tunnel entities. Edge case for PortalTrack to Tunnel usage upgrade.
        managedTrain.tunnel.managedTrain = managedTrain
    end
    if oldManagedTrainEntry ~= nil then
        -- Include in the new train approaching event the old leftTrain entry id that has been stopped.
        TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.startApproaching, nil, oldManagedTrainEntry.id)
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
    managedTrain.primaryTrainPartName = PrimaryTrainPartNames.portalTrack
    Interfaces.Call("Tunnel.TrainReservedTunnel", managedTrain)
    TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.portalTrack)
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
    if managedTrain.primaryTrainPartName == PrimaryTrainPartNames.portalTrack then
        -- Keep on running until either the train triggers the END signal or the train leaves the portal tracks.
        TrainManager.TrainOnPortalTrackOngoing(managedTrain)
        return
    end

    -- Check dummy train state is valid if it exists. Used in a lot of states so sits outside of them.
    if not skipThisTick and managedTrain.dummyTrain ~= nil and not TrainManagerFuncs.IsTrainHealthlyState(managedTrain.dummyTrain) then
        TrainManager.HandleLeavingTrainBadState("dummyTrain", managedTrain)
        skipThisTick = true
    end

    if not skipThisTick and managedTrain.primaryTrainPartName == PrimaryTrainPartNames.approaching then
        -- Check whether the train is still approaching the tunnel portal as its not committed yet and so can turn away.
        if managedTrain.enteringTrain.state ~= defines.train_state.arrive_signal or managedTrain.enteringTrain.signal ~= managedTrain.aboveEntrancePortalEndSignal.entity then
            TrainManagerStateFuncs.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.abortedApproach)
            skipThisTick = true
        else
            -- Keep on running until the train is committed to entering the tunnel.
            TrainManager.TrainApproachingOngoing(managedTrain)
        end
    end

    if not skipThisTick and managedTrain.enteringTrainState == EnteringTrainStates.entering then
        -- Keep on running until the entire train has entered the tunnel. Ignores primary state.
        TrainManager.TrainEnteringOngoing(managedTrain)
    end

    if not skipThisTick and managedTrain.primaryTrainPartName == PrimaryTrainPartNames.underground then
        -- Run just while the underground train is the primary train part. Detects when the train can start leaving.
        TrainManager.TrainUndergroundOngoing(managedTrain)
    end

    if not skipThisTick and managedTrain.primaryTrainPartName == PrimaryTrainPartNames.leaving then
        if managedTrain.leavingTrainState == LeavingTrainStates.leavingFirstCarriage then
            -- Only runs for the first carriage and then changes to the ongoing for the remainder.
            TrainManager.TrainLeavingFirstCarriage(managedTrain)
        elseif managedTrain.leavingTrainState == LeavingTrainStates.leaving then
            -- Check the leaving trains state and react accordingly
            if managedTrain.leavingTrainExpectedBadState then
                -- The train is known to have reached a bad state and is staying in it. We need to monitor the leaving train returning to a healthy state with a path, rather than try to fix the bad state.
                if TrainManagerFuncs.IsTrainHealthlyState(managedTrain.leavingTrain) and managedTrain.leavingTrain.has_path then
                    -- Leaving train is healthy again with a path so return everything to active.
                    managedTrain.undergroundTrainSetsSpeed = true
                    managedTrain.undergroundTrain.manual_mode = false
                    managedTrain.leavingTrainExpectedBadState = false
                    managedTrain.leavingTrainAtEndOfPortalTrack = false
                end
            elseif not TrainManagerFuncs.IsTrainHealthlyState(managedTrain.leavingTrain) then
                -- Check if the leaving train is in a good state before we check to add any new wagons to it.
                TrainManager.HandleLeavingTrainBadState("leavingTrain", managedTrain)
                skipThisTick = true
            else
                -- Keep on running until the entire train has left the tunnel.
                TrainManager.TrainLeavingOngoing(managedTrain)
            end
        end
    end

    if not skipThisTick and managedTrain.primaryTrainPartName == PrimaryTrainPartNames.leaving and managedTrain.leavingTrainState == LeavingTrainStates.trainLeftTunnel then
        -- Keep on running until the entire train has left the tunnel's exit rail segment.
        TrainManager.TrainLeftTunnelOngoing(managedTrain)
    end
end

---@param trainWithBadStateName LuaTrain
---@param managedTrain ManagedTrain
TrainManager.HandleLeavingTrainBadState = function(trainWithBadStateName, managedTrain)
    local trainWithBadState = managedTrain[trainWithBadStateName] ---@type LuaTrain

    -- Check if the train can just path now as trains don't try and repath every tick. So sometimes they can path forwards on their own, they just haven't realised yet.
    if trainWithBadState.recalculate_path() then
        if trainWithBadStateName == "dummyTrain" then
            -- Just return as the dummy train doesn't handle reversing itself.
            return
        elseif trainWithBadStateName == "leavingTrain" then
            -- Check if the train is pathing in the expected direction or has just reversed on its own.
            if TrainManagerStateFuncs.Check0OnlySpeedTrainWithLocoGoingExpectedDirection(managedTrain, trainWithBadStateName, 1) then
                -- Train restarted in expected direction
                return
            else
                -- Train has repathed backwards
                managedTrain.targetTrainStop = trainWithBadState.path_end_stop -- Update this cached value as we know its been updated and the old is invalid.
                TrainManager.ReverseManagedTrainTunnelTrip(managedTrain)
                return
            end
        else
            error("TrainManager.HandleLeavingTrainBadState() unsupported trainWithBadStateName:" .. tostring(trainWithBadStateName))
        end
    end

    -- Check if the full train can reverse in concept.
    local undergroundTrainReverseLocoListName, undergroundTrain = nil, managedTrain.undergroundTrain
    local undergroundTrainSpeed = undergroundTrain.speed
    if undergroundTrainSpeed > 0 then
        undergroundTrainReverseLocoListName = "back_movers"
    elseif undergroundTrainSpeed < 0 then
        undergroundTrainReverseLocoListName = "front_movers"
    elseif managedTrain.undergroundTrainForwards then
        undergroundTrainReverseLocoListName = "back_movers"
    elseif not managedTrain.undergroundTrainForwards then
        undergroundTrainReverseLocoListName = "front_movers"
    else
        error("TrainManager.HandleLeavingTrainBadState() doesn't support 0 speed underground train with no cached forwards state\nundergroundTrain id: " .. undergroundTrain.id)
    end
    local undergroundTrainReverseLocos = undergroundTrain.locomotives[undergroundTrainReverseLocoListName]
    if #undergroundTrainReverseLocos > 0 then
        ---@typelist boolean, LuaTrain
        local canPathBackwards, enteringTrain = false, managedTrain.enteringTrain
        local schedule, isManual, targetTrainStop = trainWithBadState.schedule, trainWithBadState.manual_mode, managedTrain.targetTrainStop -- Use cached targetTrainStop as the main train has likely lost its value in this state.
        local oldEnteringSchedule, oldEnteringIsManual, oldEnteringSpeed
        if managedTrain.enteringTrainState == EnteringTrainStates.entering then
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
            elseif managedTrain.enteringTrainForwards then
                reverseLocoListName = "back_movers"
                enteringTrainFrontCarriage = enteringTrain.front_stock
            elseif not managedTrain.enteringTrainForwards then
                reverseLocoListName = "front_movers"
                enteringTrainFrontCarriage = enteringTrain.back_stock
            else
                error("TrainManager.HandleLeavingTrainBadState() doesn't support 0 speed entering train with no cached forwards state\nenteringTrain id: " .. enteringTrain.id)
            end
            if #enteringTrain.locomotives[reverseLocoListName] == 0 then
                -- Put the loco at the front of the leaving train backwards to the trains current orientation. As we want to test reversing the trains current direction.
                enteringTrainReversePushingLoco = TrainManagerFuncs.AddPushingLocoToAfterCarriage(enteringTrainFrontCarriage, Utils.BoundFloatValueWithinRange(managedTrain.trainTravelOrientation + 0.5, 0, 1))
                enteringTrain = managedTrain.enteringTrain -- Update as the reference will have been broken.
            end

            -- Set a path with the new train
            TrainManagerFuncs.TrainSetSchedule(enteringTrain, schedule, isManual, targetTrainStop, true)
            if enteringTrain.has_path then
                canPathBackwards = true
                managedTrain.targetTrainStop = enteringTrain.path_end_stop -- Update this cached value as we know its been updated and te old is invalid.
            end

            -- Remove temp reversing loco if added.
            if enteringTrainReversePushingLoco ~= nil then
                enteringTrainReversePushingLoco.destroy()
                enteringTrain = managedTrain.enteringTrain -- Update as the reference will have been broken.
            end
        else
            -- Handle trains that have fully entered the tunnel.
            local pathTestTrain = TrainManagerFuncs.CreateDummyTrain(managedTrain.aboveEntrancePortal.entity, nil, nil, true)
            TrainManagerFuncs.TrainSetSchedule(pathTestTrain, schedule, isManual, targetTrainStop, true)
            if pathTestTrain.has_path then
                canPathBackwards = true
                managedTrain.targetTrainStop = pathTestTrain.path_end_stop -- Update this cached value as we know its been updated and te old is invalid.
            end
            TrainManagerFuncs.DestroyTrainsCarriages(pathTestTrain)
        end

        if canPathBackwards then
            TrainManager.ReverseManagedTrainTunnelTrip(managedTrain)
            return
        else
            if managedTrain.enteringTrainState == EnteringTrainStates.entering then
                -- Set the enteringTrain schedule, state and speed back to what it was before the repath attempt. This preserves the enteringTrain travel direction.
                TrainManagerFuncs.TrainSetSchedule(enteringTrain, oldEnteringSchedule, oldEnteringIsManual, targetTrainStop, true)
                enteringTrain.speed = oldEnteringSpeed
            end
        end
    end

    if managedTrain.leavingTrainAtEndOfPortalTrack then
        -- Train is already at end of track so don't change its schedule.
        return
    end

    -- Handle train that can't go backwards, so just pull the train forwards to the end of the tunnel (signal segment) and then return to its preivous schedule. Makes the situation more obvious for the player and easier to access the train. The train has already lost any station reservation it had.
    local newSchedule = trainWithBadState.schedule
    local exitPortalEntryRail = managedTrain.aboveExitPortalEntrySignalOut.entity.get_connected_rails()[1] ---@type LuaEntity
    local endOfTunnelScheduleRecord = {rail = exitPortalEntryRail, temporary = true}
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
        managedTrain.undergroundTrainSetsSpeed = false
        undergroundTrain.manual_mode = true
        undergroundTrain.speed = 0

        -- Work out the correct persistent state to tag the train as. Will affect what repathing checks are done per tick going forwards.
        if #undergroundTrainReverseLocos > 0 then
            -- Train can conceptually repath backwards so let this modded backwards path check keep on trying.
            managedTrain.leavingTrainExpectedBadState = false
            managedTrain.leavingTrainAtEndOfPortalTrack = true
        else
            -- Train can't repath backwards, so just wait for a natural path to be found.
            managedTrain.leavingTrainExpectedBadState = true
            managedTrain.leavingTrainAtEndOfPortalTrack = false
        end
    end
end

---@param managedTrain ManagedTrain
TrainManager.TrainApproachingOngoing = function(managedTrain)
    TrainManagerStateFuncs.UpdatePortalExitSignalPerTick(managedTrain)
    local enteringTrain = managedTrain.enteringTrain ---@type LuaTrain
    local undergroundTrainSpeed = managedTrain.undergroundTrain.speed
    -- managedTrain.enteringTrainForwards is updated by SetAbsoluteTrainSpeed().
    TrainManagerStateFuncs.SetAbsoluteTrainSpeed(managedTrain, "enteringTrain", math.abs(undergroundTrainSpeed))
    local nextCarriage = TrainManagerStateFuncs.GetEnteringTrainLeadCarriageCache(managedTrain, enteringTrain, managedTrain.enteringTrainForwards)

    -- Check the train is on the same axis as the tunnel and then measure its distance along the rail alignment axis.
    if nextCarriage.position[managedTrain.tunnel.tunnelAlignmentAxis] == managedTrain.aboveEntrancePortal.entity.position[managedTrain.tunnel.tunnelAlignmentAxis] and Utils.GetDistanceSingleAxis(nextCarriage.position, managedTrain.aboveEntrancePortalEndSignal.entity.position, managedTrain.tunnel.railAlignmentAxis) < 14 then
        -- Train is now committed to use the tunnel so prepare for the entering loop.
        managedTrain.enteringTrainState = EnteringTrainStates.entering
        managedTrain.primaryTrainPartName = PrimaryTrainPartNames.underground
        managedTrain.targetTrainStop = enteringTrain.path_end_stop
        managedTrain.dummyTrain = TrainManagerFuncs.CreateDummyTrain(managedTrain.aboveExitPortal.entity, enteringTrain.schedule, managedTrain.targetTrainStop, false)
        local dummyTrainId = managedTrain.dummyTrain.id
        managedTrain.dummyTrainId = dummyTrainId
        global.trainManager.trainIdToManagedTrain[dummyTrainId] = {
            trainId = dummyTrainId,
            managedTrain = managedTrain,
            tunnelUsagePart = TunnelUsageParts.dummyTrain
        }
        managedTrain.undergroundTrainOldAbsoluteSpeed = math.abs(undergroundTrainSpeed)

        TrainManagerStateFuncs.HandleTrainNewlyEntering(managedTrain)

        TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.startedEntering) -- The same tick the first carriage will be removed by TrainManager.TrainEnteringOngoing() and this will fire an event.
    end
end
---@param managedTrain ManagedTrain
TrainManager.TrainEnteringOngoing = function(managedTrain)
    local enteringTrain = managedTrain.enteringTrain
    local undergroundTrainSpeed = managedTrain.undergroundTrain.speed

    -- Only update these when we aren't leaving. As a very long train can be entering and leaving at the same time.
    if managedTrain.leavingTrainState == LeavingTrainStates.pre then
        TrainManagerStateFuncs.UpdatePortalExitSignalPerTick(managedTrain)
        TrainManagerStateFuncs.EnsureManagedTrainsFuel(managedTrain, math.abs(undergroundTrainSpeed))
    end

    -- Force an entering train to stay in manual mode.
    enteringTrain.manual_mode = true

    -- managedTrain.enteringTrainForwards is updated by SetAbsoluteTrainSpeed().
    TrainManagerStateFuncs.SetAbsoluteTrainSpeed(managedTrain, "enteringTrain", math.abs(undergroundTrainSpeed))
    local nextCarriage = TrainManagerStateFuncs.GetEnteringTrainLeadCarriageCache(managedTrain, enteringTrain, managedTrain.enteringTrainForwards)

    -- Only try to remove a carriage if there is a speed. A 0 speed train can occur when a leaving train reverses.
    -- Check the train is on the same axis as the portal and then measure its distance along the rail alignment axis.
    if undergroundTrainSpeed ~= 0 and nextCarriage.position[managedTrain.tunnel.tunnelAlignmentAxis] == managedTrain.aboveEntrancePortal.entity.position[managedTrain.tunnel.tunnelAlignmentAxis] and Utils.GetDistanceSingleAxis(nextCarriage.position, managedTrain.aboveEntrancePortalEndSignal.entity.position, managedTrain.tunnel.railAlignmentAxis) < 14 then
        -- Handle any player in the train carriage.
        local driver = nextCarriage.get_driver()
        if driver ~= nil then
            TrainManagerPlayerContainers.PlayerInCarriageEnteringTunnel(managedTrain, driver, nextCarriage)
        end

        nextCarriage.destroy()
        -- Update local variable as new train number after removing carriage.
        enteringTrain = managedTrain.enteringTrain

        -- Removing a carriage can flip the trains direction. Only detect if there is a non 0 speed.
        if enteringTrain ~= nil and enteringTrain.valid and undergroundTrainSpeed ~= 0 then
            local positiveSpeed = enteringTrain.speed > 0
            if positiveSpeed ~= managedTrain.enteringTrainForwards then
                -- Speed and cached forwards state don't match, so flip cached forwards state.
                managedTrain.enteringTrainForwards = not managedTrain.enteringTrainForwards
            end
        end

        -- Force the cache to be updated if the train still exists.
        if enteringTrain.valid then
            TrainManagerStateFuncs.GetEnteringTrainLeadCarriageCache(managedTrain, enteringTrain, nil)
        end

        TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.enteringCarriageRemoved)
    end

    if not enteringTrain.valid then
        -- Train has completed entering.
        managedTrain.enteringTrainState = EnteringTrainStates.finished
        global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrainId] = nil
        managedTrain.enteringTrain = nil
        managedTrain.enteringTrainId = nil
        managedTrain.enteringCarriageIdToUndergroundCarriageEntity = nil
        Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", managedTrain)
        TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.fullyEntered)
    end
end

---@param managedTrain ManagedTrain
TrainManager.TrainUndergroundOngoing = function(managedTrain)
    TrainManagerPlayerContainers.MoveATrainsPlayerContainers(managedTrain)

    -- If the train is still entering then that is doing the updating. This underground function isn't looping once the train is leaving.
    if managedTrain.enteringTrainState == EnteringTrainStates.finished then
        TrainManagerStateFuncs.UpdatePortalExitSignalPerTick(managedTrain)
        TrainManagerStateFuncs.EnsureManagedTrainsFuel(managedTrain, math.abs(managedTrain.undergroundTrain.speed))
    end

    -- Check if the lead carriage is close enough to the exit portal's entry signal to be safely in the leaving tunnel area.
    -- Gets the cached lead carriage and records if needed.
    local leadCarriage
    if managedTrain.undergroundTrainLeadCarriageCache == nil or managedTrain.undergroundTrainLeadCarriageCache.trainForwards ~= managedTrain.undergroundTrainForwards then
        -- No cache entry or cache exists, but needs updating.
        leadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(managedTrain.undergroundTrain, managedTrain.undergroundTrainForwards)
        managedTrain.undergroundTrainLeadCarriageCache = {
            trainForwards = managedTrain.undergroundTrainForwards,
            carriage = leadCarriage
        }
    else
        -- Use the cache lead carriage.
        leadCarriage = managedTrain.undergroundTrainLeadCarriageCache.carriage
    end
    if Utils.GetDistanceSingleAxis(leadCarriage.position, managedTrain.undergroundLeavingPortalEntrancePosition, managedTrain.tunnel.railAlignmentAxis) <= 30 then
        managedTrain.primaryTrainPartName = PrimaryTrainPartNames.leaving
        managedTrain.leavingTrainState = LeavingTrainStates.leavingFirstCarriage
    end
end

---@param managedTrain ManagedTrain
TrainManager.TrainLeavingFirstCarriage = function(managedTrain)
    TrainManagerStateFuncs.UpdateScheduleForTargetRailBeingTunnelRail(managedTrain, managedTrain.dummyTrain)

    -- Cleanup dummy train to make room for the reemerging train, preserving schedule and target stop for later.
    local schedule, isManual, targetTrainStop = managedTrain.dummyTrain.schedule, managedTrain.dummyTrain.manual_mode, managedTrain.dummyTrain.path_end_stop
    TrainManagerStateFuncs.DestroyDummyTrain(managedTrain)

    -- Place initial leaving train carriage and set schedule and speed back.
    local placedCarriage, undergroundLeadCarriage = TrainManagerStateFuncs.CreateFirstCarriageForLeavingTrain(managedTrain)
    TrainManagerFuncs.TrainSetSchedule(managedTrain.leavingTrain, schedule, isManual, targetTrainStop)

    -- Follow up items post train creation.
    TrainManagerPlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage(undergroundLeadCarriage, placedCarriage)
    Interfaces.Call("Tunnel.TrainStartedExitingTunnel", managedTrain)
    TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.startedLeaving)
    TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.leavingCarriageAdded)
    TrainManagerStateFuncs.UpdatePortalExitSignalPerTick(managedTrain, defines.signal_state.open) -- Reset the underground Exit signal state as the leaving train will now detect any signals.
    managedTrain.undergroundTrainSetsSpeed = true

    -- Check if all train wagons placed and train fully left the tunnel, otherwise set state for future carriages with the ongoing state.
    if managedTrain.leavingTrainCarriagesPlaced == managedTrain.undergroundTrainCarriageCount then
        TrainManager.TrainLeavingCompleted(managedTrain, nil)
    else
        managedTrain.leavingTrainState = LeavingTrainStates.leaving
    end
end

---@param managedTrain ManagedTrain
TrainManager.TrainLeavingOngoing = function(managedTrain)
    -- Handle if the train is stopping at a signal or scheduled stop (train-stop or rail). Updates managedTrain.undergroundTrainSetsSpeed and the underground train path if required.
    TrainManager.HandleLeavingTrainStoppingAtSignalSchedule(managedTrain, LeavingTrainStoppingAtType.signal)
    TrainManager.HandleLeavingTrainStoppingAtSignalSchedule(managedTrain, LeavingTrainStoppingAtType.schedule)

    local undergroundTrainSpeed = managedTrain.undergroundTrain.speed
    TrainManagerStateFuncs.EnsureManagedTrainsFuel(managedTrain, math.abs(undergroundTrainSpeed))

    -- Get the desired speed for this tick.
    local desiredSpeed
    local leavingTrainSpeed = managedTrain.leavingTrain.speed
    if managedTrain.undergroundTrainSetsSpeed then
        desiredSpeed = math.abs(undergroundTrainSpeed)
    else
        desiredSpeed = math.abs(leavingTrainSpeed)
    end

    -- Check if the leaving train has stopped, but the underground train is moving. This should only occur when the leaving train has lost its path and naturally is pathing back through the tunnel. As otherwise the state check would have caught it already this tick.
    if desiredSpeed ~= 0 and leavingTrainSpeed == 0 then
        -- Theres nothing broken with the state, but the mod doesn't expect it so we need to identify if the train is reversing on its own accord. We have to do this rather than a front/rear stock check as theres no train composition change to test around here. Its just what the base game thinks the train is doing.
        if not TrainManagerStateFuncs.Check0OnlySpeedTrainWithLocoGoingExpectedDirection(managedTrain, "leavingTrain", desiredSpeed) then
            -- The leaving train is moving opposite to the underground train (desiredSpeed). So handle the reversal and stop processing.
            managedTrain.targetTrainStop = managedTrain.leavingTrain.path_end_stop -- Update this cached value as we know its been updated and te old is invalid.
            TrainManager.ReverseManagedTrainTunnelTrip(managedTrain)
            return
        end
    end
    -- Unless the underground and leaving train are both moving we never want to add a carriage.
    if desiredSpeed ~= 0 and leavingTrainSpeed ~= 0 then
        -- Cache the rear carriage as quicker than having to get it every tick.
        local leavingTrainRearCarriage
        if managedTrain.leavingTrainRearCarriageCache == nil or managedTrain.leavingTrainRearCarriageCache.speedPositive ~= (leavingTrainSpeed > 0) then
            -- No cache entry or cache exists, but needs updating.
            leavingTrainRearCarriage = TrainManagerFuncs.GetRearCarriageOfLeavingTrain(managedTrain.leavingTrain, managedTrain.leavingTrainPushingLoco)
            managedTrain.leavingTrainRearCarriageCache = {
                speedPositive = leavingTrainSpeed > 0,
                carriage = leavingTrainRearCarriage
            }
        else
            -- Use the cache rear carriage.
            leavingTrainRearCarriage = managedTrain.leavingTrainRearCarriageCache.carriage
        end
        if Utils.GetDistanceSingleAxis(leavingTrainRearCarriage.position, managedTrain.aboveExitPortalEndSignal.entity.position, managedTrain.tunnel.railAlignmentAxis) > 20 then
            -- Reattaching next carriage can clobber speed, schedule and will set train to manual, so preserve state.
            local scheduleBeforeCarriageAttachment, isManualBeforeCarriageAttachment, targetTrainStopBeforeCarriageAttachment, leavingAbsoluteSpeedBeforeCarriageAttachment = managedTrain.leavingTrain.schedule, managedTrain.leavingTrain.manual_mode, managedTrain.leavingTrain.path_end_stop, math.abs(leavingTrainSpeed)

            -- Place new leaving train carriage and set schedule back.
            local nextSourceCarriageEntity = TrainManagerFuncs.GetCarriageToAddToLeavingTrain(managedTrain.undergroundTrain, managedTrain.leavingTrainCarriagesPlaced)
            local placedCarriage = TrainManagerStateFuncs.AddCarriageToLeavingTrain(managedTrain, nextSourceCarriageEntity, leavingTrainRearCarriage)
            TrainManagerFuncs.TrainSetSchedule(managedTrain.leavingTrain, scheduleBeforeCarriageAttachment, isManualBeforeCarriageAttachment, targetTrainStopBeforeCarriageAttachment)

            -- Set the trains speed back to what it was before we added the carriage. This will update the global facing forwards state and correct any speed loss when the carriage was added (base Factorio behavour).
            TrainManagerStateFuncs.SetAbsoluteTrainSpeed(managedTrain, "leavingTrain", leavingAbsoluteSpeedBeforeCarriageAttachment)

            -- Follow up items post leaving train carriage addition.
            TrainManagerPlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage(nextSourceCarriageEntity, placedCarriage)
            TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.leavingCarriageAdded)
            managedTrain.leavingTrainRearCarriageCache = {
                speedPositive = managedTrain.leavingTrain.speed > 0,
                carriage = TrainManagerFuncs.GetRearCarriageOfLeavingTrain(managedTrain.leavingTrain, managedTrain.leavingTrainPushingLoco)
            }

            -- Check if all train wagons placed and train fully left the tunnel.
            if managedTrain.leavingTrainCarriagesPlaced == managedTrain.undergroundTrainCarriageCount then
                TrainManagerStateFuncs.SetAbsoluteTrainSpeed(managedTrain, "leavingTrain", desiredSpeed)
                TrainManager.TrainLeavingCompleted(managedTrain)
                return
            end
        end

        -- Follow up items for the ontick, rather than related to a carriage being added.
        TrainManagerPlayerContainers.MoveATrainsPlayerContainers(managedTrain)
    end

    -- Update which ever train isn't setting the desired speed.
    if managedTrain.undergroundTrainSetsSpeed then
        TrainManagerStateFuncs.SetAbsoluteTrainSpeed(managedTrain, "leavingTrain", desiredSpeed)
    else
        TrainManagerStateFuncs.SetAbsoluteTrainSpeed(managedTrain, "undergroundTrain", desiredSpeed)
    end
end

---@param managedTrain ManagedTrain
---@param arriveAt LeavingTrainStoppingAtType
TrainManager.HandleLeavingTrainStoppingAtSignalSchedule = function(managedTrain, arriveAt)
    -- Handles a train leaving a tunnel arriving at a station/signal based on input. Updated global state data that impacts TrainManager.TrainLeavingOngoing(): managedTrain.undergroundTrainSetsSpeed and underground train path target.
    local leavingTrain, trainStoppingEntityAttributeName, stoppingTargetEntityAttributeName, arriveAtReleventStoppingTarget = managedTrain.leavingTrain, nil, nil, nil
    if arriveAt == LeavingTrainStoppingAtType.signal then
        trainStoppingEntityAttributeName = "signal"
        stoppingTargetEntityAttributeName = "leavingTrainStoppingSignal"
        arriveAtReleventStoppingTarget = leavingTrain.state == defines.train_state.arrive_signal
    elseif arriveAt == LeavingTrainStoppingAtType.schedule then
        -- Type of schedule includes both train-stop's and rail's. But we can always just use the end rail attribute for both.
        trainStoppingEntityAttributeName = "path_end_rail"
        stoppingTargetEntityAttributeName = "leavingTrainStoppingSchedule"
        arriveAtReleventStoppingTarget = leavingTrain.state == defines.train_state.arrive_station
    else
        error("TrainManager.HandleLeavingTrainStoppingAtSignalSchedule() unsuported arriveAtName: " .. tostring(arriveAt))
    end
    local managedTrainStoppingTargetEntityAttribute = managedTrain[stoppingTargetEntityAttributeName]

    -- 1: If leaving train is now arriving at a relvent stopping target (station or signal) check state in detail as we may need to update the underground train stop point.
    -- 2: Once the leaving train is stopped at a relevent stopping target, clear out stopping target arriving state.
    -- 3: Otherwise check for moving away states and if there was a preivous stopping state to be finished.
    if arriveAtReleventStoppingTarget then
        -- If a known stopping target was set, make sure it still exists.
        if managedTrainStoppingTargetEntityAttribute ~= nil and not managedTrainStoppingTargetEntityAttribute.valid then
            managedTrain[stoppingTargetEntityAttributeName] = nil
            managedTrain.undergroundTrainSetsSpeed = true
        end

        -- Check the stopping target is the expected one, if not reset state to detect new stopping target.
        if managedTrainStoppingTargetEntityAttribute ~= nil and leavingTrain[trainStoppingEntityAttributeName].unit_number ~= managedTrainStoppingTargetEntityAttribute.unit_number then
            managedTrain[stoppingTargetEntityAttributeName] = nil
            managedTrain.undergroundTrainSetsSpeed = true
        end

        -- 1: If there's no expected stopping target then record state and update leaving and underground trains activities.
        -- 2: Otherwise its the same stopping target as previously, so if the underground train is setting the speed need to check distance from stopping target and hand over control to leaving train if close.
        if managedTrainStoppingTargetEntityAttribute == nil then
            -- The above ground and underground trains will never be exactly relational to one another as they change speed each tick differently before they are re-aligned. So the underground train should be targetted as an offset from its current location and when the above train is very near the stopping target the above train can take over setting speed to manage the final pulling up.
            managedTrain[stoppingTargetEntityAttributeName] = leavingTrain[trainStoppingEntityAttributeName]

            local exactDistanceFromTrainToTarget
            if arriveAt == LeavingTrainStoppingAtType.schedule then
                -- For a station this is where the path goes, otherwise the train would never be stopping at it.
                exactDistanceFromTrainToTarget = TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTargetStation(leavingTrain, managedTrain.leavingTrainForwards) - 1 -- The -1 is to avoid any slight over reaching on to the next rail. Better to be short than long.
            else
                -- For a signal we have to find the distance via the path rails.
                exactDistanceFromTrainToTarget = TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTarget(leavingTrain, leavingTrain[trainStoppingEntityAttributeName], managedTrain.leavingTrainForwards) - 1 -- The -1 is to avoid any slight over reaching on to the next rail. Better to be short than long.
            end
            local undergroundTrainTargetPosition = TrainManagerFuncs.GetForwardPositionFromCurrentForDistance(managedTrain.undergroundTrain, exactDistanceFromTrainToTarget)

            -- Avoid looking for a rail exactly on the deviding line between 2 tracks.
            if undergroundTrainTargetPosition[managedTrain.tunnel.railAlignmentAxis] % 1 < 0.1 then
                undergroundTrainTargetPosition[managedTrain.tunnel.railAlignmentAxis] = math.floor(undergroundTrainTargetPosition[managedTrain.tunnel.railAlignmentAxis]) + 0.1
            elseif undergroundTrainTargetPosition[managedTrain.tunnel.railAlignmentAxis] % 1 > 0.9 then
                undergroundTrainTargetPosition[managedTrain.tunnel.railAlignmentAxis] = math.floor(undergroundTrainTargetPosition[managedTrain.tunnel.railAlignmentAxis]) + 0.9
            end

            TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition(managedTrain.undergroundTrain, undergroundTrainTargetPosition)
            managedTrain.undergroundTrainSetsSpeed = true
        elseif managedTrain.undergroundTrainSetsSpeed then
            -- Is the same stopping target as last tick, so check if the leaving train is close to the stopping target and give it speed control if so.
            local leadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(leavingTrain, managedTrain.leavingTrainForwards)
            local leadCarriageDistanceFromStoppingEntity = Utils.GetDistance(leadCarriage.position, managedTrainStoppingTargetEntityAttribute.position)
            local leavingTrainCloseToStoppingEntityDistance = Common.GetCarriagePlacementDistance(leadCarriage.name) + 4 -- This is the length of the leading carriage plus 4 tiles leaway so the speed handover isn't too abrupt. May be a bit abrupt if leaving train is lacking loco's to carriages though, compared to full underground train.
            if leadCarriageDistanceFromStoppingEntity < leavingTrainCloseToStoppingEntityDistance then
                managedTrain.undergroundTrainSetsSpeed = false
            end
        end
    elseif managedTrainStoppingTargetEntityAttribute ~= nil and leavingTrain.state == defines.train_state.on_the_path then
        -- If the train was stopped/stopping at a stopping target and now is back on the path, return to underground train setting speed and assume everything is back to normal.
        managedTrain[stoppingTargetEntityAttributeName] = nil
        managedTrain.undergroundTrainSetsSpeed = true
        managedTrain.undergroundTrain.manual_mode = false
        local undergroundTrainEndScheduleTargetPos = Interfaces.Call("Underground.GetForwardsEndOfRailPosition", managedTrain.tunnel.undergroundTunnel, managedTrain.trainTravelOrientation)
        TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition(managedTrain.undergroundTrain, undergroundTrainEndScheduleTargetPos)
    end
end

---@param managedTrain ManagedTrain
TrainManager.TrainLeavingCompleted = function(managedTrain)
    TrainManagerStateFuncs.DestroyUndergroundTrain(managedTrain)

    managedTrain.leftTrain, managedTrain.leftTrainId = managedTrain.leavingTrain, managedTrain.leavingTrainId
    global.trainManager.trainIdToManagedTrain[managedTrain.leavingTrainId].tunnelUsagePart = TunnelUsageParts.leftTrain -- Keep the table, just update its state, as same train id, etc between the leaving and left train at this state change point.
    managedTrain.leavingTrainState = LeavingTrainStates.trainLeftTunnel
    managedTrain.undergroundTrainState = UndergroundTrainStates.finished
    managedTrain.leavingTrainId = nil
    managedTrain.leavingTrain = nil

    TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.fullyLeft)
end

---@param managedTrain ManagedTrain
TrainManager.TrainLeftTunnelOngoing = function(managedTrain)
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

---@param oldManagedTrain ManagedTrain
TrainManager.ReverseManagedTrainTunnelTrip = function(oldManagedTrain)
    -- The managed train is going to reverse and go out of the tunnel the way it came in. Will be lodged as a new managed train so that old managed trains logic can be closed off.
    -- This function can't be reached if the train isn't committed, so no need to handle EnteringTrainStates.approaching.

    if oldManagedTrain.targetTrainStop ~= nil and not oldManagedTrain.targetTrainStop.valid then
        error("Should be either valid or nil. Meant to be updated when the reversal function is called.")
    end

    -- Release the tunnel from the old train manager. Later in this function it will be reclaimed accordingly.
    Interfaces.Call("Tunnel.TrainReleasedTunnel", oldManagedTrain)

    ---@type ManagedTrain
    local newManagedTrain = {
        id = global.trainManager.nextManagedTrainId
    }
    global.trainManager.managedTrains[newManagedTrain.id] = newManagedTrain
    global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId + 1 ---@type Id

    newManagedTrain.undergroundTrainState = oldManagedTrain.undergroundTrainState
    newManagedTrain.undergroundTrain = oldManagedTrain.undergroundTrain
    newManagedTrain.undergroundTrainSetsSpeed = true -- Intentionally reset this value.
    newManagedTrain.undergroundTrain.manual_mode = false -- Start the underground train running if it was stopped.
    newManagedTrain.undergroundTrainForwards = not oldManagedTrain.undergroundTrainForwards
    newManagedTrain.undergroundTrainCarriageCount = oldManagedTrain.undergroundTrainCarriageCount
    newManagedTrain.undergroundTrainLeadCarriageCache = nil -- Will be populated on first use.
    newManagedTrain.undergroundTrainAForwardsLocoCache = nil -- Will be populated on first use if needed.
    newManagedTrain.undergroundTrainAForwardsLocoBurnerCache = nil -- Will be populated on first use if needed.

    newManagedTrain.trainTravelDirection = Utils.LoopDirectionValue(oldManagedTrain.trainTravelDirection + 4)
    newManagedTrain.trainTravelOrientation = Utils.DirectionToOrientation(newManagedTrain.trainTravelDirection)
    newManagedTrain.targetTrainStop = oldManagedTrain.targetTrainStop

    newManagedTrain.leavingTrainExpectedBadState = false
    newManagedTrain.leavingTrainAtEndOfPortalTrack = false

    newManagedTrain.aboveSurface = oldManagedTrain.aboveSurface
    newManagedTrain.aboveEntrancePortal = oldManagedTrain.aboveExitPortal
    newManagedTrain.aboveEntrancePortalEndSignal = oldManagedTrain.aboveExitPortalEndSignal
    newManagedTrain.aboveExitPortal = oldManagedTrain.aboveEntrancePortal
    newManagedTrain.aboveExitPortalEndSignal = oldManagedTrain.aboveEntrancePortalEndSignal
    newManagedTrain.aboveExitPortalEntrySignalOut = oldManagedTrain.aboveEntrancePortal.entrySignals[TunnelSignalDirection.outSignal]
    newManagedTrain.tunnel = oldManagedTrain.tunnel
    newManagedTrain.undergroundTunnel = oldManagedTrain.undergroundTunnel
    newManagedTrain.undergroundLeavingPortalEntrancePosition = Utils.ApplyOffsetToPosition(newManagedTrain.aboveExitPortal.portalEntrancePosition, newManagedTrain.tunnel.undergroundTunnel.undergroundOffsetFromSurface)

    -- Get the schedule from what ever old train there was.
    local newTrainSchedule
    if oldManagedTrain.dummyTrain ~= nil then
        newTrainSchedule = oldManagedTrain.dummyTrain.schedule
    elseif oldManagedTrain.leavingTrain ~= nil then
        newTrainSchedule = oldManagedTrain.leavingTrain.schedule
    end

    -- Handle new entering train now all pre-req data set up.
    if oldManagedTrain.leavingTrainState == LeavingTrainStates.leavingFirstCarriage or oldManagedTrain.leavingTrainState == LeavingTrainStates.leaving then
        newManagedTrain.enteringTrainState = EnteringTrainStates.entering
        newManagedTrain.enteringTrain = oldManagedTrain.leavingTrain
        newManagedTrain.enteringTrain.speed = 0 -- We don't want to change the cached forwards state we have just generated. This was most liekly set to 0 already by the train reversing, but force it to be safe.
        newManagedTrain.enteringTrainId = oldManagedTrain.leavingTrainId
        global.trainManager.trainIdToManagedTrain[newManagedTrain.enteringTrainId] = {
            trainId = newManagedTrain.enteringTrainId,
            managedTrain = newManagedTrain,
            tunnelUsagePart = TunnelUsageParts.enteringTrain
        }
        newManagedTrain.enteringTrainForwards = not oldManagedTrain.leavingTrainForwards
        newManagedTrain.enteringTrainLeadCarriageCache = nil -- Will be populated on first use.

        TrainManagerStateFuncs.HandleTrainNewlyEntering(newManagedTrain)

        -- Old leaving train has an exiting pushing loco. We need to
        if oldManagedTrain.leavingTrainPushingLoco ~= nil then
            -- When pushing loco's are removed they may corrupt out cached Forwards state. So check if the trains idea of its front and back is changed and update accordingly.
            local oldFrontCarriageUnitNumber, oldBackCarriageUnitNumber = newManagedTrain.enteringTrain.front_stock.unit_number, newManagedTrain.enteringTrain.back_stock.unit_number
            TrainManagerFuncs.RemoveAnyPushingLocosFromTrain(newManagedTrain.enteringTrain)
            local trainGoingExpectedDirection = TrainManagerFuncs.TrainStillFacingSameDirectionAfterCarriageChange(newManagedTrain.enteringTrain, newManagedTrain.trainTravelOrientation, oldFrontCarriageUnitNumber, oldBackCarriageUnitNumber, newManagedTrain.enteringTrainForwards)
            if not trainGoingExpectedDirection then
                newManagedTrain.enteringTrainForwards = not newManagedTrain.enteringTrainForwards
            end
        end
    else
        newManagedTrain.enteringTrainState = EnteringTrainStates.finished
        Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", newManagedTrain)
    end

    -- Handle new leaving train now all pre-req data set up.
    if oldManagedTrain.enteringTrainState == EnteringTrainStates.entering then
        newManagedTrain.leavingTrainState = LeavingTrainStates.leaving
        newManagedTrain.leavingTrain = oldManagedTrain.enteringTrain
        newManagedTrain.leavingTrain.speed = 0 -- We don't want to change the cached forwards state we have just generated. This was most liekly set to 0 already by the train reversing, but force it to be safe.
        newManagedTrain.leavingTrainId = oldManagedTrain.enteringTrainId
        newManagedTrain.leavingTrainForwards = not oldManagedTrain.enteringTrainForwards
        newManagedTrain.leavingTrainCarriagesPlaced = #newManagedTrain.leavingTrain.carriages
        newManagedTrain.leavingTrainRearCarriageCache = nil -- Will be populated on first use.
        global.trainManager.trainIdToManagedTrain[newManagedTrain.leavingTrainId] = {
            trainId = newManagedTrain.leavingTrainId,
            managedTrain = newManagedTrain,
            tunnelUsagePart = TunnelUsageParts.leavingTrain
        }

        -- Handle any carriages made in-operable in previous tunnel entry usage.
        for _, carriage in pairs(newManagedTrain.leavingTrain.carriages) do
            carriage.operable = true
        end

        if not TrainManagerFuncs.DoesTrainHaveAForwardsLoco(newManagedTrain.leavingTrain, newManagedTrain.trainTravelOrientation) then
            local rearCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(newManagedTrain.leavingTrain, not newManagedTrain.leavingTrainForwards)
            -- When pushing loco is added it may corrupt out cached Forwards state. So check if the trains idea of its front and back is changed and update accordingly.
            local oldFrontCarriageUnitNumber, oldBackCarriageUnitNumber = newManagedTrain.leavingTrain.front_stock.unit_number, newManagedTrain.leavingTrain.back_stock.unit_number
            newManagedTrain.leavingTrainPushingLoco = TrainManagerFuncs.AddPushingLocoToAfterCarriage(rearCarriage, newManagedTrain.trainTravelOrientation)
            local trainGoingExpectedDirection = TrainManagerFuncs.TrainStillFacingSameDirectionAfterCarriageChange(newManagedTrain.leavingTrain, newManagedTrain.trainTravelOrientation, oldFrontCarriageUnitNumber, oldBackCarriageUnitNumber, newManagedTrain.leavingTrainForwards)
            if not trainGoingExpectedDirection then
                newManagedTrain.leavingTrainForwards = not newManagedTrain.leavingTrainForwards
            end
        end
        newManagedTrain.leavingTrainStoppingSignal = nil -- Intentionally reset this value.
        newManagedTrain.leavingTrainStoppingSchedule = nil -- Intentionally reset this value.
        TrainManagerFuncs.TrainSetSchedule(newManagedTrain.leavingTrain, newTrainSchedule, false, newManagedTrain.targetTrainStop, false)
        Interfaces.Call("Tunnel.TrainStartedExitingTunnel", newManagedTrain)
    elseif oldManagedTrain.enteringTrainState == EnteringTrainStates.finished then
        Interfaces.Call("Tunnel.TrainReservedTunnel", newManagedTrain) -- Claim the exit portal as no train leaving yet.
        newManagedTrain.leavingTrainState = LeavingTrainStates.pre
        newManagedTrain.dummyTrain = TrainManagerFuncs.CreateDummyTrain(newManagedTrain.aboveExitPortal.entity, newTrainSchedule, newManagedTrain.targetTrainStop, false)
        local dummyTrainId = newManagedTrain.dummyTrain.id ---@type Id
        newManagedTrain.dummyTrainId = dummyTrainId
        global.trainManager.trainIdToManagedTrain[dummyTrainId] = {
            trainId = dummyTrainId,
            managedTrain = newManagedTrain,
            tunnelUsagePart = "dummyTrain"
        }
    end

    -- An approaching train (not entering) is handled by the main termianted logic and thus never reversed. The main portal signal link handles when to unlock the tunnel in the scenario of the train being on portal tracks.
    newManagedTrain.leftTrain = nil
    newManagedTrain.leftTrainId = nil
    -- global.trainManager.trainIdToManagedTrain[leftTrainId] - Nothing to set or nil, but included for ease of checking all global objects included in reversal.

    if oldManagedTrain.primaryTrainPartName == PrimaryTrainPartNames.leaving then
        if oldManagedTrain.enteringTrainState == EnteringTrainStates.finished then
            newManagedTrain.primaryTrainPartName = PrimaryTrainPartNames.underground
        elseif oldManagedTrain.enteringTrainState == EnteringTrainStates.entering then
            newManagedTrain.primaryTrainPartName = PrimaryTrainPartNames.leaving
        end
    elseif oldManagedTrain.primaryTrainPartName == PrimaryTrainPartNames.underground then
        if newManagedTrain.leavingTrainCarriagesPlaced == nil then
            newManagedTrain.primaryTrainPartName = PrimaryTrainPartNames.underground
        else
            newManagedTrain.primaryTrainPartName = PrimaryTrainPartNames.leaving
        end
    else
        error("Unexpected reversed old managed train primaryTrainPartName: " .. oldManagedTrain.primaryTrainPartName)
    end

    -- Player Container updating as required. Only scenario that needs detailed updating is when a player was in a leaving carriage that has become an entering carriage.
    newManagedTrain.leavingCarriageIdToUndergroundCarriageEntity = {}
    newManagedTrain.enteringCarriageIdToUndergroundCarriageEntity = {}
    if newManagedTrain.enteringTrainState == EnteringTrainStates.entering then
        -- Populate the new enteringCarriageId to undergroundCarriageEntity table from the old left carraige list. Any players in carriages still underground at this point are fine.
        for leavingCarriageId, undergroundCarriageEntity in pairs(oldManagedTrain.leavingCarriageIdToUndergroundCarriageEntity) do
            newManagedTrain.enteringCarriageIdToUndergroundCarriageEntity[leavingCarriageId] = undergroundCarriageEntity
        end
    end
    TrainManagerPlayerContainers.On_TrainManagerReversed(oldManagedTrain, newManagedTrain)

    -- Update underground trains path and speed. Variable state done previously.
    local undergroundTrainEndScheduleTargetPos = Interfaces.Call("Underground.GetForwardsEndOfRailPosition", newManagedTrain.tunnel.undergroundTunnel, newManagedTrain.trainTravelOrientation)
    TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition(newManagedTrain.undergroundTrain, undergroundTrainEndScheduleTargetPos)
    newManagedTrain.undergroundTrain.speed = 0 -- We don't want to change the cached forwards state we have just generated. This was most liekly set to 0 already by the train reversing, but force it to be safe.
    newManagedTrain.undergroundTrainOldAbsoluteSpeed = 0

    TrainManagerRemote.TunnelUsageChanged(newManagedTrain.id, TunnelUsageAction.reversedDuringUse, TunnelUsageChangeReason.forwardPathLost, oldManagedTrain.id)

    -- If this train is heading to a station check if another train has grabbed out reservation when the path was lost. If so reset their reservation claim.
    -- We can't avoid this path lost even if we react to the event, the other train will have already bene given the path and stated.
    local targetStation = newManagedTrain.targetTrainStop ---@type LuaEntity
    if targetStation ~= nil and targetStation.trains_count > targetStation.trains_limit then
        local trainsHeadingToStation = targetStation.get_train_stop_trains() ---@type LuaTrain[]
        for index = #trainsHeadingToStation, 1, -1 do
            local otherTrain = trainsHeadingToStation[index] ---@type LuaTrain
            -- Ignore any train that isn't currently pathing (reservation) to this specific train stop entity. Also ignore any train thats related to this tunnel usage. Our usurper train will have a speed of 0 as it hasn't moved yet this tick.
            if otherTrain.path_end_stop ~= nil and otherTrain.path_end_stop.unit_number == targetStation.unit_number and otherTrain.has_path and otherTrain.speed == 0 then
                if (newManagedTrain.dummyTrain == nil or (newManagedTrain.dummyTrain ~= nil and otherTrain.id ~= newManagedTrain.dummyTrain.id)) and (newManagedTrain.leavingTrain == nil or (newManagedTrain.leavingTrain ~= nil and otherTrain.id ~= newManagedTrain.leavingTrain.id)) then
                    -- Just do the first train found
                    otherTrain.manual_mode = true
                    otherTrain.manual_mode = false
                    break
                end
            end
        end
    end
    -- Remove any left over bits of the oldManagedTrain
    TrainManagerStateFuncs.RemoveManagedTrainEntry(oldManagedTrain)
end

return TrainManager
