// Magic API request/response keys
// First various web communications req/resp pairs
key configReq;
key homeReq;  // Yup, got a real homeReq'er here
key locReq;
key ownReq;
key lockReq;

key tpReq;
key regReq;
key nameReq;

// Contants.  ish.

float tpGraceTime = 60.0;   // Seconds before you get the boot
integer maxOwnerDist = 10;

// The poor sap who has this locked to them
key gWearer;

// Configuration from the server
string home;
integer locked;
integer tracking;
integer lockout;
list locations;
list owners;
integer travel;
integer recover;

// Associated with owners, but seperate since LSL makes it SUCH a PITA
// to get the names of avis unless they are nearby.

list ownNames;
integer ownCount;

// Menus.

list MENU_WEARER_UNLOCK = ["Set Home", "Add Sim", "Del Sim", "TP Home", "Add Own", "Del Own", "Lock", "Track"];
list MENU_WEARER_LOCK_UNOWN = ["Unlock", "Travel", "TP Home"];
list MENU_WEARER_LOCK = ["Travel", "TP Home"];

// Sim dwell time menu

list MENU_SIM_DWELL = ["30 mins", "1 hour", "2 hours", "4 hours", "6 hours", "Unlimited"];

// Set Home, Add Own, Del Own, Add Loc, Del Loc, TP Home, Lock/Unlock, Track/Untrack
// We rewrite the last two entries based on the current state.

list MENU_OWNER = ["Set Home", "Add Own", "Del Own", "Add Sim", "Del Sim", "TP Home", "Lock", "Track"];

// communications channels

integer menuChan;
integer menuHand;

integer dwellChan;
integer dwellHand;

integer addOwnChan;
integer addOwnHand;

integer delOwnChan;
integer delOwnHand;

list ownerList;         // names of pending owners
list nearbyAvis;     // ids of pending owners

string BoolOf(integer val)
{
    if (val) { return "Yes"; }
    return "No";
}

default
{
    state_entry()
    {
        //llOwnerSay("Hello, Avatar!");
        gWearer = llGetOwner();
        menuChan = -1 - (integer)("0x"+ llGetSubString((string)llGetKey(), -7, -1));
        addOwnChan = menuChan - 1;
        delOwnChan = addOwnChan - 1;
        dwellChan = delOwnChan - 1;
        llOwnerSay("channels: " + (string)menuChan + ", " + (string)addOwnChan + ", " + (string)delOwnChan + ", " + (string)dwellChan);

        // Get our configuration
        configReq = llHTTPRequest(
            "http://magic.softweyr.com/api/tracker/v1",
            [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
            "{\"avid\":\"" + (string)gWearer + "\",\"cmd\":\"get\"}");
    }
    
    changed(integer change)
    {
        if (change & CHANGED_TELEPORT) //note that it's & and not &&... it's bitwise!
        {
            // Cancel any outstanding TP timer
            llSetTimerEvent(0.0);
            
            llOwnerSay("changed, locked = " + (string)locked + ", tracking = " + (string)tracking);
            
            if (locked)
            {
                // Ask the server if we're allowed to TP here
                tpReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)llGetOwner() + "\"," +
                     "\"cmd\":\"arrive\", " +
                     "\"landing\":\"" + llGetRegionName() + "\"}");
            }
            if (tracking)
            {
                llOwnerSay("Tracking for: " + (string)owners);
                string where = llGetRegionName();
                string who = llGetDisplayName(llGetOwner());
                integer l = llGetListLength(owners);
                integer i;
                for (i = 0; i < l; i++)
                {
                    key owner = (key)llList2Key(owners, i);
                    string message = who + " arrived at " + where;
                    llOwnerSay("IM("  + (string)owner + ", '" + message + "')");
                    llInstantMessage(owner, message);
                }
            }
        }
    }
    
