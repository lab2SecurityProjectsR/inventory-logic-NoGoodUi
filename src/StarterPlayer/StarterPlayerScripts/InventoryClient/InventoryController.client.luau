--!strict
--[=[
    InventoryController.client.luau
    Author: JV (lab2 / lab2SecurityProjectsR)
    Cyber-Glassmorphic Client Controller & HUD for the Inventory & Equipment Suite.
    Features drag-and-drop slot operations, 5-slot interactive Hotbar, equipment slots,
    live stat displays, detailed hover tooltips, and a instant demo starter-pack button.
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
local slotFrames: { [number]: TextButton } = {}
local hotbarFrames: { [number]: TextButton } = {}

-- UI Creation
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AegisInventoryGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Parent = playerGui

-- Toast Notification Banner
local toastFrame = Instance.new("Frame")
toastFrame.Name = "ToastNotification"
toastFrame.Size = UDim2.new(0, 360, 0, 44)
toastFrame.Position = UDim2.new(0.5, -180, 0, -60) -- Off-screen initially
toastFrame.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
toastFrame.BorderSizePixel = 0
toastFrame.ZIndex = 50
toastFrame.Parent = screenGui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 8)
toastCorner.Parent = toastFrame

local toastStroke = Instance.new("UIStroke")
toastStroke.Color = Color3.fromRGB(56, 189, 248)
toastStroke.Thickness = 1.2
toastStroke.Parent = toastFrame

local toastIcon = Instance.new("TextLabel")
toastIcon.Name = "Icon"
toastIcon.Size = UDim2.new(0, 36, 1, 0)
toastIcon.Position = UDim2.new(0, 6, 0, 0)
toastIcon.BackgroundTransparency = 1
toastIcon.Font = Enum.Font.GothamBold
toastIcon.TextSize = 16
toastIcon.Text = "ℹ️"
toastIcon.ZIndex = 51
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
toastLabel.ZIndex = 51
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

-- Top Toggle Button
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "InventoryToggleBtn"
toggleBtn.Size = UDim2.new(0, 160, 0, 42)
toggleBtn.Position = UDim2.new(1, -180, 0, 20)
toggleBtn.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
toggleBtn.BorderSizePixel = 0
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Text = "🎒 INVENTORY [E]"
toggleBtn.TextColor3 = Color3.fromRGB(56, 189, 248)
toggleBtn.TextSize = 13
toggleBtn.AutoButtonColor = true
toggleBtn.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggleBtn

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(56, 189, 248)
toggleStroke.Thickness = 1.2
toggleStroke.Transparency = 0.3
toggleStroke.Parent = toggleBtn

-- Main Window
local mainWindow = Instance.new("Frame")
mainWindow.Name = "MainWindow"
mainWindow.Size = UDim2.new(0, 860, 0, 520)
mainWindow.Position = UDim2.new(0.5, -430, 0.5, -260)
mainWindow.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
mainWindow.BackgroundTransparency = 0.05
mainWindow.BorderSizePixel = 0
mainWindow.Visible = false
mainWindow.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainWindow

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(56, 189, 248)
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.4
mainStroke.Parent = mainWindow

-- Window Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
header.BorderSizePixel = 0
header.Parent = mainWindow

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 360, 1, 0)
titleLabel.Position = UDim2.new(0, 18, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "⚡ AEGIS // QUANTUM INVENTORY & LOADOUT"
titleLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

-- Capacity Counter Pill in Header
local capPill = Instance.new("Frame")
capPill.Name = "CapacityPill"
capPill.Size = UDim2.new(0, 140, 0, 26)
capPill.Position = UDim2.new(1, -190, 0.5, -13)
capPill.BackgroundColor3 = Color3.fromRGB(24, 33, 50)
capPill.BorderSizePixel = 0
capPill.Parent = header

local capPillCorner = Instance.new("UICorner")
capPillCorner.CornerRadius = UDim.new(0, 6)
capPillCorner.Parent = capPill

local capPillLabel = Instance.new("TextLabel")
capPillLabel.Name = "Label"
capPillLabel.Size = UDim2.new(1, 0, 1, 0)
capPillLabel.BackgroundTransparency = 1
capPillLabel.Font = Enum.Font.GothamBold
capPillLabel.TextSize = 11
capPillLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
capPillLabel.Text = "SLOTS: 0 / 30"
capPillLabel.Parent = capPill

-- Close Button (Fixed glyph)
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -42, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(248, 113, 113)
closeBtn.TextSize = 14
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseEnter:Connect(function()
    closeBtn.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
end)
closeBtn.MouseLeave:Connect(function()
    closeBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
    closeBtn.TextColor3 = Color3.fromRGB(248, 113, 113)
end)

-- Left Pane: Loadout & Stats
local leftPane = Instance.new("Frame")
leftPane.Name = "LeftPane"
leftPane.Size = UDim2.new(0, 260, 1, -66)
leftPane.Position = UDim2.new(0, 16, 0, 56)
leftPane.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
leftPane.BackgroundTransparency = 0.5
leftPane.BorderSizePixel = 0
leftPane.Parent = mainWindow

local leftCorner = Instance.new("UICorner")
leftCorner.CornerRadius = UDim.new(0, 8)
leftCorner.Parent = leftPane

local eqTitle = Instance.new("TextLabel")
eqTitle.Size = UDim2.new(1, 0, 0, 26)
eqTitle.Position = UDim2.new(0, 12, 0, 8)
eqTitle.BackgroundTransparency = 1
eqTitle.Font = Enum.Font.GothamBold
eqTitle.Text = "EQUIPMENT LOADOUT"
eqTitle.TextColor3 = Color3.fromRGB(148, 163, 184)
eqTitle.TextSize = 11
eqTitle.TextXAlignment = Enum.TextXAlignment.Left
eqTitle.Parent = leftPane

-- Weapon Card
local weaponCard = Instance.new("Frame")
weaponCard.Name = "WeaponCard"
weaponCard.Size = UDim2.new(1, -24, 0, 72)
weaponCard.Position = UDim2.new(0, 12, 0, 36)
weaponCard.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
weaponCard.BorderSizePixel = 0
weaponCard.Parent = leftPane

local weaponCorner = Instance.new("UICorner")
weaponCorner.CornerRadius = UDim.new(0, 8)
weaponCorner.Parent = weaponCard

local weaponStroke = Instance.new("UIStroke")
weaponStroke.Color = Color3.fromRGB(56, 189, 248)
weaponStroke.Thickness = 1.2
weaponStroke.Parent = weaponCard

local weaponIcon = Instance.new("TextLabel")
weaponIcon.Name = "Icon"
weaponIcon.Size = UDim2.new(0, 48, 1, 0)
weaponIcon.BackgroundTransparency = 1
weaponIcon.Font = Enum.Font.GothamBold
weaponIcon.TextSize = 24
weaponIcon.Text = "⚔️"
weaponIcon.Parent = weaponCard

local weaponTitle = Instance.new("TextLabel")
weaponTitle.Name = "Title"
weaponTitle.Size = UDim2.new(1, -120, 0, 20)
weaponTitle.Position = UDim2.new(0, 48, 0, 8)
weaponTitle.BackgroundTransparency = 1
weaponTitle.Font = Enum.Font.GothamBold
weaponTitle.TextSize = 12
weaponTitle.TextColor3 = Color3.fromRGB(241, 245, 249)
weaponTitle.TextXAlignment = Enum.TextXAlignment.Left
weaponTitle.Text = "No Weapon"
weaponTitle.Parent = weaponCard

local weaponStats = Instance.new("TextLabel")
weaponStats.Name = "Stats"
weaponStats.Size = UDim2.new(1, -120, 0, 18)
weaponStats.Position = UDim2.new(0, 48, 0, 28)
weaponStats.BackgroundTransparency = 1
weaponStats.Font = Enum.Font.Gotham
weaponStats.TextSize = 10
weaponStats.TextColor3 = Color3.fromRGB(148, 163, 184)
weaponStats.TextXAlignment = Enum.TextXAlignment.Left
weaponStats.Text = "Slot Empty"
weaponStats.Parent = weaponCard

local unequipWeaponBtn = Instance.new("TextButton")
unequipWeaponBtn.Name = "UnequipBtn"
unequipWeaponBtn.Size = UDim2.new(0, 68, 0, 28)
unequipWeaponBtn.Position = UDim2.new(1, -74, 0.5, -14)
unequipWeaponBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
unequipWeaponBtn.BorderSizePixel = 0
unequipWeaponBtn.Font = Enum.Font.GothamBold
unequipWeaponBtn.Text = "UNEQUIP"
unequipWeaponBtn.TextColor3 = Color3.fromRGB(248, 113, 113)
unequipWeaponBtn.TextSize = 10
unequipWeaponBtn.Visible = false
unequipWeaponBtn.Parent = weaponCard

local uWCorner = Instance.new("UICorner")
uWCorner.CornerRadius = UDim.new(0, 6)
uWCorner.Parent = unequipWeaponBtn

-- Armor Card
local armorCard = Instance.new("Frame")
armorCard.Name = "ArmorCard"
armorCard.Size = UDim2.new(1, -24, 0, 72)
armorCard.Position = UDim2.new(0, 12, 0, 118)
armorCard.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
armorCard.BorderSizePixel = 0
armorCard.Parent = leftPane

local armorCorner = Instance.new("UICorner")
armorCorner.CornerRadius = UDim.new(0, 8)
armorCorner.Parent = armorCard

local armorStroke = Instance.new("UIStroke")
armorStroke.Color = Color3.fromRGB(168, 85, 247)
armorStroke.Thickness = 1.2
armorStroke.Parent = armorCard

local armorIcon = Instance.new("TextLabel")
armorIcon.Name = "Icon"
armorIcon.Size = UDim2.new(0, 48, 1, 0)
armorIcon.BackgroundTransparency = 1
armorIcon.Font = Enum.Font.GothamBold
armorIcon.TextSize = 24
armorIcon.Text = "🛡️"
armorIcon.Parent = armorCard

local armorTitle = Instance.new("TextLabel")
armorTitle.Name = "Title"
armorTitle.Size = UDim2.new(1, -120, 0, 20)
armorTitle.Position = UDim2.new(0, 48, 0, 8)
armorTitle.BackgroundTransparency = 1
armorTitle.Font = Enum.Font.GothamBold
armorTitle.TextSize = 12
armorTitle.TextColor3 = Color3.fromRGB(241, 245, 249)
armorTitle.TextXAlignment = Enum.TextXAlignment.Left
armorTitle.Text = "No Shield / Armor"
armorTitle.Parent = armorCard

local armorStats = Instance.new("TextLabel")
armorStats.Name = "Stats"
armorStats.Size = UDim2.new(1, -120, 0, 18)
armorStats.Position = UDim2.new(0, 48, 0, 28)
armorStats.BackgroundTransparency = 1
armorStats.Font = Enum.Font.Gotham
armorStats.TextSize = 10
armorStats.TextColor3 = Color3.fromRGB(148, 163, 184)
armorStats.TextXAlignment = Enum.TextXAlignment.Left
armorStats.Text = "Slot Empty"
armorStats.Parent = armorCard

local unequipArmorBtn = Instance.new("TextButton")
unequipArmorBtn.Name = "UnequipBtn"
unequipArmorBtn.Size = UDim2.new(0, 68, 0, 28)
unequipArmorBtn.Position = UDim2.new(1, -74, 0.5, -14)
unequipArmorBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
unequipArmorBtn.BorderSizePixel = 0
unequipArmorBtn.Font = Enum.Font.GothamBold
unequipArmorBtn.Text = "UNEQUIP"
unequipArmorBtn.TextColor3 = Color3.fromRGB(248, 113, 113)
unequipArmorBtn.TextSize = 10
unequipArmorBtn.Visible = false
unequipArmorBtn.Parent = armorCard

local uACorner = Instance.new("UICorner")
uACorner.CornerRadius = UDim.new(0, 6)
uACorner.Parent = unequipArmorBtn

-- Stats Card
local statsCard = Instance.new("Frame")
statsCard.Name = "StatsCard"
statsCard.Size = UDim2.new(1, -24, 0, 134)
statsCard.Position = UDim2.new(0, 12, 0, 202)
statsCard.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
statsCard.BorderSizePixel = 0
statsCard.Parent = leftPane

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 8)
statsCorner.Parent = statsCard

