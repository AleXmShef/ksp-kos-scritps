@lazyglobal off.
clearscreen.
//-------------------------------------Import Libraries----------------------------------------
Import(list("orbits", "propulsion", "maneuvers", "SteeringManager")).

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
DECLARE GLOBAL ArrivalTime TO 0.
DECLARE GLOBAL testFlag TO 0.

// declare function InitMode {
// 	local mode to "Ascent".
//
// 	if exists("1:/last_mode.json") {
// 		set mode to READJSON("1:/last_mode.json"):mode.
// 	}
// 	if(mode <> "Ascent")
// 		InitControls().
// 	ModeController(mode, false).
// }

// declare function ModeController {
// 	declare parameter TargetMode.
// 	declare parameter _reboot to true.
//
// 	if(_reboot = true) {
// 		local last_mode to LEXICON("mode", TargetMode).
// 		WRITEJSON(last_mode, "1:/last_mode.json").
// 		reboot.
// 	}
// 	else
// 		set CurrentMode to TargetMode.
// }

// declare function InitControls {
// 	set config:ipu to 2000.
// 	SteeringManagerMaster(1).
// 	SteeringManagerSetVector().
// 	LoopManager(0, SteeringManager@).
// 	LOCK THROTTLE TO Thrust + LoopManager().
// }

//InitMode().

declare function ModeController {
	declare parameter TargetMode.
	set CurrentMode TO TargetMode.
}

// declare function SteeringManagerSetMode {
// 	declare parameter mode.
// 	declare parameter arg to "None".
//
// 	local p to PROCESSOR("SteeringManagerProcessor").
// 	p:CONNECTION:SENDMESSAGE(LEXICON("Mode", mode, "Arg", arg)).
// }
//
// declare function SteeringManagerMaster {
// 	declare parameter enable.
//
// 	local p to PROCESSOR("SteeringManagerProcessor").
// 	if(enable = 1)
// 		p:CONNECTION:SENDMESSAGE("Enable").
// 	ELSE
// 		p:CONNECTION:SENDMESSAGE("Disable").
//}

ModeController("Ascent").

