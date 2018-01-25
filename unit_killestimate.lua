function widget:GetInfo()
	return {
		name      = "Kill estimate icons",
		desc      = "Shows kill estimate icon on enemies",
		author    = "ivand",
		date      = "2017",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true,
	}
end

--[[
damageType = {
	0 = ordinary,
	1 = EMP,
	--2 = disarm,
}
]]--

local worthyUnitDefs = {
	[UnitDefNames["bomberprec"].id] = { bomber = true, ignoreShield = true, weaponNum = 2 },
	[UnitDefNames["bomberheavy"].id] = { bomber = true, ignoreShield = false, weaponNum = 1 },

	[UnitDefNames["cloaksnipe"].id] = { ignoreShield = false, weaponNum = 1 },
	[UnitDefNames["hoverarty"].id] = { ignoreShield = false, weaponNum = 1 },

	[UnitDefNames["spiderantiheavy"].id] = { ignoreShield = true, weaponNum = 1 },

	[UnitDefNames["tacnuke"].id] = { ignoreShield = false, weaponNum = 1 },
	[UnitDefNames["empmissile"].id] = { ignoreShield = true, weaponNum = 1 },
}

local killTex = "LuaUI/Images/commands/states/capturekill_on.png"
local empTex = "LuaUI/Images/commands/Bold/detonate.png"


function ePrint (tbl, indent)
	if not indent then indent = 0 end
	for k, v in pairs(tbl) do
		formatting = string.rep(" ", indent) .. k .. ": "

		if type(v) == "table" then
			Spring.Echo(formatting)
			ePrint(v, indent+1)
		else
			if type(v) == "boolean" or type(v) == "function" then
				Spring.Echo(formatting .. tostring(v))
			else
				Spring.Echo(formatting .. v)
			end
		end
	end
end

function ePrintEx (val, indent)
	if val==nil then Spring.Echo("nil")
	else
		if type(val) == "table" then ePrint (val, indent)
		else
			Spring.Echo(tostring(val))
		end
	end
end

local function CheckSpecState(name)
	local playerID = Spring.GetMyPlayerID()
	local _, _, spec, _, _, _, _, _ = Spring.GetPlayerInfo(playerID)

	if ( spec == true ) then
		Spring.Echo(string.format("< %s >: Spectator mode. Widget removed.", name))
		widgetHandler:RemoveWidget()
		return false
	end

	return true
end

function widget:Initialize()
	CheckSpecState(widget:GetInfo().name)

	for id, wInfo in pairs(worthyUnitDefs) do
		local weaponInfo = UnitDefs[id].weapons[wInfo.weaponNum]
		local onlyTargets = weaponInfo.onlyTargets

		local cp = WeaponDefs[weaponInfo.weaponDef].customParams
		local damage = cp.statsdamage

		local paralyzer = WeaponDefs[weaponInfo.weaponDef].paralyzer

		if paralyzer then
			wInfo.paralyze = damage
		else
			wInfo.damage = damage
		end


	end

	widget:SelectionChanged(Spring.GetSelectedUnits())

end

local showIcons = false
local relevantSelection = {}

function widget:SelectionChanged(newSelection)
	if (newSelection == nil) or (newSelection == {}) then
		return
	end

	local myTeamID =  Spring.GetMyTeamID()

	showIcons = false
	relevantSelection = {}
	for i = 1, #newSelection do
		local unitID = newSelection[i]

		--widget won't work with units from other team
		local uTeamID = Spring.GetUnitTeam(unitID)
		if uTeamID ~= myTeamID then
			showIcons = false
			return
		end

		local udID = Spring.GetUnitDefID(unitID)
		if worthyUnitDefs[udID] then
			relevantSelection[unitID] = worthyUnitDefs[udID]
			showIcons = true
		end
	end
end

local minEnemyMaxHealth = 800 --tune me?
local relevantTargets = {}

local icons = {}

