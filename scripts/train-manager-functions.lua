-- Only has self contained functions in it. Doesn't require lookup to global trainmanager's managed trains.

local TrainManagerFuncs = {}
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local Common = require("scripts/common")
local RollingStockTypes = Common.RollingStockTypes

---@param train LuaTrain
---@param isFrontStockLeading boolean
---@return LuaEntity
TrainManagerFuncs.GetLeadingWagonOfTrain = function(train, isFrontStockLeading)
    if isFrontStockLeading then
        return train.front_stock
    else
        return train.back_stock
    end
end

---@param train LuaTrain
---@return boolean
TrainManagerFuncs.IsTrainHealthlyState = function(train)
    -- Uses state and not LuaTrain.has_path, as a train waiting at a station doesn't have a path, but is a healthy state.
    local trainState = train.state
    if trainState == defines.train_state.no_path or trainState == defines.train_state.path_lost then
        return false
    else
        return true
    end
end

---@param carriage LuaEntity
---@param forwardsOrientation RealOrientation
---@return boolean
TrainManagerFuncs.CarriageIsAForwardsLoco = function(carriage, forwardsOrientation)
    return carriage.type == "locomotive" and carriage.orientation == forwardsOrientation
end

---@param train LuaTrain
---@param forwardsOrientation RealOrientation
---@return boolean
TrainManagerFuncs.DoesTrainHaveAForwardsLoco = function(train, forwardsOrientation)
    for _, carriage in pairs(train.carriages) do
        if TrainManagerFuncs.CarriageIsAForwardsLoco(carriage, forwardsOrientation) then
            return true
        end
    end
    return false
end

---@param train LuaTrain
---@return boolean
TrainManagerFuncs.RemoveAnyPushingLocosFromTrain = function(train)
    -- Pushing locos should only be at either end of the train.
    local pushingLocoEntityName = "railway_tunnel-tunnel_portal_pushing_locomotive"
    local safeTrainCarriage = train.back_stock -- An entity to hold on to so we can get the train if we have to delete a carriage and the train ref becomes invalid.
    local aPushingLocoWasRemoved = false
    if train.front_stock.name == pushingLocoEntityName then
        train.front_stock.destroy()
        train = safeTrainCarriage.train
        aPushingLocoWasRemoved = true
    end
    if train.back_stock.name == pushingLocoEntityName then
        train.back_stock.destroy()
        aPushingLocoWasRemoved = true
    end
    return aPushingLocoWasRemoved
end

---@param lastCarriage LuaEntity
---@param trainOrientation RealOrientation
---@return LuaEntity
TrainManagerFuncs.AddPushingLocoToAfterCarriage = function(lastCarriage, trainOrientation)
    local pushingLocoEntityName = "railway_tunnel-tunnel_portal_pushing_locomotive"
    local pushingLocoPlacementPosition = TrainManagerFuncs.GetNextCarriagePlacementPosition(trainOrientation, lastCarriage, pushingLocoEntityName)
    local pushingLocomotiveEntity = lastCarriage.surface.create_entity {name = pushingLocoEntityName, position = pushingLocoPlacementPosition, force = lastCarriage.force, direction = Utils.OrientationToDirection(trainOrientation)}
    pushingLocomotiveEntity.destructible = false
    return pushingLocomotiveEntity
end

