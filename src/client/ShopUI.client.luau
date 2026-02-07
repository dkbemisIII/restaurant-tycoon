-- ShopUI.client.luau
-- Purchase/upgrade UI for menu items, furniture, and kitchen upgrades.
-- Opens with a button on the HUD; shows items filtered by player level.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ItemData = require(ReplicatedStorage.Shared.ItemData)
local Utils = require(ReplicatedStorage.Shared.Utils)

local player = Players.LocalPlayer
local statsChanged = ReplicatedStorage:WaitForChild("StatsChanged")
local dataLoaded = ReplicatedStorage:WaitForChild("PlayerDataLoaded")
local rebirthEvent = ReplicatedStorage:WaitForChild("Rebirth")

-- === PLAYER STATE ===
local currentData = {
    money = 0,
    level = 1,
    ownedItems = {},
    rebirths = 0,
}

-- === BUILD SHOP UI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player.PlayerGui

-- Shop toggle button (bottom-right)
local shopButton = Instance.new("TextButton")
shopButton.Name = "ShopButton"
shopButton.Size = UDim2.new(0, 120, 0, 40)
shopButton.Position = UDim2.new(1, -130, 1, -50)
shopButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
shopButton.TextScaled = true
shopButton.Font = Enum.Font.GothamBold
shopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
shopButton.Text = "Shop"
shopButton.Parent = screenGui

local shopBtnCorner = Instance.new("UICorner")
shopBtnCorner.CornerRadius = UDim.new(0, 8)
shopBtnCorner.Parent = shopButton

-- Rebirth button (next to shop)
local rebirthButton = Instance.new("TextButton")
rebirthButton.Name = "RebirthButton"
rebirthButton.Size = UDim2.new(0, 120, 0, 40)
rebirthButton.Position = UDim2.new(1, -260, 1, -50)
rebirthButton.BackgroundColor3 = Color3.fromRGB(150, 50, 150)
rebirthButton.TextScaled = true
rebirthButton.Font = Enum.Font.GothamBold
rebirthButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthButton.Text = "Rebirth"
rebirthButton.Visible = false
rebirthButton.Parent = screenGui

local rebirthBtnCorner = Instance.new("UICorner")
rebirthBtnCorner.CornerRadius = UDim.new(0, 8)
rebirthBtnCorner.Parent = rebirthButton

-- Main shop panel (hidden by default)
local shopPanel = Instance.new("Frame")
shopPanel.Name = "ShopPanel"
shopPanel.Size = UDim2.new(0, 500, 0, 450)
shopPanel.Position = UDim2.new(0.5, -250, 0.5, -225)
shopPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
shopPanel.BackgroundTransparency = 0.05
shopPanel.Visible = false
shopPanel.Parent = screenGui

local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 12)
shopCorner.Parent = shopPanel

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
titleBar.Parent = shopPanel

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

-- Square off bottom corners of title bar
local titleSquare = Instance.new("Frame")
titleSquare.Size = UDim2.new(1, 0, 0, 12)
titleSquare.Position = UDim2.new(0, 0, 1, -12)
titleSquare.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
titleSquare.BorderSizePixel = 0
titleSquare.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = "Restaurant Shop"
titleLabel.Parent = titleBar

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 35, 0, 35)
closeBtn.Position = UDim2.new(1, -38, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Text = "X"
closeBtn.Parent = titleBar

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 6)
closeBtnCorner.Parent = closeBtn

-- Tab buttons
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1, 0, 0, 35)
tabFrame.Position = UDim2.new(0, 0, 0, 42)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = shopPanel

local tabs = {"Menu", "Furniture", "Kitchen"}
local tabButtons = {}

