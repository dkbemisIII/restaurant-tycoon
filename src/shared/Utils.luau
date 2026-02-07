-- Utils.luau
-- Shared utility functions used by both server and client code.

local Config = require(script.Parent.Config)

local Utils = {}

-- Calculate total XP needed to reach a given level
function Utils.XPForLevel(level: number): number
    if level <= 1 then return 0 end
    return math.floor(Config.BaseXPToLevel * (level ^ Config.XPLevelExponent))
end

-- Given total XP, return the player's current level
function Utils.LevelFromXP(totalXP: number): number
    local level = 1
    while level < Config.MaxLevel do
        local needed = Utils.XPForLevel(level + 1)
        if totalXP < needed then break end
        level += 1
    end
    return level
end

-- XP progress toward the next level as a fraction 0-1
function Utils.XPProgress(totalXP: number): number
    local level = Utils.LevelFromXP(totalXP)
    if level >= Config.MaxLevel then return 1 end
    local currentLevelXP = Utils.XPForLevel(level)
    local nextLevelXP = Utils.XPForLevel(level + 1)
    local range = nextLevelXP - currentLevelXP
    if range <= 0 then return 1 end
    return math.clamp((totalXP - currentLevelXP) / range, 0, 1)
end

-- Calculate restaurant star rating from owned items
function Utils.CalculateStarRating(ownedItems: {string}, kitchenUpgradeId: string?): number
    local ItemData = require(script.Parent.ItemData)

    -- Food quality: 0.5 per unique menu item, capped at 5
    local foodScore = 0
    for _, id in ownedItems do
        local item = ItemData.GetItem(id)
        if item and item.paymentBonus then -- it's a menu item
            foodScore += Config.FoodQualityPerMenuItem
        end
    end
    foodScore = math.min(foodScore, 5)

    -- Decor: sum of decorBonus values, capped at 5
    local decorScore = 0
    for _, id in ownedItems do
        local item = ItemData.GetItem(id)
        if item and item.decorBonus then
            decorScore += item.decorBonus * Config.DecorPerFurniture
        end
    end
    decorScore = math.min(decorScore, 5)

    -- Service speed: base + kitchen upgrade bonus, capped at 5
    local speedScore = Config.BaseServiceSpeed
    if kitchenUpgradeId then
        local upgrade = ItemData.GetItem(kitchenUpgradeId)
        if upgrade and upgrade.speedBonus then
            speedScore += upgrade.speedBonus
        end
    end
    speedScore = math.min(speedScore, 5)

    -- Average all three categories
    local total = (foodScore + decorScore + speedScore) / #Config.StarCategories
    return math.floor(total * 10) / 10 -- Round to 1 decimal
end

-- Calculate customer payment based on base pay + menu bonuses + tip from stars
function Utils.CalculatePayment(ownedMenuItems: {string}, starRating: number, rebirths: number): number
    local ItemData = require(script.Parent.ItemData)
    local base = Config.BaseCustomerPayment

    -- Add bonus from owned menu items
    for _, id in ownedMenuItems do
        local item = ItemData.GetItem(id)
        if item and item.paymentBonus then
            base += item.paymentBonus
        end
    end

    -- Tip multiplier from star rating
    local tipMultiplier = 1 + (starRating * Config.TipMultiplierPerStar)

    -- Rebirth multiplier
    local rebirthMultiplier = 1 + (rebirths * Config.RebirthMoneyMultiplier)

    return math.floor(base * tipMultiplier * rebirthMultiplier)
end

-- Format large numbers with commas: 12345 -> "12,345"
function Utils.FormatMoney(amount: number): string
    local str = tostring(math.floor(amount))
    local formatted = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    -- Remove leading comma if present
    if formatted:sub(1, 1) == "," then
        formatted = formatted:sub(2)
    end
    return "$" .. formatted
end

-- Shallow copy a table
function Utils.ShallowCopy(t)
    local copy = {}
    for k, v in t do
        copy[k] = v
    end
    return copy
end

-- Check if a table (used as an array) contains a value
function Utils.Contains(t, value): boolean
    for _, v in t do
        if v == value then return true end
    end
    return false
end

return Utils
