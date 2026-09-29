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

function EquipmentService.ApplyEquipmentVisual(player: Player, slotType: "Weapon" | "Armor", slotData: InventorySlot?)
    local userId = player.UserId
    activeVisuals[userId] = activeVisuals[userId] or { Weapon = nil, Armor = nil }

    -- Clean up previous visual
    CleanupVisual(activeVisuals[userId][slotType])
    activeVisuals[userId][slotType] = nil

    if not slotData then
        EquipmentService.UpdatePlayerStats(player)
        return
    end

    local itemDef = ItemDatabase.GetItem(slotData.ItemId)
    if not itemDef then return end

    local character = player.Character
    if not character then return end

    local color = ItemDatabase.GetRarityColor(itemDef.Rarity)

    if slotType == "Weapon" then
        local attachPart = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
        if attachPart and attachPart:IsA("BasePart") then
            local weaponModel = Instance.new("Part")
            weaponModel.Name = "Equipped_Weapon"
            weaponModel.Size = Vector3.new(0.4, 3.2, 0.6)
            weaponModel.Material = Enum.Material.Neon
            weaponModel.Color = color
            weaponModel.CanCollide = false
            weaponModel.Massless = true

            local weld = Instance.new("WeldConstraint")
            weaponModel.CFrame = attachPart.CFrame * CFrame.new(0, -1.2, 0.4) * CFrame.Angles(math.rad(90), 0, 0)
            weld.Part0 = attachPart
            weld.Part1 = weaponModel
            weld.Parent = weaponModel

            local light = Instance.new("PointLight")
            light.Color = color
            light.Range = 8
            light.Brightness = 2
            light.Parent = weaponModel

            weaponModel.Parent = character
            activeVisuals[userId].Weapon = weaponModel
        end
    elseif slotType == "Armor" then
        local attachPart = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
        if attachPart and attachPart:IsA("BasePart") then
            local shieldModel = Instance.new("Part")
            shieldModel.Name = "Equipped_Armor"
            shieldModel.Size = Vector3.new(1.8, 2.4, 0.3)
            shieldModel.Material = Enum.Material.ForceField
            shieldModel.Color = color
            shieldModel.CanCollide = false
            shieldModel.Massless = true

            local weld = Instance.new("WeldConstraint")
            shieldModel.CFrame = attachPart.CFrame * CFrame.new(-0.3, 0, 0)
            weld.Part0 = attachPart
            weld.Part1 = shieldModel
            weld.Parent = shieldModel

            shieldModel.Parent = character
            activeVisuals[userId].Armor = shieldModel
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
