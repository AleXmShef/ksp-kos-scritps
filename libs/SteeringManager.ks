@lazyglobal off.
Import(LIST("miscellaneous", "maneuvers")).

declare global _Controls to 0.
declare global mnvrnodevector is 0.
declare global vessel is 0.
declare global SteeringManager_AlreadyInUpdate to false.

declare function Setup {
	set _Controls to 0.
	set _Controls to lexicon(
						"IsEnabled", 0,
						"Mode", "Attitude",
						"VelocityControl", 0,
						"ReferenceDirection", SHIP,
						"ThrustOffset", LEXICON("pitch", 0, "yaw", 0),
						"Vector", v(0,0,0),
						"Direction", LOOKDIRUP(v(1, 0, 0), v(0, 1, 0)),
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
	set _Controls["Pitch"]["TorquePID"]:Kp to 1.8.
	set _Controls["Pitch"]["TorquePID"]:Ki to 0.
	set _Controls["Pitch"]["TorquePID"]:Kd to 0.4.
	set _Controls["Pitch"]["TorquePID"]:maxoutput to 1.
	set _Controls["Pitch"]["TorquePID"]:minoutput to -1.
	set _Controls["Yaw"]["TorquePID"]:Kp to 1.8.
	set _Controls["Yaw"]["TorquePID"]:Ki to 0.
	set _Controls["Yaw"]["TorquePID"]:Kd to 0.4.
	set _Controls["Yaw"]["TorquePID"]:maxoutput to 1.
	set _Controls["Yaw"]["TorquePID"]:minoutput to -1.
	set _Controls["Roll"]["TorquePID"]:Kp to 1.1.
	set _Controls["Roll"]["TorquePID"]:Ki to 0.
	set _Controls["Roll"]["TorquePID"]:Kd to 0.8.
	set _Controls["Roll"]["TorquePID"]:maxoutput to 1.
	set _Controls["Roll"]["TorquePID"]:minoutput to -1.
	set _Controls["Pitch"]["VelocityPID"]:Kp to 0.2.
	set _Controls["Pitch"]["VelocityPID"]:Ki to 0.
	set _Controls["Pitch"]["VelocityPID"]:Kd to 0.5.
	set _Controls["Pitch"]["VelocityPID"]:maxoutput to 2.
	set _Controls["Pitch"]["VelocityPID"]:minoutput to -2.
	set _Controls["Yaw"]["VelocityPID"]:Kp to 0.2.
	set _Controls["Yaw"]["VelocityPID"]:Ki to 0.
	set _Controls["Yaw"]["VelocityPID"]:Kd to 0.5.
	set _Controls["Yaw"]["VelocityPID"]:maxoutput to 2.
	set _Controls["Yaw"]["VelocityPID"]:minoutput to -2.
	set _Controls["Roll"]["VelocityPID"]:Kp to 0.2.
	set _Controls["Roll"]["VelocityPID"]:Ki to 0.
	set _Controls["Roll"]["VelocityPID"]:Kd to 0.5.
	set _Controls["Roll"]["VelocityPID"]:maxoutput to 2.
	set _Controls["Roll"]["VelocityPID"]:minoutput to -2.
}

declare global currentFacingVec to ship:facing.
declare global previousFacingVec to v(0, 0, 0).
declare global previousTime to 0.

declare function SteeringManagerSetMode {
	declare parameter mode to "Attitude".
	declare parameter vec to 0.
	if(mode = "Vector") {
		set _Controls["Vector"] to vec.
		set _Controls["Mode"] to mode.
	}
	else if(mode = "Direction") {
		set _Controls:Direction to vec.
		set _Controls:Mode to mode.
	}
	else if(mode = "Vessel") {
		set _Controls["Mode"] to mode.
		set vessel to vec.
	}
	else
		set _Controls["Mode"] to "Attitude".
}

declare function SteeringManagerSetThrustOffset {
	declare parameter offset to LEXICON("pitch", 0, "yaw", 0).
	set _Controls["ThrustOffset"] to offset.
}

declare function UpdateOld {
	set currentFacingVec to _Controls["ReferenceDirection"]:facing.
	local foreVec to currentFacingVec:forevector.
	local starboardVec to currentFacingVec:starvector.
	local topVec to currentFacingVec:topvector.
	//------------------------------------------------------------------------------------------------------Delta Yaw Update
	local yawAngErr to vang(starboardVec, (_Controls["Vector"]["mVector"] - topVec)).
	if(vang((_Controls["Vector"]["mVector"] - topVec), foreVec) > 90)
		set yawAngErr to yawAngErr*-1.
	set yawAngErr to yawAngErr + _Controls:ThrustOffset:yaw.
	set _Controls["Yaw"]["AngVelocity"] to VDOT(topVec, SHIP:ANGULARVEL)*180/CONSTANT:PI.
	set _Controls["Yaw"]["AngError"]  to yawAngErr.
	//------------------------------------------------------------------------------------------------------Delta Pitch Update
	local pitchAngErr to vang(topVec, (_Controls["Vector"]["mVector"] - starboardVec)).
	if(vang((_Controls["Vector"]["mVector"] - starboardVec), foreVec) > 90)
		set pitchAngErr to pitchAngErr*-1.
	set pitchAngErr to pitchAngErr + _Controls:ThrustOffset:pitch.
	set _Controls["Pitch"]["AngVelocity"] to -VDOT(starboardVec, SHIP:ANGULARVEL)*180/CONSTANT:PI.
	set _Controls["Pitch"]["AngError"]  to pitchAngErr.
	//------------------------------------------------------------------------------------------------------Delta Roll Update
	set _Controls["Roll"]["AngVelocity"] to VDOT(foreVec, SHIP:ANGULARVEL)*180/CONSTANT:PI.
	//set _Controls["Roll"]["AngError"] to rollAngErr.
}

declare function Update {
	set currentFacingVec to Ship:facing.
	local foreVec to currentFacingVec:forevector.
	local starboardVec to currentFacingVec:starvector.
	local topVec to currentFacingVec:topvector.

	local shipBasis to LEXICON("x", foreVec, "y", starboardVec, "z", topVec).

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
