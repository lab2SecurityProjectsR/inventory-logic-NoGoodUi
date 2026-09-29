--!strict
--[=[
    WorldDropService.luau
    Author: JV (lab2 / lab2SecurityProjectsR)
    Manages 3D physical world drops, rarity particle auras, proximity collection,
    and server-side distance validation.
    Copyright (c) 2026 JV. All rights reserved.
]=]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ItemDatabase = require(ReplicatedStorage.InventorySystem.ItemDatabase)

local WorldDropService = {}
local dropsFolder: Folder

local function EnsureDropsFolder(): Folder
    if not dropsFolder or not dropsFolder.Parent then
        local found = workspace:FindFirstChild("WorldDrops")
        if found and found:IsA("Folder") then
            dropsFolder = found
        else
            dropsFolder = Instance.new("Folder")
            dropsFolder.Name = "WorldDrops"
            dropsFolder.Parent = workspace
        end
    end
    return dropsFolder
end

function WorldDropService.SpawnDrop(itemId: string, quantity: number, spawnPosition: Vector3, onPickupCallback: (player: Player) -> boolean): Model?
    local itemDef = ItemDatabase.GetItem(itemId)
    if not itemDef then return nil end

    local folder = EnsureDropsFolder()
    local dropModel = Instance.new("Model")
    dropModel.Name = "Drop_" .. itemId

    local color = ItemDatabase.GetRarityColor(itemDef.Rarity)

    local corePart = Instance.new("Part")
    corePart.Name = "PrimaryRoot"
    corePart.Size = Vector3.new(1.2, 1.8, 1.2)
    corePart.CFrame = CFrame.new(spawnPosition + Vector3.new(0, 1.6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45))
    corePart.Material = Enum.Material.Neon
    corePart.Color = color
    corePart.CanCollide = false
    corePart.Anchored = true
    corePart.Parent = dropModel
    dropModel.PrimaryPart = corePart

    -- Inner Shimmer Core
    local innerCore = Instance.new("Part")
    innerCore.Name = "InnerCore"
    innerCore.Size = Vector3.new(0.6, 1.0, 0.6)
    innerCore.CFrame = corePart.CFrame
    innerCore.Material = Enum.Material.ForceField
    innerCore.Color = Color3.new(1, 1, 1)
    innerCore.CanCollide = false
    innerCore.Anchored = true
    innerCore.Parent = dropModel

    -- Soft Sparkle / Aura Particles
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(color)
    particles.LightEmission = 0.8
    particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
    particles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
    particles.Lifetime = NumberRange.new(0.6, 1.2)
    particles.Rate = 12
    particles.Speed = NumberRange.new(1, 2)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.Parent = corePart

    -- Selection / PointLight glow
    local pointLight = Instance.new("PointLight")
    pointLight.Color = color
    pointLight.Brightness = 3
    pointLight.Range = 12
    pointLight.Parent = corePart


    -- Billboard Gui with Name and Rarity
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 140, 0, 45)
    billboard.StudsOffset = Vector3.new(0, 1.8, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 50
    billboard.Parent = corePart

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = corePart.Color
    nameLabel.TextStrokeTransparency = 0.2
    nameLabel.Text = string.format("%s %s (x%d)", itemDef.IconGlyph, itemDef.Name, quantity)
    nameLabel.Parent = billboard

    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size = UDim2.new(1, 0, 0.4, 0)
    rarityLabel.Position = UDim2.new(0, 0, 0.6, 0)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Font = Enum.Font.GothamBold
    rarityLabel.TextSize = 10
    rarityLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    rarityLabel.Text = string.format("◆ %s ◆", string.upper(itemDef.Rarity))
    rarityLabel.Parent = billboard

    -- Proximity Prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Collect"
    prompt.ObjectText = itemDef.Name
    prompt.MaxActivationDistance = 10
    prompt.HoldDuration = 0.2
    prompt.RequiresLineOfSight = false
    prompt.Parent = corePart

    local isCollected = false
    local promptConn: RBXScriptConnection
    promptConn = prompt.Triggered:Connect(function(player)
        if isCollected then return end
        
        -- Distance validation
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or (root.Position - corePart.Position).Magnitude > 14 then
            return
        end

        local accepted = onPickupCallback(player)
        if accepted then
            isCollected = true
            promptConn:Disconnect()
            prompt:Destroy()
            
            -- Dissolve animation
            local fadeTween = TweenService:Create(corePart, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.new(0.1, 0.1, 0.1),
                Transparency = 1
            })
            fadeTween:Play()
            fadeTween.Completed:Connect(function()
                dropModel:Destroy()
            end)
        end
    end)

    -- Floating / Bobbing animation loop
    task.spawn(function()
        local baseCF = corePart.CFrame
        local elapsed = 0
        while corePart.Parent and not isCollected do
            local dt = task.wait(0.03)
            elapsed += dt
            local yOffset = math.sin(elapsed * 2.5) * 0.4
            local rotAngle = elapsed * 1.5
            local currentCF = (baseCF + Vector3.new(0, yOffset, 0)) * CFrame.Angles(0, rotAngle, 0)
            corePart.CFrame = currentCF
            if innerCore and innerCore.Parent then
                innerCore.CFrame = currentCF * CFrame.Angles(0, -rotAngle * 1.2, 0)
            end
        end
    end)

    dropModel.Parent = folder
    Debris:AddItem(dropModel, 180) -- 3-minute cleanup
    return dropModel
end

return WorldDropService
