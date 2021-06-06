local Utils = require("utility/utils")
local Interfaces = require("utility/interfaces")
local Underground = {}

Underground.CreateGlobals = function()
    global.underground = global.underground or {}
    global.underground.surfaces = global.underground.surfaces or {}
    --[[
        [alignment] = {
            alignment = either "hotizontal" or "vertical"
            surface = The LuaSurface
            refRails = table of the rail entities on this underground that are to be cloned for each tunnel instance.
            trackLengthEachSide = the distance of the ref rails each side of 0 on this surface.
            railAlignmentAxis = the "x" or "y" axis the the underground rails are aligned upon per tunnel.
            tunnelInstanceAxis = the "x" or "y" axis that each tunnel's tracks are spaced along on the underground.
        }
    --]]
    global.underground.undergroundTunnels = global.underground.undergroundTunnels or {}
    --[[
        [id] = {
            id = the parent tunnel's id.
            tunnel = the parent global tunnel object.
            undergroundSurface = ref to underground surface globla object.
            railEntities = table of rail LuaEntity.
            tunnelInstanceValue = this tunnels static value of the tunnelInstanceAxis for the copied (moving) train carriages.
            undergroundOffsetFromSurface = position offset of the underground entities from the surface entities.
            surfaceOffsetFromUnderground = position offset of the surface entities from the undergroud entities.
            undergroundLeadInTiles = the tiles lead in of rail from 0
            undergroundSignals = {
                [id] = {
                    id = undergroundSignalEntity.unit_number.
                    entity = undergroundSignalEntity.
                    aboveGroundSignalPaired = portalSignal.
                    signalStateCombinator = the combinator controlling if this signal is forced closed or not.
                    signalStateCombinatorControlBehavior = cached reference to the ControlBehavior of this undergroundSignal's signalStateCombinator.
                    currentSignalStateCombinatorEnabled = cached copy of if the combiantor was last enabled or not.
                }
            }
            distanceBetweenPortalCenters = The distance from the underground tunnel center to the portal center.
            tunnelRailCenterValue = The tunnelRailCenterValue is for the railAlignmentAxis and has to be based on 1 tile offset from 0 as this is the rail grid. It does mean that odd track count tunnels are never centered around 0.
        }
    ]]
end

Underground.PreOnLoad = function()
    Interfaces.RegisterInterface("Underground.CreateUndergroundTunnel", Underground.CreateUndergroundTunnel)
    Interfaces.RegisterInterface("Underground.SetUndergroundExitSignalState", Underground.SetUndergroundExitSignalState)
    Interfaces.RegisterInterface("Underground.GetForwardsEndOfRailPosition", Underground.GetForwardsEndOfRailPosition)
end

Underground.OnStartup = function()
    if global.underground.surfaces["horizontal"] == nil then
        global.underground.surfaces["horizontal"] = Underground.CreateUndergroundSurface("horizontal")
    end
    if global.underground.surfaces["vertical"] == nil then
        global.underground.surfaces["vertical"] = Underground.CreateUndergroundSurface("vertical")
    end
end

Underground.CreateUndergroundSurface = function(alignment)
    local surfaceName = "railway_tunnel-undeground-" .. alignment
    if game.get_surface(surfaceName) ~= nil then
        -- Mod has been removed and after a clean load re-added. So clean out the old tunnel surfaces as anything on the main surfaces is gone anwyways.
        local existingSurface = game.get_surface(surfaceName)
        existingSurface.name = "OLD-" .. surfaceName -- Rename the surface as it takes a tick for it to be deleted.
        game.delete_surface(existingSurface)
    end
    local surface = game.create_surface(surfaceName)
    surface.generate_with_lab_tiles = true
    surface.always_day = true
    surface.freeze_daytime = true
    surface.show_clouds = false
    surface.request_to_generate_chunks({0, 0}, 10)

    local undergroundSurface = {
        alignment = alignment,
        surface = surface,
        refRails = {},
        trackLengthEachSide = 1000
    }

    local railDirection
    if alignment == "vertical" then
        undergroundSurface.railAlignmentAxis = "y"
        undergroundSurface.tunnelInstanceAxis = "x"
        railDirection = defines.direction.north
    else
        undergroundSurface.railAlignmentAxis = "x"
        undergroundSurface.tunnelInstanceAxis = "y"
        railDirection = defines.direction.east
    end

    -- Add reference rail.
    for valueVariation = -undergroundSurface.trackLengthEachSide, undergroundSurface.trackLengthEachSide, 2 do
        table.insert(undergroundSurface.refRails, surface.create_entity {name = "straight-rail", position = {[undergroundSurface.railAlignmentAxis] = valueVariation, [undergroundSurface.tunnelInstanceAxis] = 1}, force = global.force.tunnelForce, direction = railDirection})
    end

    return undergroundSurface
end

