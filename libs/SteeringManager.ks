@lazyglobal off.

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
						"DebugFlag", 0,
						"Vector", lexicon(
									"mVector", v(0,0,0)
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
	set _Controls["Roll"]["TorquePID"]:Kp to 1.
	set _Controls["Roll"]["TorquePID"]:Ki to 0.
	set _Controls["Roll"]["TorquePID"]:Kd to 0.1.
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
	set _Controls["Roll"]["VelocityPID"]:Kp to 0.3.
	set _Controls["Roll"]["VelocityPID"]:Ki to 0.
	set _Controls["Roll"]["VelocityPID"]:Kd to 0.1.
	set _Controls["Roll"]["VelocityPID"]:maxoutput to 1.
	set _Controls["Roll"]["VelocityPID"]:minoutput to -1.
}

declare global currentFacingVec to ship:facing.
declare global previousFacingVec to v(0, 0, 0).
declare global previousTime to 0.

declare function SteeringManagerSetVector {
	declare parameter vector to ship:facing:forevector.
	set _Controls["Vector"]["mVector"] to vector.
}

declare function SteeringManagerSetMode {
	declare parameter mode to "Attitude".
	declare parameter vec to 0.
	if(mode = "ManeuverNode") {
		set _Controls["Mode"] to mode.
		if(HASNODE) {
			lock mnvrnodevector to ALLNODES[0]:deltav.
		}
	}
	else if(mode = "Vector") {
		set _Controls["Vector"]["mVector"] to vec.
		set _Controls["Mode"] to mode.
	}
	else if(mode = "Vessel") {
		set _Controls["Mode"] to mode.
		set vessel to vec.
	}
	else
		set _Controls["Mode"] to "Attitude".
}

