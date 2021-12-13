local Utils = require("utility/utils")
local Colors = require("utility/colors")
local Common = {}

-- Make the entity lists.
---@typelist table<string, string>, table<string, string>, table<string, string>, table<string, string>
Common.TunnelSegmentPlacedEntityNames, Common.TunnelSegmentPlacementEntityNames, Common.TunnelPortalPlacedEntityNames, Common.TunnelPortalPlacementEntityNames = {}, {}, {}, {}
for _, coreName in pairs({"railway_tunnel-tunnel_segment_surface", "railway_tunnel-tunnel_segment_surface_rail_crossing"}) do
    Common.TunnelSegmentPlacedEntityNames[coreName .. "-placed"] = coreName .. "-placed"
    Common.TunnelSegmentPlacementEntityNames[coreName .. "-placement"] = coreName .. "-placement"
end
Common.TunnelSegmentPlacedPlacementEntityNames = Utils.TableMerge({Common.TunnelSegmentPlacedEntityNames, Common.TunnelSegmentPlacementEntityNames}) ---@type table<string, string>
for _, coreName in pairs({"railway_tunnel-tunnel_portal_surface"}) do
    Common.TunnelPortalPlacedEntityNames[coreName .. "-placed"] = coreName .. "-placed"
    Common.TunnelPortalPlacementEntityNames[coreName .. "-placement"] = coreName .. "-placement"
end
Common.TunnelPortalPlacedPlacementEntityNames = Utils.TableMerge({Common.TunnelPortalPlacedEntityNames, Common.TunnelPortalPlacementEntityNames}) ---@type table<string, string>
Common.TunnelSegmentAndPortalPlacedEntityNames = Utils.TableMerge({Common.TunnelSegmentPlacedEntityNames, Common.TunnelPortalPlacedEntityNames}) ---@type table<string, string>
Common.TunnelSegmentAndPortalPlacedPlacementEntityNames = Utils.TableMerge({Common.TunnelSegmentPlacedEntityNames, Common.TunnelSegmentPlacementEntityNames, Common.TunnelPortalPlacedEntityNames, Common.TunnelPortalPlacementEntityNames}) ---@type table<string, string>

---@class TunnelSurfaceRailEntityNames
Common.TunnelSurfaceRailEntityNames = {
    -- Doesn't include the tunnel crossing rail as this isn't deemed part of the tunnel's rails.
    ["railway_tunnel-portal_rail-on_map"] = "railway_tunnel-portal_rail-on_map", ---@type TunnelSurfaceRailEntityNames
    ["railway_tunnel-internal_rail-not_on_map"] = "railway_tunnel-internal_rail-not_on_map", ---@type TunnelSurfaceRailEntityNames
    ["railway_tunnel-internal_rail-on_map_tunnel"] = "railway_tunnel-internal_rail-on_map_tunnel", ---@type TunnelSurfaceRailEntityNames
    ["railway_tunnel-invisible_rail-not_on_map"] = "railway_tunnel-invisible_rail-not_on_map", ---@type TunnelSurfaceRailEntityNames
    ["railway_tunnel-invisible_rail-on_map_tunnel"] = "railway_tunnel-invisible_rail-on_map_tunnel" ---@type TunnelSurfaceRailEntityNames
}

---@class RollingStockTypes
Common.RollingStockTypes = {
    ["locomotive"] = "locomotive", ---@type RollingStockTypes
    ["cargo-wagon"] = "cargo-wagon", ---@type RollingStockTypes
    ["fluid-wagon"] = "fluid-wagon", ---@type RollingStockTypes
    ["artillery-wagon"] = "artillery-wagon" ---@type RollingStockTypes
}

