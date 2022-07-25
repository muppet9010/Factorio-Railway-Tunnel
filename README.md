# Factorio-Railway-Tunnel

ALPHA MOD
=========

Early release of the mod and you can't upgrade to future releases. Use for testing/experimenting only.

This is a demonstration release of the mod. At present there are no plans to continue development of the mod. See the Mod Design History section at the end of the file.

All references to curves/bends in tunnels in the game and this readme relate to incomplete feature development. This can be enabled with the mod's startup setting, but these curved tunnels are non functional and are just provided as a demonstration of the building system. Any tunnel built with curves will fail to complete and thus not be usable. This is also why the underground parts of the tunnel have curves and the tunnel portal parts don't.


Mod Features
============

- Trains will natively use tunnels just like any other track, no need to specially path via them.
- Tunnels are built by placing the entrance and exit tunnel portal parts and building underground tunnel parts between them. Special pieces of underground tunnel allow for rail tracks on the surface to cross the tunnel. This module design allows for maximum design flexibility.
- Tunnels support "bendy" parts for both portal segments and underground types in the form of corner, curve and diagonal parts. They give flexability when building more complicated designs and so its easier to build tunnel portals long enough for trains to fit within. These do unfortunatly have some usage considerations and limitations as detailed under the Usage Notes section.
- The mod has been designed and optimised to be UPS efficient considering what it is trying to do.
- Tunnels can be used in both directions, however, the mod is designed on the basis that most tunnels will be either used in a single direction as part of dual tracks or bi-directional on a very low usage rail track. There is a documented limitation around a rare issue with high frequency bi-diretional tunnel usage later in this readme.
- Tunnel/Portal GUI shown when a portal part is clicked on. Shows key information about it including the size of train it supports and the current usage state. It has features to help the player handle any odd situations, with options to distribute fuel to the train using the tunnel, and an option to mine all train carriages on the tunnel portal's tracks.
- Tunnels can not be entered by players, they are purely for trains to go under one another. Players riding in trains through tunnels stay on the surface to enjoy the view.
- A train must fully fit within the tunnel's entrance and exit portal to be able to use the tunnel. If the train is too long it will be prevented access upon entry and a GUI alert raised to the player for them to manually correct the issue. Some consideration in tunnel/rail network disng is thus required.


Usage Notes
===========

- Tunnels are composed of 2 complete portals with underground parts connecting them.
    - A complete portal is made of 2 portal End parts with a number of portal Segments between them. Each portal's segment’s length (end parts not counted) must be long enough for the train when it tries to use the tunnel.
        - When a complete portal is made a tunnel portal graphic will appear with both ends of the portal closed to trains.
    - The underground of the tunnel is made up of a series of underground parts.
    - When 2 valid portals are connected by underground parts a tunnel is formed. This can be seen as the outside ends of each portal facing the wider rail network will have their graphics show an opening, with rail and signals appearing on them. At this point trains can path through the tunnel and use it.