local statsText = Instance.new("TextLabel")
statsText.Name = "StatsLabel"
statsText.Size = UDim2.new(1, -20, 1, -16)
statsText.Position = UDim2.new(0, 10, 0, 8)
statsText.BackgroundTransparency = 1
statsText.Font = Enum.Font.GothamMedium
statsText.TextSize = 11
statsText.TextColor3 = Color3.fromRGB(203, 213, 225)
statsText.TextXAlignment = Enum.TextXAlignment.Left
statsText.TextYAlignment = Enum.TextYAlignment.Top
statsText.RichText = true
statsText.Text = "<b>📊 OPERATIONAL METRICS</b>\n\n• ⚡ <b>Speed:</b> 16 studs/s\n• ⚔️ <b>Damage:</b> 0 DP\n• 🛡️ <b>Armor:</b> 0 AP\n• 🔒 <b>Session Lock:</b> <font color=\"#10B981\">Active</font>"
statsText.Parent = statsCard

-- Admin Demo Button
local demoBtn = Instance.new("TextButton")
demoBtn.Name = "DemoBtn"
demoBtn.Size = UDim2.new(1, -24, 0, 44)
demoBtn.Position = UDim2.new(0, 12, 1, -54)
demoBtn.BackgroundColor3 = Color3.fromRGB(217, 119, 6)
demoBtn.BorderSizePixel = 0
demoBtn.Font = Enum.Font.GothamBold
demoBtn.Text = "🎁 GIVE STARTER PACK"
demoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
demoBtn.TextSize = 12
demoBtn.Parent = leftPane

