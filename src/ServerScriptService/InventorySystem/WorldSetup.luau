--!strict
--[=[
    WorldSetup.luau
    Author: JV (lab2 / lab2SecurityProjectsR)
    Auto-provisions a clean testing arena, neon spawn pad, atmospheric lighting,
    and initial interactive 3D world drops for demonstration testing.
    Copyright (c) 2026 JV. All rights reserved.
]=]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldDropService = require(script.Parent.WorldDropService)
local DataSessionManager = require(script.Parent.DataSessionManager)
local ItemDatabase = require(ReplicatedStorage.InventorySystem.ItemDatabase)

local WorldSetup = {}

function WorldSetup.Init()
    local arenaFolder = workspace:FindFirstChild("DemoArena")
    if arenaFolder then return end

    arenaFolder = Instance.new("Folder")
    arenaFolder.Name = "DemoArena"
    arenaFolder.Parent = workspace

    -- Atmospheric Cyber Lighting
    pcall(function()
        Lighting.ClockTime = 19.5
        Lighting.Brightness = 1.2
        Lighting.OutdoorAmbient = Color3.fromRGB(30, 41, 59)
        Lighting.Ambient = Color3.fromRGB(20, 25, 40)
    end)

    -- Baseplate
    local floor = Instance.new("Part")
    floor.Name = "ArenaFloor"
    floor.Size = Vector3.new(300, 4, 300)
    floor.Position = Vector3.new(0, -2, 0)
    floor.Anchored = true
    floor.Material = Enum.Material.SmoothPlastic
    floor.Color = Color3.fromRGB(15, 23, 42)
    floor.TopSurface = Enum.SurfaceType.Smooth
    floor.Parent = arenaFolder

    -- Center Spawn Pad
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "ArenaSpawn"
    spawn.Size = Vector3.new(16, 1, 16)
    spawn.Position = Vector3.new(0, 0.5, 0)
    spawn.Anchored = true
    spawn.Material = Enum.Material.Neon
    spawn.Color = Color3.fromRGB(56, 189, 248)
    spawn.TopSurface = Enum.SurfaceType.Smooth
    spawn.Duration = 0
    spawn.Parent = arenaFolder

    local spawnLight = Instance.new("PointLight")
    spawnLight.Color = spawn.Color
    spawnLight.Range = 25
    spawnLight.Brightness = 3
    spawnLight.Parent = spawn

    -- Billboard Title in World
    local titlePart = Instance.new("Part")
    titlePart.Name = "TitleMarker"
    titlePart.Size = Vector3.new(1, 1, 1)
    titlePart.Position = Vector3.new(0, 10, -20)
    titlePart.Anchored = true
    titlePart.Transparency = 1
    titlePart.CanCollide = false
    titlePart.Parent = arenaFolder

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 360, 0, 80)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 120
    bb.Parent = titlePart

    local t1 = Instance.new("TextLabel")
    t1.Size = UDim2.new(1, 0, 0.5, 0)
    t1.BackgroundTransparency = 1
    t1.Font = Enum.Font.GothamBold
    t1.TextSize = 22
    t1.TextColor3 = Color3.fromRGB(56, 189, 248)
    t1.Text = "AEGIS INVENTORY SUITE"
    t1.Parent = bb

    local t2 = Instance.new("TextLabel")
    t2.Size = UDim2.new(1, 0, 0.5, 0)
    t2.Position = UDim2.new(0, 0, 0.5, 0)
    t2.BackgroundTransparency = 1
    t2.Font = Enum.Font.GothamMedium
    t2.TextSize = 13
    t2.TextColor3 = Color3.fromRGB(148, 163, 184)
    t2.Text = "Press [E] to Open Inventory • Walk near items to Collect"
    t2.Parent = bb

    -- Spawn Initial Showcase World Drops
    task.delay(1.5, function()
        local drops = {
            { Id = "plasma_katana", Qty = 1, Offset = Vector3.new(-12, 0, -10) },
            { Id = "aegis_bulwark", Qty = 1, Offset = Vector3.new(0, 0, -14) },
            { Id = "health_stim", Qty = 5, Offset = Vector3.new(12, 0, -10) },
            { Id = "quantum_core", Qty = 10, Offset = Vector3.new(0, 0, 12) },
        }

        for _, d in ipairs(drops) do
            WorldDropService.SpawnDrop(d.Id, d.Qty, spawn.Position + d.Offset, function(collectingPlayer)
                local profile = DataSessionManager.GetProfile(collectingPlayer)
                if not profile then return false end

                -- Try adding to profile
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
end

return WorldSetup
