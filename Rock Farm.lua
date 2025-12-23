--[[
    MODULE 3: ROCK FARM LOGIC
    Contains: Logic to mine rocks, handle ores, and switch to Aura logic.
    Interacton: Uses PLACEHOLDERS for Target Finding and Movement.
]]

local RockFarm = {}
local Players = game:GetService("Players")

-- ==============================================================================
-- PLACEHOLDERS - YOU MUST IMPLEMENT THESE IN YOUR MASTER SCRIPT
-- ==============================================================================
RockFarm.FindTarget = function(settings) return nil, nil end 
RockFarm.MoveTo = function(pos, settings) end 
RockFarm.GetRockHP = function(model) return 100 end
RockFarm.IsSafe = function(pos, settings) return true end
RockFarm.FindMobNear = function(pos, radius, settings) return nil, nil end
RockFarm.AddToBlacklist = function(model, pos) end

-- Helper: Fetch LocalPlayer Safely
local function getLocalPlayer()
    return Players.LocalPlayer
end

local function get_distance(pos1, pos2)
    if not pos1 or not pos2 then return 999999 end
    local dx, dy, dz = pos1.X - pos2.X, pos1.Y - pos2.Y, pos1.Z - pos2.Z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

function RockFarm.ProcessSingleRock(target, hitbox, settings)
    -- Logic for mining ONE specific rock until it breaks or becomes unsafe
    
    local veinModel = hitbox.Parent
    -- [MODIFIED] Anti-stuck logic removed as requested
    
    while settings.Active and target.Parent and veinModel.Parent and hitbox.Parent do
        local LocalPlayer = getLocalPlayer()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        -- Ore Scanning & Filtering Logic (Refined V4 - Scan All then Decide)
        if settings.TargetOres and #settings.TargetOres > 0 then
            local foundOres = {}
            -- 1. Scan the rock for all the ore files it can find right now
            for _, child in ipairs(veinModel:GetChildren()) do
                if child.Name == "Ore" then
                    table.insert(foundOres, child)
                end
            end

            -- 2. If we detected any ores, scan ALL their attributes for a match
            if #foundOres > 0 then
                local matchFound = false
                
                for _, oreObj in ipairs(foundOres) do
                    local oreName = oreObj:GetAttribute("Ore")
                    if oreName then
                        for _, desiredOre in ipairs(settings.TargetOres) do
                            if desiredOre == oreName then
                                matchFound = true
                                break
                            end
                        end
                    end
                    -- Optimization: If we found at least one match, we are good to stay.
                    if matchFound then break end
                end

                -- 3. Decision: 
                -- If we found ANY match -> Continue Mining.
                -- If we found ores but NO matches -> Skip.
                if not matchFound then
                    RockFarm.AddToBlacklist(veinModel, hitbox.Position)
                    wait(0.2)
                    return "Skipped (Found " .. #foundOres .. " Ores - None Desired)"
                end
            end
        end

        -- Aura Logic (Combat switch)
        if settings.RockFarmAura then
            local auraMob, auraRoot = RockFarm.FindMobNear(hitbox.Position, 25, settings)
            if auraMob and auraRoot then
                -- Switch to killing the mob
                -- Note: We are hijacking the mining loop to kill the mob first
                while settings.RockFarmAura and auraMob.Parent and auraMob:FindFirstChild("Humanoid") and auraMob.Humanoid.Health > 0 do
                    RockFarm.MoveTo(auraRoot.Position, settings) -- Move to Mob
                    
                    if hrp then
                        local distToMob = get_distance(hrp.Position, auraRoot.Position)
                        if distToMob <= 8 then
                            pcall(function()
                                keypress(0x32); wait(0.02)
                                mouse1click(); wait(0.02)
                                keyrelease(0x32)
                            end)
                        end
                    end
                    wait(settings.ClickDelay or 0.1)
                end
            end
        end
        
        -- Safety Check
        if not settings.RockFarmAura and not RockFarm.IsSafe(hitbox.Position, settings) then
            return "Unsafe"
        end

        -- Movement (To Rock)
        RockFarm.MoveTo(hitbox.Position, settings)

        -- Action (Mining)
        if hrp then
             local distToRock = get_distance(hrp.Position, hitbox.Position)
             if distToRock <= 6 then
                 pcall(function() 
                     keypress(0x31) -- Pickaxe
                     mouse1click()
                     keyrelease(0x31) 
                 end)
             end
        end

        wait(settings.ClickDelay or 0.1)
    end
    
    return "Done"
end

return RockFarm
