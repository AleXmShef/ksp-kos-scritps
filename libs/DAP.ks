@lazyglobal off.
Import(LIST("miscellaneous", "maneuvers")).

function GetDAP {
	return LEXICON(
		"Engaged", false,
		"Mode", LEXICON(
			"Mode", "Inertial",
			"Target", ship:facing
		),
		"ReferenceAxis", "+X",
		"VelocityControl", 0,
		"ThrustOffset", LEXICON("pitch", 0, "yaw", 0),
		"Internal", LEXICON(
			"AlreadyInUpdate", false,
			"ReferenceAxis", LEXICON(
				"+X", LEXICON("x", v(1, 0, 0), "y", v(0, 1, 0), "z", v(0, 0, 1)),
				"-X", LEXICON("x", v(-1, 0, 0), "y", v(0, -1, 0), "z", v(0, 0, -1)),
				"+Y", LEXICON("x", v(0, 1, 0), "y", v(-1, 0, 0), "z", v(0, 0, 1)),
				"-Y", LEXICON("x", v(0, -1, 0), "y", v(1, 0, 0), "z", v(0, 0, -1)),
				"+Z", LEXICON("x", v(0, 0, 1), "y", v(0, 1, 0), "z", v(1, 0, 0)),
				"-Z", LEXICON("x", v(0, 0, -1), "y", v(0, -1, 0), "z", v(-1, 0, 0)),
			)
		)
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
	)
}

function DAP_Engage {
	set self:Engaged to true.
}

function DAP_Disengage {
	parameter self.
	set self:Engaged to false.
	set ship:control:neutralize to true.
}

