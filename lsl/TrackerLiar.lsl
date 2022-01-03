integer hudChan = -19351206;
integer hudHand;

float scanInterval = 60.0;

default
{
    state_entry()
    {
        // Set up our communications
        hudHand = llListen(hudChan, "", NULL_KEY, "");  // Listen to all HUDs in range
        //llSetTimerEvent(scanInterval);
    }

    touch_start(integer total_number)
    {
        llSay(0, "Touched.");
    }
    
    timer()
    {
        // Check for trackers in range.  We tell trackers our GUID
        // so they can check their owner lists.
        
        llSay(hudChan, "P:" + (string)llGetOwner());
        llSay(0, "Scan");
    }
    
    listen(integer chan, string name, key id, string message)
    {
        if (chan == hudChan)
        {
            //llSay(0, "HUD said: " + message);
            if (llGetSubString(message, 0, 1) == "P:")
            {
                key hudUser = (key)llGetSubString(message, 2, -1);
                //llSay(0, "Ping from: " + (string)hudUser);
                if (hudUser == llGetOwner())
                {
                    llSay(0, "HUD pinged me");
                    llSay(hudChan, "U:caf5386a-7dbe-488f-b194-5a7b681d9e9b:Jaelyn");
                    llSay(hudChan, "U:7da4a085-7dfc-45dd-ad6a-671532cc48a0:Taelyn");
                    llSay(hudChan, "U:fcff25a1-248f-4c7b-913e-cd6a0127dc46:Robin Beamish");
                }
            }
        }
    }
}

