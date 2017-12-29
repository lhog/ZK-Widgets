function widget:GetInfo()
  local version = "Iteration 6"
  local versionnotes = "- newtons now take target collision imminent into effect when determining when to drop the target. Simulates half a second.\n-Newtons also take into consideration if they have line of fire."
  return {
      name      = "Newton AI " .. version,
      desc      = "Causes newton spires to become ungodly annoying.\n\n" .. versionnotes,
      author    = "_Shaman",
      date      = "7-30-2016",
      license   = "Death to nonbelievers v92",
      layer     = 32,
      enabled   = true,
    }
end
local frametime = 1/30
local HighPriority = {}
local mynewtons = {}
local AlwaysAttract = {}
local AlwaysRepel = {}
local targetslastvel = {}
local targetsnotchanging = {}


local GraviUnits={
	[1] = UnitDefNames["jumpsumo"].id,
	[2] = UnitDefNames["turretimpulse"].id,
}

local GraviUnitsTruth = {}
for i = 1, #GraviUnits do
	GraviUnitsTruth[ GraviUnits[i] ] = true
end

local function round2(num, idp)
  return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

local function getDragAccelerationVec(vx, vy, vz, mass, radius)
    local airDensity = 1.2/4
    local dragCoefficient = 1.0
 
    local sx = vx <= 0 and -1 or 1
    local sy = vy <= 0 and -1 or 1
    local sz = vz <= 0 and -1 or 1
 
    local dragScale = 0.5 * airDensity * dragCoefficient * (math.pi * radius * radius * 0.01 * 0.01)
 
    return
        math.clamp((vx * vx * dragScale * -sx) / mass, -math.abs(vx), math.abs(vx)),
        math.clamp((vy * vy * dragScale * -sy) / mass, -math.abs(vy), math.abs(vy)),
        math.clamp((vz * vz * dragScale * -sz) / mass, -math.abs(vz), math.abs(vz));
end

local function GetLowestNumber(list)
  local lowest = 9999999999999999
  local lowestid = 0
  for i=1,#list do
    if list[i] < lowest then
      lowestid = i
      lowest = list[i]
    end
  end
  return lowestid
end
--CMD.ONOFF
local function TurnOn(newtonid)
  local states = Spring.GetUnitStates(newtonid)
  if states["active"] == false then
    mynewtons[newtonid].wantedstate = true
    Spring.GiveOrderToUnit(newtonid,CMD.ONOFF,{1},0)
  end
end

local function TurnOff(newtonid)
  local states = Spring.GetUnitStates(newtonid)
  if states["active"] == true then
    mynewtons[newtonid].wantedstate = false
    Spring.GiveOrderToUnit(newtonid,CMD.ONOFF,{0},0)
  end
end

local function DistanceFormula(x1,y1,x2,y2) -- 2 dimensional distance formula
  if x1 == nil or y1 == nil or x2 == nil or y2 == nil then
    return nil
  else
    return math.sqrt((x1-x2)^2+(y1-y2)^2)
  end
end

local function WillUnitHitMe(newtonid,unitid) -- tests if a unit will hit the newton within 5 frames. Assumes velocity remains the same (as if we dropped the target)
  local x,y,z = Spring.GetUnitPosition(newtonid)
  local x2,y2,z2 = Spring.GetUnitPosition(unitid)
  local vx,vy,vz = Spring.GetUnitVelocity(unitid)
  local gravityeffect = Game.gravity/30/-30
  local terrainheight = 0
  local dragx,dragy,dragz = 0
  local dir = {}
  dir[1],dir[2],dir[3] = Spring.GetUnitDirection(unitid)
  local prediction = {}
  local midposx,midposy,midposz = Spring.GetUnitPosition(newtonid,true) -- middle of the colvol?
  local predictedx,predictedy,predictedz = 0
  predictedx = x2
  predictedy = y2
  predictedz = z2
  terrainheight = Spring.GetGroundHeight(x2,z2)
  for i=1,25 do
    if vy > 0 and predictedy > terrainheight then
      vy = vy + gravityeffect
      dragx,dragy,dragz = getDragAccelerationVec(vx,vy,vz,Spring.GetUnitMass(unitid),Spring.GetUnitRadius(unitid))
      predictedx = predictedx+vx+dragx
      predictedy = predictedy+vy+dragy
      predictedz = predictedz+vz+dragz
      terrainheight = Spring.GetGroundHeight(predictedx,predictedz)
      if predictedy <= terrainheight then
        vy = 0
      end
    else
      predictedx = predictedx+vx
      predictedz = predictedz+vz
    end
    if math.abs(DistanceFormula(midposx,predictedx,midposz,predictedz)) <= 115 and math.abs(predictedy-midposy) <= 115 then
      return true
    end
  end
  return false
end

