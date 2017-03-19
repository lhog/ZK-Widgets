VFS.Include("LuaUI/Widgets/MyUtils.lua")
VFS.Include("LuaRules/Configs/customcmds.h.lua")

local widgetName = "Eco Reminder"

function widget:GetInfo()
  return {
    name      = widgetName,
    desc      = "Reminds about various economic events",
    author    = "ivand",
    date      = "2015",
    license   = "private",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

local screenx, screeny

local function ToggleIdleOne(uId)
	local commandQueueTable=spGetCommandQueue(uId)
	--if not(commandQueueTable) or #commandQueueTable==0 then
	--Echo("#commandQueueTable"..#commandQueueTable)
	if #commandQueueTable==0 then
		local unitDefId=spGetUnitDefID(uId)
		widget:UnitIdle(uId, unitDefId, myTeamId)
	end
end

local function ToggleIdle()
	local units=spGetTeamUnits(myTeamId)
	for _, uId in pairs(units) do
		ToggleIdleOne(uId)
	end
end

function widget:Initialize()
	CheckSpecState(widgetName)
	curModID = string.upper(Game.modShortName or "")
	if ( curModID ~= "ZK" ) then
		widgetHandler:RemoveWidget()
		return
	end

	screenx, screeny = widgetHandler:GetViewSizes()	
	ToggleIdle()
end

local idleList={}

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamId then
		local units=FilterMobileConstructors({unitID})
		if #units==1 then
			local gameFrame = spGetGameFrame()
			idleList[unitID]=gameFrame
			--local x, _, z = spGetUnitPosition(unitID)
			--spMarkerAddPoint(x, 0, z, "", true)
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

local stateCommands = {	-- FIXME: is there a better way of doing this?
	[CMD_WANT_CLOAK] = true,	-- this is the only one that's really needed, since it can occur without user input (when a temporarily decloaked unit recloaks)
	[CMD.FIRE_STATE] = true,
	[CMD.MOVE_STATE] = true,
	[CMD.CLOAK] = true,
	[CMD.ONOFF] = true,
	[CMD.REPEAT] = true,
	[CMD.TRAJECTORY] = true,
	[CMD.IDLEMODE] = true,
	[CMD.AUTOREPAIRLEVEL] = true,
	[CMD.LOOPBACKATTACK] = true,
	[CMD.SET_WANTED_MAX_SPEED] = true,
	[CMD_PRIORITY] = true
}

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	--if idleList[unitID] and	(cmdID<0 or idleCancelCommands[cmdID]) then		
	if idleList[unitID] and	(cmdID<0 or stateCommands[cmdID]==nil) then		
		idleList[unitID]=nil
	end
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
	
	local mCurr, mStor, mPull, mInco, mExpe, mShar, mSent, mReci = spGetTeamResources(myTeamId, "metal")
	
	mStor = mStor - magicNumber
	--ePrintEx({ mCurr=mCurr, mStor=mStor, mPull=mPull, mInco=mInco, mExpe=mExpe, mShar=mShar, mSent=mSent, mReci=mReci})
	
	local mStorageLeft=mStor-mCurr
	if mStorageLeft<0 then mStorageLeft=0 end
	
	local mProfit=mInco-mExpe+mReci-mSent
	
	--Echo("mProfit.."..mProfit)
	
	if mProfit<0 then
		flashMetalExcess=false
		return
	else
		--flash metal excess if metal will overflow in 10 seconds
		flashMetalExcess=mStorageLeft/mProfit<=10
	end
	
	
	--flashMetalExcess=mCurr >= mStor * 0.8
end

local checkFrequency=30
local checkFrequencyBias=30%math.floor(checkFrequency/2)
local waitIdlePeriod=2*30 --x times second(s)

function widget:GameFrame(frame)	
	if frame%checkFrequency==checkFrequencyBias then
		flashIdleWorkers=false
		for uId, storedFrame in pairs(idleList) do			
			--Echo("UnitID.."..uId.."storedFrame.."..storedFrame)
			if storedFrame and frame>=storedFrame+waitIdlePeriod then
				flashIdleWorkers=true
				--Echo("flashIdleWorkers")				
				break
			end
		end
		CheckAndSetFlashMetalExcess(frame)
	end
end

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
	if Spring.IsGUIHidden() then return end

	--rgba
	if flashMetalExcess or flashIdleWorkers then
		gl.PushMatrix()
		
		local frame=spGetGameFrame()
		local color=0.5+0.5*(frame%checkFrequency - checkFrequency)/(checkFrequency-1)
		if color<0 then color=0 end
		if color>1 then color=1 end
		--Echo("red="..red)
		--local red=0.5
		
		--rgba
		gl.Color(color, 0, 0, 0.2)
		DrawBigFlashingRect()	
		
		
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
		
		
		gl.PopMatrix()
	end
end