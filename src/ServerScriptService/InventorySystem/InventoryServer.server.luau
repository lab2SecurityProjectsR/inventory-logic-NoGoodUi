--!strict
--[=[
    InventoryServer.server.luau
    Author: JV (lab2 / lab2SecurityProjectsR)
    Master Server-Side Orchestrator for the Inventory & Equipment Suite.
    Enforces strict zero-client-trust validation, atomic state mutations,
    and event routing for hotbar, equipment, item consumption, and world drops.
    Copyright (c) 2026 JV. All rights reserved.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryTypes = require(ReplicatedStorage.InventorySystem.InventoryTypes)
local ItemDatabase = require(ReplicatedStorage.InventorySystem.ItemDatabase)

local DataSessionManager = require(script.Parent.DataSessionManager)
local EquipmentService = require(script.Parent.EquipmentService)
local WorldDropService = require(script.Parent.WorldDropService)

type InventoryProfile = InventoryTypes.InventoryProfile
type InventorySlot = InventoryTypes.InventorySlot

-- 1. Provision Network Remotes
local remotesFolder = ReplicatedStorage.InventorySystem:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage.InventorySystem
end

local function GetOrCreateRemote(name: string, isFunction: boolean?): Instance
    local existing = remotesFolder:FindFirstChild(name)
    if existing then return existing end

    local remote = isFunction and Instance.new("RemoteFunction") or Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = remotesFolder
    return remote
end

local SyncProfileEvent = GetOrCreateRemote("SyncProfile") :: RemoteEvent
local MoveItemEvent = GetOrCreateRemote("MoveItem") :: RemoteEvent
local SplitStackEvent = GetOrCreateRemote("SplitStack") :: RemoteEvent
local UseItemEvent = GetOrCreateRemote("UseItem") :: RemoteEvent
local EquipItemEvent = GetOrCreateRemote("EquipItem") :: RemoteEvent
local UnequipItemEvent = GetOrCreateRemote("UnequipItem") :: RemoteEvent
local DropItemEvent = GetOrCreateRemote("DropItem") :: RemoteEvent
local AdminGiveDemoItemsEvent = GetOrCreateRemote("AdminGiveDemoItems") :: RemoteEvent
local NotificationEvent = GetOrCreateRemote("NotificationEvent") :: RemoteEvent
local RequestSyncFunction = GetOrCreateRemote("RequestSync", true) :: RemoteFunction

local function SendNotification(player: Player, message: string, alertType: string?)
    NotificationEvent:FireClient(player, message, alertType or "Info")
end

local function SendProfileUpdate(player: Player)
    local profile = DataSessionManager.GetProfile(player)
    if profile then
        SyncProfileEvent:FireClient(player, profile)
    end
end


-- Helper: Find first available empty slot
local function FindEmptySlot(profile: InventoryProfile): number?
    local maxCap = DataSessionManager.GetMaxCapacity()
    for i = 1, maxCap do
        if not profile.Slots[i] then
            return i
        end
    end
    return nil
end

-- Helper: Add item to profile (handles stack merging and overflow)
local function TryAddItemToProfile(profile: InventoryProfile, itemId: string, quantity: number): boolean
    local itemDef = ItemDatabase.GetItem(itemId)
    if not itemDef or quantity <= 0 then return false end

    local maxCap = DataSessionManager.GetMaxCapacity()
    local remaining = quantity

    -- 1. Try merging into existing partial stacks
    if itemDef.MaxStack > 1 then
        for i = 1, maxCap do
            local slot = profile.Slots[i]
            if slot and slot.ItemId == itemId and slot.Quantity < itemDef.MaxStack then
                local space = itemDef.MaxStack - slot.Quantity
                local toAdd = math.min(space, remaining)
                slot.Quantity += toAdd
                remaining -= toAdd
                if remaining == 0 then
                    return true
                end
            end
        end
    end

    -- 2. Place in new empty slots
    while remaining > 0 do
        local emptySlotIndex = FindEmptySlot(profile)
        if not emptySlotIndex then
            return false -- Inventory full, cannot add all
        end

        local toAdd = math.min(itemDef.MaxStack, remaining)
        profile.Slots[emptySlotIndex] = {
            SlotIndex = emptySlotIndex,
            ItemId = itemId,
            Quantity = toAdd,
            UUID = DataSessionManager.GenerateUUID(),
        }
        remaining -= toAdd
    end

    return true
end

-- Remote Handler: Move / Swap Slot
MoveItemEvent.OnServerEvent:Connect(function(player: Player, fromSlot: number, toSlot: number)
    if type(fromSlot) ~= "number" or type(toSlot) ~= "number" then return end
    fromSlot = math.floor(fromSlot)
    toSlot = math.floor(toSlot)

    local maxCap = DataSessionManager.GetMaxCapacity()
    if fromSlot < 1 or fromSlot > maxCap or toSlot < 1 or toSlot > maxCap or fromSlot == toSlot then
        return
    end

    local profile = DataSessionManager.GetProfile(player)
    if not profile then return end

    local sourceSlot = profile.Slots[fromSlot]
    if not sourceSlot then return end

    local destSlot = profile.Slots[toSlot]

    if not destSlot then
        -- Move to empty slot
        sourceSlot.SlotIndex = toSlot
        profile.Slots[toSlot] = sourceSlot
        profile.Slots[fromSlot] = nil
    else
        -- Check for stack merge
        local itemDef = ItemDatabase.GetItem(sourceSlot.ItemId)
        if itemDef and destSlot.ItemId == sourceSlot.ItemId and destSlot.Quantity < itemDef.MaxStack then
            local space = itemDef.MaxStack - destSlot.Quantity
            local toTransfer = math.min(space, sourceSlot.Quantity)
            destSlot.Quantity += toTransfer
            sourceSlot.Quantity -= toTransfer

            if sourceSlot.Quantity <= 0 then
                profile.Slots[fromSlot] = nil
            end
        else
            -- Atomic Swap
            sourceSlot.SlotIndex = toSlot
            destSlot.SlotIndex = fromSlot
            profile.Slots[toSlot] = sourceSlot
            profile.Slots[fromSlot] = destSlot
        end
    end

    SendProfileUpdate(player)
end)

-- Remote Handler: Split Stack
SplitStackEvent.OnServerEvent:Connect(function(player: Player, slotIndex: number, splitAmount: number)
    if type(slotIndex) ~= "number" or type(splitAmount) ~= "number" then return end
    slotIndex = math.floor(slotIndex)
    splitAmount = math.floor(splitAmount)

    local profile = DataSessionManager.GetProfile(player)
    if not profile then return end

    local slot = profile.Slots[slotIndex]
    if not slot or splitAmount <= 0 or splitAmount >= slot.Quantity then return end

    local emptyIndex = FindEmptySlot(profile)
    if not emptyIndex then return end

    slot.Quantity -= splitAmount
    profile.Slots[emptyIndex] = {
        SlotIndex = emptyIndex,
        ItemId = slot.ItemId,
        Quantity = splitAmount,
        UUID = DataSessionManager.GenerateUUID(),
    }

    SendProfileUpdate(player)
end)

-- Remote Handler: Use Consumable
UseItemEvent.OnServerEvent:Connect(function(player: Player, slotIndex: number)
    if type(slotIndex) ~= "number" then return end
    slotIndex = math.floor(slotIndex)

    local profile = DataSessionManager.GetProfile(player)
    if not profile then return end

    local slot = profile.Slots[slotIndex]
    if not slot then return end

    local itemDef = ItemDatabase.GetItem(slot.ItemId)
    if not itemDef or itemDef.Category ~= "Consumable" then return end

    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- Consume 1 item
    slot.Quantity -= 1
    if slot.Quantity <= 0 then
        profile.Slots[slotIndex] = nil
    end

    -- Apply Consumable Effect
    if itemDef.Stats.HealAmount then
        humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + itemDef.Stats.HealAmount)
        SendNotification(player, string.format("Consumed %s (+%d HP)", itemDef.Name, itemDef.Stats.HealAmount), "Success")
    end

    if itemDef.Stats.SpeedBoost and itemDef.Stats.Duration then
        local boost = itemDef.Stats.SpeedBoost
        local dur = itemDef.Stats.Duration
        local originalSpeed = humanoid.WalkSpeed
        humanoid.WalkSpeed += boost
        SendNotification(player, string.format("Activated %s (+%d Speed for %ds)", itemDef.Name, boost, dur), "Success")

        task.delay(dur, function()
            if humanoid and humanoid.Parent then
                humanoid.WalkSpeed = math.max(16, humanoid.WalkSpeed - boost)
            end
        end)
    end

    SendProfileUpdate(player)
end)

-- Remote Handler: Equip Item
EquipItemEvent.OnServerEvent:Connect(function(player: Player, fromSlot: number, equipSlotType: string)
    if type(fromSlot) ~= "number" or (equipSlotType ~= "Weapon" and equipSlotType ~= "Armor") then
        return
    end
    fromSlot = math.floor(fromSlot)

    local profile = DataSessionManager.GetProfile(player)
    if not profile then return end

    local slot = profile.Slots[fromSlot]
    if not slot then return end

    local itemDef = ItemDatabase.GetItem(slot.ItemId)
    if not itemDef or itemDef.EquipSlot ~= equipSlotType then return end

    local currentEquipped = profile.Equipment[equipSlotType]

    -- Move slot to equipment
    profile.Equipment[equipSlotType] = slot
    profile.Slots[fromSlot] = currentEquipped -- swap if something was equipped, else nil

    EquipmentService.ApplyEquipmentVisual(player, equipSlotType, slot)
    SendNotification(player, string.format("Equipped %s", itemDef.Name), "Success")
    SendProfileUpdate(player)
end)

-- Remote Handler: Unequip Item
UnequipItemEvent.OnServerEvent:Connect(function(player: Player, equipSlotType: string, toSlot: number?)
    if equipSlotType ~= "Weapon" and equipSlotType ~= "Armor" then return end

    local profile = DataSessionManager.GetProfile(player)
    if not profile then return end

    local equipped = profile.Equipment[equipSlotType]
    if not equipped then return end

    local targetSlot = toSlot and math.floor(toSlot) or FindEmptySlot(profile)
    if not targetSlot or profile.Slots[targetSlot] then
        targetSlot = FindEmptySlot(profile)
    end

    if not targetSlot then
        SendNotification(player, "Inventory is full! Drop or use an item first to unequip.", "Warning")
        return
    end

    local itemDef = ItemDatabase.GetItem(equipped.ItemId)
    equipped.SlotIndex = targetSlot
    profile.Slots[targetSlot] = equipped
    profile.Equipment[equipSlotType] = nil

    EquipmentService.ApplyEquipmentVisual(player, equipSlotType, nil)
    SendNotification(player, string.format("Unequipped %s", itemDef and itemDef.Name or equipSlotType), "Info")
    SendProfileUpdate(player)
end)

-- Remote Handler: Drop Item to 3D World
DropItemEvent.OnServerEvent:Connect(function(player: Player, slotIndex: number, quantity: number?)
    if type(slotIndex) ~= "number" then return end
    slotIndex = math.floor(slotIndex)

    local profile = DataSessionManager.GetProfile(player)
    if not profile then return end

    local slot = profile.Slots[slotIndex]
    if not slot then return end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local itemDef = ItemDatabase.GetItem(slot.ItemId)
    local dropQty = quantity and math.min(slot.Quantity, math.max(1, math.floor(quantity))) or slot.Quantity

    slot.Quantity -= dropQty
    local droppedItemId = slot.ItemId

    if slot.Quantity <= 0 then
        profile.Slots[slotIndex] = nil
    end

    SendNotification(player, string.format("Dropped %s (x%d)", itemDef and itemDef.Name or droppedItemId, dropQty), "Info")
    SendProfileUpdate(player)

    -- Spawn world drop in front of player
    local spawnPos = root.Position + root.CFrame.LookVector * 4
    WorldDropService.SpawnDrop(droppedItemId, dropQty, spawnPos, function(collectingPlayer: Player)
        local pickerProfile = DataSessionManager.GetProfile(collectingPlayer)
        if not pickerProfile then return false end

        local added = TryAddItemToProfile(pickerProfile, droppedItemId, dropQty)
        if added then
            SendNotification(collectingPlayer, string.format("Collected %s (x%d)", itemDef and itemDef.Name or droppedItemId, dropQty), "Success")
            SendProfileUpdate(collectingPlayer)
            return true
        else
            SendNotification(collectingPlayer, "Cannot collect: Inventory is full!", "Warning")
            return false
        end
    end)
end)

-- Remote Handler: Admin / Demo Starter Pack
AdminGiveDemoItemsEvent.OnServerEvent:Connect(function(player: Player)
    local profile = DataSessionManager.GetProfile(player)
    if not profile then return end

    local demoItems = {
        { Id = "plasma_katana", Qty = 1 },
        { Id = "aegis_bulwark", Qty = 1 },
        { Id = "cyber_revolver", Qty = 1 },
        { Id = "velocity_elixir", Qty = 3 },
        { Id = "health_stim", Qty = 5 },
        { Id = "quantum_core", Qty = 10 },
    }

    local addedCount = 0
    for _, entry in ipairs(demoItems) do
        -- Only add if player doesn't already have this item to avoid hoarding all slots
        local exists = false
        for _, s in pairs(profile.Slots) do
            if s.ItemId == entry.Id then
                exists = true
                break
            end
        end
        if not exists then
            if TryAddItemToProfile(profile, entry.Id, entry.Qty) then
                addedCount += 1
            end
        end
    end

    if addedCount > 0 then
        SendNotification(player, "Added starter gear to inventory!", "Success")
    else
        SendNotification(player, "You already have the demo starter items in inventory.", "Info")
    end

    SendProfileUpdate(player)
end)

-- RequestSync RemoteFunction
RequestSyncFunction.OnServerInvoke = function(player: Player)
    return DataSessionManager.GetProfile(player)
end

-- Player Lifecycle
Players.PlayerAdded:Connect(function(player: Player)
    local success, profile = DataSessionManager.LoadProfileAsync(player)
    if success and profile then
        task.wait(0.5)
        SendProfileUpdate(player)
    end

    player.CharacterAdded:Connect(function(character)
        EquipmentService.OnCharacterAdded(player, character)
    end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
    DataSessionManager.SaveProfileAsync(player, true)
end)

local WorldSetup = require(script.Parent.WorldSetup)
WorldSetup.Init()

print("⚡ [Inventory Suite] Authoritative Inventory & Equipment Server Initialized.")
