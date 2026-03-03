-- HITBOX EXPANDER + PREDICTION LINES + AUTO CLICK + COURT NEON
-- VERSÃO MOBILE (Teclado Físico)
-- Teclas: K = Auto Click | C = Prediction Lines | H = Court Neon | V = Toggle Hitbox Visual

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local LocalPlayer     = Players.LocalPlayer

-- ==============================================
-- VERIFICAÇÃO DE PLATAFORMA
-- ==============================================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
-- Com teclado físico conectado, KeyboardEnabled = true mesmo no celular

-- ==============================================
-- CONFIGURAÇÕES
-- ==============================================
local Config = {
    HitboxEnabled = true,
    HitboxVisible = false,
    HitboxSize    = 4,
    CtrlHitboxSize = 8,
}

local PredictionLinesEnabled = false

local AutoCtrlConfig = {
    Enabled        = true,
    HorizontalRange = 49.99,
    VerticalRange   = 5,
    Cooldown        = 0.4,
    LastPressed     = 0,
}

-- ==============================================
-- ESTADO GLOBAL
-- ==============================================
local KHeld              = false
local ctrlVirtuallyHeld  = false
local magnetActive       = false
local hasRotatedThisK    = false
local tpUsed             = false

-- ==============================================
-- COORDENADAS DA QUADRA
-- ==============================================
local COURT_Y     = -4.81
local NET_Z       = -0.52
local COURT_X_MIN = -26.16
local COURT_X_MAX =  25.84
local COURT_Z_MIN = -50
local COURT_Z_MAX =  50

local playerSide  = nil
local areaCorners = {}

local function buildAreaForSide(side)
    if side == "positive" then
        areaCorners = {
            Vector3.new(COURT_X_MAX, COURT_Y, NET_Z),
            Vector3.new(COURT_X_MAX, COURT_Y, COURT_Z_MAX),
            Vector3.new(COURT_X_MIN, COURT_Y, COURT_Z_MAX),
            Vector3.new(COURT_X_MIN, COURT_Y, NET_Z),
        }
    else
        areaCorners = {
            Vector3.new(COURT_X_MAX, COURT_Y, COURT_Z_MIN),
            Vector3.new(COURT_X_MAX, COURT_Y, NET_Z),
            Vector3.new(COURT_X_MIN, COURT_Y, NET_Z),
            Vector3.new(COURT_X_MIN, COURT_Y, COURT_Z_MIN),
        }
    end
end

local function detectPlayerSide()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local z = root.Position.Z
    if math.abs(z - NET_Z) < 1 then return end
    local side = (z > NET_Z) and "positive" or "negative"
    if side ~= playerSide then
        playerSide = side
        buildAreaForSide(side)
    end
end

-- ==============================================
-- BORDA NEON VERDE
-- ==============================================
local courtNeonParts   = {}
local courtNeonVisible = false

local function buildCourtNeon()
    for _, p in ipairs(courtNeonParts) do
        if p and p.Parent then p:Destroy() end
    end
    courtNeonParts = {}
    if #areaCorners < 4 then return end

    local thickness = 0.3
    local height    = 0.2
    local yPos      = COURT_Y + 0.15

    for i = 1, 4 do
        local a   = areaCorners[i]
        local b   = areaCorners[(i % 4) + 1]
        local mid = (a + b) / 2
        local len = (b - a).Magnitude

        local part = Instance.new("Part")
        part.Name        = "CourtNeon_" .. i
        part.Anchored    = true
        part.CanCollide  = false
        part.CanQuery    = false
        part.CastShadow  = false
        part.Material    = Enum.Material.Neon
        part.Color       = Color3.fromRGB(0, 255, 80)
        part.Transparency = courtNeonVisible and 0 or 1

        if math.abs(b.X - a.X) > math.abs(b.Z - a.Z) then
            part.Size = Vector3.new(len, height, thickness)
        else
            part.Size = Vector3.new(thickness, height, len)
        end

        part.CFrame = CFrame.new(mid.X, yPos, mid.Z)
        part.Parent = workspace
        table.insert(courtNeonParts, part)
    end
end

local function setCourtNeonVisible(v)
    courtNeonVisible = v
    for _, p in ipairs(courtNeonParts) do
        if p and p.Parent then p.Transparency = v and 0 or 1 end
    end
end

local function toggleCourtNeon()
    setCourtNeonVisible(not courtNeonVisible)
end

