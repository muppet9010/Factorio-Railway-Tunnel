--[[
    Random utility functions that don't fit in to any other category.
--]]
local Utils = {}
local factorioUtil = require("__core__/lualib/util")
Utils.DeepCopy = factorioUtil.table.deepcopy ---@type fun(object:table):table
Utils.TableMerge = factorioUtil.merge ---@type fun(tables:table[]):table @Takes an array of tables and returns a new table with copies of their contents

---@param entity1 LuaEntity
---@param entity2 LuaEntity
Utils.Are2EntitiesTheSame = function(entity1, entity2)
    -- Uses unit number if both support it, otherwise has to compare a lot of attributes to try and work out if they are the same base entity. Assumes the entity won't ever move or change.
    if not entity1.valid or not entity2.valid then
        return false
    end
    if entity1.unit_number ~= nil and entity2.unit_number ~= nil then
        if entity1.unit_number == entity2.unit_number then
            return true
        else
            return false
        end
    else
        if entity1.type == entity2.type and entity1.name == entity2.name and entity1.surface.index == entity2.surface.index and entity1.position.x == entity2.position.x and entity1.position.y == entity2.position.y and entity1.force.index == entity2.force.index and entity1.health == entity2.health then
            return true
        else
            return false
        end
    end
end

---@param pos1 Position
---@param pos2 Position
---@return boolean
Utils.ArePositionsTheSame = function(pos1, pos2)
    if (pos1.x or pos1[1]) == (pos2.x or pos2[1]) and (pos1.y or pos1[2]) == (pos2.y or pos2[2]) then
        return true
    else
        return false
    end
end

---@param surface LuaSurface
---@param positionedBoundingBox BoundingBox
---@param collisionBoxOnlyEntities boolean
---@param onlyForceAffected LuaForce|null
---@param onlyDestructible boolean
---@param onlyKillable boolean
---@param entitiesExcluded LuaEntity[]|null
---@return table<int, LuaEntity>
Utils.ReturnAllObjectsInArea = function(surface, positionedBoundingBox, collisionBoxOnlyEntities, onlyForceAffected, onlyDestructible, onlyKillable, entitiesExcluded)
    -- Expand force affected to support range of opt in or opt out forces.
    local entitiesFound, filteredEntitiesFound = surface.find_entities(positionedBoundingBox), {}
    for k, entity in pairs(entitiesFound) do
        if entity.valid then
            local entityExcluded = false
            if entitiesExcluded ~= nil and #entitiesExcluded > 0 then
                for _, excludedEntity in pairs(entitiesExcluded) do
                    if Utils.Are2EntitiesTheSame(entity, excludedEntity) then
                        entityExcluded = true
                        break
                    end
                end
            end
            if not entityExcluded then
                if (onlyForceAffected == nil) or (entity.force == onlyForceAffected) then
                    if (not onlyDestructible) or (entity.destructible) then
                        if (not onlyKillable) or (entity.health ~= nil) then
                            if (not collisionBoxOnlyEntities) or (Utils.IsCollisionBoxPopulated(entity.prototype.collision_box)) then
                                table.insert(filteredEntitiesFound, entity)
                            end
                        end
                    end
                end
            end
        end
    end
    return filteredEntitiesFound
end

---@param surface LuaSurface
---@param positionedBoundingBox BoundingBox
---@param killerEntity LuaEntity|null
---@param collisionBoxOnlyEntities boolean
---@param onlyForceAffected boolean
---@param entitiesExcluded LuaEntity[]|null
---@param killerForce LuaForce|null
Utils.KillAllKillableObjectsInArea = function(surface, positionedBoundingBox, killerEntity, collisionBoxOnlyEntities, onlyForceAffected, entitiesExcluded, killerForce)
    if killerForce == nil then
        killerForce = "neutral"
    end
    for _, entity in pairs(Utils.ReturnAllObjectsInArea(surface, positionedBoundingBox, collisionBoxOnlyEntities, onlyForceAffected, true, true, entitiesExcluded)) do
        if killerEntity ~= nil then
            entity.die(killerForce, killerEntity)
        else
            entity.die(killerForce)
        end
    end
end

---@param surface LuaSurface
---@param positionedBoundingBox BoundingBox
---@param killerEntity LuaEntity|null
---@param onlyForceAffected boolean
---@param entitiesExcluded LuaEntity[]|null
---@param killerForce LuaForce|null
Utils.KillAllObjectsInArea = function(surface, positionedBoundingBox, killerEntity, onlyForceAffected, entitiesExcluded, killerForce)
    if killerForce == nil then
        killerForce = "neutral"
    end
    for k, entity in pairs(Utils.ReturnAllObjectsInArea(surface, positionedBoundingBox, false, onlyForceAffected, false, false, entitiesExcluded)) do
        if entity.destructible then
            if killerEntity ~= nil then
                entity.die(killerForce, killerEntity)
            else
                entity.die(killerForce)
            end
        else
            entity.destroy({dp_cliff_correction = true, raise_destroy = true})
        end
    end
end

---@param surface LuaSurface
---@param positionedBoundingBox BoundingBox
---@param collisionBoxOnlyEntities boolean
---@param onlyForceAffected boolean
---@param entitiesExcluded LuaEntity[]|null
Utils.DestroyAllKillableObjectsInArea = function(surface, positionedBoundingBox, collisionBoxOnlyEntities, onlyForceAffected, entitiesExcluded)
    for k, entity in pairs(Utils.ReturnAllObjectsInArea(surface, positionedBoundingBox, collisionBoxOnlyEntities, onlyForceAffected, true, true, entitiesExcluded)) do
        entity.destroy({dp_cliff_correction = true, raise_destroy = true})
    end
end

---@param surface LuaSurface
---@param positionedBoundingBox BoundingBox
---@param onlyForceAffected boolean
---@param entitiesExcluded LuaEntity[]|null
Utils.DestroyAllObjectsInArea = function(surface, positionedBoundingBox, onlyForceAffected, entitiesExcluded)
    for k, entity in pairs(Utils.ReturnAllObjectsInArea(surface, positionedBoundingBox, false, onlyForceAffected, false, false, entitiesExcluded)) do
        entity.destroy({dp_cliff_correction = true, raise_destroy = true})
    end
end

---@param thing table
---@return boolean
Utils.IsTableValidPosition = function(thing)
    if thing.x ~= nil and thing.y ~= nil then
        if type(thing.x) == "number" and type(thing.y) == "number" then
            return true
        else
            return false
        end
    end
    if #thing ~= 2 then
        return false
    end
    if type(thing[1]) == "number" and type(thing[2]) == "number" then
        return true
    else
        return false
    end
end

---@param thing table
---@return Position
Utils.TableToProperPosition = function(thing)
    if thing.x ~= nil and thing.y ~= nil then
        if type(thing.x) == "number" and type(thing.y) == "number" then
            return thing
        else
            return nil
        end
    end
    if #thing ~= 2 then
        return nil
    end
    if type(thing[1]) == "number" and type(thing[2]) == "number" then
        return {x = thing[1], y = thing[2]}
    else
        return nil
    end
