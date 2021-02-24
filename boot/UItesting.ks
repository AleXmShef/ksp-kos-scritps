runpath("0:/libs/LibManager.ks").
Import(LIST("SteeringManager")).

set ship:control:neutralize to true.

set config:ipu to 2000.
SteeringManagerMaster(1).
SteeringManagerSetMode("Vector", PROGRADE:FOREVECTOR).

until false {
	SteeringManagerSetMode("Vector", PROGRADE:FOREVECTOR).
	SteeringManager().
}
