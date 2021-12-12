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

-- Light - Dummy train keeps the train stop reservation as it has near 0 power and so while actively moving, it will never actaully move any distance.
-- OVERHAUL - possible alternative is to add a carraige to the cloned train that has max friction force and weight. This should mean the real train can replace the dummy train. This would mean that the leaving train uses fuel for the duration of the tunnel trip and so has to have this monitored and refilled to get it out of the tunnel :S
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

---@param train LuaTrain
---@param targetEntity LuaEntity
---@param trainGoingForwards boolean
---@return double
TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTarget = function(train, targetEntity, trainGoingForwards)
    -- This measures to the nearest edge of the target's rail, so doesn't include any of the target's rail's length. The targetEntity can be a rail itself or an entity connected to a rail.

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

    -- Measure the distance from the train to the target entity. Ignores trains exact position and just deals with the tracks. The first rail isn't included here as we get the remaining part of the rail's distance later in function.
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
    local leadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(train, trainGoingForwards)
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
    local firstRailLeadCarriageUsedPosition = Utils.ApplyOffsetToPosition(leadCarriage.position, leadCarriageEdgePositionOffset)
    local firstRail = trainPathRails[1]
    local firstRailFarEndPosition = TrainManagerFuncs.GetRailFarEndPosition(firstRail, leadCarriageForwardOrientation)
    local distanceRemainingOnRail = Utils.GetDistance(firstRailLeadCarriageUsedPosition, firstRailFarEndPosition)
    if firstRail.type == "curved-rail" then
        distanceRemainingOnRail = distanceRemainingOnRail * 1.0663824640154573798004974128959 -- Rough conversion for the straight line distance (7.3539105243401) to curved arc distance (7.842081225095).
    end
    distance = distance + distanceRemainingOnRail

    -- Add the joint distance to the result to get the center position of the carriage.
    local distanceForCarriageCenter = distance + TrainManagerFuncs.GetCarriageJointDistance(leadCarriage.name)

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
        error("TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTarget() doesn't support 0 speed train\ntrain id: " .. train.id)
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

return TrainManagerFuncs
