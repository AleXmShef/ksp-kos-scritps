@lazyglobal off.
clearscreen.
//-------------------------------------Breeze-M Flight Plan----------------------------------------
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
libDl(list("general_functions", "math", "SteeringManager")).

//Main Rocket Parameters---------------------------------------------------------------------------

//Main Body----------------------------------------------------------------------------------------
declare global Mission to lexicon(
						"Orbit Type", "GSO",
						"Inclination", 0,
						"Longitude", 189,
						"Apoapsis", 2500,
						"Periapsis", 2700,
						"AoP", "Any",
						"LAN", "25",
						"CubeSatDeploy", 0
).

declare global BreezeM to lexicon(
						"Engine", ship:partstitled("S5.98M")[0]:GETMODULE("ModuleEnginesRF"),
						"Antenna", 0
).

declare global Telemetry is lexicon(
				"Orbit", 0,
				"TrueAnomaly", 0,
				"EngineThrust", 0,
				"EngineIsp", 0,
				"SolarPower", 0,
				"Fuel", 0
).

declare global Serializable is lexicon(
				"LastMode", "Ascent",
				"SolarDeploy", 0,
				"AntennaActive", 0,
				"DockedToISS", 0,
				"AbortMode", 0,
				"EngineStatus", 0,
				"ReadyFromParkingOrbit", 0
).

declare global BurnTelemetryLexicon is lexicon(
	"mnvrnode", 0,
	"burnendtime", 0,
	"burnstarttime", 0,
	"velocityAfterBurn", 0,
	"apoapsisAfterBurn", 0,
	"periapsisAfterBurn", 0
).

declare global CurrentMode to "Ascent".
declare global Thrust to 0.
declare global FuncList to list().
declare global LoopFlag to 0.

ModeController("Ascent").

declare function ModeController {
	declare parameter TargetMode.
	set CurrentMode to TargetMode.
}

set config:ipu to 2000.

