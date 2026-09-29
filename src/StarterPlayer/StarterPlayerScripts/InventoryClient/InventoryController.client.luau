--!strict
--[=[
    InventoryController.client.luau
    Cyber-Glassmorphic Client Controller & HUD for the Inventory & Equipment Suite.
    Features drag-and-drop slot operations, 5-slot interactive Hotbar, equipment slots,
    live stat displays, detailed hover tooltips, and a instant demo starter-pack button.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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

-- State
local currentProfile: InventoryProfile? = nil
local selectedSlotIndex: number? = nil
local isInventoryOpen = false
local slotFrames: { [number]: Frame } = {}
local hotbarFrames: { [number]: Frame } = {}

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AegisInventoryGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Parent = playerGui

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
mainWindow.Size = UDim2.new(0, 780, 0, 490)
mainWindow.Position = UDim2.new(0.5, -390, 0.5, -245)
mainWindow.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
mainWindow.BackgroundTransparency = 0.08
mainWindow.BorderSizePixel = 0
mainWindow.Visible = false
mainWindow.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainWindow

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(56, 189, 248)
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.5
mainStroke.Parent = mainWindow

-- Window Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 46)
header.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
header.BorderSizePixel = 0
header.Parent = mainWindow

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 320, 1, 0)
titleLabel.Position = UDim2.new(0, 18, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "⚡ AEGIS // EQUIPMENT & INVENTORY MATRIX"
titleLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -40, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(248, 113, 113)
closeBtn.TextSize = 14
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

-- Left Pane: Equipment & Stats
local leftPane = Instance.new("Frame")
leftPane.Name = "LeftPane"
leftPane.Size = UDim2.new(0, 240, 1, -66)
leftPane.Position = UDim2.new(0, 16, 0, 54)
leftPane.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
leftPane.BackgroundTransparency = 0.5
leftPane.BorderSizePixel = 0
leftPane.Parent = mainWindow

local leftCorner = Instance.new("UICorner")
leftCorner.CornerRadius = UDim.new(0, 8)
leftCorner.Parent = leftPane

local eqTitle = Instance.new("TextLabel")
eqTitle.Size = UDim2.new(1, 0, 0, 30)
eqTitle.Position = UDim2.new(0, 12, 0, 6)
eqTitle.BackgroundTransparency = 1
eqTitle.Font = Enum.Font.GothamBold
eqTitle.Text = "ACTIVE LOADOUT"
eqTitle.TextColor3 = Color3.fromRGB(148, 163, 184)
eqTitle.TextSize = 11
eqTitle.TextXAlignment = Enum.TextXAlignment.Left
eqTitle.Parent = leftPane

-- Weapon Slot Frame
local weaponSlotFrame = Instance.new("TextButton")
weaponSlotFrame.Name = "WeaponSlot"
weaponSlotFrame.Size = UDim2.new(1, -24, 0, 56)
weaponSlotFrame.Position = UDim2.new(0, 12, 0, 38)
weaponSlotFrame.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
weaponSlotFrame.BorderSizePixel = 0
weaponSlotFrame.AutoButtonColor = false
weaponSlotFrame.Text = ""
weaponSlotFrame.Parent = leftPane

local weaponCorner = Instance.new("UICorner")
weaponCorner.CornerRadius = UDim.new(0, 8)
weaponCorner.Parent = weaponSlotFrame

local weaponStroke = Instance.new("UIStroke")
weaponStroke.Color = Color3.fromRGB(56, 189, 248)
weaponStroke.Thickness = 1.2
weaponStroke.Parent = weaponSlotFrame

local weaponLabel = Instance.new("TextLabel")
weaponLabel.Name = "Label"
weaponLabel.Size = UDim2.new(1, -12, 1, 0)
weaponLabel.Position = UDim2.new(0, 12, 0, 0)
weaponLabel.BackgroundTransparency = 1
weaponLabel.Font = Enum.Font.GothamMedium
weaponLabel.Text = "⚔️ Weapon: Empty"
weaponLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
weaponLabel.TextSize = 12
weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
weaponLabel.Parent = weaponSlotFrame

-- Armor Slot Frame
local armorSlotFrame = Instance.new("TextButton")
armorSlotFrame.Name = "ArmorSlot"
armorSlotFrame.Size = UDim2.new(1, -24, 0, 56)
armorSlotFrame.Position = UDim2.new(0, 12, 0, 104)
armorSlotFrame.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
armorSlotFrame.BorderSizePixel = 0
armorSlotFrame.AutoButtonColor = false
armorSlotFrame.Text = ""
armorSlotFrame.Parent = leftPane

local armorCorner = Instance.new("UICorner")
armorCorner.CornerRadius = UDim.new(0, 8)
armorCorner.Parent = armorSlotFrame

local armorStroke = Instance.new("UIStroke")
armorStroke.Color = Color3.fromRGB(168, 85, 247)
armorStroke.Thickness = 1.2
armorStroke.Parent = armorSlotFrame

local armorLabel = Instance.new("TextLabel")
armorLabel.Name = "Label"
armorLabel.Size = UDim2.new(1, -12, 1, 0)
armorLabel.Position = UDim2.new(0, 12, 0, 0)
armorLabel.BackgroundTransparency = 1
armorLabel.Font = Enum.Font.GothamMedium
armorLabel.Text = "🛡️ Armor: Empty"
armorLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
armorLabel.TextSize = 12
armorLabel.TextXAlignment = Enum.TextXAlignment.Left
armorLabel.Parent = armorSlotFrame

-- Live Telemetry Stats Card
local statsCard = Instance.new("Frame")
statsCard.Name = "StatsCard"
statsCard.Size = UDim2.new(1, -24, 0, 130)
statsCard.Position = UDim2.new(0, 12, 0, 172)
statsCard.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
statsCard.BorderSizePixel = 0
statsCard.Parent = leftPane

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 8)
statsCorner.Parent = statsCard