declare function Update {
	set currentFacingVec to ship:facing.
	local foreVec to currentFacingVec:forevector.
	local starboardVec to currentFacingVec:starvector.
	local topVec to currentFacingVec:topvector.
	//------------------------------------------------------------------------------------------------------Delta Yaw Update
	local yawAngErr to vang(starboardVec, (_Controls["Vector"]["mVector"] - topVec)).
	if(vang((_Controls["Vector"]["mVector"] - topVec), foreVec) > 90)
		set yawAngErr to yawAngErr*-1.
	set _Controls["Yaw"]["AngVelocity"] to VDOT(topVec, SHIP:ANGULARVEL)*180/CONSTANT:PI.
	set _Controls["Yaw"]["AngError"]  to yawAngErr.
	//------------------------------------------------------------------------------------------------------Delta Pitch Update
	local pitchAngErr to vang(topVec, (_Controls["Vector"]["mVector"] - starboardVec)).
	if(vang((_Controls["Vector"]["mVector"] - starboardVec), foreVec) > 90)
		set pitchAngErr to pitchAngErr*-1.
	set _Controls["Pitch"]["AngVelocity"] to -VDOT(starboardVec, SHIP:ANGULARVEL)*180/CONSTANT:PI.
	set _Controls["Pitch"]["AngError"]  to pitchAngErr.
	//------------------------------------------------------------------------------------------------------Delta Roll Update
	set _Controls["Roll"]["AngVelocity"] to VDOT(foreVec, SHIP:ANGULARVEL)*180/CONSTANT:PI.
	//set _Controls["Roll"]["AngError"] to rollAngErr.
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
		//DROPPRIORITY().
		if(_Controls["Mode"] = "ManeuverNode") {
			if(HASNODE) {
				set _Controls["Vector"]["mVector"] to mnvrnodevector.
			}
		}
		else if (_Controls["Mode"] = "Vessel") {
			set _Controls["Vector"]["mVector"] to vessel:POSITION.
		}
		Update().
		if(_Controls["Mode"] = "Attitude") {
			set _Controls["Pitch"]["AngError"] to 90.
			set _Controls["Yaw"]["AngError"] to 90.
			set _Controls["Roll"]["AngError"] to 90.
		}
		local desiredPitchAngVel is 0.
		local desiredPitchColumnStick is 0.
		local desiredYawAngVel is 0.
		local desiredYawColumnStick is 0.
		local desiredRollAngVel is 0.
		local desiredRollColumnStick is 0.
		if(_Controls["Mode"] = "Attitude" or _Controls["Mode"] = "KillRot" or _Controls["Mode"] = "ManeuverNode" or _Controls["Mode"] = "Vector" or _Controls["Mode"] = "Vessel") {
			//---------------------------------------------------------------------Pitch update
			set _Controls["Pitch"]["VelocityPID"]:setpoint to 90.
			set desiredPitchAngVel to _Controls["Pitch"]["VelocityPID"]:update(time:seconds, _Controls["Pitch"]["AngError"]).
			set _Controls["Pitch"]["TorquePID"]:setpoint to desiredPitchAngVel.
			set desiredPitchColumnStick to _Controls["Pitch"]["TorquePID"]:update(time:seconds, _Controls["Pitch"]["AngVelocity"]).
			//---------------------------------------------------------------------Yaw update
			set _Controls["Yaw"]["VelocityPID"]:setpoint to 90.
			set desiredYawAngVel to _Controls["Yaw"]["VelocityPID"]:update(time:seconds, _Controls["Yaw"]["AngError"]).
			set _Controls["Yaw"]["TorquePID"]:setpoint to desiredYawAngVel.
			set desiredYawColumnStick to _Controls["Yaw"]["TorquePID"]:update(time:seconds, _Controls["Yaw"]["AngVelocity"]).
			//---------------------------------------------------------------------Roll update
			//if(vang(_Controls["Vector"]["mVector"], ship:facing:forevector) > 20) {
				set _Controls["Roll"]["TorquePID"]:setpoint to 0.
				set desiredRollColumnStick to -_Controls["Roll"]["TorquePID"]:update(time:seconds, _Controls["Roll"]["AngVelocity"]).
			//}
			//else {
			//	set _Controls["Roll"]["VelocityPID"]:setpoint to 90.
			//	set desiredRollAngVel to _Controls["Roll"]["VelocityPID"]:update(time:seconds, _Controls["Roll"]["AngError"]).
			//	set _Controls["Roll"]["TorquePID"]:setpoint to desiredRollAngVel.
			//	set desiredRollColumnStick to _Controls["Roll"]["TorquePID"]:update(time:seconds, _Controls["Roll"]["AngVelocity"]).
			//}
			//---------------------------------------------------------------------Control update
			local columnStick to ship:control.
			set columnStick:pitch to desiredPitchColumnStick.
			set columnStick:yaw to desiredYawColumnStick.
			set columnStick:roll to desiredRollColumnStick.
		}
		//---------------------------------------------------------------------Print debug info
		//print "Total error: " + (90 - _Controls["Pitch"]["AngError"]) at (0, 15).
		// if(_Controls["DebugFlag"]) {
		// 	clearscreen.
		// 	print "Total error: " + vang(_Controls["Vector"]["mVector"], ship:facing:forevector) at (0, 0).
		// 	print "Pitch angular error: " + (90 - _Controls["Pitch"]["AngError"]) at (0, 1).
		// 	print "Pitch angular velocity: " + _Controls["Pitch"]["AngVelocity"] at (0, 2).
		// 	print "Pitch desired angular velocity: " + desiredPitchAngVel at (0, 3).
		// 	print "Yaw angular error: " + (90 - _Controls["Yaw"]["AngError"]) at (0, 4).
		// 	print "Yaw angular velocity: " + _Controls["Yaw"]["AngVelocity"] at (0, 5).
		// 	print "Yaw desired angular velocity: " + desiredYawAngVel at (0, 6).
		// 	print "Roll angular velocity: " + _Controls["Roll"]["AngVelocity"] at (0, 7).
		// }
		set SteeringManager_AlreadyInUpdate to false.
	}
}
