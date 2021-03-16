declare global UI_Manager_PendingAdditionLayout to 0.

Import(LIST("UI/UI_Utils")).

declare function GetUImanager {
	return LEXICON(
		"AddLayout", UI_Manager_AddLayout@,
		"RemoveLayout", UI_Manager_RemoveLayout@,
		"SetLayout", UI_Manager_Change_ActiveLayout@,
		"Start", UI_Manager_Start@,
		"Stop", UI_Manager_Stop@,
		"Update", UI_Manager_BigUpdate@,
		"Layouts", LEXICON(),
		"Data", LEXICON(
			"ActiveLayout", -1,
			"Iterations", 0,
			"lastTime", 0,
			"Tickrate", 0.1
		),
		"Keyboard", 0,
		"Command", LEXICON(
			"stage", 0,
			"OP", "",
			"ARG", "",
			"CMD", "",
			"str", ""
		)
	).
}

declare function UI_Manager_RemoveLayout {
	declare parameter self.
	declare parameter key.

	if(self:Layouts:HASKEY(key))
		self:Layouts:REMOVE(key).
}

declare function UI_Manager_AddLayout {
	declare parameter self.
	declare parameter layout.
	declare parameter key.

	local layouts to self:Layouts.
	set layouts[key] to layout.
	set self:Layouts to layouts.
	if(self:Layouts:LENGTH = 1)
		UI_Manager_Change_ActiveLayout(self, key).
}

declare function UI_Manager_ExecCommand {
	declare parameter self.

	if(self:Command:OP = "OPS" and self:Command:ARG = "-1" and self:Command:CMD = "PRO") {
		UIkeyboardDestroy(self:Keyboard).
		set self:Data:Enabled to false.
	}

	if(self:Command:OP = "ITEM") {
		local itemNumber to self:Command:ARG.
		local itemArg to "none".
		local separator to self:Command:ARG:FIND("+").
		if(separator > 0) {
			local number_arg to self:Command:ARG:SPLIT("+").
			set itemNumber to number_arg[0].
			set itemArg to number_arg[1].
		}
		if(self:Layouts[self:Data:ActiveLayout]:Items:HASKEY(itemNumber)) {
			local item to self:Layouts[self:Data:ActiveLayout]:Items[itemNumber].
			local result to item:Action(self:Layouts[self:Data:ActiveLayout], itemArg).
			if(result <> "") {
				set self:Command:stage to -1.
				set self:Command:str to result.
				return 0.
			}
		}
	}
	else if(self:Command:OP = "SPEC") {
		local spec to self:Command:ARG.
		UI_Manager_Change_ActiveLayout(self, spec).
	}
	else if(self:Command:OP = "OPS") {
		local mode to self:Command:ARG.
		ModeController(mode).
	}
	return 1.
}

declare function UI_Manager_KeyboardCallback {
	declare parameter self.
	declare parameter button.

	if(button = "CLEAR") {
		set self:Command to LEXICON(
			"stage", 0,
			"OP", "",
			"ARG", "",
			"CMD", "",
			"str", ""
		).
	}
	else if(button = "SWITCH") {
		self:Keyboard:Switch(self:Keyboard).
	}
	else if (self:Command:stage >= 0) {
		if(self:Command:stage = 0 and (button = "ITEM" or button = "SPEC" or button = "OPS")) {
			set self:Command:stage to 1.
			set self:Command:OP to button.
			set self:Command:str to button + " ".
		}
		else if(self:Command:stage = 1 and button <> "ITEM" and button <> "SPEC" and button <> "OPS" and button <> "EXEC" and button <> "PRO") {
			set self:Command:ARG to self:Command:ARG + button.
			set self:Command:str to self:Command:str + button.
		}
		else if(self:Command:stage = 1 and ((button = "EXEC" and self:Command:OP = "ITEM") or (button = "PRO" and (self:Command:OP = "SPEC" or self:Command:OP = "OPS")))) {
			set self:Command:stage to 2.
			set self:Command:CMD to button.
			set self:Command:str to self:Command:str + " " + button.
			local res to UI_Manager_ExecCommand(self).
			if(res = 1) {
				set self:Command to LEXICON(
					"stage", 0,
					"OP", "",
					"ARG", "",
					"CMD", "",
					"str", ""
				).
			}
		}
		else {
			set self:Command:stage to -1.
			set self:Command:str to "ERROR".
		}
	}
}

