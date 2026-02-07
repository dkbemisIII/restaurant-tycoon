-- DailyRewards.server.luau
-- Tracks daily login streaks and awards escalating rewards.
-- Streak resets if the player misses a day. 7-day cycle repeats.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- Wait for DataStore API
local dataStoreAPI = ServerScriptService:WaitForChild("DataStoreAPI")

local function getPlayerData(userId: number)
    return dataStoreAPI.GetPlayerData:Invoke(userId)
end

local function addMoney(player: Player, amount: number)
    dataStoreAPI.AddMoney:Fire(player, amount)
end

local function addXP(player: Player, amount: number)
    dataStoreAPI.AddXP:Fire(player, amount)
end

local function updateData(player: Player, key: string, value: any)
    dataStoreAPI.UpdateData:Fire(player, key, value)
end

-- Create RemoteEvents
local claimRewardEvent = Instance.new("RemoteEvent")
claimRewardEvent.Name = "ClaimDailyReward"
claimRewardEvent.Parent = ReplicatedStorage

local dailyRewardInfo = Instance.new("RemoteEvent")
dailyRewardInfo.Name = "DailyRewardInfo"
dailyRewardInfo.Parent = ReplicatedStorage

-- Get today's date as a string "YYYY-MM-DD"
local function getTodayString(): string
    local now = os.date("!*t")
    return string.format("%04d-%02d-%02d", now.year, now.month, now.day)
end

-- Check if two date strings are consecutive days
local function isConsecutiveDay(dateA: string, dateB: string): boolean
    if dateA == "" or dateB == "" then return false end

    -- Parse dates
    local yA, mA, dA = dateA:match("(%d+)-(%d+)-(%d+)")
    local yB, mB, dB = dateB:match("(%d+)-(%d+)-(%d+)")
    if not yA or not yB then return false end

    local timeA = os.time({year = tonumber(yA), month = tonumber(mA), day = tonumber(dA)})
    local timeB = os.time({year = tonumber(yB), month = tonumber(mB), day = tonumber(dB)})

    -- Check if exactly 1 day apart (86400 seconds)
    local diff = math.abs(timeB - timeA)
    return diff >= 82800 and diff <= 90000 -- Allow some leeway for timezone edge cases
end

-- Process a player's daily login
local function processLogin(player: Player)
    task.wait(2) -- Wait for data to load

    local data = getPlayerData(player.UserId)
    if not data then return end

    local today = getTodayString()

    -- Already claimed today?
    if data.lastDailyReward == today then
        -- Send info to client (already claimed)
        dailyRewardInfo:FireClient(player, {
            streak = data.dailyStreak,
            alreadyClaimed = true,
            rewards = Config.DailyRewards,
            currentDay = ((data.dailyStreak - 1) % Config.DailyRewardCycle) + 1,
        })
        return
    end

    -- Update streak
    if isConsecutiveDay(data.lastLoginDate, today) then
        -- Consecutive login: increment streak
        data.dailyStreak += 1
    else
        -- Missed a day or first login: reset streak to 1
        data.dailyStreak = 1
    end

    -- Update last login date
    data.lastLoginDate = today
    updateData(player, "lastLoginDate", today)
    updateData(player, "dailyStreak", data.dailyStreak)

    -- Send reward info to client (can claim)
    local currentDay = ((data.dailyStreak - 1) % Config.DailyRewardCycle) + 1
    dailyRewardInfo:FireClient(player, {
        streak = data.dailyStreak,
        alreadyClaimed = false,
        rewards = Config.DailyRewards,
        currentDay = currentDay,
    })
end

-- Handle claim request from client
claimRewardEvent.OnServerEvent:Connect(function(player)
    local data = getPlayerData(player.UserId)
    if not data then return end

    local today = getTodayString()

    -- Prevent double-claiming
    if data.lastDailyReward == today then return end

    -- Determine which reward to give
    local currentDay = ((data.dailyStreak - 1) % Config.DailyRewardCycle) + 1
    local reward = Config.DailyRewards[currentDay]
    if not reward then return end

    -- Grant the reward
    if reward.type == "Money" then
        addMoney(player, reward.amount)
    elseif reward.type == "XP" then
        addXP(player, reward.amount)
    end

    -- Mark as claimed
    data.lastDailyReward = today
    updateData(player, "lastDailyReward", today)

    -- Notify client
    dailyRewardInfo:FireClient(player, {
        streak = data.dailyStreak,
        alreadyClaimed = true,
        rewards = Config.DailyRewards,
        currentDay = currentDay,
        justClaimed = true,
        claimedReward = reward,
    })

    print("[DailyRewards]", player.Name, "claimed day", currentDay, "reward:", reward.label)
end)

-- Process login for each joining player
Players.PlayerAdded:Connect(processLogin)

print("[DailyRewards] Daily rewards system initialized")
