-- Only has stateful functions in it. Requires lookup to global trainmanager's managed trains objects.

local TrainManagerStateFuncs = {}
local TrainManagerFuncs = require("scripts/train-manager-functions")
--local Logging = require("utility/logging")
local Utils = require("utility/utils")
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")
local Common = require("scripts/common")
local TunnelSignalDirection, TunnelUsageChangeReason, TunnelUsageParts, TunnelUsageAction, PrimaryTrainPartNames, LeavingTrainStates, EnteringTrainStates = Common.TunnelSignalDirection, Common.TunnelUsageChangeReason, Common.TunnelUsageParts, Common.TunnelUsageAction, Common.PrimaryTrainPartNames, Common.LeavingTrainStates, Common.EnteringTrainStates
local TrainManagerPlayerContainers = require("scripts/train-manager-player-containers")
local TrainManagerRemote = require("scripts/train-manager-remote")

TrainManagerStateFuncs.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_created, "TrainManager.TrainTracking_OnTrainCreated", TrainManagerStateFuncs.TrainTracking_OnTrainCreated)
    Interfaces.RegisterInterface("TrainManager.On_TunnelRemoved", TrainManagerStateFuncs.On_TunnelRemoved)
    Interfaces.RegisterInterface("TrainManager.On_PortalReplaced", TrainManagerStateFuncs.On_PortalReplaced)
    Interfaces.RegisterInterface("TrainManager.GetTrainIdsManagedTrainDetails", TrainManagerStateFuncs.GetTrainIdsManagedTrainDetails)
end

--- Update the passed in train schedule if the train is currently heading for an underground tunnel rail. If so change the target rail to be the end of the portal. Avoids the train infinite loop pathing through the tunnel trying to reach a tunnel rail it never can.
---@param managedTrain ManagedTrain
---@param train LuaTrain
TrainManagerStateFuncs.UpdateScheduleForTargetRailBeingTunnelRail = function(managedTrain, train)
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
TrainManagerStateFuncs.HandleTrainNewlyEntering = function(managedTrain)
    local enteringTrain = managedTrain.enteringTrain

    -- Schedule has been transferred to dummy train.

    enteringTrain.schedule = {
        current = 1, ---@type uint
        ---@type TrainScheduleRecord[]
        records = {
            {station = "ENTERING TUNNEL - EDIT LEAVING TRAIN"}
        }
    }

    -- Prevent player from messing with all entering carriages.
    for _, carriage in pairs(enteringTrain.carriages) do
        carriage.operable = false
    end
end

---@param managedTrain ManagedTrain
---@param enteringTrain LuaTrain
---@param enteringTrainForwards boolean
---@return LuaEntity
TrainManagerStateFuncs.GetEnteringTrainLeadCarriageCache = function(managedTrain, enteringTrain, enteringTrainForwards)
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

---@param managedTrain ManagedTrain
TrainManagerStateFuncs.DestroyDummyTrain = function(managedTrain)
    -- Dummy trains are never passed between trainManagerEntries, so don't have to check the global trainIdToManagedTrain's managedTrain id.
    if managedTrain.dummyTrain ~= nil and managedTrain.dummyTrain.valid then
        global.trainManager.trainIdToManagedTrain[managedTrain.dummyTrainId] = nil
        TrainManagerFuncs.DestroyTrainsCarriages(managedTrain.dummyTrain)
        managedTrain.dummyTrain, managedTrain.dummyTrainId = nil, nil
    elseif managedTrain.dummyTrainId ~= nil then
        global.trainManager.trainIdToManagedTrain[managedTrain.dummyTrainId] = nil
    end
end

---@param event on_train_created
TrainManagerStateFuncs.TrainTracking_OnTrainCreated = function(event)
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
        trainAttributeName = "dummyTrain"
        trainIdAttributeName = "dummyTrainId"
    elseif trackedTrainIdObject.tunnelUsagePart == TunnelUsageParts.leavingTrain then
        trainAttributeName = "leavingTrain"
        trainIdAttributeName = "leavingTrainId"
    elseif trackedTrainIdObject.tunnelUsagePart == TunnelUsageParts.leftTrain then
        trainAttributeName = "leftTrain"
        trainIdAttributeName = "leftTrainId"
    elseif trackedTrainIdObject.tunnelUsagePart == TunnelUsageParts.portalTrackTrain then
        trainAttributeName = "portalTrackTrain"
        trainIdAttributeName = "portalTrackTrainId"
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

---@param managedTrain ManagedTrain
---@param trainAttributeName string
---@param absoluteSpeed double
TrainManagerStateFuncs.SetAbsoluteTrainSpeed = function(managedTrain, trainAttributeName, absoluteSpeed)
    local train = managedTrain[trainAttributeName] ---@type LuaTrain

    -- Only update train's global forwards if speed ~= 0. As the last train direction needs to be preserved in global data for if the train stops while using the tunnel.]

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
            error("TrainManagerStateFuncs.SetAbsoluteTrainSpeed() for '" .. trainAttributeName .. "' doesn't support train with current 0 speed and no 'Forwards' cached value.\n" .. trainAttributeName .. " id: " .. managedTrain.id)
        end
    end
