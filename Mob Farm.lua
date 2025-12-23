--[[
    MODULE 4: MOB FARM LOGIC
    Contains: Logic to kill mobs.
    Interacton: Uses PLACEHOLDERS for Target Finding and Movement.
]]

local MobFarm = {}
local Players = game:GetService("Players")

-- ==============================================================================
-- PLACEHOLDERS - YOU MUST IMPLEMENT THESE IN YOUR MASTER SCRIPT
-- ==============================================================================
MobFarm.FindTarget = function(settings) return nil, nil end
MobFarm.MoveTo = function(pos, settings) end

-- Helper: Fetch LocalPlayer Safely
local function getLocalPlayer()
    return Players.LocalPlayer
end

local function get_distance(pos1, pos2)
    if not pos1 or not pos2 then return 999999 end
    local dx, dy, dz = pos1.X - pos2.X, pos1.Y - pos2.Y, pos1.Z - pos2.Z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

function MobFarm.ProcessSingleMob(mob, mobRoot, settings)
    -- Logic for killing ONE specific mob until it dies
    
    while settings.MobFarm and mob.Parent and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 do
        local LocalPlayer = getLocalPlayer()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        -- Movement (To Mob)
        if mobRoot then
            MobFarm.MoveTo(mobRoot.Position, settings)
        else
            break
        end

        -- Action (Combat)
        if hrp and mobRoot then
             local dist = get_distance(hrp.Position, mobRoot.Position)
             if dist <= 5 then
                 pcall(function() 
                     keypress(0x32) -- Weapon Slot 2
                     wait(0.02)
                     mouse1click() 
                     wait(0.02)
                     keyrelease(0x32) 
                 end)
             end
        end
        
        wait(settings.ClickDelay or 0.1)
        
        -- Verify target still exists
        if not mobRoot.Parent then break end
    end
    
    return "Dead"
end

return MobFarm
