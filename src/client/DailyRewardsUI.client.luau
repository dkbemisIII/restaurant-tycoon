-- DailyRewardsUI.client.luau
-- Shows a popup when the player logs in with their daily reward streak.
-- Displays the 7-day reward cycle and lets them claim today's reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

-- Wait for remote events
local dailyRewardInfo = ReplicatedStorage:WaitForChild("DailyRewardInfo")
local claimRewardEvent = ReplicatedStorage:WaitForChild("ClaimDailyReward")

-- === BUILD DAILY REWARDS UI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DailyRewardsUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player.PlayerGui

-- Full-screen dimmer
local dimmer = Instance.new("Frame")
dimmer.Name = "Dimmer"
dimmer.Size = UDim2.new(1, 0, 1, 0)
dimmer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dimmer.BackgroundTransparency = 0.5
dimmer.Visible = false
dimmer.ZIndex = 10
dimmer.Parent = screenGui

-- Main popup panel
local panel = Instance.new("Frame")
panel.Name = "RewardPanel"
panel.Size = UDim2.new(0, 520, 0, 350)
panel.Position = UDim2.new(0.5, -260, 0.5, -175)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
panel.Visible = false
panel.ZIndex = 11
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 50)
titleLabel.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
titleLabel.Text = "Daily Rewards"
titleLabel.ZIndex = 12
titleLabel.Parent = panel

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 16)
titleCorner.Parent = titleLabel

local titleSquare = Instance.new("Frame")
titleSquare.Size = UDim2.new(1, 0, 0, 16)
titleSquare.Position = UDim2.new(0, 0, 1, -16)
titleSquare.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
titleSquare.BorderSizePixel = 0
titleSquare.ZIndex = 12
titleSquare.Parent = titleLabel

-- Streak label
local streakLabel = Instance.new("TextLabel")
streakLabel.Name = "StreakLabel"
streakLabel.Size = UDim2.new(1, 0, 0, 30)
streakLabel.Position = UDim2.new(0, 0, 0, 55)
streakLabel.BackgroundTransparency = 1
streakLabel.TextScaled = true
streakLabel.Font = Enum.Font.GothamBold
streakLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
streakLabel.Text = "Login Streak: 0 days"
streakLabel.ZIndex = 12
streakLabel.Parent = panel

-- Reward cards container
local cardsFrame = Instance.new("Frame")
cardsFrame.Name = "Cards"
cardsFrame.Size = UDim2.new(1, -20, 0, 160)
cardsFrame.Position = UDim2.new(0, 10, 0, 90)
cardsFrame.BackgroundTransparency = 1
cardsFrame.ZIndex = 12
cardsFrame.Parent = panel

-- Create 7 day reward cards
local dayCards = {}
for i = 1, Config.DailyRewardCycle do
    local reward = Config.DailyRewards[i]

    local card = Instance.new("Frame")
    card.Name = "Day" .. i
    card.Size = UDim2.new(1 / Config.DailyRewardCycle, -6, 1, 0)
    card.Position = UDim2.new((i - 1) / Config.DailyRewardCycle, 3, 0, 0)
    card.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    card.ZIndex = 13
    card.Parent = cardsFrame

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card

    -- Day number
    local dayLabel = Instance.new("TextLabel")
    dayLabel.Size = UDim2.new(1, 0, 0, 25)
    dayLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    dayLabel.TextScaled = true
    dayLabel.Font = Enum.Font.GothamBold
    dayLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    dayLabel.Text = "Day " .. i
    dayLabel.ZIndex = 14
    dayLabel.Parent = card

    local dayLabelCorner = Instance.new("UICorner")
    dayLabelCorner.CornerRadius = UDim.new(0, 8)
    dayLabelCorner.Parent = dayLabel

    -- Reward icon
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "Icon"
    iconLabel.Size = UDim2.new(1, 0, 0, 40)
    iconLabel.Position = UDim2.new(0, 0, 0, 35)
    iconLabel.BackgroundTransparency = 1
    iconLabel.TextScaled = true
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    iconLabel.Text = reward.type == "Money" and "$" or "XP"
    iconLabel.ZIndex = 14
    iconLabel.Parent = card

    -- Reward amount
    local amountLabel = Instance.new("TextLabel")
    amountLabel.Name = "Amount"
    amountLabel.Size = UDim2.new(1, 0, 0, 25)
    amountLabel.Position = UDim2.new(0, 0, 0, 80)
    amountLabel.BackgroundTransparency = 1
    amountLabel.TextScaled = true
    amountLabel.Font = Enum.Font.Gotham
    amountLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    amountLabel.Text = reward.label
    amountLabel.ZIndex = 14
    amountLabel.Parent = card

    -- Status overlay (checkmark or highlight)
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, 0, 0, 30)
    statusLabel.Position = UDim2.new(0, 0, 1, -35)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    statusLabel.Text = ""
    statusLabel.ZIndex = 14
    statusLabel.Parent = card

    dayCards[i] = card
