@lazyglobal off.
declare function calcBurnTime {
	declare parameter DeltaV.
	declare parameter thr.
	declare parameter isp.

	local Mdot to (thr/(isp*9.80665))*1000.
	local PropMass to ship:mass*1000 - (ship:mass*1000 / (constant:e^(sqrt((DeltaV)^2)/(isp*9.80665)))).
	local BurnTime to PropMass/Mdot.

	return BurnTime.

}

declare function calcDeltaVfromBurnTime {
	declare parameter time.
	declare parameter thr.
	declare parameter isp.

	local Mdot to (thr/(isp*9.80665))*1000.
	local PropMass to Mdot * time.
	local M1 to ship:mass*1000.
	local M2 to ship:mass*1000 - PropMass.
	local DeltaV to isp * 9.80665 * ln(M1/M2).

	return DeltaV.
}

declare global Globals is lexicon(
						"G", SHIP:ORBIT:BODY:MU/SHIP:ORBIT:BODY:MASS,
						"M", SHIP:ORBIT:BODY:MASS,
						"mu", SHIP:ORBIT:BODY:MU,
						"R", SHIP:ORBIT:BODY:RADIUS,
						"EarthRotationSpeed", 360/SHIP:ORBIT:BODY:ROTATIONPERIOD
).

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
	declare parameter orb.
	declare parameter _orb to ship:ORBIT.

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

	set vec to Vrot(vec, axis, -1*(orb["AoP"] + angle)).	//Rotating vector to desired true anomaly

	set vec:mag to (orb["p"]/(1 + orb["e"] * cos(angle))).	//Orbit altitude at given true anomaly

	return vec.
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

declare function RatAngle_old {
	declare parameter orb.
	declare parameter angle to 0.

	return (orb["p"]/(1 + orb["e"] * cos(angle))).
}