---@param targetSurface LuaSurface
---@param refCarriage LuaEntity
---@param newPosition Position
---@param safeCarriageFlipPosition Position
---@param requiredOrientation RealOrientation
---@return LuaEntity
TrainManagerFuncs.CopyCarriage = function(targetSurface, refCarriage, newPosition, safeCarriageFlipPosition, requiredOrientation)
    -- Work out if we will need to flip the cloned carriage or not.
    local orientationDif = math.abs(refCarriage.orientation - requiredOrientation)
    local haveToFlipCarriage = false
    if orientationDif > 0.25 and orientationDif < 0.75 then
        -- Will need to flip the carriage.
        haveToFlipCarriage = true
    elseif orientationDif == 0.25 or orientationDif == 0.75 then
        -- May end up the correct way, depending on what rotation we want. Factorio rotates positive orientation when equally close.
        if Utils.BoundFloatValueWithinRangeMaxExclusive(refCarriage.orientation + 0.25, 0, 1) ~= requiredOrientation then
            -- After a positive rounding the carriage isn't going to be facing the right way.
            haveToFlipCarriage = true
        end
    end

    -- Create an intial clone of the carriage away from the train, flip its orientation, then clone the carriage to the right place. Saves having to disconnect the train and reconnect it.
    ---@typelist LuaEntity, LuaEntity
    local tempCarriage, sourceCarriage
    if haveToFlipCarriage then
        tempCarriage = refCarriage.clone {position = safeCarriageFlipPosition, surface = targetSurface, create_build_effect_smoke = false}
        if tempCarriage.orientation == requiredOrientation then
            error("underground carriage flipping not needed, but predicted. \nrequiredOrientation: " .. tostring(requiredOrientation) .. "\ntempCarriage.orientation: " .. tostring(tempCarriage.orientation) .. "\nrefCarriage.orientation: " .. tostring(refCarriage.orientation))
        end
        tempCarriage.rotate()
        sourceCarriage = tempCarriage
    else
        sourceCarriage = refCarriage
    end

    local placedCarriage = sourceCarriage.clone {position = newPosition, surface = targetSurface, create_build_effect_smoke = false}
    if placedCarriage == nil then
        error("failed to clone carriage:" .. "\nsurface name: " .. targetSurface.name .. "\nposition: " .. Logging.PositionToString(newPosition) .. "\nsource carriage unit_number: " .. refCarriage.unit_number)
    end

    if haveToFlipCarriage then
        tempCarriage.destroy()
    end
    if placedCarriage.orientation ~= requiredOrientation then
        error("placed underground carriage isn't correct orientation.\nrequiredOrientation: " .. tostring(requiredOrientation) .. "\nplacedCarriage.orientation: " .. tostring(placedCarriage.orientation) .. "\nrefCarriage.orientation: " .. tostring(refCarriage.orientation))
    end

    return placedCarriage
end

---@param train LuaTrain
---@param targetTrainStop LuaEntity
TrainManagerFuncs.SetTrainToAuto = function(train, targetTrainStop)
    if targetTrainStop ~= nil and targetTrainStop.valid then
        -- Train limits on the original target train stop of the train going through the tunnel might prevent the exiting (dummy or real) train from pathing there, so we have to ensure that the original target stop has a slot open before setting the train to auto.
        local oldLimit = targetTrainStop.trains_limit
        targetTrainStop.trains_limit = targetTrainStop.trains_count + 1
        train.manual_mode = false
        targetTrainStop.trains_limit = oldLimit
    else
        -- There was no target train stop, so no special handling needed.
        train.manual_mode = false
    end
end

---@param exitPortalEntity LuaEntity
---@param trainSchedule TrainSchedule
---@param targetTrainStop LuaEntity
---@param skipScheduling boolean
---@return LuaTrain
TrainManagerFuncs.CreateDummyTrain = function(exitPortalEntity, trainSchedule, targetTrainStop, skipScheduling)
    skipScheduling = skipScheduling or false
    local locomotive =
        exitPortalEntity.surface.create_entity {
        name = "railway_tunnel-tunnel_exit_dummy_locomotive",
        position = exitPortalEntity.position,
        direction = exitPortalEntity.direction,
        force = exitPortalEntity.force,
        raise_built = false,
        create_build_effect_smoke = false
    }
    locomotive.destructible = false
    locomotive.burner.currently_burning = "coal"
    locomotive.burner.remaining_burning_fuel = 4000000
    local dummyTrain = locomotive.train
    if not skipScheduling then
        TrainManagerFuncs.TrainSetSchedule(dummyTrain, trainSchedule, false, targetTrainStop)
        if dummyTrain.state == defines.train_state.destination_full then
            -- If the train ends up in one of those states something has gone wrong.
            error("dummy train has unexpected state :" .. tonumber(dummyTrain.state) .. "\nexitPortalEntity position: " .. Logging.PositionToString(exitPortalEntity.position))
        end
    end
    return dummyTrain
end

---@param train LuaTrain
TrainManagerFuncs.DestroyTrainsCarriages = function(train)
    if train ~= nil and train.valid then
        for _, carriage in pairs(train.carriages) do
            carriage.destroy()
        end
    end
end