end

-- Claim button
local claimButton = Instance.new("TextButton")
claimButton.Name = "ClaimButton"
claimButton.Size = UDim2.new(0, 200, 0, 50)
claimButton.Position = UDim2.new(0.5, -100, 1, -65)
claimButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
claimButton.TextScaled = true
claimButton.Font = Enum.Font.GothamBold
claimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
claimButton.Text = "Claim Reward!"
claimButton.ZIndex = 12
claimButton.Parent = panel

local claimBtnCorner = Instance.new("UICorner")
claimBtnCorner.CornerRadius = UDim.new(0, 10)
claimBtnCorner.Parent = claimButton

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Text = "X"
closeBtn.ZIndex = 13
closeBtn.Parent = panel

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 6)
closeBtnCorner.Parent = closeBtn

-- === UI LOGIC ===

local function showPopup()
    dimmer.Visible = true
    panel.Visible = true
end

local function hidePopup()
    dimmer.Visible = false
    panel.Visible = false
end

local function updateCards(info)
    local currentDay = info.currentDay or 1
    local streak = info.streak or 0
    local alreadyClaimed = info.alreadyClaimed

    streakLabel.Text = "Login Streak: " .. streak .. " day" .. (streak == 1 and "" or "s")

    for i = 1, Config.DailyRewardCycle do
        local card = dayCards[i]
        local status = card:FindFirstChild("Status")

        -- Determine which day in the cycle has been reached
        local dayInCycle = ((streak - 1) % Config.DailyRewardCycle) + 1

        if i < currentDay then
            -- Past days (claimed)
            card.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
            if status then
                status.Text = "Claimed"
                status.TextColor3 = Color3.fromRGB(100, 200, 100)
            end
        elseif i == currentDay then
            -- Today
            if alreadyClaimed then
                card.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
                if status then
                    status.Text = "Claimed!"
                    status.TextColor3 = Color3.fromRGB(100, 255, 100)
                end
            else
                card.BackgroundColor3 = Color3.fromRGB(80, 120, 30)
                if status then
                    status.Text = "TODAY"
                    status.TextColor3 = Color3.fromRGB(255, 255, 100)
                end
            end
        else
            -- Future days
            card.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            if status then
                status.Text = ""
            end
        end
    end

    -- Update claim button
    if alreadyClaimed then
        claimButton.Text = "Already Claimed!"
        claimButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    else
        claimButton.Text = "Claim Reward!"
        claimButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
    end
end

-- === EVENT HANDLERS ===
local currentInfo = nil

dailyRewardInfo.OnClientEvent:Connect(function(info)
    currentInfo = info
    updateCards(info)

    -- Auto-show popup if reward is available
    if not info.alreadyClaimed then
        showPopup()
    end

    -- Show claimed notification
    if info.justClaimed and info.claimedReward then
        claimButton.Text = "Got: " .. info.claimedReward.label .. "!"
        claimButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        task.delay(2, function()
            hidePopup()
        end)
    end
end)

claimButton.Activated:Connect(function()
    if currentInfo and not currentInfo.alreadyClaimed then
        claimRewardEvent:FireServer()
    end
end)

closeBtn.Activated:Connect(hidePopup)
dimmer.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        hidePopup()
    end
end)

print("[DailyRewardsUI] Daily rewards popup initialized")
