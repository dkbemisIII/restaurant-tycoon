-- ItemData.luau
-- Catalog of everything players can buy: menu items, furniture, kitchen upgrades.
-- Each item has an id, display name, category, price, unlock level, and effect values.

local ItemData = {}

-- === MENU ITEMS ===
-- Adding menu items increases FoodQuality star rating and customer payment.
ItemData.MenuItems = {
    {id = "burger",       name = "Burger",         price = 100,   unlockLevel = 1,  paymentBonus = 2},
    {id = "fries",        name = "Fries",          price = 50,    unlockLevel = 1,  paymentBonus = 1},
    {id = "soda",         name = "Soda",           price = 30,    unlockLevel = 1,  paymentBonus = 1},
    {id = "pizza",        name = "Pizza",          price = 300,   unlockLevel = 5,  paymentBonus = 4},
    {id = "salad",        name = "Salad",          price = 200,   unlockLevel = 3,  paymentBonus = 3},
    {id = "steak",        name = "Steak",          price = 800,   unlockLevel = 10, paymentBonus = 8},
    {id = "sushi",        name = "Sushi",          price = 1500,  unlockLevel = 20, paymentBonus = 12},
    {id = "pasta",        name = "Pasta",          price = 500,   unlockLevel = 8,  paymentBonus = 5},
    {id = "lobster",      name = "Lobster",        price = 3000,  unlockLevel = 30, paymentBonus = 20},
    {id = "dessert_cake", name = "Chocolate Cake", price = 400,   unlockLevel = 6,  paymentBonus = 4},
}

-- === FURNITURE ===
-- Tables allow more customers; chairs are required per table; decorations boost Decor rating.
ItemData.Furniture = {
    -- Tables (each needs chairs to be functional)
    {id = "basic_table",    name = "Basic Table",     category = "Table",      price = 150,   unlockLevel = 1,  seats = 2, size = {4, 3, 4}},
    {id = "round_table",    name = "Round Table",     category = "Table",      price = 400,   unlockLevel = 5,  seats = 4, size = {5, 3, 5}},
    {id = "booth",          name = "Booth",           category = "Table",      price = 800,   unlockLevel = 12, seats = 4, size = {6, 4, 4}},
    {id = "vip_table",      name = "VIP Table",       category = "Table",      price = 2000,  unlockLevel = 25, seats = 6, size = {6, 3, 6}},

    -- Decorations (boost Decor star rating)
    {id = "potted_plant",   name = "Potted Plant",    category = "Decor",      price = 80,    unlockLevel = 1,  decorBonus = 1},
    {id = "painting",       name = "Wall Painting",   category = "Decor",      price = 200,   unlockLevel = 3,  decorBonus = 2},
    {id = "chandelier",     name = "Chandelier",      category = "Decor",      price = 600,   unlockLevel = 10, decorBonus = 4},
    {id = "fountain",       name = "Fountain",        category = "Decor",      price = 1500,  unlockLevel = 20, decorBonus = 6},
    {id = "aquarium",       name = "Aquarium",        category = "Decor",      price = 3000,  unlockLevel = 35, decorBonus = 8},

    -- Flooring/Walls (aesthetic tiers)
    {id = "tile_floor",     name = "Tile Floor",      category = "Floor",      price = 300,   unlockLevel = 2,  decorBonus = 1},
    {id = "wood_floor",     name = "Hardwood Floor",  category = "Floor",      price = 800,   unlockLevel = 8,  decorBonus = 3},
    {id = "marble_floor",   name = "Marble Floor",    category = "Floor",      price = 2500,  unlockLevel = 22, decorBonus = 5},
}

-- === KITCHEN UPGRADES ===
-- Improve service speed and food quality.
ItemData.KitchenUpgrades = {
    {id = "basic_stove",    name = "Basic Stove",     price = 200,   unlockLevel = 1,  speedBonus = 0,   qualityBonus = 0},
    {id = "gas_stove",      name = "Gas Stove",       price = 600,   unlockLevel = 5,  speedBonus = 0.5, qualityBonus = 0.5},
    {id = "industrial_oven",name = "Industrial Oven", price = 1500,  unlockLevel = 15, speedBonus = 1,   qualityBonus = 1},
    {id = "pro_kitchen",    name = "Pro Kitchen",     price = 5000,  unlockLevel = 30, speedBonus = 1.5, qualityBonus = 1.5},
    {id = "master_kitchen", name = "Master Kitchen",  price = 15000, unlockLevel = 50, speedBonus = 2,   qualityBonus = 2},
}

-- Helper: look up any item by id across all categories
function ItemData.GetItem(id: string)
    for _, list in {ItemData.MenuItems, ItemData.Furniture, ItemData.KitchenUpgrades} do
        for _, item in list do
            if item.id == id then
                return item
            end
        end
    end
    return nil
end

-- Helper: get all items a player can buy at their level
function ItemData.GetAvailableItems(playerLevel: number)
    local available = {MenuItems = {}, Furniture = {}, KitchenUpgrades = {}}
    for _, item in ItemData.MenuItems do
        if item.unlockLevel <= playerLevel then
            table.insert(available.MenuItems, item)
        end
    end
    for _, item in ItemData.Furniture do
        if item.unlockLevel <= playerLevel then
            table.insert(available.Furniture, item)
        end
    end
    for _, item in ItemData.KitchenUpgrades do
        if item.unlockLevel <= playerLevel then
            table.insert(available.KitchenUpgrades, item)
        end
    end
    return available
end

return ItemData