-- ==============================================
-- DETECÇÃO DE BOLA NA ÁREA
-- ==============================================
local function pointInPolygon(px, pz, polygon)
    if #polygon < 3 then return true end
    local inside = false
    local n = #polygon
    local j = n
    for i = 1, n do
        local xi, zi = polygon[i].X, polygon[i].Z
        local xj, zj = polygon[j].X, polygon[j].Z
        if ((zi > pz) ~= (zj > pz)) and (px < (xj - xi) * (pz - zi) / (zj - zi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function isBallInArea(ballPos)
    if #areaCorners < 4 then return true end
    return pointInPolygon(ballPos.X, ballPos.Z, areaCorners)
end

-- ==============================================
-- AUXILIARES
-- ==============================================
local function getLocalCharacter()
    return LocalPlayer.Character
end

local function getLocalRootPart()
    local char = getLocalCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ==============================================
-- CTRL VIRTUAL — MOBILE SAFE
-- Mobile não suporta VirtualInputManager igual ao PC.
-- Usamos ContextActionService para simular o input de forma confiável.
-- ==============================================
local CTRL_ACTION = "MobileCtrlHold"

local function holdCtrl()
    if ctrlVirtuallyHeld then return end
    ctrlVirtuallyHeld = true
    -- Bind temporário que retorna Sink (consome o input)
    ContextActionService:BindAction(CTRL_ACTION, function(_, state)
        return Enum.ContextActionResult.Sink
    end, false, Enum.KeyCode.LeftControl)

    -- Disparo direto via pcall como fallback
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
    end)
end

local function releaseCtrl()
    if not ctrlVirtuallyHeld then return end
    ctrlVirtuallyHeld = false
    ContextActionService:UnbindAction(CTRL_ACTION)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
    end)
end

-- ==============================================
-- HITBOX EXPANDER
-- ==============================================
local modelsProcessed = {}
local ballCache       = {}

local function isClientBallModel(model)
    if not model then return false end
    if not model:IsA("Model") then return false end
    return string.find(model.Name, "^CLIENT_BALL_%d+$") ~= nil
end

local function findBallInModel(model)
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") or child:IsA("MeshPart") then
            return child
        end
    end
    return nil
end

local function createHitboxForModel(model)
    if not Config.HitboxEnabled then return nil end
    if not modelsProcessed[model] then modelsProcessed[model] = {} end
    if modelsProcessed[model].hitbox then return modelsProcessed[model].hitbox end

    local ball = findBallInModel(model)
    if not ball then return nil end

    local hitboxName = "Hitbox_" .. model.Name
    local old = model:FindFirstChild(hitboxName)
    if old then old:Destroy() end

    local size   = Config.HitboxSize
    local hitbox = Instance.new("Part")
    hitbox.Name        = hitboxName
    hitbox.Size        = Vector3.new(size, size, size)
    hitbox.Transparency = 1
    hitbox.CanCollide  = false
    hitbox.Anchored    = false
    hitbox.Massless    = true
    hitbox.CanQuery    = true
    hitbox.CFrame      = ball.CFrame
    hitbox.Parent      = model

    local weld       = Instance.new("Weld")
    weld.Part0       = ball
    weld.Part1       = hitbox
    weld.Parent      = hitbox

    local vis        = Instance.new("Part")
    vis.Name         = "HitboxVisual"
    vis.Shape        = Enum.PartType.Ball
    vis.Size         = Vector3.new(size, size, size)
    vis.Transparency = Config.HitboxVisible and 0.85 or 1
    vis.Color        = Color3.fromRGB(100, 255, 100)
    vis.Material     = Enum.Material.ForceField
    vis.CanCollide   = false
    vis.Anchored     = false
    vis.Massless     = true
    vis.CanQuery     = false
    vis.CastShadow   = false
    vis.Parent       = hitbox

    local visWeld    = Instance.new("Weld")
    visWeld.Part0    = hitbox
    visWeld.Part1    = vis
    visWeld.Parent   = vis

    modelsProcessed[model].hitbox = hitbox
    modelsProcessed[model].ball   = ball
    modelsProcessed[model].visual = vis
    return hitbox
end

local function scanBalls()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isClientBallModel(obj) then
            if not table.find(ballCache, obj) then
                table.insert(ballCache, obj)
            end
            if Config.HitboxEnabled then
                task.spawn(createHitboxForModel, obj)
            end
        end
    end
end

