Import(LIST("globals")).

DECLARE FUNCTION UI_Manager_OrbitLayout_Init {
	declare parameter self.

	print "|                                                          |".	//0
	print "|----------------------------------------------------------|".	//1
	print "| Apoapsis:                                                |".	//2
	print "| RCS: 1. on                                               |".	//3
	print "|      2. off                                              |".	//4
	print "|                                                          |".	//5
	print "|                                                          |".	//6
	print "|                                                          |".	//7
	print "|                                                          |".	//8
	print "|                                                          |".	//9
	print "|                                                          |".	//10
	print "|                                                          |".	//11
	print "|                                                          |".	//12
	print "|                                                          |".	//13
	print "|                                                          |".	//14
	print "|                                                          |".	//15
	print "|                                                          |".	//16
	print "|                                                          |".	//17

	//    0123456789
	//              10
	//               123456789
	//                        20
	//                         123456789
	//                                  30
	//                                   123456789
	//                                            40
	//                                             123456789
	//                                                      50
	//                                                       123456789
	//                                                                60
	pc("Orbit Information", 0).

	set self:Data:RCS to RCS.
	set self:Items:rcs_on:isActive to RCS.
	set self:Items:rcs_off:isActive to (RCS <> true).
}

DECLARE FUNCTION UI_Manager_OrbitLayout_Update {
	declare parameter self.

	local ap to (SHIP:ORBIT:APOAPSIS)/1000.
	pl(ap, 12, 2).
	pl(self:Data:Arg, 12, 5).
}

SET UI_Manager_PendingAdditionLayout TO LEXICON(
	"Init", UI_Manager_OrbitLayout_Init@,
	"Update", UI_Manager_OrbitLayout_Update@,
	"Data", LEXICON(
		"Apoapsis", 0,
		"RCS", false,
		"Arg", ""
	),
	"Items", LEXICON(
		"rcs_on", LEXICON(
			"Number", 1,
			"Action", switch_rcs@:BIND(true),
			"PosX", 13,
			"PosY", 3,
			"isActive", false
		),
		"rcs_off", LEXICON(
			"Number", 2,
			"Action", switch_rcs@:BIND(false),
			"PosX", 14,
			"PosY", 4,
			"isActive", false
		)
	)
).

declare function switch_rcs {
	declare parameter _on.
	declare parameter self.
	declare parameter dummyArg.
	set rcs to _on.

	set self:Items:rcs_on:isActive to _on.
	set self:Items:rcs_off:isActive to (_on <> true).
}
