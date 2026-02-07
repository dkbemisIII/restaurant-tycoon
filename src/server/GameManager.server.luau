-- GameManager.server.luau
-- Core tycoon mechanics: plot assignment, buy buttons, money/XP progression.
-- Each player gets their own restaurant plot with purchasable items on pads.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemData = require(ReplicatedStorage.Shared.ItemData)
local Utils = require(ReplicatedStorage.Shared.Utils)

-- Wait for DataStore API to be ready
local function waitForDataStoreAPI()
    return ServerScriptService:WaitForChild("DataStoreAPI")
end

local dataStoreAPI = waitForDataStoreAPI()

-- Helper to call DataStore functions
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

-- === PLOT MANAGEMENT ===

-- Track which plot each player owns
local playerPlots: {[number]: Model} = {} -- UserId -> plot Model
local plotClaimed: {[number]: boolean} = {} -- plotIndex -> claimed

-- Create RemoteEvents for tycoon actions
local buyItemEvent = Instance.new("RemoteEvent")
buyItemEvent.Name = "BuyItem"
buyItemEvent.Parent = ReplicatedStorage

local plotAssignedEvent = Instance.new("RemoteEvent")
plotAssignedEvent.Name = "PlotAssigned"
plotAssignedEvent.Parent = ReplicatedStorage

-- Generate a restaurant plot at a position
local function createPlot(plotIndex: number): Model
    local plotModel = Instance.new("Model")
    plotModel.Name = "Plot_" .. plotIndex

    -- Calculate position in a grid layout
    local col = (plotIndex - 1) % 4
    local row = math.floor((plotIndex - 1) / 4)
    local x = col * (Config.PlotSize + Config.PlotSpacing)
    local z = row * (Config.PlotSize + Config.PlotSpacing)

    -- Base floor
    local floor = Instance.new("Part")
    floor.Name = "Floor"
    floor.Size = Vector3.new(Config.PlotSize, 1, Config.PlotSize)
    floor.Position = Vector3.new(x, 0, z)
    floor.Anchored = true
    floor.Material = Enum.Material.SmoothPlastic
    floor.Color = Color3.fromRGB(200, 200, 200)
    floor.Parent = plotModel

    -- Owner label (BillboardGui set when claimed)
    local ownerPart = Instance.new("Part")
    ownerPart.Name = "OwnerSign"
    ownerPart.Size = Vector3.new(10, 6, 1)
    ownerPart.Position = Vector3.new(x, 5, z - Config.PlotSize / 2 + 1)
    ownerPart.Anchored = true
    ownerPart.Transparency = 1
    ownerPart.CanCollide = false
    ownerPart.Parent = plotModel

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(10, 0, 4, 0)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = ownerPart

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "OwnerName"
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.Text = "Unclaimed"
    nameLabel.Parent = billboard

    local starLabel = Instance.new("TextLabel")
    starLabel.Name = "StarRating"
    starLabel.Size = UDim2.new(1, 0, 0.5, 0)
    starLabel.Position = UDim2.new(0, 0, 0.5, 0)
    starLabel.BackgroundTransparency = 1
    starLabel.TextScaled = true
    starLabel.Font = Enum.Font.Gotham
    starLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    starLabel.TextStrokeTransparency = 0.5
    starLabel.Text = ""
    starLabel.Parent = billboard

    -- Spawn point for the plot owner
    local spawnPart = Instance.new("SpawnLocation")
    spawnPart.Name = "PlotSpawn"
    spawnPart.Size = Vector3.new(6, 1, 6)
    spawnPart.Position = Vector3.new(x - Config.PlotSize / 2 + 5, 1, z + Config.PlotSize / 2 - 5)
    spawnPart.Anchored = true
    spawnPart.Transparency = 1
    spawnPart.CanCollide = false
    spawnPart.TeamColor = BrickColor.new("Medium stone grey")
    spawnPart.Neutral = true -- Anyone can spawn here initially
    spawnPart.Parent = plotModel

    -- Customer entrance point
    local entrance = Instance.new("Part")
    entrance.Name = "Entrance"
    entrance.Size = Vector3.new(4, 4, 1)
    entrance.Position = Vector3.new(x, 2, z + Config.PlotSize / 2)
    entrance.Anchored = true
    entrance.Transparency = 0.5
    entrance.Color = Color3.fromRGB(100, 200, 100)
    entrance.CanCollide = false
    entrance.Parent = plotModel

    -- Kitchen area marker (back of restaurant)
    local kitchenArea = Instance.new("Part")
    kitchenArea.Name = "KitchenArea"
    kitchenArea.Size = Vector3.new(Config.PlotSize * 0.4, 1, Config.PlotSize * 0.3)
    kitchenArea.Position = Vector3.new(x, 0.6, z - Config.PlotSize / 2 + Config.PlotSize * 0.15)
    kitchenArea.Anchored = true
    kitchenArea.Material = Enum.Material.SmoothPlastic
    kitchenArea.Color = Color3.fromRGB(180, 180, 190)
    kitchenArea.Parent = plotModel

    -- Store metadata
    plotModel:SetAttribute("PlotIndex", plotIndex)
    plotModel:SetAttribute("CenterX", x)
    plotModel:SetAttribute("CenterZ", z)
    plotModel:SetAttribute("OwnerId", 0)

    return plotModel
