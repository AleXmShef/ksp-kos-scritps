clearscreen.
runpath("0:/libs/LibManager.ks").

Import(LIST("matrixes")).

local m_ to LIST(
	LIST(
		1.2, 3.4, 0.8
	),
	LIST(
		2.6, 3.7, 0.1
	),
	LIST(
		3.4, 5.6, 9.9
	)
).

local m to m_.

local counter to 0.
local begin_time to TIME:SECONDS.
until (counter > 100) {
	local m_inv to MatrixFindInverse(m).
	set m to m_inv.
	set counter to counter + 1.
}
print m.
wait 2.
local legacy_time to TIME:SECONDS - begin_time.
print legacy_time.

set m to m_.
set counter to 0.
set begin_time to TIME:SECONDS.
until (counter > 100) {
	local m_inv to Matrix33InverseFast(m).
	set m to m_inv.
	set counter to counter + 1.
}
print m.
wait 2.

local new_time to TIME:SECONDS - begin_time.
print new_time.
wait 10.
