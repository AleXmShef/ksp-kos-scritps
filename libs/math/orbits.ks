@lazyglobal off.

Import(list("globals", "vectors")).

declare global OrbitClass is lexicon(
						"Ap", 0,
						"Pe", 0,
						"Inc", 0,
						"LAN", 0,
						"AoP", 0, //Argument of periapsis
						"T", 0,
						"a", 0, //Semi-Major Axis
						"e", 0, //Eccentricity
						"p", 0,
						"h", 0
).

declare function BuildOrbitFromVR {
	declare parameter v.
	declare parameter r.

	local orb to OrbitClass:copy.

	local v_eci to toIRF(v).
	local r_eci to toIRF(r).
	local h_eci to VCRS(r_eci, v_eci).
	local k_eci to toIRF(V(0,1,0)).
	local n_eci to VCRS(k_eci, h_eci).
	local e_eci to (VCRS(v_eci, h_eci)/Globals["mu"]) - r_eci:NORMALIZED.


	local e to e_eci:MAG.

	local a to 1/(2/r:MAG - (v:mag*v:mag)/Globals["mu"]).

	local p to a * (1 - e * e).


	local LAN to arccos(n_eci:X/n_eci:MAG).
	if(n_eci:Y < 0)
		set LAN to 360 - LAN.

	local AoP to arccos(VDOT(n_eci, e_eci)/(n_eci:MAG*e_eci:MAG)).
	if(e_eci:Z < 0)
		set AoP to 360 - AoP.

	local Inc to VANG(v(0,0,1), h_eci).

	set orb["Inc"] to Inc.
	set orb["LAN"] to LAN.
	set orb["AoP"] to AoP.
	set orb["a"] to a.
	set orb["e"] to e.
	set orb["h"] to h_eci:MAG.
	set orb["p"] to p.
	set orb["T"] to 2*CONSTANT:PI*sqrt((orb["a"] * orb["a"] * orb["a"])/Globals["mu"]).
	set orb["Ap"] to RatAngle(orb, 180):MAG.
	set orb["Pe"] to RatAngle(orb, 0):MAG.

	return orb.
}

declare function BuildOrbit {
	declare parameter orb.
	set orb["a"] to (orb["Ap"] + orb["Pe"])/2.
	set orb["T"] to 2*CONSTANT:PI*sqrt((orb["a"] * orb["a"] * orb["a"])/Globals["mu"]).
	set orb["e"] to (orb["Ap"] - orb["Pe"])/(orb["Ap"] + orb["Pe"]).
	set orb["p"] to orb["a"]*(1-orb["e"]*orb["e"]).
	set orb["h"] to sqrt(orb["p"]*Globals["mu"]).
	return orb.
}

declare function UpdateOrbitParams {
	declare parameter _orb to ship:ORBIT.

	local orb to OrbitClass:COPY.

	set orb["Ap"] to _orb:APOAPSIS + Globals["R"].
	set orb["Pe"] to _orb:PERIAPSIS + Globals["R"].
	set orb["Inc"] to _orb:INCLINATION.
	set orb["LAN"] to _orb:LAN.
	set orb["AoP"] to _orb:ARGUMENTOFPERIAPSIS.
	set orb["T"] to _orb:period.
	set orb["a"] to _orb:SEMIMAJORAXIS.
	set orb["e"] to _orb:ECCENTRICITY.
	set orb["p"] to orb["a"]*(1-orb["e"]*orb["e"]).
	set orb["h"] to sqrt(orb["p"]*Globals["mu"]).

	return orb.
}

declare function RatAngle {
	declare parameter orb.
	declare parameter angle to 0.

	local vec to ANNorm(orb["LAN"], orb["Inc"]):forevector. //Vector alongside AN/DN axis

	local axis to ANNorm(orb["LAN"], orb["Inc"]):upvector.	//Orbit normal vector

	local r to Vrot(vec, axis, -1*(orb["AoP"] + angle)).	//Rotating vector to desired true anomaly

	set r:mag to (orb["p"]/(1 + orb["e"] * cos(angle))).	//Orbit altitude at given true anomaly

	return r.
}

declare function VatR {
	declare parameter orb.
	declare parameter r.

	declare local angle to arccos((orb["p"] - r)/(orb["e"]*r)).

	return VatAngle(orb, 360 - angle).
}

