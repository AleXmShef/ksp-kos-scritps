DECLARE FUNCTION upfgMasterFunction {
	DECLARE PARAMETER argLexicon.

	LOCAL upfgGlobalLexicon IS LEXICON().




	DECLARE FUNCTION upfgReset {

		//Initialize global flags and constants

		SET upfgGlobalLexicon TO LEXICON(
			"defaultGlobals", LEXICON(
				"g0", 9.8067,				//	PEGAS will launch from any planet or moon - "g0" is a standard constant for thrust computation and shall not be changed!
				"upfgStage", -1,				//	Seems wrong (we use "vehicle[upfgStage]") but first run of stageEventHandler increments this automatically
				"stageEventFlag", FALSE,
				"systemEvents", LIST(),
				"systemEventPointer", -1,	//	Same deal as with "upfgStage"
				"systemEventFlag", FALSE,
				"userEventPointer", -1,	//	As above
				"userEventFlag", FALSE,
				"commsEventFlag", FALSE,
				"throttleSetting", 1,		//	This is what actually controls the throttle,
				"throttleDisplay", 1,		//	and this is what to display on the GUI - see throttleControl() for details.
				"steeringVector", LOOKDIRUP(SHIP:FACING:FOREVECTOR, SHIP:FACING:TOPVECTOR),
				"steeringRoll", 0,
				"upfgConverged", FALSE,
				"stagingInProgress", FALSE,
				"pitchoverParabolicMode", FALSE
			),
			"settings", LEXICON(
				//	Settings for PEGAS
				"kOS_IPU", 500,				//	Required to run the script fast enough.
				"cserVersion", "new",			//	Which version of the CSER function to use: "old" for the standard one, "new" for pand5461's implementation.
														//	"Old" CSER requires IPU of about 500, while "new" has not been extensively tested yet.
				"pitchOverTimeLimit", 20,		//	In atmospheric part of ascent, when the vehicle pitches over, the wait for velocity vector to align will be forcibly broken after that many seconds.
				"upfgConvergenceDelay", 5,		//	Transition from passive (atmospheric) to active guidance occurs that many seconds before "upfgActivation" (to give UPFG time to converge).
				"upfgFinalizationTime", 5,		//	When time-to-go gets below that, keep attitude stable and simply count down time to cutoff.
				"stagingKillRotTime", 5,			//	Updating attitude commands will be forbidden that many seconds before staging (in an attempt to keep vehicle steady for a clean separation).
				"upfgConvergenceCriterion", 0.1,	//	Maximum difference between consecutive UPFG T-go predictions that allow accepting the solution.
				"upfgGoodSolutionCriterion", 5	//	Maximum angle between guidance vectors calculated by UPFG between stages that allow accepting the solution.
			)
		).
	}
}

