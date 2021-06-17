local TrainManager = {}
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")
local Utils = require("utility/utils")
local TrainManagerFuncs = require("scripts/train-manager-functions") -- Stateless functions that don't directly use global objects.
local PlayerContainers = require("scripts/player-containers") -- Uses this file directly, rather than via interface. Details in the sub files notes.
local Logging = require("utility/logging")
local TunnelCommon = require("scripts/tunnel-common")
local UndergroundSetUndergroundExitSignalStateFunction  -- Cache the function reference during OnLoad. Saves using Interfaces every tick.

---@class ManagedTrainId:int

---@class ManagedTrain
---@field public id ManagedTrainId @uniqiue id of this managed train passing through the tunnel.
---@field public primaryTrainPartName PrimaryTrainPartNames @The primary real train part name that dictates the trains primary monitored object. Finished is for when the tunnel trip is completed.
---
---@field public enteringTrainState EnteringTrainStates @The current entering train's state.
---@field public enteringTrain LuaTrain
---@field public enteringTrainId int @The enteringTrain LuaTrain id.
---@field public enteringTrainForwards boolean @If the train is moving forwards or backwards from its viewpoint.
---@field public enteringTrainLeadCarriageCache TrainLeadCarriageCache  @Cached details of the lead carriage of the entering train. Is only used and updated during TrainManager.TrainEnteringOngoing() and TrainManager.TrainApproachingOngoing().
---
---@field public undergroundTrainState UndergroundTrainStates @The current underground train's state.
---@field public undergroundTrain LuaTrain @The train created in the underground surface.
---@field public undergroundTrainSetsSpeed boolean @If the underground train sets the overall speed or if the leading part does.
---@field public undergroundTrainForwards boolean @If the train is moving forwards or backwards from its viewpoint.
---@field public undergroundTrainCarriageCount int @Cache of the total underground train carriage count.
---@field public undergroundTrainLeadCarriageCache TrainLeadCarriageCache @Cached details of the lead carriage of the underground train. Is only used and updated during TrainManager.TrainUndergroundOngoing().
---@field public undergroundTrainOldAbsoluteSpeed double @The absolute speed of the underground train last tick. Updated once enteringStarted up untill fullLeft.
---@field public undergroundTrainAForwardsLocoCache LuaEntity @A loco facing forwards in the underground train, no specific one. Populated if the train runs out of fuel, not updated apart from a reversal clears it.
---@field public undergroundTrainAForwardsLocoBurnerCache LuaBurner @The cached loco facing forward's burner in the underground train. Populated if the train runs out of fuel, not updated apart from a reversal clears it.
---
---@field public leavingTrainState LeavingTrainStates @The current leaving train's state.
---@field public leavingTrain LuaTrain @The train created leaving the tunnel on the world surface.
---@field public leavingTrainId int @The LuaTrain ID of the above Train Leaving.
---@field public leavingTrainForwards boolean @If the train is moving forwards or backwards from its viewpoint.
---@field public leavingTrainCarriagesPlaced int @Count of how many carriages placed so far in the above train while its leaving.
---@field public leavingTrainPushingLoco LuaEntity @Locomotive entity pushing the leaving train if it donesn't have a forwards facing locomotive yet, otherwise Nil.
---@field public leavingTrainStoppingSignal LuaEntity @The signal entity the leaving train is currently stopping at beyond the portal, or nil.
---@field public leavingTrainStoppingSchedule LuaEntity @The rail entity that the leaving train is currently stopping at beyond the portal, or nil.
---@field public leavingTrainExpectedBadState boolean @If the leaving train is in a bad state and it can't be corrected. Avoids any repeating checks or trying bad actions, and just waits for the train to naturally path itself.
---@field public leavingTrainAtEndOfPortalTrack boolean @If the leaving train is in a bad state and has reached the end of the portal track. It still needs to be checked for rear paths every tick via the mod.
---@field public leavingTrainRearCarriageCache LeavingTrainRearCarriageCache @Cache of the rear carriage of the leaving train. Is only used and updated during TrainManager.TrainLeavingOngoing().
---
---@field public leftTrain LuaTrain @The train thats left the tunnel.
---@field public leftTrainId int @The LuaTrain ID of the leftTrain.
---
---@field public dummyTrain LuaTrain @The dummy train used to keep the train stop reservation alive
---@field public dummyTrainId int @The LuaTrain ID of the dummy train.
---@field public trainTravelDirection defines.direction @The cardinal direction the train is heading in. Uses the more granular defines.direction to allow natural comparison to Factorio entity direction attributes.
---@field public trainTravelOrientation TrainTravelOrientation @The orientation of the trainTravelDirection.
---@field public targetTrainStop LuaEntity @The target train stop entity of this train, needed in case the path gets lost as we only have the station name then. Used when checking bad train states and reversing trains.
---
---@field public aboveSurface LuaSurface @The main world surface.
---@field public aboveEntrancePortal Portal @The portal global object of the entrance portal for this tunnel usage instance.
---@field public aboveEntrancePortalEndSignal PortalEndSignal @The endSignal global object of the rail signal at the end of the entrance portal track (forced closed signal).
---@field public aboveExitPortal Portal @Ref to the portal global object of the exit portal for this tunnel usage instance.
---@field public aboveExitPortalEndSignal PortalEndSignal @Ref to the endSignal global object of the rail signal at the end of the exit portal track (forced closed signal).
---@field public aboveExitPortalEntrySignalOut PortalEntrySignal @Ref to the endSignal global object on the rail signal at the entrance of the exit portal for leaving trains.
---@field public tunnel Tunnel @Ref to the global tunnel object.
---@field public undergroundTunnel UndergroundTunnel @Ref to the global tunnel's underground tunnel object.
---@field public undergroundLeavingPortalEntrancePosition Position @The underground position equivilent to the portal entrance that the underground train is measured against to decide when it starts leaving.
---
---@field public enteringCarriageIdToUndergroundCarriageEntity table<UnitNumber, LuaEntity> @Each entering carriage's unit number to the corrisponding underground carriage entity in the train. Currently used for tracking players riding in a train when it enters.
---@field public leavingCarriageIdToUndergroundCarriageEntity table<UnitNumber, LuaEntity> @Each leaving carriage's unit number to the corrisponding underground carriage entity in the train. Currently used for supporting reversal of train and populating new managedTrain.

---@class TrainLeadCarriageCache
---@field public trainForwards boolean @If the train was forwards when the cache was last updated.
---@field public carriage LuaEntity @Cached ref to the lead carriage entity.

---@class LeavingTrainRearCarriageCache
---@field public speedPositive boolean @If the leaving train's speed was positive when the cache was last updated.
---@field carriage LuaEntity @Cached ref to the rear carriage entity

---@alias TrainTravelOrientation "0"|"0.25"|"0.5"|"0.75"

---@class TrainIdToManagedTrain
---@field public trainId Id @the LuaTrain id, used as Id.
---@field public managedTrain ManagedTrain
---@field public tunnelUsagePart TunnelUsageParts

