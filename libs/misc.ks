@lazyglobal off.
LOCAL LoopFlag IS 0.
declare function LoopManager {
	declare parameter action to -1.
	declare parameter pointer to 0.
	if (LoopFlag = 1) {

	}
	else if (action = -1) {
		lock LoopManagerVar to 0.
		for f in FuncList:copy {
			f:call().
		}
		lock LoopManagerVar to LoopManager().
	}
	else if (action = 0) {
		set LoopFlag to 1.
		FuncList:Add(pointer).
		set LoopFlag to 0.
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
}

declare function EngineController {
	declare parameter engine.
	declare parameter action to 0.
	if (action = 0) {
		engine:DOEVENT("shutdown engine").
	}
	else if (action = 1) {
		engine:DOEVENT("activate engine").
	}
}

declare function ExecBurn {
	declare parameter burn.
	declare parameter engine.
	declare parameter warpFlag to 1.
	declare parameter precisionMode to 0.
	declare parameter rcsOnly to 0.
	declare parameter ullage to 0.

	LOCAL mnvrnode IS burn["node"].

	ADD mnvrnode.

	SteeringManagerSetMode("ManeuverNode").

	if(rcsOnly = 0)
		local burnTime to CalcBurnTime(mnvrnode:deltav:mag, Specs["EngineThrust"], Specs["EngineIsp"]).
	else
		local burnTime to CalcBurnTime(mnvrnode:deltav:mag, Specs["UllageRcsThrust"], Specs["UllageRcsIsp"]).


	if (burnTime < 40)
		set warpFlag to 0.

	wait until (vang(ship:facing:forevector, mnvrnode:deltav) < 2).

	wait 3.

	local warpToTime to time:seconds + mnvrnode:eta - (burnTime/2) - 25.

	SteeringManagerMaster(0).

	kuniverse:TimeWarp:WARPTO(warpToTime).

	wait until (time:seconds > warpToTime + 6).

	SteeringManagerMaster(1).

	wait 10.

	wait 7.

	set Thrust to 1.

	local prevConf to config:ipu.

	if(ullage = 1)
		rcs off.

	wait 4.

	EngineController(engine, 1).

	rcs off.

	wait until (engine:GETFIELD("Thrust") > Specs["EngineThrust"] * 0.7).

	wait 1.

	if (warpFlag = 1) {
		set kuniverse:timewarp:mode to "PHYSICS".
		set kuniverse:timewarp:warp to 3.
	}

	wait burnTime - 10.

	set kuniverse:timewarp:mode to "PHYSICS".
	set kuniverse:timewarp:warp to 0.

	if (precisionMode = 1) {
		local dV to mnvrnode:deltav:mag + 100.
		local converged IS FALSE.
		clearscreen.
		set config:ipu to 2000.
		until(converged = TRUE) {
			local _mag is mnvrnode:deltav:mag.
			if(_mag > dV) {
				set converged to true.
			}
			else {
				set dV to _mag.
			}
			wait 0.
		}
	}
	else {
		local _dV is mnvrnode:deltav:mag.
		local _time is calcBurnTime(_dV, Specs["EngineThrust"], Specs["EngineIsp"]).
		wait _time - 0.2.
	}
	set Thrust to 0.

	EngineController(engine, 0).

	remove mnvrnode.

	rcs on.

	set Controls["Mode"] to "Attitude".
	wait 3.
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
	BurnUI(1).
	LoopManager(0, BurnUI@).

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
	wait ullageDuration.
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
		declare local curOrbit to OrbitClass:copy.
		set curOrbit to UpdateOrbitParams(curOrbit).
		declare local _burn to OrbitTransferDemo(curOrbit, tgtOrbit).
		if(_burn["result"] = 1) {
			set Vgo to _burn["dV"].
			set BurnTelemetry["Message"] to "Updated Vgo".
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

		if(Vgo:mag < 1) {
			wait Tgo.
			set Thrust to 0.
			EngineController(Systems["Engine"], 0).

			set cutoff to true.
			set BurnTelemetry["Status"] to "Cutoff".
			set curOrbit to UpdateOrbitParams(curOrbit).
			set BurnTelemetry["CurrentOrbit"] to curOrbit.
		}
	}

	rcs on.
	SteeringManagerSetMode("Attitude").
	wait 5.
	LoopManager(1, BurnUI@).
	BurnUI(2).
	wait 1.
}