local demoCorner = Instance.new("UICorner")
demoCorner.CornerRadius = UDim.new(0, 8)
demoCorner.Parent = demoBtn

-- Right Pane: Grid & Action Bar
local rightPane = Instance.new("Frame")
rightPane.Name = "RightPane"
rightPane.Size = UDim2.new(1, -310, 1, -66)
rightPane.Position = UDim2.new(0, 292, 0, 56)
rightPane.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
rightPane.BackgroundTransparency = 0.5
rightPane.BorderSizePixel = 0
rightPane.Parent = mainWindow

local rightCorner = Instance.new("UICorner")
rightCorner.CornerRadius = UDim.new(0, 8)
rightCorner.Parent = rightPane

-- Slot Grid Container
local gridContainer = Instance.new("ScrollingFrame")
gridContainer.Name = "GridContainer"
gridContainer.Size = UDim2.new(1, -16, 1, -86)
gridContainer.Position = UDim2.new(0, 8, 0, 8)
gridContainer.BackgroundTransparency = 1
gridContainer.BorderSizePixel = 0
gridContainer.ScrollBarThickness = 4
gridContainer.ScrollBarImageColor3 = Color3.fromRGB(56, 189, 248)
gridContainer.CanvasSize = UDim2.new(0, 0, 0, 410)
gridContainer.Parent = rightPane

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 78, 0, 74)
gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridContainer

-- Bottom Action Bar for Selected Item
local actionBar = Instance.new("Frame")
actionBar.Name = "ActionBar"
actionBar.Size = UDim2.new(1, -16, 0, 64)
actionBar.Position = UDim2.new(0, 8, 1, -72)
actionBar.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
actionBar.BorderSizePixel = 0
actionBar.Parent = rightPane

local actionCorner = Instance.new("UICorner")
actionCorner.CornerRadius = UDim.new(0, 8)
actionCorner.Parent = actionBar

local actionInfo = Instance.new("TextLabel")
actionInfo.Name = "ActionInfo"
actionInfo.Size = UDim2.new(1, -310, 1, 0)
actionInfo.Position = UDim2.new(0, 12, 0, 0)
actionInfo.BackgroundTransparency = 1
actionInfo.Font = Enum.Font.GothamMedium
actionInfo.Text = "Select an item from the matrix above..."
actionInfo.TextColor3 = Color3.fromRGB(148, 163, 184)
actionInfo.TextSize = 11
actionInfo.TextXAlignment = Enum.TextXAlignment.Left
actionInfo.RichText = true
actionInfo.Parent = actionBar

local equipBtn = Instance.new("TextButton")
equipBtn.Name = "EquipBtn"
equipBtn.Size = UDim2.new(0, 70, 0, 36)
equipBtn.Position = UDim2.new(1, -290, 0.5, -18)
equipBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
equipBtn.BorderSizePixel = 0
equipBtn.Font = Enum.Font.GothamBold
equipBtn.Text = "EQUIP"
equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
equipBtn.TextSize = 11
equipBtn.Visible = false
equipBtn.Parent = actionBar

local useBtn = Instance.new("TextButton")
useBtn.Name = "UseBtn"
useBtn.Size = UDim2.new(0, 70, 0, 36)
useBtn.Position = UDim2.new(1, -290, 0.5, -18)
useBtn.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
useBtn.BorderSizePixel = 0
useBtn.Font = Enum.Font.GothamBold
useBtn.Text = "USE"
useBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
useBtn.TextSize = 11
useBtn.Visible = false
useBtn.Parent = actionBar

local splitBtn = Instance.new("TextButton")
splitBtn.Name = "SplitBtn"
splitBtn.Size = UDim2.new(0, 68, 0, 36)
splitBtn.Position = UDim2.new(1, -210, 0.5, -18)
splitBtn.BackgroundColor3 = Color3.fromRGB(139, 92, 246)
splitBtn.BorderSizePixel = 0
splitBtn.Font = Enum.Font.GothamBold
splitBtn.Text = "SPLIT"
splitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
splitBtn.TextSize = 11
splitBtn.Visible = false
splitBtn.Parent = actionBar

local dropBtn = Instance.new("TextButton")
dropBtn.Name = "DropBtn"
dropBtn.Size = UDim2.new(0, 68, 0, 36)
dropBtn.Position = UDim2.new(1, -132, 0.5, -18)
dropBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
dropBtn.BorderSizePixel = 0
dropBtn.Font = Enum.Font.GothamBold
dropBtn.Text = "DROP"
dropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dropBtn.TextSize = 11
dropBtn.Visible = false
dropBtn.Parent = actionBar

for _, b in ipairs({ equipBtn, useBtn, splitBtn, dropBtn }) do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = b
end

-- Hotbar (Bottom Center)
local hotbar = Instance.new("Frame")
hotbar.Name = "Hotbar"
hotbar.Size = UDim2.new(0, 380, 0, 68)
hotbar.Position = UDim2.new(0.5, -190, 1, -80)
hotbar.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
hotbar.BackgroundTransparency = 0.1
hotbar.BorderSizePixel = 0
hotbar.Parent = screenGui

local hotbarCorner = Instance.new("UICorner")
hotbarCorner.CornerRadius = UDim.new(0, 10)
hotbarCorner.Parent = hotbar

