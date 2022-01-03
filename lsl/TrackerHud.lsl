integer hudChan = -19351206;
integer hudHand;

// Status LEDs

integer LED1 = 13;
integer LED2 = 12;
integer LED3 = 11;
integer LED4 = 10;
integer LED5 = 9;
integer LED6 = 8;
integer LED7 = 7;
integer LED8 = 6;

list LEDs = [ LED1, LED2, LED3, LED4, LED5, LED6, LED7, LED8 ];

integer STATUS_LED = 5;

integer LTARROW = 2;
integer RTARROW = 3;
integer TEXTBOX = 4;

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

list subjects;   // 2-strided list of my wearers that are in range; name then GUID

statusDisplay()
{
    integer l = llGetListLength(subjects) / 2;
    llSay(0, "statusDisplay: " + (string)l + " subjects");
    if (l < 1)
    {
        llSetLinkColor(STATUS_LED, COLOR_RED, ALL_SIDES);
        llSetLinkPrimitiveParamsFast(STATUS_LED, [PRIM_GLOW, ALL_SIDES, GLOW_RED]);
    }
    else
    {
        llSetLinkColor(STATUS_LED, COLOR_YELLOW, ALL_SIDES);
        llSetLinkPrimitiveParamsFast(STATUS_LED, [PRIM_GLOW, ALL_SIDES, GLOW_YELLOW]);
    }
    integer i;
    for (i = 0; i < l; i++)
    {
        integer led = llList2Integer(LEDs, i);
        llSetLinkColor(led, COLOR_GREEN, ALL_SIDES);
        llSetLinkPrimitiveParamsFast(led, [PRIM_GLOW, ALL_SIDES, GLOW_GREEN]);
        //llSay(0, "Lighting LED " + (string)i + " link " + (string)led);
    }
    for (i = l; i < 8; i++)
    {
        integer led = llList2Integer(LEDs, i);
        llSetLinkColor(led, COLOR_GREEN_OFF, ALL_SIDES);
        llSetLinkPrimitiveParamsFast(led, [PRIM_GLOW, ALL_SIDES, GLOW_OFF]);
        //llSay(0, "Dimming LED " + (string)i + " link " + (string)led);
    }
}

string selectedUser = "";

selectionDisplay()
{
    // Sort the list of responses to make sure it is in order.
    llListSort(subjects, 2, TRUE);

    // If we have a selected user, see if she is still in the nearby users;
    // otherwise select somebody.
    string name = selectedUser;
    if (llListFindList(subjects, [selectedUser]) == -1) 
    { 
        name = llList2String(subjects, 0);
    }
    llSetLinkPrimitiveParamsFast(TEXTBOX, [PRIM_TEXT, name, COLOR_BLACK, GLOW_ON]);
}


float scanInterval = 20.0; // 60.0;
float shortInterval = 2.0;

integer timerLong = TRUE;

default
{
    state_entry()
    {
        // Set up our communications
        hudHand = llListen(hudChan, "", NULL_KEY, "");  // Listen to all HUDs in range
        llSetTimerEvent(scanInterval);
    }

    touch_start(integer total_number)
    {
        llSay(0, "Touched.");
        integer l = llGetListLength(subjects);
        integer s = llListFindList(subjects, [selectedUser]);
        integer link = llDetectedLinkNumber(0);
        if (link == LTARROW)
        {
            // Select the user "before" the current one
            if (s == -1)
            {
                // That user dropped off the list, just pick somebody
                s = 0;
            }
            else if (s == 0)
            {
                // Left of the beginning is the end (minus one for stride)
                s = l - 1;
            }
            else
            {
                s -= 2; // for stride
            }
            selectedUser = llList2String(subjects, s);
            selectionDisplay();
        }
        else if (link == RTARROW)
        {
            if (s == -1)
            {
                // That user dropped off the list, just pick somebody
                s = 0;
            }
            else if (s >= l)  // Again, because stride
            {
                // Right of the end is the beginning
                s = 0;
            }
            else
            {
                s += 2; // for stride
            }
            selectedUser = llList2String(subjects, s);
            selectionDisplay();
        }
    }
    
    timer()
    {
        if (timerLong)
        {
            // Check for trackers in range.  We tell trackers our GUID
            // so they can check their owner lists.
            llSay(hudChan, "P:" + (string)llGetOwner());
            subjects = [];
            llSay(0, "Scan");
            llSetTimerEvent(shortInterval);
            timerLong = FALSE;
        }
        else
        {
            // Assume all the responses have come in by now.
            // Clean up the list.
            statusDisplay();
            selectionDisplay();
            
            llSetTimerEvent(scanInterval);
            timerLong = TRUE;
        }
    }
    
    listen(integer chan, string name, key id, string message)
    {
        if (chan == hudChan)
        {
            //llSay(0, "Tracker reply: " + message);
            list response = llParseString2List(message, [":"], []);
            if (llList2String(response, 0) == "U")
            {
                // This is an owned user.
                key user = llList2Key(response, 1);
                string name = llList2String(response, 2);
                subjects += name;
                subjects += user;
                llSay(0, name + " is in range");
            }
        }
    }
}