until (CurrentMode = "Shutdown") {
	if (CurrentMode = "debug") {
		set config:ipu to 2000.
		wait until terminal:input:haschar.
		LoopManager(0, UpdateTelemetry@).
		UpdateControls().
		SteeringManagerMaster(1).
		SteeringManagerSetVector().
		rcs on.
		ModeController("GSOdemo").
	}
	else if (CurrentMode = "Nothing") {
		wait until CurrentMode <> "Nothing".
		ModeController(CurrentMode).
	}
	else if (CurrentMode = "Ascent") {
		wait until (not CORE:MESSAGES:EMPTY or terminal:input:haschar).
		if (not CORE:MESSAGES:EMPTY) {
			local Recieved to CORE:MESSAGES:POP.
			if Recieved:content = "Successful ascent" {
				ModeController("ParkingOrbit").
			} 
			else if Recieved:content = "Load mission" {
				local MissionName to CORE:MESSAGES:POP.
				runpath("0:/missions/Proton/" + MissionName:content + ".ks").
				global Mission to BreezeMission.
			}
		}
		else
			ModeController("ParkingOrbit").
	}
	else if (CurrentMode = "ParkingOrbit") {
		set config:ipu to 2000.
		wait until terminal:input:haschar.
		LoopManager(0, UpdateTelemetry@).
		UpdateControls().
		SteeringManagerMaster(1).
		SteeringManagerSetVector().
		wait 1.
		rcs on.
		wait 1.
		stage.
		wait 1.
		ModeController("ActiveStage").
	}
	else if (CurrentMode = "ActiveStage") {
		if (Mission["Orbit Type"] = "GSO") 
			ModeController("GSOdemo").
		else if (Mission["Orbit Type"] = "General Orbit")
			ModeController("RegularTransfer").
	}
	else if (CurrentMode = "GSO") {
		local CurOrb to OrbitClass:copy.
		set CurOrb to UpdateOrbitParams(CurOrb).
		local params to FindGSOtransferOrbitAltitude(CurOrb, Mission["Longitude"]).
		
		kuniverse:TimeWarp:WARPTO(time:seconds + CurOrb["T"] * params[1]).
		wait CurOrb["T"] * params[1].
		
		wait 3.
		
		local tOrb to OrbitClass:copy.
		set tOrb["Ap"] to params[0].
		set tOrb["Pe"] to RatAngle(CurOrb, 360 - CurOrb["AoP"]):mag - 10.
		set tOrb["Inc"] to CurOrb["Inc"].
		set tOrb["LAN"] to CurOrb["LAN"].
		set tOrb["AoP"] to 0.
		set tOrb to BuildOrbit(tOrb).
		wait 1.
		local MyNode to OrbitTransferDemo(CurOrb, tOrb).
		wait 1.
		ExecBurn(MyNode, 1).
		
		wait 1.
		
		set CurOrb to UpdateOrbitParams(CurOrb).
		
		set tOrb["Ap"] to 35786 * 1000 + Globals["R"].
		set tOrb["Pe"] to CurOrb["Ap"] - 100.
		set tOrb["Inc"] to CurOrb["Inc"].
		set tOrb["LAN"] to CurOrb["LAN"].
		set tOrb["AoP"] to 180.
		set tOrb to BuildOrbit(tOrb).
		wait 1.
		set MyNode to OrbitTransferDemo(CurOrb, tOrb).
		wait 1.
		ExecBurn(MyNode, 1).
		wait 1.
		
		wait 2.
		
		stage.
		
		wait 2.
		
		set CurOrb to UpdateOrbitParams(CurOrb).
		
		set tOrb["Ap"] to CurOrb["Ap"] - 50.
		set tOrb["Pe"] to (((Globals["mu"]*(86164.09054)^2)/(4*(CONSTANT:PI^2)))^(1/3))*2 - (CurOrb["Ap"]).
		print tOrb["Pe"] at (0, 2).
		set tOrb["Inc"] to Mission["Inclination"].
		set tOrb["LAN"] to CurOrb["LAN"].
		if (tOrb["Pe"] > tOrb["Ap"]) {
			local temp to tOrb["Pe"].
			set tOrb["Pe"] to tOrb["Ap"].
			set tOrb["Ap"] to temp.
			set tOrb["AoP"] to 0.
		}
		else 
			set tOrb["AoP"] to 180.
		set tOrb to BuildOrbit(tOrb).
		wait 1.
		set MyNode to OrbitTransferDemo(CurOrb, tOrb).
		wait 1.
		ExecBurn(MyNode).
		wait 1.
		ModeController("PayloadRelease").
	}
	else if (CurrentMode = "RegularTransfer") {
		print "debug".
		local CurOrb to OrbitClass:copy.
		set CurOrb to UpdateOrbitParams(CurOrb).
		
		if (Mission["CubeSatDeploy"] = 1)
			stage.
		
		local TgtOrb to OrbitClass:copy.
		set TgtOrb["Ap"] to Mission["Apoapsis"]*1000 + Globals["R"].
		set TgtOrb["Pe"] to Mission["Periapsis"]*1000 + Globals["R"].
		set TgtOrb["Inc"] to Mission["Inclination"].
		set TgtOrb["LAN"] to CurOrb["LAN"].
		if (Mission["AoP"] <> "Any")
			set TgtOrb["AoP"] to Mission["AoP"].
		else
			set TgtOrb["AoP"] to 180.
		set TgtOrb to BuildOrbit(TgtOrb).
		wait 1.
		
		local TrOrb to OrbitClass:copy.
		set TrOrb["Ap"] to TgtOrb["Ap"].
		local DNang to (360 - CurOrb["AoP"]) + 180.
		if (DNang > 360)
			set DNang to DNang - 360.
		set TrOrb["Pe"] to RatAngle(CurOrb, DNang):mag - 1.
		set TrOrb["AoP"] to 180.
		set TrOrb["LAN"] to CurOrb["LAN"].
		set TrOrb["Inc"] to CurOrb["Inc"].
		wait 1.
		set TrOrb to BuildOrbit(TrOrb).
		wait 1.
		local MyNode to OrbitTransferDemo(CurOrb, TrOrb).
		wait 1.
		ExecBurn(MyNode, 1).
		wait 2.
		
		set CurOrb to UpdateOrbitParams(CurOrb).
		
		set TrOrb["Ap"] to CurOrb["Ap"] - 1.
		set TrOrb["Pe"] to TgtOrb["Pe"].
		set TrOrb["Inc"] to TgtOrb["Inc"].
		set TrOrb["AoP"] to 180.
		set TrOrb["LAN"] to CurOrb["LAN"].
		wait 1.
		set TrOrb to BuildOrbit(TrOrb).
		wait 1.
		set MyNode to OrbitTransferDemo(CurOrb, TrOrb).
		wait 1.
		ExecBurn(MyNode, 1).
		
		ModeController("PayloadRelease").
	}
	else if (CurrentMode = "GSOdemo") {
		local currentOrbit to OrbitClass:copy.
		set currentOrbit to UpdateOrbitParams(currentOrbit).
		local transferOrbits to FindGSOtransferOrbitAltitudeDemo(Mission["Longitude"], ship, currentOrbit).
		//-------------------------------------------------------------------------------------First transfer
		local firstTransferManeuver to OrbitTransferDemo(currentOrbit, transferOrbits[0]).
		wait 1.
		ExecBurn(firstTransferManeuver, 1).
		wait 1.
		//-------------------------------------------------------------------------------------Coasting
		set currentOrbit to UpdateOrbitParams(currentOrbit).
		local secondTransferOrbit to transferOrbits[1]:copy.
		if(transferOrbits[2] - 0.5 >= 1) {
			local currentPeriod to currentOrbit["T"].
			local mult to transferOrbits[2] - 0.5.
			local warpToTime to time:seconds + currentOrbit["T"]*mult.
			set kuniverse:TimeWarp:MODE to "RAILS".
			kuniverse:TimeWarp:WARPTO(warpToTime).
			wait until (time:seconds > warpToTime + 5).
		}
		//-------------------------------------------------------------------------------------Second transfer
		set secondTransferOrbit["Pe"] to currentOrbit["Ap"].
		set secondTransferOrbit to BuildOrbit(secondTransferOrbit).
		local secondTransferManeuver to OrbitTransferDemo(currentOrbit, secondTransferOrbit).
		wait 1.
		ExecBurn(secondTransferManeuver, 1).
		wait 3.
		//-------------------------------------------------------------------------------------Tank separation
		stage.
		wait 5.
		//-------------------------------------------------------------------------------------Final insertion
		set currentOrbit to UpdateOrbitParams(currentOrbit).
		local finalOrbit to OrbitClass:copy.
		if((currentOrbit["Ap"] - Globals["R"])/1000 < 35786) {
			set finalOrbit["Ap"] to 35786*1000 + Globals["R"].
			set finalOrbit["Pe"] to currentOrbit["Ap"].
			set finalOrbit["AoP"] to currentOrbit["AoP"] + 180.
		}
		else {
			set finalOrbit["Pe"] to 35786*1000 + Globals["R"].
			set finalOrbit["Ap"] to currentOrbit["Ap"].
			set finalOrbit["AoP"] to currentOrbit["AoP"].
		}
		set finalOrbit["LAN"] to currentOrbit["LAN"].
		set finalOrbit["Inc"] to 0.1.
		set finalOrbit to BuildOrbit(finalOrbit).
		local insertionBurn to OrbitTransferDemo(currentOrbit, finalOrbit).
		wait 1.
		ExecBurn(insertionBurn, 1).
		wait 1.
		ModeController("PayloadRelease").
	}
	else if (CurrentMode = "PayloadRelease") {
		local msg to "Deploy".
		local p to PROCESSOR("Payload").
		p:PART:CONTROLFROM().
		p:CONNECTION:SENDMESSAGE(msg).
		wait 20.
	}
	
}

