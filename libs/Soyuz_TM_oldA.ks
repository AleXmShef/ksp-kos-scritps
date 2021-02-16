
local storagePath is "1:".
if not exists(storagePath + "/libs") {
	createdir(storagePath + "/libs").
}

function libDl {
	parameter libs is list().
	
	for lib in libs {
		//if not exists(storagePath + "/libs/" + lib + ".ks") {
			copypath("0:/libs/" + lib + ".ks", storagePath + "/libs/").
		//}
	}
	for lib in libs {
		runpath(storagePath + "/libs/" + lib + ".ks").
	}
}

libDl(list("general_functions", "SteeringManager", "Soyuz_TMA_MFD", "Math")).

declare global Serializable is lexicon(
				"LastMode", "Ascent",
				"SolarDeploy", 0,
				"AntennaActive", 0,
				"DockedToISS", 0,
				"AbortMode", 0,
				"EngineStatus", 0,
				"ReadyFromParkingOrbit", 0
).

declare global Telemetry is lexicon(
				"Ap", 0,
				"Pe", 0,
				"Inc", 0,
				"Vel", 0,
				"Lan", 0,
				"TrueAnomaly", 0,
				"AngVel", 0,
				"VerSpd", 0,
				"TrueAlt", 0,
				"gLoad", 0,
				"MnvEta", 0,
				"MnvDvRem", 0,
				"RelInc", 0,
				"TrgtAp", 0,
				"TrgtPe", 0,
				"TrgtRelVel", 0,
				"EngineThrust", 0,
				"EngineIsp", 0,
				"SolarPower", 0,
				"BatteryLife", 0,
				"Fuel", 0,
				"Oxygen", 0,
				"Food", 0
).

declare global SoyuzParts is Lexicon(
				//-------------------------------------------------------------------------Base Parts
				"DescentModule", SHIP:PARTSTAGGED("DescentModule")[0],
				"OrbitalModule", SHIP:PARTSTAGGED("OrbitalModule")[0],
				"ServiceModule", SHIP:PARTSTAGGED("ServiceModule")[0]
).

declare global SoyuzModules is Lexicon(
				//-------------------------------------------------------------------------Actual Descent Module Parts
				"Chutes", SoyuzParts["DescentModule"]:GETMODULE("SSTUModularParachute"),
				//-------------------------------------------------------------------------Actual Orbital Module Parts
				"Antenna", SoyuzParts["OrbitalModule"]:GETMODULE("ModuleRTAntenna"),
				"AtmosphereRegenerator", SoyuzParts["OrbitalModule"]:GETMODULE("TacGenericConverter"),
				"DockingModule", 0,
				//-------------------------------------------------------------------------Actual Service Module Parts
				"Engine", SoyuzParts["ServiceModule"]:GETMODULE("ModuleEnginesRF"),
				"SolarPanels", SoyuzParts["ServiceModule"]:GETMODULE("SSTUAnimateUsable")	
).

declare global CurrentMode to "debug".
declare global Thrust to 0.
declare global Steer to 0.
declare global FuncList to list().
declare global LoopFlag to 0.

ExecMode("ProximityOps").

declare function ModeController {
	declare parameter TargetMode.
	if (TargetMode <> CurrentMode) {
		SerializeManager("LastMode", TargetMode).
		ExecMode(TargetMode).
	}
}

