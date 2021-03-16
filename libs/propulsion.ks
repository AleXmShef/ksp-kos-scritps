@lazyGLOBAL off.
Import(LIST("miscellaneous", "orbits")).

GLOBAL BurnTelemetryClass TO LEXICON(
	"BurnTarget", LEXICON(
		"Tig", 0,
		"dV", V(0, 0, 0)
	),
	"Telemetry", LEXICON(
		"Tgo", 0,
		"Vgo", v(0, 0, 0),
		"ResultOrbit", OrbitClass:COPY
	),
	"Gimbals", LEXICON(
		"Pitch", 0,
		"Yaw", 0,
		"Enabled", true
	),
	"Status", "Inactive"
).

GLOBAL BurnTelemetry TO BurnTelemetryClass:COPY.

FUNCTION ExecBurnNew {
	PARAMETER burn.
	PARAMETER gimbal TO true.
	PARAMETER warp TO true.

	LOCAL Vgo TO burn["dV"].
	LOCAL tImp TO burn["Tig"].

	local curOrb to UpdateOrbitParams().
	local depR to RatAngle(curOrb, AngleAtT(curOrb, SHIP:ORBIT:TRUEANOMALY, tImp - TIME:SECONDS)).
	local depV to VatAngle(
		curOrb,
		AngleAtT(curOrb, SHIP:ORBIT:TRUEANOMALY, tImp - TIME:SECONDS)
	) + Vgo.
	local tgtOrbit to BuildOrbitFromVR(depV, depR).

	LOCAL burnTime TO calcBurnTime(Vgo:mag, Systems["Engine"]:POSSIBLETHRUSTAT(0), Systems["Engine"]:VISP).
	LOCAL depTime TO tImp - burnTime/2.

	//UI
	SET BurnTelemetry:BurnTarget:Tig TO depTime.
	SET BurnTelemetry:BurnTarget:dV TO Vgo.
	SET BurnTelemetry:Telemetry:Tgo TO burnTime.
	SET BurnTelemetry:Telemetry:Vgo TO Vgo.
	SET BurnTelemetry:Status TO "Attitude".

	//Attitude aqq
	DAP:SetMode(DAP, "Inertial").
	wait 1.
	DAP:SetTarget(DAP, "Vector", Vgo).

	WAIT UNTIL (vang(ship:facing:forevector, Vgo) < 2).
	SET BurnTelemetry:Status TO "Wait Tig".

	//Warp
	if(warp) {
		KUNIVERSE:TIMEWARP:WARPTO(depTime - 5).
	}
	WAIT UNTIL (depTime - TIME:SECONDS < 3).

	if(burnTime < 30)
		SET warp TO false.

	//Ullage
	SET BurnTelemetry["Status"] TO "Ullage".
	SET Thrust TO 1.
	WAIT UNTIL (EngineController(Systems["Engine"]) = true).
	EngineController(Systems["Engine"], 1).
	rcs off.

	//Warp
	if(warp = true) {
		SET kuniverse:timewarp:mode TO "PHYSICS".
		SET kuniverse:timewarp:warp TO 2.
	}

	//Main loop
	SET BurnTelemetry["Status"] TO "Burn".
	LOCAL cutoff TO false.
	LOCAL curTime TO TIME:SECONDS.
	LOCAL prevTime TO 0.
	if(warp) {
		SET kuniverse:timewarp:mode TO "PHYSICS".
		SET kuniverse:timewarp:warp TO 2.
	}
	LOCAL warpFlag TO true.
	UNTIL (cutoff = true) {
		//Update time
		SET prevTime TO curTime.
		SET curTime TO TIME:SECONDS.

		//Update LOCAL Vgo
		SET Vgo TO Vgo - ship:facing:forevector:normalized * ((Systems["Engine"]:POSSIBLETHRUSTAT(0)/SHIP:MASS) * (curTime - prevTime)).

		//Try TO recalculate Vgo
		LOCAL curOrbit TO UpdateOrbitParams().
		LOCAL _burn TO OrbitTransfer(curOrbit, tgtOrbit, 10).
		if(_burn["result"] = 1) {
			LOCAL VgoNew TO _burn["dV"].
			if(VANG(VgoNew, Vgo) < 1 and ABS(VgoNew:MAG - Vgo:MAG) < 1) {
				SET Vgo TO VgoNew.
			}
			else {
			}
		}

		//Update attitude
		DAP:SetTarget(DAP, "Vector", Vgo).

		LOCAL Tgo TO calcBurnTime(Vgo:mag, Systems["Engine"]:POSSIBLETHRUSTAT(0), Systems["Engine"]:VISP).
		SET BurnTelemetry:Telemetry:Vgo TO Vgo.
		SET BurnTelemetry:Telemetry:Tgo TO Tgo.

		if(Vgo:mag < 5 AND warpFlag = true) {
			SET kuniverse:timewarp:mode TO "PHYSICS".
			SET kuniverse:timewarp:warp TO 0.
			SET warpFlag TO false.
		}

		if(Vgo:mag < 3) {
			WAIT Tgo.
			SET Thrust TO 0.
			EngineController(Systems["Engine"], 0).

			SET cutoff TO true.
			SET BurnTelemetry["Status"] TO "Cutoff".
			SET curOrbit TO UpdateOrbitParams().
		}
	}

	rcs on.
	DAP:SetMode(DAP, "Inertial").
	WAIT 1.
	set BurnTelemetry to BurnTelemetryClass:COPY.
	WAIT 1.
}

