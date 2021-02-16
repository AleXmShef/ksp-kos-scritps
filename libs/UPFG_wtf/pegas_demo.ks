wait until (terminal:input:haschar).

SteeringManagerMaster(1).
SteeringManagerSetVector().

wait 1.

LOCK THROTTLE TO Thrust + SteeringManager().

SteeringManagerSetMode("Vector", ship:facing:forevector).

SET CONFIG:IPU TO 500.
LOCAL CurrentOrbit IS OrbitClass:copy.
SET CurrentOrbit TO UpdateOrbitParams(CurrentOrbit).

LOCAL TargetOrbit IS OrbitClass:copy.
SET TargetOrbit["Ap"] to CurrentOrbit["Ap"] + 150000.
SET TargetOrbit["Pe"] to CurrentOrbit["Pe"].
SET TargetOrbit["Inc"] to CurrentOrbit["Inc"].
SET TargetOrbit["LAN"] to CurrentOrbit["LAN"].
SET TargetOrbit["AoP"] to CurrentOrbit["AoP"].

SET TargetOrbit TO BuildOrbit(TargetOrbit).

LOCAL InsertionBurn IS OrbitTransferDemo(CurrentOrbit, TargetOrbit).

set InsertionBurn["mission"] to lexicon(
	"apoapsis", (TargetOrbit["Ap"] - Globals["R"])/1000,
	"periapsis", (TargetOrbit["Pe"] - Globals["R"])/1000,
	"inclination", TargetOrbit["Inc"],
	"LAN", TargetOrbit["LAN"]
).

print "flag1".
wait 1.

declare LOCAL burn TO InsertionBurn.
declare LOCAL engine TO Systems["Engine"].
declare LOCAL warpFlag to 1.
declare LOCAL precisionMode to 0.
declare LOCAL rcsOnly to 0.
declare LOCAL ullage to 0.

GLOBAL mnvrnode IS burn["node"].

local _mission is burn["mission"].

declare global vehicle is list(
	lexicon(
		"name", "KTDU",
		"massTotal", 7185,
		"massDry", 6307,
		"engines", LIST(LEXICON("isp", 302, "thrust", 2950)),
		"staging", LEXICON(
						"jettison", FALSE,
						"ignition", FALSE
						)
	)
).

declare global sequence IS LIST(
).
declare GLOBAL controls IS LEXICON(
					"launchTimeAdvance", 0,
					"verticalAscentTime", 0,
					"pitchoverGuidanceMode", "parabolic",
					"terminatingPitch", 31,
					"upfgActivation", 0
).

ADD mnvrnode.

wait 1.

SteeringManagerSetMode("Vector", mnvrnode:DELTAV).

wait 1.

local burnTime to CalcBurnTime(mnvrnode:deltav:mag, Specs["EngineThrust"], Specs["EngineIsp"]).

declare global mission is lexicon(
	"apoapsis", _mission["apoapsis"],
	"periapsis", _mission["periapsis"],
	"inclination", _mission["inclination"],
	"LAN", _mission["LAN"],
	"altitude", (RatAngle(TargetOrbit, AngleAtT(TargetOrbit, 0, burnTime/2)):MAG - Globals["R"])/1000
).


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

if(ullage = 1)
	rcs off.

wait 4.

EngineController(engine, 1).

rcs off.

UNLOCK THROTTLE.
UNLOCK STEERING.
SteeringManagerMaster(0).

wait 0.1.

print "Pegas entry1".

declare global ___tgtV is VatAngle(TargetOrbit, AngleAtT(TargetOrbit, 0, burnTime/2)).




//	If no boot file was loaded, this check will immediately crash PEGAS, saving time that would otherwise be wasted on loading libraries.
IF NOT (DEFINED vehicle) OR NOT (DEFINED sequence) OR NOT (DEFINED controls) OR NOT (DEFINED mission) {
	PRINT "".
	PRINT "No boot file loaded! Crashing...".
	PRINT "".
	SET _ TO sequence.
	SET _ TO controls.
	SET _ TO vehicle.
	SET _ TO mission.
}
print "Pegas entry2".

//	Load settings and libraries.
RUN "0:/libs/UPFG/pegas_settings.ks".
IF cserVersion = "new" {
	RUN "0:/libs/UPFG/pegas_cser_new.ks".
} ELSE {
	RUN "0:/libs/UPFG/pegas_cser.ks".
}
RUN "0:/libs/UPFG/pegas_upfg.ks".
RUN "0:/libs/UPFG/pegas_util.ks".
print "Pegas entry3".
RUN "0:/libs/UPFG/pegas_comm.ks".
RUN "0:/libs/UPFG/pegas_misc.ks".
print "Pegas entry4".

//	The following is absolutely necessary to run UPFG fast enough.
SET CONFIG:IPU TO 500.