end

---@param thing table
---@return boolean
Utils.IsTableValidBoundingBox = function(thing)
    if thing.left_top ~= nil and thing.right_bottom ~= nil then
        if Utils.IsTableValidPosition(thing.left_top) and Utils.IsTableValidPosition(thing.right_bottom) then
            return true
        else
            return false
        end
    end
    if #thing ~= 2 then
        return false
    end
    if Utils.IsTableValidPosition(thing[1]) and Utils.IsTableValidPosition(thing[2]) then
        return true
    else
        return false
    end
end

---@param thing table
---@return BoundingBox
Utils.TableToProperBoundingBox = function(thing)
    if not Utils.IsTableValidBoundingBox(thing) then
        return nil
    elseif thing.left_top ~= nil and thing.right_bottom ~= nil then
        return {left_top = Utils.TableToProperPosition(thing.left_top), right_bottom = Utils.TableToProperPosition(thing.right_bottom)}
    else
        return {left_top = Utils.TableToProperPosition(thing[1]), right_bottom = Utils.TableToProperPosition(thing[2])}
    end
end

---@param centrePos Position
---@param boundingBox BoundingBox
---@param orientation double
---@return BoundingBox
Utils.ApplyBoundingBoxToPosition = function(centrePos, boundingBox, orientation)
    centrePos = Utils.TableToProperPosition(centrePos)
    boundingBox = Utils.TableToProperBoundingBox(boundingBox)
    if orientation == nil or orientation == 0 or orientation == 1 then
        return {
            left_top = {
                x = centrePos.x + boundingBox.left_top.x,
                y = centrePos.y + boundingBox.left_top.y
            },
            right_bottom = {
                x = centrePos.x + boundingBox.right_bottom.x,
                y = centrePos.y + boundingBox.right_bottom.y
            }
        }
    elseif orientation == 0.25 or orientation == 0.5 or orientation == 0.75 then
        local rotatedPoint1 = Utils.RotatePositionAround0(orientation, boundingBox.left_top)
        local rotatedPoint2 = Utils.RotatePositionAround0(orientation, boundingBox.right_bottom)
        local rotatedBoundingBox = Utils.CalculateBoundingBoxFrom2Points(rotatedPoint1, rotatedPoint2)
        return {
            left_top = {
                x = centrePos.x + rotatedBoundingBox.left_top.x,
                y = centrePos.y + rotatedBoundingBox.left_top.y
            },
            right_bottom = {
                x = centrePos.x + rotatedBoundingBox.right_bottom.x,
                y = centrePos.y + rotatedBoundingBox.right_bottom.y
            }
        }
    end
end

---@param pos Position
---@param numDecimalPlaces uint
---@return Position
Utils.RoundPosition = function(pos, numDecimalPlaces)
    return {x = Utils.RoundNumberToDecimalPlaces(pos.x, numDecimalPlaces), y = Utils.RoundNumberToDecimalPlaces(pos.y, numDecimalPlaces)}
end

---@param pos Position
---@return ChunkPosition
Utils.GetChunkPositionForTilePosition = function(pos)
    return {x = math.floor(pos.x / 32), y = math.floor(pos.y / 32)}
end

---@param chunkPos ChunkPosition
---@return Position
Utils.GetLeftTopTilePositionForChunkPosition = function(chunkPos)
    return {x = chunkPos.x * 32, y = chunkPos.y * 32}
end

---@param orientation double
---@param position Position
---@return Position
Utils.RotatePositionAround0 = function(orientation, position)
    local deg = orientation * 360
    local rad = math.rad(deg)
    local cosValue = math.cos(rad)
    local sinValue = math.sin(rad)
    local rotatedX = (position.x * cosValue) - (position.y * sinValue)
    local rotatedY = (position.x * sinValue) + (position.y * cosValue)
    return {x = rotatedX, y = rotatedY}
end

---@param point1 Position
---@param point2 Position
---@return BoundingBox
Utils.CalculateBoundingBoxFrom2Points = function(point1, point2)
    local minX, maxX, minY, maxY = nil, nil, nil, nil
    if minX == nil or point1.x < minX then
        minX = point1.x
    end
    if maxX == nil or point1.x > maxX then
        maxX = point1.x
    end
    if minY == nil or point1.y < minY then
        minY = point1.y
    end
    if maxY == nil or point1.y > maxY then
        maxY = point1.y
    end
    if minX == nil or point2.x < minX then
        minX = point2.x
    end
    if maxX == nil or point2.x > maxX then
        maxX = point2.x
    end
    if minY == nil or point2.y < minY then
        minY = point2.y
    end
    if maxY == nil or point2.y > maxY then
        maxY = point2.y
    end
    return {left_top = {x = minX, y = minY}, right_bottom = {x = maxX, y = maxY}}
end

---@param listOfBoundingBoxs BoundingBox[]
---@return BoundingBox
Utils.CalculateBoundingBoxToIncludeAllBoundingBoxs = function(listOfBoundingBoxs)
    local minX, maxX, minY, maxY = nil, nil, nil, nil
    for _, boundingBox in pairs(listOfBoundingBoxs) do
        for _, point in pairs({boundingBox.left_top, boundingBox.right_bottom}) do
            if minX == nil or point.x < minX then
                minX = point.x
            end
            if maxX == nil or point.x > maxX then
                maxX = point.x
            end
            if minY == nil or point.y < minY then
                minY = point.y
            end
            if maxY == nil or point.y > maxY then
                maxY = point.y
            end
        end
    end
    return {left_top = {x = minX, y = minY}, right_bottom = {x = maxX, y = maxY}}
end

---@param position Position
---@param offset Position
---@return Position
Utils.ApplyOffsetToPosition = function(position, offset)
    return {
        x = position.x + (offset.x or 0),
        y = position.y + (offset.y or 0)
    }
end

Utils.GrowBoundingBox = function(boundingBox, growthX, growthY)
    return {
        left_top = {
            x = boundingBox.left_top.x - growthX,
            y = boundingBox.left_top.y - growthY
        },
        right_bottom = {
            x = boundingBox.right_bottom.x + growthX,
            y = boundingBox.right_bottom.y + growthY
        }
    }
end

Utils.IsCollisionBoxPopulated = function(collisionBox)
    if collisionBox == nil then
        return false
    end
    if collisionBox.left_top.x ~= 0 and collisionBox.left_top.y ~= 0 and collisionBox.right_bottom.x ~= 0 and collisionBox.right_bottom.y ~= 0 then
        return true
    else
        return false
    end
end

Utils.LogisticEquation = function(index, height, steepness)
    return height / (1 + math.exp(steepness * (index - 0)))
end

Utils.ExponentialDecayEquation = function(index, multiplier, scale)
    return multiplier * math.exp(-index * scale)
end

Utils.RoundNumberToDecimalPlaces = function(num, numDecimalPlaces)
    local result
    if numDecimalPlaces ~= nil and numDecimalPlaces > 0 then
        local mult = 10 ^ numDecimalPlaces
        result = math.floor(num * mult + 0.5) / mult
    else
        result = math.floor(num + 0.5)
    end
    if result == "nan" then
        result = 0
    end
    return result
