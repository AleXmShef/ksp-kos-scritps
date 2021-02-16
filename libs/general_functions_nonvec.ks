

declare function calcBurnTime {
	declare parameter DeltaVs.
	declare parameter thr.
	declare parameter isp.
	
	set Mdot to (thr/(isp*9.80665))*1000.
	set PropMass to ship:mass*1000 - (ship:mass*1000 / (constant:e^(sqrt((DeltaVs)^2)/(isp*9.80665)))).
	set BurnTime to PropMass/Mdot.
	
	print BurnTime at (0, 20).
	wait 5.
	return BurnTime.
	
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
	
	set orb["Ap"] to SHIP:ORBIT:APOAPSIS + Globals["R"].
	set orb["Pe"] to SHIP:ORBIT:PERIAPSIS + Globals["R"].
	set orb["Inc"] to SHIP:ORBIT:INCLINATION.
	set orb["LAN"] to SHIP:ORBIT:LAN.
	set orb["AoP"] to SHIP:ORBIT:ARGUMENTOFPERIAPSIS.
	set orb["T"] to ship:orbit:period.
	set orb["a"] to SHIP:ORBIT:SEMIMAJORAXIS.
	set orb["e"] to SHIP:ORBIT:ECCENTRICITY.
	set orb["p"] to orb["a"]*(1-orb["e"]*orb["e"]).
	set orb["h"] to sqrt(orb["p"]*Globals["mu"]).
	
	return orb.
}

declare function RatAngle {
	declare parameter orb.
	declare parameter angle to 0.
	
	return (orb["p"]/(1 + orb["e"] * cos(angle))).
}

declare function VatR {
	declare parameter orb.
	declare parameter r.
	
	return sqrt(Globals["mu"] * ((2/r)-(1/orb["a"]))).
}

declare function TtoR {
	declare parameter orb.
	declare parameter depPhi.
	declare parameter tgtPhi.
	
	set r1 to RatAngle(orb, depPhi).
	set r2 to RatAngle(orb, tgtPhi).
	
	set E1 to arccos((orb["a"] - r1)/(orb["e"]*orb["a"])).
	print E1 at (0, 21).
	set E2 to arccos((orb["a"] - r2)/(orb["e"]*orb["a"])).
	print E2 at (0, 22).
	
	set M1 to (E1 * constant:PI/180 - orb["e"]*sin(E1)).
	set M2 to (E2 * constant:PI/180 - orb["e"]*sin(E2)).
	
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
	
	
	
	set t to t2 - t1.
	
	return t.
}

declare function EuclidNewtonianSolver {
	declare parameter M.
	set E to M.
	UpdateOrbitParams().
	until (false) {
		set dE to (E - OP["e"] * sin(E) - M)/(1-OP["e"]*cos(e)).
		set E to E - dE.
		if (dE < 0.000001)
			break.
	}
	return E.
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
		set r to RatAngle(DepartureOrbit, phi).
		
		set depv to VatR(DepartureOrbit, r).
		print (depv) at (0, 0).
		set depF to arccos(DepartureOrbit["h"]/(r*depv)).
		if (phi > 180) 
			set depF to depF*-1.
		
		set tgtv to VatR(TargetOrbit, r).
		print tgtv at (0, 3).
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
		print dVv at (0, 6).
		set dVang to arccos((dVv*dVv + depv*depv - tgtv*tgtv)/(2*depv*dVv)).
		print dF at (0, 4).
		print cos(dVang) at (0, 5).
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
			print "debug".
			if (abs(phi - (360 - DepartureOrbit["AoP"])) < 5 or abs(phi - (360 - DepartureOrbit["AoP"])) > 355) {
				
				set depvec to v(depv, 0, 0).
				set dVvec to v(dVprog, 0, dVrad).
				set tgtvec to (depvec+dVvec).
				set dVnorm to tgtvec:mag*sin(relang).
				
				set dVv to sqrt(depv*depv + tgtv*tgtv - 2*depv*tgtv*cos(dF)).
				print dVv at (0, 6).
				set dVang to arccos((dVv*dVv + depv*depv - tgtv*tgtv)/(2*depv*dVv)).
				print dF at (0, 4).
				print cos(dVang) at (0, 5).
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
	
	set dphi to orb2["AoP"] - orb1["AoP"].
	
	set a to (orb1["p"] * orb2["e"] * cos(dphi)) - (orb2["p"] * orb1["e"]).
	set b to (orb1["p"] * orb2["e"] * sin(dphi)).
	set c to (orb1["p"] - orb2["p"]).
	
	set t to a.
	set a to c - a.
	set c to c + t.
	set b to b * 2.
	
	set D to b*b - 4 * a * c.
	
	if (D >= 0) {
		set x1 to (-1*b + sqrt(D))/(2*a).
		set x1 to 2 * arctan(x1).
		set x3 to x1 - dphi.
		if (x1 < 0)
			set x1 to x1 + 360.
		if (x3 < 0)
			set x3 to x3 + 360.
		
		set x2 to (-1*b - sqrt(D))/(2*a).
		set x2 to 2 * arctan(x2).
		set x4 to x2 - dphi.
		if (x2 < 0)
			set x2 to x2 + 360.
		if (x4 < 0)
			set x4 to x4 + 360.
		
		set result to list(x1, x2, x3, x4).
		return result.
	}
	else {	
		print "Failure".
		return 0.
	}
}