Underground.CreateUndergroundTunnel = function(tunnel)
    local undergroundSurface = global.underground.surfaces[tunnel.alignment]
    local undergroundTunnel = {
        id = tunnel.id,
        tunnel = tunnel,
        undergroundSurface = undergroundSurface,
        railEntities = {},
        tunnelInstanceValue = tunnel.id * 4,
        undergroundSignals = {}
    }
    undergroundTunnel.undergroundLeadInTiles = undergroundSurface.trackLengthEachSide -- This will be dynamically tracked and generated in the future to cater for tunnel length.
    global.underground.undergroundTunnels[undergroundTunnel.id] = undergroundTunnel

    -- Place the rails for this tunnel
    local cloneRailOffset = {
        [undergroundSurface.railAlignmentAxis] = 0,
        [undergroundSurface.tunnelInstanceAxis] = 0 + undergroundTunnel.tunnelInstanceValue
    }
    undergroundTunnel.railEntities = undergroundSurface.surface.clone_entities {entities = undergroundSurface.refRails, destination_offset = cloneRailOffset, create_build_effect_smoke = false}

    -- Generate attributes used by other parts of mod.
    local greatestPortal, lesserPortal
    if tunnel.portals[1].entity.position[undergroundSurface.railAlignmentAxis] > tunnel.portals[2].entity.position[undergroundSurface.railAlignmentAxis] then
        greatestPortal = tunnel.portals[1]
        lesserPortal = tunnel.portals[2]
    else
        greatestPortal = tunnel.portals[2]
        lesserPortal = tunnel.portals[1]
    end
    undergroundTunnel.distanceBetweenPortalCenters = Utils.GetDistanceSingleAxis(greatestPortal.entity.position, lesserPortal.entity.position, undergroundSurface.railAlignmentAxis)
    local undergroundTunnelTiles = undergroundTunnel.distanceBetweenPortalCenters - 50
    -- Get the correct center of the underground tunnel as otherwise the portal entry signals will be on the wrong track pieces.
    if undergroundTunnelTiles % 4 == 0 then
        undergroundTunnel.tunnelRailCenterValue = 0
    else
        undergroundTunnel.tunnelRailCenterValue = 1
    end

    undergroundTunnel.undergroundOffsetFromSurface = {
        [undergroundSurface.railAlignmentAxis] = undergroundTunnel.tunnelRailCenterValue - (greatestPortal.entity.position[undergroundSurface.railAlignmentAxis] - (undergroundTunnel.distanceBetweenPortalCenters / 2)),
        [undergroundSurface.tunnelInstanceAxis] = (1 - tunnel.portals[1].entity.position[undergroundSurface.tunnelInstanceAxis]) + undergroundTunnel.tunnelInstanceValue
    }
    undergroundTunnel.surfaceOffsetFromUnderground = Utils.RotatePositionAround0(0.5, undergroundTunnel.undergroundOffsetFromSurface)

    -- Place the entrance signals from both portals
    for _, portal in pairs(tunnel.portals) do
        for _, portalSignal in pairs(portal.entrySignals) do
            local undergroundSignalPosition = Utils.ApplyOffsetToPosition(portalSignal.entity.position, undergroundTunnel.undergroundOffsetFromSurface)
            local undergroundSignalEntity = undergroundSurface.surface.create_entity {name = "rail-signal", force = global.force.tunnelForce, position = undergroundSignalPosition, direction = portalSignal.entity.direction}
            local undergroundSignal = {
                id = undergroundSignalEntity.unit_number,
                entity = undergroundSignalEntity,
                aboveGroundSignalPaired = portalSignal
            }

            if portalSignal.direction == "out" then
                local signalStateCombinatorPosition = Utils.ApplyOffsetToPosition(undergroundSignalEntity.position, Utils.RotatePositionAround0(portal.entity.orientation, {x = 0, y = 1})) -- 1 tile towards the tunnel center from the signal.
                undergroundSignal.signalStateCombinator = undergroundSurface.surface.create_entity {name = "constant-combinator", force = global.force.tunnelForce, position = signalStateCombinatorPosition}
                local signalStateCombinatorControlBehavior = undergroundSignal.signalStateCombinator.get_or_create_control_behavior()
                undergroundSignal.signalStateCombinatorControlBehavior = signalStateCombinatorControlBehavior
                signalStateCombinatorControlBehavior.set_signal(1, {signal = {type = "virtual", name = "signal-red"}, count = 1})
                signalStateCombinatorControlBehavior.enabled = false
                undergroundSignal.currentSignalStateCombinatorEnabled = false

                undergroundSignalEntity.connect_neighbour {wire = defines.wire_type.red, target_entity = undergroundSignal.signalStateCombinator}

                local undergroundControlBehavior = undergroundSignalEntity.get_or_create_control_behavior()
                undergroundControlBehavior.read_signal = false
                undergroundControlBehavior.close_signal = true
                undergroundControlBehavior.circuit_condition = {condition = {first_signal = {type = "virtual", name = "signal-red"}, comparator = ">", constant = 0}, fulfilled = true}
            end
            undergroundTunnel.undergroundSignals[undergroundSignal.id] = undergroundSignal
            portalSignal.undergroundSignalPaired = undergroundSignal
        end
    end

    return undergroundTunnel
end

Underground.SetUndergroundExitSignalState = function(undergroundSignal, sourceSignalState)
    local closeSignalOn
    if sourceSignalState == defines.signal_state.open then
        closeSignalOn = false
    else
        closeSignalOn = true
    end
    if undergroundSignal.currentSignalStateCombinatorEnabled ~= closeSignalOn then
        undergroundSignal.signalStateCombinatorControlBehavior.enabled = closeSignalOn
        undergroundSignal.currentSignalStateCombinatorEnabled = closeSignalOn
    end
end

Underground.GetForwardsEndOfRailPosition = function(undergroundTunnel, trainTravelOrientation)
    return Utils.ApplyOffsetToPosition(
        Utils.RotatePositionAround0(
            undergroundTunnel.tunnel.alignmentOrientation,
            {
                x = undergroundTunnel.tunnelInstanceValue + 1,
                y = 0
            }
        ),
        Utils.RotatePositionAround0(
            trainTravelOrientation,
            {
                x = 0,
                y = 0 - (undergroundTunnel.undergroundLeadInTiles - 1)
            }
        )
    )
end

return Underground
