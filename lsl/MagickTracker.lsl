// Magic API request/response keys
// First various web communications req/resp pairs
key configReq;
key homeReq;  // Yup, got a real homeReq'er here
key locReq;
key ownReq;
key lockReq;
key downReq;
key trackReq;
key travelReq;

key tpReq;
key regReq;
key nameReq;
key travReq;
key passReq;

// The poor sap who has this locked to them
key gWearer;

// Configuration from the server
integer configured;

string home;
integer locked;
integer tracking;
integer lockdown;
list locations;
list owners;
integer travel;
integer recover;

// Associated with owners, but seperate since LSL makes it SUCH a PITA
// to get the names of avis unless they are nearby.

list ownNames;
integer ownCount;

// Menus.
// First is the menu for OWNERS, which is also used for UNLOCKED WEARERS
// We rewrite the "lock" and "track" entries based on the current state.

list MENU_OWNER = ["TP Home", "Add Sim", "Del Sim", 
                   "Lock", "Add Own", "Del Own", 
                   "Track", "Travel Time", "Set Home",
                   "Web", "LockDown" ];

// Customize the owner menu for the current state
// Do it the safe way.

list ownerMenu()
{
    list menu = MENU_OWNER;
    integer i;
    if (locked)
    {
        i = llListFindList(menu, ["Lock"]);
        //llOwnerSay("Menu: Lock at: " + (string)i);
        menu = llListReplaceList(menu, ["Unlock"], i, i);
    }
    //else
    //{
    //    llOwnerSay("Menu: Unlocked");
    //}
    if (tracking)
    {
        i = llListFindList(menu, ["Track"]);
        //llOwnerSay("Menu: Track at: " + (string)i);
        menu = llListReplaceList(menu, ["Untrack"], i, i);
    }
    //else
    //{
    //    llOwnerSay("Menu: Untracked");
    //}
    
    if (lockdown)
    {
        i = llListFindList(menu, ["LockDown"]);
        menu = llListReplaceList(menu, ["Release"], i, i);
    }
    return menu;
}

list MENU_WEARER_LOCK_UNOWN = ["Unlock", "Travel", "TP Home"];
list MENU_WEARER_LOCK = ["Travel", "TP Home"];

// Sim dwell time menu

list MENU_LINGER = ["30 mins", "1 hour", "2 hours", 
                    "4 hours", "6 hours", "Unlimited"];

// Travel time and reocvery menus
list MENU_TRAVEL = ["None", "30 mins", "1 hour", 
                    "2 hours", "4 hours", "6 hours"];

list MENU_RECOVER = ["Hour", "SL Day", "RL Day", "Week"];

// communications channels

integer menuChan;
integer menuHand;

integer dwellChan;
integer dwellHand;

integer perChan;
integer perHand;

integer allowChan;
integer allowHand;

integer passChan;
integer passHand;

integer recoverChan;
integer recoverHand;

integer addOwnChan;
integer addOwnHand;

integer delOwnChan;
integer delOwnHand;

// Contants.  ish.

integer tpGraceTime = 60;   // Seconds before you get the boot
integer menuGraceTime = 30; // How long menus wait for a decision
integer maxOwnerDist = 10;

// Prims we make GLOW to indicate activity or state,
// and their relative GLOW states, because colors show
// glow differently.

integer PRIM_ANTENNA = 6;
integer PRIM_GREEN_LED = 5;
integer PRIM_RED_LED = 2;
integer PRIM_YELLOW_LED = 3; // Not currently used

float GLOW_ANTENNA = 1.0;
float GLOW_GREEN = 0.65;
float GLOW_RED = 0.90;
float GLOW_YELLOW = 0.65;
float GLOW_OFF = 0.0;

vector COLOR_RED = <1.000, 0.255, 0.212>;
vector COLOR_YELLOW = <1.000, 0.863, 0.000>;

float BELL_SOUND_VOLUME = 1.0;
float LOCK_SOUND_VOLUME = 1.0;
float TRACK_SOUND_VOLUME = 0.75;
float TRAVEL_SOUND_VOLUME = 0.80;