UNTIL (CurrentMode = "Shutdown") {
	IF (CurrentMode = "debug") {


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
	}
	ELSE IF (CurrentMode = "ParkingOrbit") {
		SET config:IPU to 2000.
		SteeringManagerMaster(1).
		SteeringManagerSetMode("Attitude").
		LoopManager(0, SteeringManager@).
		wait 1.
		LOCK THROTTLE TO Thrust + LoopManager().
		WAIT 1.
		ModeController("Decouple").
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
		LOCAL CurrentOrbit TO UpdateOrbitParams().

		LOCAL TargetOrbit IS OrbitClass:copy.
		SET TargetOrbit["Ap"] to 210*1000 + Globals["R"].
		SET TargetOrbit["Pe"] to 209*1000 + Globals["R"].
		SET TargetOrbit["Inc"] to CurrentOrbit["Inc"].
		SET TargetOrbit["LAN"] to CurrentOrbit["LAN"].
		SET TargetOrbit["AoP"] to CurrentOrbit["AoP"].

		SET TargetOrbit TO BuildOrbit(TargetOrbit).

		LOCAL InsertionBurn IS OrbitTransfer(CurrentOrbit, TargetOrbit).

		ExecBurnNew(InsertionBurn, CurrentOrbit, TargetOrbit).

		WAIT 5.

		ModeController("CoellipticPhase").
	}
	ELSE IF (CurrentMode = "CoellipticPhase") {
		SET TARGET TO "Soyuz Docking Target".

		LOCAL CurrentOrbit TO UpdateOrbitParams().

		LOCAL TargetOrbit TO UpdateOrbitParams(TARGET:ORBIT).

		LOCAL RBarDistance IS 5.
		LOCAL YBarDistance IS 30.

		LOCAL burn is RendezvousTransfer(CurrentOrbit, TargetOrbit, YBarDistance, RBarDistance, SHIP:ORBIT:TRUEANOMALY, TARGET:ORBIT:TRUEANOMALY).
		IF(burn["node"] = "none") {
			LOCAL warpToTime IS time:seconds + burn["warpTime"].
			SET kuniverse:timewarp:mode TO "RAILS".
			KUNIVERSE:TIMEWARP:WARPTO(warpToTime).
			WAIT UNTIL (TIME:SECONDS > warpToTime + 2).
			set burn to RendezvousTransfer(CurrentOrbit, TargetOrbit, YBarDistance, RBarDistance, SHIP:ORBIT:TRUEANOMALY, TARGET:ORBIT:TRUEANOMALY).
		}

		set burn["depTime"] to burn["depTime"] + TIME:SECONDS.
		local depR to RatAngle(CurrentOrbit, AngleAtT(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY, burn["depTime"] - TIME:SECONDS)).
		local depV to VatAngle(CurrentOrbit, AngleAtT(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY, burn["depTime"] - TIME:SECONDS)) + burn["dV"].
		LOCAL transferOrbit is BuildOrbitFromVR(depV, depR).

		local trueBurn to OrbitTransfer(CurrentOrbit, transferOrbit).

		clearscreen.
		print "perf test".
		wait 5.
		ExecBurnNew(trueBurn, CurrentOrbit, transferOrbit).
		WAIT 2.
		SET arrivalTime TO burn["arrivalTime"].
		ModeController("Circularization").
	}
	ELSE IF (CurrentMode = "Circularization") {
		SET TARGET TO "Soyuz Docking Target".
		LOCAL CurrentOrbit TO UpdateOrbitParams().

		LOCAL TargetOrbit TO UpdateOrbitParams(TARGET:ORBIT).

		LOCAL CircularizationOrbit IS CurrentOrbit:COPY.
		SET CircularizationOrbit["Ap"] TO TargetOrbit["Ap"] - 5000.
		SET CircularizationOrbit["Pe"] TO CircularizationOrbit["Ap"] - 100.
		SET CircularizationOrbit["Inc"] TO TargetOrbit["Inc"].
		SET CircularizationOrbit["LAN"] TO TargetOrbit["LAN"].
		SET CircularizationOrbit["AoP"] TO TargetOrbit["AoP"].
		SET CircularizationOrbit TO BuildOrbit(CircularizationOrbit).

		LOCAL CircularizationBurn IS OrbitTransfer(CurrentOrbit, CircularizationOrbit).
		ExecBurnNew(CircularizationBurn, CurrentOrbit, CircularizationOrbit).
		WAIT 2.
		ModeController("TerminalPhaseInitiation").
	}
	ELSE IF (CurrentMode = "TerminalPhaseInitiation") {
		SET TARGET TO "Soyuz Docking Target".
		LOCAL ISS IS Vessel("Soyuz Docking Target").

		SET ISS:LOADDISTANCE:ORBIT:UNPACK to 1200.

		LOCAL state TO CWequationFutureFromCurrent(Ship, ISS, 0, 0).

		LOCAL timeToRbar TO ABS(state:LVLHrelativePosition:Y)/ABS(state:LVLHrelativeVelocity:Y) + TIME:SECONDS.

		local RendezvousManagerOps TO LEXICON().
		set RendezvousManagerOps["chaserShip"] to Ship.
		set RendezvousManagerOps["targetShip"] to ISS.

		local legs is Queue().
		legs:PUSH(LEXICON("targetPosition", V(-1000, 0, 0), "arrivalTime", timeToRbar, "cont", false)).

		set RendezvousManagerOps["legs"] to legs.
		RendezvousManager(RendezvousManagerOps).

		ModeController("ProximityOps").

	}
	ELSE IF (CurrentMode = "ProximityOps") {
		SET TARGET TO "Soyuz Docking Target".
		LOCAL ISS IS Vessel("Soyuz Docking Target").

		local RendezvousManagerOps TO LEXICON().
		set RendezvousManagerOps["chaserShip"] to Ship.
		set RendezvousManagerOps["targetShip"] to ISS.

		local legs is Queue().
		legs:PUSH(LEXICON("targetPosition", V(-500, 0, 0), "legVelocity", 2, "cont", false)).
		legs:PUSH(LEXICON("targetPosition", V(-100, 0, 0), "legVelocity", 1, "cont", true, "killRelVel", true)).

		set RendezvousManagerOps["legs"] to legs.

		RendezvousManager(RendezvousManagerOps).

		ModeController("Docking").
	}
	ELSE IF (CurrentMode = "Docking") {
		ModeController("Shutdown").
	}
}
