@lazyglobal off.
clearscreen.
//-------------------------------------Import Libraries----------------------------------------
Import(list("maneuvers", "propulsion", "DAP", "miscellaneous", "UI/UI_Manager")).

DECLARE GLOBAL Systems to lexicon(
						"Engine", ship:partstitled("R7 Fregat M")[0]
).

DECLARE GLOBAL CurrentMode TO 0.
DECLARE GLOBAL Thrust TO 0.
GLOBAL DAP TO GetDAP().
GLOBAL UI to GetUImanager().

FUNCTION UpdateDAP {
	DAP:Update(DAP).
}

FUNCTION UpdateUI {
	UI:Update(UI).
}

LoopManager(0, UpdateDAP@).
LoopManager(0, UpdateUI@).

FUNCTION AcquireControls {
	lock Throttle to Thrust + LoopManager().
}

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

GLOBAL Modes TO LEXICON(
	"98", "Nothing",
	"99", "Bebug",
	"100", "Boot",
	"101", "Ascent",
	"102", "Insertion",
	"202", "OnOrbit",
	"203", "PayloadRelease",
	"301", "Deorbit",
	"400", "Shutdown",
	"401", "Reboot"
).

Import(LIST(
	"UI/Layouts/BurnLayout"
)).

GLOBAL UIlayouts TO LEXICON(
	"BurnLayout", UI_Manager_GetBurnLayout()
).

ModeController("101").

UNTIL (CurrentMode = "400") {
	IF (CurrentMode = "98") {
		WAIT UNTIL CurrentMode <> "Nothing".
	}
	ELSE IF (CurrentMode = "101") {
		//SET CONFIG:IPU TO 10.
		WAIT UNTIL (not CORE:MESSAGES:EMPTY).
		IF (not CORE:MESSAGES:EMPTY) {
			LOCAL Recieved TO CORE:MESSAGES:POP.
			IF Recieved:content = "Successful ascent" {
				ModeController("102").
			}
			ELSE IF Recieved:content = "Load mission" {
				LOCAL MissionName to CORE:MESSAGES:POP.
				RUNPATH("0:/missions/Soyuz/" + MissionName:content + ".ks").
				DECLARE GLOBAL Mission to FregatMission.
			}
		}
		ELSE
			ModeController("102").
	}
	ELSE IF (CurrentMode = "102") {
		set config:ipu to 2000.

		DAP:Init(DAP).
		UI:Start(UI, false).
		AcquireControls().
		UI:AddLayout(UI, UIlayouts:BurnLayout, "12").
		DAP:Engage(DAP).
		wait 1.
		RCS ON.
		WAIT 2.
		STAGE.
		SET SHIP:CONTROL:FORE TO 1.
		WAIT 2.
		SET SHIP:CONTROL:FORE TO 0.
		WAIT 1.
		ModeController("202").
	}
	ELSE IF (CurrentMode = "202") {
		LOCAL CurrentOrbit TO UpdateOrbitParams().

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

		LOCAL DummyTransferBurn IS OrbitTransfer(CurrentOrbit, DummyTransferOrbit).

		ExecBurnNew(LEXICON("dV", DummyTransferBurn:dV, "Tig", DummyTransferBurn:depTime)).

		SET CurrentOrbit TO UpdateOrbitParams().
		LOCAL FinalizationBurn IS OrbitTransfer(CurrentOrbit, TargetOrbit).
		ExecBurnNew(LEXICON("dV", FinalizationBurn:dV, "Tig", FinalizationBurn:depTime)).
		ModeController("203").
	}
	ELSE IF (CurrentMode = "203") {
		WAIT 3.
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
		ModeController("301").
	}
	ELSE IF (CurrentMode = "301") {
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
