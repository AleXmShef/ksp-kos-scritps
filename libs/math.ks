local storagePath is "1:".
if not exists(storagePath + "/libs") {
	createdir(storagePath + "/libs").
}
clearscreen.
function libDl2 {
	parameter libs is list().
	for lib in libs {
		//if not exists(storagePath + "/libs/" + lib + ".ks") {
			copypath("0:/libs/math/" + lib + ".ks", storagePath + "/libs/").
		//}
	}
	for lib in libs {
		runpath(storagePath + "/libs/" + lib + ".ks").
	}
}
libDl2(list("lambertsolver", "vectors", "matrixes")).
