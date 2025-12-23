--[[
    MODULE 2: TARGET IDENTIFIER
    Contains: Rock/Mob finding logic, Safety checks, HP Checks
    Interacton: Zero external logic.
]]

local TargetLib = {}
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RocksBase = Workspace:FindFirstChild("Rocks")
local LivingFolder = Workspace:FindFirstChild("Living")

-- Internal State
local BlacklistedModels = setmetatable({}, {__mode = "k"}) 
local SkippedPositions = {} 

-- Helpers
local function getLocalPlayer()
    return Players.LocalPlayer
end

local function get_distance(pos1, pos2)
    if not pos1 or not pos2 then return 999999 end
    local dx, dy, dz = pos1.X - pos2.X, pos1.Y - pos2.Y, pos1.Z - pos2.Z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- ==============================================================================
-- INFO GETTERS
-- ==============================================================================

function TargetLib.GetRockTypes(settings)
    local types = {}
    local seen = {}
    if settings.TargetLocations and RocksBase then
        for _, locationName in ipairs(settings.TargetLocations) do
            local folder = RocksBase:FindFirstChild(locationName)
            if folder then
                for _, child in ipairs(folder:GetChildren()) do
                    if (child:IsA("Part") or child:IsA("MeshPart")) then
                        local model = child:FindFirstChildOfClass("Model")
                        if model and not seen[model.Name] then
                            table.insert(types, model.Name)
                            seen[model.Name] = true
                        end
                    end
                end
            end
        end
    end
    table.sort(types)
    return types
end

function TargetLib.GetMobTypes()
    local types = {}
    local seen = {}
    if LivingFolder then
        for _, child in ipairs(LivingFolder:GetChildren()) do
            if child:IsA("Model") then
                local humanoid = child:FindFirstChild("Humanoid")
                if humanoid and not humanoid:FindFirstChild("Status") then
                    local cleanName = string.gsub(child.Name, "%d+$", "") 
                    cleanName = string.match(cleanName, "^%s*(.-)%s*$") or cleanName
                    
                    if not seen[cleanName] then
                        table.insert(types, cleanName)
                        seen[cleanName] = true
                    end
                end
            end
        end
    end
    table.sort(types)
    return types
end

function TargetLib.GetRockHP(veinModel)
    if not veinModel then return nil end
    local infoFrame = veinModel:FindFirstChild("infoFrame")
    if infoFrame then
        local frame = infoFrame:FindFirstChild("Frame")
        if frame then
            local hpLabel = frame:FindFirstChild("rockHP")
            if hpLabel then
                local text = hpLabel.Text
                local number = tonumber(string.match(text, "%d+"))
                return number
            end
        end
    end
    return nil
end

-- ==============================================================================
-- SAFETY & AVOIDANCE
-- ==============================================================================

function TargetLib.IsTargetSafe(targetPos, settings)
    -- settings requires: RockFarmAura, SafeRadius, PlayerMiningDist
    local LocalPlayer = getLocalPlayer()
    
    if settings.RockFarmAura then return true end

    if not LivingFolder then return true end
    local entities = LivingFolder:GetChildren()
    for _, entity in ipairs(entities) do
        if entity:IsA("Model") and entity.Name ~= LocalPlayer.Name then
            local root = entity:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = get_distance(targetPos, root.Position)
                local humanoid = entity:FindFirstChild("Humanoid")
                if humanoid then
                    if not humanoid:FindFirstChild("Status") then
                        -- Mob
                        if dist < (settings.SafeRadius or 20) then return false end
                    else
                        -- Player
                        if dist < (settings.PlayerMiningDist or 10) then return false end
                    end
                end
            end
        end
    end
    return true
end

function TargetLib.GetAvoidanceVector(currentPos, settings)
    -- settings requires: RockFarmAura, MobAvoidDist
    
    if settings.RockFarmAura then return 0, 0 end

    local totalPushX, totalPushY = 0, 0
    if not LivingFolder then return 0, 0 end
    local entities = LivingFolder:GetChildren()
    for _, entity in ipairs(entities) do
        if entity:IsA("Model") then
            local humanoid = entity:FindFirstChild("Humanoid")
            if humanoid and not humanoid:FindFirstChild("Status") then
                local root = entity:FindFirstChild("HumanoidRootPart")
                if root then
                    local dist = get_distance(currentPos, root.Position)
                    local avoidDist = settings.MobAvoidDist or 20
                    if dist < avoidDist and dist > 0.1 then
                        local pushX, pushZ = currentPos.X - root.Position.X, currentPos.Z - root.Position.Z 
                        local pushDist = math.sqrt(pushX*pushX + pushZ*pushZ)
                        local weight = (avoidDist - dist) / avoidDist
                        totalPushX = totalPushX + ((pushX / pushDist) * weight)
                        totalPushY = totalPushY + ((pushZ / pushDist) * weight)
                    end
                end
            end
        end
    end
    return totalPushX, totalPushY
end

-- ==============================================================================
-- SEARCH LOGIC
-- ==============================================================================

