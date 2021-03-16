@lazyglobal off.
clearscreen.
clearvecdraws().
SET config:IPU TO 2000.
//-------------------------------------Import Libraries----------------------------------------
Import(list("orbits", "propulsion", "maneuvers", "DAP", "miscellaneous", "UI/UI_manager")).

GLOBAL Components TO lexicon().

FUNCTION PopulateParts {
	SET Components["SM"] TO SHIP:PARTSTITLED("Soyuz TM/TMA/MS Service Module")[0].
	SET Components["SM_Separator"] TO GetConnectedParts(Components["SM"], "SOYUZ.SEPARATOR").
	SET Components["dockingAntenna"] TO GetConnectedParts(Components["SM"], "SOYUZ.DockingAntenna").
	SET Components["heatShield"] TO GetConnectedParts(Components["SM_Separator"], "SOYUZ.HEAT.SHIELD").
	SET Components["DM"] TO GetConnectedParts(Components["heatShield"], "SOYUZ.REENTRY.CAPSULE").
	SET Components["mainChute"] TO GetConnectedParts(Components["DM"], "SOYUZ.PARASHUTE").
	SET Components["spareChute"] TO GetConnectedParts(Components["DM"], "SOYUZ.PARASHUTE.SPARE").
	SET Components["perescope"] TO GetConnectedParts(Components["DM"], "SOYUZ.PERESCOPE").
	SET Components["OM"] TO GetConnectedParts(Components["DM"], "SOYUZ.orbitalSegment").
	SET Components["dockingPort"] TO GetConnectedParts(Components["OM"], "SOYUZdockingPort").
	SET Components["solarPanels"] TO GetConnectedParts(Components["SM"], "SOYUZ.SOLAR.Panel").
}

PopulateParts().

GLOBAL Systems TO lexicon(
						"Engine", Components:SM,
						"MainAntenna", Components:dockingAntenna:GETMODULE("ModuleRTAntenna"),
						"SM_Separator", Components:SM_Separator:GETMODULE("ModuleDecouple"),
						"OM_Separator", Components:OM:GETMODULE("ModuleDecouple"),
						"DockingAntenna", Components:OM:GETMODULE("ModuleRTAntenna"),
						"SolarPanels", Components:solarPanels:GETMODULE("ModuleDeployableSolarPanel"),
						"DockingPort", Components:dockingPort:GETMODULE("ModuleDockingNode")
).

GLOBAL AvailableTargets TO LEXICON(
	"1", VESSEL("Soyuz Docking Target")
).

FUNCTION UpdateDAP {
	DAP:Update(DAP).
}

FUNCTION UpdateUI {
	UI:Update(UI).
}

FUNCTION AcquireControls {
	IF(ControlsAquired = FALSE) {
		UI:Start(UI).
		DAP:Init(DAP).
		lock Throttle to Thrust + LoopManager().
		DAP:Engage(DAP).
		set ControlsAquired TO TRUE.
	}
}

FUNCTION ExecTask {
	LOCAL task TO TaskQueue:POP().
	if(task:Type = "Burn") {
		ExecBurnNew(LEXICON("Tig", task:Tig, "dV", task:dV)).
	}
	else if(task:Type = "CW_Burn") {
		RendezvousManager(task:Ops).
	}
	else if(task:Type = "killRelVel") {
		KillRelVel(SHIP, task:targetShip).
	}
}

GLOBAL CurrentMode TO 0.
GLOBAL Thrust TO 0.
GLOBAL DAP TO GetDAP().
GLOBAL UI to GetUImanager().
GLOBAL TaskQueue TO QUEUE().
GLOBAL ControlsAquired TO FALSE.

LoopManager(0, UpdateDAP@).
LoopManager(0, UpdateUI@).

GLOBAL Modes TO LEXICON(
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
).