declare function UI_Manager_Stop {
	declare parameter self.

}

declare function UI_Manager_BigUpdate {
	declare parameter self.
	if(self:Data:lastTime + self:Data:Tickrate < TIME:SECONDS) {
		if(self:Data:Iterations > 10) {
			UI_Manager_Refresh(self).
			set self:Data:Iterations to 0.
		}
		UI_Manager_Update(self).
		set self:Data:Iterations to self:Data:Iterations + 1.
		set self:Data:lastTime to TIME:SECONDS.
	}
}

declare function UI_Manager_Start {
	declare parameter self.
	declare parameter enable_keyboard to true.
	declare parameter separate_thread to true.
	set TERMINAL:WIDTH to 60.
	set TERMINAL:HEIGHT to 27.

	set self:Data:Enabled to true.
	if(enable_keyboard) {
		Import(LIST("UI/UI_Keyboard")).
		set self:Keyboard to UIkeyboardCreate(UI_Manager_KeyboardCallback@:BIND(self)).
	}

	if(separate_thread <> true) {
		UNTIL(self:Data:Enabled = false) {
			if(self:Data:Iterations > 10) {
				UI_Manager_Refresh(self).
				set self:Data:Iterations to 0.
			}
			UI_Manager_Update(self).
			wait self:Data:Tickrate.
			set self:Data:Iterations to self:Data:Iterations + 1.
		}
	}
}

declare function UI_Manager_Change_ActiveLayout {
	declare parameter self.
	declare parameter layoutKey.

	if(self:Layouts:HASKEY(layoutKey))
		set self:Data:ActiveLayout to layoutKey.
	UI_Manager_Refresh(self).
}

declare function UI_Manager_Refresh {
	declare parameter self.
	UI_Manager_Init().
	if(self:Data:ActiveLayout >= 0)
		self:Layouts[self:Data:ActiveLayout]:Init(self:Layouts[self:Data:ActiveLayout]).
	else {
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
	}
	UI_Manager_Print_CommandLine().
}

declare function UI_Manager_Init {
	clearscreen.
	print "/   /   .--------------------------------------------.     ".	//0
	print ".-------*                                            *-----.".	//1
	print "|----------------------------------------------------------|".	//2
	print "| MET:         d   h   m   s || UTC:                :  :   |".	//3
	print "|----------------------------------------------------------|".	//4

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
}

declare function UI_Manager_Print_CommandLine {
	print "|----------------------------------------------------------|".
	print "|                                                          |".
}

declare function UI_Manager_Update {
	declare parameter self.

	local beginTime to TIME:SECONDS.

	if(DEFINED(ShipName))
		pc(ShipName, 1, false, 0).
	else
		pc(SHIP:NAME, 1, false, 0).
	local met TO ParseTime(MISSIONTIME).
	pr(met:d, 15, 3, false, 0).
	pr(met:h, 19, 3, false, 0).
	pr(met:m, 23, 3, false, 0).
	pr(met:s, 27, 3, false, 0).

	pl(CurrentMode, 1, 0, false, 0).
	pl(self:Data:ActiveLayout, 5, 0, false, 0).

	pl(self:Command:str, 2, 24, false, 0).

	if(self:Data:ActiveLayout >= 0)
		self:Layouts[self:Data:ActiveLayout]:Update(self:Layouts[self:Data:ActiveLayout]).

	pr(TIME:SECONDS - beginTime, 59, 0, true, 0).

	// for key in self:Layouts[self:Data:ActiveLayout]:Items:KEYS {
	// 	local item is self:Layouts[self:Data:ActiveLayout]:Items[key].
	// 	if (item:HASKEY("isActive") and item:isActive) {
	// 		pl("*", item:posX, item:posY).
	// 	}
	// }
}