---@class EnteringTrainStates
local EnteringTrainStates = {
    approaching = "approaching", -- Train is approaching the tunnel, but can still turn back.
    entering = "entering", -- Train is committed to entering the tunnel.
    finished = "finished" -- Train has fully completed entering the tunnel.
}
---@class UndergroundTrainStates
local UndergroundTrainStates = {
    travelling = "travelling",
    finished = "finished"
}
---@class LeavingTrainStates
local LeavingTrainStates = {
    pre = "pre",
    leavingFirstCarriage = "leavingFirstCarriage",
    leaving = "leaving",
    trainLeftTunnel = "trainLeftTunnel",
    finished = "finished"
}
---@class PrimaryTrainPartNames
local PrimaryTrainPartNames = {approaching = "approaching", underground = "underground", leaving = "leaving", finished = "finished"}
---@class TunnelUsageParts
local TunnelUsageParts = {enteringTrain = "enteringTrain", dummyTrain = "dummyTrain", leavingTrain = "leavingTrain", leftTrain = "leftTrain"}

TrainManager.CreateGlobals = function()
    global.trainManager = global.trainManager or {}
    global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId or 1
    global.trainManager.managedTrains = global.trainManager.managedTrains or {} ---@type table<Id, ManagedTrain>
    global.trainManager.trainIdToManagedTrain = global.trainManager.trainIdToManagedTrain or {} ---@type table<Id, TrainIdToManagedTrain> @Used to track trainIds to managedTrainEntries. When the trainId is detected as changing via event the global object is updated to stay up to date.
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
    Interfaces.RegisterInterface("TrainManager.On_TunnelRemoved", TrainManager.On_TunnelRemoved)
    Interfaces.RegisterInterface("TrainManager.On_PortalReplaced", TrainManager.On_PortalReplaced)
    Interfaces.RegisterInterface("TrainManager.GetTrainIdsManagedTrainDetails", TrainManager.GetTrainIdsManagedTrainDetails)
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
    if existingTrainIDTrackedObject ~= nil and existingTrainIDTrackedObject.tunnelUsagePart == TunnelUsageParts.leftTrain then
        trainLeftEntry = existingTrainIDTrackedObject.managedTrain
        -- Terminate the old tunnel usage that was delayed until this point. Don't try to reverse the tunnel usage as this event has naturally happened and the old tunnel usage was effectively over anyways.
        TrainManager.TerminateTunnelTrip(trainLeftEntry, TrainManager.TunnelUsageChangeReason.reversedAfterLeft)
    end

    local managedTrain = TrainManager.CreateManagedTrainObject(enteringTrain, aboveEntrancePortalEndSignal)
    managedTrain.primaryTrainPartName, managedTrain.enteringTrainState, managedTrain.undergroundTrainState, managedTrain.leavingTrainState = PrimaryTrainPartNames.approaching, EnteringTrainStates.approaching, UndergroundTrainStates.travelling, LeavingTrainStates.pre
    TrainManager.CreateUndergroundTrainObject(managedTrain)
    Interfaces.Call("Tunnel.TrainReservedTunnel", managedTrain)

    if trainLeftEntry ~= nil then
        -- Include in the new train approaching event the old leftTrain entry id that has been stopped.
        TrainManager.Remote_TunnelUsageChanged(managedTrain.id, TrainManager.TunnelUsageAction.startApproaching, nil, trainLeftEntry.id)
    else
        TrainManager.Remote_TunnelUsageChanged(managedTrain.id, TrainManager.TunnelUsageAction.startApproaching)
    end
end

TrainManager.ProcessManagedTrains = function()
    -- Loop over each train and process it.
    for _, managedTrain in pairs(global.trainManager.managedTrains) do
        TrainManagerFuncs.RunFunctionAndCatchErrors(TrainManager.ProcessManagedTrain, managedTrain)
    end

    -- Raise any events from this tick for external listener mods to react to.
    if #global.trainManager.eventsToRaise ~= 0 then
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
end

TrainManager.ProcessManagedTrain = function(managedTrain)
    local skipThisTick = false -- Used to provide a "continue" ability as some actions could leave the trains in a weird state this tick and thus error on later functions in the process.

    -- Check dummy train state is valid if it exists. Used in a lot of states so sits outside of them.
    if not skipThisTick and managedTrain.dummyTrain ~= nil and not TrainManagerFuncs.IsTrainHealthlyState(managedTrain.dummyTrain) then
        TrainManager.HandleLeavingTrainBadState("dummyTrain", managedTrain)
        skipThisTick = true
    end

    if not skipThisTick and managedTrain.primaryTrainPartName == PrimaryTrainPartNames.approaching then
        -- Check whether the train is still approaching the tunnel portal as its not committed yet and so can turn away.
        if managedTrain.enteringTrain.state ~= defines.train_state.arrive_signal or managedTrain.enteringTrain.signal ~= managedTrain.aboveEntrancePortalEndSignal.entity then
            TrainManager.TerminateTunnelTrip(managedTrain, TrainManager.TunnelUsageChangeReason.abortedApproach)
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

TrainManager.HandleLeavingTrainBadState = function(trainWithBadStateName, managedTrain)
    local trainWithBadState = managedTrain[trainWithBadStateName]

    -- Check if the train can just path now as trains don't try and repath every tick. So sometimes they can path forwards on their own, they just haven't realised yet.
    if trainWithBadState.recalculate_path() then
        if trainWithBadStateName == "dummyTrain" then
            -- Just return as the dummy train doesn't handle reversing itself.
            return
        elseif trainWithBadStateName == "leavingTrain" then
            -- Check if the train is pathing in the expected direction or has just reversed on its own.
            if TrainManager.Check0OnlySpeedTrainWithLocoGoingExpectedDirection(managedTrain, trainWithBadStateName, 1) then
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
    local undergroundTrainReverseLocoListName
    local undergroundTrainSpeed = managedTrain.undergroundTrain.speed
    if undergroundTrainSpeed > 0 then
        undergroundTrainReverseLocoListName = "back_movers"
    elseif undergroundTrainSpeed < 0 then
        undergroundTrainReverseLocoListName = "front_movers"
    elseif managedTrain.undergroundTrainForwards then
        undergroundTrainReverseLocoListName = "back_movers"
    elseif not managedTrain.undergroundTrainForwards then
        undergroundTrainReverseLocoListName = "front_movers"
    else
        error("TrainManager.HandleLeavingTrainBadState() doesn't support 0 speed underground train with no cached forwards state\nundergroundTrain id: " .. managedTrain.undergroundTrain.id)
    end
    if #managedTrain.undergroundTrain.locomotives[undergroundTrainReverseLocoListName] > 0 then
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
    local exitPortalEntryRail = managedTrain.aboveExitPortalEntrySignalOut.entity.get_connected_rails()[1]
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
        managedTrain.undergroundTrain.manual_mode = true
        managedTrain.undergroundTrain.speed = 0

        -- Work out the correct persistent state to tag the train as. Will affect what repathing checks are done per tick going forwards.
        if #managedTrain.undergroundTrain.locomotives[undergroundTrainReverseLocoListName] > 0 then
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