// list MENU_WEARER_UNLOCK
// list MENU_WEARER_LOCK_UNOWN
// list MENU_WEARER_LOCK

    touch_start(integer num)
    {
        key toucher = llDetectedKey(0);
        llOwnerSay("Touch start by " + (string)toucher);
        
        if (llDetectedKey(0) == llGetOwner())
        {
            llOwnerSay("Touched by wearer");

            // Wearer menu.  This depends on whether we are locked or not.
            menuHand = llListen(menuChan, "", llGetOwner(), "");  // Listen only to wearer
            if (locked)
            {
                llOwnerSay("Wearer is locked");
                
                // Unowned?
                if (llGetListLength(owners) == 0)
                {
                    llOwnerSay("Wearer is unowned");
                    llDialog(llGetOwner(), "Locked wearer menu", MENU_WEARER_LOCK_UNOWN, menuChan);
                }
                else
                { 
                    llOwnerSay("Wearer is Owned");
                    llDialog(llGetOwner(), "Unowned wearer menu", MENU_WEARER_LOCK, menuChan);
                }
            }
            else
            {
                llDialog(llGetOwner(), "Unlocked wearer menu", MENU_WEARER_UNLOCK, menuChan);
            }
        }
        else
        {
            integer i = llListFindList(owners, [toucher]);
            if (i == -1)
            {
                llOwnerSay(llGetDisplayName(toucher) + " is not allowed to operate your tracker");
            }
            else
            {
                llOwnerSay(llList2String(ownNames, i) + " is operating your tracker");
                
                // Update the Lock and Track items based on the current state.
                // We have to do it both ways each time, in case we modified
                // the non-constant.
                
                list menu = MENU_OWNER;
                if (locked)
                {
                    menu = llListReplaceList(menu, ["Unlock"], 6, 6);
                }
                if (tracking)
                {
                    menu = llListReplaceList(menu, ["Untrack"], 7, 7);
                }
                menuHand = llListen(menuChan, "", toucher, "");
                string statmsg = llGetDisplayName(llGetOwner()) + "'s Tracker\n" +
                    "Locked: " + BoolOf(locked) + "\n" +
                    "Tracking: " + BoolOf(tracking);
                llDialog(toucher, statmsg, menu, menuChan);
            }
        }
    }
    
    listen(integer chan, string name, key id, string message)
    {
        if (chan == dwellChan)
        {
            // MENU_SIM_DWELL = ["30 mins", "1 hour", "2 hours", "4 hours", "6 hours", "Unlimited"];
            
            llOwnerSay("Sim dwell time: " + message);
            integer minutes = 0;
            if (message == "30 mins") { minutes = 30; }
            else if (message == "1 hour") { minutes = 60; }
            else if (message == "2 hours") { minutes = 120; }
            else if (message == "4 hours") { minutes = 240; }
            else if (message == "6 hours") { minutes = 360; }
            else { minutes = 0; }

            locReq = llHTTPRequest(
                "http://magic.softweyr.com/api/tracker/v1",
                [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                "{\"avid\":\"" + (string)gWearer + "\"," +
                 "\"cmd\":\"addloc\"," +
                 "\"location\":\"" + llGetRegionName() + "\"," + 
                 "\"dwell\":\"" + (string)minutes + "\"}");

            //llOwnerSay(llGetRegionName() + " being allowed?");
            llListenRemove(dwellHand);
        }
        else if (chan == addOwnChan)
        {
            llOwnerSay("New owner: " + message);
            
            // Find the selected name in the name list
            // This is such a totally fucking stupid way to do this,
            // why can't dialog at least take a strided list?
            
            integer i = llListFindList(ownerList, [message]);
            if (i < 0)
            {
                llOwnerSay("WTF?  Owner list b0rked");
            }
            else
            {
                key newOwner = llList2Key(nearbyAvis, i);
                llOwnerSay("Owner: " + llList2String(ownerList, i) + " : " + (string)newOwner);
                
                ownReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"addowner\"," +
                     "\"owner\":\"" + (string)newOwner + "\"}");
            }
            llListenRemove(addOwnHand);
        }
        else if (chan == delOwnChan)
        {
            llOwnerSay("Del owner: " + message);
            
            // Find the selected name in the name list
            // This is such a totally fucking stupid way to do this,
            // why can't dialog at least take a strided list?
            // On the other hand, why doesn't LSL have dictionaries?
            // This is the DELETE side, so look in the list of our
            // owners.
            
            integer i = llListFindList(ownNames, [message]);
            if (i < 0)
            {
                llOwnerSay("WTF?  Owner list jacked");
            }
            else
            {
                key newOwner = llList2Key(owners, i);
                llOwnerSay("Owner: " + message + " : " + (string)newOwner);
                
                ownReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"delowner\"," +
                     "\"owner\":\"" + (string)newOwner + "\"}");
            }
            llListenRemove(delOwnHand);
        }
        else if (chan == menuChan)
        {
            if (message == "Set Home")
            {
                // As of RLVa 2.9.20, we have enhanced tpto...
                // Set home directly, then send to server as well
                vector pos = llGetPos();
                home = llGetRegionName() + "/" + 
                    (string)((integer)pos.x) + "/" +
                    (string)((integer)pos.y) + "/" + 
                    (string)((integer)pos.z);
                homeReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\",\"cmd\":\"sethome\",\"home\":\"" + home + "\"}");
                llOwnerSay("Set home to " + home);
            }
            // The next four are satisfyingly similar
            else if (message == "Lock")
            {
                locked = TRUE;
                lockReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"lock\"}");
                llOwnerSay("Locked");
            }
            else if (message == "Unlock")
            {
                locked = FALSE;
                lockReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"lock\"," +
                     "\"value\":\"false\"}");
                llOwnerSay("Unlocked");
            }
            else if (message == "Track")
            {
                tracking = TRUE;
                lockReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"track\"}");
                llOwnerSay("Tracking");
            }
            else if (message == "Untrack")
            {
                tracking = FALSE;
                lockReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"track\"," +
                     "\"value\":\"false\"}");
                llOwnerSay("Utracked");
            }
            else if (message == "Add Own")
            {
                // Perms: unlocked or owner
                
                list avis = llGetAgentList(AGENT_LIST_PARCEL_OWNER, []);
                
                // Remove me from the list
                integer p = llListFindList(avis, [llGetOwner()]);
                if (p != -1)
                    avis = llDeleteSubList(avis, p, p);
                
                integer numberOfKeys = llGetListLength(avis);
 
                vector currentPos = llGetPos();
                list avilist;
                key avi;
                integer dist;
 
                integer i;
                for (i = 0; i < numberOfKeys; ++i)
                {
                    avi = llList2Key(avis, i);
                    dist = llRound(llVecDist(currentPos, llList2Vector(llGetObjectDetails(avi, [OBJECT_POS]), 0)));
                    if (dist <= maxOwnerDist)
                        avilist += [dist, avi];
                }
 
                //  sort strided list by ascending distance
                avilist = llListSort(avilist, 2, TRUE);
                
                // Add avis to the list, nearest to farthest, stopping at 12.
                ownerList = [];
                nearbyAvis = [];

                integer nitems = numberOfKeys;
                if (12 < numberOfKeys)
                    nitems = 12;
                    
                for (i = 0; i < (nitems * 2); i += 2)
                {
                    key avatar = llList2Key(avilist, i+1);
                    string name = llGetDisplayName(avatar);
                    integer dist = llList2Integer(avilist, i);
                    llOwnerSay(name + " @ " + (string)dist + "m");
                    ownerList += name;
                    nearbyAvis += avatar;
                }
                
                addOwnHand = llListen(addOwnChan, "", llGetOwner(), "");
                llDialog(llGetOwner(), "Choose new Owner", ownerList, addOwnChan);
            }
            else if (message == "Del Own")
            {
                // Display the list of owner names we have cached.
                // This is racey as all hell.
                delOwnHand = llListen(delOwnChan, "", llGetOwner(), "");
                llDialog(llGetOwner(), "Remove which Owner", ownNames, delOwnChan);
            }
            else if (message == "TP Home")
            {
                llOwnerSay("@tpto:" + home + "=force");
            }
            else if (message == "Add Sim")
            {
                // Perms: Unlocked or Owner
                
                // This requires a secondary menu, to ask if the sim should have time limits.
                
                dwellHand = llListen(dwellChan, "", id, "");  // Listen only to toucher
                llDialog(id, "Sim dwell time", MENU_SIM_DWELL, dwellChan);
            }
            
            llListenRemove(menuHand);
        }
    }
    
    dataserver(key qId, string data)
    {
        // nameReq is exclusively used to get the names of our owners,
        // one at a time, from the dataserver.  What a fucking kludge.
        
        if (nameReq == qId)
        {
            llSay(0, "Display name[" + (string)ownCount + "] is " + data);
            ownNames += data;
            ownCount += 1;
            if (ownCount < llGetListLength(owners)) {
                nameReq = llRequestDisplayName(llList2Key(owners, ownCount));
            }                
        }
    }

