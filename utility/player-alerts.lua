--[[
    Library to support using player alerts that handles all of the complicated edge cases.
    This includes players changing forces and getting existing/removing old alerts.
--]]
--
-- TODO: Need to handle players changing forces (leaving and joining).

local PlayerAlerts = {}

---@class ForceAlertObject @ The cached details of an alert applied to all players on a force. Used to track the alerts and remove them, but also to allow adding/removing from players as they join/leave a force.
---@field id Id @ Id of the alert object.
---@field force LuaForce @ The force that this alert applies to.
---@field players LuaPlayer[] @ The players who had this alert applied to them.
---@field alertEntity LuaEntity @ The entity the alert targets.
---@field alertSignalId SignalID
---@field alertMessage LocalisedString
---@field showOnMap boolean

--------------------------------------------------------------------------------------------
--                                    Public Functions
--------------------------------------------------------------------------------------------

--- Add a custom alert to all players on the force. Automatically removes any old duplicate alerts of the same alertId.
---@param force LuaForce
---@param alertId Id|null @ A unique Id that we will use to track duplicate requests for the same alert. If nil is provided a sequential number shall be affixed to "auto" as the Id.
---@param alertEntity LuaEntity
---@param alertSignalId SignalID
---@param alertMessage LocalisedString
---@param showOnMap boolean
---@return Id alertId @ The Id of the created alert.
PlayerAlerts.AddCustomAlertToForce = function(force, alertId, alertEntity, alertSignalId, alertMessage, showOnMap)
    local forceId = force.index
    local forceAlerts = PlayerAlerts._CreateForceAlertsGlobalObject(forceId) ---@type table<Id, ForceAlertObject>

    -- Get an alertId if one not provided
    if alertId == nil then
        if global.UTILITYPLAYERALERTS.forceAlertsNextAutoId == nil then
            global.UTILITYPLAYERALERTS.forceAlertsNextAutoId = 1
        end
        alertId = "auto_" .. global.UTILITYPLAYERALERTS.forceAlertsNextAutoId
        global.UTILITYPLAYERALERTS.forceAlertsNextAutoId = global.UTILITYPLAYERALERTS.forceAlertsNextAutoId + 1
    end

    -- Existing alert exists for this Id, so destroy the old one before creating the new one.
    if forceAlerts[alertId] ~= nil then
        PlayerAlerts.RemoveCustomAlertFromForce(forceId, alertId)
    end

    --- Apply the alert to the players currently on the force and create the global object to track the alert in the future.
    for _, player in pairs(force.players) do
        player.add_custom_alert(alertEntity, alertSignalId, alertMessage, showOnMap)
    end
    forceAlerts[alertId] = {
        id = alertId,
        force = force,
        players = force.players,
        alertEntity = alertEntity,
        alertSignalId = alertSignalId,
        alertMessage = alertMessage,
        showOnMap = showOnMap
    }

    return alertId
end

--- Remove a custom alert from all players on the force and delete it from the force's alert global table.
---@param forceIndex Id @ the index of the LuaForce.
---@param alertId Id @ The unique Id of the alert.
---@return boolean alertRemoved @ If an alert was removed.
PlayerAlerts.RemoveCustomAlertFromForce = function(forceIndex, alertId)
    -- Get the alert if it exists.
    local forceAlert = PlayerAlerts._GetForceAlert(forceIndex, alertId)
    if forceAlert == nil then
        return false
    end

    -- Remove the alert from all players.
    for _, player in pairs(forceAlert.players) do
        if player.valid then
            player.remove_alert {
                entity = forceAlert.alertEntity,
                type = defines.alert_type.custom,
                icon = forceAlert.alertSignalId,
                message = forceAlert.alertMessage
            }
        end
    end

    -- Remove the alert from the force's global object.
    global.UTILITYPLAYERALERTS.forceAlerts[forceIndex][alertId] = nil
end

--------------------------------------------------------------------------------------------
--                                    Internal Functions
--------------------------------------------------------------------------------------------

--- Creates (if needed) and returns a force's alerts Factorio global table.
---@param forceIndex Id @ the index of the LuaForce.
---@return table<Id, ForceAlertObject> forceAlerts
PlayerAlerts._CreateForceAlertsGlobalObject = function(forceIndex)
    if global.UTILITYPLAYERALERTS == nil then
        global.UTILITYPLAYERALERTS = {}
    end
    if global.UTILITYPLAYERALERTS.forceAlerts == nil then
        global.UTILITYPLAYERALERTS.forceAlerts = {}
    end
    local forceAlerts = global.UTILITYPLAYERALERTS.forceAlerts[forceIndex]
    if forceAlerts == nil then
        global.UTILITYPLAYERALERTS.forceAlerts[forceIndex] = global.UTILITYPLAYERALERTS.forceAlerts[forceIndex] or {}
        forceAlerts = global.UTILITYPLAYERALERTS.forceAlerts[forceIndex]
    end
    return forceAlerts
end

--- Returns a force's alerts Factorio global table if it exists.
---@param forceIndex Id @ the index of the LuaForce.
---@return table<Id, ForceAlertObject>|null forceAlerts
PlayerAlerts._GetForceAlerts = function(forceIndex)
    if global.UTILITYPLAYERALERTS == nil or global.UTILITYPLAYERALERTS.forceAlerts == nil or global.UTILITYPLAYERALERTS.forceAlerts[forceIndex] then
        return nil
    else
        return global.UTILITYPLAYERALERTS.forceAlerts[forceIndex]
    end
end

--- Returns a force's specific alert from the Factorio global table if it exists.
---@param forceIndex Id @ the index of the LuaForce.
---@param alertId Id
---@return ForceAlertObject|null forceAlert
PlayerAlerts._GetForceAlert = function(forceIndex, alertId)
    if global.UTILITYPLAYERALERTS == nil or global.UTILITYPLAYERALERTS.forceAlerts == nil or global.UTILITYPLAYERALERTS.forceAlerts[forceIndex] == nil or global.UTILITYPLAYERALERTS.forceAlerts[forceIndex][alertId] == nil then
        return nil
    else
        return global.UTILITYPLAYERALERTS.forceAlerts[forceIndex][alertId]
    end
end

return PlayerAlerts
