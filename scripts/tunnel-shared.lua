local Utils = require("utility/utils")
local Colors = require("utility/colors")
local Common = require("scripts/common")
local TunnelShared = {}

---@param startingTunnelPart LuaEntity
---@param startingTunnelPartPoint Position
---@param checkingDirection defines.direction
---@param placer EntityActioner
---@param tunnelPortalEntities LuaEntity[] @A reference to an existing tunnel portal entity array that will have discovered portal entities added to. Can be an empty array.
---@param tunnelSegmentEntities LuaEntity[] @A reference to an existing tunnel segment entity array that will have discovered segment entities added to. Can be an empty array.
---@return boolean @Direction is completed successfully.
TunnelShared.CheckTunnelPartsInDirectionAndGetAllParts = function(startingTunnelPart, startingTunnelPartPoint, checkingDirection, placer, tunnelPortalEntities, tunnelSegmentEntities)
    local startingTunnelPart_name, startingTunnelPart_direction, startingTunnelPart_position = startingTunnelPart.name, startingTunnelPart.direction, startingTunnelPart.position

    if Common.TunnelSegmentPlacedEntityNames[startingTunnelPart_name] then
        -- Only include the starting tunnel segment when we are checking its direction, not when checking from it the other direction. Otherwise we double add it.
        if checkingDirection == startingTunnelPart_direction then
            table.insert(tunnelSegmentEntities, startingTunnelPart)
        end
    elseif Common.TunnelPortalPlacedEntityNames[startingTunnelPart_name] then
        table.insert(tunnelPortalEntities, startingTunnelPart)
    else
        error("Common.CheckTunnelPartsInDirectionAndGetAllParts() unsupported startingTunnelPart.name: " .. startingTunnelPart_name)
    end
    local continueChecking, nextCheckingPos = true, startingTunnelPartPoint
    local checkingPositionOffset = Utils.RotatePositionAround0(Utils.DirectionToOrientation(checkingDirection), {x = 0, y = 2})
    while continueChecking do
        nextCheckingPos = Utils.ApplyOffsetToPosition(nextCheckingPos, checkingPositionOffset)
        local connectedTunnelEntities = startingTunnelPart.surface.find_entities_filtered {position = nextCheckingPos, name = Common.TunnelSegmentAndPortalPlacedEntityNames, force = startingTunnelPart.force, limit = 1}
        if #connectedTunnelEntities == 0 then
            continueChecking = false
        else
            local connectedTunnelEntity = connectedTunnelEntities[1] ---@type LuaEntity
            local connectedTunnelEntity_position, connectedTunnelEntity_direction = connectedTunnelEntity.position, connectedTunnelEntity.direction
            if connectedTunnelEntity_position.x ~= startingTunnelPart_position.x and connectedTunnelEntity_position.y ~= startingTunnelPart_position.y then
                TunnelShared.EntityErrorMessage(placer, "Tunnel parts must be in a straight line", connectedTunnelEntity.surface, connectedTunnelEntity_position)
                continueChecking = false
            elseif Common.TunnelSegmentPlacedEntityNames[connectedTunnelEntity.name] then
                if connectedTunnelEntity_direction == startingTunnelPart_direction or connectedTunnelEntity_direction == Utils.LoopDirectionValue(startingTunnelPart_direction + 4) then
                    table.insert(tunnelSegmentEntities, connectedTunnelEntity)
                else
                    TunnelShared.EntityErrorMessage(placer, "Tunnel segments must be in the same direction; horizontal or vertical", connectedTunnelEntity.surface, connectedTunnelEntity_position)
                    continueChecking = false
                end
            elseif Common.TunnelPortalPlacedEntityNames[connectedTunnelEntity.name] then
                continueChecking = false
                if connectedTunnelEntity_direction == Utils.LoopDirectionValue(checkingDirection + 4) then
                    table.insert(tunnelPortalEntities, connectedTunnelEntity)
                    return true, tunnelPortalEntities, tunnelSegmentEntities
                else
                    TunnelShared.EntityErrorMessage(placer, "Tunnel portal facing wrong direction", connectedTunnelEntity.surface, connectedTunnelEntity_position)
                end
            else
                error("unhandled railway_tunnel entity type")
            end
        end
    end
    return false, tunnelPortalEntities, tunnelSegmentEntities
end

---@param placementEntity LuaEntity
---@return boolean
TunnelShared.IsPlacementOnRailGrid = function(placementEntity)
    if placementEntity.position.x % 2 == 0 or placementEntity.position.y % 2 == 0 then
        return false
    else
        return true
    end
