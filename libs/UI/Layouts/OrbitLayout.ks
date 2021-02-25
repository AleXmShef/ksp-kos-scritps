Import(LIST("globals")).
Import(LIST("orbits")).

DECLARE FUNCTION UI_Manager_OrbitLayout_Init {
	declare parameter self.

	print "|                                                          |".	//0
	print "|----------------------------------------------------------|".	//1
	print "|         Keplerian:         ||      ECI State Vector:     |".	//2
	print "| Apoapsis:               km || X:                       m |".	//3
	print "| Periapsis:              km || Y:                       m |".	//4
	print "| Inclination:           deg || Z:                       m |".	//5
	print "| Long. of AN:           deg || Xdot:                  m/s |".	//6
	print "| Arg. of Per:           deg || Ydot:                  m/s |".	//7
	print "| Eccentrity:            ___ || Zdot:                  m/s |".	//8
	print "| True Anomaly:          deg |*----------------------------|".	//9
	print "|----------------------------|                             |".	//10
	print "|            Time:           |                             |".	//11
	print "| T to Pe:                 s |                             |".	//12
	print "| T to Ap:                 s |                             |".	//13
	print "| T to LAN:                s |                             |".	//14
	print "|                                                          |".	//15
	print "|                                                          |".	//16
	print "|                                                          |".	//17

	//    0123456789 123456789 123456789 123456789 123456789 123456789

	pc("Orbit Information", 0).

	set self:Data:Orbit TO UpdateOrbitParams().
	set self:Data:StateVector:Position to toIRF(SHIP:BODY:POSITION*-1).
	set self:Data:StateVector:Velocity to toIRF(SHIP:VELOCITY:ORBIT).
}

DECLARE FUNCTION UI_Manager_OrbitLayout_Update {
	declare parameter self.



	//Keplerian
	pr((self:Data:Orbit:Ap - Globals:R)/1000, 25, 3).
	pr((self:Data:Orbit:Pe - Globals:R)/1000, 25, 4).
	pr(self:Data:Orbit:Inc, 24, 5).
	pr(self:Data:Orbit:LAN, 24, 6).
	pr(self:Data:Orbit:AoP, 24, 7).
	pr(self:Data:Orbit:e, 24, 8).
	pr(SHIP:ORBIT:TRUEANOMALY, 24, 9).

	//StateVector
	pr(self:Data:StateVector:Position:X, 56, 3).
	pr(self:Data:StateVector:Position:Y, 56, 4).
	pr(self:Data:StateVector:Position:Z, 56, 5).
	pr(self:Data:StateVector:Velocity:X, 54, 6).
	pr(self:Data:StateVector:Velocity:Y, 54, 7).
	pr(self:Data:StateVector:Velocity:Z, 54, 8).
}

FUNCTION UI_Manager_GetOrbitLayout {
	return LEXICON(
		"Init", UI_Manager_OrbitLayout_Init@,
		"Update", UI_Manager_OrbitLayout_Update@,
		"Data", LEXICON(
			"Orbit", 0,
			"StateVector", LEXICON(
				"Position", 0,
				"Velocity", 0
			)
		),
		"Items", LEXICON()
	).
}
