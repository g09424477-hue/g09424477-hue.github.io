-- Brookhaven Candy Helper (Mobile UI Framework)
-- 适用于 Delta Android 执行器
-- 注意：此脚本不保证能真正收集糖果，仅提供 UI 与可扩展逻辑框架

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========== 配置 ==========
local CONFIG = {
    ScanInterval = 1.5,        -- 扫描间隔（秒），避免手机卡顿
    TeleportOffset = Vector3.new(0, 3, 0), -- 传送到糖果上方的偏移
    MaxTeleportDistance = 5000, -- 最大传送距离（防止瞬移过远被检测）
    CollectRadius = 8,          -- 靠近判定半径
}

-- ========== 状态 ==========
local State = {
    isRunning = false,
    collectedCount = 0,
    visitedCandies = {},       -- 已访问过的糖果（用对象引用或位置做 key）
    currentTarget = nil,
    scanThread = nil,
}

-- ========== UI 创建 ==========
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BrookhavenCandyHelper"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = playerGui

    -- 浮动按钮
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleBtn"
    toggleBtn.Size = UDim2.new(0, 70, 0, 70)
    toggleBtn.Position = UDim2.new(0, 20, 0, 100)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
    toggleBtn.Text = "🍬"
    toggleBtn.TextSize = 36
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.AutoButtonColor = false
    toggleBtn.Parent = screenGui

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0.5, 0)
    toggleCorner.Parent = toggleBtn

    local toggleStroke = Instance.new("UIStroke")
    toggleStroke.Color = Color3.fromRGB(255, 200, 0)
    toggleStroke.Thickness = 2
    toggleStroke.Parent = toggleBtn

    -- 主面板
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 320, 0, 420)
    mainFrame.Position = UDim2.new(0.5, -160, 0.3, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 15, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 18)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(255, 140, 0)
    mainStroke.Thickness = 2
    mainStroke.Parent = mainFrame

    -- 标题栏（可拖动）
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 55)
    titleBar.BackgroundColor3 = Color3.fromRGB(45, 20, 55)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 18)
    titleCorner.Parent = titleBar

    -- 标题文字
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -60, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🎃 Candy Helper"
    titleLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    titleLabel.TextSize = 22
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    -- 关闭按钮
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -50, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "✕"
    closeBtn.TextSize = 20
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = titleBar

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 10)
    closeCorner.Parent = closeBtn

    -- 状态显示
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(1, -30, 0, 80)
    statusFrame.Position = UDim2.new(0, 15, 0, 70)
    statusFrame.BackgroundColor3 = Color3.fromRGB(35, 25, 45)
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = mainFrame

    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 12)
    statusCorner.Parent = statusFrame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -20, 0, 30)
    statusLabel.Position = UDim2.new(0, 10, 0, 5)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Auto Farm: OFF"
    statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    statusLabel.TextSize = 18
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusFrame

    local countLabel = Instance.new("TextLabel")
    countLabel.Name = "CountLabel"
    countLabel.Size = UDim2.new(1, -20, 0, 30)
    countLabel.Position = UDim2.new(0, 10, 0, 40)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = "已收集: 0"
    countLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    countLabel.TextSize = 16
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextXAlignment = Enum.TextXAlignment.Left
    countLabel.Parent = statusFrame

    -- 主按钮：Auto Collect
    local autoBtn = Instance.new("TextButton")
    autoBtn.Name = "AutoBtn"
    autoBtn.Size = UDim2.new(1, -30, 0, 70)
    autoBtn.Position = UDim2.new(0, 15, 0, 170)
    autoBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 0)
    autoBtn.Text = "Auto Collect Candy"
    autoBtn.TextSize = 22
    autoBtn.Font = Enum.Font.GothamBold
    autoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoBtn.BorderSizePixel = 0
    autoBtn.AutoButtonColor = false
    autoBtn.Parent = mainFrame

    local autoCorner = Instance.new("UICorner")
    autoCorner.CornerRadius = UDim.new(0, 14)
    autoCorner.Parent = autoBtn

    -- 停止按钮
    local stopBtn = Instance.new("TextButton")
    stopBtn.Name = "StopBtn"
    stopBtn.Size = UDim2.new(1, -30, 0, 55)
    stopBtn.Position = UDim2.new(0, 15, 0, 260)
    stopBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    stopBtn.Text = "⏹ 立即停止"
    stopBtn.TextSize = 20
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stopBtn.BorderSizePixel = 0
    stopBtn.AutoButtonColor = false
    stopBtn.Parent = mainFrame

    local stopCorner = Instance.new("UICorner")
    stopCorner.CornerRadius = UDim.new(0, 12)
    stopCorner.Parent = stopBtn

    -- 说明文字
    local hintLabel = Instance.new("TextLabel")
    hintLabel.Size = UDim2.new(1, -30, 0, 60)
    hintLabel.Position = UDim2.new(0, 15, 0, 330)
    hintLabel.BackgroundTransparency = 1
    hintLabel.Text = "⚠️ 此脚本不保证能找到/收集糖果\n请确认游戏内糖果对象名称后再使用"
    hintLabel.TextColor3 = Color3.fromRGB(255, 180, 100)
    hintLabel.TextSize = 13
    hintLabel.Font = Enum.Font.Gotham
    hintLabel.TextWrapped = true
    hintLabel.Parent = mainFrame

    return {
        screenGui = screenGui,
        toggleBtn = toggleBtn,
        mainFrame = mainFrame,
        titleBar = titleBar,
        closeBtn = closeBtn,
        autoBtn = autoBtn,
        stopBtn = stopBtn,
        statusLabel = statusLabel,
        countLabel = countLabel,
    }
