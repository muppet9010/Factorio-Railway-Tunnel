-- Manages the cached data of trains for use by other modules.

local TrainCachedData = {}
local Events = require("utility/events")
local Common = require("scripts/common")

---@class TrainCachedData
---@field id Id @ Train Id
---@field carriagesCachedData Utils_TrainCarriageData[] @ The cached carriage details of the train.

TrainCachedData.CreateGlobals = function()
    global.trainCachedData = global.trainCachedData or {}
    global.trainCachedData.trains = global.trainCachedData.trains or {} ---@type table<Id, TrainCachedData> @ Id is the train's Id.
end

TrainCachedData.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_created, "TrainCachedData.OnTrainCreated", TrainCachedData.OnTrainCreated)

    local rollingStockTypeFilter = {}
    for _, rollingStockType in pairs(Common.RollingStockTypes) do
        table.insert(rollingStockTypeFilter, {filter = "type", type = rollingStockType})
    end
    Events.RegisterHandlerEvent(defines.events.on_player_mined_entity, "TrainCachedData.OnRollingStockRemoved", TrainCachedData.OnRollingStockRemoved, rollingStockTypeFilter)
    Events.RegisterHandlerEvent(defines.events.on_robot_mined_entity, "TrainCachedData.OnRollingStockRemoved", TrainCachedData.OnRollingStockRemoved, rollingStockTypeFilter)
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "TrainCachedData.OnRollingStockRemoved", TrainCachedData.OnRollingStockRemoved, rollingStockTypeFilter)
    Events.RegisterHandlerEvent(defines.events.script_raised_destroy, "TrainCachedData.OnRollingStockRemoved", TrainCachedData.OnRollingStockRemoved, rollingStockTypeFilter)

    MOD.Interfaces.TrainCachedData = MOD.Interfaces.TrainCachedData or {}
    MOD.Interfaces.TrainCachedData.CreateTrainCache = TrainCachedData.CreateTrainCache
    MOD.Interfaces.TrainCachedData.UpdateTrainCacheId = TrainCachedData.UpdateTrainCacheId
end

--- Called when a new train is created, which includes all train carriage changes apart from the removal of the final train carriage from the map.
---@param event on_train_created
TrainCachedData.OnTrainCreated = function(event)
    -- Id no old train Id then its a brand new train being built.
    if event.old_train_id_1 == nil then
        return
    end

    -- Old train Id 1 is populated for changes to a single train. Old train Id 2 is populated purely when 2 trains are joined in to 1 new train.
    ---@type TrainCachedData
    local trainCachedData = global.trainCachedData.trains[event.old_train_id_1] or global.trainCachedData.trains[event.old_train_id_2]
    if trainCachedData == nil then
        return
    end

    -- Removed the cached data for this train as the train is no longer valid.
    global.trainCachedData.trains[trainCachedData.id] = nil
end

--- Called by all the events that remove rolling stock. To fill the logic gap in TrainCachedData.OnTrainCreated().
--- Alternative to needing this event handler is to not cache trains 1 carriage long in the global state at all. As unlikely many real trains are going to be this long ever.
---@param event on_player_mined_entity|on_robot_mined_entity|on_entity_died|script_raised_destroy
TrainCachedData.OnRollingStockRemoved = function(event)
    local entity = event.entity
    -- Handle any other registrations of this event across the mod.
    if Common.RollingStockTypes[entity.type] == nil then
        return
    end

    --
    local trainId = entity.train
    local trainCachedData = global.trainCachedData.trains[trainId]
    if trainCachedData ~= nil then
        -- Removed the cached data for this train as the train is no longer valid.
        global.trainCachedData.trains[trainCachedData.id] = nil
    end
end

--- Creates a new train cache for the supplied train.
---@param train LuaTrain
---@param train_id Id
---@return Utils_TrainCarriageData[] carriagesCachedData
TrainCachedData.CreateTrainCache = function(train, train_id)
    --- Get the initial cache's data.
    ---@type Utils_TrainCarriageData[]
    local carriagesCachedData = {}
    for i, carriage in pairs(train.carriages) do
        carriagesCachedData[i] = {entity = carriage}
        if i == 1 then
            carriagesCachedData[1].unitNumber = carriage.unit_number
        end
    end

    ---@type TrainCachedData
    local trainCachedData = {
        id = train_id,
        carriagesCachedData = carriagesCachedData
    }
    global.trainCachedData.trains[train_id] = trainCachedData

    return carriagesCachedData
end

--- Updates an existing train cache to a new train Id. Used when teleporting a train from 1 location to another.
---@param oldId Id
---@param newId Id
TrainCachedData.UpdateTrainCacheId = function(oldId, newId)
    local trainCache = global.trainCachedData.trains[oldId]
    global.trainCachedData.trains[oldId] = nil
    global.trainCachedData.trains[newId] = trainCache
    trainCache.id = newId
end

return TrainCachedData
