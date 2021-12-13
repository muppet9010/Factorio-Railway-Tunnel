-- Only has stateful functions in it. Requires lookup to global trainmanager's managed trains objects.

local TrainManagerStateFuncs = {}
local TrainManagerFuncs = require("scripts/train-manager-functions")
--local Logging = require("utility/logging")
local Utils = require("utility/utils")
local Interfaces = require("utility/interfaces")
local Common = require("scripts/common")
local TunnelSignalDirection, TunnelUsageChangeReason, TunnelUsageParts, TunnelUsageAction, PrimaryTrainState = Common.TunnelSignalDirection, Common.TunnelUsageChangeReason, Common.TunnelUsageParts, Common.TunnelUsageAction, Common.PrimaryTrainState
local TrainManagerPlayerContainers = require("scripts/train-manager-player-containers")
local TrainManagerRemote = require("scripts/train-manager-remote")

TrainManagerStateFuncs.OnLoad = function()
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
        leavingTrainAtEndOfPortalTrack = false,
        tempEnteringSpeed = trainSpeed
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
    managedTrain.primaryTrainPartName = PrimaryTrainState.finished

    global.trainManager.managedTrains[managedTrain.id] = nil
end

---@param trainId Id
---@return ManagedTrain
TrainManagerStateFuncs.GetTrainIdsManagedTrainDetails = function(trainId)
    return global.trainManager.trainIdToManagedTrain[trainId]
end

-- Clone the entering train to the front of the end portal. This will minimise any tracking of the train when leaving.
---@param managedTrain ManagedTrain
---@return LuaTrain
TrainManagerStateFuncs.CloneEnteringTrainToExit = function(managedTrain)
    -- This currently assumes the portals are in a stright line of each other and that the portal areas are straight.
    local refTrain, trainCarriagesForwardOrientation = managedTrain.enteringTrain, managedTrain.trainTravelOrientation
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
    local refTrainSpeed, refTrainCarriages = refTrain.speed, refTrain.carriages
    if (refTrainSpeed > 0) then
        minCarriageIndex, maxCarriageIndex, carriageIterator = 1, #refTrainCarriages, 1
    elseif (refTrainSpeed < 0) then
        minCarriageIndex, maxCarriageIndex, carriageIterator = #refTrainCarriages, 1, -1
    else
        error("TrainManagerStateFuncs.CopyEnteringTrainUnderground() doesn't support 0 speed refTrain.\nrefTrain id: " .. refTrain.id)
    end

    --Iterate over the carriages and clone them.
    local refCarriage, refCarriage_name
    local lastPlacedCarriage, lastPlacedCarriage_name
    for currentSourceTrainCarriageIndex = minCarriageIndex, maxCarriageIndex, carriageIterator do
        refCarriage = refTrainCarriages[currentSourceTrainCarriageIndex]
        refCarriage_name = refCarriage.name
        local carriageOrientation = trainCarriagesForwardOrientation
        if refCarriage.speed ~= refTrainSpeed then
            carriageOrientation = Utils.BoundFloatValueWithinRangeMaxExclusive(carriageOrientation + 0.5, 0, 1)
        end

        nextCarriagePosition = TrainManagerFuncs.GetNextCarriagePlacementPosition(managedTrain.trainTravelOrientation, nextCarriagePosition, lastPlacedCarriage_name, refCarriage_name)
        lastPlacedCarriage = TrainManagerFuncs.CopyCarriage(targetSurface, refCarriage, nextCarriagePosition, nil, carriageOrientation)
        lastPlacedCarriage_name = refCarriage_name
    end

    return lastPlacedCarriage.train
end

return TrainManagerStateFuncs
