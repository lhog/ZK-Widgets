VFS.Include("LuaRules/Configs/customcmds.h.lua")
VFS.Include("LuaUI/Widgets/MyUtils.lua")

function widget:GetInfo()
  local version = "Iteration 7"
  local versionnotes = "- newtons now take target collision imminent into effect when determining when to drop the target. Simulates half a second.\n-Newtons also take into consideration if they have line of fire."
  return {
      name      = "Newton AI " .. version,
      desc      = "Causes newton spires to become ungodly annoying.\n\n" .. versionnotes,
      author    = "ivand, parts by _Shaman",
      date      = "2018",
      license   = "PD",
      layer     = 0,
      enabled   = true,
    }
end

local DEBUG_SWITCH = false


local HandledUnitDefIDs = {
	[UnitDefNames["jumpsumo"].id] =	{ --newton
			searchRange = UnitDefNames["jumpsumo"].maxWeaponRange,
			isStructure = (UnitDefNames["jumpsumo"].canMove == false) or (UnitDefNames["jumpsumo"].isBuilding == true),
			radius = UnitDefNames["jumpsumo"].radius,
			--pullRange = 460,
			--pushRange = 440,
			pushWeapons = {4, 5},
			pullWeapons = {2, 3},
		},
	[UnitDefNames["turretimpulse"].id] = { --sumo
			searchRange = UnitDefNames["turretimpulse"].maxWeaponRange,
			isStructure = (UnitDefNames["turretimpulse"] == false) or (UnitDefNames["turretimpulse"].isBuilding == true),
			radius = UnitDefNames["turretimpulse"].radius,
			--pullRange = 460,
			--pushRange = 440,
			pushWeapons = {1},
			pullWeapons = {2},
		},
}

local impulseMult = {
	[0] = 0.02, -- fixedwing
	[1] = 0.004, -- gunships
	[2] = 0.0036, -- other
}

local MAGNITUDE = 150 --just to not bother
local GRAVITY_BASELINE = 120

local GetMoveType = Spring.Utilities.getMovetype


