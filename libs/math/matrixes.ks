@lazyglobal off.
clearscreen.

declare global MatrixClass is lexicon (
							"MatrixSelf", 0,
							"Inverse", 0,
							"Determinant", 0
).

declare function BuildMatrix {
	declare parameter m.
	
	
}

declare function MatrixBuildZero {
	declare parameter z.
	declare parameter n.
	
	local i to 0.
	
	local m to MatrixClass:copy.
	set m["MatrixSelf"] to list().
	
	local row to list().
	
	until (i = n) {
		row:add(0).
		set i to i + 1.
	}
	
	set i to 0.
	until (i = z) {
		m["MatrixSelf"]:add(row:copy).
		set i to i + 1.
	}
	
	return m.
}
	
declare function MatrixFindInverse {
	declare parameter m.
	local n to m["MatrixSelf"]:length.
	
	if (MatrixFindDeterminant(m, n) = 0)
		return 0.
	return MatrixCalcCofactor(m, n, MatrixFindDeterminant(m, n)).
}

declare function MatrixFindDeterminant {
	//print "FindDeterminant".
	declare parameter a.
	declare parameter n.
	
	
	local b to MatrixBuildZero(n,n).
	local sum to 0.
	if (n = 1) 
		return a["MatrixSelf"][0][0].
	else if (n = 2) 
		return (a["MatrixSelf"][0][0]*a["MatrixSelf"][1][1] - a["MatrixSelf"][0][1]*a["MatrixSelf"][1][0]).
	else {
		local i to 0.
		until (i = n) {
			set b to MatrixFindMinor(b, a, i, n).
			set sum to sum + a["MatrixSelf"][0][i]*((-1)^i)*MatrixFindDeterminant(b, (n-1)).
			set i to i + 1.
		}
		return sum.
	}
}

declare function MatrixTranspose {
	declare parameter c.
	//declare parameter d.
	declare parameter n.
	declare parameter det.
	
	local f to MatrixBuildZero(n, n).
	local b to MatrixBuildZero(n, n).
	local i to 0.
	local j to 0.
	
	set i to 0.
	until (i = n) {
		set j to 0.
		until (j = n) {
			set b["MatrixSelf"][i][j] to c["MatrixSelf"][j][i].
			set j to j+1.
		}
		set i to i+1.
	}
	
	set i to 0.
	until (i = n) {
		set j to 0.
		until (j = n) {
			set f["MatrixSelf"][i][j] to b["MatrixSelf"][i][j]/det.
			set j to j+1.
		}
		set i to i+1.
	}
	return f.
	
}

declare function MatrixCalcCofactor {
	declare parameter a.
	//declare parameter d.
	declare parameter n.
	declare parameter det.
	
	local b to MatrixBuildZero(n, n).
	local c to MatrixBuildZero(n, n).
	local l to 0.
	local h to 0.
	local m to 0.
	local k to 0.
	local i to 0.
	local j to 0.
	
	set h to 0.
	until (h = n) {
		set l to 0.
		until (l = n) {
			set m to 0.
			set k to 0.
			
			set i to 0.
			until (i = n) {
				set j to 0.
				until (j = n) {
					if ((i <> h) and (j <> l)) {
						set b["MatrixSelf"][m][k] to a["MatrixSelf"][i][j].
						if (k < (n - 2))
							set k to k+1.
						else {
							set k to 0.
							set m to m+1.
						}
					}
					set j to j+1.
				}
				set i to i+1.
			}
			set c["MatrixSelf"][h][l] to ((-1)^(h+l))*MatrixFindDeterminant(b, (n-1)).
			set l to l+1.
		}
		set h to h+1.
	}
	local d to MatrixClass:copy.
	set d["MatrixSelf"] to MatrixTranspose(c, n, det)["MatrixSelf"]:copy.
	return d.
}

declare function MatrixFindMinor {
	declare parameter b.
	declare parameter a.
	declare parameter i.
	declare parameter n.
	
	
	local l to 1.
	local j to 0.
	local h to 0.
	local k to 0.
	
	until (l = n) {
		set j to 0.
		until (j = n) {
			if (j <> i) {
				set b["MatrixSelf"][h][k] to a["MatrixSelf"][l][j].
				set k to k+1.
				if (k = (n - 1)) {
					set h to h+1.
					set k to 0.
				}
			}
			set j to j+1.
		}
		set l to l+1.
	}
	return b.
}

declare function MatrixMultiply {
	declare parameter m1.
	declare parameter m2.
	
	local m to MatrixBuildZero(m1["MatrixSelf"]:length, m2["MatrixSelf"][0]:length).
	
	local i to 0.
	local j to 0.
	local k to 0.
	
	until (i = m1["MatrixSelf"]:length) {
		set j to 0.
		until (j = m2["MatrixSelf"][0]:length) {
			set k to 0.
			until (k = m1["MatrixSelf"][0]:length) {
				set m["MatrixSelf"][i][j] to m["MatrixSelf"][i][j] + m1["MatrixSelf"][i][k]*m2["MatrixSelf"][k][j].
				set k to k + 1.
			}
			set j to j + 1.
		}
		set i to i + 1.
	}
	
	return m.
}

