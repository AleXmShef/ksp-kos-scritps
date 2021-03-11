@lazyglobal off.
set config:ipu to 2000.

function GetAtmosphericDAP {
	return LEXICON(
		//methods
		"Init", DAPa_Init@,
		"Engage", DAPa_Engage@,
		"Disengage", DAPa_Disengage@,
		"Update", DAPa_Update@,
		"Target", LEXICON(
			"Pitch", 0,
			"Roll", 0
		),
		"ManualOverride", true,
		//fields
		"Engaged", false,
		"Internal", LEXICON(
			"AlreadyInUpdate", false,
			"PrintDebugInfo", false,
			"UpdateTime", 0
		),
		"Pitch", lexicon(
					"Ang", 0,
					"AngError", 0,
					"AngVelocity", 0,
					"AngAcceleration", 0,
					"VelocityPID", PIDLOOP(),
					"TorquePID", PIDLOOP(),
					"DeflectionPID", PIDLOOP()
					),
		"Roll", lexicon(
					"Ang", 0,
					"AngError", 0,
					"AngVelocity", 0,
					"AngAcceleration", 0,
					"VelocityPID", PIDLOOP(),
					"TorquePID", PIDLOOP(),
					"DeflectionPID", PIDLOOP()
					)
	).
}

function DAPa_Engage {
	parameter self.

	set self:Engaged to true.
	set self["Pitch"]["AngError"] to 0.
	set self["Pitch"]["AngVelocity"] to 0.
	set self["Pitch"]["AngAcceleration"] to 0.

	set self["Roll"]["AngError"] to 0.
	set self["Roll"]["AngAcceleration"] to 0.
	set self["Roll"]["AngVelocity"] to 0.

	set self["Internal"]["UpdateTime"] to TIME:SECONDS - 1.
	DAPa_UpdateAttitude(self).
	wait 0.
}

function DAPa_Disengage {
	parameter self.
	set self:Engaged to false.
	set ship:control:neutralize to true.
}

function DAPa_Init {
	parameter self.
	set self["Pitch"]["VelocityPID"]:Kp to 0.2.
	set self["Pitch"]["VelocityPID"]:Ki to 0.
	set self["Pitch"]["VelocityPID"]:Kd to 0.5.
	set self["Pitch"]["VelocityPID"]:maxoutput to 2.
	set self["Pitch"]["VelocityPID"]:minoutput to -2.
	set self["Roll"]["VelocityPID"]:Kp to 0.2.
	set self["Roll"]["VelocityPID"]:Ki to 0.
	set self["Roll"]["VelocityPID"]:Kd to 0.5.
	set self["Roll"]["VelocityPID"]:maxoutput to 2.
	set self["Roll"]["VelocityPID"]:minoutput to -2.

	set self["Pitch"]["TorquePID"]:Kp to 1.8.
	set self["Pitch"]["TorquePID"]:Ki to 0.
	set self["Pitch"]["TorquePID"]:Kd to 0.4.
	set self["Pitch"]["TorquePID"]:maxoutput to 2.
	set self["Pitch"]["TorquePID"]:minoutput to -2.
	set self["Roll"]["TorquePID"]:Kp to 1.8.
	set self["Roll"]["TorquePID"]:Ki to 0.
	set self["Roll"]["TorquePID"]:Kd to 0.4.
	set self["Roll"]["TorquePID"]:maxoutput to 2.
	set self["Roll"]["TorquePID"]:minoutput to -2.

	set self["Pitch"]["DeflectionPID"]:Kp to 0.05.
	set self["Pitch"]["DeflectionPID"]:Ki to 0.
	set self["Pitch"]["DeflectionPID"]:Kd to 0.01.
	set self["Pitch"]["DeflectionPID"]:maxoutput to 0.1.
	set self["Pitch"]["DeflectionPID"]:minoutput to -0.1.
	set self["Roll"]["DeflectionPID"]:Kp to 0.2.
	set self["Roll"]["DeflectionPID"]:Ki to 0.
	set self["Roll"]["DeflectionPID"]:Kd to 0.01.
	set self["Roll"]["DeflectionPID"]:maxoutput to 0.1.
	set self["Roll"]["DeflectionPID"]:minoutput to -0.1.
}

