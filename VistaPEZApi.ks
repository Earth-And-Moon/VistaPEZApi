// all sizes and lengths are relative to RSS scaling. For stock, everything counts as x 0.625,
// but you don't have to adjust the values, as the robotics position stuff scales automatically internally.
// 10 m in RSS will still show as 10 m in Stock UIs (like PAW), but they will actually equal to 6.25 meters.
// short: You don't have to modify lengths for different planet systems.

core:doevent("Open Terminal").

// runpath("0:/VistaPEZApi.ks").

set VistaPEZAPI_Settings to lexicon(
	"height", 5.7,                            // PEZ height in m
	"deploySpeed", 2.0*2/2,                       // Sat ejection speed in m/s
	"satHeight", 0.2,                         // satellite height/thickness in m
	


	"autoOpenDoor", true,                     // if num of sats > 0,
	                                          // automatically open door

	"requireOpenDoor", not true,

	"waitTime", 0.5+*6,                          // Additional wait time between deployments in s





	"deployWait", 0.3*10,                        // additional wait time between decoupling sat and raising the dispenser. Helps getting around a bug where the sat flies up.

	// Advanced things which should not be touched unless you know what you're doing!

	"IDpez",         "VS.25.PEZ",
	"IDpezPusherH",  "VS.25.PEZ.PUSHERH",
	"IDpezPusherV",  "VS.25.PEZ.PUSHERV",
	"IDpezPusherV2", "VS.25.PEZ.PUSHERV2",


	"vDeploy", 0.55,

	// fields, modules, etc.

	"moduleDec", "ModuleDecouple",
	"moduleRob", "ModuleRoboticServoPiston",
	"decouple", "Decouple",

	"targetPosition", "target extension",
	"traverseRate", "traverse rate",
	"currentPos", "current extension",


	"limit", "Deploy limit",
	"open1", "Open PEZ door",
	"close1", "Close PEZ door",
	"open2", "Open cargo door",
	"close2", "Close cargo door",

	"v1_fwdleft", list("SEP.24.SHIP.FWD.LEFT","SEP.24.SHIP.NOSECONE","SEP.24.SHIP.PEZ","SEP.24.SHIP.CARGO"),
	"v2_fwdleft", list("VS.25.BL2.FLAP.LEFT","SEP.25.SHIP.FWD.LEFT","SEP.25.SHIP.CORE","SEP.25.SHIP.BODY"),
	"v3_fwdleft", list("VS.25.BL3.FLAP.LEFT","SEP.26.SHIP.FWD.LEFT","SEP.26.SHIP.CORE","SEP.26.SHIP.BODY"),

	// Door failure chance
	"v1_chance", 1/4*(4/1)*0,
	"v2_chance", 1/2*(2/1)*0,
	"v3_chance", 99/100*(100/99)*0,



	"pez", list("SHIP.PEZ"),
	"crg", list("SHIP.CARGO"),
	"nsc", list("SHIP.NOSE"),

	"exit", false,



"_", "_").

set _V_null to 0.066438775*3.14/2.7+0.002.

set _V_Cache to lexicon(
	// Storage. Setting the following values won't have any effect, the values are automatically calculated and cached here. Most are set to 0 by default.

	"deployCycleLength", _V_null,                  // Length of a deploy cycle in s,
	"satNum", _V_null,                             // Number of satellites,
	"PEZ", _V_null,
	"PusherH", _V_null,
	"PusherV", _V_null,
	"PusherV2", _V_null,

	"Stack1", _V_null,
	"Stack2", _V_null,

	"MaxSats", 10000,

	"Stacks", list(),

	"StackLens", list(),

	"Stack1Root", _V_null,
	"Stack2Root", _V_null,

	"PusherModules", list(),

	"chance", 0.5,
	"shipver", 1,
	"nosever", "pez",

	"nosepart", _V_null,


	"vr", 0.5,


	
"_", "_").



set _V_success to 0.

set _v_digits to "0123457689".



set _V_Errors to lexicon(
	"NOPEZ", "No PEZ Dispenser found on this vehicle!",
	"PUSHER", "At least one PEZ pusher is missing!",
	"TOOMANY", "Other than the pushers and the satellite stacks, parts have been found attached to the dispenser.",
	"MOD", "A part module was not found on one of the three pushers: (0)",
	"FIELD", "A part module field was not found on one of the three pushers: (0)",
	"EXIT", "Canceling deployment by user or script request.",
	"TMSATS", "There are too many sats in the dispenser stack: (0) found, (1) is max.",
	"DOOR", "Door is not open, but the PEZ requires an open door to do its task. Open it or configure the setting.",

	"FINISH", "The PEZ dispenser has completed its task."	// not an error actually
).

