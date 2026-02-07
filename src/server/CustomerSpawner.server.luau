-- CustomerSpawner.server.luau
-- Spawns NPC customers that walk into restaurants, sit at tables, eat, pay, and leave.
-- Customer spawn rate and payment scale with the restaurant's star rating.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local Config = require(ReplicatedStorage.Shared.Config)
local Utils = require(ReplicatedStorage.Shared.Utils)

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

-- NPC appearance options for variety
local SHIRT_COLORS = {
    Color3.fromRGB(255, 100, 100),
    Color3.fromRGB(100, 100, 255),
    Color3.fromRGB(100, 255, 100),
    Color3.fromRGB(255, 255, 100),
    Color3.fromRGB(255, 150, 50),
    Color3.fromRGB(200, 100, 255),
    Color3.fromRGB(100, 200, 200),
    Color3.fromRGB(255, 180, 180),
}

local SKIN_COLORS = {
    Color3.fromRGB(255, 204, 153),
    Color3.fromRGB(210, 160, 110),
    Color3.fromRGB(165, 113, 78),
    Color3.fromRGB(120, 80, 50),
    Color3.fromRGB(240, 200, 170),
}

-- Create a simple NPC character model
local function createCustomerModel(): Model
    local model = Instance.new("Model")
    model.Name = "Customer"

    -- Torso
    local torso = Instance.new("Part")
    torso.Name = "HumanoidRootPart"
    torso.Size = Vector3.new(2, 2, 1)
    torso.Color = SHIRT_COLORS[math.random(#SHIRT_COLORS)]
    torso.Anchored = false
    torso.CanCollide = false
    torso.Parent = model

    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(1.2, 1.2, 1.2)
    head.Color = SKIN_COLORS[math.random(#SKIN_COLORS)]
    head.Anchored = false
    head.CanCollide = false
    head.Parent = model

    local headWeld = Instance.new("WeldConstraint")
    headWeld.Part0 = torso
    headWeld.Part1 = head
    headWeld.Parent = head
    head.CFrame = torso.CFrame * CFrame.new(0, 1.5, 0)

    -- Legs
    local leftLeg = Instance.new("Part")
    leftLeg.Name = "LeftLeg"
    leftLeg.Size = Vector3.new(0.8, 1.5, 0.8)
    leftLeg.Color = Color3.fromRGB(50, 50, 150)
    leftLeg.Anchored = false
    leftLeg.CanCollide = false
    leftLeg.Parent = model

    local leftLegWeld = Instance.new("WeldConstraint")
    leftLegWeld.Part0 = torso
    leftLegWeld.Part1 = leftLeg
    leftLegWeld.Parent = leftLeg
    leftLeg.CFrame = torso.CFrame * CFrame.new(-0.5, -1.75, 0)

    local rightLeg = Instance.new("Part")
    rightLeg.Name = "RightLeg"
    rightLeg.Size = Vector3.new(0.8, 1.5, 0.8)
    rightLeg.Color = Color3.fromRGB(50, 50, 150)
    rightLeg.Anchored = false
    rightLeg.CanCollide = false
    rightLeg.Parent = model

    local rightLegWeld = Instance.new("WeldConstraint")
    rightLegWeld.Part0 = torso
    rightLegWeld.Part1 = rightLeg
    rightLegWeld.Parent = rightLeg
    rightLeg.CFrame = torso.CFrame * CFrame.new(0.5, -1.75, 0)

    -- Humanoid (for pathfinding and animation)
    local humanoid = Instance.new("Humanoid")
    humanoid.WalkSpeed = Config.CustomerWalkSpeed
    humanoid.Parent = model

    model.PrimaryPart = torso

    return model
end

-- Find an available (unoccupied) table in a plot's placed items
local function findAvailableTable(plotModel: Model): Part?
    local placedItems = plotModel:FindFirstChild("PlacedItems")
    if not placedItems then return nil end

    for _, item in placedItems:GetChildren() do
        if item:GetAttribute("Category") == "Table" and not item:GetAttribute("Occupied") then
            return item
        end
    end
    return nil
end

-- Find a seat near a table
local function findSeatForTable(plotModel: Model, tablePart: Part): Part?
    local placedItems = plotModel:FindFirstChild("PlacedItems")
    if not placedItems then return nil end

    for _, item in placedItems:GetChildren() do
        if item:IsA("Seat") and item:GetAttribute("TableName") == tablePart.Name then
            return item
        end
    end
    return nil
end

-- Spawn and run one customer's lifecycle on a plot
local function spawnCustomer(plotModel: Model)
    local ownerId = plotModel:GetAttribute("OwnerId")
    if ownerId == 0 then return end

    local player = Players:GetPlayerByUserId(ownerId)
    if not player then return end

    local data = getPlayerData(ownerId)
    if not data then return end

    -- Find an available table
    local tablePart = findAvailableTable(plotModel)
    if not tablePart then return end -- No free tables, skip this spawn

    -- Mark table as occupied
    tablePart:SetAttribute("Occupied", true)

    -- Create NPC
    local customer = createCustomerModel()
    customer.Name = "Customer_" .. math.random(10000)

    -- Spawn at entrance
    local entrance = plotModel:FindFirstChild("Entrance")
    if not entrance then
        tablePart:SetAttribute("Occupied", false)
        return
    end

    local customersFolder = workspace:FindFirstChild("Customers")
    if not customersFolder then
        customersFolder = Instance.new("Folder")
        customersFolder.Name = "Customers"
        customersFolder.Parent = workspace
    end

    customer.Parent = customersFolder
    local hrp = customer.PrimaryPart
    if not hrp then
        customer:Destroy()
        tablePart:SetAttribute("Occupied", false)
        return
    end

    hrp.CFrame = entrance.CFrame + Vector3.new(0, 2, 3)
    hrp.Anchored = true

    -- Emoji indicator above head
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(2, 0, 2, 0)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = hrp

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, 0, 1, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.TextStrokeTransparency = 0.3
    statusLabel.Text = "🚶"
    statusLabel.Parent = billboardGui

    -- Phase 1: Walk to the table (simple lerp since NPCs are anchored)
    local seatPart = findSeatForTable(plotModel, tablePart)
    local targetPos = seatPart and seatPart.Position or tablePart.Position + Vector3.new(3, 0, 0)

    local startPos = hrp.Position
    local distance = (targetPos - startPos).Magnitude
    local walkTime = distance / Config.CustomerWalkSpeed
    local steps = math.max(1, math.floor(walkTime * 10)) -- 10 updates per second

    for step = 1, steps do
        if not customer.Parent then
            tablePart:SetAttribute("Occupied", false)
            return
        end
        local alpha = step / steps
        local newPos = startPos:Lerp(targetPos, alpha)
        hrp.CFrame = CFrame.new(newPos) * CFrame.Angles(0, math.atan2(targetPos.X - startPos.X, targetPos.Z - startPos.Z), 0)
        task.wait(0.1)
    end

    -- Phase 2: Sit and eat
    statusLabel.Text = "🍽️"
    hrp.CFrame = CFrame.new(targetPos)
    task.wait(Config.CustomerEatTime)

    -- Phase 3: Pay and award money/XP
    if not customer.Parent then
        tablePart:SetAttribute("Occupied", false)
        return
    end

    -- Check player is still in game
    if not player.Parent then
        tablePart:SetAttribute("Occupied", false)
        customer:Destroy()
        return
    end

    local starRating = plotModel:GetAttribute("StarRating") or 1
    local ownedMenuItems = {}
    for _, itemId in data.ownedItems do
        local item = require(ReplicatedStorage.Shared.ItemData).GetItem(itemId)
        if item and item.paymentBonus then
            table.insert(ownedMenuItems, itemId)
        end
    end

    local payment = Utils.CalculatePayment(ownedMenuItems, starRating, data.rebirths or 0)

    -- Add payment to the plot's pending money (player collects at the $ sign)
    local currentPending = plotModel:GetAttribute("PendingMoney") or 0
    plotModel:SetAttribute("PendingMoney", currentPending + payment)

    -- XP is still awarded immediately
    addXP(player, Config.XPPerCustomerServed)

    statusLabel.Text = "💰 " .. Utils.FormatMoney(payment)
    statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)

    task.wait(1.5)

    -- Phase 4: Walk out
    statusLabel.Text = "😊"
    local exitPos = entrance.Position + Vector3.new(0, 2, 5)
    local leaveSteps = math.max(1, math.floor((hrp.Position - exitPos).Magnitude / Config.CustomerWalkSpeed * 10))

    local currentPos = hrp.Position
    for step = 1, leaveSteps do
        if not customer.Parent then break end
        local alpha = step / leaveSteps
        hrp.CFrame = CFrame.new(currentPos:Lerp(exitPos, alpha))
        task.wait(0.1)
    end

    -- Clean up
    tablePart:SetAttribute("Occupied", false)
    if customer.Parent then
        customer:Destroy()
    end
end

-- === MAIN SPAWN LOOP ===
-- For each claimed plot, periodically spawn customers based on star rating

task.spawn(function()
    -- Wait for plots to be created
    task.wait(3)

    while true do
        local plotsFolder = workspace:FindFirstChild("Plots")
        if plotsFolder then
            for _, plotModel in plotsFolder:GetChildren() do
                local ownerId = plotModel:GetAttribute("OwnerId")
                if ownerId and ownerId ~= 0 then
                    -- Check if there's an available table before spawning
                    local hasTable = findAvailableTable(plotModel) ~= nil
                    if hasTable then
                        -- Spawn customer in a separate thread so multiple plots run in parallel
                        task.spawn(spawnCustomer, plotModel)
                    end
                end
            end
        end

        -- Calculate spawn interval based on lowest star rating (so better restaurants get more customers)
        local spawnInterval = Config.BaseSpawnInterval
        local plotsFolder2 = workspace:FindFirstChild("Plots")
        if plotsFolder2 then
            for _, plotModel in plotsFolder2:GetChildren() do
                local stars = plotModel:GetAttribute("StarRating") or 0
                local plotInterval = math.max(
                    Config.MinSpawnInterval,
                    Config.BaseSpawnInterval - stars * Config.SpawnIntervalReduction
                )
                spawnInterval = math.min(spawnInterval, plotInterval)
            end
        end

        task.wait(spawnInterval)
    end
end)

print("[CustomerSpawner] Customer AI system initialized")