TrainManager.TrainApproachingOngoing = function(managedTrain)
    TrainManager.UpdatePortalExitSignalPerTick(managedTrain)
    local enteringTrain = managedTrain.enteringTrain
    local undergroundTrainSpeed = managedTrain.undergroundTrain.speed
    -- managedTrain.enteringTrainForwards is updated by SetAbsoluteTrainSpeed().
    TrainManager.SetAbsoluteTrainSpeed(managedTrain, "enteringTrain", math.abs(undergroundTrainSpeed))
    local nextCarriage = TrainManager.GetEnteringTrainLeadCarriageCache(managedTrain, enteringTrain, managedTrain.enteringTrainForwards)

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

        TrainManager.HandleTrainNewlyEntering(managedTrain)

        TrainManager.Remote_TunnelUsageChanged(managedTrain.id, TrainManager.TunnelUsageAction.startedEntering) -- The same tick the first carriage will be removed by TrainManager.TrainEnteringOngoing() and this will fire an event.
    end
end

TrainManager.TrainEnteringOngoing = function(managedTrain)
    local enteringTrain = managedTrain.enteringTrain
    local undergroundTrainSpeed = managedTrain.undergroundTrain.speed

    -- Only update these when we aren't leaving. As a very long train can be entering and leaving at the same time.
    if managedTrain.leavingTrainState == LeavingTrainStates.pre then
        TrainManager.UpdatePortalExitSignalPerTick(managedTrain)
        TrainManager.EnsureManagedTrainsFuel(managedTrain, math.abs(undergroundTrainSpeed))
    end

    -- Force an entering train to stay in manual mode.
    enteringTrain.manual_mode = true

    -- managedTrain.enteringTrainForwards is updated by SetAbsoluteTrainSpeed().
    TrainManager.SetAbsoluteTrainSpeed(managedTrain, "enteringTrain", math.abs(undergroundTrainSpeed))
    local nextCarriage = TrainManager.GetEnteringTrainLeadCarriageCache(managedTrain, enteringTrain, managedTrain.enteringTrainForwards)

    -- Only try to remove a carriage if there is a speed. A 0 speed train can occur when a leaving train reverses.
    -- Check the train is on the same axis as the portal and then measure its distance along the rail alignment axis.
    if undergroundTrainSpeed ~= 0 and nextCarriage.position[managedTrain.tunnel.tunnelAlignmentAxis] == managedTrain.aboveEntrancePortal.entity.position[managedTrain.tunnel.tunnelAlignmentAxis] and Utils.GetDistanceSingleAxis(nextCarriage.position, managedTrain.aboveEntrancePortalEndSignal.entity.position, managedTrain.tunnel.railAlignmentAxis) < 14 then
        -- Handle any player in the train carriage.
        local driver = nextCarriage.get_driver()
        if driver ~= nil then
            PlayerContainers.PlayerInCarriageEnteringTunnel(managedTrain, driver, nextCarriage)
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
            TrainManager.GetEnteringTrainLeadCarriageCache(managedTrain, enteringTrain, nil)
        end

        TrainManager.Remote_TunnelUsageChanged(managedTrain.id, TrainManager.TunnelUsageAction.enteringCarriageRemoved)
    end

    if not enteringTrain.valid then
        -- Train has completed entering.
        managedTrain.enteringTrainState = EnteringTrainStates.finished
        global.trainManager.trainIdToManagedTrain[managedTrain.enteringTrainId] = nil
        managedTrain.enteringTrain = nil
        managedTrain.enteringTrainId = nil
        managedTrain.enteringCarriageIdToUndergroundCarriageEntity = nil
        Interfaces.Call("Tunnel.TrainFinishedEnteringTunnel", managedTrain)
        TrainManager.Remote_TunnelUsageChanged(managedTrain.id, TrainManager.TunnelUsageAction.fullyEntered)
    end
end

TrainManager.TrainUndergroundOngoing = function(managedTrain)
    PlayerContainers.MoveATrainsPlayerContainers(managedTrain)

    -- If the train is still entering then that is doing the updating. This underground function isn't looping once the train is leaving.
    if managedTrain.enteringTrainState == EnteringTrainStates.finished then
        TrainManager.UpdatePortalExitSignalPerTick(managedTrain)
        TrainManager.EnsureManagedTrainsFuel(managedTrain, math.abs(managedTrain.undergroundTrain.speed))
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

TrainManager.TrainLeavingFirstCarriage = function(managedTrain)
    -- Cleanup dummy train to make room for the reemerging train, preserving schedule and target stop for later.
    local schedule, isManual, targetTrainStop, targetRail = managedTrain.dummyTrain.schedule, managedTrain.dummyTrain.manual_mode, managedTrain.dummyTrain.path_end_stop, managedTrain.dummyTrain.path_end_rail
    TrainManager.DestroyDummyTrain(managedTrain)

    -- Check if the train is heading for a rail and not a station. If so will need to check and handle should the current target rail be part of this underground tunnel. As if it is the train can infinite loop path through the tunnel tryign to reach a tunnel rail it never can.
    if targetTrainStop == nil and targetRail ~= nil then
        if targetRail.name == "railway_tunnel-invisible_rail-on_map_tunnel" or targetRail.name == "railway_tunnel-invisible_rail-on_map_tunnel" then
            -- The target rail is the type used by a portal/segment for underground rail, so check if it belongs to the just used tunnel.
            if managedTrain.tunnel.tunnelRailEntities[targetRail.unit_number] ~= nil then
                -- The taret rail is part of the tunnel, so update the schedule rail to be the one at the end of the portal and just leave the train to do its thing from there.
                local currentScheduleRecord = schedule.records[schedule.current]
                local exitPortalEntryRail = managedTrain.aboveExitPortalEntrySignalOut.entity.get_connected_rails()[1]
                currentScheduleRecord.rail = exitPortalEntryRail
                schedule.records[schedule.current] = currentScheduleRecord
            end
        end
    end

    -- Place initial leaving train carriage and set schedule and speed back.
    local placedCarriage, undergroundLeadCarriage = TrainManager.CreateFirstCarriageForLeavingTrain(managedTrain)
    TrainManagerFuncs.TrainSetSchedule(managedTrain.leavingTrain, schedule, isManual, targetTrainStop)

    -- Follow up items post train creation.
    PlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage(undergroundLeadCarriage, placedCarriage)
    Interfaces.Call("Tunnel.TrainStartedExitingTunnel", managedTrain)
    TrainManager.Remote_TunnelUsageChanged(managedTrain.id, TrainManager.TunnelUsageAction.startedLeaving)
    TrainManager.Remote_TunnelUsageChanged(managedTrain.id, TrainManager.TunnelUsageAction.leavingCarriageAdded)
    TrainManager.UpdatePortalExitSignalPerTick(managedTrain, defines.signal_state.open) -- Reset the underground Exit signal state as the leaving train will now detect any signals.
    managedTrain.undergroundTrainSetsSpeed = true

    -- Check if all train wagons placed and train fully left the tunnel, otherwise set state for future carriages with the ongoing state.
    if managedTrain.leavingTrainCarriagesPlaced == managedTrain.undergroundTrainCarriageCount then
        TrainManager.TrainLeavingCompleted(managedTrain, nil)
    else
        managedTrain.leavingTrainState = LeavingTrainStates.leaving
    end
end