local function cleanupHitboxes()
    for _, data in pairs(modelsProcessed) do
        if data.hitbox then
            data.hitbox:Destroy()
            data.hitbox = nil
            data.visual = nil
            data.ball   = nil
        end
    end
end

local function toggleHitbox()
    Config.HitboxEnabled = not Config.HitboxEnabled
    if Config.HitboxEnabled then scanBalls() else cleanupHitboxes() end
end

local function toggleHitboxVisual()
    Config.HitboxVisible = not Config.HitboxVisible
    for _, data in pairs(modelsProcessed) do
        if data.visual then
            data.visual.Transparency = Config.HitboxVisible and 0.85 or 1
        end
    end
end

-- ==============================================
-- CTRL HITBOXES
-- ==============================================
local function createCtrlHitboxes()
    for _, ballModel in ipairs(ballCache) do
        if not (ballModel and ballModel.Parent) then continue end
        if not modelsProcessed[ballModel] then modelsProcessed[ballModel] = {} end
        local data = modelsProcessed[ballModel]

        if data.ctrlHitboxes then
            for _, hb in ipairs(data.ctrlHitboxes) do
                if hb and hb.Parent then hb:Destroy() end
            end
        end
        data.ctrlHitboxes = {}

        local ball = findBallInModel(ballModel)
        if not ball then continue end

        local cs  = Config.CtrlHitboxSize
        local hSz = cs * 1.8
        local vSz = 6

        local function makeHB(name, sz, offset)
            local p = Instance.new("Part")
            p.Name        = name .. "_" .. ballModel.Name
            p.Size        = sz
            p.Transparency = 1
            p.CanCollide  = false
            p.Anchored    = false
            p.Massless    = true
            p.CanQuery    = true
            p.CFrame      = ball.CFrame * CFrame.new(offset or Vector3.new())
            p.Parent      = ballModel
            local w       = Instance.new("Weld")
            w.Part0       = ball
            w.Part1       = p
            w.Parent      = p
            table.insert(data.ctrlHitboxes, p)
        end

        makeHB("CtrlMain",   Vector3.new(cs, vSz, cs),          nil)
        makeHB("CtrlGiant",  Vector3.new(hSz*2, vSz, hSz*2),    nil)
        makeHB("CtrlDisk",   Vector3.new(hSz*2, 2, hSz*2),      nil)
        makeHB("CtrlRod",    Vector3.new(2, vSz, 2),             nil)
        makeHB("CtrlCrossX", Vector3.new(hSz*2, 2, 2),           nil)
        makeHB("CtrlCrossZ", Vector3.new(2, 2, hSz*2),           nil)

        local offsets = {
            Vector3.new(4,0,0), Vector3.new(-4,0,0),
            Vector3.new(0,2,0), Vector3.new(0,-2,0),
            Vector3.new(0,0,4), Vector3.new(0,0,-4),
            Vector3.new(3,2,3), Vector3.new(-3,-2,-3),
            Vector3.new(5,0,0), Vector3.new(-5,0,0),
            Vector3.new(0,0,5), Vector3.new(0,0,-5),
        }
        for i, off in ipairs(offsets) do
            makeHB("CtrlOff"..i, Vector3.new(hSz, vSz, hSz), off)
        end
    end
end

local function destroyCtrlHitboxes()
    for _, data in pairs(modelsProcessed) do
        if data.ctrlHitboxes then
            for _, hb in ipairs(data.ctrlHitboxes) do
                if hb and hb.Parent then hb:Destroy() end
            end
            data.ctrlHitboxes = nil
        end
    end
end

-- ==============================================
-- AUTO CLICK
-- ==============================================
local function checkAutoCtrl()
    if not KHeld then return end
    if not AutoCtrlConfig.Enabled then return end
    detectPlayerSide()

    local rootPart = getLocalRootPart()
    if not rootPart then return end
    local playerPos = rootPart.Position
    local ballInRange = false

    for _, ballModel in ipairs(ballCache) do
        if not (ballModel and ballModel.Parent) then continue end
        local ball = findBallInModel(ballModel)
        if not ball then continue end
        local ballPos = ball.Position

        if not isBallInArea(ballPos) then continue end

        local hDist = Vector3.new(ballPos.X - playerPos.X, 0, ballPos.Z - playerPos.Z).Magnitude
        local vDiff = math.abs(ballPos.Y - playerPos.Y)
        local heightOk = vDiff <= AutoCtrlConfig.VerticalRange or ballPos.Y <= AutoCtrlConfig.VerticalRange

        if hDist <= AutoCtrlConfig.HorizontalRange and heightOk then
            ballInRange = true

            if not hasRotatedThisK then
                hasRotatedThisK = true
                local dir = Vector3.new(ballPos.X - playerPos.X, 0, ballPos.Z - playerPos.Z).Unit
                rootPart.CFrame = CFrame.new(playerPos, playerPos + dir)
            end

            if not tpUsed and hDist <= 5 then
                tpUsed = true
                local newPos = Vector3.new(ballPos.X, playerPos.Y, ballPos.Z)
                rootPart.CFrame = CFrame.new(newPos) * (rootPart.CFrame - rootPart.CFrame.Position)
            end

            local now = tick()
            if now - AutoCtrlConfig.LastPressed >= AutoCtrlConfig.Cooldown then
                AutoCtrlConfig.LastPressed = now
                task.delay(0.03, releaseCtrl)
            end
            break
        end
    end

    if not ballInRange then holdCtrl() end