---@param train LuaTrain
---@param schedule TrainSchedule
---@param isManual boolean
---@param targetTrainStop LuaEntity
---@param skipStateCheck boolean
TrainManagerFuncs.TrainSetSchedule = function(train, schedule, isManual, targetTrainStop, skipStateCheck)
    train.schedule, skipStateCheck = schedule, skipStateCheck or false
    if not isManual then
        TrainManagerFuncs.SetTrainToAuto(train, targetTrainStop)
        if not skipStateCheck and not TrainManagerFuncs.IsTrainHealthlyState(train) then
            -- Any issue on the train from the previous tick should be detected by the state check. So this should only trigger after misplaced wagons.
            error("train doesn't have positive state after setting schedule.\ntrain id: " .. train.id .. "\nstate: " .. train.state)
        end
    else
        train.manual_mode = true
    end
end

---@param leavingTrain LuaTrain
---@param leavingTrainPushingLoco LuaEntity
---@return LuaEntity
TrainManagerFuncs.GetRearCarriageOfLeavingTrain = function(leavingTrain, leavingTrainPushingLoco)
    -- Get the current rear carriage of the leaving train based on if a pushing loco was added. Handles train facing either direction (+/- speed) assuming the train is leaving the tunnel.
    local leavingTrainRearCarriage, leavingTrainRearCarriageIndex, leavingTrainRearCarriagePushingIndexMod
    local leavingTrainSpeed, leavingTrainCarriages = leavingTrain.speed, leavingTrain.carriages
    if (leavingTrainSpeed > 0) then
        leavingTrainRearCarriageIndex = #leavingTrainCarriages
        leavingTrainRearCarriagePushingIndexMod = -1
    elseif (leavingTrainSpeed < 0) then
        leavingTrainRearCarriageIndex = 1
        leavingTrainRearCarriagePushingIndexMod = 1
    else
        error("TrainManagerFuncs.GetRearCarriageOfLeavingTrain() doesn't support 0 speed\nleavingTrain id: " .. leavingTrain.id)
    end
    if leavingTrainPushingLoco ~= nil then
        leavingTrainRearCarriageIndex = leavingTrainRearCarriageIndex + leavingTrainRearCarriagePushingIndexMod
    end
    leavingTrainRearCarriage = leavingTrainCarriages[leavingTrainRearCarriageIndex]

    return leavingTrainRearCarriage
end

---@param sourceTrain LuaTrain
---@param leavingTrainCarriagesPlaced uint
---@return LuaEntity
TrainManagerFuncs.GetCarriageToAddToLeavingTrain = function(sourceTrain, leavingTrainCarriagesPlaced)
    -- Get the next carriage to be placed from the underground train.
    local currentSourceTrainCarriageIndex, nextSourceTrainCarriageIndex
    local sourceTrainSpeed, sourceTrainCarriages = sourceTrain.speed, sourceTrain.carriages
    if (sourceTrainSpeed > 0) then
        currentSourceTrainCarriageIndex = leavingTrainCarriagesPlaced
        nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex + 1
    elseif (sourceTrainSpeed < 0) then
        currentSourceTrainCarriageIndex = #sourceTrainCarriages - leavingTrainCarriagesPlaced
        nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex
    else
        error("TrainManagerFuncs.GetCarriageToAddToLeavingTrain() doesn't support 0 speed sourceTrain\nsourceTrain id: " .. sourceTrain.id)
    end
    local nextSourceCarriageEntity = sourceTrainCarriages[nextSourceTrainCarriageIndex]
    return nextSourceCarriageEntity
end

