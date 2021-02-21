@lazyglobal off.

Import(list("globals", "vectors", "matrixes", "lambertsolver")).

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

declare function RendezvousTransfer {
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
		//SET node TO OrbitTransfer(chaserOrbit, hohmannTransferOrbit).
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

	LOCAL plusY TO -VCRS(ANNorm(orbit["LAN"], orbit["Inc"]):UPVECTOR:NORMALIZED, plusX).
	SET plusY:MAG TO 1.

	LOCAL plusZ IS VCRS(plusX, plusY).
	SET plusZ:MAG TO 1.

	RETURN getTransform(LEXICON("x", plusX, "y", plusY, "z", plusZ)).
}

declare function getTransform {
	DECLARE PARAMETER basis.
	LOCAL transform TO BuildTransformMatrix(basis).
	LOCAL transform_inv to MatrixFindInverse(transform).
	return lexicon("Transform", BuildTransformMatrix(basis), "Inverse", transform_inv, "Basis", basis).
}

declare function CWequationFutureFromCurrent {
	DECLARE PARAMETER chaserShip.
	DECLARE PARAMETER targetShip.
	DECLARE PARAMETER initialTime.
	DECLARE PARAMETER finalTime.

	//Compute craft's positions and velocities
	LOCAL chaserOrbit TO UpdateOrbitParams(chaserShip:ORBIT).
	LOCAL targetOrbit TO UpdateOrbitParams(targetShip:ORBIT).

	LOCAL chaserPosition TO RatAngle(chaserOrbit, AngleAtT(chaserOrbit, chaserShip:ORBIT:TRUEANOMALY, initialTime)).
	LOCAL chaserVelocity TO VatAngle(chaserOrbit, AngleAtT(chaserOrbit, chaserShip:ORBIT:TRUEANOMALY, initialTime)).

	LOCAL targetPosition TO RatAngle(targetOrbit, AngleAtT(targetOrbit, targetShip:ORBIT:TRUEANOMALY, initialTime)).
	LOCAL targetVelocity TO VatAngle(targetOrbit, AngleAtT(targetOrbit, targetShip:ORBIT:TRUEANOMALY, initialTime)).

	LOCAL n IS SQRT((Globals["mu"]) / (TargetOrbit["a"] * TargetOrbit["a"] * TargetOrbit["a"])).

	//Convert ECI to LVLH
	//Create target LVLH basis
	LOCAL LVLH IS getLVLHfromR(targetOrbit, targetPosition).

	//Compute relative position vectors
	LOCAL relativePosition IS chaserPosition - targetPosition.
	LOCAL LVLHrelativePosition IS VCMT(LVLH:Transform, relativePosition).

	//Compute relative velocity vectors
	LOCAL relativeVelocity IS chaserVelocity - targetVelocity - VCRS(n*LVLH:basis:z, relativePosition).
	LOCAL LVLHrelativeVelocity IS VCMT(LVLH:Transform, relativeVelocity).

	LOCAL LVLHrelativePositionFinal TO V(0,0,0).

	IF (finalTime <> 0) {

		LOCAL relativePositionMatrix TO LIST().
		SET relativePositionMatrix TO LIST(
														LIST(LVLHrelativePosition:X),
														LIST(LVLHrelativePosition:Y),
														LIST(LVLHrelativePosition:Z)
													).

		LOCAL relativeVelocityMatrix TO LIST().
		SET relativeVelocityMatrix TO LIST(
														LIST(LVLHrelativeVelocity:X),
														LIST(LVLHrelativeVelocity:Y),
														LIST(LVLHrelativeVelocity:Z)
													).

		SET LVLHrelativePositionFinal TO _CWfindRatT_(relativePositionMatrix, relativeVelocityMatrix, n, finalTime - initialTime).
	}

	RETURN LEXICON(
		"LVLHrelativePosition", LVLHrelativePosition,
		"LVLHrelativeVelocity", LVLHrelativeVelocity,
		"LVLHrelativePositionFinal", LVLHrelativePositionFinal
	).
}

