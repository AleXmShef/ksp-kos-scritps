set MissionName to "Soyuz TMA".

if(MissionName <> "None") {
	runpath("0:/missions/Soyuz/" + MissionName + ".ks").
	GLOBAL mission IS SoyuzMission.
	SET TARGET TO "Soyuz Docking Target".
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
						"massTotal", 130275,
						"massDry", 39244,
						"engines", LIST(LEXICON("isp", 320.39, "thrust", 839100), LEXICON("isp", 320.39, "thrust", 37800*4)),
						"staging", LEXICON(
										"jettison", FALSE,
										"ignition", FALSE
										)
					),
					LEXICON(
						"name", "Block I",
						"massTotal", 30282,
						"massDry", 2527,
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
					LEXICON("time", -2.5, "type", "stage", "message", "RD-107s & RD108 ignition"),
					LEXICON("time", 0, "type", "stage", "message", "LIFTOFF"),
					LEXICON("time", 5, "type", "warp", "dur", 110, "message", "Warping through 1st stage"),
					LEXICON("time", 115, "type", "stage", "message", "LES jettison"),
					LEXICON("time", 123, "type", "stage", "message", "Blocks B, V, G, D jettison"),
					LEXICON("time", 135, "type", "warp", "dur", 145, "message", "Warping through 2nd stage"),
					LEXICON("time", 157, "type", "jettison", "message", "Fairing jettison", "massLost", 1400),
					LEXICON("time", 300, "type", "warp", "dur", 235, "message", "Warping through 3rd stage"),
					LEXICON("time", 305, "type", "jettison", "message", "RD0110 fairing jettison", "massLost", 4)
).
GLOBAL controls IS LEXICON(
					"launchTimeAdvance", 150,
					"verticalAscentTime", 14,
					"pitchoverGuidanceMode", "parabolic",
					"terminatingPitch", 31,
					"upfgActivation", 129
).
SWITCH TO 0.
CLEARSCREEN.
SET STEERINGMANAGER:ROLLTS TO 10.
print "Continue booting sequence? (y/n):".
wait until TERMINAL:INPUT:HASCHAR.
if(TERMINAL:INPUT:GETCHAR() = "y") {

	run "0:/libs/UPFG/pegas.ks".

	local msg is "Successful ascent".
	if(SoyuzMission:HASKEY("PayloadProcessor"))
		set p to PROCESSOR(SoyuzMission["PayloadProcessor"]).

	p:CONNECTION:SENDMESSAGE(msg).
}
else {
	shutdown.
}
