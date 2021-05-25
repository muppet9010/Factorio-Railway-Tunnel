Remote Interfaces & Custom Events
=================

All interfaces are under the interface name "railway_tunnel".



Train Tunnel Usage Changed
--------------

**Remote interface to get custom event id**
- Interface Name: get_tunnel_usage_changed_event_id
- Description: Returns an event id that will be raised every time a train's tunnel usage details change. This can be subscribed to as per any other Factorio event.
- Arguments:
    - none
- Returns:
    - Factorio event id.

**Custom event raised**
- Description: Event raised every time a train's tunnel usage details change. This will occur for changes to primaryState and changes of LuaTrain ids, i.e. when a carriage is added/removed from the entering/leaving train. Any instances of this event are raised at the end of the tunnel's usage processing each tick, so train states should be stable.
- Event Attributes:
    - The Returns from "Get A Train's Tunnel Usage Details" remote interface for the train. This constitutes the main train tunnel usage's state data and related Lua object references at this point.
    - action: the action that occured (STRING):
        - StartApproaching: When the train is first detected as using the tunnel, the tunnel is reserved and an underground train created to force the approaching train to maintain its speed. May include a populated "replacedTrainTunnelUsageId" attribute if this new train usage is a "ReversedAfterLeft" instance.
        - Terminated: The tunnel usage has been stopped and/or completed. The "changeReason" attribute will include the specific cause.
        - ReversedDuringUse: Raised if while the train was using the tunnel something happened to cause the train to start to reverse back out. Will be raised for the new tunnel usage and include the "replacedTrainTunnelUsageId" attribute with the old usage id in it. The "changeReason" attribute will include the specific cause.
        - EnteringCarriageRemoved: Raised each time a carriage is removed from the train entering the tunnel. Event occurs after the carriage is removed and so for the last carriage removal event the "enteringTrain" attribute will have a nil value as the train will entirely have gone.
        - FullyEntered: Raised after the train has fully entered the tunnel. Included for when simplier event tracking is desired, rather than per carriage.
        - StartedLeaving: Raised when the train starts to leave and the first carriage for the "leavingTrain" has been placed.
        - LeavingCarriageAdded: Raised each time a carriage is added to the train leaving the tunnel. Happens after the carriage is added.
        - FullyLeft: Raised when the train has fully left the tunnel, but is still using the portal & tracks at this time. When the train has finished with the tracks the "Terminated" action will be raised.
    - changeReason: the cause of the change (STRING):
        - ReversedAfterLeft: Raised for "Terminated" action. Occurs when a train has FullyLeft, but not released the tunnel and then reverses back down the tunnel. The new tunnel usage event for "StartApproaching" action will have the "replacedTrainTunnelUsageId" attribute populated. This old tunnel usage has completed with this event.
        - AbortedApproach: Raised for "Terminated" action. Occurs when a train aborts its approach before it starts to enter the tunnel, but after it has reserved the tunnel and the "StartApproaching" action evet has been raised.
        - ForwardPathLost: Raised for "ReversedDuringUse" action. Is just to clarify why the train reversed during its use, in this case as the path out of the tunnel was lost and so the train had to reverse up the tunnel to reach its destination.
        - CompletedTunnelUsage: Raised for "Terminated" action. The train finished leaving the portal tracks and the tunnel has been unlocked ready for future use. This is the successful completed clarification on the "Terminated" action.
    - replacedTrainTunnelUsageId: Normally nil, unless an old train tunnel usage has been replaced by this new tunnel usage for some reason. When this occurs the new tunnel usage event data includes the old tunnel usage id as this attributes value. With the old tunnel usage reporting "Terminated" action.



Get A Train's Tunnel Usage Details
----------------

- Interface Name: get_train_tunnel_usage_details
- Description: Remote interface to get details on specific train's tunnel usage. Can be called at any time.
- Arguments:
    - Train's tunnel usage id (INT).
- Returns:
    - trainTunnelUsageId = id of the train's tunnel usage details (INT). Always presnet.
    - valid = if the train is still using the tunnel (BOOLEAN). If its false then all other return attributes will be nil.
    - primaryState = the primary (lead) state of the trains tunnel usage (STRING): approaching, underground, leaving, finished.
    - enteringTrain = LuaTrain of the train still entering the tunnel if it exists, otherwise nil. Exists from "StartApproaching" to the final "EnteringCarriageRemoved" and "FullyEntered" action events.
    - undergroundTrain = LuaTrain of the complete train underground if it exists, otherwise nil. Exists from "StartApproaching" to the final "LeavingCarriageAdded" and "FullyLeft" action events.
    - leavingTrain = LuaTrain of the train while partially leaving the tunnel if it exists, otherwise nil. Exists from the " StartedLeaving" and first "LeavingCarriageAdded" action events until the tunnel usage is "Terminated".