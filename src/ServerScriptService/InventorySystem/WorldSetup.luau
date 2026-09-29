--!strict
--[=[
    WorldSetup.luau
    Author: JV (lab2 / lab2SecurityProjectsR)
    Provisions a AAA-grade Sci-Fi Holo-Hangar testing facility.
    Features cinematic atmospheric lighting, post-processing bloom,
    tactical modular architecture, recessed energy conduits, and interactive holographic pedestals.
    Copyright (c) 2026 JV. All rights reserved.
]=]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local WorldDropService = require(script.Parent.WorldDropService)
local DataSessionManager = require(script.Parent.DataSessionManager)
local ItemDatabase = require(ReplicatedStorage.InventorySystem.ItemDatabase)

local WorldSetup = {}

local function SetupLighting()
    pcall(function()
        Lighting.ClockTime = 20.5
        Lighting.Brightness = 2.0
        Lighting.OutdoorAmbient = Color3.fromRGB(18, 24, 38)
        Lighting.Ambient = Color3.fromRGB(15, 20, 32)
        Lighting.GlobalShadows = true
        Lighting.EnvironmentDiffuseScale = 0.5
        Lighting.EnvironmentSpecularScale = 0.6

        -- Cinematic Post-Processing
        local existingBloom = Lighting:FindFirstChildOfClass("BloomEffect")
        if not existingBloom then
            local bloom = Instance.new("BloomEffect")
            bloom.Intensity = 0.65
            bloom.Size = 24
            bloom.Threshold = 1.6
            bloom.Parent = Lighting
        end

        local existingCC = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
        if not existingCC then
            local cc = Instance.new("ColorCorrectionEffect")
            cc.Contrast = 0.12
            cc.Saturation = 0.15
            cc.TintColor = Color3.fromRGB(242, 248, 255)
            cc.Parent = Lighting
        end

        local existingAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if not existingAtmosphere then
            local atmo = Instance.new("Atmosphere")
            atmo.Density = 0.32
            atmo.Offset = 0.25
            atmo.Color = Color3.fromRGB(15, 23, 42)
            atmo.Decay = Color3.fromRGB(30, 41, 59)
            atmo.Glare = 0.1
            atmo.Haze = 0.8
            atmo.Parent = Lighting
        end
    end)
end

