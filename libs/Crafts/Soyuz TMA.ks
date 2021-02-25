@lazyglobal off.
clearscreen.
SET config:IPU TO 2000.
//-------------------------------------Import Libraries----------------------------------------
Import(list("orbits", "propulsion", "maneuvers", "DAP", "miscellaneous")).

GLOBAL Components TO lexicon().

FUNCTION PopulateParts {
	SET Components["SM"] TO CORE:PART.
	SET Components["SM_Separator"] TO GetConnectedParts(Components["SM"], "SOYUZ.SEPARATOR").
	SET Components["dockingAntenna"] TO GetConnectedParts(Components["SM"], "SOYUZ.DockingAntenna").
	SET Components["heatShield"] TO GetConnectedParts(Components["SM_Separator"], "SOYUZ.HEAT.SHIELD").
	SET Components["DM"] TO GetConnectedParts(Components["heatShield"], "SOYUZ.REENTRY.CAPSULE").
	SET Components["mainChute"] TO GetConnectedParts(Components["DM"], "SOYUZ.PARASHUTE").
	SET Components["spareChute"] TO GetConnectedParts(Components["DM"], "SOYUZ.PARASHUTE.SPARE").
	SET Components["perescope"] TO GetConnectedParts(Components["DM"], "SOYUZ.PERESCOPE").
	SET Components["OM"] TO GetConnectedParts(Components["DM"], "SOYUZ.orbitalSegment").
	SET Components["dockingPort"] TO GetConnectedParts(Components["OM"], "SOYUZdockingPort").
	SET Components["solarPanels"] TO GetConnectedParts(SM, "SOYUZ.SOLAR.Panel").
}

PopulateParts().

GLOBAL Systems TO lexicon(
						"Engine", Components:SM:GETMODULE("ModuleEnginesRF"),
						"MainAntenna", Components:dockingAntenna:GETMODULE("ModuleRTAntenna"),
						"SM_Separator", Components:SM_Separator:GETMODULE("ModuleDecouple"),
						"OM_Separator", Components:OM:GETMODULE("ModuleDecouple"),
						"DockingAntenna", Components:OM:GETMODULE("ModuleRTAntenna"),
						"SolarPanels", Components:solarPanels:GETMODULE("ModuleDeployableSolarPanel"),
						"DockingPort", Components:dockingPort:GETMODULE("ModuleDockingNode")
).

GLOBAL Specs TO lexicon(
						"EngineThrust", 2.95,
						"EngineIsp", 302,
						"UllageRcsThrust", 0.13*4,
						"UllageRcsIsp", 291
).

FUNCTION UpdateDAP {
	DAP:Update(DAP).
}

FUNCTION UpdateUI {
	UI:Update(UI).
}

FUNCTION AcquireControls {
	lock Throttle to Thrust + LoopManager().
}

FUNCTION ExecTask {
	LOCAL task TO TaskQueue:POP().
}

GLOBAL CurrentMode TO 0.
GLOBAL Thrust TO 0.
GLOBAL DAP TO GetDAP().
GLOBAL UI to GetUImanager().
GLOBAL TaskQueue TO QUEUE().

LoopManager(0, UpdateDAP@).
LoopManager(0, UpdateUI@).

GLOBAL Modes TO LEXICON(
	"98", "Nothing",
	"99", "Bebug",
	"100", "Boot",
	"101", "Ascent",
	"102", "Insertion",
	"202", "OnOrbit",
	//"203", "Docking",
	"204", "Docked",
	"301", "Deorbit",
	"302", "Abort",
	"400", "Shutdown",
	"401", "Reboot"
).

Import(LIST(
	"UI/Layouts/OrbitLayout",
	"UI/Layouts/BootLayout",
	"UI/Layouts/BurnLayout"
)).

GLOBAL UIlayouts TO LEXICON(
	"OrbitLayout", UI_Manager_GetOrbitLayout(),
	"BootLayout", UI_Manager_GetBootLayout(),
	"AscentLayout", UI_MAnager_GetAscentLayout(),
	"BurnLayout", UI_Manager_GetBurnLayout()
).

FUNCTION ModeController {
	PARAMETER TargetMode.
	IF(TargetMode = "400")
		shutdown.
	ELSE IF(TargetMode = "401")
		reboot.
	ELSE IF(Modes:HASKEY(TargetMode)) {
		SET CurrentMode TO TargetMode.
		LOCAL lmj TO LEXICON("Mode", TargetMode).
		WRITEJSON(lmj, "1:/LastMode.json").
	}
}



IF(exists("1:/LastMode.json")) {
	LOCAL last_mode_json TO READJSON("1:/LastMode.json").
	ModeController(last_mode_json:Mode).
}
ELSE
	ModeController("100").