--- This measures to the nearest edge of the target's rail, so doesn't include any of the target's rail's length. As the target may be on an odd location on the rail.
---@param train LuaTrain
---@param targetEntity LuaEntity @Can be a rail itself or an entity connected to a rail.
---@param trainGoingForwards boolean
---@return double
TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTarget = function(train, targetEntity, trainGoingForwards)
    -- Get the rail we are measuring too.
    local targetRails
    local targetEntityType = targetEntity.type
    if targetEntityType == "train-stop" then
        targetRails = {targetEntity.connected_rail} -- A station as the stopping target can only be on 1 rail at a time.
    elseif targetEntityType == "rail-signal" or targetEntityType == "rail-chain-signal" then
        targetRails = targetEntity.get_connected_rails() -- A signal as the stopping target can be on multiple rails at once, however, only 1 will be in our path list.
    elseif targetEntityType == "straight-rail" or targetEntityType == "curved-rail" then
        targetRails = {targetEntity} -- The target is a rail itself, rather than an entity attached to a rail.
    else
        error("TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTarget() doesn't support targetEntity type: " .. targetEntityType)
    end
    local targetRailUnitNumberAsKeys = Utils.TableInnerValueToKey(targetRails, "unit_number")

    local leadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(train, trainGoingForwards)
    local leadCarriagePosition, targetRailPosition, distanceForCarriageCenter = leadCarriage.position, nil, nil

    -- Can only measure by Axis distance if theres only 1 rail attached to the targetEntity. This will be fine for when the targetEntity is part of a portal.
    local singleDifferentAxis
    if #targetRails == 1 then
        targetRailPosition = targetRails[1].position
        if leadCarriagePosition.x == targetRailPosition.x then
            singleDifferentAxis = "y"
        elseif leadCarriagePosition.y == targetRailPosition.y then
            singleDifferentAxis = "x"
        end
    end

    if singleDifferentAxis ~= nil then
        -- Just measure the single axis distance from the lead carriage to the target rail.
        local distance = Utils.GetDistanceSingleAxis(leadCarriagePosition, targetRailPosition, singleDifferentAxis)
        distanceForCarriageCenter = distance - TrainManagerFuncs.GetRailEntityLength(targetRails[1].type) -- Reduce the distance to be to the edge of the rail, rather than its center.
    elseif train.has_path then
        -- Train has a path so measure the distance from the train to the target entity. Ignores trains exact position and just deals with the tracks. The first rail isn't included here as we get the remaining part of the rail's distance later in function.
        local distance, trainPathRails = 0, train.path.rails
        for i, railEntity in pairs(trainPathRails) do
            if i > 1 then
                if targetRailUnitNumberAsKeys[railEntity.unit_number] then
                    -- One of the rails attached to the target entity has been reached in the path, so stop before we count it.
                    break
                end
                distance = distance + TrainManagerFuncs.GetRailEntityLength(railEntity.type)
            end
        end

        -- Add the remaining part of the first rail being used by the lead carriage. Carriage uses the lead joint as when it is "on" a rail piece. This isn't quite perfect when carriage is on a corner, but far closer than just the whole rail. In testing up to 0.5 tiles wrong for curves, but trains drift during tunnel use from speed as well so.
        local leadCarriageForwardOrientation
        local lastCarriageSpeed = leadCarriage.speed
        if lastCarriageSpeed > 0 then
            leadCarriageForwardOrientation = leadCarriage.orientation
        elseif lastCarriageSpeed < 0 then
            leadCarriageForwardOrientation = Utils.BoundFloatValueWithinRange(leadCarriage.orientation + 0.5, 0, 1)
        else
            error("TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTarget() doesn't support 0 speed train\ntrain id: " .. train.id)
        end
        local leadCarriageEdgePositionOffset = Utils.RotatePositionAround0(leadCarriageForwardOrientation, {x = 0, y = 0 - TrainManagerFuncs.GetCarriageJointDistance(leadCarriage.name)})
        local firstRailLeadCarriageUsedPosition = Utils.ApplyOffsetToPosition(leadCarriagePosition, leadCarriageEdgePositionOffset)
        local firstRail = trainPathRails[1]
        local firstRailFarEndPosition = TrainManagerFuncs.GetRailFarEndPosition(firstRail, leadCarriageForwardOrientation)
        local distanceRemainingOnRail = Utils.GetDistance(firstRailLeadCarriageUsedPosition, firstRailFarEndPosition)
        if firstRail.type == "curved-rail" then
            distanceRemainingOnRail = distanceRemainingOnRail * 1.0663824640154573798004974128959 -- Rough conversion for the straight line distance (7.3539105243401) to curved arc distance (7.842081225095).
        end
        distance = distance + distanceRemainingOnRail

        -- Add the joint distance to the result to get the center position of the carriage.
        distanceForCarriageCenter = distance + TrainManagerFuncs.GetCarriageJointDistance(leadCarriage.name)
    else
        error("TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTarget() not on safe single axis and train doesn't have path")
    end

    return distanceForCarriageCenter
end

