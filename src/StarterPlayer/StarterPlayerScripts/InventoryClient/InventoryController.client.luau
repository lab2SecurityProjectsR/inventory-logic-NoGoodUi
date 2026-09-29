--!strict
--[=[
    InventoryController.client.luau
    Author: JV (lab2 / lab2SecurityProjectsR)
    Elite AAA Tactile "Gominola" Cyber-Chassis UI & Hotbar for the Inventory & Equipment Suite.
    Modeled after professional industry UI references (beveled metallic chassis, 6-column grid,
    search & category filtering, 3D gummy bounce micro-animations, live slot toggling).
    Copyright (c) 2026 JV. All rights reserved.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

-- Disable default Roblox backpack to prevent conflict with custom HUD
pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local InventoryTypes = require(ReplicatedStorage:WaitForChild("InventorySystem"):WaitForChild("InventoryTypes"))
local ItemDatabase = require(ReplicatedStorage.InventorySystem:WaitForChild("ItemDatabase"))

type InventoryProfile = InventoryTypes.InventoryProfile
type InventorySlot = InventoryTypes.InventorySlot

local RemotesFolder = ReplicatedStorage.InventorySystem:WaitForChild("Remotes")
local SyncProfileEvent = RemotesFolder:WaitForChild("SyncProfile") :: RemoteEvent
local MoveItemEvent = RemotesFolder:WaitForChild("MoveItem") :: RemoteEvent
local SplitStackEvent = RemotesFolder:WaitForChild("SplitStack") :: RemoteEvent
local UseItemEvent = RemotesFolder:WaitForChild("UseItem") :: RemoteEvent
local EquipItemEvent = RemotesFolder:WaitForChild("EquipItem") :: RemoteEvent
local UnequipItemEvent = RemotesFolder:WaitForChild("UnequipItem") :: RemoteEvent
local DropItemEvent = RemotesFolder:WaitForChild("DropItem") :: RemoteEvent
local AdminGiveDemoItemsEvent = RemotesFolder:WaitForChild("AdminGiveDemoItems") :: RemoteEvent
local NotificationEvent = RemotesFolder:WaitForChild("NotificationEvent") :: RemoteEvent

-- State
local currentProfile: InventoryProfile? = nil
local selectedSlotIndex: number? = nil
local isInventoryOpen = false
local currentCategoryFilter = "All"
local searchQuery = ""
local currentSortMode = "Rarity" -- "Rarity", "Name", "Quantity"

local slotFrames: { [number]: Frame } = {}
local hotbarFrames: { [number]: Frame } = {}

-- UI Creation
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AegisInventoryGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Parent = playerGui

-- =========================================================================
-- TOAST NOTIFICATION BANNER
-- =========================================================================
local toastFrame = Instance.new("Frame")
toastFrame.Name = "ToastNotification"
toastFrame.Size = UDim2.new(0, 360, 0, 44)
toastFrame.Position = UDim2.new(0.5, -180, 0, -60)
toastFrame.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
toastFrame.BorderSizePixel = 0
toastFrame.ZIndex = 60
toastFrame.Parent = screenGui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 8)
toastCorner.Parent = toastFrame

local toastStroke = Instance.new("UIStroke")
toastStroke.Color = Color3.fromRGB(56, 189, 248)
toastStroke.Thickness = 1.4
toastStroke.Parent = toastFrame

local toastIcon = Instance.new("TextLabel")
toastIcon.Name = "Icon"
toastIcon.Size = UDim2.new(0, 36, 1, 0)
toastIcon.Position = UDim2.new(0, 6, 0, 0)
toastIcon.BackgroundTransparency = 1
toastIcon.Font = Enum.Font.GothamBold
toastIcon.TextSize = 16
toastIcon.Text = "ℹ️"
toastIcon.ZIndex = 61
toastIcon.Parent = toastFrame

local toastLabel = Instance.new("TextLabel")
toastLabel.Name = "Message"
toastLabel.Size = UDim2.new(1, -48, 1, 0)
toastLabel.Position = UDim2.new(0, 44, 0, 0)
toastLabel.BackgroundTransparency = 1
toastLabel.Font = Enum.Font.GothamMedium
toastLabel.TextSize = 12
toastLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
toastLabel.TextXAlignment = Enum.TextXAlignment.Left
toastLabel.RichText = true
toastLabel.ZIndex = 61
toastLabel.Parent = toastFrame

local isToastActive = false
local function ShowToast(message: string, alertType: string?)
    toastLabel.Text = message
    if alertType == "Warning" then
        toastIcon.Text = "⚠️"
        toastStroke.Color = Color3.fromRGB(245, 158, 11)
    elseif alertType == "Success" then
        toastIcon.Text = "✅"
        toastStroke.Color = Color3.fromRGB(16, 185, 129)
    else
        toastIcon.Text = "ℹ️"
        toastStroke.Color = Color3.fromRGB(56, 189, 248)
    end

    if isToastActive then return end
    isToastActive = true

    toastFrame:TweenPosition(
        UDim2.new(0.5, -180, 0, 20),
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Back,
        0.3,
        true
    )

    task.delay(2.6, function()
        toastFrame:TweenPosition(
            UDim2.new(0.5, -180, 0, -60),
            Enum.EasingDirection.In,
            Enum.EasingStyle.Quad,
            0.25,
            true,
            function()
                isToastActive = false
            end
        )
    end)
end

NotificationEvent.OnClientEvent:Connect(ShowToast)

-- =========================================================================
-- MAIN INVENTORY WINDOW (ARTSTATION CHASSIS WITH BEVELED DETAILS)
-- =========================================================================
local mainContainer = Instance.new("Frame")
mainContainer.Name = "MainInventoryWindow"
mainContainer.Size = UDim2.new(0, 580, 0, 560)
mainContainer.Position = UDim2.new(0.5, -290, 0.5, -280)
mainContainer.BackgroundColor3 = Color3.fromRGB(32, 42, 58) -- Brushed titanium slate
mainContainer.BorderSizePixel = 0
mainContainer.Visible = false
mainContainer.ZIndex = 20
mainContainer.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = mainContainer

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(65, 82, 108)
mainStroke.Thickness = 2.5
mainStroke.Parent = mainContainer

-- 4 Corner Screws / Hex Bolts (Exactly as in ArtStation reference)
local boltPositions = {
    UDim2.new(0, 8, 0, 8),
    UDim2.new(1, -16, 0, 8),
    UDim2.new(0, 8, 1, -16),
    UDim2.new(1, -16, 1, -16),
}
for i, bPos in ipairs(boltPositions) do
    local bolt = Instance.new("Frame")
    bolt.Name = "Bolt_" .. i
    bolt.Size = UDim2.new(0, 8, 0, 8)
    bolt.Position = bPos
    bolt.BackgroundColor3 = Color3.fromRGB(120, 135, 155)
    bolt.BorderSizePixel = 0
    bolt.ZIndex = 25
    bolt.Parent = mainContainer

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = bolt
end

-- Side Copper/Bronze Hydraulic Vents (ArtStation Detail)
local leftVent = Instance.new("Frame")
leftVent.Name = "LeftHydraulicVent"
leftVent.Size = UDim2.new(0, 5, 0, 120)
leftVent.Position = UDim2.new(0, 2, 0.5, -60)
leftVent.BackgroundColor3 = Color3.fromRGB(190, 120, 65)
leftVent.BorderSizePixel = 0
leftVent.ZIndex = 22
leftVent.Parent = mainContainer
Instance.new("UICorner", leftVent).CornerRadius = UDim.new(0, 3)

local rightVent = Instance.new("Frame")
rightVent.Name = "RightHydraulicVent"
rightVent.Size = UDim2.new(0, 5, 0, 120)
rightVent.Position = UDim2.new(1, -7, 0.5, -60)
rightVent.BackgroundColor3 = Color3.fromRGB(190, 120, 65)
rightVent.BorderSizePixel = 0
rightVent.ZIndex = 22
rightVent.Parent = mainContainer
Instance.new("UICorner", rightVent).CornerRadius = UDim.new(0, 3)

-- Bottom Grill with Amber Status Diode
local bottomGrill = Instance.new("Frame")
bottomGrill.Name = "BottomGrill"
bottomGrill.Size = UDim2.new(0, 140, 0, 5)
bottomGrill.Position = UDim2.new(0.5, -70, 1, -12)
bottomGrill.BackgroundColor3 = Color3.fromRGB(245, 175, 40)
bottomGrill.BorderSizePixel = 0
bottomGrill.ZIndex = 25
bottomGrill.Parent = mainContainer
Instance.new("UICorner", bottomGrill).CornerRadius = UDim.new(1, 0)

-- Inner Dark Glass Panel
local innerPanel = Instance.new("Frame")
innerPanel.Name = "InnerPanel"
innerPanel.Size = UDim2.new(1, -24, 1, -30)
innerPanel.Position = UDim2.new(0, 12, 0, 15)
innerPanel.BackgroundColor3 = Color3.fromRGB(14, 20, 32)
innerPanel.BorderSizePixel = 0
innerPanel.ZIndex = 21
innerPanel.Parent = mainContainer

local innerCorner = Instance.new("UICorner")
innerCorner.CornerRadius = UDim.new(0, 10)
innerCorner.Parent = innerPanel

local innerStroke = Instance.new("UIStroke")
innerStroke.Color = Color3.fromRGB(24, 34, 52)
innerStroke.Thickness = 1.5
innerStroke.Parent = innerPanel

-- Header Title: "MY INVENTORY"
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(0, 200, 0, 32)
titleLabel.Position = UDim2.new(0, 16, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "MY INVENTORY"
titleLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 24
titleLabel.Parent = innerPanel

-- Close Button (Top-Right ✕ with Gummy Tactile Feel)
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -38, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(25, 33, 48)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(148, 163, 184)
closeBtn.TextSize = 14
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 25
closeBtn.Parent = innerPanel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(45, 58, 80)
closeStroke.Thickness = 1.2
closeStroke.Parent = closeBtn

closeBtn.MouseEnter:Connect(function()
    closeBtn.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
end)
closeBtn.MouseLeave:Connect(function()
    closeBtn.BackgroundColor3 = Color3.fromRGB(25, 33, 48)
    closeBtn.TextColor3 = Color3.fromRGB(148, 163, 184)
end)

-- =========================================================================
-- FILTER & SEARCH BAR (MATCHING ARTSTATION REFERENCE)
-- =========================================================================
local controlRow = Instance.new("Frame")
controlRow.Name = "ControlRow"
controlRow.Size = UDim2.new(1, -32, 0, 34)
controlRow.Position = UDim2.new(0, 16, 0, 46)
controlRow.BackgroundTransparency = 1
controlRow.ZIndex = 24
controlRow.Parent = innerPanel

-- Search Input Pill
local searchFrame = Instance.new("Frame")
searchFrame.Name = "SearchFrame"
searchFrame.Size = UDim2.new(0, 160, 1, 0)
searchFrame.BackgroundColor3 = Color3.fromRGB(20, 28, 44)
searchFrame.BorderSizePixel = 0
searchFrame.ZIndex = 24
searchFrame.Parent = controlRow
Instance.new("UICorner", searchFrame).CornerRadius = UDim.new(0, 8)

local searchStroke = Instance.new("UIStroke")
searchStroke.Color = Color3.fromRGB(45, 60, 85)
searchStroke.Thickness = 1.2
searchStroke.Parent = searchFrame

local searchIcon = Instance.new("TextLabel")
searchIcon.Size = UDim2.new(0, 24, 1, 0)
searchIcon.Position = UDim2.new(0, 6, 0, 0)
searchIcon.BackgroundTransparency = 1
searchIcon.Text = "🔍"
searchIcon.TextSize = 12
searchIcon.ZIndex = 25
searchIcon.Parent = searchFrame

local searchInput = Instance.new("TextBox")
searchInput.Name = "SearchInput"
searchInput.Size = UDim2.new(1, -34, 1, 0)
searchInput.Position = UDim2.new(0, 30, 0, 0)
searchInput.BackgroundTransparency = 1
searchInput.Font = Enum.Font.GothamMedium
searchInput.PlaceholderText = "Search..."
searchInput.PlaceholderColor3 = Color3.fromRGB(100, 116, 139)
searchInput.Text = ""
searchInput.TextColor3 = Color3.fromRGB(241, 245, 249)
searchInput.TextSize = 12
searchInput.TextXAlignment = Enum.TextXAlignment.Left
searchInput.ClearTextOnFocus = false
searchInput.ZIndex = 25
searchInput.Parent = searchFrame

-- Category Tabs (All, Weapons, Armor, Stims, Materials)
local categoryButtons: { [string]: TextButton } = {}
local categories = {
    { Id = "All", Label = "✨ All" },
    { Id = "Weapon", Label = "⚔️ Weapons" },
    { Id = "Armor", Label = "🛡️ Armor" },
    { Id = "Consumable", Label = "🧪 Stims" },
}

local tabContainer = Instance.new("Frame")
tabContainer.Name = "TabContainer"
tabContainer.Size = UDim2.new(1, -260, 1, 0)
tabContainer.Position = UDim2.new(0, 170, 0, 0)
tabContainer.BackgroundTransparency = 1
tabContainer.ZIndex = 24
tabContainer.Parent = controlRow

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Parent = tabContainer

local function UpdateCategoryVisuals()
    for id, btn in pairs(categoryButtons) do
        local isSelected = (id == currentCategoryFilter)
        btn.BackgroundColor3 = isSelected and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(22, 30, 46)
        btn.TextColor3 = isSelected and Color3.fromRGB(15, 23, 42) or Color3.fromRGB(148, 163, 184)
        local stroke = btn:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = isSelected and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(40, 52, 74)
        end
    end
end

for _, cat in ipairs(categories) do
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. cat.Id
    btn.Size = UDim2.new(0, 72, 1, -4)
    btn.BackgroundColor3 = (cat.Id == "All") and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(22, 30, 46)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.Text = cat.Label
    btn.TextColor3 = (cat.Id == "All") and Color3.fromRGB(15, 23, 42) or Color3.fromRGB(148, 163, 184)
    btn.TextSize = 10
    btn.AutoButtonColor = false
    btn.ZIndex = 25
    btn.Parent = tabContainer
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke")
    stroke.Color = (cat.Id == "All") and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(40, 52, 74)
    stroke.Thickness = 1.2
    stroke.Parent = btn

    categoryButtons[cat.Id] = btn

    btn.MouseButton1Click:Connect(function()
        currentCategoryFilter = cat.Id
        UpdateCategoryVisuals()
        task.spawn(function()
            -- Re-render inventory grid
            local RenderInventory = _G.__RenderInventoryFunc
            if RenderInventory then RenderInventory() end
        end)
    end)
end

-- Starter Pack Demo Button (Top Right)
local demoBtn = Instance.new("TextButton")
demoBtn.Name = "DemoKitBtn"
demoBtn.Size = UDim2.new(0, 80, 1, 0)
demoBtn.Position = UDim2.new(1, -80, 0, 0)
demoBtn.BackgroundColor3 = Color3.fromRGB(245, 158, 11)
demoBtn.BorderSizePixel = 0
demoBtn.Font = Enum.Font.GothamBold
demoBtn.Text = "🎁 KIT"
demoBtn.TextColor3 = Color3.fromRGB(15, 23, 42)
demoBtn.TextSize = 11
demoBtn.ZIndex = 25
demoBtn.Parent = controlRow
Instance.new("UICorner", demoBtn).CornerRadius = UDim.new(0, 6)

demoBtn.MouseButton1Click:Connect(function()
    AdminGiveDemoItemsEvent:FireServer()
end)

-- =========================================================================
-- 6-COLUMN BEVELED GRID SCROLL FRAME (MATCHING ARTSTATION REFERENCE)
-- =========================================================================
local gridScroll = Instance.new("ScrollingFrame")
gridScroll.Name = "GridScroll"
gridScroll.Size = UDim2.new(1, -32, 0, 340)
gridScroll.Position = UDim2.new(0, 16, 0, 88)
gridScroll.BackgroundTransparency = 1
gridScroll.BorderSizePixel = 0
gridScroll.ScrollBarThickness = 4
gridScroll.ScrollBarImageColor3 = Color3.fromRGB(56, 189, 248)
gridScroll.ZIndex = 23
gridScroll.Parent = innerPanel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 78, 0, 78) -- 6 columns inside 520px
gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridScroll

-- =========================================================================
-- TACTILE ITEM INSPECTOR DRAWER (AT BOTTOM OF INVENTORY)
-- =========================================================================
local inspectorDrawer = Instance.new("Frame")
inspectorDrawer.Name = "InspectorDrawer"
inspectorDrawer.Size = UDim2.new(1, -32, 0, 80)
inspectorDrawer.Position = UDim2.new(0, 16, 1, -92)
inspectorDrawer.BackgroundColor3 = Color3.fromRGB(20, 28, 42)
inspectorDrawer.BorderSizePixel = 0
inspectorDrawer.ZIndex = 24
inspectorDrawer.Parent = innerPanel
Instance.new("UICorner", inspectorDrawer).CornerRadius = UDim.new(0, 8)

local inspStroke = Instance.new("UIStroke")
inspStroke.Color = Color3.fromRGB(42, 56, 78)
inspStroke.Thickness = 1.4
inspStroke.Parent = inspectorDrawer

local inspIcon = Instance.new("TextLabel")
inspIcon.Name = "Icon"
inspIcon.Size = UDim2.new(0, 50, 0, 50)
inspIcon.Position = UDim2.new(0, 14, 0.5, -25)
inspIcon.BackgroundColor3 = Color3.fromRGB(15, 22, 34)
inspIcon.Font = Enum.Font.GothamBold
inspIcon.Text = "⚔️"
inspIcon.TextSize = 26
inspIcon.ZIndex = 25
inspIcon.Parent = inspectorDrawer
Instance.new("UICorner", inspIcon).CornerRadius = UDim.new(0, 8)

local inspName = Instance.new("TextLabel")
inspName.Name = "ItemName"
inspName.Size = UDim2.new(0, 220, 0, 22)
inspName.Position = UDim2.new(0, 74, 0, 14)
inspName.BackgroundTransparency = 1
inspName.Font = Enum.Font.GothamBold
inspName.Text = "Select an item..."
inspName.TextColor3 = Color3.fromRGB(241, 245, 249)
inspName.TextSize = 14
inspName.TextXAlignment = Enum.TextXAlignment.Left
inspName.ZIndex = 25
inspName.Parent = inspectorDrawer

local inspDesc = Instance.new("TextLabel")
inspDesc.Name = "ItemDesc"
inspDesc.Size = UDim2.new(0, 220, 0, 32)
inspDesc.Position = UDim2.new(0, 74, 0, 36)
inspDesc.BackgroundTransparency = 1
inspDesc.Font = Enum.Font.GothamMedium
inspDesc.Text = "Click any inventory slot to view details, equip, or drop."
inspDesc.TextColor3 = Color3.fromRGB(148, 163, 184)
inspDesc.TextSize = 11
inspDesc.TextXAlignment = Enum.TextXAlignment.Left
inspDesc.TextWrapped = true
inspDesc.ZIndex = 25
inspDesc.Parent = inspectorDrawer

-- Action Buttons in Inspector (Gummy Tactile Buttons)
local inspActionBtn = Instance.new("TextButton")
inspActionBtn.Name = "EquipActionBtn"
inspActionBtn.Size = UDim2.new(0, 100, 0, 36)
inspActionBtn.Position = UDim2.new(1, -215, 0.5, -18)
inspActionBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
inspActionBtn.BorderSizePixel = 0
inspActionBtn.Font = Enum.Font.GothamBold
inspActionBtn.Text = "EQUIP"
inspActionBtn.TextColor3 = Color3.fromRGB(15, 23, 42)
inspActionBtn.TextSize = 12
inspActionBtn.Visible = false
inspActionBtn.ZIndex = 26
inspActionBtn.Parent = inspectorDrawer
Instance.new("UICorner", inspActionBtn).CornerRadius = UDim.new(0, 6)

local inspDropBtn = Instance.new("TextButton")
inspDropBtn.Name = "DropActionBtn"
inspDropBtn.Size = UDim2.new(0, 90, 0, 36)
inspDropBtn.Position = UDim2.new(1, -105, 0.5, -18)
inspDropBtn.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
inspDropBtn.BorderSizePixel = 0
inspDropBtn.Font = Enum.Font.GothamBold
inspDropBtn.Text = "DROP"
inspDropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
inspDropBtn.TextSize = 12
inspDropBtn.Visible = false
inspDropBtn.ZIndex = 26
inspDropBtn.Parent = inspectorDrawer
Instance.new("UICorner", inspDropBtn).CornerRadius = UDim.new(0, 6)

-- =========================================================================
-- BOTTOM HOTBAR (MATCHING ARTSTATION METALLIC LOWER CHASSIS)
-- =========================================================================
local hotbarContainer = Instance.new("Frame")
hotbarContainer.Name = "BottomHotbarChassis"
hotbarContainer.Size = UDim2.new(0, 480, 0, 108)
hotbarContainer.Position = UDim2.new(0.5, -240, 1, -120)
hotbarContainer.BackgroundColor3 = Color3.fromRGB(28, 36, 50)
hotbarContainer.BorderSizePixel = 0
hotbarContainer.ZIndex = 10
hotbarContainer.Parent = screenGui
Instance.new("UICorner", hotbarContainer).CornerRadius = UDim.new(0, 12)

local hotbarStroke = Instance.new("UIStroke")
hotbarStroke.Color = Color3.fromRGB(55, 72, 98)
hotbarStroke.Thickness = 2
hotbarStroke.Parent = hotbarContainer

-- Upper Hotbar Status Row (Credits & Slot Counter Pills)
local statusRow = Instance.new("Frame")
statusRow.Name = "StatusRow"
statusRow.Size = UDim2.new(1, -20, 0, 24)
statusRow.Position = UDim2.new(0, 10, 0, 8)
statusRow.BackgroundTransparency = 1
statusRow.ZIndex = 11
statusRow.Parent = hotbarContainer

local energyPill = Instance.new("TextLabel")
energyPill.Name = "EnergyPill"
energyPill.Size = UDim2.new(0, 130, 1, 0)
energyPill.Position = UDim2.new(0, 0, 0, 0)
energyPill.BackgroundColor3 = Color3.fromRGB(16, 26, 38)
energyPill.Font = Enum.Font.GothamBold
energyPill.Text = "💎 12,500 CR"
energyPill.TextColor3 = Color3.fromRGB(56, 189, 248)
energyPill.TextSize = 11
energyPill.ZIndex = 12
energyPill.Parent = statusRow
Instance.new("UICorner", energyPill).CornerRadius = UDim.new(0, 6)

local slotCapPill = Instance.new("TextLabel")
slotCapPill.Name = "SlotCapPill"
slotCapPill.Size = UDim2.new(0, 130, 1, 0)
slotCapPill.Position = UDim2.new(1, -130, 0, 0)
slotCapPill.BackgroundColor3 = Color3.fromRGB(16, 26, 38)
slotCapPill.Font = Enum.Font.GothamBold
slotCapPill.Text = "🎒 0 / 30 SLOTS"
slotCapPill.TextColor3 = Color3.fromRGB(245, 158, 11)
slotCapPill.TextSize = 11
slotCapPill.ZIndex = 12
slotCapPill.Parent = statusRow
Instance.new("UICorner", slotCapPill).CornerRadius = UDim.new(0, 6)

-- 5 Hotbar Slots
local hotbarSlotRow = Instance.new("Frame")
hotbarSlotRow.Name = "HotbarSlotRow"
hotbarSlotRow.Size = UDim2.new(1, -20, 0, 64)
hotbarSlotRow.Position = UDim2.new(0, 10, 0, 36)
hotbarSlotRow.BackgroundTransparency = 1
hotbarSlotRow.ZIndex = 11
hotbarSlotRow.Parent = hotbarContainer

local hotbarLayout = Instance.new("UIListLayout")
hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hotbarLayout.Padding = UDim.new(0, 12)
hotbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
hotbarLayout.Parent = hotbarSlotRow

-- Top Toggle Inventory Button
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "InventoryToggleBtn"
toggleBtn.Size = UDim2.new(0, 150, 0, 42)
toggleBtn.Position = UDim2.new(1, -170, 0, 20)
toggleBtn.BackgroundColor3 = Color3.fromRGB(22, 30, 44)
toggleBtn.BorderSizePixel = 0
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Text = "🎒 INVENTORY [E]"
toggleBtn.TextColor3 = Color3.fromRGB(56, 189, 248)
toggleBtn.TextSize = 12
toggleBtn.AutoButtonColor = false
toggleBtn.ZIndex = 30
toggleBtn.Parent = screenGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(56, 189, 248)
toggleStroke.Thickness = 1.4
toggleStroke.Parent = toggleBtn

-- =========================================================================
-- SLOT BUILDERS & TACTILE "GOMINOLA" SQUISH / BOUNCE INTERACTION
-- =========================================================================

local function ApplyTactileBounce(btn: GuiButton)
    local originalSize = btn.Size
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset + 4, originalSize.Y.Scale, originalSize.Y.Offset + 4)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = originalSize
        }):Play()
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset - 4, originalSize.Y.Scale, originalSize.Y.Offset - 4)
        }):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = originalSize
        }):Play()
    end)
