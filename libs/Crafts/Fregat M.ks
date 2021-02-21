@lazyglobal off.
clearscreen.
//-------------------------------------Import Libraries----------------------------------------
LOCAL storagePath is "1:".
if not exists(storagePath + "/libs") {
	createdir(storagePath + "/libs").
}
FUNCTION libDl {
	parameter libs is list().

	for lib in libs {
		if not exists(storagePath + "/libs/" + lib + ".ks") {
			copypath("0:/libs/" + lib + ".ks", storagePath + "/libs/").
		}
	}
	for lib in libs {
		runpath(storagePath + "/libs/" + lib + ".ks").
	}
}
libDl(list("general_functions", "math", "SteeringManager", "misc")).

DECLARE GLOBAL Systems to lexicon(
						"Engine", ship:partstitled("R7 Fregat M")[0]:GETMODULE("ModuleEnginesRF")
).

DECLARE GLOBAL Specs to lexicon(
						"EngineThrust", 20.01,
						"EngineIsp", 333.2
).

DECLARE GLOBAL CurrentMode TO 0.
DECLARE GLOBAL Thrust TO 0.
DECLARE GLOBAL FuncList TO list().
DECLARE GLOBAL LoopFlag TO 0.

declare function ModeController {
	declare parameter TargetMode.
	set CurrentMode to TargetMode.
}

ModeController("Ascent").

UNTIL (CurrentMode = "Shutdown") {
	IF (CurrentMode = "debug") {

		set config:ipu to 1000.
		SteeringManagerMaster(1).
		SteeringManagerSetMode().
		LoopManager(0, SteeringManager@).
		LOCK THROTTLE TO Thrust + LoopManager().
		//SteeringManagerSetMode("Vector", SHIP:FACING:FOREVECTOR*-1).
		wait 1000.

		ModeController("Shutdown").
	}
	ELSE IF (CurrentMode = "Nothing") {
		WAIT UNTIL CurrentMode <> "Nothing".
	}
	ELSE IF (CurrentMode = "Ascent") {
		//SET CONFIG:IPU TO 10.
		WAIT UNTIL (not CORE:MESSAGES:EMPTY).
		IF (not CORE:MESSAGES:EMPTY) {
			LOCAL Recieved TO CORE:MESSAGES:POP.
			IF Recieved:content = "Successful ascent" {
				ModeController("ParkingOrbit").
			}
			ELSE IF Recieved:content = "Load mission" {
				LOCAL MissionName to CORE:MESSAGES:POP.
				RUNPATH("0:/missions/Soyuz/" + MissionName:content + ".ks").
				DECLARE GLOBAL Mission to FregatMission.
			}
		}
		ELSE
			ModeController("ParkingOrbit").
	}
	ELSE IF (CurrentMode = "ParkingOrbit") {
		set config:ipu to 1000.
		SteeringManagerMaster(1).
		SteeringManagerSetMode().
		LoopManager(0, SteeringManager@).
		LOCK THROTTLE TO Thrust + LoopManager().
		ModeController("Decouple").
		//ModeController("ActiveStage").
	}
	ELSE IF (CurrentMode = "Decouple") {
		RCS ON.
		WAIT 2.
		STAGE.
		SET SHIP:CONTROL:FORE TO 1.
		WAIT 2.
		SET SHIP:CONTROL:FORE TO 0.
		WAIT 1.
		ModeController("ActiveStage").
	}
	ELSE IF (CurrentMode = "ActiveStage") {
		if (Mission["Orbit Type"] = "GSO")
			ModeController("GSO").
		else if (Mission["Orbit Type"] = "General Orbit")
			ModeController("RegularTransfer").
	}
	ELSE IF (CurrentMode = "RegularTransfer") {
		LOCAL CurrentOrbit IS OrbitClass:copy.
		SET CurrentOrbit TO UpdateOrbitParams(CurrentOrbit).

		LOCAL TargetOrbit IS OrbitClass:copy.
		SET TargetOrbit["Ap"] to Mission["Apoapsis"]*1000 + Globals["R"].
		SET TargetOrbit["Pe"] to Mission["Periapsis"]*1000 + Globals["R"].
		SET TargetOrbit["Inc"] to CurrentOrbit["Inc"].
		SET TargetOrbit["LAN"] to CurrentOrbit["LAN"].
		if (Mission["AoP"] <> "Any")
			set TargetOrbit["AoP"] to Mission["AoP"].
		else
			set TargetOrbit["AoP"] to 180.
		SET TargetOrbit TO BuildOrbit(TargetOrbit).
		LOCAL InclinationDifference IS CurrentOrbit["Inc"] - TargetOrbit["Inc"].

		LOCAL DummyTransferOrbit IS OrbitClass:copy.
		SET DummyTransferOrbit["Ap"] to Mission["Periapsis"]*1000 + Globals["R"].
		SET DummyTransferOrbit["Inc"] to CurrentOrbit["Inc"].
		SET DummyTransferOrbit["LAN"] to CurrentOrbit["LAN"].
		SET DummyTransferOrbit["AoP"] to TargetOrbit["AoP"] + 180.
		SET DummyTransferOrbit["Pe"] to RatAngle(CurrentOrbit, DummyTransferOrbit["AoP"]):MAG.
		SET DummyTransferOrbit to BuildOrbit(DummyTransferOrbit).

		LOCAL DummyTransferBurn IS OrbitTransferDemo(CurrentOrbit, DummyTransferOrbit).

		ExecBurnNew(DummyTransferBurn, CurrentOrbit, DummyTransferOrbit, 5).

		SET CurrentOrbit TO UpdateOrbitParams(CurrentOrbit).
		LOCAL FinalizationBurn IS OrbitTransferDemo(CurrentOrbit, TargetOrbit).
		ExecBurnNew(FinalizationBurn, CurrentOrbit, TargetOrbit, 5).
		ModeController("PayloadRelease").
	}
	ELSE IF (CurrentMode = "PayloadRelease") {
		SteeringManagerSetMode().
		WAIT 15.
		RCS OFF.
		IF (Mission:HASKEY("PayloadProcessor")) {
			local msg to "Deploy".
			local p to PROCESSOR("Payload").
			p:PART:CONTROLFROM().
			p:CONNECTION:SENDMESSAGE(msg).
		}
		ELSE
			STAGE.
		wait 60.
		RCS ON.
		SteeringManagerSetMode("Vector", SHIP:VELOCITY:ORBIT*-1).
		wait 120.
		SET SHIP:CONTROL:FORE TO 1.
		WAIT 10.
		SET SHIP:CONTROL:FORE TO 0.
		WAIT 30.
		ModeController("Deorbit").
	}
	ELSE IF (CurrentMode = "Deorbit") {
		SteeringManagerSetMode("Vector", SHIP:VELOCITY:ORBIT*-1).
		WAIT UNTIL (VANG(SHIP:FACING:FOREVECTOR, SHIP:VELOCITY:ORBIT*-1) < 2).

		SET SHIP:CONTROL:FORE TO 1.
		WAIT 5.
		EngineController(Systems["Engine"], 1).
		SET SHIP:CONTROL:FORE TO 0.

		LOCAL shutdown TO FALSE.
		UNTIL (shutdown = TRUE) {
			SteeringManagerSetMode("Vector", SHIP:VELOCITY:ORBIT*-1).
			IF (SHIP:VELOCITY:ORBIT:MAG < 3000)
				SET shutdown TO TRUE.
		}
		EngineController(Systems["Engine"], 0).
		RCS OFF.

		ModeController("Shutdown").
	}
}