---@param train LuaTrain
---@param trainGoingForwards boolean
---@return double
TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTargetStation = function(train, trainGoingForwards)
    local trainPath = train.path
    local distance = trainPath.total_distance - trainPath.travelled_distance

    -- Subtract the remaining part of the first rail being used by the lead carriage as the distance travelled is opposite to path.rails. Carriage uses the lead joint as when it is "on" a rail piece. This isn't quite perfect when carriage is on a corner, but far closer than just the whole rail. In testing up to 0.5 tiles wrong for curves, but trains drift during tunnel use from speed as well so.
    local leadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(train, trainGoingForwards)
    local leadCarriageForwardOrientation
    local lastCarriageSpeed = leadCarriage.speed
    if lastCarriageSpeed > 0 then
        leadCarriageForwardOrientation = leadCarriage.orientation
    elseif lastCarriageSpeed < 0 then
        leadCarriageForwardOrientation = Utils.BoundFloatValueWithinRange(leadCarriage.orientation + 0.5, 0, 1)
    else
        error("TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTargetStation() doesn't support 0 speed train\ntrain id: " .. train.id)
    end
    local leadCarriageEdgePositionOffset = Utils.RotatePositionAround0(leadCarriageForwardOrientation, {x = 0, y = 0 - TrainManagerFuncs.GetCarriageJointDistance(leadCarriage.name)})
    local firstRailLeadCarriageUsedPosition = Utils.ApplyOffsetToPosition(leadCarriage.position, leadCarriageEdgePositionOffset)
    local firstRail = trainPath.rails[trainPath.current]
    local firstRailFarEndPosition = TrainManagerFuncs.GetRailFarEndPosition(firstRail, leadCarriageForwardOrientation)
    local distanceRemainingOnRail = Utils.GetDistance(firstRailLeadCarriageUsedPosition, firstRailFarEndPosition)
    if firstRail.type == "curved-rail" then
        distanceRemainingOnRail = distanceRemainingOnRail * 1.0663824640154573798004974128959 -- Rough conversion for the straight line distance (7.3539105243401) to curved arc distance (7.842081225095).
    end
    distance = distance - distanceRemainingOnRail

    -- Add the joint distance to the result to get the center position of the carriage.
    local distanceForCarriageCenter = distance + TrainManagerFuncs.GetCarriageJointDistance(leadCarriage.name)

    return distanceForCarriageCenter
end

---@param railEntity LuaEntity
---@param forwardsOrientation RealOrientation
---@return Position
TrainManagerFuncs.GetRailFarEndPosition = function(railEntity, forwardsOrientation)
    local railFarEndPosition
    if railEntity.type == "straight-rail" then
        railFarEndPosition = Utils.ApplyOffsetToPosition(railEntity.position, Utils.RotatePositionAround0(forwardsOrientation, {x = 0, y = -1}))
    elseif railEntity.type == "curved-rail" then
        -- Curved end offset position based on that a diagonal straight rail is 2 long and this sets where the curved end points must be.
        local directionDetails = {
            [defines.direction.north] = {
                straightEndOffset = {x = 1, y = 4},
                straightEndOrientation = 0.5,
                curvedEndOffset = {x = -1.8, y = -2.8},
                curvedEndOrientation = 0.875
            },
            [defines.direction.northeast] = {
                straightEndOffset = {x = -1, y = 4},
                straightEndOrientation = 0.5,
                curvedEndOffset = {x = 1.8, y = -2.8},
                curvedEndOrientation = 0.125
            },
            [defines.direction.east] = {
                straightEndOffset = {x = -4, y = 1},
                straightEndOrientation = 0.75,
                curvedEndOffset = {x = 2.8, y = -1.8},
                curvedEndOrientation = 0.125
            },
            [defines.direction.southeast] = {
                straightEndOffset = {x = -4, y = -1},
                straightEndOrientation = 0.75,
                curvedEndOffset = {x = 2.8, y = 1.8},
                curvedEndOrientation = 0.375
            },
            [defines.direction.south] = {
                straightEndOffset = {x = -1, y = -4},
                straightEndOrientation = 1,
                curvedEndOffset = {x = 1.8, y = 2.8},
                curvedEndOrientation = 0.375
            },
            [defines.direction.southwest] = {
                straightEndOffset = {x = 1, y = -4},
                straightEndOrientation = 0,
                curvedEndOffset = {x = -1.8, y = 2.8},
                curvedEndOrientation = 0.625
            },
            [defines.direction.west] = {
                straightEndOffset = {x = 4, y = -1},
                straightEndOrientation = 0.25,
                curvedEndOffset = {x = -2.8, y = 1.8},
                curvedEndOrientation = 0.625
            },
            [defines.direction.northwest] = {
                straightEndOffset = {x = 4, y = 1},
                straightEndOrientation = 0.25,
                curvedEndOffset = {x = -2.8, y = -1.8},
                curvedEndOrientation = 0.875
            }
        }
        local endoffset
        local thisTrackDirectionDetails = directionDetails[railEntity.direction]
        -- Rails specifically have 0 or 1 to avoid having to check for 0/1 wrapping. As the carriage on a specific curve has a very limited orientation range.
        if math.abs(forwardsOrientation - thisTrackDirectionDetails.straightEndOrientation) < math.abs(forwardsOrientation - thisTrackDirectionDetails.curvedEndOrientation) then
            -- Closer aligned to straight orientation.
            endoffset = thisTrackDirectionDetails.straightEndOffset
        else
            -- Closer aligned to curved orientation.
            endoffset = thisTrackDirectionDetails.curvedEndOffset
        end

        -- Mark on map end of rail locations for debugging.
        --rendering.draw_circle {color = {0, 0, 1, 1}, radius = 0.1, filled = true, target = railEntity, surface = railEntity.surface}
        --rendering.draw_circle {color = {0, 1, 0, 1}, radius = 0.1, filled = true, target = Utils.ApplyOffsetToPosition(railEntity.position, thisTrackDirectionDetails.straightEndOffset), surface = railEntity.surface}
        --rendering.draw_circle {color = {1, 0, 0, 1}, radius = 0.1, filled = true, target = Utils.ApplyOffsetToPosition(railEntity.position, thisTrackDirectionDetails.curvedEndOffset), surface = railEntity.surface}

        railFarEndPosition = Utils.ApplyOffsetToPosition(railEntity.position, endoffset)
    else
        error("not valid rail type: " .. railEntity.type)
    end

    return railFarEndPosition