- Too long a train trying to use a tunnel will be prevented, but unfortunately I can't stop a train that is too long trying to path through the tunnel so some consideration by the player when building their rail network is required. The max length train a tunnel can accept is the minimum length of either portal's segments (non end parts). A train's length for vanilla Factorio carriages is 6 tiles, plus 1 tile per carriage connection. This will match the length of a train on a regular track. i.e. 1 carriage is 6 tiles, 2 carriages are 13 tiles (6+1+6). This limitation was introduced as it massively saves on UPS and with large bases this is very important.
- The tunnel parts can only be validly placed on the rail grid, however, it isn't possible to snap these like a regular rail track. So if the tunnel part is misplaced the nearby rail grid locations will be highlighted, a green square for buildable locations and a red square for blocked locations, based on ghost type placement.
- The tunnel is a single block of rail and so only 1 train can use a tunnel at a time. Trains do slightly prefer empty normal tracks over tunnels, but will use a tunnel over congested track.
- Bendy tunnel parts of corner, curve and diagonal parts are a bit special all around, but it is the best overall compromise I could find.
    - The 3 types of bendy parts are:
        - Corner parts are the inner part of a 90 degree bend with their 2 ends being on the diagonal.
        - Curve parts are the ends of a bendy track section and have one end straight and the other end on the diagonal.
        - Diagonal parts are diagonal and have both ends as diagonals.
    - When building with bendy parts the below rules apply:
        - Portal bendy parts must go between the straight End parts.
        - Tunnel parts (straight and bendy) must connect to each other in the same orientation (both straight or diagonal). This can be easily seen by the arrows on the parts must connect to each other in a consistent line, with any change of direction happening within a part.
        - 2 curve parts can not directly connect to each other on their diagonal end as this is a tighter S bend than Factorio rail track allows. So atleast one other part must be between them, either a diagonal or a corner part. A message will appear ingame if this tries to be done.
    - Tunnel parts of type curve and diagonal (not corners) have 2 versions, but made easy for players usage:
        - They have both a regular entity with 4 orientations that all connect to each other and a flipped entity with the other 4 rotations that all connect to each other. The regular and flipped entity rotations corrispond to if you flip a blueprint with the tunnel parts in them.
        - The flipped part items however are faked by the mod for player convience (the special bit).
        - Players and bots only craft and carry regular curve and diagonal part items. The regualr part items are able to build both regular and flipped orientations of entites. This is to facilitate ease of blue print design, player building, bot building, item crafting and carrying.
        - A player can get a flipped item of a part by holding a regular part item in their hand (cursor) and pressing your standard Factorio blueprint flip key. With the flipped item having a big F on its icon if you hover over something where its icon is shown, i.e. you player hotbar or an inventory. You can also return a flipped item back to a regular item by pressing the same blueprint flip key again.
        - You can also obtain a flipped item version if you use the smart pipette feature on a flipped part entity or ghost.
        - The flipped item only exists in your hand (cursor) for manual building/ghost placing. This means if you try and use the flipped item for anything else the game will just ignore your request and possibly return the item to your inventory with no loss of item count, this includes: as an inventory filter, drop on the ground, put in a chest.
        - Any tunnel curve or diagonal parts in blueprints will not be correct if the blueprint is flipped as I can't manipulate a blueprint's contents upon flipping safely. This shouldn't be a major issue as you can't flip bleurpints with rail signals in them either in base Factorio. At present a message ingame advises of this situation and of the 2 options the player has; One, flip the blueprint back and it will all be fine again, you can still rotate the blueprint safely. Two, paste the flipped blueprint with any curve and diagonal parts facing the wrong way and then manually replace them with the flipped entity, as the rest of the bluepritn will still be there and so the manual fix is usally very quick and easy.
- Trains using a tunnel have their speed and traversal time estimated. This means a train using a tunnel won't be exactly the same speed as a train on a regular track, but they are approximately equivalent in their total journey time.
- If a train is using a tunnel and its forward path is removed due to rail network or station changes, once it has left the underground section it can look for a reverse path back through the tunnel. If it can't find a route it will pull to the front of the tunnel's exit portal ready for a path becoming available in the future. This delay in re-pathing may cause it to lose a station reservation if station train limits are being used.
- Manually driven trains can not use a tunnel. They will be stopped at the tunnel portal entrance track or from entering the underground part of the tunnel. There is a known limitation documented in relation to a contrived scenario that will cause a crash for player driven trains.
- Trains that aren't following an automatic schedule will be prevented from entering the tunnel portal's tracks or going underground. Tunnels are reserved for intentional train traffic and not free wheeling trains.
- Destroyed tunnels will lose the train within and players' corpses will be left on the surface.
- If 2 trains try to enter a tunnel at once one will be rejected and a GUI alert raised.
- Trains with players riding in them use a more detailed tunnel traversal logic than non-player trains to give the player a smoother riding experience. This will mean that they take a different amount of time to use a tunnel as its speed is more actively managed. This is only done for trains with players riding in them as it’s less UPS efficient and is approximately the same final result.


Known Limitations
=================

There are certain limitations of the mod which have been chosen over alternatives. The reasons for these choices can include keeping the mod as light UPS wise as possible, to avoid overly complicated code logic for non standard (edge) use cases or just due to limitations in Factorio and how a mod can interact with it.

