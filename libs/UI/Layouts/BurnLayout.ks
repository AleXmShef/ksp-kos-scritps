GLOBAL ComputedBurnStorage TO LEXICON(
	"Tig", 0,
	"dV", v(0, 0, 0)
).

FUNCTION UI_Manager_BurnLayout_Init {
    parameter self.

    print "|                                                          |".	//0
	print "|----------------------------------------------------------|".	//1
	print "|        Orbit        |   Burn Att   |      Execution      |".	//2
	print "| Ap               km | P        deg | ΔVtot           m/s |".	//3
	print "| Pe               km | Y        deg | Tgo               s |".	//4
	print "| Incl            deg | R        deg | Vgo             m/s |".	//5
	print "| LAN             deg |   Cur Att    |     X           m/s |".	//6
	print "| AoP             deg | P        deg |     Y           m/s |".	//7
	print "|---------------------| Y        deg |     Z           m/s |".	//8
	print "|       Mnvr Tgt      | R        deg |---------------------|".	//9
	print "| 1 Tig             s |    7 Mnvr    |        Status       |".	//10
	print "| 2 ΔVx           m/s |--------------| Stage               |".	//11
	print "| 3 ΔVy           m/s |    Gimbals   |---------------------|".	//12
	print "| 4 ΔVz           m/s | P        deg |       Warp          |".	//13
	print "|   5 Load / 6 Exec   | Y        deg | 9 Warp Tig          |".	//14
	print "|                     |   8 Enable   | Burn warp  10 ON    |".	//15
	print "|                                    |            11 OFF   |".	//16
	print "|                                                          |".	//17

	//    0123456789 123456789 123456789 123456789 123456789 123456789

	pc("Burn Execution", 0).
	if(self:Internal:PendingTarget:Tig - TIME:SECONDS < 0 and BurnTelemetry:Status = "Inactive") {
		set self["Internal"]["PendingTarget"] to LEXICON(
			"X", 0,
			"Y", 0,
			"Z", 0,
			"dV", v(0, 0, 0),
			"Tig", 0,
			"Obt", UpdateOrbitParams()
		).
	}
	if(BurnTelemetry:Status <> "Inactive" and self:Internal:PendingTarget:Tig = 0) {
		local dv_irf to toIRF(BurnTelemetry["BurnTarget"]["dV"]).
		set self["internal"]["PendingTarget"] to LEXICON(
			"X", dv_irf:X,
			"Y", dv_irf:Y,
			"Z", dv_irf:Z,
			"dV", dv_irf,
			"Tig", BurnTelemetry["BurnTarget"]["Tig"]
		).
		UI_Manager_BurnLayout_CalcOrbit(self).
	}
	if(ComputedBurnStorage:Tig - TIME:SECONDS < 0)
		set ComputedBurnStorage TO LEXICON(
			"Tig", 0,
			"dV", v(0, 0, 0)
		).
}

FUNCTION UI_Manager_BurnLayout_Update {
    parameter self.

	//Orbit
	local orbt to self["Internal"]["PendingTarget"]["Obt"]:COPY.
	pr((orbt:Ap - Globals:R)/1000, 18, 3).
	pr((orbt:Pe - Globals:R)/1000, 18, 4).
	pr(orbt:Inc, 17, 5).
	pr(orbt:LAN, 17, 6).
	pr(orbt:AoP, 17, 7).


	//Mnvr Tgt
	if(self:Internal:PendingTarget:Tig > 0) {
		pr(self:Internal:PendingTarget:Tig - TIME:SECONDS, 19, 10).
		pr(self:Internal:PendingTarget:X, 17, 11).
		pr(self:Internal:PendingTarget:Y, 17, 12).
		pr(self:Internal:PendingTarget:Z, 17, 13).
	}

	//Burn Att
	IF(BurnTelemetry:Status <> "Inactive") {
		local tgtRot to NormalizeAngles(LOOKDIRUP(toIRF(BurnTelemetry:BurnTarget:dV), toIRF(v(1, 0, 0)))).
		local curRot to NormalizeAngles(LOOKDIRUP(toIRF(SHIP:FACING:FOREVECTOR), toIRF(SHIP:FACING:UPVECTOR))).
		pr(tgtRot:PITCH, 32, 3).
		pr(tgtRot:YAW, 32, 4).
		pr(tgtRot:ROLL, 32, 5).

		pr(curRot:PITCH, 32, 7).
		pr(curRot:YAW, 32, 8).
		pr(curRot:ROLL, 32, 9).
	}

	//Gimbals
	IF(BurnTelemetry["Status"] <> "Inactive") {
		pr(BurnTelemetry["Gimbals"]["Pitch"], 32, 13).
		pr(BurnTelemetry["Gimbals"]["Yaw"], 32, 14).
	}

	//Execution
	IF(BurnTelemetry["Status"] <> "Inactive") {
		pr(BurnTelemetry["BurnTarget"]["dV"]:MAG, 54, 3).
		pr(BurnTelemetry["Telemetry"]["Tgo"], 56, 4).
		pr(BurnTelemetry["Telemetry"]["Vgo"]:MAG, 54, 5).
		local VgoIRF to toIRF(BurnTelemetry["Telemetry"]["Vgo"]).
		pr(VgoIRF:X, 54, 6).
		pr(VgoIRF:Y, 54, 7).
		pr(VgoIRF:Z, 54, 8).
	}

	//Status
	pr(BurnTelemetry["Status"], 58, 11).
}