end

-- Create buy button pads on a plot
local function createBuyButtons(plotModel: Model)
    local centerX = plotModel:GetAttribute("CenterX")
    local centerZ = plotModel:GetAttribute("CenterZ")
    local buttonsFolder = Instance.new("Folder")
    buttonsFolder.Name = "BuyButtons"
    buttonsFolder.Parent = plotModel

    -- Layout buy buttons in a row near the entrance
    local allItems = {}

    -- Add furniture items as buy buttons
    for _, item in ItemData.Furniture do
        if item.category == "Table" then
            table.insert(allItems, {item = item, category = "Furniture"})
        end
    end
    -- Add some decor
    for _, item in ItemData.Furniture do
        if item.category == "Decor" then
            table.insert(allItems, {item = item, category = "Furniture"})
        end
    end
    -- Add menu items
    for _, item in ItemData.MenuItems do
        table.insert(allItems, {item = item, category = "MenuItem"})
    end
    -- Add kitchen upgrades
    for _, item in ItemData.KitchenUpgrades do
        table.insert(allItems, {item = item, category = "KitchenUpgrade"})
    end

    -- Place buy buttons in a grid along the side of the plot
    local buttonSize = Vector3.new(5, 0.5, 5)
    local buttonsPerRow = 5
    local startX = centerX - Config.PlotSize / 2 + 4
    local startZ = centerZ

    for i, entry in allItems do
        local col = (i - 1) % buttonsPerRow
        local row = math.floor((i - 1) / buttonsPerRow)

        local pad = Instance.new("Part")
        pad.Name = "BuyPad_" .. entry.item.id
        pad.Size = buttonSize
        pad.Position = Vector3.new(
            startX + col * 6,
            0.75,
            startZ + row * 6
        )
        pad.Anchored = true
        pad.Material = Enum.Material.Neon
        pad.Color = Color3.fromRGB(0, 200, 0)
        pad.Parent = buttonsFolder

        -- Store item info on the pad
        pad:SetAttribute("ItemId", entry.item.id)
        pad:SetAttribute("Category", entry.category)
        pad:SetAttribute("Price", entry.item.price)
        pad:SetAttribute("UnlockLevel", entry.item.unlockLevel)
        pad:SetAttribute("Purchased", false)

        -- Price label floating above the pad
        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Size = UDim2.new(6, 0, 3, 0)
        billboardGui.StudsOffset = Vector3.new(0, 3, 0)
        billboardGui.AlwaysOnTop = false
        billboardGui.Parent = pad

        local nameText = Instance.new("TextLabel")
        nameText.Name = "ItemName"
        nameText.Size = UDim2.new(1, 0, 0.5, 0)
        nameText.BackgroundTransparency = 1
        nameText.TextScaled = true
        nameText.Font = Enum.Font.GothamBold
        nameText.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameText.TextStrokeTransparency = 0.3
        nameText.Text = entry.item.name
        nameText.Parent = billboardGui

        local priceText = Instance.new("TextLabel")
        priceText.Name = "PriceLabel"
        priceText.Size = UDim2.new(1, 0, 0.5, 0)
        priceText.Position = UDim2.new(0, 0, 0.5, 0)
        priceText.BackgroundTransparency = 1
        priceText.TextScaled = true
        priceText.Font = Enum.Font.Gotham
        priceText.TextColor3 = Color3.fromRGB(100, 255, 100)
        priceText.TextStrokeTransparency = 0.3
        priceText.Text = Utils.FormatMoney(entry.item.price)
        priceText.Parent = billboardGui
    end