function VistaPEZAPI_cancel {
	parameter msg is "", p0 is "", p1 is "", p2 is "".
	set msg to msg:replace("(0)", p0:tostring):replace("(1)", p1:tostring):replace("(2)", p2:tostring).
	return _V_Errors[msg].
	set a to 0.
	set b to 1/a.
	//print "Shutting down the PEZ dispenser. Reboot kOS to try again.".
	//shutdown.
}


function _V_clamp {
	parameter x,m,n.
	return max(min(x,n),m).
}

function listmax {
	parameter x.

	set s to 0.
	for i in x {
		if i > s {
			set s to i.
		}
	}
	return s.
}


function _V_update_values {
	parameter finalize is false.





	set doexit to VistaPEZAPI_settings["exit"].

	if doexit {
		return VistaPEZAPI_cancel("EXIT").
	}



	set pez to ship:partsnamed(VistaPEZAPI_Settings["IDpez"]).

	if pez:length < 1 {
		return VistaPEZAPI_cancel("NOPEZ").
	}

	set disp to pez[0].

	//print(disp).

	set _V_Cache["PEZ"] to disp.

	set pusherH to disp:partsnamed(VistaPEZAPI_Settings["IDpezPusherH"]).

	if pusherH:length < 1 {
		return VistaPEZAPI_cancel("PUSHER").
	}

	set pusherHpart to pusherH[0].


	set _V_Cache["PusherH"] to pusherHpart.

	set pusherV to pusherHpart:partsnamed(VistaPEZAPI_Settings["IDpezPusherV"]).

	if pusherV:length < 1 {
		return VistaPEZAPI_cancel("PUSHER").
	}

	set pusherVpart to pusherV[0].

	set _V_Cache["PusherV"] to pusherVpart.

	set pusherV2 to pusherHpart:partsnamed(VistaPEZAPI_Settings["IDpezPusherV2"]).

	if pusherV2:length < 1 {
		return VistaPEZAPI_cancel("PUSHER").
	}

	set pusherV2part to pusherV2[0].

	set _V_Cache["PusherV2"] to pusherV2part.



	set mdl to VistaPEZAPI_Settings["moduleRob"].
	set flds to list(VistaPEZAPI_Settings["targetPosition"], VistaPEZAPI_Settings["traverseRate"]).

	set dispm to disp:modulesnamed(mdl).
	set pusherHm to pusherHpart:modulesnamed(mdl).
	set pusherVm to pusherVpart:modulesnamed(mdl).
	set pusherV2m to pusherV2part:modulesnamed(mdl).

	if dispm:length < 4 or pusherHm:length < 3 or pusherVm:length = 0 or pusherV2:length = 0 {
		return VistaPEZAPI_cancel("MOD",mdl).
	}

	set dispm to disp:getmodule(mdl).

	//print("HERE").
	//print(dispm:length).
	//set dispm to dispm[0].
	//print(dispm:part).
	set pusherHm to pusherHpart:getmodule(mdl).
	set pusherVm to pusherVpart:getmodule(mdl).
	set pusherV2m to pusherV2part:getmodule(mdl).

	print(dispm:name).
	print(disp).


	set _V_Cache["PusherModules"] to list(dispm, pusherHm, pusherVm, pusherV2m).

	for fld in flds {
		if not(dispm:allfieldnames:contains(fld) or pusherHm:allfieldnames:contains(fld) or pusherVm:allfieldnames:contains(fld) or pusherV2m:allfieldnames:contains(fld)) {
			print(pusherHm:allfieldnames).
			return VistaPEZAPI_cancel("FIELD",fld).
		}
	}

	set stack1root to "".
	set stack2root to "".

	set stack1 to _V_null.
	set stack2 to _V_null.

	set stacks to list().

	set stackroots to list().

	for thing in disp:children {
		if not (thing:name = VistaPEZAPI_Settings["IDpezPusherH"]) {
			stacks:add(list(thing)).
		}
	}

	print(stacks).

	if stacks:length >= 3 {
		return VistaPEZAPI_cancel("TOOMANY").
	}




	//if stacks:length = 0 {
	//	stacks:add(list(null)).
	//	stacks:add(list(null)).
	//}

	//if stacks:length = 1 {
	//	stacks:add(list(null)).
	//}

	set stacklens to list().

	set height to VistaPEZAPI_settings["height"].

	set satheight to VistaPEZAPI_settings["satHeight"].

	for i in range(stacks:length) {
		set root to stacks[i][0].

		for j in root:partsnamedpattern(".*") {
			//if not (stacks[i]:contains(j)) {
				stacks[i]:add(j).
			//}
		}

		//if stacks[i][0] = stacks[i][1] {
		stacks[i]:remove(0).	// remove root part as it will be there twice
		//}

		stacklens:add(stacks[i]:length).

		set maxsatsps to floor(height/satHeight - satheight).

		set _V_Cache["MaxSatsPerStack"] to maxsatsps.

		if stacks[i]:length > maxsatsps {
			return VistaPEZAPI_cancel("TMSATS", stacks[i]:length, maxsatsps).
		}
	}


	set longest to listmax(stacklens).


	if longest > maxsatsps {
		return VistaPEZAPI_cancel("TMSATS").
	}


	set _V_Cache["Stacks"] to stacks.
	set _V_Cache["StackLens"] to stacklens.

	//print(_V_Cache["Stacks"]).
	print("l").
	print(_V_Cache["StackLens"]).




	set vehicleID_x to ship:rootpart:uid.

	set vehicleID_y to vehicleID_x.	//:split("").

	set vehicleID_z to vehicleID_y.		//list().

	for charx in vehicleID_y {
		if not _V_digits:contains(charx) {
			//vehicleID_z:add(charx).
			set vehicleID_z to vehicleID_z:replace(charx, "").
		}
	}

	set vehicleID_s to 0.

	for x in vehicleID_z {
		set vehicleID_s to vehicleID_s + x:tonumber().
	}

	print(vehicleID_z).

	//set vehicleID to vehicleID_z:replace("",""):replace(" ",""):trim():tonumber().	// :join("")

	set vehicleID to vehicleID_s.

	//set almost_unique_val to vehicleID:length*10 / (vehicleID:length*10 + vehicleID[1]:tonumber + vehicleID[3]:tonumber).

	randomseed("rg1",vehicleID).

	set vr to random("rg1").





	//set vr to 0.1.

	

	//for i in range(2) {
	

	set v1_chance to VistaPEZAPI_settings["v1_chance"].
	set v2_chance to VistaPEZAPI_settings["v2_chance"].
	set v3_chance to VistaPEZAPI_settings["v3_chance"].

	set v1_fwdleft to VistaPEZAPI_settings["v1_fwdleft"].
	set v2_fwdleft to VistaPEZAPI_settings["v2_fwdleft"].
	set v3_fwdleft to VistaPEZAPI_settings["v3_fwdleft"].

	set nose_pez to VistaPEZAPI_settings["pez"].
	set nose_cargo to VistaPEZAPI_settings["crg"].
	set nose_crg to nose_cargo.
	set nose to VistaPEZAPI_settings["nsc"].

	set shipver to 1.
	set chance to 0.5.



	for i in v1_fwdleft {
		if ship:partsnamedpattern(i):length > 0 {
			set shipver to 1.
			set chance to v1_chance.
		}
	}
	for i in v2_fwdleft {
		if ship:partsnamedpattern(i):length > 0 {
			set shipver to 2.
			set chance to v2_chance.
		}
	}
	for i in v3_fwdleft {
		if ship:partsnamedpattern(i):length > 0 {
			set shipver to 3.
			set chance to v3_chance.
		}
	}



	set _V_Cache["chance"] to chance.
	set _V_Cache["shipver"] to shipver.

	set nosever to "pez".
	set nosepart to _V_null.

	for i in nose {
		set j to ship:partsnamedpattern(i).
		if j:length > 0 {
			set nosever to "nose".
			set nosepart to j[0].
		}
	}

	for i in nose_pez {
		set j to ship:partsnamedpattern(i).
		if j:length > 0 {
			set nosever to "pez".
			set nosepart to j[0].
		}
	}

	for i in nose_crg {
		set j to ship:partsnamedpattern(i).
		if j:length > 0 {
			set nosever to "crg".
			set nosepart to j[0].
		}
	}

	set _V_Cache["nosever"] to nosever.

	set _V_Cache["nosepart"] to nosepart.

	set _V_Cache["vr"] to vr.


	//}



	set ev_open1 to VistaPEZAPI_settings["open1"].
	set ev_close1 to VistaPEZAPI_settings["close1"].

	set ev_open2 to VistaPEZAPI_settings["open1"].
	set ev_close2 to VistaPEZAPI_settings["close1"].

	set ev_limit to VistaPEZAPI_settings["limit"].

	print("vr " + vr).
	print("chance " + chance).

	set opendoor to vr >= chance.
	


	//if vr >= chance {

	if VistaPEZAPI_settings["autoOpenDoor"] {

		for modu in nosepart:allmodules {
			set modul to nosepart:getmodule(modu).
			if modul:hasfield(ev_limit) {
				if opendoor {
					modul:setfield(ev_limit, 100).
				} else {
					modul:setfield(ev_limit, 0).
				}
			} //else {
			//	set opendoor to false.
			//}

			print(opendoor).

			if opendoor {
				if modul:hasevent(ev_open1) {
					modul:doevent(ev_open1).
				}
				else if modul:hasevent(ev_open2) {
					modul:doevent(ev_open2).
				}
			} //else {

			wait 0.

			set nogo_1 to (modul:hasevent(ev_open1) or modul:hasevent(ev_open2)).

			set nogo_2 to false.

			if modul:hasfield(ev_limit) {
				if modul:getfield(ev_limit) <= 84.999999 {
					set nogo_2 to true.
				}.
			}

			if (nogo_1 or nogo_2) and VistaPEZAPI_settings["requireOpenDoor"] {
				return VistaPEZAPI_cancel("DOOR").
			}

			wait 0.

			//}

			if finalize {
				if modul:hasevent(ev_close1) {
					modul:doevent(ev_close1).
				}
				else if modul:hasevent(ev_close2) {
					modul:doevent(ev_close2).
				}
			}

		}
	//}

	}



	return _V_success.

}