declare function MatrixTriangulate {
	declare parameter m.
	
	local i to 0.
	local j to 0.
	until (i = m["MatrixSelf"]:length) {
		set ColMax to MatrixColumnMax(m, i).
		if (i <> ColMax[1]) {
			set m to MatrixSwapRow(m, ColMax[1], 0).
		}
		
		set j to i + 1.
		
		until j = (m["MatrixSelf"]:length) {
			set mult to -1*((m["MatrixSelf"][j][i])/(m["MatrixSelf"][i][i])).
			set temp to m["MatrixSelf"][i].
			if (mult <> 0) {
				set m to MatrixMultiplyRow(m, i, mult).
				set m to MatrixAddTwoRows(m, j, i).
			}
			set m["MatrixSelf"][i] to temp.
			set j to j + 1.
		}
		set i to i + 1.
	}
	return m.
}

declare function MatrixColumnMax {
	declare parameter m.
	declare parameter column.
	
	local result to list(0, 0).
	set result[0] to 0.
	local i to 0.
	
	for c in m["MatrixSelf"] {
		if (m["MatrixSelf"][i][column] > result[0]) {
			set result[0] to m["MatrixSelf"][i][column].
			set result[1] to i.
		}
		set i to i + 1.
	}
	
	return result.
}

declare function MatrixSwapRow {
	declare parameter m.
	declare parameter r1.
	declare parameter r2.
	
	set temp to m["MatrixSelf"][r1].
	set m["MatrixSelf"][r1] to m["MatrixSelf"][r2].
	set m["MatrixSelf"][r2] to temp.
	
	return m.
}

declare function MatrixMultiplyRow {
	declare parameter m.
	declare parameter r.
	declare parameter s.
	
	local i to 0.
	for e in m["MatrixSelf"][r] {
		set m["MatrixSelf"][r][i] to m["MatrixSelf"][r][i]*s.
		set i to i + 1.
	}
	
	return m.
}

declare function MatrixAddTwoRows {
	declare parameter m.
	declare parameter r1.
	declare parameter r2.
	
	local i to 0.
	for e in m["MatrixSelf"][r1] {
		set m["MatrixSelf"][r1][i] to m["MatrixSelf"][r1][i] + m["MatrixSelf"][r2][i].
		set i to i + 1.
	}
	
	return m.
}

declare function MatrixConstructTwoMatrixes {
	declare parameter m1.
	declare parameter m2.
	
	local resm to MatrixClass:copy.
	local i to 0.
	
	until (i = m1["MatrixSelf"]:length) {
		resm["MatrixSelf"]:add(m1["MatrixSelf"][i]).
		set i to i + 1.
	}
	
	local i to 0.
	local j to 0.
	
	until (i = m1["MatrixSelf"]:length) {
		until (j = m2["MatrixSelf"][0]:length) {
			resm["MatrixSelf"][i]:add(m2["MatrixSelf"][i][j]).
			set j to j + 1.
		}
		set i to i + 1.
		set j to 0.
	}
	return resm.
	
}

declare function MatrixPrint {
	clearscreen.
	declare parameter m.
	if (m["MatrixSelf"] = 0) {
		print 0.
		return 0.
	}
	
	local i to 0.
	local j to 0.
	
	until (i = m["MatrixSelf"]:length) {
		set j to 0.
		until (j = m["MatrixSelf"][0]:length) {
			print round((m["MatrixSelf"][i][j]), 3) at (j*12, i*2).
			set j to j + 1.
		}
		set i to i + 1.
	}
	wait 1.
}

declare function MatrixSubtract {
	declare parameter m1.
	declare parameter m2.
	
	local m to MatrixBuildZero(m1["MatrixSelf"]:length, m1["MatrixSelf"][0]:length).
	
	local i to 0.
	local j to 0.
	
	until (i = m1["MatrixSelf"]:length) {
		set j to 0.
		until (j = m1["MatrixSelf"][0]:length) {
			set m["MatrixSelf"][i][j] to m1["MatrixSelf"][i][j] - m2["MatrixSelf"][i][j].
			set j to j + 1.
		}
		set i to i + 1.
	}
	
	return m.
}

declare function MatrixAdd {
	declare parameter m1.
	declare parameter m2.
	
	local m to MatrixBuildZero(m1["MatrixSelf"]:length, m1["MatrixSelf"][0]:length).
	
	local i to 0.
	local j to 0.
	
	until (i = m1["MatrixSelf"]:length) {
		set j to 0.
		until (j = m1["MatrixSelf"][0]:length) {
			set m["MatrixSelf"][i][j] to m1["MatrixSelf"][i][j] + m2["MatrixSelf"][i][j].
			set j to j + 1.
		}
		set i to i + 1.
	}
	
	return m.
}









