--!strict
--[=[
    InventoryTypes.luau
    Author: JV (lab2 / lab2SecurityProjectsR)
    Core data structure types and schemas for the inventory & equipment framework.
    Copyright (c) 2026 JV. All rights reserved.
]=]

local ItemDatabase = require(script.Parent.ItemDatabase)

export type InventorySlot = {
    SlotIndex: number,
    ItemId: string,
    Quantity: number,
    UUID: string,
}

export type EquipmentSlots = {
    Weapon: InventorySlot?,
    Armor: InventorySlot?,
}

export type InventoryProfile = {
    UserId: number,
    Version: number,
    Slots: { [number]: InventorySlot }, -- 1 to 24
    Equipment: EquipmentSlots,
    IsSessionLocked: boolean,
    LastSaveTimestamp: number,
}

local InventoryTypes = {}
return InventoryTypes