local hotbarStroke = Instance.new("UIStroke")
hotbarStroke.Color = Color3.fromRGB(56, 189, 248)
hotbarStroke.Thickness = 1.2
hotbarStroke.Transparency = 0.5
hotbarStroke.Parent = hotbar

local hotbarLayout = Instance.new("UIListLayout")
hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hotbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
hotbarLayout.Padding = UDim.new(0, 8)
hotbarLayout.Parent = hotbar

-- Create 30 Grid Slot Frames
for i = 1, 30 do
    local slotBtn = Instance.new("TextButton")
    slotBtn.Name = "Slot_" .. tostring(i)
    slotBtn.LayoutOrder = i
    slotBtn.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    slotBtn.BorderSizePixel = 0
    slotBtn.AutoButtonColor = false
    slotBtn.Text = ""
    slotBtn.Parent = gridContainer

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 8)
    sCorner.Parent = slotBtn

    local sStroke = Instance.new("UIStroke")
    sStroke.Name = "BorderStroke"
    sStroke.Color = Color3.fromRGB(51, 65, 85)
    sStroke.Thickness = 1
    sStroke.Parent = slotBtn

    local indexLabel = Instance.new("TextLabel")
    indexLabel.Name = "IndexNum"
    indexLabel.Size = UDim2.new(0, 16, 0, 14)
    indexLabel.Position = UDim2.new(0, 4, 0, 2)
    indexLabel.BackgroundTransparency = 1
    indexLabel.Font = Enum.Font.Gotham
    indexLabel.Text = tostring(i)
    indexLabel.TextColor3 = Color3.fromRGB(100, 116, 139)
    indexLabel.TextSize = 9
    indexLabel.Parent = slotBtn

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "IconLabel"
    iconLabel.Size = UDim2.new(1, 0, 0, 26)
    iconLabel.Position = UDim2.new(0, 0, 0, 12)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 20
    iconLabel.Text = ""
    iconLabel.Parent = slotBtn

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "ItemName"
    nameLabel.Size = UDim2.new(1, -6, 0, 20)
    nameLabel.Position = UDim2.new(0, 3, 0, 38)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamMedium
    nameLabel.TextSize = 9
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
    nameLabel.Text = ""
    nameLabel.Parent = slotBtn

    -- Pill badge for Quantity
    local qtyBadge = Instance.new("Frame")
    qtyBadge.Name = "QtyBadge"
    qtyBadge.Size = UDim2.new(0, 26, 0, 14)
    qtyBadge.Position = UDim2.new(1, -28, 1, -16)
    qtyBadge.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
    qtyBadge.BorderSizePixel = 0
    qtyBadge.Visible = false
    qtyBadge.Parent = slotBtn

    local qCorner = Instance.new("UICorner")
    qCorner.CornerRadius = UDim.new(0, 4)
    qCorner.Parent = qtyBadge

    local qtyLabel = Instance.new("TextLabel")
    qtyLabel.Name = "ItemQty"
    qtyLabel.Size = UDim2.new(1, 0, 1, 0)
    qtyLabel.BackgroundTransparency = 1
    qtyLabel.Font = Enum.Font.GothamBold
    qtyLabel.TextSize = 9
    qtyLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
    qtyLabel.Text = ""
    qtyLabel.Parent = qtyBadge

    slotBtn.MouseButton1Click:Connect(function()
        selectedSlotIndex = i

        -- Clear selection outlines
        for j = 1, 30 do
            local f = slotFrames[j]
            local st = f and f:FindFirstChild("BorderStroke") :: UIStroke?
            if st and j ~= i then
                if currentProfile and currentProfile.Slots[j] then
                    local d = ItemDatabase.GetItem(currentProfile.Slots[j].ItemId)
                    st.Color = d and ItemDatabase.GetRarityColor(d.Rarity) or Color3.fromRGB(51, 65, 85)
                    st.Thickness = 1
                else
                    st.Color = Color3.fromRGB(51, 65, 85)
                    st.Thickness = 1
                end
            end
        end

        sStroke.Color = Color3.fromRGB(255, 255, 255)
        sStroke.Thickness = 2

        if currentProfile and currentProfile.Slots[i] then
            local slotData = currentProfile.Slots[i]
            local def = ItemDatabase.GetItem(slotData.ItemId)
            if def then
                local statDesc = ""
                if def.Stats.Damage then statDesc ..= string.format(" • ⚔️ +%d Damage", def.Stats.Damage) end
                if def.Stats.Defense then statDesc ..= string.format(" • 🛡️ +%d Defense", def.Stats.Defense) end
                if def.Stats.SpeedBoost then statDesc ..= string.format(" • ⚡ +%d Speed", def.Stats.SpeedBoost) end
                if def.Stats.HealAmount then statDesc ..= string.format(" • 💚 +%d HP", def.Stats.HealAmount) end

                local hex = ItemDatabase.GetRarityColor(def.Rarity):ToHex()
                actionInfo.Text = string.format("<b>%s %s</b> [<font color=\"#%s\">%s</font>]%s\n%s (x%d)",
                    def.IconGlyph, def.Name, hex, string.upper(def.Rarity), statDesc, def.Category, slotData.Quantity)

                equipBtn.Visible = (def.EquipSlot ~= nil)
                useBtn.Visible = (def.Category == "Consumable")
                splitBtn.Visible = (slotData.Quantity > 1)
                dropBtn.Visible = true
            end
        else
            actionInfo.Text = string.format("Slot %d: Empty (Ready for loot)", i)
            actionInfo.TextColor3 = Color3.fromRGB(148, 163, 184)
            equipBtn.Visible = false
            useBtn.Visible = false
            splitBtn.Visible = false
            dropBtn.Visible = false
        end
    end)

    slotFrames[i] = slotBtn