end

---@param railEntityType string @Prototype name.
---@return double
TrainManagerFuncs.GetRailEntityLength = function(railEntityType)
    if railEntityType == "straight-rail" then
        return 2
    elseif railEntityType == "curved-rail" then
        return 7.842081225095
    else
        error("not valid rail type: " .. railEntityType)
    end
end

---@param undergroundTrain LuaTrain
---@param position Position
TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition = function(undergroundTrain, position)
    undergroundTrain.schedule = {
        current = 1,
        records = {
            {
                rail = undergroundTrain.front_stock.surface.find_entity("straight-rail", position)
            }
        }
    }
end

---@param trainOrientation RealOrientation
---@param lastCarriageEntityName LuaEntity
---@param nextCarriageEntityName LuaEntity
---@param extraDistance double
---@return Position
TrainManagerFuncs.GetNextCarriagePlacementOffset = function(trainOrientation, lastCarriageEntityName, nextCarriageEntityName, extraDistance)
    extraDistance = extraDistance or 0
    local carriagesDistance = Common.GetCarriagePlacementDistance(lastCarriageEntityName) + Common.GetCarriagePlacementDistance(nextCarriageEntityName)
    return Utils.RotatePositionAround0(trainOrientation, {x = 0, y = carriagesDistance + extraDistance})
end

---@param trainOrientation RealOrientation
---@param lastCarriageEntity LuaEntity
---@param nextCarriageEntityName string
---@return Position
TrainManagerFuncs.GetNextCarriagePlacementPosition = function(trainOrientation, lastCarriageEntity, nextCarriageEntityName)
    local carriagesDistance = Common.GetCarriagePlacementDistance(lastCarriageEntity.name) + Common.GetCarriagePlacementDistance(nextCarriageEntityName)
    local nextCarriageOffset = Utils.RotatePositionAround0(trainOrientation, {x = 0, y = carriagesDistance})
    return Utils.ApplyOffsetToPosition(lastCarriageEntity.position, nextCarriageOffset)
end

---@param carriageEntityName string
---@return double
TrainManagerFuncs.GetCarriageJointDistance = function(carriageEntityName)
    -- For now we assume all unknown carriages have a joint of 4 as we can't get the joint distance via API. Can hard code custom values in future if needed.
    if carriageEntityName == "test" then
        return 0 -- Placeholder to stop syntax warnings on function variable. Will be needed when we support mods with custom train lengths.
    else
        return 2 -- Half of vanilla carriages 4 joint distance.
    end
end