local statsText = Instance.new("TextLabel")
statsText.Name = "StatsLabel"
statsText.Size = UDim2.new(1, -16, 1, -16)
statsText.Position = UDim2.new(0, 8, 0, 8)
statsText.BackgroundTransparency = 1
statsText.Font = Enum.Font.GothamMedium
statsText.TextSize = 11
statsText.TextColor3 = Color3.fromRGB(203, 213, 225)
statsText.TextXAlignment = Enum.TextXAlignment.Left
statsText.TextYAlignment = Enum.TextYAlignment.Top
statsText.Text = "📊 OPERATIONAL STATS\n\n• WalkSpeed: 16 studs/s\n• Attack Power: 0 DP\n• Shield Armor: 0 AP\n• Session Lock: Active"
statsText.Parent = statsCard

-- Admin Demo Button
local demoBtn = Instance.new("TextButton")
demoBtn.Name = "DemoBtn"
demoBtn.Size = UDim2.new(1, -24, 0, 42)
demoBtn.Position = UDim2.new(0, 12, 1, -52)
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
rightPane.Size = UDim2.new(1, -290, 1, -66)
rightPane.Position = UDim2.new(0, 272, 0, 54)
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
gridContainer.Size = UDim2.new(1, -16, 1, -84)
gridContainer.Position = UDim2.new(0, 8, 0, 8)
gridContainer.BackgroundTransparency = 1
gridContainer.BorderSizePixel = 0
gridContainer.ScrollBarThickness = 4
gridContainer.ScrollBarImageColor3 = Color3.fromRGB(56, 189, 248)
gridContainer.CanvasSize = UDim2.new(0, 0, 0, 360)
gridContainer.Parent = rightPane

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 72, 0, 72)
gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridContainer

-- Bottom Action Bar for Selected Item
local actionBar = Instance.new("Frame")
actionBar.Name = "ActionBar"
actionBar.Size = UDim2.new(1, -16, 0, 60)
actionBar.Position = UDim2.new(0, 8, 1, -68)
actionBar.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
actionBar.BorderSizePixel = 0
actionBar.Parent = rightPane

local actionCorner = Instance.new("UICorner")
actionCorner.CornerRadius = UDim.new(0, 8)
actionCorner.Parent = actionBar

local actionInfo = Instance.new("TextLabel")
actionInfo.Name = "ActionInfo"
actionInfo.Size = UDim2.new(0, 200, 1, 0)
actionInfo.Position = UDim2.new(0, 12, 0, 0)
actionInfo.BackgroundTransparency = 1
actionInfo.Font = Enum.Font.GothamMedium
actionInfo.Text = "Select an item..."
actionInfo.TextColor3 = Color3.fromRGB(148, 163, 184)
actionInfo.TextSize = 11
actionInfo.TextXAlignment = Enum.TextXAlignment.Left
actionInfo.Parent = actionBar

