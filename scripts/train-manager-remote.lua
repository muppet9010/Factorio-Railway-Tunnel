-- The remote interface functions of the Train Manager.

local TrainManagerRemote = {}
local Utils = require("utility/utils")
local Events = require("utility/events")

---@class TunnelUsageEntry
---@field tunnelUsageId Id
---@field primaryState PrimaryTrainPartNames
---@field enteringTrain LuaTrain
---@field undegroundTrain LuaTrain
---@field leavingTrain LuaTrain
---@field leftTrain LuaTrain
---@field tunnelId Id

TrainManagerRemote.CreateGlobals = function()
    global.trainManager.eventsToRaise = global.trainManager.eventsToRaise or {} ---@type table[] @Events are raised at end of tick to avoid other mods interupting this mod's process and breaking things.
end

TrainManagerRemote.ProcessTicksEvents = function()
    -- Raise any events from this tick for external listener mods to react to.
    if #global.trainManager.eventsToRaise ~= 0 then
        for _, eventData in pairs(global.trainManager.eventsToRaise) do
            TrainManagerRemote.PopulateTableWithTunnelUsageEntryObjectAttributes(eventData, eventData.tunnelUsageId)
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

---@param tableToPopulate table
---@param managedTrainId Id
TrainManagerRemote.PopulateTableWithTunnelUsageEntryObjectAttributes = function(tableToPopulate, managedTrainId)
    local managedTrain = global.trainManager.managedTrains[managedTrainId]
    if managedTrain == nil then
        return
    end

    -- Only return valid LuaTrains as otherwise the events are dropped by Factorio.
    tableToPopulate.tunnelUsageId = managedTrainId
    tableToPopulate.primaryState = managedTrain.primaryTrainPartName
    tableToPopulate.enteringTrain = Utils.ReturnValidLuaObjectOrNil(managedTrain.enteringTrain)
    tableToPopulate.leavingTrain = Utils.ReturnValidLuaObjectOrNil(managedTrain.leavingTrain)
    tableToPopulate.leftTrain = Utils.ReturnValidLuaObjectOrNil(managedTrain.leftTrain)
    tableToPopulate.tunnelId = managedTrain.tunnel.id
end

---@param managedTrainId Id
---@param action TunnelUsageAction
---@param changeReason TunnelUsageChangeReason
---@param replacedtunnelUsageId Id
TrainManagerRemote.TunnelUsageChanged = function(managedTrainId, action, changeReason, replacedtunnelUsageId)
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

---@param managedTrainId Id
---@return TunnelUsageEntry
TrainManagerRemote.GetTunnelUsageEntry = function(managedTrainId)
    local tunnelUsageEntry = {}
    TrainManagerRemote.PopulateTableWithTunnelUsageEntryObjectAttributes(tunnelUsageEntry, managedTrainId)
    return tunnelUsageEntry
end

---@param trainId Id
---@return TunnelUsageEntry
TrainManagerRemote.GetATrainsTunnelUsageEntry = function(trainId)
    local trackedTrainIdObject = global.trainManager.trainIdToManagedTrain[trainId]
    if trackedTrainIdObject == nil then
        return nil
    end
    local managedTrain = trackedTrainIdObject.managedTrain
    if managedTrain ~= nil then
        local tunnelUsageEntry = {}
        TrainManagerRemote.PopulateTableWithTunnelUsageEntryObjectAttributes(tunnelUsageEntry, managedTrain.id)
        return tunnelUsageEntry
    else
        return nil
    end
end

---@return table<string, string> @Entity names.
TrainManagerRemote.GetTemporaryCarriageNames = function()
    return {
        ["railway_tunnel-tunnel_portal_pushing_locomotive"] = "railway_tunnel-tunnel_portal_pushing_locomotive",
        ["railway_tunnel-tunnel_exit_dummy_locomotive"] = "railway_tunnel-tunnel_exit_dummy_locomotive",
        ["railway_tunnel-tunnel_portal_blocking_locomotive"] = "railway_tunnel-tunnel_portal_blocking_locomotive"
    }
end

return TrainManagerRemote
