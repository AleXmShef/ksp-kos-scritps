DECLARE FUNCTION UI_Manager_DapLayout_Init {
	parameter self.
    print "|                                                          |".	//0
	print "|----------------------------------------------------------|".	//1
	print "| DAP:       |       Tgt       |           Status          |".	//2
	print "|   1 On     | 7 P           d |     Att          Rate     |".	//3
	print "|   2 Off    | 8 Y           d |  Cur        |  Cur        |".	//4
	print "|            | 9 R           d | P         d | P       d/s |".	//5
	print "| Mode:      | Body            | Y         d | Y       d/s |".	//6
	print "|   3 Inrtl  |   10 Sun        | R         d | R       d/s |".	//7
	print "|   4 LVLH   |   11 Earth      |  Tgt        |  Tgt        |".	//8
	print "| Track      |   12 Tgt        | P         d | P       d/s |".	//9
	print "|   5 Pos    |                 | Y         d | Y       d/s |".	//10
	print "|   6 Att    |                 | R         d | R       d/s |".	//11
	print "|    13 Confirm / 14 Reset                                 |".	//12
	print "|                                                          |".	//13
	print "|                                                          |".	//14
	print "|                                                          |".	//15
	print "|                                                          |".	//16
	print "|                                                          |".	//17

	//    0123456789 123456789 123456789 123456789 123456789 123456789

	pc("DAP", 0).
}

FUNCTION UI_Manager_DapLayout_Update {
	parameter self.

	if(DAP:Engaged)
		pl("*", 8, 3).
	else
		pl("*", 9, 4).

	local source to DAP.
	if(self:Internal:Pending)
		set source to self:Internal.

	if(source:Mode:Mode = "Inertial") {
		pl("*", 11, 7).
		local tgtRot to NormalizeAngles(LOOKDIRUP(source:Mode:Target:FOREVECTOR, source:Mode:Target:UPVECTOR)).
		pr(tgtRot:PITCH, 28, 3).
		pr(tgtRot:YAW, 28, 4).
		pr(tgtRot:ROLL, 28, 5).
	}
	else if(source:Mode:Mode = "LVLH") {
		pl("*", 10, 8).
		local tgtRot to NormalizeAngles(LOOKDIRUP(source:Mode:Target:FOREVECTOR, source:Mode:Target:UPVECTOR)).
		pr(tgtRot:PITCH, 28, 3).
		pr(tgtRot:YAW, 28, 4).
		pr(tgtRot:ROLL, 28, 5).
	}
	else if(source:Mode:Mode = "Track") {
		if(source:Mode:Reference = "Position")
			pl("*", 9, 10).
		else
			pl("*", 9, 11).

		if(source:Mode:Target:Name = "Sun")
			pl("*", 23, 7).
		else if(source:Mode:Target:Name = "Earth")
			pl("*", 25, 8).
		else {
			pl("*", 23, 9).
			pr(self:Internal:TargetIndex, 30, 9, false).
		}
	}
}

FUNCTION UI_Manager_DapLayout_CopyDAPmode {
	parameter self.
	set self["Internal"]["Mode"] to DAP:Mode:Copy.
	set self["Internal"]["Pending"] to true.
}

FUNCTION UI_Manager_DapLayout_SetMode {
	parameter mode.
	parameter self.
	parameter arg.

	if(self:Internal:Pending = false)
		UI_Manager_DapLayout_CopyDAPmode(self).

	if(mode = "Inertial") {
		local shipBasis to LEXICON("z", ship:facing:forevector, "x", ship:facing:starvector, "y", ship:facing:upvector).
		local curRot to LOOKDIRUP(toIRF(shipBasis:z), toIRF(shipBasis:y)).
		set self["Internal"]["Mode"] to LEXICON(
			"Mode", "Inertial",
			"Target", curRot
		).
	}
	else if(mode = "LVLH") {
		local shipBasis to LEXICON("z", ship:facing:forevector, "x", ship:facing:starvector, "y", ship:facing:upvector).
		local lvlh to getLVLHfromR_DAP(UpdateOrbitParams(), -SHIP:BODY:POSITION).
		local curRot to LOOKDIRUP(VCMT(lvlh:Transform, shipBasis:z), VCMT(lvlh:Transform, shipBasis:y)).
		set self["Internal"]["Mode"] to LEXICON(
			"Mode", "LVLH",
			"Target", curRot
		).
	}
	else if(mode = "Position") {
		set self["Internal"]["Mode"] to LEXICON(
			"Mode", "Track",
			"Target", BODY("Earth"),
			"Reference", "Position"
		).
	}
	else if(mode = "Orientation") {
		set self["Internal"]["Mode"] to LEXICON(
			"Mode", "Track",
			"Target", BODY("Earth"),
			"Reference", "Orientation"
		).
	}

	return "".
}