function _V_decouple_sat {

	set satdeployed to false.

	until satdeployed {
		if satdeployed {	// safe guard
			break.
		}

		set stacks to _V_Cache["stacks"].
		set stacklens to  _V_Cache["stacklens"].

		set longest to listmax(stacklens).

		set u to 0.


		for i in range(stacks:length) {
			set u to u+1.

			set sstack to stacks[i].
			set ssl to sstack:length.

			print("i " + u + " len " + ssl + " lst " + longest).
			if sstack:length = longest and sstack:length > 0 {
				set sl to sstack:length.
				for i in range(sl) {
					set sat to sstack[i].
					set md to VistaPEZAPI_Settings["moduleDec"].
					set hasmdl to false.
					set breakloop to false.
					//print(sat:allmodules).
					if sat:hasmodule(md) {
						set hasmdl to true.
						set mdl to sat:getmodule(md).

						//if mdl:length > 0 {
							mdl:doevent(VistaPEZAPI_Settings["decouple"]).
							print("<event>").
							set breakloop to true.
						//}
					}

					print(hasmdl).

					if breakloop {
						break.
					}

					//sstack:remove(0).
					//set sl to sstack:length.
				}
			}
		}

		set satdeployed to true.

		break.
	}

	return _V_success.
}


function _V_wait {
	parameter t,plus is 0.5.

	if t+plus >= 0.01 {
		wait t + plus.
	}
}


