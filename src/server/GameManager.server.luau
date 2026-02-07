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

    local S = Config.PlotSize
    local W = Config.WallHeight
    local T = Config.WallThickness
    local DOOR = Config.DoorWidth

    -- Calculate position in a grid layout (4 columns, 2 rows)
    local col = (plotIndex - 1) % 4
    local row = math.floor((plotIndex - 1) / 4)
    local x = col * (S + Config.PlotSpacing)
    local z = row * (S + Config.PlotSpacing)

    -- Half-sizes for convenience
    local halfS = S / 2

    -- =============================================
    -- FLOOR — polished restaurant tile
    -- =============================================
    local floor = Instance.new("Part")
    floor.Name = "Floor"
    floor.Size = Vector3.new(S, 1, S)
    floor.Position = Vector3.new(x, 0, z)
    floor.Anchored = true
    floor.Material = Enum.Material.Marble
    floor.Color = Color3.fromRGB(225, 218, 200)
    floor.Parent = plotModel

    -- Accent border strip around the floor edge
    for _, info in {
        {Vector3.new(S, 0.1, 2), Vector3.new(x, 0.55, z - halfS + 1)},
        {Vector3.new(S, 0.1, 2), Vector3.new(x, 0.55, z + halfS - 1)},
        {Vector3.new(2, 0.1, S), Vector3.new(x - halfS + 1, 0.55, z)},
        {Vector3.new(2, 0.1, S), Vector3.new(x + halfS - 1, 0.55, z)},
    } do
        local strip = Instance.new("Part")
        strip.Name = "FloorBorder"
        strip.Size = info[1]
        strip.Position = info[2]
        strip.Anchored = true
        strip.Material = Enum.Material.Marble
        strip.Color = Color3.fromRGB(160, 130, 80)
        strip.Parent = plotModel
    end

    -- Kitchen floor area (back 30% of restaurant)
    local kitchenDepth = S * 0.28
    local kitchenArea = Instance.new("Part")
    kitchenArea.Name = "KitchenArea"
    kitchenArea.Size = Vector3.new(S - T * 2, 0.15, kitchenDepth)
    kitchenArea.Position = Vector3.new(x, 0.58, z - halfS + kitchenDepth / 2 + T)
    kitchenArea.Anchored = true
    kitchenArea.Material = Enum.Material.SmoothPlastic
    kitchenArea.Color = Color3.fromRGB(190, 190, 195)
    kitchenArea.Parent = plotModel

    -- =============================================
    -- WALLS — 4 walls with a doorway in the front
    -- =============================================
    local wallColor = Color3.fromRGB(235, 228, 215)
    local accentWallColor = Color3.fromRGB(140, 60, 60) -- warm restaurant accent

    -- Back wall (solid)
    local backWall = Instance.new("Part")
    backWall.Name = "Wall_Back"
    backWall.Size = Vector3.new(S, W, T)
    backWall.Position = Vector3.new(x, W / 2, z - halfS)
    backWall.Anchored = true
    backWall.Material = Enum.Material.SmoothPlastic
    backWall.Color = accentWallColor
    backWall.Parent = plotModel

    -- Left wall (solid)
    local leftWall = Instance.new("Part")
    leftWall.Name = "Wall_Left"
    leftWall.Size = Vector3.new(T, W, S)
    leftWall.Position = Vector3.new(x - halfS, W / 2, z)
    leftWall.Anchored = true
    leftWall.Material = Enum.Material.SmoothPlastic
    leftWall.Color = wallColor
    leftWall.Parent = plotModel

    -- Right wall (solid)
    local rightWall = Instance.new("Part")
    rightWall.Name = "Wall_Right"
    rightWall.Size = Vector3.new(T, W, S)
    rightWall.Position = Vector3.new(x + halfS, W / 2, z)
    rightWall.Anchored = true
    rightWall.Material = Enum.Material.SmoothPlastic
    rightWall.Color = wallColor
    rightWall.Parent = plotModel

    -- Front wall — split into left and right sections with a doorway in the center
    local frontWallSectionWidth = (S - DOOR) / 2
    local frontWallLeft = Instance.new("Part")
    frontWallLeft.Name = "Wall_FrontLeft"
    frontWallLeft.Size = Vector3.new(frontWallSectionWidth, W, T)
    frontWallLeft.Position = Vector3.new(x - halfS + frontWallSectionWidth / 2, W / 2, z + halfS)
    frontWallLeft.Anchored = true
    frontWallLeft.Material = Enum.Material.SmoothPlastic
    frontWallLeft.Color = wallColor
    frontWallLeft.Parent = plotModel

    local frontWallRight = Instance.new("Part")
    frontWallRight.Name = "Wall_FrontRight"
    frontWallRight.Size = Vector3.new(frontWallSectionWidth, W, T)
    frontWallRight.Position = Vector3.new(x + halfS - frontWallSectionWidth / 2, W / 2, z + halfS)
    frontWallRight.Anchored = true
    frontWallRight.Material = Enum.Material.SmoothPlastic
    frontWallRight.Color = wallColor
    frontWallRight.Parent = plotModel

    -- Header above the door
    local doorHeader = Instance.new("Part")
    doorHeader.Name = "DoorHeader"
    doorHeader.Size = Vector3.new(DOOR + 2, 4, T + 1)
    doorHeader.Position = Vector3.new(x, W - 2, z + halfS)
    doorHeader.Anchored = true
    doorHeader.Material = Enum.Material.SmoothPlastic
    doorHeader.Color = Color3.fromRGB(60, 40, 30)
    doorHeader.Parent = plotModel

    -- =============================================
    -- WINDOWS — large glass panes on left and right walls
    -- =============================================
    for _, wallInfo in {
        {pos = Vector3.new(x - halfS + 0.2, W * 0.45, z + 10), size = Vector3.new(0.5, W * 0.45, 20)},
        {pos = Vector3.new(x - halfS + 0.2, W * 0.45, z - 15), size = Vector3.new(0.5, W * 0.45, 15)},
        {pos = Vector3.new(x + halfS - 0.2, W * 0.45, z + 10), size = Vector3.new(0.5, W * 0.45, 20)},
        {pos = Vector3.new(x + halfS - 0.2, W * 0.45, z - 15), size = Vector3.new(0.5, W * 0.45, 15)},
    } do
        local window = Instance.new("Part")
        window.Name = "Window"
        window.Size = wallInfo.size
        window.Position = wallInfo.pos
        window.Anchored = true
        window.Material = Enum.Material.Glass
        window.Color = Color3.fromRGB(200, 220, 240)
        window.Transparency = 0.6
        window.CanCollide = false
        window.Parent = plotModel
    end

    -- =============================================
    -- CEILING — with warm recessed lighting
    -- =============================================
    local ceiling = Instance.new("Part")
    ceiling.Name = "Ceiling"
    ceiling.Size = Vector3.new(S, 1, S)
    ceiling.Position = Vector3.new(x, W, z)
    ceiling.Anchored = true
    ceiling.Material = Enum.Material.SmoothPlastic
    ceiling.Color = Color3.fromRGB(240, 238, 230)
    ceiling.Parent = plotModel

    -- Recessed ceiling lights (4 warm lights in a grid)
    for _, lightOffset in {
        {-S * 0.25, -S * 0.2},
        { S * 0.25, -S * 0.2},
        {-S * 0.25,  S * 0.2},
        { S * 0.25,  S * 0.2},
    } do
        local lightFixture = Instance.new("Part")
        lightFixture.Name = "CeilingLight"
        lightFixture.Size = Vector3.new(4, 0.5, 4)
        lightFixture.Position = Vector3.new(x + lightOffset[1], W - 0.5, z + lightOffset[2])
        lightFixture.Anchored = true
        lightFixture.Material = Enum.Material.Neon
        lightFixture.Color = Color3.fromRGB(255, 240, 200)
        lightFixture.Parent = plotModel

        local pointLight = Instance.new("PointLight")
        pointLight.Brightness = 0.8
        pointLight.Range = 35
        pointLight.Color = Color3.fromRGB(255, 235, 200)
        pointLight.Parent = lightFixture
    end

    -- =============================================
    -- KITCHEN COUNTER — divider between kitchen and dining
    -- =============================================
    local counterZ = z - halfS + kitchenDepth + T
    local counterWidth = S * 0.7

    local counter = Instance.new("Part")
    counter.Name = "KitchenCounter"
    counter.Size = Vector3.new(counterWidth, 3.5, 2)
    counter.Position = Vector3.new(x, 2.25, counterZ)
    counter.Anchored = true
    counter.Material = Enum.Material.Marble
    counter.Color = Color3.fromRGB(60, 60, 65)
    counter.Parent = plotModel

    -- Counter top surface (lighter)
    local counterTop = Instance.new("Part")
    counterTop.Name = "CounterTop"
    counterTop.Size = Vector3.new(counterWidth + 1, 0.3, 3)
    counterTop.Position = Vector3.new(x, 4.15, counterZ)
    counterTop.Anchored = true
    counterTop.Material = Enum.Material.Marble
    counterTop.Color = Color3.fromRGB(200, 195, 185)
    counterTop.Parent = plotModel

    -- Pass-through window in the counter
    local passWindow = Instance.new("Part")
    passWindow.Name = "PassWindow"
    passWindow.Size = Vector3.new(12, 2.5, 0.5)
    passWindow.Position = Vector3.new(x, 2.75, counterZ)
    passWindow.Anchored = true
    passWindow.Material = Enum.Material.Glass
    passWindow.Color = Color3.fromRGB(200, 230, 255)
    passWindow.Transparency = 0.7
    passWindow.CanCollide = false
    passWindow.Parent = plotModel

    -- =============================================
    -- HOST STAND — near the entrance
    -- =============================================
    local hostStand = Instance.new("Part")
    hostStand.Name = "HostStand"
    hostStand.Size = Vector3.new(3, 3.5, 2)
    hostStand.Position = Vector3.new(x + DOOR / 2 + 3, 1.75, z + halfS - 5)
    hostStand.Anchored = true
    hostStand.Material = Enum.Material.Wood
    hostStand.Color = Color3.fromRGB(80, 50, 30)
    hostStand.Parent = plotModel

    -- =============================================
    -- RESTAURANT SIGN — above the front door (outside)
    -- =============================================
    local ownerPart = Instance.new("Part")
    ownerPart.Name = "OwnerSign"
    ownerPart.Size = Vector3.new(DOOR + 4, 4, 1)
    ownerPart.Position = Vector3.new(x, W + 3, z + halfS + 1)
    ownerPart.Anchored = true
    ownerPart.Material = Enum.Material.Neon
    ownerPart.Color = Color3.fromRGB(40, 40, 50)
    ownerPart.Parent = plotModel

    local signGui = Instance.new("SurfaceGui")
    signGui.Face = Enum.NormalId.Front
    signGui.CanvasSize = Vector2.new(500, 150)
    signGui.Parent = ownerPart

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "OwnerName"
    nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Text = "Available"
    nameLabel.Parent = signGui

    local starLabel = Instance.new("TextLabel")
    starLabel.Name = "StarRating"
    starLabel.Size = UDim2.new(1, 0, 0.4, 0)
    starLabel.Position = UDim2.new(0, 0, 0.6, 0)
    starLabel.BackgroundTransparency = 1
    starLabel.TextScaled = true
    starLabel.Font = Enum.Font.Gotham
    starLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    starLabel.Text = ""
    starLabel.Parent = signGui

    -- =============================================
    -- SPAWN POINT — inside near the entrance
    -- =============================================
    local spawnPart = Instance.new("SpawnLocation")
    spawnPart.Name = "PlotSpawn"
    spawnPart.Size = Vector3.new(6, 1, 6)
    spawnPart.Position = Vector3.new(x, 1, z + halfS - 8)
    spawnPart.Anchored = true
    spawnPart.Transparency = 1
    spawnPart.CanCollide = false
    spawnPart.TeamColor = BrickColor.new("Medium stone grey")
    spawnPart.Neutral = true
    spawnPart.Parent = plotModel

    -- =============================================
    -- CUSTOMER ENTRANCE — invisible trigger at the door
    -- =============================================
    local entrance = Instance.new("Part")
    entrance.Name = "Entrance"
    entrance.Size = Vector3.new(DOOR, 6, 2)
    entrance.Position = Vector3.new(x, 3, z + halfS)
    entrance.Anchored = true
    entrance.Transparency = 1
    entrance.CanCollide = false
    entrance.Parent = plotModel

    -- =============================================
    -- MONEY COLLECTOR — big flashing $ sign near entrance
    -- =============================================
    local collectorPart = Instance.new("Part")
    collectorPart.Name = "MoneyCollector"
    collectorPart.Size = Vector3.new(8, 1, 8)
    collectorPart.Position = Vector3.new(x - DOOR / 2 - 6, 0.6, z + halfS - 6)
    collectorPart.Anchored = true
    collectorPart.Material = Enum.Material.Neon
    collectorPart.Color = Color3.fromRGB(255, 215, 0)
    collectorPart.Shape = Enum.PartType.Cylinder
    collectorPart.Orientation = Vector3.new(0, 0, 90)
    collectorPart.Parent = plotModel

    local dollarPillar = Instance.new("Part")
    dollarPillar.Name = "DollarPillar"
    dollarPillar.Size = Vector3.new(3, 10, 3)
    dollarPillar.Position = Vector3.new(x - DOOR / 2 - 6, 6, z + halfS - 6)
    dollarPillar.Anchored = true
    dollarPillar.Material = Enum.Material.Neon
    dollarPillar.Color = Color3.fromRGB(255, 215, 0)
    dollarPillar.CanCollide = false
    dollarPillar.Transparency = 0.3
    dollarPillar.Parent = plotModel

    local dollarBillboard = Instance.new("BillboardGui")
    dollarBillboard.Name = "DollarSign"
    dollarBillboard.Size = UDim2.new(8, 0, 10, 0)
    dollarBillboard.StudsOffset = Vector3.new(0, 2, 0)
    dollarBillboard.AlwaysOnTop = true
    dollarBillboard.Parent = dollarPillar

    local dollarLabel = Instance.new("TextLabel")
    dollarLabel.Name = "DollarText"
    dollarLabel.Size = UDim2.new(1, 0, 0.6, 0)
    dollarLabel.BackgroundTransparency = 1
    dollarLabel.TextScaled = true
    dollarLabel.Font = Enum.Font.GothamBold
    dollarLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    dollarLabel.TextStrokeColor3 = Color3.fromRGB(100, 80, 0)
    dollarLabel.TextStrokeTransparency = 0
    dollarLabel.Text = "$"
    dollarLabel.Parent = dollarBillboard

    local pendingLabel = Instance.new("TextLabel")
    pendingLabel.Name = "PendingAmount"
    pendingLabel.Size = UDim2.new(1, 0, 0.35, 0)
    pendingLabel.Position = UDim2.new(0, 0, 0.6, 0)
    pendingLabel.BackgroundTransparency = 1
    pendingLabel.TextScaled = true
    pendingLabel.Font = Enum.Font.GothamBold
    pendingLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    pendingLabel.TextStrokeColor3 = Color3.fromRGB(0, 50, 0)
    pendingLabel.TextStrokeTransparency = 0
    pendingLabel.Text = "$0"
    pendingLabel.Parent = dollarBillboard

    local hintLabel = Instance.new("TextLabel")
    hintLabel.Name = "Hint"
    hintLabel.Size = UDim2.new(1, 0, 0.15, 0)
    hintLabel.Position = UDim2.new(0, 0, 0.88, 0)
    hintLabel.BackgroundTransparency = 1
    hintLabel.TextScaled = true
    hintLabel.Font = Enum.Font.Gotham
    hintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    hintLabel.TextStrokeTransparency = 0.3
    hintLabel.Text = "Stand here to collect!"
    hintLabel.Parent = dollarBillboard

    -- =============================================
    -- DECORATIVE BASEBOARDS along all walls
    -- =============================================
    for _, info in {
        {Vector3.new(S - T, 1, 0.5), Vector3.new(x, 0.5, z - halfS + T / 2 + 0.25)},
        {Vector3.new(0.5, 1, S), Vector3.new(x - halfS + T / 2 + 0.25, 0.5, z)},
        {Vector3.new(0.5, 1, S), Vector3.new(x + halfS - T / 2 - 0.25, 0.5, z)},
    } do
        local baseboard = Instance.new("Part")
        baseboard.Name = "Baseboard"
        baseboard.Size = info[1]
        baseboard.Position = info[2]
        baseboard.Anchored = true
        baseboard.Material = Enum.Material.Wood
        baseboard.Color = Color3.fromRGB(80, 50, 30)
        baseboard.Parent = plotModel
    end

    -- =============================================
    -- METADATA
    -- =============================================
    plotModel:SetAttribute("PlotIndex", plotIndex)
    plotModel:SetAttribute("CenterX", x)
    plotModel:SetAttribute("CenterZ", z)
    plotModel:SetAttribute("OwnerId", 0)
    plotModel:SetAttribute("PendingMoney", 0)

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

    -- Place buy buttons in a corridor along the left wall inside the restaurant
    local buttonSize = Vector3.new(5, 0.5, 5)
    local buttonsPerRow = 2  -- Two columns along the left wall
    local startX = centerX - Config.PlotSize / 2 + 6
    local startZ = centerZ + Config.PlotSize / 2 - 14 -- Start near entrance, go back

    for i, entry in allItems do
        local col = (i - 1) % buttonsPerRow
        local row = math.floor((i - 1) / buttonsPerRow)

        local pad = Instance.new("Part")
        pad.Name = "BuyPad_" .. entry.item.id
        pad.Size = buttonSize
        pad.Position = Vector3.new(
            startX + col * 7,
            0.75,
            startZ - row * 7
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

    -- Place tables in the dining area (center-right of the restaurant, in front of the kitchen counter)
    if item.category == "Table" then
        local tableIndex = 0
        for _, child in placedFolder:GetChildren() do
            if child:GetAttribute("Category") == "Table" then
                tableIndex += 1
            end
        end

        -- 4 columns x multiple rows, spread across the large dining area
        local diningLeft = centerX - Config.PlotSize * 0.15
        local diningTop = centerZ - Config.PlotSize * 0.15
        local col = tableIndex % 4
        local row = math.floor(tableIndex / 4)
        local tableX = diningLeft + col * 14
        local tableZ = diningTop + row * 14

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
        -- Place decorations along the right wall and back wall
        local decorIndex = 0
        for _, child in placedFolder:GetChildren() do
            if child:GetAttribute("Category") == "Decor" then
                decorIndex += 1
            end
        end

        -- Alternate between right wall and spaces between windows
        local halfS = Config.PlotSize / 2
        local decorX, decorZ
        if decorIndex % 2 == 0 then
            -- Along the right wall
            decorX = centerX + halfS - 4
            decorZ = centerZ - halfS + 10 + math.floor(decorIndex / 2) * 15
        else
            -- Along the back wall (inside kitchen area as decor)
            decorX = centerX - halfS + 10 + math.floor(decorIndex / 2) * 15
            decorZ = centerZ - halfS + 4
        end

        local decorPart = Instance.new("Part")
        decorPart.Name = "Decor_" .. itemId .. "_" .. decorIndex
        decorPart.Size = Vector3.new(2, 4, 2)
        decorPart.Position = Vector3.new(decorX, 2.5, decorZ)
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

-- === MALL ENVIRONMENT ===
-- Build a shopping mall around the restaurant plots

local function buildMallEnvironment()
    local mallFolder = Instance.new("Folder")
    mallFolder.Name = "MallEnvironment"
    mallFolder.Parent = workspace

    -- Calculate mall bounds based on plot grid
    -- Plots are in a 4x2 grid, each PlotSize with PlotSpacing gaps
    local totalWidth = 4 * Config.PlotSize + 3 * Config.PlotSpacing
    local totalDepth = 2 * Config.PlotSize + 1 * Config.PlotSpacing
    local mallCenterX = (totalWidth - Config.PlotSize - Config.PlotSpacing) / 2
    local mallCenterZ = (totalDepth - Config.PlotSize - Config.PlotSpacing) / 2
    local mallPadding = 50 -- Extra space around restaurant rooms for hallways
    local mallW = totalWidth + mallPadding * 2
    local mallD = totalDepth + mallPadding * 2
    local wallHeight = 25
    local mallLeft = mallCenterX - mallW / 2
    local mallRight = mallCenterX + mallW / 2
    local mallFront = mallCenterZ + mallD / 2
    local mallBack = mallCenterZ - mallD / 2

    -- Main mall floor (polished tile look)
    local mainFloor = Instance.new("Part")
    mainFloor.Name = "MallFloor"
    mainFloor.Size = Vector3.new(mallW, 0.5, mallD)
    mainFloor.Position = Vector3.new(mallCenterX, -0.75, mallCenterZ)
    mainFloor.Anchored = true
    mainFloor.Material = Enum.Material.Marble
    mainFloor.Color = Color3.fromRGB(230, 225, 215)
    mainFloor.Parent = mallFolder

    -- Decorative floor stripe down the center walkway
    local centerStripe = Instance.new("Part")
    centerStripe.Name = "CenterStripe"
    centerStripe.Size = Vector3.new(6, 0.52, mallD - 10)
    centerStripe.Position = Vector3.new(mallCenterX, -0.74, mallCenterZ)
    centerStripe.Anchored = true
    centerStripe.Material = Enum.Material.Marble
    centerStripe.Color = Color3.fromRGB(180, 140, 90)
    centerStripe.Parent = mallFolder

    -- Cross stripe
    local crossStripe = Instance.new("Part")
    crossStripe.Name = "CrossStripe"
    crossStripe.Size = Vector3.new(mallW - 10, 0.52, 6)
    crossStripe.Position = Vector3.new(mallCenterX, -0.74, mallCenterZ)
    crossStripe.Anchored = true
    crossStripe.Material = Enum.Material.Marble
    crossStripe.Color = Color3.fromRGB(180, 140, 90)
    crossStripe.Parent = mallFolder

    -- === WALLS ===
    local wallColor = Color3.fromRGB(235, 230, 220)
    local accentColor = Color3.fromRGB(160, 130, 80)

    -- Back wall
    local backWall = Instance.new("Part")
    backWall.Name = "BackWall"
    backWall.Size = Vector3.new(mallW, wallHeight, 2)
    backWall.Position = Vector3.new(mallCenterX, wallHeight / 2, mallBack)
    backWall.Anchored = true
    backWall.Material = Enum.Material.SmoothPlastic
    backWall.Color = wallColor
    backWall.Parent = mallFolder

    -- Front wall (with gap for mall entrance)
    local frontWallLeft = Instance.new("Part")
    frontWallLeft.Name = "FrontWallLeft"
    frontWallLeft.Size = Vector3.new(mallW / 2 - 15, wallHeight, 2)
    frontWallLeft.Position = Vector3.new(mallCenterX - mallW / 4 - 7.5, wallHeight / 2, mallFront)
    frontWallLeft.Anchored = true
    frontWallLeft.Material = Enum.Material.SmoothPlastic
    frontWallLeft.Color = wallColor
    frontWallLeft.Parent = mallFolder

    local frontWallRight = Instance.new("Part")
    frontWallRight.Name = "FrontWallRight"
    frontWallRight.Size = Vector3.new(mallW / 2 - 15, wallHeight, 2)
    frontWallRight.Position = Vector3.new(mallCenterX + mallW / 4 + 7.5, wallHeight / 2, mallFront)
    frontWallRight.Anchored = true
    frontWallRight.Material = Enum.Material.SmoothPlastic
    frontWallRight.Color = wallColor
    frontWallRight.Parent = mallFolder

    -- Entrance arch above the gap
    local entranceArch = Instance.new("Part")
    entranceArch.Name = "EntranceArch"
    entranceArch.Size = Vector3.new(30, 4, 3)
    entranceArch.Position = Vector3.new(mallCenterX, wallHeight - 2, mallFront)
    entranceArch.Anchored = true
    entranceArch.Material = Enum.Material.SmoothPlastic
    entranceArch.Color = accentColor
    entranceArch.Parent = mallFolder

    -- Left wall
    local leftWall = Instance.new("Part")
    leftWall.Name = "LeftWall"
    leftWall.Size = Vector3.new(2, wallHeight, mallD)
    leftWall.Position = Vector3.new(mallLeft, wallHeight / 2, mallCenterZ)
    leftWall.Anchored = true
    leftWall.Material = Enum.Material.SmoothPlastic
    leftWall.Color = wallColor
    leftWall.Parent = mallFolder

    -- Right wall
    local rightWall = Instance.new("Part")
    rightWall.Name = "RightWall"
    rightWall.Size = Vector3.new(2, wallHeight, mallD)
    rightWall.Position = Vector3.new(mallRight, wallHeight / 2, mallCenterZ)
    rightWall.Anchored = true
    rightWall.Material = Enum.Material.SmoothPlastic
    rightWall.Color = wallColor
    rightWall.Parent = mallFolder

    -- === CEILING with skylights ===
    local ceilingHeight = wallHeight

    -- Solid ceiling sections (4 panels with gaps for skylights)
    for i = 0, 3 do
        local panelW = mallW / 4 - 5
        local ceiling = Instance.new("Part")
        ceiling.Name = "Ceiling_" .. i
        ceiling.Size = Vector3.new(panelW, 1, mallD - 10)
        ceiling.Position = Vector3.new(mallLeft + panelW / 2 + i * (mallW / 4) + 2.5, ceilingHeight, mallCenterZ)
        ceiling.Anchored = true
        ceiling.Material = Enum.Material.SmoothPlastic
        ceiling.Color = Color3.fromRGB(240, 238, 230)
        ceiling.Parent = mallFolder
    end

    -- Skylight strips (glass between ceiling panels)
    for i = 0, 2 do
        local skylight = Instance.new("Part")
        skylight.Name = "Skylight_" .. i
        skylight.Size = Vector3.new(5, 0.5, mallD - 10)
        skylight.Position = Vector3.new(mallLeft + (i + 1) * (mallW / 4), ceilingHeight + 0.25, mallCenterZ)
        skylight.Anchored = true
        skylight.Material = Enum.Material.Glass
        skylight.Color = Color3.fromRGB(200, 230, 255)
        skylight.Transparency = 0.5
        skylight.Parent = mallFolder
    end

    -- === STOREFRONT FACADES on back wall ===
    local storefrontNames = {"Electronics", "Fashion", "Books", "Toys", "Jewelry", "Sports"}
    local storefrontColors = {
        Color3.fromRGB(50, 100, 200),
        Color3.fromRGB(200, 50, 100),
        Color3.fromRGB(80, 150, 80),
        Color3.fromRGB(200, 150, 50),
        Color3.fromRGB(150, 50, 200),
        Color3.fromRGB(200, 100, 50),
    }

    for i, storeName in storefrontNames do
        local storeWidth = 25
        local storeX = mallLeft + 15 + (i - 1) * (storeWidth + 5)
        if storeX + storeWidth > mallRight - 10 then break end

        -- Storefront sign
        local signPart = Instance.new("Part")
        signPart.Name = "Storefront_" .. storeName
        signPart.Size = Vector3.new(storeWidth, 4, 1)
        signPart.Position = Vector3.new(storeX + storeWidth / 2, wallHeight - 5, mallBack + 2)
        signPart.Anchored = true
        signPart.Material = Enum.Material.Neon
        signPart.Color = storefrontColors[i]
        signPart.Parent = mallFolder

        local signGui = Instance.new("SurfaceGui")
        signGui.Face = Enum.NormalId.Front
        signGui.CanvasSize = Vector2.new(400, 80)
        signGui.Parent = signPart

        local signText = Instance.new("TextLabel")
        signText.Size = UDim2.new(1, 0, 1, 0)
        signText.BackgroundTransparency = 1
        signText.TextScaled = true
        signText.Font = Enum.Font.GothamBold
        signText.TextColor3 = Color3.fromRGB(255, 255, 255)
        signText.Text = storeName
        signText.Parent = signGui

        -- Window display
        local windowPart = Instance.new("Part")
        windowPart.Name = "Window_" .. storeName
        windowPart.Size = Vector3.new(storeWidth - 2, 8, 0.5)
        windowPart.Position = Vector3.new(storeX + storeWidth / 2, 5, mallBack + 1.5)
        windowPart.Anchored = true
        windowPart.Material = Enum.Material.Glass
        windowPart.Color = storefrontColors[i]
        windowPart.Transparency = 0.7
        windowPart.Parent = mallFolder
    end

    -- === CENTRAL FOUNTAIN ===
    local fountainX = mallCenterX
    local fountainZ = mallCenterZ

    -- Fountain base (circular pool)
    local fountainBase = Instance.new("Part")
    fountainBase.Name = "FountainBase"
    fountainBase.Shape = Enum.PartType.Cylinder
    fountainBase.Size = Vector3.new(2, 16, 16)
    fountainBase.Position = Vector3.new(fountainX, 0.5, fountainZ)
    fountainBase.Orientation = Vector3.new(0, 0, 90)
    fountainBase.Anchored = true
    fountainBase.Material = Enum.Material.Marble
    fountainBase.Color = Color3.fromRGB(200, 195, 185)
    fountainBase.Parent = mallFolder

    -- Water
    local water = Instance.new("Part")
    water.Name = "FountainWater"
    water.Shape = Enum.PartType.Cylinder
    water.Size = Vector3.new(1, 14, 14)
    water.Position = Vector3.new(fountainX, 1, fountainZ)
    water.Orientation = Vector3.new(0, 0, 90)
    water.Anchored = true
    water.Material = Enum.Material.Glass
    water.Color = Color3.fromRGB(100, 170, 230)
    water.Transparency = 0.3
    water.Parent = mallFolder

    -- Fountain center pillar
    local fountainPillar = Instance.new("Part")
    fountainPillar.Name = "FountainPillar"
    fountainPillar.Shape = Enum.PartType.Cylinder
    fountainPillar.Size = Vector3.new(6, 3, 3)
    fountainPillar.Position = Vector3.new(fountainX, 3.5, fountainZ)
    fountainPillar.Orientation = Vector3.new(0, 0, 90)
    fountainPillar.Anchored = true
    fountainPillar.Material = Enum.Material.Marble
    fountainPillar.Color = Color3.fromRGB(220, 215, 205)
    fountainPillar.Parent = mallFolder

    -- Fountain top spout
    local spout = Instance.new("Part")
    spout.Name = "FountainSpout"
    spout.Shape = Enum.PartType.Ball
    spout.Size = Vector3.new(2, 2, 2)
    spout.Position = Vector3.new(fountainX, 7, fountainZ)
    spout.Anchored = true
    spout.Material = Enum.Material.Neon
    spout.Color = Color3.fromRGB(150, 200, 255)
    spout.Parent = mallFolder

    -- === BENCHES along walkways ===
    local benchPositions = {
        {mallCenterX - 20, mallCenterZ + 15},
        {mallCenterX + 20, mallCenterZ + 15},
        {mallCenterX - 20, mallCenterZ - 15},
        {mallCenterX + 20, mallCenterZ - 15},
    }

    for i, pos in benchPositions do
        local benchSeat = Instance.new("Part")
        benchSeat.Name = "Bench_" .. i
        benchSeat.Size = Vector3.new(6, 1.5, 2)
        benchSeat.Position = Vector3.new(pos[1], 0.75, pos[2])
        benchSeat.Anchored = true
        benchSeat.Material = Enum.Material.Wood
        benchSeat.Color = Color3.fromRGB(120, 80, 40)
        benchSeat.Parent = mallFolder

        -- Bench backrest
        local backrest = Instance.new("Part")
        backrest.Name = "BenchBack_" .. i
        backrest.Size = Vector3.new(6, 1.5, 0.5)
        backrest.Position = Vector3.new(pos[1], 2, pos[2] - 0.75)
        backrest.Anchored = true
        backrest.Material = Enum.Material.Wood
        backrest.Color = Color3.fromRGB(120, 80, 40)
        backrest.Parent = mallFolder

        -- Metal bench legs
        for _, legOffset in {{-2.5, 0.75}, {2.5, 0.75}} do
            local leg = Instance.new("Part")
            leg.Name = "BenchLeg"
            leg.Size = Vector3.new(0.3, 1.5, 1.5)
            leg.Position = Vector3.new(pos[1] + legOffset[1], legOffset[2], pos[2])
            leg.Anchored = true
            leg.Material = Enum.Material.Metal
            leg.Color = Color3.fromRGB(80, 80, 80)
            leg.Parent = mallFolder
        end
    end

    -- === PLANTERS with trees ===
    local planterPositions = {
        {mallCenterX - 40, mallCenterZ},
        {mallCenterX + 40, mallCenterZ},
        {mallCenterX, mallCenterZ + 25},
        {mallCenterX, mallCenterZ - 25},
    }

    for i, pos in planterPositions do
        -- Planter box
        local planter = Instance.new("Part")
        planter.Name = "Planter_" .. i
        planter.Size = Vector3.new(5, 2, 5)
        planter.Position = Vector3.new(pos[1], 1, pos[2])
        planter.Anchored = true
        planter.Material = Enum.Material.Concrete
        planter.Color = Color3.fromRGB(160, 150, 140)
        planter.Parent = mallFolder

        -- Soil
        local soil = Instance.new("Part")
        soil.Name = "Soil_" .. i
        soil.Size = Vector3.new(4.5, 0.5, 4.5)
        soil.Position = Vector3.new(pos[1], 2.25, pos[2])
        soil.Anchored = true
        soil.Material = Enum.Material.Ground
        soil.Color = Color3.fromRGB(80, 60, 40)
        soil.Parent = mallFolder

        -- Tree trunk
        local trunk = Instance.new("Part")
        trunk.Name = "Trunk_" .. i
        trunk.Shape = Enum.PartType.Cylinder
        trunk.Size = Vector3.new(8, 1.5, 1.5)
        trunk.Position = Vector3.new(pos[1], 6.5, pos[2])
        trunk.Orientation = Vector3.new(0, 0, 90)
        trunk.Anchored = true
        trunk.Material = Enum.Material.Wood
        trunk.Color = Color3.fromRGB(100, 70, 40)
        trunk.Parent = mallFolder

        -- Tree canopy
        local canopy = Instance.new("Part")
        canopy.Name = "Canopy_" .. i
        canopy.Shape = Enum.PartType.Ball
        canopy.Size = Vector3.new(8, 6, 8)
        canopy.Position = Vector3.new(pos[1], 12, pos[2])
        canopy.Anchored = true
        canopy.Material = Enum.Material.Grass
        canopy.Color = Color3.fromRGB(60, 140, 50)
        canopy.CanCollide = false
        canopy.Parent = mallFolder
    end

    -- === LAMPPOSTS ===
    local lampPositions = {
        {mallLeft + 8, mallCenterZ - 20},
        {mallLeft + 8, mallCenterZ + 20},
        {mallRight - 8, mallCenterZ - 20},
        {mallRight - 8, mallCenterZ + 20},
    }

    for i, pos in lampPositions do
        local pole = Instance.new("Part")
        pole.Name = "LampPole_" .. i
        pole.Size = Vector3.new(0.5, 12, 0.5)
        pole.Position = Vector3.new(pos[1], 6, pos[2])
        pole.Anchored = true
        pole.Material = Enum.Material.Metal
        pole.Color = Color3.fromRGB(60, 60, 60)
        pole.Parent = mallFolder

        local lampHead = Instance.new("Part")
        lampHead.Name = "LampHead_" .. i
        lampHead.Shape = Enum.PartType.Ball
        lampHead.Size = Vector3.new(3, 3, 3)
        lampHead.Position = Vector3.new(pos[1], 13, pos[2])
        lampHead.Anchored = true
        lampHead.Material = Enum.Material.Neon
        lampHead.Color = Color3.fromRGB(255, 240, 200)
        lampHead.Parent = mallFolder

        -- Point light
        local light = Instance.new("PointLight")
        light.Brightness = 1
        light.Range = 30
        light.Color = Color3.fromRGB(255, 240, 200)
        light.Parent = lampHead
    end

    -- === MALL ENTRANCE SIGN ===
    local entranceSign = Instance.new("Part")
    entranceSign.Name = "MallSign"
    entranceSign.Size = Vector3.new(24, 5, 1)
    entranceSign.Position = Vector3.new(mallCenterX, wallHeight + 2, mallFront + 2)
    entranceSign.Anchored = true
    entranceSign.Material = Enum.Material.SmoothPlastic
    entranceSign.Color = Color3.fromRGB(40, 40, 50)
    entranceSign.Parent = mallFolder

    local mallSignGui = Instance.new("SurfaceGui")
    mallSignGui.Face = Enum.NormalId.Front
    mallSignGui.CanvasSize = Vector2.new(600, 120)
    mallSignGui.Parent = entranceSign

    local mallTitle = Instance.new("TextLabel")
    mallTitle.Size = UDim2.new(1, 0, 1, 0)
    mallTitle.BackgroundTransparency = 1
    mallTitle.TextScaled = true
    mallTitle.Font = Enum.Font.GothamBold
    mallTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
    mallTitle.TextStrokeColor3 = Color3.fromRGB(100, 80, 0)
    mallTitle.TextStrokeTransparency = 0
    mallTitle.Text = "FOOD COURT"
    mallTitle.Parent = mallSignGui

    -- === FLOOR DIRECTORY SIGNS ===
    local dirSign = Instance.new("Part")
    dirSign.Name = "DirectorySign"
    dirSign.Size = Vector3.new(8, 12, 1)
    dirSign.Position = Vector3.new(mallCenterX, 6, mallFront - 8)
    dirSign.Anchored = true
    dirSign.Material = Enum.Material.SmoothPlastic
    dirSign.Color = Color3.fromRGB(30, 30, 40)
    dirSign.Parent = mallFolder

    local dirGui = Instance.new("SurfaceGui")
    dirGui.Face = Enum.NormalId.Back
    dirGui.CanvasSize = Vector2.new(300, 500)
    dirGui.Parent = dirSign

    local dirTitle = Instance.new("TextLabel")
    dirTitle.Size = UDim2.new(1, 0, 0.15, 0)
    dirTitle.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    dirTitle.TextScaled = true
    dirTitle.Font = Enum.Font.GothamBold
    dirTitle.TextColor3 = Color3.fromRGB(30, 30, 30)
    dirTitle.Text = "DIRECTORY"
    dirTitle.Parent = dirGui

    local dirBody = Instance.new("TextLabel")
    dirBody.Size = UDim2.new(1, 0, 0.85, 0)
    dirBody.Position = UDim2.new(0, 0, 0.15, 0)
    dirBody.BackgroundTransparency = 1
    dirBody.TextScaled = true
    dirBody.Font = Enum.Font.Gotham
    dirBody.TextColor3 = Color3.fromRGB(220, 220, 220)
    dirBody.TextYAlignment = Enum.TextYAlignment.Top
    dirBody.Text = "\nFood Court Restaurants\n\nBuy a plot to start!\nServe customers\nEarn money\nUpgrade your restaurant\n\nPress E for Shop"
    dirBody.Parent = dirGui

    -- === AMBIENT LIGHTING ===
    local lighting = game:GetService("Lighting")
    lighting.Ambient = Color3.fromRGB(120, 115, 105)
    lighting.Brightness = 1.5
    lighting.ClockTime = 14 -- Afternoon light
    lighting.FogEnd = 1000
    lighting.OutdoorAmbient = Color3.fromRGB(150, 145, 135)

    print("[GameManager] Mall environment built")
end

buildMallEnvironment()

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
                    local gui = sign:FindFirstChildOfClass("SurfaceGui") or sign:FindFirstChildOfClass("BillboardGui")
                    if gui then
                        local nameLabel = gui:FindFirstChild("OwnerName")
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
        -- Check for SurfaceGui (new room style) or BillboardGui (legacy)
        local gui = sign:FindFirstChildOfClass("SurfaceGui") or sign:FindFirstChildOfClass("BillboardGui")
        if gui then
            local starLabel = gui:FindFirstChild("StarRating")
            if starLabel then
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

-- === MONEY COLLECTOR LOGIC ===

-- Update the pending money display on a plot's collector
local function updatePendingMoneyDisplay(plotModel: Model)
    local pending = plotModel:GetAttribute("PendingMoney") or 0
    local pillar = plotModel:FindFirstChild("DollarPillar")
    if pillar then
        local billboard = pillar:FindFirstChild("DollarSign")
        if billboard then
            local pendingLabel = billboard:FindFirstChild("PendingAmount")
            if pendingLabel then
                pendingLabel.Text = Utils.FormatMoney(pending)
            end
        end
    end
end

-- Listen for PendingMoney attribute changes to update display
for _, plotModel in plotsFolder:GetChildren() do
    plotModel:GetAttributeChangedSignal("PendingMoney"):Connect(function()
        updatePendingMoneyDisplay(plotModel)
    end)
end

-- Flashing animation for all money collectors
task.spawn(function()
    local flashOn = true
    while true do
        flashOn = not flashOn
        for _, plotModel in plotsFolder:GetChildren() do
            local pending = plotModel:GetAttribute("PendingMoney") or 0
            local pillar = plotModel:FindFirstChild("DollarPillar")
            local collector = plotModel:FindFirstChild("MoneyCollector")
            if pillar and collector then
                if pending > 0 then
                    -- Flash bright when there's money to collect
                    local color = flashOn
                        and Color3.fromRGB(255, 255, 50)
                        or Color3.fromRGB(255, 180, 0)
                    pillar.Color = color
                    collector.Color = color
                    pillar.Transparency = flashOn and 0.1 or 0.4
                else
                    -- Dim when nothing to collect
                    pillar.Color = Color3.fromRGB(150, 130, 50)
                    collector.Color = Color3.fromRGB(150, 130, 50)
                    pillar.Transparency = 0.6
                end
            end
        end
        task.wait(0.5)
    end
end)

-- Collection via touching the collector pad
for _, plotModel in plotsFolder:GetChildren() do
    local collector = plotModel:FindFirstChild("MoneyCollector")
    if collector then
        local collecting = {} -- debounce per player
        collector.Touched:Connect(function(hit)
            local character = hit.Parent
            if not character then return end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end

            local player = Players:GetPlayerFromCharacter(character)
            if not player then return end

            -- Only the plot owner can collect
            if plotModel:GetAttribute("OwnerId") ~= player.UserId then return end

            -- Debounce: don't spam collections
            if collecting[player.UserId] then return end
            collecting[player.UserId] = true

            local pending = plotModel:GetAttribute("PendingMoney") or 0
            if pending > 0 then
                -- Transfer pending money to the player
                addMoney(player, pending)
                plotModel:SetAttribute("PendingMoney", 0)

                -- Notify client with updated money
                local data = getPlayerData(player.UserId)
                if data then
                    local statsEvent = ReplicatedStorage:FindFirstChild("StatsChanged")
                    if statsEvent then
                        statsEvent:FireClient(player, "money", data.money, data.level)
                    end
                end

                print("[GameManager]", player.Name, "collected", Utils.FormatMoney(pending))
            end

            task.delay(0.5, function()
                collecting[player.UserId] = nil
            end)
        end)
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
            local gui = sign:FindFirstChildOfClass("SurfaceGui") or sign:FindFirstChildOfClass("BillboardGui")
            if gui then
                local nameLabel = gui:FindFirstChild("OwnerName")
                if nameLabel then nameLabel.Text = "Available" end
                local starLabel = gui:FindFirstChild("StarRating")
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
