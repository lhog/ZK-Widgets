include('keysym.h.lua')
VFS.Include("LuaUI/Widgets/MyUtils.lua")
VFS.Include("LuaRules/Configs/customcmds.h.lua")
-- to be located <spring_home>/LuaUI/Widgets
----------------------------------------------------------------
-- global variables
----------------------------------------------------------------

local terraformQueue={}
local timeQueue={}
local terraformWall={}

local moveStopQueue={}
local terraformHieghtAccumulator={}



----------------------------------------------------------------
-- callins
----------------------------------------------------------------
local widgetName="Terraform automation v2"

function widget:GetInfo()
  return {
    name      = widgetName,
    desc      = "Automates terraform in certain situations",
    author    = "ivand",
    date      = "2017",
    license   = "Personal, non-public use",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

local terraCommandNotifyMex

function widget:Initialize()
	CheckSpecState(widgetName)
	local curModID = string.upper(Game.modShortName or "")
	if not( curModID == "ZK" or curModID == "ZKE" ) then
		widgetHandler:RemoveWidget()
		return
	end
	--widgetHandler:RegisterGlobal("CommandNotifyMex", terraCommandNotifyMex)
--	WG.GlobalBuildCommand = {}
--	WG.GlobalBuildCommand.CommandNotifyMex = terraCommandNotifyMex
end

function widget:Shutdown()
	--widgetHandler:DeregisterGlobal('CommandNotifyMex')
--	WG.GlobalBuildCommand = nil
end

--
-- 18 height wall blocks bots
-- 8 height wall blocks vehicles

---=== units to terrorm ===---
local unitsToWall={}

-- wte - thickness of the edge of the terraform wall on the very top
--unitsToWall[-cormex.id]={wte=16, h=50}
unitsToWall[-fusion.id]={wte=32}
unitsToWall[-singu.id]={wte=32, h=120}
unitsToWall[-geo.id]={wte=32, h=60}
unitsToWall[-caretaker.id]={h=44}
unitsToWall[-silo.id]={h=70}
unitsToWall[-silencer.id]={wte=32}
unitsToWall[-protector.id]={wte=32}
unitsToWall[-advRadar.id]={wte=8, h=75}
unitsToWall[-pylon.id]={wte=16}
unitsToWall[-gsfac.id]={}
unitsToWall[-airfac.id]={}
unitsToWall[-spiderfac.id]={}
unitsToWall[-sonar.id]={wte=8}
unitsToWall[-aegis.id]={h=40}
unitsToWall[-storage.id]={}

local unitsToRaise={}
unitsToRaise[-stardust.id]={h=150}
unitsToRaise[-newton.id]={h=90}
unitsToRaise[-faraday.id]={h=90}
unitsToRaise[-razor.id]={h=30}
unitsToRaise[-cobra.id]={h=20}
unitsToRaise[-screamer.id]={h=75}
unitsToRaise[-chainsaw.id]={h=75}
unitsToRaise[-anni.id]={h=30}
unitsToRaise[-llt.id]={h=75}
unitsToRaise[-defender.id]={h=75}
unitsToRaise[-hlt.id]={h=20}
unitsToRaise[-ddm.id]={h=100}
unitsToRaise[-behemoth.id]={h=100}
unitsToRaise[-gauss.id]={h=150}
unitsToRaise[-urchin.id]={h=5}

local unitsToLower={}
--unitsToLower[-faraday.id]={h=-56}
--unitsToLower[-gauss.id]={h=-30}
---=== units to terraform ===---

local function GetTerraParameters(terraType, points, constructors, teamID, volumeSelection)
	local terraParams = {}

	local commandTag = WG.Terraform_GetNextTag()
	local pointAveX = 0
	local pointAveZ = 0

	for i = 1, #points do
		pointAveX = pointAveX + points[i].x
		pointAveZ = pointAveZ + points[i].z
	end
	pointAveX = pointAveX/#points
	pointAveZ = pointAveZ/#points

	local height = spGetGroundHeight(pointAveX, pointAveZ)

	--terraParams[1] = terraform_type -- 1 = level, 2 = raise, 3 = smooth, 4 = ramp, 5 = restore
	terraParams[1] = terraType
	--terraParams[2] = team -- teamID of the team doing the terraform
	terraParams[2] = teamID
	--terraParams[3] = loop -- true or false

	terraParams[3] = pointAveX
	terraParams[4] = pointAveZ

	terraParams[5] = commandTag

	terraParams[6] = 1 --need to be closed

	terraParams[7] = points[1].y --height

	terraParams[8] = #points -- how many points there are in the lasso (2 for ramp)
	terraParams[9] = #constructors -- how many constructors are working on it

	--terraParams[7] = volumeSelection -- 0 = none, 1 = only raise, 2 = only lower
	terraParams[10] = volumeSelection


	local i = 11
	for j = 1, #points do
		terraParams[i] = points[j].x
		terraParams[i + 1] = points[j].z
		i = i + 2
	end

	--i = i + 2
	for j = 1, #constructors do
		terraParams[i] = constructors[j]
		i = i + 1
	end

	local levelParams = {pointAveX, height, pointAveZ, commandTag}

	return terraParams, levelParams
end

local function GetTerraRectByParams(bx1, bz1, bw1, bh1, liftHeight, woff, hoff)
		local rect={
			{x=bx1-bw1-woff, y=math.round(liftHeight), z=bz1-bh1-hoff},
			{x=bx1-bw1-woff, y=math.round(liftHeight), z=bz1+bh1+hoff-1},
			{x=bx1+bw1+woff-1, y=math.round(liftHeight), z=bz1+bh1+hoff-1},
			{x=bx1+bw1+woff-1, y=math.round(liftHeight), z=bz1-bh1-hoff}
		}
		rect[5]=rect[1]

		return rect
end

local function GetTerraRectByUDId(udId, bx1, bz1, facing, unitHeight, wwte, hwte)
	if udId and IsBuildingbyUdID(udId) then
		local by1 = spGetGroundHeight(bx1, bz1)

		local floater=UnitDefs[udId].floatOnWater

		local bw1, bh1 = GetBuildingDimensions(udId, facing)

		if unitHeight==nil then unitHeight=spGetUnitDefDimensions(udId).height end

		local liftHeight=by1+unitHeight
		if by1<0 then --for underwater stuff
			if floater then
				liftHeight=5+unitHeight --lift wall above waterline
			else
				liftHeight=math.max(by1+unitHeight, 30) --lift wall min 30 points above waterline or to model's height
			end
		end

		local woff=0
		local hoff=0

		local liftHeightRel=liftHeight-by1
		--every 30 elmo of height deform next block of 8 elmo width ground

		if wwte>0 then --autodetect needed wall thickness around the base
			woff=wwte+math.ceil(liftHeightRel/30)*8
		end

		if hwte>0 then --autodetect needed wall thickness around the base
			hoff=hwte+math.ceil(liftHeightRel/30)*8
		end

		return GetTerraRectByParams(bx1, bz1, bw1, bh1, liftHeight, woff, hoff)
	end

	return nil
end

local keyPressed=false
local lastKPFrame=nil
local keySpeed=20 --handle KeyPress event once in keySpeed frames
function widget:KeyPress(key, mods, isRepeat)
	if mods.ctrl then
		local dir=nil
		if key==KEYSYMS.KP8 then
			dir=1	--up
		elseif key==KEYSYMS.KP2 then
			dir=-1	--down
		elseif key==KEYSYMS.KP0 then
			dir=0	--restore
		end

		if dir~=nil then
			local frame=spGetGameFrame()
			if isRepeat and lastKPFrame and frame-lastKPFrame<keySpeed then return end --skip some keypresses

			lastKPFrame=frame
			keyPressed=true
			--Echo("widget:KeyPress KeyPressed")
			local height=80 --tune me

			local addition

			if dir==1 or dir==-1 then
				addition=dir*height
			else --0
				addition=math.huge --restore
			end

			local selUnits=spGetSelectedUnits()
			for _, uId in pairs(selUnits) do
				if spValidUnitID(uId) and IsBuildingbyUID(uId)==false then --valid and we don't care about buildings
					if terraformHieghtAccumulator[uId] then
						terraformHieghtAccumulator[uId]=terraformHieghtAccumulator[uId]+addition
					else
						terraformHieghtAccumulator[uId]=addition
					end
				end
			end
		end

	end
end

local function DoMobileUnitLiftPrepare(uId, relHeight, aroundConses)
	if spValidUnitID(uId) then
		if relHeight~=math.huge and relHeight~=0 then
			local udId=spGetUnitDefID(uId)
			local x,_,z =spGetUnitPosition(uId)
			local y = spGetGroundHeight(x, z)
			local bDef = UnitDefs[udId]

			local size=8

			local height=y+relHeight
			local rect=GetTerraRectByParams(x, z, size, size, height, 0, 0)
			local volumeSelection=1
			if relHeight<0 then volumeSelection=2 end --1 if raise, 2 if lower
			--volumeSelection=0

			local terraParams, levelParams=GetTerraParameters(1, rect, aroundConses, myTeamId, volumeSelection)
			local cq=spGetCommandQueue(uId)
			local vx, vy, vz=spGetUnitVelocity(uId)

			local vabs2=vx*vx+vz*vz

			if #cq==0 and vabs2==0 then --unit is idle and its velocity is zero. Another words standing still.
				return "ready", {terraParams=terraParams, levelParams=levelParams}
			else --unit is rather busy or moving still
				return "notready", {relHeight=relHeight}
			end
		elseif relHeight==math.huge then --handle restore ground task
			local x,_,z =spGetUnitPosition(uId)
			local ratio=30/8 --tune me?
			local heightTolerance=10 --tune me?
			local y = spGetGroundHeight(x, z)
			local y0 = spGetGroundOrigHeight(x, z)
			local dy = math.abs(y0-y)
			Spring.Echo("dy=",dy)
			if dy>heightTolerance then
				local size=2*dy/ratio
				local rect=GetTerraRectByParams(x, z, size, size, 0, 0, 0)
				local volumeSelection=0
				local terraParams, levelParams=GetTerraParameters(5, rect, aroundConses, myTeamId, volumeSelection) --restore
				local cq=spGetCommandQueue(uId)
				local vx, vy, vz=spGetUnitVelocity(uId)
				--local vabs2=vx*vx+vy*vy+vz*vz
				local vabs2=vx*vx+vz*vz

				if #cq==0 and vabs2==0 then --unit is idle and its velocity is zero. Another words standing still.
					return "ready", {terraParams=terraParams, levelParams=levelParams}
				else --unit is rather busy or moving still
					return "notready", {relHeight=math.huge}
				end
			end
		end
	end
	return nil
end


function widget:KeyRelease(key)
	if keyPressed then
		local radius=600 --tune me
		--Echo("widget:KeyRelease KeyPressed")
		for uId, height in pairs(terraformHieghtAccumulator) do
			if height~=0 then
				local x,_,z =spGetUnitPosition(uId)

				local aroundUnits=spGetUnitsInCylinder(x, z, radius, myTeamId)
				local aroundConses=FilterMobileConstructors(aroundUnits)

				local state, params=DoMobileUnitLiftPrepare(uId, height, aroundConses)

				--ePrintEx({state, params})

				if #aroundConses>0 then
					if state=="ready" then
						spGiveOrderToUnit(aroundConses[1], CMD_TERRAFORM_INTERNAL, params.terraParams, {"shift"})
						spGiveOrderToUnitArray(aroundConses, CMD_LEVEL, params.levelParams, {"shift"})
					elseif state=="notready" then
						moveStopQueue[uId]={relHeight=params.relHeight, conses=aroundConses}
						spGiveOrderToUnit(uId, CMD.STOP, {}, {}) --stopping selected unit
					end
				end
				terraformHieghtAccumulator[uId]=nil --relative height is dropped after the key is released
			end
		end
		keyPressed=false
	end
end

local function DrawTerraformElevation(yoffset ,elevation)
	gl.Translate(0, yoffset,0)
	gl.Billboard()
	gl.Translate(0, 10 ,0)

	local elevstr
	if elevation==math.huge then elevstr="restore"
	elseif elevation==0 then elevstr=""
	elseif elevation<0 then elevstr=tostring(elevation)
	elseif elevation>0 then elevstr="+"..tostring(elevation)
	end

	gl.Text(elevstr, 0, 0, 20, "cvo")
end

function widget:DrawWorld()
	if Spring.IsGUIHidden() then return end
	gl.DepthTest(true)

	gl.Color(1, 1, 1)
	for uId, height in pairs(terraformHieghtAccumulator) do
		local udId=spGetUnitDefID(uId)
		unitHeight=spGetUnitDefDimensions(udId).height
		gl.DrawFuncAtUnit(uId, false, DrawTerraformElevation, unitHeight+15, height)
	end

	gl.DepthTest(false)
end

terraCommandNotifyMex = function(id, params, options, isAreaMex)
	params[2]=spGetGroundHeight(params[1], params[3])
	return widget:CommandNotify(id, params, options)
end

local wallLastFrame=-1
local wallDeltaFrameMult=1

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	--Echo("widget:CommandNotify(id, params, cmdOptions)")
	local selUnits=spGetSelectedUnits()
	local unitIds=FilterConstructors(selUnits)

	if unitsToWall[cmdID] and cmdOptions.ctrl then
		local params=unitsToWall[cmdID]

		local height=nil
		if params.h~=nil then height=params.h end
		local wte=8 --tuneme
		if params.wte~=nil then wte=params.wte end

		local x, z, facing=cmdParams[1], cmdParams[3], cmdParams[4]

		local rect=GetTerraRectByUDId(-cmdID, x, z, facing, height, wte, wte)

		if #unitIds>0 then
			--ePrintCMD({id=cmdID, params=cmdParams, options=cmdOptions})
			local frame=spGetGameFrame()
			if wallLastFrame~=frame then
				wallLastFrame=frame
				wallDeltaFrameMult=1
			else
				wallDeltaFrameMult=wallDeltaFrameMult+1
			end

			local adjOptions=cmdOptions.coded
			if wallDeltaFrameMult>1 then --first command in the series
				adjOptions=math.bit_or(adjOptions, CMD.OPT_SHIFT)
			end

			--Echo("Adding walledconstruction")
			table.insert(timeQueue,{type="walledconstruction", frame=frame+5*wallDeltaFrameMult, unitIds=unitIds, cmdID=cmdID, cmdParams=cmdParams, cmdOptions=adjOptions, rect=rect})

			--spGiveOrderToUnitArray(unitIds, cmdID, cmdParams, cmdOptions.coded)
			--Echo("unitsToWall[cmdID]")
			--spGiveOrderToUnitArray(unitIds, cmdID, cmdParams, CMD.OPT_SHIFT)
			--spGiveOrderToUnit(unitIds[1], CMD_TERRAFORM_INTERNAL, restParams, CMD.OPT_SHIFT)
			return true --cancel command
		end

	elseif unitsToRaise[cmdID] and cmdOptions.ctrl then
		local x,z=cmdParams[1], cmdParams[3]
		local facing=cmdParams[4]
		local relHeight=unitsToRaise[cmdID].h
		local rect=GetTerraRectByUDId(-cmdID, x, z, facing, relHeight, 0, 0)
		local terraParams, levelParams=GetTerraParameters(1, rect, unitIds, myTeamId, 1)

		--spGiveOrderToUnitArray(unitIds, CMD_TERRAFORM_INTERNAL, restParams, cmdOptions.coded)
		if #unitIds>0 then
			spGiveOrderToUnit(unitIds[1], CMD_TERRAFORM_INTERNAL, terraParams, {"shift"})
			spGiveOrderToUnitArray(unitIds, CMD_LEVEL, levelParams, cmdOptions.coded)
			local hash=z+x*mapSizeZ
			terraformQueue[hash]={cmdParams=cmdParams, h=rect[1].y, cmdID=cmdID ,conses=unitIds} --coordinates, desired height, what to build, constructors array
			return true --cancel command
		end
	elseif unitsToLower[cmdID] and cmdOptions.ctrl then
		local x,z=cmdParams[1], cmdParams[3]
		local facing=cmdParams[4]
		local relHeight=unitsToLower[cmdID].h
		local rect=GetTerraRectByUDId(-cmdID, x, z, facing, relHeight, 0, 0)
		local terraParams, levelParams=GetTerraParameters(1, rect, unitIds, myTeamId, 2)

		--spGiveOrderToUnitArray(unitIds, CMD_TERRAFORM_INTERNAL, restParams, cmdOptions.coded)
		if #unitIds>0 then
			spGiveOrderToUnit(unitIds[1], CMD_TERRAFORM_INTERNAL, terraParams, {"shift"})
			spGiveOrderToUnitArray(unitIds, CMD_LEVEL, levelParams, cmdOptions.coded)
			local hash=z+x*mapSizeZ
			terraformQueue[hash]={cmdParams=cmdParams, h=rect[1].y, cmdID=cmdID ,conses=unitIds} --coordinates, desired height, what to build, constructors array
			return true --cancel command
		end
	end
	return false
end


local function ProcessTerraformQueue()
	for hash, params in pairs(terraformQueue) do
		local x, z=params.cmdParams[1], params.cmdParams[3]
		local y = spGetGroundHeight(x, z) --checking height
		--ePrintEx({grHeight=y, desHeight=params.h})
		if y==params.h then--height is exactly as desired here
			local conses=FilterConstructors(params.conses) --in case someone is invalid already
			spGiveOrderToUnitArray(conses, params.cmdID, params.cmdParams, {"shift"})
			terraformQueue[hash]=nil --clear hash entry
		end
	end
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdTag, cmdParams, cmdOpts)
	if cmdID==CMD.STOP and unitTeam==myTeamId and moveStopQueue[unitID] then
		--we have a unit what is still moving but recieved stop command. Give it 2 cycles to stop
		local params=moveStopQueue[unitID]
		--Echo("forming timeQueue for CMD.STOP")
		local frame=spGetGameFrame()
		table.insert(timeQueue,{type="move", frame=frame+15, uId=unitID, relHeight=params.relHeight, conses=params.conses})  --half second?
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if unitTeam==myTeamId then
		if unitsToWall[-unitDefID] then
			local x, _, z=spGetUnitPosition(unitID)
			local hash=z+x*mapSizeZ
			local value=terraformWall[hash]

			if value then
				local terraParams, levelParams =GetTerraParameters(1, value.someParams.rect, value.unitIds, myTeamId, value.someParams.volumeSelection)
				spGiveOrderToUnit(value.unitIds[1], CMD_TERRAFORM_INTERNAL, terraParams, {"shift"})
				spGiveOrderToUnitArray(value.unitIds, CMD_LEVEL, levelParams, {"shift"})
				terraformWall[hash]=nil
			end
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam==myTeamId then
		if unitDefID==terraunit.id then
			--Echo("Terraunit created")
			table.insert(timeQueue,{type="construction", frame=spGetGameFrame()+30}) --one seconds?
		end
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if unitTeam==myTeamId then
		if unitsToWall[-unitDefID] then
			local x, _, z = spGetUnitPosition(unitID)
			local hash=z+x*mapSizeZ
			if terraformWall[hash] then terraformWall[hash]=nil end
		end
	end