end

-- ==============================================
-- PREDICTION LINES
-- ==============================================
local RAYCAST_INTERVAL      = 0.1
local LINE_LENGTH           = 25
local LINE_SIZE             = Vector3.new(0.2, 0.2, LINE_LENGTH)
local GROUND_CHECK_DISTANCE = -3.1
local VELOCITY_THRESHOLD    = 0.5

local lines            = {}
local frozenDirections = {}
local wasOnGround      = {}
local lastRaycastTime  = {}
local cachedGroundState = {}

local raycastParams = RaycastParams.new()
raycastParams.FilterType  = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function isEnemy(player)
    if not LocalPlayer.Team then return true end
    if not player.Team then return true end
    return player.Team ~= LocalPlayer.Team
end

local function createPredictionLine()
    local line = Instance.new("Part")
    line.Name        = "PredictionLine"
    line.Anchored    = true
    line.CanCollide  = false
    line.Material    = Enum.Material.Neon
    line.Color       = Color3.fromRGB(255, 0, 0)
    line.Size        = LINE_SIZE
    line.Transparency = 0.3
    line.CastShadow  = false
    line.Parent      = workspace
    return line
end

local function isOnGroundCached(player, character, rootPart, t)
    if lastRaycastTime[player] and (t - lastRaycastTime[player]) < RAYCAST_INTERVAL then
        return cachedGroundState[player] or false
    end
    lastRaycastTime[player] = t
    local vy = rootPart.AssemblyLinearVelocity.Y
    if math.abs(vy) > 5 then
        cachedGroundState[player] = false
        return false
    end
    raycastParams.FilterDescendantsInstances = {character}
    local ray    = workspace:Raycast(rootPart.Position, Vector3.new(0, GROUND_CHECK_DISTANCE, 0), raycastParams)
    local onGnd  = ray ~= nil and math.abs(vy) < VELOCITY_THRESHOLD
    cachedGroundState[player] = onGnd
    return onGnd
end

local function calcLookDir(head)
    local lv = head.CFrame.LookVector
    local h  = Vector3.new(lv.X, 0, lv.Z)
    return h.Magnitude > 0.01 and h.Unit or Vector3.new(0, 0, -1)
end

local function updatePredictionLine(player, t)
    if not PredictionLinesEnabled then
        if lines[player] then
            lines[player]:Destroy()
            lines[player] = nil
            frozenDirections[player]  = nil
            wasOnGround[player]       = nil
            lastRaycastTime[player]   = nil
            cachedGroundState[player] = nil
        end
        return
    end
    if player == LocalPlayer then return end
    if not isEnemy(player) then
        if lines[player] then
            lines[player]:Destroy()
            lines[player] = nil
        end
        return
    end

    local char     = player.Character
    local head     = char and char:FindFirstChild("Head")
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")

    if not char or not head or not rootPart then
        if lines[player] then lines[player]:Destroy() lines[player] = nil end
        return
    end

    if not lines[player] then lines[player] = createPredictionLine() end

    local onGnd = isOnGroundCached(player, char, rootPart, t)
    if wasOnGround[player] == nil then wasOnGround[player] = onGnd end

    local lookDir
    if (wasOnGround[player] and not onGnd) then
        lookDir = calcLookDir(head)
        frozenDirections[player] = lookDir
    elseif onGnd then
        lookDir = calcLookDir(head)
        frozenDirections[player] = lookDir
    else
        lookDir = frozenDirections[player] or calcLookDir(head)
    end
    wasOnGround[player] = onGnd

    local start  = head.Position
    local finish = start + (lookDir * LINE_LENGTH)
    local mid    = (start + finish) * 0.5
    lines[player].CFrame = CFrame.new(mid, finish)
