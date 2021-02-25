@lazyglobal off.
Import(LIST("vectors", "maneuvers", "orbits")).

function GetDAP {
	return LEXICON(
		//methods
		"Init", DAP_Init@,
		"Engage", DAP_Engage@,
		"Disengage", DAP_Disengage@,
		"Update", DAP_Update@,
		"SetMode", DAP_SetMode@,
		"SetTarget", DAP_SetTarget@,
		"DAP_SetTarget", DAP_SetTarget@,

		//fields
		"Engaged", false,
		"ManualOverride", true,
		"Mode", LEXICON(
			"Mode", "Inertial"
		),
		"ReferenceAxis", "+X",
		"VelocityControl", 0,
		"ThrustOffset", LEXICON("pitch", 0, "yaw", 0),
		"Internal", LEXICON(
			"AlreadyInUpdate", false,
			"PrintDebugInfo", false
		),
		"Pitch", lexicon(
					"AngError", 0,
					"AngVelocity", 0,
					"VelocityPID", PIDLOOP(),
					"TorquePID", PIDLOOP()
					),
		"Yaw", lexicon(
					"AngError", 0,
					"AngVelocity", 0,
					"VelocityPID", PIDLOOP(),
					"TorquePID", PIDLOOP()
					),
		"Roll", lexicon(
					"AngError", 0,
					"AngVelocity", 0,
					"VelocityPID", PIDLOOP(),
					"TorquePID", PIDLOOP()
					)
	).
}

function DAP_Engage {
	parameter self.

	set self:Engaged to true.
	set self["Pitch"]["AngError"] to 0.
	set self["Pitch"]["AngVelocity"] to 0.
	set self["Yaw"]["AngError"] to 0.
	set self["Yaw"]["AngVelocity"] to 0.
	set self["Roll"]["AngError"] to 0.
	set self["Roll"]["AngVelocity"] to 0.
}

function DAP_Disengage {
	parameter self.
	set self:Engaged to false.
	set ship:control:neutralize to true.
}

function DAP_Init {
	parameter self.

	set self["Pitch"]["TorquePID"]:Kp to 1.8.
	set self["Pitch"]["TorquePID"]:Ki to 0.
	set self["Pitch"]["TorquePID"]:Kd to 0.4.
	set self["Pitch"]["TorquePID"]:maxoutput to 1.
	set self["Pitch"]["TorquePID"]:minoutput to -1.
	set self["Yaw"]["TorquePID"]:Kp to 1.8.
	set self["Yaw"]["TorquePID"]:Ki to 0.
	set self["Yaw"]["TorquePID"]:Kd to 0.4.
	set self["Yaw"]["TorquePID"]:maxoutput to 1.
	set self["Yaw"]["TorquePID"]:minoutput to -1.
	set self["Roll"]["TorquePID"]:Kp to 0.5.
	set self["Roll"]["TorquePID"]:Ki to 0.
	set self["Roll"]["TorquePID"]:Kd to 1.0.
	set self["Roll"]["TorquePID"]:maxoutput to 1.
	set self["Roll"]["TorquePID"]:minoutput to -1.
	set self["Pitch"]["VelocityPID"]:Kp to 0.2.
	set self["Pitch"]["VelocityPID"]:Ki to 0.
	set self["Pitch"]["VelocityPID"]:Kd to 0.5.
	set self["Pitch"]["VelocityPID"]:maxoutput to 2.
	set self["Pitch"]["VelocityPID"]:minoutput to -2.
	set self["Yaw"]["VelocityPID"]:Kp to 0.2.
	set self["Yaw"]["VelocityPID"]:Ki to 0.
	set self["Yaw"]["VelocityPID"]:Kd to 0.5.
	set self["Yaw"]["VelocityPID"]:maxoutput to 2.
	set self["Yaw"]["VelocityPID"]:minoutput to -2.
	set self["Roll"]["VelocityPID"]:Kp to 0.2.
	set self["Roll"]["VelocityPID"]:Ki to 0.
	set self["Roll"]["VelocityPID"]:Kd to 0.5.
	set self["Roll"]["VelocityPID"]:maxoutput to 2.
	set self["Roll"]["VelocityPID"]:minoutput to -2.
}

function DAP_SetTarget {
	parameter self.
	parameter type.
	parameter tgt.
	//wait until (self:Internal:AlreadyInUpdate = false).
	//set self:Internal:AlreadyInUpdate to true.
	if(type = "Attitude") {
		set self:Mode:Target to DenormalizeAngles(tgt).
	}
	else if(type = "Vector") {
		local vec_fwd to 0.
		local vec_up to 0.
		if(self:Mode:Mode = "Inertial") {
			set vec_fwd to toIRF(tgt).
			set vec_up to toIRF(v(1, 0, 0)).
		}
		else if(self:Mode:Mode = "LVLH") {
			local lvlh to getLVLHfromR_DAP(UpdateOrbitParams(), -SHIP:BODY:POSITION).
			set vec_fwd to VCMT(lvlh:Transform, tgt).
			set vec_up to lvlh:basis:x.
		}
		local tgtDir to LOOKDIRUP(vec_fwd, vec_up).
		set self:Mode:Target to tgtDir.
	}
	//set self:Internal:AlreadyInUpdate to false.
}