end

---@param value int
---@param min int
---@param max int
---@return int
Utils.LoopIntValueWithinRange = function(value, min, max)
    -- This steps through the ints with min and max being seperatee steps.
    if value > max then
        return min - (max - value) - 1
    elseif value < min then
        return max + (value - min) + 1
    else
        return value
    end
end

---@param value double
---@param min double
---@param max double
---@return double
Utils.BoundFloatValueWithinRange = function(value, min, max)
    -- This treats the min and max values as equal when bounding: max - 0.1, max/min, min + 0.1. Depending on starting input value you get either the min or max value at the border.
    if value > max then
        return min + (value - max)
    elseif value < min then
        return max - (value - min)
    else
        return value
    end
end

---@param value double
---@param minInclusive double
---@param maxExclusive double
---@return double
Utils.BoundFloatValueWithinRangeMaxExclusive = function(value, minInclusive, maxExclusive)
    -- maxExclusive will give the minInclusive value. So maxExclsuive can never be returned.
    if value >= maxExclusive then
        return minInclusive + (value - maxExclusive)
    elseif value < minInclusive then
        return maxExclusive - (value - minInclusive)
    else
        return value
    end
end

Utils.HandleFloatNumberAsChancedValue = function(value)
    local intValue = math.floor(value)
    local partialValue = value - intValue
    local chancedValue = intValue
    if partialValue ~= 0 then
        local rand = math.random()
        if rand >= partialValue then
            chancedValue = chancedValue + 1
        end
    end
    return chancedValue
end

Utils.FuzzyCompareDoubles = function(num1, logic, num2)
    -- This doesn't guarentee correct on some of the edge cases, but is as close as possible assuming that 1/256 is the variance for the same number (Bilka, Dev on Discord)
    local numDif = num1 - num2
    local variance = 1 / 256
    if logic == "=" then
        if numDif < variance and numDif > -variance then
            return true
        else
            return false
        end
    elseif logic == "!=" then
        if numDif < variance and numDif > -variance then
            return false
        else
            return true
        end
    elseif logic == ">" then
        if numDif > variance then
            return true
        else
            return false
        end
    elseif logic == ">=" then
        if numDif > -variance then
            return true
        else
            return false
        end
    elseif logic == "<" then
        if numDif < -variance then
            return true
        else
            return false
        end
    elseif logic == "<=" then
        if numDif < variance then
            return true
        else
            return false
        end
    end
end

---@param table table
---@return boolean
Utils.IsTableEmpty = function(table)
    if table == nil or next(table) == nil then
        return true
    else
        return false
    end
end