FUNCTION UI_Manager_DapLayout_SetTarget {
	parameter type.
	parameter self.
	parameter arg to "-1".

	if(self:Internal:Pending <> true)
		UI_Manager_DapLayout_CopyDAPmode(self).

	if ((type = "P" or type = "Y" or type = "R") and (self:Internal:Mode:Mode = "Inertial" or self:Internal:Mode:Mode = "LVLH")) {
		local tgtRot to NormalizeAngles(self:Internal:Mode:Target).
		if(type = "P")
			set self["Internal"]["Mode"]["Target"] to DenormalizeAngles(R(arg:TONUMBER(0), tgtRot:YAW, tgtRot:ROLL)).
		else if(type = "Y")
			set self["Internal"]["Mode"]["Target"] to DenormalizeAngles(R(tgtRot:PITCH, arg:TONUMBER(0), tgtRot:ROLL)).
		else if(type = "R")
			set self["Internal"]["Mode"]["Target"] to DenormalizeAngles(R(tgtRot:PITCH, tgtRot:YAW, arg:TONUMBER(0))).
	}
	else if((type = "Earth" or type = "Sun" or type = "Custom") and self:Internal:Mode:Mode = "Track") {
		if(type = "Earth")
			set self["Internal"]["Mode"]["Target"] to BODY("Earth").
		else if(type = "Sun")
			set self["Internal"]["Mode"]["Target"] to BODY("Sun").
		else {
			if (DEFINED AvailableTargets and AvailableTargets:HASKEY(arg))
				set self["Internal"]["Mode"]["Target"] to AvailableTargets[arg].
				set self["Internal"]["TargetIndex"] to arg.
		}
	}


	return "".
}

FUNCTION UI_Manager_DapLayout_Reset {
	parameter self.
	parameter arg.

	set self["Internal"]["Pending"] to false.

	return "".
}

FUNCTION UI_Manager_DapLayout_Confirm {
	parameter self.
	parameter arg.

	if(self["Internal"]["Pending"] = true) {
		set DAP["Mode"] to self["Internal"]["Mode"]:Copy.
		set self["Internal"]["Pending"] to false.
	}
	return "".
}

FUNCTION UI_Manager_DapLayout_ToggleDAP {
	parameter key.
	parameter self.
	parameter arg.

	if(key = 1)
		DAP:Engage(DAP).
	else
		DAP:Disengage(DAP).

	return "".
}

FUNCTION UI_Manager_GetDapLayout {
	return LEXICON (
		"Init", UI_Manager_DapLayout_Init@,
		"Update", UI_Manager_DapLayout_Update@,
		"Internal", LEXICON(
			"Pending", false,
			"Mode", LEXICON(
				"Mode", "None",
				"Target", 0,
				"Reference", "None"
			),
			"TargetIndex", "-1"
		),
		"Items", LEXICON(
			"1", LEXICON("Action", UI_Manager_DapLayout_ToggleDAP@:BIND(1)),
			"2", LEXICON("Action", UI_Manager_DapLayout_ToggleDAP@:BIND(0)),
			"3", LEXICON("Action", UI_Manager_DapLayout_SetMode@:BIND("Inertial")),
			"4", LEXICON("Action", UI_Manager_DapLayout_SetMode@:BIND("LVLH")),
			"5", LEXICON("Action", UI_Manager_DapLayout_SetMode@:BIND("Position")),
			"6", LEXICON("Action", UI_Manager_DapLayout_SetMode@:BIND("Orientation")),
			"7", LEXICON("Action", UI_Manager_DapLayout_SetTarget@:BIND("P")),
			"8", LEXICON("Action", UI_Manager_DapLayout_SetTarget@:BIND("Y")),
			"9", LEXICON("Action", UI_Manager_DapLayout_SetTarget@:BIND("R")),
			"10", LEXICON("Action", UI_Manager_DapLayout_SetTarget@:BIND("Sun")),
			"11", LEXICON("Action", UI_Manager_DapLayout_SetTarget@:BIND("Earth")),
			"12", LEXICON("Action", UI_Manager_DapLayout_SetTarget@:BIND("Custom")),
			"13", LEXICON("Action", UI_Manager_DapLayout_Confirm@),
			"14", LEXICON("Action", UI_Manager_DapLayout_Reset@)
		)
	).
}