end

-- Place a purchased item (table, decor, etc.) visually on the plot
local function placeItemOnPlot(plotModel: Model, itemId: string, itemIndex: number)
    local item = ItemData.GetItem(itemId)
    if not item then return end

    local centerX = plotModel:GetAttribute("CenterX")
    local centerZ = plotModel:GetAttribute("CenterZ")

    local placedFolder = plotModel:FindFirstChild("PlacedItems")
    if not placedFolder then
        placedFolder = Instance.new("Folder")
        placedFolder.Name = "PlacedItems"
        placedFolder.Parent = plotModel
    end

    -- Place tables in the dining area (right side of plot)
    if item.category == "Table" then
        local tableIndex = 0
        for _, child in placedFolder:GetChildren() do
            if child:GetAttribute("Category") == "Table" then
                tableIndex += 1
            end
        end

        local col = tableIndex % 3
        local row = math.floor(tableIndex / 3)
        local tableX = centerX + 5 + col * 10
        local tableZ = centerZ - 10 + row * 10

        local tablePart = Instance.new("Part")
        tablePart.Name = "Table_" .. itemId .. "_" .. tableIndex
        tablePart.Size = Vector3.new(item.size[1], item.size[2], item.size[3])
        tablePart.Position = Vector3.new(tableX, item.size[2] / 2 + 0.5, tableZ)
        tablePart.Anchored = true
        tablePart.Material = Enum.Material.Wood
        tablePart.Color = Color3.fromRGB(139, 90, 43)
        tablePart:SetAttribute("ItemId", itemId)
        tablePart:SetAttribute("Category", "Table")
        tablePart:SetAttribute("Seats", item.seats or 2)
        tablePart:SetAttribute("Occupied", false)
        tablePart.Parent = placedFolder

        -- Create seat attachment points around the table
        for seatNum = 1, (item.seats or 2) do
            local angle = (seatNum / (item.seats or 2)) * math.pi * 2
            local seatX = tableX + math.cos(angle) * (item.size[1] / 2 + 2)
            local seatZ = tableZ + math.sin(angle) * (item.size[3] / 2 + 2)

            local seat = Instance.new("Seat")
            seat.Name = "Seat_" .. seatNum
            seat.Size = Vector3.new(2, 2, 2)
            seat.Position = Vector3.new(seatX, 1.5, seatZ)
            seat.Anchored = true
            seat.Material = Enum.Material.Wood
            seat.Color = Color3.fromRGB(100, 60, 30)
            seat.Transparency = 0
            seat.Disabled = true -- We handle seating manually for NPCs
            seat:SetAttribute("TableName", tablePart.Name)
            seat.Parent = placedFolder
        end

    elseif item.category == "Decor" then
        -- Place decorations along the walls
        local decorIndex = 0
        for _, child in placedFolder:GetChildren() do
            if child:GetAttribute("Category") == "Decor" then
                decorIndex += 1
            end
        end

        local decorX = centerX - Config.PlotSize / 2 + 3 + (decorIndex % 6) * 8
        local decorZ = centerZ - Config.PlotSize / 2 + 3

        local decorPart = Instance.new("Part")
        decorPart.Name = "Decor_" .. itemId .. "_" .. decorIndex
        decorPart.Size = Vector3.new(2, 3, 2)
        decorPart.Position = Vector3.new(decorX, 2, decorZ)
        decorPart.Anchored = true
        decorPart.Material = Enum.Material.SmoothPlastic
        decorPart.Color = Color3.fromRGB(200, 150, 100)
        decorPart:SetAttribute("ItemId", itemId)
        decorPart:SetAttribute("Category", "Decor")
        decorPart.Parent = placedFolder
    end
