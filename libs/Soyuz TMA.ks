@lazyglobal off.
clearscreen.
set config:ipu to 1000.
//-------------------------------------Import Libraries----------------------------------------
LOCAL storagePath is "1:".
if not exists(storagePath + "/libs") {
	createdir(storagePath + "/libs").
}
FUNCTION libDl {
	parameter libs is list().

	for lib in libs {
		//if not exists(storagePath + "/libs/" + lib + ".ks") {
			copypath("0:/libs/" + lib + ".ks", storagePath + "/libs/").
			//compile ("0:/libs/" + lib + ".ks") to ( storagePath + "/libs/" + lib + ".ksm").
		//}
	}
	for lib in libs {
		runpath(storagePath + "/libs/" + lib + ".ks").
		//runpath(storagePath + "/libs/" + lib + ".ksm").
	}
}
libDl(list("general_functions", "math", "SteeringManager", "misc")).

DECLARE GLOBAL Systems to lexicon(
						"Engine", ship:partstitled("Soyuz TM/TMA/MS Service Module")[0]:GETMODULE("ModuleEnginesRF")
).

DECLARE GLOBAL Specs to lexicon(
						"EngineThrust", 2.95,
						"EngineIsp", 302,
						"UllageRcsThrust", 0.13*4,
						"UllageRcsIsp", 291
).

DECLARE GLOBAL CurrentMode TO 0.
DECLARE GLOBAL Thrust TO 0.
DECLARE GLOBAL FuncList TO list().
DECLARE GLOBAL LoopFlag TO 0.
DECLARE GLOBAL ArrivalTime TO 0.
DECLARE GLOBAL testFlag TO 0.

declare function ModeController {
	declare parameter TargetMode.
	set CurrentMode to TargetMode.
}

ModeController("ParkingOrbit").



