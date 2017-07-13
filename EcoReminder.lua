VFS.Include("LuaUI/Widgets/MyUtils.lua")
VFS.Include("LuaRules/Configs/customcmds.h.lua")

local widgetName = "Eco Reminder"

function widget:GetInfo()
  return {
    name      = widgetName,
    desc      = "Reminds about various economic events",
    author    = "ivand",
    date      = "2015",
    license   = "public",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

local screenx, screeny
local myTeamID = Spring.GetMyTeamID()

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

--local WARNING_IMAGE = LUAUI_DIRNAME .. "Images/Crystal_Clear_app_error.png"
local WARNING_IMAGE = LUAUI_DIRNAME .. 'Images/idlecon.png'

function widget:Initialize()
	CheckSpecState(widgetName)
	curModID = string.upper(Game.modShortName or "")
	if ( curModID ~= "ZK" ) then
		widgetHandler:RemoveWidget()
		return
	end

	local iconDist = Spring.GetConfigInt("UnitIconDist")
	ePrintEx({iconDist=iconDist})

	screenx, screeny = widgetHandler:GetViewSizes()

	ToggleIdle()
end

function widget:Shutdown()

end

function widget:TeamChanged(teamID)
	myTeamID = Spring.GetMyTeamID()
end

function widget:PlayerChanged(playerID)
	myTeamID = Spring.GetMyTeamID()
end

function widget:PlayerAdded(playerID)
	myTeamID = Spring.GetMyTeamID()
end

function widget:PlayerRemoved(playerID)
	myTeamID = Spring.GetMyTeamID()
end

function widget:TeamDied(teamID)
	myTeamID = Spring.GetMyTeamID()
end

function widget:TeamChanged(teamID)
	myTeamID = Spring.GetMyTeamID()
end

local idleList={}

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID then
		local units=FilterMobileConstructors({unitID})
		local _, _, _, _, built = Spring.GetUnitHealth(unitID)
		if #units == 1 and built == 1.0 then
			local gameFrame = spGetGameFrame()
			idleList[unitID] = {}
			idleList[unitID].gameFrame = gameFrame
			--local dims = Spring.GetUnitDefDimensions(unitDefID)
			local uDef = UnitDefs[unitDefID]


			--idleList[unitID].radius = math.round( math.sqrt( (uDef.zsize or uDef.ysize)^2 + uDef.xsize^2 ) ) * 4
			local factor = 4 * 1.2
			factor = factor * (tonumber(uDef.customParams.selection_scale) or 1)

			--idleList[unitID].radius = dims.radius
			--idleList[unitID].radius = math.round( math.sqrt( uDef.zsize^2 + uDef.xsize^2 ) ) * factor
			idleList[unitID].radius = math.sqrt( 2 * math.max( uDef.zsize, uDef.xsize ) ^ 2 ) * factor
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
	ToggleIdleOne(unitID)
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	ToggleIdleOne(unitID)
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	ToggleIdleOne(unitID)
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if idleList[unitID] then
		idleList[unitID]=nil
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if idleList[unitID] then
		idleList[unitID]=nil
	end
end

local flashIdleWorkers=false
local flashMetalExcess=false
local gracePeriod=30*30 --first 30 seconds of the game
local magicNumber = 10000
local function CheckAndSetFlashMetalExcess(frame)
	if frame<gracePeriod then return end

	local mCurr, mStor, mPull, mInco, mExpe, mShar, mSent, mReci = spGetTeamResources(myTeamID, "metal")

	mStor = mStor - magicNumber

	local mStorageLeft=mStor-mCurr
	if mStorageLeft<0 then mStorageLeft=0 end

	local mProfit=mInco-mExpe+mReci-mSent

	if mProfit<0 then
		flashMetalExcess=false
		return
	else
		flashMetalExcess=mStorageLeft/mProfit<=10
	end
end

local checkFrequency=30
local checkFrequencyBias=30%math.floor(checkFrequency/2)
local waitIdlePeriod=2*30 --x times second(s)

function widget:GameFrame(frame)
	if frame%checkFrequency==checkFrequencyBias then
		flashIdleWorkers=false
		for uId, info in pairs(idleList) do
			--Echo("UnitID.."..uId.."storedFrame.."..storedFrame)
			if info and info.gameFrame and frame >= info.gameFrame + waitIdlePeriod then
				idleList[uId].flash = true
				flashIdleWorkers=true
				--Echo("flashIdleWorkers")
			else
				idleList[uId].flash = false
			end
		end
		CheckAndSetFlashMetalExcess(frame)
	end
end

local color

function widget:Update(dt)
	local cx, cy, cz = Spring.GetCameraPosition()

	for uId, info in pairs(idleList) do
		if info and info.flash then
			local x, y, z = Spring.GetUnitPosition(uId)

			local isIcon = Spring.IsUnitIcon(uId)
			info.isIcon = isIcon
			info.udid = Spring.GetUnitDefID(uId)

			if isIcon then
				local h = Spring.GetGroundHeight(x, z)
				y = math.max(y, h)
				local cameraDist = math.min( 8000, math.sqrt( (cx-x)^2 + (cy-y)^2 + (cz-z)^2 ) )

				local scale = math.sqrt((cameraDist / 600)) --number is an "optimal" view distance
				--scale = math.min(scale, 2.5) --stop keeping icon size unchanged if zoomed out farther than "optimal" view distance


				local iconInfo = iconTypes[UnitDefs[info.udid].iconType]

				if iconInfo.radiusadjust then
					scale = scale * Spring.GetUnitRadius(uId) / 30.0
				end
				y = math.max(y, h + scale)
				--y = y + Spring.GetUnitHeight(uId)
				info.iconSize = iconInfo.size
				info.scale = scale
			end

			info.x, info.y, info.z = x, y, z
			info.h = Spring.GetUnitHeight(uId)

			idleList[uId] = info
		end
	end

	local frame=spGetGameFrame()
	color = 0.5 + 0.5 * (frame % checkFrequency - checkFrequency)/(checkFrequency - 1)
	if color < 0 then color = 0 end
	if color > 1 then color = 1 end
end



--[[
function widget:Update(dt)
	for uId, info in pairs(idleList) do
		if info and info.flash then
			local x, y, z = Spring.GetUnitPosition(uId)

			local isIcon = Spring.IsUnitIcon(uId)
			info.isIcon = isIcon

			if isIcon then
				y = y + Spring.GetUnitHeight(uId) / 2
				info.radius = 32
			end

			info.x, info.y, info.z = x, y, z

			idleList[uId] = info
		end
	end

	local frame=spGetGameFrame()
	color = 0.5 + 0.5 * (frame % checkFrequency - checkFrequency)/(checkFrequency - 1)
	if color < 0 then color = 0 end
	if color > 1 then color = 1 end
end
]]--


function widget:ViewResize(viewSizeX, viewSizeY)
	screenx, screeny = widgetHandler:GetViewSizes()
end

local function DrawBigFlashingRect()
	gl.Translate(0, 0, 0)
--	gl.LineWidth(2)
	gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
	gl.Scale(1, 1, 1)
	gl.Rect(0, 0, screenx, screeny)
end

function widget:DrawScreen()
	if Spring.IsGUIHidden() or Spring.IsCheatingEnabled() then return end

	--rgba
	if flashMetalExcess or flashIdleWorkers then
		--rgba
		gl.PushMatrix()
		gl.Color(color, 0, 0, 0.2)
		DrawBigFlashingRect()
		gl.PopMatrix()

		if flashMetalExcess then
			gl.PushMatrix()
			gl.Color(color, 0, 0, 0.8)
			gl.Translate(screenx/2, 2*screeny/3, 0)
			gl.Scale(1, 0.5, 1)
			gl.Text("Metal Excess", 0, 0, 100, "cv")
			gl.PopMatrix()
		end

		if flashIdleWorkers then
			gl.PushMatrix()
			gl.Color(color, color, 0, 0.8)
			gl.Translate(screenx/2, 2*screeny/3-50, 0)
			gl.Scale(1, 0.5, 1)
			gl.Text("Idle Workers", 0, 0, 100, "cv")
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
--[[
				gl.LineWidth(9 / info.scale + color * 6 / info.scale)
				gl.Color(color, color, 0, 1)
				gl.DrawGroundCircle(info.x, 0, info.z, info.radius + color * 16, 32)
				--gl.DrawGroundCircle(info.x, 0, info.z, info.radius, 32)
				gl.Color(1, 1, 1, 1)
]]--
				if info.isIcon then
					--gl.Blending(GL.ONE, GL.Z)
					gl.Translate(info.x, info.y, info.z)
					gl.Billboard()
					--gl.Rotate(270, 1, 0, 0)
					gl.Translate(0, 4 * info.iconSize * info.scale, 0)

					gl.Color(color, color, 0, 0.4)
					--gl.Texture(WARNING_IMAGE)
					--local iconSideSize = info.iconSize * info.scale * 6
					local iconSideSize = info.iconSize * info.scale * 10
					gl.PolygonMode(GL.FRONT, GL.FILL)
					gl.Rect(-iconSideSize, -iconSideSize, iconSideSize, iconSideSize)

					gl.Color(color, color, 0, 0.8)
					gl.LineWidth(9.0/info.scale)
					gl.PolygonMode(GL.FRONT, GL.LINE)
					gl.Rect(-iconSideSize, -iconSideSize, iconSideSize, iconSideSize)
					gl.LineWidth(1.0)

					--gl.TexRect(-iconSideSize, -iconSideSize, iconSideSize, iconSideSize)
					--gl.Texture(false)
				else
					gl.Blending(GL.ONE, GL.ONE)
					gl.DepthTest(GL.LEQUAL)
					gl.PolygonOffset(-10, -10)
					gl.Culling(GL.BACK)
					gl.Color(color, color, 0, 1)
					gl.Unit(uId, true)
				end

				gl.PopMatrix()
			else
				----
			end

		end
	end
end