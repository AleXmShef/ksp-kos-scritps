FUNCTION UI_Manager_BootLayout_Init {
	declare parameter self.
    print "|                                                          |".	//0
	print "|----------------------------------------------------------|".	//1
	print "|                                                          |".	//2
	print "|                                                          |".	//3
	print "|                                                          |".	//4
	print "|                                                          |".	//5
	print "|                                                          |".	//6
	print "|                    Successfully booted                   |".	//7
	print "|                                                          |".	//8
	print "|                   Awaiting Instructions                  |".	//9
	print "|                                                          |".	//10
	print "|                  _____   _____     _____                 |".	//11
	print "|                 / ____| |  __ \   / ____|                |".	//12
	print "|                | |  __  | |__) | | |                     |".	//13
	print "|                | | |_ | |  ___/  | |                     |".	//14
	print "|                | |__| | | |      | |____                 |".	//15
	print "|                 \_____| |_|       \_____|                |".	//16
	print "|                                                          |".	//17

	//    0123456789 123456789 123456789 123456789 123456789 123456789
	pc("Boot", 0).
}

FUNCTION UI_Manager_BootLayout_Update {
	parameter self.
}

FUNCTION UI_Manager_GetBootLayout {
	return LEXICON(
		"Init", UI_Manager_BootLayout_Init@,
		"Update", UI_Manager_BootLayout_Update@,
		"Items", LEXICON()
	).
}
