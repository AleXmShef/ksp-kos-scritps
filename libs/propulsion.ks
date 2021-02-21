@lazyglobal off.
DECLARE GLOBAL FuncList TO list().
DECLARE GLOBAL LoopFlag TO 0.
declare function LoopManager {
	declare parameter action to -1.
	declare parameter pointer to 0.

	if (action = -1) {
		LoopManagerUpdate().
	}
	else {
		wait until (LoopFlag = 0).
		set LoopFlag to 1.
		if (action = 0) {
			FuncList:Add(pointer).
		}
		else if (action = 1) {
			local tList to FuncList:copy.
			local i is 0.
			for f in tList {
				if (pointer = f) {
					tList:Remove(i).
					break.
				}
				set i to i+1.
			}
			set FuncList to tList.
		}
		set LoopFlag to 0.
	}
}

declare function LoopManagerUpdate {
	if (LoopFlag = 0) {
		set LoopFlag to 1.
		for f in FuncList:copy {
			f:call().
		}
		set LoopFlag to 0.
	}
}

declare function EngineController {
	declare parameter engine.
	declare parameter action to -1.
	if (action = 0) {
		engine:DOEVENT("shutdown engine").
	}
	else if (action = 1) {
		engine:DOEVENT("activate engine").
	}
	else {
		local status to engine:GETFIELD("Propellant").
		if(status:CONTAINS("VERY STABLE"))
			return true.
		else
			return false.
	}
}

declare function BurnUI {
	declare parameter action to 0.
	declare function BurnUiReset {
		set BurnTelemetry to BurnTelemetryClass:COPY.
	}
	declare function BurnUiInit {
		clearscreen.
		print ".------------------------------.".	//0
		print "|   Burn Execution Interface   |".	//1
		print "|------------------------------|".	//2
		print "| Status:                      |".	//3
		print "|------------------------------|".	//4
		print "| MET:           d   h   m   s |".	//5
		print "|------------------------------|".	//6
		print "| Ignition time  =           s |".	//7
		print "| Cutoff time    =           s |".	//8
		print "| dVgo           =         m/s |".	//9
		print "|------------------------------|".	//10
		print "|     Current       Target     |".	//11
		print "| Ap          km |          km |".	//12
		print "| Pe          km |          km |".	//13
		print "| Inc        deg |         deg |".	//14
		print "| AoP        deg |         deg |".	//15
		print "| LAN        deg |         deg |".	//16
		print "|------------------------------|".	//17
		print "|                              |".	//18
		print "*------------------------------*".	//19
		//     123456789
		//              10
		//               123456789
		//                        20
		//                         123456789
		//                                  30
		//                                   12
	}
	declare function BurnUiUpdate {
		declare function RightPadding {
			declare parameter coord.
			declare parameter item.

			local conv_item to item:TOSTRING.
			return coord - conv_item:LENGTH.
		}
		declare function ParseTime {
			declare parameter time to 0.

			local minute to 60.
			local hour to minute*60.
			local day to hour*24.

			local days to floor(time/day).
			set time to time - day*days.
			local hours to floor(time/hour).
			set time to time - hour*hours.
			local minutes to floor(time/minute).
			local seconds to ROUND(time - minute*minutes, 0).

			return LEXICON("d", days, "h", hours, "m", minutes, "s", seconds).
		}

		set BurnTelemetry["RefreshCounter"] to BurnTelemetry["RefreshCounter"] + 1.
		if (BurnTelemetry["RefreshCounter"] >= 50) {
			BurnUiInit().
			set BurnTelemetry["RefreshCounter"] to 0.
		}

		declare local CurTime to TIME:SECONDS.
		declare local MET to ParseTime(MISSIONTIME).

		//Status
		print BurnTelemetry["Status"] at (RightPadding(30, BurnTelemetry["Status"]), 3).

		//MET
		print MET["d"] at (RightPadding(17, MET["d"]), 5).
		print MET["h"] at (RightPadding(21, MET["h"]), 5).
		print MET["m"] at (RightPadding(25, MET["m"]), 5).
		print MET["s"] at (RightPadding(29, MET["s"]), 5).

		//Stats
		local ignTime to ROUND((BurnTelemetry["IgnitionTime"] - TIME:SECONDS), 1).
		if(BurnTelemetry["IgnitionTime"] > 0)
			print ignTime at (RightPadding(28, ignTime), 7).

		local coTime to ROUND(BurnTelemetry["CutoffTime"], 1).
		if (BurnTelemetry["CutoffTime"] > 0)
			print coTime at (RightPadding(28, coTime), 8).
		print ROUND(BurnTelemetry["dVgo"], 1) at (RightPadding(26, ROUND(BurnTelemetry["dVgo"], 1)), 9).

		//Telemetry
		local curAp to ROUND((BurnTelemetry["CurrentOrbit"]["Ap"] - Globals["R"])/1000, 2).
		local curPe to ROUND((BurnTelemetry["CurrentOrbit"]["Pe"] - Globals["R"])/1000, 2).
		local curInc to ROUND(BurnTelemetry["CurrentOrbit"]["Inc"], 2).
		local curAoP to ROUND(BurnTelemetry["CurrentOrbit"]["AoP"], 2).
		local curLAN to ROUND(BurnTelemetry["CurrentOrbit"]["LAN"], 2).

		local tgtAp to ROUND((BurnTelemetry["TargetOrbit"]["Ap"] - Globals["R"])/1000, 2).
		local tgtPe to ROUND((BurnTelemetry["TargetOrbit"]["Pe"] - Globals["R"])/1000, 2).
		local tgtInc to ROUND(BurnTelemetry["TargetOrbit"]["Inc"], 2).
		local tgtAoP to ROUND(BurnTelemetry["TargetOrbit"]["AoP"], 2).
		local tgtLAN to ROUND(BurnTelemetry["TargetOrbit"]["LAN"], 2).

		print curAp at (RightPadding(13, curAp), 12).
		print tgtAp at (RightPadding(27, tgtAp), 12).

		print curPe at (RightPadding(13, curPe), 13).
		print tgtPe at (RightPadding(27, tgtPe), 13).

		print curInc at (RightPadding(12, curInc), 14).
		print tgtInc at (RightPadding(26, tgtInc), 14).

		print curAoP at (RightPadding(12, curAoP), 15).
		print tgtAoP at (RightPadding(26, tgtAoP), 15).

		print curLAN at (RightPadding(12, curLAN), 16).
		print tgtLAN at (RightPadding(26, tgtLAN), 16).


		//Message
		print BurnTelemetry["Message"] at (2, 18).
	}

	if(action = 0) {
		BurnUiUpdate().
	}
	else if(action = 1){
		BurnUiInit().
	}
	else if(action = 2) {
		BurnUiReset().
	}
}

declare global BurnTelemetryClass TO LEXICON (
	"TargetOrbit", OrbitClass:COPY,
	"CurrentOrbit", OrbitClass:COPY,
	"IgnitionTime", 0,
	"CutoffTime", 0,
	"dVgo", 0,
	"Status", "",
	"Message", "",
	"RefreshCounter", 0
).

declare global BurnTelemetry to BurnTelemetryClass:COPY.

declare function ExecBurnNew {
	declare parameter burn.
	declare parameter depOrbit.
	declare parameter tgtOrbit.
	declare parameter ullageDuration to 3.

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
