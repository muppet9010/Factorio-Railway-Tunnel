--[[
    Simple entity that only collides with the train layer to block trains placement and passing (if indestructible). Doesn't trigger signals.
]]
local Utils = require("utility/utils")

local baseBlockerPrototype = {
    type = "simple-entity-with-owner",
    icons = {
        {
            icon = "__base__/graphics/icons/locomotive.png",
            icon_size = 64,
            icon_mipmaps = 4
        },
        {
            icon = "__core__/graphics/cancel.png",
            icon_size = 64,
            scale = 0.5,
            icon_mipmaps = 0
        }
    },
    subgroup = "railway_tunnel-train_blockers",
    flags = {"not-repairable", "not-blueprintable", "not-deconstructable", "no-copy-paste", "not-upgradable", "placeable-off-grid", "not-in-kill-statistics"},
    selectable_in_game = false,
    collision_mask = {"train-layer"}, -- Just collide with trains.
    picture = Utils.EmptyRotatedSprite(),
    map_color = {0, 0, 0, 0}, -- No map color ever.
    friendly_map_color = {0, 0, 0, 0}, -- No map color ever.
    enemy_map_color = {0, 0, 0, 0} -- No map color ever.
    --selection_box = {{-0.5, -0.5}, {0.5, 0.5}} -- For testing when we need to select them
}

local portalEntryTrainDetector1x1 = Utils.DeepCopy(baseBlockerPrototype)
portalEntryTrainDetector1x1.name = "railway_tunnel-portal_entry_train_detector_1x1"
portalEntryTrainDetector1x1.collision_box = {{-0.4, -0.4}, {0.4, 0.4}}

local portalTransitionTrainDetector1x1 = Utils.DeepCopy(baseBlockerPrototype)
portalTransitionTrainDetector1x1.name = "railway_tunnel-portal_transition_train_detector_1x1"
portalTransitionTrainDetector1x1.collision_box = {{-0.4, -0.4}, {0.4, 0.4}}

local blocker2x2 = Utils.DeepCopy(baseBlockerPrototype)
blocker2x2.name = "railway_tunnel-train_blocker_2x2"
blocker2x2.collision_box = {{-0.8, -0.8}, {0.8, 0.8}}

data:extend(
    {
        portalEntryTrainDetector1x1,
        portalTransitionTrainDetector1x1,
        blocker2x2
    }
)