// timer values, expressed in "unix" time
// TP home, set when the avi enters an unpermitted sim,
// reset when avi enters a permitted sim.
// One per listen channel, in case of timeout

integer timerTP;
integer timerMenuChan;
integer timerDwellChan;
integer timerAddOwnChan;
integer timerDelOwnChan;
integer timerPerChan;
integer timerAllowChan;
integer timerPassChan;
integer timerRecoverChan;

// Multi-stage data

list ownerList;         // names of pending owners
list nearbyAvis;        // ids of pending owners
integer sentHome = FALSE;

integer dwellMinutes;   // per-sim minutes
integer allowMinutes;   // travel minutes

string BoolOf(integer val)
{
    if (val) { return "Yes"; }
    return "No";
}


// RLV-secure the device, or remove any restrictions set.
// These need to be paired, so keep them together here.

secure(integer tx)
{
    // Restrictions first, let's get these in place
    if (locked)
    {
        // Lockdown only counts if wearer is locked.
        // Check lockdown first for our shortcut to 
        // removing restrictions.
        
        if (lockdown)
        {
            string restrain = "@startim=n,chatshout=ntplocal:0.5=n,tplm=n,tploc=n,tplure_sec=n,sittp:0.5=n,standtp=n";
            if (sentHome)
            {
                restrain = restrain + ",tpto:" + home + "=force";
                sentHome = FALSE;
            }
            integer i;
            integer l = llGetListLength(owners);
            for (i = 0; i < l; i++)
            {
                // Except owners from tplure lockout
                key o = llList2Key(owners, i);
                restrain = restrain + ",tplure:" + (string)o + "=add";
            }
            llInstantMessage(llGetOwner(), "lockdown! " + restrain);
            llOwnerSay(restrain);
        }
        else
        {
            llOwnerSay("@clear");
        }
        
        // (Re)-lock as needed
        
        string restrain = "@detach=n,permissive=n,editobj:" + (string)llGetLinkKey(1) + "=n";
        llInstantMessage(llGetOwner(), "locked: " + restrain);
        llOwnerSay(restrain);
        llTriggerSound("Locking", LOCK_SOUND_VOLUME);
    }
    else
    {
        llOwnerSay("@clear");
        llTriggerSound("Unlocking", LOCK_SOUND_VOLUME);
    }
    
    // On/off air status
    if (tx)
    {
        llInstantMessage(llGetOwner(), "tx");
        llSetLinkPrimitiveParamsFast(PRIM_ANTENNA, [PRIM_GLOW, ALL_SIDES, GLOW_ANTENNA]);
    }
    else
    {
        llInstantMessage(llGetOwner(), "rx");
        llSetLinkPrimitiveParamsFast(PRIM_ANTENNA, [PRIM_GLOW, ALL_SIDES, GLOW_OFF]);
    }

    // Set the LEDs as needed
    if (locked)
    {
        if (lockdown)
        {
            llSetLinkColor(PRIM_RED_LED, COLOR_RED, ALL_SIDES);
            llSetLinkPrimitiveParamsFast(PRIM_RED_LED, [PRIM_GLOW, ALL_SIDES, GLOW_RED]);
        }
        else
        {
            llSetLinkColor(PRIM_RED_LED, COLOR_YELLOW, ALL_SIDES);
            llSetLinkPrimitiveParamsFast(PRIM_RED_LED, [PRIM_GLOW, ALL_SIDES, GLOW_YELLOW]);
        }
    }
    else
    {
        llSetLinkColor(PRIM_RED_LED, COLOR_YELLOW, ALL_SIDES);
        llSetLinkPrimitiveParamsFast(PRIM_RED_LED, [PRIM_GLOW, ALL_SIDES, GLOW_OFF]);
    }
    
    if (tracking)
    {
        llSetLinkPrimitiveParamsFast(PRIM_GREEN_LED, [PRIM_GLOW, ALL_SIDES, GLOW_GREEN]);
    }
    else
    {
        llSetLinkPrimitiveParamsFast(PRIM_GREEN_LED, [PRIM_GLOW, ALL_SIDES, GLOW_OFF]);
    }
}


