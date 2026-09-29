--!strict
--[=[
    EquipmentService.luau
    Author: JV (lab2 / lab2SecurityProjectsR)
    Handles visual attachment of equipped weapons and armor to the character model,
    character stat modifiers (WalkSpeed, Defense), and respawn persistence.
    Uses standard rigid Welds with calibrated offsets so items never drift or drop.
    Copyright (c) 2026 JV. All rights reserved.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage.InventorySystem.ItemDatabase)
local InventoryTypes = require(ReplicatedStorage.InventorySystem.InventoryTypes)

type InventorySlot = InventoryTypes.InventorySlot

local EquipmentService = {}
local activeVisuals: { [number]: { Weapon: Model?, Armor: Model? } } = {}

-- Helper: Create a rigidly welded part
local function CreateWeldedPart(
    parentModel: Model,
    name: string,
    size: Vector3,
    material: Enum.Material,
    color: Color3,
    attachTo: BasePart,
    c0Offset: CFrame
): BasePart
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Material = material
    part.Color = color
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Massless = true
    part.CastShadow = false
    part.CFrame = attachTo.CFrame * c0Offset
    part.Parent = parentModel

    local weld = Instance.new("Weld")
    weld.Name = name .. "_Weld"
    weld.Part0 = attachTo
    weld.Part1 = part
    weld.C0 = c0Offset
    weld.C1 = CFrame.identity
    weld.Parent = part

    return part
end

local function CleanupVisual(instance: Instance?)
    if instance and instance.Parent then
        instance:Destroy()
    end
end

local function ClearAllEquipmentFromCharacter(character: Model, slotType: "Weapon" | "Armor")
    for _, child in ipairs(character:GetChildren()) do
        if slotType == "Weapon" then
            if child.Name == "Equipped_Weapon" or child.Name:find("Equipped_Weapon") then
                child:Destroy()
            elseif child:IsA("Tool") and child.Name:find("Equipped") then
                child:Destroy()
            end
        elseif slotType == "Armor" then
            if child.Name == "Equipped_Armor" or child.Name:find("Equipped_Armor") then
                child:Destroy()
            end
        end
    end
end

-- =========================================================================
-- WEAPON BUILDERS
-- =========================================================================

local function BuildWeaponModel(itemDef: any, color: Color3, hand: BasePart): Model
    local model = Instance.new("Model")
    model.Name = "Equipped_Weapon"

    -- Find RightGripAttachment or fallback
    local gripAttachment = hand:FindFirstChild("RightGripAttachment") :: Attachment?
    local baseGripCF = gripAttachment and gripAttachment.CFrame or CFrame.new(0, -0.9, 0)

    if itemDef.Id == "cyber_revolver" then
        -- Cyber Revolver Hand Cannon
        -- Held in hand, barrel pointing forward (-Z)
        local gripOffset = baseGripCF * CFrame.new(0, -0.15, 0.1)

        -- Handle / Grip
        local handle = CreateWeldedPart(
            model, "Grip",
            Vector3.new(0.3, 0.75, 0.38),
            Enum.Material.DiamondPlate,
            Color3.fromRGB(28, 32, 42),
            hand,
            gripOffset * CFrame.Angles(math.rad(-15), 0, 0)
        )

        -- Receiver Frame
        local receiver = CreateWeldedPart(
            model, "Receiver",
            Vector3.new(0.38, 0.45, 0.65),
            Enum.Material.Metal,
            Color3.fromRGB(55, 65, 80),
            hand,
            gripOffset * CFrame.new(0, 0.45, -0.2)
        )

        -- Glowing Cylinder (Plasma Cell)
        local cylinder = CreateWeldedPart(
            model, "PlasmaCylinder",
            Vector3.new(0.42, 0.32, 0.42),
            Enum.Material.Neon,
            color,
            hand,
            gripOffset * CFrame.new(0, 0.45, -0.18)
        )

        -- Heavy Barrel
        local barrel = CreateWeldedPart(
            model, "Barrel",
            Vector3.new(0.28, 0.38, 1.2),
            Enum.Material.Metal,
            Color3.fromRGB(45, 52, 65),
            hand,
            gripOffset * CFrame.new(0, 0.48, -1.05)
        )

        -- Top Rail & Glow Sight
        local rail = CreateWeldedPart(
            model, "SightRail",
            Vector3.new(0.12, 0.08, 1.4),
            Enum.Material.Neon,
            color,
            hand,
            gripOffset * CFrame.new(0, 0.7, -0.75)
        )

        -- Muzzle Light
        local light = Instance.new("PointLight")
        light.Color = color
        light.Range = 8
        light.Brightness = 2
        light.Parent = barrel

    elseif itemDef.Id == "iron_broadsword" then
        -- Classic Heavy Broadsword
        -- Blade points forward and angled up 30 degrees
        local swordAngle = CFrame.Angles(math.rad(-30), 0, 0)
        local swordBase = baseGripCF * CFrame.new(0, 0, 0.2) * swordAngle

        -- Grip / Handle
        local handle = CreateWeldedPart(
            model, "Grip",
            Vector3.new(0.25, 0.3, 1.1),
            Enum.Material.SmoothPlastic,
            Color3.fromRGB(50, 35, 25),
            hand,
            swordBase
        )

        -- Pommel
        CreateWeldedPart(
            model, "Pommel",
            Vector3.new(0.4, 0.4, 0.25),
            Enum.Material.Metal,
            Color3.fromRGB(180, 185, 195),
            hand,
            swordBase * CFrame.new(0, 0, 0.6)
        )

        -- Crossguard
        CreateWeldedPart(
            model, "Crossguard",
            Vector3.new(1.4, 0.25, 0.22),
            Enum.Material.Metal,
            Color3.fromRGB(200, 175, 70),
            hand,
            swordBase * CFrame.new(0, 0, -0.6)
        )

        -- Steel Blade
        CreateWeldedPart(
            model, "SteelBlade",
            Vector3.new(0.12, 0.45, 3.2),
            Enum.Material.Metal,
            Color3.fromRGB(215, 220, 230),
            hand,
            swordBase * CFrame.new(0, 0.05, -2.25)
        )

    else
        -- Default: Plasma Katana (High-Tech Energy Blade)
        -- Blade points forward and angled up 35 degrees (combat ready samurai draw stance)
        local swordAngle = CFrame.Angles(math.rad(-35), 0, 0)
        local swordBase = baseGripCF * CFrame.new(0, 0, 0.2) * swordAngle

        -- Handle (Tsuka - Carbon Weave)
        local handle = CreateWeldedPart(
            model, "Grip",
            Vector3.new(0.24, 0.28, 1.1),
            Enum.Material.DiamondPlate,
            Color3.fromRGB(24, 28, 36),
            hand,
            swordBase
        )

        -- Pommel Cap (Kashira) with glowing energy pip
        CreateWeldedPart(
            model, "Pommel",
            Vector3.new(0.3, 0.35, 0.2),
            Enum.Material.Neon,
            color,
            hand,
            swordBase * CFrame.new(0, 0, 0.6)
        )

        -- Energy Guard (Tsuba)
        CreateWeldedPart(
            model, "Tsuba",
            Vector3.new(0.65, 0.65, 0.12),
            Enum.Material.Metal,
            Color3.fromRGB(245, 185, 40),
            hand,
            swordBase * CFrame.new(0, 0, -0.6)
        )

        -- Glowing Plasma Blade Edge
        local blade = CreateWeldedPart(
            model, "PlasmaBlade",
            Vector3.new(0.1, 0.4, 3.5),
            Enum.Material.Neon,
            color,
            hand,
            swordBase * CFrame.new(0, 0.05, -2.4)
        )

        -- Dark Titanium Spine
        CreateWeldedPart(
            model, "BladeSpine",
            Vector3.new(0.14, 0.14, 3.5),
            Enum.Material.Metal,
            Color3.fromRGB(51, 65, 85),
            hand,
            swordBase * CFrame.new(0, 0.23, -2.4)
        )

        -- Ambient Lighting
        local light = Instance.new("PointLight")
        light.Color = color
        light.Range = 10
        light.Brightness = 2.5
        light.Parent = blade

        -- Plasma Energy Sparks
        local sparks = Instance.new("ParticleEmitter")
        sparks.Color = ColorSequence.new(color)
        sparks.LightEmission = 1
        sparks.Size = NumberSequence.new(0.15, 0.02)
        sparks.Lifetime = NumberRange.new(0.2, 0.4)
        sparks.Rate = 5
        sparks.Speed = NumberRange.new(1, 2)
        sparks.SpreadAngle = Vector2.new(45, 45)
        sparks.Parent = blade
    end

    return model
end

-- =========================================================================
-- ARMOR BUILDERS
-- =========================================================================

local function BuildArmorModel(itemDef: any, color: Color3, character: Model): Model
    local model = Instance.new("Model")
    model.Name = "Equipped_Armor"

    if itemDef.Id == "nano_vest" then
        -- Torso Cyber Armor Suit
        local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
        if not torso or not torso:IsA("BasePart") then return model end

        -- Front ChestPlate
        local chest = CreateWeldedPart(
            model, "ChestPlate",
            Vector3.new(2.1, 1.75, 0.3),
            Enum.Material.DiamondPlate,
            Color3.fromRGB(24, 28, 38),
            torso,
            CFrame.new(0, 0.05, -0.56)
        )

        -- Arc Reactor Core (Chest Center)
        local reactor = CreateWeldedPart(
            model, "ReactorCore",
            Vector3.new(0.55, 0.55, 0.12),
            Enum.Material.Neon,
            color,
            torso,
            CFrame.new(0, 0.15, -0.72)
        )

        -- Energy Conduits across chest
        CreateWeldedPart(
            model, "ConduitLeft",
            Vector3.new(0.65, 0.08, 0.06),
            Enum.Material.Neon,
            color,
            torso,
            CFrame.new(-0.55, 0.25, -0.71) * CFrame.Angles(0, 0, math.rad(25))
        )
        CreateWeldedPart(
            model, "ConduitRight",
            Vector3.new(0.65, 0.08, 0.06),
            Enum.Material.Neon,
            color,
            torso,
            CFrame.new(0.55, 0.25, -0.71) * CFrame.Angles(0, 0, math.rad(-25))
        )

        -- Back Spinal Armor
        local back = CreateWeldedPart(
            model, "BackPlate",
            Vector3.new(2.1, 1.75, 0.3),
            Enum.Material.DiamondPlate,
            Color3.fromRGB(24, 28, 38),
            torso,
            CFrame.new(0, 0.05, 0.56)
        )

        -- Spinal Energy Channel
        CreateWeldedPart(
            model, "SpinalConduit",
            Vector3.new(0.22, 1.3, 0.08),
            Enum.Material.Neon,
            color,
            torso,
            CFrame.new(0, 0.1, 0.71)
        )

        -- Dual Heatsink Exhausts
        CreateWeldedPart(
            model, "ExhaustLeft",
            Vector3.new(0.35, 0.55, 0.12),
            Enum.Material.Metal,
            Color3.fromRGB(45, 52, 65),
            torso,
            CFrame.new(-0.6, 0.25, 0.72)
        )
        CreateWeldedPart(
            model, "ExhaustRight",
            Vector3.new(0.35, 0.55, 0.12),
            Enum.Material.Metal,
            Color3.fromRGB(45, 52, 65),
            torso,
            CFrame.new(0.6, 0.25, 0.72)
        )

        -- Shoulder Pauldrons (Mounted to Upper Arms for natural movement)
        local leftArm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm")
        if leftArm and leftArm:IsA("BasePart") then
            CreateWeldedPart(
                model, "LeftPauldron",
                Vector3.new(1.15, 0.4, 1.15),
                Enum.Material.DiamondPlate,
                Color3.fromRGB(28, 32, 45),
                leftArm,
                CFrame.new(0.12, 0.55, 0)
            )
            CreateWeldedPart(
                model, "LeftPauldronTrim",
                Vector3.new(1.18, 0.08, 1.18),
                Enum.Material.Neon,
                color,
                leftArm,
                CFrame.new(0.12, 0.72, 0)
            )
        end

        local rightArm = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
        if rightArm and rightArm:IsA("BasePart") then
            CreateWeldedPart(
                model, "RightPauldron",
                Vector3.new(1.15, 0.4, 1.15),
                Enum.Material.DiamondPlate,
                Color3.fromRGB(28, 32, 45),
                rightArm,
                CFrame.new(-0.12, 0.55, 0)
            )
            CreateWeldedPart(
                model, "RightPauldronTrim",
                Vector3.new(1.18, 0.08, 1.18),
                Enum.Material.Neon,
                color,
                rightArm,
                CFrame.new(-0.12, 0.72, 0)
            )
        end

        -- Reactor Core Glow
        local light = Instance.new("PointLight")
        light.Color = color
        light.Range = 8
        light.Brightness = 2.5
        light.Parent = reactor

    else
        -- Aegis Bulwark (Forearm Energy Shield)
        local forearm = character:FindFirstChild("LeftLowerArm") or character:FindFirstChild("Left Arm")
        if not forearm or not forearm:IsA("BasePart") then return model end

        -- Bracer Clamp on outer forearm
        -- In R15 LeftLowerArm: +X is outer (away from body), -Z is forward
        local bracer = CreateWeldedPart(
            model, "Bracer",
            Vector3.new(0.35, 0.75, 0.45),
            Enum.Material.Metal,
            Color3.fromRGB(35, 42, 54),
            forearm,
            CFrame.new(0.52, -0.15, -0.15)
        )

        -- Hex Generator Core
        local core = CreateWeldedPart(
            model, "GeneratorCore",
            Vector3.new(0.2, 0.35, 0.35),
            Enum.Material.Neon,
            color,
            forearm,
            CFrame.new(0.68, -0.15, -0.15)
        )

        -- Hardlight Barrier (Facing FORWARD to block incoming attacks)
        local barrier = CreateWeldedPart(
            model, "EnergyBarrier",
            Vector3.new(2.4, 2.8, 0.1),
            Enum.Material.ForceField,
            color,
            forearm,
            CFrame.new(0.55, -0.15, -0.55)
        )
        barrier.Transparency = 0.3

        -- Top and Bottom Reinforcement Wings
        CreateWeldedPart(
            model, "BezelTop",
            Vector3.new(2.5, 0.14, 0.18),
            Enum.Material.Neon,
            color,
            forearm,
            CFrame.new(0.55, 1.25, -0.55)
        )
        CreateWeldedPart(
            model, "BezelBottom",
            Vector3.new(2.5, 0.14, 0.18),
            Enum.Material.Neon,
            color,
            forearm,
            CFrame.new(0.55, -1.55, -0.55)
        )

        -- Shield Light
        local light = Instance.new("PointLight")
        light.Color = color
        light.Range = 10
        light.Brightness = 2.5
        light.Parent = core
    end

    return model
end

-- =========================================================================
-- PUBLIC API
-- =========================================================================

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
        local model = BuildArmorModel(itemDef, color, character)
        model.Parent = character
        activeVisuals[userId].Armor = model
    end

    EquipmentService.UpdatePlayerStats(player)
end

function EquipmentService.UpdatePlayerStats(player: Player)
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

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
    character:WaitForChild("HumanoidRootPart", 5)
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
