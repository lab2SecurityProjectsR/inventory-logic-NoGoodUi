--!strict
--[=[
    ItemDatabase.luau
    Author: JV (lab2 / lab2SecurityProjectsR)
    Authoritative definitions and static data for all inventory items in the experience.
    Provides strict typing, categorization, rarity grading, and equipment stats.
    Copyright (c) 2026 JV. All rights reserved.
]=]

export type ItemRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type ItemCategory = "Weapon" | "Armor" | "Consumable" | "Material"

export type ItemStats = {
    Damage: number?,
    Defense: number?,
    SpeedBoost: number?,
    HealAmount: number?,
    Duration: number?,
}

export type ItemDefinition = {
    Id: string,
    Name: string,
    Description: string,
    Category: ItemCategory,
    Rarity: ItemRarity,
    MaxStack: number,
    Stats: ItemStats,
    Icon: string?,
    IconGlyph: string,
    EquipSlot: string?, -- "Weapon" | "Armor" | "Offhand"
}

local RarityColors: { [ItemRarity]: Color3 } = {
    Common = Color3.fromRGB(160, 160, 160),
    Uncommon = Color3.fromRGB(60, 200, 100),
    Rare = Color3.fromRGB(40, 140, 255),
    Epic = Color3.fromRGB(180, 70, 255),
    Legendary = Color3.fromRGB(255, 175, 25),
}

local Items: { [string]: ItemDefinition } = {
    ["plasma_katana"] = {
        Id = "plasma_katana",
        Name = "Plasma Katana",
        Description = "A high-frequency energy blade vibrating at hyper-sonic speed. Slices through heavy armor.",
        Category = "Weapon",
        Rarity = "Legendary",
        MaxStack = 1,
        EquipSlot = "Weapon",
        IconGlyph = "⚡",
        Stats = { Damage = 75, SpeedBoost = 4 },
    },
    ["cyber_revolver"] = {
        Id = "cyber_revolver",
        Name = "Cyber Revolver",
        Description = "Precision electromagnetic hand cannon firing high-velocity ionized darts.",
        Category = "Weapon",
        Rarity = "Epic",
        MaxStack = 1,
        EquipSlot = "Weapon",
        IconGlyph = "🔫",
        Stats = { Damage = 52 },
    },
    ["iron_broadsword"] = {
        Id = "iron_broadsword",
        Name = "Iron Broadsword",
        Description = "A reliable, heavy-forged steel blade with a balanced crossguard.",
        Category = "Weapon",
        Rarity = "Common",
        MaxStack = 1,
        EquipSlot = "Weapon",
        IconGlyph = "⚔️",
        Stats = { Damage = 22 },
    },
    ["aegis_bulwark"] = {
        Id = "aegis_bulwark",
        Name = "Aegis Energy Shield",
        Description = "Hard-light projection shield that absorbs incoming kinetic and thermal impacts.",
        Category = "Armor",
        Rarity = "Legendary",
        MaxStack = 1,
        EquipSlot = "Armor",
        IconGlyph = "🛡️",
        Stats = { Defense = 55 },
    },
    ["nano_vest"] = {
        Id = "nano_vest",
        Name = "Nanotech Vest",
        Description = "Interwoven carbon-nanotube weave providing lightweight projectile dissipation.",
        Category = "Armor",
        Rarity = "Rare",
        MaxStack = 1,
        EquipSlot = "Armor",
        IconGlyph = "🦺",
        Stats = { Defense = 28 },
    },
    ["health_stim"] = {
        Id = "health_stim",
        Name = "Bio-Nano Stimpack",
        Description = "Rapidly synthesizes biological tissue, restoring 50 HP immediately upon consumption.",
        Category = "Consumable",
        Rarity = "Uncommon",
        MaxStack = 16,
        IconGlyph = "💉",
        Stats = { HealAmount = 50 },
    },
    ["velocity_elixir"] = {
        Id = "velocity_elixir",
        Name = "Overdrive Booster",
        Description = "Adrenaline overdrive stimulant granting +14 WalkSpeed for 15 seconds.",
        Category = "Consumable",
        Rarity = "Rare",
        MaxStack = 8,
        IconGlyph = "🧪",
        Stats = { SpeedBoost = 14, Duration = 15 },
    },
    ["quantum_core"] = {
        Id = "quantum_core",
        Name = "Quantum Core Fragment",
        Description = "A pulsating miniature singularity used as a catalyst for high-tier cyber crafting.",
        Category = "Material",
        Rarity = "Legendary",
        MaxStack = 99,
        IconGlyph = "🔮",
        Stats = {},
    },
    ["refined_titanium"] = {
        Id = "refined_titanium",
        Name = "Refined Titanium Ingot",
        Description = "Aerospace-grade purified titanium alloy plate.",
        Category = "Material",
        Rarity = "Uncommon",
        MaxStack = 64,
        IconGlyph = "🔩",
        Stats = {},
    },
}

local ItemDatabase = {}

function ItemDatabase.GetItem(id: string): ItemDefinition?
    return Items[id]
end

function ItemDatabase.GetAllItems(): { [string]: ItemDefinition }
    return Items
end

function ItemDatabase.GetRarityColor(rarity: ItemRarity): Color3
    return RarityColors[rarity] or Color3.fromRGB(200, 200, 200)
end

return table.freeze(ItemDatabase)