local function BuildHangarFloor(parentFolder: Folder)
    -- Main Facility Base Floor
    local mainFloor = Instance.new("Part")
    mainFloor.Name = "FacilityFloor"
    mainFloor.Size = Vector3.new(160, 4, 160)
    mainFloor.Position = Vector3.new(0, -2, 0)
    mainFloor.Anchored = true
    mainFloor.Material = Enum.Material.Metal
    mainFloor.Color = Color3.fromRGB(15, 20, 30)
    mainFloor.TopSurface = Enum.SurfaceType.Smooth
    mainFloor.Parent = parentFolder

    -- Center Octagonal Platform
    local centerPlate = Instance.new("Part")
    centerPlate.Name = "CenterDeck"
    centerPlate.Size = Vector3.new(90, 0.4, 90)
    centerPlate.Position = Vector3.new(0, 0.2, 0)
    centerPlate.Anchored = true
    centerPlate.Material = Enum.Material.DiamondPlate
    centerPlate.Color = Color3.fromRGB(25, 32, 45)
    centerPlate.Parent = parentFolder

    -- Recessed Circuit LED Lines (Subtle Cyan & Gold Grid)
    local circuitLines = {
        { Size = Vector3.new(90, 0.05, 0.6), Pos = Vector3.new(0, 0.42, 25), Color = Color3.fromRGB(56, 189, 248) },
        { Size = Vector3.new(90, 0.05, 0.6), Pos = Vector3.new(0, 0.42, -25), Color = Color3.fromRGB(56, 189, 248) },
        { Size = Vector3.new(0.6, 0.05, 90), Pos = Vector3.new(25, 0.42, 0), Color = Color3.fromRGB(56, 189, 248) },
        { Size = Vector3.new(0.6, 0.05, 90), Pos = Vector3.new(-25, 0.42, 0), Color = Color3.fromRGB(56, 189, 248) },
    }

    for i, line in ipairs(circuitLines) do
        local p = Instance.new("Part")
        p.Name = "CircuitLine_" .. i
        p.Size = line.Size
        p.Position = line.Pos
        p.Anchored = true
        p.CanCollide = false
        p.Material = Enum.Material.Neon
        p.Color = line.Color
        p.Parent = parentFolder
    end

    -- Flush Teleportation Spawn Pad (High-Tech, NO Blinding Neon)
    local spawnPad = Instance.new("SpawnLocation")
    spawnPad.Name = "ArrivalPad"
    spawnPad.Size = Vector3.new(12, 0.3, 12)
    spawnPad.Position = Vector3.new(0, 0.35, 0)
    spawnPad.Anchored = true
    spawnPad.Material = Enum.Material.DiamondPlate
    spawnPad.Color = Color3.fromRGB(30, 38, 52)
    spawnPad.TopSurface = Enum.SurfaceType.Smooth
    spawnPad.Duration = 0
    spawnPad.Parent = parentFolder

    -- Spawn Outer Bezel (Brushed Titanium Ring)
    local bezel = Instance.new("Part")
    bezel.Name = "SpawnBezel"
    bezel.Size = Vector3.new(12.8, 0.2, 12.8)
    bezel.Position = Vector3.new(0, 0.4, 0)
    bezel.Anchored = true
    bezel.Material = Enum.Material.Metal
    bezel.Color = Color3.fromRGB(50, 60, 75)
    bezel.CanCollide = false
    bezel.Parent = parentFolder

    -- Subtle Neon Border Indicator (Refined, not blinding)
    local spawnBorder = Instance.new("Part")
    spawnBorder.Name = "SpawnLED"
    spawnBorder.Size = Vector3.new(12.4, 0.05, 12.4)
    spawnBorder.Position = Vector3.new(0, 0.46, 0)
    spawnBorder.Anchored = true
    spawnBorder.CanCollide = false
    spawnBorder.Material = Enum.Material.Neon
    spawnBorder.Color = Color3.fromRGB(56, 189, 248)
    spawnBorder.Transparency = 0.3
    spawnBorder.Parent = parentFolder

    local spawnLight = Instance.new("PointLight")
    spawnLight.Color = Color3.fromRGB(56, 189, 248)
    spawnLight.Range = 16
    spawnLight.Brightness = 1.4
    spawnLight.Parent = spawnPad

    -- Perimeter Glass & Carbon Stanchions
    local perimeterDist = 44
    local offsets = {
        Vector3.new(perimeterDist, 0, perimeterDist),
        Vector3.new(-perimeterDist, 0, perimeterDist),
        Vector3.new(perimeterDist, 0, -perimeterDist),
        Vector3.new(-perimeterDist, 0, -perimeterDist),
    }

    for i, cornerPos in ipairs(offsets) do
        local pillar = Instance.new("Part")
        pillar.Name = "Pillar_" .. i
        pillar.Size = Vector3.new(3, 14, 3)
        pillar.Position = cornerPos + Vector3.new(0, 7, 0)
        pillar.Anchored = true
        pillar.Material = Enum.Material.Metal
        pillar.Color = Color3.fromRGB(28, 35, 48)
        pillar.Parent = parentFolder

        local pillarLED = Instance.new("Part")
        pillarLED.Name = "PillarLED"
        pillarLED.Size = Vector3.new(3.2, 0.4, 3.2)
        pillarLED.Position = pillar.Position + Vector3.new(0, 5, 0)
        pillarLED.Anchored = true
        pillarLED.Material = Enum.Material.Neon
        pillarLED.Color = Color3.fromRGB(56, 189, 248)
        pillarLED.Parent = parentFolder

        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(56, 189, 248)
        light.Range = 22
        light.Brightness = 1.8
        light.Parent = pillarLED
    end