declare function UpdateTelemetry {
	set Telemetry["TrueAnomaly"] to SHIP:ORBIT:TRUEANOMALY.
	set Telemetry["EngineThrust"] to 49.025 + 0.392*4.		
	set Telemetry["EngineIsp"] to (Telemetry["EngineThrust"])/(49.025/328 + (0.392/326)*4).	
	set Telemetry["UllageThrust"] to 0.392*4.
	set Telemetry["UllageISP"] to 326.
}

declare function FindGSOtransferOrbitAltitude {
	
	declare parameter orb1.
	declare parameter tgtLong to 0.
	
	
	local LatAtAN to Func1(orb1).
	
	if (tgtLong > LatAtAN)
		local MainTime to (360 - (tgtLong - LatAtAN))/Globals["EarthRotationSpeed"].
	else 
		local MainTime to (LatAtAN - tgtLong)/Globals["EarthRotationSpeed"].
		
	local EstPe to 5000 * 1000 + Globals["R"].
	
	local Correction to 9500 * 1000.
	local fflag to 0.
	
	local transforb1 to OrbitClass:copy.
	set transforb1["Pe"] to RatAngle(orb1, 360 - orb1["AoP"]):mag.
	set transforb1["Ap"] to EstPe.
	set transforb1["Inc"] to orb1["Inc"].
	set transforb1["LAN"] to orb1["LAN"].
	set transforb1["AoP"] to 0.
	set transforb1 to BuildOrbit(transforb1).
	
	local transforb2 to OrbitClass:copy.
	set transforb2["Pe"] to EstPe.
	set transforb2["Ap"] to 35000*1000 + Globals["R"].
	set transforb2["Inc"] to orb1["Inc"].
	set transforb2["LAN"] to orb1["LAN"].
	set transforb2["AoP"] to 180.
	set transforb2 to BuildOrbit(transforb2).
	
	local converged to 0.
	local converged2 to 0.
	
	local n to 0.
	
	until (converged <> 0) {
		until (converged2 <> 0) {
			local CurTime to transforb1["T"]/2 + transforb2["T"]/2.
			clearscreen.
			print (EstPe - Globals["R"])/1000 at (0, 0).
			print MainTime at (0, 7).
			print CurTime at (0, 8).
			//wait 1.
			if (EstPe - Globals["R"] < 0) {
				set EstPe to 0.
				set converged2 to 1.
			}
			else if (transforb1["Pe"] > EstPe or transforb2["Ap"] < EstPe) {
				set EstPe to 0.
				set converged2 to 1.
			}
			else if (abs(CurTime - MainTime) < 10)
				set converged2 to 1.
			else if (CurTime > MainTime) {
				if (fflag <> -1) {
					set Correction to Correction / 2.
					set fflag to -1.
				}
			
				set EstPe to EstPe - Correction.

				set transforb1["Ap"] to EstPe.
				set transforb1 to BuildOrbit(transforb1).
				set transforb2["Pe"] to EstPe.
				set transforb2 to BuildOrbit(transforb2).
			}
			else if (CurTime < MainTime) {
				if (fflag <> 1) {
					set Correction to Correction / 2.
					set fflag to 1.
				}
				set EstPe to EstPe + Correction.

				set transforb1["Ap"] to EstPe.
				set transforb1 to BuildOrbit(transforb1).
				set transforb2["Pe"] to EstPe.
				set transforb2 to BuildOrbit(transforb2).
			}
		}
		if((EstPe - Globals["R"])/1000 < 10000 and (EstPe - Globals["R"])/1000 > 2000) 
			set converged to 1.
		else {
			set n to n + 1.
			set LatAtAN to Func1(orb1, n).
			if (tgtLong > LatAtAN)
				set MainTime to (360 - (tgtLong - LatAtAN))/Globals["EarthRotationSpeed"].
			else 
				set MainTime to (LatAtAN - tgtLong)/Globals["EarthRotationSpeed"].
			set converged2 to 0.
			
			set EstPe to 19000 * 1000 + Globals["R"].
			set Correction to 9500 * 1000.
		}
	}
	
	print EstPe at (0, 0).
	wait 1.
	
	return list(EstPe, n).
}

