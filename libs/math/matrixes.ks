@lazyglobal off.
declare function BuildMatrix {
	declare parameter m.


}

declare function MatrixBuildZero {
	declare parameter z.
	declare parameter n.

	local i to 0.

	local m to list().

	local row to list().

	until (i = n) {
		row:add(0).
		set i to i + 1.
	}

	set i to 0.
	until (i = z) {
		m:add(row:copy).
		set i to i + 1.
	}

	return m.
}

function MatrixMultiplyScalar {
	parameter m.
	parameter s.

	local i to 0.
	local j to 0.
	until (i >= m:length) {
		until (j >= m[0]:LENGTH) {
			set m[i][j] to m[i][j]*s.
			set j to j + 1.
		}
		set i to i + 1.
		set j to 0.
	}
	return m.
}

function Matrix33InverseFast {
	parameter m.

	local test to (
		m[0][0]*m[1][1]*m[2][2] -
		m[0][0]*m[1][2]*m[2][1] -
		m[0][1]*m[1][0]*m[2][2] +
		m[0][1]*m[1][2]*m[2][0] +
		m[0][2]*m[1][0]*m[2][1] -
		m[0][2]*m[1][1]*m[2][0]
	).



	local d to 1/test.

	local m_ to LIST(
		LIST(
			m[1][1]*m[2][2] - m[1][2]*m[2][1], m[0][2]*m[2][1] - m[0][1]*m[2][2], m[0][1]*m[1][2] - m[0][2]*m[1][1]
		),
		LIST(
			m[1][2]*m[2][0] - m[1][0]*m[2][2], m[0][0]*m[2][2] - m[0][2]*m[2][0], m[0][2]*m[1][0] - m[0][0]*m[1][2]
		),
		LIST(
			m[1][0]*m[2][1] - m[1][1]*m[2][0], m[0][1]*m[2][0] - m[0][0]*m[2][1], m[0][0]*m[1][1] - m[0][1]*m[1][0]
		)
	).
	return MatrixMultiplyScalar(m_, d).
}

declare function MatrixFindInverse {
	declare parameter m.
	local n to m:length.

	//if (MatrixFindDeterminant(m, n) = 0)
		//return 0.
	if(m:LENGTH = 3 and m[0]:LENGTH = 3) {
		return Matrix33InverseFast(m).
	}
	return MatrixCalcCofactor(m, n, MatrixFindDeterminant(m, n)).
}

declare function MatrixFindDeterminant {
	//print "FindDeterminant".
	declare parameter a.
	declare parameter n.


	local b to MatrixBuildZero(n,n).
	local sum to 0.
	if (n = 1)
		return a[0][0].
	else if (n = 2)
		return (a[0][0]*a[1][1] - a[0][1]*a[1][0]).
	else {
		local i to 0.
		until (i = n) {
			set b to MatrixFindMinor(b, a, i, n).
			set sum to sum + a[0][i]*((-1)^i)*MatrixFindDeterminant(b, (n-1)).
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
			set b[i][j] to c[j][i].
			set j to j+1.
		}
		set i to i+1.
	}

	set i to 0.
	until (i = n) {
		set j to 0.
		until (j = n) {
			set f[i][j] to b[i][j]/det.
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
						set b[m][k] to a[i][j].
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
			set c[h][l] to ((-1)^(h+l))*MatrixFindDeterminant(b, (n-1)).
			set l to l+1.
		}
		set h to h+1.
	}
	local d to MatrixTranspose(c, n, det):copy.
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
				set b[h][k] to a[l][j].
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

	local m to MatrixBuildZero(m1:length, m2[0]:length).

	local i to 0.
	local j to 0.
	local k to 0.

	until (i = m1:length) {
		set j to 0.
		until (j = m2[0]:length) {
			set k to 0.
			until (k = m1[0]:length) {
				set m[i][j] to m[i][j] + m1[i][k]*m2[k][j].
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
	until (i = m:length) {
		set ColMax to MatrixColumnMax(m, i).
		if (i <> ColMax[1]) {
			set m to MatrixSwapRow(m, ColMax[1], 0).
		}

		set j to i + 1.

		until j = (m:length) {
			set mult to -1*((m[j][i])/(m[i][i])).
			set temp to m[i].
			if (mult <> 0) {
				set m to MatrixMultiplyRow(m, i, mult).
				set m to MatrixAddTwoRows(m, j, i).
			}
			set m[i] to temp.
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

	for c in m {
		if (m[i][column] > result[0]) {
			set result[0] to m[i][column].
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

	set temp to m[r1].
	set m[r1] to m[r2].
	set m[r2] to temp.

	return m.
}

declare function MatrixMultiplyRow {
	declare parameter m.
	declare parameter r.
	declare parameter s.

	local i to 0.
	for e in m[r] {
		set m[r][i] to m[r][i]*s.
		set i to i + 1.
	}

	return m.
}

declare function MatrixAddTwoRows {
	declare parameter m.
	declare parameter r1.
	declare parameter r2.

	local i to 0.
	for e in m[r1] {
		set m[r1][i] to m[r1][i] + m[r2][i].
		set i to i + 1.
	}

	return m.
}

declare function MatrixConstructTwoMatrixes {
	declare parameter m1.
	declare parameter m2.

	local resm to list().
	local i to 0.

	until (i = m1:length) {
		resm:add(m1[i]).
		set i to i + 1.
	}

	local i to 0.
	local j to 0.

	until (i = m1:length) {
		until (j = m2[0]:length) {
			resm[i]:add(m2[i][j]).
			set j to j + 1.
		}
		set i to i + 1.
		set j to 0.
	}
	return resm.

}

declare function MatrixPrint {
	declare parameter m.
	if (m = 0) {
		print 0.
		return 0.
	}

	local i to 0.
	local j to 0.

	until (i = m:length) {
		set j to 0.
		until (j = m[0]:length) {
			print round((m[i][j]), 3) at (j*12, i*2).
			set j to j + 1.
		}
		set i to i + 1.
	}
	wait 1.
}

declare function MatrixSubtract {
	declare parameter m1.
	declare parameter m2.

	local m to MatrixBuildZero(m1:length, m1[0]:length).

	local i to 0.
	local j to 0.

	until (i = m1:length) {
		set j to 0.
		until (j = m1[0]:length) {
			set m[i][j] to m1[i][j] - m2[i][j].
			set j to j + 1.
		}
		set i to i + 1.
	}

	return m.
}

declare function MatrixAdd {
	declare parameter m1.
	declare parameter m2.

	local m to MatrixBuildZero(m1:length, m1[0]:length).

	local i to 0.
	local j to 0.

	until (i = m1:length) {
		set j to 0.
		until (j = m1[0]:length) {
			set m[i][j] to m1[i][j] + m2[i][j].
			set j to j + 1.
		}
		set i to i + 1.
	}

	return m.
}

declare function MatrixFromVector {
	declare parameter vec.

	local m to LIST().
	set m to LIST().
	m:ADD(list(vec:x)).
	m:ADD(list(vec:y)).
	m:ADD(list(vec:z)).
	return m.
}

declare function BuildTransformMatrix {
	declare parameter basis.

	local x to basis:x.
	local y to basis:y.
	local z to basis:z.

	local m to LIST().

	set m to list(
		list(x:x, x:y, x:z),
		list(y:x, y:y, y:z),
		list(z:x, z:y, z:z)
	).

	return m.
}

declare function VCMT {
	declare parameter m.
	declare parameter v.

	local vm to MatrixFromVector(v).

	local mult to MatrixMultiply(m, vm).
	return v(mult[0][0], mult[1][0], mult[2][0]).
}
