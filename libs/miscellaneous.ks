@lazyglobal off.
DECLARE GLOBAL FuncList TO list().
DECLARE GLOBAL LoopFlag TO 0.
declare function LoopManager {
	declare parameter action to -1.
	declare parameter pointer to 0.

	if (action = -1) {
		LoopManagerUpdate().
	}
	else {
		wait until (LoopFlag = 0).
		set LoopFlag to 1.
		if (action = 0) {
			FuncList:Add(pointer).
		}
		else if (action = 1) {
			local tList to FuncList:copy.
			local i is 0.
			for f in tList {
				if (pointer = f) {
					tList:Remove(i).
					break.
				}
				set i to i+1.
			}
			set FuncList to tList.
		}
		set LoopFlag to 0.
	}
}

declare function LoopManagerUpdate {
	if (LoopFlag = 0) {
		set LoopFlag to 1.
		for f in FuncList:copy {
			f:call().
		}
		set LoopFlag to 0.
	}
}

declare function EngineController {
	declare parameter engine.
	declare parameter action to -1.
	if (action = 0) {
		engine:DOEVENT("shutdown engine").
	}
	else if (action = 1) {
		engine:DOEVENT("activate engine").
	}
	else {
		local status to engine:GETFIELD("Propellant").
		if(status:CONTAINS("VERY STABLE"))
			return true.
		else
			return false.
	}
}

declare function GetConnectedParts {
    declare parameter part.
    declare parameter name to "".

    local parts to part:CHILDREN.
    if(part:HASPARENT)
        parts:ADD(part:PARENT).
    if(name <> "") {
        for part in parts {
            if (part:NAME = name)
                return part.
        }
    }
    return parts.
}

declare function GetRotationBetweenBasisDirection {
	declare parameter basis.
	declare parameter dir.

	local vec_fwd to dir:FOREVECTOR.
	local vec_up to dir:UPVECTOR.

	local yaw to vang(basis:y, (vec_fwd - basis:z)).
	if(vang((vec_fwd - basis:z), basis:x) > 90)
		set yaw to yaw*-1.


	local pitch to vang(basis:z, (vec_fwd - basis:y)).
	if(vang((vec_fwd - basis:y), basis:x) > 90)
		set pitch to pitch*-1.

	local roll to 0.

	if(vang(vec_fwd, basis:x) < 45) {
		set roll to -vang(basis:z, (vec_up - basis:x)).
		if(vang((vec_up - basis:x), basis:y) > 90)
			set roll to roll*-1.
	}

	set pitch to pitch - 90.
	set yaw to yaw - 90.

	return lexicon("pitch", pitch, "yaw", yaw, "roll", roll).


}
