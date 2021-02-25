runpath("0:/libs/LibManager.ks").
Import(LIST("vectors", "matrixes", "orbits", "DAP")).
clearscreen.
set config:ipu to 2000.
set ship:control:neutralize to true.

global DAP to GetDAP().

function _updateDAP {
	DAP:Update(DAP).
}

DAP:Init(DAP).
DAP:Engage(DAP).
DAP:SetMode(DAP, "LVLH").
DAP:Update(DAP).
DAP:SetTarget(DAP, "Vector", SHIP:PROGRADE:FOREVECTOR).

lock Throttle to 0 + _updateDAP().

until false {
	//local irf to getIRF().
	local lvlh to getLVLHfromR_DAP(UpdateOrbitParams(), -SHIP:BODY:POSITION).
	clearvecdraws().

	vecdraw(v(0, 0, 0), lvlh:basis:x*10, rgb(0, 1, 0), "x", 1.0, true, 0.2, true, true).
	vecdraw(v(0, 0, 0), lvlh:basis:y*10, rgb(0, 1, 0), "y", 1.0, true, 0.2, true, true).
	vecdraw(v(0, 0, 0), lvlh:basis:z*10, rgb(0, 1, 0), "z", 1.0, true, 0.2, true, true).

	vecdraw(v(0, 0, 0), ship:facing:upvector*10, rgb(1, 0, 0), "up", 1.0, true, 0.2, true, true).
	vecdraw(v(0, 0, 0), ship:facing:forevector*10, rgb(1, 0, 0), "fore", 1.0, true, 0.2, true, true).
}