end

-- Create 30 Grid Slots (6 columns x 5 rows)
for i = 1, 30 do
    local slotCard = Instance.new("TextButton")
    slotCard.Name = "Slot_" .. i
    slotCard.Size = UDim2.new(0, 78, 0, 78)
    slotCard.BackgroundColor3 = Color3.fromRGB(18, 25, 38)
    slotCard.BorderSizePixel = 0
    slotCard.AutoButtonColor = false
    slotCard.Text = ""
    slotCard.ZIndex = 24
    slotCard.Parent = gridScroll
    Instance.new("UICorner", slotCard).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Name = "BevelStroke"
    stroke.Color = Color3.fromRGB(40, 52, 74)
    stroke.Thickness = 1.5
    stroke.Parent = slotCard

    -- Item Icon
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "Icon"
    iconLabel.Size = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 28
    iconLabel.Text = ""
    iconLabel.ZIndex = 25
    iconLabel.Parent = slotCard

    -- Stack Count Badge (Bottom-Right Pill)
    local qtyBadge = Instance.new("TextLabel")
    qtyBadge.Name = "QtyBadge"
    qtyBadge.Size = UDim2.new(0, 26, 0, 16)
    qtyBadge.Position = UDim2.new(1, -28, 1, -18)
    qtyBadge.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
    qtyBadge.Font = Enum.Font.GothamBold
    qtyBadge.Text = ""
    qtyBadge.TextColor3 = Color3.fromRGB(241, 245, 249)
    qtyBadge.TextSize = 10
    qtyBadge.Visible = false
    qtyBadge.ZIndex = 26
    qtyBadge.Parent = slotCard
    Instance.new("UICorner", qtyBadge).CornerRadius = UDim.new(0, 4)

    -- Equipped Indicator (Top-Right Green Pill)
    local eqBadge = Instance.new("TextLabel")
    eqBadge.Name = "EqBadge"
    eqBadge.Size = UDim2.new(0, 28, 0, 14)
    eqBadge.Position = UDim2.new(1, -30, 0, 4)
    eqBadge.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
    eqBadge.Font = Enum.Font.GothamBold
    eqBadge.Text = "EQ"
    eqBadge.TextColor3 = Color3.fromRGB(15, 23, 42)
    eqBadge.TextSize = 9
    eqBadge.Visible = false
    eqBadge.ZIndex = 26
    eqBadge.Parent = slotCard
    Instance.new("UICorner", eqBadge).CornerRadius = UDim.new(0, 4)

    ApplyTactileBounce(slotCard)
    slotFrames[i] = slotCard
