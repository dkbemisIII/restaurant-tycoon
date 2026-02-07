-- Config.luau
-- All game balance constants in one place. Tweak these to tune the game feel.

local Config = {}

-- === MONEY ===
Config.StartingMoney = 500         -- Cash new players begin with
Config.BaseCustomerPayment = 10    -- Minimum a customer pays per meal
Config.TipMultiplierPerStar = 0.15 -- Extra tip % per restaurant star (e.g. 3 stars = +45%)

-- === XP & LEVELS ===
Config.XPPerCustomerServed = 5
Config.XPPerDollarEarned = 0.1     -- Fractional XP from income
Config.BaseXPToLevel = 100         -- XP needed for level 2
Config.XPLevelExponent = 1.4       -- Each level needs Base * level^Exponent XP
Config.MaxLevel = 100

-- === RESTAURANT ===
Config.MaxPlots = 8                -- Max simultaneous players with plots
Config.PlotSize = 100              -- Studs; square plot side length (big enough for a fancy build-out)
Config.PlotSpacing = 16            -- Gap between plots (mall hallway width)
Config.WallHeight = 18             -- Restaurant room wall height
Config.WallThickness = 2           -- Wall part thickness
Config.DoorWidth = 10              -- Entrance doorway width

-- === CUSTOMERS ===
Config.BaseSpawnInterval = 8       -- Seconds between customer spawns (star-1 restaurant)
Config.MinSpawnInterval = 2        -- Fastest possible spawn rate
Config.SpawnIntervalReduction = 0.5 -- Seconds faster per star rating
Config.CustomerEatTime = 6        -- Seconds a customer sits and eats
Config.CustomerWalkSpeed = 12     -- Studs per second

-- === STAR RATING ===
-- Rating is average of these sub-scores, each 0-5
Config.StarCategories = {"FoodQuality", "Decor", "ServiceSpeed"}
Config.FoodQualityPerMenuItem = 0.5   -- Each unique menu item adds to food score (cap 5)
Config.DecorPerFurniture = 0.25       -- Each decoration piece adds to decor score (cap 5)
Config.BaseServiceSpeed = 3           -- Default speed score; upgrades increase it

-- === DAILY REWARDS ===
Config.DailyRewardCycle = 7        -- Days before the reward cycle repeats
Config.DailyRewards = {
    {type = "Money", amount = 200,  label = "200 Cash"},
    {type = "Money", amount = 400,  label = "400 Cash"},
    {type = "XP",    amount = 150,  label = "150 XP"},
    {type = "Money", amount = 600,  label = "600 Cash"},
    {type = "XP",    amount = 300,  label = "300 XP"},
    {type = "Money", amount = 1000, label = "1,000 Cash"},
    {type = "Money", amount = 2000, label = "2,000 Cash + Mystery Item"},
}

-- === REBIRTH ===
Config.RebirthMinLevel = 50           -- Must reach this level to rebirth
Config.RebirthMoneyMultiplier = 0.1   -- Permanent +10% earnings per rebirth
Config.MaxRebirths = 10

-- === AUTO-SAVE ===
Config.AutoSaveInterval = 120  -- Seconds between auto-saves
Config.DataStoreKey = "PlayerData_v1"

-- === LEADERBOARD ===
Config.LeaderboardUpdateInterval = 30  -- Seconds between leaderboard refreshes
Config.LeaderboardSize = 100           -- Top N shown

return Config
