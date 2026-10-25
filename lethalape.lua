--[[ Lethal Ape - Auto Collect & Sell (Corrigido)
     Requer: Delta Executor (Android) ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer

-- ========== ESTADO ==========
local farming = false
local visited = {}
local collectedCount = 0
local loopId = 0 -- Controle de loop para não bugar ao religar

-- ========== UTIL ==========
local function getHRP()
    local char = lp.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

-- ========== LÓGICA DE DIAMANTE ==========
local function findDiamonds()
    local list = {}
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "Diamond" and obj:IsA("BasePart") then
            local prompt = obj:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                table.insert(list, {part = obj, prompt = prompt})
            end
        end
    end
    return list
end

local function collectOne(entry)
    local hrp = getHRP()
    if not hrp or not entry.part.Parent or not entry.prompt.Parent then return false end
    
    hrp.CFrame = CFrame.new(entry.part.Position + Vector3.new(0, 3, 0))
    task.wait(0.1)
    
    pcall(function()
        entry.prompt:InputHoldBegin()
        task.wait(entry.prompt.HoldDuration + 0.05)
        entry.prompt:InputHoldEnd()
    end)
    task.wait(0.05)
    return true
end

-- ========== LÓGICA DE VENDA ==========
local function findScrapRecycler()
    local recycler = workspace:FindFirstChild("ScrapRecycler")
    if not recycler then return nil end
    for _, obj in ipairs(recycler:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parentPart = obj.Parent
            if parentPart and parentPart:IsA("BasePart") then
                return {part = parentPart, prompt = obj}
            end
        end
    end
    return nil
end

local function sellAll()
    local s = findScrapRecycler()
    if not s then return false end
    local hrp = getHRP()
    if not hrp then return false end
    
    local returnPos = hrp.CFrame
    hrp.CFrame = CFrame.new(s.part.Position + Vector3.new(0, 3, 0))
    task.wait(0.15)
    
    pcall(function()
        s.prompt:InputHoldBegin()
        task.wait(s.prompt.HoldDuration + 0.05)
        s.prompt:InputHoldEnd()
    end)
    task.wait(0.2)
    
    hrp.CFrame = returnPos
    return true
end

-- ========== LOOP PRINCIPAL CORRIGIDO ==========
local function runFarm(currentId)
    while farming and loopId == currentId do
        local diamonds = findDiamonds()
        local didAny = false
        
        for _, entry in ipairs(diamonds) do
            if not farming or loopId ~= currentId then break end
            
            -- Se o diamante ainda existe e não foi visitado
            if not visited[entry.part] and entry.part.Parent then
                visited[entry.part] = true
                if collectOne(entry) then
                    collectedCount += 1
                    didAny = true
                end
            end
        end
        
        -- Limpa diamantes que sumiram do mapa
        for k in pairs(visited) do
            if not k.Parent then visited[k] = nil end
        end
        
        if farming and loopId == currentId then
            task.wait(didAny and 0.1 or 1.5)
        end
    end
end

-- ========== UI MOBILE ==========
local gui = Instance.new("ScreenGui")
gui.Name = "LethalApeUI"
gui.ResetOnSpawn = false
gui.Parent = lp:WaitForChild("PlayerGui")

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.fromOffset(56, 56)
toggle.Position = UDim2.new(0, 20, 0.5, -28)
toggle.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
toggle.TextColor3 = Color3.fromRGB(120, 200, 255)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 22
toggle.Text = "◆"
toggle.BorderSizePixel = 0
toggle.Parent = gui
Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(260, 360)
panel.Position = UDim2.new(0.5, -130, 0.5, -180)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 44)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
title.Text = "  ◆ Lethal Ape Auto"
title.TextColor3 = Color3.fromRGB(120, 200, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 16)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(30, 30)
closeBtn.Position = UDim2.new(1, -38, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -24, 0, 26)
status.Position = UDim2.new(0, 12, 0, 54)
status.BackgroundTransparency = 1
status.Text = "Farm: OFF"
status.TextColor3 = Color3.fromRGB(200, 200, 200)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = panel

local counter = Instance.new("TextLabel")
counter.Size = UDim2.new(1, -24, 0, 26)
counter.Position = UDim2.new(0, 12, 0, 80)
counter.BackgroundTransparency = 1
counter.Text = "Diamantes Coletados: 0"
counter.TextColor3 = Color3.fromRGB(120, 255, 180)
counter.Font = Enum.Font.Gotham
counter.TextSize = 13
counter.TextXAlignment = Enum.TextXAlignment.Left
counter.Parent = panel

local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(1, -24, 0, 48)
autoBtn.Position = UDim2.new(0, 12, 0, 115)
autoBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
autoBtn.Text = "Iniciar Auto Farm"
autoBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextSize = 14
autoBtn.Parent = panel
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 10)

local sellBtn = Instance.new("TextButton")
sellBtn.Size = UDim2.new(1, -24, 0, 40)
sellBtn.Position = UDim2.new(0, 12, 0, 170)
sellBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
sellBtn.Text = "Vender no Scrap"
sellBtn.TextColor3 = Color3.fromRGB(255, 200, 120)
sellBtn.Font = Enum.Font.GothamBold
sellBtn.TextSize = 14
sellBtn.Parent = panel
Instance.new("UICorner", sellBtn).CornerRadius = UDim.new(0, 10)

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(1, -24, 0, 40)
stopBtn.Position = UDim2.new(0, 12, 0, 220)
stopBtn.BackgroundColor3 = Color3.fromRGB(80, 35, 35)
stopBtn.Text = "STOP FARM"
stopBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 14
stopBtn.Parent = panel
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 10)

