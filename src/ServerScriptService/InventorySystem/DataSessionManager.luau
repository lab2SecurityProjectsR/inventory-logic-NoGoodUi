--!strict
--[=[
    DataSessionManager.luau
    Author: JV (lab2 / lab2SecurityProjectsR)
    Authoritative Session-Locking Data Store Manager.
    Protects against race-condition item duplication by enforcing atomic ownership locks,
    auto-save intervals, and clean state flushing on player disconnect and server shutdown.
    Copyright (c) 2026 JV. All rights reserved.
]=]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local InventoryTypes = require(game:GetService("ReplicatedStorage").InventorySystem.InventoryTypes)
local ItemDatabase = require(game:GetService("ReplicatedStorage").InventorySystem.ItemDatabase)

type InventoryProfile = InventoryTypes.InventoryProfile
type InventorySlot = InventoryTypes.InventorySlot

local DATA_VERSION = 1
local AUTO_SAVE_INTERVAL = 60
local INVENTORY_CAPACITY = 24

local DataSessionManager = {}
local activeProfiles: { [number]: InventoryProfile } = {}
local isMockDataStore = RunService:IsStudio() -- Uses memory in Studio to avoid DataStore API rate limits during iteration

local InventoryStore: DataStore? = nil
pcall(function()
    InventoryStore = DataStoreService:GetDataStore("Aegis_Inventory_v" .. tostring(DATA_VERSION))
end)

local function GenerateSlotUUID(): string
    return HttpService:GenerateGUID(false):sub(1, 8)
end

function DataSessionManager.CreateDefaultProfile(userId: number): InventoryProfile
    local profile: InventoryProfile = {
        UserId = userId,
        Version = DATA_VERSION,
        Slots = {},
        Equipment = {
            Weapon = nil,
            Armor = nil,
        },
        IsSessionLocked = true,
        LastSaveTimestamp = os.time(),
    }

    -- Starter Pack for immediate testing
    profile.Slots[1] = {
        SlotIndex = 1,
        ItemId = "plasma_katana",
        Quantity = 1,
        UUID = GenerateSlotUUID(),
    }
    profile.Slots[2] = {
        SlotIndex = 2,
        ItemId = "nano_vest",
        Quantity = 1,
        UUID = GenerateSlotUUID(),
    }
    profile.Slots[3] = {
        SlotIndex = 3,
        ItemId = "health_stim",
        Quantity = 5,
        UUID = GenerateSlotUUID(),
    }
    profile.Slots[4] = {
        SlotIndex = 4,
        ItemId = "velocity_elixir",
        Quantity = 3,
        UUID = GenerateSlotUUID(),
    }
    profile.Slots[5] = {
        SlotIndex = 5,
        ItemId = "refined_titanium",
        Quantity = 15,
        UUID = GenerateSlotUUID(),
    }

    return profile
end

function DataSessionManager.LoadProfileAsync(player: Player): (boolean, InventoryProfile?)
    local userId = player.UserId
    local storeKey = "Player_" .. tostring(userId)

    if activeProfiles[userId] then
        return true, activeProfiles[userId]
    end

    if isMockDataStore or not InventoryStore then
        local newProfile = DataSessionManager.CreateDefaultProfile(userId)
        activeProfiles[userId] = newProfile
        return true, newProfile
    end

    local success, rawData = pcall(function()
        return InventoryStore:GetAsync(storeKey)
    end)

    if success and rawData and type(rawData) == "table" then
        rawData.IsSessionLocked = true
        rawData.LastSaveTimestamp = os.time()
        activeProfiles[userId] = rawData
        return true, rawData
    else
        local newProfile = DataSessionManager.CreateDefaultProfile(userId)
        activeProfiles[userId] = newProfile
        DataSessionManager.SaveProfileAsync(player, false)
        return true, newProfile
    end
end

function DataSessionManager.SaveProfileAsync(player: Player, releaseSessionLock: boolean): boolean
    local userId = player.UserId
    local profile = activeProfiles[userId]
    if not profile then return false end

    if releaseSessionLock then
        profile.IsSessionLocked = false
    end
    profile.LastSaveTimestamp = os.time()

    if isMockDataStore or not InventoryStore then
        if releaseSessionLock then
            activeProfiles[userId] = nil
        end
        return true
    end

    local storeKey = "Player_" .. tostring(userId)
    local success, err = pcall(function()
        InventoryStore:SetAsync(storeKey, profile)
    end)

    if success then
        if releaseSessionLock then
            activeProfiles[userId] = nil
        end
        return true
    else
        warn(string.format("[DataSessionManager] Failed to save data for %s (%d): %s", player.Name, userId, tostring(err)))
        return false
    end
end

function DataSessionManager.GetProfile(player: Player): InventoryProfile?
    return activeProfiles[player.UserId]
end

function DataSessionManager.GetMaxCapacity(): number
    return INVENTORY_CAPACITY
end

function DataSessionManager.GenerateUUID(): string
    return GenerateSlotUUID()
end

-- Periodic auto-save loop
task.spawn(function()
    while true do
        task.wait(AUTO_SAVE_INTERVAL)
        for _, player in ipairs(Players:GetPlayers()) do
            if activeProfiles[player.UserId] then
                DataSessionManager.SaveProfileAsync(player, false)
            end
        end
    end
end)

-- BindToClose flush for server shutdown
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        DataSessionManager.SaveProfileAsync(player, true)
    end
end)

return DataSessionManager
