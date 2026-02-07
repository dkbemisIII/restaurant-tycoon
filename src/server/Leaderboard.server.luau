-- Leaderboard.server.luau
-- Maintains global leaderboards using Roblox OrderedDataStore.
-- Tracks: Richest (total money earned), Highest Level, Best Star Rating.
-- Also creates in-game leaderboard display.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- Wait for DataStore API
local dataStoreAPI = ServerScriptService:WaitForChild("DataStoreAPI")

local function getPlayerData(userId: number)
    return dataStoreAPI.GetPlayerData:Invoke(userId)
end

-- OrderedDataStores for each leaderboard
local moneyLeaderboard = DataStoreService:GetOrderedDataStore("Leaderboard_Money_v1")
local levelLeaderboard = DataStoreService:GetOrderedDataStore("Leaderboard_Level_v1")

-- RemoteEvent to send leaderboard data to clients
local leaderboardData = Instance.new("RemoteEvent")
leaderboardData.Name = "LeaderboardData"
leaderboardData.Parent = ReplicatedStorage

-- Cache of current leaderboard entries
local cachedLeaderboards = {
    Money = {},
    Level = {},
}

-- Create a physical leaderboard display in the world
local function createLeaderboardDisplay()
    local board = Instance.new("Part")
    board.Name = "LeaderboardDisplay"
    board.Size = Vector3.new(20, 15, 1)
    board.Position = Vector3.new(-30, 8, -30) -- Placed near spawn area
    board.Anchored = true
    board.Material = Enum.Material.SmoothPlastic
    board.Color = Color3.fromRGB(30, 30, 40)
    board.Parent = workspace

    -- SurfaceGui on the front face
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Name = "LeaderboardGui"
    surfaceGui.Face = Enum.NormalId.Front
    surfaceGui.CanvasSize = Vector2.new(800, 600)
    surfaceGui.Parent = board

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0.1, 0)
    title.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.fromRGB(30, 30, 30)
    title.Text = "🏆 TOP RESTAURANTS 🏆"
    title.Parent = surfaceGui

    -- Two columns: Money and Level
    for i, category in {"Richest Players", "Highest Level"} do
        local columnFrame = Instance.new("Frame")
        columnFrame.Name = "Column_" .. i
        columnFrame.Size = UDim2.new(0.5, -2, 0.88, 0)
        columnFrame.Position = UDim2.new((i - 1) * 0.5, 1, 0.12, 0)
        columnFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        columnFrame.BorderSizePixel = 0
        columnFrame.Parent = surfaceGui

        local columnTitle = Instance.new("TextLabel")
        columnTitle.Name = "ColumnTitle"
        columnTitle.Size = UDim2.new(1, 0, 0.08, 0)
        columnTitle.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        columnTitle.TextScaled = true
        columnTitle.Font = Enum.Font.GothamBold
        columnTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        columnTitle.Text = category
        columnTitle.Parent = columnFrame

        -- Entry rows
        for row = 1, 10 do
            local entry = Instance.new("TextLabel")
            entry.Name = "Entry_" .. row
            entry.Size = UDim2.new(1, -4, 0.08, 0)
            entry.Position = UDim2.new(0, 2, 0.08 + (row - 1) * 0.085, 2)
            entry.BackgroundTransparency = 0.5
            entry.BackgroundColor3 = row % 2 == 0 and Color3.fromRGB(50, 50, 65) or Color3.fromRGB(45, 45, 60)
            entry.TextScaled = true
            entry.Font = Enum.Font.Gotham
            entry.TextColor3 = Color3.fromRGB(200, 200, 200)
            entry.TextXAlignment = Enum.TextXAlignment.Left
            entry.Text = "#" .. row .. "  ---"
            entry.Parent = columnFrame
        end
    end

    return surfaceGui
end

local displayGui = createLeaderboardDisplay()

-- Update the physical leaderboard display
local function updateDisplay()
    if not displayGui then return end

    -- Update Money column
    local moneyColumn = displayGui:FindFirstChild("Column_1")
    if moneyColumn then
        for i, entry in cachedLeaderboards.Money do
            if i > 10 then break end
            local label = moneyColumn:FindFirstChild("Entry_" .. i)
            if label then
                local medal = ""
                if i == 1 then medal = "🥇 "
                elseif i == 2 then medal = "🥈 "
                elseif i == 3 then medal = "🥉 "
                end
                label.Text = medal .. "#" .. i .. "  " .. entry.name .. "  -  $" .. tostring(entry.value)
            end
        end
    end

    -- Update Level column
    local levelColumn = displayGui:FindFirstChild("Column_2")
    if levelColumn then
        for i, entry in cachedLeaderboards.Level do
            if i > 10 then break end
            local label = levelColumn:FindFirstChild("Entry_" .. i)
            if label then
                local medal = ""
                if i == 1 then medal = "🥇 "
                elseif i == 2 then medal = "🥈 "
                elseif i == 3 then medal = "🥉 "
                end
                label.Text = medal .. "#" .. i .. "  " .. entry.name .. "  -  Lv." .. tostring(entry.value)
            end
        end
    end
end

-- Submit current player stats to the leaderboard DataStores
local function submitPlayerStats(player: Player)
    local data = getPlayerData(player.UserId)
    if not data then return end

    local userId = tostring(player.UserId)

    pcall(function()
        moneyLeaderboard:SetAsync(userId, math.floor(data.totalMoneyEarned or 0))
    end)

    pcall(function()
        levelLeaderboard:SetAsync(userId, data.level or 1)
    end)
end

-- Fetch leaderboard data from OrderedDataStore
local function fetchLeaderboard(store, category: string)
    local success, pages = pcall(function()
        return store:GetSortedAsync(false, 10) -- Top 10, descending
    end)

    if not success or not pages then return end

    local entries = {}
    local pageData = pages:GetCurrentPage()

    for _, entry in pageData do
        local userId = tonumber(entry.key)
        local playerName = "[Unknown]"

        -- Try to get the player name
        local nameSuccess, name = pcall(function()
            return Players:GetNameFromUserIdAsync(userId)
        end)
        if nameSuccess and name then
            playerName = name
        end

        table.insert(entries, {
            userId = userId,
            name = playerName,
            value = entry.value,
        })
    end

    cachedLeaderboards[category] = entries
end

-- === MAIN UPDATE LOOP ===
task.spawn(function()
    task.wait(5) -- Initial delay

    while true do
        -- Submit stats for all online players
        for _, player in Players:GetPlayers() do
            task.spawn(submitPlayerStats, player)
        end

        task.wait(2) -- Brief delay between submit and fetch

        -- Fetch updated leaderboards
        task.spawn(function()
            fetchLeaderboard(moneyLeaderboard, "Money")
        end)
        task.spawn(function()
            fetchLeaderboard(levelLeaderboard, "Level")
        end)

        task.wait(1) -- Wait for fetches to complete
        updateDisplay()

        -- Send to all connected clients
        for _, player in Players:GetPlayers() do
            leaderboardData:FireClient(player, cachedLeaderboards)
        end

        task.wait(Config.LeaderboardUpdateInterval)
    end
end)

-- Send cached leaderboard to newly joining players
Players.PlayerAdded:Connect(function(player)
    task.wait(3)
    leaderboardData:FireClient(player, cachedLeaderboards)
end)

print("[Leaderboard] Leaderboard system initialized")