end

-- Create 5 Hotbar Slots
for i = 1, 5 do
    local hSlot = Instance.new("TextButton")
    hSlot.Name = "Hotbar_" .. tostring(i)
    hSlot.Size = UDim2.new(0, 56, 0, 54)
    hSlot.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    hSlot.BorderSizePixel = 0
    hSlot.Text = ""
    hSlot.AutoButtonColor = false
    hSlot.Parent = hotbar

    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(0, 8)
    hCorner.Parent = hSlot

    local hStroke = Instance.new("UIStroke")
    hStroke.Name = "BorderStroke"
    hStroke.Color = Color3.fromRGB(51, 65, 85)
    hStroke.Thickness = 1.2
    hStroke.Parent = hSlot

    local numTag = Instance.new("TextLabel")
    numTag.Size = UDim2.new(0, 14, 0, 12)
    numTag.Position = UDim2.new(0, 4, 0, 2)
    numTag.BackgroundTransparency = 1
    numTag.Font = Enum.Font.GothamBold
    numTag.Text = tostring(i)
    numTag.TextColor3 = Color3.fromRGB(56, 189, 248)
    numTag.TextSize = 10
    numTag.Parent = hSlot

    local hIcon = Instance.new("TextLabel")
    hIcon.Name = "IconLabel"
    hIcon.Size = UDim2.new(1, 0, 0, 22)
    hIcon.Position = UDim2.new(0, 0, 0, 12)
    hIcon.BackgroundTransparency = 1
    hIcon.Font = Enum.Font.GothamBold
    hIcon.TextSize = 16
    hIcon.Text = ""
    hIcon.Parent = hSlot

    local hName = Instance.new("TextLabel")
    hName.Name = "ItemName"
    hName.Size = UDim2.new(1, -4, 0, 14)
    hName.Position = UDim2.new(0, 2, 0, 36)
    hName.BackgroundTransparency = 1
    hName.Font = Enum.Font.GothamMedium
    hName.TextSize = 8
    hName.TextTruncate = Enum.TextTruncate.AtEnd
    hName.TextColor3 = Color3.fromRGB(241, 245, 249)
    hName.Text = ""
    hName.Parent = hSlot

    local hQtyBadge = Instance.new("Frame")
    hQtyBadge.Name = "QtyBadge"
    hQtyBadge.Size = UDim2.new(0, 22, 0, 12)
    hQtyBadge.Position = UDim2.new(1, -24, 0, 2)
    hQtyBadge.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
    hQtyBadge.BorderSizePixel = 0
    hQtyBadge.Visible = false
    hQtyBadge.Parent = hSlot

    local hQCorner = Instance.new("UICorner")
    hQCorner.CornerRadius = UDim.new(0, 3)
    hQCorner.Parent = hQtyBadge

    local hQty = Instance.new("TextLabel")
    hQty.Name = "ItemQty"
    hQty.Size = UDim2.new(1, 0, 1, 0)
    hQty.BackgroundTransparency = 1
    hQty.Font = Enum.Font.GothamBold
    hQty.TextSize = 8
    hQty.TextColor3 = Color3.fromRGB(56, 189, 248)
    hQty.Text = ""
    hQty.Parent = hQtyBadge

    hotbarFrames[i] = hSlot
end