TrainManager.TrainLeavingOngoing = function(managedTrain)
    -- Handle if the train is stopping at a signal or scheduled stop (train-stop or rail). Updates managedTrain.undergroundTrainSetsSpeed and the underground train path if required.
    TrainManager.HandleLeavingTrainStoppingAtSignalSchedule(managedTrain, "signal")
    TrainManager.HandleLeavingTrainStoppingAtSignalSchedule(managedTrain, "schedule")

    local undergroundTrainSpeed = managedTrain.undergroundTrain.speed
    TrainManager.EnsureManagedTrainsFuel(managedTrain, math.abs(undergroundTrainSpeed))

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
        if not TrainManager.Check0OnlySpeedTrainWithLocoGoingExpectedDirection(managedTrain, "leavingTrain", desiredSpeed) then
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
            local placedCarriage = TrainManager.AddCarriageToLeavingTrain(managedTrain, nextSourceCarriageEntity, leavingTrainRearCarriage)
            TrainManagerFuncs.TrainSetSchedule(managedTrain.leavingTrain, scheduleBeforeCarriageAttachment, isManualBeforeCarriageAttachment, targetTrainStopBeforeCarriageAttachment)

            -- Set the trains speed back to what it was before we added the carriage. This will update the global facing forwards state and correct any speed loss when the carriage was added (base Factorio behavour).
            TrainManager.SetAbsoluteTrainSpeed(managedTrain, "leavingTrain", leavingAbsoluteSpeedBeforeCarriageAttachment)

            -- Follow up items post leaving train carriage addition.
            PlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage(nextSourceCarriageEntity, placedCarriage)
            TrainManager.Remote_TunnelUsageChanged(managedTrain.id, TrainManager.TunnelUsageAction.leavingCarriageAdded)
            managedTrain.leavingTrainRearCarriageCache = {
                speedPositive = managedTrain.leavingTrain.speed > 0,
                carriage = TrainManagerFuncs.GetRearCarriageOfLeavingTrain(managedTrain.leavingTrain, managedTrain.leavingTrainPushingLoco)
            }

            -- Check if all train wagons placed and train fully left the tunnel.
            if managedTrain.leavingTrainCarriagesPlaced == managedTrain.undergroundTrainCarriageCount then
                TrainManager.SetAbsoluteTrainSpeed(managedTrain, "leavingTrain", desiredSpeed)
                TrainManager.TrainLeavingCompleted(managedTrain)
                return
            end
        end

        -- Follow up items for the ontick, rather than related to a carriage being added.
        PlayerContainers.MoveATrainsPlayerContainers(managedTrain)
    end

    -- Update which ever train isn't setting the desired speed.
    if managedTrain.undergroundTrainSetsSpeed then
        TrainManager.SetAbsoluteTrainSpeed(managedTrain, "leavingTrain", desiredSpeed)
    else
        TrainManager.SetAbsoluteTrainSpeed(managedTrain, "undergroundTrain", desiredSpeed)
    end
end

TrainManager.HandleLeavingTrainStoppingAtSignalSchedule = function(managedTrain, arriveAtName)
    -- Handles a train leaving a tunnel arriving at a station/signal based on input. Updated global state data that impacts TrainManager.TrainLeavingOngoing(): managedTrain.undergroundTrainSetsSpeed and underground train path target.
    local leavingTrain, trainStoppingEntityAttributeName, stoppingTargetEntityAttributeName, arriveAtReleventStoppingTarget = managedTrain.leavingTrain, nil, nil, nil
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
        error("TrainManager.HandleLeavingTrainStoppingAtSignalSchedule() unsuported arriveAtName: " .. tostring(arriveAtName))
    end

    -- 1: If leaving train is now arriving at a relvent stopping target (station or signal) check state in detail as we may need to update the underground train stop point.
    -- 2: Once the leaving train is stopped at a relevent stopping target, clear out stopping target arriving state.
    -- 3: Otherwise check for moving away states and if there was a preivous stopping state to be finished.
    if arriveAtReleventStoppingTarget then
        -- If a known stopping target was set, make sure it still exists.
        if managedTrain[stoppingTargetEntityAttributeName] ~= nil and not managedTrain[stoppingTargetEntityAttributeName].valid then
            managedTrain[stoppingTargetEntityAttributeName] = nil
            managedTrain.undergroundTrainSetsSpeed = true
        end

        -- Check the stopping target is the expected one, if not reset state to detect new stopping target.
        if managedTrain[stoppingTargetEntityAttributeName] ~= nil and leavingTrain[trainStoppingEntityAttributeName].unit_number ~= managedTrain[stoppingTargetEntityAttributeName].unit_number then
            managedTrain[stoppingTargetEntityAttributeName] = nil
            managedTrain.undergroundTrainSetsSpeed = true
        end

        -- 1: If there's no expected stopping target then record state and update leaving and underground trains activities.
        -- 2: Otherwise its the same stopping target as previously, so if the underground train is setting the speed need to check distance from stopping target and hand over control to leaving train if close.
        if managedTrain[stoppingTargetEntityAttributeName] == nil then
            -- The above ground and underground trains will never be exactly relational to one another as they change speed each tick differently before they are re-aligned. So the underground train should be targetted as an offset from its current location and when the above train is very near the stopping target the above train can take over setting speed to manage the final pulling up.
            managedTrain[stoppingTargetEntityAttributeName] = leavingTrain[trainStoppingEntityAttributeName]

            local exactDistanceFromTrainToTarget
            if arriveAtName == "schedule" then
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
            local leadCarriageDistanceFromStoppingEntity = Utils.GetDistance(leadCarriage.position, managedTrain[stoppingTargetEntityAttributeName].position)
            local leavingTrainCloseToStoppingEntityDistance = TunnelCommon.GetCarriagePlacementDistance(leadCarriage.name) + 4 -- This is the length of the leading carriage plus 4 tiles leaway so the speed handover isn't too abrupt. May be a bit abrupt if leaving train is lacking loco's to carriages though, compared to full underground train.
            if leadCarriageDistanceFromStoppingEntity < leavingTrainCloseToStoppingEntityDistance then
                managedTrain.undergroundTrainSetsSpeed = false
            end
        end
    elseif managedTrain[stoppingTargetEntityAttributeName] ~= nil and leavingTrain.state == defines.train_state.on_the_path then
        -- If the train was stopped/stopping at a stopping target and now is back on the path, return to underground train setting speed and assume everything is back to normal.
        managedTrain[stoppingTargetEntityAttributeName] = nil
        managedTrain.undergroundTrainSetsSpeed = true
        managedTrain.undergroundTrain.manual_mode = false
        local undergroundTrainEndScheduleTargetPos = Interfaces.Call("Underground.GetForwardsEndOfRailPosition", managedTrain.tunnel.undergroundTunnel, managedTrain.trainTravelOrientation)
        TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition(managedTrain.undergroundTrain, undergroundTrainEndScheduleTargetPos)
    end
end

TrainManager.TrainLeavingCompleted = function(managedTrain)
    TrainManager.DestroyUndergroundTrain(managedTrain)

    managedTrain.leftTrain, managedTrain.leftTrainId = managedTrain.leavingTrain, managedTrain.leavingTrainId
    global.trainManager.trainIdToManagedTrain[managedTrain.leavingTrainId].tunnelUsagePart = TunnelUsageParts.leftTrain -- Keep the table, just update its state, as same train id, etc between the leaving and left train at this state change point.
    managedTrain.leavingTrainState = LeavingTrainStates.trainLeftTunnel
    managedTrain.undergroundTrainState = UndergroundTrainStates.finished
    managedTrain.leavingTrainId = nil
    managedTrain.leavingTrain = nil

    TrainManager.Remote_TunnelUsageChanged(managedTrain.id, TrainManager.TunnelUsageAction.fullyLeft)