declare function FindGSOtransferOrbitAltitudeDemo {
	declare parameter targetLongitude.
	declare parameter vessel.
	declare parameter departureOrbit.
	clearscreen.
	
	local earthsRotationRate to (360/(23*60*60 + 56*60)).
	
	local firstTransferOrbitPe to RatAngle(departureOrbit, 360 - departureOrbit["AoP"]):mag.
	local timeToFirstTransferOrbitPe to TtoR(departureOrbit, vessel:orbit:trueanomaly, 360 - departureOrbit["AoP"]).
	local currentLongitude to vessel:longitude.
	if(currentLongitude < 0)
		set currentLongitude to currentLongitude + 360.
	local departureLongitude to vessel:longitude - earthsRotationRate*timeToFirstTransferOrbitPe + (360/(departureOrbit["T"]))*timeToFirstTransferOrbitPe.
	if (departureLongitude > 360)
		set departureLongitude to departureLongitude - 360.

	
	
	
	local convergedFlag to 0.
	local operationFlag to 0.
	local coastTimeMultiplier to 1/2.
	local component to 100*1000.
	
	local transferOrbit1 to OrbitClass:copy.
	set transferOrbit1["Pe"] to firstTransferOrbitPe.
	set transferOrbit1["Ap"] to 12000*1000 + Globals["R"].
	
	local transferOrbit2 to OrbitClass:copy.
	set transferOrbit2["Ap"] to 35786*1000 + Globals["R"].
	set transferOrbit2["Pe"] to 12000*1000 + Globals["R"].
	
	until (convergedFlag <> 0) {
		clearscreen.
		print "departure longitude: " + departureLongitude at(0, 9).
		set transferOrbit1 to BuildOrbit(transferOrbit1).
		set transferOrbit2 to BuildOrbit(transferOrbit2).
		local calculatedLongitude to departureLongitude - earthsRotationRate*((transferOrbit1["T"]*coastTimeMultiplier)+(transferOrbit2["T"]/2)).
		if (calculatedLongitude > 360)
			set calculatedLongitude to calculatedLongitude - 360.
		if(calculatedLongitude < 0)
			set calculatedLongitude to calculatedLongitude + 360.
		if(transferOrbit1["Ap"] < (2000*1000 + Globals["R"])) {
			set coastTimeMultiplier to coastTimeMultiplier + 1.
			set transferOrbit1["Ap"] to 4000*1000 + Globals["R"].
			set transferOrbit2["Pe"] to 4000*1000 + Globals["R"].
			print "coast multiplier: " + coastTimeMultiplier.
		}
		else if((calculatedLongitude - targetLongitude <= -0.01)) {
			print "Long diff in deg1: " + (calculatedLongitude - targetLongitude) at (0, 11).
			print "calculatedLongitude: " + calculatedLongitude at(0,12).
			print "Apoapsis: " + ((transferOrbit1["Ap"] - Globals["R"])/1000) at (0, 13).
			print "Coast time: " + ((transferOrbit1["T"]/2)/3600) at (0, 14).
			if(operationFlag = 2)
				set component to component/2.
			set operationFlag to 1.
			set transferOrbit1["Ap"] to transferOrbit1["Ap"] - component.
			set transferOrbit2["Pe"] to transferOrbit2["Pe"] - component.
		}
		else if(calculatedLongitude - targetLongitude >= 0.01) {
			print "Long diff in deg2: " + (calculatedLongitude - targetLongitude) at (0, 11).
			print "calculatedLongitude: " + calculatedLongitude at(0,12).
			print "Apoapsis: " + ((transferOrbit1["Ap"] - Globals["R"])/1000) at (0, 13).
			print "Coast time: " + ((transferOrbit1["T"]/2)/3600) at (0, 14).
			if(operationFlag = 1)
				set component to component/2.
			set operationFlag to 2.
			set transferOrbit1["Ap"] to transferOrbit1["Ap"] + component.
			set transferOrbit2["Pe"] to transferOrbit2["Pe"] + component.
		}
		else {
			print "Long diff in deg2: " + (calculatedLongitude - targetLongitude) at (0, 11).
			print "calculatedLongitude: " + calculatedLongitude at(0,12).
			print "Apoapsis: " + ((transferOrbit1["Ap"] - Globals["R"])/1000) at (0, 13).
			print "Coast time: " + (((transferOrbit1["T"]/2)+(transferOrbit2["T"]/2))/3600) at (0, 14).
			print "Finished" at (0,10).
			set convergedFlag to 1.
			wait 1.
		}
	}
	set transferOrbit1["LAN"] to departureOrbit["LAN"].
	set transferOrbit1["AoP"] to 0.
	set transferOrbit1["Inc"] to departureOrbit["Inc"].
	set transferOrbit2["LAN"] to departureOrbit["LAN"].
	set transferOrbit2["AoP"] to 180.
	set transferOrbit2["Inc"] to departureOrbit["Inc"].
	clearscreen.
	return LIST(transferOrbit1, transferOrbit2, coastTimeMultiplier).
}