//    touch_end(integer num)
//    {
//        key toucher = llDetectedKey(0);
//        llOwnerSay("Touch end by " + (string)toucher);
//    }

    attach(key id)
    {
        // Get our configuration
        gWearer = llGetOwner();
        configReq = llHTTPRequest(
            "http://magic.softweyr.com/api/tracker/v1",
            [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
            "{\"avid\":\"" + (string)gWearer + "\",\"cmd\":\"get\"}");
    }
    
    timer()
    {
        // So far our only timer event is the 'send the silly cow home' timer
        // Cancel it and send her home
        llSetTimerEvent(0.0);
        llOwnerSay("Timed out, sending you home");
        //llOwnerSay("tpto:" + home + "=force");
        llOwnerSay("@tpto:" + home + "=force");
    }

    http_response(key id, integer status, list metadata, string body)
    {
        // Owner added or deleted; the response is the same to both:
        // the complete current list of owners.  Save the list, then
        // start getting their names from the dataserver.
        if (id == ownReq) 
        {
            string ty = llJsonValueType(body, [(string)gWearer]);
            if (ty == JSON_ARRAY)
            {
                string ownStr = (string)llJsonGetValue(body, [(string)gWearer]);
                llOwnerSay("owners as string: " + ownStr);
                list ownlist = llParseString2List(ownStr, ["[", "]", "\"", ","], [""]);
                llOwnerSay("ownlist: " + (string)ownlist);
                integer n = llGetListLength(ownlist);
                llOwnerSay("Found " + (string)n + " ownlist:");
                
                // Convert owners to keys and store
                owners = [];
                integer i;
                for (i = 0; i < n; i++)
                {
                    key owner = llList2Key(ownlist, i);
//                    llOwnerSay("owner: " + (string)owner);
                    owners += owner;
                }
                
                llOwnerSay("owners: " + (string)owners);
                
                // Kick off the search for owner names.
                // Wow this is a suck-ass way to do this.
                // We leave the existing list in place, 
                // just in case it has valid names in it
                
                ownCount = 0;
                nameReq = llRequestDisplayName(llList2Key(owners, 0));
            }
            else
            {
                llOwnerSay("We got WTF for owners");
            }
        }
        else if (id == tpReq) {
            //llOwnerSay(body);
            if (llJsonValueType(body, [(string)llGetOwner()]) == JSON_TRUE)
            {
                llOwnerSay("Welcome to " + llGetRegionName());
            }
            else
            {
                llOwnerSay("You are not allowed in " + llGetRegionName() + ", booting in " + (string)tpGraceTime + " seconds");
                // Start the tp timer; we will cancel it if they scoot home
                llSetTimerEvent(tpGraceTime);
            }
        }
        else if (id == homeReq)
        {
            // User set a new home.  Do we need to do anything here?
            llOwnerSay(body);
        }
        else if (id == locReq)
        {
            // User added a location.  Do we need to do anything here?
            llOwnerSay(body);
        }
        else if (id == lockReq)
        {
            // This was a lock/unlock or track/untrack request
            llOwnerSay(body);
        }
        else if (id == configReq)
        {
            //llOwnerSay(body);
            home = llJsonGetValue(body, ["home"]);
            llOwnerSay("home: " + home);
            
            if (llJsonValueType(body, ["locked"]) == JSON_TRUE)
            {
                locked = TRUE;
                llOwnerSay("locked: " + (string)locked);
            }
            else if (llJsonValueType(body, ["locked"]) == JSON_FALSE)
            {
                locked = FALSE;
                llOwnerSay("locked: " + (string)locked);
            }
            else
            {
                llOwnerSay("Lock is fucked, or LSL sucks tiny balls");
            }
            
            if (llJsonValueType(body, ["tracking"]) == JSON_TRUE)
            {
                tracking = TRUE;
                llOwnerSay("tracking: " + (string)tracking);
            }
            else if (llJsonValueType(body, ["tracking"]) == JSON_FALSE)
            {
                locked = FALSE;
                llOwnerSay("tracking: " + (string)tracking);
            }
            else
            {
                llOwnerSay("tracking is fucked, or LSL sucks tiny balls");
            }
            
            string lo = llJsonValueType(body, ["lockout"]);
            if (lo == JSON_TRUE)
            {
                lockout = TRUE;
                llOwnerSay("lockout: " + (string)lockout);
            }
            else if (lo == JSON_FALSE)
            {
                lockout = FALSE;
                llOwnerSay("lockout: " + (string)lockout);
            }
            else
            {
                llOwnerSay("lockout is fucked, or LSL sucks tiny balls");
            }

            string ty = llJsonValueType(body, ["travel"]);
            if (ty == JSON_NUMBER)
            {
                travel = (integer)llJsonGetValue(body, ["travel"]);
                llOwnerSay("travel: " + (string)travel);
            }
            else
            {
                llOwnerSay("travel type is? ");
            }

            ty = llJsonValueType(body, ["recover"]);
            if (ty == JSON_NUMBER)
            {
                recover = (integer)llJsonGetValue(body, ["recover"]);
                llOwnerSay("recover: " + (string)recover);
            }
            else
            {
                llOwnerSay("recover type is? ");
            }
            
            ty = llJsonValueType(body, ["owners"]);
            if (ty == JSON_ARRAY)
            {
                llOwnerSay("me: " + (string)llGetOwner());
                
                llOwnerSay("owners is an array");
                // The fucking LSL JSON parser is an absolute fucking
                // pile of shit here.  It sends the owner list as an 
                // array type, but retrieves it as a fucking string.
                
                string ownStr = (string)llJsonGetValue(body, ["owners"]);
                llOwnerSay("ownStr: " + ownStr);

                // Now what the blinding fuck do we do with that?
                list ownlist = llParseString2List(ownStr, ["[", "]", "\"", ","], [""]);
                llOwnerSay("ownlist: " + (string)ownlist);
                integer n = llGetListLength(ownlist);
                llOwnerSay("Found " + (string)n + " ownlist:");
                
                // Convert owners to keys and store
                owners = [];
                integer i;
                for (i = 0; i < n; i++)
                {
                    key owner = llList2Key(ownlist, i);
                    llOwnerSay("owner: " + (string)owner);
                    owners += owner;
                }
                
                llOwnerSay("owners: " + (string)owners);
                
                // Go find the owners names, too, for the "Del Owner" menu
                
                ownCount = 0;
                nameReq = llRequestDisplayName(llList2Key(owners, 0));
            }
            else
            {
                llOwnerSay("owners type is? ");
            }
            
            ty = llJsonValueType(body, ["locations"]);
            if (ty == JSON_ARRAY)
            {
                llOwnerSay("locations is an array");
                // Locations are structures, which we don't have in
                // fucking LSL, so we'll turn them into a strided list.
                // Ugh what a fucking dumbass scripting language.
                list locs = (list)llJsonGetValue(body, ["locations"]);
                llOwnerSay("locs (" + (string)llGetListLength(locs) + "): " + (string)locs);
                // So now each element in locs should be a json map
                //integer len = llGetListLength(locs);
                //integer i;
                //for (i = 0; i < len; i++)
                //{
                //    llOwnerSay((string)i + ": " + llList2String(locs, i));
                //}
            }
            else
            {
                llOwnerSay("locations type is? ");
            }
        }
    }
}

