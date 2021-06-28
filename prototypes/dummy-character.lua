local Utils = require("utility/utils")

local dummyCharacter = Utils.DeepCopy(data.raw["character"]["character"])
dummyCharacter.name = "railway_tunnel-dummy_character"
dummyCharacter.subgroup = "railway_tunnel-hidden_cars"
dummyCharacter.flags = {"not-on-map", "placeable-off-grid", "not-selectable-in-game"}
dummyCharacter.collision_mask = {}
dummyCharacter.corpse = nil

data:extend(
    {
        dummyCharacter
    }
)