UNTIL (CurrentMode = "Shutdown") {
	IF (CurrentMode = "BurnDebug") {

		rcs on.
		SteeringManagerMaster(1).
		SteeringManagerSetVector().
		LoopManager(0, SteeringManager@).
		LOCK THROTTLE TO Thrust + LoopManager().

		declare local curOrbit to OrbitClass:copy.
		set curOrbit to UpdateOrbitParams(curOrbit).

		declare local tgtOrbit to curOrbit:copy.
		set tgtOrbit["Ap"] to tgtOrbit["Ap"] + 100000.
		BuildOrbit(tgtOrbit).

		declare local burn to OrbitTransferDemo(curOrbit, tgtOrbit).
		print "test".

		ExecBurnNew(burn, curOrbit, tgtOrbit).

		ModeController("Shutdown").
	}
	ELSE IF (CurrentMode = "debug") {
		local basis is lexicon("x", v(1, 1, 0), "y", v(-1, 1, 0), "z", VCRS(v(1, 1, 0), v(-1, 1, 0))).
		local vec is v(1, 0, 0).
		local new_vec is convertToLVLH(basis, vec).
		print new_vec.

		wait 1000.
		ModeController("Shutdown").
	}
	ELSE IF (CurrentMode = "Nothing") {
		WAIT UNTIL CurrentMode <> "Nothing".
	}
	ELSE IF (CurrentMode = "Ascent") {
		WAIT UNTIL (not CORE:MESSAGES:EMPTY).
		IF (not CORE:MESSAGES:EMPTY) {
			LOCAL Recieved TO CORE:MESSAGES:POP.
			IF Recieved:content = "Successful ascent" {
				ModeController("ParkingOrbit").
			}
		}
		ELSE
			ModeController("Decouple").
	}
	ELSE IF (CurrentMode = "ParkingOrbit") {
		SteeringManagerMaster(1).
		SteeringManagerSetVector().
		LoopManager(0, SteeringManager@).
		LOCK THROTTLE TO Thrust + LoopManager().
		//LOCK LoopManagerVar TO LoopManager().
		ModeController("TerminalPhaseInitiation").
	}
	ELSE IF (CurrentMode = "Decouple") {
		RCS ON.
		WAIT 2.
		STAGE.
		SET SHIP:CONTROL:FORE TO 1.
		WAIT 2.
		SET SHIP:CONTROL:FORE TO 0.
		WAIT 1.
		ModeController("Insertion").
	}
	ELSE IF (CurrentMode = "Insertion") {
		SET CONFIG:IPU TO 1000.
		LOCAL CurrentOrbit IS OrbitClass:copy.
		SET CurrentOrbit TO UpdateOrbitParams(CurrentOrbit).

		LOCAL TargetOrbit IS OrbitClass:copy.
		SET TargetOrbit["Ap"] to 210*1000 + Globals["R"].
		SET TargetOrbit["Pe"] to 209*1000 + Globals["R"].
		SET TargetOrbit["Inc"] to CurrentOrbit["Inc"].
		SET TargetOrbit["LAN"] to CurrentOrbit["LAN"].
		SET TargetOrbit["AoP"] to CurrentOrbit["AoP"].

		SET TargetOrbit TO BuildOrbit(TargetOrbit).

		LOCAL InsertionBurn IS OrbitTransferDemo(CurrentOrbit, TargetOrbit).

		ExecBurnNew(InsertionBurn, CurrentOrbit, TargetOrbit).

		WAIT 5.

		ModeController("CoellipticPhase").
	}
	ELSE IF (CurrentMode = "CoellipticPhase") {
		SET TARGET TO "Soyuz Docking Target".

		LOCAL CurrentOrbit IS OrbitClass:COPY.
		SET CurrentOrbit TO UpdateOrbitParams(CurrentOrbit).

		LOCAL TargetOrbit IS OrbitClass:COPY.
		SET TargetOrbit TO UpdateOrbitParams(TargetOrbit, TARGET:ORBIT).

		LOCAL RBarDistance IS 5.
		LOCAL YBarDistance IS 30.

		LOCAL burn is RendezvousTransferDemo(CurrentOrbit, TargetOrbit, YBarDistance, RBarDistance, SHIP:ORBIT:TRUEANOMALY, TARGET:ORBIT:TRUEANOMALY).
		IF(burn["node"] = "none") {
			LOCAL warpToTime IS time:seconds + burn["warpTime"].
			SET kuniverse:timewarp:mode TO "RAILS".
			KUNIVERSE:TIMEWARP:WARPTO(warpToTime).
			WAIT UNTIL (TIME:SECONDS > warpToTime + 2).
			set burn to RendezvousTransferDemo(CurrentOrbit, TargetOrbit, YBarDistance, RBarDistance, SHIP:ORBIT:TRUEANOMALY, TARGET:ORBIT:TRUEANOMALY).
		}

		set burn["depTime"] to burn["depTime"] + TIME:SECONDS.
		local depR to RatAngle(CurrentOrbit, AngleAtT(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY, burn["depTime"] - TIME:SECONDS)).
		local depV to VatAngle(CurrentOrbit, AngleAtT(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY, burn["depTime"] - TIME:SECONDS)) + burn["dV"].
		LOCAL transferOrbit is BuildOrbitFromVR(depV, depR).

		local trueBurn to OrbitTransferDemo(CurrentOrbit, transferOrbit).

		ExecBurnNew(trueBurn, CurrentOrbit, transferOrbit).
		WAIT 2.
		SET arrivalTime TO burn["arrivalTime"].
		ModeController("Circularization").
	}
	ELSE IF (CurrentMode = "Circularization") {
		SET TARGET TO "Soyuz Docking Target".
		LOCAL CurrentOrbit IS OrbitClass:COPY.
		SET CurrentOrbit TO UpdateOrbitParams(CurrentOrbit).

		LOCAL TargetOrbit IS OrbitClass:COPY.
		SET TargetOrbit TO UpdateOrbitParams(TargetOrbit, TARGET:ORBIT).

		LOCAL CircularizationOrbit IS CurrentOrbit:COPY.
		LOCAL arrivalAltitude IS RatAngle(CurrentOrbit, AngleAtT(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY, arrivalTime - TIME:SECONDS)).
		SET CircularizationOrbit["Ap"] TO TargetOrbit["Ap"] - 5000.
		SET CircularizationOrbit["Pe"] TO CircularizationOrbit["Ap"] - 100.
		SET CircularizationOrbit["Inc"] TO TargetOrbit["Inc"].
		SET CircularizationOrbit["LAN"] TO TargetOrbit["LAN"].
		SET CircularizationOrbit["AoP"] TO (CurrentOrbit["AoP"] + AngleAtT(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY, arrivalTime - TIME:SECONDS)) - 180.
		IF(CircularizationOrbit["AoP"] < 0)
			SET CircularizationOrbit["AoP"] TO CircularizationOrbit["AoP"] + 360.
		SET CircularizationOrbit TO BuildOrbit(CircularizationOrbit).

		LOCAL CircularizationBurn IS OrbitTransferDemo(CurrentOrbit, CircularizationOrbit).
		ExecBurnNew(CircularizationBurn, CurrentOrbit, CircularizationOrbit).
		WAIT 2.
		ModeController("TerminalPhaseInitiation").
	}
	ELSE IF (CurrentMode = "TerminalPhaseInitiation") {
		SET TARGET TO "Soyuz Docking Target".
		LOCAL ISS IS Vessel("Soyuz Docking Target").

		wait 2.

		LOCAL CurrentOrbit IS OrbitClass:COPY.
		SET CurrentOrbit TO UpdateOrbitParams(CurrentOrbit).

		LOCAL TargetOrbit IS OrbitClass:COPY.
		SET TargetOrbit TO UpdateOrbitParams(TargetOrbit, ISS:ORBIT).

		LOCAL chaserPosition TO 0.
		LOCAL targetPosition TO 0.
		LOCAL chaserVelocity TO 0.
		LOCAL targetVelocity TO 0.

		LOCAL state to 0.

		UNTIL (FALSE) {
			SET chaserPosition TO RatAngle(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY).
			SET targetPosition TO RatAngle(TargetOrbit, ISS:ORBIT:TRUEANOMALY).

			SET chaserVelocity TO VatAngle(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY).
			SET targetVelocity TO VatAngle(TargetOrbit, ISS:ORBIT:TRUEANOMALY).

			SET state TO CWequationFutureFromCurrent(
				chaserPosition,
				chaserVelocity,
				0,
				TargetOrbit,
				targetPosition,
				targetVelocity
			).

			clearscreen.
			print "Current state: " at (0, 0).
			print "posX: " + state:LVLHcurrentR:X at (0, 1).
			print "posY: " + state:LVLHcurrentR:Y at (0, 2).
			print "posZ: " + state:LVLHcurrentR:Z at (0, 3).

			print "velX: " + state:LVLHcurrentV:X at (0, 5).
			print "velY: " + state:LVLHcurrentV:Y at (0, 6).
			print "velZ: " + state:LVLHcurrentV:Z at (0, 7).

			print "Future state: " at (0, 9).
			print "posX: " + state:LVLHfutureR:X at (0, 10).
			print "posY: " + state:LVLHfutureR:Y at (0, 11).
			print "posZ: " + state:LVLHfutureR:Z at (0, 12).
		}
	}
}
