@lazyglobal off.
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

libDl(list("general_functions", "SteeringManager", "math")).

declare global Serializable is lexicon (
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

declare global ProgressParts is Lexicon(
				//-------------------------------------------------------------------------Base Parts
				"ServiceModule", SHIP:PARTSTAGGED("Progress Service Module")[0],
				"OrbitalModule", SHIP:PARTSTAGGED("Progress Orbital Module")[0],
				//"Antenna", SHIP:PARTSTAGGED("Progress Antenna")[0],
				"DockingPort", SHIP:PARTSTAGGED("Progress Docking Port")[0]
				//"SolarPanelL", SHIP:PARTSTAGGED("Progress Solar Panel")[0],
				//"SolarPanelR", SHIP:PARTSTAGGED("Progress Solar Panel")[1]
).

declare global ProgressModules is Lexicon(
				"Antenna", ProgressParts["OrbitalModule"]:GETMODULE("ModuleRTAntenna"),
				"DockingModule", 0,
				"Engine", ProgressParts["ServiceModule"]:GETMODULE("ModuleEnginesRF")
				//"SolaPanelL", SoyuzParts["SolarPanelL"]:GETMODULE("SSTUAnimateUsable"),
				//"SolaPanelR", SoyuzParts["SolarPanelL"]:GETMODULE("SSTUAnimateUsable")	
).

declare global CurrentMode to "debug".
declare global Thrust to 0.
declare global Steer to 0.
declare global FuncList to list().
declare global LoopFlag to 0.

ExecMode("debug").

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
		

		LoopManager(0, UpdateTelemetry@).
		Tooggle().
		UpdateControls().
		set Controls["Vector"]["mVector"] to v(0, 0, 0).
		
		
		//wait until CurrentMode <> "debug".
		ModeController("ProximityOps1").

	}
	if (pMode = "Nothing") {
		UpdateControls().
		LoopManager(0, MFD@).
		set CurrentMode to "Nothing".
		wait until CurrentMode <> "Nothing".
		ModeController(CurrentMode).
	}
	if (pMode = "Boot") {
		
	}
	if (pMode = "Ascent") {
		set CurrentMode to "Ascent".
		wait until not CORE:MESSAGES:EMPTY.
		local Recieved to CORE:MESSAGES:POP.
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
		Tooggle().
		set Controls["Vector"]["mVector"] to v(0, 0, 0).
		wait 3.
		rcs on.
		
		stage.
		wait 1.
		AntennaController().
		ModeController("TPO").
	}
	else if (pMode = "TPO") {
		set CurrentMode to "TPO".
		
		local CurOrb to OrbitClass:copy.
		set CurOrb to UpdateOrbitParams(CurOrb).
		//-------------------------------------------------------Transfer to phasing orbit
		local TgtOrb to OrbitClass:copy.
		set TgtOrb["Pe"] to CurOrb["Pe"] - 1.
		set TgtOrb["Ap"] to Globals["R"] + 220*1000.
		set TgtOrb["Inc"] to CurOrb["Inc"].
		set TgtOrb["LAN"] to CurOrb["LAN"].
		set TgtOrb["AoP"] to CurOrb["AoP"].
		set TgtOrb to BuildOrbit(TgtOrb).
		wait 1.
		local MyNode to OrbitTransferDemo(CurOrb, TgtOrb).
		wait 1.
		ExecBurn(MyNode, 1).
		wait 1.
		
		ModeController("PhasingOrbit").
	}
	else if (pMode = "PhasingOrbit") {
		//-------------------------------------------------------Circularization
		set CurrentMode to "PhasingOrbit".
		local CurOrb to OrbitClass:copy.
		set CurOrb to UpdateOrbitParams(CurOrb).
		
		local TgtOrb to OrbitClass:copy.
		set TgtOrb["Pe"] to CurOrb["Ap"] - 1.
		set TgtOrb["Ap"] to CurOrb["Ap"] + 1.
		set TgtOrb["Inc"] to CurOrb["Inc"].
		set TgtOrb["LAN"] to CurOrb["LAN"].
		set TgtOrb["AoP"] to CurOrb["AoP"] + 180.
		set TgtOrb to BuildOrbit(TgtOrb).
		wait 1.
		local MyNode to OrbitTransferDemo(CurOrb, TgtOrb).
		wait 1.
		ExecBurn(MyNode, 1).
		
		ModeController("Rendezvous").
	}
	else if (pMode = "Rendezvous") {
		set CurrentMode to "Rendezvous".
		
		local CurOrb to OrbitClass:copy.
		set CurOrb to UpdateOrbitParams(CurOrb).
		
		set target to "ISS".
		local ISSOrb to OrbitClass:copy.
		set ISSOrb to UpdateOrbitParams(ISSOrb, target).
		
		local MyNode to RendezvouzTransfer(CurOrb, ISSOrb, ship:orbit:trueanomaly, target:orbit:trueanomaly, target).
		wait 1.
		ExecBurn(MyNode, 1).
		wait 1.
		
		ModeController("InjectingTargetOrbit").
	}
	else if (pMode = "InjectingTargetOrbit") {
		local CurOrb to OrbitClass:copy.
		set CurOrb to UpdateOrbitParams(CurOrb).
		
		set target to "ISS".
		
		local TgtOrb to OrbitClass:copy.
		set TgtOrb to UpdateOrbitParams(TgtOrb, target).
		set TgtOrb["LAN"] to CurOrb["LAN"].
		set TgtOrb to BuildOrbit(TgtOrb).
		wait 1.
		local MyNode is OrbitTransferDemo(CurOrb, TgtOrb).
		wait 1.
		ExecBurn(MyNode, 1).
		
		ModeController("ProximityOps1").
	}
	else if (pMode = "ProximityOps1") {			//30km to 2km
		set CurrentMode to "ProximityOps1".
		
		local CurOrb to OrbitClass:copy.					//Current ship orbit
		set CurOrb to UpdateOrbitParams(CurOrb).
		
		set target to "ISS".								//Current target orbit
		local TgtOrb to OrbitClass:copy.					
		set TgtOrb to UpdateOrbitParams(TgtOrb, target).
		
		local DelayTime to 200.								//Time before burn
			
		local CurMeanMotion to 360/CurOrb["T"].				//Ship mean motion
		local TgtMeanMotion to 360/TgtOrb["T"].				//Target mean motion
		local PhiDifference to TgtOrb["AoP"] - CurOrb["AoP"].		//Difference between AOPs
		
		
		print "Period: " + TgtOrb["T"].
		local n to sqrt(Globals["mu"]/((target:orbit:semimajoraxis)^3)).	//n used in CW Equations

		//---------------------------------------------------------------------------------------------------------------------Current Relative Position
		local CurE to EuclidNewtonianSolver(ship:orbit:meananomalyatepoch + 						//Ship's E at burn
			CurMeanMotion*((time:seconds + DelayTime) - ship:orbit:epoch), CurOrb).
			
		local TgtE to EuclidNewtonianSolver(target:orbit:meananomalyatepoch + 						//Target's E at burn
			TgtMeanMotion*((time:seconds + DelayTime) - target:orbit:epoch), TgtOrb).
			
		local CurPhi to 2*arctan(sqrt((1 + CurOrb["e"])/(1 - CurOrb["e"]))*tan(CurE/2)).			//Ship's true anomaly at burn
		local TgtPhi to 2*arctan(sqrt((1 + TgtOrb["e"])/(1 - TgtOrb["e"]))*tan(TgtE/2)).			//Target's true anomaly at burn
		local phPhi to CurPhi - (TgtPhi + PhiDifference).
		if (phPhi > 180)
			set phPhi to phPhi - 360.
		else if (phPhi < -180)
			set phPhi to phPhi + 360.
			
		local t to TgtOrb["T"] + 60.
		local CurPosVec to RatAngle(CurOrb, CurPhi).	//Ship Position after 120s							
		local TgtPosVec to RatAngle(TgtOrb, TgtPhi).	//Target Position after 120s
		set TgtPosVec:mag to TgtOrb["Ap"].
		local RelPosVec to TgtPosVec - CurPosVec.		//Relative Position Vector					
		print "Distance: " + RelPosVec:mag.
		local RelPosAng to vang(CurPosVec, RelPosVec).	//Angle Between RelativePositionVector and TargetLVLH

		local CurX to RelPosVec:mag * cos(RelPosAng).	//CURRENT X OFFSET
		//if (CurPosVec:mag < TgtPosVec:mag)
			//set CurX to -1*CurX.
		local CurY to RelPosVec:mag * sin(RelPosAng).	//CURRENT Y OFFSET
		if (phPhi < 0)
			set CurY to -1*CurY.
		local CurZ to 0.								//CURRENT Z OFFSET
		print "X offset: " + CurX.
		print "Y offset: " + CurY.
		print "Z offset: " + CurZ.
		
		//----------------------------------------------------------------------------------------------------------------------Target Relative Position
		local TgtX to 0.								//TARGET X OFFSET
		print "TgtX: " + TgtX.
		local TgtY to -500.								//TARGET Y OFFSET
		local TgtZ to 0.								//TARGET Z OFFSET
		
		//--------------------------------------------------------------------------------------------------------------------------------Build Matrixes
		local Rc to MatrixClass:copy.		//---------------Current Position Matrix
		set Rc["MatrixSelf"] to list(list(CurX),
									list(CurY),
									list(CurZ)
								).
		
		local Rt to MatrixClass:copy.		//---------------Target Position Matrix
		set Rt["MatrixSelf"] to list(list(TgtX),
									list(TgtY),
									list(TgtZ)
								).
		local Vct to Help(Rc, Rt, n, t).
		
		//----------------------------------------------------------------------------------------------------------------------Target Relative Velocity
		local CurTgtVx to Vct["MatrixSelf"][0][0].
		local CurTgtVy to Vct["MatrixSelf"][1][0].
		local CurTgtVz to Vct["MatrixSelf"][2][0].
		
		//------------------------------------------------------------------------------------------------------------Prepare Maneuver Node for Transfer
		set CurOrb to OrbitClass:copy.
		set CurOrb to UpdateOrbitParams(CurOrb).
		
		set TgtOrb to OrbitClass:copy.
		set TgtOrb to UpdateOrbitParams(TgtOrb, target).
		
		local TgtRelVx to RatAngle(TgtOrb, TgtPhi).
		set TgtRelVx:mag to CurTgtVx.
		local axis to ANNorm(TgtOrb["LAN"], TgtOrb["Inc"]):upvector.
		local TgtRelVy to vcrs(TgtRelVx, axis).
		set TgtRelVy:mag to CurTgtVy.
		local TgtRelVz to vcrs(TgtRelVy, TgtRelVx).
		set TgtRelVz:mag to CurTgtVz.
		local TgtRelVel to TgtRelVx + TgtRelVy + TgtRelVz.
		local TgtV to VatAngle(TgtOrb, TgtPhi) + TgtRelVel.
		
		local CurV to VatAngle(CurOrb, CurPhi).
		
		local MyNode to nodeFromV(RatAngle(CurOrb, CurPhi), CurV, TgtV).
		set MyNode:eta to DelayTime.
		add MyNode.
		wait until terminal:input:haschar.
		remove MyNode.
		ExecBurn(MyNode, 1).
		
		wait until false.
	}
	else if (pMode = "ProximityOps2") {			//5km to 0.5km
		set CurrentMode to "ProximityOps2".
	}
	else if (pMode = "Docking") {				//0.5km to 0km
		set CurrentMode to "Docking".
	}
	else if (pMode = "Docked") {
		set CurrentMode to "Docked".
	}
	else if (pMode = "Undock") {
		set CurrentMode to "Undock".
	}
	else if (pMode = "Deorbit") {
		set pMode to "Deorbit".
	}
	else if (pMode = "Reentry") {
		set pMode to "Reentry".
	}
}