//	The following is absolutely necessary to run UPFG fast enough.
SET CONFIG:IPU TO kOS_IPU.



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
GLOBAL liftoffTime IS currentTime + timeToOrbitIntercept - controls["launchTimeAdvance"] - 20.
IF timeToOrbitIntercept < controls["launchTimeAdvance"] { SET liftoffTime TO liftoffTime + SHIP:BODY:ROTATIONPERIOD. }
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
if (liftoffTime:seconds - time:seconds > 60) {
	wait 5.
	set kuniverse:timewarp:mode to "RAILS".
	kuniverse:TimeWarp:WARPTO(liftoffTime:seconds - 10).
}
UNTIL ABORT {
	//	Sequence handling
	IF systemEventFlag = TRUE { systemEventHandler(). }
	IF   userEventFlag = TRUE {   userEventHandler(). }
	IF  commsEventFlag = TRUE {  commsEventHandler(). }
	//	Control handling
	IF ascentFlag = 0 {
		//	The vehicle is going straight up for given amount of time
		IF TIME:SECONDS >= liftoffTime:SECONDS + controls["verticalAscentTime"] {
			//	Then it changes attitude for an initial pitchover "kick"
			IF(controls:HASKEY("pitchoverGuidanceMode")) {
				IF(controls["pitchoverGuidanceMode"] = "parabolic") {
				SET pitchoverParabolicMode TO TRUE.
					parabolicPitchGuidance(1).
					SET ascentFlag TO 3.
				}
				ELSE {
					SET steeringVector TO aimAndRoll(HEADING(mission["launchAzimuth"],90-controls["pitchOverAngle"]):VECTOR, steeringRoll).
					SET ascentFlag TO 1.
					pushUIMessage( "Pitching over by " + ROUND(controls["pitchOverAngle"],1) + " degrees." ).
				}
			}
			ELSE {
				SET steeringVector TO aimAndRoll(HEADING(mission["launchAzimuth"],90-controls["pitchOverAngle"]):VECTOR, steeringRoll).
				SET ascentFlag TO 1.
				pushUIMessage( "Pitching over by " + ROUND(controls["pitchOverAngle"],1) + " degrees." ).
			}
		}
	}
	ELSE IF ascentFlag = 1 {
		//	It keeps this attitude until velocity vector matches it closely
		IF TIME:SECONDS < liftoffTime:SECONDS + controls["verticalAscentTime"] + 3 {
			//	Delay this check for the first few seconds to allow the vehicle to pitch away from current prograde
		} ELSE {
			//	Attitude must be recalculated at every iteration though
			SET velocityAngle TO VANG(SHIP:UP:VECTOR, SHIP:VELOCITY:SURFACE).
			IF controls["pitchOverAngle"] - velocityAngle < 0.1 {
				SET ascentFlag TO 2.
			}
		}
		//	As a safety check - do not stay deadlocked in this state for too long (might be unnecessary).
		IF TIME:SECONDS >= liftoffTime:SECONDS + controls["verticalAscentTime"] + pitchOverTimeLimit {
			SET ascentFlag TO 2.
			pushUIMessage( "Pitchover time limit exceeded!", 5, PRIORITY_HIGH ).
		}
	}
	ELSE IF ascentFlag = 2 {
		//	We cannot blindly hold prograde though, because this will provide no azimuth control
		//	Much better option is to read current velocity angle and aim for that, but correct for azimuth
		SET velocityAngle TO 90-VANG(SHIP:UP:VECTOR, SHIP:VELOCITY:SURFACE).
		SET steeringVector TO aimAndRoll(HEADING(mission["launchAzimuth"],velocityAngle):VECTOR, steeringRoll).
		//	There are two almost identical cases, in the first we set the initial message, in the next we just keep attitude.
		pushUIMessage( "Holding prograde at " + ROUND(mission["launchAzimuth"],1) + " deg azimuth." ).
		SET ascentFlag TO 3.
	}
	ELSE {
		IF(pitchoverParabolicMode = TRUE) {
			SET targetPitchAngle TO parabolicPitchGuidance().
			SET steeringVector TO aimAndRoll(HEADING(mission["launchAzimuth"],targetPitchAngle):VECTOR, steeringRoll).
		}
		ELSE {
			SET velocityAngle TO 90-VANG(SHIP:UP:VECTOR, SHIP:VELOCITY:SURFACE).
			SET steeringVector TO aimAndRoll(HEADING(mission["launchAzimuth"],velocityAngle):VECTOR, steeringRoll).
		}
	}
	//	The passive guidance loop ends a few seconds before actual ignition of the first UPFG-controlled stage.
	//	This is to give UPFG time to converge. Actual ignition occurs via stagingEvents.
	IF TIME:SECONDS >= liftoffTime:SECONDS + controls["upfgActivation"] - upfgConvergenceDelay {
		pushUIMessage( "Initiating UPFG!" ).
		BREAK.
	}
	//	UI - recalculate UPFG target solely for printing relative angle
	SET upfgTarget["normal"] TO targetNormal(mission["inclination"], mission["LAN"]).
	refreshUI().
	WAIT 0.
}


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