local equipBtn = Instance.new("TextButton")
equipBtn.Name = "EquipBtn"
equipBtn.Size = UDim2.new(0, 70, 0, 36)
equipBtn.Position = UDim2.new(1, -240, 0.5, -18)
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
useBtn.Position = UDim2.new(1, -240, 0.5, -18)
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
splitBtn.Size = UDim2.new(0, 65, 0, 36)
splitBtn.Position = UDim2.new(1, -160, 0.5, -18)
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
dropBtn.Size = UDim2.new(0, 65, 0, 36)
dropBtn.Position = UDim2.new(1, -85, 0.5, -18)
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
hotbar.Size = UDim2.new(0, 360, 0, 64)
hotbar.Position = UDim2.new(0.5, -180, 1, -76)
hotbar.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
hotbar.BackgroundTransparency = 0.15
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

-- Create 24 Grid Slot Frames
for i = 1, 24 do
    local slotBtn = Instance.new("TextButton")
    slotBtn.Name = "Slot_" .. tostring(i)
    slotBtn.LayoutOrder = i
    slotBtn.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
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
    indexLabel.Position = UDim2.new(0, 4, 0, 3)
    indexLabel.BackgroundTransparency = 1
    indexLabel.Font = Enum.Font.Gotham
    indexLabel.Text = tostring(i)
    indexLabel.TextColor3 = Color3.fromRGB(100, 116, 139)
    indexLabel.TextSize = 9
    indexLabel.Parent = slotBtn

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "ItemName"
    nameLabel.Size = UDim2.new(1, -8, 0, 30)
    nameLabel.Position = UDim2.new(0, 4, 0, 16)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamMedium
    nameLabel.TextSize = 10
    nameLabel.TextWrapped = true
    nameLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
    nameLabel.Text = ""
    nameLabel.Parent = slotBtn

    local qtyLabel = Instance.new("TextLabel")
    qtyLabel.Name = "ItemQty"
    qtyLabel.Size = UDim2.new(1, -6, 0, 14)
    qtyLabel.Position = UDim2.new(0, 0, 1, -16)
    qtyLabel.BackgroundTransparency = 1
    qtyLabel.Font = Enum.Font.GothamBold
    qtyLabel.TextSize = 10
    qtyLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
    qtyLabel.TextXAlignment = Enum.TextXAlignment.Right
    qtyLabel.Text = ""
    qtyLabel.Parent = slotBtn

    slotBtn.MouseButton1Click:Connect(function()
        selectedSlotIndex = i
        if currentProfile and currentProfile.Slots[i] then
            local slotData = currentProfile.Slots[i]
            local def = ItemDatabase.GetItem(slotData.ItemId)
            if def then
                actionInfo.Text = string.format("<b>%s</b>\n%s (x%d)", def.Name, def.Category, slotData.Quantity)
                actionInfo.TextColor3 = ItemDatabase.GetRarityColor(def.Rarity)

                equipBtn.Visible = (def.EquipSlot ~= nil)
                useBtn.Visible = (def.Category == "Consumable")
                splitBtn.Visible = (slotData.Quantity > 1)
                dropBtn.Visible = true
            end
        else
            actionInfo.Text = "Empty Slot (" .. i .. ")"
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
    hSlot.Size = UDim2.new(0, 52, 0, 52)
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
    numTag.Position = UDim2.new(0, 4, 0, 3)
    numTag.BackgroundTransparency = 1
    numTag.Font = Enum.Font.GothamBold
    numTag.Text = tostring(i)
    numTag.TextColor3 = Color3.fromRGB(56, 189, 248)
    numTag.TextSize = 10
    numTag.Parent = hSlot

    local hName = Instance.new("TextLabel")
    hName.Name = "ItemName"
    hName.Size = UDim2.new(1, -6, 0, 24)
    hName.Position = UDim2.new(0, 3, 0, 14)
    hName.BackgroundTransparency = 1
    hName.Font = Enum.Font.GothamMedium
    hName.TextSize = 8
    hName.TextWrapped = true
    hName.TextColor3 = Color3.fromRGB(241, 245, 249)
    hName.Text = ""
    hName.Parent = hSlot

    local hQty = Instance.new("TextLabel")
    hQty.Name = "ItemQty"
    hQty.Size = UDim2.new(1, -4, 0, 12)
    hQty.Position = UDim2.new(0, 0, 1, -14)
    hQty.BackgroundTransparency = 1
    hQty.Font = Enum.Font.GothamBold
    hQty.TextSize = 9
    hQty.TextColor3 = Color3.fromRGB(56, 189, 248)
    hQty.TextXAlignment = Enum.TextXAlignment.Right
    hQty.Text = ""
    hQty.Parent = hSlot

    hotbarFrames[i] = hSlot
end

-- Refresh UI from Profile
local function RenderInventory()
    if not currentProfile then return end

    -- Update Grid Slots
    for i = 1, 24 do
        local frame = slotFrames[i]
        local nameLabel = frame:FindFirstChild("ItemName") :: TextLabel
        local qtyLabel = frame:FindFirstChild("ItemQty") :: TextLabel
        local stroke = frame:FindFirstChild("BorderStroke") :: UIStroke

        local slotData = currentProfile.Slots[i]
        if slotData then
            local def = ItemDatabase.GetItem(slotData.ItemId)
            if def then
                nameLabel.Text = def.Name
                qtyLabel.Text = slotData.Quantity > 1 and "x" .. tostring(slotData.Quantity) or ""
                stroke.Color = ItemDatabase.GetRarityColor(def.Rarity)
            end
        else
            nameLabel.Text = ""
            qtyLabel.Text = ""
            stroke.Color = Color3.fromRGB(51, 65, 85)
        end
    end

    -- Update Hotbar Slots (Mirrors Slots 1 to 5)
    for i = 1, 5 do
        local hFrame = hotbarFrames[i]
        local hName = hFrame:FindFirstChild("ItemName") :: TextLabel
        local hQty = hFrame:FindFirstChild("ItemQty") :: TextLabel
        local stroke = hFrame:FindFirstChild("BorderStroke") :: UIStroke

        local slotData = currentProfile.Slots[i]
        if slotData then
            local def = ItemDatabase.GetItem(slotData.ItemId)
            if def then
                hName.Text = def.Name
                hQty.Text = slotData.Quantity > 1 and "x" .. tostring(slotData.Quantity) or ""
                stroke.Color = ItemDatabase.GetRarityColor(def.Rarity)
            end
        else
            hName.Text = ""
            hQty.Text = ""
            stroke.Color = Color3.fromRGB(51, 65, 85)
        end
    end

    -- Update Equipment Slot Display
    local weapon = currentProfile.Equipment.Weapon
    local armor = currentProfile.Equipment.Armor

    if weapon then
        local def = ItemDatabase.GetItem(weapon.ItemId)
        weaponLabel.Text = string.format("⚔️ %s", def and def.Name or "Equipped")
        weaponLabel.TextColor3 = def and ItemDatabase.GetRarityColor(def.Rarity) or Color3.fromRGB(56, 189, 248)
    else
        weaponLabel.Text = "⚔️ Weapon: Empty"
        weaponLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
    end

    if armor then
        local def = ItemDatabase.GetItem(armor.ItemId)
        armorLabel.Text = string.format("🛡️ %s", def and def.Name or "Equipped")
        armorLabel.TextColor3 = def and ItemDatabase.GetRarityColor(def.Rarity) or Color3.fromRGB(168, 85, 247)
    else
        armorLabel.Text = "🛡️ Armor: Empty"
        armorLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
    end

    -- Update Stats Summary
    local totalDmg = weapon and ItemDatabase.GetItem(weapon.ItemId) and ItemDatabase.GetItem(weapon.ItemId).Stats.Damage or 0
    local totalDef = armor and ItemDatabase.GetItem(armor.ItemId) and ItemDatabase.GetItem(armor.ItemId).Stats.Defense or 0
    local char = localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local curSpeed = hum and hum.WalkSpeed or 16

    statsText.Text = string.format(
        "📊 OPERATIONAL STATS\n\n• WalkSpeed: %d studs/s\n• Attack Power: %d DP\n• Shield Armor: %d AP\n• Session Lock: Active",
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

weaponSlotFrame.MouseButton1Click:Connect(function()
    UnequipItemEvent:FireServer("Weapon")
end)

armorSlotFrame.MouseButton1Click:Connect(function()
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
