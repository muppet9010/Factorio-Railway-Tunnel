local PrototypeUtils = require("utility.prototype-utils")
local TableUtils = require("utility.table-utils")
local CollisionMaskUtil = require("__core__.lualib.collision-mask-util")

local refCharacter = data.raw["character"]["character"]
local characterPlacementLeaveTunnelCollisionMask = TableUtils.DeepCopy(CollisionMaskUtil.get_mask(refCharacter))
table.insert(characterPlacementLeaveTunnelCollisionMask, "rail-layer")

data:extend(
    {
        PrototypeUtils.CreatePlacementTestEntityPrototype(refCharacter, "railway_tunnel-character_placement_leave_tunnel", "railway_tunnel-hidden_placement_tests", characterPlacementLeaveTunnelCollisionMask)
    }
)
