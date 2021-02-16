clearscreen.
//-------------Proton-M Flight Plan--------------
//Libs include-------------------------------------------------------------------------------------

set MissionName to "ComSat V1 Atlantic".

if(MissionName <> "None") {
	runpath("0:/missions/Proton/" + MissionName + ".ks").
	set Mission to ProtonMission.
	if (BreezeFlag = 1) {
		set msg to "Load mission".
		set p to PROCESSOR("Breeze-M").
		p:CONNECTION:SENDMESSAGE(msg).
		
		set msg to MissionName.
		p:CONNECTION:SENDMESSAGE(msg).
	}
}

set warpt to time:seconds.
when (time:seconds - warpt > 35) THEN {
	set kuniverse:timewarp:mode to "PHYSICS".
	set kuniverse:timewarp:warp to 2.
}
when (time:seconds - warpt > 135) THEN {
	set kuniverse:timewarp:mode to "PHYSICS".
	set kuniverse:timewarp:warp to 0.
}
when (time:seconds - warpt > 160) THEN {
	set kuniverse:timewarp:mode to "PHYSICS".
	set kuniverse:timewarp:warp to 2.
}
when (time:seconds - warpt > 340) THEN {
	set kuniverse:timewarp:mode to "PHYSICS".
	set kuniverse:timewarp:warp to 0.
}
when (time:seconds - warpt > 370) THEN {
	set kuniverse:timewarp:mode to "PHYSICS".
	set kuniverse:timewarp:warp to 2.
}
when (time:seconds - warpt > 540) THEN {
	set kuniverse:timewarp:mode to "PHYSICS".
	set kuniverse:timewarp:warp to 0.
}


GLOBAL vehicle IS LIST(
					LEXICON(
						"name", "2nd Stage",
						"massTotal", 217580,
						"massDry", 61470,
						"engines", LIST(LEXICON("isp", 327, "thrust", 4*584.77*1000)),
						"staging", LEXICON(
										"jettison", TRUE,
										"waitBeforeJettison", 1,
										"ignition", TRUE,
										"waitBeforeIgnition", 2,
										"ullage", "none"
										)
					),
					LEXICON(
						"name", "3rd Stage",
						"massTotal", 49750,			
						"massDry", 3190,		
						"engines", LIST(LEXICON("isp", 327, "thrust", 584.77*1000), LEXICON("isp", 293, "thrust", 30.98*4000)),
						"staging", LEXICON(
										"jettison", TRUE,
										"waitBeforeJettison", 0,
										"ignition", TRUE,
										"waitBeforeIgnition", 2,
										"ullage", "none"
										)
					)
).
GLOBAL sequence IS LIST(
					LEXICON("time", -4.0, "type", "stage", "message", "RD-275"),
					LEXICON("time", 0, "type", "stage", "message", "LIFTOFF"),
					LEXICON("time", 140, "type", "jettison", "message", "Fairing jettison", "massLost", 1594)
).
GLOBAL controls IS LEXICON(
					"launchTimeAdvance", 150,
					"verticalAscentTime", 14,	
					"pitchOverAngle", 3,
					"upfgActivation", 130
).
GLOBAL mission IS LEXICON(
					"payload", 22090,
					"apoapsis", 200,
					"periapsis", 200,
					"inclination", 51.6
).
SWITCH TO 0.
CLEARSCREEN.
SET STEERINGMANAGER:ROLLTS TO 10.
run "0:/libs/UPFG/pegas.ks".


set msg to "Successful ascent".
if(BreezeFlag = 1)
	set p to PROCESSOR("Breeze-M").
else 
	set p to PROCESSOR("Payload").

p:PART:CONTROLFROM().
p:CONNECTION:SENDMESSAGE(msg).