end

-- === PLOT SETUP ===
-- Create all plots in the workspace
local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Plots"
plotsFolder.Parent = workspace

for i = 1, Config.MaxPlots do
    local plot = createPlot(i)
    plot.Parent = plotsFolder
    createBuyButtons(plot)
end

-- Assign a plot to a player
local function assignPlot(player: Player)
    for i = 1, Config.MaxPlots do
        if not plotClaimed[i] then
            plotClaimed[i] = true
            local plotModel = plotsFolder:FindFirstChild("Plot_" .. i)
            if plotModel then
                plotModel:SetAttribute("OwnerId", player.UserId)
                playerPlots[player.UserId] = plotModel

                -- Update the owner sign
                local sign = plotModel:FindFirstChild("OwnerSign")
                if sign then
                    local billboard = sign:FindFirstChildOfClass("BillboardGui")
                    if billboard then
                        local nameLabel = billboard:FindFirstChild("OwnerName")
                        if nameLabel then
                            nameLabel.Text = player.Name .. "'s Restaurant"
                        end
                    end
                end

                -- Teleport player to their plot spawn
                local spawnPart = plotModel:FindFirstChild("PlotSpawn")
                if spawnPart and player.Character then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
                    end
                end

                -- Restore any previously purchased items
                local data = getPlayerData(player.UserId)
                if data and data.ownedItems then
                    for idx, itemId in data.ownedItems do
                        -- Mark buy button as purchased
                        local buyButtons = plotModel:FindFirstChild("BuyButtons")
                        if buyButtons then
                            local pad = buyButtons:FindFirstChild("BuyPad_" .. itemId)
                            if pad then
                                pad:SetAttribute("Purchased", true)
                                pad.Color = Color3.fromRGB(100, 100, 100)
                                pad.Transparency = 0.5
                                local bg = pad:FindFirstChildOfClass("BillboardGui")
                                if bg then
                                    local priceLabel = bg:FindFirstChild("PriceLabel")
                                    if priceLabel then
                                        priceLabel.Text = "OWNED"
                                        priceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                                    end
                                end
                            end
                        end
                        -- Place the item visually
                        local itemInfo = ItemData.GetItem(itemId)
                        if itemInfo and (itemInfo.category == "Table" or itemInfo.category == "Decor") then
                            placeItemOnPlot(plotModel, itemId, idx)
                        end
                    end

                    -- Update star rating display
                    updateStarRating(player)
                end

                plotAssignedEvent:FireClient(player, i)
                print("[GameManager] Assigned plot", i, "to", player.Name)
                return
            end
        end
    end
    warn("[GameManager] No plots available for", player.Name)
end

-- Update the star rating display on a player's plot
function updateStarRating(player: Player)
    local plotModel = playerPlots[player.UserId]
    if not plotModel then return end

    local data = getPlayerData(player.UserId)
    if not data then return end

    local rating = Utils.CalculateStarRating(data.ownedItems, data.kitchenUpgrade)

    local sign = plotModel:FindFirstChild("OwnerSign")
    if sign then
        local billboard = sign:FindFirstChildOfClass("BillboardGui")
        if billboard then
            local starLabel = billboard:FindFirstChild("StarRating")
            if starLabel then
                -- Show stars as unicode stars
                local fullStars = math.floor(rating)
                local starText = string.rep("★", fullStars)
                if rating - fullStars >= 0.5 then
                    starText ..= "½"
                end
                starLabel.Text = starText .. " (" .. string.format("%.1f", rating) .. ")"
            end
        end
    end

    -- Store on plot for customer spawner to reference
    plotModel:SetAttribute("StarRating", rating)
