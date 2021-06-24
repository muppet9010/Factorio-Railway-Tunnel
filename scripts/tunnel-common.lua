local Utils = require("utility/utils")
local Colors = require("utility/colors")
local TunnelCommon = {}

-- Make the entity lists.
TunnelCommon.tunnelSegmentPlacedEntityNames, TunnelCommon.tunnelSegmentPlacementEntityNames, TunnelCommon.tunnelPortalPlacedEntityNames, TunnelCommon.tunnelPortalPlacementEntityNames = {}, {}, {}, {}
for _, coreName in pairs({"railway_tunnel-tunnel_segment_surface", "railway_tunnel-tunnel_segment_surface_rail_crossing"}) do
    TunnelCommon.tunnelSegmentPlacedEntityNames[coreName .. "-placed"] = coreName .. "-placed"
    TunnelCommon.tunnelSegmentPlacementEntityNames[coreName .. "-placement"] = coreName .. "-placement"
end
TunnelCommon.tunnelSegmentPlacedPlacementEntityNames = Utils.TableMerge({TunnelCommon.tunnelSegmentPlacedEntityNames, TunnelCommon.tunnelSegmentPlacementEntityNames})
for _, coreName in pairs({"railway_tunnel-tunnel_portal_surface"}) do
    TunnelCommon.tunnelPortalPlacedEntityNames[coreName .. "-placed"] = coreName .. "-placed"
    TunnelCommon.tunnelPortalPlacementEntityNames[coreName .. "-placement"] = coreName .. "-placement"
end
TunnelCommon.tunnelPortalPlacedPlacementEntityNames = Utils.TableMerge({TunnelCommon.tunnelPortalPlacedEntityNames, TunnelCommon.tunnelPortalPlacementEntityNames})
TunnelCommon.tunnelSegmentAndPortalPlacedEntityNames = Utils.TableMerge({TunnelCommon.tunnelSegmentPlacedEntityNames, TunnelCommon.tunnelPortalPlacedEntityNames})
TunnelCommon.tunnelSegmentAndPortalPlacedPlacementEntityNames = Utils.TableMerge({TunnelCommon.tunnelSegmentPlacedEntityNames, TunnelCommon.tunnelSegmentPlacementEntityNames, TunnelCommon.tunnelPortalPlacedEntityNames, TunnelCommon.tunnelPortalPlacementEntityNames})

---@class TunnelSurfaceRailEntityNames
TunnelCommon.TunnelSurfaceRailEntityNames = {
    -- Doesn't include the tunnel crossing rail as this isn't deemed part of the tunnel's rails.
    ["railway_tunnel-portal_rail-on_map"] = "railway_tunnel-portal_rail-on_map", ---@type TunnelSurfaceRailEntityNames
    ["railway_tunnel-internal_rail-not_on_map"] = "railway_tunnel-internal_rail-not_on_map", ---@type TunnelSurfaceRailEntityNames
    ["railway_tunnel-internal_rail-on_map_tunnel"] = "railway_tunnel-internal_rail-on_map_tunnel", ---@type TunnelSurfaceRailEntityNames
    ["railway_tunnel-invisible_rail-not_on_map"] = "railway_tunnel-invisible_rail-not_on_map", ---@type TunnelSurfaceRailEntityNames
    ["railway_tunnel-invisible_rail-on_map_tunnel"] = "railway_tunnel-invisible_rail-on_map_tunnel" ---@type TunnelSurfaceRailEntityNames
}

---@class RollingStockTypes
TunnelCommon.RollingStockTypes = {
    ["locomotive"] = "locomotive", ---@type RollingStockTypes
    ["cargo-wagon"] = "cargo-wagon", ---@type RollingStockTypes
    ["fluid-wagon"] = "fluid-wagon", ---@type RollingStockTypes
    ["artillery-wagon"] = "artillery-wagon" ---@type RollingStockTypes
}

