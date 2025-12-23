--[[
    MATCHA MASTER CONTROLLER
    Integrates: Movement, Target Identifier, Rock Farm, Mob Farm
    System: Custom Drawing GUI + Manual Input Polling (Due to broken Signals)
]]

-- 1. UTILITY & CONFIGURATION
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Global Settings Table (Shared across all modules)
local Settings = {
    Active = false,             -- Global Toggle
    MobFarm = false,            -- Mob Farm Toggle
    RockFarmAura = false,       -- Rock Farm Toggle (Aura Mode)
    TargetRocks = {"Coal", "Iron", "Gold", "Diamond"}, -- Default targets
    TargetMobs = {"Boar", "Wolf"}, -- Default mob targets
    TargetLocations = {"Spawn", "Forest"}, -- Default locations
    
    -- Movement Settings
    SkyHeight = 250,
    MovementSpeed = 1,
    SpeedCap = 15,
    
    -- Safety
    SafeRadius = 20,
    PlayerMiningDist = 15,
    MobAvoidDist = 15,
    ClickDelay = 0.1,
}

-- 2. MODULE LOADING
local function loadRepo(url)
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    if not success then 
        warn("Failed to fetch: " .. url)
        return nil 
    end
    
    local func, err = loadstring(result)
    if not func then
        warn("Failed to compile: " .. url .. " | Error: " .. tostring(err))
        return nil
    end
    
    return func()
end

notify("Loading Modules...", "Matcha", 3)

local MovementLib = loadRepo("https://raw.githubusercontent.com/dunnerulz/forge-recoded/refs/heads/main/Movement%20(TweenService).lua")
local TargetLib = loadRepo("https://raw.githubusercontent.com/dunnerulz/forge-recoded/refs/heads/main/Target%20Identifier.lua")
local RockFarm = loadRepo("https://raw.githubusercontent.com/dunnerulz/forge-recoded/refs/heads/main/Rock%20Farm.lua")
local MobFarm = loadRepo("https://raw.githubusercontent.com/dunnerulz/forge-recoded/refs/heads/main/Mob%20Farm.lua")

if not (MovementLib and TargetLib and RockFarm and MobFarm) then
    notify("Error: Failed to load one or more modules.", "System", 5)
    return
end

-- 3. DEPENDENCY INJECTION (Connecting the scripts)
-- The individual scripts have "Placeholder" functions. We overwrite them here.

-- Connect Rock Farm Dependencies
RockFarm.FindTarget = TargetLib.FindRockTarget
RockFarm.MoveTo = MovementLib.MoveToPosition
RockFarm.GetRockHP = TargetLib.GetRockHP
RockFarm.IsSafe = TargetLib.IsTargetSafe
RockFarm.FindMobNear = TargetLib.FindMobNearPoint
RockFarm.AddToBlacklist = TargetLib.AddToBlacklist

-- Connect Mob Farm Dependencies
MobFarm.FindTarget = TargetLib.FindMobTarget
MobFarm.MoveTo = MovementLib.MoveToPosition

notify("Modules Connected!", "System", 2)

-- 4. CUSTOM DRAWING GUI (Because ScreenGui events are broken)
local UI = {}
local UI_Visible = true

local function createButton(text, pos, callback)
    local btn = {}
    
    -- Background
    btn.Box = Drawing.new("Square")
    btn.Box.Size = Vector2.new(150, 25)
    btn.Box.Position = pos
    btn.Box.Color = Color3.fromRGB(40, 40, 40)
    btn.Box.Filled = true
    btn.Box.Visible = true
    btn.Box.Transparency = 1
    
    -- Border
    btn.Border = Drawing.new("Square")
    btn.Border.Size = Vector2.new(154, 29)
    btn.Border.Position = Vector2.new(pos.X - 2, pos.Y - 2)
    btn.Border.Color = Color3.fromRGB(0, 0, 0)
    btn.Border.Filled = false
    btn.Border.Thickness = 2
    btn.Border.Visible = true
    
    -- Text
    btn.Text = Drawing.new("Text")
    btn.Text.Text = text
    btn.Text.Size = 16
    btn.Text.Center = true
    btn.Text.Outline = true
    btn.Text.Color = Color3.fromRGB(255, 255, 255)
    btn.Text.Position = Vector2.new(pos.X + 75, pos.Y + 5)
    btn.Text.Visible = true
    
    btn.Callback = callback
    btn.Active = false
    
    function btn:UpdateState(isActive)
        self.Active = isActive
        if isActive then
            self.Box.Color = Color3.fromRGB(0, 150, 0) -- Green for ON
        else
            self.Box.Color = Color3.fromRGB(40, 40, 40) -- Dark for OFF
        end
    end
    
    function btn:IsHovered()
        local mx, my = Mouse.X, Mouse.Y
        -- Add Y offset for GUI inset if necessary, usually standard Mouse.X/Y works with Drawing
        local p = self.Box.Position
        local s = self.Box.Size
        return (mx >= p.X and mx <= p.X + s.X and my >= p.Y and my <= p.Y + s.Y)
    end
    
    table.insert(UI, btn)
    return btn