end

-- Create 5 Hotbar Slots
for i = 1, 5 do
    local hbSlot = Instance.new("TextButton")
    hbSlot.Name = "HBSlot_" .. i
    hbSlot.Size = UDim2.new(0, 64, 0, 64)
    hbSlot.BackgroundColor3 = Color3.fromRGB(18, 25, 38)
    hbSlot.BorderSizePixel = 0
    hbSlot.AutoButtonColor = false
    hbSlot.Text = ""
    hbSlot.ZIndex = 12
    hbSlot.Parent = hotbarSlotRow
    Instance.new("UICorner", hbSlot).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Name = "BevelStroke"
    stroke.Color = Color3.fromRGB(45, 60, 84)
    stroke.Thickness = 1.5
    stroke.Parent = hbSlot

    -- Hotkey Number (Top-Left)
    local numLabel = Instance.new("TextLabel")
    numLabel.Size = UDim2.new(0, 16, 0, 16)
    numLabel.Position = UDim2.new(0, 4, 0, 4)
    numLabel.BackgroundTransparency = 1
    numLabel.Font = Enum.Font.GothamBold
    numLabel.Text = tostring(i)
    numLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
    numLabel.TextSize = 11
    numLabel.ZIndex = 14
    numLabel.Parent = hbSlot

    -- Icon
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "Icon"
    iconLabel.Size = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 24
    iconLabel.Text = ""
    iconLabel.ZIndex = 13
    iconLabel.Parent = hbSlot

    -- Stack Badge
    local qtyBadge = Instance.new("TextLabel")
    qtyBadge.Name = "QtyBadge"
    qtyBadge.Size = UDim2.new(0, 24, 0, 14)
    qtyBadge.Position = UDim2.new(1, -26, 1, -16)
    qtyBadge.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
    qtyBadge.Font = Enum.Font.GothamBold
    qtyBadge.Text = ""
    qtyBadge.TextColor3 = Color3.fromRGB(241, 245, 249)
    qtyBadge.TextSize = 9
    qtyBadge.Visible = false
    qtyBadge.ZIndex = 14
    qtyBadge.Parent = hbSlot
    Instance.new("UICorner", qtyBadge).CornerRadius = UDim.new(0, 4)

    -- Active Indicator Badge (Bottom Center)
    local activeBadge = Instance.new("TextLabel")
    activeBadge.Name = "ActiveBadge"
    activeBadge.Size = UDim2.new(0.8, 0, 0, 12)
    activeBadge.Position = UDim2.new(0.1, 0, 1, -14)
    activeBadge.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
    activeBadge.Font = Enum.Font.GothamBold
    activeBadge.Text = "ACTIVE"
    activeBadge.TextColor3 = Color3.fromRGB(15, 23, 42)
    activeBadge.TextSize = 8
    activeBadge.Visible = false
    activeBadge.ZIndex = 15
    activeBadge.Parent = hbSlot
    Instance.new("UICorner", activeBadge).CornerRadius = UDim.new(0, 3)

    ApplyTactileBounce(hbSlot)
    hotbarFrames[i] = hbSlot
