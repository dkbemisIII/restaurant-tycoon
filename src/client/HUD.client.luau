-- HUD.client.luau
-- Displays the player's money, XP bar, level, and star rating on screen.
-- Listens for StatsChanged events from the server to update in real time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Utils = require(ReplicatedStorage.Shared.Utils)

local player = Players.LocalPlayer

-- Wait for remote events
local statsChanged = ReplicatedStorage:WaitForChild("StatsChanged")
local dataLoaded = ReplicatedStorage:WaitForChild("PlayerDataLoaded")

-- === BUILD HUD ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player.PlayerGui

-- Top bar background
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 50)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
topBar.BackgroundTransparency = 0.3
topBar.BorderSizePixel = 0
topBar.Parent = screenGui

local topBarCorner = Instance.new("UICorner")
topBarCorner.CornerRadius = UDim.new(0, 0)
topBarCorner.Parent = topBar

-- Money display (left side)
local moneyFrame = Instance.new("Frame")
moneyFrame.Name = "MoneyFrame"
moneyFrame.Size = UDim2.new(0, 200, 0, 40)
moneyFrame.Position = UDim2.new(0, 10, 0, 5)
moneyFrame.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
moneyFrame.BackgroundTransparency = 0.3
moneyFrame.Parent = topBar

local moneyCorner = Instance.new("UICorner")
moneyCorner.CornerRadius = UDim.new(0, 8)
moneyCorner.Parent = moneyFrame

local moneyIcon = Instance.new("TextLabel")
moneyIcon.Name = "Icon"
moneyIcon.Size = UDim2.new(0, 35, 1, 0)
moneyIcon.BackgroundTransparency = 1
moneyIcon.TextScaled = true
moneyIcon.Font = Enum.Font.GothamBold
moneyIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
moneyIcon.Text = "$"
moneyIcon.Parent = moneyFrame

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Name = "Amount"
moneyLabel.Size = UDim2.new(1, -40, 1, 0)
moneyLabel.Position = UDim2.new(0, 38, 0, 0)
moneyLabel.BackgroundTransparency = 1
moneyLabel.TextScaled = true
moneyLabel.Font = Enum.Font.GothamBold
moneyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
moneyLabel.Text = "0"
moneyLabel.Parent = moneyFrame

-- Level display (center)
local levelFrame = Instance.new("Frame")
levelFrame.Name = "LevelFrame"
levelFrame.Size = UDim2.new(0, 280, 0, 40)
levelFrame.Position = UDim2.new(0.5, -140, 0, 5)
levelFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
levelFrame.BackgroundTransparency = 0.3
levelFrame.Parent = topBar

local levelCorner = Instance.new("UICorner")
levelCorner.CornerRadius = UDim.new(0, 8)
levelCorner.Parent = levelFrame

local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "LevelText"
levelLabel.Size = UDim2.new(0, 80, 1, 0)
levelLabel.BackgroundTransparency = 1
levelLabel.TextScaled = true
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
levelLabel.Text = "Lv. 1"
levelLabel.Parent = levelFrame

-- XP bar
local xpBarBg = Instance.new("Frame")
xpBarBg.Name = "XPBarBG"
xpBarBg.Size = UDim2.new(1, -90, 0, 14)
xpBarBg.Position = UDim2.new(0, 85, 0.5, -7)
xpBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
xpBarBg.Parent = levelFrame

local xpBarBgCorner = Instance.new("UICorner")
xpBarBgCorner.CornerRadius = UDim.new(0, 6)
xpBarBgCorner.Parent = xpBarBg

local xpBarFill = Instance.new("Frame")
xpBarFill.Name = "Fill"
xpBarFill.Size = UDim2.new(0, 0, 1, 0)
xpBarFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
xpBarFill.Parent = xpBarBg

local xpFillCorner = Instance.new("UICorner")
xpFillCorner.CornerRadius = UDim.new(0, 6)
xpFillCorner.Parent = xpBarFill

local xpLabel = Instance.new("TextLabel")
xpLabel.Name = "XPText"
xpLabel.Size = UDim2.new(1, 0, 1, 0)
xpLabel.BackgroundTransparency = 1
xpLabel.TextScaled = true
xpLabel.Font = Enum.Font.Gotham
xpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
xpLabel.TextStrokeTransparency = 0.5
xpLabel.Text = "0 / 100 XP"
xpLabel.ZIndex = 2
xpLabel.Parent = xpBarBg

-- Star rating display (right side)
local starFrame = Instance.new("Frame")
starFrame.Name = "StarFrame"
starFrame.Size = UDim2.new(0, 150, 0, 40)
starFrame.Position = UDim2.new(1, -160, 0, 5)
starFrame.BackgroundColor3 = Color3.fromRGB(120, 80, 20)
starFrame.BackgroundTransparency = 0.3
starFrame.Parent = topBar

local starCorner = Instance.new("UICorner")
starCorner.CornerRadius = UDim.new(0, 8)
starCorner.Parent = starFrame