function VistaPEZAPI_do_cycle {

	set deploySpeed to VistaPEZAPI_settings["deploySpeed"].

	//set cycle_time to *2.

	set mods to _V_Cache["PusherModules"].

	set fld_pos to VistaPEZAPI_settings["targetPosition"].

	set fld_cur to VistaPEZAPI_settings["currentPos"].

	set fld_spd to VistaPEZAPI_settings["traverseRate"].


	set height to VistaPEZAPI_settings["height"].

	set satheight to VistaPEZAPI_settings["satHeight"].

	set deployWait to VistaPEZAPI_settings["deployWait"].


	set stacks to _V_Cache["stacks"].
	set stacklens to  _V_Cache["stacklens"].
	set longest to listmax(stacklens).


	set max_sats to height/satheight.	//floor().

	set half_sat to abs(max_sats - floor(max_sats)) * satHeight.

	set vDeploy to VistaPEZAPI_settings["vDeploy"].



	// m = 5.7/0.5 = 11.4

	// half = (12 - 11.4) * satHeight (which is 0.5)

	// half = 0.6 * 0.4
	// half = 0.24

	// dist = 5.7 - (11*0.5) + half


	set d to mods[0].
	set h to mods[1].
	set v1 to mods[2].
	set v2 to mods[3].


	lock d_time to abs(d:getfield(fld_pos) - d:getfield(fld_cur))/abs(d:getfield(fld_spd)).



	lock h_time to abs(h:getfield(fld_pos) - h:getfield(fld_cur))/abs(h:getfield(fld_spd)).


	lock v1_time to abs(v1:getfield(fld_pos) - v1:getfield(fld_cur))/abs(v1:getfield(fld_spd)).


	d:setfield(fld_spd, 1).

	v1:setfield(fld_spd, 0.2*5).
	v2:setfield(fld_spd, 0.2*5).
	h:setfield(fld_spd, 10).


	v1:setfield(fld_spd, 0.5*vDeploy*3).
	v2:setfield(fld_spd, 0.5*vDeploy*3).

	set _x to v1_time.

	h:setfield(fld_pos, -0.1).
	v1:setfield(fld_pos, vDeploy).
	v2:setfield(fld_pos, vDeploy).

	set _x to v1_time.

	//wait 0.

	_V_wait(h_time).

	print(stacklens).

	print(longest).

	set dist to height - (longest)*satHeight + half_sat - half_sat.	 // / height.		5.7 - 5.6			5.7 - 28 * 0.2			4 * 0.2 = 0.8

	set _x to v1_time.

	h:setfield(fld_spd, deploySpeed).

	print(dist).

	print(d:part).

	d:setfield(fld_pos, -dist).		// -5.07

	wait 0.

	set _x to v1_time.

	_V_wait(max(d_time,h_time+v1_time),0).


	set _x to v1_time.

	print("NOW!").

	// DECOUPLE

	//stage.

	_V_decouple_sat().
	//wait 0.1.
	wait deployWait.
	set dist to height - (longest)*satHeight + half_sat - satHeight.

	set _x to v1_time.

	d:setfield(fld_pos, -dist).

	wait 0.5.


	h:setfield(fld_pos, 100).

	wait 0.

	_V_wait(h_time/2, 0).

	set _x to v1_time.

	h:setfield(fld_spd, deploySpeed-0.01).



	set _x to v1_time.

	v1:setfield(fld_pos, -100).
	v2:setfield(fld_pos, -100).

	set _x to v1_time.

	//v1:setfield(fld_spd, abs(v1:getfield(fld_cur)-v1:getfield(fld_cur)  )/v1_time).
	//v2:setfield(fld_spd, abs(v2:getfield(fld_cur)-v1:getfield(fld_cur)  )/v1_time).
	
	set _x to v1_time.

	wait 0.

	_V_wait(v1_time, 0).

	
	set _x to v1_time.


	print("ARRIVED").

	return _V_success.
}






