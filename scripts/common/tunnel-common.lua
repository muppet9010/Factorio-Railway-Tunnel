--local Events = require("utility/events")
--local Interfaces = require("utility/interfaces")
local Utils = require("utility/utils")
local TunnelCommon = {}

TunnelCommon.setupValues = {
    entranceFromCenter = 25,
    -- Tunnels distance starts from the first entrace tile.
    entrySignalsDistance = 1,
    endSignalsDistance = 49,
    straightRailCountFromEntrance = 21,
    invisibleRailCountFromEntrance = 4,
    undergroundLeadInTiles = 100 -- hard coded for now just cos
}

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

TunnelCommon.CheckTunnelPartsInDirection = function(startingTunnelPart, startingTunnelPartPoint, tunnelPortals, tunnelSegments, checkingDirection, placer)
    local orientation = checkingDirection / 8
    local continueChecking = true
    local nextCheckingPos = startingTunnelPartPoint
    while continueChecking do
        nextCheckingPos = Utils.ApplyOffsetToPosition(nextCheckingPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 2}))
        local connectedTunnelEntities = startingTunnelPart.surface.find_entities_filtered {position = nextCheckingPos, name = TunnelCommon.tunnelSegmentAndPortalPlacedEntityNames, force = startingTunnelPart.force, limit = 1}
        if #connectedTunnelEntities == 0 then
            continueChecking = false
        else
            local connectedTunnelEntity = connectedTunnelEntities[1]
            if connectedTunnelEntity.position.x ~= startingTunnelPart.position.x and connectedTunnelEntity.position.y ~= startingTunnelPart.position.y then
                TunnelCommon.EntityErrorMessage(placer, "Tunnel parts must be in a straight line", connectedTunnelEntity)
                continueChecking = false
            elseif TunnelCommon.tunnelSegmentPlacedEntityNames[connectedTunnelEntity.name] then
                if connectedTunnelEntity.direction == startingTunnelPart.direction or connectedTunnelEntity.direction == Utils.LoopDirectionValue(startingTunnelPart.direction + 4) then
                    table.insert(tunnelSegments, connectedTunnelEntity)
                else
                    TunnelCommon.EntityErrorMessage(placer, "Tunnel segments must be in the same direction; horizontal or vertical", connectedTunnelEntity)
                    continueChecking = false
                end
            elseif TunnelCommon.tunnelPortalPlacedEntityNames[connectedTunnelEntity.name] then
                continueChecking = false
                if connectedTunnelEntity.direction == Utils.LoopDirectionValue(checkingDirection + 4) then
                    table.insert(tunnelPortals, connectedTunnelEntity)
                    return true
                else
                    TunnelCommon.EntityErrorMessage(placer, "Tunnel portal facing wrong direction", connectedTunnelEntity)
                end
            else
                error("unhandled railway_tunnel entity type")
            end
        end
    end
    return false
end

TunnelCommon.UndoInvalidPlacement = function(placementEntity, placer, mine)
    if placer ~= nil then
        TunnelCommon.EntityErrorMessage(placer, "Tunnel must be placed on the rail grid", placementEntity)
        if mine then
            local result
            if placer.is_player() then
                result = placer.mine_entity(placementEntity, true) --TODO: this triggers the on mined event. This may be bad????
            else
                -- Is construction bot
                result = placementEntity.mine({inventory = placer.get_inventory(defines.inventory.robot_cargo), force = true, raise_destroyed = false, ignore_minable = true})
            end
            if result ~= true then
                error("couldn't mine invalidly placed tunnel placement entity")
            end
        else
            placementEntity.destroy()
        end
    end
end

TunnelCommon.EntityErrorMessage = function(entityDoingInteraction, text, entityErrored)
    local textAudience = Utils.GetRenderPlayersForcesFromActioner(entityDoingInteraction)
    rendering.draw_text {text = text, surface = entityErrored.surface, target = entityErrored.position, time_to_live = 180, players = textAudience.players, forces = textAudience.forces, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
end

return TunnelCommon