end

function widget:GameFrame(thisFrame)
	--Echo("GameFrame="..thisFrame)
	if (thisFrame % 5 == 0) then
		for tid, params in pairs(timeQueue) do
			local frame=params.frame
			if thisFrame-frame>9000 then --5 min time safeguard
				timeQueue[tid]=nil
			else
				if thisFrame>=frame then --time has come
					if params.type=="walledconstruction" then --types
						local conses=FilterConstructors(params.unitIds)
						if #conses>0 then
							spGiveOrderToUnitArray(conses, params.cmdID, params.cmdParams, params.cmdOptions)
							local restParams=GetTerraParameters(1, params.rect, conses, myTeamId, 1)
							spGiveOrderToUnit(conses[1], CMD_TERRAFORM_INTERNAL, restParams, CMD.OPT_SHIFT)
						end
						timeQueue[tid]=nil
					elseif params.type=="construction" then --types
						ProcessTerraformQueue()
						timeQueue[tid]=nil
					elseif params.type=="move" then --types
						local relHeight=params.relHeight
						local uId=params.uId
						local conses=FilterConstructors(params.conses)
						local state, params=DoMobileUnitLiftPrepare(uId, relHeight, conses)
						if state=="ready" then
							if #conses>0 then
								spGiveOrderToUnit(conses[1], CMD_TERRAFORM_INTERNAL, params.terraParams, {"shift"})
								spGiveOrderToUnitArray(conses, CMD_LEVEL, params.levelParams, {"shift"})
							end
						end
						timeQueue[tid]=nil
					else --other types we safely delete
						timeQueue[tid]=nil
					end
				end
			end
		end
	end
end