local starLabel = Instance.new("TextLabel")
starLabel.Name = "Stars"
starLabel.Size = UDim2.new(1, 0, 1, 0)
starLabel.BackgroundTransparency = 1
starLabel.TextScaled = true
starLabel.Font = Enum.Font.GothamBold
starLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
starLabel.Text = "★ 0.0"
starLabel.Parent = starFrame

-- Rebirth counter (below stars, only shown if rebirths > 0)
local rebirthLabel = Instance.new("TextLabel")
rebirthLabel.Name = "RebirthLabel"
rebirthLabel.Size = UDim2.new(0, 150, 0, 20)
rebirthLabel.Position = UDim2.new(1, -160, 0, 52)
rebirthLabel.BackgroundTransparency = 1
rebirthLabel.TextScaled = true
rebirthLabel.Font = Enum.Font.GothamBold
rebirthLabel.TextColor3 = Color3.fromRGB(255, 100, 255)
rebirthLabel.Text = ""
rebirthLabel.Visible = false
rebirthLabel.Parent = screenGui

-- Level-up notification (center screen, fades in/out)
local levelUpLabel = Instance.new("TextLabel")
levelUpLabel.Name = "LevelUpNotif"
levelUpLabel.Size = UDim2.new(0, 400, 0, 80)
levelUpLabel.Position = UDim2.new(0.5, -200, 0.3, 0)
levelUpLabel.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
levelUpLabel.BackgroundTransparency = 0.2
levelUpLabel.TextScaled = true
levelUpLabel.Font = Enum.Font.GothamBold
levelUpLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
levelUpLabel.Text = "LEVEL UP!"
levelUpLabel.Visible = false
levelUpLabel.Parent = screenGui

local levelUpCorner = Instance.new("UICorner")
levelUpCorner.CornerRadius = UDim.new(0, 12)
levelUpCorner.Parent = levelUpLabel

-- === STATE ===
local currentData = {
    money = 0,
    totalXP = 0,
    level = 1,
    ownedItems = {},
    kitchenUpgrade = "basic_stove",
    rebirths = 0,
}

-- === UPDATE FUNCTIONS ===
local function updateMoneyDisplay()
    moneyLabel.Text = Utils.FormatMoney(currentData.money):sub(2) -- Remove $ since we have the icon
end

local function updateLevelDisplay()
    levelLabel.Text = "Lv. " .. currentData.level

    local progress = Utils.XPProgress(currentData.totalXP)
    xpBarFill.Size = UDim2.new(progress, 0, 1, 0)

    local currentLevelXP = Utils.XPForLevel(currentData.level)
    local nextLevelXP = Utils.XPForLevel(currentData.level + 1)
    local xpIntoLevel = currentData.totalXP - currentLevelXP
    local xpNeeded = nextLevelXP - currentLevelXP
    xpLabel.Text = tostring(math.floor(xpIntoLevel)) .. " / " .. tostring(math.floor(xpNeeded)) .. " XP"
end

local function updateStarDisplay()
    local rating = Utils.CalculateStarRating(currentData.ownedItems, currentData.kitchenUpgrade)
    local fullStars = math.floor(rating)
    local starText = string.rep("★", fullStars)
    if rating - fullStars >= 0.5 then
        starText ..= "½"
    end
    starLabel.Text = starText .. " " .. string.format("%.1f", rating)
end

local function updateRebirthDisplay()
    if currentData.rebirths and currentData.rebirths > 0 then
        rebirthLabel.Text = "Rebirth x" .. currentData.rebirths
        rebirthLabel.Visible = true
    else
        rebirthLabel.Visible = false
    end
end

local function showLevelUpNotification(newLevel: number)
    levelUpLabel.Text = "LEVEL UP! Lv. " .. newLevel
    levelUpLabel.Visible = true
    levelUpLabel.BackgroundTransparency = 0.2
    levelUpLabel.TextTransparency = 0

    task.delay(2, function()
        -- Fade out
        for i = 1, 10 do
            levelUpLabel.BackgroundTransparency = 0.2 + (i / 10) * 0.8
            levelUpLabel.TextTransparency = i / 10
            task.wait(0.05)
        end
        levelUpLabel.Visible = false
    end)
end

local function updateAll()
    updateMoneyDisplay()
    updateLevelDisplay()
    updateStarDisplay()
    updateRebirthDisplay()
end

-- === EVENT HANDLERS ===

-- Initial data load
dataLoaded.OnClientEvent:Connect(function(data)
    for key, value in data do
        currentData[key] = value
    end
    updateAll()
end)

-- Real-time stat changes
statsChanged.OnClientEvent:Connect(function(key, value, level)
    if key == "money" then
        currentData.money = value
        updateMoneyDisplay()
    elseif key == "xp" then
        currentData.totalXP = value
        currentData.level = level
        updateLevelDisplay()
    elseif key == "levelUp" then
        showLevelUpNotification(value)
    elseif key == "ownedItems" then
        currentData.ownedItems = value
        updateStarDisplay()
    elseif key == "kitchenUpgrade" then
        currentData.kitchenUpgrade = value
        updateStarDisplay()
    elseif key == "rebirths" then
        currentData.rebirths = value
        updateRebirthDisplay()
    end
end)

print("[HUD] Player HUD initialized")
