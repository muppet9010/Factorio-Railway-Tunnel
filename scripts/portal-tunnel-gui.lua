local Events = require("utility.events")
local PortalTunnelGui = {}
local Common = require("scripts.common")
local GuiUtil = require("utility.gui-util")
local GuiActionsClick = require("utility.gui-actions-click")

PortalTunnelGui.CreateGlobals = function()
end

PortalTunnelGui.OnLoad = function()
    Events.RegisterHandlerCustomInput("railway_tunnel-open_gui", "PortalTunnelGui.OnOpenGuiInput", PortalTunnelGui.OnOpenGuiInput)
    GuiActionsClick.LinkGuiClickActionNameToFunction("PortalTunnelGui.OnCloseButtonClicked", PortalTunnelGui.OnCloseButtonClicked)
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

    -- Mark the portalPart as GuiOpened.
    -- TODO: theres no logic to check for opened GUI's when the various part-portal-tunnel are made/deconstructed/mined.
    MOD.Interfaces.Portal.GuiOpenedOnPortalPart(portalPart, event.player_index)

    -- Load GUI to player.
    PortalTunnelGui.MakeGui(portalPart, player, event.player_index)
end

--- Called to make the GUI.
---@param portalPart PortalPart
---@param player LuaPlayer
---@param playerIndex Id
PortalTunnelGui.MakeGui = function(portalPart, player, playerIndex)
    GuiUtil.AddElement(
        {
            parent = player.gui.screen,
            descriptiveName = "pt_main",
            type = "frame",
            direction = "vertical",
            style = "muppet_frame_main_shadowRisen_paddingBR",
            storeName = "portalTunnelGui",
            attributes = {auto_center = true},
            children = {
                {
                    type = "flow",
                    direction = "horizontal",
                    style = "muppet_flow_horizontal_marginTL",
                    styling = {horizontal_align = "left", right_padding = 4},
                    children = {
                        {
                            descriptiveName = "pt_title",
                            type = "label",
                            style = "muppet_label_heading_large_bold_paddingSides",
                            caption = "self"
                        },
                        {
                            descriptiveName = "pt_dragBar",
                            type = "empty-widget",
                            style = "draggable_space",
                            styling = {horizontally_stretchable = true, height = 20, top_margin = 4, minimal_width = 80},
                            attributes = {
                                drag_target = function()
                                    return GuiUtil.GetElementFromPlayersReferenceStorage(playerIndex, "portalTunnelGui", "pt_main", "frame")
                                end
                            }
                        },
                        {
                            type = "flow",
                            direction = "horizontal",
                            style = "muppet_flow_horizontal_spaced",
                            styling = {horizontal_align = "right", top_margin = 4},
                            children = {
                                --[[{
                                    descriptiveName = "pt_openHelp",
                                    type = "button",
                                    style = "muppet_button_text_small_bold_frame_paddingNone",
                                    styling = {},
                                    caption = "self",
                                    registerClick = {actionName = "ShopGui.OpenHelpAction"},
                                    enabled = true
                                },]]
                                {
                                    descriptiveName = "pt_closeButton",
                                    type = "sprite-button",
                                    tooltip = "self",
                                    sprite = "utility/close_white",
                                    style = "muppet_sprite_button_frameCloseButtonClickable",
                                    registerClick = {actionName = "PortalTunnelGui.OnCloseButtonClicked", data = {portalPart = portalPart}}
                                }
                            }
                        }
                    }
                }
            }
        }
    )
end

--- When the player clicks the close button on their GUI.
---@param event UtilityGuiActionsClick_ActionData
PortalTunnelGui.OnCloseButtonClicked = function(event)
    -- Tell the protal part which will propigate up to the tunnel.
    MOD.Interfaces.Portal.GuiClosedOnPortalPart(event.data.portalPart, event.playerIndex)

    -- Close and destroy all the Gui Element's for this overall GUI on screen.
    GuiUtil.DestroyPlayersReferenceStorage(event.playerIndex, "portalTunnelGui")
end

--- Called by the Portal class when a change has occured to the portal part of one of its parents that the GUI needs to react to.
--- Currently we just recreate the GUI as its the easiest and this will be a very rare event.
---@param portalPart PortalPart
---@param playerIndex Id
PortalTunnelGui.PortalPartChanged = function(portalPart, playerIndex)
end

--- Called when the usage state of the tunnel changes by the TrainManager class.
---@param playerIndex Id
PortalTunnelGui.TunnelUsageChanged = function(playerIndex)
end

return PortalTunnelGui
