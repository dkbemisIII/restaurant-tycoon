-- DataStore.server.luau
-- Handles saving and loading player data using Roblox DataStoreService.
-- Data is saved automatically on an interval and when a player leaves.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- The DataStore where all player data lives
local playerDataStore = DataStoreService:GetDataStore(Config.DataStoreKey)

-- In-memory cache of loaded player data (indexed by UserId)
local playerDataCache: {[number]: any} = {}

-- Default data for a brand-new player
local function getDefaultData()
    return {
        money = Config.StartingMoney,
        totalXP = 0,
        level = 1,
        ownedItems = {},         -- Array of item IDs the player has bought
        kitchenUpgrade = "basic_stove",
        placedFurniture = {},    -- Array of {id, position, rotation} for layout
        dailyStreak = 0,
        lastLoginDate = "",      -- "YYYY-MM-DD" string
        lastDailyReward = "",    -- Date they last claimed a daily reward
        totalMoneyEarned = 0,    -- Lifetime earnings (for leaderboard)
        rebirths = 0,
        dailyQuests = {},        -- Tracked daily quest progress
    }
end

-- Create RemoteEvents for client communication
local function createRemotes()
    -- Fires to client with full player data on load
    local dataLoaded = Instance.new("RemoteEvent")
    dataLoaded.Name = "PlayerDataLoaded"
    dataLoaded.Parent = ReplicatedStorage

    -- Client requests to update a specific field (validated server-side)
    local dataUpdate = Instance.new("RemoteEvent")
    dataUpdate.Name = "PlayerDataUpdate"
    dataUpdate.Parent = ReplicatedStorage

    -- Fires to client whenever money/XP/level changes
    local statsChanged = Instance.new("RemoteEvent")
    statsChanged.Name = "StatsChanged"
    statsChanged.Parent = ReplicatedStorage

    return dataLoaded, dataUpdate, statsChanged
end

local DataLoadedEvent, DataUpdateEvent, StatsChangedEvent = createRemotes()

-- === PUBLIC API (used by other server scripts via module require) ===
-- We expose functions via a ModuleScript-like pattern using BindableFunction/Event

-- Load player data from DataStore (called when player joins)
local function loadPlayerData(player: Player)
    local userId = player.UserId
    local success, data = pcall(function()
        return playerDataStore:GetAsync(tostring(userId))
    end)

    if success and data then
        -- Merge with defaults to handle schema migrations (new fields added later)
        local defaults = getDefaultData()
        for key, defaultValue in defaults do
            if data[key] == nil then
                data[key] = defaultValue
            end
        end
        playerDataCache[userId] = data
    else
        -- New player or DataStore error: use defaults
        if not success then
            warn("[DataStore] Failed to load data for", player.Name, "- using defaults")
        end
        playerDataCache[userId] = getDefaultData()
    end

    -- Recalculate level from XP (in case of inconsistency)
    local Utils = require(ReplicatedStorage.Shared.Utils)
    playerDataCache[userId].level = Utils.LevelFromXP(playerDataCache[userId].totalXP)

    -- Send data to the client
    DataLoadedEvent:FireClient(player, playerDataCache[userId])

    return playerDataCache[userId]
end

-- Save player data to DataStore
local function savePlayerData(player: Player)
    local userId = player.UserId
    local data = playerDataCache[userId]
    if not data then return end

    local success, err = pcall(function()
        playerDataStore:SetAsync(tostring(userId), data)
    end)

    if not success then
        warn("[DataStore] Failed to save data for", player.Name, ":", err)
    end
end

-- Get cached data for a player (returns nil if not loaded yet)
local function getPlayerData(userId: number)
    return playerDataCache[userId]
end

-- Update a specific field and notify the client
local function updatePlayerData(player: Player, key: string, value: any)
    local userId = player.UserId
    local data = playerDataCache[userId]
    if not data then return end

    data[key] = value

    -- Recalculate level when XP changes
    if key == "totalXP" then
        local Utils = require(ReplicatedStorage.Shared.Utils)
        data.level = Utils.LevelFromXP(data.totalXP)
    end

    -- Notify client of the change
    StatsChangedEvent:FireClient(player, key, value, data.level)
end

-- Add money to a player (convenience function used everywhere)
local function addMoney(player: Player, amount: number)
    local data = playerDataCache[player.UserId]
    if not data then return end

    data.money += amount
    data.totalMoneyEarned += amount

    StatsChangedEvent:FireClient(player, "money", data.money, data.level)
end

-- Add XP to a player
local function addXP(player: Player, amount: number)
    local data = playerDataCache[player.UserId]
    if not data then return end

    local oldLevel = data.level
    data.totalXP += amount

    local Utils = require(ReplicatedStorage.Shared.Utils)
    data.level = Utils.LevelFromXP(data.totalXP)

    StatsChangedEvent:FireClient(player, "xp", data.totalXP, data.level)

    -- If leveled up, send a special notification
    if data.level > oldLevel then
        StatsChangedEvent:FireClient(player, "levelUp", data.level, data.level)
    end
end

-- === EXPOSE FUNCTIONS VIA BINDABLE OBJECTS ===
-- Other server scripts can call these via BindableFunctions in ServerScriptService

local function createBindables()
    local folder = Instance.new("Folder")
    folder.Name = "DataStoreAPI"
    folder.Parent = game:GetService("ServerScriptService")

    local getDataFn = Instance.new("BindableFunction")
    getDataFn.Name = "GetPlayerData"
    getDataFn.OnInvoke = function(userId: number)
        return getPlayerData(userId)
    end
    getDataFn.Parent = folder

    local addMoneyEvent = Instance.new("BindableEvent")
    addMoneyEvent.Name = "AddMoney"
    addMoneyEvent.Event:Connect(function(player: Player, amount: number)
        addMoney(player, amount)
    end)
    addMoneyEvent.Parent = folder

    local addXPEvent = Instance.new("BindableEvent")
    addXPEvent.Name = "AddXP"
    addXPEvent.Event:Connect(function(player: Player, amount: number)
        addXP(player, amount)
    end)
    addXPEvent.Parent = folder

    local updateDataEvent = Instance.new("BindableEvent")
    updateDataEvent.Name = "UpdateData"
    updateDataEvent.Event:Connect(function(player: Player, key: string, value: any)
        updatePlayerData(player, key, value)
    end)
    updateDataEvent.Parent = folder

    local saveDataEvent = Instance.new("BindableEvent")
    saveDataEvent.Name = "SaveData"
    saveDataEvent.Event:Connect(function(player: Player)
        savePlayerData(player)
    end)
    saveDataEvent.Parent = folder
end

createBindables()

-- === PLAYER JOIN/LEAVE ===
Players.PlayerAdded:Connect(function(player)
    loadPlayerData(player)
end)

Players.PlayerRemoving:Connect(function(player)
    savePlayerData(player)
    -- Clean up cache after saving
    playerDataCache[player.UserId] = nil
end)

-- === AUTO-SAVE LOOP ===
task.spawn(function()
    while true do
        task.wait(Config.AutoSaveInterval)
        for _, player in Players:GetPlayers() do
            task.spawn(savePlayerData, player)
        end
    end
end)

-- === SAVE ALL ON SERVER SHUTDOWN ===
game:BindToClose(function()
    for _, player in Players:GetPlayers() do
        savePlayerData(player)
    end
end)

print("[DataStore] Player data system initialized")
