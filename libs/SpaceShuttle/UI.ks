@lazyglobal off.

GLOBAL UIkeyboard IS LEXICON(
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
	"NumberButtons", 0,
	"Showed", FALSE
).

declare function UIkeyboardCreate {
	CLEARGUIS().

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
	UIkeyboard["LeftColumnBox"]:ADDSPACING(4).
	SET UIkeyboard["ItemButton"] TO UIkeyboard["LeftColumnBox"]:ADDBUTTON("ITEM").
	UIkeyboard["LeftColumnBox"]:ADDSPACING(4).
	SET UIkeyboard["ExecButton"] TO UIkeyboard["LeftColumnBox"]:ADDBUTTON("EXEC").
	UIkeyboard["LeftColumnBox"]:ADDSPACING(4).
	SET UIkeyboard["OpsButton"] TO UIkeyboard["LeftColumnBox"]:ADDBUTTON("OPS").
	UIkeyboard["LeftColumnBox"]:ADDSPACING(4).
	SET UIkeyboard["SpecButton"] TO UIkeyboard["LeftColumnBox"]:ADDBUTTON("SPEC").

	SET UIkeyboard["NumberButtons"] TO UIkeyboard["Numpad1RowBox"]:ADDBUTTON("1").
	SET UIkeyboard["NumberButtons"] TO UIkeyboard["Numpad1RowBox"]:ADDBUTTON("2").
	SET UIkeyboard["NumberButtons"] TO UIkeyboard["Numpad1RowBox"]:ADDBUTTON("3").

	SET UIkeyboard["NumberButtons"] TO UIkeyboard["Numpad2RowBox"]:ADDBUTTON("4").
	SET UIkeyboard["NumberButtons"] TO UIkeyboard["Numpad2RowBox"]:ADDBUTTON("5").
	SET UIkeyboard["NumberButtons"] TO UIkeyboard["Numpad2RowBox"]:ADDBUTTON("6").

	SET UIkeyboard["NumberButtons"] TO UIkeyboard["Numpad3RowBox"]:ADDBUTTON("7").
	SET UIkeyboard["NumberButtons"] TO UIkeyboard["Numpad3RowBox"]:ADDBUTTON("8").
	SET UIkeyboard["NumberButtons"] TO UIkeyboard["Numpad3RowBox"]:ADDBUTTON("9").


	SET UIkeyboard["NumberButtons"] TO UIkeyboard["Numpad4RowBox"]:ADDBUTTON("-").
	SET UIkeyboard["NumberButtons"] TO UIkeyboard["Numpad4RowBox"]:ADDBUTTON("0").
	SET UIkeyboard["NumberButtons"] TO UIkeyboard["Numpad4RowBox"]:ADDBUTTON("+").

	SET UIkeyboard["NumberButtons"] TO UIkeyboard["BottomRowBox"]:ADDBUTTON("CLEAR").
	SET UIkeyboard["NumberButtons"] TO UIkeyboard["BottomRowBox"]:ADDBUTTON(".").
	SET UIkeyboard["ProceedButton"] TO UIkeyboard["BottomRowBox"]:ADDBUTTON("PRO").

	SET UIkeyboard["SwitchButton"]:ONCLICK TO UIkeyboardOnSwitch@.

	UIkeyboard["GUIclass"]:SHOW().

	SET UIkeyboard["Showed"] TO TRUE.

	WAIT 1000.


}

DECLARE FUNCTION UIkeyboardOnSwitch {
	IF(UIkeyboard["Showed"]) {
		UIkeyboard["HorizontalBox"]:SHOWONLY(UIkeyboard["LeftColumnBox"]).
		UIkeyboard["LeftColumnBox"]:SHOWONLY(UIkeyboard["SwitchButton"]).
		SET UIkeyboard["Showed"] TO FALSE.
	}
	ELSE {
		UIkeyboard["NumpadBox"]:SHOW().

		FOR button IN UIkeyboard["LeftColumnBox"]:WIDGETS {
			button:SHOW().
		}

		SET UIkeyboard["Showed"] TO TRUE.
	}
}

DECLARE FUNCTION UIkeyboardOnButtonPressed {

}
UIkeyboardCreate().
