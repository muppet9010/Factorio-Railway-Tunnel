Remote Interfaces & Custom Events
=================

All remote interfaces are under the interface name "railway_tunnel".



Tunnel Usage Entry Object Attributes
----------------

The common attributes that are returned giving details about a tunnel usage entry by many of the mods events and remote interfaces. If the tunnel usage has completed then these values will all be nil.
- tunnelUsageId = id of the tunnel usage details (INT). Always present.
- primaryState = the primary (lead) state of the train in its tunnel usage (STRING): approaching, underground, leaving, finished.
- enteringTrain = LuaTrain of the train still entering the tunnel if it exists, otherwise nil. Exists from "startApproaching" to the final "enteringCarriageRemoved" and "fullyEntered" action events.
- undergroundTrain = LuaTrain of the complete train underground if it exists, otherwise nil. Exists from "startApproaching" to the final "leavingCarriageAdded" and "fullyLeft" action events.
- leavingTrain = LuaTrain of the train leaving the tunnel if it exists, otherwise nil. Exists from the " startedLeaving" and first "leavingCarriageAdded" action events until the tunnel usage is "terminated". So may be a partally leaving train up to the full train until "fullyLeft".
- tunnelId = id of the tunnel the train is using. Can use this to get tunnel details via remote interface: get_tunnel_details_for_id



Tunnel Usage Changed Event
--------------

Get a custom event id via a remote interface call that can be registered to be notified when a tunnel usage instance's state changes. The event will be raised for all changes to tunnel usage primaryState and changes to trains composition, i.e. when a carriage is added or removed from either the entering or leaving train.

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
    - action: the action that occured (STRING):
        - startApproaching: When the train is first detected as using the tunnel, the tunnel is reserved and an underground train created to force the approaching train to maintain its speed. In cases of a "fullyLeft" train reversing down the tunnel the "replacedtunnelUsageId" attribute will be populated. The old tunnel usage will have the "changeReason" attribute with a value of "reversedAfterLeft" on its "terminated" action event.
        - terminated: The tunnel usage has been stopped and/or completed. The "changeReason" attribute will include the specific cause.
        - reversedDuringUse: Raised if while the train was using the tunnel something happened to cause the train to start to reverse back out. Will be raised for the new tunnel usage and include the "replacedtunnelUsageId" attribute with the old usage id in it. The "changeReason" attribute will include the specific cause.
        - enteringCarriageRemoved: Raised each time a carriage is removed from the train entering the tunnel. Event occurs after the carriage is removed and so for the last carriage removal event the "enteringTrain" attribute will have a nil value as the train will entirely have gone.
        - fullyEntered: Raised after the train has fully entered the tunnel. Occurs at the same point as the last "enteringCarriageRemoved" action event. Included for when simplier high level event tracking is desired, rather than per carriage.
        - startedLeaving: Raised when the train starts to leave and the first carriage for the "leavingTrain" has been placed.
        - leavingCarriageAdded: Raised each time a carriage is added to the train leaving the tunnel. Happens after the carriage is added.
        - fullyLeft: Raised when the train has fully left the tunnel, but is still using the portal & tracks at this time. When the train has finished with the portal and its tracks the "terminated" action will be raised. Occurs at the same point as the last "leavingCarriageAdded" action event. Included for when simplier high level event tracking is desired, rather than per carriage.
    - changeReason: the cause of the change (STRING):
        - reversedAfterLeft: Raised for "terminated" action. Occurs when a train has fullyLeft, but not released the tunnel and then reverses back down the tunnel. The new tunnel usage event for "startApproaching" action will have the "replacedtunnelUsageId" attribute populated. This old tunnel usage has completed with this event.
        - abortedApproach: Raised for "terminated" action. Occurs when a train aborts its approach before it starts to enter the tunnel, but after it has reserved the tunnel and the "startApproaching" action evet has been raised.
        - forwardPathLost: Raised for "reversedDuringUse" action. Is just to clarify why the train reversed during its use, in this case as the path out of the tunnel was lost and so the train had to reverse up the tunnel to reach its destination.
        - completedTunnelUsage: Raised for "terminated" action. The train finished leaving the portal tracks and the tunnel has been unlocked ready for future use. This is the successful completed clarification on the "terminated" action.
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

The common attributes that are returned giving details about a tunnel by many of the mods events and remote interfaces. If the tunnel is not complete these values will all be nil.
- tunnelId = Id of the tunnel (INT).
- portals = Array of the 2 portal entities in this tunnel.
- segments = Array of the tunnel segment entities in this tunnel.
- tunnelUsageId = Id (INT) of the tunnel usage entry using this tunnel if one is currently active. Can use the get_tunnel_usage_entry_for_id remote interface to get details of the tunnel usage entry.



Get Tunnel Details For Id
-----------------

- Interface Name: get_tunnel_details_for_id
- Description: Remote interface to get details on a specific tunnel by its id.
- Arguments:
    - Tunnel Id (INT) - The id of a tunnel. Is provided by tunnel usage based remote interface results.
- Returns:
    - Tunnel Object Attributes for this tunnel id or nil if no complete tunnel.



Get Tunnel Details For Entity
-----------------

- Interface Name: get_tunnel_details_for_entity
- Description: Remote interface to get details on a specific tunnel that a tunnel part (portal or segment) entity is part of, by the entities unit_number.
- Arguments:
    - Tunnel Part Unit Number (INT) - The unit number of an entity that is part of the tunne.
- Returns:
    - Tunnel Object Attributes for this entities tunnel or nil if no complete tunnel.