---@param startingTunnelPart LuaEntity
---@param startingTunnelPartPoint Position
---@param checkingDirection defines.direction
---@param placer EntityActioner
---@return boolean @Direction is completed successfully.
---@return LuaEntity[] @Tunnel portal entities.
---@return LuaEntity[] @Tunnel segment entities.
Common.CheckTunnelPartsInDirectionAndGetAllParts = function(startingTunnelPart, startingTunnelPartPoint, checkingDirection, placer, tunnelPortalEntities, tunnelSegmentEntities)
    if Common.TunnelSegmentPlacedEntityNames[startingTunnelPart.name] then
        -- Only include the starting tunnel segment when we are checking its direction, not when checking from it the other direction. Otherwise we double add it.
        if checkingDirection == startingTunnelPart.direction then
            table.insert(tunnelSegmentEntities, startingTunnelPart)
        end
    elseif Common.TunnelPortalPlacedEntityNames[startingTunnelPart.name] then
        table.insert(tunnelPortalEntities, startingTunnelPart)
    else
        error("Common.CheckTunnelPartsInDirectionAndGetAllParts() unsupported startingTunnelPart.name: " .. startingTunnelPart.name)
    end
    local orientation, continueChecking, nextCheckingPos = Utils.DirectionToOrientation(checkingDirection), true, startingTunnelPartPoint
    while continueChecking do
        nextCheckingPos = Utils.ApplyOffsetToPosition(nextCheckingPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 2}))
        local connectedTunnelEntities = startingTunnelPart.surface.find_entities_filtered {position = nextCheckingPos, name = Common.TunnelSegmentAndPortalPlacedEntityNames, force = startingTunnelPart.force, limit = 1}
        if #connectedTunnelEntities == 0 then
            continueChecking = false
        else
            local connectedTunnelEntity = connectedTunnelEntities[1] ---@type LuaEntity
            if connectedTunnelEntity.position.x ~= startingTunnelPart.position.x and connectedTunnelEntity.position.y ~= startingTunnelPart.position.y then
                Common.EntityErrorMessage(placer, "Tunnel parts must be in a straight line", connectedTunnelEntity.surface, connectedTunnelEntity.position)
                continueChecking = false
            elseif Common.TunnelSegmentPlacedEntityNames[connectedTunnelEntity.name] then
                if connectedTunnelEntity.direction == startingTunnelPart.direction or connectedTunnelEntity.direction == Utils.LoopDirectionValue(startingTunnelPart.direction + 4) then
                    table.insert(tunnelSegmentEntities, connectedTunnelEntity)
                else
                    Common.EntityErrorMessage(placer, "Tunnel segments must be in the same direction; horizontal or vertical", connectedTunnelEntity.surface, connectedTunnelEntity.position)
                    continueChecking = false
                end
            elseif Common.TunnelPortalPlacedEntityNames[connectedTunnelEntity.name] then
                continueChecking = false
                if connectedTunnelEntity.direction == Utils.LoopDirectionValue(checkingDirection + 4) then
                    table.insert(tunnelPortalEntities, connectedTunnelEntity)
                    return true, tunnelPortalEntities, tunnelSegmentEntities
                else
                    Common.EntityErrorMessage(placer, "Tunnel portal facing wrong direction", connectedTunnelEntity.surface, connectedTunnelEntity.position)
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
Common.IsPlacementOnRailGrid = function(placementEntity)
    if placementEntity.position.x % 2 == 0 or placementEntity.position.y % 2 == 0 then
        return false
    else
        return true
    end
end

---@param placementEntity LuaEntity
---@param placer EntityActioner
---@param mine boolean @If to mine and return the item to the placer, or just destroy it.
Common.UndoInvalidTunnelPartPlacement = function(placementEntity, placer, mine)
    Common.UndoInvalidPlacement(placementEntity, placer, mine, true, "Tunnel must be placed on the rail grid", "tunnel part")
end