Import(LIST(
	"UI/Layouts/OrbitLayout",
	//"UI/Layouts/BootLayout",
	"UI/Layouts/BurnLayout",
	"UI/Layouts/RendezvousLayout",
	"UI/Layouts/RelativeNavigationLayout",
	"UI/Layouts/DapLayout"
)).

GLOBAL UIlayouts TO LEXICON(
	"OrbitLayout", UI_Manager_GetOrbitLayout(),
	//"BootLayout", UI_Manager_GetBootLayout(),
	//"AscentLayout", UI_MAnager_GetAscentLayout(),
	"BurnLayout", UI_Manager_GetBurnLayout(),
	"RendezvousLayout", UI_Manager_GetRendezvousLayout(),
	"RelNavLayout", UI_Manager_GetRelNavLayout(),
	"DapLayout", UI_Manager_GetDapLayout()
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
	ModeController("101").

UNTIL (CurrentMode = "400") {
	IF (CurrentMode = "99") {


		wait 1000.
		ModeController("Shutdown").
	}
	ELSE IF (CurrentMode = "98") {
		ModeController("202").
		local dockPort to VESSEL("Soyuz Docking Target"):PARTSTITLED("ISS Russian Docking Port")[0].
		DockingManager(dockPort).
	}
	ELSE IF (CurrentMode = "100") {
		//UI:AddLayout(UI, UIlayouts:BootLayout, "1").
		UNTIL (CurrentMode <> "100") {
			//UpdateUI().
			wait 0.01.
		}
		//UI:RemoveLayout(UI, "1").
	}
	ELSE IF (CurrentMode = "101") {
		ON ABORT {
			ModeController("302").
		}
		Systems:MainAntenna:DOEVENT("Deactivate").
		//UI:AddLayout(UI, UIlayouts:AscentLayout, "2").
		UNTIL (not CORE:MESSAGES:EMPTY or CurrentMode <> "101") {
			//UpdateUI().
			wait 0.01.
		}.
		IF (not CORE:MESSAGES:EMPTY) {
			LOCAL Recieved TO CORE:MESSAGES:POP.
			IF Recieved:content = "Successful ascent" {
				ModeController("102").
				//UI:RemoveLayout(UI, "2").
			}
		}
	}
	ELSE IF (CurrentMode = "102") {
		set config:ipu to 2000.
		//DAP Init
		AcquireControls().
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
		UI:AddLayout(UI, UIlayouts:BurnLayout, "12").

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

		ExecBurnNew(LEXICON("dV", InsertionBurn:dV, "Tig", InsertionBurn:depTime)).

		WAIT 2.

		ModeController("202").
	}
	ELSE IF (CurrentMode = "202") {
		AcquireControls().
		UI:AddLayout(UI, UIlayouts:OrbitLayout, "10").
		UI:AddLayout(UI, UIlayouts:RendezvousLayout, "34").
		UI:AddLayout(UI, UIlayouts:BurnLayout, "12").
		UI:AddLayout(UI, UIlayouts:RelNavLayout, "32").
		UI:AddLayout(UI, UIlayouts:DapLayout, "20").

		LOCAL ISS IS Vessel("Soyuz Docking Target").
		SET ISS:LOADDISTANCE:ORBIT:UNPACK TO 2500.
		set ISS:LOADDISTANCE:ORBIT:LOAD TO 2800.

		set config:ipu to 2000.

		UNTIL(CurrentMode <> "202") {
			IF(TaskQueue:LENGTH > 0) {
				ExecTask().
			}
			WAIT 0.1.
		}
	}
	ELSE IF (CurrentMode = "302") {
		IF(SHIP:PARTSTITLED("Soyuz Emergency Rescue System Abort Motor"):LENGTH > 0) {
			local les to SHIP:PARTSTITLED("Soyuz Emergency Rescue System Abort Motor")[0].
			local les_jet to SHIP:PARTSTITLED("Soyuz Emergency Rescue System Jettison Motor")[0].

			local fairing_front to SHIP:PARTSTITLED("Soyuz TM/TMA/MS Fairing (Front)")[0].
			local fairing_back to SHIP:PARTSTITLED("Soyuz TM/TMA/MS Fairing (Back)")[0].
			local grid_fin_front to fairing_front:GETMODULE("ModuleAnimateGeneric").
			local grid_fin_back to fairing_back:GETMODULE("ModuleAnimateGeneric").

			grid_fin_front:DOEVENT("open grid fins").
			grid_fin_back:DOEVENT("open grid fins").
			wait 0.1.
			les:activate().
			Components["SM_Separator"]:GETMODULE("ModuleDecouple"):DOEVENT("jettison service module").
			wait 1.
			fairing_front:GETMODULE("ModuleJettison"):DOEVENT("jettison shroud").
			fairing_back:GETMODULE("ModuleJettison"):DOEVENT("jettison shroud").
			Components["perescope"]:GETMODULE("ModuleDecouple"):DOEVENT("jettison periscope").
			wait 0.5.
			les_jet:activate().
			Components["OM"]:GETMODULE("ModuleDecouple"):DOEVENT("jettison orbital module").
			wait until (ship:GEOPOSITION:POSITION:MAG < 3000).
			Components["mainChute"]:GETMODULE("RealChuteModule"):DOEVENT("arm parachute").
			wait until (vang(ship:velocity:surface, up:forevector) > 150 and ship:velocity:surface:mag < 10).
			Components["heatShield"]:GETMODULE("ModuleDecouple"):DOEVENT("Jettison Heat Shield").
			wait until (ship:GEOPOSITION:POSITION:MAG < 5.5).
			Components["DM"]:GETMODULE("ModuleEnginesRF"):DOEVENT("Activate Engine").
			ModeController("400").
		}
		ELSE IF(SHIP:PARTSTITLED("Soyuz TM/TMA/MS Fairing (Front)"):length > 0) {
			local fairing_front to SHIP:PARTSTITLED("Soyuz TM/TMA/MS Fairing (Front)")[0].
			local fairing_back to SHIP:PARTSTITLED("Soyuz TM/TMA/MS Fairing (Back)")[0].
			local grid_fin_front to fairing_front:GETMODULE("ModuleAnimateGeneric").
			local grid_fin_back to fairing_back:GETMODULE("ModuleAnimateGeneric").

			grid_fin_front:DOEVENT("open grid fins").
			grid_fin_back:DOEVENT("open grid fins").
			wait 0.1.
			fairing_front:GETMODULE("ModuleEnginesRF"):doevent("Activate Engine").
			fairing_back:GETMODULE("ModuleEnginesRF"):doevent("Activate Engine").
			Components["SM_Separator"]:GETMODULE("ModuleDecouple"):DOEVENT("jettison service module").
			wait 0.1.
			fairing_front:GETMODULE("ModuleJettison"):DOEVENT("jettison shroud").
			fairing_back:GETMODULE("ModuleJettison"):DOEVENT("jettison shroud").
			wait 1.
			Components["perescope"]:GETMODULE("ModuleDecouple"):DOEVENT("jettison periscope").
			wait 0.5.
			Components["OM"]:GETMODULE("ModuleDecouple"):DOEVENT("jettison orbital module").
			wait until (ship:GEOPOSITION:POSITION:MAG < 3000).
			Components["mainChute"]:GETMODULE("RealChuteModule"):DOEVENT("arm parachute").
			wait until (vang(ship:velocity:surface, up:forevector) > 150 and ship:velocity:surface:mag < 10).
			Components["heatShield"]:GETMODULE("ModuleDecouple"):DOEVENT("Jettison Heat Shield").
			wait until (ship:GEOPOSITION:POSITION:MAG < 5.5).
			Components["DM"]:GETMODULE("ModuleEnginesRF"):DOEVENT("Activate Engine").
			ModeController("400").
		}
		ModeController("98").
	}
}
