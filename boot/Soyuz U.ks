GLOBAL vehicle IS LIST(
					LEXICON(
						"name", "Block A",
						"massTotal", 128475,
						"massDry", 36031,
						"engines", LIST(LEXICON("isp", 314.58, "thrust", 846607), LEXICON("isp", 314.58, "thrust", 38173*4)),
						"staging", LEXICON(
										"jettison", FALSE,
										"ignition", FALSE
										)
					),
					LEXICON(
						"name", "Block I",
						"massTotal", 26739,			//	RSB Centaur has too much oxygen in the tank
						"massDry", 3948,		//	these masses are for Centaur that has been reset and had tanks readjusted
						"engines", LIST(LEXICON("isp", 305, "thrust", 215000), LEXICON("isp", 330, "thrust", 6000*4)),
						"staging", LEXICON(
										"jettison", TRUE,
										"waitBeforeJettison", 0,
										"ignition", TRUE,
										"waitBeforeIgnition", 4,
										"ullage", "none"
										)
					)
).
GLOBAL sequence IS LIST(
					LEXICON("time", -3.7, "type", "stage", "message", "RD-107s & RD108 ignition"),
					LEXICON("time", 0, "type", "stage", "message", "LIFTOFF"),
					LEXICON("time", 122, "type", "stage", "message", "Blocks B, V, G, D jettison"),
					LEXICON("time", 140, "type", "jettison", "message", "Fairing jettison", "massLost", 1766),
					LEXICON("time", 295, "type", "jettison", "message", "RD0110 fairing jettison", "massLost", 4)
).
GLOBAL controls IS LEXICON(
					"launchTimeAdvance", 150,
					"verticalAscentTime", 14,	
					"pitchoverGuidanceMode", "parabolic",
					"terminatingPitch", 33,
					"upfgActivation", 131
).
GLOBAL mission IS LEXICON(
					"payload" , 6568 + 7625,
					"apoapsis", 200,
					"periapsis", 190,
					"inclination", 51.6
).
SWITCH TO 0.
CLEARSCREEN.
SET STEERINGMANAGER:ROLLTS TO 10.
run "0:/libs/UPFG/pegas.ks".