end

-- ========== 拖动逻辑 ==========
local function makeDraggable(frame, dragArea)
    local dragging = false
    local dragStart = nil
    local startPos = nil

    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- ========== 糖果查找逻辑（需要你根据实际游戏调整） ==========
local function findCandies()
    local found = {}
    -- 尝试在 Workspace 中查找名称含 "Candy" 或 "CandyCorn" 的对象
    -- 注意：Brookhaven 的糖果可能不叫这个名字，这里只是示例
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = obj.Name:lower()
            if name:find("candy") or name:find("candycorn") then
                -- 排除已访问的
                if not State.visitedCandies[obj] then
                    table.insert(found, obj)
                end
            end
        end
    end
    return found
end

-- ========== 传送逻辑 ==========
local function teleportTo(target)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- 获取目标位置
    local targetPos
    if target:IsA("BasePart") then
        targetPos = target.Position
    elseif target:IsA("Model") then
        local primary = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
        if primary then
            targetPos = primary.Position
        else
            return false
        end
    else
        return false
    end

    -- 距离检查
    local distance = (hrp.Position - targetPos).Magnitude
    if distance > CONFIG.MaxTeleportDistance then
        return false -- 太远不传送，防止被检测
    end

    -- 执行传送
    hrp.CFrame = CFrame.new(targetPos + CONFIG.TeleportOffset)
    return true
end

-- ========== 收集循环 ==========
local function startCollectLoop(ui)
    State.isRunning = true
    State.collectedCount = 0
    State.visitedCandies = {}

    ui.statusLabel.Text = "Auto Farm: ON"
    ui.statusLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
    ui.autoBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)

    State.scanThread = task.spawn(function()
        while State.isRunning do
            local candies = findCandies()

            if #candies == 0 then
                -- 没有找到新的糖果，等待后继续
                task.wait(CONFIG.ScanInterval)
            else
                for _, candy in ipairs(candies) do
                    if not State.isRunning then break end

                    -- 标记为已访问
                    State.visitedCandies[candy] = true

                    -- 尝试传送
                    local success = teleportTo(candy)
                    if success then
                        task.wait(0.3) -- 等待传送完成
                        -- 尝试触发触摸（如果糖果是靠触碰收集的）
                        local char = player.Character
                        if char then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                -- firetouchinterest 是执行器函数，Delta 应该支持
                                pcall(function()
                                    firetouchinterest(hrp, candy, 0)
                                    task.wait(0.1)
                                    firetouchinterest(hrp, candy, 1)
                                end)
                            end
                        end
                        State.collectedCount = State.collectedCount + 1
                        ui.countLabel.Text = "已收集: " .. State.collectedCount
                    end

                    task.wait(0.2) -- 每个糖果之间的间隔
                end
            end

            task.wait(CONFIG.ScanInterval)
        end
    end)
end

local function stopCollectLoop(ui)
    State.isRunning = false
    if State.scanThread then
        task.cancel(State.scanThread)
        State.scanThread = nil
    end
    ui.statusLabel.Text = "Auto Farm: OFF"
    ui.statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    ui.autoBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 0)
end

-- ========== 主初始化 ==========
local function init()
    local ui = createUI()

    -- 开关面板
    ui.toggleBtn.MouseButton1Click:Connect(function()
        ui.mainFrame.Visible = not ui.mainFrame.Visible
    end)

    ui.closeBtn.MouseButton1Click:Connect(function()
        ui.mainFrame.Visible = false
    end)

    -- 拖动
    makeDraggable(ui.mainFrame, ui.titleBar)

    -- Auto 按钮
    ui.autoBtn.MouseButton1Click:Connect(function()
        if State.isRunning then
            stopCollectLoop(ui)
        else
            startCollectLoop(ui)
        end
    end)

    -- 停止按钮
    ui.stopBtn.MouseButton1Click:Connect(function()
        stopCollectLoop(ui)
    end)

    print("[CandyHelper] UI 已加载。注意：自动收集逻辑需要根据实际游戏对象调整。")
end

init()
