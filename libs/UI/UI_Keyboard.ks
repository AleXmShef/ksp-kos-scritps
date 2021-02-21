@lazyglobal off.

declare function UIkeyboardCreate {
	declare parameter UIkeyboardOnButtonPressed.
	CLEARGUIS().

	LOCAL UIkeyboard IS LEXICON(
		"GUIclass", 0,
		"HorizontalBox", 0,
		"LeftColumnBox", 0,
		"NumpadBox", 0,
		"Numpad1RowBox", 0,
		"Numpad2RowBox", 0,
		"Numpad3RowBox", 0,
		"Numpad4RowBox", 0,
		"BottomRowBox", 0,
		"SwitchButton", 0,
		"ItemButton", 0,
		"ExecButton", 0,
		"OpsButton", 0,
		"SpecButton", 0,
		"ProceedButton", 0,
		"NumberButtons", LEXICON(),
		"Showed", FALSE,
		"PressedCallback", 0,
		"Switch", UIkeyboardOnSwitch@
	).

	SET UIkeyboard["GUIclass"] TO GUI(270/5*4, 270).
	SET UIkeyboard["GUIclass"]:X TO 200.
	SET UIkeyboard["GUIclass"]:Y TO 50.

	SET UIkeyboard["HorizontalBox"] TO UIkeyboard["GUIclass"]:ADDHLAYOUT().

	SET UIkeyboard["LeftColumnBox"] TO UIkeyboard["HorizontalBox"]:ADDVLAYOUT().
	SET UIkeyboard["NumpadBox"] TO UIkeyboard["HorizontalBox"]:ADDVLAYOUT().

	SET UIkeyboard["Numpad1RowBox"] TO UIkeyboard["NumpadBox"]:ADDHLAYOUT().
	SET UIkeyboard["Numpad2RowBox"] TO UIkeyboard["NumpadBox"]:ADDHLAYOUT().
	SET UIkeyboard["Numpad3RowBox"] TO UIkeyboard["NumpadBox"]:ADDHLAYOUT().
	SET UIkeyboard["Numpad4RowBox"] TO UIkeyboard["NumpadBox"]:ADDHLAYOUT().
	SET UIkeyboard["BottomRowBox"] TO UIkeyboard["NumpadBox"]:ADDHLAYOUT().

	SET UIkeyboard["SwitchButton"] TO UIkeyboard["LeftColumnBox"]:ADDBUTTON("SWITCH").
	SET UIkeyboard["SwitchButton"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("SWITCH").
	UIkeyboard["LeftColumnBox"]:ADDSPACING(4).

	SET UIkeyboard["ItemButton"] TO UIkeyboard["LeftColumnBox"]:ADDBUTTON("ITEM").
	SET UIkeyboard["ItemButton"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("ITEM").
	UIkeyboard["LeftColumnBox"]:ADDSPACING(4).

	SET UIkeyboard["ExecButton"] TO UIkeyboard["LeftColumnBox"]:ADDBUTTON("EXEC").
	SET UIkeyboard["ExecButton"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("EXEC").
	UIkeyboard["LeftColumnBox"]:ADDSPACING(4).

	SET UIkeyboard["OpsButton"] TO UIkeyboard["LeftColumnBox"]:ADDBUTTON("OPS").
	SET UIkeyboard["OpsButton"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("OPS").

	UIkeyboard["LeftColumnBox"]:ADDSPACING(4).
	SET UIkeyboard["SpecButton"] TO UIkeyboard["LeftColumnBox"]:ADDBUTTON("SPEC").
	SET UIkeyboard["SpecButton"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("SPEC").

	SET UIkeyboard["NumberButtons"]["1"] TO UIkeyboard["Numpad1RowBox"]:ADDBUTTON("1").
	SET UIkeyboard["NumberButtons"]["1"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("1").

	SET UIkeyboard["NumberButtons"]["2"] TO UIkeyboard["Numpad1RowBox"]:ADDBUTTON("2").
	SET UIkeyboard["NumberButtons"]["2"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("2").

	SET UIkeyboard["NumberButtons"]["3"] TO UIkeyboard["Numpad1RowBox"]:ADDBUTTON("3").
	SET UIkeyboard["NumberButtons"]["3"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("3").


	SET UIkeyboard["NumberButtons"]["4"] TO UIkeyboard["Numpad2RowBox"]:ADDBUTTON("4").
	SET UIkeyboard["NumberButtons"]["4"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("4").

	SET UIkeyboard["NumberButtons"]["5"] TO UIkeyboard["Numpad2RowBox"]:ADDBUTTON("5").
	SET UIkeyboard["NumberButtons"]["5"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("5").

	SET UIkeyboard["NumberButtons"]["6"] TO UIkeyboard["Numpad2RowBox"]:ADDBUTTON("6").
	SET UIkeyboard["NumberButtons"]["6"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("6").


	SET UIkeyboard["NumberButtons"]["7"] TO UIkeyboard["Numpad3RowBox"]:ADDBUTTON("7").
	SET UIkeyboard["NumberButtons"]["7"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("7").

	SET UIkeyboard["NumberButtons"]["8"] TO UIkeyboard["Numpad3RowBox"]:ADDBUTTON("8").
	SET UIkeyboard["NumberButtons"]["8"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("8").

	SET UIkeyboard["NumberButtons"]["9"] TO UIkeyboard["Numpad3RowBox"]:ADDBUTTON("9").
	SET UIkeyboard["NumberButtons"]["9"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("9").


	SET UIkeyboard["NumberButtons"]["-"] TO UIkeyboard["Numpad4RowBox"]:ADDBUTTON("-").
	SET UIkeyboard["NumberButtons"]["-"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("-").

	SET UIkeyboard["NumberButtons"]["0"] TO UIkeyboard["Numpad4RowBox"]:ADDBUTTON("0").
	SET UIkeyboard["NumberButtons"]["0"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("0").

	SET UIkeyboard["NumberButtons"]["+"] TO UIkeyboard["Numpad4RowBox"]:ADDBUTTON("+").
	SET UIkeyboard["NumberButtons"]["+"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("+").


	SET UIkeyboard["NumberButtons"]["CLEAR"] TO UIkeyboard["BottomRowBox"]:ADDBUTTON("CLEAR").
	SET UIkeyboard["NumberButtons"]["CLEAR"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("CLEAR").

	SET UIkeyboard["NumberButtons"]["."] TO UIkeyboard["BottomRowBox"]:ADDBUTTON(".").
	SET UIkeyboard["NumberButtons"]["."]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND(".").

	SET UIkeyboard["ProceedButton"] TO UIkeyboard["BottomRowBox"]:ADDBUTTON("PRO").
	SET UIkeyboard["ProceedButton"]:ONCLICK TO UIkeyboardOnButtonPressed@:BIND("PRO").

	UIkeyboard["GUIclass"]:SHOW().

	SET UIkeyboard["Showed"] TO TRUE.

	return UIkeyboard.
}

declare function UIkeyboardDestroy {
	declare parameter self.
	self:GUIclass:HIDE().
	self:GUIclass:DISPOSE().
}

DECLARE FUNCTION UIkeyboardOnSwitch {
	declare parameter self.
	IF(self["Showed"]) {
		self["HorizontalBox"]:SHOWONLY(self["LeftColumnBox"]).
		self["LeftColumnBox"]:SHOWONLY(self["SwitchButton"]).
		SET self["Showed"] TO FALSE.
	}
	ELSE {
		self["NumpadBox"]:SHOW().

		FOR button IN self["LeftColumnBox"]:WIDGETS {
			button:SHOW().
		}

		SET self["Showed"] TO TRUE.
	}
}