declare function ExecMode {
	declare parameter pMode to -1.
	if (pMode = "debug") {
		set CurrentMode to "debug".
		wait until terminal:input:haschar.
		
		UpdateControls().
		//LoopManager(0, MFD@).
		LoopManager(0, UpdateTelemetry@).
		
		
		
		wait until CurrentMode <> "debug".

	}
	if (pMode = "Nothing") {
		UpdateControls().
		LoopManager(0, MFD@).
		set CurrentMode to "Nothing".
		wait until CurrentMode <> "Nothing".
		ModeController(CurrentMode).
	}
	if (pMode = "Ascent") {
		set CurrentMode to "Ascent".
		until not CORE:MESSAGES:EMPTY {
			MFD().
		}
		set Recieved to CORE:MESSAGES:POP.
		if Recieved:content = "Successful ascent" {
			ModeController("ParkingOrbit").
		} 
		else {
			ModeController("FailedAscent").
		}
	}
	else if (pMode = "ParkingOrbit") {
		clearscreen.
		set CurrentMode to "ParkingOrbit".
		UpdateControls().
		LoopManager(0, UpdateTelemetry@).
		LoopManager(0, MFD@).
		wait 5.
		rcs on.
		
		//stage.
		//if ok, proceed to the next mode
		//wait until CurrentMode <> "ParkingOrbit".
		ModeController("PhasingOrbit").
		//ModeController("TPO").
	}
	else if (pMode = "TPO") {
		set CurrentMode to "TPO".
		
		set CurOrb to OrbitClass:copy.
		set CurOrb to UpdateOrbitParams(CurOrb).
		//-------------------------------------------------------Transfer to phasing orbit
		set TgtOrb to OrbitClass:copy.
		set TgtOrb["Pe"] to CurOrb["Pe"] - 100.
		print TgtOrb["Pe"].
		set TgtOrb["Ap"] to Globals["R"] + 280*1000.
		print TgtOrb["Ap"].
		set TgtOrb["Inc"] to CurOrb["Inc"].
		set TgtOrb["LAN"] to CurOrb["LAN"].
		set TgtOrb["AoP"] to CurOrb["AoP"].
		set TgtOrb to BuildOrbit(TgtOrb).
		
		set MyNode to OrbitTransfer(CurOrb, TgtOrb).
		ExecBurn(MyNode).
		wait 5.
		
		ModeController("PhasingOrbit").
		
	}
	else if (pMode = "PhasingOrbit") {
		//-------------------------------------------------------Circularization
		set CurrentMode to "PhasingOrbit".
		set CurOrb to OrbitClass:copy.
		set CurOrb to UpdateOrbitParams(CurOrb).
		
		set TgtOrb to OrbitClass:copy.
		set TgtOrb["Pe"] to CurOrb["Ap"] + 100.
		set TgtOrb["Ap"] to CurOrb["Ap"] - 100.
		set TgtOrb["Inc"] to CurOrb["Inc"].
		set TgtOrb["LAN"] to CurOrb["LAN"].
		set TgtOrb["AoP"] to CurOrb["AoP"].
		set TgtOrb to BuildOrbit(TgtOrb).
		
		set MyNode to OrbitTransfer(CurOrb, TgtOrb).
		ExecBurn(MyNode).
		
		wait until CurrentMode <> "PhasingOrbit".
		ModeController(CurrentMode).
	}
	else if (pMode = "Rendezvous") {
		set CurrentMode to "Rendezvous".
	}
	else if (pMode = "ProximityOps") {
		
		wait until terminal:input:haschar.
		set CurrentMode to "ProximityOps".
		
		set target to "Soyuz Docking Target".
		
		set t to target:orbit:period/2.
		set n to sqrt(Globals["mu"]/((target:orbit:semimajoraxis)^3)).
		//--------------------------------------------------------------------Target Relative Position
		set TgtX to -200.
		set TgtY to 0.
		set TgtZ to 1.
		//--------------------------------------------------------------------Current Relative Position
		set CurTgtVec to target:position - ship:body:position.	//Current Target Position
		set CurVec to ship:position - ship:body:position.	//Current Ship Position
		set RelPosVec to CurTgtVec - CurVec.	//Relative Posotion Vector
		set RelPosAng to -1*(90 - (180 - vang(CurTgtVec, RelPosVec))).	//Angle Between RelativePositionVector and TargetLVLH
		print RelPosAng.
		
		set CurX to -1*RelPosVec:mag * sin(RelPosAng).
		set CurZ to RelPosVec:mag * cos(RelPosAng).
		set deb to sqrt(CurX^2 + CurZ^2).
		set CurY to 0.
		
		//--------------------------------------------------------------------Current Relative Velocity
		set CurTgtVel to target:velocity:orbit.	//Current Target Velocity
		set CurVel to ship:velocity:orbit.	//Current Ship Velocity
		set CurVelAng to vang(CurTgtVel, CurVel).	//Angle Between Velocities
		set CurRelVel to CurVel - CurTgtVel.	//Current Relative Velocity
		set CurRelVelAng to vang(CurTgtVel, CurRelVel).	//Angle Between Reltive Velocity and Target Velocity
		
		set CurVz to CurRelVel:mag*cos(CurRelVelAng).	//Current V-Bar velocity
		set CurVx to CurRelVel:mag*sin(CurRelVelAng).	//Current Z-Bar velocity
		set CurVy to 0.
		//Current Y-Bar velocity
		print CurRelVelAng.
		print CurVz.
		print CurVx.
		
		//---------------------------------------------------------------------Build Matrices
		set Rc to MatrixClass:copy.		//---------------Current Position Matrix
		set Rc["MatrixSelf"] to list(list(CurX),
									list(CurY),
									list(CurZ)
								).
		
		set Rt to MatrixClass:copy.		//---------------Target Position Matrix
		set Rt["MatrixSelf"] to list(list(TgtX),
									list(TgtY),
									list(TgtZ)
								).
		set Vct to Help(Rc, Rt).
		
		//----------------------------------------------------------------------Target Relative Velocity
		set CurTgtVx to Vct["MatrixSelf"][0][0].
		set CurTgtVy to Vct["MatrixSelf"][1][0].
		set CurTgtVz to Vct["MatrixSelf"][2][0].
		
		print CurTgtVx.
		print CurTgtVy.
		print CurTgtVz.
		
		wait 2.
		
		set CurTgtVel to target:velocity:orbit.
		set TgtRelVel to sqrt(CurTgtVx^2 + CurTgtVz^2).
		set TgtRelVelRelAng to arctan(CurTgtVx/CurTgtVz).
		set TgtCurVel to sqrt(CurTgtVel:mag^2+TgtRelVel^2 - 2*CurTgtVel:mag*TgtRelVel*cos(TgtRelVelRelAng)).
		print TgtRelVel.
		wait 2.
		
		//----------------------------------------------------------------------Prepare Maneuver Node for Transfer
		set CurOrb to OrbitClass:copy.
		set CurOrb to UpdateOrbitParams(CurOrb).
		set CurVel to ship:velocity:orbit.
		set depF to arccos(CurOrb["h"]/(RatAngle(CurOrb, ship:orbit:trueanomaly)*CurVel:mag)).
		if (ship:orbit:trueanomaly > 180)
			set CurVelAng to CurVelAng*-1.
		set tgtF to CurVelAng + TgtRelVelRelAng + depF.
		set dF to tgtF - depF.
		
		set dVv to sqrt(CurVel:mag*CurVel:mag + TgtCurVel*TgtCurVel - 2*CurVel:mag*TgtCurVel*cos(dF)).
		set dVang to arccos((dVv*dVv + CurVel:mag*CurVel:mag - TgtCurVel*TgtCurVel)/(2*CurVel:mag*dVv)).
		set dVprog to -1*dVv*cos(dVang).
		
				set dVrad to dVv*sin(dVang).
	
		set dVnorm to 0.
		set meta to time:seconds + 1.
		set MyNode to NODE(meta, dVrad, dVnorm, dVprog).
		add MyNode.
		
		
		
	
		
		
		
		
		wait until false.
	}
	else if (pMode = "Docking") {
		set CurrentMode to "Docking".
	}
	else if (pMode = "Docked") {
		set CurrentMode to "Docked".
	}
	else if (pMode = "Returning") {
		set pMode to "Returning".
	}
	else if (pMode = "Reentry") {
		set pMode to "Reentry".
	}
}







