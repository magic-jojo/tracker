# Magic Tracker Configuration Database #

The configuration database is external to SL because SL provides _shit_ for storage tools.
I've tried Experience and key-value pairs, even switched my account (Jojo) so I could create
an experience, and I only ever get error messages from the server, so fuck that.

## Architectural Notes ##

We'll make a simple flask gateway to a PgSQL database to store configurations in.  We 
can run this on a cloud account if it ever becomes a profitable.

### Avatar IDs  ###

The database requests are all keyed by avatar id, the only "personal" data stored.
Avatar IDs for owners are also stored.

### Locations ###

Locations are simply Region Names, as returned by llGetRegionName().

The Home position may include region-local coordinates as well, from this function:

	string wwGetSLUrl()
	{
	    string globe = "http://maps.secondlife.com/secondlife";
	    string region = llGetRegionName();
	    vector pos = llGetPos();
	    string posx = (string)llRound(pos.x);
	    string posy = (string)llRound(pos.y);
	    string posz = (string)llRound(pos.z);
	    return (globe + "/" + llEscapeURL(region) +"/" + posx + "/" + posy + "/" + posz);
	}

Searching for a location being removed in this is simple, as the home region name is a proper subset of the SLURL.
If the entire region name matches (being careful about URL encoding of spaces etc), it is safe to assume the region is a match.
This isn't strictly true, but should suffice for keeping cows safe.

# Database API #

## Configuration API ##
### Get(avid) ###

Return the entire configuration for the specified avatar.
This is expected to be called on attach, for instance.

The entire configuration includes:

* Locked
* Tracking
* Lockout
* Travel Time
* Travel Recovery
* Home
* Locations
* Owners

If a configuration does not exist for the avatar, a default one will be constructed per the database defaults, including:

* Locked: False
* Tracking: True
* Lockout: False

All other settings are empty.

The first few transactions are simple.

### Lock(avid, state=True) ###

Set the Lock state unconditionally. returns the current Lock state.

### Track(avid, state=True) ###

Set the Track state unconditionally, returns the current Track state.

### Lockout(avid, State=True) ###

Set the Lockout state unconditionally, returns the current Lockout state.

### AddOwner(avid, ownerid) ###

Add the avatar ownerid (deduped) to the owners list

### DelOwner(avid, ownerid) ###

Remove the avatar ownerid from the owners list if exists

### SetHome(avid, location) ###

Set the Home location unconditionally.
This also adds the location region to the Locations list with unlimited dwell time.

### AddLoc(avid, location, dwell=0, per=0) ###

Add the location to the Locations list unconditionally.
Locations will be de-duplicated by spelling.
Old or invalid locations are not detected.
If specified, a maximum sim dwell time in minutes and 'per' value in days will be saved.
The expected usage for these is roughly 'dwell' hours per day, week, or month.

### DelLoc(avid, location) ###

Remove the location from the Locations list.
If it happens to be the Home location, unset Home as well.

## Operational Requests ##

These APIs will be called during normal operation of the tracker

### Travel(avid) ###

Request travel time if available.

	If travelExpires is not NULL and has not passed, return True.
	If (expires or has passed, AND recovers or has passed)
	    set expires to 'now' plus travel minutes
	    set recovers to 'now' plus travel + recover minutes
	    return True
	else
	    return False (travel request failed)

The return value indicates if travel time is available when the call completes.

### CanTravel(avid, location) ###

Location is the region name.

This is the basic check if the avi can travel to the location they just landed in.
The return value may also be a time limit remaining in this sim, or on travel time.
Sim time limits override and use travel time, but the cows will never figure this out.

	If location exists in locations return True
	else If users(expires) is not NULL and has NOT passed
	    return True
	else return False (unknown location, no travel time)

# Schema #

The primary table holds all the singular configuration items:

	CREATE TABLE users (
		-- basic avi controls
		avid 		UUID 	PRIMARY KEY,
		locked 		BOOLEAN NOT NULL DEFAULT FALSE,
		tracking	BOOLEAN NOT NULL DEFAULT FALSE,
		lockout 	BOOLEAN NOT NULL DEFAULT FALSE,
		-- configure & record travel time
		-- when created, travel time has already expired
		travel 		INTEGER NOT NULL DEFAULT 0,
		recover 	INTEGER NOT NULL DEFAULT 0,
		expires 	DATETIME WITHOUT TIMEZONE NOT NULL DEFAULT now(),
		recovers 	DATETIME WITHOUT TIMEZONE NOT NULL DEFAULT now(),
		home VARCHAR(1024)
	);

Data items that allow multiples are relational and allow 0 entries.
The tracker code should treat "no owners" as unowned.

	CREATE TABLE owners (
		avid 	UUID 	REFERENCES users(avid),
		owner 	UUID 	NOT NULL
	);

For the locations table, we add an optional time limit per region.
We can use the travel timer to timeout a stay in this region as well.
A timelimit of 0 means 'no time limit,' of course.

	CREATE TABLE locations (
		avid 		UUID 	REFERENCES users(avid),
		location 	TEXT 	NOT NULL,
		dwell		INTEGER NOT NULL DEFAULT 0,
		expires		TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
		recovers	TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
	);

Note that a tracker that is locked and has no locations will repeatedly TP the wearer to their SL home location.
