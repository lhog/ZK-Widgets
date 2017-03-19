include('keysym.h.lua')

local version = "0.2" -- String declaration. We can do this before the GetInfo callin (event).
function widget:GetInfo()
	return {
		name      = "Graphic Unit selector " .. version, -- .. means to combine two strings. The second string, 'version' (see above) is added to the end of this string.
		desc      = "Selects units when a user presses a certain key.",
		author    = "Shaman, mod by Helwor, NCG",
		date      = "June 13, 2016",
		license   = "None",
		layer     = 15,
		enabled   = true,
	}
end -- All widgets/gadgets need this to run. You can declare variables before it though. This tells the engine this is a widget.

--config--
local debug = false
local color = {
	raider = {0.25,0.41,1},
	assault = {0.86,0.08,0.24},
	skirm = {0.25,0.55,0.13},
	arty = {0.8,0.68,0},
	riot = {0,0.81,0.82},
	special1 = {0.25,0.41,1},
	special2 = {0.86,0.08,0.24},
	aaunit = {0.25,0.41,1},
	conunit = {5,2,1},
	none = {1,1,1},
	growth = {0.19,0.5,0.08},
	shrink = {1,0.08,0.58},
}

local keypresses = {
	raider = KEYSYMS.N_1,
	assault = KEYSYMS.N_3,
	riot = KEYSYMS.N_2,
	skirm = KEYSYMS.N_4,
	arty = KEYSYMS.N_5,
	aaunit = KEYSYMS.N_6,
	special1 = KEYSYMS.N_7,
	special2 = KEYSYMS.N_8,
	conunit = KEYSYMS.N_0,
	plus = KEYSYMS.KP6,
	minus = KEYSYMS.KP4,
}
 
local triggerkeys = {
	[keypresses.raider] = true,
	[keypresses.skirm] = true,
	[keypresses.riot] = true,
	[keypresses.assault] = true,
	[keypresses.arty] = true,
	[keypresses.special1] = true,
	[keypresses.special2] = true,
	[keypresses.aaunit] = true,
	[keypresses.conunit] = true,
}

local keyHoldTime = 0.2

local rad = 1250
local on = false
local ontype = "none" -- we'll use ontype and on to talk to gameframe and drawworld.
local unittypes = {
	raider = {
		armpw = 1,
		corak = 1,
		corgator = 1,
		amphraider3 = 1,
		corfav = 1,
		corpyro = 1,
		corsh = 1,
		subraider = 1,
		logkoda = 1,
		armkam = 1,
		puppy = 1,
		panther = 1,
		amphraider2 = 1,
	},
	skirm = {
		armrock = 1,
		armsptk = 1,
		slowmort = 1,
		corstorm = 1,
		shipskirm = 1,
		amphfloater = 1,
		cormist = 1,
		gunshipsupport = 1,
		shieldfelon = 1,
		nsaclash = 1,
	},
	riot = {
		armwar = 1,
		cormak = 1,
		spiderriot = 1,
		arm_venom = 1,
		jumpblackhole = 1,
		corlevlr = 1,
		tawf114 = 1,
		amphriot = 1,
		shiptorp = 1,
		hoverriot = 1,
		blackdawn = 1,
	},
	assault = {
		corsumo = 1,
		armzeus = 1,
		armorco = 1,
		spiderassault = 1,
		corgol = 1,
		correap = 1,
		shipraider = 1,
		amphassault = 1,
		corraid = 1,
		corthud = 1,
		corcan = 1,
		hoverassault = 1,
	},
	arty = {
		armham = 1,
		armraven = 1,
		shieldarty = 1,
		firewalker = 1,
		corgarp = 1,
		cormart = 1,
		armcrabe = 1,
		shiparty = 1,
		corbats = 1,
		reef = 1,
		armmanni = 1,
		armbrawl = 1,
		trem = 1,
		armsptk = 1,
		armmerl = 1,
	},
	special1 = {
		corclog = 1,
		spherepole = 1,
		capturecar = 1,
		blastwing = 1,
		hoverdepthcharge = 1,
		armspy = 1,
		shipscout = 1,
		spherecloaker = 1,
		core_spectre = 1,
	},
	special2 = {
		corvalk = 1,
		corcrw = 1,
		corroach = 1,
		armtick = 1,
		armmerl = 1,
		bladew = 1,
		corsktl = 1,
		corbtrans = 1,
		subarty = 1,
		armflea = 1,
	},
	aaunit = {
		gunshipaa = 1,
		corcrash = 1,
		armjeth = 1,
		vehaa = 1,
		hoveraa = 1,
		amphaa = 1,
		spideraa = 1,
		armaak = 1,
		corsent = 1,
		shipaa = 1,
	},
	conunit = {
		amphcon = 1,
		armca = 1,
		armrectr = 1,
		arm_spider = 1,
		corfast = 1,
		coracv = 1,
		corch = 1,
		cornecro = 1,
		corned = 1,
		gunshipcon = 1,
		shipcon = 1,
	},
}
 
