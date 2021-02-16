rcs on.
copypath("0:/libs/SteeringManager.ks", "1:/").
runpath("1:/SteeringManager.ks").

local Thrust is 0.
set config:ipu to 2000.
SteeringManagerMaster(1).
SteeringManagerSetVector(SHIP:VELOCITY:ORBIT).
LOCK THROTTLE TO Thrust + SteeringManager().
print "test".
wait 2000.