--!strict
--[=[
    WorldDropService.luau
    Author: JV (lab2 / lab2SecurityProjectsR)
    Manages high-fidelity 3D physical world drops, item-specific geometries
    (rotating miniature weapons, stimpack vials, faceted quantum cores),
    magnetic levitation effects, rarity auras, and server-side pickup validation.
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

-- Helper: Create 3D drop geometry based on category
local function BuildDropGeometry(dropModel: Model, itemId: string, color: Color3, spawnPos: Vector3): BasePart
    local itemDef = ItemDatabase.GetItem(itemId)
    local category = itemDef and itemDef.Category or "Material"

    local root = Instance.new("Part")
    root.Name = "PrimaryRoot"
    root.Anchored = true
    root.CanCollide = false
    root.CanQuery = false
    root.CanTouch = false
    root.Position = spawnPos + Vector3.new(0, 1.2, 0)
    root.Parent = dropModel
    dropModel.PrimaryPart = root

    if itemId == "plasma_katana" or itemId == "iron_broadsword" then
        -- Miniature 3D Floating Katana
        root.Size = Vector3.new(0.3, 2.8, 0.3)
        root.Transparency = 1

        local hilt = Instance.new("Part")
        hilt.Size = Vector3.new(0.2, 0.8, 0.2)
        hilt.Material = Enum.Material.DiamondPlate
        hilt.Color = Color3.fromRGB(24, 28, 36)
        hilt.CFrame = root.CFrame * CFrame.new(0, -0.8, 0)
        hilt.Anchored = true
        hilt.CanCollide = false
        hilt.Parent = dropModel

        local guard = Instance.new("Part")
        guard.Size = Vector3.new(0.6, 0.08, 0.6)
        guard.Material = Enum.Material.Metal
        guard.Color = Color3.fromRGB(220, 180, 60)
        guard.CFrame = root.CFrame * CFrame.new(0, -0.38, 0)
        guard.Anchored = true
        guard.CanCollide = false
        guard.Parent = dropModel

        local blade = Instance.new("Part")
        blade.Size = Vector3.new(0.08, 2.0, 0.3)
        blade.Material = Enum.Material.Neon
        blade.Color = color
        blade.CFrame = root.CFrame * CFrame.new(0, 0.7, 0)
        blade.Anchored = true
        blade.CanCollide = false
        blade.Parent = dropModel

    elseif itemId == "cyber_revolver" then
        -- Miniature 3D Floating Revolver
        root.Size = Vector3.new(0.4, 1.4, 2.0)
        root.Transparency = 1

        local frame = Instance.new("Part")
        frame.Size = Vector3.new(0.32, 0.45, 0.7)
        frame.Material = Enum.Material.Metal
        frame.Color = Color3.fromRGB(45, 55, 70)
        frame.CFrame = root.CFrame * CFrame.new(0, 0.1, 0.1)
        frame.Anchored = true
        frame.CanCollide = false
        frame.Parent = dropModel

        local cylinder = Instance.new("Part")
        cylinder.Size = Vector3.new(0.36, 0.36, 0.38)
        cylinder.Material = Enum.Material.Neon
        cylinder.Color = color
        cylinder.CFrame = root.CFrame * CFrame.new(0, 0.1, 0.1)
        cylinder.Anchored = true
        cylinder.CanCollide = false
        cylinder.Parent = dropModel

        local barrel = Instance.new("Part")
        barrel.Size = Vector3.new(0.24, 0.32, 1.1)
        barrel.Material = Enum.Material.Metal
        barrel.Color = Color3.fromRGB(35, 42, 54)
        barrel.CFrame = root.CFrame * CFrame.new(0, 0.15, -0.7)
        barrel.Anchored = true
        barrel.CanCollide = false
        barrel.Parent = dropModel

    elseif itemId == "health_stim" or itemId == "velocity_elixir" then
        -- High-Tech Pharmaceutical Injector Vial
        root.Size = Vector3.new(0.6, 1.8, 0.6)
        root.Transparency = 1

        local glassTube = Instance.new("Part")
        glassTube.Size = Vector3.new(0.45, 1.3, 0.45)
        glassTube.Material = Enum.Material.ForceField
        glassTube.Color = color
        glassTube.CFrame = root.CFrame
        glassTube.Anchored = true
        glassTube.CanCollide = false
        glassTube.Parent = dropModel

        local liquidCore = Instance.new("Part")
        liquidCore.Size = Vector3.new(0.35, 1.1, 0.35)
        liquidCore.Material = Enum.Material.Neon
        liquidCore.Color = color
        liquidCore.CFrame = root.CFrame
        liquidCore.Anchored = true
        liquidCore.CanCollide = false
        liquidCore.Parent = dropModel

        local topCap = Instance.new("Part")
        topCap.Size = Vector3.new(0.52, 0.22, 0.52)
        topCap.Material = Enum.Material.Metal
        topCap.Color = Color3.fromRGB(180, 190, 205)
        topCap.CFrame = root.CFrame * CFrame.new(0, 0.72, 0)
        topCap.Anchored = true
        topCap.CanCollide = false
        topCap.Parent = dropModel

    elseif itemId == "aegis_bulwark" then
        -- Miniature Aegis Shield
        root.Size = Vector3.new(1.4, 2.0, 0.2)
        root.Transparency = 1

        local shield = Instance.new("Part")
        shield.Size = Vector3.new(1.5, 2.0, 0.08)
        shield.Material = Enum.Material.ForceField
        shield.Color = color
        shield.Transparency = 0.3
        shield.CFrame = root.CFrame
        shield.Anchored = true
        shield.CanCollide = false
        shield.Parent = dropModel

        local core = Instance.new("Part")
        core.Size = Vector3.new(0.3, 0.3, 0.16)
        core.Material = Enum.Material.Neon
        core.Color = color
        core.CFrame = root.CFrame
        core.Anchored = true
        core.CanCollide = false
        core.Parent = dropModel

    else
        -- Quantum Core Fragment: Faceted Cyber Crystal
        root.Size = Vector3.new(1.1, 1.5, 1.1)
        root.Material = Enum.Material.Glass
        root.Color = color
        root.Transparency = 0.2
        root.CFrame = root.CFrame * CFrame.Angles(math.rad(45), 0, math.rad(45))

        local innerCore = Instance.new("Part")
        innerCore.Name = "InnerCore"
        innerCore.Size = Vector3.new(0.55, 0.85, 0.55)
        innerCore.CFrame = root.CFrame
        innerCore.Material = Enum.Material.Neon
        innerCore.Color = color
        innerCore.CanCollide = false
        innerCore.Anchored = true
        innerCore.Parent = dropModel
    end

    return root
end

function WorldDropService.SpawnDrop(itemId: string, quantity: number, spawnPosition: Vector3, onPickupCallback: (player: Player) -> boolean): Model?
    local itemDef = ItemDatabase.GetItem(itemId)
    if not itemDef then return nil end

    local folder = EnsureDropsFolder()
    local dropModel = Instance.new("Model")
    dropModel.Name = "Drop_" .. itemId

    local color = ItemDatabase.GetRarityColor(itemDef.Rarity)

    local corePart = BuildDropGeometry(dropModel, itemId, color, spawnPosition)

    -- Soft Sparkle / Aura Particles
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(color)
    particles.LightEmission = 0.8
    particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
    particles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
    particles.Lifetime = NumberRange.new(0.5, 1.0)
    particles.Rate = 6
    particles.Speed = NumberRange.new(0.5, 1.2)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.Parent = corePart

    -- Selection / PointLight glow
    local pointLight = Instance.new("PointLight")
    pointLight.Color = color
    pointLight.Brightness = 2.2
    pointLight.Range = 10
    pointLight.Parent = corePart

    -- Billboard Gui with Name and Rarity
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 170, 0, 52)
    billboard.StudsOffset = Vector3.new(0, 2.0, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 50
    billboard.Parent = corePart

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 1, 0)
    card.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    card.BackgroundTransparency = 0.2
    card.BorderSizePixel = 0
    card.Parent = billboard

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 6)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = color
    cardStroke.Thickness = 1.4
    cardStroke.Parent = card

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -12, 0.55, 0)
    nameLabel.Position = UDim2.new(0, 6, 0, 3)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 12
    nameLabel.TextColor3 = Color3.fromRGB(245, 248, 252)
    nameLabel.Text = string.format("%s %s (x%d)", itemDef.IconGlyph, itemDef.Name, quantity)
    nameLabel.Parent = card

    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size = UDim2.new(1, -12, 0.4, 0)
    rarityLabel.Position = UDim2.new(0, 6, 0.55, 0)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Font = Enum.Font.GothamBold
    rarityLabel.TextSize = 10
    rarityLabel.TextColor3 = color
    rarityLabel.Text = string.format("✦ %s ✦", string.upper(itemDef.Rarity))
    rarityLabel.Parent = card

    -- Interactive ClickDetector / Proximity Collection
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 14
    clickDetector.Parent = corePart

    local isCollected = false
    local function TryCollect(player: Player)
        if isCollected then return end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not root then return end

        local dist = (root.Position - corePart.Position).Magnitude
        if dist > 18 then return end

        if onPickupCallback(player) then
            isCollected = true
            pointLight.Enabled = false
            particles.Enabled = false
            billboard.Enabled = false

            -- Pickup Tween Animation
            local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            for _, child in ipairs(dropModel:GetChildren()) do
                if child:IsA("BasePart") then
                    local t = TweenService:Create(child, tweenInfo, {
                        Size = Vector3.new(0.05, 0.05, 0.05),
                        Transparency = 1,
                        Position = child.Position + Vector3.new(0, 1.2, 0)
                    })
                    t:Play()
                end
            end

            task.delay(0.3, function()
                dropModel:Destroy()
            end)
        end
    end

    clickDetector.MouseClick:Connect(TryCollect)

    -- Proximity Heartbeat Check
    task.spawn(function()
        local Players = game:GetService("Players")
        while not isCollected and dropModel.Parent do
            task.wait(0.25)
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                if root then
                    local dist = (root.Position - corePart.Position).Magnitude
                    if dist <= 7 then
                        TryCollect(player)
                        break
                    end
                end
            end
        end
    end)

    -- Floating Animation
    task.spawn(function()
        local startPos = corePart.Position
        local t = 0
        local parts = {}
        for _, p in ipairs(dropModel:GetChildren()) do
            if p:IsA("BasePart") then
                table.insert(parts, { Part = p, LocalOffset = p.Position - startPos, InitCF = p.CFrame })
            end
        end

        while not isCollected and dropModel.Parent do
            local dt = task.wait(0.03)
            t += dt
            local yOffset = math.sin(t * 2.2) * 0.25
            local rotDelta = CFrame.Angles(0, math.rad(dt * 35), 0)

            for _, entry in ipairs(parts) do
                if entry.Part and entry.Part.Parent then
                    local currentOffset = entry.Part.Position - startPos
                    entry.Part.CFrame = entry.Part.CFrame * rotDelta + Vector3.new(0, (yOffset - currentOffset.Y) * 0.1, 0)
                end
            end
        end
    end)

    dropModel.Parent = folder
    Debris:AddItem(dropModel, 600)

    return dropModel
end

return WorldDropService
