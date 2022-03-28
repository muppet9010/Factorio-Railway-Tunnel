local Utils = require("utility.utils")
local Colors = require("utility.colors")
local EventScheduler = require("utility.event-scheduler")
local PlayerAlerts = require("utility.player-alerts")
local Events = require("utility.events")
local Common = require("scripts.common")
local TunnelShared = {}

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
    Events.RegisterHandlerCustomInput("railway_tunnel-smart_pipette", "TunnelShared.OnSmartPipetteInput", TunnelShared.OnSmartPipetteInput)
end

---@param builtEntity LuaEntity
---@return boolean
TunnelShared.IsPlacementOnRailGrid = function(builtEntity)
    local builtEntity_position = builtEntity.position
    if builtEntity_position.x % 2 == 0 or builtEntity_position.y % 2 == 0 then
        return false
    else
        return true
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

--- Highlights the single tiles to the placer player/force that are valid centres for an entity on the rail grid.
---@param placer EntityActioner
---@param position MapPosition
---@param surface LuaSurface
---@param entityName string
---@param ghostName string
---@param direction defines.direction @ Direction of the entity trying to be placed.
TunnelShared.HighlightValidPlacementPositionsOnRailGrid = function(placer, position, surface, entityName, ghostName, direction)
    local highlightAudiencePlayer, highlightAudienceForce = Utils.GetPlayerForceFromActioner(placer)
    -- Get the minimum position from where the attempt as made and then mark out the 4 iterations from that.
    local minX, maxX, minY, maxY
    if position.x % 2 == 1 then
        --Correct X position.
        minX = position.x
        maxX = position.x
    else
        -- Wrong X position.
        minX = position.x - 1
        maxX = position.x + 1
    end
    if position.y % 2 == 1 then
        --Correct Y position.
        minY = position.y
        maxY = position.y
    else
        -- Wrong Y position.
        minY = position.y - 1
        maxY = position.y + 1
    end
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
    local textAudiencePlayer, textAudienceForce = Utils.GetPlayerForceFromActioner(entityDoingInteraction)
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

    -- A built entity can only meet one of these modules conditions. Ordered in lowest UPS cost overall.
    -- Means we don't have to check if its still valid between handler functions called.

    local createdEntity_type = createdEntity.type
    if Common.RollingStockTypes[createdEntity_type] ~= nil then
        MOD.Interfaces.Tunnel.OnTrainCarriageEntityBuilt(event, createdEntity)
        return
    end

    local createdEntity_name = createdEntity.name
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
            MOD.Interfaces.Portal.OnTunnelPortalPartGhostBuilt(event, createdEntity)
            return
        elseif Common.UndergroundSegmentEntityNames[createdEntity_ghostName] ~= nil then
            MOD.Interfaces.Underground.OnUndergroundSegmentGhostBuilt(event, createdEntity)
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
--- We only react if it's an item of one of the curved tunnel parts (not hovering over an entity). Or its a blueprint that contains a curved tunnel part.
---@param event CustomInputEvent
TunnelShared.OnFlipBlueprintHorizontalInput = function(event)
    -- TODO: these functions will be used by both underground and portal curved parts as same logic for all. So add in portal curve part names when made.

    -- Always react to the player pressing the button and check if an approperiate item is in the cursor. If its not then nothing is done.
    -- CODE DEV: Doing it purely by player cursor rather than by the event's selected prototype data means if a curved part is in the cursor and the player has their cursor on an entity (selected) then we still flip the item in the cursor.
    local player = game.get_player(event.player_index)
    local itemInHand = player.cursor_stack
    -- If theres nothing in the players cursor then nothing to do.
    if not itemInHand.valid_for_read then
        return
    end
    local itemInHandName = itemInHand.name

    -- If it's a Blueprint item then handle specially.
    if itemInHandName == "blueprint" then
        local bpContents = itemInHand.cost_to_build

        -- Check for curved undergrounds and if found handle them.
        if bpContents["railway_tunnel-underground_segment-curved-regular"] ~= nil or bpContents["railway_tunnel-underground_segment-curved-flipped"] ~= nil then
            -- I can't find a way to deal with flipping bluepritns with curved rails in them or blocking it, so just show a message for now.
            -- CODE DEV: would have to handle the current player (non game state) of the BP having been flipped, but the game state of the BP not being flipped. So can't win with changing the BP entities between regular/flipped. If I change the cursor in hand in this event the origional BP is remebered locally as still having been flipped, thus breaking it. I can't consume this event as I can't trigger a players local BP flip via API. I also can't add an non flippable entity to the BP at this point as the flip has already been approved. Only way to stop is to have the base type of this entity as one that can't be flipped, which looks to be either something with a 2 fluid boxes or and off center fluid box (i.e. chemical plant), or a mining drill with an off center output (like burner mining drill).
            rendering.draw_text(
                {
                    text = {"message.railway_tunnel-blueprint_with_curved_tunnel_part_warning-1"},
                    surface = player.surface,
                    target = event.cursor_position,
                    color = Colors.red,
                    time_to_live = 900,
                    scale_with_zoom = true,
                    alignment = "center",
                    vertical_alignment = "bottom"
                }
            )
            rendering.draw_text(
                {
                    text = {"message.railway_tunnel-blueprint_with_curved_tunnel_part_warning-2"},
                    surface = player.surface,
                    target = event.cursor_position,
                    color = Colors.red,
                    time_to_live = 900,
                    scale_with_zoom = true,
                    alignment = "center",
                    vertical_alignment = "top"
                }
            )
        end

        -- No further processing of blueprints is required.
        return
    end

    -- Change item in cursor to the other item.
    local newPartName, realToFakeChange
    if itemInHandName == "railway_tunnel-underground_segment-curved-regular" then
        newPartName = "railway_tunnel-underground_segment-curved-flipped"
        realToFakeChange = true
    elseif itemInHandName == "railway_tunnel-underground_segment-curved-flipped" then
        newPartName = "railway_tunnel-underground_segment-curved-regular"
        realToFakeChange = false
    else
        -- Not a cursor item we need to handle.
        return
    end

    -- Handle the curved underground part item.
    if realToFakeChange then
        -- Going from real item to flipped fake item.

        -- Return the real item to the inventory. means theres no "hand" icon in the inventory from this point on as the item in cursor will never be returned there.
        player.clear_cursor()

        -- Set the fake item to the cursor at the correct starting count.
        itemInHand.set_stack({name = newPartName, count = player.get_item_count(itemInHandName)})

        -- Start tracking the players inventory count of the real item to the fake item in the player's cursor.
        ---@class TrackingPlayersRealToFakeItemCount_Scheduled_Data
        local data = {
            player = player,
            realItemInInventoryName = itemInHandName, ---@string
            fakeItemInCursorName = newPartName, ---@string
            cursorCount = itemInHand.count -- Get once set as this will account for the max stack size.
        }
        EventScheduler.ScheduleEventOnce(event.tick + 1, "TunnelShared.TrackingPlayersRealToFakeItemCount_Scheduled", event.player_index, data)
    else
        -- Going back to real item from flipped fake item.

        -- Cancel any traking of real item to fake item for this player.
        TunnelShared.CancelTrackingPlayersRealToFakeItemCount(event.player_index, event.tick)

        -- Discard the fake item (its destroyed automatically on releae from cursor).
        player.clear_cursor()

        -- Set a real item stack to the cursor from the player's inventory.
        local regularItemStack, regularItemStackIndex = player.get_inventory(defines.inventory.character_main).find_item_stack(newPartName)
        itemInHand.swap_stack(regularItemStack)
        player.hand_location = {inventory = defines.inventory.character_main, slot = regularItemStackIndex}
    end