---@param undergroundTrain LuaTrain
---@param distance double
---@return Position
TrainManagerFuncs.GetForwardPositionFromCurrentForDistance = function(undergroundTrain, distance)
    -- Applies the target distance to the train's leading carriage for the train direction on a straight track.
    local leadCarriage
    local undergroundTrainSpeed = undergroundTrain.speed
    if undergroundTrainSpeed > 0 then
        leadCarriage = undergroundTrain.front_stock
    elseif undergroundTrainSpeed < 0 then
        leadCarriage = undergroundTrain.back_stock
    else
        error("TrainManagerFuncs.GetForwardPositionFromCurrentForDistance() doesn't support 0 speed underground train.\nundergroundTrain id: " .. undergroundTrain.id)
    end
    local undergroundTrainOrientation
    if leadCarriage.speed > 0 then
        undergroundTrainOrientation = leadCarriage.orientation
    elseif leadCarriage.speed < 0 then
        undergroundTrainOrientation = Utils.BoundFloatValueWithinRange(leadCarriage.orientation + 0.5, 0, 1)
    else
        error("TrainManagerFuncs.GetForwardPositionFromCurrentForDistance() doesn't support 0 speed underground train.\nundergroundTrain id: " .. undergroundTrain.id)
    end
    return Utils.ApplyOffsetToPosition(
        leadCarriage.position,
        Utils.RotatePositionAround0(
            undergroundTrainOrientation,
            {
                x = 0,
                y = 0 - distance
            }
        )
    )
end

---@param train LuaTrain
---@param expectedOrientation RealOrientation
---@param oldFrontCarriageUnitNumber UnitNumber
---@param oldBackCarriageUnitNumber UnitNumber
---@param trainWasFacingForwards boolean
---@return boolean
TrainManagerFuncs.TrainStillFacingSameDirectionAfterCarriageChange = function(train, expectedOrientation, oldFrontCarriageUnitNumber, oldBackCarriageUnitNumber, trainWasFacingForwards)
    -- Checks if a train is still facing in the expected direction (front and back stock). For use after changing a trains composition as this regenerates these attributes. Works with 0 speed trains as doesn't require or consider train speed +/-.

    -- Check trains make up depending on its length.
    if #train.carriages == 1 then
        -- A single carriage train will have the same carriage referenced by front and back stock attributes. So just use its orientation to decide if its facing the expected direction.
        if train.front_stock.orientation == expectedOrientation then
            return trainWasFacingForwards
        else
            return not trainWasFacingForwards
        end
    else
        -- With >= 2 carriages we can check if either the trains front or back stock attributes have renamed the same (train direction not rotated).
        if train.front_stock.unit_number == oldFrontCarriageUnitNumber or train.back_stock.unit_number == oldBackCarriageUnitNumber then
            -- One end changed as was a pushing loco, but other is the same, so train still same direction.
            return true
        else
            -- Neither are the same so the train must have reversed direction.
            return false
        end
    end
end

---@param functionRef function
TrainManagerFuncs.RunFunctionAndCatchErrors = function(functionRef, ...)
    -- Doesn't support returning values to caller as can't do this for unknown argument count.
    -- Uses a random number in file name to try and avoid overlapping errors in real game. If save is reloaded and nothing different done by player will be the same result however.

    -- If its not a debug release or the debug adapter with instrument mode (control hook) is active just end as no need to log to file anything. As the logging write out is slow in debugger. Just runs the function normally and return any results.
    if not global.debugRelease or (__DebugAdapter ~= nil and __DebugAdapter.instrument) then
        functionRef(...)
        return
    end

    local errorHandlerFunc = function(errorMessage)
        local errorObject = {message = errorMessage, stacktrace = debug.traceback()}
        return errorObject
    end

    local args = {...}

    -- Is in debug mode so catch any errors and log state data.
    -- Only produces correct stack traces in regular Factorio, not in debugger as this adds extra lines to the stacktrace.
    local success, errorObject = xpcall(functionRef, errorHandlerFunc, ...)
    if success then
        return
    else
        local logFileName = "railway_tunnel error details - " .. tostring(math.random() .. ".log")
        local contents = ""
        local AddLineToContents = function(text)
            contents = contents .. text .. "\r\n"
        end
        AddLineToContents("Error: " .. errorObject.message)

        -- Tidy the stacktrace up by removing the indented (\9) lines that relate to this xpcall function. Makes the stack trace read more naturally ignoring this function.
        local newStackTrace, lineCount, rawxpcallLine = "stacktrace:\n", 1, nil
        for line in string.gmatch(errorObject.stacktrace, "(\9[^\n]+)\n") do
            local skipLine = false
            if lineCount == 1 then
                skipLine = true
            elseif string.find(line, "(...tail calls...)") then
                skipLine = true
            elseif string.find(line, "rawxpcall") or string.find(line, "xpcall") then
                skipLine = true
                rawxpcallLine = lineCount + 1
            elseif lineCount == rawxpcallLine then
                skipLine = true
            end
            if not skipLine then
                newStackTrace = newStackTrace .. line .. "\n"
            end
            lineCount = lineCount + 1
        end
        AddLineToContents(newStackTrace)

        AddLineToContents("")
        AddLineToContents("Function call arguments:")
        for index, arg in pairs(args) do
            AddLineToContents(Utils.TableContentsToJSON(TrainManagerFuncs.PrintThingsDetails(arg), index))
        end

        game.write_file(logFileName, contents, false) -- Wipe file if it exists from before.
        error('Debug release: see log file in Factorio Data\'s "script-output" folder.\n' .. errorObject.message .. "\n" .. newStackTrace, 0)
    end