end

TrainManager.TrainLeftTunnelOngoing = function(managedTrain)
    -- Track the tunnel's exit portal entry rail signal so we can mark the tunnel as open for the next train when the current train has left. We are assuming that no train gets in to the portal rail segment before our main train gets out. This is far more UPS effecient than checking the trains last carriage and seeing if its end rail signal is our portal entrance one.
    local exitPortalEntranceSignalEntity = managedTrain.aboveExitPortal.entrySignals["in"].entity
    if exitPortalEntranceSignalEntity.signal_state ~= defines.signal_state.closed then
        -- No train in the block so our one must have left.
        global.trainManager.trainIdToManagedTrain[managedTrain.leftTrainId] = nil
        managedTrain.leftTrain = nil
        managedTrain.leftTrainId = nil
        TrainManager.TerminateTunnelTrip(managedTrain, TrainManager.TunnelUsageChangeReason.completedTunnelUsage)
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

TrainManager.HandleTrainNewlyEntering = function(managedTrain)
    local enteringTrain = managedTrain.enteringTrain

    -- Schedule has been transferred to dummy train.
    enteringTrain.schedule = {
        current = 1,
        records = {
            {station = "ENTERING TUNNEL - EDIT LEAVING TRAIN"}
        }
    }

    -- Prevent player from messing with all entering carriages.
    for _, carriage in pairs(enteringTrain.carriages) do
        carriage.operable = false
    end
end

TrainManager.EnsureManagedTrainsFuel = function(managedTrain, undergroundTrainSpeed)
    local undergroundTrain = managedTrain.undergroundTrain
    -- A train thats run out of fuel will still break for signals and stations. Only check if its on the path, as then it should not be losing speed.
    if undergroundTrainSpeed < managedTrain.undergroundTrainOldAbsoluteSpeed and undergroundTrainSpeed < 0.1 and undergroundTrain.state == defines.train_state.on_the_path then
        local leadLocoBurner = managedTrain.undergroundTrainAForwardsLocoBurnerCache
        if managedTrain.undergroundTrainAForwardsLocoBurnerCache == nil then
            -- Not cached so obtain and then store it.
            local leadLoco
            if managedTrain.undergroundTrainForwards then
                leadLoco = undergroundTrain.locomotives.front_movers[1]
            else
                leadLoco = undergroundTrain.locomotives.back_movers[1]
            end
            leadLocoBurner = leadLoco.burner
            managedTrain.undergroundTrainAForwardsLocoCache, managedTrain.undergroundTrainAForwardsLocoBurnerCache = leadLoco, leadLocoBurner
        end
        if leadLocoBurner.currently_burning == nil then
            -- This loco has no fuel currently, so top it up.
            leadLocoBurner.currently_burning = "railway_tunnel-temporary_fuel"
            leadLocoBurner.remaining_burning_fuel = 200000
        end
    end
    managedTrain.undergroundTrainOldAbsoluteSpeed = undergroundTrainSpeed
end

---@param managedTrain ManagedTrain
---@param enteringTrain LuaTrain
---@param enteringTrainForwards boolean
---@return LuaEntity
TrainManager.GetEnteringTrainLeadCarriageCache = function(managedTrain, enteringTrain, enteringTrainForwards)
    -- Returns the cached lead carriage and records if needed.
    if managedTrain.enteringTrainLeadCarriageCache == nil or managedTrain.enteringTrainLeadCarriageCache.trainForwards ~= enteringTrainForwards then
        -- No cache entry or cache exists, but needs updating.
        local enteringTrainLeadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(enteringTrain, enteringTrainForwards)
        managedTrain.enteringTrainLeadCarriageCache = {
            trainForwards = enteringTrainForwards,
            carriage = enteringTrainLeadCarriage
        }
        return enteringTrainLeadCarriage
    else
        -- Use the cache lead carriage.
        return managedTrain.enteringTrainLeadCarriageCache.carriage
    end
end

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

TrainManager.DestroyUndergroundTrain = function(managedTrain)
    if managedTrain.undergroundTrain ~= nil then
        TrainManagerFuncs.DestroyTrainsCarriages(managedTrain.undergroundTrain)
        managedTrain.undergroundTrain = nil
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
    if trackedTrainIdObject.tunnelUsagePart == TunnelUsageParts.enteringTrain then
        trainAttributeName = "enteringTrain"
        trainIdAttributeName = "enteringTrainId"
    elseif trackedTrainIdObject.tunnelUsagePart == TunnelUsageParts.dummyTrain then
        trainAttributeName = "leftTrain"
        trainIdAttributeName = "leftTrainId"
    elseif trackedTrainIdObject.tunnelUsagePart == TunnelUsageParts.leavingTrain then
        trainAttributeName = "leavingTrain"
        trainIdAttributeName = "leavingTrainId"
    elseif trackedTrainIdObject.tunnelUsagePart == TunnelUsageParts.leftTrain then
        trainAttributeName = "leftTrain"
        trainIdAttributeName = "leftTrainId"
    else
        error("unrecognised global.trainManager.trainIdToManagedTrain tunnelUsagePart: " .. tostring(trackedTrainIdObject.tunnelUsagePart))
    end

    -- Update the object and globals for the change of train and train id.
    local newTrain, newTrainId = event.train, event.train.id
    trackedTrainIdObject.managedTrain[trainAttributeName] = newTrain
    trackedTrainIdObject.managedTrain[trainIdAttributeName] = newTrainId
    trackedTrainIdObject.trainId = newTrainId
    if event.old_train_id_1 ~= nil then
        global.trainManager.trainIdToManagedTrain[event.old_train_id_1] = nil
    end
    if event.old_train_id_2 ~= nil then
        global.trainManager.trainIdToManagedTrain[event.old_train_id_2] = nil
    end
    global.trainManager.trainIdToManagedTrain[newTrainId] = trackedTrainIdObject
end

TrainManager.SetAbsoluteTrainSpeed = function(managedTrain, trainAttributeName, absoluteSpeed)
    local train = managedTrain[trainAttributeName]

    -- Only update train's global forwards if speed ~= 0. As the last train direction needs to be preserved in global data for if the train stops while using the tunnel.
    local trainSpeed = train.speed
    if trainSpeed > 0 then
        managedTrain[trainAttributeName .. "Forwards"] = true
        train.speed = absoluteSpeed
    elseif trainSpeed < 0 then
        managedTrain[trainAttributeName .. "Forwards"] = false
        train.speed = -1 * absoluteSpeed
    else
        if managedTrain[trainAttributeName .. "Forwards"] == true then
            train.speed = absoluteSpeed
        elseif managedTrain[trainAttributeName .. "Forwards"] == false then
            train.speed = -1 * absoluteSpeed
        else
            error("TrainManager.SetAbsoluteTrainSpeed() for '" .. trainAttributeName .. "' doesn't support train with current 0 speed and no 'Forwards' cached value.\n" .. trainAttributeName .. " id: " .. managedTrain[trainAttributeName].id)
        end
    end
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

            PlayerContainers.On_TunnelRemoved(managedTrain.undergroundTrain)

            TrainManager.TerminateTunnelTrip(managedTrain, TrainManager.TunnelUsageChangeReason.tunnelRemoved)
        end
    end
