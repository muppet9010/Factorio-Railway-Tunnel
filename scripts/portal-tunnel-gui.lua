local Events = require("utility.events")
local PortalTunnelGui = {}
local Common = require("scripts.common")
local GuiUtil = require("utility.gui-util")
local GuiActionsClick = require("utility.gui-actions-click")
local Utils = require("utility.utils")
local MuppetStyles = require("utility.style-data").MuppetStyles

PortalTunnelGui.CreateGlobals = function()
    global.portalTunnelGui = global.portalTunnelGui or {}
    global.portalTunnelGui.portalPartOpenByPlayer = global.portalTunnelGui.portalPartOpenByPlayer or {} ---@type table<Id, PortalPart> @ A list of each palyer with a portal GUI open and which PortalPart it is. For reverse lookup of PortalPart by player.
end

PortalTunnelGui.OnLoad = function()
    Events.RegisterHandlerCustomInput("railway_tunnel-open_gui", "PortalTunnelGui.On_OpenGuiInput", PortalTunnelGui.On_OpenGuiInput)
    GuiActionsClick.LinkGuiClickActionNameToFunction("PortalTunnelGui.On_CloseButtonClicked", PortalTunnelGui.On_CloseButtonClicked)
    GuiActionsClick.LinkGuiClickActionNameToFunction("PortalTunnelGui.On_OpenTrainGuiClicked", PortalTunnelGui.On_OpenTrainGuiClicked)

    MOD.Interfaces.PortalTunnelGui = MOD.Interfaces.PortalTunnelGui or {}
    MOD.Interfaces.PortalTunnelGui.On_PortalPartChanged = PortalTunnelGui.On_PortalPartChanged
    MOD.Interfaces.PortalTunnelGui.On_TunnelUsageChanged = PortalTunnelGui.On_TunnelUsageChanged
end

--- Called when ever a player left clicks on an entity. We want to check if they have clicked on a portal part entity and if so call to load the GUI for it.
---@param event CustomInputEvent
PortalTunnelGui.On_OpenGuiInput = function(event)
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

    -- If theres already a GUI open close it down fully before opening the new one. Assumes player has clicked on a new Part while an exisitng Part GUI was open.
    local openGuiForPortalPart = global.portalTunnelGui.portalPartOpenByPlayer[event.player_index]
    if openGuiForPortalPart then
        PortalTunnelGui.CloseGui(event.player_index, portalPart)
    end

    -- Record to global lookups this player has this PortalPart open.
    global.portalTunnelGui.portalPartOpenByPlayer[event.player_index] = portalPart

    -- Mark the portalPart as GuiOpened.
    MOD.Interfaces.Portal.GuiOpenedOnPortalPart(portalPart, event.player_index, player)

    -- Load GUI to player.
    PortalTunnelGui.MakeGui(portalPart, player, event.player_index)
end