declare function CWequationCurrentVelFromFuturePos {
	DECLARE PARAMETER chaserShip.
	DECLARE PARAMETER targetShip.
	DECLARE PARAMETER LVLHrelativePositionFinal.
	DECLARE PARAMETER initialTime.
	DECLARE PARAMETER finalTime.

	LOCAL debugVectorDraw to FALSE.

	//Compute craft's positions and velocities
	LOCAL chaserOrbit TO UpdateOrbitParams(chaserShip:ORBIT).
	LOCAL targetOrbit TO UpdateOrbitParams(targetShip:ORBIT).

	LOCAL chaserPosition TO 0.
	LOCAL chaserVelocity TO 0.
	LOCAL targetPosition TO 0.
	LOCAL targetVelocity TO 0.
	LOCAL targetPositionFinal TO 0.
	LOCAL targetVelocityFinal TO 0.

	LOCAL bodyPos to chaserShip:BODY:POSITION.

	SET chaserPosition TO chaserShip:ORBIT:POSITION - bodyPos.
	SET chaserVelocity TO chaserShip:VELOCITY:ORBIT.

	SET targetPosition TO targetShip:ORBIT:POSITION - bodyPos.
	SET targetVelocity TO targetShip:VELOCITY:ORBIT.
	//}

	LOCAL n IS SQRT(Globals["mu"] / (TargetOrbit["a"] * TargetOrbit["a"] * TargetOrbit["a"])).

	//Convert ECI to LVLH
	//Create target LVLH basis
	LOCAL LVLH IS getLVLHfromR(targetOrbit, targetPosition).

	//Compute relative position vectors
	LOCAL relativePosition IS chaserPosition - targetPosition.
	LOCAL LVLHrelativePosition IS VCMT(LVLH:Transform, relativePosition).

	LOCAL relativeVelocity IS chaserVelocity - targetVelocity - VCRS(n*LVLH:basis:z, relativePosition).
	LOCAL LVLHrelativeVelocity IS VCMT(LVLH:Transform, relativeVelocity).

	LOCAL relativePositionMatrix IS LIST().
	SET relativePositionMatrix TO LIST(
													LIST(LVLHrelativePosition:X),
													LIST(LVLHrelativePosition:Y),
													LIST(LVLHrelativePosition:Z)
												).

	LOCAL relativePositionFinalMatrix IS LIST().
	SET relativePositionFinalMatrix TO LIST(
													LIST(LVLHrelativePositionFinal:X),
													LIST(LVLHrelativePositionFinal:Y),
													LIST(LVLHrelativePositionFinal:Z)
												).

	LOCAL targetLVLHrelativeVelocity TO _CWfindVatT_(relativePositionMatrix, relativePositionFinalMatrix, n, finalTime - initialTime).
	LOCAL targetRelativeVelocity TO VCMT(LVLH:Inverse, targetLVLHrelativeVelocity).

	LOCAL targetChaserVelocity IS targetRelativeVelocity + targetVelocity + VCRS(n*LVLH:basis:z, relativePosition).

	IF(debugVectorDraw = true) {
		CLEARVECDRAWS().
		vecdraw(V(0,0,0), LVLH:basis:X*10, rgb(1, 0, 0), "X", 1.0, true, 0.2, true, true).
		vecdraw(V(0,0,0), LVLH:basis:Y*10, rgb(0, 1, 0), "Y", 1.0, true, 0.2, true, true).
		vecdraw(V(0,0,0), LVLH:basis:Z*10, rgb(0, 0, 1), "Z", 1.0, true, 0.2, true, true).

		local posVec to LVLH:basis:X*LVLHrelativePosition:X + LVLH:basis:Y*LVLHrelativePosition:Y + LVLH:basis:Z*LVLHrelativePosition:Z.
		local velVec to LVLH:basis:X*LVLHrelativeVelocity:X + LVLH:basis:Y*LVLHrelativeVelocity:Y + LVLH:basis:Z*LVLHrelativeVelocity:Z.
		vecdraw(V(0,0,0), -posVec, rgb(0, 1, 1), "pos", 1.0, true, 0.2, true, true).
		vecdraw(V(0,0,0), velVec*10, rgb(1, 0, 1), "vel", 1.0, true, 0.2, true, true).
	}

	RETURN LEXICON(
		"LVLHrelativePosition", LVLHrelativePosition,
		"LVLHrelativeVelocity", LVLHrelativeVelocity,
		"targetLVLHrelativeVelocity", targetLVLHrelativeVelocity,
		"chaserVelocity", chaserVelocity,
		"targetChaserVelocity", targetChaserVelocity,
		"chaserPosition", chaserPosition,
		"chaserOrbit", chaserOrbit
	).
}

declare function _CWfindRatT_ {
	declare parameter currentR.
	declare parameter currentV.
	declare parameter n.
	declare parameter t.

	//LOCAL _n IS n.
	LOCAL _n IS n * 180/CONSTANT:PI.


	local Mtrans is LIST().	//---------------Mtransition Matrix
	set Mtrans to list(list(4-3*cos(_n*t), 	   0, 0),
									 list(6*(sin(_n*t) - n*t),  1, 0),
									 list(0,                   0, cos(_n*t))
									 ).
	local Ntrans is LIST().	//---------------Ntransition Matrix
	set Ntrans to list(list((1/n)*sin(_n*t),          (2/n)*(1 - cos(_n*t)),     0),
									 list((2/n)*(cos(_n*t) - 1), (1/n)*(4*sin(_n*t)-3*n*t), 0),
									 list(0,                       0,                        (1/n)*sin(_n*t))
									 ).
	local MR is MatrixMultiply(Mtrans, currentR).
	local NV is MatrixMultiply(Ntrans, currentV).
	local futureR to MatrixAdd(MR, NV). //Relative Velocity at T
	return v(futureR[0][0], futureR[1][0], futureR[2][0]).
}

declare function _CWfindVatT_ {
	declare parameter currentR.
	declare parameter futureR.
	declare parameter n.
	declare parameter t.

	LOCAL _n IS n * 180/CONSTANT:PI.


	local Mtrans is LIST().	//---------------Mtransition Matrix
	set Mtrans to list(list(4-3*cos(_n*t), 	   			0, 				0),
									 list(6*(sin(_n*t) - n*t),  		1, 				0),
									 list(0,                   			0, 		cos(_n*t))
									 ).
	local Ntrans is LIST().	//---------------Ntransition Matrix
	set Ntrans to list(
									list((1/n)*sin(_n*t),				(2/n)*(1 - cos(_n*t)),								0),
									list((2/n)*(cos(_n*t) - 1),			(1/n)*(4*sin(_n*t)-3*n*t),							0),
									list(0,								0,										(1/n)*sin(_n*t))
									).

	 LOCAL NtransInverse IS MatrixFindInverse(Ntrans).
	 LOCAL MR IS MatrixMultiply(Mtrans, currentR).
	 LOCAL idk IS MatrixSubtract(futureR, MR).
	 LOCAL futureV IS MatrixMultiply(NtransInverse, idk).
	 RETURN v(futureV[0][0], futureV[1][0], futureV[2][0]).
}

declare function OrbitTransfer {
	declare parameter DepartureOrbit.
	declare parameter TargetOrbit.
	declare parameter maxIterations to 1000.
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
		until (converged <> 0 or iterations >= maxIterations) {
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
		if(iterations >= maxIterations) {
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
