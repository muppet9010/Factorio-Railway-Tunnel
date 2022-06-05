local MiscUtils = require("utility.misc-utils")
local Colors = require("utility.colors")
local EventScheduler = require("utility.event-scheduler")
local PlayerAlerts = require("utility.player-alerts")
local Events = require("utility.events")
local Common = require("scripts.common")
local TunnelShared = {}

---@class PlayersFakePartTracking
---@field playerId Id
---@field player LuaPlayer
---@field realItemInInventoryName string
---@field fakeItemInCursorName string
---@field cursorCount uint

TunnelShared.CreateGlobals = function()
    global.tunnelShared = global.tunnelShared or {}
    global.tunnelShared.playersFakePartTracking = global.tunnelShared.playersFakePartTracking or {} ---@type table<Id, PlayersFakePartTracking>
end

TunnelShared.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("TunnelShared.SetTrainToManual_Scheduled", TunnelShared.SetTrainToManual_Scheduled)
    EventScheduler.RegisterScheduledEventType("TunnelShared.CheckIfAlertingTrainStillStopped_Scheduled", TunnelShared.CheckIfAlertingTrainStillStopped_Scheduled)

    -------------------------------------------------------------------------------------
    -- Shared event handlers to reduce duplicated relevence checking across many modules.
    -------------------------------------------------------------------------------------

    -- OnBuiltEntity type events
    ----------------------------
    local onBuiltEntityFilter = {}
    -- Portal
    for _, name in pairs(Common.PortalEndAndSegmentEntityNames) do
        table.insert(onBuiltEntityFilter, {filter = "name", name = name})
    end
    for _, name in pairs(Common.PortalEndAndSegmentEntityNames) do
        table.insert(onBuiltEntityFilter, {filter = "ghost_name", name = name})
    end
    -- Underground
    for _, name in pairs(Common.UndergroundSegmentEntityNames) do
        table.insert(onBuiltEntityFilter, {filter = "name", name = name})
    end
    for _, name in pairs(Common.UndergroundSegmentEntityNames) do
        table.insert(onBuiltEntityFilter, {filter = "ghost_name", name = name})
    end
    -- Tunnel
    table.insert(onBuiltEntityFilter, {filter = "rolling-stock"}) -- Just gets real entities, not ghosts.
    table.insert(onBuiltEntityFilter, {filter = "ghost_type", type = "locomotive"})
    table.insert(onBuiltEntityFilter, {filter = "ghost_type", type = "cargo-wagon"})
    table.insert(onBuiltEntityFilter, {filter = "ghost_type", type = "fluid-wagon"})
    table.insert(onBuiltEntityFilter, {filter = "ghost_type", type = "artillery-wagon"})
    -- Register Events
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "TunnelShared.OnBuiltEntity", TunnelShared.OnBuiltEntity, onBuiltEntityFilter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "TunnelShared.OnBuiltEntity", TunnelShared.OnBuiltEntity, onBuiltEntityFilter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "TunnelShared.OnBuiltEntity", TunnelShared.OnBuiltEntity, onBuiltEntityFilter)
    Events.RegisterHandlerEvent(defines.events.script_raised_revive, "TunnelShared.OnBuiltEntity", TunnelShared.OnBuiltEntity, onBuiltEntityFilter)

    -- OnDiedEntity type events
    ----------------------------
    local onDiedEntityFilter = {}
    -- Portal
    for _, name in pairs(Common.PortalEndAndSegmentEntityNames) do
        table.insert(onDiedEntityFilter, {filter = "name", name = name})
    end
    table.insert(onDiedEntityFilter, {filter = "name", name = "railway_tunnel-portal_entry_train_detector_1x1"})
    table.insert(onDiedEntityFilter, {filter = "name", name = "railway_tunnel-portal_transition_train_detector_1x1"})
    -- Underground
    for _, name in pairs(Common.UndergroundSegmentEntityNames) do
        table.insert(onDiedEntityFilter, {filter = "name", name = name})
    end
    -- Train Cached Data
    for _, rollingStockType in pairs(Common.RollingStockTypes) do
        table.insert(onDiedEntityFilter, {filter = "type", type = rollingStockType})
    end
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "TunnelShared.OnDiedEntity", TunnelShared.OnDiedEntity, onDiedEntityFilter)
    Events.RegisterHandlerEvent(defines.events.script_raised_destroy, "TunnelShared.OnDiedEntity", TunnelShared.OnDiedEntity, onDiedEntityFilter)

    -- OnDiedEntity type events
    ----------------------------
    local onPreMinedEntityFilter = {}
    -- Portal
    for _, name in pairs(Common.PortalEndAndSegmentEntityNames) do
        table.insert(onPreMinedEntityFilter, {filter = "name", name = name})
    end
    -- Underground
    for _, name in pairs(Common.UndergroundSegmentEntityNames) do
        table.insert(onPreMinedEntityFilter, {filter = "name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_pre_player_mined_item, "TunnelShared.OnPreMinedEntity", TunnelShared.OnPreMinedEntity, onPreMinedEntityFilter)
    Events.RegisterHandlerEvent(defines.events.on_robot_pre_mined, "TunnelShared.OnPreMinedEntity", TunnelShared.OnPreMinedEntity, onPreMinedEntityFilter)

    -------------------------------------------------------------------------------------
    -- END Shared event handlers
    -------------------------------------------------------------------------------------

    Events.RegisterHandlerCustomInput("railway_tunnel-flip_blueprint_horizontal", "TunnelShared.OnFlipBlueprintHorizontalInput", TunnelShared.OnFlipBlueprintHorizontalInput)
    Events.RegisterHandlerCustomInput("railway_tunnel-flip_blueprint_vertical", "TunnelShared.OnFlipBlueprintVerticalInput", TunnelShared.OnFlipBlueprintVerticalInput)
    EventScheduler.RegisterScheduledEventType("TunnelShared.TrackingPlayersRealToFakeItemCount_Scheduled", TunnelShared.TrackingPlayersRealToFakeItemCount_Scheduled)
    Events.RegisterHandlerEvent(defines.events.on_player_pipette, "TunnelShared.OnSmartPipette", TunnelShared.OnSmartPipette)
end

--- Checks if an entity is on the rail grid based on its type. As some entities are centered off rail grid.
---@param builtEntity LuaEntity
---@param entityType string @ The entity or ghost type.
---@return boolean
TunnelShared.IsPlacementOnRailGrid = function(builtEntity, entityType)
    local builtEntity_position = builtEntity.position

    if Common.RailGridCenteredTunnelParts[entityType] ~= nil then
        -- Should be placed on the rail grid.
        if builtEntity_position.x % 2 == 0 or builtEntity_position.y % 2 == 0 then
            return false
        else
            return true
        end
    else
        -- Is built off the rail grid so the connection points are on the grid.

        -- Get the grid requirements for the direction of the entity. Both the curved and diagonal parts have the same requirements.
        local xOnGrid, yOnGrid
        local builtEntity_direction = builtEntity.direction
        if builtEntity_direction == defines.direction.north or builtEntity_direction == defines.direction.south then
            xOnGrid = false
            yOnGrid = true
        else
            xOnGrid = true
            yOnGrid = false
        end

        -- Check if the on grid placement matches expected.
        if builtEntity_position.x % 2 == 0 ~= not xOnGrid then
            return false
        elseif builtEntity_position.y % 2 == 0 ~= not yOnGrid then
            return false
        else
            return true
        end
    end
end

---@param builtEntity LuaEntity
---@param placer EntityActioner
---@param mine boolean @ If to mine and return the item to the placer, or just destroy it.
TunnelShared.UndoInvalidTunnelPartPlacement = function(builtEntity, placer, mine)
    TunnelShared.UndoInvalidPlacement(builtEntity, placer, mine, true, {"message.railway_tunnel-tunnel_part_must_be_on_rail_grid"}, "tunnel part")
end

---@param builtEntity LuaEntity
---@param placer EntityActioner
---@param mine boolean @ If to mine and return the item to the placer, or just destroy it.
---@param highlightValidRailGridPositions boolean @ If to show to the placer valid positions on the rail grid.
---@param warningMessageText LocalisedString @ Text shown to the placer
---@param errorEntityNameText string @ Entity name shown if the process errors.
TunnelShared.UndoInvalidPlacement = function(builtEntity, placer, mine, highlightValidRailGridPositions, warningMessageText, errorEntityNameText)
    if placer ~= nil then
        local position, surface, entityName, ghostName, direction = builtEntity.position, builtEntity.surface, builtEntity.name, nil, builtEntity.direction
        if entityName == "entity-ghost" then
            ghostName = builtEntity.ghost_name
        end
        TunnelShared.EntityErrorMessage(placer, warningMessageText, surface, position)
        if mine then
            local result
            if placer.is_player() then
                result = placer.mine_entity(builtEntity, true)
            else
                -- Is construction bot
                result = builtEntity.mine({inventory = placer.get_inventory(defines.inventory.robot_cargo), force = true, raise_destroyed = false, ignore_minable = true})
            end
            if result ~= true then
                error("couldn't mine invalidly placed " .. errorEntityNameText .. " entity")
            end
        else
            builtEntity.destroy {raise_destroy = false}
        end
        if highlightValidRailGridPositions then
            TunnelShared.HighlightValidPlacementPositionsOnRailGrid(placer, position, surface, entityName, ghostName, direction)
        end
    else
        local builtEntity_position = builtEntity.position
        builtEntity.destroy {raise_destroy = false}
        game.print({"message.railway_tunnel-invalid_placement_by_script", errorEntityNameText, tostring(builtEntity_position.x), tostring(builtEntity_position.y)}, Colors.red)
    end
end

--- Highlights the single tiles to the placer player/force that are valid centres for an entity on the rail grid based on the tunnel part being built (as some are built partially off grid).
---@param placer EntityActioner
---@param position MapPosition
---@param surface LuaSurface
---@param entityName string
---@param ghostName string
---@param direction defines.direction @ Direction of the entity trying to be placed.
TunnelShared.HighlightValidPlacementPositionsOnRailGrid = function(placer, position, surface, entityName, ghostName, direction)
    local highlightAudiencePlayer, highlightAudienceForce = MiscUtils.GetPlayerForceFromActioner(placer)

    -- Get the minimum position from where the attempt as made and then mark out the 4 iterations from that.
    local minX, maxX, minY, maxY
    if Common.RailGridCenteredTunnelParts[ghostName or entityName] ~= nil then
        -- Should be placed on the rail grid.
        if position.x % 2 == 1 then
            -- Already on the correct X position.
            minX = position.x
            maxX = position.x
        else
            -- Was on the wrong X position.
            minX = position.x - 1
            maxX = position.x + 1
        end
        if position.y % 2 == 1 then
            -- Already on the correct Y position.
            minY = position.y
            maxY = position.y
        else
            -- Was on the wrong Y position.
            minY = position.y - 1
            maxY = position.y + 1
        end
    else
        -- Should be placed off the rail grid on the axis perpendicular to the direction.
        -- Get the grid requirements for the direction of the entity. Both the curved and diagonal parts have the same requirements.
        local xOnGrid, yOnGrid
        if direction == defines.direction.north or direction == defines.direction.south then
            xOnGrid = false
            yOnGrid = true
        else
            xOnGrid = true
            yOnGrid = false
        end

        if position.x % 2 == 1 == xOnGrid then
            -- Already on the correct X position.
            minX = position.x
            maxX = position.x
        else
            -- Was on the wrong X position.
            minX = position.x - 1
            maxX = position.x + 1
        end
        if position.y % 2 == 1 == yOnGrid then
            -- Already on the correct Y position.
            minY = position.y
            maxY = position.y
        else
            -- Was on the wrong Y position.
            minY = position.y - 1
            maxY = position.y + 1
        end
    end

    -- Draw the highlight boxes to the player/force.
    local validHighlightSprite, invalidHighlightSprite = "railway_tunnel-valid_placement_highlight", "railway_tunnel-invalid_placement_highlight"
    for x = minX, maxX, 2 do
        for y = minY, maxY, 2 do
            local thisPlacementPosition = {x = x, y = y}
            local thisHighlightSprite
            if surface.can_place_entity {name = entityName, inner_name = ghostName, position = thisPlacementPosition, direction = direction, force = placer.force, build_check_type = defines.build_check_type.manual_ghost, forced = true} then
                thisHighlightSprite = validHighlightSprite
            else
                thisHighlightSprite = invalidHighlightSprite
            end
            rendering.draw_sprite {sprite = thisHighlightSprite, target = thisPlacementPosition, surface = surface, time_to_live = 300, players = {highlightAudiencePlayer}, forces = {highlightAudienceForce}}
        end
    end
end

--- Shows warning/error text on the map to either the player (character) or the force (construction robots) doing the interaction.
---@param entityDoingInteraction EntityActioner
---@param text LocalisedString @ Text shown.
---@param surface LuaSurface
---@param position MapPosition
TunnelShared.EntityErrorMessage = function(entityDoingInteraction, text, surface, position)
    local textAudiencePlayer, textAudienceForce = MiscUtils.GetPlayerForceFromActioner(entityDoingInteraction)
    rendering.draw_text {
        text = text,
        surface = surface,
        target = position,
        time_to_live = 180,
        players = {textAudiencePlayer},
        forces = {textAudienceForce},
        color = {r = 1, g = 0, b = 0, a = 1},
        scale_with_zoom = true,
        alignment = "center",
        vertical_alignment = "bottom"
    }
end

--- Correctly stops a train when it collides with an entity. As the Factorio game engine will return a manual train upon collision the following tick. So we have to stop it this tick and set it to be manual again next tick.
---@param train LuaTrain
---@param train_id Id
---@param currentTick Tick
TunnelShared.StopTrainOnEntityCollision = function(train, train_id, currentTick)
    train.manual_mode = true
    train.speed = 0
    EventScheduler.ScheduleEventOnce(currentTick + 1, "TunnelShared.SetTrainToManual_Scheduled", train_id, {train = train})
end

--- Set the train to manual.
---@param event UtilityScheduledEvent_CallbackObject
TunnelShared.SetTrainToManual_Scheduled = function(event)
    local train = event.data.train ---@type LuaTrain
    if train.valid then
        train.manual_mode = true
    end
end

--- Train can't enter the portal so stop it, set it to manual and alert the players. This stops the train the following tick if Facotrio engine decides to restart it.
---@param train LuaTrain
---@param train_id Id
---@param alertEntity LuaEntity
---@param currentTick Tick
TunnelShared.StopTrainFromEnteringTunnel = function(train, train_id, alertEntity, currentTick, message)
    -- Stop the train now and next tick.
    TunnelShared.StopTrainOnEntityCollision(train, train_id, currentTick)
    TunnelShared.AlertOnTrain(train, train_id, alertEntity, alertEntity.force, currentTick, message)
end

--- Alerts the player to a train via onscreen text and alert icon.
---@param train LuaTrain
---@param train_id Id
---@param alertEntity LuaEntity
---@param forceToSeeAlert LuaForce
---@param currentTick Tick
TunnelShared.AlertOnTrain = function(train, train_id, alertEntity, forceToSeeAlert, currentTick, message)
    -- Show a text message at the tunnel entrance for a short period.
    rendering.draw_text {
        text = message,
        surface = alertEntity.surface,
        target = alertEntity,
        time_to_live = 300,
        forces = {forceToSeeAlert},
        color = {r = 1, g = 0, b = 0, a = 1},
        scale_with_zoom = true,
        alignment = "center",
        vertical_alignment = "bottom"
    }

    -- Add the alert for the tunnel force.
    local alertId = PlayerAlerts.AddCustomAlertToForce(forceToSeeAlert, train_id, alertEntity, {type = "virtual", name = "railway_tunnel"}, message, true)

    -- Setup a schedule to detect when the train is either moving or changed (not valid LuaTrain) and the alert can be removed.
    EventScheduler.ScheduleEventOnce(currentTick + 1, "TunnelShared.CheckIfAlertingTrainStillStopped_Scheduled", train_id, {train = train, alertEntity = alertEntity, alertId = alertId, force = forceToSeeAlert})
end

--- Checks a train until it is no longer stopped and then removes the alert associated with it.
---@param event UtilityScheduledEvent_CallbackObject
TunnelShared.CheckIfAlertingTrainStillStopped_Scheduled = function(event)
    local train = event.data.train ---@type LuaTrain
    local alertEntity = event.data.alertEntity ---@type LuaEntity
    local trainStopped = true

    if not train.valid then
        -- Train is not valid any more so alert should be removed.
        trainStopped = false
    elseif not alertEntity.valid then
        -- The alert target entity is not valid any more so alert should be removed.
        trainStopped = false
    elseif train.speed ~= 0 then
        -- The train has speed and so isn't stopped any more.
        trainStopped = false
    elseif not train.manual_mode then
        -- The train is in automatic so isn't stopped any more.
        trainStopped = false
    end

    -- Handle the stopped state.
    if not trainStopped then
        -- Train isn't stopped so remove the alert.
        PlayerAlerts.RemoveCustomAlertFromForce(event.data.force, event.data.alertId)
    else
        -- Train is still stopped so schedule a check for next tick.
        EventScheduler.ScheduleEventOnce(event.tick + 1, "TunnelShared.CheckIfAlertingTrainStillStopped_Scheduled", event.instanceId, event.data)
    end
end

--- Merged event handler to call the approperiate module function. More UPS effecient than other options and allows smart function calling based on known context.
---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive
TunnelShared.OnBuiltEntity = function(event)
    local createdEntity = event.created_entity or event.entity
    if not createdEntity.valid then
        return
    end

    -- A built entity can only meet one of these below modules conditions. Ordered in lowest UPS cost to check if module condition is met.
    -- As only one function is ever going to be called we don't have to check if objects are still valid between the below checks and handler functions called.
    -- Does the real entities first and then ghosts.

    local createdEntity_type = createdEntity.type
    if Common.RollingStockTypes[createdEntity_type] ~= nil then
        MOD.Interfaces.Tunnel.OnTrainCarriageEntityBuilt(event, createdEntity)
        return
    end

    local createdEntity_name = createdEntity.name
    if Common.FakeTunnelPartNameToRealTunnelPartName[createdEntity_name] ~= nil and event.player_index ~= nil then
        -- A fake tunnel part was just build by a player ONLY. This is an edge case as here we do allow calling multiple functions, but this function will never lead to anything becoming invalid.
        TunnelShared.FakeTunnelPartBuiltByPlayer(event, createdEntity_name)
    end
    if Common.PortalEndAndSegmentEntityNames[createdEntity_name] ~= nil then
        MOD.Interfaces.Portal.OnTunnelPortalPartEntityBuilt(event, createdEntity, createdEntity_name)
        return
    elseif Common.UndergroundSegmentEntityNames[createdEntity_name] ~= nil then
        MOD.Interfaces.Underground.OnUndergroundSegmentBuilt(event, createdEntity, createdEntity_name, nil)
        return
    end

    if createdEntity_type == "entity-ghost" then
        local createdEntity_ghostName = createdEntity.ghost_name
        if Common.PortalEndAndSegmentEntityNames[createdEntity_ghostName] ~= nil then
            MOD.Interfaces.Portal.OnTunnelPortalPartGhostBuilt(event, createdEntity, createdEntity_ghostName)
            return
        elseif Common.UndergroundSegmentEntityNames[createdEntity_ghostName] ~= nil then
            MOD.Interfaces.Underground.OnUndergroundSegmentGhostBuilt(event, createdEntity, createdEntity_ghostName)
            return
        elseif Common.RollingStockTypes[createdEntity_ghostName] ~= nil then
            MOD.Interfaces.Tunnel.OnTrainCarriageGhostBuilt(event, createdEntity, createdEntity_ghostName)
            return
        end
    end

    error("some function should have been called")
end

--- Merged event handler to call the approperiate module function. More UPS effecient than other options and allows smart function calling based on known context.
---@param event on_entity_died|script_raised_destroy
TunnelShared.OnDiedEntity = function(event)
    local diedEntity = event.entity
    if not diedEntity.valid then
        return
    end

    -- A died entity can only meet one of these modules conditions. Ordered in lowest UPS cost overall.
    -- Means we don't have to check if its still valid between handler functions called.

    local diedEntity_type = diedEntity.type
    if Common.RollingStockTypes[diedEntity_type] ~= nil then
        MOD.Interfaces.TrainCachedData.OnRollingStockRemoved(event, diedEntity)
        return
    end

    local diedEntity_name = diedEntity.name
    if diedEntity_name == "railway_tunnel-portal_entry_train_detector_1x1" then
        MOD.Interfaces.Portal.OnPortalEntryTrainDetectorEntityDied(event, diedEntity)
        return
    elseif diedEntity_name == "railway_tunnel-portal_transition_train_detector_1x1" then
        MOD.Interfaces.Portal.OnPortalTransitionTrainDetectorEntityDied(event, diedEntity)
        return
    elseif Common.PortalEndAndSegmentEntityNames[diedEntity_name] ~= nil then
        MOD.Interfaces.Portal.OnPortalPartEntityDied(event, diedEntity)
        return
    elseif Common.UndergroundSegmentEntityNames[diedEntity_name] ~= nil then
        MOD.Interfaces.Underground.OnUndergroundSegmentEntityDied(event, diedEntity)
        return
    end

    error("some function should have been called")
end

--- Merged event handler to call the approperiate module function. More UPS effecient than other options and allows smart function calling based on known context.
---@param event on_pre_player_mined_item|on_robot_pre_mined
TunnelShared.OnPreMinedEntity = function(event)
    local minedEntity = event.entity
    if not minedEntity.valid then
        return
    end

    -- A pre-mined entity can only meet one of these modules conditions. Ordered in lowest UPS cost overall.
    -- Means we don't have to check if its still valid between handler functions called.

    local minedEntity_name = minedEntity.name
    if Common.PortalEndAndSegmentEntityNames[minedEntity_name] ~= nil then
        MOD.Interfaces.Portal.OnPortalPartEntityPreMined(event, minedEntity)
        return
    elseif Common.UndergroundSegmentEntityNames[minedEntity_name] ~= nil then
        MOD.Interfaces.Underground.OnUndergroundSegmentEntityPreMined(event, minedEntity)
        return
    end

    error("some function should have been called")
end

--- Prints a red warning message to all players, including that they should report this bug to the mod author.
---
--- For use when an edge case will error in Debug Release, but is allowed in production release as probably shouldn't error.
---@param text string
TunnelShared.PrintWarningAndReportToModAuthor = function(text)
    if string.sub(text, #text) ~= "." then
        text = text .. "."
    end
    game.print("WARNING: " .. text .. " Please report to mod author.", Colors.red)
end

--- Called when a player presses the F key to try and horizontally flip something (blueprint or curved rail in vanilla). Runs before the game handles the event and does its action based on what event(s) are bound to the key.
---
--- Horizontal flip is a straight swap between regular and flipped entities, no rotations required.
--- We only react if it's an item of one of the fake/real tunnel parts (not hovering over an entity). Or its a blueprint that contains a fake/real tunnel part.
---@param event CustomInputEvent
TunnelShared.OnFlipBlueprintHorizontalInput = function(event)
    -- Always react to the player pressing the button and check if an approperiate item is in the cursor. If its not then nothing is done.
    -- CODE DEV: Doing it purely by player cursor rather than by the event's selected prototype data means if a tunnel part is in the cursor and the player has their cursor on an entity (selected) then we still flip the item in the cursor.

    local player = game.get_player(event.player_index)

    -- Check what's in the players cursor.
    local itemInHand = player.cursor_stack
    local ghostItemInHand, itemInHandName
    if not itemInHand.valid_for_read then
        -- No real item in hand, check for a ghost in cursor.
        ghostItemInHand = player.cursor_ghost

        -- Check if theres an item prototype as a ghost in hand.
        if ghostItemInHand == nil then
            -- Theres nothing in the players cursor so nothing to do.
            return
        end

        itemInHandName = ghostItemInHand.name
    else
        -- There is a real item in hand.
        itemInHandName = itemInHand.name
    end

    -- If it's a Blueprint item then handle specially (will never be a ghost type).
    if itemInHandName == "blueprint" then
        local bpContents = itemInHand.cost_to_build

        -- Check for fake/real tunnel parts and if found handle them.
        for fakeAndRealTunnelPartName in pairs(Common.FakeAndRealTunnelPartNames) do
            if bpContents[fakeAndRealTunnelPartName] ~= nil then
                -- I can't find a way to deal with flipping blueprints with fake/real rails in them or blocking it, so just show a message for now.
                -- CODE DEV: would have to handle the current player (non game state) of the BP having been flipped, but the game state of the BP not being flipped. So can't win with changing the BP entities between regular/flipped. If I change the cursor in hand in this event the origional BP is remebered locally as still having been flipped, thus breaking it. I can't consume this event as I can't trigger a players local BP flip via API. I also can't add an non flippable entity to the BP at this point as the flip has already been approved. Only way to stop is to have the base type of this entity as one that can't be flipped, which looks to be either something with a 2 fluid boxes or an off center fluid box (i.e. chemical plant), or a mining drill with an off center output (like burner mining drill).
                rendering.draw_text(
                    {
                        text = {"message.railway_tunnel-blueprint_with_fakereal_tunnel_part_warning-1"},
                        surface = player.surface,
                        target = event.cursor_position,
                        color = Colors.red,
                        time_to_live = 900,
                        players = {player},
                        scale_with_zoom = true,
                        alignment = "center",
                        vertical_alignment = "bottom"
                    }
                )
                rendering.draw_text(
                    {
                        text = {"message.railway_tunnel-blueprint_with_fakereal_tunnel_part_warning-2"},
                        surface = player.surface,
                        target = event.cursor_position,
                        color = Colors.red,
                        time_to_live = 900,
                        players = {player},
                        scale_with_zoom = true,
                        alignment = "center",
                        vertical_alignment = "top"
                    }
                )
                -- Once one is found and the message shown no more checking is required.
                return
            end
        end

        -- No further processing of blueprints is required.
        return
    end

    -- Check that is an item we care about and if so get its other item name.
    local newPartName, realToFakeChange
    newPartName = Common.RealTunnelPartNameToFakeTunnelPartName[itemInHandName]
    if newPartName ~= nil then
        realToFakeChange = true
    else
        newPartName = Common.FakeTunnelPartNameToRealTunnelPartName[itemInHandName]
        if newPartName ~= nil then
            realToFakeChange = false
        else
            -- Not a cursor item we need to handle.
            return
        end
    end

    -- Handle an actual (non ghost) underground part item.
    if ghostItemInHand == nil then
        if realToFakeChange then
            -- Going from real item to flipped fake item.
            TunnelShared.SwapCursorFromRealTunnelPartToFakeTunnelPart(player, itemInHandName, newPartName, itemInHand, event.tick, event.player_index)
        else
            -- Going back to real item from flipped fake item.

            -- Cancel any traking of real item to fake item for this player.
            TunnelShared.CancelTrackingPlayersRealTunnelPartToFakeTunnelPartItemCount(event.player_index, event.tick)

            -- Discard the fake item (its destroyed automatically on releae from cursor).
            player.clear_cursor()

            -- Set a real item stack to the cursor from the player's inventory.
            local regularItemStack, regularItemStackIndex = player.get_inventory(defines.inventory.character_main).find_item_stack(newPartName)
            itemInHand.swap_stack(regularItemStack)
            player.hand_location = {inventory = defines.inventory.character_main, slot = regularItemStackIndex}
        end
        return
    end

    -- Must be a ghost item in players cursor.
    player.cursor_ghost = newPartName
end

--- Called when a player presses the G key to try and vertically flip something (blueprint or curved rail in vanilla). Runs before the game handles the event and does its action based on what event(s) are bound to the key.
---
--- Can't do the flip and reverse rotation on an item in cursor as can't rotate players cursor. So calls the horizontal flip function to still change between the regular and flipped items and to ensure if its a BP in hand that the failed flip message is shown.
--- Does mean that the can not disconnect rolling stock message is shown by the game in some cases, but this keeps the logic simple and players would generally use the main flip anyways (F) as next to rotate (R).
---@param event CustomInputEvent
TunnelShared.OnFlipBlueprintVerticalInput = function(event)
    TunnelShared.OnFlipBlueprintHorizontalInput(event)
end

--- Swap from a real tunnel part to a fake tunnel part. Handles if there is an actual item or a ghost in the cursor.
---@param player LuaPlayer
---@param realItemInInventoryName string
---@param fakeItemInCursorName string
---@param playerCursorStack LuaItemStack
---@param currentTick Tick
---@param playerId Id
TunnelShared.SwapCursorFromRealTunnelPartToFakeTunnelPart = function(player, realItemInInventoryName, fakeItemInCursorName, playerCursorStack, currentTick, playerId)
    -- Return the real item to the inventory. means theres no "hand" icon in the inventory from this point on as the item in cursor will never be returned there.
    player.clear_cursor()

    -- Set the fake item to the cursor at the correct starting count.
    local realItemCountInInventory = player.get_item_count(realItemInInventoryName)
    if realItemCountInInventory == 0 then
        -- Theres none of this item in the inventory so set the cursor to be a ghost item and stop processing.
        player.cursor_ghost = fakeItemInCursorName
        return
    end
    playerCursorStack.set_stack({name = fakeItemInCursorName, count = realItemCountInInventory})

    --- Start tracking a fake item in the cursor to the real item in a player's inventory.
    ---@type PlayersFakePartTracking
    local playersFakePartTrackingData = {
        playerId = playerId,
        player = player,
        realItemInInventoryName = realItemInInventoryName,
        fakeItemInCursorName = fakeItemInCursorName,
        cursorCount = playerCursorStack.count -- Get once set as this will account for the max stack size.
    }
    -- If theres no schedule already for this player then schedule it. 2 swaps can be done in the same tick when the game is paused, but they may be for different items. So we always replace the old ones data, but don't schedule a new event as it would be a duplicate for the player Id.
    if global.tunnelShared.playersFakePartTracking[playerId] == nil then
        EventScheduler.ScheduleEventOnce(currentTick + 1, "TunnelShared.TrackingPlayersRealToFakeItemCount_Scheduled", playerId)
    end
    global.tunnelShared.playersFakePartTracking[playerId] = playersFakePartTrackingData
end

--- Called every tick to update the fake cursor item count with the real count from the players inventory. This is to catch any non player building actions that lead to a reducution in the item in the player's inventory.
---@param event UtilityScheduledEvent_CallbackObject
TunnelShared.TrackingPlayersRealToFakeItemCount_Scheduled = function(event)
    -- CODE NOTE: Does a simple code solution of just checking the players inventory every tick rather than trying to track every way the count could be reduced. Not convinced I could track every reduction method and the length and player count this will be active for should be very low at any given time.

    local playersFakePartTrackingData = global.tunnelShared.playersFakePartTracking[event.instanceId]
    local player_cursorStack = playersFakePartTrackingData.player.cursor_stack
    -- Check nothing has changed that means we no longer need to do the update.
    -- Note: when the last ite is palced this code would not detect it as the cursor would have been changed to empty. This is caught by the dedicated on entity built.
    if not player_cursorStack.valid_for_read or player_cursorStack.name ~= playersFakePartTrackingData.fakeItemInCursorName then
        TunnelShared.CancelTrackingPlayersRealTunnelPartToFakeTunnelPartItemCount(event.instanceId, event.tick)
        return
    end

    local playerMainInventory = playersFakePartTrackingData.player.get_inventory(defines.inventory.character_main)

    -- Remove any removed cursor item count from from the inventories items. This could be as built via script or some other way the fake item has been removed from the players cursor without the player doing a manual building action. Is edge case protection.
    local currentCursorCount = player_cursorStack.count
    if currentCursorCount < playersFakePartTrackingData.cursorCount then
        playerMainInventory.remove({name = playersFakePartTrackingData.realItemInInventoryName, count = playersFakePartTrackingData.cursorCount - currentCursorCount})
        playersFakePartTrackingData.cursorCount = currentCursorCount
    end

    -- Check the inventory current count and update to cursor.
    local currentInventoryCount = playerMainInventory.get_item_count(playersFakePartTrackingData.realItemInInventoryName)
    if currentInventoryCount > 0 then
        -- Still count in the inventory so update the cursor and schedule a check next tick.
        player_cursorStack.count = currentInventoryCount
        playersFakePartTrackingData.cursorCount = player_cursorStack.count -- Get once set as this will account for the max stack size.
        EventScheduler.ScheduleEventOnce(event.tick + 1, "TunnelShared.TrackingPlayersRealToFakeItemCount_Scheduled", event.instanceId)
    else
        -- None left in inventory so remove cursor item and just don't add another check.
        player_cursorStack.clear()
        TunnelShared.CancelTrackingPlayersRealTunnelPartToFakeTunnelPartItemCount(event.instanceId, event.tick)
    end
end

--- Called when a fake tunnel part is built by a player only.
--- This function is not allowed to invalidate any game or cached object within its current calling logic.
---@param event on_built_entity
---@param createdEntity_name string
TunnelShared.FakeTunnelPartBuiltByPlayer = function(event, createdEntity_name)
    -- Check that the part built is being tracked for that player.
    local playersFakePartTrackingData = global.tunnelShared.playersFakePartTracking[event.player_index]
    if playersFakePartTrackingData == nil then
        -- If the player is not in the character mode then they can instant build blueprints which is outside of the standard handling.
        local player = game.get_player(event.player_index)
        if player.controller_type ~= defines.controllers.character then
            -- Player is in a special mode placing a blueprint with instant blueprint enabled. This mode in Factorio doesn't use items from the players inventory and so nothing needs to be done in this situation.
            -- This can sometimes have a readable cursor stack and sometimes not, for an unknown reasons; so can't check it.
            return
        else
            -- Player is in normal character mode so this state should be unreachable.
            error("Player " .. event.player_index .. " built a fake (flipped) tunnel part, but they aren't being monitored for any.")
        end
    end
    if createdEntity_name ~= playersFakePartTrackingData.fakeItemInCursorName then
        error("Player " .. event.player_index .. " built a " .. createdEntity_name .. ", but they are being monitored for a " .. playersFakePartTrackingData.fakeItemInCursorName)
    end

    local player_cursorStack = playersFakePartTrackingData.player.cursor_stack
    if player_cursorStack.valid_for_read then
        -- Theres still some count in the cursor so handle it.
        local currentCursorCount = player_cursorStack.count
        if currentCursorCount < playersFakePartTrackingData.cursorCount then
            local playerMainInventory = playersFakePartTrackingData.player.get_inventory(defines.inventory.character_main)
            playerMainInventory.remove({name = playersFakePartTrackingData.realItemInInventoryName, count = playersFakePartTrackingData.cursorCount - currentCursorCount})
            playersFakePartTrackingData.cursorCount = currentCursorCount
        else
            error("Player " .. event.player_index .. " built a " .. createdEntity_name .. ", but their cursor count is NOT less than their last known count.")
        end
    else
        -- The cursor is presently empty and so the last item was just built.
        local playerMainInventory = playersFakePartTrackingData.player.get_inventory(defines.inventory.character_main)
        playerMainInventory.remove({name = playersFakePartTrackingData.realItemInInventoryName, count = 1})
        TunnelShared.CancelTrackingPlayersRealTunnelPartToFakeTunnelPartItemCount(event.player_index, event.tick)
    end
end

--- Called to stop tracking a player's real tunnel part to fake tunnel part item count.
---@param playerIndex Id
---@param currentTick Tick
TunnelShared.CancelTrackingPlayersRealTunnelPartToFakeTunnelPartItemCount = function(playerIndex, currentTick)
    global.tunnelShared.playersFakePartTracking[playerIndex] = nil
    EventScheduler.RemoveScheduledOnceEvents("TunnelShared.TrackingPlayersRealToFakeItemCount_Scheduled", playerIndex)
end

--- Called when a player triggers the smart pipette functionality (not just every time the key is pressed). Runs after the game handles the event in its default way.
---
--- We only react if its a flipped fake/real tunnel part being selected as it will give the regular item (non-flipped) by default, so we need to change it to the right item/ghost.
---@param event on_player_pipette
TunnelShared.OnSmartPipette = function(event)
    local player = game.get_player(event.player_index) ---@type LuaPlayer
    local selectedEntity = player.selected
    if selectedEntity == nil then
        return
    end

    -- Only react if its one of our parts (entity or ghost) with a fake item to build it.
    local selectedEntityName = selectedEntity.name
    local realItemName = Common.FakeTunnelPartNameToRealTunnelPartName[selectedEntityName]
    if realItemName == nil then
        if selectedEntityName == "entity-ghost" then
            player = game.get_player(event.player_index)
            selectedEntityName = selectedEntity.ghost_name
            realItemName = Common.FakeTunnelPartNameToRealTunnelPartName[selectedEntityName]
            if realItemName == nil then
                -- Not a ghost type we need to react too.
                return
            end
        else
            -- Not an entity we need to react too.
            return
        end
    end

    -- Set the cursor to the desired item.
    TunnelShared.SwapCursorFromRealTunnelPartToFakeTunnelPart(player, realItemName, selectedEntityName, player.cursor_stack, event.tick, event.player_index)
end

return TunnelShared