--- Called to make the GUI.
---@param portalPart PortalPart
---@param player LuaPlayer
---@param playerIndex Id
PortalTunnelGui.MakeGui = function(portalPart, player, playerIndex)
    -- Get the protal and tunnel variable values.
    local thisPortal = portalPart.portal
    local tunnel  ---@type Tunnel
    local portalState  ---@type string
    if thisPortal ~= nil and thisPortal.tunnel ~= nil then
        tunnel = thisPortal.tunnel
    else
        -- Work out the portal state descriptions needed for when not in a complete portal.
        if thisPortal == nil then
            portalState = "not part of a portal"
        elseif not thisPortal.isComplete then
            portalState = "portal incomplete"
        else
            portalState = "portal complete, but not part of a tunnel"
        end
    end

    -- Add the GUI Elements.
    local createdElements =
        GuiUtil.AddElement(
        {
            parent = player.gui.screen,
            descriptiveName = "pt_main",
            type = "frame",
            direction = "vertical",
            style = MuppetStyles.frame.main_shadowRisen.paddingBR,
            storeName = "portalTunnelGui",
            returnElement = true,
            attributes = {auto_center = true},
            children = {
                {
                    -- Header bar of the GUI.
                    type = "flow",
                    direction = "horizontal",
                    style = MuppetStyles.flow.horizontal.marginTL,
                    styling = {horizontal_align = "left", right_padding = 4},
                    children = {
                        {
                            descriptiveName = "pt_title",
                            type = "label",
                            style = MuppetStyles.label.heading.large.bold_paddingSides,
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
                            style = MuppetStyles.flow.horizontal.spaced,
                            styling = {horizontal_align = "right", top_margin = 4},
                            children = {
                                {
                                    descriptiveName = "pt_closeButton",
                                    type = "sprite-button",
                                    tooltip = "self",
                                    sprite = "utility/close_white",
                                    style = MuppetStyles.spriteButton.frameCloseButtonClickable,
                                    registerClick = {actionName = "PortalTunnelGui.On_CloseButtonClicked", data = {portalPart = portalPart}}
                                }
                            }
                        }
                    }
                }
            }
        }
    )
    local mainGuiElement = createdElements["railway_tunnel-pt_main-frame"]

    -- The GUI part for a single portal being shown for incomplete tunnel or smaller.
    if tunnel == nil then
        -- Have to calculate these carefully as functions in template are always called even if not enabled. So pass strings in for these.
        local thisPortalTrainLengthCarriages, thisPortalTrainLengthTiles
        if thisPortal ~= nil then
            thisPortalTrainLengthTiles = thisPortal.trainWaitingAreaTilesLength
            thisPortalTrainLengthCarriages = PortalTunnelGui.GetMaxTrainLengthInCarriages(thisPortalTrainLengthTiles)
        else
            -- These will never be seen as the element won't be added.
            thisPortalTrainLengthTiles = ""
            thisPortalTrainLengthCarriages = ""
        end

        -- Add the elements.
        GuiUtil.AddElement(
            {
                parent = mainGuiElement,
                type = "frame",
                direction = "vertical",
                style = MuppetStyles.frame.content_shadowSunken.marginTL_paddingBR,
                styling = {horizontally_stretchable = true},
                children = {
                    {
                        type = "flow",
                        direction = "vertical",
                        style = MuppetStyles.flow.vertical.marginTL_spaced,
                        children = {
                            {
                                descriptiveName = "pt_portal_title",
                                type = "label",
                                style = MuppetStyles.label.heading.medium.bold,
                                caption = "self"
                            },
                            {
                                descriptiveName = "pt_portal_state",
                                type = "label",
                                style = MuppetStyles.label.text.medium.plain,
                                caption = {"self", portalState}
                            },
                            {
                                -- For when there is a portal.
                                exclude = thisPortal == nil,
                                descriptiveName = "pt_train_length",
                                type = "label",
                                style = MuppetStyles.label.text.medium.plain,
                                caption = {"self", thisPortalTrainLengthCarriages, thisPortalTrainLengthTiles},
                                tooltip = "self",
                                attributes = {}
                            }
                        }
                    }
                }
            }
        )
    end

    -- The GUI part for a tunnel being shown with 2 portals.
    if tunnel ~= nil then
        -- Work out portal A and B details. A is left of GUI, B is right.
        ---@typelist Portal, Portal, string, string, string, string
        local portalA, portalB, portalAOrientationText, portalBOrientationText, portalASelectedText, portalBSelectedText
        local portal1, portal2 = thisPortal.tunnel.portals[1], thisPortal.tunnel.portals[2]
        if portal1.leavingDirection == defines.direction.north or portal1.leavingDirection == defines.direction.west then
            portalA = portal1
            portalAOrientationText = {"gui-caption.railway_tunnel-" .. Utils.DirectionValueToName[portal1.leavingDirection] .. "-capital"}
            portalB = portal2
            portalBOrientationText = {"gui-caption.railway_tunnel-" .. Utils.DirectionValueToName[portal2.leavingDirection] .. "-capital"}
        else
            portalA = portal2
            portalAOrientationText = {"gui-caption.railway_tunnel-" .. Utils.DirectionValueToName[portal2.leavingDirection] .. "-capital"}
            portalB = portal1
            portalBOrientationText = {"gui-caption.railway_tunnel-" .. Utils.DirectionValueToName[portal1.leavingDirection] .. "-capital"}
        end
        if thisPortal.id == portalA.id then
            portalASelectedText = {"gui-caption.railway_tunnel-selected-capital-brackets"}
            portalBSelectedText = ""
        else
            portalASelectedText = ""
            portalBSelectedText = {"gui-caption.railway_tunnel-selected-capital-brackets"}
        end

        -- Work out tunnel usage details.
        local tunnelUsageStateText, trainGuiButton_clickEnabled, trainGuiButton_tooltip
        local managedTrain = tunnel.managedTrain
        if managedTrain == nil or managedTrain.tunnelUsageState == Common.TunnelUsageState.finished then
            tunnelUsageStateText = {"gui-caption.railway_tunnel-train_usage_state-none"}
            trainGuiButton_clickEnabled = false
            trainGuiButton_tooltip = {"gui-tooltip.railway_tunnel-pt_open_train_gui_button-none"}
        elseif managedTrain.tunnelUsageState == Common.TunnelUsageState.approaching or managedTrain.tunnelUsageState == Common.TunnelUsageState.portalTrack then
            tunnelUsageStateText = {"gui-caption.railway_tunnel-train_usage_state-entering"}
            trainGuiButton_clickEnabled = true
            trainGuiButton_tooltip = {"gui-tooltip.railway_tunnel-pt_open_train_gui_button-enabled"}
        elseif managedTrain.tunnelUsageState == Common.TunnelUsageState.underground then
            tunnelUsageStateText = {"gui-caption.railway_tunnel-train_usage_state-underground"}
            trainGuiButton_clickEnabled = false
            trainGuiButton_tooltip = {"gui-tooltip.railway_tunnel-pt_open_train_gui_button-underground"}
        elseif managedTrain.tunnelUsageState == Common.TunnelUsageState.leaving then
            tunnelUsageStateText = {"gui-caption.railway_tunnel-train_usage_state-leaving"}
            trainGuiButton_clickEnabled = true
            trainGuiButton_tooltip = {"gui-tooltip.railway_tunnel-pt_open_train_gui_button-enabled"}
        else
            error("PortalTunnelGui.MakeGui() recieved unrecognised ManagedTrain.tunnelUsageState: " .. tostring(managedTrain.tunnelUsageState))
        end

        -- Tunnel and inner Portals.
        GuiUtil.AddElement(
            {
                parent = mainGuiElement,
                type = "frame",
                direction = "vertical",
                style = MuppetStyles.frame.content_shadowSunken.marginTL_paddingBR,
                styling = {horizontally_stretchable = true},
                children = {
                    {
                        -- Tunnel Details
                        type = "flow",
                        direction = "vertical",
                        style = MuppetStyles.flow.vertical.marginTL_spaced,
                        children = {
                            {
                                descriptiveName = "pt_tunnel_title",
                                type = "label",
                                style = MuppetStyles.label.heading.medium.bold,
                                caption = "self"
                            },
                            {
                                descriptiveName = "pt_train_length",
                                type = "label",
                                style = MuppetStyles.label.text.medium.plain,
                                caption = {"self", PortalTunnelGui.GetMaxTrainLengthInCarriages(tunnel.maxTrainLengthTiles), tunnel.maxTrainLengthTiles},
                                tooltip = "self"
                            }
                        }
                    },
                    {
                        -- Portal container.
                        type = "flow",
                        direction = "horizontal",
                        style = MuppetStyles.flow.horizontal.marginTL_spaced,
                        children = {
                            {
                                -- Portal 1.
                                type = "frame",
                                direction = "vertical",
                                style = MuppetStyles.frame.contentInnerDark_shadowSunken.paddingBR,
                                children = {
                                    {
                                        type = "flow",
                                        direction = "vertical",
                                        style = MuppetStyles.flow.vertical.marginTL_spaced,
                                        children = {
                                            {
                                                descriptiveName = "pt_portal_direction",
                                                type = "label",
                                                style = MuppetStyles.label.heading.medium.plain,
                                                caption = {"self", portalAOrientationText, portalASelectedText}
                                            },
                                            {
                                                descriptiveName = "pt_train_length",
                                                type = "label",
                                                style = MuppetStyles.label.text.medium.plain,
                                                caption = {"self", PortalTunnelGui.GetMaxTrainLengthInCarriages(portalA.trainWaitingAreaTilesLength), portalA.trainWaitingAreaTilesLength},
                                                tooltip = "self"
                                            }
                                        }
                                    }
                                }
                            },
                            {
                                -- Portal 2.
                                type = "frame",
                                direction = "vertical",
                                style = MuppetStyles.frame.contentInnerDark_shadowSunken.paddingBR,
                                children = {
                                    {
                                        type = "flow",
                                        direction = "vertical",
                                        style = MuppetStyles.flow.vertical.marginTL_spaced,
                                        children = {
                                            {
                                                descriptiveName = "pt_portal_direction",
                                                type = "label",
                                                style = MuppetStyles.label.heading.medium.plain,
                                                caption = {"self", portalBOrientationText, portalBSelectedText}
                                            },
                                            {
                                                descriptiveName = "pt_train_length",
                                                type = "label",
                                                style = MuppetStyles.label.text.medium.plain,
                                                caption = {"self", PortalTunnelGui.GetMaxTrainLengthInCarriages(portalB.trainWaitingAreaTilesLength), portalB.trainWaitingAreaTilesLength},
                                                tooltip = "self"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    {
                        -- Tunnel usage and train manipulation.
                        parent = mainGuiElement,
                        type = "frame",
                        direction = "vertical",
                        style = MuppetStyles.frame.contentInnerDark_shadowSunken.marginTL_paddingBR,
                        styling = {horizontally_stretchable = true},
                        children = {
                            {
                                type = "flow",
                                direction = "vertical",
                                style = MuppetStyles.flow.vertical.marginTL_spaced,
                                children = {
                                    {
                                        descriptiveName = "pt_train_usage_title",
                                        type = "label",
                                        style = MuppetStyles.label.heading.medium.plain,
                                        caption = "self"
                                    },
                                    {
                                        type = "flow",
                                        direction = "horizontal",
                                        style = MuppetStyles.flow.horizontal.spaced,
                                        children = {
                                            {
                                                descriptiveName = "pt_train_usage_state",
                                                type = "label",
                                                style = MuppetStyles.label.text.medium.plain,
                                                caption = {"self", tunnelUsageStateText}
                                            },
                                            {
                                                descriptiveName = "pt_open_train_gui_button",
                                                type = "sprite-button",
                                                style = MuppetStyles.spriteButton.smallText,
                                                sprite = "entity.locomotive",
                                                registerClick = {actionName = "PortalTunnelGui.On_OpenTrainGuiClicked", data = {player = player, managedTrain = managedTrain}},
                                                enabled = trainGuiButton_clickEnabled,
                                                tooltip = trainGuiButton_tooltip,
                                                styling = {left_margin = 4, top_margin = -2}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        )
    end
end

--- Called to close the GUI and update the open GUI tracking.
---@param playerIndex Id
---@param portalPart? PortalPart|null @ If provided then the PortalPart has its open GUIs updates and this bleeds through the portal/tunnel structure.
PortalTunnelGui.CloseGui = function(playerIndex, portalPart)
    if portalPart ~= nil then
        -- Tell the portal part which will propigate up to the tunnel.
        MOD.Interfaces.Portal.GuiClosedOnPortalPart(portalPart, playerIndex)
    end

    -- Remove the backwards lookup from global.
    global.portalTunnelGui.portalPartOpenByPlayer[playerIndex] = nil

    -- Close and destroy all the Gui Element's for this overall GUI on screen.
    GuiUtil.DestroyPlayersReferenceStorage(playerIndex, "portalTunnelGui")
end

--- When the player clicks the close button on their GUI.
---@param event UtilityGuiActionsClick_ActionData
PortalTunnelGui.On_CloseButtonClicked = function(event)
    PortalTunnelGui.CloseGui(event.playerIndex, event.data.portalPart)
end

--- Called by the Portal class when a change has occured to the portal part of one of its parents that the GUI needs to react to.
--- Currently we just recreate the GUI as its the easiest and this will be a very rare event.
---@param portalPart PortalPart
---@param playerIndex Id
---@param player LuaPlayer
---@param partRemoved boolean @ If the part has been removed and thus the GUI should be closed.
PortalTunnelGui.On_PortalPartChanged = function(portalPart, playerIndex, player, partRemoved)
    -- TODO: not  tested through all usage cases.
    -- TODO: this didn't work right when I had a second portal GUI open and mined a first portal's part. As the second portal's GUI closed.
    if partRemoved then
        -- Part removed so just close the GUI. No need to update the PortalPart object as its gone.
        PortalTunnelGui.CloseGui(playerIndex, nil)
        return
    end

    -- Redraw the GUI so it accounts for whatever change has occured.
    -- Just close the open GUI, don;t update the PortalPart about it being watched as we will still be afterwards.
    PortalTunnelGui.CloseGui(playerIndex, nil)
    PortalTunnelGui.MakeGui(portalPart, player, playerIndex)
end

--- Called when the usage state of the tunnel changes by the TrainManager class.
---@param managedTrain ManagedTrain
PortalTunnelGui.On_TunnelUsageChanged = function(managedTrain)
    -- TODO: not tested through all usage cases.
    for playerIndex in pairs(managedTrain.tunnel.guiOpenedByPlayers) do
        --TODO: remove the status section of the GUI and re-create it.
    end
end

--- Gets the max train length in whole carriages for a tile length. Assumes carriages are 6 long with 1 connecting gap.
---@param tiles uint
---@return uint fullCarriages
PortalTunnelGui.GetMaxTrainLengthInCarriages = function(tiles)
    local fullCarriages = math.floor(tiles / 7)
    -- If theres 6 tiles left then the last carraige can fit in that as it doens't need a connection onwards.
    if tiles - (fullCarriages * 7) >= 6 then
        fullCarriages = fullCarriages + 1
    end
    return fullCarriages
end

--- Called when a player with the a tunnel GUI open clicks the train icon for a train using the tunnel.
---@param event UtilityGuiActionsClick_ActionData
PortalTunnelGui.On_OpenTrainGuiClicked = function(event)
    local managedTrain = event.data.managedTrain ---@type ManagedTrain
    local player = event.data.player ---@type LuaPlayer

    local train  ---@type LuaTrain
    if managedTrain.portalTrackTrain ~= nil then
        train = managedTrain.portalTrackTrain
    elseif managedTrain.approachingTrain ~= nil then
        train = managedTrain.approachingTrain
    elseif managedTrain.leavingTrain ~= nil then
        train = managedTrain.leavingTrain
    else
        error("PortalTunnelGui.On_OpenTrainGuiClicked() called when train wasn't in suitable state for its GUI to be opened.")
    end
    player.opened = train.front_stock
end

return PortalTunnelGui