declare function EngineController {
	declare parameter action to 0.
	
	if (action <> Serializable["EngineStatus"]) {
		if (action = 0) {
			SoyuzModules["Engine"]:DOEVENT("shutdown engine").
			SerializeManager("EngineStatus", 0).
		}
		else if (action = 1) {
			SoyuzModules["Engine"]:DOEVENT("activate engine").
			SerializeManager("EngineStatus", 1).
		}
	}
}

declare function test {
	LoopManager(1, MFD@).
	clearscreen.
	print "HUI".
	wait 2.
	LoopManager(0, MFD@).
}

declare function SolarController {
	declare parameter action to 1.
	
	if (action <> Serializable["SolarDeploy"]) {
		if (action = 1) {
			SoyuzModules["SolarPanels"]:DOEVENT("Deploy Solar Panels").
			SerializeManager("SolarDeploy", 1).
		}
		else if (action = 0) {
			SoyuzModules["SolarPanels"]:DOEVENT("Retract Solar Panels").
			SerializeManager("SolarDeploy", 0).
		}
	}
}

declare function AntennaController {
	declare parameter mode to 11.
	
	if (mode <> Serializable["AntennaActive"]) {
		if (mode = 0) {
			SoyuzModules["Antenna"]:DOEVENT("Deactivate").
			SerializeManager("AntennaActive", 0).
		}
		else if (mode > 0) {
			if (Serializable["AntennaActive"] = 0)
				SoyuzModules["Antenna"]:DOEVENT("Activate").
			if (mode = 11) {
				//SatelliteManager()
				SerializeManager("AntennaActive", 11).
			}
			else if (mode = 12) {
				SoyuzModules["Antenna"]:SETFIELD("target", "ISS").
				SerializeManager("AntennaActive", 12).
			}
		}
	}
}