// Kick off the search for owner names.
// Wow this is a suck-ass way to do this.
// This is racey as hell, and the ownNames list may be invalid
// while we're frobbing the dataserver filling it in, but it
// SHOULD complete fast enough to not let a user get another
// menu on screen.

updateOwners()
{
    ownCount = 0;
    ownNames = [];
    nameReq = llRequestDisplayName(llList2Key(owners, 0));
}


default
{
    state_entry()
    {
        //llOwnerSay("Hello, Avatar!");
        gWearer = llGetOwner();
        configured = FALSE;
        
        menuChan = -1 - (integer)("0x"+ llGetSubString((string)llGetKey(), -7, -1));
        addOwnChan = menuChan - 1;
        delOwnChan = addOwnChan - 1;
        dwellChan = delOwnChan - 1;
        perChan = dwellChan - 1;
        allowChan = perChan -1;
        recoverChan = allowChan - 1;
        passChan = recoverChan - 1;
        
        llSetTouchText("Track");

        // Get wearers configuration, update displayname
        configReq = llHTTPRequest(
            "http://magic.softweyr.com/api/tracker/v1",
            [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
            "{\"avid\":\"" + (string)gWearer + "\"," +
             "\"dn\":\"" + llGetDisplayName(gWearer) + "\"," +
             "\"cmd\":\"get\"}");
        llSetLinkPrimitiveParamsFast(PRIM_ANTENNA, [PRIM_GLOW, ALL_SIDES, GLOW_ANTENNA]);
                
        // Zero out any timers, then start the timer tick
        timerTP = 0;
        timerMenuChan = 0;
        timerDwellChan = 0;
        timerAddOwnChan = 0;
        timerDelOwnChan = 0;
        timerPerChan = 0;
        timerAllowChan = 0;
        timerPassChan = 0;
        timerRecoverChan = 0;
        
        llSetTimerEvent(1.0);
    }
    
    changed(integer change)
    {
        if (change & CHANGED_TELEPORT) //note that it's & and not &&... it's bitwise!
        {
            //llOwnerSay("changed, locked = " + (string)locked + 
            //           ", tracking = " + (string)tracking);
            
            if (locked)
            {
                // Ask the server if we're allowed to TP here
                tpReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)llGetOwner() + "\"," +
                     "\"cmd\":\"arrive\", " +
                     "\"landing\":\"" + llGetRegionName() + "\"}");
                secure(TRUE);
            }
            // Do tracking when we know if this sim is permitted or not.
        }
    }
    
    touch_start(integer num)
    {
        key toucher = llDetectedKey(0);
        llOwnerSay("Touch start by " + (string)toucher);
        
        if (toucher == llGetOwner())
        {
            // Which wearer menu.  This depends on tracker states owned and locked.
            
            menuHand = llListen(menuChan, "", llGetOwner(), "");  // Listen only to wearer
            timerMenuChan = llGetUnixTime() + menuGraceTime;

            if (!locked)
            {
                // Unlocked wearer menu is identical to the owner menu
                llDialog(llGetOwner(), "Unlocked wearer menu", ownerMenu(), menuChan);
            }
            else if (llGetListLength(owners) == 0)
            {
                //llOwnerSay("Wearer is self-locked (unowned)");
                llDialog(llGetOwner(), "Unowned wearer menu", MENU_WEARER_LOCK_UNOWN, menuChan);
            }
            else
            {
                //llOwnerSay("Wearer is owned and locked");
                llDialog(llGetOwner(), "Locked wearer menu", MENU_WEARER_LOCK, menuChan);
            }
        }
        else
        {
            integer i = llListFindList(owners, [toucher]);
            if (i < 0)
            {
                llInstantMessage(toucher, "You are not allowed to operate " +
                                 llGetDisplayName(llGetOwner()) + "s tracker");
                llInstantMessage(llGetOwner(),
                                 llGetDisplayName(toucher) +
                                 " is not allowed to operate your tracker");
                //llOwnerSay(llGetDisplayName(toucher) + " is not allowed to operate your tracker");
            }
            else
            {
                llInstantMessage(llGetOwner(), llGetDisplayName(toucher) + " is operating your tracker");
                
                menuHand = llListen(menuChan, "", toucher, "");
                string statmsg = llGetDisplayName(llGetOwner()) + "'s Tracker\n" +
                    "Locked: " + BoolOf(locked) + "\n" +
                    "Tracking: " + BoolOf(tracking);
                llDialog(toucher, statmsg, ownerMenu(), menuChan);
                timerMenuChan = llGetUnixTime() + menuGraceTime;
            }
        }
    }
    
    listen(integer chan, string name, key id, string message)
    {
        if (chan == dwellChan)
        {
            //llOwnerSay("Sim dwell time: " + message);

            if (message == "30 mins") { dwellMinutes = 30; }
            else if (message == "1 hour") { dwellMinutes = 60; }
            else if (message == "2 hours") { dwellMinutes = 120; }
            else if (message == "4 hours") { dwellMinutes = 240; }
            else if (message == "6 hours") { dwellMinutes = 360; }
            else { dwellMinutes = 0; }

            if (dwellMinutes == 0)
            {
                locReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"addloc\"," +
                     "\"location\":\"" + llGetRegionName() + "\"}");
                secure(TRUE);
                //llOwnerSay("Adding " + llGetRegionName());
            }
            else // per?
            {
                // Otherwise, we have to solicit the recover time as well.
                perHand = llListen(perChan, "", id, "");
                string desc = llGetRegionName() + " per time";
                llDialog(id, desc, MENU_RECOVER, perChan);
                timerPerChan = llGetUnixTime() + menuGraceTime;
            }

            //llOwnerSay(llGetRegionName() + " being allowed?");
            llListenRemove(dwellHand);
        }
        else if (chan == perChan)
        {
            //llOwnerSay("Recover time: " + message);
            // NOTE: sim per time is in HOURS
            integer perHours = 1;
            if (message == "SL Day") { perHours = 4; }
            else if (message == "RL Day") { perHours = 24; }
            else if (message == "Week") { perHours = 168; }
            
            locReq = llHTTPRequest(
                "http://magic.softweyr.com/api/tracker/v1",
                [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                "{\"avid\":\"" + (string)gWearer + "\"," +
                 "\"cmd\":\"addloc\"," +
                 "\"location\":\"" + llGetRegionName() + "\"," +
                 "\"dwell\":" + (string)dwellMinutes + "," +
                 "\"per\":" + (string)perHours + "}");
            secure(TRUE);
            //llOwnerSay("Adding " + llGetRegionName() + " :: " + 
            //           (string)dwellMinutes + " / " + (string)perHours + " hrs");
            llListenRemove(perHand);
        }
        else if (chan == passChan)
        {
            // This is the owners (new) password
            passReq = llHTTPRequest(
                "http://magic.softweyr.com/api/tracker/v1",
                [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                "{\"avid\":\"" + (string)id + "\"," +
                 "\"cmd\":\"password\"," +
                 "\"username\":\"" + llGetUsername(id) + "\"," +
                 "\"password\":\"" + message + "\"}");
            secure(TRUE);
            llListenRemove(passHand);
        }
        else if (chan == allowChan)
        {
            //llOwnerSay("Travel time: " + message);
            if (message == "30 mins") { allowMinutes = 30; }
            else if (message == "1 hour") { allowMinutes = 60; }
            else if (message == "2 hours") { allowMinutes = 120; }
            else if (message == "4 hours") { allowMinutes = 240; }
            else if (message == "6 hours") { allowMinutes = 360; }
            else { allowMinutes = 0; }
            
            if (allowMinutes == 0) 
            {
                // If allowMinutes is zero, we just disable travel here.
                travReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"settravel\"}");
                secure(TRUE);
            }
            else
            {
                // Otherwise, we have to solicit the recover time as well.
                recoverHand = llListen(recoverChan, "", id, "");
                string desc = llGetDisplayName(llGetOwner()) + " travel recovery time";
                llDialog(id, desc, MENU_RECOVER, recoverChan);
                timerRecoverChan = llGetUnixTime() + menuGraceTime;
            }
            llListenRemove(allowHand);
        }
        else if (chan == recoverChan)
        {
            //llOwnerSay("Recover time: " + message);
            integer recoverMinutes = 60;
            if (message == "SL Day") { recoverMinutes = 240; }
            else if (message == "RL Day") { recoverMinutes = 1440; }
            else if (message == "Week") { recoverMinutes = 10080; }
            travReq = llHTTPRequest(
                "http://magic.softweyr.com/api/tracker/v1",
                [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                "{\"avid\":\"" + (string)gWearer + "\"," +
                 "\"cmd\":\"settravel\"," +
                 "\"away\":" + (string)allowMinutes + "," +
                 "\"recover\":" + (string)recoverMinutes + "}");
            secure(TRUE);
            //llOwnerSay("Requesting travel " + (string)allowMinutes + 
            //           " / " + (string)recoverMinutes);
            llListenRemove(recoverHand);
        }
        else if (chan == addOwnChan)
        {
            // llOwnerSay("New owner: " + message);
            
            // Find the selected name in the name list
            // This is such a totally fucking stupid way to do this,
            // why can't dialog at least take a strided list?
            
            integer i = llListFindList(ownerList, [message]);
            if (i < 0)
            {
                llOwnerSay("Add Own cancelled");
            }
            else
            {
                key newOwner = llList2Key(nearbyAvis, i);
                //llOwnerSay("Owner: " + llList2String(ownerList, i) + " : " + (string)newOwner);
                ownReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"addowner\"," +
                     "\"owner\":\"" + (string)newOwner + "\"}");
                secure(TRUE);
            }
            llListenRemove(addOwnHand);
        }
        else if (chan == delOwnChan)
        {
            // llOwnerSay("Del owner: " + message);
            
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
                //llOwnerSay("Owner: " + message + " : " + (string)newOwner);
                
                ownReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"delowner\"," +
                     "\"owner\":\"" + (string)newOwner + "\"}");
                secure(TRUE);
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
                secure(TRUE);
                llTriggerSound("Doorbell", BELL_SOUND_VOLUME);
            }
            else if (message == "Web")
            {
                // Set a password for the owner for the web app.
                allowHand = llListen(passChan, "", id, "");  // Listen only to toucher
                llTextBox(id, "Enter your new password:", passChan);
                timerPassChan = llGetUnixTime() + menuGraceTime;
                // Server call after second dialog
            }
            else if (message == "Travel Time")
            {
                // Specify the wearer's travel times, if any.
                allowHand = llListen(allowChan, "", id, "");  // Listen only to toucher
                llDialog(id, "Select allowed travel time", MENU_LINGER, allowChan);
                timerAllowChan = llGetUnixTime() + menuGraceTime;
                // Server call after second dialog
            }
            else if (message == "Travel")
            {
                // This requests travel permission.
                // If granted, the travel timeout is stored
                // in the server, so the response is only 
                // use for wearer feedback.
                
                travelReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"travel\"}");
                secure(TRUE);
            }
            // The next six are similar, but not identical
            else if (message == "Lock")
            {
                locked = TRUE;
                lockReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"lock\"}");
                secure(TRUE);
            }
            else if (message == "Unlock")
            {
                locked = FALSE;
                lockdown = FALSE;
                lockReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"lock\"," +
                     "\"state\":\"false\"}");
                secure(TRUE);
            }
            else if (message == "LockDown")
            {
                locked = TRUE;          // Lockdown implies lock
                lockdown = TRUE;
                downReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"lockdown\"}");
                sentHome = TRUE;
                secure(TRUE);
            }
            else if (message == "Release")
            {
                lockdown = FALSE;
                downReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"lock\"," +
                     "\"state\":\"false\"}");
                secure(TRUE);
            }
            else if (message == "Track")
            {
                tracking = TRUE;
                trackReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"track\"}");
                llTriggerSound("Tracking", TRACK_SOUND_VOLUME);
                secure(TRUE);
            }
            else if (message == "Untrack")
            {
                tracking = FALSE;
                trackReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\"," +
                     "\"cmd\":\"track\"," +
                     "\"state\":\"false\"}");
                secure(TRUE);
                llTriggerSound("Untracking", TRACK_SOUND_VOLUME);
            }
            else if (message == "Add Own")
            {
                // Perms: unlocked or owner
                
                list avis = llGetAgentList(AGENT_LIST_PARCEL_OWNER, []);
                
                integer i;
                integer j;
                key o;

                // Remove me from the list
                i = llListFindList(avis, [llGetOwner()]);
                if (i != -1) 
                {
                    llOwnerSay("Skipping me @ " + (string)i);
                    avis = llDeleteSubList(avis, i, i);
                }
                
                // Remove each of my existing owners from the list
                integer l = llGetListLength(owners);
                for (i = 0; i < l; i++)
                {
                    o = llList2Key(owners, i);
                    //llOwnerSay("Checking owner [" + (string)i + "]: " + (string)o);
                    j = llListFindList(avis, [o]);
                    if (j != -1) 
                    {
                        llOwnerSay("Skipping owner [" + (string)i + "]: " + (string)o + " @ " + (string)j);
                        avis = llDeleteSubList(avis, j, j);
                        if (llGetListLength(avis) < 1) { jump purged; }
                    }
                }
                
                @purged;
                l = llGetListLength(avis);
                llOwnerSay((string)l + " people in range");
                if (l > 0)
                {
                    vector currentPos = llGetPos();
                    list avilist;
                    key avi;
                    integer dist;
     
                    for (i = 0; i < l; ++i)
                    {
                        avi = llList2Key(avis, i);
                        dist = llRound(llVecDist(currentPos,
                                       llList2Vector(llGetObjectDetails(avi, [OBJECT_POS]), 0)));
                        llOwnerSay((string)avi + " @ " + (string)dist + "m");
                        if (dist <= maxOwnerDist)
                            avilist += [dist, avi];
                    }
     
                    //  sort strided list by ascending distance
                    avilist = llListSort(avilist, 2, TRUE);
                    
                    // Add avis to the list, nearest to farthest, stopping at 12.
                    ownerList = [];
                    nearbyAvis = [];
    
                    integer count = 0;
                    for (i = 0; i < (l * 2); i += 2)
                    {
                        key avatar = llList2Key(avilist, i+1);
                        string name = llGetDisplayName(avatar);
                        integer dist = llList2Integer(avilist, i);
                        //llOwnerSay(name + " @ " + (string)dist + "m");
                        ownerList += name;
                        nearbyAvis += avatar;
                        count += 1;
                        if (count == 12) jump maxxedOut;
                    }
                    
                    @maxxedOut;
                    addOwnHand = llListen(addOwnChan, "", id, "");
                    llDialog(id, "Choose new Owner", ownerList, addOwnChan);
                    timerAddOwnChan = llGetUnixTime() + menuGraceTime;
                }
                else
                {
                    addOwnHand = llListen(addOwnChan, "", id, "");
                    llDialog(id, "No potential owners in range", [], addOwnChan);
                    timerAddOwnChan = llGetUnixTime() + menuGraceTime;
                }
            }
            else if (message == "Del Own")
            {
                // Display the list of owner names we have cached.
                // This is racey as all hell.
                delOwnHand = llListen(delOwnChan, "", id, "");
                llDialog(id, "Remove which Owner", ownNames, delOwnChan);
                timerDelOwnChan = llGetUnixTime() + menuGraceTime;
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
                llDialog(id, "Sim linger time", MENU_LINGER, dwellChan);
                timerDwellChan = llGetUnixTime() + menuGraceTime;
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
            //llSay(0, "Display name[" + (string)ownCount + "] is " + data);
            // Save this name in the (rebuilding) owner names list
            ownNames += data;

            // If we haven't finished our owners list yet, keep going
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
        configured = FALSE;
        gWearer = llGetOwner();
        configReq = llHTTPRequest(
            "http://magic.softweyr.com/api/tracker/v1",
            [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
            "{\"avid\":\"" + (string)gWearer + "\",\"cmd\":\"get\"}");
        llSetLinkPrimitiveParamsFast(PRIM_ANTENNA, [PRIM_GLOW, ALL_SIDES, GLOW_ANTENNA]);
    }
    
    timer()
    {
        integer now = llGetUnixTime();
        
        // Has our configuration loaded?
        // Keep trying until the configuration server responds
        if (!configured)
        {
            // Get wearers configuration, update displayname
            configReq = llHTTPRequest(
                "http://magic.softweyr.com/api/tracker/v1",
                [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                "{\"avid\":\"" + (string)gWearer + "\"," +
                 "\"dn\":\"" + llGetDisplayName(gWearer) + "\"," +
                 "\"cmd\":\"get\"}");
            llSetLinkPrimitiveParamsFast(PRIM_ANTENNA, [PRIM_GLOW, ALL_SIDES, GLOW_ANTENNA]);
        }
        
        // Check to see if any timers have expired.
        if (timerTP != 0 && timerTP < now)
        {
            llInstantMessage(llGetOwner(), "Timed out, sending you home");
            llOwnerSay("@tpto:" + home + "=force");
            // Bump the timer in case the tp failed, so we keep trying.
            // A TP to a permitted sim will disable the timer.
            timerTP += tpGraceTime;
        }
        if (timerMenuChan != 0 && timerMenuChan < now)
        {
            llListenRemove(menuHand);
            timerMenuChan = 0;
        }
        if (timerDwellChan != 0 && timerDwellChan < now)
        {
            llListenRemove(dwellHand);
            timerDwellChan = 0;
        }
        if (timerAddOwnChan != 0 && timerAddOwnChan < now)
        {
            llListenRemove(addOwnHand);
            timerAddOwnChan = 0;
        }
        if (timerDelOwnChan != 0 && timerDelOwnChan < now)
        {
            llListenRemove(delOwnHand);
            timerDelOwnChan = 0;
        }
        if (timerPerChan != 0 && timerPerChan < now)
        {
            llListenRemove(perHand);
            timerPerChan = 0;
        }
        if (timerAllowChan != 0 && timerAllowChan < now)
        {
            llListenRemove(allowHand);
            timerAllowChan = 0;
        }
        if (timerPassChan != 0 && timerPassChan < now)
        {
            llListenRemove(passHand);
            timerPassChan = 0;
        }
        if (timerRecoverChan != 0 && timerRecoverChan < now)
        {
            llListenRemove(recoverHand);
            timerRecoverChan = 0;
        }
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
                //llOwnerSay("owners as string: " + ownStr);
                list ownlist = llParseString2List(ownStr, ["[", "]", "\"", ","], [""]);
                //llOwnerSay("ownlist: " + (string)ownlist);
                integer n = llGetListLength(ownlist);
                //llOwnerSay("Found " + (string)n + " ownlist:");
                
                // Convert owners to keys and store
                owners = [];
                integer i;
                for (i = 0; i < n; i++)
                {
                    key owner = llList2Key(ownlist, i);
                    //llOwnerSay("owner: " + (string)owner);
                    owners += owner;
                }
                
                //llOwnerSay("owners: " + (string)owners);
                
                updateOwners();
            }
            else
            {
                llOwnerSay("We got WTF for owners");
            }
        }
        else if (id == travelReq) 
        {
            //llOwnerSay(body);
            if (llJsonValueType(body, [(string)llGetOwner()]) == JSON_TRUE)
            {
                llTriggerSound("Swoosh", TRAVEL_SOUND_VOLUME);
            }
            else
            {
                llTriggerSound("Denied", TRAVEL_SOUND_VOLUME);
            }
        }
        else if (id == travReq)
        {
            // Travel time set.  Do we need to do anything here?
            llOwnerSay("travReq: " + body);
        }
        else if (id == passReq)
        {
            // Password saved.  Do we need to do anything here?
            llOwnerSay("passReq: " + body);
        }
        else if (id == tpReq) 
        {
            //llOwnerSay(body);
            string permitted;
            if (llJsonValueType(body, [(string)llGetOwner()]) == JSON_TRUE)
            {
                llOwnerSay("Welcome to " + llGetRegionName());
                timerTP = 0;
                permitted = "permitted";
            }
            else
            {
                llOwnerSay("You are not allowed in " + llGetRegionName() + 
                    ", booting in " + (string)tpGraceTime + " seconds");
                timerTP = llGetUnixTime() + tpGraceTime;
                permitted = "forbidden";
            }
            if (tracking)
            {
                //llOwnerSay("Tracking for: " + (string)owners);
                string where = llGetRegionName();
                string who = llGetDisplayName(llGetOwner());
                integer l = llGetListLength(owners);
                integer i;
                for (i = 0; i < l; i++)
                {
                    key owner = (key)llList2Key(owners, i);
                    string message = who + " arrived at " + permitted + " location " + where;
                    //llOwnerSay("IM("  + (string)owner + ", '" + message + "')");
                    llInstantMessage(owner, message);
                }
            }
        }
        else if (id == homeReq)
        {
            // User set a new home.  Do we need to do anything here?
            llOwnerSay("homeReq: " + body);
        }
        else if (id == locReq)
        {
            // User added a location.  Do we need to do anything here?
            llOwnerSay("locReq: " + body);
        }
        else if (id == lockReq)
        {
            // This was a lock/unlock, lockdown/release or track/untrack request
            llOwnerSay("lockReq: " + body);
        }
        else if (id == downReq)
        {
            // This was a lock/unlock, lockdown/release or track/untrack request
            llOwnerSay("downReq: " + body);
        }
        else if (id == trackReq)
        {
            // This was a lock/unlock, lockdown/release or track/untrack request
            llOwnerSay("trackReq: " + body);
        }
        else if (id == configReq)
        {
            llOwnerSay(body);
            
            if (llJsonValueType(body, ["locked"]) == JSON_TRUE)
            {
                locked = TRUE;
            }
            else if (llJsonValueType(body, ["locked"]) == JSON_FALSE)
            {
                locked = FALSE;
            }
            else
            {
                llOwnerSay("Lock is fucked, or LSL sucks tiny balls");
            }
            
            home = llJsonGetValue(body, ["home"]);
            //llOwnerSay("home: " + home);
            
            if (llJsonValueType(body, ["tracking"]) == JSON_TRUE)
            {
                tracking = TRUE;
            }
            else if (llJsonValueType(body, ["tracking"]) == JSON_FALSE)
            {
                tracking = FALSE;
            }
            else
            {
                llOwnerSay("tracking is fucked, or LSL sucks tiny balls");
            }
            //llOwnerSay("tracking: " + (string)tracking);
            
            string lo = llJsonValueType(body, ["lockdown"]);
            if (lo == JSON_TRUE)
            {
                lockdown = TRUE;
            }
            else if (lo == JSON_FALSE)
            {
                lockdown = FALSE;
            }
            //llOwnerSay("lockdown: " + (string)lockdown);

            recover = (integer)llJsonGetValue(body, ["recover"]);
            //llOwnerSay("recover: " + (string)recover);
            
            string ownStr = (string)llJsonGetValue(body, ["owners"]);
            list ownlist = llParseString2List(ownStr, ["[", "]", "\"", ","], [""]);
            integer n = llGetListLength(ownlist);
            owners = [];
            integer i;
            for (i = 0; i < n; i++)
            {
                key owner = llList2Key(ownlist, i);
                owners += owner;
            }
            //llOwnerSay("owners: <" + llDumpList2String(owners, "><") + ">");
            // Go find the owners names, too, for the "Del Owner" menu
            //ownCount = 0;
            //nameReq = llRequestDisplayName(llList2Key(owners, 0));
            updateOwners();

            //llOwnerSay("locations is an array: figure out the fucking names");
            string locsStr = (string)llJsonGetValue(body, ["locations"]);
            locations = llParseString2List(locsStr, ["[", "]", "\"", ","], [""]);
            //llOwnerSay("locations: <" + llDumpList2String(locations, "><") + ">");
            
            configured = TRUE;
        }
            
        // Update the lock, indicate we are off the air
        secure(FALSE);
    }
}

