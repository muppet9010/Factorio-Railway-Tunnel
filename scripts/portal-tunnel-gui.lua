local Events = require("utility.events")
local PortalTunnelGui = {}
local Common = require("scripts.common")
local GuiUtil = require("utility.gui-util")
local GuiActionsClick = require("utility.gui-actions-click")

PortalTunnelGui.CreateGlobals = function()
end

PortalTunnelGui.OnLoad = function()
    Events.RegisterHandlerCustomInput("railway_tunnel-open_gui", "PortalTunnelGui.OnOpenGuiInput", PortalTunnelGui.OnOpenGuiInput)
end

--- Called when ever a player left clicks on an entity. We want to check if they have clicked on a portal part entity and if so call to load the GUI for it.
---@param event CustomInputEvent
PortalTunnelGui.OnOpenGuiInput = function(event)
    -- This event will fire for a number of player actions we can just entirely ignore, or for clicked entity types we don't care about.
    if event.selected_prototype == nil or event.selected_prototype.base_type ~= "entity" or event.selected_prototype.derived_type ~= "simple-entity-with-owner" then
        return
    end

    -- Check if the clicked entity is one of our portal parts specifically.
    if Common.PortalEndAndSegmentEntityNames[event.selected_prototype.name] == nil then
        return
    end

    -- Is one of our portal parts so get the portal its part of and open the GUI for it.
    local player = game.get_player(event.player_index)
    local portalPartId = player.selected.unit_number
    local portalPart = global.portals.portalPartEntityIdToPortalPart[portalPartId]
    if portalPart == nil then
        error("no registered portal part object for clicked portal part entity")
    end

    -- Load GUI to player.
    --TODO
end

return PortalTunnelGui
