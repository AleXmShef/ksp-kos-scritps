set MissionName to "Soyuz Docking Target".

if(MissionName <> "None") {
	runpath("0:/missions/Soyuz/" + MissionName + ".ks").
	GLOBAL mission IS SoyuzMission.
	if (FregatFlag = 1) {
		set msg to "Load mission".
		set p to PROCESSOR("Fregat").
		p:CONNECTION:SENDMESSAGE(msg).
		
		set msg to MissionName.
		p:CONNECTION:SENDMESSAGE(msg).
	}
}
else {
	GLOBAL mission IS LEXICON(
					"payload" , ship:mass - 310074,
					"apoapsis", 210,
					"periapsis", 205,
					"inclination", 51.6
	).
}

GLOBAL vehicle IS LIST(
					LEXICON(
						"name", "Block A",
						"massTotal", 132143,
						"massDry", 39911,
						"engines", LIST(LEXICON("isp", 320.39, "thrust", 839126), LEXICON("isp", 320.39, "thrust", 37836*4)),
						"staging", LEXICON(
										"jettison", FALSE,
										"ignition", FALSE
										)
					),
					LEXICON(
						"name", "Block I",
						"massTotal", 29935,			//	RSB Centaur has too much oxygen in the tank
						"massDry", 2180,		//	these masses are for Centaur that has been reset and had tanks readjusted
						"engines", LIST(LEXICON("isp", 330.4, "thrust", 298200), LEXICON("isp", 330, "thrust", 6000*4)),
						"staging", LEXICON(
										"jettison", TRUE,
										"waitBeforeJettison", 0,
										"ignition", TRUE,
										"waitBeforeIgnition", 3,
										"ullage", "none"
										)
					)
).
GLOBAL sequence IS LIST(
					LEXICON("time", -3.7, "type", "stage", "message", "RD-107s & RD108 ignition"),
					LEXICON("time", 0, "type", "stage", "message", "LIFTOFF"),
					LEXICON("time", 5, "type", "warp", "dur", 110, "message", "Warping through 1st stage"),
					LEXICON("time", 122, "type", "stage", "message", "Blocks B, V, G, D jettison"),
					LEXICON("time", 130, "type", "warp", "dur", 150, "message", "Warping through 2nd stage"),
					LEXICON("time", 140, "type", "jettison", "message", "Fairing jettison", "massLost", 1766),
					LEXICON("time", 300, "type", "warp", "dur", 200, "message", "Warping through 3rd stage"),
					LEXICON("time", 305, "type", "jettison", "message", "RD0110 fairing jettison", "massLost", 4)
).
GLOBAL controls IS LEXICON(
					"launchTimeAdvance", 150,
					"verticalAscentTime", 14,	
					"pitchoverGuidanceMode", "parabolic",
					"terminatingPitch", 33,
					"upfgActivation", 129
).
SWITCH TO 0.
CLEARSCREEN.
SET STEERINGMANAGER:ROLLTS TO 10.
run "0:/libs/UPFG/pegas.ks".

set msg to "Successful ascent".
if(FregatFlag = 1)
	set p to PROCESSOR("Fregat").
else if(SoyuzMission:HASKEY("PayloadProcessor") AND SoyuzMission["PayloadProcessor"] <> "None")
	set p to PROCESSOR(SoyuzMission["PayloadProcessor"]).

p:CONNECTION:SENDMESSAGE(msg).