function widget:GameFrame(frame)
	if frame % 10 == 5 then --3 times a second

		if showIcons then

			relevantTargets = {}

			local myAllyTeamID =  Spring.GetMyAllyTeamID()
			local units = Spring.GetAllUnits() -- Spring.GetVisibleUnits()?

			for i = 1, #units do
				local unit = units[i]
				local unitAllyTeam = Spring.GetUnitAllyTeam(unit)
				if unitAllyTeam ~= myAllyTeamID then --enemy
					local los = Spring.GetUnitLosState(unit, myAllyTeamID)

					if los and los.typed then

						local health = 0
						local maxHealth = 0
						local paralyzeDamage = 0
						local shield = nil

						local unitDefID = Spring.GetUnitDefID(unit)
						local ud = UnitDefs[unitDefID]

						local udShield = ud.customParams.shield_power

						if los.los then
							local armor = select(2, Spring.GetUnitArmored(unit)) or 1
							health, maxHealth, paralyzeDamage = Spring.GetUnitHealth(unit)
							--Spring.Echo(health, maxHealth, paralyzeDamage)
							health, maxHealth = health / armor, maxHealth / armor

							local shieldEnabled, currentPower = Spring.GetUnitShieldState(unit)
							shield = shieldEnabled and math.min(currentPower * 1.2, udShield) -- * 1.2 in case it charges up.
						else							--assume worst case
							maxHealth = ud.health / ud.armoredMultiple
							health = maxHealth

							--assume worst case
							shield = udShield
						end

						if maxHealth >= minEnemyMaxHealth then
							relevantTargets[unit] = {
								health = health,
								maxHealth = maxHealth,
								shield = shield,
								paralyze = paralyzeDamage,
							}
						end
					end
				end
			end

			local selectionPower = {
				damage = 0,
				paralyze = 0,
				shieldDamage =0,
			}
			for unitID, wInfo in pairs(relevantSelection) do

				--check built and not stunned
				local readyToShoot = not Spring.GetUnitIsStunned(unitID)


				--check not disarmed
				readyToShoot = readyToShoot and ((Spring.GetUnitRulesParam(unitID, "disarmed") or 0) == 0)

				if wInfo.bomber then
					-- check bomber has its ammo
					readyToShoot = readyToShoot and ((Spring.GetUnitRulesParam(unitID, "noammo") or 0) == 0)
				else
					--check if weapons is reloaded
					readyToShoot = readyToShoot and (Spring.GetUnitWeaponState(unitID, wInfo.weaponNum, "reloadState") <= frame)
					--Spring.Echo("reloadState", Spring.GetUnitWeaponState(unitID, wInfo.weaponNum, "reloadState"), frame)
				end

				--Spring.Echo("readyToShoot", readyToShoot)

				if readyToShoot then
					if wInfo.ignoreShield then
						selectionPower.damage = selectionPower.damage + (wInfo.damage or 0)
						selectionPower.paralyze = selectionPower.paralyze + (wInfo.paralyze or 0)
					else
						selectionPower.shieldDamage = selectionPower.shieldDamage + (wInfo.damage or 0)
					end
				end

			end

			for tID, tInfo in pairs(relevantTargets) do
				local dmg = 0
				if tInfo.shield then
					dmg = tInfo.shield - selectionPower.shieldDamage
					if dmg < 0 then --shield is gone
						dmg = -dmg --positive damage leftover
					end
				else
					dmg = selectionPower.shieldDamage
				end

				dmg = tInfo.health - selectionPower.damage - dmg

				icons[tID] = nil

				if dmg <= 0 then
					WG.icons.SetUnitIcon(tID, {name='cankill', texture=killTex})
					icons[tID] = true
				else
					WG.icons.SetUnitIcon(tID, {name='cankill', texture=nil})
				end

				local emp = tInfo.maxHealth - tInfo.paralyze - (tInfo.maxHealth / tInfo.health) * selectionPower.paralyze
				--Spring.Echo("EMP "..emp)
				if emp <= 0 then
					WG.icons.SetUnitIcon(tID, {name='canemp', texture=empTex})
					icons[tID] = true
				else
					WG.icons.SetUnitIcon(tID, {name='canemp', texture=nil})
				end

			end

		else --showIcons
			for tID, _ in pairs(icons) do
				WG.icons.SetUnitIcon(tID, {name='cankill', texture=nil})
				WG.icons.SetUnitIcon(tID, {name='canemp', texture=nil})
				icons[tID] = nil
			end
		end
	end
end

function widget:Shutdown()
	for tID, _ in pairs(icons) do
		WG.icons.SetUnitIcon(tID, {name='cankill', texture=nil})
		WG.icons.SetUnitIcon(tID, {name='canemp', texture=nil})
	end
end