local Utils = require("utility/utils")

--[[
    Once created we will put a dummy character in the passanger seat to avoid possibility of someone else getting in.
    We teleport the vehicle and so it has 0 speed itself so the player can't have any movement control.
]]
local playerContainer = {
    type = "car",
    name = "railway_tunnel-player_container",
    icon = "__railway_tunnel__/graphics/icon/tunnel_portal_surface/railway_tunnel-tunnel_portal_surface-placement.png",
    icon_size = 32,
    icon_mipmaps = 4,
    subgroup = "railway_tunnel-hidden_cars",
    collision_mask = {},
    flags = {"not-on-map", "placeable-off-grid", "not-selectable-in-game"},
    weight = 1,
    braking_force = 1,
    friction_force = 1,
    energy_per_hit_point = 1,
    animation = Utils.EmptyRotatedSprite(),
    energy_source = {
        type = "void"
    },
    consumption = "1W",
    effectivity = 1,
    inventory_size = 0,
    rotation_speed = 0
}

local playerContainerPassangerCharacter = Utils.DeepCopy(data.raw["character"]["character"])
playerContainerPassangerCharacter.name = "railway_tunnel-player_container_passanger_character"
playerContainerPassangerCharacter.subgroup = "railway_tunnel-hidden_cars"
playerContainerPassangerCharacter.flags = {"not-on-map", "placeable-off-grid", "not-selectable-in-game"}
playerContainerPassangerCharacter.collision_mask = {}
playerContainerPassangerCharacter.corpse = nil

data:extend(
    {
        playerContainer,
        playerContainerPassangerCharacter
    }
)
