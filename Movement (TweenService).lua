--[[
    MODULE 1: MOVEMENT & TWEEN SERVICE
    Contains: Custom TweenService, Custom Wait, Sky Hop Logic
    Interacton: Zero external logic.
]]

local MovementLib = {}
local Players = game:GetService("Players")

-- Helper: Fetch LocalPlayer Safely
local function getLocalPlayer()
    return Players.LocalPlayer
end

-- ==============================================================================
-- CUSTOM TWEEN SERVICE IMPLEMENTATION
-- ==============================================================================
local TweenService = {}
local EasingFunctions = {
    Linear = function(t) return t end,
    Sine = {
        In = function(t) return 1 - math.cos((t * math.pi) / 2) end,
        Out = function(t) return math.sin((t * math.pi) / 2) end,
        InOut = function(t) return -(math.cos(math.pi * t) - 1) / 2 end
    },
    Quad = {
        In = function(t) return t * t end,
        Out = function(t) return 1 - (1 - t) * (1 - t) end,
        InOut = function(t) return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2 end
    }
}

local function isVector3(obj)
    if type(obj) == "userdata" then return pcall(function() return obj.x and obj.y and obj.z end)
    elseif type(obj) == "table" then return obj.x ~= nil and obj.y ~= nil and obj.z ~= nil
    elseif type(obj) == "Vector3" then return obj.X and obj.Y and obj.Z end
    return false
end

local function createVector3(x, y, z)
    local s, r = pcall(function() return Vector3.new(x, y, z) end)
    if s then return r else return {x=x, y=y, z=z} end
end

local function getEasingFunction(style, dir)
    if style == "Linear" then return EasingFunctions.Linear
    elseif EasingFunctions[style] then
        if dir == "In" then return EasingFunctions[style].In
        elseif dir == "Out" then return EasingFunctions[style].Out
        else return EasingFunctions[style].InOut end
    end
    return EasingFunctions.Linear
end

local TweenInfo = {}
TweenInfo.__index = TweenInfo
function TweenInfo.new(time, style, dir, rep, rev, del)
    local self = setmetatable({}, TweenInfo)
    self.Time = time or 1; self.EasingStyle = style or "Quad"; self.EasingDirection = dir or "Out"
    self.RepeatCount = rep or 0; self.Reverses = rev or false; self.DelayTime = del or 0
    return self
end

local Tween = {}
Tween.__index = Tween
function Tween.new(instance, tweenInfo, properties)
    local self = setmetatable({}, Tween)
    self.Instance = instance
    self.TweenInfo = (type(tweenInfo) == "table" and getmetatable(tweenInfo) ~= TweenInfo) and 
        TweenInfo.new(tweenInfo.Time, tweenInfo.EasingStyle, tweenInfo.EasingDirection, tweenInfo.RepeatCount, tweenInfo.Reverses, tweenInfo.DelayTime) 
        or tweenInfo
    self.Properties = properties
    self.InitialProperties = {}
    self.IsPlaying = false
    self.StartTime = 0; self.CurrentTime = 0; self.CompletedLoops = 0; self.CurrentDirection = 1
    
    for prop, targetValue in pairs(properties) do
        if instance[prop] ~= nil then
            local initialValue = instance[prop]
            if isVector3(initialValue) then
                self.InitialProperties[prop] = {type="Vector3", x=initialValue.x, y=initialValue.y, z=initialValue.z}
            else
                self.InitialProperties[prop] = initialValue
            end
        end
    end
    for prop, targetValue in pairs(properties) do
        if isVector3(targetValue) then properties[prop] = {type="Vector3", x=targetValue.x, y=targetValue.y, z=targetValue.z} end
    end
    return self
end

local activeTweens = {}
function TweenService._addActiveTween(t) table.insert(activeTweens, t); if not TweenService._updateLoopRunning then TweenService._startUpdateLoop() end end
function TweenService._removeActiveTween(t) for i,at in ipairs(activeTweens) do if at==t then table.remove(activeTweens, i) break end end; if #activeTweens==0 then TweenService._stopUpdateLoop() end end

