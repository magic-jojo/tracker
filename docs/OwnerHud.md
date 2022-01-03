# Magic Tracker InWorld Implementation

## Definitions

* Wearer: the avatar that wears the item with the Magic Tracker script in it.  Also the avatar whose location is tracked and/or controlled.
* Owner: one or more avatars that have been assigned ownership privileges by the wearer or another owner.
* Locations: A list of SL "Region Names" the avatar is allowed to remain in.  Optionally, some Locations may restrict how long the Wearer can remain at that Location, and how often they can visit that Location.
* Home Location: a special Location that has been assigned as the place the user may be TP'd to when they TP to an unpermitted sim.  This is a specific location, subject to the usual SL limitations on teleports, such as sim landing spots.  It could be, for instance, an auto-locking cage or stall, or a grabby leash post.
* Locked: the tracker is active and will only allow the Wearer to remain in permitted Locations.
* Tracking: if locked, the tracker will report the initial (login) location of the Wearer, and the location of any place the Wearer TPs to.
* Lockout: this function may be elided.


## Functions

The purpose of the HUD is to allow Owners to select common controls across all of the owned Wearers within 20m of the Owner.
Consider an Owner with 4 or more leashed Wearers, hopping from sim to sim adding them as safe locations; the HUD is much simpler than tracking down mulitple ankles.

In the HUD display, the Owner will select from the located Wearers and be able to:

1. TP Home.  Teleport the Wearer to their assigned Home Location. Done W-only
1. LockDown.  Sends the wearer home, without the ability to TP.
1. Lock/Unlock.  Lock or unlock the tracker.
1. Track/Untrack. Enable or disable Tracking for the Wearer.
1. Add/Del Sim.  Add or Delete the current Location to the permitted Locations list, with an optional limit on how long they can visit the location and how long until they can revisit.  Visit time is specified in minutes, while revisit time is specified in hours.
1. Set Home.  Set the Home Location for the Wearer.  If the Wearer is found to be in an unpermitted Location, she will be TP'd to the Home Location. Done W-only

### Idea: Broadcast Mode?

This makes a lot of sense for Add/Del Sim, Set Home, and possibly even TP Home and LockDown.  Possibly even Lock and Track.  Makes for a super simple HUD, like Wendys.

### Potential add-ons, if I can be arsed:

1. Add/Del Own.  Del requires another list view in the HUD.


# Communications Plan

The hud will send a "Scan" for Trackers in the vicinity on a timer.  Each Tracker that gets this message will check the HUD Owner GUID against it's owner list, and reply to owners with a packet that includes:

* GUID
* Display name
* Lock status
* Track status

The Wearer GUID is used to identify which Wearer in outbound commands other than scan, the HUD Owner GUID is sent for authentication.