end

---@param placementEntity LuaEntity
---@param placer EntityActioner
---@param mine boolean @If to mine and return the item to the placer, or just destroy it.
TunnelShared.UndoInvalidTunnelPartPlacement = function(placementEntity, placer, mine)
    TunnelShared.UndoInvalidPlacement(placementEntity, placer, mine, true, "Tunnel must be placed on the rail grid", "tunnel part")
end

---@param placementEntity LuaEntity
---@param placer EntityActioner
---@param mine boolean @If to mine and return the item to the placer, or just destroy it.
---@param highlightValidRailGridPositions boolean @If to show to the placer valid positions on the rail grid.
---@param warningMessageText string @Text shown to the placer
---@param errorEntityNameText string @Entity name shown if the process errors.
TunnelShared.UndoInvalidPlacement = function(placementEntity, placer, mine, highlightValidRailGridPositions, warningMessageText, errorEntityNameText)
    if placer ~= nil then
        local position, surface, entityName, ghostName, direction = placementEntity.position, placementEntity.surface, placementEntity.name, nil, placementEntity.direction
        if entityName == "entity-ghost" then
            ghostName = placementEntity.ghost_name
        end
        TunnelShared.EntityErrorMessage(placer, warningMessageText, surface, position)
        if mine then
            local result
            if placer.is_player() then
                result = placer.mine_entity(placementEntity, true)
            else
                -- Is construction bot
                result = placementEntity.mine({inventory = placer.get_inventory(defines.inventory.robot_cargo), force = true, raise_destroyed = false, ignore_minable = true})
            end
            if result ~= true then
                error("couldn't mine invalidly placed " .. errorEntityNameText .. " entity")
            end
        else
            placementEntity.destroy()
        end
        if highlightValidRailGridPositions then
            TunnelShared.HighlightValidPlacementPositionsOnRailGrid(placer, position, surface, entityName, ghostName, direction)
        end
    else
        placementEntity.destroy()
        game.print("invalid placement of " .. errorEntityNameText .. " by script at {" .. tostring(placementEntity.position.x) .. "," .. tostring(placementEntity.position.y) .. "} removed", Colors.red)
    end
end

--- Highlights the single tiles to the placer player/force that are valid centres for an entity on the rail grid.
---@param placer EntityActioner
---@param position Position
---@param surface LuaSurface
---@param entityName string
---@param ghostName string
---@param direction defines.direction @Direction of the entity trying to be placed.
TunnelShared.HighlightValidPlacementPositionsOnRailGrid = function(placer, position, surface, entityName, ghostName, direction)
    local highlightAudiencePlayers, highlightAudienceForces = Utils.GetRenderPlayersForcesFromActioner(placer)
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
            rendering.draw_sprite {sprite = thisHighlightSprite, target = thisPlacementPosition, surface = surface, time_to_live = 300, players = highlightAudiencePlayers, forces = highlightAudienceForces}
        end
    end
end

--- Shows warning/error text on the map to either the player (character) or the force (construction robots) doign the interaction.
---@param entityDoingInteraction EntityActioner
---@param text string @Text shown.
---@param surface LuaSurface
---@param position Position
TunnelShared.EntityErrorMessage = function(entityDoingInteraction, text, surface, position)
    local textAudiencePlayers, textAudienceForces = Utils.GetRenderPlayersForcesFromActioner(entityDoingInteraction)
    rendering.draw_text {text = text, surface = surface, target = position, time_to_live = 180, players = textAudiencePlayers, forces = textAudienceForces, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
end

---@param railEntityList LuaEntity[]
---@param killForce LuaForce
---@param killerCauseEntity LuaEntity
TunnelShared.DestroyCarriagesOnRailEntityList = function(railEntityList, killForce, killerCauseEntity)
    if Utils.IsTableEmpty(railEntityList) then
        return
    end
    local refEntity, railEntityCollisionBoxList = nil, {}
    for _, railEntity in pairs(railEntityList) do
        if railEntity.valid then
            refEntity = railEntity
            table.insert(railEntityCollisionBoxList, railEntity.bounding_box) -- Only supports straight track by design.
        end
    end
    local searchArea = Utils.CalculateBoundingBoxToIncludeAllBoundingBoxs(railEntityCollisionBoxList)
    local carriagesFound = refEntity.surface.find_entities_filtered {area = searchArea, type = {"locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon"}}
    for _, carriage in pairs(carriagesFound) do
        Utils.EntityDie(carriage, killForce, killerCauseEntity)
    end
end

return TunnelShared
