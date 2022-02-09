local Utils = require("utility.utils")
local CollisionMaskUtil = require("__core__.lualib.collision-mask-util")

local refCharacter = data.raw["character"]["character"]
local characterPlacementLeaveTunnelCollisionMask = Utils.DeepCopy(CollisionMaskUtil.get_mask(refCharacter))
table.insert(characterPlacementLeaveTunnelCollisionMask, "rail-layer")

data:extend(
    {
        Utils.CreatePlacementTestEntityPrototype(refCharacter, "railway_tunnel-character_placement_leave_tunnel", "railway_tunnel-hidden_placement_tests", characterPlacementLeaveTunnelCollisionMask)
    }
)