declare function DAP_Setup {
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
	set self["Roll"]["TorquePID"]:Kp to 1.1.
	set self["Roll"]["TorquePID"]:Ki to 0.
	set self["Roll"]["TorquePID"]:Kd to 0.8.
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

declare function DAP_SetMode {
	declare parameter self.
	declare parameter mode to "Attitude".
	declare parameter arg to 0.
	if(mode = "Inertial") {
		set self["Mode"] to LEXICON(
			"Mode", "Inertial"
		).
	}
	else if(mode = "LVLH") {
		set self["Mode"] to LEXICON(
			"Mode", "LVLH"
		).
	}
	else if(mode = "Track") {
		set self["Mode"] to LEXICON(
			"Mode", "Track",
			"Target", arg:Target,
			"Reference", arg:Reference
		).
	}
	else
		set _Controls["Mode"] to "Attitude".
}

declare function DAP_SetThrustOffset {
	declare parameter offset to LEXICON("pitch", 0, "yaw", 0).
	set _Controls["ThrustOffset"] to offset.
}

declare function Update {
	//EXPECTS DEFINED GLOBAL: DAP_GLOBAL
	local shipBasis to DAP_GLOBAL:

	local angErr to 0.
	if(_Controls:Mode = "Vector")
		set angErr to GetRotationBetweenBasisDirection(shipBasis, LOOKDIRUP(_Controls:Vector, -SHIP:BODY:POSITION)).
	else
		set angErr to GetRotationBetweenBasisDirection(shipBasis, _Controls:Direction).
	//------------------------------------------------------------------------------------------------------Delta Yaw Update
	local yawAngErr to angErr:yaw.
	set yawAngErr to yawAngErr + _Controls:ThrustOffset:yaw.
	set _Controls["Yaw"]["AngVelocity"] to VDOT(topVec, SHIP:ANGULARVEL)*180/CONSTANT:PI.
	set _Controls["Yaw"]["AngError"]  to yawAngErr.
	//------------------------------------------------------------------------------------------------------Delta Pitch Update
	local pitchAngErr to angErr:pitch.
	set pitchAngErr to pitchAngErr + _Controls:ThrustOffset:pitch.
	set _Controls["Pitch"]["AngVelocity"] to -VDOT(starboardVec, SHIP:ANGULARVEL)*180/CONSTANT:PI.
	set _Controls["Pitch"]["AngError"]  to pitchAngErr.
	//------------------------------------------------------------------------------------------------------Delta Roll Update
	local rollAngErr to angErr:roll.
	set _Controls["Roll"]["AngVelocity"] to -VDOT(foreVec, SHIP:ANGULARVEL)*180/CONSTANT:PI.
	set _Controls["Roll"]["AngError"] to rollAngErr.
}

declare function SteeringManagerMaster {
	declare parameter action is 0.
	if(action = 0) {
		set _Controls["IsEnabled"] to 0.
		set ship:control:neutralize to true.
	}
	else if (action = 1) {
		if (_Controls = 0)
			Setup().
		set _Controls["Pitch"]["AngError"] to 0.
		set _Controls["Pitch"]["AngVelocity"] to 0.
		set _Controls["Yaw"]["AngError"] to 0.
		set _Controls["Yaw"]["AngVelocity"] to 0.
		set _Controls["IsEnabled"] to 1.
	}
}

declare function SteeringManager {
	if (_Controls["IsEnabled"] = 1 AND SteeringManager_AlreadyInUpdate = false) {
		set SteeringManager_AlreadyInUpdate to true.
		if (_Controls["Mode"] = "Vessel") {
			set _Controls["Vector"] to vessel:POSITION.
		}
		Update().
		if(_Controls["Mode"] = "Attitude") {
			set _Controls["Pitch"]["AngError"] to 0.
			set _Controls["Yaw"]["AngError"] to 0.
			set _Controls["Roll"]["AngError"] to 0.
		}
		local desiredPitchAngVel is 0.
		local desiredPitchColumnStick is 0.
		local desiredYawAngVel is 0.
		local desiredYawColumnStick is 0.
		local desiredRollAngVel is 0.
		local desiredRollColumnStick is 0.
		if(_Controls["Mode"] = "Attitude" or _Controls["Mode"] = "Vector" or _Controls["Mode"] = "Direction" or _Controls["Mode"] = "Vessel") {
			//---------------------------------------------------------------------Pitch update
			set _Controls["Pitch"]["VelocityPID"]:setpoint to 0.
			set desiredPitchAngVel to _Controls["Pitch"]["VelocityPID"]:update(time:seconds, _Controls["Pitch"]["AngError"]).
			set _Controls["Pitch"]["TorquePID"]:setpoint to desiredPitchAngVel.
			set desiredPitchColumnStick to _Controls["Pitch"]["TorquePID"]:update(time:seconds, _Controls["Pitch"]["AngVelocity"]).
			//---------------------------------------------------------------------Yaw update
			set _Controls["Yaw"]["VelocityPID"]:setpoint to 0.
			set desiredYawAngVel to _Controls["Yaw"]["VelocityPID"]:update(time:seconds, _Controls["Yaw"]["AngError"]).
			set _Controls["Yaw"]["TorquePID"]:setpoint to desiredYawAngVel.
			set desiredYawColumnStick to _Controls["Yaw"]["TorquePID"]:update(time:seconds, _Controls["Yaw"]["AngVelocity"]).
			//---------------------------------------------------------------------Roll update
			set _Controls["Roll"]["VelocityPID"]:setpoint to 0.
			set desiredRollAngVel to _Controls["Roll"]["VelocityPID"]:update(time:seconds, _Controls["Roll"]["AngError"]).
			set _Controls["Roll"]["TorquePID"]:setpoint to desiredRollAngVel.
			set desiredRollColumnStick to _Controls["Roll"]["TorquePID"]:update(time:seconds, _Controls["Roll"]["AngVelocity"]).
			//---------------------------------------------------------------------Control update
			local columnStick to ship:control.
			set columnStick:pitch to desiredPitchColumnStick.
			set columnStick:yaw to desiredYawColumnStick.
			set columnStick:roll to desiredRollColumnStick.
		}
		//---------------------------------------------------------------------Print debug info

		//if(_Controls["DebugFlag"]) {
			clearscreen.
			clearvecdraws().
			//vecdraw(v(0,0,0), )
			print "Total error: " + vang(_Controls["Vector"], ship:facing:forevector) at (0, 13).
			print "Pitch angular error: " + (_Controls["Pitch"]["AngError"]) at (0, 1).
			print "Pitch angular velocity: " + _Controls["Pitch"]["AngVelocity"] at (0, 2).
			print "Pitch desired angular velocity: " + desiredPitchAngVel at (0, 3).
			print "Yaw angular error: " + (_Controls["Yaw"]["AngError"]) at (0, 5).
			print "Yaw angular velocity: " + _Controls["Yaw"]["AngVelocity"] at (0, 6).
			print "Yaw desired angular velocity: " + desiredYawAngVel at (0, 7).
			print "Roll angular error: " + (_Controls["Roll"]["AngError"]) at (0, 9).
			print "Roll angular velocity: " + _Controls["Roll"]["AngVelocity"] at (0, 10).
			print "Roll desired angular velocity: " + desiredRollAngVel at (0, 11).
		//}
		set SteeringManager_AlreadyInUpdate to false.
	}
}
