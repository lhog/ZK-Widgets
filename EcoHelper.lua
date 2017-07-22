VFS.Include("LuaUI/Widgets/MyUtils.lua")
VFS.Include("LuaRules/Configs/customcmds.h.lua")

local widgetName = "Eco Helper"

function widget:GetInfo()
  return {
    name      = widgetName,
    desc      = "Reminds about various economic events, automates some stuff",
    author    = "ivand",
    date      = "2017",
    license   = "public",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

local screenx, screeny

local myTeamID
local myAllyTeamID
local function UpdateTeamAndAllyTeamID()
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
end



local iconTypes = VFS.Include("LuaUI/Configs/icontypes.lua")

local function ToggleIdleOne(uId)
	--Spring.Echo("ToggleIdleOne")
	local commandQueueTableSize=spGetCommandQueue(uId, 0)
	--if not(commandQueueTable) or #commandQueueTable==0 then
	--Spring.Echo("#commandQueueTable"..#commandQueueTable)
	if commandQueueTableSize==0 then
		local unitDefId=spGetUnitDefID(uId)
		widget:UnitIdle(uId, unitDefId, myTeamID)
	end
end

local function ToggleIdle()
	local units=spGetTeamUnits(myTeamID)
	for _, uId in pairs(units) do
		ToggleIdleOne(uId)
	end
end

local heavenRadius = 160
local heavenRadiusSq = heavenRadius * heavenRadius
local heavenZones = {}

local function FindNearestHeavenZone(x, z)
	local minZoneID = nil
	local minZoneDist = math.huge
	for hash, heavenZone in pairs(heavenZones) do
		local DistSq = (heavenZone.x - x)^2 + (heavenZone.z - z)^2
		if (DistSq <= heavenRadiusSq) and (DistSq < minZoneDist) then
			minZoneID = hash
			minZoneDist = DistSq
		end
	end
	if minZoneID ~= nil then
		return minZoneID, math.sqrt(minZoneDist), heavenZones[minZoneID].x, heavenZones[minZoneID].z
	else
		return nil
	end
end

local function UpdateExistingHeavenZones()
	local heavenCount = Spring.GetTeamRulesParam(myTeamID, "haven_count")
	for i = 1, heavenCount do
		local x = Spring.GetTeamRulesParam(myTeamID, "haven_x" .. i)
		local z = Spring.GetTeamRulesParam(myTeamID, "haven_z" .. i)
		local hash = z + x * mapSizeZ
		heavenZones[hash] = {
			thisWidget = false,
			unitID = nil,
			x = x,
			z = z,
		}
	end
end


local scanInterval = 1 * Game.gameSpeed
local scanForRemovalInterval = 10 * Game.gameSpeed --10 sec

local knownFeatures = {}
local featuresUpdated

local E2M = 2 / 70 --solar ratio
local function UpdateFeatures(gf)
	featuresUpdated = false
	for _, fID in ipairs(Spring.GetAllFeatures()) do
		if not knownFeatures[fID] then --first time seen
			knownFeatures[fID] = {}
			knownFeatures[fID].lastScanned = -math.huge

			local fx, fy, fz = Spring.GetFeaturePosition(fID)
			knownFeatures[fID].x = fx
			knownFeatures[fID].y = fy
			knownFeatures[fID].z = fz

			knownFeatures[fID].isGaia = (Spring.GetFeatureTeam(fID) == gaiaTeamId)
			knownFeatures[fID].height = Spring.GetFeatureHeight(fID)
			knownFeatures[fID].drawAlt = ((fy > 0 and fy) or 0) + knownFeatures[fID].height + 10

			knownFeatures[fID].metal = 0
			featuresUpdated = true
		end

		if knownFeatures[fID] and gf - knownFeatures[fID].lastScanned >= scanInterval then
			knownFeatures[fID].lastScanned = gf

			local fx, fy, fz = Spring.GetFeaturePosition(fID)

			if knownFeatures[fID].x ~= fx or knownFeatures[fID].y ~= fy or knownFeatures[fID].z ~= fz then
				knownFeatures[fID].x = fx
				knownFeatures[fID].y = fy
				knownFeatures[fID].z = fz

				knownFeatures[fID].drawAlt = ((fy > 0 and fy) or 0) + knownFeatures[fID].height + 10
				featuresUpdated = true
			end

			local metal, _, energy = Spring.GetFeatureResources(fID)
			metal = metal + energy * E2M
			if knownFeatures[fID].metal ~= metal then
				knownFeatures[fID].metal = metal
				featuresUpdated = true
			end
		end
	end

	for fID, fInfo in pairs(knownFeatures) do

		if fInfo.isGaia and Spring.ValidFeatureID(fID) == false then
			Spring.Echo("fInfo.isGaia and Spring.ValidFeatureID(fID) == false")
			knownFeatures[fID] = nil
			fInfo = nil
			featuresUpdated = true
		end

		if fInfo and gf - fInfo.lastScanned >= scanForRemovalInterval then --long time unseen features, maybe they were relcaimed or destroyed?
			local los = Spring.IsPosInLos(fInfo.x, fInfo.y, fInfo.z, myAllyTeamID)
			if los then --this place has no feature, it's been moved or reclaimed or destroyed
				Spring.Echo("this place has no feature, it's been moved or reclaimed or destroyed")
				fInfo = nil
				knownFeatures[fID] = nil
				featuresUpdated = true
			end
		end

		if fInfo and featuresUpdated then
			knownFeatures[fID].clID = nil
		end
	end
end

local minSqDistance = 170^2
--local minRequiredForce = 1
local minFeatureMetal = 8 --flea

local featureClusters = {}
local function ClusterizeFeatures(gf)
	featureClusters = {}

	local sortedTable = {}
	for fID, fInfo in pairs(knownFeatures) do
		if fInfo.metal >= minFeatureMetal then
			sortedTable[#sortedTable + 1] = {fInfo.metal, fID}
		end
	end

	table.sort(sortedTable, function(a,b) return a[1] > b[1] end)
	--Spring.Echo("#sortedTable", #sortedTable)

	for i = 1, #sortedTable do
		local metal1 = sortedTable[i][1]
		local fID1 = sortedTable[i][2]
		if not knownFeatures[fID1].clID then
			local fx1, fz1 = knownFeatures[fID1].x, knownFeatures[fID1].z

			featureClusters[#featureClusters + 1] = {}
			knownFeatures[fID1].clID = #featureClusters

			local thisCluster = {
				members = {fID1},
				xmin = fx1,
				xmax = fx1,
				zmin = fz1,
				zmax = fz1,
				metal = metal1,
			}

			local iter = 0

			local goodDist = true
			while goodDist do
				iter = iter + 1
				if iter > 200 then
					Spring.Log(widget:GetInfo().name, LOG.ERROR, "Stuck in goodDist, made more than 200 iterations")
					break
				end
				local minDist = math.huge
				local metalAddition = nil
				local minDistIdx = nil

				local txmin, txmax, tzmin, tzmax = thisCluster.xmin, thisCluster.xmax, thisCluster.zmin, thisCluster.zmax
				for j = i + 1, #sortedTable do
					local metal2 = sortedTable[j][1]
					local fID2 = sortedTable[j][2]
					if not knownFeatures[fID2].clID then
						local fx2, fz2 = knownFeatures[fID2].x, knownFeatures[fID2].z

						local dx, dz = 0, 0

						if     fx2 > txmax then
							dx = fx2 - txmax
						elseif fx2 < txmin then
							dx = fx2 - txmin
						end

						if     fz2 > tzmax then
							dz = fz2 - tzmax
						elseif fz2 < tzmin then
							dz = fz2 - tzmin
						end

						local sqDist = dx^2 + dz^2

						if sqDist <= minSqDistance and sqDist < minDist then
							--Spring.Echo("minDist", sqDist)
							minDist = sqDist
							metalAddition = metal2
							minDistIdx = j
						end
					end
				end

				if minDistIdx then
					--Spring.Echo("minDist", minDist, "#featureClusters", #featureClusters)
					local fIDMax = sortedTable[minDistIdx][2]

					knownFeatures[fIDMax].clID = #featureClusters
					thisCluster.members[#thisCluster.members + 1] = fIDMax

					thisCluster.metal = thisCluster.metal + metalAddition

					local fxM, fzM = knownFeatures[fIDMax].x, knownFeatures[fIDMax].z

					txmin = math.min(txmin, fxM)
					txmax = math.max(txmax, fxM)
					tzmin = math.min(tzmin, fzM)
					tzmax = math.max(tzmax, fzM)

					thisCluster.xmin, thisCluster.xmax, thisCluster.zmin, thisCluster.zmax = txmin, txmax, tzmin, tzmax

				end
				goodDist = (minDistIdx ~= nil)
				--ePrintEx({thisCluster=thisCluster})
			end

			featureClusters[#featureClusters] = thisCluster
		end
	end
end

--- JARVIS MARCH
-- https://github.com/kennyledet/Algorithm-Implementations/blob/master/Convex_hull/Lua/Yonaba/convex_hull.lua

-- Convex hull algorithms implementation
-- See : http://en.wikipedia.org/wiki/Convex_hull

-- Calculates the signed area
local function signedArea(p, q, r)
  local cross = (q.z - p.z) * (r.x - q.x)
              - (q.x - p.x) * (r.z - q.z)
  return cross
end

-- Checks if points p, q, r are oriented counter-clockwise
local function isCCW(p, q, r) return signedArea(p, q, r) < 0 end

-- Returns the convex hull using Jarvis' Gift wrapping algorithm).
-- It expects an array of points as input. Each point is defined
-- as : {x = <value>, y = <value>}.
-- See : http://en.wikipedia.org/wiki/Gift_wrapping_algorithm
-- points  : an array of points
-- returns : the convex hull as an array of points
local function JarvisMarch(points)
  -- We need at least 3 points
  local numPoints = #points
  if numPoints < 3 then return end

  -- Find the left-most point
  local leftMostPointIndex = 1
  for i = 1, numPoints do
    if points[i].x < points[leftMostPointIndex].x then
      leftMostPointIndex = i
    end
  end

  local p = leftMostPointIndex
  local hull = {} -- The convex hull to be returned

  -- Process CCW from the left-most point to the start point
  repeat
    -- Find the next point q such that (p, i, q) is CCW for all i
    q = points[p + 1] and p + 1 or 1
    for i = 1, numPoints, 1 do
      if isCCW(points[p], points[i], points[q]) then q = i end
    end

    table.insert(hull, points[q]) -- Save q to the hull
    p = q  -- p is now q for the next iteration
  until (p == leftMostPointIndex)

  return hull
end
--- JARVIS MARCH

local minDim = 100

local featureConvexHulls = {}
local function ClustersToConvexHull()
	featureConvexHulls = {}
	for fc = 1, #featureClusters do
		local clusterPoints = {}
		for fcm = 1, #featureClusters[fc].members do
			local fID = featureClusters[fc].members[fcm]
			clusterPoints[#clusterPoints + 1] = {
				x = knownFeatures[fID].x,
				y = knownFeatures[fID].drawAlt,
				z = knownFeatures[fID].z
			}
			--Spring.MarkerAddPoint(knownFeatures[fID].x, 0, knownFeatures[fID].z, string.format("%i(%i)", fc, fcm))
		end

		local convexHull
		if #clusterPoints >= 3 then
			convexHull = JarvisMarch(clusterPoints)
		else
			local thisCluster = featureClusters[fc]

			local xmin, xmax, zmin, zmax = thisCluster.xmin, thisCluster.xmax, thisCluster.zmin, thisCluster.zmax

			local dx, dz = xmax - xmin, zmax - zmin

			if dx < minDim then
				xmin = xmin - (minDim - dx) / 2
				xmax = xmax + (minDim - dx) / 2
			end

			if dz < minDim then
				zmin = zmin - (minDim - dz) / 2
				zmax = zmax + (minDim - dz) / 2
			end

			local height = clusterPoints[1].y
			if #clusterPoints == 2 then
				height = math.max(height, clusterPoints[2].y)
			end

			convexHull = {
				{x = xmin, y = height, z = zmin},
				{x = xmax, y = height, z = zmin},
				{x = xmax, y = height, z = zmax},
				{x = xmin, y = height, z = zmax},
			}
		end

		featureConvexHulls[#featureConvexHulls + 1] = convexHull
		--[[
		for i = 1, #convexHull do
			Spring.MarkerAddPoint(convexHull[i].x, convexHull[i].y, convexHull[i].z, string.format("C%i(%i)", fc, i))
		end
		]]--
	end
end

--local reclaimColor = (1.0, 0.2, 1.0, 0.7);
local reclaimColor = {1.0, 0.2, 1.0, 0.3}
local reclaimEdgeColor = {1.0, 0.2, 1.0, 0.5}
local flashColor = {1.0, 0.0, 0.0, 0.15}
local flashMetalTextColor = {1.0, 0.0, 0.0, 0.8}

local flashIdleTextColor = {1.0, 1.0, 0.0, 0.8}
local idleFillColor = {1.0, 1.0, 0.0, 0.4}
local idleModelColor = {1.0, 1.0, 0.0, 1.0}

local flashEStallTextColor = {1.0, 0.0, 1.0, 0.8}

local textScale = {1.0, 0.4, 1.0}


local function ColorMul(scalar, actionColor)
	return {scalar * actionColor[1], scalar * actionColor[2], scalar * actionColor[3], actionColor[4]}
end

function widget:Initialize()
	CheckSpecState(widgetName)
	curModID = string.upper(Game.modShortName or "")
	if ( curModID ~= "ZK" ) then
		widgetHandler:RemoveWidget()
		return
	end

	UpdateTeamAndAllyTeamID()

	--local iconDist = Spring.GetConfigInt("UnitIconDist")
	UpdateExistingHeavenZones()

	screenx, screeny = widgetHandler:GetViewSizes()

	local units=spGetTeamUnits(myTeamID)
	for _, unitID in pairs(units) do
		widget:UnitGiven(unitID, Spring.GetUnitDefID(unitID), myTeamID, nil)
	end
	--ToggleIdle()
end

function widget:TeamChanged(teamID)
	UpdateTeamAndAllyTeamID()
end

function widget:PlayerChanged(playerID)
	UpdateTeamAndAllyTeamID()
end

function widget:PlayerAdded(playerID)
	UpdateTeamAndAllyTeamID()
end

function widget:PlayerRemoved(playerID)
	UpdateTeamAndAllyTeamID()
end

function widget:TeamDied(teamID)
	UpdateTeamAndAllyTeamID()
end

function widget:TeamChanged(teamID)
	UpdateTeamAndAllyTeamID()
end

local idleList={}

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID then
		local units=FilterMobileConstructors({unitID})
		local built = select(5, Spring.GetUnitHealth(unitID))
		if #units == 1 and built == 1.0 then
			local gameFrame = spGetGameFrame()
			idleList[unitID] = {}
			idleList[unitID].gameFrame = gameFrame
			--local dims = Spring.GetUnitDefDimensions(unitDefID)
			--local uDef = UnitDefs[unitDefID]


			--idleList[unitID].radius = math.round( math.sqrt( (uDef.zsize or uDef.ysize)^2 + uDef.xsize^2 ) ) * 4
			--local factor = 4 * 1.2
			--factor = factor * (tonumber(uDef.customParams.selection_scale) or 1)

			--idleList[unitID].radius = dims.radius
			--idleList[unitID].radius = math.round( math.sqrt( uDef.zsize^2 + uDef.xsize^2 ) ) * factor
			--idleList[unitID].radius = math.sqrt( 2 * math.max( uDef.zsize, uDef.xsize ) ^ 2 ) * factor
		end
	end
end

--[[
local idleCancelCommands={
	[CMD.WAIT]=true, --in case one wants to mute widget
	[CMD.MOVE]=true,
	[CMD.ATTACK]=true,
	[CMD.RECLAIM]=true,
	[CMD.REPAIR]=true,
	[CMD.FIGHT]=true,
	[CMD.PATROL]=true,
	[CMD.AREA_ATTACK]=true,
	[CMD.GUARD]=true,
	[CMD.DGUN]=true,
	[CMD.RESURRECT]=true,
	[CMD_UNIT_SET_TARGET]=true,
	[CMD_BUILD]=true,
	[CMD_AREA_GUARD]=true,
	[CMD_AREA_MEX]=true,
	[CMD_MORPH]=true,
	[CMD_JUMP]=true,
	[CMD_ONECLICK_WEAPON]=true,
	--to be extended
}
]]--

local stateCommands = {
	[CMD.ONOFF] = true,
	[CMD.FIRE_STATE] = true,
	[CMD.MOVE_STATE] = true,
	[CMD.REPEAT] = true,
	[CMD.CLOAK] = true,
	[CMD.STOCKPILE] = true,
	[CMD.TRAJECTORY] = true,
	[CMD.IDLEMODE] = true,
	[CMD_GLOBAL_BUILD] = true,
	[CMD_STEALTH] = true,
	[CMD_CLOAK_SHIELD] = true,
	[CMD_UNIT_FLOAT_STATE] = true,
	[CMD_PRIORITY] = true,
	[CMD_MISC_PRIORITY] = true,
	[CMD_RETREAT] = true,
	[CMD_UNIT_BOMBER_DIVE_STATE] = true,
	[CMD_AP_FLY_STATE] = true,
	[CMD_AP_AUTOREPAIRLEVEL] = true,
	[CMD_UNIT_SET_TARGET] = true,
	[CMD_UNIT_CANCEL_TARGET] = true,
	[CMD_UNIT_SET_TARGET_CIRCLE] = true,
	[CMD_ABANDON_PW] = true,
	[CMD_RECALL_DRONES] = true,
	[CMD_UNIT_KILL_SUBORDINATES] = true,
	[CMD_UNIT_AI] = true,
	[CMD_WANT_CLOAK] = true,
	[CMD_DONT_FIRE_AT_RADAR] = true,
	[CMD_AIR_STRAFE] = true,
	[CMD_PREVENT_OVERKILL] = true,
	[CMD_SELECTION_RANK] = true,
	[CMD.SET_WANTED_MAX_SPEED] = true,
}

local energyUnitDefs = {
	[UnitDefNames["energywind"].id] = true,
	[UnitDefNames["energysolar"].id] = true,
	[UnitDefNames["energygeo"].id] = true,
	[UnitDefNames["energyfusion"].id] = true,
}
local storageUnitDef = UnitDefNames["staticstorage"].id
local mexUnitDefs = UnitDefNames["staticmex"].id
local caretakerUnitDef = UnitDefNames["staticcon"].id

local energyUnitsUnderConstruction = {}
local storageUnitsUnderConstruction = {}
local mexUnitsUnderConstruction = {}
local caretakerUnitsUnderConstruction = {}

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	--if idleList[unitID] and	(cmdID<0 or idleCancelCommands[cmdID]) then
	if idleList[unitID] and	(cmdID < 0 or stateCommands[cmdID] == nil) then
		idleList[unitID] = nil
	end
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	ToggleIdleOne(unitID)
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if (myTeamID == unitTeam) then
		if energyUnitDefs[unitDefID] then
			energyUnitsUnderConstruction[unitID] = Spring.GetUnitRulesParam(unitID, "buildpriority") or 1
		end
		if storageUnitDef == unitDefID then
			storageUnitsUnderConstruction[unitID] = Spring.GetUnitRulesParam(unitID, "buildpriority") or 1
		end
		if mexUnitDef == unitDefID then
			mexUnitsUnderConstruction[unitID] = Spring.GetUnitRulesParam(unitID, "buildpriority") or 1
		end
		if caretakerUnitDef == unitDefID then
			caretakerUnitsUnderConstruction[unitID] = Spring.GetUnitRulesParam(unitID, "buildpriority") or 1
		end
	end
	ToggleIdleOne(unitID)
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	--Spring.Echo("UnitFinished", unitID)
	if (myTeamID == unitTeam) then
		if energyUnitDefs[unitDefID] then
			energyUnitsUnderConstruction[unitID] = nil
		end
		if storageUnitDef == unitDefID then
			storageUnitsUnderConstruction[unitID] = nil
		end
		if mexUnitDef == unitDefID then
			mexUnitsUnderConstruction[unitID] = nil
		end
		if caretakerUnitDef == unitDefID then
			caretakerUnitsUnderConstruction[unitID] = nil
		end
		-----
		if caretakerUnitDef == unitDefID then
			local x, y, z = Spring.GetUnitPosition(unitID)

			local minZoneID = FindNearestHeavenZone(x, z)
			--Spring.Echo("minZoneID", minZoneID)
			if minZoneID == nil then
				--Spring.Echo("UnitFinished sethaven", unitID)
				Spring.SendLuaRulesMsg('sethaven|' .. x .. '|' .. y .. '|' .. z )
				local hash = z + x * mapSizeZ
				heavenZones[hash] = {
					thisWidget = true,
					unitID = unitID,
					x = x,
					z = z,
				}
			end


		end
	end
	ToggleIdleOne(unitID)
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if (myTeamID == newTeam) then
		local buildProg = select(5, Spring.GetUnitHealth(unitID))
		if buildProg == 1.0 then
			widget:UnitFinished(unitID, unitDefID, newTeam)
		else
			widget:UnitCreated(unitID, unitDefID, newTeam)
		end
	end
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	widget:UnitDestroyed(unitID, unitDefID, newTeam, nil, nil, nil)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	--Spring.Echo("UnitDestroyed", unitID)
	if idleList[unitID] then
		idleList[unitID]=nil
	end
	if (myTeamID == unitTeam) then
		if energyUnitDefs[unitDefID] then
			energyUnitsUnderConstruction[unitID] = nil
		end
		if storageUnitDef == unitDefID then
			storageUnitsUnderConstruction[unitID] = nil
		end
		if mexUnitDef == unitDefID then
			mexUnitsUnderConstruction[unitID] = nil
		end
		---
		if caretakerUnitDef == unitDefID then
			caretakerUnitsUnderConstruction[unitID] = nil
			local x, y, z = Spring.GetUnitPosition(unitID)

			local thisZoneID = FindNearestHeavenZone(x, z)
			--Spring.Echo("thisZoneID", thisZoneID)
			if thisZoneID then
				local nearbyUnits = Spring.GetUnitsInCylinder(x, z, heavenRadius, unitTeam)
				--ePrintEx(nearbyUnits)
				local nearbyCaretaker = false
				for _, nearbyUnitID in ipairs(nearbyUnits) do
					local unitStatus = Spring.GetUnitIsDead(nearbyUnitID)
					--Spring.Echo("unitStatus", unitStatus)
					if unitStatus ~= nil and unitStatus == false then
						local nearbyUnitDefID = Spring.GetUnitDefID(nearbyUnitID)
						--Spring.Echo(UnitDefs[nearbyUnitDefID].humanName)
						if nearbyUnitDefID == caretakerUnitDef then
							nearbyCaretaker = true
							break
						end
					end
				end
				if not nearbyCaretaker then --kill HeavenZone
					--Spring.Echo("UnitDestroyed sethaven", unitID)
					Spring.SendLuaRulesMsg('sethaven|' .. x .. '|' .. y .. '|' .. z )
					heavenZones[thisZoneID] = nil
				end
			end
		end
	end
end

local flashIdleWorkers = false
local flashMetalExcess = false
local flashEnergyStall = false
local metalStall = false

local gracePeriod = 30 * 30 --first 30 seconds of the game
local magicNumber = 10000
local function CheckAndSetFlashMetalExcess(frame)
	if frame < gracePeriod then return end

	local mCurr, mStor, mPull, mInco, mExpe, mShar, mSent, mReci = spGetTeamResources(myTeamID, "metal")
	local eCurr, eStor, ePull, eInco, eExpe, eShar, eSent, eReci = spGetTeamResources(myTeamID, "energy")

	mStor, eStor  = mStor - magicNumber, eStor - magicNumber

	local mStorageLeft = mStor-mCurr
	if mStorageLeft < 0 then mStorageLeft = 0 end

	if eCurr < 0 then eCurr = 1 end
	if mCurr < 0 then mCurr = 1 end

	local mProfit=mInco - mExpe + mReci - mSent
	local eProfit=eInco - math.max(eExpe, ePull) + eReci - eSent

	--ePrintEx({eCurr=eCurr, eStor=eStor, ePull=ePull, eInco=eInco, eExpe=eExpe, eShar=eShar, eSent=eSent, eReci=eReci})
	--ePrintEx({eProfit=eProfit, mProfit=mProfit})


	flashEnergyStall = eStor/eCurr > 5
	metalStall = mStor/mCurr > 5
	--[[
	if eProfit < 0 and eProfit < mProfit then
		flashEnergyStall = eCurr / -eProfit <= 20
	else
		flashEnergyStall = false
	end
	]]--

	if mProfit < 0 then
		flashMetalExcess=false
	else
		flashMetalExcess=mStorageLeft / mProfit <= 10
	end
end

local highPrio = 2
local SHIFT_TABLE = {"shift"}

local function SetEcoHighPriority()
	for uID, prio in pairs(energyUnitsUnderConstruction) do
		if flashEnergyStall and prio and prio < highPrio then
			--Spring.Echo("energyUnitsUnderConstruction")
			Spring.GiveOrderToUnit(uID, CMD_PRIORITY, {highPrio}, SHIFT_TABLE)
			energyUnitsUnderConstruction[uID] = highPrio
		end
	end
	for uID, prio in pairs(storageUnitsUnderConstruction) do
		if flashMetalExcess and prio and prio < highPrio then
			--Spring.Echo("storageUnitsUnderConstruction")
			Spring.GiveOrderToUnit(uID, CMD_PRIORITY, {highPrio}, SHIFT_TABLE)
			storageUnitsUnderConstruction[uID] = highPrio
		end
	end
	for uID, prio in pairs(caretakerUnitsUnderConstruction) do
		if flashMetalExcess and prio and prio < highPrio then
			--Spring.Echo("mexUnitsUnderConstruction")
			Spring.GiveOrderToUnit(uID, CMD_PRIORITY, {highPrio}, SHIFT_TABLE)
			mexUnitsUnderConstruction[uID] = highPrio
		end
	end
	for uID, prio in pairs(mexUnitsUnderConstruction) do
		if metalStall and prio and prio < highPrio then
			--Spring.Echo("mexUnitsUnderConstruction")
			Spring.GiveOrderToUnit(uID, CMD_PRIORITY, {highPrio}, SHIFT_TABLE)
			mexUnitsUnderConstruction[uID] = highPrio
		end
	end
end

local color
local cameraScale

local drawFeatureConvexHullSolidList
local function DrawFeatureConvexHullSolid()
	gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
	for i = 1, #featureConvexHulls do
		gl.PushMatrix()

		gl.BeginEnd(GL.TRIANGLE_FAN, function()
									   for j = 1, #featureConvexHulls[i] do
										 gl.Vertex(featureConvexHulls[i][j].x, featureConvexHulls[i][j].y, featureConvexHulls[i][j].z)
									   end
									 end)

		gl.PopMatrix()
	end
end

local drawFeatureConvexHullEdgeList
local function DrawFeatureConvexHullEdge()
	gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
	for i = 1, #featureConvexHulls do
		gl.PushMatrix()

		gl.BeginEnd(GL.LINE_LOOP, function()
									   for j = 1, #featureConvexHulls[i] do
										 gl.Vertex(featureConvexHulls[i][j].x, featureConvexHulls[i][j].y, featureConvexHulls[i][j].z)
									   end
									 end)

		gl.PopMatrix()
	end
	gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
end

local checkFrequency = 30
local checkFrequencyBias = math.floor(checkFrequency / 2)

function widget:Update(dt)
	local cx, cy, cz = Spring.GetCameraPosition()

	local desc, w = Spring.TraceScreenRay(screenx / 2, screeny / 2, true)
	if desc then
		local cameraDist = math.min( 8000, math.sqrt( (cx-w[1])^2 + (cy-w[2])^2 + (cz-w[3])^2 ) )
		cameraScale = math.sqrt((cameraDist / 600)) --number is an "optimal" view distance
	else
		cameraScale = 1.0
	end

	for uId, info in pairs(idleList) do
		if info and info.flash then
			local x, y, z = Spring.GetUnitPosition(uId)

			local isIconDraw = Spring.IsUnitIcon(uId) or Spring.GetUnitIsCloaked(uId)
			info.isIconDraw = isIconDraw

			if isIconDraw then
				local cameraDist = math.min( 8000, math.sqrt( (cx-x)^2 + (cy-y)^2 + (cz-z)^2 ) )

				local scale = math.sqrt((cameraDist / 600)) --number is an "optimal" view distance
				--scale = math.min(scale, 2.5) --stop keeping icon size unchanged if zoomed out farther than "optimal" view distance

				local udid = Spring.GetUnitDefID(uId)
				local iconInfo = iconTypes[UnitDefs[udid].iconType]

				if iconInfo.radiusadjust then
					scale = scale * Spring.GetUnitRadius(uId) / 30.0
				end

				info.iconSize = iconInfo.size
				info.scale = scale
			end

			info.x, info.y, info.z = x, y, z

			idleList[uId] = info
		end
	end

	local frame=spGetGameFrame()
	color = 0.5 + 0.5 * (frame % checkFrequency - checkFrequency)/(checkFrequency - 1)
	if color < 0 then color = 0 end
	if color > 1 then color = 1 end

	if featuresUpdated or drawFeatureConvexHullSolidList == nil then
		if drawFeatureConvexHullSolidList then
			gl.DeleteList(drawFeatureConvexHullSolidList)
			drawFeatureConvexHullSolidList = nil
		end
		if drawFeatureConvexHullEdgeList then
			gl.DeleteList(drawFeatureConvexHullEdgeList)
			drawFeatureConvexHullEdgeList = nil
		end
		drawFeatureConvexHullSolidList = gl.CreateList(DrawFeatureConvexHullSolid)
		drawFeatureConvexHullEdgeList = gl.CreateList(DrawFeatureConvexHullEdge)
	end

end

local waitIdlePeriod= 2 * 30 --x times second(s)

function widget:GameFrame(frame)
	local frameMod = frame % checkFrequency
	if frameMod == checkFrequencyBias then
		flashIdleWorkers = false
		for uId, info in pairs(idleList) do
			if info and info.gameFrame and frame >= info.gameFrame + waitIdlePeriod then
				idleList[uId].flash = true
				flashIdleWorkers = true
			else
				idleList[uId].flash = false
			end
		end
		CheckAndSetFlashMetalExcess(frame)
	elseif frameMod == 0 then
		--Spring.Echo("SetEcoHighPriority")
		SetEcoHighPriority()

		UpdateFeatures(frame)
		--Spring.Echo("featuresUpdated", featuresUpdated)
		if featuresUpdated then
			ClusterizeFeatures(frame)
			ClustersToConvexHull()
		end
	end
end

function widget:ViewResize(viewSizeX, viewSizeY)
	screenx, screeny = widgetHandler:GetViewSizes()
end

local function DrawBigFlashingRect()
	gl.Translate(0, 0, 0)
	gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
	gl.Scale(1, 1, 1)
	gl.Rect(0, 0, screenx, screeny)
end

function widget:DrawScreen()
	if Spring.IsGUIHidden() or Spring.IsCheatingEnabled() then return end

	--rgba
	if flashMetalExcess or flashIdleWorkers or flashEnergyStall then
		--rgba
		gl.PushMatrix()
		gl.Color(ColorMul(color, flashColor))
		DrawBigFlashingRect()
		gl.PopMatrix()

		if flashMetalExcess then
			gl.PushMatrix()
			gl.Color(ColorMul(color, flashMetalTextColor))
			gl.Translate(screenx/2, 2*screeny/3-50, 0)
			gl.Scale(textScale[1], textScale[2], textScale[3])
			gl.Text("Metal Excess", 0, 0, 100, "cv")
			gl.PopMatrix()
		end

		if flashIdleWorkers then
			gl.PushMatrix()
			gl.Color(ColorMul(color, flashIdleTextColor))
			gl.Translate(screenx/2, 2*screeny/3, 0)
			gl.Scale(textScale[1], textScale[2], textScale[3])
			gl.Text("Idle Workers", 0, 0, 100, "cv")
			gl.PopMatrix()
		end

		if flashEnergyStall then
			gl.PushMatrix()
			gl.Color(ColorMul(color, flashEStallTextColor))
			gl.Translate(screenx/2, 2*screeny/3+50, 0)
			gl.Scale(textScale[1], textScale[2], textScale[3])
			gl.Text("Stalling Energy", 0, 0, 100, "cv")
			gl.PopMatrix()
		end
	end
end

function widget:DrawWorld()
	if Spring.IsGUIHidden() or Spring.IsCheatingEnabled() then return end
	for uId, info in pairs(idleList) do
		if info then
			if info.flash then
				gl.PushMatrix()
				if info.isIconDraw then
					gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
					gl.Translate(info.x, info.y, info.z)
					gl.Billboard()
					gl.Translate(0, 4 * info.iconSize * info.scale, 0)

					gl.Color(ColorMul(color, idleFillColor))
					local iconSideSize = info.iconSize * info.scale * 10
					gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
					gl.Rect(-iconSideSize, -iconSideSize, iconSideSize, iconSideSize)

					gl.Color(ColorMul(color, flashIdleTextColor))
					gl.LineWidth(9.0 / info.scale)
					gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
					gl.Rect(-iconSideSize, -iconSideSize, iconSideSize, iconSideSize)
					gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
					gl.LineWidth(1.0)
					--gl.Blending(false)
				else
					gl.Blending(GL.ONE, GL.ONE)
					gl.DepthTest(GL.LEQUAL)
					gl.PolygonOffset(-10, -10)
					gl.Culling(GL.BACK)
					gl.Color(ColorMul(color, idleModelColor))
					gl.Unit(uId, true)
					gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
					gl.Culling(false)
				end

				gl.PopMatrix()
			else
				----
			end

		end
	end

	gl.DepthTest(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	if drawFeatureConvexHullSolidList then
		gl.Color(ColorMul(color, reclaimColor))
		gl.CallList(drawFeatureConvexHullSolidList)
	end


	if drawFeatureConvexHullEdgeList then
		gl.LineWidth(6.0 / cameraScale)
		gl.Color(ColorMul(color, reclaimEdgeColor))
		gl.CallList(drawFeatureConvexHullEdgeList)
		gl.LineWidth(1.0)
	end
	gl.DepthTest(true)

end

function widget:Shutdown()
	for hash, heavenZone in pairs(heavenZones) do
		if heavenZone.thisWidget then
			Spring.SendLuaRulesMsg('sethaven|' .. heavenZone.x .. '|' .. 0 .. '|' .. heavenZone.z )
		end
	end
end