end

local function BuildShowcasePedestal(
    parentFolder: Folder,
    position: Vector3,
    title: string,
    subtitle: string,
    themeColor: Color3
): Part
    -- Base Column
    local base = Instance.new("Part")
    base.Name = "PedestalBase"
    base.Size = Vector3.new(6, 1.2, 6)
    base.Position = position + Vector3.new(0, 0.6, 0)
    base.Anchored = true
    base.Material = Enum.Material.Metal
    base.Color = Color3.fromRGB(22, 28, 40)
    base.Parent = parentFolder

    -- Cylinder Platform
    local cyl = Instance.new("Part")
    cyl.Name = "PedestalTop"
    cyl.Size = Vector3.new(5.2, 0.4, 5.2)
    cyl.Position = base.Position + Vector3.new(0, 0.7, 0)
    cyl.Anchored = true
    cyl.Material = Enum.Material.DiamondPlate
    cyl.Color = Color3.fromRGB(35, 45, 60)
    cyl.Parent = parentFolder

    -- Floating Magnetic Ring
    local ring = Instance.new("Part")
    ring.Name = "MagRing"
    ring.Size = Vector3.new(5.6, 0.1, 5.6)
    ring.Position = cyl.Position + Vector3.new(0, 0.25, 0)
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.Color = themeColor
    ring.Parent = parentFolder

    local ringLight = Instance.new("PointLight")
    ringLight.Color = themeColor
    ringLight.Range = 14
    ringLight.Brightness = 2
    ringLight.Parent = ring

    -- Holographic Terminal Monitor on the back of the pedestal
    local pylon = Instance.new("Part")
    pylon.Name = "TerminalPylon"
    pylon.Size = Vector3.new(0.6, 5, 0.6)
    pylon.Position = position + Vector3.new(0, 2.5, 3.2)
    pylon.Anchored = true
    pylon.Material = Enum.Material.Metal
    pylon.Color = Color3.fromRGB(28, 35, 48)
    pylon.Parent = parentFolder

    local screenPart = Instance.new("Part")
    screenPart.Name = "TerminalScreen"
    screenPart.Size = Vector3.new(4.5, 2.6, 0.15)
    screenPart.Position = pylon.Position + Vector3.new(0, 2.4, -0.2)
    screenPart.Anchored = true
    screenPart.Material = Enum.Material.SmoothPlastic
    screenPart.Color = Color3.fromRGB(15, 23, 42)
    screenPart.CFrame = CFrame.new(screenPart.Position, screenPart.Position + Vector3.new(0, 0, -1))
    screenPart.Parent = parentFolder

    -- SurfaceGui for crisp high-tech holographic readout
    local sg = Instance.new("SurfaceGui")
    sg.Name = "HoloDisplay"
    sg.Face = Enum.NormalId.Front
    sg.CanvasSize = Vector2.new(450, 260)
    sg.AlwaysOnTop = false
    sg.Parent = screenPart

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    frame.BorderSizePixel = 0
    frame.Parent = sg

    local stroke = Instance.new("UIStroke")
    stroke.Color = themeColor
    stroke.Thickness = 2
    stroke.Parent = frame

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -20, 0, 44)
    header.Position = UDim2.new(0, 10, 0, 10)
    header.BackgroundTransparency = 1
    header.Font = Enum.Font.GothamBold
    header.Text = title
    header.TextColor3 = themeColor
    header.TextSize = 22
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = frame

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -20, 0, 30)
    sub.Position = UDim2.new(0, 10, 0, 50)
    sub.BackgroundTransparency = 1
    sub.Font = Enum.Font.GothamMedium
    sub.Text = subtitle
    sub.TextColor3 = Color3.fromRGB(148, 163, 184)
    sub.TextSize = 14
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = frame

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 120, 0, 28)
    badge.Position = UDim2.new(0, 10, 1, -40)
    badge.BackgroundColor3 = Color3.fromRGB(24, 32, 48)
    badge.Font = Enum.Font.GothamBold
    badge.Text = "● ACTIVE SECURE"
    badge.TextColor3 = Color3.fromRGB(16, 185, 129)
    badge.TextSize = 11
    badge.Parent = frame

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 4)
    badgeCorner.Parent = badge

    return cyl
