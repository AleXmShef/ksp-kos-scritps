declare function pc {
	declare parameter item.
	declare parameter coordY.
	declare parameter offset to 5.

	local conv_item to item:TOSTRING.
	local coordX to  TERMINAL:WIDTH/2 - FLOOR(conv_item:LENGTH/2).
	print conv_item at (coordX, coordY + offset).
}

declare function pl {
	declare parameter item.
	declare parameter coordX.
	declare parameter coordY.
	declare parameter offset to 5.

	local conv_item to item:TOSTRING.
	print conv_item at (coordX, coordY + offset).
}
declare function pr {
	declare parameter item.
	declare parameter coordX_wanted.
	declare parameter coordY.
	declare parameter offset to 5.

	local conv_item to item:TOSTRING.
	local coordX to  coordX_wanted - conv_item:LENGTH.

	print conv_item at (coordX, coordY + offset).
}
declare function ParseTime {
	declare parameter time to 0.

	local minute to 60.
	local hour to minute*60.
	local day to hour*24.

	local days to floor(time/day).
	set time to time - day*days.
	local hours to floor(time/hour).
	set time to time - hour*hours.
	local minutes to floor(time/minute).
	local seconds to ROUND(time - minute*minutes, 0).

	return LEXICON("d", days, "h", hours, "m", minutes, "s", seconds).
}