local function IsAirborne(unitid)
  local x,y,z = Spring.GetUnitPosition(unitid)
  local ground = Spring.GetGroundHeight(x,z)
  local vx,vy,vz = Spring.GetUnitVelocity(unitid)
  local neededvel = Spring.GetUnitMass(unitid)*0.00675
  --Spring.Echo(vy .. " ? " .. neededvel)
  if vy > neededvel or y-ground > 10 then
    x,y,z,ground,vx,vy,vz,needevel = nil
    return true
  else
    x,y,z,ground,vx,vy,vz,needevel = nil
    return false
  end
end

local function ProcessTargets(targetlist,newtonid)
  list = {}
  local x,y,z = 0
  local x2,y2,z2 = Spring.GetUnitPosition(newtonid)
  local distancemod,distance,wantedvelocity,currentvelocity = 0
  if targetlist and #targetlist > 1 then
    for i=1,#targetlist do
      _,currentvelocity,_ = Spring.GetUnitVelocity(targetlist[i])
      x,y,z = Spring.GetUnitPosition(targetlist[i])
      distancemod = DistanceFormula(x,z,x2,z2)/460
      wantedvelocity = Spring.GetUnitMass(targetlist[i])*0.00675
      if currentvelocity == 0 then
        currentvelocity = 0.01
      end
      list[i] = Spring.GetUnitMass(targetlist[i])*distancemod*math.abs(currentvelocity/wantedvelocity)
    end
  end
  distancemod,x,y,z,x2,y2,z2,currentvelocity,wantedvelocity,distancemod,distance = nil
  return list
end

local function TrackTarget(newtonid,targetid)
  if Spring.ValidUnitID(targetid) then
    local healthremaining,_ = Spring.GetUnitHealth(targetid)
    local queue = Spring.GetCommandQueue(newtonid,1)
    local states = Spring.GetUnitStates(newtonid)
    if not queue[1] or queue[1]["id"] ~= CMD.ATTACK or queue[1]["params"][1] ~= targetid then--not attacking, reissue the comamnd.
      Spring.GiveOrderToUnit(newtonid,CMD.ATTACK,{targetid},0)
    end
    if states["active"] ~= mynewtons[newtonid].wantedstate then
      Spring.GiveOrderToUnit(newtonid,CMD.STOP,{},0)
    end
    local x,y,z = Spring.GetUnitPosition(targetid)
    local x2,y2,z2 = Spring.GetUnitPosition(newtonid)
    local distance = DistanceFormula(x,z,x2,z2)
    if UnitDefs[Spring.GetUnitDefID(targetid)].isGroundUnit then
      local willhit = WillUnitHitMe(newtonid,targetid)
    else
      local willhit = false
    end
    --Spring.Echo("target is " .. distance .. " away")
    if distance >= 459 or healthremaining <= 0 or x == nil or y == nil or z == nil then
      mynewtons[newtonid]["target"] = nil
      TurnOff(newtonid)
      Spring.GiveOrderToUnit(newtonid,CMD.STOP,{shift = true},0)
    elseif willhit then
      TurnOn(newtonid)
    elseif (IsAirborne(targetid) or (distance <= 200 and not IsAirborne(targetid))) and mynewtons[newtonid]["numtargs"] == 1 and not AlwaysAttract[Spring.GetUnitDefID(targetid)] then
      TurnOn(newtonid)
    elseif distance >= 200 and not IsAirborne(targetid) and not willhit then
      TurnOff(newtonid)
    end
  elseif Spring.ValidUnitID(targetid) and AlwaysRepel[Spring.GetUnitDefID(targetid)] then
    TurnOn(newtonid)
  elseif Spring.ValidUnitID(targetid) and AlwaysAttract[Spring.GetUnitDefID(targetid)] then
    TurnOff(newtonid)
  elseif not Spring.ValidUnitID(targetid) or not Spring.GetUnitWeaponHaveFreeLineOfFire(newtonid,1,targetid) then
    mynewtons[newtonid]["target"] = nil
  end
end

