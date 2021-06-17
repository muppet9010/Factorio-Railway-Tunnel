# Factorio-Railway-Tunnel

ALPHA MOD - Early release mod and versions won't upgrade. Use for testing/experimenting only.
==============================


Mod Features
===========

- Trains will natively use tunnels just like any other track, no need to specially path via them. You can have a train stop part way in/out of a tunnel at a signal or station and then resume or reverse its journey.
- Tunnels are built by placing the entrance and exit pieces (rails outwards) and then building underground tunnel between them. When a tunnel is complete rail signals will appear on both ends of the tunnel. Special pieces of underground tunnel allow for rail tracks on the surface to cross the tunnel.
- Tunnels can not be entered by players, they are purely for trains to go under one another. Players riding in trains through tunnels stay on the surface to enjoy the view.
- The tunnel parts can only be validly placed on the rail grid, however it isn't possible to snap these like regular rail track. So if the tunnel part is misplaced the nearby rail grid locations will be highlighted; A green square for buildable locations and a red square for blocked locations, based on ghost type placement.


Usage Notes
===============

- The tunnel is a single block of rail and so only 1 train can use a tunnel at a time. Trains do prefer empty normal tracks over tunnels, but will use a tunnel over congested track (few trains or medium distance).
- The train signal reservation for leaving a tunnel may be sub optimal and so it's advised to have some track and a signal block for the train to emerge in to. The train may also pull up to a blocking signal slowly when leaving a tunnel.
- Trains using a tunnel will never be exactly aligned for the entering and leaving parts, but will be very close. This is a technical limitation of how the mod syncs train speeds each tick and isn't a bug.
- If a train is using a tunnel and some track in its path is removed, it will try and repath like normal Factorio (forwards/backwards) from the tunnel. If it can't path it will pull to the front of the tunnel so it can be accessed by the player easier.
- Manually driven trains that enter a tunnel will go through on automatic for the tunnel journey, with control returned to the player when they emerge from the tunnel.
- Any train using a tunnel that has an issue (runs out of fuel, has a carriage removed, etc) will be pushed fully out of the tunnel so it can be fixed by the player.
- Destroyed tunnels will lose the train and players within.
- While a train is entering a tunnel access by the player is restricted. The leaving train can be manipulated if needed.


Editor Mode
===============

- Don't mine any part of a tunnel while in Editor mode in the Entity tab. As this just removes the tunnel part without notifying the mod. If you are in any other tab (i.e. Time) then this is fine as Factorio notifies the mod. You know this has happened when the tunnel is removed, but other hidden parts of the tunnel (like rails) remain. In this case I'd advise loading a save from before this corrupted state was reached.
- This may apply to other modded creative modes that don't raise events on removing entities from the map.


Debug Release
==============

In debug releases of the mod if an error occurs a full mod state dump will be done in to the clients Factorio Data "script-output" folder. This will be stated in the error message on screen at the time of the error. The file will be named "railway_tunnel error details - " and then a semi-random number. It should be provided with any bug report to the mod author.


Contributors
===============

- blahfasel2000 - code contributions.


Rejected Ideas
===============

Let players control manual trains speed through the tunnel
---------------
While this is likely possible, its a lot of mod development work for very little reward. The current automatic tunnel journey enables support of manual trains without delaying wider mod development significantly for them.