UNTIL (CurrentMode = "400") {
	IF (CurrentMode = "99") {


		wait 1000.
		ModeController("Shutdown").
	}
	ELSE IF (CurrentMode = "98") {
		WAIT UNTIL CurrentMode <> "Nothing".
	}
	ELSE IF (CurrentMode = "100") {
		UI:AddLayout(UI, UIlayouts:BootLayout, "1").
		UNTIL (CurrentMode <> "100") {
			UpdateUI().
		}
		UI:RemoveLayout(UI, "1").
	}
	ELSE IF (CurrentMode = "101") {
		UI:AddLayout(UI, UIlayouts:AscentLayout, "2").
		UNTIL (not CORE:MESSAGES:EMPTY or CurrentMode <> "101") {
			UpdateUI().
		}.
		IF (not CORE:MESSAGES:EMPTY) {
			LOCAL Recieved TO CORE:MESSAGES:POP.
			IF Recieved:content = "Successful ascent" {
				ModeController("102").
				UI:RemoveLayout(UI, "2").
			}
		}
	}
	ELSE IF (CurrentMode = "102") {
		//DAP Init
		AcquireControls().
		DAP:Init(DAP).
		wait 1.

		//Separation
		RCS ON.
		WAIT 1.
		STAGE.
		SET SHIP:CONTROL:FORE TO 1.
		WAIT 2.
		SET SHIP:CONTROL:FORE TO 0.
		WAIT 1.

		//UI
		UI:AddLayout(UI, UIlayouts:BurnLayout, "34").

		//Insertion burn
		LOCAL CurrentOrbit TO UpdateOrbitParams().

		LOCAL TargetOrbit IS OrbitClass:copy.
		SET TargetOrbit["Ap"] TO 210*1000 + Globals["R"].
		SET TargetOrbit["Pe"] TO 209*1000 + Globals["R"].
		SET TargetOrbit["Inc"] TO CurrentOrbit["Inc"].
		SET TargetOrbit["LAN"] TO CurrentOrbit["LAN"].
		SET TargetOrbit["AoP"] TO CurrentOrbit["AoP"].

		SET TargetOrbit TO BuildOrbit(TargetOrbit).

		LOCAL InsertionBurn IS OrbitTransfer(CurrentOrbit, TargetOrbit).

		ExecBurnNew(InsertionBurn, CurrentOrbit, TargetOrbit).

		WAIT 2.

		ModeController("202").
	}
	ELSE IF (CurrentMode = "202") {
		AcquireControls().
		UNTIL(CurrentMode <> "202") {
			IF(TaskQueue:LENGTH > 0) {


			}
		}
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
			SET burn TO RendezvousTransfer(CurrentOrbit, TargetOrbit, YBarDistance, RBarDistance, SHIP:ORBIT:TRUEANOMALY, TARGET:ORBIT:TRUEANOMALY).
		}

		SET burn["depTime"] TO burn["depTime"] + TIME:SECONDS.
		LOCAL depR TO RatAngle(CurrentOrbit, AngleAtT(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY, burn["depTime"] - TIME:SECONDS)).
		LOCAL depV TO VatAngle(CurrentOrbit, AngleAtT(CurrentOrbit, SHIP:ORBIT:TRUEANOMALY, burn["depTime"] - TIME:SECONDS)) + burn["dV"].
		LOCAL transferOrbit is BuildOrbitFromVR(depV, depR).

		LOCAL trueBurn TO OrbitTransfer(CurrentOrbit, transferOrbit).

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

		SET ISS:LOADDISTANCE:ORBIT:UNPACK TO 1200.

		LOCAL state TO CWequationFutureFromCurrent(Ship, ISS, 0, 0).

		LOCAL timeToRbar TO ABS(state:LVLHrelativePosition:Y)/ABS(state:LVLHrelativeVelocity:Y) + TIME:SECONDS.

		LOCAL RendezvousManagerOps TO LEXICON().
		SET RendezvousManagerOps["chaserShip"] TO Ship.
		SET RendezvousManagerOps["targetShip"] TO ISS.

		LOCAL legs is Queue().
		legs:PUSH(LEXICON("targetPosition", V(-1000, 0, 0), "arrivalTime", timeToRbar, "cont", false)).

		SET RendezvousManagerOps["legs"] TO legs.
		RendezvousManager(RendezvousManagerOps).

		ModeController("ProximityOps").

	}
	ELSE IF (CurrentMode = "ProximityOps") {
		SET TARGET TO "Soyuz Docking Target".
		LOCAL ISS IS Vessel("Soyuz Docking Target").

		LOCAL RendezvousManagerOps TO LEXICON().
		SET RendezvousManagerOps["chaserShip"] TO Ship.
		SET RendezvousManagerOps["targetShip"] TO ISS.

		LOCAL legs is Queue().
		legs:PUSH(LEXICON("targetPosition", V(-500, 0, 0), "legVelocity", 2, "cont", false)).
		legs:PUSH(LEXICON("targetPosition", V(-100, 0, 0), "legVelocity", 1, "cont", true, "killRelVel", true)).

		SET RendezvousManagerOps["legs"] TO legs.

		RendezvousManager(RendezvousManagerOps).

		ModeController("Docking").
	}
	ELSE IF (CurrentMode = "Docking") {
		ModeController("Shutdown").
	}
}