end

-- =========================================================================
-- RENDERING & STATE SYNCHRONIZATION
-- =========================================================================

local function IsItemEquipped(slot: InventorySlot?): boolean
    if not slot or not currentProfile or not currentProfile.Equipment then
        return false
    end
    local eqW = currentProfile.Equipment.Weapon
    local eqA = currentProfile.Equipment.Armor
    return (eqW and eqW.UUID == slot.UUID) or (eqA and eqA.UUID == slot.UUID) or false
end

local function UpdateInspector(slotIndex: number?)
    if not slotIndex or not currentProfile or not currentProfile.Slots[slotIndex] then
        inspIcon.Text = "📦"
        inspName.Text = "Select an item..."
        inspName.TextColor3 = Color3.fromRGB(241, 245, 249)
        inspDesc.Text = "Click any inventory slot to view stats, equip, or drop."
        inspActionBtn.Visible = false
        inspDropBtn.Visible = false
        return
    end

    local slot = currentProfile.Slots[slotIndex]
    local def = ItemDatabase.GetItem(slot.ItemId)
    if not def then return end

    local color = ItemDatabase.GetRarityColor(def.Rarity)
    inspIcon.Text = def.IconGlyph
    inspName.Text = string.format("%s (x%d)", def.Name, slot.Quantity)
    inspName.TextColor3 = color

    local statsTxt = def.Description
    if def.Stats.Damage then
        statsTxt = string.format("⚡ DAMAGE: +%d  •  %s", def.Stats.Damage, statsTxt)
    elseif def.Stats.Defense then
        statsTxt = string.format("🛡️ DEFENSE: +%d  •  %s", def.Stats.Defense, statsTxt)
    elseif def.Stats.HealAmount then
        statsTxt = string.format("❤️ HEAL: +%d HP  •  %s", def.Stats.HealAmount, statsTxt)
    end
    inspDesc.Text = statsTxt

    inspDropBtn.Visible = true

    if def.EquipSlot then
        inspActionBtn.Visible = true
        local isEq = IsItemEquipped(slot)
        if isEq then
            inspActionBtn.Text = "UNEQUIP"
            inspActionBtn.BackgroundColor3 = Color3.fromRGB(245, 158, 11)
        else
            inspActionBtn.Text = "EQUIP"
            inspActionBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
        end
    elseif def.Category == "Consumable" then
        inspActionBtn.Visible = true
        inspActionBtn.Text = "USE"
        inspActionBtn.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
    else
        inspActionBtn.Visible = false
    end