---@param startingTunnelPart LuaEntity
---@param startingTunnelPartPoint Position
---@param checkingDirection defines.direction
---@param placer EntityBuildPlacer
---@return boolean, LuaEntity[], LuaEntity[]
TunnelCommon.CheckTunnelPartsInDirectionAndGetAllParts = function(startingTunnelPart, startingTunnelPartPoint, checkingDirection, placer)
    local tunnelPortalEntities, tunnelSegmentEntities = {}, {}
    if TunnelCommon.tunnelSegmentPlacedEntityNames[startingTunnelPart.name] then
        table.insert(tunnelSegmentEntities, startingTunnelPart)
    elseif TunnelCommon.tunnelPortalPlacedEntityNames[startingTunnelPart.name] then
        table.insert(tunnelPortalEntities, startingTunnelPart)
    else
        error("TunnelCommon.CheckTunnelPartsInDirectionAndGetAllParts() unsupported startingTunnelPart.name: " .. startingTunnelPart.name)
    end
    local orientation, continueChecking, nextCheckingPos = Utils.DirectionToOrientation(checkingDirection), true, startingTunnelPartPoint
    while continueChecking do
        nextCheckingPos = Utils.ApplyOffsetToPosition(nextCheckingPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 2}))
        local connectedTunnelEntities = startingTunnelPart.surface.find_entities_filtered {position = nextCheckingPos, name = TunnelCommon.tunnelSegmentAndPortalPlacedEntityNames, force = startingTunnelPart.force, limit = 1}
        if #connectedTunnelEntities == 0 then
            continueChecking = false
        else
            local connectedTunnelEntity = connectedTunnelEntities[1] ---@type LuaEntity
            if connectedTunnelEntity.position.x ~= startingTunnelPart.position.x and connectedTunnelEntity.position.y ~= startingTunnelPart.position.y then
                TunnelCommon.EntityErrorMessage(placer, "Tunnel parts must be in a straight line", connectedTunnelEntity.surface, connectedTunnelEntity.position)
                continueChecking = false
            elseif TunnelCommon.tunnelSegmentPlacedEntityNames[connectedTunnelEntity.name] then
                if connectedTunnelEntity.direction == startingTunnelPart.direction or connectedTunnelEntity.direction == Utils.LoopDirectionValue(startingTunnelPart.direction + 4) then
                    table.insert(tunnelSegmentEntities, connectedTunnelEntity)
                else
                    TunnelCommon.EntityErrorMessage(placer, "Tunnel segments must be in the same direction; horizontal or vertical", connectedTunnelEntity.surface, connectedTunnelEntity.position)
                    continueChecking = false
                end
            elseif TunnelCommon.tunnelPortalPlacedEntityNames[connectedTunnelEntity.name] then
                continueChecking = false
                if connectedTunnelEntity.direction == Utils.LoopDirectionValue(checkingDirection + 4) then
                    table.insert(tunnelPortalEntities, connectedTunnelEntity)
                    return true, tunnelPortalEntities, tunnelSegmentEntities
                else
                    TunnelCommon.EntityErrorMessage(placer, "Tunnel portal facing wrong direction", connectedTunnelEntity.surface, connectedTunnelEntity.position)
                end
                table.insert(tunnelSegmentEntities, connectedTunnelEntity)
            else
                error("unhandled railway_tunnel entity type")
            end
        end
    end
    return false, tunnelPortalEntities, tunnelSegmentEntities
end

---@param placementEntity LuaEntity
---@return boolean
TunnelCommon.IsPlacementOnRailGrid = function(placementEntity)
    if placementEntity.position.x % 2 == 0 or placementEntity.position.y % 2 == 0 then
        return false
    else
        return true
    end
end

---@param placementEntity LuaEntity
---@param placer EntityBuildPlacer
---@param mine boolean @If to mine and return the item to the placer, or just destroy it.
TunnelCommon.UndoInvalidTunnelPartPlacement = function(placementEntity, placer, mine)
    TunnelCommon.UndoInvalidPlacement(placementEntity, placer, mine, true, "Tunnel must be placed on the rail grid", "tunnel part")
