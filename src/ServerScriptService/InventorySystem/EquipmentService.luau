--!strict
--[=[
    EquipmentService.luau
    Author: JV (lab2 / lab2SecurityProjectsR)
    Handles visual attachment of equipped weapons and armor to the character model,
    procedural combat stances (raising arms in guard/aiming pose), character stat modifiers,
    and respawn persistence. Uses rigid Welds with calibrated offsets so items never drift or drop.
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

-- Helper: Create a wedge part for sharp/beveled katana kissaki
local function CreateWeldedWedge(
    parentModel: Model,
    name: string,
    size: Vector3,
    material: Enum.Material,
    color: Color3,
    attachTo: BasePart,
    c0Offset: CFrame
): WedgePart
    local wedge = Instance.new("WedgePart")
    wedge.Name = name
    wedge.Size = size
    wedge.Material = material
    wedge.Color = color
    wedge.CanCollide = false
    wedge.CanQuery = false
    wedge.CanTouch = false
    wedge.Massless = true
    wedge.CastShadow = false
    wedge.CFrame = attachTo.CFrame * c0Offset
    wedge.Parent = parentModel

    local weld = Instance.new("Weld")
    weld.Name = name .. "_Weld"
    weld.Part0 = attachTo
    weld.Part1 = wedge
    weld.C0 = c0Offset
    weld.C1 = CFrame.identity
    weld.Parent = wedge

    return wedge
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
-- PROCEDURAL COMBAT STANCE (ARM POSING)
-- =========================================================================

local function SetWeaponStance(character: Model, stanceType: "Sword" | "Gun" | "None")
    local rightUpperArm = character:FindFirstChild("RightUpperArm")
    local rightLowerArm = character:FindFirstChild("RightLowerArm")
    local rightShoulder = rightUpperArm and rightUpperArm:FindFirstChild("RightShoulder") :: Motor6D?
    local rightElbow = rightLowerArm and rightLowerArm:FindFirstChild("RightElbow") :: Motor6D?

    if not rightShoulder then return end

    if not rightShoulder:GetAttribute("DefaultC0") then
        rightShoulder:SetAttribute("DefaultC0", rightShoulder.C0)
    end
    if rightElbow and not rightElbow:GetAttribute("DefaultC0") then
        rightElbow:SetAttribute("DefaultC0", rightElbow.C0)
    end

    local defaultShoulderC0 = rightShoulder:GetAttribute("DefaultC0") :: CFrame
    local defaultElbowC0 = rightElbow and rightElbow:GetAttribute("DefaultC0") :: CFrame?

    if stanceType == "Sword" then
        -- Sword Combat Stance: Arm raised, elbow bent 35 degrees, sword held proudly upright in front of chest
        rightShoulder.C0 = defaultShoulderC0 * CFrame.Angles(math.rad(72), math.rad(-18), math.rad(12))
        if rightElbow and defaultElbowC0 then
            rightElbow.C0 = defaultElbowC0 * CFrame.Angles(math.rad(-38), 0, 0)
        end
    elseif stanceType == "Gun" then
        -- Tactical Aim Stance: Arm raised forward in firing position
        rightShoulder.C0 = defaultShoulderC0 * CFrame.Angles(math.rad(85), math.rad(-8), math.rad(4))
        if rightElbow and defaultElbowC0 then
            rightElbow.C0 = defaultElbowC0 * CFrame.Angles(math.rad(-12), 0, 0)
        end
    else
        -- Relaxed Stance: Restore default
        rightShoulder.C0 = defaultShoulderC0
        if rightElbow and defaultElbowC0 then
            rightElbow.C0 = defaultElbowC0
        end
    end
end

local function SetShieldStance(character: Model, hasShield: boolean)
    local leftUpperArm = character:FindFirstChild("LeftUpperArm")
    local leftLowerArm = character:FindFirstChild("LeftLowerArm")
    local leftShoulder = leftUpperArm and leftUpperArm:FindFirstChild("LeftShoulder") :: Motor6D?
    local leftElbow = leftLowerArm and leftLowerArm:FindFirstChild("LeftElbow") :: Motor6D?

    if not leftShoulder then return end

    if not leftShoulder:GetAttribute("DefaultC0") then
        leftShoulder:SetAttribute("DefaultC0", leftShoulder.C0)
    end
    if leftElbow and not leftElbow:GetAttribute("DefaultC0") then
        leftElbow:SetAttribute("DefaultC0", leftElbow.C0)
    end

    local defaultLeftShoulderC0 = leftShoulder:GetAttribute("DefaultC0") :: CFrame
    local defaultLeftElbowC0 = leftElbow and leftElbow:GetAttribute("DefaultC0") :: CFrame?

    if hasShield then
        -- Shield Guard Stance: Forearm raised across the chest to defend
        leftShoulder.C0 = defaultLeftShoulderC0 * CFrame.Angles(math.rad(45), math.rad(22), math.rad(-12))
        if leftElbow and defaultLeftElbowC0 then
            leftElbow.C0 = defaultLeftElbowC0 * CFrame.Angles(math.rad(-42), 0, 0)
        end
    else
        leftShoulder.C0 = defaultLeftShoulderC0
        if leftElbow and defaultLeftElbowC0 then
            leftElbow.C0 = defaultLeftElbowC0
        end
    end
end

-- =========================================================================
-- WEAPON BUILDERS (HIGH-PRECISION 3D MODELS)
-- =========================================================================

local function BuildWeaponModel(itemDef: any, color: Color3, hand: BasePart): Model
    local model = Instance.new("Model")
    model.Name = "Equipped_Weapon"

    -- Find RightGripAttachment or fallback
    local gripAttachment = hand:FindFirstChild("RightGripAttachment") :: Attachment?
    local gripCF = gripAttachment and gripAttachment.CFrame or CFrame.new(0, -0.9, 0)

    if itemDef.Id == "cyber_revolver" then
        -- CYBER REVOLVER: Heavy electromagnetic hand cannon
        -- Barrel points forward (-Z), grip sits firmly in the palm
        local baseCF = gripCF * CFrame.new(0, -0.1, 0.05)

        -- Textured Grip (angled 18 degrees back)
        CreateWeldedPart(
            model, "Grip",
            Vector3.new(0.3, 0.8, 0.38),
            Enum.Material.DiamondPlate,
            Color3.fromRGB(24, 28, 36),
            hand,
            baseCF * CFrame.Angles(math.rad(-18), 0, 0)
        )

        -- Grip Base Diode
        CreateWeldedPart(
            model, "GripBase",
            Vector3.new(0.32, 0.12, 0.4),
            Enum.Material.Neon,
            color,
            hand,
            baseCF * CFrame.new(0, -0.42, 0.14) * CFrame.Angles(math.rad(-18), 0, 0)
        )

        -- Receiver Frame
        local receiver = CreateWeldedPart(
            model, "Receiver",
            Vector3.new(0.38, 0.5, 0.72),
            Enum.Material.Metal,
            Color3.fromRGB(50, 60, 75),
            hand,
            baseCF * CFrame.new(0, 0.45, -0.2)
        )

        -- Revolver Cylinder (with 6 glowing plasma chambers)
        CreateWeldedPart(
            model, "CylinderFrame",
            Vector3.new(0.44, 0.44, 0.46),
            Enum.Material.Metal,
            Color3.fromRGB(30, 36, 46),
            hand,
            baseCF * CFrame.new(0, 0.45, -0.2)
        )
        CreateWeldedPart(
            model, "PlasmaCore",
            Vector3.new(0.4, 0.4, 0.42),
            Enum.Material.Neon,
            color,
            hand,
            baseCF * CFrame.new(0, 0.45, -0.2)
        )

        -- Fluted Barrel (Extends forward along -Z)
        local barrel = CreateWeldedPart(
            model, "Barrel",
            Vector3.new(0.28, 0.38, 1.3),
            Enum.Material.Metal,
            Color3.fromRGB(42, 50, 64),
            hand,
            baseCF * CFrame.new(0, 0.5, -1.1)
        )

        -- Ported Muzzle Brake at the tip
        CreateWeldedPart(
            model, "MuzzleBrake",
            Vector3.new(0.32, 0.42, 0.28),
            Enum.Material.Metal,
            Color3.fromRGB(65, 75, 90),
            hand,
            baseCF * CFrame.new(0, 0.5, -1.85)
        )

        -- Tactical Top Rail & Illuminated Fiber-Optic Sights
        CreateWeldedPart(
            model, "TopRail",
            Vector3.new(0.12, 0.08, 1.5),
            Enum.Material.Metal,
            Color3.fromRGB(30, 36, 46),
            hand,
            baseCF * CFrame.new(0, 0.74, -0.8)
        )
        CreateWeldedPart(
            model, "FrontSight",
            Vector3.new(0.08, 0.14, 0.12),
            Enum.Material.Neon,
            color,
            hand,
            baseCF * CFrame.new(0, 0.8, -1.75)
        )

        -- Underbarrel Laser Targeting Diode
        CreateWeldedPart(
            model, "LaserDiode",
            Vector3.new(0.14, 0.14, 0.5),
            Enum.Material.Metal,
            Color3.fromRGB(35, 42, 54),
            hand,
            baseCF * CFrame.new(0, 0.22, -1.1)
        )
        CreateWeldedPart(
            model, "LaserEmitter",
            Vector3.new(0.08, 0.08, 0.08),
            Enum.Material.Neon,
            Color3.fromRGB(239, 68, 68),
            hand,
            baseCF * CFrame.new(0, 0.22, -1.36)
        )

        -- Muzzle Flash / Ambient Light
        local light = Instance.new("PointLight")
        light.Color = color
        light.Range = 8
        light.Brightness = 1.8
        light.Parent = barrel

    elseif itemDef.Id == "iron_broadsword" then
        -- IRON BROADSWORD: Heavy forged steel blade
        -- Blade extends UPWARDS (+Y) out of the top of the hand
        local baseCF = gripCF

        -- Leather-Wrapped Grip
        CreateWeldedPart(
            model, "Grip",
            Vector3.new(0.26, 1.1, 0.28),
            Enum.Material.SmoothPlastic,
            Color3.fromRGB(55, 38, 26),
            hand,
            baseCF * CFrame.new(0, 0, 0)
        )

        -- Steel Pommel
        CreateWeldedPart(
            model, "Pommel",
            Vector3.new(0.38, 0.3, 0.38),
            Enum.Material.Metal,
            Color3.fromRGB(180, 185, 195),
            hand,
            baseCF * CFrame.new(0, -0.65, 0)
        )

        -- Ornate Crossguard
        CreateWeldedPart(
            model, "Crossguard",
            Vector3.new(1.5, 0.22, 0.35),
            Enum.Material.Metal,
            Color3.fromRGB(200, 170, 70),
            hand,
            baseCF * CFrame.new(0, 0.6, 0)
        )

        -- Steel Blade (UPWARDS along +Y)
        CreateWeldedPart(
            model, "SteelBlade",
            Vector3.new(0.1, 3.4, 0.45),
            Enum.Material.Metal,
            Color3.fromRGB(215, 222, 232),
            hand,
            baseCF * CFrame.new(0, 2.35, 0)
        )

        -- Blade Tip (Wedge)
        CreateWeldedWedge(
            model, "BladeTip",
            Vector3.new(0.1, 0.5, 0.45),
            Enum.Material.Metal,
            Color3.fromRGB(215, 222, 232),
            hand,
            baseCF * CFrame.new(0, 4.2, 0) * CFrame.Angles(0, math.rad(90), 0)
        )

    else
        -- DEFAULT: PLASMA KATANA (Elite High-Frequency Energy Blade)
        -- Blade extends UPWARDS (+Y) out of the top of the fist, towering upright
        local baseCF = gripCF

        -- Handle (Tsuka): Dark Obsidian Carbon Fiber with Diamond Pattern
        CreateWeldedPart(
            model, "TsukaGrip",
            Vector3.new(0.24, 1.1, 0.28),
            Enum.Material.DiamondPlate,
            Color3.fromRGB(22, 25, 32),
            hand,
            baseCF * CFrame.new(0, 0, 0)
        )

        -- Gold Wrap Bands (Ito Wrap Accents)
        for i, yOffset in ipairs({ -0.25, 0, 0.25 }) do
            CreateWeldedPart(
                model, "WrapBand_" .. i,
                Vector3.new(0.26, 0.08, 0.3),
                Enum.Material.Metal,
                Color3.fromRGB(215, 175, 55),
                hand,
                baseCF * CFrame.new(0, yOffset, 0)
            )
        end

        -- Pommel Cap (Kashira) with glowing cyan inset diode
        CreateWeldedPart(
            model, "Kashira",
            Vector3.new(0.28, 0.16, 0.32),
            Enum.Material.Metal,
            Color3.fromRGB(50, 60, 75),
            hand,
            baseCF * CFrame.new(0, -0.6, 0)
        )
        CreateWeldedPart(
            model, "KashiraDiode",
            Vector3.new(0.14, 0.06, 0.16),
            Enum.Material.Neon,
            color,
            hand,
            baseCF * CFrame.new(0, -0.68, 0)
        )

        -- Blade Collar (Habaki): Polished Brass
        CreateWeldedPart(
            model, "Habaki",
            Vector3.new(0.26, 0.14, 0.32),
            Enum.Material.Metal,
            Color3.fromRGB(230, 185, 60),
            hand,
            baseCF * CFrame.new(0, 0.62, 0)
        )

        -- Layered Energy Guard (Tsuba)
        CreateWeldedPart(
            model, "TsubaBase",
            Vector3.new(0.72, 0.08, 0.72),
            Enum.Material.Metal,
            Color3.fromRGB(40, 48, 60),
            hand,
            baseCF * CFrame.new(0, 0.54, 0)
        )
        CreateWeldedPart(
            model, "TsubaRing",
            Vector3.new(0.64, 0.1, 0.64),
            Enum.Material.Neon,
            color,
            hand,
            baseCF * CFrame.new(0, 0.54, 0)
        )

        -- Main Plasma Blade: Extends UPWARDS (+Y) out of the top of the hand!
        -- Length: 3.4 studs along Y, Width: 0.38 studs, Thickness: 0.08 studs
        local blade = CreateWeldedPart(
            model, "PlasmaBlade",
            Vector3.new(0.08, 3.4, 0.36),
            Enum.Material.Neon,
            color,
            hand,
            baseCF * CFrame.new(0, 2.38, -0.04)
        )

        -- Dark Titanium Spine (Mune) along the back of the blade
        CreateWeldedPart(
            model, "BladeSpine",
            Vector3.new(0.12, 3.4, 0.12),
            Enum.Material.Metal,
            Color3.fromRGB(48, 56, 70),
            hand,
            baseCF * CFrame.new(0, 2.38, 0.13)
        )

        -- Kissaki: Curved, angled sharp Katana Tip at the top
        CreateWeldedWedge(
            model, "KissakiTip",
            Vector3.new(0.08, 0.55, 0.36),
            Enum.Material.Neon,
            color,
            hand,
            baseCF * CFrame.new(0, 4.35, -0.04) * CFrame.Angles(0, math.rad(90), 0)
        )

        -- Radiant Energy Glow & PointLight
        local light = Instance.new("PointLight")
        light.Color = color
        light.Range = 9
        light.Brightness = 2.2
        light.Parent = blade

        -- Hyper-Frequency Spark Particles
        local sparks = Instance.new("ParticleEmitter")
        sparks.Color = ColorSequence.new(color)
        sparks.LightEmission = 1
        sparks.Size = NumberSequence.new(0.14, 0.02)
        sparks.Lifetime = NumberRange.new(0.15, 0.35)
        sparks.Rate = 6
        sparks.Speed = NumberRange.new(0.8, 1.8)
        sparks.SpreadAngle = Vector2.new(35, 35)
        sparks.Parent = blade
    end

    return model
end

-- =========================================================================
-- ARMOR BUILDERS (HIGH-PRECISION 3D MODELS)
-- =========================================================================

local function BuildArmorModel(itemDef: any, color: Color3, character: Model): Model
    local model = Instance.new("Model")
    model.Name = "Equipped_Armor"

    if itemDef.Id == "nano_vest" then
        -- NANOTECH BODY ARMOR: Multi-panel tactical cyber suit
        local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
        if not torso or not torso:IsA("BasePart") then return model end

        -- Front ChestPlate: Contoured ballistic armor
        local chest = CreateWeldedPart(
            model, "ChestPlate",
            Vector3.new(2.1, 1.75, 0.32),
            Enum.Material.DiamondPlate,
            Color3.fromRGB(22, 26, 36),
            torso,
            CFrame.new(0, 0.05, -0.56)
        )

        -- Arc Reactor Core: Layered housing with pulsing core
        CreateWeldedPart(
            model, "ReactorHousing",
            Vector3.new(0.68, 0.68, 0.08),
            Enum.Material.Metal,
            Color3.fromRGB(48, 56, 72),
            torso,
            CFrame.new(0, 0.15, -0.68)
        )
        local reactor = CreateWeldedPart(
            model, "ReactorCore",
            Vector3.new(0.52, 0.52, 0.14),
            Enum.Material.Neon,
            color,
            torso,
            CFrame.new(0, 0.15, -0.72)
        )

        -- Energy Conduits routing power across the clavicles
        CreateWeldedPart(
            model, "ConduitLeft",
            Vector3.new(0.65, 0.08, 0.06),
            Enum.Material.Neon,
            color,
            torso,
            CFrame.new(-0.55, 0.28, -0.71) * CFrame.Angles(0, 0, math.rad(25))
        )
        CreateWeldedPart(
            model, "ConduitRight",
            Vector3.new(0.65, 0.08, 0.06),
            Enum.Material.Neon,
            color,
            torso,
            CFrame.new(0.55, 0.28, -0.71) * CFrame.Angles(0, 0, math.rad(-25))
        )

        -- Back Spinal Stabilizer Unit
        CreateWeldedPart(
            model, "BackPlate",
            Vector3.new(2.1, 1.75, 0.32),
            Enum.Material.DiamondPlate,
            Color3.fromRGB(22, 26, 36),
            torso,
            CFrame.new(0, 0.05, 0.56)
        )
        CreateWeldedPart(
            model, "SpinalCore",
            Vector3.new(0.24, 1.4, 0.08),
            Enum.Material.Neon,
            color,
            torso,
            CFrame.new(0, 0.1, 0.72)
        )

        -- Dual Heatsink Cooling Radiators
        CreateWeldedPart(
            model, "ExhaustL",
            Vector3.new(0.35, 0.55, 0.14),
            Enum.Material.Metal,
            Color3.fromRGB(45, 54, 68),
            torso,
            CFrame.new(-0.6, 0.25, 0.72)
        )
        CreateWeldedPart(
            model, "ExhaustR",
            Vector3.new(0.35, 0.55, 0.14),
            Enum.Material.Metal,
            Color3.fromRGB(45, 54, 68),
            torso,
            CFrame.new(0.6, 0.25, 0.72)
        )

        -- Articulated Shoulder Pauldrons (Mounted on Upper Arms for natural walking motion)
        local leftArm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm")
        if leftArm and leftArm:IsA("BasePart") then
            CreateWeldedPart(
                model, "LeftPauldron",
                Vector3.new(1.15, 0.42, 1.15),
                Enum.Material.DiamondPlate,
                Color3.fromRGB(26, 32, 44),
                leftArm,
                CFrame.new(0.12, 0.55, 0)
            )
            CreateWeldedPart(
                model, "LeftPauldronTrim",
                Vector3.new(1.18, 0.08, 1.18),
                Enum.Material.Neon,
                color,
                leftArm,
                CFrame.new(0.12, 0.74, 0)
            )
        end

        local rightArm = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
        if rightArm and rightArm:IsA("BasePart") then
            CreateWeldedPart(
                model, "RightPauldron",
                Vector3.new(1.15, 0.42, 1.15),
                Enum.Material.DiamondPlate,
                Color3.fromRGB(26, 32, 44),
                rightArm,
                CFrame.new(-0.12, 0.55, 0)
            )
            CreateWeldedPart(
                model, "RightPauldronTrim",
                Vector3.new(1.18, 0.08, 1.18),
                Enum.Material.Neon,
                color,
                rightArm,
                CFrame.new(-0.12, 0.74, 0)
            )
        end

        -- Reactor PointLight
        local light = Instance.new("PointLight")
        light.Color = color
        light.Range = 8
        light.Brightness = 2.4
        light.Parent = reactor

    else
        -- AEGIS BULWARK: Advanced Forearm Energy Shield
        local forearm = character:FindFirstChild("LeftLowerArm") or character:FindFirstChild("Left Arm")
        if not forearm or not forearm:IsA("BasePart") then return model end

        -- Hydraulic Gauntlet Clamp around outer forearm
        CreateWeldedPart(
            model, "BracerClamp",
            Vector3.new(0.4, 0.8, 0.48),
            Enum.Material.Metal,
            Color3.fromRGB(32, 40, 52),
            forearm,
            CFrame.new(0.52, -0.1, -0.1)
        )

        -- Hexagonal Hardlight Emitter Core
        local core = CreateWeldedPart(
            model, "EmitterCore",
            Vector3.new(0.24, 0.4, 0.4),
            Enum.Material.Neon,
            color,
            forearm,
            CFrame.new(0.7, -0.1, -0.1)
        )

        -- Holographic ForceField Barrier (Facing FORWARD to protect player)
        local barrier = CreateWeldedPart(
            model, "ForceFieldBarrier",
            Vector3.new(2.4, 3.2, 0.08),
            Enum.Material.ForceField,
            color,
            forearm,
            CFrame.new(0.58, -0.1, -0.6)
        )
        barrier.Transparency = 0.3

        -- Top & Bottom Bezel Wings
        CreateWeldedPart(
            model, "BezelTop",
            Vector3.new(2.5, 0.14, 0.18),
            Enum.Material.Neon,
            color,
            forearm,
            CFrame.new(0.58, 1.45, -0.6)
        )
        CreateWeldedPart(
            model, "BezelBottom",
            Vector3.new(2.5, 0.14, 0.18),
            Enum.Material.Neon,
            color,
            forearm,
            CFrame.new(0.58, -1.65, -0.6)
        )

        -- Shield Glow
        local light = Instance.new("PointLight")
        light.Color = color
        light.Range = 10
        light.Brightness = 2.4
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
        -- Unequipped: Reset Stances
        if character then
            if slotType == "Weapon" then
                SetWeaponStance(character, "None")
            elseif slotType == "Armor" then
                SetShieldStance(character, false)
            end
        end
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

            -- Apply Stance
            if itemDef.Id == "cyber_revolver" then
                SetWeaponStance(character, "Gun")
            else
                SetWeaponStance(character, "Sword")
            end
        end
    elseif slotType == "Armor" then
        local model = BuildArmorModel(itemDef, color, character)
        model.Parent = character
        activeVisuals[userId].Armor = model

        -- Apply Shield Stance if equipping Aegis Bulwark
        if itemDef.Id == "aegis_bulwark" then
            SetShieldStance(character, true)
        else
            SetShieldStance(character, false)
        end
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
