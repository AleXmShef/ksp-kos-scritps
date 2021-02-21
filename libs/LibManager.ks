declare function Import {
	declare parameter libs.

	local storagePath is "1:".
	if not exists(storagePath + "/libs") {
		createdir(storagePath + "/libs").
	}
	for lib in libs {
		//if not exists(storagePath + "/libs/" + lib + ".ks") {
			if(exists("0:/libs/Math/" + lib + ".ks")) {
				copypath("0:/libs/Math/" + lib + ".ks", storagePath + "/libs/" + lib + ".ks").
			}

			else if(exists("0:/libs/" + lib + ".ks")) {
				copypath("0:/libs/" + lib + ".ks", storagePath + "/libs/" + lib + ".ks").
			}
		//}
	}
	for lib in libs {
		runoncepath(storagePath + "/libs/" + lib + ".ks").
	}
}