local function SelectTarget(newtonid)
  local x,y,z = Spring.GetUnitPosition(newtonid)
  local units = Spring.GetUnitsInCylinder(x,z,441)
  local unitsproc = {}
  if #units == 0 or not units then
    unitsproc,units,x,y,z = nil
    return
  end
  local healthremaining,finished
  for i=1,#units do -- First pass
    if Spring.ValidUnitID(units[i]) then
      healthremaining,_,_,_,finished = Spring.GetUnitHealth(units[i])
      if Spring.GetUnitAllyTeam(units[i]) ~= Spring.GetMyAllyTeamID() and healthremaining >= 0 and not UnitDefs[Spring.GetUnitDefID(units[i])].isImmobile and finished == 1 and Spring.GetUnitWeaponHaveFreeLineOfFire(newtonid,1,units[i]) then
        unitsproc[#unitsproc+1] = units[i]
      end
    end
  end
  --Spring.Echo("Number of targets: " .. #unitsproc)
  if #unitsproc > 1 then
    local unitstargetingpriorities = ProcessTargets(unitsproc,newtonid)
    for i=1,#unitstargetingpriorities do -- post processing
      if HighPriority[Spring.GetUnitDefID(units[i])] then
        unitstargetingpriorities[i] = unitstargetingpriorities[i]/10
      end
    end
    local target = unitsproc[GetLowestNumber(unitstargetingpriorities)]
    --Spring.Echo("Target is " .. tostring(target))
    mynewtons[newtonid]["target"] = target
  elseif #unitsproc == 1 then
    target = unitsproc[1]
    mynewtons[newtonid]["target"] = target
  end
  if target ~= nil then
    x2,y2,z2 = Spring.GetUnitPosition(target)
    local d = DistanceFormula(x,z,x2,z2)
    --Spring.Echo("target is " .. d .. " elmos away")
    if d > 460 then
      mynewtons[newtonid]["target"] = nil
      TurnOff(newtonid)
    elseif (d < 150 and IsAirborne(target)) or (d < 100) then
      TurnOn(newtonid)
    elseif d > 275 and not IsAirborne(target) then
      TurnOff(newtonid)
    end
    mynewtons[newtonid]["numtargs"] = #unitsproc
    Spring.GiveOrderToUnit(newtonid,CMD.ATTACK,{target},{shift = true,})
  end
  x,y,z,units,unitsproc,target,healthremaining = nil
end

local function UpdateTarget(newtonid)
  if Spring.ValidUnitID(mynewtons[newtonid]["target"]) then
    local vx,vy,vz = Spring.GetUnitVelocity(mynewtons[newtonid]["target"])
    local x,y,z = Spring.GetUnitPosition(newtonid)
    local x2,y2,z2 = Spring.GetUnitPosition(mynewtons[newtonid]["target"])
    local distance = DistanceFormula(x,y,x2,y2)
    if (not (HighPriority[Spring.GetUnitDefID(mynewtons[newtonid]["target"])]) and IsAirborne(mynewtons[newtonid]["target"]) and WillUnitHitMe(newtonid,mynewtons[newtonid]["target"]) == false and distance <= 200) or distance >= 455 then
      mynewtons[newtonid]["target"] = nil
      SelectTarget(newtonid)
    end
  else
    mynewtons[newtonid]["target"] = nil
    SelectTarget(newtonid)
  end
end

function widget:GameFrame(f)
  if mynewtons then
    for id,data in pairs(mynewtons) do
      if data.target == nil then
        --Spring.Echo("Selecting target for " .. id)
        SelectTarget(id)
      elseif data.target ~= nil then
        --Spring.Echo("Tracking for " .. id)
        TrackTarget(id,data.target)
        UpdateTarget(id)
      end
    end
  end
end

function widget:Initialize()
  local newtons = Spring.GetTeamUnitsByDefs(Spring.GetMyTeamID(), GraviUnits)
  if #newtons > 0 then
    for i=1,#newtons do
      mynewtons[newtons[i]] = {wantedstate = false}
      TurnOff(newtons[i])
      Spring.GiveOrderToUnit(newtons[i],CMD.FIRE_STATE,{0},0)
    end
    newtons = nil
  end
  HighPriority[UnitDefNames["bomberheavy"].id] = true
  AlwaysAttract[UnitDefNames["bomberheavy"].id] = true
  AlwaysAttract[UnitDefNames["bomberprec"].id] = true
  AlwaysRepel[UnitDefNames["bomberdisarm"].id] = true
  AlwaysRepel[UnitDefNames["bomberriot"].id] = true
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
  if unitTeam == Spring.GetMyTeamID() and GraviUnitsTruth[unitDefID] then
    mynewtons[unitID] = {target = nil,numtargs = 0,wantedstate = false}
    TurnOff(unitID)
    Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{0},0)
  end
end

function widget:UnitReverseBuilt(unitID, unitDefID, unitTeam)
  mynewtons[unitID] = nil
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
  mynewtons[unitID] = nil
end

local function LINES()
  for id,data in pairs(mynewtons) do
    if data.target ~= nil then
      if Spring.ValidUnitID(data.target) then
        gl.LineStipple(true)
        local x,y,z = Spring.GetUnitPosition(id)
        local x2,y2,z2 = Spring.GetUnitPosition(data.target)
        gl.Color(1,0,0,1)
        gl.Vertex(x,y,z)
        gl.Vertex(x2,y2,z2)
        gl.LineStipple(false)
        gl.Color(1,1,1,1)
        x,y,z,x2,y2,z2 = nil
      end
    end
  end
end

function widget:DrawWorld()
  gl.BeginEnd(GL.LINES,LINES)
end

function widget:Shutdown()
  for id,_ in pairs(mynewtons) do
    Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{2},0) -- emergency turn on
    Spring.Echo("game_message: Newton AI has either crashed or shut down. Emergency turn on issued.")
  end
end