end

---@param placementEntity LuaEntity
---@param placer EntityBuildPlacer
---@param mine boolean @If to mine and return the item to the placer, or just destroy it.
---@param highlightValidRailGridPositions boolean @If to show to the placer valid positions on the rail grid.
---@param warningMessageText string @Text shown to the placer
---@param errorEntityNameText string @Entity name shown if the process errors.
TunnelCommon.UndoInvalidPlacement = function(placementEntity, placer, mine, highlightValidRailGridPositions, warningMessageText, errorEntityNameText)
    if placer ~= nil then
        local position, surface, entityName, ghostName, direction = placementEntity.position, placementEntity.surface, placementEntity.name, nil, placementEntity.direction
        if entityName == "entity-ghost" then
            ghostName = placementEntity.ghost_name
        end
        TunnelCommon.EntityErrorMessage(placer, warningMessageText, surface, position)
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
            TunnelCommon.HighlightValidPlacementPositionsOnRailGrid(placer, position, surface, entityName, ghostName, direction)
        end
    else
        placementEntity.destroy()
        game.print("invalid placement of " .. errorEntityNameText .. " by script at {" .. tostring(placementEntity.position.x) .. "," .. tostring(placementEntity.position.y) .. "} removed", Colors.red)
    end
end

--- Highlights the single tiles to the placer player/force that are valid centres for an entity on the rail grid.
---@param placer EntityBuildPlacer
---@param position Position
---@param surface LuaSurface
---@param entityName string
---@param ghostName string
---@param direction defines.direction @Direction of the entity trying to be placed.
TunnelCommon.HighlightValidPlacementPositionsOnRailGrid = function(placer, position, surface, entityName, ghostName, direction)
    local highlightAudience = Utils.GetRenderPlayersForcesFromActioner(placer)
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
            rendering.draw_sprite {sprite = thisHighlightSprite, target = thisPlacementPosition, surface = surface, time_to_live = 300, players = highlightAudience.players, forces = highlightAudience.forces}
        end
    end
end

--- Shows warning/error text on the map to either the player (character) or the force (construction robots) doign the interaction.
---@param entityDoingInteraction EntityBuildPlacer
---@param text string @Text shown.
---@param surface LuaSurface
---@param position Position
TunnelCommon.EntityErrorMessage = function(entityDoingInteraction, text, surface, position)
    local textAudience = Utils.GetRenderPlayersForcesFromActioner(entityDoingInteraction)
    rendering.draw_text {text = text, surface = surface, target = position, time_to_live = 180, players = textAudience.players, forces = textAudience.forces, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
end

---@param railEntityList LuaEntity[]
---@param killForce LuaForce
---@param killerCauseEntity LuaEntity
TunnelCommon.DestroyCarriagesOnRailEntityList = function(railEntityList, killForce, killerCauseEntity)
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

---comment
---@param carriageEntityName string @The entity name.
---@return double
TunnelCommon.GetCarriagePlacementDistance = function(carriageEntityName)
    -- For now we assume all unknown carriages have a gap of 7 as we can't get the connection and joint distance via API. Can hard code custom values in future if needed.
    if carriageEntityName == "railway_tunnel-tunnel_portal_pushing_locomotive" then
        return 0.5
    else
        return 3.5 -- Half of vanilla carriages 7 joint and connection distance.
    end
end

---@class TunnelAlignment
TunnelCommon.TunnelAlignment = {
    vertical = "vertical",
    horizontal = "horizontal"
}

---@class TunnelAlignmentOrientation
TunnelCommon.TunnelAlignmentOrientation = {
    vertical = 0,
    horizontal = 0.25
}

---@class TunnelSignalDirection
TunnelCommon.TunnelSignalDirection = {
    inSignal = "inSignal",
    outSignal = "outSignal"
}

return TunnelCommon