for i, tabName in tabs do
    local btn = Instance.new("TextButton")
    btn.Name = tabName
    btn.Size = UDim2.new(1 / #tabs, -4, 1, -4)
    btn.Position = UDim2.new((i - 1) / #tabs, 2, 0, 2)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Text = tabName
    btn.Parent = tabFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    tabButtons[tabName] = btn
end

-- Scrolling item list
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ItemList"
scrollFrame.Size = UDim2.new(1, -20, 1, -90)
scrollFrame.Position = UDim2.new(0, 10, 0, 80)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = shopPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- === ITEM CARD BUILDER ===
local function createItemCard(item, category: string, index: number): Frame
    local card = Instance.new("Frame")
    card.Name = item.id
    card.Size = UDim2.new(1, 0, 0, 60)
    card.LayoutOrder = index
    card.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    card.Parent = scrollFrame

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 6)
    cardCorner.Parent = card

    -- Item name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.45, 0, 0, 25)
    nameLabel.Position = UDim2.new(0, 10, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text = item.name
    nameLabel.Parent = card

    -- Details (varies by category)
    local detailText = ""
    if category == "Menu" then
        detailText = "Payment +" .. item.paymentBonus
    elseif category == "Furniture" then
        if item.seats then
            detailText = item.seats .. " seats"
        elseif item.decorBonus then
            detailText = "Decor +" .. item.decorBonus
        end
    elseif category == "Kitchen" then
        detailText = "Speed +" .. (item.speedBonus or 0) .. " | Quality +" .. (item.qualityBonus or 0)
    end

    local detailLabel = Instance.new("TextLabel")
    detailLabel.Size = UDim2.new(0.45, 0, 0, 18)
    detailLabel.Position = UDim2.new(0, 10, 0, 32)
    detailLabel.BackgroundTransparency = 1
    detailLabel.TextScaled = true
    detailLabel.Font = Enum.Font.Gotham
    detailLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
    detailLabel.TextXAlignment = Enum.TextXAlignment.Left
    detailLabel.Text = detailText
    detailLabel.Parent = card

    -- Level requirement
    local levelReq = Instance.new("TextLabel")
    levelReq.Name = "LevelReq"
    levelReq.Size = UDim2.new(0, 60, 0, 20)
    levelReq.Position = UDim2.new(0.5, 0, 0.5, -10)
    levelReq.BackgroundTransparency = 1
    levelReq.TextScaled = true
    levelReq.Font = Enum.Font.Gotham
    levelReq.TextColor3 = Color3.fromRGB(200, 200, 100)
    levelReq.Text = "Lv." .. item.unlockLevel
    levelReq.Parent = card

    -- Price / status button
    local owned = Utils.Contains(currentData.ownedItems, item.id)
    local canAfford = currentData.money >= item.price
    local meetsLevel = currentData.level >= item.unlockLevel

    local buyBtn = Instance.new("TextButton")
    buyBtn.Name = "BuyButton"
    buyBtn.Size = UDim2.new(0, 100, 0, 35)
    buyBtn.Position = UDim2.new(1, -110, 0.5, -17)
    buyBtn.TextScaled = true
    buyBtn.Font = Enum.Font.GothamBold
    buyBtn.Parent = card

    local buyBtnCorner = Instance.new("UICorner")
    buyBtnCorner.CornerRadius = UDim.new(0, 6)
    buyBtnCorner.Parent = buyBtn

    if owned then
        buyBtn.Text = "OWNED"
        buyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        buyBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
    elseif not meetsLevel then
        buyBtn.Text = "LOCKED"
        buyBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 50)
        buyBtn.TextColor3 = Color3.fromRGB(200, 100, 100)
    else
        buyBtn.Text = Utils.FormatMoney(item.price)
        buyBtn.BackgroundColor3 = canAfford and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 100, 50)
        buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end

    -- Note: actual purchase happens via stepping on buy pads in-game
    -- The shop UI is informational - shows what's available and requirements
    buyBtn.Activated:Connect(function()
        if owned or not meetsLevel then return end
        -- Flash feedback - direct player to find the buy pad on their plot
        buyBtn.Text = "Walk to pad!"
        task.delay(2, function()
            if buyBtn.Parent then
                buyBtn.Text = Utils.FormatMoney(item.price)
            end
        end)
    end)

    return card
end

-- === TAB SWITCHING ===
local currentTab = "Menu"

local function refreshShop()
    -- Clear existing items
    for _, child in scrollFrame:GetChildren() do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local items
    local category = currentTab
    if currentTab == "Menu" then
        items = ItemData.MenuItems
    elseif currentTab == "Furniture" then
        items = ItemData.Furniture
    elseif currentTab == "Kitchen" then
        items = ItemData.KitchenUpgrades
    end

    if items then
        for i, item in items do
            createItemCard(item, category, i)
        end
    end

    -- Update canvas size
    listLayout:ApplyLayout()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)

    -- Highlight active tab
    for tabName, btn in tabButtons do
        if tabName == currentTab then
            btn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
end

for tabName, btn in tabButtons do
    btn.Activated:Connect(function()
        currentTab = tabName
        refreshShop()
    end)
end

-- === TOGGLE SHOP ===
local shopOpen = false

local function toggleShop()
    shopOpen = not shopOpen
    shopPanel.Visible = shopOpen
    if shopOpen then
        refreshShop()
    end
end

shopButton.Activated:Connect(toggleShop)
closeBtn.Activated:Connect(function()
    shopOpen = false
    shopPanel.Visible = false
end)

-- Keyboard shortcut: E to toggle shop
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.E then
        toggleShop()
    end
end)

-- === REBIRTH BUTTON ===
rebirthButton.Activated:Connect(function()
    if currentData.level >= Config.RebirthMinLevel and currentData.rebirths < Config.MaxRebirths then
        rebirthEvent:FireServer()
    end
end)

-- === DATA SYNC ===
dataLoaded.OnClientEvent:Connect(function(data)
    for key, value in data do
        currentData[key] = value
    end
    -- Show rebirth button if eligible
    rebirthButton.Visible = currentData.level >= Config.RebirthMinLevel and currentData.rebirths < Config.MaxRebirths
    if shopOpen then refreshShop() end
end)

statsChanged.OnClientEvent:Connect(function(key, value, level)
    if key == "money" then
        currentData.money = value
    elseif key == "xp" then
        currentData.totalXP = value
        currentData.level = level
    elseif key == "ownedItems" then
        currentData.ownedItems = value
    end
    rebirthButton.Visible = currentData.level >= Config.RebirthMinLevel and currentData.rebirths < Config.MaxRebirths
    if shopOpen then refreshShop() end
end)

print("[ShopUI] Shop UI initialized (press E to toggle)")