function TargetLib.FindRockTarget(settings)
    -- settings requires: TargetLocations, TargetRocks, SkippedPositions logic handled internally?
    -- No, we need to clean SkippedPositions manually or checking time
    
    if not settings.TargetLocations or #settings.TargetLocations == 0 then return nil, nil end
    if not RocksBase then return nil, nil end

    -- Cleanup SkippedPositions
    local now = os.clock()
    for i = #SkippedPositions, 1, -1 do
        if now - SkippedPositions[i].time > 15 then
            table.remove(SkippedPositions, i)
        end
    end

    local bestTarget, bestHitbox = nil, nil
    local bestDistance = 9999999
    
    local LocalPlayer = getLocalPlayer()
    local character = LocalPlayer.Character; if not character then return nil, nil end
    local hrp = character:FindFirstChild("HumanoidRootPart"); if not hrp then return nil, nil end
    local myPos = hrp.Position
    
    for _, locationName in ipairs(settings.TargetLocations) do
        local folder = RocksBase:FindFirstChild(locationName)
        if folder then
             for _, spawnLocation in ipairs(folder:GetChildren()) do
                local veinModel = spawnLocation:FindFirstChildOfClass("Model")
                
                if veinModel then
                    if BlacklistedModels[veinModel] then continue end
                    
                    local rockName = veinModel.Name
                    local allowed = false
                    if not settings.TargetRocks or #settings.TargetRocks == 0 then allowed = false 
                    else
                        for _, target in ipairs(settings.TargetRocks) do
                            if target == rockName then allowed = true; break end
                        end
                    end

                    if not allowed then continue end

                    local hitbox = veinModel:FindFirstChild("Hitbox")
                    
                    -- Safety check using internal function
                    if hitbox and TargetLib.IsTargetSafe(hitbox.Position, settings) then
                        
                        -- Skip bad rocks check
                        local tooCloseToBadRock = false
                        for _, skipped in ipairs(SkippedPositions) do
                            if get_distance(hitbox.Position, skipped.pos) < 8 then
                                tooCloseToBadRock = true; break
                            end
                        end
                        if tooCloseToBadRock then continue end

                        local dist = get_distance(myPos, hitbox.Position)
                        if dist < bestDistance then
                            bestDistance = dist
                            bestTarget = spawnLocation
                            bestHitbox = hitbox
                        end
                    end
                end
            end
        end
    end
    
    return bestTarget, bestHitbox
end

function TargetLib.FindMobTarget(settings)
    -- settings requires: MobFarmRange, TargetMobs
    if not LivingFolder then return nil, nil end
    local children = LivingFolder:GetChildren()
    local closestMob, closestRoot, minDistance = nil, nil, (settings.MobFarmRange or 1000)
    
    local LocalPlayer = getLocalPlayer()
    local character = LocalPlayer.Character; if not character then return nil, nil end
    local hrp = character:FindFirstChild("HumanoidRootPart"); if not hrp then return nil, nil end
    local myPos = hrp.Position
    
    local checkCount = 0
    
    for _, entity in ipairs(children) do
        checkCount = checkCount + 1
        if checkCount % 100 == 0 then wait() end -- Yield for performance
        
        if entity:IsA("Model") then
            local humanoid = entity:FindFirstChild("Humanoid")
            if humanoid and not humanoid:FindFirstChild("Status") then
                local mobAllowed = false
                local cleanEntityName = string.gsub(entity.Name, "%d+$", "")
                cleanEntityName = string.match(cleanEntityName, "^%s*(.-)%s*$") or cleanEntityName
                
                if not settings.TargetMobs or #settings.TargetMobs == 0 then mobAllowed = true
                else
                    for _, target in ipairs(settings.TargetMobs) do
                        if target == cleanEntityName then mobAllowed = true; break end
                    end
                end
                
                if mobAllowed then
                    local root = entity:FindFirstChild("HumanoidRootPart")
                    if root and humanoid.Health > 0 then
                        local dist = get_distance(myPos, root.Position)
                        if dist < minDistance then
                            minDistance = dist
                            closestMob = entity
                            closestRoot = root
                        end
                    end
                end
            end
        end
    end
    return closestMob, closestRoot
end

function TargetLib.FindMobNearPoint(point, radius, settings)
    if not LivingFolder then return nil, nil end
    local closest, closestRoot, minDst = nil, nil, radius
    local LocalPlayer = getLocalPlayer()

    for _, entity in ipairs(LivingFolder:GetChildren()) do
         if entity:IsA("Model") and entity.Name ~= LocalPlayer.Name then
             local hum = entity:FindFirstChild("Humanoid")
             local root = entity:FindFirstChild("HumanoidRootPart")
             if hum and root and hum.Health > 0 and not hum:FindFirstChild("Status") then
                 local cleanName = string.gsub(entity.Name, "%d+$", "")
                 cleanName = string.match(cleanName, "^%s*(.-)%s*$") or cleanName
                 local allowed = (#settings.TargetMobs == 0)
                 if not allowed then
                     for _, t in ipairs(settings.TargetMobs) do if t == cleanName then allowed = true; break end end
                 end
                 
                 if allowed then
                     local d = get_distance(point, root.Position)
                     if d < minDst then
                         minDst = d
                         closest = entity
                         closestRoot = root
                     end
                 end
             end
         end
    end
    return closest, closestRoot
end

-- Exported functions to manipulate blacklist
function TargetLib.AddToBlacklist(model, pos)
    BlacklistedModels[model] = true
    if pos then table.insert(SkippedPositions, {pos = pos, time = os.clock()}) end
end

function TargetLib.ClearBlacklist()
    BlacklistedModels = {}
    SkippedPositions = {}
end

return TargetLib
