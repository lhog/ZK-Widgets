include('keysym.h.lua')

local version = "0.3" -- String declaration. We can do this before the GetInfo callin (event).
function widget:GetInfo()
	return {
		name      = "Graphic Unit selector " .. version, -- .. means to combine two strings. The second string, 'version' (see above) is added to the end of this string.
		desc      = "Selects units when a user presses a certain key.",
		author    = "Shaman, mod by Helwor, NCG. Almost total rewrite ivand",
		date      = "May, 2017",
		license   = "None",
		layer     = 15,
		enabled   = true,
	}
end

------------------------------------------------------------------------------------------------------------
---  CONFIG
------------------------------------------------------------------------------------------------------------

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

local keysByClass = {
	raider = KEYSYMS.N_1,
	assault = KEYSYMS.N_3,
	riot = KEYSYMS.N_2,
	skirm = KEYSYMS.N_4,
	arty = KEYSYMS.N_5,
	aaunit = KEYSYMS.N_6,
	special1 = KEYSYMS.N_7,
	special2 = KEYSYMS.N_8,
	conunit = KEYSYMS.N_0,
}

local classByKeys = {}
for k, v in pairs(keysByClass) do
	classByKeys[v] = k
end

local keysAux={
	plus = KEYSYMS.KP6,
	minus = KEYSYMS.KP4,
}

local triggerKeys = {
	[keysByClass.raider] = true,
	[keysByClass.skirm] = true,
	[keysByClass.riot] = true,
	[keysByClass.assault] = true,
	[keysByClass.arty] = true,
	[keysByClass.special1] = true,
	[keysByClass.special2] = true,
	[keysByClass.aaunit] = true,
	[keysByClass.conunit] = true,
}

local triggerKeysAux = {
	[keysAux.plus] = true,
	[keysAux.minus] = true,
}

local keyHoldTime = 0.01

local rad = 1000
local unitTypes = {
	raider = {
		shipscout = true,
		shiptorpraider = true,
		spiderscout = true,
		cloakraid = true,
		shieldraid = true,
		vehraid = true,
		amphraid = true,
		vehscout = true,
		jumpraid = true,
		hoverraid = true,
		subraider = true,
		tankraid = true,
		gunshipraid = true,
		jumpscout = true,
		tankheavyraid = true,
		planefighter = true,
	},
	skirm = {
		cloakskirm = true,
		spiderskirm = true,
		jumpskirm = true,
		shieldskirm = true,
		shipskirm = true,
		amphfloater = true,
		vehsupport = true,
		gunshipskirm = true,
		shieldfelon = true,
		hoverskirm = true,
		striderfunnelweb = true,
		striderbantha = true,
	},
	riot = {
		bomberriot = true,
		amphimpulse = true,
		cloakriot = true,
		shieldriot = true,
		spiderriot = true,
		spideremp = true,
		jumpblackhole = true,
		vehriot = true,
		tankriot = true,
		amphriot = true,
		shiptorp = true,
		hoverriot = true,
		gunshipassault = true,
		shipassault = true,
		shipriot = true,
		striderdante = true,
	},
	assault = {
		jumpsumo = true,
		cloakassault = true,
		spiderassault = true,
		tankheavyassault = true,
		tankassault = true,
		shipassault = true,
		amphassault = true,
		vehassault = true,
		shieldassault = true,
		jumpassault = true,
		hoverassault = true,
		bomberprec = true,
		bomberheavy = true,
		gunshipkrow = true,
		striderdetriment = true,
	},
	arty = {
		cloakarty = true,
		striderarty = true,
		shieldarty = true,
		jumparty = true,
		veharty = true,
		tankarty = true,
		spidercrabe = true,
		shiparty = true,
		shipheavyarty = true,
		shipcarrier = true,
		hoverarty = true,
		gunshipheavyskirm = true,
		tankheavyarty = true,
		vehheavyarty = true,
	},
	special1 = {
		shieldscout = true,
		cloakheavyraid = true,
		cloaksnipe = true,
		vehcapture = true,
		gunshipemp = true,
		hoverdepthcharge = true,
		spiderantiheavy = true,
		spherecloaker = true,
		shieldshield = true,
		cloakjammer = true,
		planescout = true,
	},
	special2 = {
		gunshiptrans = true,
		shieldbomb = true,
		cloakbomb = true,
		gunshipbomb = true,
		jumpbomb = true,
		amphbomb = true,
		gunshipheavytrans = true,
		subtacmissile = true,
		spiderscout = true,
		amphtele = true,
		bomberdisarm = true,
		striderantiheavy = true,
		striderscorpion = true,
	},
	aaunit = {
		planefighter = true,
		planeheavyfighter = true,
		gunshipaa = true,
		shieldaa = true,
		cloakaa = true,
		vehaa = true,
		hoveraa = true,
		amphaa = true,
		spideraa = true,
		jumpaa = true,
		tankaa = true,
		shipaa = true,
	},
	conunit = {
		amphcon = true,
		planecon = true,
		cloakcon = true,
		spidercon = true,
		jumpcon = true,
		tankcon = true,
		hovercon = true,
		shieldcon = true,
		vehcon = true,
		gunshipcon = true,
		shipcon = true,
	},
}