end

---@param tunnelRemoved Tunnel
TrainManagerStateFuncs.On_TunnelRemoved = function(tunnelRemoved)
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

            TrainManagerStateFuncs.TerminateTunnelTrip(managedTrain, TunnelUsageChangeReason.tunnelRemoved)
        end
    end
end

-- Light - reviewed.
---@param train LuaTrain
---@param aboveEntrancePortalEndSignal PortalEndSignal
---@param traversingTunnel boolean
---@param upgradeManagedTrain ManagedTrain @An existing ManagedTrain object that is being updated/overwritten with fresh data.
---@return ManagedTrain
TrainManagerStateFuncs.CreateManagedTrainObject = function(train, aboveEntrancePortalEndSignal, traversingTunnel, upgradeManagedTrain)
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
        leavingTrainExpectedBadState = false,
        leavingTrainAtEndOfPortalTrack = false
    }
    if trainSpeed == 0 then
        error("TrainManagerStateFuncs.CreateManagedTrainObject() doesn't support 0 speed\ntrain id: " .. trainId)
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
TrainManagerStateFuncs.On_PortalReplaced = function(tunnel, newPortal)
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
TrainManagerStateFuncs.TerminateTunnelTrip = function(managedTrain, tunnelUsageChangeReason, releaseTunnel)
    TrainManagerPlayerContainers.On_TerminateTunnelTrip(managedTrain) --OVERHAUL - was conditional on underground train before. May need fixing up.
    TrainManagerStateFuncs.RemoveManagedTrainEntry(managedTrain)

    if releaseTunnel == nil or releaseTunnel == true then
        Interfaces.Call("Tunnel.TrainReleasedTunnel", managedTrain)
    end
    TrainManagerRemote.TunnelUsageChanged(managedTrain.id, TunnelUsageAction.terminated, tunnelUsageChangeReason)
end

---@param managedTrain ManagedTrain
TrainManagerStateFuncs.RemoveManagedTrainEntry = function(managedTrain)
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

    TrainManagerStateFuncs.DestroyDummyTrain(managedTrain)

    if managedTrain.portalTrackTrain and managedTrain.portalTrackTrain.valid and global.trainManager.trainIdToManagedTrain[managedTrain.portalTrackTrain.id] and global.trainManager.trainIdToManagedTrain[managedTrain.portalTrackTrain.id].managedTrain.id == managedTrain.id then
        global.trainManager.trainIdToManagedTrain[managedTrain.portalTrackTrain.id] = nil
    elseif managedTrain.portalTrackTrainId and global.trainManager.trainIdToManagedTrain[managedTrain.portalTrackTrainId] and global.trainManager.trainIdToManagedTrain[managedTrain.portalTrackTrainId].managedTrain.id == managedTrain.id then
        global.trainManager.trainIdToManagedTrain[managedTrain.portalTrackTrainId] = nil
    end

    -- Set all states to finished so that the TrainManagerStateFuncs.ProcessManagedTrains() loop won't execute anything further this tick.
    managedTrain.primaryTrainPartName = PrimaryTrainPartNames.finished
    managedTrain.enteringTrainState = EnteringTrainStates.finished
    managedTrain.leavingTrainState = LeavingTrainStates.finished

    global.trainManager.managedTrains[managedTrain.id] = nil
end

---@param managedTrain ManagedTrain
---@param trainAttributeName string
---@param desiredSpeed double
---@return boolean
TrainManagerStateFuncs.Check0OnlySpeedTrainWithLocoGoingExpectedDirection = function(managedTrain, trainAttributeName, desiredSpeed)
    -- This requires the train to have a locomotive so that it can be given a path.
    -- This is the only known way to check which way a train with 0 speed and making no carriage changes is really wanting to go. As the LuaTrain attributes only update when the train has a speed or a carriage is added/removed.
    local train = managedTrain[trainAttributeName]
    local scheduleBackup, isManualBackup, targetTrainStop = train.schedule, train.manual_mode, train.path_end_stop

    train.manual_mode = true
    TrainManagerStateFuncs.SetAbsoluteTrainSpeed(managedTrain, trainAttributeName, desiredSpeed)
    TrainManagerFuncs.TrainSetSchedule(train, scheduleBackup, isManualBackup, targetTrainStop, true) -- Don't force validation.
    local trainIsFacingExpectedDirection = train.speed ~= 0
    train.speed = 0 -- Set speed back, everything else was reset by the setting train schedule.
    if trainIsFacingExpectedDirection then
        return true
    else
        return false
    end
end

---@param trainId Id
---@return ManagedTrain
TrainManagerStateFuncs.GetTrainIdsManagedTrainDetails = function(trainId)
    return global.trainManager.trainIdToManagedTrain[trainId]
end

return TrainManagerStateFuncs
