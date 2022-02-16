-- Manages the cached data of trains for use by other modules.

local TrainCachedData = {}
local Events = require("utility.events")
local Common = require("scripts.common")
local Utils = require("utility.utils")

---@class TrainCachedData
---@field id Id @ Train Id
---@field carriagesCachedData Utils_TrainCarriageData[] @ The cached carriage details of the train.
---@field leadCarriageUnitNumber UnitNumber @ The carriage unit number of the first carriage in the train, regardless of travelling direction or speed.
---@field trainLength double @ How much tunnel space the train takes up.
---@field forwardFacingLocomotiveCount? uint|null @ How many locomotives are facing forwards for the cached carriage data. Only populated when either train speed calculation data is generated.
---@field backwardFacingLocomotiveCount? uint|null @ How many locomotives are facing backwards for the cached carriage data. Only populated when either train speed calculation data is generated.
---@field forwardMovingTrainSpeedCalculationData? Utils_TrainSpeedCalculationData|null @ Only populated when required for the forward movement of this cached train.
---@field backwardMovingTrainSpeedCalculationData? Utils_TrainSpeedCalculationData|null @ Only populated when required for the backwards movement of this cached train.

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

    MOD.Interfaces.TrainCachedData = MOD.Interfaces.TrainCachedData or {}
    MOD.Interfaces.TrainCachedData.GetCreateTrainCache = TrainCachedData.GetCreateTrainCache
    MOD.Interfaces.TrainCachedData.UpdateTrainCacheId = TrainCachedData.UpdateTrainCacheId
    MOD.Interfaces.TrainCachedData.UpdateTrainSpeedCalculationData = TrainCachedData.UpdateTrainSpeedCalculationData
    -- Merged event handler interfaces.
    MOD.Interfaces.TrainCachedData.OnRollingStockRemoved = TrainCachedData.OnRollingStockRemoved
end

--- Called when a new train is created from train carriage changes. Primarily when a train has a carriage added to it, is decoupled in to 2 new trains or old 2 trains are coupled in to 1 new train.
---@param event on_train_created
TrainCachedData.OnTrainCreated = function(event)
    -- Id no old train Id then its a brand new train being built.
    if event.old_train_id_1 == nil then
        return
    end

    -- Check if either/both old train had been cached and if so remove the cache.
    local trainCachedData1 = global.trainCachedData.trains[event.old_train_id_1]
    if trainCachedData1 ~= nil then
        -- Removed the cached data for this train as the train is no longer valid.
        global.trainCachedData.trains[trainCachedData1.id] = nil
    end

    local trainCachedData2 = global.trainCachedData.trains[event.old_train_id_2]
    if trainCachedData2 ~= nil then
        -- Removed the cached data for this train as the train is no longer valid.
        global.trainCachedData.trains[trainCachedData2.id] = nil
    end

    -- Check if there is a managed train that needs stopping for either/both. Both could be using a tunnel if both leaving portals and are coupled togeather.
    local managedTrain1 = global.trainManager.trainIdToManagedTrain[event.old_train_id_1] --TrainManager.GetTrainIdsManagedTrain()
    if managedTrain1 ~= nil then
        -- Managed train for this Id exist, so stop it processing as the main train is now invalid.
        MOD.Interfaces.TrainManager.InvalidTrainFound(managedTrain1)
    end
    local managedTrain2 = global.trainManager.trainIdToManagedTrain[event.old_train_id_2] --TrainManager.GetTrainIdsManagedTrain()
    if managedTrain2 ~= nil then
        -- Managed train for this Id exist, so stop it processing as the main train is now invalid.
        MOD.Interfaces.TrainManager.InvalidTrainFound(managedTrain2)
    end
end

