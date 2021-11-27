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

Searching for a location being removed in this is simple, as the home region name is a proper subset of the SLURL.  If the entire region name matches, it is safe to assume the region is a match.  This isn't strictly true, but should suffice for keeping cows safe.

# Database API #

## GetConfiguration(avid) ##

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

If a configuration does not exist for the avatar, a default one will be constructed as follows:

* Locked: False
* Tracking: True
* Lockout: False

All other settings are empty.

The first few transactions are simple.

## Lock(avid, state=True) ##

Set the Lock state unconditionally.

## Track(avid, state=True) ##

Set the Track state unconditionally

## Lockout(avid, State=True) ##

Set the Lockout state unconditionally

## AddOwner(avid, ownerid) ##

Add the avatar ownerid to the owners list

## DelOwner(avid, ownerid) ##

Remove the avatar ownerid from the owners list

## SetHome(avid, location) ##

Set the Home location unconditionally.
This also adds the location to the Locations list.

## AddLoc(avid, location) ##

Add the location to the Locations list unconditionally.
Locations will be de-duplicated by spelling.
Old or invalid locations are not detected.

## DelLoc(avid, location) ##

Remove the location from the Locations list.
If it happens to be the Home location, unset Home as well.

## Travel(avid) ##

Request travel time if available.

# Schema #

The primary table holds all the singular configuration items:

	CREATE TABLE users (
		avid UUID PRIMARY KEY,
		locked BOOLEAN NOT NULL,
		tracking BOOLEAN NOT NULL,
		lockout BOOLEAN NOT NULL,
		travelTime INTEGER,
		travelRecovery INTEGER,
		home VARCHAR(1024)
	);

Data items that allow multiples are relational and nullable.
The tracker code should treat "no owners" as unowned.

	CREATE TABLE locations (
		avid UUID REFERENCES users(avid),
		location TEXT
	);

	CREATE TABLE owners (
		avid UUID REFERENCES users(avid),
		owner UUID
	);

