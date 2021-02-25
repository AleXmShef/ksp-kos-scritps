FUNCTION UI_Manager_BootLayout_Init {
	declare parameter self.
    print "|                                                          |".	//0
	print "|                                                          |".	//1
	print "|                                                          |".	//2
	print "|                                                          |".	//3
	print "|                                                          |".	//4
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

	//    0123456789 123456789 123456789 123456789 123456789 123456789
}

FUNCTION UI_Manager_BootLayout_Update {

}

FUNCTION UI_Manager_GetBootLayout {
	return LEXICON(
		"Init", UI_Manager_BootLayout_Init@,
		"Update", UI_Manager_BootLayout_Update@,
		"Items", LEXICON()
	).
}