--- Called by all the events that remove rolling stock and thus change a train.
---@param event on_player_mined_entity|on_robot_mined_entity|on_entity_died|script_raised_destroy
---@param diedEntity LuaEntity
TrainCachedData.OnRollingStockRemoved = function(event, diedEntity)
    -- This function can be called either by local event registration or from tunnel-shared event handlder function.
    if diedEntity == nil then
        diedEntity = event.entity
        if not diedEntity.valid then
            return
        end
    end

    local trainId = diedEntity.train.id

    -- Check if the entity's train was one we had cached and if so remove the cache.
    if global.trainCachedData.trains[trainId] ~= nil then
        -- Removed the cached data for this train as the train is no longer valid.
        global.trainCachedData.trains[trainId] = nil
    end

    -- Check if there is a managed train that needs stopping.
    local managedTrain = global.trainManager.trainIdToManagedTrain[trainId] --TrainManager.GetTrainIdsManagedTrain()
    if managedTrain ~= nil then
        -- Managed train for this Id exist, so stop it processing as the main train is now invalid.
        MOD.Interfaces.TrainManager.InvalidTrainFound(managedTrain)
    end
end

--- Gets a train cache for the supplied train and if one doesn't exist it creates it first.
---@param train LuaTrain
---@param train_id Id
---@return TrainCachedData trainCachedData
TrainCachedData.GetCreateTrainCache = function(train, train_id)
    -- If cache already exists return this.
    local trainCache = global.trainCachedData.trains[train_id]
    if trainCache ~= nil then
        return trainCache
    end

    -- No cache found so create the initial cache's data.
    local carriagesCachedData = {} ---@type Utils_TrainCarriageData[]
    local leadCarriageUnitNumber  ---@type UnitNumber
    for i, carriage in pairs(train.carriages) do
        carriagesCachedData[i] = {entity = carriage}
        if i == 1 then
            leadCarriageUnitNumber = carriage.unit_number
        end
    end
    ---@type TrainCachedData
    local trainCachedData = {
        id = train_id,
        carriagesCachedData = carriagesCachedData,
        leadCarriageUnitNumber = leadCarriageUnitNumber
    }
    -- Register the cache.
    global.trainCachedData.trains[train_id] = trainCachedData

    return trainCachedData
end

--- Updates an existing train cache to a new train Id and the lead carriage unit number. Used when teleporting a train from 1 location to another.
---@param oldId Id
---@param newId Id
---@param newLeadCarriageUnitNumber UnitNumber
TrainCachedData.UpdateTrainCacheId = function(oldId, newId, newLeadCarriageUnitNumber)
    local trainCache = global.trainCachedData.trains[oldId]
    global.trainCachedData.trains[oldId] = nil
    global.trainCachedData.trains[newId] = trainCache
    trainCache.id = newId
    trainCache.leadCarriageUnitNumber = newLeadCarriageUnitNumber
end