end

local function cleanupPlayer(player)
    if lines[player] then lines[player]:Destroy() lines[player] = nil end
    frozenDirections[player]  = nil
    wasOnGround[player]       = nil
    lastRaycastTime[player]   = nil
    cachedGroundState[player] = nil
end

local function togglePredictionLines()
    PredictionLinesEnabled = not PredictionLinesEnabled
    if not PredictionLinesEnabled then
        for _, p in ipairs(Players:GetPlayers()) do cleanupPlayer(p) end
    end
end

-- ==============================================
-- INPUT — TECLADO FÍSICO (mobile-safe)
-- Teclas: K, C, H, V
-- ==============================================
local function setupInput()
    -- K pressionado → ativa auto click + ctrl hitboxes
    ContextActionService:BindAction("ActionK",
        function(_, state)
            if state == Enum.UserInputState.Begin then
                KHeld           = true
                hasRotatedThisK = false
                tpUsed          = false
                createCtrlHitboxes()
                holdCtrl()
            elseif state == Enum.UserInputState.End then
                KHeld           = false
                hasRotatedThisK = false
                tpUsed          = false
                destroyCtrlHitboxes()
                releaseCtrl()
            end
            return Enum.ContextActionResult.Pass
        end,
        false,  -- sem botão na tela (teclado físico)
        Enum.KeyCode.K
    )

    -- C → toggle prediction lines
    ContextActionService:BindAction("ActionC",
        function(_, state)
            if state == Enum.UserInputState.Begin then
                togglePredictionLines()
            end
            return Enum.ContextActionResult.Pass
        end,
        false,
        Enum.KeyCode.C
    )

    -- H → toggle court neon
    ContextActionService:BindAction("ActionH",
        function(_, state)
            if state == Enum.UserInputState.Begin then
                toggleCourtNeon()
            end
            return Enum.ContextActionResult.Pass
        end,
        false,
        Enum.KeyCode.H
    )

    -- V → toggle hitbox visual
    ContextActionService:BindAction("ActionV",
        function(_, state)
            if state == Enum.UserInputState.Begin then
                toggleHitboxVisual()
            end
            return Enum.ContextActionResult.Pass
        end,
        false,
        Enum.KeyCode.V
    )
end

-- ==============================================
-- INICIALIZAÇÃO
-- ==============================================
local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        updatePredictionLine(player, tick())
        if player == LocalPlayer then
            task.wait(0.3)
            detectPlayerSide()
            buildCourtNeon()
        end
    end)
    if player.Character then
        task.wait(0.1)
        updatePredictionLine(player, tick())
        if player == LocalPlayer then
            task.spawn(function()
                task.wait(0.5)
                detectPlayerSide()
                buildCourtNeon()
            end)
        end
    end
end

for _, p in ipairs(Players:GetPlayers()) do onPlayerAdded(p) end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(cleanupPlayer)

workspace.DescendantAdded:Connect(function(obj)
    if isClientBallModel(obj) then
        if not table.find(ballCache, obj) then
            table.insert(ballCache, obj)
        end
        task.wait(0.3)
        if Config.HitboxEnabled then createHitboxForModel(obj) end
    end
end)

setupInput()

task.spawn(function()
    task.wait(1)
    detectPlayerSide()
    buildCourtNeon()
end)

-- Limpeza periódica do cache
task.spawn(function()
    while true do
        task.wait(5)
        for i = #ballCache, 1, -1 do
            if not ballCache[i] or not ballCache[i].Parent then
                table.remove(ballCache, i)
            end
        end
        for model, data in pairs(modelsProcessed) do
            if data.hitbox and not data.hitbox.Parent then
                data.hitbox = nil
                data.visual = nil
            end
        end
    end
end)

-- Loop principal
RunService.RenderStepped:Connect(function()
    local t = tick()
    for _, p in ipairs(Players:GetPlayers()) do
        pcall(updatePredictionLine, p, t)
    end
end)

RunService.Heartbeat:Connect(function()
    if AutoCtrlConfig.Enabled and KHeld then
        checkAutoCtrl()
    end
end)

task.wait(1)
if Config.HitboxEnabled then scanBalls() end

print("[Mobile Script] Carregado! Teclas: K=AutoClick | C=PredictionLines | H=CourtNeon | V=HitboxVisual")