function DAPa_UpdateAttitude {
	parameter self.

	local up_vector to UP:FOREVECTOR.
	local ship_vector to SHIP:FACING:FOREVECTOR.
	local ship_upvector to SHIP:FACING:UPVECTOR.
	local ship_starvector to SHIP:FACING:STARVECTOR.

	local star_vector to VCRS(up_vector, ship_vector).
	local horizon_vector to VCRS(up_vector, star_vector).

	local pitch to 90 - vang(ship_vector, up_vector).
	local roll to 90 - VANG(ship_starvector, up_vector - ship_vector * cos(vang(up_vector, ship_vector))).

	set self["Pitch"]["Ang"] to pitch.
	set self["Roll"]["Ang"] to -roll.

	if(self:ManualOverride = false) {
		set self["Pitch"]["AngError"] to self["Target"]["Pitch"] - self["Pitch"]["Ang"].
		set self["Roll"]["AngError"] to self["Target"]["Roll"] - self["Roll"]["Ang"].
	}
}

function DAPa_UpdateAttitudeRates {
	parameter self.

	local prevPitch to self["Pitch"]["Ang"].
	local prevRoll to self["Roll"]["Ang"].
	local prevPitchAngVel to self["Pitch"]["AngVelocity"].
	local prevRollAngVel to self["Roll"]["AngVelocity"].

	DAPa_UpdateAttitude(self).

	set self["Pitch"]["AngVelocity"] to (self["Pitch"]["Ang"] - prevPitch)/(TIME:SECONDS - self["Internal"]["UpdateTime"]).
	set self["Roll"]["AngVelocity"] to (self["Roll"]["Ang"] - prevRoll)/(TIME:SECONDS - self["Internal"]["UpdateTime"]).

	set self["Pitch"]["AngAcceleration"] to (self["Pitch"]["AngVelocity"] - prevPitchAngVel)/(TIME:SECONDS - self["Internal"]["UpdateTime"]).
	set self["Roll"]["AngAcceleration"] to (self["Roll"]["AngVelocity"] - prevRollAngVel)/(TIME:SECONDS - self["Internal"]["UpdateTime"]).
	set self["Internal"]["UpdateTime"] to TIME:SECONDS.
}

function DAPa_Update {
	parameter self.
	if (self:Engaged AND self:Internal:AlreadyInUpdate = false) {
		set self:Internal:AlreadyInUpdate to true.

		if(ship:control:pilotrotation = v(0, 0, 0) and self:ManualOverride = true) {
			DAPa_UpdateAttitude(self).
			set self["Target"] to LEXICON(
				"Pitch", self["Pitch"]["Ang"],
				"Roll", self["Roll"]["Ang"]
			).
			set self["ManualOverride"] to false.
		}
		else if (ship:control:pilotrotation <> v(0, 0, 0)) {
			set self["ManualOverride"] to true.
		}

		DAPa_UpdateAttitudeRates(self).

		local rotVec to ship:control:pilotrotation.
		local desiredPitchVel to rotVec:Y*10.
		local desiredRollVel to rotVec:Z*10.

		if(self:ManualOverride = false) {
			set self["Pitch"]["VelocityPID"]:setpoint to self["Target"]["Pitch"].
			set desiredPitchVel to self["Pitch"]["VelocityPID"]:update(time:seconds, self["Pitch"]["ang"]).
			set self["Roll"]["VelocityPID"]:setpoint to self["Target"]["Roll"].
			set desiredRollVel to self["Roll"]["VelocityPID"]:update(time:seconds, self["Roll"]["ang"]).
		}

		set self["Pitch"]["TorquePID"]:setpoint to desiredPitchVel.
		local desiredPitchTorque to self["Pitch"]["TorquePID"]:update(time:seconds, self["Pitch"]["AngVelocity"]).

		set self["Pitch"]["DeflectionPID"]:setpoint to desiredPitchTorque.
		local desiredPitchDeltaDeflection to self["Pitch"]["DeflectionPID"]:update(time:seconds, self["Pitch"]["AngAcceleration"]).

		set self["Roll"]["TorquePID"]:setpoint to desiredRollVel.
		local desiredRollTorque to self["Roll"]["TorquePID"]:update(time:seconds, self["Roll"]["AngVelocity"]).

		set self["Roll"]["DeflectionPID"]:setpoint to desiredRollTorque.
		local desiredRollDeltaDeflection to self["Roll"]["DeflectionPID"]:update(time:seconds, self["Roll"]["AngAcceleration"]).

		local columnStick to ship:control.
		set columnStick:pitch to columnStick:pitch + desiredPitchDeltaDeflection.
		set columnStick:roll to columnStick:roll + desiredRollDeltaDeflection.

		print "Pitch tgt vel: " + desiredPitchVel at (0, 0).
		print "Pitch err" + self["Pitch"]["AngError"] at (0, 1).
		print "Roll tgt vel: " + desiredRollVel at (0, 3).
		print "Roll err" + self["Roll"]["AngError"] at (0, 4).


		set self:Internal:AlreadyInUpdate to false.
	}
}