------------------------------------------------------------------------------------------------------------
---  END OF CONFIG
------------------------------------------------------------------------------------------------------------

function widget:Initialize()
	--Unload if in replay or if mod is not Zero-K
	if Spring.IsReplay() or string.upper(Game.modShortName or "") ~= "ZK" then
		widgetHandler:RemoveWidget()
	end
end

function widget:GameOver(winningAllyTeams)
	--GameOver is irreversable with cheats, thus removing
	widgetHandler:RemoveWidget()
end

local unloaded = false
local function CheckIfSpectator()
	--spectator state is reversable with cheats
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveCallIn("KeyPress")
		widgetHandler:RemoveCallIn("KeyRelease")
		widgetHandler:RemoveCallIn("Update")
		widgetHandler:RemoveCallIn("DrawWorld")
		unloaded = true
	else
		if unloaded then
			widgetHandler:UpdateCallIn("KeyPress")
			widgetHandler:UpdateCallIn("KeyRelease")
			widgetHandler:UpdateCallIn("Update")
			widgetHandler:UpdateCallIn("DrawWorld")
			unloaded = false
		end
	end
end

local myTeamID = Spring.GetMyTeamID()
function widget:TeamChanged(teamID)
	CheckIfSpectator()
	myTeamID = Spring.GetMyTeamID()
end

function widget:PlayerChanged(playerID)
	CheckIfSpectator()
	myTeamID = Spring.GetMyTeamID()
end

function widget:PlayerAdded(playerID)
	CheckIfSpectator()
	myTeamID = Spring.GetMyTeamID()
end

function widget:PlayerRemoved(playerID)
	CheckIfSpectator()
	myTeamID = Spring.GetMyTeamID()
end

function widget:TeamDied(teamID)
	CheckIfSpectator()
	myTeamID = Spring.GetMyTeamID()
end

function widget:TeamChanged(teamID)
	CheckIfSpectator()
	myTeamID = Spring.GetMyTeamID()
end


local selection = {}

local on = false
local ontype = "none"

local keyPressedTime = 0
function widget:KeyPress(key, mods, isRepeat)
	if triggerKeysAux[key] then
		if key == keysAux.plus then
			rad = math.min(3000, rad+100)
		end

		if key == keysAux.minus then
			rad = math.max(100, rad-100)
		end
	end

	if triggerKeys[key] then
		if keyPressedTime == 0 then
			keyPressedTime = Spring.GetTimer()
		end

		local timeOk = Spring.DiffTimers(Spring.GetTimer(), keyPressedTime) >= keyHoldTime
		if timeOk then
			on = true
			ontype = tostring(classByKeys[key])
		end
	end
end

function widget:KeyRelease(key) -- Called whenever user stops pressing a key.
	if triggerKeys[key] then
		keyPressedTime = 0
		local _, _, _, shiftKey = Spring.GetModKeyState()
		if #selection > 0 then
			Spring.SelectUnitArray(selection, shiftKey)
		end
		selection = {}
		on = false
		ontype = "none"
	end
end

local x, y, z
local unitsPos
function widget:Update()
	if on then
		local mouseX, mouseY = Spring.GetMouseState()
		local desc, pos = Spring.TraceScreenRay(mouseX, mouseY, true)
		if desc ~= nil then
			x, y, z = pos[1], pos[2], pos[3]

			selection = {}
			for _, uID in ipairs(Spring.GetUnitsInCylinder(x, z, rad, myTeamID)) do
				if unitTypes[ontype][UnitDefs[Spring.GetUnitDefID(uID)].name] then
					selection[#selection + 1] = uID
				end
			end

			unitsPos = {}
			for _, uID in ipairs(selection) do
				if Spring.ValidUnitID(uID) then
					local ux, uy, uz = Spring.GetUnitPosition(uID)
					unitsPos[uID] = {
						ux = ux,
						uy = uy,
						uz = uz,
					}
				end
			end
		else
			x = nil
		end
	end
end

function widget:DrawWorld() -- this is used for openGL stuff.
	if on and x then
		gl.PushMatrix() --This is the start of an openGL function.
		gl.LineStipple(true)
		gl.LineWidth(2.0)
		gl.Color(color[ontype][1], color[ontype][2], color[ontype][3], 1)
		gl.DrawGroundCircle(x, y, z, rad, 40) -- draws a simple circle.
		gl.Translate(x, y, z)
		gl.Billboard()
		gl.Text("Selecting " .. ontype, 30, -25, 36, "v") -- Displays text. First value is the string, second is a modifier for x (in this case it's x-25), third is a modifier for y, fourth is the size, then last is a modifier for the text itself. "v" means vertical align.
		gl.Color(1, 1, 1, 1) -- we have to reset what we did here.
		gl.LineWidth(1.0)
		gl.LineStipple(false)
		gl.PopMatrix() -- end of function. Have to use this with after a push!


		for _, uID in ipairs(selection) do
			gl.PushMatrix()
			gl.LineWidth(3.0)
			gl.Color(color[ontype][1], color[ontype][2], color[ontype][3] ,1)
			gl.DrawGroundCircle(unitsPos[uID].ux, unitsPos[uID].uy, unitsPos[uID].uz, 40, 40)
			gl.Color(1, 1, 1, 1)
			gl.PopMatrix()
		end

	end
end