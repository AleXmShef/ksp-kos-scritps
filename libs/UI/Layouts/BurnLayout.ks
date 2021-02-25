GLOBAL ComputedBurnStorage TO LEXICON(
	"Tig", 0,
	"Vgo", v(0, 0, 0)
)

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
}

FUNCTION UI_Manager_BurnLayout_Update {
    parameter self.

	//Orbit
	IF(BurnTelemetry:Status <> "Inactive") {
		local orbt to BurnTelemetry:Telemetry:ResultOrbit:COPY.
		pr((orbt:Ap - Globals:R)/1000, 18, 3).
		pr((orbt:Pe - Globals:R)/1000, 18, 4).
		pr(orbt:Inc, 17, 5).
		pr(orbt:LAN, 17, 6).
		pr(orbt:AoP, 17, 7).
	}

	//Mnvr Tgt
	pr(BurnTelemetry:BurnTarget:Tig - TIME:SECONDS, 19, 10).
	local dVirf to toIRF(BurnTelemetry:Telemetry:Vgo).
	pr(dVirf:X, 17, 11).
	pr(dVirf:Y, 17, 12).
	pr(dVirf:Z, 17, 13).

	//Burn Att
	IF(BurnTelemetry:Status <> "Inactive") {
		local tgtRot to NormalizeAngles(LOOKDIRUP(dVirf, toIRF(v(1, 0, 0)))).
		local curRot to NormalizeAngles(LOOKDIRUP(toIRF(SHIP:FACING:FOREVECTOR), toIRF(SHIP:FACING:UPVECTOR))).
		pr(tgtRot:PITCH, 32, 3).
		pr(tgtRot:YAW, 32, 4).
		pr(tgtRot:ROLL, 32, 5).

		pr(curRot:PITCH, 32, 7).
		pr(curRot:YAW, 32, 8).
		pr(curRot:ROLL, 32, 9).
	}

	//Gimbals
	IF(BurnTelemetry:Status <> "Inactive") {
		pr(BurnTelemetry:Gimbals:Pitch, 32, 13).
		pr(BurnTelemetry:Gimbals:Yaw, 32, 14).
	}

	//Execution
	IF(BurnTelemetry:Status <> "Inactive") {
		pr(BurnTelemetry:BurnTarget:dV, 54, 3).
		pr(BurnTelemetry:Telemetry:Tgo, 56, 4).
		pr(BurnTelemetry:Telemetry:Vgo:MAG, 54, 5).
		local VgoIRF to toIRF(BurnTelemetry:Telemetry:Vgo).
		pr(VgoIRF:X, 54, 6).
		pr(VgoIRF:Y, 54, 7).
		pr(VgoIRF:Z, 54, 8).
	}

	//Status
	pr(BurnTelemetry:Status, 58, 11).
}

FUNCTION UI_Manager_BurnLayout_Load {
	IF (ComputedBurnStorage:Tig <> 0) {

		return "".
	}
	ELSE {
		return "ERR: NOTHING TO LOAD"
	}
}

FUNCTION UI_Manager_BurnLayout_SetTarget {
	declare parameter type.
	declare parameter self.
	declare parameter arg.

	if(type = "Tig") {
		self:Internal:PendingTarget[type] to arg:TONUMBER(0) + TIME:SECONDS.
	}
	set self:Internal:PendingTarget[type] to arg:TONUMBER(0).
	local tgtVec to V(
		self:Internal:PendingTarget:X,
		self:Internal:PendingTarget:Y,
		self:Internal:PendingTarget:Z
	).
	if(self:Internal:PendingTarget:Tig > 0) {
		local curOrb to UpdateOrbitParams().
		local
		set self:Internal:PendingTarget:Obt to BuildOrbitFromVR()
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
				"Tig", 0,
				"Obt", OrbitClass:COPY.
			)
		)
		"Items", LEXICON(
			"1", UI_Manager_BurnLayout_SetTarget@:BIND("Tig"),
			"2", UI_Manager_BurnLayout_SetTarget@:BIND("X"),
			"3", UI_Manager_BurnLayout_SetTarget@:BIND("Y"),
			"4", UI_Manager_BurnLayout_SetTarget@:BIND("Z"),

		)
	).
}
