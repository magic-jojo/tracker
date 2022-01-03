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
            list packet = llParseString2List(message, [":"], []);
            
            // Verify this user is our owner.  Short-circuit here for testing
            key hudUser = llList2Key(packet, 1);
            llSay(0, "From: " + (string)hudUser);
            if (hudUser == llGetOwner()) // TODO owner check!
            {
                llSay(0, "pOWNED");
            }
            
            llSay(0, "HUD said: " + llList2String(packet, 0));
            if (llList2String(packet, 0) == "P")
            {
                llSay(hudChan, "U:caf5386a-7dbe-488f-b194-5a7b681d9e9b:Jaelyn:1:1");
                llSay(hudChan, "U:7da4a085-7dfc-45dd-ad6a-671532cc48a0:Taelyn:1:1");
                llSay(hudChan, "U:fcff25a1-248f-4c7b-913e-cd6a0127dc46:Robin Beamish:1:1");
                llSay(0, "PONG");
            }
            else if (llList2String(packet, 0) == "H")
            {
                // This was a broadcast HOME command
                llSay(0, "GO HOME");
            }
            else if (llList2String(packet, 0) == "L")
            {
                // This was a broadcast HOME command
                llSay(0, "LOCK");
            }
            else if (llList2String(packet, 0) == "UL")
            {
                // This was a broadcast HOME command
                llSay(0, "UnLOCK");
            }
            else if (llList2String(packet, 0) == "T")
            {
                // This was a broadcast HOME command
                llSay(0, "Track");
            }
            else if (llList2String(packet, 0) == "UT")
            {
                // This was a broadcast HOME command
                llSay(0, "UnTrack");
            }
            else if (llList2String(packet, 0) == "AL")
            {
                // This was a broadcast HOME command
                llSay(0, "AddLock");
            }
            else if (llList2String(packet, 0) == "DL")
            {
                // This was a broadcast HOME command
                llSay(0, "DelLoc");
            }
            else if (llList2String(packet, 0) == "LD")
            {
                // This was a broadcast HOME command
                llSay(0, "It's the FINAL LOCKDOWN");
            }
        }
    }
}