declare function EngineController {
	declare parameter action to 0.
	if (action = 0) {
		BreezeM["Engine"]:DOEVENT("shutdown engine").
		//SerializeManager("EngineStatus", 0).
	}
	else if (action = 1) {
		BreezeM["Engine"]:DOEVENT("activate engine").
		//SerializeManager("EngineStatus", 1).
	}
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
		local tList to FuncList:copy.
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
	WRITEJSON(Serializable, "BreezeM.json").
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
	LoopManager(0, SteeringManager@).
	lock throttle to LoopManager() + Thrust.
}

declare function BurnTelemetry {
	local apoapsisAfterBurn to BurnTelemetryLexicon["apoapsisAfterBurn"]/1000.
	local periapsisAfterBurn to BurnTelemetryLexicon["periapsisAfterBurn"]/1000.
	local velocityAfterBurn to BurnTelemetryLexicon["velocityAfterBurn"].
	
	local currentApoapsis to (ship:orbit:apoapsis)/1000.
	local currentPeriapsis to (ship:orbit:periapsis)/1000.
	local currentVeclocity to ship:velocity:orbit:mag.
	
	clearscreen.
	print "Apoapsis after burn: " + apoapsisAfterBurn at (0, 0).
	print "Current apoapsis: " + currentApoapsis at (0, 1).
	print "Apoapsis error: " + abs(apoapsisAfterBurn - currentApoapsis) at (0, 2).
	print "Periapsis after burn: " + periapsisAfterBurn at (0, 3).
	print "Current periapsis: " + currentPeriapsis at (0, 4).
	print "Periapsis error: " + abs(periapsisAfterBurn - currentPeriapsis) at (0, 5).
	print "Velocity after burn: " + velocityAfterBurn at (0, 6).
	print "Current velocity: " + currentVeclocity at (0, 7).
	if(HASNODE) {
		print "Velocity error: " + ALLNODES[0]:deltav:mag at (0, 8).
	}
	print "Burn eta: " + (BurnTelemetryLexicon["burnstarttime"] - time:seconds) at (0, 9).
	print "Meco eta: " + (BurnTelemetryLexicon["burnendtime"] - time:seconds) at (0, 10).
}

