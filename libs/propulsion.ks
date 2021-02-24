@lazyglobal off.
Import(LIST("miscellaneous")).

declare global BurnTelemetry to BurnTelemetryClass:COPY.

declare function ExecBurnNew {
	declare parameter burn.
	declare parameter gimbal to true.

	declare local Vgo to burn["dV"].
	declare local tImp to burn["depTime"].
	declare local node to burn["node"].

	declare local isWarp to true.

	declare local burnTime to calcBurnTime(Vgo:mag, Specs["EngineThrust"], Specs["EngineIsp"]).
	declare local depTime to tImp - burnTime/2.

	if(burnTime < 30)
		set isWarp to false.

	//UI
	set BurnTelemetry["CurrentOrbit"] to depOrbit.
	set BurnTelemetry["TargetOrbit"] to tgtOrbit.
	set BurnTelemetry["IgnitionTime"] to depTime.
	set BurnTelemetry["CutoffTime"] to burnTime.
	set BurnTelemetry["dVgo"] to Vgo:MAG.
	set BurnTelemetry["Status"] to "Attitude".

	//BurnUI(1).
	//LoopManager(0, BurnUI@).

	//Attitude aqq
	SteeringManagerSetMode("Vector", Vgo).

	wait until (vang(ship:facing:forevector, Vgo) < 2).

	//Warp
	set BurnTelemetry["Status"] to "Warp".
	kuniverse:timewarp:WARPTO(depTime - (ullageDuration + 5)).
	wait until (depTime - TIME:SECONDS < ullageDuration).

	//Ullage
	set BurnTelemetry["Status"] to "Ullage".
	set Thrust to 1.
	wait until (EngineController(Systems["Engine"]) = true).
	EngineController(Systems["Engine"], 1).
	rcs off.

	//Warp
	if(isWarp = true) {
		set kuniverse:timewarp:mode to "PHYSICS".
		set kuniverse:timewarp:warp to 2.
	}

	//Main loop
	set BurnTelemetry["Status"] to "Burn".
	declare local cutoff to false.
	declare local curTime to TIME:SECONDS.
	declare local prevTime to 0.
	declare local warpFlag to true.
	until (cutoff = true) {
		//Update time
		set prevTime to curTime.
		set curTime to TIME:SECONDS.

		//Update local Vgo
		set Vgo to Vgo - ship:facing:forevector:normalized * ((Specs["EngineThrust"]/SHIP:MASS) * (curTime - prevTime)).

		//Try to recalculate Vgo
		local curOrbit to UpdateOrbitParams().
		declare local _burn to OrbitTransfer(curOrbit, tgtOrbit, 10).
		if(_burn["result"] = 1) {
			local VgoNew to _burn["dV"].
			if(VANG(VgoNew, Vgo) < 1 and ABS(VgoNew:MAG - Vgo:MAG) < 1) {
				set Vgo to VgoNew.
				set BurnTelemetry["Message"] to "Updated Vgo".
			}
			else {
				set BurnTelemetry["Message"] to "Vgo divergence, using old".
			}
		}
		else {
			set BurnTelemetry["Message"] to "Old Vgo".
		}

		//Update attitude
		SteeringManagerSetMode("Vector", Vgo).

		local Tgo to calcBurnTime(Vgo:mag, Specs["EngineThrust"], Specs["EngineIsp"]).
		set BurnTelemetry["CurrentOrbit"] to curOrbit.
		set BurnTelemetry["dVgo"] to Vgo:mag.
		set BurnTelemetry["CutoffTime"] to Tgo.

		if(Vgo:mag < 5 AND warpFlag = true) {
			set kuniverse:timewarp:mode to "PHYSICS".
			set kuniverse:timewarp:warp to 0.
			set warpFlag to false.
		}

		if(Vgo:mag < 3) {
			wait Tgo.
			set Thrust to 0.
			EngineController(Systems["Engine"], 0).

			set cutoff to true.
			set BurnTelemetry["Status"] to "Cutoff".
			set curOrbit to UpdateOrbitParams().
			set BurnTelemetry["CurrentOrbit"] to curOrbit.
		}
	}

	rcs on.
	SteeringManagerSetMode("Attitude").
	wait 5.
	//LoopManager(1, BurnUI@).
	//BurnUI(2).
	wait 1.
}