end

TrainManager.CreateFirstCarriageForLeavingTrain = function(managedTrain)
    local undergroundLeadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(managedTrain.undergroundTrain, managedTrain.undergroundTrainForwards)
    local placementPosition = Utils.ApplyOffsetToPosition(undergroundLeadCarriage.position, managedTrain.tunnel.undergroundTunnel.surfaceOffsetFromUnderground)
    local placedCarriage = undergroundLeadCarriage.clone {position = placementPosition, surface = managedTrain.aboveSurface, create_build_effect_smoke = false}
    if placedCarriage == nil then
        error("failed to clone carriage:" .. "\nsurface name: " .. managedTrain.aboveSurface.name .. "\nposition: " .. Logging.PositionToString(placementPosition) .. "\nsource carriage unit_number: " .. undergroundLeadCarriage.unit_number)
    end
    placedCarriage.train.speed = undergroundLeadCarriage.speed -- Set the speed when its a train of 1. Before a pushing locomotive may be added and make working out speed direction harder.
    managedTrain.leavingTrainCarriagesPlaced = 1
    managedTrain.leavingTrain, managedTrain.leavingTrainId = placedCarriage.train, placedCarriage.train.id
    global.trainManager.trainIdToManagedTrain[managedTrain.leavingTrainId] = {
        trainId = managedTrain.leavingTrainId,
        managedTrain = managedTrain,
        tunnelUsagePart = TunnelUsageParts.leavingTrain
    }
    managedTrain.leavingCarriageIdToUndergroundCarriageEntity[placedCarriage.unit_number] = undergroundLeadCarriage

    -- Add a pushing loco if needed.
    if not TrainManagerFuncs.CarriageIsAForwardsLoco(placedCarriage, managedTrain.trainTravelOrientation) then
        managedTrain.leavingTrainPushingLoco = TrainManagerFuncs.AddPushingLocoToAfterCarriage(placedCarriage, managedTrain.trainTravelOrientation)
    end

    local leavingTrainSpeed = managedTrain.leavingTrain.speed
    if leavingTrainSpeed > 0 then
        managedTrain.leavingTrainForwards = true
    elseif leavingTrainSpeed < 0 then
        managedTrain.leavingTrainForwards = true
    else
        error("TrainManager.CreateFirstCarriageForLeavingTrain() doesn't support 0 speed leaving train.\nleavingTrain id: " .. managedTrain.leavingTrain.id)
    end

    return placedCarriage, undergroundLeadCarriage
end

TrainManager.AddCarriageToLeavingTrain = function(managedTrain, nextSourceCarriageEntity, leavingTrainRearCarriage)
    -- Remove the pushing loco if present before the next carriage is placed.
    local hadPushingLoco = managedTrain.leavingTrainPushingLoco ~= nil
    if managedTrain.leavingTrainPushingLoco ~= nil then
        managedTrain.leavingTrainPushingLoco.destroy()
        managedTrain.leavingTrainPushingLoco = nil
    end

    local aboveTrainOldCarriageCount = #leavingTrainRearCarriage.train.carriages
    local nextCarriagePosition = TrainManagerFuncs.GetNextCarriagePlacementPosition(managedTrain.trainTravelOrientation, leavingTrainRearCarriage, nextSourceCarriageEntity.name)
    local placedCarriage = nextSourceCarriageEntity.clone {position = nextCarriagePosition, surface = managedTrain.aboveSurface, create_build_effect_smoke = false}
    if placedCarriage == nil then
        error("failed to clone carriage:" .. "\nsurface name: " .. managedTrain.aboveSurface.name .. "\nposition: " .. Logging.PositionToString(nextCarriagePosition) .. "\nsource carriage unit_number: " .. nextSourceCarriageEntity.unit_number)
    end
    managedTrain.leavingTrainCarriagesPlaced = managedTrain.leavingTrainCarriagesPlaced + 1
    if #placedCarriage.train.carriages ~= aboveTrainOldCarriageCount + 1 then
        error("Placed carriage not part of leaving train as expected carriage count not right.\nleavingTrain id: " .. managedTrain.leavingTrain.id)
    end
    managedTrain.leavingCarriageIdToUndergroundCarriageEntity[placedCarriage.unit_number] = nextSourceCarriageEntity

    -- If train had a pushing loco before and still needs one, add one back.
    if hadPushingLoco and (not TrainManagerFuncs.CarriageIsAForwardsLoco(placedCarriage, managedTrain.trainTravelOrientation)) then
        managedTrain.leavingTrainPushingLoco = TrainManagerFuncs.AddPushingLocoToAfterCarriage(placedCarriage, managedTrain.trainTravelOrientation)
    end

    return placedCarriage
end

