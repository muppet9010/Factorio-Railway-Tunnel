--[[
    Random utility functions that don't fit in to any other category.
]]
--

local MiscUtils = {}

MiscUtils.WasCreativeModeInstantDeconstructionUsed = function(event)
    if event.instant_deconstruction ~= nil and event.instant_deconstruction == true then
        return true
    else
        return false
    end
end

-- called from OnInit
MiscUtils.DisableWinOnRocket = function()
    if remote.interfaces["silo_script"] == nil then
        return
    end
    remote.call("silo_script", "set_no_victory", true)
end

-- called from OnInit
MiscUtils.ClearSpawnRespawnItems = function()
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_created_items", {})
    remote.call("freeplay", "set_respawn_items", {})
end

-- called from OnInit
---@param distanceTiles uint
MiscUtils.SetStartingMapReveal = function(distanceTiles)
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_chart_distance", distanceTiles)
end

-- called from OnInit
MiscUtils.DisableIntroMessage = function()
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_skip_intro", true)
end

--- Get the builder/miner player/construction robot or nil if script placed.
---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive|on_pre_player_mined_item|on_robot_pre_mined
---@return EntityActioner|nil placer
MiscUtils.GetActionerFromEvent = function(event)
    if event.robot ~= nil then
        -- Construction robots
        return event.robot
    elseif event.player_index ~= nil then
        -- Player
        return game.get_player(event.player_index)
    else
        -- Script placed
        return nil
    end
end

--- Returns either tha player or force for robots from the EntityActioner.
---
--- Useful for passing in to rendering player/force filters or for returning items to them.
---@param actioner EntityActioner
---@return LuaPlayer|nil
---@return LuaForce|nil
MiscUtils.GetPlayerForceFromActioner = function(actioner)
    if actioner.is_player() then
        -- Is a player.
        return actioner, nil
    else
        -- Is construction bot.
        return nil, actioner.force
    end
end

--- Returns a luaObject if its valid, else nil. Convientent for inline usage when rarely called.
---
--- Should be done locally if called frequently.
---@param luaObject LuaBaseClass
---@return LuaBaseClass|nil
MiscUtils.ReturnValidLuaObjectOrNil = function(luaObject)
    if luaObject == nil or not luaObject.valid then
        return nil
    else
        return luaObject
    end
end

return MiscUtils
