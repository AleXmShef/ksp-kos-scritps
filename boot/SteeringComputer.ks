runpath("0:/libs/LibManager.ks").
Import(LIST("SteeringManager")).

clearscreen.

LOCAL done to false.
LOCAL enabled to false.
until (done = true) {
	IF (not CORE:MESSAGES:EMPTY) {
		LOCAL Recieved TO CORE:MESSAGES:POP.
		IF (Recieved:content = "Enable") {
			SteeringManagerMaster(1).
			SteeringManagerSetMode("Attitude").
			SET enabled to true.
		}
		ELSE IF (Recieved:content = "Disable") {
			SteeringManagerMaster(0).
			set SHIP:CONTROL:NEUTRALIZE TO true.
		}
		ELSE IF(Recieved:content:HASKEY("Mode")) {
			SteeringManagerSetMode(Recieved:content:Mode, Recieved:content:Arg).
		}
	}
	if(enabled)
		SteeringManager().
	wait 0.01.
}