TrainManager.CreateManagedTrainObject = function(enteringTrain, aboveEntrancePortalEndSignal)
    local enteringTrainId = enteringTrain.id
    local managedTrain = {
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
    global.trainManager.managedTrains[managedTrain.id] = managedTrain
    managedTrain.aboveSurface = managedTrain.tunnel.aboveSurface
    local enteringTrainSpeed = managedTrain.enteringTrain.speed
    if enteringTrainSpeed > 0 then
        managedTrain.enteringTrainForwards = true
    elseif enteringTrainSpeed < 0 then
        managedTrain.enteringTrainForwards = false
    else
        error("TrainManager.CreateManagedTrainObject() doesn't support 0 speed\nenteringTrain id: " .. managedTrain.enteringTrainId)
    end
    managedTrain.trainTravelOrientation = Utils.DirectionToOrientation(managedTrain.trainTravelDirection)
    global.trainManager.trainIdToManagedTrain[enteringTrainId] = {
        trainId = enteringTrainId,
        managedTrain = managedTrain,
        tunnelUsagePart = TunnelUsageParts.enteringTrain
    }

    -- Get the exit end signal on the other portal so we know when to bring the train back in.
    for _, portal in pairs(managedTrain.tunnel.portals) do
        if portal.id ~= aboveEntrancePortalEndSignal.portal.id then
            managedTrain.aboveExitPortalEndSignal = portal.endSignals["out"]
            managedTrain.aboveExitPortal = portal
            managedTrain.aboveExitPortalEntrySignalOut = portal.entrySignals["out"]
        end
    end

    return managedTrain
end

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

TrainManager.CreateUndergroundTrainObject = function(managedTrain)
    -- Copy the above train underground and set it running.
    -- The above ground and underground trains will never be exactly relational to one another, but should be within half a tile correctly aligned.
    local firstCarriagePosition = TrainManager.GetUndergroundFirstWagonPosition(managedTrain)
    local undergroundTrain = TrainManager.CopyEnteringTrainUnderground(managedTrain, firstCarriagePosition)
    managedTrain.undergroundTrain = undergroundTrain
    managedTrain.undergroundTrainCarriageCount = #undergroundTrain.carriages

    local undergroundTrainEndScheduleTargetPos = Interfaces.Call("Underground.GetForwardsEndOfRailPosition", managedTrain.tunnel.undergroundTunnel, managedTrain.trainTravelOrientation)
    TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition(undergroundTrain, undergroundTrainEndScheduleTargetPos)

    -- Set speed and cached 'Forwards' value manually so future use of TrainManager.SetAbsoluteTrainSpeed() works.
    local enteringTrainSpeed = managedTrain.enteringTrain.speed
    undergroundTrain.speed = enteringTrainSpeed
    if enteringTrainSpeed > 0 then
        managedTrain.undergroundTrainForwards = true
    elseif enteringTrainSpeed < 0 then
        managedTrain.undergroundTrainForwards = false
    else
        error("TrainManager.CreateUndergroundTrainObject() doesn't support 0 speed undergroundTrain.\nundergroundTrain id: " .. undergroundTrain.id)
    end
    undergroundTrain.manual_mode = false
    if undergroundTrain.speed == 0 then
        -- If the speed is undone (0) by setting to automatic then the underground train is moving opposite to the entering train. Simple way to handle the underground train being an unknown "forwards".
        managedTrain.undergroundTrainForwards = not managedTrain.undergroundTrainForwards
        undergroundTrain.speed = -1 * enteringTrainSpeed
    end

    managedTrain.undergroundLeavingPortalEntrancePosition = Utils.ApplyOffsetToPosition(managedTrain.aboveExitPortal.portalEntrancePosition, managedTrain.tunnel.undergroundTunnel.undergroundOffsetFromSurface)
end

TrainManager.GetUndergroundFirstWagonPosition = function(managedTrain)
    -- Work out the distance in rail tracks between the train and the portal's end signal's rail. This accounts for curves/U-bends and gives us a straight line distance as an output.
    local firstCarriageDistanceFromPortalEndSignalsRail = TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTarget(managedTrain.enteringTrain, managedTrain.aboveEntrancePortalEndSignal.entity, managedTrain.enteringTrainForwards)

    -- Apply the straight line distance to the above portal's end signal's rail. Account for the distance being from rail edge, rather than rail center (but rail is always straight in portal so easy).
    local firstCarriageOffsetFromEndSignalsRail = Utils.RotatePositionAround0(managedTrain.trainTravelOrientation, {x = 0, y = firstCarriageDistanceFromPortalEndSignalsRail})
    local signalsRailEdgePosition = Utils.ApplyOffsetToPosition(managedTrain.aboveEntrancePortalEndSignal.entity.get_connected_rails()[1].position, Utils.RotatePositionAround0(managedTrain.trainTravelOrientation, {x = 0, y = 1})) -- Theres only ever 1 rail connected to the signal as its in the portal. + 1 for the difference in signals rail edge and its center position.
    local firstCarriageAbovegroundPosition = Utils.ApplyOffsetToPosition(signalsRailEdgePosition, firstCarriageOffsetFromEndSignalsRail)

    -- Get the underground position for this above ground spot.
    local firstCarriageUndergroundPosition = Utils.ApplyOffsetToPosition(firstCarriageAbovegroundPosition, managedTrain.tunnel.undergroundTunnel.undergroundOffsetFromSurface)
    return firstCarriageUndergroundPosition
end

TrainManager.CopyEnteringTrainUnderground = function(managedTrain, firstCarriagePosition)
    local nextCarriagePosition, refTrain, targetSurface = firstCarriagePosition, managedTrain.enteringTrain, managedTrain.tunnel.undergroundTunnel.undergroundSurface.surface
    local trainCarriagesForwardOrientation = managedTrain.trainTravelOrientation
    if not managedTrain.enteringTrainForwards then
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
            nextCarriagePosition = TrainManagerFuncs.GetNextCarriagePlacementPosition(managedTrain.trainTravelOrientation, placedCarriage, refCarriage.name)
            safeCarriageFlipPosition = Utils.ApplyOffsetToPosition(nextCarriagePosition, TrainManagerFuncs.GetNextCarriagePlacementOffset(managedTrain.trainTravelOrientation, placedCarriage.name, refCarriage.name, 20))
        else
            safeCarriageFlipPosition = Utils.ApplyOffsetToPosition(nextCarriagePosition, TrainManagerFuncs.GetNextCarriagePlacementOffset(managedTrain.trainTravelOrientation, refCarriage.name, refCarriage.name, 20))
        end

        placedCarriage = TrainManagerFuncs.CopyCarriage(targetSurface, refCarriage, nextCarriagePosition, safeCarriageFlipPosition, carriageOrientation)
        managedTrain.enteringCarriageIdToUndergroundCarriageEntity[refCarriage.unit_number] = placedCarriage
    end

    return placedCarriage.train
end

TrainManager.TerminateTunnelTrip = function(managedTrain, tunnelUsageChangeReason)
    TrainManager.UpdatePortalExitSignalPerTick(managedTrain, defines.signal_state.open) -- Reset the underground Exit signal state to open for the next train.
    if managedTrain.undergroundTrain then
        PlayerContainers.On_TerminateTunnelTrip(managedTrain.undergroundTrain)
        TrainManager.DestroyUndergroundTrain(managedTrain)
    end
    TrainManager.RemoveManagedTrainEntry(managedTrain)

    Interfaces.Call("Tunnel.TrainReleasedTunnel", managedTrain)
    TrainManager.Remote_TunnelUsageChanged(managedTrain.id, TrainManager.TunnelUsageAction.terminated, tunnelUsageChangeReason)
end

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

    if managedTrain.leftTrain and managedTrain.leftTrain.valid and global.trainManager.trainIdToManagedTrain[managedTrain.leftTrain.id] and global.trainManager.trainIdToManagedTrain[managedTrain.leftTrain.id].managedTrain.id == managedTrain.id then
        global.trainManager.trainIdToManagedTrain[managedTrain.leftTrain.id] = nil
    elseif managedTrain.leftTrainId and global.trainManager.trainIdToManagedTrain[managedTrain.leftTrainId] and global.trainManager.trainIdToManagedTrain[managedTrain.leftTrainId].managedTrain.id == managedTrain.id then
        global.trainManager.trainIdToManagedTrain[managedTrain.leftTrainId] = nil
    end

    TrainManager.DestroyDummyTrain(managedTrain)

    -- Set all states to finished so that the TrainManager.ProcessManagedTrains() loop won't execute anything further this tick.
    managedTrain.primaryTrainPartName = PrimaryTrainPartNames.finished
    managedTrain.enteringTrainState = EnteringTrainStates.finished
    managedTrain.undergroundTrainState = UndergroundTrainStates.finished
    managedTrain.leavingTrainState = LeavingTrainStates.finished

    global.trainManager.managedTrains[managedTrain.id] = nil
end

TrainManager.Check0OnlySpeedTrainWithLocoGoingExpectedDirection = function(managedTrain, trainAttributeName, desiredSpeed)
    -- This requires the train to have a locomotive so that it can be given a path.
    -- This is the only known way to check which way a train with 0 speed and making no carriage changes is really wanting to go. As the LuaTrain attributes only update when the train has a speed or a carriage is added/removed.
    local train = managedTrain[trainAttributeName]
    local scheduleBackup, isManualBackup, targetTrainStop = train.schedule, train.manual_mode, train.path_end_stop

    train.manual_mode = true
    TrainManager.SetAbsoluteTrainSpeed(managedTrain, trainAttributeName, desiredSpeed)
    TrainManagerFuncs.TrainSetSchedule(train, scheduleBackup, isManualBackup, targetTrainStop, true) -- Don't force validation.
    local trainIsFacingExpectedDirection = train.speed ~= 0
    train.speed = 0 -- Set speed back, everything else was reset by the setting train schedule.
    if trainIsFacingExpectedDirection then
        return true
    else
        return false
    end
end

TrainManager.ReverseManagedTrainTunnelTrip = function(oldManagedTrain)
    -- The managed train is going to reverse and go out of the tunnel the way it came in. Will be lodged as a new managed train so that old managed trains logic can be closed off.
    -- This function can't be reached if the train isn't committed, so no need to handle EnteringTrainStates.approaching.

    if oldManagedTrain.targetTrainStop ~= nil and not oldManagedTrain.targetTrainStop.valid then
        error("Should be either valid or nil. Meant to be updated when the reversal function is called.")
    end

    -- Release the tunnel from the old train manager. Later in this function it will be reclaimed accordingly.
    Interfaces.Call("Tunnel.TrainReleasedTunnel", oldManagedTrain)

    local newManagedTrain = {
        id = global.trainManager.nextManagedTrainId
    }
    global.trainManager.managedTrains[newManagedTrain.id] = newManagedTrain
    global.trainManager.nextManagedTrainId = global.trainManager.nextManagedTrainId + 1

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
    newManagedTrain.aboveExitPortalEntrySignalOut = oldManagedTrain.aboveEntrancePortal.entrySignals["out"]
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

        TrainManager.HandleTrainNewlyEntering(newManagedTrain)

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
        local dummyTrainId = newManagedTrain.dummyTrain.id
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
    PlayerContainers.On_TrainManagerReversed(oldManagedTrain, newManagedTrain)

    -- Update underground trains path and speed. Variable state done previously.
    local undergroundTrainEndScheduleTargetPos = Interfaces.Call("Underground.GetForwardsEndOfRailPosition", newManagedTrain.tunnel.undergroundTunnel, newManagedTrain.trainTravelOrientation)
    TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition(newManagedTrain.undergroundTrain, undergroundTrainEndScheduleTargetPos)
    newManagedTrain.undergroundTrain.speed = 0 -- We don't want to change the cached forwards state we have just generated. This was most liekly set to 0 already by the train reversing, but force it to be safe.
    newManagedTrain.undergroundTrainOldAbsoluteSpeed = 0

    TrainManager.Remote_TunnelUsageChanged(newManagedTrain.id, TrainManager.TunnelUsageAction.reversedDuringUse, TrainManager.TunnelUsageChangeReason.forwardPathLost, oldManagedTrain.id)

    -- If this train is heading to a station check if another train has grabbed out reservation when the path was lost. If so reset their reservation claim.
    -- We can't avoid this path lost even if we react to the event, the other train will have already bene given the path and stated.
    local targetStation = newManagedTrain.targetTrainStop
    if targetStation ~= nil and targetStation.trains_count > targetStation.trains_limit then
        local trainsHeadingToStation = targetStation.get_train_stop_trains()
        for index = #trainsHeadingToStation, 1, -1 do
            local otherTrain = trainsHeadingToStation[index]
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
    TrainManager.RemoveManagedTrainEntry(oldManagedTrain)
end

TrainManager.UpdatePortalExitSignalPerTick = function(managedTrain, forceSignalState)
    -- Mirror aboveground exit signal state to underground signal so primary train (underground) honours stopping points. Primary speed limiter before leaving train has got to a significant size and escaped the portal signals as a very small leaving/dummy train will have low breaking distance and thus very short signal block reservation/detecting distances.
    -- Close the underground Exit signal if the aboveground Exit signal isn't open, otherwise open it.
    -- forceSignalState is optional and when set will be applied rather than the aboveground exit signal state.
    if forceSignalState ~= nil then
        UndergroundSetUndergroundExitSignalStateFunction(managedTrain.aboveExitPortalEntrySignalOut.undergroundSignalPaired, forceSignalState)
    else
        UndergroundSetUndergroundExitSignalStateFunction(managedTrain.aboveExitPortalEntrySignalOut.undergroundSignalPaired, managedTrain.aboveExitPortalEntrySignalOut.entity.signal_state)
    end
end

TrainManager.GetTrainIdsManagedTrainDetails = function(trainId)
    return global.trainManager.trainIdToManagedTrain[trainId]
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
    startedEntering = "startedEntering",
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
    completedTunnelUsage = "completedTunnelUsage",
    tunnelRemoved = "tunnelRemoved"
}