local selection = {}
local selected = {}
local checked = {}
local radchanged = false
local originalrad = rad
local radchangeddrawtime = 0
local lastrelease = -1

local shiftKey = nil
local keyPressedTime = 0
function widget:KeyPress(key, mods, isRepeat) -- This callin is triggered whenever the user presses a key.
	shiftKey = mods["shift"]

	if keyPressedTime == 0 then
		keyPressedTime = Spring.GetTimer()
	end	
	
	if key == keypresses.plus then
		if radchanged == false then
			originalrad = rad
			radchangeddrawtime = 4
		end
		rad = rad+20
		radchanged = true
	end

	if key == keypresses.minus and rad > 101 then
		if radchanged == false then
			originalrad = rad
			radchangeddrawtime = 4
		end
		rad = rad-20    
		radchanged = true
	end

	if key == keypresses.minus and rad < 101 then
		if radchanged == false then
			originalrad = rad
			radchangeddrawtime = 8
		end
		radchanged = true
	end

	if isRepeat == false and debug then
		Spring.Echo("game_message: key: " .. key)
	end
	
	local timeOk = Spring.DiffTimers(Spring.GetTimer(), keyPressedTime) >= keyHoldTime

	if key == keypresses.raider and ontype == "none" and timeOk then --Here keypresses.raider is the same as keypresses["raider"]. This is how you look up values in a table.
		on = true -- we're using this variable to talk to KeyRelease and DrawWorld. This way then they know we're working on getting a selection going.
		ontype = "raider"
	end

	if key == keypresses.skirm and ontype == "none" and timeOk then
		on = true
		ontype = "skirm"
	end

	if key == keypresses.riot and ontype == "none" and timeOk then
		on = true
		ontype = "riot"
	end

	if key == keypresses.assault  and ontype == "none" and timeOk then
		on = true
		ontype = "assault"
	end

	if key == keypresses.arty  and ontype == "none" and timeOk then
		on = true
		ontype = "arty"
	end

	if key == keypresses.special1  and ontype == "none" and timeOk then
		on = true
		ontype = "special1"
	end

	if key == keypresses.special2  and ontype == "none" and timeOk then
		on = true
		ontype = "special2"
	end

	if key == keypresses.aaunit  and ontype == "none" and timeOk and timeOk then
		on = true
		ontype = "aaunit"
	end

	if key == keypresses.conunit  and ontype == "none" and timeOk then
		on = true
		ontype = "conunit"
	end
end