end

function WorldSetup.Init()
    local arenaFolder = workspace:FindFirstChild("DemoArena")
    if arenaFolder then
        arenaFolder:Destroy()
    end

    arenaFolder = Instance.new("Folder")
    arenaFolder.Name = "DemoArena"
    arenaFolder.Parent = workspace

    SetupLighting()
    BuildHangarFloor(arenaFolder)

    -- Build 4 Dedicated Showcase Pedestals
    local pedWeapon = BuildShowcasePedestal(
        arenaFolder,
        Vector3.new(-18, 0, -18),
        "ARMORY // WEAPONS",
        "Plasma Katana & Cyber Revolver",
        Color3.fromRGB(245, 158, 11)
    )

    local pedArmor = BuildShowcasePedestal(
        arenaFolder,
        Vector3.new(18, 0, -18),
        "AEGIS // DEFENSE SUITE",
        "Nanotech Vest & Aegis Energy Shield",
        Color3.fromRGB(56, 189, 248)
    )

    local pedConsumables = BuildShowcasePedestal(
        arenaFolder,
        Vector3.new(-18, 0, 18),
        "SYNTHESIS // STIMPACKS",
        "Bio-Nano Stims & Velocity Elixirs",
        Color3.fromRGB(16, 185, 129)
    )

    local pedMaterials = BuildShowcasePedestal(
        arenaFolder,
        Vector3.new(18, 0, 18),
        "EXTRACTION // RELICS",
        "Quantum Core Reactor Fragments",
        Color3.fromRGB(168, 85, 247)
    )

    -- Spawn Initial Interactive 3D World Drops on the Pedestals
    task.delay(1.5, function()
        local dropLocations = {
            { Id = "plasma_katana", Qty = 1, Pos = pedWeapon.Position + Vector3.new(0, 1.8, 0) },
            { Id = "aegis_bulwark", Qty = 1, Pos = pedArmor.Position + Vector3.new(0, 1.8, 0) },
            { Id = "health_stim", Qty = 5, Pos = pedConsumables.Position + Vector3.new(0, 1.8, 0) },
            { Id = "quantum_core", Qty = 10, Pos = pedMaterials.Position + Vector3.new(0, 1.8, 0) },
        }

        for _, d in ipairs(dropLocations) do
            WorldDropService.SpawnDrop(d.Id, d.Qty, d.Pos, function(collectingPlayer)
                local profile = DataSessionManager.GetProfile(collectingPlayer)
                if not profile then return false end

                local maxCap = DataSessionManager.GetMaxCapacity()
                for i = 1, maxCap do
                    if not profile.Slots[i] then
                        profile.Slots[i] = {
                            SlotIndex = i,
                            ItemId = d.Id,
                            Quantity = d.Qty,
                            UUID = DataSessionManager.GenerateUUID(),
                        }
                        local SyncProfileEvent = ReplicatedStorage.InventorySystem.Remotes:FindFirstChild("SyncProfile") :: RemoteEvent?
                        if SyncProfileEvent then
                            SyncProfileEvent:FireClient(collectingPlayer, profile)
                        end
                        return true
                    end
                end
                return false
            end)
        end
    end)

    print("🛡️ [WorldSetup] High-End Sci-Fi Holo-Hangar testing facility provisioned.")
end

return WorldSetup