declare function VatR_old {
	declare parameter orb.
	declare parameter r.

	return sqrt(Globals["mu"] * ((2/r)-(1/orb["a"]))).
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

declare function TtoR {
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

declare function RendezvousTransferDemo {
	CLEARVECDRAWS().
	terminal:input:clear().
	declare parameter chaserOrbit.
	declare parameter targetOrbit.
	declare parameter YBarDistance.
	declare parameter RBarDistance.
	declare parameter chaserTrueAnomaly.
	declare parameter targetTrueAnomaly.
	declare parameter lambertSolverFlag TO TRUE.

	LOCAL tNow IS TIME:SECONDS.

	LOCAL chaserAbsoluteTrueAnomaly IS chaserTrueAnomaly + chaserOrbit["AoP"].
	IF (chaserAbsoluteTrueAnomaly > 360) {
		UNTIL (chaserAbsoluteTrueAnomaly < 360)
			SET chaserAbsoluteTrueAnomaly TO chaserAbsoluteTrueAnomaly -360.
	}

	LOCAL targetAbsoluteTrueAnomaly IS targetTrueAnomaly + targetOrbit["AoP"].
	IF (targetAbsoluteTrueAnomaly > 360) {
		UNTIL (targetAbsoluteTrueAnomaly < 360)
			SET targetAbsoluteTrueAnomaly TO targetAbsoluteTrueAnomaly -360.
	}

	LOCAL currentPhasingAngle IS targetAbsoluteTrueAnomaly - chaserAbsoluteTrueAnomaly.
	IF (currentPhasingAngle < 0)
		SET currentPhasingAngle TO 360 + currentPhasingAngle.

	LOCAL chaserAverageAngularVelocity IS 360/chaserOrbit["T"].
	LOCAL targetAverageAngularVelocity IS 360/targetOrbit["T"].

	LOCAL averageRelativeAngularVelocity IS chaserAverageAngularVelocity - targetAverageAngularVelocity.

	LOCAL averageHohmannTransferOrbit IS chaserOrbit:COPY.
	SET averageHohmannTransferOrbit["Ap"] TO targetOrbit["Ap"] - RBarDistance*1000.
	SET averageHohmannTransferOrbit TO BuildOrbit(averageHohmannTransferOrbit).

	LOCAL additive is 10.
	LOCAL burnCoastTime IS averageHohmannTransferOrbit["T"]/2 - 40.
	LOCAL done IS FALSE.
	LOCAL diff IS 10000000.
	LOCAL node IS LEXICON("node", 0, "dV", 1000000000000000).
	LOCAL _coastTimeBeforeBurn IS 0.
	LOCAL _burnCoastTime IS 0.
	LOCAL angle IS 180.

	IF(lambertSolverFlag) {
		UNTIL (done = TRUE) {

			SET burnCoastTime TO burnCoastTime + additive.

			//SET burnCoastTime TO averageHohmannTransferOrbit["T"]/2.

			LOCAL idk IS 180/(averageHohmannTransferOrbit["T"]/2).

			LOCAL chaserHohmannAverageAngularVelocity IS idk.
			//LOCAL chaserHohmannAverageAngularVelocity IS (185)/(burnCoastTime).

			LOCAL averagePostBurnRelativeAngularVelocity IS chaserHohmannAverageAngularVelocity - targetAverageAngularVelocity.

			LOCAL burnCoastRelativeAngle IS averagePostBurnRelativeAngularVelocity*burnCoastTime.

			LOCAL phasingAngleAfterBurn IS ((YBarDistance*1000 * 180) / (CONSTANT:PI * targetOrbit["Ap"])).

			//LOCAL phasingAngleAfterBurn IS 0.

			LOCAL burnPhasingAngle IS (phasingAngleAfterBurn + burnCoastRelativeAngle).

			LOCAL coastTimeBeforeBurn IS ((currentPhasingAngle - burnPhasingAngle) / averageRelativeAngularVelocity).

			LOCAL r1 IS RatAngle(chaserOrbit, AngleAtT(chaserOrbit, chaserTrueAnomaly, coastTimeBeforeBurn)).
			LOCAL _r2 IS RatAngle(targetOrbit, AngleAtT(targetOrbit, targetTrueAnomaly, coastTimeBeforeBurn + burnCoastTime)).
			LOCAL r2 IS Vrot(_r2, ANNorm(targetOrbit["LAN"], targetOrbit["Inc"]):UPVECTOR, phasingAngleAfterBurn).
			set r2:MAG TO r2:MAG - RBarDistance*1000.

			set angle to vang(r1, r2).


			LOCAL targetV IS lambert2(r1, r2, burnCoastTime, Globals["mu"])["v0"].

			LOCAL _node IS nodeFromV(chaserOrbit, r1, VatAngle(chaserOrbit, AngleAtT(chaserOrbit, chaserTrueAnomaly, coastTimeBeforeBurn)), targetV).

			clearscreen.
			PRINT "previous deltaV: " + node["dV"] at (0, 0).
			PRINT "deltaV: " + _node["dV"] at (0,1).
			print "additive: " + additive at (0,2).
			if(_node["dV"] > node["dV"]) {
				LOCAL _diff IS (_node["dV"] - abs(additive)*5) - node["dV"].
				IF (_diff > diff) {
					SET additive TO additive * -0.5.
					SET diff TO 1000000.
				}
				ELSE
					SET diff TO _diff.
			}
			IF(_node["dV"] < node["dV"]) {
				SET node TO _node.
				SET _coastTimeBeforeBurn TO coastTimeBeforeBurn.
				SET _burnCoastTime TO burnCoastTime.
				SET diff TO 10000000.
			}
			IF (node["dV"] < 150)
				IF (additive > 10)
					SET additive TO 5.
			PRINT "min dV: " + node["dV"] at (0,3).
			PRINT "diff: " + (averageHohmannTransferOrbit["T"]/2 - _burnCoastTime) at (0,4).
			//WAIT UNTIL (TERMINAL:INPUT:HASCHAR).
			//TERMINAL:INPUT:CLEAR().
			//SET done TO TRUE.
			if(abs(additive) < 0.1)
				SET done TO TRUE.
		}
	}
	ELSE {
		SET burnCoastTime TO averageHohmannTransferOrbit["T"]/2.

		LOCAL chaserHohmannAverageAngularVelocity IS 180/(burnCoastTime).

		LOCAL averagePostBurnRelativeAngularVelocity IS chaserHohmannAverageAngularVelocity - targetAverageAngularVelocity.

		LOCAL burnCoastRelativeAngle IS averagePostBurnRelativeAngularVelocity*burnCoastTime.

		LOCAL phasingAngleAfterBurn IS ((YBarDistance*1000 * 180) / (CONSTANT:PI * targetOrbit["Ap"])).

		LOCAL burnPhasingAngle IS (phasingAngleAfterBurn + burnCoastRelativeAngle).

		LOCAL coastTimeBeforeBurn IS ((currentPhasingAngle - burnPhasingAngle) / averageRelativeAngularVelocity).
		PRINT "TEST: " + (1650*averageRelativeAngularVelocity).

		LOCAL r1 IS RatAngle(chaserOrbit, AngleAtT(chaserOrbit, chaserTrueAnomaly, coastTimeBeforeBurn)).
		LOCAL _r2 IS RatAngle(targetOrbit, AngleAtT(targetOrbit, targetTrueAnomaly, coastTimeBeforeBurn + burnCoastTime)).
		LOCAL r2 IS Vrot(_r2, ANNorm(TargetOrbit["LAN"], TargetOrbit["Inc"]):UPVECTOR, phasingAngleAfterBurn).
		set r2:MAG TO r2:MAG - RBarDistance*1000.

		LOCAL hohmannTransferOrbit IS OrbitClass:COPY.
		SET hohmannTransferOrbit["Pe"] TO r1:MAG.
		SET hohmannTransferOrbit["Ap"] TO r2:MAG.
		LOCAL hohAoP IS AngleAtT(chaserOrbit, chaserTrueAnomaly, coastTimeBeforeBurn) + chaserOrbit["AoP"].
		IF (hohAoP > 360) {
			UNTIL (hohAoP < 360)
				SET hohAoP TO hohAoP -360.
		}
		SET hohmannTransferOrbit["AoP"] TO hohAoP + 0.01.
		SET hohmannTransferOrbit["LAN"] TO chaserOrbit["LAN"].
		SET hohmannTransferOrbit["Inc"] TO chaserOrbit["Inc"].
		SET hohmannTransferOrbit TO BuildOrbit(hohmannTransferOrbit).

		PRINT "diff: " + (hohmannTransferOrbit["T"]/2 - averageHohmannTransferOrbit["T"]/2).

		LOCAL targetV IS VatAngle(hohmannTransferOrbit, 359.9).
		SET node TO nodeFromV(chaserOrbit, r1, VatAngle(chaserOrbit, chaserTrueAnomaly + coastTimeBeforeBurn*chaserAverageAngularVelocity), targetV).
		//SET node TO OrbitTransferDemo(chaserOrbit, hohmannTransferOrbit).
		//PRINT "deltaV: " + node["dV"] at (0,1).
		SET _coastTimeBeforeBurn TO coastTimeBeforeBurn.
		SET _burnCoastTime TO burnCoastTime.
	}
	IF(_coastTimeBeforeBurn > 7200) {
		LOCAL tooFar IS LEXICON("node", "none", "warpTime", _coastTimeBeforeBurn - 1000).
		RETURN tooFar.
	}
	ELSE {
		LOCAL burn IS LEXICON("node", node["node"], "dV", node["dVvec"], "depTime", _coastTimeBeforeBurn, "burnCoastTime", _burnCoastTime, "arrivalTime", TIME:SECONDS + _coastTimeBeforeBurn + _burnCoastTime).
		SET burn["node"]:ETA TO _coastTimeBeforeBurn.
		RETURN burn.
	}

}

declare function getLVLHfromR {
	DECLARE PARAMETER orbit.
	DECLARE PARAMETER position.

	LOCAL plusX IS position:VEC.
	SET plusX:MAG TO 1.

	LOCAL plusY TO VCRS(ANNorm(orbit["LAN"], orbit["Inc"]):UPVECTOR:NORMALIZED, plusX).
	SET plusY:MAG TO 1.

	LOCAL plusZ IS VCRS(plusX, plusY).
	SET plusZ:MAG TO 1.
	RETURN LEXICON("x", plusX, "y", plusY, "z", plusZ).
}

declare function getECI {	//TODO: Convert all functions to return true ECI
	return LEXICON("x", v(1,0,0), "y", v(1,0,0), "z", v(0,0,1)).
}

declare function convertToLVLH {
	declare parameter LVLH.
	declare parameter vec.

	LOCAL plusX IS LVLH["x"]:VEC.
	LOCAL plusY IS LVLH["y"]:VEC.
	LOCAL plusZ IS LVLH["z"]:VEC.

	LOCAL XYplane IS vec - (plusZ * (vec:mag*cos(vang(vec, plusZ)))).

	LOCAL x TO XYplane:MAG * cos(vang(XYplane, plusX)).
	LOCAL y TO XYplane:MAG * cos(vang(XYplane, plusY)).
	LOCAL Zvec TO vec - XYplane.
	LOCAL z TO Zvec:MAG * cos(vang(Zvec, plusZ)).



	RETURN v(x, y, z).
}

declare function CWequation {
	DECLARE PARAMETER chaserPosition.
	DECLARE PARAMETER chaserVelocity.
	DECLARE PARAMETER time.
	DECLARE PARAMETER targetOrbit.
	DECLARE PARAMETER targetPosition.
	DECLARE PARAMETER targetVelocity.

	LOCAL n IS SQRT((Globals["mu"]) / (TargetOrbit["a"] * TargetOrbit["a"] * TargetOrbit["a"])).

	//Convert ECI to LVLH
	//Create target LVLH basis
	LOCAL LVLH IS getLVLHfromR(targetOrbit, targetPosition).
	LOCAL ECI IS getECI().

	//Compute relative position vectors
	LOCAL relativePosition IS chaserPosition - targetPosition.
	LOCAL LVLHrelativePosition IS convertToLVLH(LVLH, relativePosition).

	SET relativePositionMatrix["MatrixSelf"] TO LIST(
													LIST(LVLHrelativePosition:X),
													LIST(LVLHrelativePosition:Y),
													LIST(LVLHrelativePosition:Z)
												).

	//Compute relative velocity vectors
	LOCAL relativeVelocity IS chaserVelocity - targetVelocity - VCRS(n*plusZ, relativePosition).
	LOCAL LVLHrelativeVelocity IS convertToLVLH(LVLH, relativeVelocity).

	SET relativeVelocityMatrix["MatrixSelf"] TO LIST(
													LIST(LVLHrelativeVelocity:X),
													LIST(LVLHrelativeVelocity:Y),
													LIST(LVLHrelativeVelocity:Z)
												).

	LOCAL LVLHrelativePositionFinal TO _CWfindRatT_(relativePositionMatrix, relativeVelocityMatrix, n, time).

	RETURN LEXICON("LVLHcurrentR", LVLHrelativePosition, "LVLHcurrentV", LVLHrelativeVelocity, "LVLHfutureR", LVLHrelativePositionFinal).
}

declare function CWgetVelocityFromPositions {
	DECLARE PARAMETER chaserPosition.
	DECLARE PARAMETER chaserPositionFinal.
	DECLARE PARAMETER time.
	DECLARE PARAMETER targetOrbit.
	DECLARE PARAMETER targetPosition.
	DECLARE PARAMETER targetVelocity.
	DECLARE PARAMETER targetPositionFinal.

	LOCAL n IS SQRT(Globals["mu"] / (TargetOrbit["a"] * TargetOrbit["a"] * TargetOrbit["a"])).

	//Convert ECI to LVLH

	//Create target LVLH basis
	LOCAL LVLH IS getLVLHfromR(targetOrbit, targetPosition).
	LOCAL ECI if getECI().

	//Compute relative position vectors
	LOCAL relativePosition IS chaserPosition - targetPosition.
	LOCAL LVLHrelativePosition IS convertToLVLH(LVLH, relativePosition).

	LOCAL LVLHfinal IS getLVLHfromR(targetOrbit, targetPositionFinal).

	LOCAL relativePositionFinal IS chaserPositionFinal - targetPositionFinal.
	LOCAL LVLHrelativePositionFinal IS convertToLVLH(LVLHfinal, relativePositionFinal).

	LOCAL relativePositionMatrix IS MatrixClass:COPY.
	SET relativePositionMatrix["MatrixSelf"] TO LIST(
													LIST(LVLHrelativePosition:X),
													LIST(LVLHrelativePosition:Y),
													LIST(LVLHrelativePosition:Z)
												).

	LOCAL relativePositionFinalMatrix IS MatrixClass:COPY.
	SET relativePositionFinalMatrix["MatrixSelf"] TO LIST(
													LIST(LVLHrelativePositionFinal:X),
													LIST(LVLHrelativePositionFinal:Y),
													LIST(LVLHrelativePositionFinal:Z)
												).

	LOCAL LVLHrelativeVelocity IS _CWfindVatT_(relativePositionMatrix, relativePositionFinalMatrix, n, time).

	LOCAL chaserVelocity IS LVLHrelativeVelocity + targetVelocity + VCRS(n*plusZ, relativePosition).

	RETURN chaserVelocity.
}

declare function _CWfindRatT_ {
	declare parameter currentR.
	declare parameter currentV.
	declare parameter n.
	declare parameter t.

	//LOCAL _n IS n.
	LOCAL _n IS n * 180/CONSTANT:PI.


	local Mtrans is MatrixClass:copy.	//---------------Mtransition Matrix
	set Mtrans["MatrixSelf"] to list(list(4-3*cos(_n*t), 	   0, 0),
									 list(6*(sin(_n*t) - n*t),  1, 0),
									 list(0,                   0, cos(_n*t))
									 ).
	local Ntrans is MatrixClass:copy.	//---------------Ntransition Matrix
	set Ntrans["MatrixSelf"] to list(list((1/n)*sin(_n*t),          (2/n)*(1 - cos(_n*t)),     0),
									 list((2/n)*(cos(_n*t) - 1), (1/n)*(4*sin(_n*t)-3*n*t), 0),
									 list(0,                       0,                        (1/n)*sin(_n*t))
									 ).
	local MR is MatrixMultiply(Mtrans, currentR).
	local NV is MatrixMultiply(Ntrans, currentV).
	local futureR to MatrixAdd(MR, NV)["MatrixSelf"]. //Relative Velocity at T
	return v(futureR[0][0], futureR[1][0], futureR[2][0]).
}

declare function _CWfindVatT_ {
	declare parameter currentR.
	declare parameter futureR.
	declare parameter n.
	declare parameter t.

	LOCAL _n IS n * 180/CONSTANT:PI.


	local Mtrans is MatrixClass:copy.	//---------------Mtransition Matrix
	set Mtrans["MatrixSelf"] to list(list(4-3*cos(_n*t), 	   0, 0),
									 list(6*(sin(_n*t) - n*t),  1, 0),
									 list(0,                   0, cos(_n*t))
									 ).
	local Ntrans is MatrixClass:copy.	//---------------Ntransition Matrix
	set Ntrans["MatrixSelf"] to list(list((1/n)*sin(_n*t),          (2/n)*(1 - cos(_n*t)),     0),
									 list((2/n)*(cos(_n*t) - 1), (1/n)*(4*sin(_n*t)-3*n*t), 0),
									 list(0,                       0,                        (1/n)*sin(_n*t))
									 ).

	 LOCAL NtransInverse IS MatrixFindInverse(Ntrans).
	 LOCAL MR IS MatrixMultiply(Mtrans, currentR).
	 LOCAL idk IS MatrixSubtract(futureR, MR).
	 LOCAL futureV IS MatrixMultiply(NtransInverse, idk).
	 RETURN futureV.
}

declare function OrbitTransferDemo {
	declare parameter DepartureOrbit.
	declare parameter TargetOrbit.
	local TargetOrbitCopyOne to TargetOrbit:copy.
	local TargetOrbitCopyTwo to TargetOrbit:copy.
	local TargetOrbitCopyThree to TargetOrbit:copy.
	local TargetOrbitCopyFour to TargetOrbit:copy.

	local aphi is 0.
	local aphiOne to FindOrbitIntersection(DepartureOrbit, TargetOrbit).
	local aphiTwo to FindOrbitIntersection(DepartureOrbit, TargetOrbit).
	local aphiThree to FindOrbitIntersection(DepartureOrbit, TargetOrbit).
	local aphiFour to FindOrbitIntersection(DepartureOrbit, TargetOrbit).

	if(aphiOne = 0) {
		local converged to 0.
		local iterations to 0.
		until (converged <> 0 or iterations >= 30) {
			set TargetOrbitCopyOne["Pe"] to TargetOrbit["Pe"] - 10.
			set TargetOrbitCopyOne to BuildOrbit(TargetOrbitCopyOne).
			set aphiOne to FindOrbitIntersection(DepartureOrbit, TargetOrbitCopyOne).

			set TargetOrbitCopyTwo["Pe"] to TargetOrbitCopyTwo["Pe"] + 10.
			set TargetOrbitCopyTwo to BuildOrbit(TargetOrbitCopyTwo).
			set aphiTwo to FindOrbitIntersection(DepartureOrbit, TargetOrbitCopyTwo).

			set TargetOrbitCopyThree["Ap"] to TargetOrbitCopyThree["Ap"] - 10.
			set TargetOrbitCopyThree to BuildOrbit(TargetOrbitCopyThree).
			set aphiThree to FindOrbitIntersection(DepartureOrbit, TargetOrbitCopyThree).

			set TargetOrbitCopyFour["Ap"] to TargetOrbitCopyFour["Ap"] + 10.
			set TargetOrbitCopyFour to BuildOrbit(TargetOrbitCopyFour).
			set aphiFour to FindOrbitIntersection(DepartureOrbit, TargetOrbitCopyFour).

			if(aphiOne <> 0) {
				set aphi to aphiOne.
				set TargetOrbit to TargetOrbitCopyOne.
				set converged to 1.
			}
			else if(aphiTwo <> 0) {
				set aphi to aphiTwo.
				set TargetOrbit to TargetOrbitCopyTwo.
				set converged to 1.
			}
			else if(aphiThree <> 0) {
				set aphi to aphiThree.
				set TargetOrbit to TargetOrbitCopyThree.
				set converged to 1.
			}
			else if(aphiFour <> 0) {
				set aphi to aphiFour.
				set TargetOrbit to TargetOrbitCopyFour.
				set converged to 1.
			}
			set iterations to iterations + 1.
		}
		if(iterations >= 30) {
			return lexicon("result", 0).
		}
	}
	else
		set aphi to aphiOne.

	local phi to aphi[0].
	local phi2 to aphi[2].

	local depV to VatAngle(DepartureOrbit, phi).
	local tgtV to VatAngle(TargetOrbit, phi2).
	local R is RatAngle(DepartureOrbit, phi).

	local dV to tgtV - depV.
	local progVec to depV:vec:normalized.
	local normVec to  ANNorm(DepartureOrbit["LAN"], DepartureOrbit["Inc"]):UPVECTOR:normalized.
	local radVec is -vcrs(progVec, normVec):normalized.
	if(vang(R, radVec) > 90) {
		clearscreen.
		print "fatal error".
		wait 4.
		set radVec to radVec * -1.
	}
	local orbPlaneVec to dV - normVec*(dV:mag*cos(vang(dV, normVec))).
	local progV to orbPlaneVec:mag*cos(vang(progVec, orbPlaneVec)).
	local radV to orbPlaneVec:mag*cos(vang(radVec, orbPlaneVec)).
	local tangentPlaneVec to dV - radVec*(dV:mag*cos(vang(dV, radVec))).
	local normV to tangentPlaneVec:mag*cos(vang(normVec, tangentPlaneVec)).

	local mnode to NODE(time:seconds + TtoR(DepartureOrbit, ship:orbit:trueanomaly, phi), radV, normV, progV).
	return lexicon("node", mnode, "dV", dV, "tgtV", tgtV:mag, "tgtVvec", tgtV, "depTime", time:seconds + TtoR(DepartureOrbit, ship:orbit:trueanomaly, phi), "result", 1).
}

declare function nodeFromV {
	declare parameter orbit.
	declare parameter R.
	declare parameter depV.
	declare parameter tgtV.

	local dV to tgtV - depV.
	local progVec to depV:vec:normalized.
	local normVec to  ANNorm(orbit["LAN"], orbit["Inc"]):UPVECTOR:normalized.
	local radVec is -vcrs(progVec, normVec):normalized.
	if(vang(R, radVec) > 90) {
		clearscreen.
		print "fatal error".
		wait 4.
		set radVec to radVec * -1.
	}
	local orbPlaneVec to dV - normVec*(dV:mag*cos(vang(dV, normVec))).
	local progV to orbPlaneVec:mag*cos(vang(progVec, orbPlaneVec)).
	local radV to orbPlaneVec:mag*cos(vang(radVec, orbPlaneVec)).
	local tangentPlaneVec to dV - radVec*(dV:mag*cos(vang(dV, radVec))).
	local normV to tangentPlaneVec:mag*cos(vang(normVec, tangentPlaneVec)).

	local _dv is progVec * progV + radVec * radV + normVec * normV.
	local _willBeV is depV + _dv.
	if(abs(_willBeV:mag - tgtV:mag) > 0.001 or vang(tgtV, _willBeV) > 0.001) {
		clearscreen.
		print "fatal error: ".
		print "dV: " + dV.
		print "_dv: " + _dv.
		wait 100000.
	}

	local mnode to NODE(time:seconds, radV, normV, progV).
	return lexicon("node", mnode, "dV", dV:mag, "dVvec", dV).
}

declare function OrbitTransfer {

	declare parameter DepartureOrbit.
	declare parameter TargetOrbit.
	set dif to 0.

	set relang to -1*(DepartureOrbit["Inc"] - TargetOrbit["Inc"]).

	if (true) {
		set aphi to FindOrbitIntersection(DepartureOrbit, TargetOrbit).
		until (aphi <> 0) {
			set TargetOrbit["Pe"] to TargetOrbit["Pe"] - 100.
			set TargetOrbit["Ap"] to TargetOrbit["Ap"] + 100.
			set aphi to FindOrbitIntersection(DepartureOrbit, TargetOrbit).
		}
		set phi to aphi[0].
		set phi2 to aphi[2].
		set r to RatAngle_old(DepartureOrbit, phi).

		set depv to VatR(DepartureOrbit, r).
		set depF to arccos(DepartureOrbit["h"]/(r*depv)).
		if (phi > 180)
			set depF to depF*-1.
		set tgtv to VatR(TargetOrbit, r).
		set tgtF to arccos(TargetOrbit["h"]/(r*tgtv)).
		if (phi2 > 180)
			set tgtF to tgtF*-1.
		if(depF/abs(depF) <> tgtF/abs(tgtF)) {
			set dF to (abs(tgtF) + abs(depF)).
			set dif to 1.
		}
		else
			set dF to abs (tgtF - depF).
		set dVv to sqrt(depv*depv + tgtv*tgtv - 2*depv*tgtv*cos(dF)).
		set dVang to arccos((dVv*dVv + depv*depv - tgtv*tgtv)/(2*depv*dVv)).
		set dVprog to -1*dVv*cos(dVang).
		if (dif = 0) {
			if (depF >= tgtF)
				set dVrad to -1*dVv*sin(dVang).
			else
				set dVrad to dVv*sin(dVang).
		}
		else if (dif = 1) {
			if (tgtF < 0)
				set dVrad to -1*dVv*sin(dVang).
			else
				set dVrad to dVv*sin(dVang).
		}

		set meta to time:seconds + TtoR(DepartureOrbit, ship:orbit:trueanomaly, phi).

		set dVnorm to 0.

		if (relang <> 0) {
			if (abs(phi - (360 - DepartureOrbit["AoP"])) < 5 or abs(phi - (360 - DepartureOrbit["AoP"])) > 355) {

				set depvec to v(depv, 0, 0).
				set dVvec to v(dVprog, 0, dVrad).
				set tgtvec to (depvec+dVvec).
				set dVnorm to tgtvec:mag*sin(relang).

				set dVv to sqrt(depv*depv + tgtv*tgtv - 2*depv*tgtv*cos(dF)).
				set dVang to arccos((dVv*dVv + depv*depv - tgtv*tgtv)/(2*depv*dVv)).
				set dVprog to -1*dVv*cos(dVang)  - (tgtvec:mag - tgtvec:mag*cos(relang)).
				if (dif = 0) {
					if (depF >= tgtF)
						set dVrad to -1*dVv*sin(dVang).
					else
						set dVrad to dVv*sin(dVang).
				}
				else if (dif = 1) {
					if (tgtF < 0)
						set dVrad to -1*dVv*sin(dVang).
					else
						set dVrad to dVv*sin(dVang).
				}
			}
		}

		set result to NODE(meta, dVrad, dVnorm, dVprog).
		return result.
	}
	else
		return 0.
}

declare function FindOrbitIntersection {
	declare parameter orb1.
	declare parameter orb2.

	local dphi to orb2["AoP"] - orb1["AoP"].

	local a to (orb1["p"] * orb2["e"] * cos(dphi)) - (orb2["p"] * orb1["e"]).
	local b to (orb1["p"] * orb2["e"] * sin(dphi)).
	local c to (orb1["p"] - orb2["p"]).

	local t to a.
	set a to c - a.
	set c to c + t.
	set b to b * 2.

	local D to b*b - 4 * a * c.

	if(a = 0) {
		return 0.
	}
	else if (D >= 0) {
		local x1 to (-1*b + sqrt(D))/(2*a).
		set x1 to 2 * arctan(x1).
		local x3 to x1 - dphi.
		if (x1 < 0)
			set x1 to x1 + 360.
		if (x3 < 0)
			set x3 to x3 + 360.

		local x2 to (-1*b - sqrt(D))/(2*a).
		set x2 to 2 * arctan(x2).
		local x4 to x2 - dphi.
		if (x2 < 0)
			set x2 to x2 + 360.
		if (x4 < 0)
			set x4 to x4 + 360.

		local result to list(x1, x2, x3, x4).
		return result.
	}
	else {
		return 0.
	}
}