Utils.GetTableNonNilLength = function(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

---@param table table
---@return StringOrNumber
Utils.GetFirstTableKey = function(table)
    return next(table)
end

---@param table table
---@return any
Utils.GetFirstTableValue = function(table)
    return table[next(table)]
end

---@param table table
---@return uint
Utils.GetMaxKey = function(table)
    local max_key = 0
    for k in pairs(table) do
        if k > max_key then
            max_key = k
        end
    end
    return max_key
end

Utils.GetTableValueByIndexCount = function(table, indexCount)
    local count = 0
    for _, v in pairs(table) do
        count = count + 1
        if count == indexCount then
            return v
        end
    end
end

Utils.CalculateBoundingBoxFromPositionAndRange = function(position, range)
    return {
        left_top = {
            x = position.x - range,
            y = position.y - range
        },
        right_bottom = {
            x = position.x + range,
            y = position.y + range
        }
    }
end

Utils.CalculateTilesUnderPositionedBoundingBox = function(positionedBoundingBox)
    local tiles = {}
    for x = positionedBoundingBox.left_top.x, positionedBoundingBox.right_bottom.x do
        for y = positionedBoundingBox.left_top.y, positionedBoundingBox.right_bottom.y do
            table.insert(tiles, {x = math.floor(x), y = math.floor(y)})
        end
    end
    return tiles
end

---@param pos1 Position
---@param pos2 Position
---@return number
Utils.GetDistance = function(pos1, pos2)
    -- Don't do any valid checks as called so frequently, big UPS wastage.
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    return math.sqrt(dx * dx + dy * dy)
end

---@param pos1 Position
---@param pos2 Position
---@param axis Axis
---@return number
Utils.GetDistanceSingleAxis = function(pos1, pos2, axis)
    -- Don't do any valid checks as called so frequently, big UPS wastage.
    return math.abs(pos1[axis] - pos2[axis])
end

---@param newPosition Position
---@param basePosition Position
---@return Position
Utils.GetOffsetForPositionFromPosition = function(newPosition, basePosition)
    -- Returns the offset for the first position in relation to the second position.
    return {x = newPosition.x - basePosition.x, y = newPosition.y - basePosition.y}
end

---@param position Position
---@param boundingBox BoundingBox
---@param safeTiling boolean|null @If enabled the boundingbox can be tiled without risk of an entity on the border being in 2 result sets, i.e. for use on each chunk.
---@return boolean
Utils.IsPositionInBoundingBox = function(position, boundingBox, safeTiling)
    if safeTiling == nil or not safeTiling then
        if position.x >= boundingBox.left_top.x and position.x <= boundingBox.right_bottom.x and position.y >= boundingBox.left_top.y and position.y <= boundingBox.right_bottom.y then
            return true
        else
            return false
        end
    else
        if position.x > boundingBox.left_top.x and position.x <= boundingBox.right_bottom.x and position.y > boundingBox.left_top.y and position.y <= boundingBox.right_bottom.y then
            return true
        else
            return false
        end
    end
end

Utils.GetEntityReturnedToInventoryName = function(entity)
    if entity.prototype.mineable_properties ~= nil and entity.prototype.mineable_properties.products ~= nil and #entity.prototype.mineable_properties.products > 0 then
        return entity.prototype.mineable_properties.products[1].name
    else
        return entity.name
    end
end

Utils.TableKeyToArray = function(aTable)
    local newArray = {}
    for key in pairs(aTable) do
        table.insert(newArray, key)
    end
    return newArray
end

Utils.TableKeyToCommaString = function(aTable)
    -- Doesn't support commas in values or nested tables. Really for logging.
    local newString = ""
    if Utils.IsTableEmpty(aTable) then
        return newString
    end
    for key in pairs(aTable) do
        if newString == "" then
            newString = key
        else
            newString = newString .. ", " .. tostring(key)
        end
    end
    return newString
end

Utils.TableValueToCommaString = function(aTable)
    -- Doesn't support commas in values or nested tables. Really for logging.
    local newString = ""
    if Utils.IsTableEmpty(aTable) then
        return newString
    end
    for _, value in pairs(aTable) do
        if newString == "" then
            newString = value
        else
            newString = newString .. ", " .. tostring(value)
        end
    end
    return newString
end

-- Stringify a table in to a JSON text string. Options to make it pretty printable.
---@param targetTable table
---@param name string|null @If provided will appear as a "name:JSONData" output.
---@param singleLineOutput boolean|null @If provided and true removes all lines and spacing from the output.
---@return string
Utils.TableContentsToJSON = function(targetTable, name, singleLineOutput)
    --
    singleLineOutput = singleLineOutput or false
    local tablesLogged = {}
    return Utils._TableContentsToJSON(targetTable, name, singleLineOutput, tablesLogged)
end
Utils._TableContentsToJSON = function(targetTable, name, singleLineOutput, tablesLogged, indent, stopTraversing)
    local newLineCharacter = "\r\n"
    indent = indent or 1
    local indentstring = string.rep(" ", (indent * 4))
    if singleLineOutput then
        newLineCharacter = ""
        indentstring = ""
    end
    tablesLogged[targetTable] = "logged"
    local table_contents = ""
    if Utils.GetTableNonNilLength(targetTable) > 0 then
        for k, v in pairs(targetTable) do
            local key, value
            if type(k) == "string" or type(k) == "number" or type(k) == "boolean" then -- keys are always strings
                key = '"' .. tostring(k) .. '"'
            elseif type(k) == "nil" then
                key = '"nil"'
            elseif type(k) == "table" then
                if stopTraversing == true then
                    key = '"CIRCULAR LOOP TABLE"'
                else
                    local subStopTraversing = nil
                    if tablesLogged[k] ~= nil then
                        subStopTraversing = true
                    end
                    key = "{" .. newLineCharacter .. Utils._TableContentsToJSON(k, name, singleLineOutput, tablesLogged, indent + 1, subStopTraversing) .. newLineCharacter .. indentstring .. "}"
                end
            elseif type(k) == "function" then
                key = '"' .. tostring(k) .. '"'
            else
                key = '"unhandled type: ' .. type(k) .. '"'
            end
            if type(v) == "string" then
                value = '"' .. tostring(v) .. '"'
            elseif type(v) == "number" or type(v) == "boolean" then
                value = tostring(v)
            elseif type(v) == "nil" then
                value = '"nil"'
            elseif type(v) == "table" then
                if stopTraversing == true then
                    value = '"CIRCULAR LOOP TABLE"'
                else
                    local subStopTraversing = nil
                    if tablesLogged[v] ~= nil then
                        subStopTraversing = true
                    end
                    value = "{" .. newLineCharacter .. Utils._TableContentsToJSON(v, name, singleLineOutput, tablesLogged, indent + 1, subStopTraversing) .. newLineCharacter .. indentstring .. "}"
                end
            elseif type(v) == "function" then
                value = '"' .. tostring(v) .. '"'
            else
                value = '"unhandled type: ' .. type(v) .. '"'
            end
            if table_contents ~= "" then
                table_contents = table_contents .. "," .. newLineCharacter
            end
            table_contents = table_contents .. indentstring .. tostring(key) .. ":" .. tostring(value)
        end
    else
        table_contents = indentstring .. ""
    end
    if indent == 1 then
        local resultString = ""
        if name ~= nil then
            resultString = '"' .. name .. '":'
        end
        resultString = resultString .. "{" .. newLineCharacter .. table_contents .. newLineCharacter .. "}"
        return resultString
    else
        return table_contents
    end
end

Utils.FormatPositionTableToString = function(positionTable)
    return positionTable.x .. "," .. positionTable.y
end

Utils.FormatSurfacePositionTableToString = function(surfaceId, positionTable)
    return surfaceId .. "_" .. positionTable.x .. "," .. positionTable.y
end

---@param theTable table
---@param value StringOrNumber
---@param returnMultipleResults boolean|null @Can return a single result (returnMultipleResults = false/nil) or a list of results (returnMultipleResults = true)
---@param isValueAList boolean|null @Can have innerValue as a string/number (isValueAList = false/nil) or as a list of strings/numbers (isValueAList = true)
---@return StringOrNumber[] @table of keys.
Utils.GetTableKeyWithValue = function(theTable, value, returnMultipleResults, isValueAList)
    local keysFound = {}
    for k, v in pairs(theTable) do
        if not isValueAList then
            if v == value then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        else
            if v == value then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        end
    end
    return keysFound
end

---@param theTable table
---@param innerKey StringOrNumber
---@param innerValue StringOrNumber
---@param returnMultipleResults boolean|null @Can return a single result (returnMultipleResults = false/nil) or a list of results (returnMultipleResults = true)
---@param isValueAList boolean|null @Can have innerValue as a string/number (isValueAList = false/nil) or as a list of strings/numbers (isValueAList = true)
---@return StringOrNumber[] @table of keys.
Utils.GetTableKeyWithInnerKeyValue = function(theTable, innerKey, innerValue, returnMultipleResults, isValueAList)
    local keysFound = {}
    for k, innerTable in pairs(theTable) do
        if not isValueAList then
            if innerTable[innerKey] ~= nil and innerTable[innerKey] == innerValue then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        else
            if innerTable[innerKey] ~= nil and innerTable[innerKey] == innerValue then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        end
    end
    return keysFound
end

---@param theTable table
---@param innerKey StringOrNumber
---@param innerValue StringOrNumber
---@param returnMultipleResults boolean|null @Can return a single result (returnMultipleResults = false/nil) or a list of results (returnMultipleResults = true)
---@param isValueAList boolean|null @Can have innerValue as a string/number (isValueAList = false/nil) or as a list of strings/numbers (isValueAList = true)
---@return table[] @table of values, which must be a table to have an inner key/value.
Utils.GetTableValueWithInnerKeyValue = function(theTable, innerKey, innerValue, returnMultipleResults, isValueAList)
    local valuesFound = {}
    for _, innerTable in pairs(theTable) do
        if not isValueAList then
            if innerTable[innerKey] ~= nil and innerTable[innerKey] == innerValue then
                if not returnMultipleResults then
                    return innerTable
                end
                table.insert(valuesFound, innerTable)
            end
        else
            for _, valueInList in pairs(innerValue) do
                if innerTable[innerKey] ~= nil and innerTable[innerKey] == valueInList then
                    if not returnMultipleResults then
                        return innerTable
                    end
                    table.insert(valuesFound, innerTable)
                end
            end
        end
    end
    return valuesFound
end

Utils.TableValuesToKey = function(tableWithValues)
    if tableWithValues == nil then
        return nil
    end
    local newTable = {}
    for _, value in pairs(tableWithValues) do
        newTable[value] = value
    end
    return newTable
end

Utils.TableInnerValueToKey = function(refTable, innerValueAttributeName)
    if refTable == nil then
        return nil
    end
    local newTable = {}
    for _, value in pairs(refTable) do
        newTable[value[innerValueAttributeName]] = value
    end
    return newTable
end

Utils.GetRandomFloatInRange = function(lower, upper)
    return lower + math.random() * (upper - lower)
end

Utils.WasCreativeModeInstantDeconstructionUsed = function(event)
    if event.instant_deconstruction ~= nil and event.instant_deconstruction == true then
        return true
    else
        return false
    end
end

--- Updates the 'chancePropertyName' named attribute of each entry in the referenced `dataSet` table to be proportional of a combined dataSet value of 1.
---@param dataSet table[] @The dataSet to be reviewed and updated.
---@param chancePropertyName string @The attribute name that has the chance value per dataSet entry.
---@param skipFillingEmptyChance boolean @If TRUE then total chance below 1 will not be scaled up, so that nil results can be had in random selection.
---@return table[] @Same object passed in by reference as dataSet, so technically no return is needed, legacy.
Utils.NormaliseChanceList = function(dataSet, chancePropertyName, skipFillingEmptyChance)
    -- The dataset is a table of entries. Each entry has various keys that are used in the calling scope and ignored by this funciton. It also has a key of the name passed in as the chancePropertyName parameter that defines the chance of this result.
    local totalChance = 0
    for _, v in pairs(dataSet) do
        totalChance = totalChance + v[chancePropertyName]
    end
    local multiplier = 1
    if not skipFillingEmptyChance or (skipFillingEmptyChance and totalChance > 1) then
        multiplier = 1 / totalChance
    end
    for _, v in pairs(dataSet) do
        v[chancePropertyName] = v[chancePropertyName] * multiplier
    end
    return dataSet
end

Utils.GetRandomEntryFromNormalisedDataSet = function(dataSet, chancePropertyName)
    local random = math.random()
    local chanceRangeLow = 0
    local chanceRangeHigh
    for _, v in pairs(dataSet) do
        chanceRangeHigh = chanceRangeLow + v[chancePropertyName]
        if random >= chanceRangeLow and random <= chanceRangeHigh then
            return v
        end
        chanceRangeLow = chanceRangeHigh
    end
    return nil
end

Utils.DisableWinOnRocket = function()
    -- OnInit
    if remote.interfaces["silo_script"] == nil then
        return
    end
    remote.call("silo_script", "set_no_victory", true)
end

Utils.ClearSpawnRespawnItems = function()
    -- OnInit
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_created_items", {})
    remote.call("freeplay", "set_respawn_items", {})
end

---@param distanceTiles uint
Utils.SetStartingMapReveal = function(distanceTiles)
    -- OnInit
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_chart_distance", distanceTiles)
end

Utils.DisableIntroMessage = function()
    -- OnInit
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_skip_intro", true)
end

Utils.PadNumberToMinimumDigits = function(input, requiredLength)
    local shortBy = requiredLength - string.len(input)
    for i = 1, shortBy do
        input = "0" .. input
    end
    return input
end

Utils.DisplayNumberPretty = function(number)
    if number == nil then
        return ""
    end
    local formatted = number
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if (k == 0) then
            break
        end
    end
    return formatted
end

Utils.DisplayTimeOfTicks = function(inputTicks, displayLargestTimeUnit, displaySmallestTimeUnit)
    -- display time units: hour, minute, second
    if inputTicks == nil then
        return ""
    end
    local negativeSign = ""
    if inputTicks < 0 then
        negativeSign = "-"
        inputTicks = 0 - inputTicks
    end
    local hours = math.floor(inputTicks / 216000)
    local displayHours = Utils.PadNumberToMinimumDigits(hours, 2)
    inputTicks = inputTicks - (hours * 216000)
    local minutes = math.floor(inputTicks / 3600)
    local displayMinutes = Utils.PadNumberToMinimumDigits(minutes, 2)
    inputTicks = inputTicks - (minutes * 3600)
    local seconds = math.floor(inputTicks / 60)
    local displaySeconds = Utils.PadNumberToMinimumDigits(seconds, 2)

    if displayLargestTimeUnit == nil or displayLargestTimeUnit == "" or displayLargestTimeUnit == "auto" then
        if hours > 0 then
            displayLargestTimeUnit = "hour"
        elseif minutes > 0 then
            displayLargestTimeUnit = "minute"
        else
            displayLargestTimeUnit = "second"
        end
    end
    if not (displayLargestTimeUnit == "hour" or displayLargestTimeUnit == "minute" or displayLargestTimeUnit == "second") then
        error("unrecognised displayLargestTimeUnit argument in Utils.MakeLocalisedStringDisplayOfTime")
    end
    if displaySmallestTimeUnit == nil or displaySmallestTimeUnit == "" or displaySmallestTimeUnit == "auto" then
        displaySmallestTimeUnit = "second"
    end
    if not (displaySmallestTimeUnit == "hour" or displaySmallestTimeUnit == "minute" or displaySmallestTimeUnit == "second") then
        error("unrecognised displaySmallestTimeUnit argument in Utils.MakeLocalisedStringDisplayOfTime")
    end

    local timeUnitIndex = {second = 1, minute = 2, hour = 3}
    local displayLargestTimeUnitIndex = timeUnitIndex[displayLargestTimeUnit]
    local displaySmallestTimeUnitIndex = timeUnitIndex[displaySmallestTimeUnit]
    local timeUnitRange = displayLargestTimeUnitIndex - displaySmallestTimeUnitIndex

    if timeUnitRange == 2 then
        return (negativeSign .. displayHours .. ":" .. displayMinutes .. ":" .. displaySeconds)
    elseif timeUnitRange == 1 then
        if displayLargestTimeUnit == "hour" then
            return (negativeSign .. displayHours .. ":" .. displayMinutes)
        else
            return (negativeSign .. displayMinutes .. ":" .. displaySeconds)
        end
    elseif timeUnitRange == 0 then
        if displayLargestTimeUnit == "hour" then
            return (negativeSign .. displayHours)
        elseif displayLargestTimeUnit == "minute" then
            return (negativeSign .. displayMinutes)
        else
            return (negativeSign .. displaySeconds)
        end
    else
        error("time unit range is negative in Utils.MakeLocalisedStringDisplayOfTime")
    end
end

---@param entityToClone table @Any entity prototype.
---@param newEntityName string
---@param subgroup string
---@param collisionMask CollisionMask
---@return table @A simple entity prototype.
Utils.CreatePlacementTestEntityPrototype = function(entityToClone, newEntityName, subgroup, collisionMask)
    -- Doesn't handle mipmaps at all presently. Also ignores any of the extra data in an icons table of "Types/IconData". Think this should just duplicate the target icons table entry.
    local clonedIcon = entityToClone.icon
    local clonedIconSize = entityToClone.icon_size
    if clonedIcon == nil then
        clonedIcon = entityToClone.icons[1].icon
        clonedIconSize = entityToClone.icons[1].icon_size
    end
    return {
        type = "simple-entity",
        name = newEntityName,
        subgroup = subgroup,
        order = "zzz",
        icons = {
            {
                icon = clonedIcon,
                icon_size = clonedIconSize
            },
            {
                icon = "__core__/graphics/cancel.png",
                icon_size = 64,
                scale = (clonedIconSize / 64) * 0.5
            }
        },
        flags = entityToClone.flags,
        selection_box = entityToClone.selection_box,
        collision_box = entityToClone.collision_box,
        collision_mask = collisionMask,
        picture = {
            filename = "__core__/graphics/cancel.png",
            height = 64,
            width = 64
        }
    }
end

Utils.CreateLandPlacementTestEntityPrototype = function(entityToClone, newEntityName, subgroup)
    subgroup = subgroup or "other"
    return Utils.CreatePlacementTestEntityPrototype(entityToClone, newEntityName, subgroup, {"water-tile", "colliding-with-tiles-only"})
end

Utils.CreateWaterPlacementTestEntityPrototype = function(entityToClone, newEntityName, subgroup)
    subgroup = subgroup or "other"
    return Utils.CreatePlacementTestEntityPrototype(entityToClone, newEntityName, subgroup, {"ground-tile", "colliding-with-tiles-only"})
end

--- Tries to converts a non boolean to a boolean value.
---@param text string|int|boolean @The input to check.
---@return boolean|null @Returns a boolean if successful, or nil if not.
Utils.ToBoolean = function(text)
    if text == nil then
        return nil
    end
    local textType = type(text)
    if textType == "string" then
        text = string.lower(text)
        if text == "true" then
            return true
        elseif text == "false" then
            return false
        else
            return nil
        end
    elseif textType == "number" then
        if text == 0 then
            return false
        elseif text == 1 then
            return true
        else
            return nil
        end
    elseif textType == "boolean" then
        return text
    else
        return nil
    end
end

Utils.RandomLocationInRadius = function(centrePos, maxRadius, minRadius)
    local angle = math.random(0, 360)
    minRadius = minRadius or 0
    local radiusMultiplier = maxRadius - minRadius
    local distance = minRadius + (math.random() * radiusMultiplier)
    return Utils.GetPositionForAngledDistance(centrePos, distance, angle)
end

Utils.GetPositionForAngledDistance = function(startingPos, distance, angle)
    if angle < 0 then
        angle = 360 + angle
    end
    local angleRad = math.rad(angle)
    local newPos = {
        x = (distance * math.sin(angleRad)) + startingPos.x,
        y = (distance * -math.cos(angleRad)) + startingPos.y
    }
    return newPos
end

---@param startingPos Position
---@param distance number
---@param orientation double
---@return Position
Utils.GetPositionForOrientationDistance = function(startingPos, distance, orientation)
    return Utils.GetPositionForAngledDistance(startingPos, distance, orientation * 360)
end

Utils.FindWhereLineCrossesCircle = function(radius, slope, yIntercept)
    local centerPos = {x = 0, y = 0}
    local A = 1 + slope * slope
    local B = -2 * centerPos.x + 2 * slope * yIntercept - 2 * centerPos.y * slope
    local C = centerPos.x * centerPos.x + yIntercept * yIntercept + centerPos.y * centerPos.y - 2 * centerPos.y * yIntercept - radius * radius
    local delta = B * B - 4 * A * C

    if delta < 0 then
        return nil, nil
    else
        local x1 = (-B + math.sqrt(delta)) / (2 * A)

        local x2 = (-B - math.sqrt(delta)) / (2 * A)

        local y1 = slope * x1 + yIntercept

        local y2 = slope * x2 + yIntercept

        local pos1 = {x = x1, y = y1}
        local pos2 = {x = x2, y = y2}
        if pos1 == pos2 then
            return pos1, nil
        else
            return pos1, pos2
        end
    end
end

Utils.IsPositionWithinCircled = function(circleCenter, radius, position)
    local deltaX = math.abs(position.x - circleCenter.x)
    local deltaY = math.abs(position.y - circleCenter.y)
    if deltaX + deltaY <= radius then
        return true
    elseif deltaX > radius then
        return false
    elseif deltaY > radius then
        return false
    elseif deltaX ^ 2 + deltaY ^ 2 <= radius ^ 2 then
        return true
    else
        return false
    end
end

Utils.GetValueAndUnitFromString = function(text)
    return string.match(text, "%d+%.?%d*"), string.match(text, "%a+")
end

Utils.TryMoveInventoriesLuaItemStacks = function(sourceInventory, targetInventory, dropUnmovedOnGround, ratioToMove)
    -- Moves the full Lua Item Stacks so handles items with data and other complicated items. Updates the passed in inventory object.
    -- Returns true/false if all items were moved successfully.
    local sourceOwner, itemAllMoved = nil, true
    if dropUnmovedOnGround == nil then
        dropUnmovedOnGround = false
    end
    if ratioToMove == nil then
        ratioToMove = 1
    end
    if sourceInventory == nil or sourceInventory.is_empty() then
        return itemAllMoved
    end
    for index = 1, #sourceInventory do
        local itemStack = sourceInventory[index]
        if itemStack.valid_for_read then
            local toMoveCount = math.ceil(itemStack.count * ratioToMove)
            local itemStackToMove = Utils.DeepCopy(itemStack)
            itemStackToMove.count = toMoveCount
            local movedCount = targetInventory.insert(itemStackToMove)
            local remaining = itemStack.count - movedCount
            if movedCount > 0 then
                itemStack.count = remaining
            end
            if remaining > 0 then
                itemAllMoved = false
                if dropUnmovedOnGround then
                    sourceOwner = sourceOwner or targetInventory.entity_owner or targetInventory.player_owner
                    sourceOwner.surface.spill_item_stack(sourceOwner.position, {name = itemStack.name, count = remaining}, true, sourceOwner.force, false)
                end
            end
        end
    end

    return itemAllMoved
end

Utils.TryTakeGridsItems = function(sourceGrid, targetInventory, dropUnmovedOnGround)
    -- Can only move the item name and count via API, Facotrio doesn't support putting equipment objects in an inventory. Updates the passed in grid object.
    -- Returns true/false if all items were moved successfully.
    if sourceGrid == nil then
        return
    end
    local sourceOwner, itemAllMoved = nil, true
    if dropUnmovedOnGround == nil then
        dropUnmovedOnGround = false
    end
    for _, equipment in pairs(sourceGrid.equipment) do
        local moved = targetInventory.insert({name = equipment.name, count = 1})
        if moved > 0 then
            sourceGrid.take({equipment = equipment})
        end
        if moved == 0 then
            itemAllMoved = false
            if dropUnmovedOnGround then
                sourceOwner = sourceOwner or targetInventory.entity_owner or targetInventory.player_owner
                sourceOwner.surface.spill_item_stack(sourceOwner.position, {name = equipment.name, count = 1}, true, sourceOwner.force, false)
            end
        end
    end
    return itemAllMoved
end

Utils.TryInsertInventoryContents = function(contents, targetInventory, dropUnmovedOnGround, ratioToMove)
    -- Just takes a list of item names and counts that you get from the inventory.get_contents(). Updates the passed in contents object.
    -- Returns true/false if all items were moved successfully.
    if Utils.IsTableEmpty(contents) then
        return
    end
    local sourceOwner, itemAllMoved = nil, true
    if dropUnmovedOnGround == nil then
        dropUnmovedOnGround = false
    end
    if ratioToMove == nil then
        ratioToMove = 1
    end
    for name, count in pairs(contents) do
        local toMove = math.ceil(count * ratioToMove)
        local moved = targetInventory.insert({name = name, count = toMove})
        local remaining = count - moved
        if moved > 0 then
            contents[name] = remaining
        end
        if remaining > 0 then
            itemAllMoved = false
            if dropUnmovedOnGround then
                sourceOwner = sourceOwner or targetInventory.entity_owner or targetInventory.player_owner
                sourceOwner.surface.spill_item_stack(sourceOwner.position, {name = name, count = remaining}, true, sourceOwner.force, false)
            end
        end
    end
    return itemAllMoved
end

Utils.TryInsertSimpleItems = function(contents, targetInventory, dropUnmovedOnGround, ratioToMove)
    -- Takes a table of SimpleItemStack and inserts them in to an inventory. Updates the passed in contents object.
    -- Returns true/false if all items were moved successfully.
    if contents == nil or #contents == 0 then
        return
    end
    local sourceOwner, itemAllMoved = nil, true
    if dropUnmovedOnGround == nil then
        dropUnmovedOnGround = false
    end
    if ratioToMove == nil then
        ratioToMove = 1
    end
    for index, simpleItemStack in pairs(contents) do
        local toMove = math.ceil(simpleItemStack.count * ratioToMove)
        local moved = targetInventory.insert({name = simpleItemStack.name, count = toMove, health = simpleItemStack.health, durability = simpleItemStack.durablilty, ammo = simpleItemStack.ammo})
        local remaining = simpleItemStack.count - moved
        if moved > 0 then
            contents[index].count = remaining
        end
        if remaining > 0 then
            itemAllMoved = false
            if dropUnmovedOnGround then
                sourceOwner = sourceOwner or targetInventory.entity_owner or targetInventory.player_owner
                sourceOwner.surface.spill_item_stack(sourceOwner.position, {name = simpleItemStack.name, count = remaining}, true, sourceOwner.force, false)
            end
        end
    end
    return itemAllMoved
end

---@param builder EntityActioner
Utils.GetBuilderInventory = function(builder)
    if builder.is_player() then
        return builder.get_main_inventory()
    elseif builder.type ~= nil and builder.type == "construction-robot" then
        return builder.get_inventory(defines.inventory.robot_cargo)
    else
        return builder
    end
end

---@param actioner EntityActioner
---@return LuaPlayer[] @Table of players or nil.
---@return LuaForce[] @Table of forces or nil.
Utils.GetRenderPlayersForcesFromActioner = function(actioner)
    if actioner == nil then
        -- Is a script.
        return nil, nil
    elseif actioner.is_player() then
        -- Is a player.
        return {actioner}, nil
    else
        -- Is construction bot.
        return nil, {actioner.force}
    end
end

---@param repeat_count int|null @Defaults to 1 if not provided
---@return Sprite
Utils.EmptyRotatedSprite = function(repeat_count)
    return {
        direction_count = 1,
        filename = "__core__/graphics/empty.png",
        width = 1,
        height = 1,
        repeat_count = repeat_count or 1
    }
end

--[[
    This function will set trackingTable to have the below entry. Query these keys in calling function:
        trackingTable {
            fuelName = STRING,
            fuelCount = INT,
            fuelValue = INT,
        }
--]]
---@param trackingTable table @reference to an existing table that the function will populate.
---@param itemName string
---@param itemCount uint
---@return boolean|null @Returns true when the fuel is a new best and false when its not. Returns nil if the item isn't a fuel type.
Utils.TrackBestFuelCount = function(trackingTable, itemName, itemCount)
    local itemPrototype = game.item_prototypes[itemName]
    local fuelValue = itemPrototype.fuel_value
    if fuelValue == nil then
        return nil
    end
    if trackingTable.fuelValue == nil or fuelValue > trackingTable.fuelValue then
        trackingTable.fuelName = itemName
        trackingTable.fuelCount = itemCount
        trackingTable.fuelValue = fuelValue
        return true
    end
    if trackingTable.fuelName == itemName and itemCount > trackingTable.fuelCount then
        trackingTable.fuelCount = itemCount
        return true
    end
    return false
end

Utils.MakeRecipePrototype = function(recipeName, resultItemName, enabled, ingredientLists, energyLists)
    --[[
        Takes tables of the various recipe types (normal, expensive and ingredients) and makes the required recipe prototypes from them. Only makes the version if the ingredientsList includes the type. So supplying just energyLists types doesn't make new versions.
        ingredientLists is a table with optional tables for "normal", "expensive" and "ingredients" tables within them. Often generatered by Utils.GetRecipeIngredientsAddedTogeather().
        energyLists is a table with optional keys for "normal", "expensive" and "ingredients". The value of the keys is the energy_required value.
    ]]
    local recipePrototype = {
        type = "recipe",
        name = recipeName
    }
    if ingredientLists.ingredients ~= nil then
        recipePrototype.energy_required = energyLists.ingredients
        recipePrototype.enabled = enabled
        recipePrototype.result = resultItemName
        recipePrototype.ingredients = ingredientLists.ingredients
    end
    if ingredientLists.normal ~= nil then
        recipePrototype.normal = {
            energy_required = energyLists.normal or energyLists.ingredients,
            enabled = enabled,
            result = resultItemName,
            ingredients = ingredientLists.normal
        }
    end
    if ingredientLists.expensive ~= nil then
        recipePrototype.expensive = {
            energy_required = energyLists.expensive or energyLists.ingredients,
            enabled = enabled,
            result = resultItemName,
            ingredients = ingredientLists.expensive
        }
    end
    return recipePrototype
end

Utils.GetRecipeIngredientsAddedTogeather = function(recipeIngredientHandlingTables)
    --[[
        Is for handling a mix of recipes and ingredient list. Supports recipe ingredients, normal and expensive.
        Returns the widest range of types fed in as a table of result tables (nil for non required returns): {ingredients, normal, expensive}
        Takes a table (list) of entries. Each entry is a table (list) of recipe/ingredients, handling type and ratioMultiplier (optional), i.e. {{ingredients1, "add"}, {recipe1, "add", 0.5}, {ingredients2, "highest", 2}}
        handling types:
            - add: adds the ingredients from a list to the total
            - subtract: removes the ingredients in this list from the total
            - highest: just takes the highest counts of each ingredients across the 2 lists.
        ratioMultiplier item counts for recipes are rounded up. Defaults to ration of 1 if not provided.
    ]]
    local ingredientsTable, ingredientTypes = {}, {}
    for _, recipeIngredientHandlingTable in pairs(recipeIngredientHandlingTables) do
        if recipeIngredientHandlingTable[1].normal ~= nil then
            ingredientTypes.normal = true
        end
        if recipeIngredientHandlingTable[1].expensive ~= nil then
            ingredientTypes.expensive = true
        end
    end
    if Utils.IsTableEmpty(ingredientTypes) then
        ingredientTypes.ingredients = true
    end

    for ingredientType in pairs(ingredientTypes) do
        local ingredientsList = {}
        for _, recipeIngredientHandlingTable in pairs(recipeIngredientHandlingTables) do
            local ingredients  --try to find the correct ingredients for our desired type, if not found just try all of them to find one to use. Assume its a simple ingredient list last.
            if recipeIngredientHandlingTable[1][ingredientType] ~= nil then
                ingredients = recipeIngredientHandlingTable[1][ingredientType].ingredients or recipeIngredientHandlingTable[1][ingredientType]
            elseif recipeIngredientHandlingTable[1]["ingredients"] ~= nil then
                ingredients = recipeIngredientHandlingTable[1]["ingredients"]
            elseif recipeIngredientHandlingTable[1]["normal"] ~= nil then
                ingredients = recipeIngredientHandlingTable[1]["normal"].ingredients
            elseif recipeIngredientHandlingTable[1]["expensive"] ~= nil then
                ingredients = recipeIngredientHandlingTable[1]["expensive"].ingredients
            else
                ingredients = recipeIngredientHandlingTable[1]
            end
            local handling, ratioMultiplier = recipeIngredientHandlingTable[2], recipeIngredientHandlingTable[3]
            if ratioMultiplier == nil then
                ratioMultiplier = 1
            end
            for _, details in pairs(ingredients) do
                local name, count = details[1] or details.name, math.ceil((details[2] or details.amount) * ratioMultiplier)
                if handling == "add" then
                    ingredientsList[name] = (ingredientsList[name] or 0) + count
                elseif handling == "subtract" then
                    if ingredientsList[name] ~= nil then
                        ingredientsList[name] = ingredientsList[name] - count
                    end
                elseif handling == "highest" then
                    if count > (ingredientsList[name] or 0) then
                        ingredientsList[name] = count
                    end
                end
            end
        end
        ingredientsTable[ingredientType] = {}
        for name, count in pairs(ingredientsList) do
            if ingredientsList[name] > 0 then
                table.insert(ingredientsTable[ingredientType], {name, count})
            end
        end
    end
    return ingredientsTable
end

Utils.GetRecipeAttribute = function(recipe, attributeName, recipeCostType, defaultValue)
    --[[
        Returns the attributeName for the recipeCostType if available, otherwise the inline ingredients version.
        recipeType defaults to the no cost type if not supplied. Values are: "ingredients", "normal" and "expensive".
    --]]
    recipeCostType = recipeCostType or "ingredients"
    if recipeCostType == "ingredients" and recipe[attributeName] ~= nil then
        return recipe[attributeName]
    elseif recipe[recipeCostType] ~= nil and recipe[recipeCostType][attributeName] ~= nil then
        return recipe[recipeCostType][attributeName]
    end

    if recipe[attributeName] ~= nil then
        return recipe[attributeName]
    elseif recipe["normal"] ~= nil and recipe["normal"][attributeName] ~= nil then
        return recipe["normal"][attributeName]
    elseif recipe["expensive"] ~= nil and recipe["expensive"][attributeName] ~= nil then
        return recipe["expensive"][attributeName]
    end

    return defaultValue -- may well be nil
end

Utils.DoesRecipeResultsIncludeItemName = function(recipePrototype, itemName)
    for _, recipeBase in pairs({recipePrototype, recipePrototype.normal, recipePrototype.expensive}) do
        if recipeBase ~= nil then
            if recipeBase.result ~= nil and recipeBase.result == itemName then
                return true
            elseif recipeBase.results ~= nil and #Utils.GetTableKeyWithInnerKeyValue(recipeBase.results, "name", itemName) > 0 then
                return true
            end
        end
    end
    return false
end

Utils.RemoveEntitiesRecipesFromTechnologies = function(entityPrototype, recipes, technolgies)
    --[[
        From the provided technology list remove all provided recipes from being unlocked that create an item that can place a given entity prototype.
        Returns a table of the technologies affected or a blank table if no technologies are affected.
    ]]
    local technologiesChanged = {}
    local placedByItemName
    if entityPrototype.minable ~= nil and entityPrototype.minable.result ~= nil then
        placedByItemName = entityPrototype.minable.result
    else
        return technologiesChanged
    end
    for _, recipePrototype in pairs(recipes) do
        if Utils.DoesRecipeResultsIncludeItemName(recipePrototype, placedByItemName) then
            recipePrototype.enabled = false
            for _, technologyPrototype in pairs(technolgies) do
                if technologyPrototype.effects ~= nil then
                    for effectIndex, effect in pairs(technologyPrototype.effects) do
                        if effect.type == "unlock-recipe" and effect.recipe ~= nil and effect.recipe == recipePrototype.name then
                            table.remove(technologyPrototype.effects, effectIndex)
                            table.insert(technologiesChanged, technologyPrototype)
                        end
                    end
                end
            end
        end
    end
    return technologiesChanged
end

Utils.SplitStringOnCharacters = function(text, splitCharacters, returnAskey)
    local list = {}
    local results = text:gmatch("[^" .. splitCharacters .. "]*")
    for phrase in results do
        phrase = Utils.StringTrim(phrase)
        if phrase ~= nil and phrase ~= "" then
            if returnAskey ~= nil and returnAskey == true then
                list[phrase] = true
            else
                table.insert(list, phrase)
            end
        end
    end
    return list
end

Utils.StringTrim = function(text)
    -- trim6 from http://lua-users.org/wiki/StringTrim
    return string.match(text, "^()%s*$") and "" or string.match(text, "^%s*(.*%S)")
end

---@param orientation double @Will be rounded to the nearest cardinal or intercardinal direction.
---@return defines.direction
Utils.OrientationToDirection = function(orientation)
    return Utils.LoopIntValueWithinRange(Utils.RoundNumberToDecimalPlaces(orientation * 8, 0), 0, 7)
end

---@param directionValue defines.direction
---@return double
Utils.DirectionToOrientation = function(directionValue)
    return directionValue / 8
end

---@param directionValue defines.direction
---@return string
Utils.DirectionValueToName = function(directionValue)
    local names = {[0] = "north", [1] = "northeast", [2] = "east", [3] = "southeast", [4] = "south", [5] = "southwest", [6] = "west", [7] = "northwest"}
    return names[directionValue]
end

---@param directionValue defines.direction
---@return int
Utils.LoopDirectionValue = function(directionValue)
    return Utils.LoopIntValueWithinRange(directionValue, 0, 7)
end

---@param entity LuaEntity
---@param killerForce LuaForce
---@param killerCauseEntity LuaEntity|null
Utils.EntityDie = function(entity, killerForce, killerCauseEntity)
    if killerCauseEntity ~= nil then
        entity.die(killerForce, killerCauseEntity)
    else
        entity.die(killerForce)
    end
end

Utils.MaxTrainStopLimit = 4294967295 ---@type uint

---@param luaObject LuaBaseClass
---@return LuaBaseClass|null
Utils.ReturnValidLuaObjectOrNil = function(luaObject)
    if luaObject == nil or not luaObject.valid then
        return nil
    else
        return luaObject
    end
end

---@param train LuaTrain
---@param isFrontStockLeading boolean @If the trains speed is > 0 then pass in true, if speed < 0 then pass in false.
---@return LuaEntity
Utils.GetLeadingCarriageOfTrain = function(train, isFrontStockLeading)
    if isFrontStockLeading then
        return train.front_stock
    else
        return train.back_stock
    end
end

return Utils