--for Spring.GetTeamUnitsByDefs
local HandledUnitDefsList = {}
for id, _ in pairs(HandledUnitDefIDs) do
	HandledUnitDefsList[#HandledUnitDefsList + 1] = id
end

local HighPriority = {}
local AlwaysAttract = {}
local AlwaysRepel = {}

HighPriority[UnitDefNames["bomberheavy"].id] = true

AlwaysAttract[UnitDefNames["bomberheavy"].id] = true
AlwaysAttract[UnitDefNames["bomberprec"].id] = true

AlwaysRepel[UnitDefNames["bomberdisarm"].id] = true
AlwaysRepel[UnitDefNames["bomberriot"].id] = true


--[[
local HandledWeaponDefIDs = {
	[WeaponDefNames["turretimpulse_gravity_pos"].id] = {dir =  1, period = 6, weaponIndex = 1},
	[WeaponDefNames["turretimpulse_gravity_neg"].id] = {dir = -1, period = 6, weaponIndex = 2},
	[WeaponDefNames["jumpsumo_gravity_pos"].id] = {dir =  1, period = 6, weaponIndex = 1},
	[WeaponDefNames["jumpsumo_gravity_neg"].id] = {dir = -1, period = 6, weaponIndex = 2},
}
]]--


local myAllyTeamID = Spring.GetMyAllyTeamID()
local myTeamID = Spring.GetMyTeamID()
function widget:TeamChanged(teamID)
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
end

function widget:PlayerChanged(playerID)
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
end

function widget:PlayerAdded(playerID)
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
end

function widget:PlayerRemoved(playerID)
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
end

function widget:TeamDied(teamID)
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
end

function widget:TeamChanged(teamID)
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
end



local handledGraviUnits = {}

local function SwitchToPush(unitID)
	if handledGraviUnits[unitID] and Spring.GetUnitStates(unitID)["active"] == false then
		if DEBUG_SWITCH then Spring.Echo("SwitchToPush") end
		Spring.GiveOrderToUnit(unitID, CMD_PUSH_PULL, {1}, 0)
	end
end

local function SwitchToPull(unitID)
	if handledGraviUnits[unitID] and Spring.GetUnitStates(unitID)["active"] == true then
		if DEBUG_SWITCH then Spring.Echo("SwitchToPull") end
		Spring.GiveOrderToUnit(unitID, CMD_PUSH_PULL, {0}, 0)
	end
end

-- Constants
local TARGET_NONE = 0
local TARGET_GROUND = 1
local TARGET_UNIT= 2

local function SignalAttackTarget(unitID, unitDefID, targetID)
	local queue = Spring.GetUnitCommands(unitID, 1)
	if #queue == 1 then
		local cmd = queue[1]

		if (cmd.id == CMD.ATTACK and #cmd.params == 1 and cmd.params[1] == targetID) then
			return -- already attacking
		end
	end

	if HandledUnitDefIDs[unitDefID].isStructure then
		Spring.GiveOrderToUnit(unitID, CMD.ATTACK, {targetID}, {})
	else
		local setTarget
		local targetType=Spring.GetUnitRulesParam(unitID,"target_type") or TARGET_NONE
		if targetType == TARGET_UNIT then
			setTarget = Spring.GetUnitRulesParam(unitID, "target_id")
		end
		if setTarget ~= targetID then
			Spring.GiveOrderToUnit(unitID, CMD_UNIT_SET_TARGET, {targetID}, CMD.OPT_INTERNAL)
		end
	end
end

local function SignalClearTarget(unitID, unitDefID)
	if HandledUnitDefIDs[unitDefID].isStructure then
		local queue = Spring.GetUnitCommands(unitID, 1)
		if #queue == 1 then
			local cmd = queue[1]

			if (cmd.id == CMD.ATTACK and #cmd.params == 1) then
				Spring.GiveOrderToUnit(unitID, CMD.REMOVE, {cmd.tag}, {} )
			end
		end
	else
		Spring.GiveOrderToUnit(unitID, CMD_UNIT_CANCEL_TARGET, {}, {})
	end
end

--[[
local function SignalAttackTarget2(unitID, unitDefID, targetID)
	local queue = Spring.GetUnitCommands(unitID, 1)
	if #queue == 1 then
		local cmd = queue[1]

		if (cmd.id == CMD.ATTACK and #cmd.params == 1 and cmd.params[1] == targetID) then
			return -- already attacking
		end

		if (cmdID == CMD_RAW_MOVE or cmdID == CMD.MOVE or cmdID == CMD_FIGHT) then
			local setTarget
			local targetType=Spring.GetUnitRulesParam(unitID,"target_type") or TARGET_NONE
			if targetType == TARGET_UNIT then
				setTarget = Spring.GetUnitRulesParam(unitID, "target_id")
			end
			if setTarget ~= targetID then
				Spring.GiveOrderToUnit(unitID, CMD_UNIT_SET_TARGET, {targetID}, CMD.OPT_INTERNAL)
				return
			end
		end
	end

	Spring.GiveOrderToUnit(unitID, CMD.ATTACK, {targetID}, {})
end
]]--

local GRAVITY = -Game.gravity/30/30
local AIR_DENSITY = 1.2/4
local DRAG_COEFF = 1.0

local function GetDragAccelerationVec(vx, vy, vz, mass, radius)


    local sx = vx <= 0 and -1 or 1
    local sy = vy <= 0 and -1 or 1
    local sz = vz <= 0 and -1 or 1

    local dragScale = 0.5 * AIR_DENSITY * DRAG_COEFF * (math.pi * radius * radius * 0.01 * 0.01)

    return
        math.clamp((vx * vx * dragScale * -sx) / mass, -math.abs(vx), math.abs(vx)),
        math.clamp((vy * vy * dragScale * -sy) / mass, -math.abs(vy), math.abs(vy)),
        math.clamp((vz * vz * dragScale * -sz) / mass, -math.abs(vz), math.abs(vz));
end

local function WillHitMe(unitID, unitDefID, unitRadius, targetID, targetMass, targetRadius, frames, distTolerance)
	local tvx, tvy, tvz = Spring.GetUnitVelocity(targetID)

	local _, _, _, umx, umy, umz  = Spring.GetUnitPosition(unitID, true) --mid pos
	local tx, ty, tz, tmx, tmy, tmz  = Spring.GetUnitPosition(targetID, true) --mid pos

	local tox, toy, toz = tmx - tx, tmy - ty, tmz - tz --offsets

	for i = 1, frames do
		height = Spring.GetGroundHeight(tx, tz)
		if ty > height then
			tvy = tvy + GRAVITY
			local dx, dy, dz = GetDragAccelerationVec(tvx, tvy, tvz, targetMass, targetRadius)
			tvx, tvy, tvz = tvx + dx, tvy + dy, tvz + dz --drag will decrease velocity

			tx, ty, tz = tx + tvx, ty + tvy, tz + tvz

			if ty <= Spring.GetGroundHeight(tx, tz) then --crashed onto land
				tvy = 0
			end
		else
			tx, ty, tz = tx + tvx, height, tz + tvz
		end

		tmx, tmy, tmz = tx + tox, ty + toy, tz + toz --apply offsets

		local distance = math.sqrt( (umx - tmx)^2 + (umy - tmy)^2 + (umz - tmz)^2 ) - unitRadius - targetRadius

		if distance < distTolerance then
			return i
		end
	end
	return nil
end

local function SelectTarget(unitID, unitDefID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	local x, y, z = Spring.GetUnitPosition(unitID)
	local searchRange = HandledUnitDefIDs[unitDefID].searchRange	
	local unitsAround = Spring.GetUnitsInCylinder(x, z, searchRange)
	
	local radius = HandledUnitDefIDs[unitDefID].radius

	local potentialTargets = {}

	for _, uID in ipairs(unitsAround) do
		local uAllyTeamID = Spring.GetUnitAllyTeam(uID)
		local tUnitDefID = Spring.GetUnitDefID(uID)

		if Spring.ValidUnitID(uID) and tUnitDefID and Spring.GetUnitIsDead(uID) == false and uAllyTeamID ~= myAllyTeamID then
			local health, maxHealth, _, _, buildProgress = Spring.GetUnitHealth(uID)
			
			local moveType = GetMoveType(UnitDefs[tUnitDefID])

			local trans = Spring.GetUnitTransporter(unitID)

			if moveType and buildProgress == 1.0 and (trans == nil) then
				--local tx, ty, tz = Spring.GetUnitPosition(uID)
				local tx, ty, tz, tAx, tAy, tAz = Spring.GetUnitPosition(uID, false, true) --aim pos

				local tMass = Spring.GetUnitRulesParam(unitID, "massOverride") or Spring.GetUnitMass(uID) --massOverride for transporters and commanders
				local tRadius = Spring.GetUnitRadius(uID)

				local distance = math.sqrt( (x-tx)^2 + (y-ty)^2 + (z-tz)^2 )
				local magAbs = MAGNITUDE * GRAVITY_BASELINE / distance * impulseMult[moveType] / tMass
				--Spring.Echo(magAbs)


				local targetPush = 0
				local pushMag = 0
				for _, weaponNum in ipairs(HandledUnitDefIDs[unitDefID].pushWeapons) do
					if Spring.GetUnitWeaponTryTarget(unitID, weaponNum, uID) then
						pushMag = pushMag + magAbs
					end

					result, _, wTarget = Spring.GetUnitWeaponTarget(unitID, weaponNum)
					--Spring.Echo(result or "nil")
					if result == 1 and wTarget == uID  then -- this unit is currently targeted
						targetPush = targetPush + 1
					end
				end
				targetPush = targetPush / #HandledUnitDefIDs[unitDefID].pushWeapons

				local targetPull = 0
				local pullMag = 0
				for _, weaponNum in ipairs(HandledUnitDefIDs[unitDefID].pullWeapons) do
					if Spring.GetUnitWeaponTryTarget(unitID, weaponNum, uID) then
						pullMag = pullMag + magAbs
					end

					result, _, wTarget = Spring.GetUnitWeaponTarget(unitID, weaponNum)
					--Spring.Echo(result or "nil")
					if result == 0 and wTarget == uID  then -- this unit is currently targeted
						targetPull = targetPull + 1
					end
				end
				targetPull = targetPull / #HandledUnitDefIDs[unitDefID].pullWeapons

				local rangeMult = Spring.GetUnitRulesParam(uID, "comm_range_mult") or 1
				local enemyWeaponRange = UnitDefs[tUnitDefID].maxWeaponRange * rangeMult


				local tVx, tVy, tVz, tVel = Spring.GetUnitVelocity(uID)

				potentialTargets[uID] = {
					unitDefID = tUnitDefID,

					vx = tVx,
					vy = tVy,
					vz = tVz,
					vel = tVel,

					mass = tMass,
					radius = tRadius,

					moveType = moveType,
					unitDefID = tUnitDefID,
					grounded = (ty - Spring.GetGroundHeight(tx, tz) < 1),

					x = tx,
					y = ty,
					z = tz,

					ax = tAx,
					ay = tAy,
					az = tAz,

					distance = distance,
					--magAbs = magAbs,
					pushMag = pushMag,
					pullMag = pullMag,

					targetPush = targetPush,
					targetPull = targetPull,

					cost = UnitDefs[tUnitDefID].metalCost,

					enemyWeaponRange = enemyWeaponRange,

					healthPercentage = health / maxHealth,
				}




				--Spring.Echo("Target = ", uID)
			end
		end
	end

	--Spring.Echo("-----=========------")
	--ePrintEx(potentialTargets)

	local bestTargetMetric = math.huge
	local bestTarget = nil

	for uID, info in pairs(potentialTargets) do
		if info.pushMag + info.pullMag > 0 then
			local metricOrig = info.mass / math.max(info.pushMag, info.pullMag) / info.cost

			local metric = metricOrig

			if info.distance < info.enemyWeaponRange then
				metric = metric - 0.2 * metricOrig --priority for enemies that can shoot us!
			end

			if info.moveType == 2 and (info.grounded == false) then
				metric = metric - 0.05 * metricOrig -- prioritize land units in the air
			end

			metric = metric - 0.1 * metricOrig * (1.0 - info.healthPercentage) --prefer wounded units
			metric = metric - 0.1 * metricOrig * math.min(info.vel, 5.0) / 5.0 --unit speed with cap of 5.0
			metric = metric - 0.1 * metricOrig * math.max(info.targetPush, info.targetPull) --unit is targeted already

			metric = metric - 0.1 * metricOrig * ((AlwaysRepel[info.unitDefID] and 1) or 0) --prioritize units in special lists
			metric = metric - 0.1 * metricOrig * ((AlwaysAttract[info.unitDefID] and 1) or 0)

			if HighPriority[info.unitDefID] then
				metric = metric - 0.9 * metricOrig
			end

			if metric < bestTargetMetric then
				bestTargetMetric = metric
				bestTarget = uID
			end
			--Spring.Echo(uID, metric)
		end
	end

	if bestTarget then
		local tInfo = potentialTargets[bestTarget]
		--Spring.MarkerAddPoint(potentialTargets[bestTarget].x, potentialTargets[bestTarget].y, potentialTargets[bestTarget].z, tostring(bestTarget), true)
		--ePrintEx(potentialTargets[bestTarget])
		
		local collisionFrame = WillHitMe(unitID, unitDefID, radius, bestTarget, tInfo.mass, tInfo.radius, 12, 16) --12 frames prediction, 16 elmo proximity

		if AlwaysRepel[tInfo.unitDefID] then
			--Spring.Echo("Case 1")
			SwitchToPush(unitID)
		elseif AlwaysAttract[tInfo.unitDefID] then
			--Spring.Echo("Case 2")
			SwitchToPull(unitID)
		elseif tInfo.moveType == 0 or tInfo.moveType == 1 then --GS or Air
			--Spring.Echo("Case 3")
			SwitchToPush(unitID)
		elseif collisionFrame ~= nil then
			--Spring.Echo("Case 4", collisionFrame, Spring.GetGameFrame())
			SwitchToPush(unitID)
--[[		elseif tInfo.distance < tInfo.enemyWeaponRange then
			Spring.Echo("Case 5")
			SwitchToPush(unitID) ]]--
		elseif tInfo.distance <= searchRange / 2  then
			--Spring.Echo("Case 6")
			SwitchToPush(unitID)			
		elseif tInfo.distance > searchRange / 2  then
			--Spring.Echo("Case 7")
			SwitchToPull(unitID)
		else
			--Spring.Echo("Case Idiot!!!")
		end

		SignalAttackTarget(unitID, unitDefID, bestTarget)
	else
		--Spring.Echo(Spring.GetGameFrame())
		SignalClearTarget(unitID, unitDefID)
	end

end


function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if unitTeam == myTeamId and HandledUnitDefIDs[unitDefID] and cmdID == CMD.FIRE_STATE then
		if cmdParams[1] == 0 then --hold fire
			handledGraviUnits[unitID] = true
		else
			handledGraviUnits[unitID] = nil
		end
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	handledGraviUnits[unitID] = nil
end

function widget:UnitReverseBuilt(unitID, unitDefID, unitTeam)
	widget:UnitDestroyed(unitID, unitDefID, unitTeam)
end

function widget:Initialize()
	local graviUnits = Spring.GetTeamUnitsByDefs(myTeamID, HandledUnitDefsList)
	for _, unitID in pairs(graviUnits) do
		local fireState = Spring.GetUnitStates(unitID)["firestate"]
		if fireState == 0 then
			handledGraviUnits[unitID] = true
		end
	end
end

function widget:GameFrame(f)
	if f % 3 == 0 then
		for unitID, _ in pairs(handledGraviUnits) do
			local target, shootMode = SelectTarget(unitID)
		end
	end
end