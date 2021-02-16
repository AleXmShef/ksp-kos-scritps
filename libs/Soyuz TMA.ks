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
	IF (CurrentMode = "debug") {

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
	ELSE IF (CurrentMode = "debug2") {
		local curOrb to OrbitClass:copy.
		set curOrb to UpdateOrbitParams(curOrb).

		local testOrb to BuildOrbitFromVR(SHIP:VELOCITY:ORBIT, SHIP:POSITION - SHIP:BODY:POSITION).

		clearscreen.
		print curOrb.
		print "".
		print testOrb.
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

		LOCAL CurrentOrbit IS OrbitClass:COPY.
		SET CurrentOrbit TO UpdateOrbitParams(CurrentOrbit).

		LOCAL TargetOrbit IS OrbitClass:COPY.
		SET TargetOrbit TO UpdateOrbitParams(TargetOrbit, ISS:ORBIT).

		LOCAL soyuzAverageAngularVelocity IS 360/CurrentOrbit["T"].
		LOCAL targetAverageAngularVelocity IS 360/TargetOrbit["T"].

		LOCAL chaserPosition IS RatAngle(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY).
		LOCAL targetPosition IS RatAngle(TargetOrbit, ISS:ORBIT:TRUEANOMALY).


		LOCAL chaserVelocity IS VatAngle(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY).
		LOCAL targetVelocity IS VatAngle(TargetOrbit, ISS:ORBIT:TRUEANOMALY).

		DECLARE FUNCTION timeToRbarFunc {
			LOCAL timeToRbar IS 500.
			LOCAL additive IS 100.
			LOCAL pos IS LEXICON("y", 10000000000000).
			LOCAL converged IS FALSE.
			LOCAL counter IS 0.
			UNTIL (converged = TRUE) {
				SET timeToRbar TO timeToRbar + additive.
				LOCAL _pos IS CWequation(chaserPosition, chaserVelocity, timeToRbar, TargetOrbit, targetPosition, targetVelocity).
				IF (abs(_pos["y"]) > abs(pos["y"])) {
					if(counter > 0) {
						SET additive TO additive * -0.5.
						SET counter TO 0.
					}
					else
						SET counter TO counter + 1.
				}
				SET pos TO _pos.

				IF (abs(additive) < 0.01)
					SET converged TO TRUE.
			}
			RETURN timeToRbar.
		}
		local timeToRbar is timeToRbarFunc().
		LOCAL _timeToRbar IS time:seconds + timeToRbar.

		local RBarTargetPosition is RatAngle(TargetOrbit, AngleAtT(TargetOrbit, ISS:ORBIT:TRUEANOMALY, _timeToRbar - time:seconds)).
		local RBarChaserPosition is RBarTargetPosition:vec.
		set RBarChaserPosition:mag to RBarChaserPosition:MAG - 1000.

		SteeringManagerSetMode("Vessel", ISS).

		CWequationCorrectionBurn(RBarChaserPosition, _timeToRbar, ISS).

		LOCAL warpToTime IS _timeToRbar.
		KUNIVERSE:TIMEWARP:WARPTO(warpToTime -6*60).
		WAIT UNTIL (ISS:POSITION:MAG < 1600 AND VANG(SHIP:FACING:FOREVECTOR, ISS:POSITION) < 1).

		LOCAL arrivedToRbar IS FALSE.
		UNTIL (arrivedToRbar) {
			SET CurrentOrbit TO UpdateOrbitParams(CurrentOrbit).
			SET TargetOrbit TO UpdateOrbitParams(TargetOrbit, ISS:ORBIT).

			LOCAL chaserPosition IS RatAngle(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY).
			LOCAL targetPosition IS RatAngle(TargetOrbit, ISS:ORBIT:TRUEANOMALY).


			LOCAL chaserVelocity IS VatAngle(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY).
			LOCAL targetVelocity IS VatAngle(TargetOrbit, ISS:ORBIT:TRUEANOMALY).

			local RBarTargetPosition is RatAngle(TargetOrbit, AngleAtT(TargetOrbit, ISS:ORBIT:TRUEANOMALY, _timeToRbar - time:seconds)).
			local RBarChaserPosition is RBarTargetPosition:vec.
			set RBarChaserPosition:mag to RBarChaserPosition:MAG - 1000.

			LOCAL arrivalPos IS CWequation(chaserPosition, chaserVelocity, _timeToRbar - TIME:SECONDS, TargetOrbit, targetPosition, targetVelocity).
			WAIT 1.

			IF(abs(arrivalPos["y"]) > 180 OR abs(abs(arrivalPos["x"]) - 1000) > 100 OR abs(arrivalPos["z"]) > 100) {
				CWequationCorrectionBurn(RBarChaserPosition, _timeToRbar, ISS, 2).
			}
			IF(abs(arrivalPos["curY"]) < 180 AND abs(abs(arrivalPos["curX"]) - 1000) < 100 AND abs(arrivalPos["curZ"]) < 100
			OR _timeToRbar - time:seconds < 1) {
				SET arrivedToRbar TO TRUE.
			}
			WAIT 2.
		}

		ModeController("TerminalPhase").
	}
	ELSE IF (CurrentMode = "TerminalPhase") {
		LOCAL ISS IS Vessel("Soyuz Docking Target").
		SteeringManagerSetMode("Vessel", ISS).

		SET ISS:LOADDISTANCE:ORBIT:UNPACK TO 1800.
		SET ISS:LOADDISTANCE:ORBIT:PACK TO 1900.

		WAIT UNTIL (VANG(SHIP:FACING:FOREVECTOR, ISS:POSITION) < 1).
		WAIT 3.

		LOCAL CurrentOrbit IS OrbitClass:COPY.
		SET CurrentOrbit TO UpdateOrbitParams(CurrentOrbit).

		LOCAL TargetOrbit IS OrbitClass:COPY.
		SET TargetOrbit TO UpdateOrbitParams(TargetOrbit, ISS:ORBIT).

		LOCAL arrivalTime IS time:seconds + 500.
		LOCAL arrivedToHP1 IS FALSE.
		UNTIL (arrivedToHP1) {
			SET CurrentOrbit TO UpdateOrbitParams(CurrentOrbit).
			SET TargetOrbit TO UpdateOrbitParams(TargetOrbit, ISS:ORBIT).

			LOCAL chaserPosition IS SHIP:POSITION - SHIP:BODY:POSITION.
			LOCAL targetPosition IS ISS:POSITION - SHIP:BODY:POSITION..

			LOCAL chaserVelocity IS SHIP:VELOCITY:ORBIT.
			LOCAL targetVelocity IS ISS:VELOCITY:ORBIT.

			local RBarTargetPosition is RatAngle(TargetOrbit, AngleAtT(TargetOrbit, ISS:ORBIT:TRUEANOMALY, arrivalTime - time:seconds)).
			local RBarChaserPosition is RBarTargetPosition:vec.
			set RBarChaserPosition:mag to RBarChaserPosition:MAG - 500.

			LOCAL arrivalPos IS CWequation(chaserPosition, chaserVelocity, arrivalTime - TIME:SECONDS, TargetOrbit, targetPosition, targetVelocity).
			WAIT 1.

			IF(abs(arrivalPos["y"]) > 15 OR abs(abs(arrivalPos["x"]) - 500) > 40 OR abs(arrivalPos["z"]) > 10) {
				set kuniverse:timewarp:warp to 0.
				WAIT 1.
				CWequationCorrectionBurn(RBarChaserPosition, arrivalTime, ISS, 2).
			}
			ELSE {
				set kuniverse:timewarp:mode to "PHYSICS".
				set kuniverse:timewarp:warp to 3.
			}
			IF(abs(arrivalPos["curY"]) < 15 AND abs(abs(arrivalPos["curX"]) - 500) < 40 AND abs(arrivalPos["curZ"]) < 15
			OR arrivalTime - time:seconds < 1) {
				set kuniverse:timewarp:warp to 0.
				SET arrivedToHP1 TO TRUE.
			}
			WAIT 1.
		}
		WAIT 2.
		SET arrivalTime TO TIME:SECONDS + 650.
		LOCAL arrivedToHP2 IS FALSE.
		UNTIL (arrivedToHP2) {
			SET CurrentOrbit TO UpdateOrbitParams(CurrentOrbit).
			SET TargetOrbit TO UpdateOrbitParams(TargetOrbit, ISS:ORBIT).

			LOCAL chaserPosition IS SHIP:POSITION - SHIP:BODY:POSITION.
			LOCAL targetPosition IS ISS:POSITION - SHIP:BODY:POSITION..

			LOCAL chaserVelocity IS SHIP:VELOCITY:ORBIT.
			LOCAL targetVelocity IS ISS:VELOCITY:ORBIT.

			local RBarTargetPosition is RatAngle(TargetOrbit, AngleAtT(TargetOrbit, ISS:ORBIT:TRUEANOMALY, arrivalTime - time:seconds)).
			local RBarChaserPosition is RBarTargetPosition:vec.
			set RBarChaserPosition:mag to RBarChaserPosition:MAG - 50.

			LOCAL arrivalPos IS CWequation(chaserPosition, chaserVelocity, arrivalTime - TIME:SECONDS, TargetOrbit, targetPosition, targetVelocity).
			WAIT 1.

			IF(abs(arrivalPos["y"]) > 5 OR abs(abs(arrivalPos["x"]) - 50) > 5 OR abs(arrivalPos["z"]) > 3) {
				set kuniverse:timewarp:warp to 0.
				WAIT 1.
				CWequationCorrectionBurn(RBarChaserPosition, arrivalTime, ISS, 2).
			}
			ELSE {
				set kuniverse:timewarp:mode to "PHYSICS".
				set kuniverse:timewarp:warp to 3.
			}
			IF(abs(arrivalPos["curY"]) < 5 AND abs(abs(arrivalPos["curX"]) - 50) < 5 AND abs(arrivalPos["curZ"]) < 3
			OR arrivalTime - time:seconds < 1) {
				SET arrivedToHP2 TO TRUE.
				set kuniverse:timewarp:warp to 0.
			}
			WAIT 1.
		}
		WAIT 2.
		LOCAL proceedToDocking IS FALSE.
		set CONFIG:IPU TO 1500.
		UNTIL (proceedToDocking) {

			LOCAL dV IS ISS:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.

			LOCAL shipBasis IS LEXICON("x", SHIP:FACING:STARVECTOR, "y", SHIP:FACING:TOPVECTOR, "z", SHIP:FACING:FOREVECTOR).

			IF(dV:MAG < 0.005) {
				SET SHIP:CONTROL:TRANSLATION TO V(0, 0, 0).
			}
			ELSE {
				SET dV to dV*10.
				LOCAL burnVector IS convertToLVLH(shipBasis, dV).
				LOCAL starVec is burnVector["x"].
				LOCAL topVec is burnVector["y"].
				LOCAL foreVec is burnVector["z"].

				LOCAL starScalar is starVec:mag.
				// IF(starScalar < 0.1)
				// 	SET starScalar TO 0.1.
				if(vang(ship:facing:starvector, starVec) > 90)
					set starScalar to starScalar*-1.

				LOCAL topScalar is topVec:mag.
				// IF(topScalar < 0.1)
				// 	SET topScalar TO 0.1.
				if(vang(ship:facing:topvector, topVec) > 90)
					set topScalar to topScalar*-1.

				LOCAL foreScalar is foreVec:mag.
				// IF(foreScalar < 0.1)
				// 	SET foreScalar TO 0.1.
				if(vang(ship:facing:forevector, foreVec) > 90)
					set foreScalar to foreScalar*-1.

				LOCAL transVec IS V(starScalar, topScalar, foreScalar).
				SET SHIP:CONTROL:TRANSLATION TO transVec.
			}
			IF(TERMINAL:INPUT:HASCHAR) {
				SET proceedToDocking TO TRUE.
				SET config:ipu to 700.
			}
			wait 0.
		}

		ModeController("Docking").
	}
	ELSE IF(CurrentMode = "Docking") {
		LOCAL ISS IS Vessel("Soyuz Docking Target").

		LOCAL dockingPort IS ISS:DOCKINGPORTS[0].
		SteeringManagerSetMode("Vessel", dockingPort).

		LOCAL docked IS FALSE.
		UNTIL (docked) {
			LOCAL portAxis IS dockingPort:FACING:FOREVECTOR.
			LOCAL relativePosition IS -1*dockingPort:POSITION.
			LOCAL relativeVelocity IS SHIP:VELOCITY:ORBIT - ISS:VELOCITY:ORBIT.

			LOCAL distanceToPortAxis IS portAxis:NORMALIZED * COS(VANG(relativePosition, portAxis)) * relativePosition:MAG - relativePosition.

			CLEARVECDRAWS().

			VECDRAW(dockingPort:POSITION, relativePosition, rgb(0, 1, 0), "pos", 1, true).
			VECDRAW(dockingPort:POSITION, portAxis, rgb(1, 0, 0), "axis", 1, true).
			VECDRAW(V(0,0,0), distanceToPortAxis, rgb(0, 0, 1), "dist", 1, true).

			LOCAL tangentDv IS distanceToPortAxis:NORMALIZED * (MIN(1, distanceToPortAxis:MAG)) * 0.2.
			LOCAL _dV IS tangentDv.

			IF(distanceToPortAxis:MAG < 0.5) {
				SET _dV TO _dV + portAxis:NORMALIZED * -0.1.
			}

			LOCAL dV IS _dV - relativeVelocity.

			LOCAL shipBasis IS LEXICON("x", SHIP:FACING:STARVECTOR, "y", SHIP:FACING:TOPVECTOR, "z", SHIP:FACING:FOREVECTOR).

			IF(dV:MAG < 0.005) {
				SET SHIP:CONTROL:TRANSLATION TO V(0, 0, 0).
			}
			ELSE {
				SET dV to dV*10.
				LOCAL burnVector IS convertToLVLH(shipBasis, dV).
				LOCAL starVec is burnVector["x"].
				LOCAL topVec is burnVector["y"].
				LOCAL foreVec is burnVector["z"].

				LOCAL starScalar is starVec:mag.
				if(vang(ship:facing:starvector, starVec) > 90)
					set starScalar to starScalar*-1.

				LOCAL topScalar is topVec:mag.
				if(vang(ship:facing:topvector, topVec) > 90)
					set topScalar to topScalar*-1.

				LOCAL foreScalar is foreVec:mag.
				if(vang(ship:facing:forevector, foreVec) > 90)
					set foreScalar to foreScalar*-1.

				LOCAL transVec IS V(starScalar, topScalar, foreScalar).
				SET SHIP:CONTROL:TRANSLATION TO transVec.
			}
			IF(dockingPort:POSITION:MAG < 0.5) {
				SET SHIP:CONTROL:TRANSLATION TO V(0, 0, 0).
				SET docked TO TRUE.
			}
			wait 0.
		}
	}
}
