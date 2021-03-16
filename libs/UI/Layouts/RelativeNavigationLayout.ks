FUNCTION UI_Manager_RelNavLayout_Init {
    parameter self.

    print "|                                                          |".	//0
	print "|----------------------------------------------------------|".	//1
	print "|                                                          |".	//2
	print "| 1 Tgt Sel    |                  | 2 Pred time          s |".	//3
	print "|                                                          |".	//4
	print "|     Cur LVLH           Pred LVLH           Tgt LVLH      |".	//5
	print "| X              m | X               m | 3 X             m |".	//6
	print "| Y              m | Y               m | 4 Y             m |".	//7
	print "| Z              m | Z               m | 5 Z             m |".	//8
	print "| Xdot         m/s | Xdot          m/s | Xdot          m/s |".	//9
	print "| Ydot         m/s | Ydot          m/s | Ydot          m/s |".	//10
	print "| Zdot         m/s | Zdot          m/s | Zdot          m/s |".	//11
	print "|      Cur Rel                                  Mnvr       |".	//12
	print "| R              m | Mnvr type:        | ΔVx           m/s |".	//13
	print "| Rdot         m/s |         6 Single  | ΔVy           m/s |".	//14
	print "| El           deg |         7   Cont  | ΔVz           m/s |".	//15
	print "| Az           deg | 8 Kill rel vel      9 Exec / 10 Warp  |".	//16
	print "|                                            11 Abort      |".	//17

	//    0123456789 123456789 123456789 123456789 123456789 123456789

	pc("Relative Navigation", 0).
	if(self:Internal:Target:Target <> 0) {
		set self["Data"]["FutureState"] to CWequationFutureFromCurrent(SHIP, self:Internal:Target:Target, 0, self:Internal:PredictionTime - TIME:SECONDS).
	}
	if(self:Internal:TargetPos:IsActive = true and self:Internal:PredictionTime - TIME:SECONDS > 0) {
		set self["Data"]["FutureTargetState"] to CWequationCurrentVelFromFuturePos(
			SHIP,
			self:Internal:Target:Target,
			v(self:Internal:TargetPos:X, self:Internal:TargetPos:Y, self:Internal:TargetPos:Z),
			0,
			self:Internal:PredictionTime - TIME:SECONDS
		).
	}
}

FUNCTION UI_Manager_RelNavLayout_Update {
	parameter self.

	if(RendezvousManagerTelemetry:Status <> "Inactive")
		pl("*", 47, 16).

	if(self:Internal:Target:Target <> 0 and self["Data"]["FutureState"] <> 0) {

		pr(self:Internal:Target:Index, 14, 3, false).

		local curState to self["Data"]["FutureState"].

		pr(curState:LVLHrelativePosition:X, 16, 6).
		pr(curState:LVLHrelativePosition:Y, 16, 7).
		pr(curState:LVLHrelativePosition:Z, 16, 8).

		pr(curState:LVLHrelativeVelocity:X, 14, 9).
		pr(curState:LVLHrelativeVelocity:Y, 14, 10).
		pr(curState:LVLHrelativeVelocity:Z, 14, 11).

		local relPos to SHIP:POSITION - self:Internal:Target:Target:POSITION.
		local relVel to SHIP:VELOCITY:ORBIT  - self:Internal:Target:Target:VELOCITY:ORBIT.

		pr(relPos:MAG, 16, 13).
		pr(relVel:MAG, 14, 14).

		if(self:Internal:ManeuverType = "Single")
			pr("*", 38, 14).
		else
			pr("*", 38, 15).

		if(self:Internal:PredictionTime - TIME:SECONDS > 0) {
			pr(self:Internal:PredictionTime - TIME:SECONDS, 56, 3).
			//local tgtPos to v(self:Internal:TargetPos:X, self:Internal:TargetPos:Y, self:Internal:TargetPos:Z).
			local futState to self["Data"]["FutureState"].

			pr(futState:LVLHrelativePositionFinal:X, 36, 6).
			pr(futState:LVLHrelativePositionFinal:Y, 36, 7).
			pr(futState:LVLHrelativePositionFinal:Z, 36, 8).

			if(self:Internal:TargetPos:IsActive = true and self:Data:FutureTargetState <> 0) {
				pr(self:Internal:TargetPos:X, 56, 6).
				pr(self:Internal:TargetPos:Y, 56, 7).
				pr(self:Internal:TargetPos:Z, 56, 8).

				local dV to (self:Data:FutureTargetState:targetLVLHrelativeVelocity - self:Data:FutureTargetState:LVLHrelativeVelocity).
				pr(dV:X, 54, 13).
				pr(dV:Y, 54, 14).
				pr(dV:Z, 54, 15).
			}

			// pr(curState:LVLHrelativeVelocity:X, 34, 9).
			// pr(curState:LVLHrelativeVelocity:Y, 34, 10).
			// pr(curState:LVLHrelativeVelocity:Z, 34, 11).
		}
	}

}

FUNCTION UI_Manager_RelNavLayout_SetTarget {
	parameter self.
	parameter arg.

	if(not (DEFINED AvailableTargets))
		return "ERR: NO TGTS EXISTS".
	if(not AvailableTargets:HASKEY(arg)) {
		set self["Internal"]["Target"]["Index"] TO -1.
		set self["Internal"]["Target"]["Target"] TO 0.
		set self["Internal"]["PredictionTime"] to 0.
		return "ERR: TGT NOT FOUND".
	}
	set self["Internal"]["Target"]["Target"] TO AvailableTargets[arg].
	set self["Internal"]["Target"]["Index"] TO arg.

	return "".
}

