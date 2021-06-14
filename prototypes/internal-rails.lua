local Utils = require("utility/utils")
local CommonPrototypeFunctions = require("prototypes/common-prototype-functions")

local refStraightRail = data.raw["straight-rail"]["straight-rail"]

local internalRailBase = {
    type = "straight-rail",
    icon = "__base__/graphics/icons/rail.png",
    icon_size = 64,
    icon_mipmaps = 4,
    subgroup = "railway_tunnel-hidden_rails",
    flags = {"not-repairable", "not-blueprintable", "not-deconstructable", "no-copy-paste", "not-upgradable", "player-creation"}, -- We want it to show on the map to help tunnels look better.
    selectable_in_game = false,
    collision_mask = {"rail-layer"}, -- Just collide with other rails.
    pictures = refStraightRail.pictures
}

local portalRailOnMap = Utils.DeepCopy(internalRailBase)
portalRailOnMap.name = "railway_tunnel-portal_rail-on_map"

-- The crossing rail isn't used to make part of the tunnel itself, but to be a rail crossing the tunnel.
local crossingRailOnMap = Utils.DeepCopy(internalRailBase)
crossingRailOnMap.name = "railway_tunnel-crossing_rail-on_map"

local internalRailNotOnMap = Utils.DeepCopy(internalRailBase)
internalRailNotOnMap.name = "railway_tunnel-internal_rail-not_on_map"
table.insert(internalRailNotOnMap.flags, "not-on-map")

local internalRailOnMapTunnel = Utils.DeepCopy(internalRailBase)
internalRailOnMapTunnel.name = "railway_tunnel-internal_rail-on_map_tunnel"
internalRailOnMapTunnel.map_color = CommonPrototypeFunctions.TunnelMapColor

data:extend(
    {
        portalRailOnMap,
        crossingRailOnMap,
        internalRailNotOnMap,
        internalRailOnMapTunnel
    }
)