declare function ExecBurn {
	declare parameter mnode.
	declare parameter warpFlag to 1.
	
	local mnvrnode to mnode["node"].
	local tgtV to mnode["tgtV"].
	
	add mnvrnode.
	
	set Controls["Mode"] to "ManeuverNode".
	
	local ullageDeltaV is calcDeltaVfromBurnTime(3, Telemetry["UllageThrust"], Telemetry["UllageISP"]).
	
	local burnTime to CalcBurnTime(mnvrnode:deltav:mag - ullageDeltaV, Telemetry["EngineThrust"], Telemetry["EngineIsp"]).
	
	set BurnTelemetryLexicon["apoapsisAfterBurn"] to mnvrnode:orbit:apoapsis.
	set BurnTelemetryLexicon["periapsisAfterBurn"] to mnvrnode:orbit:periapsis.
	set BurnTelemetryLexicon["burnendtime"] to time:seconds + mnvrnode:eta + burnTime/2.
	set BurnTelemetryLexicon["burnstarttime"] to time:seconds + mnvrnode:eta - burnTime/2.
	set BurnTelemetryLexicon["velocityAfterBurn"] to tgtV.
	
	LoopManager(0, BurnTelemetry@).
	
	if (burnTime < 20)
		set warpFlag to 0.
	
	wait until (vang(ship:facing:forevector, mnvrnode:deltav) < 2).
	
	local warpToTime to time:seconds + mnvrnode:eta - (burnTime/2) - 25.
	
	SteeringManagerMaster(0).

	kuniverse:TimeWarp:WARPTO(warpToTime).
	
	wait until (time:seconds > warpToTime + 15).
	
	wait 1.
	
	SteeringManagerMaster(1).
	
	wait 7.
	
	set Thrust to 1.
	
	rcs off.
	
	wait 3.
	
	EngineController(1).
	
	wait until (BreezeM["Engine"]:getfield("Thrust") > 40).
	
	wait 4.
	
	if (warpFlag = 1) {
		set kuniverse:timewarp:mode to "PHYSICS".
		set kuniverse:timewarp:warp to 3.
	}
	
	wait until (mnvrnode:deltav:mag < 50).
	
	set kuniverse:timewarp:mode to "PHYSICS".
	set kuniverse:timewarp:warp to 0.
	
	set Controls["Mode"] to "Attitude".
	
	local dV to mnvrnode:deltav:mag.
	local convergedFlag to 0.
	until(convergedFlag <> 0) {
		if(mnvrnode:deltav:mag > dV)
			set convergedFlag to 1.
		else 
			set dV to mnvrnode:deltav:mag.
	}
	
	set Thrust to 0.
	
	EngineController(0).
	
	LoopManager(1, BurnTelemetry@).
	
	remove mnvrnode.
	
	rcs on.	
	
	wait 1.
	
}














 