declare function AngleAtT {
	declare parameter orbit.
	declare parameter currentTrueAnomaly.
	declare parameter time.

	LOCAL currentEccentricAnomaly IS ARCTAN(TAN(currentTrueAnomaly/2)/SQRT((1 + orbit["e"])/(1 - orbit["e"])))*2.
	LOCAL currentMeanAnomaly IS currentEccentricAnomaly - orbit["e"]*SIN(currentEccentricAnomaly).

	LOCAL currentMeanMotion IS 360/orbit["T"].

	LOCAL futureMeanAnomaly IS currentMeanAnomaly + time*currentMeanMotion.
	UNTIL (futureMeanAnomaly < 360)
		SET futureMeanAnomaly TO futureMeanAnomaly - 360.
	SET futureMeanAnomaly TO futureMeanAnomaly * CONSTANT:PI/180.

	LOCAL futureEccentricAnomaly IS EuclidNewtonianSolver(futureMeanAnomaly, orbit).
	LOCAL futureTrueAnomaly to 2*ARCTAN(SQRT((1 + orbit["e"])/(1 - orbit["e"]))*TAN((futureEccentricAnomaly * 180/CONSTANT:PI)/2)).

	RETURN futureTrueAnomaly.
}

declare function VatAngle {
	declare parameter orb.
	declare parameter angle.

	local PosVec to RatAngle(orb, angle).

	local axis to ANNorm(orb["LAN"], orb["Inc"]):upvector.

	local VelVec to PosVec:vec.
	set VelVec:mag to sqrt(Globals["mu"] * ((2/PosVec:mag)-(1/orb["a"]))).

	LOCAL idk IS orb["h"]/(PosVec:mag*VelVec:mag).
	IF (idk < -1)
		SET idk TO -1.
	IF (idk > 1)
		SET idk TO 1.
	local depF to arccos(idk).

	if (angle > 180 or angle <= 0)
		set depF to depF*-1.
	local VelVec2 to Vrot(VelVec, axis, -1*(90 - depF)).

	return VelVec2.
}

function AngleAtR {
	parameter orb.
	parameter r.

	return arccos(((orb:p/r) - 1)/orb:e).
}

declare function TtoAngle {
	declare parameter orb.
	declare parameter depPhi.
	declare parameter tgtPhi.

	local r1 to RatAngle(orb, depPhi).
	local r2 to RatAngle(orb, tgtPhi).

	local E1 to arccos((orb["a"] - r1:mag)/(orb["e"]*orb["a"])).
	local E2 to arccos((orb["a"] - r2:mag)/(orb["e"]*orb["a"])).

	local M1 to (E1 * constant:PI/180 - orb["e"]*sin(E1)).
	local M2 to (E2 * constant:PI/180 - orb["e"]*sin(E2)).

	local t1 is 0.
	local t2 is 0.

	if (tgtPhi > 180 and depPhi > 180) {
		if (tgtPhi > depPhi) {
			set t1 to M1*sqrt((orb["a"]*orb["a"]*orb["a"])/Globals["mu"]).
			set t1 to t1 + (orb["T"]/2 - t1)*2.
			set t2 to M2*sqrt((orb["a"]*orb["a"]*orb["a"])/Globals["mu"]).
			set t2 to t2 + (orb["T"]/2 - t2)*2.
		}
		else if (tgtPhi < depPhi) {
			set t1 to M1*sqrt((orb["a"]*orb["a"]*orb["a"])/Globals["mu"]).
			set t1 to t1*-1.
			set t2 to M2*sqrt((orb["a"]*orb["a"]*orb["a"])/Globals["mu"]).
			set t2 to t2 + (orb["T"]/2 - t2)*2.
		}
	}
	else if (tgtPhi > 180 and depPhi < 180) {
		set t1 to M1*sqrt((orb["a"]*orb["a"]*orb["a"])/Globals["mu"]).
		set t2 to M2*sqrt((orb["a"]*orb["a"]*orb["a"])/Globals["mu"]).
		set t2 to t2 + (orb["T"]/2 - t2)*2.
	}
	else if (tgtPhi < 180 and depPhi > 180) {
		set t1 to M1*sqrt((orb["a"]*orb["a"]*orb["a"])/Globals["mu"]).
		set t1 to t1*-1.
		set t2 to M2*sqrt((orb["a"]*orb["a"]*orb["a"])/Globals["mu"]).
	}
	else if (tgtPhi < depPhi) {
		set t1 to M1*sqrt((orb["a"]*orb["a"]*orb["a"])/Globals["mu"]).
		set t1 to orb["T"] - t1.
		set t1 to t1*-1.
		set t2 to M2*sqrt((orb["a"]*orb["a"]*orb["a"])/Globals["mu"]).
	}
	else if (tgtPhi > depPhi) {
		set t1 to M1*sqrt((orb["a"]*orb["a"]*orb["a"])/Globals["mu"]).
		set t2 to M2*sqrt((orb["a"]*orb["a"]*orb["a"])/Globals["mu"]).
	}

	local t is t2 - t1.

	return t.
}

declare function EuclidNewtonianSolver {
	declare parameter M.
	declare parameter orb.
	local E to M.
	until (false) {
		local dE to (E - orb["e"] * sin(E) - M)/(1-orb["e"]*cos(E)).
		set E to E - dE.
		if (abs(dE) < 0.0000001)
			break.
	}
	return E.
}