GLOBAL RendezvousManagerOpsClass TO LEXICON(
	"Mode", "Auto",
	"TargetShip", 0,
	"Warp", false,
	"Legs", QUEUE()
).

GLOBAL RendezvousManagerLegClass TO LEXICON(
	"TargetPosition", V(0, 0, 0),
	"LegVelocity", 2,
	"Continuous", false
).

GLOBAL RendezvousManagerTelemetry TO LEXICON(
	"CW_Result", 0,
	"Status", "Inactive",
	"Abort", false
).

FUNCTION RendezvousManager {
	PARAMETER ops.

	set RendezvousManagerTelemetry:Status to "Correcting".

	FUNCTION correct {
		PARAMETER chaserShip, targetShip, targetPosition, arrivalTime.
		PARAMETER cont TO false.
		parameter warp to false.
		LOCAL warpEnabled TO false.
		LOCAL corrected TO false.
		UNTIL (corrected = true or ship:control:pilottranslation <> v(0, 0, 0) or RendezvousManagerTelemetry:Abort = true) {
			if(cont = true and warpEnabled = false and warp = true) {
				SET kuniverse:timewarp:mode TO "PHYSICS".
				SET kuniverse:timewarp:warp TO 3.
				SET warpEnabled TO true.
			}

			LOCAL requiredChange TO CWequationCurrentVelFromFuturePos(chaserShip, targetShip, targetPosition, 0, arrivalTime - TIME:SECONDS).

			LOCAL shipBasis TO LEXICON("x", chaserShip:FACING:STARVECTOR, "y", chaserShip:FACING:UPVECTOR, "z", chaserShip:FACING:FOREVECTOR).
			LOCAL shipBasis TO getTransform(shipBasis).
			LOCAL dV TO VCMT(shipBasis:Transform, requiredChange:targetChaserVelocity - requiredChange:chaserVelocity).

			if(TIME:SECONDS > arrivalTime - 10) {
				SET SHIP:CONTROL:NEUTRALIZE TO true.
				SET corrected TO true.
				SET kuniverse:timewarp:mode TO "PHYSICS".
				SET kuniverse:timewarp:warp TO 0.
			}
			if(dV:MAG < 0.05) {
				SET SHIP:CONTROL:NEUTRALIZE TO true.
				if(cont = false)
					SET corrected TO true.
			}
			else {
				SET SHIP:CONTROL:TRANSLATION TO dV*5.
			}
			WAIT 0.1.
		}
	}

	LOCAL chaserShip TO SHIP.
	LOCAL targetShip TO ops:targetShip.
	LOCAL warp to ops:Warp.

	LOCAL legs TO ops:legs.

	UNTIL (legs:length = 0) {
		LOCAL leg TO legs:POP().

		LOCAL currentState TO CWequationFutureFromCurrent(chaserShip, targetShip, 0, 0).

		LOCAL targetPosition TO leg:TargetPosition.
		LOCAL cont TO leg:Continuous.
		LOCAL arrivalTime TO 0.
		LOCAL legTime TO 0.
		LOCAL legVelocity TO 0.

		if(leg:HASKEY("arrivalTime")) {
			SET arrivalTime TO leg:arrivalTime.
			SET legTime TO (arrivalTime - TIME:SECONDS)/2.
			SET legVelocity TO (targetPosition - currentState:LVLHrelativePosition):MAG/legTime.
		}
		else {
			SET legVelocity TO leg:legVelocity.
			SET legTime TO (targetPosition - currentState:LVLHrelativePosition):MAG/legVelocity + 20.
			SET arrivalTime TO legTime + TIME:SECONDS.
		}

		correct(chaserShip, targetShip, targetPosition, arrivalTime, cont, warp).

		if(cont = false and warp = true) {
			kuniverse:timewarp:warpto(arrivalTime - legTime/2).
			WAIT UNTIL (time:seconds - 10 > arrivalTime - legTime/2).

			correct(chaserShip, targetShip, targetPosition, arrivalTime, cont, warp).

			kuniverse:timewarp:warpto(arrivalTime - 10).
			WAIT UNTIL (time:seconds > arrivalTime - 10).
		}
	}

	set RendezvousManagerTelemetry:Status to "Inactive".
	set RendezvousManagerTelemetry:Abort to "False".
}

