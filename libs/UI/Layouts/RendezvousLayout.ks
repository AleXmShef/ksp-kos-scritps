FUNCTION UI_Manager_RendezvousLayout_Init {
	declare parameter self.
    print "|                                                          |".	//0
	print "|----------------------------------------------------------|".	//1
	print "|                                                          |".	//2
	print "|                                      | 5 Compute T1      |".	//3
	print "|------------------.                   | 6 Store T1        |".	//4
	print "|        T1        | 1 Tgt Sel         |                   |".	//5
	print "| Tig            s | Tgt Pos LVLH      | 7 Compute T2      |".	//6
	print "| ΔVx          m/s |      2 X          | 8 Store T2        |".	//7
	print "| ΔVy          m/s |      3 Y          |-------------------|".	//8
	print "| ΔVz          m/s |                   | 4 Warp          s |".	//9
	print "|                  |-------------------|-------------------|".	//10
	print "|        T2        | Phi           deg |     Tgt State     |".	//11
	print "| Tig            s | dPhi        deg/s | X               m |".	//12
	print "| ΔVx          m/s | ΔH              m | Y               m |".	//13
	print "| ΔVy          m/s |                   | Z               m |".	//14
	print "| ΔVz          m/s |                   | Xdot          m/s |".	//15
	print "|                                      | Ydot          m/s |".	//16
	print "|                                      | Zdot          m/s |".	//17

	//    0123456789 123456789 123456789 123456789 123456789 123456789
	//              1         2         3         4         5         6

	pc("Rendezvous Planning", 0).


}

FUNCTION UI_Manager_RendezvousLayout_Update {
	parameter self.

	pr(self:Internal:Target:Name, 38, 5).
	pr(self:Internal:TargetPos:X, 38, 7).
	pr(self:Internal:TargetPos:Y, 38, 8).

	if(self:Internal:Target:Name <> "None") {
		pr(self:Internal:Relative:Phi, 34, 11).
		pr(self:Internal:Relative:dPhi, 32, 12).
		pr(self:Internal:Relative:dH, 36, 13).

		local posVec to toIRF(self:Internal:Target:POSITION - SHIP:BODY:POSITION).
		local velVec to toIRF(self:Internal:Target:VELOCITY:ORBIT).

		pr(posVec:X, 56, 12).
		pr(posVec:Y, 56, 13).
		pr(posVec:Z, 56, 14).

		pr(velVec:X, 54, 15).
		pr(velVec:Y, 54, 16).
		pr(velVec:Z, 54, 17).
	}

	if(self:Internal:T1_Burn:Tig > 0) {
		pr(self:Internal:T1_Burn:Tig - TIME:SECONDS, 16, 6).
		pr(self:Internal:T1_Burn:X, 16, 7).
		pr(self:Internal:T1_Burn:Y, 14, 8).
		pr(self:Internal:T1_Burn:Z, 14, 9).
	}

	if(self:Internal:T2_Burn:Tig > 0) {
		pr(self:Internal:T2_Burn:Tig - TIME:SECONDS, 16, 12).
		pr(self:Internal:T2_Burn:X, 16, 13).
		pr(self:Internal:T2_Burn:Y, 14, 14).
		pr(self:Internal:T2_Burn:Z, 14, 15).
	}
	if(self:Internal:TooFar:IsTrue) {
		pr(self:Internal:TooFar:WarpTime - TIME:SECONDS, 56, 9).
	}

	if(self:Internal:Target:Name <> "None") {
		LOCAL chaserAbsoluteTrueAnomaly IS SHIP:ORBIT:TRUEANOMALY + SHIP:ORBIT:ARGUMENTOFPERIAPSIS.
		IF (chaserAbsoluteTrueAnomaly > 360) {
			UNTIL (chaserAbsoluteTrueAnomaly < 360)
				SET chaserAbsoluteTrueAnomaly TO chaserAbsoluteTrueAnomaly -360.
		}

		LOCAL targetAbsoluteTrueAnomaly IS self:Internal:Target:ORBIT:TRUEANOMALY + self:Internal:Target:ORBIT:ARGUMENTOFPERIAPSIS.
		IF (targetAbsoluteTrueAnomaly > 360) {
			UNTIL (targetAbsoluteTrueAnomaly < 360)
				SET targetAbsoluteTrueAnomaly TO targetAbsoluteTrueAnomaly -360.
		}

		LOCAL currentPhasingAngle IS targetAbsoluteTrueAnomaly - chaserAbsoluteTrueAnomaly.
		IF (currentPhasingAngle < 0)
			SET currentPhasingAngle TO 360 + currentPhasingAngle.

		LOCAL chaserAverageAngularVelocity IS 360/SHIP:ORBIT:PERIOD.
		LOCAL targetAverageAngularVelocity IS 360/self:Internal:Target:ORBIT:PERIOD.

		LOCAL averageRelativeAngularVelocity IS chaserAverageAngularVelocity - targetAverageAngularVelocity.

		set self:Internal:Relative to LEXICON(
			"Phi", currentPhasingAngle,
			"dPhi", averageRelativeAngularVelocity,
			"dH", SHIP:ORBIT:APOAPSIS - self:Internal:Target:ORBIT:APOAPSIS
		).
	}
}