TrainManager.Remote_PopulateTableWithTunnelUsageEntryObjectAttributes = function(tableToPopulate, managedTrainId)
    local managedTrain = global.trainManager.managedTrains[managedTrainId]
    if managedTrain == nil then
        return
    end

    -- Only return valid LuaTrains as otherwise the events are dropped by Factorio.
    tableToPopulate.tunnelUsageId = managedTrainId
    tableToPopulate.primaryState = managedTrain.primaryTrainPartName
    tableToPopulate.enteringTrain = Utils.ReturnValidLuaObjectOrNil(managedTrain.enteringTrain)
    tableToPopulate.undergroundTrain = Utils.ReturnValidLuaObjectOrNil(managedTrain.undergroundTrain)
    tableToPopulate.leavingTrain = Utils.ReturnValidLuaObjectOrNil(managedTrain.leavingTrain)
    tableToPopulate.leftTrain = Utils.ReturnValidLuaObjectOrNil(managedTrain.leftTrain)
    tableToPopulate.tunnelId = managedTrain.tunnel.id
end

TrainManager.Remote_TunnelUsageChanged = function(managedTrainId, action, changeReason, replacedtunnelUsageId)
    -- Schedule the event to be raised after all trains are handled for this tick. Otherwise events can interupt the mods processes and cause errors.
    -- Don't put the Factorio Lua object references in here yet as they may become invalid by send time and then the event is dropped.
    local data = {
        tunnelUsageId = managedTrainId,
        name = "RailwayTunnel.TunnelUsageChanged",
        action = action,
        changeReason = changeReason,
        replacedtunnelUsageId = replacedtunnelUsageId
    }
    table.insert(global.trainManager.eventsToRaise, data)
end

TrainManager.Remote_GetTunnelUsageEntry = function(managedTrainId)
    local tunnelUsageEntry = {}
    TrainManager.Remote_PopulateTableWithTunnelUsageEntryObjectAttributes(tunnelUsageEntry, managedTrainId)
    return tunnelUsageEntry
end

TrainManager.Remote_GetATrainsTunnelUsageEntry = function(trainId)
    local trackedTrainIdObject = global.trainManager.trainIdToManagedTrain[trainId]
    if trackedTrainIdObject == nil then
        return nil
    end
    local managedTrain = trackedTrainIdObject.managedTrain
    if managedTrain ~= nil then
        local tunnelUsageEntry = {}
        TrainManager.Remote_PopulateTableWithTunnelUsageEntryObjectAttributes(tunnelUsageEntry, managedTrain.id)
        return tunnelUsageEntry
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