declare function UpdateTelemetry {
	set Telemetry["Ap"] to (SHIP:ORBIT:APOAPSIS - Globals["R"]) / 1000.
	set Telemetry["Pe"] to (SHIP:ORBIT:PERIAPSIS - Globals["R"]) / 1000.
	set Telemetry["Inc"] to SHIP:ORBIT:INCLINATION.
	set Telemetry["Vel"] to SHIP:VELOCITY:ORBIT:MAG.
	set Telemetry["Lan"] to SHIP:ORBIT:LAN.
	set Telemetry["TrueAnomaly"] to SHIP:ORBIT:TRUEANOMALY.
	set Telemetry["AngVel"] to SHIP:ANGULARVEL:MAG.
	set Telemetry["VerSpd"] to SHIP:VERTICALSPEED.
	set Telemetry["TrueAlt"] to 0.			//-------------CHANGE---------------------------------------------------------------------------------
	set Telemetry["gLoad"] to SHIP:Q.
	if (HASNODE) {
		set Telemetry["MnvEta"] to NEXTNODE:DELTAV:MAG.
		set Telemetry["MnvDvRem"] to NEXTNODE:ETA - time:seconds.
		set Controls["Vector"]["mVector"] to -1*NEXTNODE:DELTAV.
	}
//	if (SHIP:HASTARGET) {
//		set Telemetry["RelInc"] to abs(SHIP:TARGET:ORBIT:INCLINATION - Telemetry["Inclination"]).
//		set Telemetry["TrgtAp"] to (SHIP:TARGET:ORBIT:APOAPSIS - Globals["R"]) / 1000.
//		set Telemetry["TrgtPe"] to (SHIP:TARGET:ORBIT:PERIAPSIS - Globals["R"]) / 1000.
//		set Telemetry["TrgtRelVel"] to abs(Telemetry["Vel"] - SHIP:TARGET:VELOCITY:ORBIT:MAG).
//	}
	set Telemetry["EngineThrust"] to 4.09.		//-------------CHANGE---------------------------------------------------------------------------------
	set Telemetry["EngineIsp"] to 282.
	set Telemetry["SolarPower"] to 1.
	set Telemetry["BatteryLife"] to 1.
	set Telemetry["Fuel"] to 1.
	set Telemetry["Oxygen"] to 1.
	set Telemetry["Food"] to 1.
}