--- Updates the train cache's trainSpeedCalculationData for the supplied train based on its movement direction.
---@param train LuaTrain
---@param train_speed double
---@param trainCachedData TrainCachedData
---@return boolean trainForwardsCacheData @ If the train is moving in the forwards direction in relation to the cached train data. This accounts for if the train has been flipped and/or reversed in comparison to the cache.
TrainCachedData.UpdateTrainSpeedCalculationData = function(train, train_speed, trainCachedData)
    -- Code Dev Note: Looked at using the other direction's data if populated as base for new data, but the values that can be just copied are all cached base data already so basically just as quick to regenerate it and much simplier logic.
    local trainForwardsCacheData  ---@type boolean
    local trainSpeedCalculationData  ---@type Utils_TrainSpeedCalculationData

    -- Check if the train is the same layout or a flip (180 degree rotated) of what we cached before.
    if train.carriages[1].unit_number == trainCachedData.leadCarriageUnitNumber then
        -- Is the same layout so can just use speed to identify relationship between current train and cached train.
        trainForwardsCacheData = train_speed > 0
    else
        -- Is the flipped layout so its the opposite to the train's speed for the relationship between the current train and the cache.
        trainForwardsCacheData = train_speed < 0
    end

    if trainForwardsCacheData then
        -- Train moving forwards.
        if trainCachedData.forwardMovingTrainSpeedCalculationData == nil then
            -- No data held for current direction so generate it.
            trainCachedData.forwardMovingTrainSpeedCalculationData = Utils.GetTrainSpeedCalculationData(train, train_speed, nil, trainCachedData.carriagesCachedData)
        else
            -- Just update the locomotiveAccelerationPower.
            trainSpeedCalculationData = trainCachedData.forwardMovingTrainSpeedCalculationData
        end
    else
        -- Train moving backwards.
        if trainCachedData.backwardMovingTrainSpeedCalculationData == nil then
            -- No data held for current direction so generate it.
            trainCachedData.backwardMovingTrainSpeedCalculationData = Utils.GetTrainSpeedCalculationData(train, train_speed, nil, trainCachedData.carriagesCachedData)
        else
            -- Just update the locomotiveAccelerationPower.
            trainSpeedCalculationData = trainCachedData.backwardMovingTrainSpeedCalculationData
        end
    end

    -- Only run when speed calculated data is being generated for the first time
    if trainSpeedCalculationData == nil then
        -- Record how many locomotives are facing each direction if needed.
        if trainCachedData.forwardFacingLocomotiveCount == nil then
            local otherDirectionName, otherDirectionFacing
            if trainForwardsCacheData then
                -- Generated full speed data for forwards.
                trainCachedData.forwardFacingLocomotiveCount = trainCachedData.forwardMovingTrainSpeedCalculationData.forwardFacingLocoCount
                otherDirectionName = "backwardFacingLocomotiveCount"
                otherDirectionFacing = false
            else
                -- Generated full speed data for backwards.
                trainCachedData.backwardFacingLocomotiveCount = trainCachedData.backwardMovingTrainSpeedCalculationData.forwardFacingLocoCount
                otherDirectionName = "forwardFacingLocomotiveCount"
                otherDirectionFacing = true
            end

            -- Loop over the cached carriage data and count how many locos are facing the other direction.
            local otherDirectionCount = 0
            for _, carriage in pairs(trainCachedData.carriagesCachedData) do
                if carriage.faceingFrontOfTrain == otherDirectionFacing then
                    otherDirectionCount = otherDirectionCount + 1
                end
            end
            trainCachedData[otherDirectionName] = otherDirectionCount
        end

        -- Nothing else needs doing as all data was generated during function call.
        return trainForwardsCacheData
    end

    -- Update the acceleration value back in to the cache on each calling.
    local fuelAccelerationBonus
    for _, carriageCachedData in pairs(trainCachedData.carriagesCachedData) do
        -- Note: this is a partial clone from Utils.GetTrainSpeedCalculationData().
        -- Only process locomotives that are powering the trains movement.
        if carriageCachedData.prototypeType == "locomotive" and trainForwardsCacheData == carriageCachedData.faceingFrontOfTrain then
            local carriage = carriageCachedData.entity
            local currentFuelPrototype = Utils.GetLocomotivesCurrentFuelPrototype(carriage)
            if currentFuelPrototype ~= nil then
                -- No benefit to using PrototypeAttributes.GetAttribute() as we'd have to get the prototypeName to load from the cache each time and theres only 1 attribute we want in this case.
                fuelAccelerationBonus = currentFuelPrototype.fuel_acceleration_multiplier
                -- Just get fuel from one forward facing loco that has fuel. Have to check the inventory as the train ill be breaking for the signal theres no currently burning.0a
                break
            end
        end
    end
    trainSpeedCalculationData.locomotiveAccelerationPower = 10 * trainSpeedCalculationData.forwardFacingLocoCount * ((fuelAccelerationBonus or 1) / trainSpeedCalculationData.trainWeight)

    return trainForwardsCacheData
end

return TrainCachedData
