local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local tunnelRailSurfaceCollisionLayer = CollisionMaskUtil.get_first_unused_layer()

-- This needs a placment entity with 2 or 4 orientations.
-- It shoudl have the collsion boxes and graphics for the tunnel placement piece on the surface.
-- Once placed it can be have an invisble rail and have the hidden signals added.
-- The placement entity should collide with all rails so you can't join regular track on to it easily. Should have a tunnel crossing entity that is fast replaceable with the tunnel placement piece. Would need to be same size as the tunnel track placement entity.
