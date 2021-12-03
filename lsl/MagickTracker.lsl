// Magic API request/response keys
// First various web communications req/resp pairs
key configReq;
key homeReq;  // Yup, got a real homeReq'er here
key locReq;

key tpReq;
key regReq;

// Contants.  ish.

float tpGraceTime = 30.0;   // Seconds before you get the boot
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

// Menus.

list MENU_WEARER_INIT = ["Set Home", "Add Loc", "Add Own", "TP Home"];

// communications channels

integer menuChan;
integer menuHand;

integer ownerChan;
integer ownerHand;

list ownerList;         // names of pending owners
list pendingOwners;     // ids of pending owners
    
default
{
    state_entry()
    {
        //llOwnerSay("Hello, Avatar!");
        gWearer = llGetOwner();
        menuChan = -1 - (integer)("0x"+ llGetSubString((string)llGetKey(), -7, -1));
        ownerChan = menuChan - 1;
        llOwnerSay("Menu chan: " + (string)menuChan + ", Owner chan: " + (string)ownerChan);

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
    
    touch_start(integer num)
    {
        gWearer = llDetectedKey(0);
        llOwnerSay("Touch start by " + (string)gWearer);
        
        if (llDetectedKey(0) == llGetOwner())
        {
            // Wearer menu.  This depends on whether we are locked or not.
            menuHand = llListen(menuChan, "", llGetOwner(), "");  // Listen only to wearer
            llDialog(llGetOwner(), "Wearer menu", MENU_WEARER_INIT, menuChan);
        }
        
        integer l = llGetListLength(owners);
        integer i;
        for (i = 0; i < l; i++)
        {
            key owner = (key)llList2Key(owners, i);
            llOwnerSay("own: " + (string)owner);
        }
    }
    
    listen(integer chan, string name, key id, string message)
    {
        if (chan == ownerChan)
        {
            // We have a new owner
            llOwnerSay("New owner: " + message);
            llListenRemove(ownerHand);
            
            // Find the selected name in the name list
            integer i = llListFindList(ownerList, [message]);
            if (i < 0)
            {
                llOwnerSay("WTF?  Owner list b0rked");
            }
            else
            {
                key newOwner = llList2Key(pendingOwners, i);
                llOwnerSay("New owner: " + llList2String(ownerList, i) + " : " + (string)newOwner);
            }
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
                pendingOwners = [];

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
                    pendingOwners += avatar;
                }
                
                ownerHand = llListen(ownerChan, "", llGetOwner(), "");
                llDialog(llGetOwner(), "Choose new Owner", ownerList, ownerChan);
            }
            else if (message == "TP Home")
            {
                llOwnerSay("@tpto:" + home + "=force");
            }
            else if (message == "Add Loc")
            {
                // Perms: Unlocked or Owner
                
                locReq = llHTTPRequest(
                    "http://magic.softweyr.com/api/tracker/v1",
                    [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                    "{\"avid\":\"" + (string)gWearer + "\",\"cmd\":\"addloc\",\"location\":\"" + llGetRegionName() + "\"}");
                llOwnerSay(llGetRegionName() + " is now allowed");
            }
            
            llListenRemove(menuHand);
        }
    }
        
    touch_end(integer num)
    {
        gWearer = llDetectedKey(0);
        llOwnerSay("Touch end by " + (string)gWearer);
    }
    
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
        llOwnerSay("tpto:" + home + "=force");
        llOwnerSay("@tpto:" + home + "=force");
    }

    http_response(key id, integer status, list metadata, string body)
    {
        if (id == tpReq) {
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

