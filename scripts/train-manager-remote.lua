-- The remote interface functions of the Train Manager.

local TrainManagerRemote = {}
local Utils = require("utility/utils")
local Events = require("utility/events")

---@class RemoteTunnelUsageEntry
---@field tunnelUsageId Id
---@field primaryState PrimaryTrainState
---@field enteringTrain LuaTrain
---@field leavingTrain LuaTrain
---@field tunnelId Id

---@class RemoteTunnelUsageChanged : RemoteTunnelUsageEntry
---@field name string @ The custom event name that this event is bveing raised for. Used by the Events library to find the remote Id to publish it under.
---@field action TunnelUsageAction
---@field changeReason TunnelUsageChangeReason
---@field replacedtunnelUsageId Id

TrainManagerRemote.CreateGlobals = function()
    global.trainManager.eventsToRaise = global.trainManager.eventsToRaise or {} ---@type table[] @ Events are raised at end of tick to avoid other mods interupting this mod's process and breaking things.
end

TrainManagerRemote.ProcessTicksEvents = function()
    -- Raise any events from this tick for external listener mods to react to.
    if #global.trainManager.eventsToRaise ~= 0 then
        for _, eventData in pairs(global.trainManager.eventsToRaise) do
            TrainManagerRemote.PopulateTableWithTunnelUsageEntryObjectAttributes(eventData, eventData.tunnelUsageId)
            Events.RaiseEvent(eventData)
        end
        global.trainManager.eventsToRaise = {}
    end
end

--- The managedTrainID is passed in from caller, whether than be from the caller's context or by the caller from already being set in the tableToPopulate as the tunnelUsageId value.
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
    tableToPopulate.tunnelId = managedTrain.tunnel.id
end

---@param managedTrainId Id
---@param action TunnelUsageAction
---@param changeReason TunnelUsageChangeReason
---@param replacedtunnelUsageId Id
TrainManagerRemote.TunnelUsageChanged = function(managedTrainId, action, changeReason, replacedtunnelUsageId)
    -- Schedule the event to be raised after all trains are handled for this tick. Otherwise events can interupt the mods processes and cause errors.
    -- Don't put the Factorio Lua object references in here yet as they may become invalid by send time and then the event is dropped.
    ---@type RemoteTunnelUsageChanged
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
---@return RemoteTunnelUsageEntry
TrainManagerRemote.GetTunnelUsageEntry = function(managedTrainId)
    local tunnelUsageEntry = {}
    TrainManagerRemote.PopulateTableWithTunnelUsageEntryObjectAttributes(tunnelUsageEntry, managedTrainId)
    return tunnelUsageEntry
end

---@param trainId Id
---@return RemoteTunnelUsageEntry
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

---@return table<string, string> @ Entity names.
TrainManagerRemote.GetTemporaryCarriageNames = function()
    return {
        ["railway_tunnel-tunnel_exit_dummy_locomotive"] = "railway_tunnel-tunnel_exit_dummy_locomotive",
        ["railway_tunnel-tunnel_portal_blocking_locomotive"] = "railway_tunnel-tunnel_portal_blocking_locomotive"
    }
end

return TrainManagerRemote
