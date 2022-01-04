integer hudChan = -19351206;
integer hudHand;

integer STATUS_LED = 10;

integer BUTTON_LOCK = 9;
integer BUTTON_UNLOCK = 8;
integer BUTTON_TRACK = 7;
integer BUTTON_UNTRACK = 6;
integer BUTTON_ADDLOC = 5;
integer BUTTON_DELLOC = 4;
integer BUTTON_HOME = 3;
integer BUTTON_LOCKDOWN = 2;

vector COLOR_GREEN = <0.255, 1.000, 0.212>;
vector COLOR_GREEN_OFF = <0.255, 0.480, 0.212>;
vector COLOR_RED = <1.000, 0.255, 0.212>;
vector COLOR_YELLOW = <1.000, 0.863, 0.000>;
vector COLOR_BLACK = <0.0, 0.0, 0.0>;

float GLOW_GREEN = 0.95;
float GLOW_RED = 0.90;
float GLOW_YELLOW = 0.65;
float GLOW_OFF = 0.0;
float GLOW_ON = 1.0;

list subjects;   // 4-strided list of my wearers that are in range; name then GUID

float scanInterval = 20.0;  // 60.0;
float shortInterval = 2.0;  // maybe 1.0?
integer longTimer;

statusDisplay()
{
    integer l = llGetListLength(subjects) / 4;
    //llOwnerSay("statusDisplay: " + (string)l + " subjects");
    if (l < 1)
    {
        llSetLinkColor(STATUS_LED, COLOR_GREEN, ALL_SIDES);
        llSetLinkPrimitiveParamsFast(STATUS_LED, [PRIM_GLOW, ALL_SIDES, GLOW_OFF]);
    }
    else
    {
        llSetLinkColor(STATUS_LED, COLOR_GREEN, ALL_SIDES);
        llSetLinkPrimitiveParamsFast(STATUS_LED, [PRIM_GLOW, ALL_SIDES, GLOW_GREEN]);
    }
}

default
{
    state_entry()
    {
        llOwnerSay("Magic Tracker HUD starting");
        
        // Set up our communications
        hudHand = llListen(hudChan, "", NULL_KEY, "");  // Listen to all HUDs in range
        
        // Clean up any lingering object texts
        llSetLinkPrimitiveParamsFast(STATUS_LED, [PRIM_TEXT, "", COLOR_GREEN, GLOW_OFF]);
        llSetLinkPrimitiveParamsFast(BUTTON_LOCK, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
        llSetLinkPrimitiveParamsFast(BUTTON_UNLOCK, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
        llSetLinkPrimitiveParamsFast(BUTTON_TRACK, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
        llSetLinkPrimitiveParamsFast(BUTTON_UNTRACK, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
        llSetLinkPrimitiveParamsFast(BUTTON_ADDLOC, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
        llSetLinkPrimitiveParamsFast(BUTTON_DELLOC, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
        llSetLinkPrimitiveParamsFast(BUTTON_HOME, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
        llSetLinkPrimitiveParamsFast(BUTTON_LOCKDOWN, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
        
        // Start out first scan for nearby trackers that belong to us.
        subjects = [];
        string scanMsg = "P:" + (string)llGetOwner();
        llSay(hudChan, scanMsg);
        //llOwnerSay("Scan: " + scanMsg);
        
        // Start the short timer
        longTimer = FALSE;
        llSetTimerEvent(shortInterval);
    }
    
    timer()
    {
        //llOwnerSay("timer");
        if (longTimer)
        {
            // Scan for trackers in range.  We tell trackers our GUID
            // so they can check their owner lists.
            subjects = [];
            llSay(hudChan, "P:" + (string)llGetOwner());
            //llOwnerSay("Scan");
            
            // Start the short timer
            longTimer = FALSE;
            llSetTimerEvent(shortInterval);
        }
        else
        {
            // Assume all the responses have come in by now.
            // Clean up the list.
            //llOwnerSay("Reap");
            llListSort(subjects, 4, TRUE);
            statusDisplay();
            
            // Restart the long timer
            llSetTimerEvent(scanInterval);
            longTimer = TRUE;
        }
    }

    touch_start(integer total_number)
    {
        //llOwnerSay("Touched.");
        integer link = llDetectedLinkNumber(0);
        if (link == BUTTON_LOCK)
        {
            llSetLinkPrimitiveParamsFast(BUTTON_LOCK, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
            llSay(hudChan, "L:" + (string)llGetOwner());
            llOwnerSay("Lock");
        }
        else if (link == BUTTON_UNLOCK)
        {
            llOwnerSay("Unlock");
            llSetLinkPrimitiveParamsFast(BUTTON_UNLOCK, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
            llSay(hudChan, "UL:" + (string)llGetOwner());
        }
        else if (link == BUTTON_TRACK)
        {
            llOwnerSay("Track");
            llSetLinkPrimitiveParamsFast(BUTTON_TRACK, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
            llSay(hudChan, "T:" + (string)llGetOwner());
        }
        else if (link == BUTTON_UNTRACK)
        {
            llOwnerSay("Untrack");
            llSetLinkPrimitiveParamsFast(BUTTON_UNTRACK, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
            llSay(hudChan, "UT:" + (string)llGetOwner());
        }
        else if (link == BUTTON_ADDLOC)
        {
            llOwnerSay("Add Location");
            llSetLinkPrimitiveParamsFast(BUTTON_ADDLOC, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
            llSay(hudChan, "AL:" + (string)llGetOwner());
        }
        else if (link == BUTTON_DELLOC)
        {
            llOwnerSay("Del Location");
            llSetLinkPrimitiveParamsFast(BUTTON_DELLOC, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
            llSay(hudChan, "DL:" + (string)llGetOwner());
        }
        else if (link == BUTTON_HOME)
        {
            llOwnerSay("Home");
            llSetLinkPrimitiveParamsFast(BUTTON_HOME, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
            llSay(hudChan, "H:" + (string)llGetOwner());
        }
        else if (link == BUTTON_LOCKDOWN)
        {
            llOwnerSay("It's the final lockdown!");
            llSetLinkPrimitiveParamsFast(BUTTON_LOCKDOWN, [PRIM_TEXT, "", COLOR_BLACK, GLOW_OFF]);
            llSay(hudChan, "LD:" + (string)llGetOwner());
        }
    }
    
    listen(integer chan, string name, key id, string message)
    {
        if (chan == hudChan)
        {
            //llOwnerSay("Tracker reply: " + message);
            list response = llParseString2List(message, [":"], []);
            if (llList2String(response, 0) == "U")
            {
                // This is an owned user.
                key user = llList2Key(response, 1);
                string name = llList2String(response, 2);
                integer locked = llList2Integer(response, 3);
                integer tracking = llList2Integer(response, 4);
                subjects += name;
                subjects += user;
                subjects += locked;
                subjects += tracking;
                //llOwnerSay(name + " is in range");
            }
        }
    }
}