function Tween:Play() if self.IsPlaying then return end; self.IsPlaying=true; self.StartTime=os.clock(); self.CurrentTime=0; self.CompletedLoops=0; self.CurrentDirection=1; TweenService._addActiveTween(self); self:Update(0.001) end
function Tween:Stop() if not self.IsPlaying then return end; self.IsPlaying=false; TweenService._removeActiveTween(self) end
function Tween:Update(dt)
    if not self.IsPlaying then return false end
    self.CurrentTime = self.CurrentTime + dt
    local info = self.TweenInfo; if not info then return false end
    local func = getEasingFunction(info.EasingStyle, info.EasingDirection)
    
    if self.CurrentTime < info.DelayTime then return true end
    local adjTime = self.CurrentTime - info.DelayTime
    local duration = info.Time
    
    if self.CurrentTime >= (info.DelayTime + duration * ((info.RepeatCount==0) and 1 or info.RepeatCount)) then
        pcall(function()
            for p, v in pairs(self.Properties) do
                if type(v)=="table" and v.type=="Vector3" then self.Instance[p] = createVector3(v.x, v.y, v.z)
                else self.Instance[p] = v end
            end
        end)
        self:Stop(); return false
    end
    
    local progress = (adjTime % duration) / duration
    if self.CurrentDirection == -1 then progress = 1 - progress end
    local alpha = func(progress)
    
    for p, v in pairs(self.Properties) do
        local init = self.InitialProperties[p]
        if init and self.Instance[p] ~= nil then
            if type(init)=="table" and init.type=="Vector3" then
                local nx = init.x + (v.x - init.x) * alpha
                local ny = init.y + (v.y - init.y) * alpha
                local nz = init.z + (v.z - init.z) * alpha
                self.Instance[p] = createVector3(nx, ny, nz)
            elseif type(init)=="number" and type(v)=="number" then
                self.Instance[p] = init + (v - init) * alpha
            else
                 self.Instance[p] = v
            end
        end
    end
    return true
end

function TweenService:Create(inst, info, props) return Tween.new(inst, info, props) end
TweenService.TweenInfo = TweenInfo
TweenService._updateLoopRunning = false
TweenService._lastUpdateTime = os.clock()

function TweenService._processTweens()
    local curr = os.clock()
    local dt = curr - TweenService._lastUpdateTime
    TweenService._lastUpdateTime = curr
    local i = 1
    while i <= #activeTweens do
        if activeTweens[i]:Update(dt) then i=i+1 else table.remove(activeTweens, i) end
    end
    if #activeTweens == 0 then TweenService._updateLoopRunning = false end
end

function TweenService._startUpdateLoop() TweenService._updateLoopRunning = true; TweenService._lastUpdateTime = os.clock() end
function TweenService._stopUpdateLoop() TweenService._updateLoopRunning = false end

-- Custom Wait Function to allow Tweens to run during yields
-- You must overwrite the global wait with this in your master script if you want tweens to update
local function CustomWait(seconds)
    local start = os.clock()
    local finish = start + (seconds or 0)
    local originalWait = wait -- Uses the environment's wait
    if TweenService._updateLoopRunning then TweenService._processTweens() end
    while os.clock() < finish do
        local rem = math.min(0.006, finish - os.clock())
        if rem > 0 then originalWait(rem) end
        if TweenService._updateLoopRunning then TweenService._processTweens() end
    end
    return os.clock() - start
end

-- ==============================================================================
-- SKY HOP MOVEMENT LOGIC
-- ==============================================================================

function MovementLib.MoveToPosition(targetCenter, settings)
    -- settings requires: SkyHeight, MovementSpeed, SpeedCap
    
    local LocalPlayer = getLocalPlayer()
    local character = LocalPlayer.Character; if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local currentPos = hrp.Position
    local camera = workspace.CurrentCamera 
    
    if camera then
        pcall(function() 
            if Camera and Camera.lookAt then Camera.lookAt(camera.Position, targetCenter)
            elseif camera.lookAt then camera:lookAt(camera.Position, targetCenter) end
        end)
    end

    local destX = targetCenter.X
    local destZ = targetCenter.Z
    local destY = targetCenter.Y - 2 -- Final Destination Y
    local skyY = settings.SkyHeight or 250 
    
    local dx = destX - currentPos.X
    local dz = destZ - currentPos.Z
    local hDist = math.sqrt(dx*dx + dz*dz) 
    
    -- [LOGIC]: Up -> Over -> Down
    if hDist > 10 then
        -- Horizontal Move Phase
        if currentPos.Y < (skyY - 5) then
             -- PHASE 1: INSTANT ASCEND
             hrp.Position = Vector3.new(currentPos.X, skyY, currentPos.Z)
             hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
             CustomWait(0.05)
             return
        else
             -- PHASE 2: SMOOTH HOVER
             local distToDest = hDist
             local moveX = destX - currentPos.X
             local moveZ = destZ - currentPos.Z
             
             local moveStep = distToDest * (settings.MovementSpeed or 1)
             if moveStep > (settings.SpeedCap or 10) then moveStep = settings.SpeedCap or 10 end
             
             local newX = currentPos.X + (moveX / distToDest) * moveStep
             local newZ = currentPos.Z + (moveZ / distToDest) * moveStep
             
             local stepTarget = Vector3.new(newX, skyY, newZ)
             local tween = TweenService:Create(hrp, TweenInfo.new(0.05, "Linear"), {Position = stepTarget})
             tween:Play()
             hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
             return
        end
    else
        -- Vertical Descent Phase
        if math.abs(currentPos.Y - destY) > 5 then
            -- PHASE 3: INSTANT DESCEND
            hrp.Position = Vector3.new(destX, destY, destZ)
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            CustomWait(0.05)
            return
        else
            -- Stick to target
            hrp.Position = Vector3.new(destX, destY, destZ)
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end
end

MovementLib.TweenService = TweenService
MovementLib.CustomWait = CustomWait

return MovementLib
