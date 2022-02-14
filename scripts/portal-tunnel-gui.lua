local Events = require("utility.events")
local PortalTunnelGui = {}
local Common = require("scripts.common")
local GuiUtil = require("utility.gui-util")
local GuiActionsClick = require("utility.gui-actions-click")
local Utils = require("utility.utils")
local MuppetStyles = require("utility.style-data").MuppetStyles
local EventScheduler = require("utility.event-scheduler")

local TrainFuelChestCheckTicks = 15

PortalTunnelGui.CreateGlobals = function()
    global.portalTunnelGui = global.portalTunnelGui or {}
    global.portalTunnelGui.portalPartOpenByPlayer = global.portalTunnelGui.portalPartOpenByPlayer or {} ---@type table<Id, PortalPart> @ A list of each palyer with a portal GUI open and which PortalPart it is. For reverse lookup of PortalPart by player.
    global.portalTunnelGui.lastFuelChestId = global.portalTunnelGui.lastFuelChestId or 0 ---@type uint
end

PortalTunnelGui.OnLoad = function()
    Events.RegisterHandlerCustomInput("railway_tunnel-open_gui", "PortalTunnelGui.On_OpenGuiInput", PortalTunnelGui.On_OpenGuiInput)
    GuiActionsClick.LinkGuiClickActionNameToFunction("PortalTunnelGui.On_CloseButtonClicked", PortalTunnelGui.On_CloseButtonClicked)
    GuiActionsClick.LinkGuiClickActionNameToFunction("PortalTunnelGui.On_OpenTrainGuiClicked", PortalTunnelGui.On_OpenTrainGuiClicked)
    GuiActionsClick.LinkGuiClickActionNameToFunction("PortalTunnelGui.On_OpenAddFuelInventoryClicked", PortalTunnelGui.On_OpenAddFuelInventoryClicked)
    EventScheduler.RegisterScheduledEventType("PortalTunnelGui.Scheduled_TrackTrainFuelChestGui", PortalTunnelGui.Scheduled_TrackTrainFuelChestGui)

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
            styling = {natural_width = 650}, -- Width to have some padding on the tunnel's 2 portal train lengths.
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
        local tunnelUsageStateText, trainGuiButton_clickEnabled, trainGuiButton_tooltip, trainFuel_tooltip, trainFuel_clickEnabled
        local managedTrain = tunnel.managedTrain
        if managedTrain == nil or managedTrain.tunnelUsageState == Common.TunnelUsageState.finished then
            tunnelUsageStateText = {"gui-caption.railway_tunnel-train_usage_state-none"}
            trainGuiButton_clickEnabled = false
            trainGuiButton_tooltip = {"gui-tooltip.railway_tunnel-pt_open_train_gui-none"}
            trainFuel_clickEnabled = false
            trainFuel_tooltip = {"gui-tooltip.railway_tunnel-pt_open_add_fuel_inventory-none"}
        elseif managedTrain.tunnelUsageState == Common.TunnelUsageState.approaching or managedTrain.tunnelUsageState == Common.TunnelUsageState.portalTrack then
            tunnelUsageStateText = {"gui-caption.railway_tunnel-train_usage_state-entering"}
            trainGuiButton_clickEnabled = true
            trainGuiButton_tooltip = {"gui-tooltip.railway_tunnel-pt_open_train_gui-enabled"}
            trainFuel_clickEnabled = true
            trainFuel_tooltip = {"gui-tooltip.railway_tunnel-pt_open_add_fuel_inventory-enabled"}
        elseif managedTrain.tunnelUsageState == Common.TunnelUsageState.underground then
            tunnelUsageStateText = {"gui-caption.railway_tunnel-train_usage_state-underground"}
            trainGuiButton_clickEnabled = false
            trainGuiButton_tooltip = {"gui-tooltip.railway_tunnel-pt_open_train_gui-underground"}
            trainFuel_clickEnabled = true
            trainFuel_tooltip = {"gui-tooltip.railway_tunnel-pt_open_add_fuel_inventory-enabled"}
        elseif managedTrain.tunnelUsageState == Common.TunnelUsageState.leaving then
            tunnelUsageStateText = {"gui-caption.railway_tunnel-train_usage_state-leaving"}
            trainGuiButton_clickEnabled = true
            trainGuiButton_tooltip = {"gui-tooltip.railway_tunnel-pt_open_train_gui-enabled"}
            trainFuel_clickEnabled = true
            trainFuel_tooltip = {"gui-tooltip.railway_tunnel-pt_open_add_fuel_inventory-enabled"}
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
                                styling = {horizontally_stretchable = true},
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
                                styling = {horizontally_stretchable = true},
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
                                                descriptiveName = "pt_open_train_gui",
                                                type = "sprite-button",
                                                style = MuppetStyles.spriteButton.smallText,
                                                sprite = "entity.locomotive",
                                                registerClick = {actionName = "PortalTunnelGui.On_OpenTrainGuiClicked", data = {player = player, managedTrain = managedTrain}},
                                                enabled = trainGuiButton_clickEnabled,
                                                tooltip = trainGuiButton_tooltip,
                                                styling = {left_margin = 4, top_margin = -2}
                                            }
                                        }
                                    },
                                    {
                                        type = "flow",
                                        direction = "horizontal",
                                        style = MuppetStyles.flow.horizontal.spaced,
                                        children = {
                                            {
                                                descriptiveName = "pt_open_add_fuel_inventory",
                                                type = "button",
                                                style = MuppetStyles.button.text.medium.paddingSides,
                                                caption = "self",
                                                tooltip = trainFuel_tooltip,
                                                registerClick = {actionName = "PortalTunnelGui.On_OpenAddFuelInventoryClicked", data = {player = player, managedTrain = managedTrain}},
                                                enabled = trainFuel_clickEnabled
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
---@param portalPart PortalPart @ The PortalPart that had its open GUI is updated and this bleeds through the portal/tunnel structure.
PortalTunnelGui.CloseGuiAndUpdatePortalPart = function(playerIndex, portalPart)
    -- Tell the portal part which will propigate up to the tunnel.
    MOD.Interfaces.Portal.GuiClosedOnPortalPart(portalPart, playerIndex)

    -- Remove the backwards lookup from global.
    global.portalTunnelGui.portalPartOpenByPlayer[playerIndex] = nil

    -- Close and destroy all the Gui Element's for this overall GUI on screen.
    GuiUtil.DestroyPlayersReferenceStorage(playerIndex, "portalTunnelGui")
end

--- Called to destroy the GUI and forget it was open, but updating is done to the portal part.
---@param playerIndex Id
PortalTunnelGui.CloseGuiAndForetPortalPart = function(playerIndex)
    -- Remove the backwards lookup from global.
    global.portalTunnelGui.portalPartOpenByPlayer[playerIndex] = nil

    -- Close and destroy all the Gui Element's for this overall GUI on screen.
    GuiUtil.DestroyPlayersReferenceStorage(playerIndex, "portalTunnelGui")
end

--- Called to only destroy the GUI.
---@param playerIndex Id
PortalTunnelGui.CloseGuiOnly = function(playerIndex)
    -- Close and destroy all the Gui Element's for this overall GUI on screen.
    GuiUtil.DestroyPlayersReferenceStorage(playerIndex, "portalTunnelGui")
end

--- When the player clicks the close button on their GUI.
---@param event UtilityGuiActionsClick_ActionData
PortalTunnelGui.On_CloseButtonClicked = function(event)
    PortalTunnelGui.CloseGuiAndUpdatePortalPart(event.playerIndex, event.data.portalPart)
end

--- Called by the Portal class when a change has occured to the portal part of one of its parents that the GUI needs to react to.
--- Currently we just recreate the GUI as its the easiest and this will be a very rare event.
---@param portalPart PortalPart
---@param playerIndex Id
---@param player LuaPlayer
---@param partRemoved boolean @ If the part has been removed and thus the GUI should be closed.
PortalTunnelGui.On_PortalPartChanged = function(portalPart, playerIndex, player, partRemoved)
    -- TODO: not tested through all usage cases.
    -- TODO: this didn't work right when I had a second portal GUI open and mined a first portal's part. As the second portal's GUI closed.
    if partRemoved then
        -- Part removed so just close the GUI. No need to update the PortalPart object as its gone.
        PortalTunnelGui.CloseGuiAndForetPortalPart(playerIndex)
        return
    end

    -- Re-draw the GUI so it accounts for whatever change has occured. Lazy approach, but low freqency and concurrency.
    -- Just close the open GUI, don't update the PortalPart or the global cache of what the player is watching as we will just open the GUI straight back up afterwards.
    PortalTunnelGui.CloseGuiOnly(playerIndex)
    PortalTunnelGui.MakeGui(portalPart, player, playerIndex)
end

--- Called when the usage state of the tunnel changes by the TrainManager class.
---@param managedTrain ManagedTrain
PortalTunnelGui.On_TunnelUsageChanged = function(managedTrain)
    for playerIndex, player in pairs(managedTrain.tunnel.guiOpenedByPlayers) do
        -- Re-draw the GUI so it accounts for whatever change has occured. Lazy approach, but low freqency and concurrency.
        -- Just close the open GUI, don't update the PortalPart or the global cache of what the player is watching as we will just open the GUI straight back up afterwards.
        local portalPart = global.portalTunnelGui.portalPartOpenByPlayer[playerIndex]
        PortalTunnelGui.CloseGuiOnly(playerIndex)
        PortalTunnelGui.MakeGui(portalPart, player, playerIndex)
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

    local train = MOD.Interfaces.TrainManager.GetCurrentTrain(managedTrain)
    player.opened = train.front_stock
end

--- Called when a player with the a tunnel GUI open clicks the button to add fuel to the train using the tunnel.
---@param event UtilityGuiActionsClick_ActionData
PortalTunnelGui.On_OpenAddFuelInventoryClicked = function(event)
    local managedTrain = event.data.managedTrain ---@type ManagedTrain
    local player = event.data.player ---@type LuaPlayer

    -- Create a chest for the fuel to go in to. Its hidden graphics layer so fine.
    local blockedPortalEnd = managedTrain.entrancePortal.blockedPortalEnd
    local fuelChest = blockedPortalEnd.surface.create_entity {name = "railway_tunnel-tunnel_fuel_chest", force = global.force.tunnelForce, position = blockedPortalEnd.entity_position}
    fuelChest.destructible = false

    -- Open the chest to the player
    player.opened = fuelChest

    -- Schedule the check of the chest and player's open GUIs.
    global.portalTunnelGui.lastFuelChestId = global.portalTunnelGui.lastFuelChestId + 1
    EventScheduler.ScheduleEventOnce(event.eventData.tick + TrainFuelChestCheckTicks, "PortalTunnelGui.Scheduled_TrackTrainFuelChestGui", global.portalTunnelGui.lastFuelChestId, {player = player, fuelChest = fuelChest, managedTrain = managedTrain})
end

--- Called frequently while the player has a train fuel chest open. Checks states and moves any fuel across thats been put in the fuel chest.
---@param event UtilityScheduledEvent_CallbackObject
PortalTunnelGui.Scheduled_TrackTrainFuelChestGui = function(event)
    local managedTrain = event.data.managedTrain ---@type ManagedTrain
    local player = event.data.player ---@type LuaPlayer
    local fuelChest = event.data.fuelChest ---@type LuaEntity

    -- If theres no managed train any more then close everything.
    if managedTrain.tunnelUsageState == Common.TunnelUsageState.finished then
        PortalTunnelGui.RemoveTrainFuelChest(fuelChest, player)
        return
    end

    -- Move across any fuel in the chest across all locomotives.
    local fuelChestInventory = fuelChest.get_inventory(defines.inventory.chest)
    if not fuelChestInventory.is_empty() then
        -- Start with all loco's.
        local locoCountTakingFuel = managedTrain.trainCachedData.forwardFacingLocomotiveCount + managedTrain.trainCachedData.backwardFacingLocomotiveCount
        local reminingLocoCountTakingFuel = locoCountTakingFuel

        -- While there is still fuel to distribute keep on looping over the fuel we have between the locomotives taht are taking fuel.
        -- If no locomotive takes any fuel then stop trying.
        while not fuelChestInventory.is_empty() do
            locoCountTakingFuel = 0
            for _, carriageData in pairs(managedTrain.trainCachedData.carriagesCachedData) do
                if carriageData.prototypeType == "locomotive" then
                    local thisLocoRatio = 1 / reminingLocoCountTakingFuel
                    reminingLocoCountTakingFuel = reminingLocoCountTakingFuel - 1
                    local burner = carriageData.entity.burner
                    if burner ~= nil then
                        local burnerInventory = burner.inventory
                        if burnerInventory ~= nil then
                            local _, someFuelTaken = Utils.TryMoveInventoriesLuaItemStacks(fuelChestInventory, burnerInventory, false, thisLocoRatio)
                            if someFuelTaken then
                                locoCountTakingFuel = locoCountTakingFuel + 1
                            end
                        end
                    end
                end
            end

            -- If no locomotives took any fuel this pass then stop checking.
            if locoCountTakingFuel == 0 then
                break
            end

            -- Reset totoal loco count taking fuel for next cycle.
            reminingLocoCountTakingFuel = locoCountTakingFuel
        end
    end

    -- If the inventory is still open to the player then schedule the next check, otherwise close everything.
    if player.opened == fuelChest then
        global.portalTunnelGui.lastFuelChestId = global.portalTunnelGui.lastFuelChestId + 1
        EventScheduler.ScheduleEventOnce(event.tick + TrainFuelChestCheckTicks, "PortalTunnelGui.Scheduled_TrackTrainFuelChestGui", global.portalTunnelGui.lastFuelChestId, event.data)
    else
        PortalTunnelGui.RemoveTrainFuelChest(fuelChest, player)
    end
end

--- Called when a trian fuel chest should be removed. Returns any items in it back to the player.
---@param fuelChest LuaEntity
---@param player LuaPlayer
PortalTunnelGui.RemoveTrainFuelChest = function(fuelChest, player)
    -- Move anything left in the fuel chest back to the player, just spilling the rest on the ground.
    local playerInventory = player.get_main_inventory()
    local fuelChest_inventory = fuelChest.get_inventory(defines.inventory.chest)
    if not fuelChest_inventory.is_empty() then
        if playerInventory ~= nil then
            Utils.TryMoveInventoriesLuaItemStacks(fuelChest_inventory, playerInventory, true, 1)
        elseif fuelChest_inventory ~= nil then
            for index = 1, #fuelChest_inventory do
                local itemStack = fuelChest_inventory[index]
                if itemStack.valid_for_read then
                    player.surface.spill_item_stack(player.position, {name = itemStack.name, count = itemStack.count}, true, player.force, false)
                end
            end
        end
    end

    -- Destroy the fuelChest, which will close the player GUI if still open and will be empty of items at this point.
    fuelChest.destroy {raise_destroy = false}
end

return PortalTunnelGui
