// Magic API request/response keys
// First various web communications req/resp pairs
key configReq;
key homeReq;  // Yup, got a real homeReq'er here

key tpReq;
key regReq;

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

list MENU_WEARER_INIT = ["Set Home", "Add Loc", "Add Own"];

// communications channels

integer menuChan;
integer menuHand;

default
{
    state_entry()
    {
        //llOwnerSay("Hello, Avatar!");
        gWearer = llGetOwner();
        menuChan = -1 - (integer)("0x"+ llGetSubString((string)llGetKey(), -7, -1));
        llOwnerSay("Menu chan: " + (string)menuChan);
    }
    
    changed(integer change)
    {
        if (change & CHANGED_TELEPORT) //note that it's & and not &&... it's bitwise!
        {
            //string region = llGetRegionName();
            //llOwnerSay("Arrived in " + region);

            // Ask the server if we're allowed to TP here
            tpReq = llHTTPRequest(
                 "http://magic.softweyr.com/api/tracker/v1",
                [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                "{\"avid\":\"" + (string)llGetOwner() + "\",\"cmd\":\"arrive\", \"landing\":\"" + llGetRegionName() + "\"}");
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
    }
    
    listen(integer chan, string name, key id, string message)
    {
        if (chan == menuChan)
        {
            if (message == "Set Home")
            {
                //llOwnerSay(llGetRegionName() + " is your home now");
                
                // Get the global coordinates for where the wearer is right now.
                // This requires getting the region global coords from the server.
                regReq = llRequestSimulatorData(llGetRegionName(), DATA_SIM_POS);
            }
            
            llListenRemove(menuHand);
        }
    }
    
    dataserver(key qId, string data)
    {
        if (qId == regReq)
        {
            // Data is the region position, add the local position
            vector globalPos = (vector)data + llGetPos();
            // Send a "set home" request.
            home = llEscapeURL(llGetRegionName()) + "/" + 
                (string)((integer)globalPos.x) + "/" +
                (string)((integer)globalPos.y) + "/" + 
                (string)((integer)globalPos.z);
            homeReq = llHTTPRequest(
                "http://magic.softweyr.com/api/tracker/v1",
                [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json" ],
                "{\"avid\":\"" + (string)gWearer + "\",\"cmd\":\"sethome\",\"home\":\"" + home + "\"}");
            llOwnerSay("Set home to " + home);
            //llOwnerSay("@tpto:" + home + "=force");
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
                llOwnerSay("You are not allowed in " + llGetRegionName());
            }
        }
        else if (id == homeReq)
        {
            // User set a new home.  Do we need to do anything here?
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
                //llOwnerSay("It's an array");
                //string os = llJsonGetValue(body, ["owners"]);
                //llOwnerSay("owners (string): " + os);
                owners = (list)llJsonGetValue(body, ["owners"]);
                llOwnerSay("owners: " + (string)owners);
            }
            else
            {
                llOwnerSay("owners type is? ");
            }
            
            ty = llJsonValueType(body, ["locations"]);
            if (ty == JSON_ARRAY)
            {
                llOwnerSay("It's an array");
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

