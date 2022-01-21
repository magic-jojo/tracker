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

Done + JSON

The first few transactions are simple.

### Lock(avid, state=True) ###

Set the Lock state unconditionally. returns the current Lock state.

Done + JSON

### Track(avid, state=True) ###

Set the Track state unconditionally, returns the current Track state.

Done + JSON

### Lockout(avid, State=True) ###

Set the Lockout state unconditionally, returns the current Lockout state.

Done + JSON

### SetTravel(avid, away = 0, recover = 0)

Set the allowed travel time for the wearer.
If 0, travel is not allowed.
Recover must be greater than or equal to away.
If Recover is not specified, it is set to away.

Done + JSON

### AddOwner(avid, ownerid) ###

Add the avatar ownerid (deduped) to the owners list

Done + JSON

### DelOwner(avid, ownerid) ###

Remove the avatar ownerid from the owners list if exists

Done + JSON

### SetHome(avid, location) ###

Set the Home location unconditionally.
Location is a SLURL.
This also adds the location region to the Locations list with unlimited dwell time.
Note that the home location is URL-encoded, while Locations are not, so care must be
taken when adding the home.

Done + JSON

### AddLoc(avid, location, dwell=0, per=0) ###

Add the location to the Locations list unconditionally.
Locations will be de-duplicated by spelling.
Old or invalid locations are not detected.
If specified, a maximum sim dwell time in minutes and 'per' value in days will be saved.
The expected usage for these is roughly 'dwell' hours per day, week, or month.

Done + JSON

### DelLoc(avid, location) ###

Remove the location from the Locations list.
If it happens to be the Home location, unset Home as well.

Done + JSON

### Password(ownid, username, password)

Set or change the owners web access password.  Username is the SL Username of the owner (not the display) name.
Password is gathered from the owner.

NOT DONE


## Operational Requests ##

These APIs will be called during normal operation of the tracker

### Travel(avid) ###

Request travel time if available.

	If expires has not passed, return True.
	If (expires has passed, AND recovers has passed)
	    set expires to 'now' plus travel minutes
	    set recovers to 'now' plus travel + recover minutes
	    return True
	else
	    return False (travel request failed)

The return value indicates if travel time is available when the call completes.

Done + JSON

### Arrive(avid, location) ###

Location is the region name.

This is the basic check if the avi is allowed the location they just landed in.
If the return value is False, the avi should be returned home ASAP.
Sim time limits override and use travel time, but the cows will never figure this out.  (If you request travel, then jump to a time-limited sim, both timers are running simultaneously.)

	if NOT locked, return True
	if users(expires) has not passed, return True
	if location does NOT exist in locations, return False
	if location(dwell) is 0, return True
	if location(expires) has NOT passed, return True
	if location(recovers) has NOT passed, return False
	-- Start the sim timer
	location(expires) = now() + dwell minutes
	location(recovers) = now() + per hours
	return True

Done + JSON

# Schema #

See sql/schema.sql for details
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
		-- configure & record penalty box time
		penalty		INTEGER NOT NULL DEFAULT 0,
		release		DATETIME WITHOUT TIMEZONE NOT NULL DEFAULT now(),
		home VARCHAR(1024)
	);

Data items that allow multiples are relational and allow 0 entries.

We de-dupe owners for each wearer with a unique constraint, the insert
code has to be able to handle this.
The tracker code should treat "no owners" as unowned.

	CREATE TABLE owners (
		avid 	UUID 	REFERENCES users(avid),
		owner 	UUID 	NOT NULL,
		UNIQUE (avid, owner)
	);

For the web application, we need a (hashed) password for each owner.  
We also tuck the session key here when the user is logged in.

	CREATE TABLE passwords (
		ownid 		UUID    NOT NULL PRIMARY KEY,
		username	VARCHAR(64),
		password	VARCHAR(128),
		session		UUID
	);

The username is the SL username (not the display name), the password is the clear text password from the app.

For the locations table, we allow an optional time limit per region.
We can use the travel timer to timeout a stay in this region as well.
A timelimit of 0 means 'no time limit,' of course.

	CREATE TABLE locations (
		avid 		UUID 	REFERENCES users(avid),
		location 	TEXT 	NOT NULL,
		dwell		INTEGER NOT NULL DEFAULT 0,		-- sim time, minutes
		per		    INTEGER NOT NULL DEFAULT 0,		-- per this many days
		expires		TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
		recovers	TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
	);

Note that a tracker that is locked and has no locations will repeatedly TP the wearer to their SL home location.

Finally we have a display names table.  This is updated each time we rebuild the display names in the tracker, so it can be kept reasonably fresh.

	CREATE TABLE displaynames (
		avid	UUID	PRIMARY KEY,
		name	VARCHAR(128)
	);