end

-- Create Menu Header
local HeaderBox = Drawing.new("Square")
HeaderBox.Size = Vector2.new(170, 200)
HeaderBox.Position = Vector2.new(40, 40)
HeaderBox.Color = Color3.fromRGB(20, 20, 20)
HeaderBox.Filled = true
HeaderBox.Visible = true

local HeaderText = Drawing.new("Text")
HeaderText.Text = "Matcha Farm"
HeaderText.Size = 20
HeaderText.Center = true
HeaderText.Outline = true
HeaderText.Color = Color3.fromRGB(255, 170, 0)
HeaderText.Position = Vector2.new(125, 50)
HeaderText.Visible = true

-- Create Buttons
local btnRock = createButton("Rock Farm", Vector2.new(50, 80), function(s) 
    Settings.Active = s
    if s then Settings.MobFarm = false end -- Mutually exclusive
end)

local btnMob = createButton("Mob Farm", Vector2.new(50, 115), function(s) 
    Settings.MobFarm = s 
    if s then Settings.Active = false end -- Mutually exclusive
end)

local btnClose = createButton("Hide Menu", Vector2.new(50, 150), function()
    -- Logic handled in loop
end)

-- 5. INPUT HANDLING LOOP (Manual Polling)
spawn(function()
    local wasPressed = false
    while true do
        wait(0.05) -- Fast poll
        
        -- Toggle Menu Visibility with RightControl (Keycode check needed? Just use button for now)
        -- Matcha docs: iskeypressed(keycode). RightControl is usually 0x46 or similar.
        -- We will stick to the "Hide Menu" button logic for simplicity.
        
        if ismouse1pressed() then
            if not wasPressed then
                wasPressed = true
                -- Check UI Clicks
                if UI_Visible then
                    for _, btn in ipairs(UI) do
                        if btn:IsHovered() then
                            -- Handle specific logic
                            if btn.Text.Text == "Hide Menu" then
                                UI_Visible = not UI_Visible
                                HeaderBox.Visible = UI_Visible
                                HeaderText.Visible = UI_Visible
                                for _, b in ipairs(UI) do
                                    b.Box.Visible = UI_Visible
                                    b.Border.Visible = UI_Visible
                                    b.Text.Visible = UI_Visible
                                end
                            else
                                -- Toggle Logic
                                local newState = not btn.Active
                                btn:UpdateState(newState)
                                if btn.Callback then btn.Callback(newState) end
                                
                                -- Sync other buttons
                                if btn == btnRock then btnMob:UpdateState(false) end
                                if btn == btnMob then btnRock:UpdateState(false) end
                            end
                        end
                    end
                end
            end
        else
            wasPressed = false
        end
    end
end)

-- 6. MAIN LOGIC LOOP
spawn(function()
    while true do
        wait(0.1)
        
        -- Always fetch fresh LocalPlayer instance data inside loop
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        
        if not myRoot then 
            wait(1)
            continue 
        end
        
        -- ---------------------------------------------------------
        -- ROCK FARM LOGIC
        -- ---------------------------------------------------------
        if Settings.Active then
            -- 1. Find Target
            local target, hitbox = RockFarm.FindTarget(Settings)
            
            if target and hitbox then
                -- 2. Process Target (Mining loop inside RockFarm module)
                local result = RockFarm.ProcessSingleRock(target, hitbox, Settings)
                -- Result can be "Done", "Unsafe", or "Skipped"
                
                if result == "Unsafe" then
                    -- Run away slightly?
                    MovementLib.MoveToPosition(myRoot.Position + Vector3.new(0, 50, 0), Settings)
                end
            else
                -- Idle / Search
                -- Optional: Move to center of zone to find more rocks
            end
        
        -- ---------------------------------------------------------
        -- MOB FARM LOGIC
        -- ---------------------------------------------------------
        elseif Settings.MobFarm then
            local mob, mobRoot = MobFarm.FindTarget(Settings)
            
            if mob and mobRoot then
                MobFarm.ProcessSingleMob(mob, mobRoot, Settings)
            end
        end
    end
end)