declare function EngineController {
	declare parameter action to 0.
	
	if (action = 0) {
		if(ProgressModules["Engine"]:hasevent("shutdown engine"))
			ProgressModules["Engine"]:DOEVENT("shutdown engine").
	}
	else if (action = 1) {
		if(ProgressModules["Engine"]:hasevent("activate engine"))
			ProgressModules["Engine"]:DOEVENT("activate engine").
	}
}

declare function SolarController {
	declare parameter action to 1.
	
	if (action = 1) {
		ProgressModules["SolarPanels"]:DOEVENT("Deploy Solar Panels").
	}
	else if (action = 0) {
		ProgressModules["SolarPanels"]:DOEVENT("Retract Solar Panels").
	}
}

declare function AntennaController {
	declare parameter mode to 11.
	if (mode = 0) {
		if(ProgressModules["Antenna"]:hasevent("Deactivate"))
			ProgressModules["Antenna"]:DOEVENT("Deactivate").
	}
	else if (mode > 0) {
		if(ProgressModules["Antenna"]:hasevent("Activate"))
			ProgressModules["Antenna"]:DOEVENT("Activate").
		if (mode = 11) {
			//SatelliteManager()
		}
		else if (mode = 12) {
			ProgressModules["Antenna"]:SETFIELD("target", "ISS").
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
	set Telemetry["EngineThrust"] to 2.95.		//-------------CHANGE---------------------------------------------------------------------------------
	set Telemetry["EngineIsp"] to 302.
	set Telemetry["ThrusterThrust"] to 0.13.
	set Telemetry["ThrusterISP"] to 291.
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
		print "Hello there".
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
	LoopManager(0, SteerManager@).
	lock throttle to LoopManager() + Thrust.
}

declare function ExecBurn {
	declare parameter mnvrnode.
	declare parameter WarpFlag to 0.
	
	add mnvrnode.
	
	local UllageDeltaV is calcDeltaVfromBurnTime(3, Telemetry["ThrusterThrust"], Telemetry["ThrusterISP"]).
	local tm is CalcBurnTime(mnvrnode:deltav:mag - UllageDeltaV, Telemetry["EngineThrust"], Telemetry["EngineIsp"]).
	
	if (tm < 60)
		set WarpFlag to 0.
	
	wait until (vang(ship:facing:forevector, mnvrnode:deltav) < 2).
	local hi is time:seconds + mnvrnode:eta - (tm/2) - 30.
	
	Tooggle().
	wait 1.
	kuniverse:TimeWarp:WARPTO(hi).
	wait until (time:seconds > hi + 5).
	wait 1.
	Tooggle().
	wait 21.
	
	set Thrust to 1.
	set ship:control:fore to 1.
	wait 3.
	EngineController(1).
	set ship:control:fore to 0.
	
	wait 5.
	
	if (WarpFlag = 1) {
		set kuniverse:timewarp:mode to "PHYSICS".
		set kuniverse:timewarp:warp to 3.
	}
	
	wait tm - 15.
	
	set kuniverse:timewarp:mode to "PHYSICS".
	set kuniverse:timewarp:warp to 0.
	
	wait 5.
	remove nextnode.
	wait 5.
	
	set Thrust to 0.
	EngineController(0).
	set Controls["Vector"]["mVector"] to v(0, 0, 0).
}

declare function Help {
	declare parameter Rc.
	declare parameter Rt.
	declare parameter n.
	declare parameter t.
	
	local ang to n*t.
	set ang to (ang*180)/constant:pi.
	
	local Mtrans to MatrixClass:copy.	//---------------Mtransition Matrix
	set Mtrans["MatrixSelf"] to list(list(4-3*cos(ang), 	   0, 0),
									 list(6*(sin(ang) - n*t),  1, 0),
									 list(0,                   0, cos(ang))
									 ).
	local Ntrans to MatrixClass:copy.	//---------------Ntransition Matrix
	set Ntrans["MatrixSelf"] to list(list((1/n)*sin(ang),          (2/n)*(1 - cos(ang)),     				0),
									 list(-1*(2/n)*(1 - cos(ang)), (1/n)*(4*sin(ang)-3*n*t), 				0),
									 list(0,                       						  0,   (1/n)*sin(ang))
									 ).
	//----------------------------------------------------------------------Compute Target Relative Velocity Matrix								 
	local NtransInv to MatrixFindInverse(Ntrans).
	local MRc to MatrixMultiply(Mtrans, Rc).
	local RtMrc to MatrixSubtract(Rt, MRc).
	local Vct is MatrixMultiply(NtransInv, RtMrc). //Target Relative Velocity Matrix
	return Vct.
}

	







