--!strict
--[=[
    EquipmentService.luau
    Author: JV (lab2 / lab2SecurityProjectsR)
    Handles visual attachment of equipped weapons and armor to the character model,
    character stat modifiers (WalkSpeed, Defense), and respawn persistence.
    Copyright (c) 2026 JV. All rights reserved.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage.InventorySystem.ItemDatabase)
local InventoryTypes = require(ReplicatedStorage.InventorySystem.InventoryTypes)

type InventorySlot = InventoryTypes.InventorySlot

local EquipmentService = {}
local activeVisuals: { [number]: { Weapon: Instance?, Armor: Instance? } } = {}

local function CleanupVisual(instance: Instance?)
    if instance and instance.Parent then
        instance:Destroy()
    end
end

local function ClearAllEquipmentFromCharacter(character: Model, slotType: "Weapon" | "Armor")
    for _, child in ipairs(character:GetChildren()) do
        if child.Name == "Equipped_" .. slotType then
            child:Destroy()
        end
    end
end

local function BuildWeaponModel(itemDef: any, color: Color3, attachPart: BasePart): Model
    local model = Instance.new("Model")
    model.Name = "Equipped_Weapon"

    local gripCF = attachPart.CFrame * CFrame.new(0, -0.9, 0.4) * CFrame.Angles(math.rad(80), 0, 0)

    if itemDef.Id == "cyber_revolver" then
        -- Sci-Fi Hand Cannon
        local grip = Instance.new("Part")
        grip.Name = "Grip"
        grip.Size = Vector3.new(0.3, 0.8, 0.4)
        grip.Color = Color3.fromRGB(30, 35, 45)
        grip.Material = Enum.Material.DiamondPlate
        grip.CanCollide = false
        grip.Massless = true
        grip.CFrame = gripCF * CFrame.Angles(math.rad(-25), 0, 0)
        grip.Parent = model

        local barrel = Instance.new("Part")
        barrel.Name = "Barrel"
        barrel.Size = Vector3.new(0.35, 0.45, 1.6)
        barrel.Color = Color3.fromRGB(60, 70, 85)
        barrel.Material = Enum.Material.Metal
        barrel.CanCollide = false
        barrel.Massless = true
        barrel.CFrame = gripCF * CFrame.new(0, 0.4, 0.7)
        barrel.Parent = model

        local neonRail = Instance.new("Part")
        neonRail.Name = "NeonRail"
        neonRail.Size = Vector3.new(0.15, 0.15, 1.4)
        neonRail.Color = color
        neonRail.Material = Enum.Material.Neon
        neonRail.CanCollide = false
        neonRail.Massless = true
        neonRail.CFrame = barrel.CFrame * CFrame.new(0, 0.22, 0)
        neonRail.Parent = model

        for _, part in ipairs({ grip, barrel, neonRail }) do
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = attachPart
            weld.Part1 = part
            weld.Parent = part
        end
    else
        -- Blade / Katana / Sword
        local hilt = Instance.new("Part")
        hilt.Name = "Hilt"
        hilt.Size = Vector3.new(0.3, 1.0, 0.3)
        hilt.Color = Color3.fromRGB(25, 28, 35)
        hilt.Material = Enum.Material.DiamondPlate
        hilt.CanCollide = false
        hilt.Massless = true
        hilt.CFrame = gripCF
        hilt.Parent = model

        local guard = Instance.new("Part")
        guard.Name = "Guard"
        guard.Size = Vector3.new(0.7, 0.12, 0.7)
        guard.Color = Color3.fromRGB(245, 185, 40)
        guard.Material = Enum.Material.Metal
        guard.CanCollide = false
        guard.Massless = true
        guard.CFrame = hilt.CFrame * CFrame.new(0, 0.55, 0)
        guard.Parent = model

        local blade = Instance.new("Part")
        blade.Name = "Blade"
        blade.Size = Vector3.new(0.16, 3.2, 0.4)
        blade.Color = color
        blade.Material = Enum.Material.Neon
        blade.CanCollide = false
        blade.Massless = true
        blade.CFrame = guard.CFrame * CFrame.new(0, 1.65, 0)
        blade.Parent = model

        local bladeSpine = Instance.new("Part")
        bladeSpine.Name = "Spine"
        bladeSpine.Size = Vector3.new(0.2, 3.1, 0.2)
        bladeSpine.Color = Color3.fromRGB(80, 90, 105)
        bladeSpine.Material = Enum.Material.Metal
        bladeSpine.CanCollide = false
        bladeSpine.Massless = true
        bladeSpine.CFrame = blade.CFrame * CFrame.new(0, 0, -0.12)
        bladeSpine.Parent = model

        local light = Instance.new("PointLight")
        light.Color = color
        light.Range = 10
        light.Brightness = 2.5
        light.Parent = blade

        for _, part in ipairs({ hilt, guard, blade, bladeSpine }) do
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = attachPart
            weld.Part1 = part
            weld.Parent = part
        end
    end

    return model
end

local function BuildArmorModel(itemDef: any, color: Color3, attachPart: BasePart): Model
    local model = Instance.new("Model")
    model.Name = "Equipped_Armor"

    local baseCF = attachPart.CFrame * CFrame.new(-0.35, 0, 0)

    -- Forearm Generator Clamp
    local generator = Instance.new("Part")
    generator.Name = "Generator"
    generator.Size = Vector3.new(0.5, 0.8, 0.5)
    generator.Color = Color3.fromRGB(35, 40, 50)
    generator.Material = Enum.Material.Metal
    generator.CanCollide = false
    generator.Massless = true
    generator.CFrame = baseCF
    generator.Parent = model

    local genCore = Instance.new("Part")
    genCore.Name = "Core"
    genCore.Size = Vector3.new(0.3, 0.4, 0.3)
    genCore.Color = color
    genCore.Material = Enum.Material.Neon
    genCore.CanCollide = false
    genCore.Massless = true
    genCore.CFrame = generator.CFrame * CFrame.new(-0.25, 0, 0)
    genCore.Parent = model

    -- Hardlight Energy Barrier
    local barrier = Instance.new("Part")
    barrier.Name = "EnergyBarrier"
    barrier.Size = Vector3.new(0.15, 2.8, 2.2)
    barrier.Color = color
    barrier.Material = Enum.Material.ForceField
    barrier.Transparency = 0.25
    barrier.CanCollide = false
    barrier.Massless = true
    barrier.CFrame = genCore.CFrame * CFrame.new(-0.2, 0, 0)
    barrier.Parent = model

    -- Neon Outer Rim
    local rimTop = Instance.new("Part")
    rimTop.Name = "RimTop"
    rimTop.Size = Vector3.new(0.2, 0.15, 2.2)
    rimTop.Color = color
    rimTop.Material = Enum.Material.Neon
    rimTop.CanCollide = false
    rimTop.Massless = true
    rimTop.CFrame = barrier.CFrame * CFrame.new(0, 1.4, 0)
    rimTop.Parent = model

    local rimBottom = Instance.new("Part")
    rimBottom.Name = "RimBottom"
    rimBottom.Size = Vector3.new(0.2, 0.15, 2.2)
    rimBottom.Color = color
    rimBottom.Material = Enum.Material.Neon
    rimBottom.CanCollide = false
    rimBottom.Massless = true
    rimBottom.CFrame = barrier.CFrame * CFrame.new(0, -1.4, 0)
    rimBottom.Parent = model

    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = 10
    light.Brightness = 2
    light.Parent = genCore

    for _, part in ipairs({ generator, genCore, barrier, rimTop, rimBottom }) do
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = attachPart
        weld.Part1 = part
        weld.Parent = part
    end

    return model
end

function EquipmentService.ApplyEquipmentVisual(player: Player, slotType: "Weapon" | "Armor", slotData: InventorySlot?)
    local userId = player.UserId
    activeVisuals[userId] = activeVisuals[userId] or { Weapon = nil, Armor = nil }

    local character = player.Character
    if character then
        ClearAllEquipmentFromCharacter(character, slotType)
    end

    activeVisuals[userId][slotType] = nil

    if not slotData then
        EquipmentService.UpdatePlayerStats(player)
        return
    end

    local itemDef = ItemDatabase.GetItem(slotData.ItemId)
    if not itemDef or not character then return end

    local color = ItemDatabase.GetRarityColor(itemDef.Rarity)

    if slotType == "Weapon" then
        local attachPart = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
        if attachPart and attachPart:IsA("BasePart") then
            local model = BuildWeaponModel(itemDef, color, attachPart)
            model.Parent = character
            activeVisuals[userId].Weapon = model
        end
    elseif slotType == "Armor" then
        local attachPart = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
        if attachPart and attachPart:IsA("BasePart") then
            local model = BuildArmorModel(itemDef, color, attachPart)
            model.Parent = character
            activeVisuals[userId].Armor = model
        end
    end

    EquipmentService.UpdatePlayerStats(player)
end


function EquipmentService.UpdatePlayerStats(player: Player)
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- Base WalkSpeed
    local speedBonus = 0
    local DataSessionManager = require(script.Parent.DataSessionManager)
    local profile = DataSessionManager.GetProfile(player)

    if profile and profile.Equipment then
        if profile.Equipment.Weapon then
            local def = ItemDatabase.GetItem(profile.Equipment.Weapon.ItemId)
            if def and def.Stats and def.Stats.SpeedBoost then
                speedBonus += def.Stats.SpeedBoost
            end
        end
    end

    humanoid.WalkSpeed = 16 + speedBonus
end

function EquipmentService.OnCharacterAdded(player: Player, character: Model)
    task.wait(0.2)
    local DataSessionManager = require(script.Parent.DataSessionManager)
    local profile = DataSessionManager.GetProfile(player)
    if profile and profile.Equipment then
        if profile.Equipment.Weapon then
            EquipmentService.ApplyEquipmentVisual(player, "Weapon", profile.Equipment.Weapon)
        end
        if profile.Equipment.Armor then
            EquipmentService.ApplyEquipmentVisual(player, "Armor", profile.Equipment.Armor)
        end
    end
end

Players.PlayerRemoving:Connect(function(player)
    if activeVisuals[player.UserId] then
        CleanupVisual(activeVisuals[player.UserId].Weapon)
        CleanupVisual(activeVisuals[player.UserId].Armor)
        activeVisuals[player.UserId] = nil
    end
end)

return EquipmentService