end

local function RenderInventory()
    if not currentProfile then return end

    local usedSlots = 0
    for i = 1, 30 do
        if currentProfile.Slots[i] then
            usedSlots += 1
        end
    end
    slotCapPill.Text = string.format("🎒 %d / 30 SLOTS", usedSlots)

    -- Filter logic
    local searchLower = string.lower(searchQuery)

    -- Render 30 Main Grid Slots
    for i = 1, 30 do
        local frame = slotFrames[i]
        local slotData = currentProfile.Slots[i]
        local icon = frame:FindFirstChild("Icon") :: TextLabel
        local qtyBadge = frame:FindFirstChild("QtyBadge") :: TextLabel
        local eqBadge = frame:FindFirstChild("EqBadge") :: TextLabel
        local stroke = frame:FindFirstChild("BevelStroke") :: UIStroke

        if slotData then
            local def = ItemDatabase.GetItem(slotData.ItemId)
            local matchesCat = (currentCategoryFilter == "All") or (def and def.Category == currentCategoryFilter)
            local matchesSearch = (searchLower == "") or (def and string.find(string.lower(def.Name), searchLower) ~= nil)

            if matchesCat and matchesSearch and def then
                frame.Visible = true
                icon.Text = def.IconGlyph

                if slotData.Quantity > 1 then
                    qtyBadge.Text = "x" .. slotData.Quantity
                    qtyBadge.Visible = true
                else
                    qtyBadge.Visible = false
                end

                local isEq = IsItemEquipped(slotData)
                eqBadge.Visible = isEq

                if isEq then
                    stroke.Color = Color3.fromRGB(16, 185, 129)
                    stroke.Thickness = 2
                elseif selectedSlotIndex == i then
                    stroke.Color = Color3.fromRGB(56, 189, 248)
                    stroke.Thickness = 2
                else
                    stroke.Color = Color3.fromRGB(45, 60, 85)
                    stroke.Thickness = 1.5
                end
            else
                frame.Visible = false
            end
        else
            -- Empty Slot
            frame.Visible = (currentCategoryFilter == "All" and searchLower == "")
            icon.Text = ""
            qtyBadge.Visible = false
            eqBadge.Visible = false
            stroke.Color = Color3.fromRGB(30, 40, 56)
            stroke.Thickness = 1.2
        end
    end

    -- Render 5 Hotbar Slots
    for i = 1, 5 do
        local frame = hotbarFrames[i]
        local slotData = currentProfile.Slots[i]
        local icon = frame:FindFirstChild("Icon") :: TextLabel
        local qtyBadge = frame:FindFirstChild("QtyBadge") :: TextLabel
        local activeBadge = frame:FindFirstChild("ActiveBadge") :: TextLabel
        local stroke = frame:FindFirstChild("BevelStroke") :: UIStroke

        if slotData then
            local def = ItemDatabase.GetItem(slotData.ItemId)
            if def then
                icon.Text = def.IconGlyph

                if slotData.Quantity > 1 then
                    qtyBadge.Text = "x" .. slotData.Quantity
                    qtyBadge.Visible = true
                else
                    qtyBadge.Visible = false
                end

                local isEq = IsItemEquipped(slotData)
                activeBadge.Visible = isEq

                if isEq then
                    stroke.Color = Color3.fromRGB(56, 189, 248)
                    stroke.Thickness = 2.2
                    frame.BackgroundColor3 = Color3.fromRGB(24, 38, 58)
                else
                    stroke.Color = Color3.fromRGB(45, 60, 84)
                    stroke.Thickness = 1.5
                    frame.BackgroundColor3 = Color3.fromRGB(18, 25, 38)
                end
            end
        else
            icon.Text = ""
            qtyBadge.Visible = false
            activeBadge.Visible = false
            stroke.Color = Color3.fromRGB(35, 46, 64)
            stroke.Thickness = 1.2
            frame.BackgroundColor3 = Color3.fromRGB(18, 25, 38)
        end
    end

    UpdateInspector(selectedSlotIndex)