declare function LoopManager {
	declare parameter action to -1.
	declare parameter pointer to 0.
	if (LoopFlag = 1) {
		
	}
	else if (action = -1) {
		lock throttle to Thrust.
		for f in FuncList:copy {
			f:call().
		}
		lock throttle to Thrust + LoopManager.
	}
	else if (action = 0) {
		set LoopFlag to 1.
		FuncList:Add(pointer).
		set LoopFlag to 0.
	}
	else if (action = 1) {
		set tList to FuncList:copy.
		local i is 0.
		for f in tList {
			if (pointer = f) {
				tList:Remove(i).
				break.
			}
			set i to i+1.
		}
		set FuncList to tList.
	}
}

declare function SerializeManager {
	declare parameter key to 0.
	declare parameter value to 0.
	set Serializable[key] to value.
	WRITEJSON(Serializable, "1:/SoyuzTMAcfg.json").
}

declare function UpdateControls {
	set STEERINGMANAGER:PITCHPID:KP to 0.8.
	set STEERINGMANAGER:PITCHPID:KI to 0.5.
	set STEERINGMANAGER:PITCHPID:KD to 0.1.
	set STEERINGMANAGER:YAWPID:KP to 0.8.
	set STEERINGMANAGER:YAWPID:KI to 0.5.
	set STEERINGMANAGER:YAWPID:KD to 0.1.
	set STEERINGMANAGER:MAXSTOPPINGTIME to 15.
	set STEERINGMANAGER:PITCHTS to 10.
	set STEERINGMANAGER:YAWTS to 10.
	LoopManager(0, SteerManager@).
	lock throttle to LoopManager() + Thrust.
}

declare function ExecBurn {
	declare parameter mnvrnode.
	add mnvrnode.
	
	set tm to CalcBurnTime(mnvrnode:deltav:mag, Telemetry["EngineThrust"], Telemetry["EngineIsp"]).
	
	wait until (vang(ship:facing:forevector, mnvrnode:deltav) < 2).
	
	set hi to time:seconds + mnvrnode:eta - (tm/2) - 25.
	
	kuniverse:TimeWarp:WARPTO(hi).
	
	wait until (time:seconds > hi + 20).
	
	EngineController(1).
	
	wait 5.
	
	set Thrust to 1.
	
	wait tm - 4.2.
	
	remove nextnode.
	
	wait 5.
	
	set Thrust to 0.
	
	EngineController(0).
	
	set Controls["Vector"]["mVector"] to v(0, 0, 0).
	
	
}

declare function help {
	declare parameter Rc.
	declare parameter Rt.
	
	set Mtrans to MatrixClass:copy.	//---------------Mtransition Matrix
	set Mtrans["MatrixSelf"] to list(list(4-3*cos(n*t), 	   0, 0),
									 list(6*(sin(n*t) - n*t),  1, 0),
									 list(0,                   0, cos(n*t))
									 ).
	set Ntrans to MatrixClass:copy.	//---------------Ntransition Matrix
	set Ntrans["MatrixSelf"] to list(list((1/n)*sin(n*t),          (2/n)*(1 - cos(n*t)),     0),
									 list(-1*(2/n)*(1 - cos(n*t)), (1/n)*(4*sin(n*t)-3*n*t), 0),
									 list(0,                       0,                        (1/n)*sin(n*t))
									 ).
	//----------------------------------------------------------------------Compute Target Relative Velocity Matrix								 
	set NtransInv to MatrixFindInverse(Ntrans).
	set MRc to MatrixMultiply(Mtrans, Rc).
	set RtMrc to MatrixSubtract(Rt, Mrc).
	declare Vct to MatrixMultiply(NtransInv, RtMrc). //Target Relative Velocity Matrix
	return Vct.
}

	







