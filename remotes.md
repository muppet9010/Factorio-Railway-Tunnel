Remote Interfaces & Custom Events
=================

All remote interfaces are under the interface name "railway_tunnel".



Tunnel Usage Entry Object Attributes
----------------
The common attributes that are returned give details about a tunnel usage entry by many of the mods events and remote interfaces. If the tunnel usage has completed then these values will all be nil.
- tunnelUsageId = id of the tunnel usage details (INT). Always present.
- primaryState = the primary (lead) state of the train in its tunnel usage (STRING): approaching, underground, leaving, finished.
- train = LuaTrain of the train entering or leaving the tunnel. Will be nil while primaryState is "underground".
- tunnelId = id of the tunnel the train is using. Can use this to get tunnel details via remote interface: get_tunnel_details_for_id



Tunnel Usage Changed Event
--------------
Get a custom event id via a remote interface call that can be registered to be notified when a tunnel usage instance's state changes. The event will be raised for all changes to tunnel usage primaryState.

**Remote interface to get custom event id**
- Interface Name: get_tunnel_usage_changed_event_id
- Description: Returns an event id that will be raised every time tunnel usage details change. This can be subscribed to as per any other Factorio event.
- Arguments:
    - none
- Returns:
    - Factorio event id.

**Custom event raised**
- Description: Event raised every time a tunnel usage details change. Any instances of this event are raised at the end of the tunnel's usage processing each tick, so train states should be stable.
- Event Attributes:
    - Tunnel Usage Entry Object Attributes for this tunnel usage.
    - action: the action that occurred (STRING):
        - onPortalTrack: When the train has initially moved on to the tunnel portals tracks. This may be on route to use the tunnel or may be just moving on to some tracks within the portal. Either way the tunnel and the other portal are now reserved for this train. If the train leaves the portal track without using the tunnel the terminated action will be raised with a "changeReason" of "portalTrackReleased". If the train moves in to use the tunnel then the "startApproaching" or action will be raised when the train reserves the inner transition signals.
        - startApproaching: When the train has first reserved the tunnel by pathing across the inner end of a tunnel portal. The tunnel is reserved. In cases of a "fullyLeft" train reversing down the tunnel the "replacedtunnelUsageId" attribute will be populated. The old tunnel usage will have the "changeReason" attribute with a value of "reversedAfterLeft" on its "terminated" action event.
        - entered: Raised when the train enters the tunnel and is removed from the entrance portal on the map.
        - leaving: Raised when the train has left the tunnel and starts to path away from the exit portal. When the train has finished leaving the portal and its tracks the "terminated" action will be raised.
        - terminated: The tunnel usage has been stopped and/or completed. The "changeReason" attribute will include the specific cause.
    - changeReason: the cause of the change (STRING):
        - reversedAfterLeft: Raised for "terminated" action. Occurs when a train has fullyLeft, but not released the tunnel and then reverses back down the tunnel. The new tunnel usage event for "startApproaching" action will have the "replacedtunnelUsageId" attribute populated. This old tunnel usage has been completed with this event.
        - abortedApproach: Raised for "terminated" action. Occurs when a train aborts its approach before it starts to enter the tunnel, but after it has reserved the tunnel and the "startApproaching" action event has been raised.
        - completedTunnelUsage: Raised for "terminated" action. The train finished leaving the portal tracks and the tunnel has been unlocked ready for future use. This is the successful completed clarification on the "terminated" action.
        - tunnelRemoved: Raised once a tunnel is removed (destroyed) while the train is using it.
        - portalTrackReleased: Raised when a train that had entered a tunnels portal rails leaves without using the tunnel.
    - replacedtunnelUsageId: Normally nil, unless an old tunnel usage has been replaced by this new tunnel usage for some reason. When this occurs the new tunnel usage event data includes the old tunnel usage id as this attributes value. With the old tunnel usage reporting "terminated" action.



Get Tunnel Usage Entry For Id
----------------

- Interface Name: get_tunnel_usage_entry_for_id
- Description: Remote interface to get details on specific tunnel usage entry. Can be called at any time.
- Arguments:
    - Tunnel Usage Id (INT). This is the "tunnelUsageId" attribute from the Tunnel Usage Entry Object Attributes that is returned by some other events and remote interfaces.
- Returns:
    - Tunnel Usage Entry Object Attributes for this tunnel usage.



Get Tunnel Usage Entry For Train
----------------

- Interface Name: get_tunnel_usage_entry_for_train
- Description: Remote interface to get details on if a specific train has a tunnel usage entry related to it. Can be called at any time on any train.
- Arguments:
    - Train's Id (INT) - LuaTrain.id of a train.
- Returns:
    - Tunnel Usage Entry Object Attributes if this train is part of a tunnel usage instance. Otherwise returns nil if there is no tunnel usage related to this train id.



Get Temporary Carriage Names
----------------

- Interface Name: get_temporary_carriage_names
- Description: Remote interface to get a list of train carriage names that are used temporarily during tunnel usage. These special carriages will need to be avoided for any manipulation by other mods.
- Arguments:
    - none
- Returns:
    - Table of the temporary carriage names with key and value being the name. i.e: {["name1"]="name1"}.



Tunnel Object Attributes
----------------

The common attributes that are returned give details about a tunnel by many of the mods events and remote interfaces. If the tunnel is not complete these values will all be nil.
- tunnelId = Id of the tunnel (INT).
- portals = table of the 2 portals in this tunnel. Comprising the below details:
    - portalId = Id of the portal (INT).
    - portalPartEntities = table of the portal part entities as: unit_number -> entity
- undergroundSegmentEntities = table of the tunnel segment entities in this tunnel as: unit_number -> entity
- tunnelUsageId = Id (INT) of the tunnel usage entry using this tunnel if one is currently active. Can use the get_tunnel_usage_entry_for_id remote interface to get details of the tunnel usage entry.



Get Tunnel Details For Id
-----------------

- Interface Name: get_tunnel_details_for_id
- Description: Remote interface to get details on a specific tunnel by its id.
- Arguments:
    - Tunnel Id (INT) - The id of a tunnel. Is provided by tunnel usage based remote interface results.
- Returns:
    - Tunnel Object Attributes for this tunnel id or nil if no complete tunnel.



Get Tunnel Details For Entity Unit Number
-----------------

- Interface Name: get_tunnel_details_for_entity_unit_number
- Description: Remote interface to get the details of the tunnel a tunnel part (portal or segment) entity is part of, by the entity's unit_number.
- Arguments:
    - Tunnel Part Unit Number (INT) - The unit number of an entity that is part of the tunnel.
- Returns:
    - Tunnel Object Attributes for this entity's tunnel or nil if no complete tunnel.