end

--TODO: don't think can use if we can't rotate players cursor. If so have the key either do nothing or call the horizontal flip. Still need to show the BP message however.
---@param event CustomInputEvent
TunnelShared.OnFlipBlueprintVerticalInput = function(event)
    --TODO
end

--@class TrackingPlayersRealToFakeItemCount_Scheduled_Data
--@field player LuaPlayer
--@field realItemInInventoryName string
--@field fakeItemInCursorName string
--@field cursorCount uint

--- Called every tick to update the fake cursor item count with the real count from the players inventory.
---@param event UtilityScheduledEvent_CallbackObject
TunnelShared.TrackingPlayersRealToFakeItemCount_Scheduled = function(event)
    -- CODE NOTE: Does a simple code solution of just checking the players inventory every tick rather than trying to track every way the count could be reduced. Not convinced I could track every reduction method and the length and player count this will be active for should be very low at any given time.

    -- TODO: still need to track when player builds one of these fake entities as in this case the cursor count reduces to 0 and thus becomes empty. This appears the same as if the cursor was changed to another item within this function. So the build event needs to reduce 1 real from inventory, with this function just catching any unexepcted count changes and updating both directions. Means that the count data for a player will need to be a global as both locations need to be able to update it.

    local data = event.data ---@type TrackingPlayersRealToFakeItemCount_Scheduled_Data
    local player = event.data.player ---@type LuaPlayer
    local player_cursor = player.cursor_stack
    -- Check nothing has changed that means we no longer need to do the update.
    if not player_cursor.valid_for_read or player_cursor.name ~= data.fakeItemInCursorName then
        TunnelShared.CancelTrackingPlayersRealToFakeItemCount(event.instanceId, event.tick)
        return
    end

    local playerMainInventory = player.get_inventory(defines.inventory.character_main)

    -- Remove any placed entities from the inventory.
    local currentCursorCount = player_cursor.count
    if currentCursorCount < data.cursorCount then
        playerMainInventory.remove({name = data.realItemInInventoryName, count = data.cursorCount - currentCursorCount})
        data.cursorCount = currentCursorCount
    end

    -- Check the inventory current count and update to cursor.
    local currentInventoryCount = playerMainInventory.get_item_count(data.realItemInInventoryName)
    if currentInventoryCount > 0 then
        -- Still count in the inventory so update the cursor and schedule a check next tick.
        player_cursor.count = currentInventoryCount
        data.cursorCount = player_cursor.count -- Get once set as this will account for the max stack size.
        EventScheduler.ScheduleEventOnce(event.tick + 1, "TunnelShared.TrackingPlayersRealToFakeItemCount_Scheduled", event.instanceId, data)
    else
        -- None left in inventory so remove cursor item and just don't add another check.
        player_cursor.clear()
    end