function DAP_SetMode {
	declare parameter self.
	declare parameter mode to "Inertial".
	declare parameter arg to 0.
	if(mode = "Inertial") {
		set self["Mode"] to LEXICON(
			"Mode", "Inertial"
		).
		set self:ManualOverride to true.
	}
	else if(mode = "LVLH") {
		set self["Mode"] to LEXICON(
			"Mode", "LVLH"
		).
		set self:ManualOverride to true.
	}
	else if(mode = "Track") {
		set self["Mode"] to LEXICON(
			"Mode", "Track",
			"Target", arg:Target,
			"Reference", arg:Reference
		).
	}
	else {
		set self["Mode"] to LEXICON(
			"Mode", "Inertial"
		).
		set self:ManualOverride to true.
	}
}

function DAP_SetThrustOffset {
	parameter offset to LEXICON("pitch", 0, "yaw", 0).
	set self["ThrustOffset"] to offset.
}

function DAP_UpdateAttitude {
	parameter self.

	local shipBasis to LEXICON("z", ship:facing:forevector, "x", ship:facing:starvector, "y", ship:facing:upvector).


	if(not self:ManualOverride) {
		local raw_fore to 0.
		local raw_up to 0.

		clearscreen.
		print self:Mode:Target at (0, 1).

		if(self:Mode:Mode = "Inertial") {
			set raw_fore to fromIRF(self:Mode:Target:forevector).
			set raw_up to fromIRF(self:Mode:Target:upvector).
		}
		else if(self:Mode:Mode = "LVLH") {
			local lvlh to getLVLHfromR_DAP(UpdateOrbitParams(), -SHIP:BODY:POSITION).
			set raw_fore to VCMT(lvlh:Inverse, self:Mode:Target:forevector).
			set raw_up to -SHIP:BODY:POSITION:NORMALIZED.
		}

		vecdraw(v(0, 0, 0), raw_fore*10, rgb(0, 0, 1), "tgt_fore", 1.0, true, 0.2, true, true).
		vecdraw(v(0, 0, 0), raw_up*10, rgb(0, 0, 1), "tgt_up", 1.0, true, 0.2, true, true).

		local pitch to 90 - VANG(shipBasis:y, raw_fore - shipBasis:x * cos(vang(raw_fore, shipBasis:x))).
		local yaw to 90 - VANG(shipBasis:x, raw_fore - shipBasis:y * cos(vang(raw_fore, shipBasis:y))).
		local roll to 0.

		print pitch at (0, 3).
		print yaw at (0, 4).
		print roll at (0, 5).

		if(vang(raw_fore, shipBasis:z) < 45) {
			set roll to 90 - VANG(shipBasis:x, raw_up - shipBasis:z * cos(vang(raw_up, shipBasis:z))).
		}

		//------------------------------------------------------------------------------------------------------Delta Roll Update
		local rollAngErr to -roll.
		set self["Roll"]["AngError"] to rollAngErr.
		//------------------------------------------------------------------------------------------------------Delta Pitch Update
		local pitchAngErr to -pitch.
		set pitchAngErr to pitchAngErr + self:ThrustOffset:pitch.
		set self["Pitch"]["AngError"]  to pitchAngErr.
		//------------------------------------------------------------------------------------------------------Delta Yaw Update
		local yawAngErr to -yaw.
		set yawAngErr to yawAngErr + self:ThrustOffset:yaw.
		set self["Yaw"]["AngError"]  to yawAngErr.
	}

	set self["Yaw"]["AngVelocity"] to VDOT(shipBasis:y, SHIP:ANGULARVEL)*180/CONSTANT:PI.
	set self["Pitch"]["AngVelocity"] to -VDOT(shipBasis:x, SHIP:ANGULARVEL)*180/CONSTANT:PI.
	set self["Roll"]["AngVelocity"] to -VDOT(shipBasis:z, SHIP:ANGULARVEL)*180/CONSTANT:PI.
}

