@lazyGLOBAL off.
Import(LIST("miscellaneous")).

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
	"Gimals", LEXICON(
		"Pitch", 0,
		"Yaw", 0,
		"Enabled", true
	)
	"Status", "Inactive"
)

GLOBAL BurnTelemetry TO BurnTelemetryClass:COPY.

FUNCTION ExecBurnNew {
	PARAMETER burn.
	PARAMETER gimbal TO true.

	LOCAL Vgo TO burn["dV"].
	LOCAL tImp TO burn["depTime"].
	LOCAL node TO burn["node"].

	LOCAL isWarp TO true.

	LOCAL burnTime TO calcBurnTime(Vgo:mag, Specs["EngineThrust"], Specs["EngineIsp"]).
	LOCAL depTime TO tImp - burnTime/2.

	if(burnTime < 30)
		SET isWarp TO false.

	//UI
	SET BurnTelemetry:BurnTarget:Tig TO depTime.
	SET BurnTelemetry:Telemetry:Tgo TO burnTime.
	SET BurnTelemetry:Telemetry:Vgo TO Vgo.
	SET BurnTelemetry:Status TO "Attitude".

	//Attitude aqq
	DAP:SetMode(DAP, "Inertial").
	DAP:SetTarget(DAP, LVLHfromVector(Vgo)).

	WAIT UNTIL (vang(ship:facing:forevector, Vgo) < 2).
	SET BurnTelemetry:Status TO "Wait Tig".

	//Warp
	WAIT UNTIL (depTime - TIME:SECONDS < ullageDuration).

	//Ullage
	SET BurnTelemetry["Status"] TO "Ullage".
	SET Thrust TO 1.
	WAIT UNTIL (EngineController(Systems["Engine"]) = true).
	EngineController(Systems["Engine"], 1).
	rcs off.

	//Warp
	if(isWarp = true) {
		SET kuniverse:timewarp:mode TO "PHYSICS".
		SET kuniverse:timewarp:warp TO 2.
	}

	//Main loop
	SET BurnTelemetry["Status"] TO "Burn".
	LOCAL cutoff TO false.
	LOCAL curTime TO TIME:SECONDS.
	LOCAL prevTime TO 0.
	LOCAL warpFlag TO true.
	UNTIL (cutoff = true) {
		//Update time
		SET prevTime TO curTime.
		SET curTime TO TIME:SECONDS.

		//Update LOCAL Vgo
		SET Vgo TO Vgo - ship:facing:forevector:normalized * ((Specs["EngineThrust"]/SHIP:MASS) * (curTime - prevTime)).

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
		DAP:SetTarget(DAP, LVLHfromVector(Vgo)).

		LOCAL Tgo TO calcBurnTime(Vgo:mag, Specs["EngineThrust"], Specs["EngineIsp"]).
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
	WAIT 5.
	set BurnTelemetry to BurnTelemetryClass:COPY.
	WAIT 1.
}

FUNCTION RendezvousManager {
	PARAMETER ops.

	FUNCTION correct {
		PARAMETER chaserShip, targetShip, targetPosition, arrivalTime.
		PARAMETER cont TO false.
		LOCAL warpEnabled TO false.
		LOCAL corrected TO false.
		UNTIL (corrected = true) {
			if(cont = true and warpEnabled = false) {
				SET kuniverse:timewarp:mode TO "PHYSICS".
				SET kuniverse:timewarp:warp TO 3.
				SET warpEnabled TO true.
			}

			LOCAL requiredChange TO CWequationCurrentVelFromFuturePos(chaserShip, targetShip, targetPosition, 0, arrivalTime - TIME:SECONDS).

			LOCAL shipBasis TO LEXICON("x", chaserShip:FACING:STARVECTOR, "y", chaserShip:FACING:UPVECTOR, "z", chaserShip:FACING:FOREVECTOR).
			LOCAL shipBasis TO getTransform(shipBasis).
			LOCAL dV TO VCMT(shipBasis:Transform, requiredChange:targetChaserVelocity - requiredChange:chaserVelocity).

			clearscreen.
			print "Correcting" at (0, 0).
			print "Current LVLH velocity:" at (0, 1).
			print "Vel x: " + requiredChange:LVLHrelativeVelocity:X at (0,2).
			print "Vel y: " + requiredChange:LVLHrelativeVelocity:Y at (0,3).
			print "Vel z: " + requiredChange:LVLHrelativeVelocity:Z at (0,4).

			print "Target LVLH velocity:" at (0, 6).
			print "Vel x: " + requiredChange:targetLVLHrelativeVelocity:X at (0,7).
			print "Vel y: " + requiredChange:targetLVLHrelativeVelocity:Y at (0,8).
			print "Vel z: " + requiredChange:targetLVLHrelativeVelocity:Z at (0,9).

			print "Current LVLH position:" at (0, 11).
			print "Pos x: " + requiredChange:LVLHrelativePosition:X at (0,12).
			print "Pos y: " + requiredChange:LVLHrelativePosition:Y at (0,13).
			print "Pos z: " + requiredChange:LVLHrelativePosition:Z at (0,14).

			print "Target LVLH position:" at (0, 16).
			print "Pos x: " + targetPosition:X at (0,17).
			print "Pos y: " + targetPosition:Y at (0,18).
			print "Pos z: " + targetPosition:Z at (0,19).

			print "dV mag: " + dV:MAG at (0, 21).
			print "time TO WP: " + (arrivalTime - TIME:SECONDS) at (0, 22).

			if(TIME:SECONDS + requiredChange:LVLHrelativeVelocity:MAG/0.1 > arrivalTime) {
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
			WAIT 0.5.
		}
	}

	FUNCTION killRelVel {
		PARAMETER chaserShip, targetShip.

		LOCAL corrected TO false.
		UNTIL (corrected = true) {

			LOCAL shipBasis TO LEXICON("x", chaserShip:FACING:STARVECTOR, "y", chaserShip:FACING:UPVECTOR, "z", chaserShip:FACING:FOREVECTOR).
			LOCAL shipBasis TO getTransform(shipBasis).

			LOCAL dV TO VCMT(shipBasis:Transform, targetShip:VELOCITY:ORBIT - chaserShip:VELOCITY:ORBIT).
			if(dV:MAG < 0.05) {
				SET SHIP:CONTROL:NEUTRALIZE TO true.
				SET corrected TO true.
			}
			else {
				SET SHIP:CONTROL:TRANSLATION TO dV*5.
			}
			WAIT 0.1.
		}
	}

	LOCAL chaserShip TO ops:chaserShip.
	LOCAL targetShip TO ops:targetShip.

	LOCAL legs TO ops:legs.

	UNTIL (legs:length = 0) {
		LOCAL leg TO legs:POP().

		LOCAL currentState TO CWequationFutureFromCurrent(chaserShip, targetShip, 0, 0).

		LOCAL targetPosition TO leg:targetPosition.
		LOCAL cont TO leg:cont.
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

		correct(chaserShip, targetShip, targetPosition, arrivalTime, cont).

		if(cont = false) {
			kuniverse:timewarp:warpto(arrivalTime - legTime/2).
			WAIT UNTIL (time:seconds - 2 > arrivalTime - legTime/2).

			correct(chaserShip, targetShip, targetPosition, arrivalTime, cont).

			kuniverse:timewarp:warpto(arrivalTime - legVelocity/0.1).
			WAIT UNTIL (time:seconds - 2 > arrivalTime - legVelocity/0.1).
		}
		if(leg:HASKEY("killRelVel") and leg:killRelVel = true) {
			killRelVel(chaserShip, targetShip).
		}
	}
}