---@param placementEntity LuaEntity
---@param placer EntityActioner
---@param mine boolean @If to mine and return the item to the placer, or just destroy it.
---@param highlightValidRailGridPositions boolean @If to show to the placer valid positions on the rail grid.
---@param warningMessageText string @Text shown to the placer
---@param errorEntityNameText string @Entity name shown if the process errors.
Common.UndoInvalidPlacement = function(placementEntity, placer, mine, highlightValidRailGridPositions, warningMessageText, errorEntityNameText)
    if placer ~= nil then
        local position, surface, entityName, ghostName, direction = placementEntity.position, placementEntity.surface, placementEntity.name, nil, placementEntity.direction
        if entityName == "entity-ghost" then
            ghostName = placementEntity.ghost_name
        end
        Common.EntityErrorMessage(placer, warningMessageText, surface, position)
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
            Common.HighlightValidPlacementPositionsOnRailGrid(placer, position, surface, entityName, ghostName, direction)
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
Common.HighlightValidPlacementPositionsOnRailGrid = function(placer, position, surface, entityName, ghostName, direction)
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
Common.EntityErrorMessage = function(entityDoingInteraction, text, surface, position)
    local textAudiencePlayers, textAudienceForces = Utils.GetRenderPlayersForcesFromActioner(entityDoingInteraction)
    rendering.draw_text {text = text, surface = surface, target = position, time_to_live = 180, players = textAudiencePlayers, forces = textAudienceForces, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
end

---@param railEntityList LuaEntity[]
---@param killForce LuaForce
---@param killerCauseEntity LuaEntity
Common.DestroyCarriagesOnRailEntityList = function(railEntityList, killForce, killerCauseEntity)
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

-- Gets the distance from the center of the carriage to the end of it for when placing carriages.
---@param carriageEntityName string @The entity name.
---@return double
Common.GetCarriagePlacementDistance = function(carriageEntityName)
    -- For now we assume all unknown carriages have a gap of 7 as we can't get the connection and joint distance via API. Can hard code custom values in future if needed.
    if carriageEntityName ~= nil then
        return 3.5 -- Half of vanilla carriages 7 joint and connection distance.
    end
end

---@class TunnelAlignment
Common.TunnelAlignment = {
    vertical = "vertical",
    horizontal = "horizontal"
}

---@class TunnelAlignmentOrientation
Common.TunnelAlignmentOrientation = {
    vertical = 0,
    horizontal = 0.25
}

---@class TunnelSignalDirection
Common.TunnelSignalDirection = {
    inSignal = "inSignal",
    outSignal = "outSignal"
}

-- The managed train's state. Finished is for when the tunnel trip is completed.
---@class PrimaryTrainState
Common.PrimaryTrainState = {
    portalTrack = "portalTrack", ---@type PrimaryTrainState
    approaching = "approaching", ---@type PrimaryTrainState
    underground = "underground", ---@type PrimaryTrainState
    leaving = "leaving", ---@type PrimaryTrainState
    finished = "finished" ---@type PrimaryTrainState
}

-- A specific LuaTrain's role within its parent managed train object.
---@class TunnelUsageParts
Common.TunnelUsageParts = {
    enteringTrain = "enteringTrain", ---@type TunnelUsageParts
    dummyTrain = "dummyTrain", ---@type TunnelUsageParts
    leftTrain = "leftTrain", ---@type TunnelUsageParts
    portalTrackTrain = "portalTrackTrain" ---@type TunnelUsageParts
}

-- The train's state - Used by the train manager remote for state notifications to remote interface calls.
---@class TunnelUsageAction
Common.TunnelUsageAction = {
    startApproaching = "startApproaching", ---@type TunnelUsageAction
    terminated = "terminated", ---@type TunnelUsageAction
    fullyEntered = "fullyEntered", ---@type TunnelUsageAction
    fullyLeft = "fullyLeft", ---@type TunnelUsageAction
    onPortalTrack = "onPortalTrack" ---@type TunnelUsageAction
}

-- The train's state change reason - Used by the train manager remote for state notifications to remote interface calls.
---@class TunnelUsageChangeReason
Common.TunnelUsageChangeReason = {
    reversedAfterLeft = "reversedAfterLeft", ---@type TunnelUsageChangeReason
    abortedApproach = "abortedApproach", ---@type TunnelUsageChangeReason
    completedTunnelUsage = "completedTunnelUsage", ---@type TunnelUsageChangeReason
    tunnelRemoved = "tunnelRemoved", ---@type TunnelUsageChangeReason
    portalTrackReleased = "portalTrackReleased" ---@type TunnelUsageChangeReason
}

return Common