end

_G.__RenderInventoryFunc = RenderInventory

-- Slot Click Handlers
for i = 1, 30 do
    local btn = slotFrames[i]
    btn.MouseButton1Click:Connect(function()
        if not currentProfile then return end
        local slotData = currentProfile.Slots[i]
        if slotData then
            selectedSlotIndex = i
            RenderInventory()
        end
    end)
end

-- Inspector Action Buttons Click
inspActionBtn.MouseButton1Click:Connect(function()
    if not selectedSlotIndex or not currentProfile then return end
    local slot = currentProfile.Slots[selectedSlotIndex]
    if not slot then return end

    local def = ItemDatabase.GetItem(slot.ItemId)
    if not def then return end

    if def.EquipSlot then
        -- Toggle equip on server
        EquipItemEvent:FireServer(selectedSlotIndex, def.EquipSlot)
    elseif def.Category == "Consumable" then
        UseItemEvent:FireServer(selectedSlotIndex)
    end
end)

inspDropBtn.MouseButton1Click:Connect(function()
    if not selectedSlotIndex or not currentProfile then return end
    DropItemEvent:FireServer(selectedSlotIndex, 1)
end)

-- Search Input Filter
searchInput:GetPropertyChangedSignal("Text"):Connect(function()
    searchQuery = searchInput.Text
    RenderInventory()
end)