- When a tunnel is being used bi-directionally (2 ways) and 2 trains simultaneously approach from opposite ends in the specific situation of; an unused tunnel, with clear approaching track, both trains at slow speeds; In some cases they can both be allowed to reserve a path into the tunnel. When they both reach the portal they will be mutually blocking each other from using the tunnel, leaving the rails deadlocked. At present the 2 trains are stopped and a GUI alert is raised for both trains to the player to manually resolve as it should be a very rare occurrence. This is not an issue when the tunnel is being used in a single direction rail line, as is the mod's primary expected use case.
- Trains kill counts will be lost when using a tunnel as the Factorio API doesn't allow this to be set by a mod. It will also be artificially inflated by 1 when a train leaves the tunnel. Factorio API request: https://forums.factorio.com/viewtopic.php?f=28&t=99049
- Trains leaving a portal very fast which plan to do a non stop loop straight back into the same tunnel portal will instead leave very slowly. This is to protect against a leaving train that hasn't already reserved its own tunnel again, as this is an unsupported usage case and shouldn't ever exist in a real rail network.
- Presently it is possible to cause a mod crash in the below contrived scenario, just don't do it: If you are manually driving a train and tailgate a second train that's entering a tunnel while in automatic mode, your manual train will be able to enter the portal and reach the inner end. It will be prevented from entering the tunnel at this point, however, should the automatica train reverse its tunnel use before fully leaving it will try to exit the tunnel where your manual train is and the mod will crash.
- Corner and diagonal tunnel parts have some oddities and limitations to their usage, see the Usage Notes section for full details.


Mod Compatibility
=================

At present the mod isn't tested or supported with any mods that add custom train carriages or interferes with the rail tunnel entities in any way.
Notes on generic mod compatibility:
    - Any mod that moves or removes entities from the map without raising notification events is not supported.

Blacklisted mods:
    - Picker Dollies - lets the player move entities randomly and life is too short to try and undo all the damage it could do.


Editor Mode
===========

- Don't mine any part of a tunnel while in Editor mode in the Entity tab. As this just removes the tunnel part without notifying the mod. If you are in any other tab (i.e. Time) then this is fine as Factorio notifies the mod. In this case I'd advise loading a save from before this corrupted state was reached.


Debug Mode
==========

In debug mode some additional state checking will be done and hard errors thrown in some undesirable state situations. Does have a small UPS impact and is turned off by default.
Debug mode can be enabled/disabled via the command "railway_tunnel_toggle_debug_state" and it will report the new state in text upon changing.


Mod Design History
==================

At present the mod has been on pause for many months. This is due to my lack of interest in completing it and my feeling that too much inconvienience has been introduced to resolve the previous UPS issues.

This is technically the second major iteration of this mod. Below is a brief history of this for those curious.
    - The first iteration was developed to beta stage from December 2020 for around 6 months, before being abandoned. Its vision was to mirror base Factorio's train activities while providing the most convenient player experience. This included supporting any length trains moving through a set tunnel portal size. This led to ever growing logic complexity as more use cases and edge cases were discovered. This logic bloat required growing state data and manipulation to be done which led to the mods UPS usage growing steadily. Collective this ground development to a halt in addition to other commitments.
    - In December 2021 I reviewed the mod to decide its future. To resolve both the logic complexity and high UPS impact of iteration 1 the mod was rescoped to the vision of providing automatic train usage through a tunnel with minimal UPS usage in a simple code manner. This rescope led to massive changes throughout the mods logic and some reduction on user experience. A simple example is the move to require a train to be fully within a portal's length to be able to use a tunnel, thus requiring the player to fit in much larger tunnels in their designs. In a megabase scenario this shouldn't be an issue, but to small bases it may be an inconvenience.
So far iteration 2 of the mod has succeeded in its aim of reducing UPS usage and while it introduces some player inconveniences it has also opened up new opportunities, i.e. curved tunnel and portal parts. Although its development has been rather stop/start and taken multiple times longer than hoped to date.


Contributors
============

- blahfasel2000 - code contributions to V1 of the mod.
- justarandomgeek - creator of Factorio Mod Debug plugin for VSCode. Without which this mod would not be possible.


Upgrading Alpha Mod
===================

To apply a new mod version to your game you will need to do the below manual upgrade process. I'd advise that an extra safety save of the game is kept before this process is started so you can rollback if needed:
    - Empty all your tunnels of their trains and save the game (save 1). Take blueprint copies of any tunnel/track designs you wish as they will be removed in the next stage.
    - Remove the old mod version and load the save (save 1). This will purge your map and game state of old mod entities and data. Save the game again (save 2).
    - Put the new mod in place and load the save (save 2). Your game is now on the new mod version. Add your tunnels back in and should be good to go.
