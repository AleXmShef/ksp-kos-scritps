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
		local tr to getTransform(basis).
		local vec is v(-112, 450, -150).
		print vec.
		local new_vec is VectorMatrixMultiply(tr:Transform, vec).
		print new_vec.
		local new_vec2 to VectorMatrixMultiply(tr:Inverse, new_vec).
		print new_vec2.
		print vec:mag.
		print new_vec2:mag.
		print vec - new_vec2.

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

		local t to TIME:SECONDS + 3100.

		LOCAL state TO CWequationFutureFromCurrent(
			SHIP,
			ISS,
			0,
			t - TIME:SECONDS
		).

		LOCAL timeToRbar TO ABS(state:LVLHrelativePosition:Y)/ABS(state:LVLHrelativeVelocity:Y) + TIME:SECONDS.
		print (timeToRbar - TIME:SECONDS).

		local done is false.
		UNTIL (done = true) {

			LOCAL state2 TO CWequationCurrentVelFromFuturePos(
				SHIP,
				ISS,
				V(-1000, 0, 0),
				5,
				timeToRbar - TIME:SECONDS
			).

			LOCAL dV TO (state2:targetChaserVelocity - state2:chaserVelocity).
			CLEARVECDRAWS().
			vecdraw(v(0,0,0), dV, RGB(0,1,0), "pos", 1.0, true, 0.2, true, true).
			clearscreen.
			print dV:MAG at (0,0).
			print state2:LVLHrelativeVelocity at (0,2).
			print state2:targetLVLHrelativeVelocity at (0,4).
			print state2:LVLHrelativePosition at (0,6).


			local shipBasis to LEXICON("x", SHIP:FACING:STARVECTOR, "y", SHIP:FACING:UPVECTOR, "z", SHIP:FACING:FOREVECTOR).
			local shipBasis to getTransform(shipBasis).
			local dV_ to VCMT(shipBasis:Transform, dV).
			SET SHIP:CONTROL:TRANSLATION TO dV_.

			if(dV:MAG < 0.1) {
				set ship:control:neutralize to true.
				set done to true.
			}

			wait 0.1.
		}

		kuniverse:timewarp:WARPTO(timeToRbar).

	}
}