declare function RendezvousManager {
	declare parameter ops.

	declare function correct {
		declare parameter chaserShip, targetShip, targetPosition, arrivalTime.
		declare parameter cont to false.
		local warpEnabled to false.
		local corrected to false.
		until (corrected = true) {
			if(cont = true and warpEnabled = false) {
				set kuniverse:timewarp:mode to "PHYSICS".
				set kuniverse:timewarp:warp to 3.
				set warpEnabled to true.
			}

			local requiredChange to CWequationCurrentVelFromFuturePos(chaserShip, targetShip, targetPosition, 0, arrivalTime - TIME:SECONDS).

			local shipBasis to LEXICON("x", chaserShip:FACING:STARVECTOR, "y", chaserShip:FACING:UPVECTOR, "z", chaserShip:FACING:FOREVECTOR).
			local shipBasis to getTransform(shipBasis).
			local dV to VCMT(shipBasis:Transform, requiredChange:targetChaserVelocity - requiredChange:chaserVelocity).

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
			print "time to WP: " + (arrivalTime - TIME:SECONDS) at (0, 22).

			if(TIME:SECONDS + requiredChange:LVLHrelativeVelocity:MAG/0.1 > arrivalTime) {
				set SHIP:CONTROL:NEUTRALIZE to true.
				set corrected to true.
				set kuniverse:timewarp:mode to "PHYSICS".
				set kuniverse:timewarp:warp to 0.
			}
			if(dV:MAG < 0.05) {
				set SHIP:CONTROL:NEUTRALIZE to true.
				if(cont = false)
					set corrected to true.
			}
			else {
				set SHIP:CONTROL:TRANSLATION to dV*5.
			}
			wait 0.5.
		}
	}

	declare function killRelVel {
		declare parameter chaserShip, targetShip.

		local corrected to false.
		until (corrected = true) {

			local shipBasis to LEXICON("x", chaserShip:FACING:STARVECTOR, "y", chaserShip:FACING:UPVECTOR, "z", chaserShip:FACING:FOREVECTOR).
			local shipBasis to getTransform(shipBasis).

			local dV to VCMT(shipBasis:Transform, targetShip:VELOCITY:ORBIT - chaserShip:VELOCITY:ORBIT).
			if(dV:MAG < 0.05) {
				set SHIP:CONTROL:NEUTRALIZE to true.
				set corrected to true.
			}
			else {
				set SHIP:CONTROL:TRANSLATION to dV*5.
			}
			wait 0.1.
		}
	}

	declare local chaserShip to ops:chaserShip.
	declare local targetShip to ops:targetShip.

	declare local legs to ops:legs.

	until (legs:length = 0) {
		local leg to legs:POP().

		local currentState to CWequationFutureFromCurrent(chaserShip, targetShip, 0, 0).

		local targetPosition to leg:targetPosition.
		local cont to leg:cont.
		local arrivalTime to 0.
		local legTime to 0.
		local legVelocity to 0.

		if(leg:HASKEY("arrivalTime")) {
			set arrivalTime to leg:arrivalTime.
			set legTime to (arrivalTime - TIME:SECONDS)/2.
			set legVelocity to (targetPosition - currentState:LVLHrelativePosition):MAG/legTime.
		}
		else {
			set legVelocity to leg:legVelocity.
			set legTime to (targetPosition - currentState:LVLHrelativePosition):MAG/legVelocity + 20.
			set arrivalTime to legTime + TIME:SECONDS.
		}

		correct(chaserShip, targetShip, targetPosition, arrivalTime, cont).

		if(cont = false) {
			kuniverse:timewarp:warpto(arrivalTime - legTime/2).
			wait until (time:seconds - 2 > arrivalTime - legTime/2).

			correct(chaserShip, targetShip, targetPosition, arrivalTime, cont).

			kuniverse:timewarp:warpto(arrivalTime - legVelocity/0.1).
			wait until (time:seconds - 2 > arrivalTime - legVelocity/0.1).
		}
		if(leg:HASKEY("killRelVel") and leg:killRelVel = true) {
			killRelVel(chaserShip, targetShip).
		}
	}
}