local prevTime to 0.
function DAP_Update {
	parameter self.
	set prevTime to TIME:SECONDS.
	if (self:Engaged AND self:Internal:AlreadyInUpdate = false) {
		set self:Internal:AlreadyInUpdate to true.
		if(SHIP:CONTROL:PILOTNEUTRAL) {
			if(self:ManualOverride) {
				set self:ManualOverride to false.
				if(self:Mode:Mode = "Track") {
					set self:Mode to LEXICON("Mode", "Inertial").
				}
				if(self:Mode:Mode = "Inertial") {
					local shipBasis to LEXICON("z", ship:facing:forevector, "x", ship:facing:starvector, "y", ship:facing:upvector).
					local curRot to LOOKDIRUP(toIRF(shipBasis:z), toIRF(shipBasis:y)).
					//set curRot to NormalizeAngles(curRot).
					set self:Mode:Target to curRot.
				}
				else if(self:Mode:Mode = "LVLH") {
					local shipBasis to LEXICON("z", ship:facing:forevector, "x", ship:facing:starvector, "y", ship:facing:upvector).
					local lvlh to getLVLHfromR_DAP(UpdateOrbitParams(), -SHIP:BODY:POSITION).
					local curRot to LOOKDIRUP(VCMT(lvlh:Transform, shipBasis:z), VCMT(lvlh:Transform, shipBasis:y)).
					//set curRot to NormalizeAngles(curRot).

					set self:Mode:Target to curRot.
				}
			}
			DAP_UpdateAttitude(self).

			//---------------------------------------------------------------------Pitch update
			set self["Pitch"]["VelocityPID"]:setpoint to 0.
			local desiredPitchAngVel to self["Pitch"]["VelocityPID"]:update(time:seconds, self["Pitch"]["AngError"]).
			set self["Pitch"]["TorquePID"]:setpoint to desiredPitchAngVel.
			local desiredPitchColumnStick to self["Pitch"]["TorquePID"]:update(time:seconds, self["Pitch"]["AngVelocity"]).
			//---------------------------------------------------------------------Yaw update
			set self["Yaw"]["VelocityPID"]:setpoint to 0.
			local desiredYawAngVel to self["Yaw"]["VelocityPID"]:update(time:seconds, self["Yaw"]["AngError"]).
			set self["Yaw"]["TorquePID"]:setpoint to desiredYawAngVel.
			local desiredYawColumnStick to self["Yaw"]["TorquePID"]:update(time:seconds, self["Yaw"]["AngVelocity"]).
			//---------------------------------------------------------------------Roll update
			set self["Roll"]["VelocityPID"]:setpoint to 0.
			local desiredRollAngVel to self["Roll"]["VelocityPID"]:update(time:seconds, self["Roll"]["AngError"]).
			set self["Roll"]["TorquePID"]:setpoint to desiredRollAngVel.
			local desiredRollColumnStick to self["Roll"]["TorquePID"]:update(time:seconds, self["Roll"]["AngVelocity"]).
			//---------------------------------------------------------------------Control update
			local columnStick to ship:control.
			set columnStick:pitch to desiredPitchColumnStick.
			set columnStick:yaw to desiredYawColumnStick.
			set columnStick:roll to desiredRollColumnStick.

			//clearscreen.
			// print "pitch angErr: " +  self["Pitch"]["AngError"] at (0, 0).
			// print "des pitch ang vel: " + desiredPitchAngVel at (0, 1).
			// print "pith ang vel: " + self["Pitch"]["AngVelocity"] at (0, 2).
			//
			// print "yaw angErr: " +  self["Yaw"]["AngError"] at (0, 4).
			// print "des yaw ang vel: " + desiredYawAngVel at (0, 5).
			// print "yaw ang vel: " + self["Yaw"]["AngVelocity"] at (0, 6).
			//
			// print "roll angErr: " +  self["Roll"]["AngError"] at (0, 8).
			// print "des roll ang vel: " + desiredRollAngVel at (0, 9).
			// print "roll ang vel: " + self["Roll"]["AngVelocity"] at (0, 10).

		}
		else {
			set self:ManualOverride to true.

			DAP_UpdateAttitude(self).

			local rotVec to ship:control:pilotrotation.

			set self["Pitch"]["TorquePID"]:setpoint to rotVec:Y.
			local desiredPitchColumnStick to self["Pitch"]["TorquePID"]:update(time:seconds, self["Pitch"]["AngVelocity"]).

			set self["Yaw"]["TorquePID"]:setpoint to rotVec:X.
			local desiredYawColumnStick to self["Yaw"]["TorquePID"]:update(time:seconds, self["Yaw"]["AngVelocity"]).

			set self["Roll"]["TorquePID"]:setpoint to rotVec:Z.
			local desiredRollColumnStick to self["Roll"]["TorquePID"]:update(time:seconds, self["Roll"]["AngVelocity"]).

			local columnStick to ship:control.
			set columnStick:pitch to desiredPitchColumnStick.
			set columnStick:yaw to desiredYawColumnStick.
			set columnStick:roll to desiredRollColumnStick.
		}

		set self:Internal:AlreadyInUpdate to false.
	}
	print TIME:SECONDS - prevTime at (0, 0).
}