FUNCTION UI_Manager_RendezvousLayout_SetTarget {
	parameter self.
	parameter arg.

	if(not (DEFINED AvailableTargets))
		return "ERR: NO TGTS EXISTS".
	if(not AvailableTargets:HASKEY(arg)) {
		set self["Internal"]["Target"] TO LEXICON("Name", "None").
		return "ERR: TGT NOT FOUND".
	}
	set self:Internal:Target TO AvailableTargets[arg].
	return "".
}

FUNCTION UI_Manager_RendezvousLayout_SetTargetPos {
	parameter type.
	parameter self.
	parameter arg.

	set self["Internal"]["TargetPos"][type] to arg:TONUMBER(0).
	return "".
}

FUNCTION UI_Manager_RendezvousLayout_Warp {
	parameter self.
	parameter arg.

	if(self:Internal:TooFar:IsTrue) {
		KUNIVERSE:TIMEWARP:WARPTO(self:Internal:TooFar:WarpTime).
		set self:Internal:TooFar TO LEXICON(
			"IsTrue", false,
			"WarpTime", 0
		).
	}
	else
		return "ERR: NO WARP TGT".

	return "".
}

FUNCTION UI_Manager_RendezvousLayout_ComputeT1 {
	parameter self.
	parameter arg.
	if(self:Internal:Target:Name = "None")
		return "ERR: NO TGT SELECTED".
	if(ship:ORBIT:ECCENTRICITY > 0.002 or self:Internal:Target:ORBIT:ECCENTRICITY > 0.002)
		return "ERR: HIGH ECC OBT".

	local burn to RendezvousTransfer(
		UpdateOrbitParams(),
		UpdateOrbitParams(self:Internal:Target:ORBIT),
		self:Internal:TargetPos:Y,
		self:Internal:TargetPos:X,
		SHIP:ORBIT:TRUEANOMALY,
		self:Internal:Target:ORBIT:TRUEANOMALY
	).

	if(burn:node = "none") {
		set self["Internal"]["TooFar"] to LEXICON(
			"IsTrue", true,
			"WarpTime", burn:warpTime
		).
		return "ERR: Tig OUT OF RNG".
	}
	else {
		local dV to burn:dV.
		local depTime to burn:depTime.

		local dvIRF to toIRF(dV).
		set self:Internal:T1_Burn TO LEXICON(
			"X", dvIRF:X,
			"Y", dvIRF:Y,
			"Z", dvIRF:Z,
			"dV", dV,
			"Tig", depTime
		).
	}

	return "".
}