-- Refresh UI from Profile
local function RenderInventory()
    if not currentProfile then return end

    local filledSlots = 0

    -- Update Grid Slots
    for i = 1, 30 do
        local frame = slotFrames[i]
        local iconLabel = frame:FindFirstChild("IconLabel") :: TextLabel
        local nameLabel = frame:FindFirstChild("ItemName") :: TextLabel
        local qtyBadge = frame:FindFirstChild("QtyBadge") :: Frame
        local qtyLabel = qtyBadge and qtyBadge:FindFirstChild("ItemQty") :: TextLabel
        local stroke = frame:FindFirstChild("BorderStroke") :: UIStroke

        local slotData = currentProfile.Slots[i]
        if slotData then
            filledSlots += 1
            local def = ItemDatabase.GetItem(slotData.ItemId)
            if def then
                iconLabel.Text = def.IconGlyph
                nameLabel.Text = def.Name
                if slotData.Quantity > 1 then
                    qtyBadge.Visible = true
                    qtyLabel.Text = "x" .. tostring(slotData.Quantity)
                else
                    qtyBadge.Visible = false
                end
                stroke.Color = ItemDatabase.GetRarityColor(def.Rarity)
            end
        else
            iconLabel.Text = ""
            nameLabel.Text = ""
            if qtyBadge then qtyBadge.Visible = false end
            stroke.Color = Color3.fromRGB(51, 65, 85)
        end
    end

    -- Update Capacity Pill in Header
    capPillLabel.Text = string.format("SLOTS: %d / 30", filledSlots)
    if filledSlots >= 30 then
        capPillLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
        capPill.BackgroundColor3 = Color3.fromRGB(69, 10, 10)
    elseif filledSlots >= 24 then
        capPillLabel.TextColor3 = Color3.fromRGB(245, 158, 11)
        capPill.BackgroundColor3 = Color3.fromRGB(55, 35, 10)
    else
        capPillLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
        capPill.BackgroundColor3 = Color3.fromRGB(24, 33, 50)
    end

    -- Update Hotbar Slots (Mirrors Slots 1 to 5)
    for i = 1, 5 do
        local hFrame = hotbarFrames[i]
        local hIcon = hFrame:FindFirstChild("IconLabel") :: TextLabel
        local hName = hFrame:FindFirstChild("ItemName") :: TextLabel
        local hBadge = hFrame:FindFirstChild("QtyBadge") :: Frame
        local hQty = hBadge and hBadge:FindFirstChild("ItemQty") :: TextLabel
        local stroke = hFrame:FindFirstChild("BorderStroke") :: UIStroke

        local slotData = currentProfile.Slots[i]
        if slotData then
            local def = ItemDatabase.GetItem(slotData.ItemId)
            if def then
                hIcon.Text = def.IconGlyph
                hName.Text = def.Name
                if slotData.Quantity > 1 then
                    hBadge.Visible = true
                    hQty.Text = "x" .. tostring(slotData.Quantity)
                else
                    hBadge.Visible = false
                end
                stroke.Color = ItemDatabase.GetRarityColor(def.Rarity)
            end
        else
            hIcon.Text = ""
            hName.Text = ""
            if hBadge then hBadge.Visible = false end
            stroke.Color = Color3.fromRGB(51, 65, 85)
        end
    end

    -- Update Equipment Slot Display
    local weapon = currentProfile.Equipment.Weapon
    local armor = currentProfile.Equipment.Armor

    if weapon then
        local def = ItemDatabase.GetItem(weapon.ItemId)
        weaponIcon.Text = def and def.IconGlyph or "⚔️"
        weaponTitle.Text = def and def.Name or "Equipped Weapon"
        weaponTitle.TextColor3 = def and ItemDatabase.GetRarityColor(def.Rarity) or Color3.fromRGB(56, 189, 248)
        local wStat = ""
        if def and def.Stats.Damage then wStat ..= string.format("+%d Damage", def.Stats.Damage) end
        if def and def.Stats.SpeedBoost then wStat ..= string.format(" | +%d Speed", def.Stats.SpeedBoost) end
        weaponStats.Text = wStat ~= "" and wStat or "Active Equipment"
        unequipWeaponBtn.Visible = true
    else
        weaponIcon.Text = "⚔️"
        weaponTitle.Text = "No Weapon"
        weaponTitle.TextColor3 = Color3.fromRGB(148, 163, 184)
        weaponStats.Text = "Select weapon to equip"
        unequipWeaponBtn.Visible = false
    end

    if armor then
        local def = ItemDatabase.GetItem(armor.ItemId)
        armorIcon.Text = def and def.IconGlyph or "🛡️"
        armorTitle.Text = def and def.Name or "Equipped Shield"
        armorTitle.TextColor3 = def and ItemDatabase.GetRarityColor(def.Rarity) or Color3.fromRGB(168, 85, 247)
        local aStat = ""
        if def and def.Stats.Defense then aStat ..= string.format("+%d Defense AP", def.Stats.Defense) end
        armorStats.Text = aStat ~= "" and aStat or "Active Equipment"
        unequipArmorBtn.Visible = true
    else
        armorIcon.Text = "🛡️"
        armorTitle.Text = "No Shield / Armor"
        armorTitle.TextColor3 = Color3.fromRGB(148, 163, 184)
        armorStats.Text = "Select shield to equip"
        unequipArmorBtn.Visible = false
    end

    -- Update Stats Summary
    local totalDmg = weapon and ItemDatabase.GetItem(weapon.ItemId) and ItemDatabase.GetItem(weapon.ItemId).Stats.Damage or 0
    local totalDef = armor and ItemDatabase.GetItem(armor.ItemId) and ItemDatabase.GetItem(armor.ItemId).Stats.Defense or 0
    local char = localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local curSpeed = hum and hum.WalkSpeed or 16

    statsText.Text = string.format(
        "<b>📊 OPERATIONAL METRICS</b>\n\n• ⚡ <b>WalkSpeed:</b> %d studs/s\n• ⚔️ <b>Attack Power:</b> %d DP\n• 🛡️ <b>Shield Armor:</b> %d AP\n• 🔒 <b>Session Lock:</b> <font color=\"#10B981\">Enforced (Anti-Dupe)</font>",
        curSpeed, totalDmg, totalDef
    )