end

---@param thing any
---@param _tablesLogged table
---@return table
TrainManagerFuncs.PrintThingsDetails = function(thing, _tablesLogged)
    _tablesLogged = _tablesLogged or {} -- Internal variable passed when self referencing to avoid loops.

    -- Simple values just get returned.
    if type(thing) ~= "table" then
        return tostring(thing)
    end

    -- Handle specific Factorio Lua objects
    if thing.object_name ~= nil then
        -- Invalid things are returned in safe way.
        if not thing.valid then
            return {
                object_name = thing.object_name,
                valid = thing.valid
            }
        end

        if thing.object_name == "LuaEntity" then
            local entityDetails = {
                object_name = thing.object_name,
                valid = thing.valid,
                type = thing.type,
                name = thing.name,
                unit_number = thing.unit_number,
                position = thing.position,
                direction = thing.direction,
                orientation = thing.orientation,
                health = thing.health,
                color = thing.color,
                speed = thing.speed,
                backer_name = thing.backer_name
            }
            if RollingStockTypes[thing.type] ~= nil then
                entityDetails.trainId = thing.train.id
            end

            return entityDetails
        elseif thing.object_name == "LuaTrain" then
            local carriages = {}
            for i, carriage in pairs(thing.carriages) do
                carriages[i] = TrainManagerFuncs.PrintThingsDetails(carriage, _tablesLogged)
            end
            return {
                object_name = thing.object_name,
                valid = thing.valid,
                id = thing.id,
                state = thing.state,
                schedule = thing.schedule,
                manual_mode = thing.manual_mode,
                has_path = thing.has_path,
                speed = thing.speed,
                signal = TrainManagerFuncs.PrintThingsDetails(thing.signal, _tablesLogged),
                station = TrainManagerFuncs.PrintThingsDetails(thing.station, _tablesLogged),
                carriages = carriages
            }
        else
            -- Other Lua object.
            return {
                object_name = thing.object_name,
                valid = thing.valid
            }
        end
    end

    -- Is just a general table so return all its keys.
    local returnedSafeTable = {}
    _tablesLogged[thing] = "logged"
    for key, value in pairs(thing) do
        if _tablesLogged[key] ~= nil or _tablesLogged[value] ~= nil then
            local valueIdText
            if value.id ~= nil then
                valueIdText = "ID: " .. value.id
            else
                valueIdText = "no ID"
            end
            returnedSafeTable[key] = "circular table reference - " .. valueIdText
        else
            returnedSafeTable[key] = TrainManagerFuncs.PrintThingsDetails(value, _tablesLogged)
        end
    end
    return returnedSafeTable
end

TrainManagerFuncs.GetLeadingLocoAndBurner = function(train, trainFacingForwards)
    local leadLoco
    if trainFacingForwards then
        leadLoco = train.locomotives.front_movers[1]
    else
        leadLoco = train.locomotives.back_movers[1]
    end
    return leadLoco, leadLoco.burner
end

TrainManagerFuncs.AddDriverCharacterToCarriage = function(carriage)
    local driverCharacter = carriage.surface.create_entity {name = "railway_tunnel-dummy_character", position = carriage.position, force = carriage.force}
    carriage.set_driver(driverCharacter)
    return driverCharacter
end

return TrainManagerFuncs