FUNCTION UI_Manager_RendezvousLayout_ComputeT2 {
	parameter self.
	parameter arg.

	if(self:Internal:Target:Name = "None")
		return "ERR: NO TGT SELECTED".

	//if(self:Internal:Target:ORBIT:Apoapsis - SHIP:ORBIT:APOAPSIS > self:Internal:TargetPos:X)
		//return "ERR: CUR OBT OUT OF RCH".

	local curOrb to UpdateOrbitParams().
	local tgtOrb to curOrb:COPY.
	set tgtOrb:Ap to (self:Internal:Target:Apoapsis + Globals:R) - self:Internal:TargetPos:X.
	set tgtOrb:pe to tgtOrb:Ap - 100.
	set tgtOrb to BuildOrbit(tgtOrb).

	local burn to OrbitTransfer(curOrb, tgtOrb).
	if(burn:result = 0)
		return "ERR: FAILED TO COMPUTE".

	local dV to burn:dV.
	local depTime to burn:depTime.

	local dvIRF to toIRF(dV).
	set self["Internal"]["T2_Burn"] TO LEXICON(
		"X", dvIRF:X,
		"Y", dvIRF:Y,
		"Z", dvIRF:Z,
		"dV", dV,
		"Tig", depTime
	).

	return "".
}

FUNCTION UI_Manager_RendezvousLayout_StoreT1 {
	parameter self.
	parameter arg.

	if(self:Internal:T1_Burn:Tig <= 0)
		return "ERR: NOT COMPUTED".
	if(not (DEFINED ComputedBurnStorage))
		return "ERR: NO STORAGE".
	set ComputedBurnStorage TO LEXICON(
		"Tig", self:Internal:T1_Burn:Tig,
		"dV", self:Internal:T1_Burn:dV
	).

	return "".
}

FUNCTION UI_Manager_RendezvousLayout_StoreT2 {
	parameter self.
	parameter arg.

	if(self:Internal:T2_Burn:Tig <= 0)
		return "ERR: NOT COMPUTED".
	if(not (DEFINED ComputedBurnStorage))
		return "ERR: NO STORAGE".
	set ComputedBurnStorage TO LEXICON(
		"Tig", self:Internal:T2_Burn:Tig,
		"dV", self:Internal:T2_Burn:dV
	).

	return "".
}

FUNCTION UI_Manager_GetRendezvousLayout {
	return LEXICON (
		"Init", UI_Manager_RendezvousLayout_Init@,
		"Update", UI_Manager_RendezvousLayout_Update@,
		"Internal", LEXICON(
			"TooFar", LEXICON(
				"IsTrue", false,
				"WarpTime", 0
			),
			"T1_Burn", LEXICON(
				"X", 0,
				"Y", 0,
				"Z", 0,
				"dV", v(0, 0, 0),
				"Tig", 0
			),
			"T2_Burn", LEXICON(
				"X", 0,
				"Y", 0,
				"Z", 0,
				"dV", v(0, 0, 0),
				"Tig", 0
			),
			"TargetPos", LEXICON(
				"X", 0,
				"Y", 0,
				"Z", 0
			),
			"Relative", LEXICON(
				"Phi", 0,
				"dPhi", 0,
				"dH", 0
			),
			"Target", LEXICON("Name", "None")
		),
		"Items", LEXICON(
			"1", LEXICON("Action", UI_Manager_RendezvousLayout_SetTarget@),
			"2", LEXICON("Action", UI_Manager_RendezvousLayout_SetTargetPos@:BIND("X")),
			"3", LEXICON("Action", UI_Manager_RendezvousLayout_SetTargetPos@:BIND("Y")),
			"4", LEXICON("Action", UI_Manager_RendezvousLayout_Warp@),
			"5", LEXICON("Action", UI_Manager_RendezvousLayout_ComputeT1@),
			"6", LEXICON("Action", UI_Manager_RendezvousLayout_StoreT1@),
			"7", LEXICON("Action", UI_Manager_RendezvousLayout_ComputeT2@),
			"8", LEXICON("Action", UI_Manager_RendezvousLayout_StoreT2@)
		)
	).
}
