# Magic Tracker WebApp Implementation

This lays out the functions of the Owner's web app.  No web is provided or needed for a wearer, since their interactions with the track will be while in-world and worn.

## Definitions

* Wearer: the avatar that wears the item with the Magic Tracker script in it.  Also the avatar whose location is tracked and/or controlled.
* Owner: one or more avatars that have been assigned ownership privileges by the wearer or another owner.
* Locations: A list of SL "Region Names" the avatar is allowed to remain in.  Optionally, some Locations may restrict how long the Wearer can remain at that Location, and how often they can visit that Location.
* Home Location: a special Location that has been assigned as the place the user may be TP'd to when they TP to an unpermitted sim.  This is a specific location, subject to the usual SL limitations on teleports, such as sim landing spots.  It could be, for instance, an auto-locking cage or stall, or a grabby leash post.
* Locked: the tracker is active and will only allow the Wearer to remain in permitted Locations.
* Tracking: if locked, the tracker will report the initial (login) location of the Wearer, and the location of any place the Wearer TPs to.
* Lockout: this function may be elided.

## Registration

The first challenge is it identify an owner-wearer relationship, We can do this easily by planting the registration process in the tracker itself:

1. The owner selects the Register function on the tracker.
2. This sends a register request with the owner and wearer UUIDs to the DB.
3. The DB generates a registration key (timeuuid), records it in a registration pending table, and returns the UUID (or key).
4. The owner is prompted to follow a link with the key embedded to complete the registration.
5. Does the owner have a complete registration (email as login id, password?)
5.1. If yes, the registration is recorded.
5.2. If not, the owner is presented with a 'create an account' page, soliciting as username and password.

Password resets are similarly intiated from the tracker, so we do not need to record email addresses.

1. The owner selects the Password function on the tracker.
2. This sends a password reset request with the owner id.
3. The DB generates a reset key (timeuuid), records it in a reset pending table, and returns the UUID.
4. The owner is prompted to follow a link with the key embedded to complete the reset.
5. The resulting page simple validates a new password and stores it.

## Web Functions

Once authenticated, the following functions are offered to the owner:

1. TP Home
1. Delete the sim the wearer is current in
1. Add sim (from SLURL?)
1. Set Travel parameters
1. Report wearer location (this could be tricky to coordinate)

## New Features

1. Lockdown: TP Home, ban TPs until cleared.  (On tracker menu too?)
1. Message wearer (picked up at next config scan)
1.1. Sender (in case multiple owners)
1.1. Time (from id)


# Questions

An owner with multiple wearers will probably want to identify wearers by name.
How often we send the wearer's display name?  Record it in the User table?

How often do we scan for config changes that arrived via the web UI?
Do we shorten the scan after receiving a message?

Maybe we just add a 'trigger' to the location check that indicates a pending config change, clear it the next time the config is loaded.