FUNCTION KillRelVel {
	PARAMETER chaserShip, targetShip.

	LOCAL corrected TO false.
	UNTIL (corrected = true) {

		LOCAL shipBasis TO LEXICON("x", chaserShip:FACING:STARVECTOR, "y", chaserShip:FACING:UPVECTOR, "z", chaserShip:FACING:FOREVECTOR).
		LOCAL shipBasis TO getTransform(shipBasis).

		LOCAL dV TO VCMT(shipBasis:Transform, targetShip:VELOCITY:ORBIT - chaserShip:VELOCITY:ORBIT).
		if(dV:MAG < 0.05 or ship:control:pilottranslation <> v(0, 0, 0)) {
			SET SHIP:CONTROL:NEUTRALIZE TO true.
			SET corrected TO true.
		}
		else {
			SET SHIP:CONTROL:TRANSLATION TO dV*5.
		}
		WAIT 0.1.
	}
}

FUNCTION DockingManager {
	parameter dockingPort.

	DAP:SetMode(DAP, "Track", LEXICON("Target", dockingPort, "Reference", "Position")).

	local aligned to false.

	until (aligned = true or SHIP:CONTROL:PILOTNEUTRAL = false) {
		clearvecdraws().
		local portAxis to dockingPort:FACING:FOREVECTOR.
		local desPos to portAxis*100.
		local curPos to Components:dockingPort:POSITION - dockingPort:POSITION.

		//distance correction
		local distance_correction to -((curPos:MAG - 100)/ABS(curPos:MAG - 100))*curPos:NORMALIZED*MIN(0.5, ABS(curPos:MAG - 100)/10).

		//position correction
		local position_correction to (vcrs(vcrs(curPos, desPos), curPos):NORMALIZED) * min(0.5, (desPos - curPos):MAG/2).

		local dV to (distance_correction + position_correction) - (SHIP:VELOCITY:ORBIT - dockingPort:SHIP:VELOCITY:ORBIT).

		LOCAL shipBasis TO LEXICON("x", SHIP:FACING:STARVECTOR, "y", SHIP:FACING:UPVECTOR, "z", SHIP:FACING:FOREVECTOR).
		LOCAL shipBasis TO getTransform(shipBasis).
		LOCAL dV_ TO VCMT(shipBasis:Transform, dV).

		if(dV:MAG > 0.01)
			set ship:control:translation to dV_*5.

		if((desPos - curPos):MAG < 0.5) {
			set aligned to true.
			set ship:control:neutralize to true.
		}


		// vecdraw(dockingPort:POSITION, portAxis*100, rgb(0, 1, 0), "portAxis", 1.0, true, 0.2, true, true).
		// vecdraw(dockingPort:POSITION, curPos, rgb(0, 1, 0), "curPos", 1.0, true, 0.2, true, true).
		wait 0.01.
	}
	local docked to false.
	DAP:SetMode(DAP, "Track", LEXICON("Target", dockingPort, "Reference", "Orientation")).
	until (docked = true or SHIP:CONTROL:PILOTNEUTRAL = false) {
		clearvecdraws().
		local portAxis to dockingPort:FACING:FOREVECTOR.
		local desPos to portAxis*100.
		local curPos to Components:dockingPort:POSITION - dockingPort:POSITION.

		//distance correction
		local distance_correction to -curPos:NORMALIZED*MIN(0.5, ABS(curPos:MAG)/5).

		//position correction
		local position_correction to (vcrs(vcrs(curPos, desPos), curPos):NORMALIZED) * min(0.2, curPos:MAG*sin(vang(curPos, desPos))/5).

		local dV to (distance_correction + position_correction) - (SHIP:VELOCITY:ORBIT - dockingPort:SHIP:VELOCITY:ORBIT).

		LOCAL shipBasis TO LEXICON("x", SHIP:FACING:STARVECTOR, "y", SHIP:FACING:UPVECTOR, "z", SHIP:FACING:FOREVECTOR).
		LOCAL shipBasis TO getTransform(shipBasis).
		LOCAL dV_ TO VCMT(shipBasis:Transform, dV).

		if(dV:MAG > 0.01)
			set ship:control:translation to dV_*5.

		if(dockingPort:haspartner) {
			set docked to true.
			set ship:control:neutralize to true.
		}


		// vecdraw(dockingPort:POSITION, portAxis*100, rgb(0, 1, 0), "portAxis", 1.0, true, 0.2, true, true).
		// vecdraw(dockingPort:POSITION, curPos, rgb(0, 1, 0), "curPos", 1.0, true, 0.2, true, true).
		wait 0.01.
	}
	DAP:Disengage(DAP).
}
