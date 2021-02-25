@lazyglobal off.
function chFrame {
  parameter oldVec, oldSP, newSP to SolarPrimeVector.
  return vdot(oldVec, oldSP)*newSP + (oldVec:z * oldSP:x - oldVec:x * oldSP:z)*V(-newSP:z, 0, newSP:x) + V(0, oldVec:y, 0).
}

function toIRF {
// changes to inertial right-handed coordinate system where ix = SPV, iy = vcrs(SPV, V(0, 1, 0)), iz = V(0, 1, 0)
  parameter oldVec, SPV to SolarPrimeVector.
  return V( oldVec:x * SPV:x + oldVec:z * SPV:z, oldVec:z * SPV:x - oldVec:x * SPV:z, oldVec:y).
}

function fromIRF {
// changes from inertial right-handed coordinate system where ix = SPV, iy = vcrs(SPV, V(0, 1, 0)), iz = V(0, 1, 0)
  parameter irfVec, SPV to SolarPrimeVector.
  return V( irfVec:x * SPV:x - irfVec:y * SPV:z, irfVec:z, irfVec:x * SPV:z + irfVec:y * SPV:x ).
}

function getIRF {
	local SPV to SolarPrimeVector.
	local irf to LEXICON("x", SPV, "y", vcrs(SPV, V(0, 1, 0)), "z", V(0, 1, 0)).
	return getTransform(irf).
}

function ANNorm {
//returns direction with vector=AN vector, up=normal
  parameter lan, incl, SPV to SolarPrimeVector.
  return lookdirup(SPV, V(0, 1, 0)) * R(0,-lan,-incl).
}

function Vrot {
	//Rotate vector about another vector by given degrees
	parameter oldVec, axisVec, angle.
	set axisVec:mag to 1.
	return oldVec*cos(angle) + vcrs(axisVec, oldVec)*sin(angle) + axisVec*(axisVec*oldVec)*(1 - cos(angle)).
}

function fastdrawvec {
	parameter vec.
	parameter color.

	vecdraw(v(0, 0, 0), vec, color, "", 10.0, true, 0.2, true, true).
}

declare function NormalizeAngles {
	declare parameter dir.

	local pitch to dir:PITCH.
	if(pitch > 180)
		set pitch to -1*(360 - pitch).
	// else
	// 	set pitch to pitch*-1.

	local yaw to dir:yaw.
	if(yaw > 180)
		set yaw to -1*(360 - yaw).
	// else
	// 	set yaw to yaw*-1.

	local roll to dir:ROLL.
	if(roll > 180)
		set roll to -1*(360 - roll).
	// else
	// 	set roll to roll*-1.

	return R(pitch, yaw, -roll).
}

function DenormalizeAngles {
	parameter dir.

	local pitch to -dir:pitch.
	local yaw to -dir:yaw.
	local roll to -dir:roll.


	return R(pitch, yaw, roll).
}

//get LVLH basis with Y axis along R vector, Z axis along the velocity vector and X axis is vcrs(Z, Y)
function getLVLHfromR_DAP {
	DECLARE PARAMETER orbit.
	DECLARE PARAMETER position.

	LOCAL plusX IS position:VEC.
	SET plusX:MAG TO 1.

	LOCAL plusY TO -VCRS(ANNorm(orbit["LAN"], orbit["Inc"]):UPVECTOR:NORMALIZED, plusX).
	SET plusY:MAG TO 1.

	LOCAL plusZ IS VCRS(plusY, plusX).
	SET plusZ:MAG TO 1.

	RETURN getTransform(LEXICON("x", plusZ, "y", plusX, "z", plusY)).
}

//get LVLH basis with X axis along R vector, Y axis along the velocity vector and Z axis is vcrs(X, Y)
declare function getLVLHfromR {
	DECLARE PARAMETER orbit.
	DECLARE PARAMETER position.

	LOCAL plusX IS position:VEC.
	SET plusX:MAG TO 1.

	LOCAL plusY TO -VCRS(ANNorm(orbit["LAN"], orbit["Inc"]):UPVECTOR:NORMALIZED, plusX).
	SET plusY:MAG TO 1.

	LOCAL plusZ IS VCRS(plusX, plusY).
	SET plusZ:MAG TO 1.

	RETURN getTransform(LEXICON("x", plusX, "y", plusY, "z", plusZ)).
}

declare function getTransform {
	DECLARE PARAMETER basis.
	LOCAL transform TO BuildTransformMatrix(basis).
	LOCAL transform_inv to MatrixFindInverse(transform).
	return lexicon("Transform", BuildTransformMatrix(basis), "Inverse", transform_inv, "Basis", basis).
}