end

-- === BUY BUTTON INTERACTION ===
-- When a player steps on a buy pad, attempt to purchase the item

local function setupBuyPadTouch(pad: Part)
    pad.Touched:Connect(function(hit)
        local character = hit.Parent
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end

        local player = Players:GetPlayerFromCharacter(character)
        if not player then return end

        -- Check if this pad belongs to the player's plot
        local plotModel = pad.Parent and pad.Parent.Parent
        if not plotModel then return end
        if plotModel:GetAttribute("OwnerId") ~= player.UserId then return end

        -- Already purchased?
        if pad:GetAttribute("Purchased") then return end

        local itemId = pad:GetAttribute("ItemId")
        local price = pad:GetAttribute("Price")
        local unlockLevel = pad:GetAttribute("UnlockLevel")
        local category = pad:GetAttribute("Category")

        local data = getPlayerData(player.UserId)
        if not data then return end

        -- Check level requirement
        if data.level < unlockLevel then return end

        -- Check if already owned (for non-stackable items)
        if Utils.Contains(data.ownedItems, itemId) then return end

        -- Check money
        if data.money < price then return end

        -- Purchase!
        data.money -= price
        table.insert(data.ownedItems, itemId)

        -- Handle kitchen upgrades specially
        if category == "KitchenUpgrade" then
            data.kitchenUpgrade = itemId
            updateData(player, "kitchenUpgrade", itemId)
        end

        updateData(player, "money", data.money)
        updateData(player, "ownedItems", data.ownedItems)

        -- Mark pad as purchased
        pad:SetAttribute("Purchased", true)
        pad.Color = Color3.fromRGB(100, 100, 100)
        pad.Transparency = 0.5
        local bg = pad:FindFirstChildOfClass("BillboardGui")
        if bg then
            local priceLabel = bg:FindFirstChild("PriceLabel")
            if priceLabel then
                priceLabel.Text = "OWNED"
                priceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end

        -- Place the item on the plot if it's furniture
        local itemInfo = ItemData.GetItem(itemId)
        if itemInfo and (itemInfo.category == "Table" or itemInfo.category == "Decor") then
            placeItemOnPlot(plotModel, itemId, #data.ownedItems)
        end

        -- Award XP for purchasing
        addXP(player, 10)

        -- Update star rating
        updateStarRating(player)

        -- Notify client
        local statsEvent = ReplicatedStorage:FindFirstChild("StatsChanged")
        if statsEvent then
            statsEvent:FireClient(player, "money", data.money, data.level)
        end

        print("[GameManager]", player.Name, "purchased", itemId, "for", Utils.FormatMoney(price))
    end)
end

-- Connect touch events for all buy pads across all plots
for _, plotModel in plotsFolder:GetChildren() do
    local buyButtons = plotModel:FindFirstChild("BuyButtons")
    if buyButtons then
        for _, pad in buyButtons:GetChildren() do
            setupBuyPadTouch(pad)
        end
    end
end

-- === PLAYER LIFECYCLE ===
Players.PlayerAdded:Connect(function(player)
    -- Wait a moment for data to load
    task.wait(1)

    player.CharacterAdded:Connect(function(character)
        -- Teleport to plot if they have one
        task.wait(0.5)
        local plotModel = playerPlots[player.UserId]
        if plotModel then
            local spawnPart = plotModel:FindFirstChild("PlotSpawn")
            if spawnPart then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
                end
            end
        end
    end)

    assignPlot(player)
end)

Players.PlayerRemoving:Connect(function(player)
    local plotModel = playerPlots[player.UserId]
    if plotModel then
        local plotIndex = plotModel:GetAttribute("PlotIndex")
        plotClaimed[plotIndex] = false
        plotModel:SetAttribute("OwnerId", 0)
        playerPlots[player.UserId] = nil

        -- Reset plot sign
        local sign = plotModel:FindFirstChild("OwnerSign")
        if sign then
            local billboard = sign:FindFirstChildOfClass("BillboardGui")
            if billboard then
                local nameLabel = billboard:FindFirstChild("OwnerName")
                if nameLabel then nameLabel.Text = "Unclaimed" end
                local starLabel = billboard:FindFirstChild("StarRating")
                if starLabel then starLabel.Text = "" end
            end
        end

        -- Remove placed items (they'll be restored from data on rejoin)
        local placed = plotModel:FindFirstChild("PlacedItems")
        if placed then placed:ClearAllChildren() end

        -- Reset buy buttons
        local buyButtons = plotModel:FindFirstChild("BuyButtons")
        if buyButtons then
            for _, pad in buyButtons:GetChildren() do
                pad:SetAttribute("Purchased", false)
                pad.Color = Color3.fromRGB(0, 200, 0)
                pad.Transparency = 0
                local bg = pad:FindFirstChildOfClass("BillboardGui")
                if bg then
                    local priceLabel = bg:FindFirstChild("PriceLabel")
                    if priceLabel then
                        local price = pad:GetAttribute("Price")
                        priceLabel.Text = Utils.FormatMoney(price)
                        priceLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                    end
                end
            end
        end
    end
end)

-- === REBIRTH ===
local rebirthEvent = Instance.new("RemoteEvent")
rebirthEvent.Name = "Rebirth"
rebirthEvent.Parent = ReplicatedStorage

rebirthEvent.OnServerEvent:Connect(function(player)
    local data = getPlayerData(player.UserId)
    if not data then return end

    -- Check rebirth requirements
    if data.level < Config.RebirthMinLevel then return end
    if data.rebirths >= Config.MaxRebirths then return end

    -- Perform rebirth: reset progress, grant permanent multiplier
    data.rebirths += 1
    data.money = Config.StartingMoney
    data.totalXP = 0
    data.level = 1
    data.ownedItems = {}
    data.kitchenUpgrade = "basic_stove"
    data.placedFurniture = {}

    updateData(player, "rebirths", data.rebirths)
    updateData(player, "money", data.money)
    updateData(player, "totalXP", data.totalXP)
    updateData(player, "ownedItems", data.ownedItems)
    updateData(player, "kitchenUpgrade", data.kitchenUpgrade)

    -- Reset the plot
    local plotModel = playerPlots[player.UserId]
    if plotModel then
        local placed = plotModel:FindFirstChild("PlacedItems")
        if placed then placed:ClearAllChildren() end

        local buyButtons = plotModel:FindFirstChild("BuyButtons")
        if buyButtons then
            for _, pad in buyButtons:GetChildren() do
                pad:SetAttribute("Purchased", false)
                pad.Color = Color3.fromRGB(0, 200, 0)
                pad.Transparency = 0
                local bg = pad:FindFirstChildOfClass("BillboardGui")
                if bg then
                    local priceLabel = bg:FindFirstChild("PriceLabel")
                    if priceLabel then
                        local price = pad:GetAttribute("Price")
                        priceLabel.Text = Utils.FormatMoney(price)
                        priceLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                    end
                end
            end
        end

        updateStarRating(player)
    end

    -- Notify client
    local dataLoadedEvent = ReplicatedStorage:FindFirstChild("PlayerDataLoaded")
    if dataLoadedEvent then
        dataLoadedEvent:FireClient(player, data)
    end

    print("[GameManager]", player.Name, "rebirthed! Total rebirths:", data.rebirths)
end)

print("[GameManager] Tycoon system initialized with", Config.MaxPlots, "plots")
