declare function UI_Manager_BurnLayout_Init {
    declare parameter self.

    print "|                                                          |".	//0
	print "|----------------------------------------------------------|".	//1
	print "|                                                          |".	//2
	print "|                                                          |".	//3
	print "|                                                          |".	//4
	print "|                                                          |".	//5
	print "|                                                          |".	//6
	print "|                                                          |".	//7
	print "|                                                          |".	//8
	print "|                                                          |".	//9
	print "|                                                          |".	//10
	print "|                                                          |".	//11
	print "|                                                          |".	//12
	print "|                                                          |".	//13
	print "|                                                          |".	//14
	print "|                                                          |".	//15
	print "|                                                          |".	//16
	print "|                                                          |".	//17

	//    0123456789 123456789 123456789 123456789 123456789 123456789

    print ".------------------------------.".	//0
    print "|   Burn Execution Interface   |".	//1
    print "|------------------------------|".	//2
    print "| Status:                      |".	//3
    print "|------------------------------|".	//4
    print "| MET:           d   h   m   s |".	//5
    print "|------------------------------|".	//6
    print "| Ignition time  =           s |".	//7
    print "| Cutoff time    =           s |".	//8
    print "| dVgo           =         m/s |".	//9
    print "|------------------------------|".	//10
    print "|     Current       Target     |".	//11
    print "| Ap          km |          km |".	//12
    print "| Pe          km |          km |".	//13
    print "| Inc        deg |         deg |".	//14
    print "| AoP        deg |         deg |".	//15
    print "| LAN        deg |         deg |".	//16
    print "|------------------------------|".	//17
    print "|                              |".	//18
    print "*------------------------------*".	//19
    //     123456789
    //              10
    //               123456789
    //                        20
    //                         123456789
    //                                  30
    //                                   12
}

declare function UI_Manager_BurnLayout_Update {
    declare parameter self.

    //Status
    print BurnTelemetry["Status"] at (RightPadding(30, BurnTelemetry["Status"]), 3).

    //Stats
    local ignTime to ROUND((BurnTelemetry["IgnitionTime"] - TIME:SECONDS), 1).
    if(BurnTelemetry["IgnitionTime"] > 0)
        print ignTime at (RightPadding(28, ignTime), 7).

    local coTime to ROUND(BurnTelemetry["CutoffTime"], 1).
    if (BurnTelemetry["CutoffTime"] > 0)
        print coTime at (RightPadding(28, coTime), 8).
    print ROUND(BurnTelemetry["dVgo"], 1) at (RightPadding(26, ROUND(BurnTelemetry["dVgo"], 1)), 9).

    //Telemetry
    local curAp to ROUND((BurnTelemetry["CurrentOrbit"]["Ap"] - Globals["R"])/1000, 2).
    local curPe to ROUND((BurnTelemetry["CurrentOrbit"]["Pe"] - Globals["R"])/1000, 2).
    local curInc to ROUND(BurnTelemetry["CurrentOrbit"]["Inc"], 2).
    local curAoP to ROUND(BurnTelemetry["CurrentOrbit"]["AoP"], 2).
    local curLAN to ROUND(BurnTelemetry["CurrentOrbit"]["LAN"], 2).

    local tgtAp to ROUND((BurnTelemetry["TargetOrbit"]["Ap"] - Globals["R"])/1000, 2).
    local tgtPe to ROUND((BurnTelemetry["TargetOrbit"]["Pe"] - Globals["R"])/1000, 2).
    local tgtInc to ROUND(BurnTelemetry["TargetOrbit"]["Inc"], 2).
    local tgtAoP to ROUND(BurnTelemetry["TargetOrbit"]["AoP"], 2).
    local tgtLAN to ROUND(BurnTelemetry["TargetOrbit"]["LAN"], 2).

    print curAp at (RightPadding(13, curAp), 12).
    print tgtAp at (RightPadding(27, tgtAp), 12).

    print curPe at (RightPadding(13, curPe), 13).
    print tgtPe at (RightPadding(27, tgtPe), 13).

    print curInc at (RightPadding(12, curInc), 14).
    print tgtInc at (RightPadding(26, tgtInc), 14).

    print curAoP at (RightPadding(12, curAoP), 15).
    print tgtAoP at (RightPadding(26, tgtAoP), 15).

    print curLAN at (RightPadding(12, curLAN), 16).
    print tgtLAN at (RightPadding(26, tgtLAN), 16).

    //Message
    print BurnTelemetry["Message"] at (2, 18).
}

SET UI_Manager_PendingAdditionLayout TO LEXICON (
	"TargetOrbit", OrbitClass:COPY,
	"CurrentOrbit", OrbitClass:COPY,
	"Tig", 0,
	"Tgo", 0,
	"Vgo", 0,
	"Status", "",
	"Message", "",
	"ConfirmationFlag", false
).