//	Initialize global flags and constants
GLOBAL g0 IS 9.8067.				//	PEGAS will launch from any planet or moon - "g0" is a standard constant for thrust computation and shall not be changed!
GLOBAL upfgStage IS -1.				//	Seems wrong (we use "vehicle[upfgStage]") but first run of stageEventHandler increments this automatically
GLOBAL stageEventFlag IS FALSE.
GLOBAL systemEvents IS LIST().
GLOBAL systemEventPointer IS -1.	//	Same deal as with "upfgStage"
GLOBAL systemEventFlag IS FALSE.
GLOBAL userEventPointer IS -1.		//	As above
GLOBAL userEventFlag IS FALSE.
GLOBAL commsEventFlag IS FALSE.
GLOBAL throttleSetting IS 1.		//	This is what actually controls the throttle,
GLOBAL throttleDisplay IS 1.		//	and this is what to display on the GUI - see throttleControl() for details.
GLOBAL steeringVector IS LOOKDIRUP(SHIP:FACING:FOREVECTOR, SHIP:FACING:TOPVECTOR).
GLOBAL steeringRoll IS 0.
GLOBAL upfgConverged IS FALSE.
GLOBAL stagingInProgress IS FALSE.
GLOBAL pitchoverParabolicMode IS FALSE.

PRINT "PEGAS FLAG".
//	PREFLIGHT ACTIVITIES
//	Click "control from here" on a part that runs the system.
//	Helpful when your payload is not perfectly rigidly attached, and you're not sure whether it controls the vessel or not.
//CORE:PART:CONTROLFROM().
//	Update mission struct and set up UPFG target
missionSetup().
SET upfgTarget TO targetSetup().
//	Calculate time to launch
SET currentTime TO TIME.
SET timeToOrbitIntercept TO orbitInterceptTime().
GLOBAL liftoffTime IS currentTime.
//	Calculate launch azimuth if not specified
IF NOT mission:HASKEY("launchAzimuth") {
	mission:ADD("launchAzimuth", launchAzimuth()).
}
//	Read initial roll angle (to be executed during the pitchover maneuver)
IF controls:HASKEY("initialRoll") {
	SET steeringRoll TO controls["initialRoll"].
}
//	Set up the system for flight
setSystemEvents().		//	Set up countdown messages
setUserEvents().		//	Initialize vehicle sequence
setVehicle().			//	Complete vehicle definition (as given by user)
setComms(). 			//	Setting up communications


//	PEGAS TAKES CONTROL OF THE MISSION
createUI().
//	Prepare control for vertical ascent
LOCK THROTTLE TO throttleSetting.
LOCK STEERING TO steeringVector.
SET ascentFlag TO 0.	//	0 = vertical, 1 = pitching over, 2 = notify about holding prograde, 3 = just hold prograde
//	Main loop - wait on launch pad, lift-off and passive guidance

//	ACTIVE GUIDANCE
createUI().
//	Initialize UPFG
initializeVehicle().
SET upfgState TO acquireState().
SET upfgInternal TO setupUPFG().
//	Main loop - iterate UPFG (respective function controls attitude directly)
UNTIL ABORT {
	//	Sequence handling
	IF systemEventFlag = TRUE { systemEventHandler(). }
	IF   userEventFlag = TRUE {   userEventHandler(). }
	IF  stageEventFlag = TRUE {  stageEventHandler(). }
	IF  commsEventFlag = TRUE {  commsEventHandler(). }
	//	Update UPFG target and vehicle state
	SET upfgTarget["normal"] TO targetNormal(mission["inclination"], mission["LAN"]).
	SET upfgState TO acquireState().
	//	Iterate UPFG and preserve its state
	SET upfgInternal TO upfgSteeringControl(vehicle, upfgStage, upfgTarget, upfgState, upfgInternal).
	//	Manage throttle, with the exception of initial portion of guided flight (where we're technically still flying the first stage).
	IF upfgStage >= 0 { throttleControl(). }
	//	For the final seconds of the flight, just hold attitude and wait.
	IF upfgConverged AND upfgInternal["tgo"] < upfgFinalizationTime { BREAK. }
	//	UI
	refreshUI().
	WAIT 0.
}
//	Final orbital insertion loop
pushUIMessage( "Holding attitude for burn finalization!" ).
SET previousTime TO TIME:SECONDS.
UNTIL ABORT {
	LOCAL finalizeDT IS TIME:SECONDS - previousTime.
	SET previousTime TO TIME:SECONDS.
	SET upfgInternal["tgo"] TO upfgInternal["tgo"] - finalizeDT.
	IF upfgInternal["tgo"] < finalizeDT { BREAK. }	//	Exit loop before entering the next refresh cycle
													//	We could have done "tgo < 0" but this would mean that the previous loop tgo was 0.01 yet we still didn't break
	refreshUI().
	WAIT 0.
}


//	EXIT
UNLOCK STEERING.
UNLOCK THROTTLE.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
WAIT 0.
missionValidation().
refreshUI().
