@lazyglobal off.
clearscreen.
SET config:IPU to 2000.
//-------------------------------------Import Libraries----------------------------------------
Import(list("orbits", "propulsion", "maneuvers", "SteeringManager", "miscellaneous")).

DECLARE GLOBAL Components to lexicon().

DECLARE FUNCTION PopulateParts {
	set Components["SM"] to CORE:PART.
	set Components["SM_Separator"] to GetConnectedParts(Components["SM"], "SOYUZ.SEPARATOR").
	set Components["dockingAntenna"] to GetConnectedParts(Components["SM"], "SOYUZ.DockingAntenna").
	set Components["heatShield"] to GetConnectedParts(Components["SM_Separator"], "SOYUZ.HEAT.SHIELD").
	set Components["DM"] to GetConnectedParts(Components["heatShield"], "SOYUZ.REENTRY.CAPSULE").
	set Components["mainChute"] to GetConnectedParts(Components["DM"], "SOYUZ.PARASHUTE").
	set Components["spareChute"] to GetConnectedParts(Components["DM"], "SOYUZ.PARASHUTE.SPARE").
	set Components["perescope"] to GetConnectedParts(Components["DM"], "SOYUZ.PERESCOPE").
	set Components["OM"] to GetConnectedParts(Components["DM"], "SOYUZ.orbitalSegment").
	set Components["dockingPort"] to GetConnectedParts(Components["OM"], "SOYUZdockingPort").
	set Components["solarPanels"] to GetConnectedParts(SM, "SOYUZ.SOLAR.Panel").
}

PopulateParts().

DECLARE GLOBAL Systems to lexicon(
						"Engine", Components:SM:GETMODULE("ModuleEnginesRF"),
						"MainAntenna", Components:dockingAntenna:GETMODULE("ModuleRTAntenna"),
						"SM_Separator", Components:SM_Separator:GETMODULE("ModuleDecouple"),
						"OM_Separator", Components:OM:GETMODULE("ModuleDecouple"),
						"DockingAntenna", Components:OM:GETMODULE("ModuleRTAntenna"),
						"SolarPanels", Components:solarPanels:GETMODULE("ModuleDeployableSolarPanel"),
						"DockingPort", Components:dockingPort:GETMODULE("ModuleDockingNode")
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

DECLARE GLOBAL Modes TO LEXICON(
	"98", "Nothing",
	"99", "Bebug",
	"100", "Boot",
	"101", "Ascent",
	"102", "Insertion",
	"202", "OnOrbit",
	"203", "Docking",
	"204", "Docked",
	"301", "Deorbit",
	"302", "Abort",
	"400", "Shutdown",
	"401", "Reboot"
)

declare function ModeController {
	declare parameter TargetMode.
	if(TargetMode = "400")
		shutdown.
	else if(TargetMode = "401")
		reboot.
	else if(Modes:HASKEY(TargetMode)) {
		set CurrentMode TO TargetMode.
		local lmj to LEXICON("Mode", TargetMode).
		WRITEJSON(lmj, "1:/LastMode.json").
	}
}

if(exists("1:/LastMode.json")) {
	local last_mode_json to READJSON("1:/LastMode.json").
	ModeController(last_mode_json:Mode).
}
else
	ModeController("100").

UNTIL (CurrentMode = "400") {
	IF (CurrentMode = "99") {


		wait 1000.
		ModeController("Shutdown").
	}
	ELSE IF (CurrentMode = "98") {
		WAIT UNTIL CurrentMode <> "Nothing".
	}
	ELSE IF (CurrentMode = "101") {
		WAIT UNTIL (not CORE:MESSAGES:EMPTY or CurrentMode <> "101").
		IF (not CORE:MESSAGES:EMPTY) {
			LOCAL Recieved TO CORE:MESSAGES:POP.
			IF Recieved:content = "Successful ascent" {
				ModeController("102").
			}
		}
	}
	ELSE IF (CurrentMode = "ParkingOrbit") {
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
	ELSE IF (CurrentMode = "102") {
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
	ELSE IF (CurrentMode = "202") {

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