local destroyBtn = Instance.new("TextButton")
destroyBtn.Size = UDim2.new(1, -24, 0, 36)
destroyBtn.Position = UDim2.new(0, 12, 0, 270)
destroyBtn.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
destroyBtn.Text = "Destruir Menu"
destroyBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
destroyBtn.Font = Enum.Font.GothamBold
destroyBtn.TextSize = 13
destroyBtn.Parent = panel
Instance.new("UICorner", destroyBtn).CornerRadius = UDim.new(0, 8)

-- ========== CONEXÕES ==========
local function setFarmState(on)
    farming = on
    if on then
        loopId = loopId + 1 -- Cria um ID novo para o loop
        visited = {} -- LIMPA a memória para ele procurar do zero!
        
        status.Text = "Farm: ON"
        status.TextColor3 = Color3.fromRGB(120, 255, 180)
        autoBtn.Text = "Farm Rodando..."
        autoBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 60)
        
        local currentId = loopId
        task.spawn(function()
            runFarm(currentId)
        end)
    else
        status.Text = "Farm: OFF"
        status.TextColor3 = Color3.fromRGB(200, 200, 200)
        autoBtn.Text = "Iniciar Auto Farm"
        autoBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
    end
end

autoBtn.MouseButton1Click:Connect(function() setFarmState(not farming) end)
stopBtn.MouseButton1Click:Connect(function() setFarmState(false) end)

sellBtn.MouseButton1Click:Connect(function()
    local wasFarming = farming
    setFarmState(false)
    
    sellBtn.Text = "Vendendo..."
    sellAll()
    collectedCount = 0
    
    task.wait(0.3)
    
    if wasFarming then
        setFarmState(true)
    end
    sellBtn.Text = "Vender no Scrap"
end)

destroyBtn.MouseButton1Click:Connect(function()
    setFarmState(false)
    gui:Destroy()
end)

closeBtn.MouseButton1Click:Connect(function() panel.Visible = false toggle.Visible = true end)
toggle.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible toggle.Visible = false end)

task.spawn(function()
    while gui.Parent do
        counter.Text = "Diamantes Coletados: " .. collectedCount
        task.wait(0.5)
    end
end)

local dragging, dragStart, startPos
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = panel.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

print("[LethalApe] Script corrigido e pronto!")
