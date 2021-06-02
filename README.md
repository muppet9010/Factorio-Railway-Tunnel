# Factorio-Railway-Tunnel

ALPHA MOD - Early release mod and versions won't upgrade. Use for testing/experimenting only.
==============================

Mod Features
===========

- Trains will natively use tunnels just like any other track, no need to specially path via them. You can have a train stop part way in/out of a tunnel at a signal or station and then resume or reverse its journey.
- The tunnel is a single block of rail and so only 1 train can use a tunnel at a time. Trains do prefer empty normal tracks over tunnels, but will use a tunnel over congested track.
- Tunnels are built by placing the entrance and exit pieces (rails outwards) and then building underground tunnel between them. When a tunnel is complete rail signals will appear on both ends of the tunnel. Special pieces of underground tunnel allow for rail tracks on the surface to cross the tunnel.


Usage Notes
===============

- The train signal reservation for leaving a tunnel may be sub optimal and so it's advised to have some track and a signal block for the train to emerge in to. The train may also pull up to a blocking signal slowly when leaving a tunnel.
- Trains using a tunnel will never be exactly aligned for the entering and leaving parts, but will be very close. This is a technical limitation of how the mod syncs train speeds each tick and isn't a bug.
- If a train is using a tunnel and some track in its path is removed, it will try and repath like normal Factorio (forwards/backwards) from the tunnel. If it can't path it will pull to the front of the tunnel so it can be accessed by the player easier.

Contributors
===============

- blahfasel2000 - code contributions.