-- Toggle Inventory Window
local function ToggleInventory()
    isInventoryOpen = not isInventoryOpen
    mainContainer.Visible = isInventoryOpen

    if isInventoryOpen then
        mainContainer.Position = UDim2.new(0.5, -290, 0.5, -240)
        TweenService:Create(mainContainer, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -290, 0.5, -280)
        }):Play()
        RenderInventory()
    end
end

toggleBtn.MouseButton1Click:Connect(ToggleInventory)
closeBtn.MouseButton1Click:Connect(ToggleInventory)

-- =========================================================================
-- KEYBOARD HOTKEY TOGGLING (1..5 QUICK-EQUIP & TOGGLE UNEQUIP)
-- =========================================================================

local function HandleHotbarKey(slotIndex: number)
    if not currentProfile then return end
    local slotData = currentProfile.Slots[slotIndex]
    if not slotData then return end

    local def = ItemDatabase.GetItem(slotData.ItemId)
    if not def then return end

    if def.Category == "Consumable" then
        UseItemEvent:FireServer(slotIndex)
    elseif def.EquipSlot then
        -- TOGGLE EQUIP / UNEQUIP ON PRESS!
        -- If already equipped -> Server will unequip!
        -- If not equipped -> Server will equip!
        EquipItemEvent:FireServer(slotIndex, def.EquipSlot)
    end
end

-- Hotbar Slot Click Handlers
for i = 1, 5 do
    local hbSlot = hotbarFrames[i]
    hbSlot.MouseButton1Click:Connect(function()
        HandleHotbarKey(i)
    end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.E then
        ToggleInventory()
    elseif input.KeyCode == Enum.KeyCode.One then
        HandleHotbarKey(1)
    elseif input.KeyCode == Enum.KeyCode.Two then
        HandleHotbarKey(2)
    elseif input.KeyCode == Enum.KeyCode.Three then
        HandleHotbarKey(3)
    elseif input.KeyCode == Enum.KeyCode.Four then
        HandleHotbarKey(4)
    elseif input.KeyCode == Enum.KeyCode.Five then
        HandleHotbarKey(5)
    end
end)

-- Receive Server Sync
SyncProfileEvent.OnClientEvent:Connect(function(profile: InventoryProfile)
    currentProfile = profile
    RenderInventory()
end)

print("⚡ [Inventory Suite] ArtStation-Grade Tactile Gominola UI & Hotbar Initialized.")