FUNCTION UI_Manager_BurnLayout_Warp {
	parameter self.
	parameter arg.
	IF(BurnTelemetry["Status"] = "Wait Tig") {
		KUNIVERSE:TIMEWARP:WARPTO(BurnTelemetry:BurnTarget:TIG - 10).
	}
}

FUNCTION UI_Manager_BurnLayout_Load {
	parameter self.
	parameter arg.
	IF (ComputedBurnStorage:Tig <> 0) {
		set self["Internal"]["PendingTarget"]["Tig"] to ComputedBurnStorage["Tig"].
		set self["Internal"]["PendingTarget"]["dV"] to toIRF(ComputedBurnStorage["dV"]).
		set self["Internal"]["PendingTarget"]["X"] to self["Internal"]["PendingTarget"]["dV"]:X.
		set self["Internal"]["PendingTarget"]["Y"] to self["Internal"]["PendingTarget"]["dV"]:Y.
		set self["Internal"]["PendingTarget"]["Z"] to self["Internal"]["PendingTarget"]["dV"]:Z.
		UI_Manager_BurnLayout_CalcOrbit(self).
		return "".
	}
	ELSE {
		return "ERR: NOTHING TO LOAD".
	}
}

FUNCTION UI_Manager_BurnLayout_Exec {
	parameter self.
	parameter arg.

	if(self["Internal"]["PendingTarget"]["Tig"] - TIME:SECONDS < 0)
		return "ERR: NO TGT".

	TaskQueue:PUSH(
		LEXICON(
			"Type", "Burn",
			"Tig", self["Internal"]["PendingTarget"]["Tig"],
			"dV", fromIRF(self["Internal"]["PendingTarget"]["dV"])
		)
	).
	return "".
}

FUNCTION UI_Manager_BurnLayout_CalcOrbit {
	parameter self.
	local curOrb to UpdateOrbitParams().
	local depR to RatAngle(curOrb, AngleAtT(curOrb, SHIP:ORBIT:TRUEANOMALY, self["Internal"]["PendingTarget"]["Tig"] - TIME:SECONDS)).
	local depV to VatAngle(
		curOrb,
		AngleAtT(curOrb, SHIP:ORBIT:TRUEANOMALY, self["Internal"]["PendingTarget"]["Tig"] - TIME:SECONDS)
	) + fromIRF(self["Internal"]["PendingTarget"]["dV"]).
	set self["Internal"]["PendingTarget"]["Obt"] to BuildOrbitFromVR(depV, depR).
}

FUNCTION UI_Manager_BurnLayout_SetTarget {
	declare parameter type.
	declare parameter self.
	declare parameter arg.

	if(type = "Tig") {
		set self["Internal"]["PendingTarget"][type] to arg:TONUMBER(0) + TIME:SECONDS.
	}
	else
		set self["Internal"]["PendingTarget"][type] to arg:TONUMBER(0).
	set self["Internal"]["PendingTarget"]["dV"] to fromIRF(V(
		self["Internal"]["PendingTarget"]["X"],
		self["Internal"]["PendingTarget"]["Y"],
		self["Internal"]["PendingTarget"]["Z"]
	)).
	if(self["Internal"]["PendingTarget"]["Tig"] > 0) {
		UI_Manager_BurnLayout_CalcOrbit(self).
	}

	return "".
}

FUNCTION UI_Manager_GetBurnLayout {
	return LEXICON (
		"Init", UI_Manager_BurnLayout_Init@,
		"Update", UI_Manager_BurnLayout_Update@,
		"Internal", LEXICON(
			"PendingTarget", LEXICON(
				"X", 0,
				"Y", 0,
				"Z", 0,
				"dV", v(0, 0, 0),
				"Tig", 0,
				"Obt", UpdateOrbitParams()
			)
		),
		"Items", LEXICON(
			"1", LEXICON("Action", UI_Manager_BurnLayout_SetTarget@:BIND("Tig")),
			"2", LEXICON("Action", UI_Manager_BurnLayout_SetTarget@:BIND("X")),
			"3", LEXICON("Action", UI_Manager_BurnLayout_SetTarget@:BIND("Y")),
			"4", LEXICON("Action", UI_Manager_BurnLayout_SetTarget@:BIND("Z")),
			"5", LEXICON("Action", UI_Manager_BurnLayout_Load@),
			"6", LEXICON("Action", UI_Manager_BurnLayout_Exec@),
			"9", LEXICON("Action", UI_Manager_BurnLayout_Warp@)
		)
	).
}