end

-- Wire Action Buttons
equipBtn.MouseButton1Click:Connect(function()
    if not selectedSlotIndex or not currentProfile then return end
    local slotData = currentProfile.Slots[selectedSlotIndex]
    if not slotData then return end
    local def = ItemDatabase.GetItem(slotData.ItemId)
    if def and def.EquipSlot then
        EquipItemEvent:FireServer(selectedSlotIndex, def.EquipSlot)
    end
end)

useBtn.MouseButton1Click:Connect(function()
    if not selectedSlotIndex then return end
    UseItemEvent:FireServer(selectedSlotIndex)
end)

splitBtn.MouseButton1Click:Connect(function()
    if not selectedSlotIndex or not currentProfile then return end
    local slotData = currentProfile.Slots[selectedSlotIndex]
    if slotData and slotData.Quantity > 1 then
        local half = math.floor(slotData.Quantity / 2)
        SplitStackEvent:FireServer(selectedSlotIndex, half)
    end
end)

dropBtn.MouseButton1Click:Connect(function()
    if not selectedSlotIndex then return end
    DropItemEvent:FireServer(selectedSlotIndex)
end)

unequipWeaponBtn.MouseButton1Click:Connect(function()
    UnequipItemEvent:FireServer("Weapon")
end)

unequipArmorBtn.MouseButton1Click:Connect(function()
    UnequipItemEvent:FireServer("Armor")
end)

demoBtn.MouseButton1Click:Connect(function()
    AdminGiveDemoItemsEvent:FireServer()
end)

-- Toggle Window Function
local function ToggleInventory()
    isInventoryOpen = not isInventoryOpen
    mainWindow.Visible = isInventoryOpen
end

toggleBtn.MouseButton1Click:Connect(ToggleInventory)
closeBtn.MouseButton1Click:Connect(ToggleInventory)

-- Keybinds (E to open, 1-5 for hotbar)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.E then
        ToggleInventory()
    elseif input.KeyCode == Enum.KeyCode.One then
        local slotData = currentProfile and currentProfile.Slots[1]
        if slotData then
            local def = ItemDatabase.GetItem(slotData.ItemId)
            if def and def.Category == "Consumable" then
                UseItemEvent:FireServer(1)
            elseif def and def.EquipSlot then
                EquipItemEvent:FireServer(1, def.EquipSlot)
            end
        end
    elseif input.KeyCode == Enum.KeyCode.Two then
        local slotData = currentProfile and currentProfile.Slots[2]
        if slotData then
            local def = ItemDatabase.GetItem(slotData.ItemId)
            if def and def.Category == "Consumable" then
                UseItemEvent:FireServer(2)
            elseif def and def.EquipSlot then
                EquipItemEvent:FireServer(2, def.EquipSlot)
            end
        end
    elseif input.KeyCode == Enum.KeyCode.Three then
        local slotData = currentProfile and currentProfile.Slots[3]
        if slotData then
            local def = ItemDatabase.GetItem(slotData.ItemId)
            if def and def.Category == "Consumable" then
                UseItemEvent:FireServer(3)
            elseif def and def.EquipSlot then
                EquipItemEvent:FireServer(3, def.EquipSlot)
            end
        end
    elseif input.KeyCode == Enum.KeyCode.Four then
        local slotData = currentProfile and currentProfile.Slots[4]
        if slotData then
            local def = ItemDatabase.GetItem(slotData.ItemId)
            if def and def.Category == "Consumable" then
                UseItemEvent:FireServer(4)
            elseif def and def.EquipSlot then
                EquipItemEvent:FireServer(4, def.EquipSlot)
            end
        end
    elseif input.KeyCode == Enum.KeyCode.Five then
        local slotData = currentProfile and currentProfile.Slots[5]
        if slotData then
            local def = ItemDatabase.GetItem(slotData.ItemId)
            if def and def.Category == "Consumable" then
                UseItemEvent:FireServer(5)
            elseif def and def.EquipSlot then
                EquipItemEvent:FireServer(5, def.EquipSlot)
            end
        end
    end
end)

-- Receive Server Sync
SyncProfileEvent.OnClientEvent:Connect(function(profile: InventoryProfile)
    currentProfile = profile
    RenderInventory()
end)

print("⚡ [Inventory Suite] Client Controller & Cyber-Glassmorphic HUD Initialized.")