FUNCTION UI_Manager_RelNavLayout_SetPredictionTime {
	parameter self.
	parameter arg.

	set self["Internal"]["PredictionTime"] to arg:TONUMBER(0) + TIME:SECONDS.

	return "".
}

FUNCTION UI_Manager_RelNavLayout_SetTargetPos {
	parameter type.
	parameter self.
	parameter arg.

	set self["Internal"]["TargetPos"][type] to arg:TONUMBER(0).

	if(self["Internal"]["TargetPos"]:X = 0 and self["Internal"]["TargetPos"]:Y = 0 and self["Internal"]["TargetPos"]:Z = 0)
		set self["Internal"]["TargetPos"]["IsActive"] to false.
	else
		set self["Internal"]["TargetPos"]["IsActive"] to true.
	return "".
}

FUNCTION UI_Manager_RelNavLayout_SetManeuverType {
	parameter type.
	parameter self.
	parameter arg.

	if(type = 0) {
		set self["Internal"]["ManeuverType"] to "Single".
	}
	else if(type = 1) {
		set self["Internal"]["ManeuverType"] to "Cont".
	}

	return "".
}

FUNCTION UI_Manager_RelNavLayout_ExecBurn {
	parameter self.
	parameter arg.

	if(self:Internal:PredictionTime - TIME:SECONDS < 0)
		return "ERR: NO TGT POS".
	else if(self:Internal:Target:Target = 0)
		return "ERR: NO TGT SPECIFIED".

	local tgtPos to v(self:Internal:TargetPos:X, self:Internal:TargetPos:Y, self:Internal:TargetPos:Z).
	local ops to RendezvousManagerOpsClass:COPY.
	set ops:Mode to "Manual".
	set ops:TargetShip to self:Internal:Target:Target.
	set ops:Warp to false.

	local leg to RendezvousManagerLegClass:COPY.
	set leg:TargetPosition to tgtPos.
	set leg:arrivalTime to self:Internal:PredictionTime.
	if(self:Internal:ManeuverType = "Cont")
		set leg:Continuous to true.

	ops["Legs"]:PUSH(leg).

	TaskQueue:PUSH(
		LEXICON(
			"Type", "CW_Burn",
			"Ops", ops
		)
	).

	return "".
}

FUNCTION UI_Manager_RelNavLayout_KillRelVel {
	parameter self.
	parameter arg.

	TaskQueue:PUSH(
		LEXICON(
			"Type", "killRelVel",
			"targetShip", self:Internal:Target:Target
		)
	).

	return "".
}

FUNCTION UI_Manager_RelNavLayout_Warp {
	parameter self.
	parameter arg.

	if(arg = "none")
		set arg to 1.
	else
		set arg to arg:TONUMBER(1).

	if(self:Internal:PredictionTime - TIME:SECONDS > 0) {
		KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + (self:Internal:PredictionTime - TIME:SECONDS)/arg - 20).
	}

	return "".
}

FUNCTION UI_Manager_RelNavLayout_Abort {
	parameter self.
	parameter arg.

	if(RendezvousManagerTelemetry:Status <> "Inactive")
		set RendezvousManagerTelemetry:Abort to true.

	return "".
}

FUNCTION UI_Manager_GetRelNavLayout {
	return LEXICON(
		"Init", UI_Manager_RelNavLayout_Init@,
		"Update", UI_Manager_RelNavLayout_Update@,
		"Internal", LEXICON(
			"Target", LEXICON(
				"Target", 0,
				"Index", "-1"
			),
			"TargetPos", LEXICON(
				"X", 0,
				"Y", 0,
				"Z", 0,
				"IsActive", false
			),
			"PredictionTime", 0,
			"ManeuverType", "Single"
		),
		"Data", LEXICON(
			"FutureState", 0,
			"FutureTargetState", 0
		),
		"Items", LEXICON(
			"1", LEXICON("Action", UI_Manager_RelNavLayout_SetTarget@),
			"2", LEXICON("Action", UI_Manager_RelNavLayout_SetPredictionTime@),
			"3", LEXICON("Action", UI_Manager_RelNavLayout_SetTargetPos@:BIND("X")),
			"4", LEXICON("Action", UI_Manager_RelNavLayout_SetTargetPos@:BIND("Y")),
			"5", LEXICON("Action", UI_Manager_RelNavLayout_SetTargetPos@:BIND("Z")),
			"6", LEXICON("Action", UI_Manager_RelNavLayout_SetManeuverType@:BIND(0)),
			"7", LEXICON("Action", UI_Manager_RelNavLayout_SetManeuverType@:BIND(1)),
			"8", LEXICON("Action", UI_Manager_RelNavLayout_KillRelVel@),
			"9", LEXICON("Action", UI_Manager_RelNavLayout_ExecBurn@),
			"10", LEXICON("Action", UI_Manager_RelNavLayout_Warp@),
			"11", LEXICON("Action", UI_Manager_RelNavLayout_Abort@)
		)
	).
}