end

--- Called to stop tracking a player's real to fake item count.
---@param playerIndex Id
---@param currentTick Tick
TunnelShared.CancelTrackingPlayersRealToFakeItemCount = function(playerIndex, currentTick)
    EventScheduler.RemoveScheduledOnceEvents("TunnelShared.TrackingPlayersRealToFakeItemCount_Scheduled", playerIndex, currentTick)
end

--- Called when a player presses the Q key to use the smart pipette. Runs before the game handles the event and does its action based on what event(s) are bound to the key.
---
--- We only react if its a flipped curved tunnel part as it will give the regular item (wrong) by default.
---@param event CustomInputEvent
TunnelShared.OnSmartPipetteInput = function(event)
    --TODO: will need to include flipped curved portal parts as well as underground parts.

    -- Only need to react if the player's cursor has selected an entity when the key is pressed.
    if event.selected_prototype == nil or event.selected_prototype.base_type ~= "entity" or event.selected_prototype.name ~= "railway_tunnel-underground_segment-curved-flipped" then
        return
    end

    local player = game.get_player(event.player_index)
    local itemInHand = player.cursor_stack
    -- If there's an item in the cursor then do nothing, as this is how vanilla smart pipette works.
    if itemInHand.valid_for_read then
        return
    end

    -- Get the real item we will count in the players inventory.
    local realItemName
    if event.selected_prototype.name == "railway_tunnel-underground_segment-curved-flipped" then
        realItemName = "railway_tunnel-underground_segment-curved-regular"
    end

    -- Set the fake item to the cursor at the correct starting count.
    -- TODO: we need to do a 0 tick schedule so that our action happens after the base game does its smart pipette action, as otherwise our change is overwritten by the game.
    itemInHand.set_stack({name = "rail", count = player.get_item_count(realItemName)})
    --TODO: need to start the item count tracking.
end

return TunnelShared