function widget:GameFrame(f) -- called once every frame. This is so we don't keep looking for units every keypress.
	if radchanged then
		radchangeddrawtime = radchangeddrawtime - 1    
		if radchangeddrawtime == 0 then
			radchanged = false
		end
	end


	if f%2 == 0 then -- % - remainers left after divided by the second number. here it's framenum divided by 2. So this happens every 2nd frame.
		if Spring.IsGameOver() or Spring.GetSpectatingState() then
			Spring.Log(widget:GetInfo().name, LOG.ERROR, "Removing widget for spectator and after game has ended")
			widgetHandler:RemoveWidget(widget)
		end

		-- this has performance impact, test in use
		if on and ontype ~= "none" then
			local x,y = Spring.GetMouseState()
			local _,pos = Spring.TraceScreenRay(x,y,true)
			if type(pos) == "table" then -- prevent crashing from attempting to index a number value. The above seems to give random numbers sometimes.
				x = pos[1];y = pos[3];pos = nil -- ; is effectively a new line in LUA. This just makes your code look nicer.
			else
				if Spring.ValidUnitID(pos) then
					x,_,y = Spring.GetUnitPosition(pos)
				end
			end
			if x ~= nil and y ~= nil then
				for _,id in pairs(Spring.GetUnitsInCylinder(x,y,rad,Spring.GetMyTeamID())) do -- Here we're skipping the creation of the table altogether in favor of just plugging in the results of 'getunitsincylinder'
					if checked[id] == nil and unittypes[ontype][UnitDefs[Spring.GetUnitDefID(id)].name] and not selected[id] then -- Here we're using LUA's if true or exists logic. This says 'if this unit's unitdefid exists as a value in this table AND it's not a key in selected, then do this. This means units must match on the table and be a unique unit
						if debug then Spring.Echo("game_message: Selected " .. id) end
						selection[#selection+1] = id
						selected[id] = id
					end
					checked[id] = 1
				end
			end          
		end
	end
end

function widget:KeyRelease(key) -- Called whenever user stops pressing a key.
	if triggerkeys[key] then
		keyPressedTime = 0
		if on then		
			on = false
			ontype = "none"
			
			local olderSelection = {}
			if shiftKey then
				olderSelection = Spring.GetSelectedUnits()
			end
			
			for _,id in pairs(olderSelection) do
				selection[#selection+1] = id
			end
			
			Spring.SelectUnitArray(selection,false)
			
			selection = {} -- clear the table.
			selected = {}
			checked = {}
		end
	end
end

function widget:DrawWorld() -- this is used for openGL stuff.
	if on or radchanged then
		local x,y = Spring.GetMouseState()
		local _,pos = Spring.TraceScreenRay(x,y,true)
		x,y = nil
		if type(pos) == "number" then -- prevent crashing from attempting to index a number value. The above seems to give random numbers sometimes.
			if Spring.ValidUnitID(pos) then
				local id = pos
				pos = {}
				pos[1],pos[2],pos[3] = Spring.GetUnitPosition(id)
				id = nil
			elseif Spring.ValidFeatureID(pos) then -- This is also not needed...
				local id = pos                       --
				pos = {}                             --
				pos[1],pos[2],pos[3] = Spring.GetFeaturePosition(id) --
			end                                    --
		end

	if on then
		if type(pos) == "table" and pos[1] ~= nil and pos[2] ~= nil then
			gl.PushMatrix() --This is the start of an openGL function.
			gl.LineStipple(true)
			gl.LineWidth(2.0)
			gl.Color(color[ontype][1],color[ontype][2],color[ontype][3],1)
			gl.DrawGroundCircle(pos[1], pos[2], pos[3], rad, 40) -- draws a simple circle.
			gl.Translate(pos[1],pos[2],pos[3])
			gl.Billboard()
			gl.Text("Selecting " .. ontype,-0,-25,36,"v") -- Displays text. First value is the string, second is a modifier for x (in this case it's x-25), third is a modifier for y, fourth is the size, then last is a modifier for the text itself. "v" means vertical align.
			gl.Color(1,1,1,1) -- we have to reset what we did here.
			gl.LineWidth(1.0)
			gl.LineStipple(false)
			gl.PopMatrix() -- end of function. Have to use this with after a push!
		end
	end

	if radchanged and not on and type(pos) == "table" and originalrad then
		gl.PushMatrix()
		gl.LineWidth(1.0)
		gl.Color(1,1,1,1)
		gl.DrawGroundCircle(pos[1],pos[2],pos[3],originalrad,40) 
		gl.Translate(pos[1],pos[2],pos[3])
		gl.Billboard()
		gl.Text("Unit selection circle size: " .. rad,-105,10,15,"v")
		gl.LineWidth(1.0)
		gl.Color(1,1,1,1)
		gl.PopMatrix()
	end
	pos = nil
	end

	if #selection > 0 then -- Draw circles around selected units. #tablename is the length of the ordered table (or last consecutive value)
		local pos = {}
		for i=1,#selection do -- do this for every entry in the ordered table. i is the incremental value. i=1 means that the first value is 1. i increases by 1 (or a third value if provided eg 1,5,0.25 would do 1 + 0.25 every execution) with every execution and will continue until i == #selection. i=1,#table is very useful for doing things to every entry in an ordered table.
			if Spring.ValidUnitID(selection[i]) then
				pos[1],pos[2],pos[3] = Spring.GetUnitPosition(selection[i])
				gl.PushMatrix()
				gl.LineWidth(3.0)
				gl.Color(color[ontype][1],color[ontype][2],color[ontype][3],1)
				gl.DrawGroundCircle(pos[1],pos[2],pos[3],40,40)
				gl.Color(1,1,1,1)
				gl.PopMatrix()
			end
		end
	end
end