function VistaPEZAPI_get_stats {
	parameter iterations is -1.
	set result to _V_update_values().
	set stacks to _V_Cache["stacks"].
	set stacklens to  _V_Cache["stacklens"].
	set longest to listmax(stacklens).


	return lexicon(
		"stacks", stacks,		// list of lists of parts, bottom to top in the stacks
		"stack_lengths", stacklens,	// all stack lengths, same order as part lists in stacks
		"stack_longest", longest,	// longest stacks
		
		"status", result


	).


}

function VistaPEZAPI_exit {
	set VistaPEZAPI_settings["exit"] to true.
}



function VistaPEZAPI_run {
	parameter iterations is -1.

	set iterations to -1.	// bug patch

	until false {

		set statusx to _V_update_values().

		if not (statusx = _V_success) {
			return statusx.
		}



		set stacks to _V_Cache["stacks"].
		set stacklens to  _V_Cache["stacklens"].
		set longest to listmax(stacklens).

		if iterations < -0.00001 {
			set iterations to longest.
		}

		if iterations >= 0.00001 {
			
			VistaPEZAPI_do_cycle().
		} else {
			set statusx to _V_update_values(true).

			if not (statusx = _V_success) {
				return statusx.
			}

			return VistaPEZAPI_cancel("FINISH").
			// return.
		}

		set wt to VistaPEZAPI_Settings["waitTime"].

		wait wt.
	}



	return VistaPEZAPI_cancel("FINISH").
}





//for i in range(3) {
	//_V_update_values().
	//VistaPEZAPI_do_cycle().
	////_V_decouple_sat().
//}

//wait until ship:unpacked.

//wait until ag9.


//set VistaPEZAPI_Settings["targetPosition"] to "targ".

//wait until alt:radar >= 10000.

//print("Return: " + VistaPEZAPI_run()).

//print(_V_update_values()).



//wait 3.






