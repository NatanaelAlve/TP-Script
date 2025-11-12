-- SCRIPT UNIFICADO: V = Toggle TP | X = Troca Head/Peito | C = Marca/TP
-- Aimlock e Highlight SEMPRE ativos

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local WS = game:GetService("Workspace")

local lp = Players.LocalPlayer
local cam = WS.CurrentCamera

-- === CONFIGURAÇÕES GLOBAIS ===
local TP_ATIVO = true  -- V controla apenas o Teleport

-- Highlight
local highlights, highlightOn = {}, true
local AURA = Color3.fromRGB(255, 0, 0)
local LOCKED = Color3.fromRGB(0, 255, 0)
local FILL_T, OUT_T = 0.6, 0.2

-- Aimlock
local AIM_FOV = 300
local aimOn = false
local lockColor = false
local target = nil
local aimPart = "Head" -- Alterna com X

-- Teleport
local TP_ENABLED = false
local TP_POSITION = nil
local ESFERA = nil
local HIGHLIGHT_ESFERA = nil
local spinConnection = nil
local ESFERA_SIZE = 1.5
local ESFERA_COLOR = Color3.fromRGB(0, 255, 0)

-- Teclas
local KEY_V = Enum.KeyCode.V
local KEY_T = Enum.KeyCode.T
local KEY_R = Enum.KeyCode.R
local KEY_G = Enum.KeyCode.G
local KEY_C = Enum.KeyCode.C   -- Agora: Marca/TP
local KEY_X = Enum.KeyCode.X   -- NOVO: Troca Head/Peito

-- === FUNÇÕES AUXILIARES ===
local function getHRP()
    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        return lp.Character.HumanoidRootPart
    end
    return nil
end

-- === HIGHLIGHT SYSTEM ===
local function makeHighlight(char)
    if not char or not char:IsA("Model") then return end
    local h = Instance.new("Highlight")
    h.Adornee = char
    h.FillColor = AURA
    h.OutlineColor = AURA
    h.FillTransparency = FILL_T
    h.OutlineTransparency = OUT_T
    h.Enabled = highlightOn
    h.Parent = char
    return h
end

local function cleanup(p)
    if highlights[p] then
        highlights[p]:Destroy()
        highlights[p] = nil
    end
end

local function setup(p)
    if p == lp then return end
    local function add(char)
        if not char then return end
        cleanup(p)
        local h = makeHighlight(char)
        highlights[p] = h
        char.AncestryChanged:Connect(function(_, parent)
            if not parent then cleanup(p) end
        end)
    end
    if p.Character then add(p.Character) end
    p.CharacterAdded:Connect(add)
end

for _, p in ipairs(Players:GetPlayers()) do setup(p) end
Players.PlayerAdded:Connect(setup)
Players.PlayerRemoving:Connect(cleanup)

-- === TELEPORT SYSTEM ===
local function limparEsfera()
    if ESFERA and ESFERA.Parent then ESFERA:Destroy() end
    if HIGHLIGHT_ESFERA and HIGHLIGHT_ESFERA.Parent then HIGHLIGHT_ESFERA:Destroy() end
    if spinConnection then spinConnection:Disconnect() end
    ESFERA = nil
    HIGHLIGHT_ESFERA = nil
    spinConnection = nil
end

local function criarEsfera(pos)
    limparEsfera()
    local hrp = getHRP()
    if not hrp then return end

    ESFERA = Instance.new("Part")
    ESFERA.Name = "TP_Esfera_" .. lp.Name
    ESFERA.Shape = Enum.PartType.Ball
    ESFERA.Size = Vector3.new(ESFERA_SIZE, ESFERA_SIZE, ESFERA_SIZE)
    ESFERA.Position = pos + Vector3.new(0, ESFERA_SIZE/2, 0)
    ESFERA.Anchored = true
    ESFERA.CanCollide = false
    ESFERA.Material = Enum.Material.Neon
    ESFERA.Color = ESFERA_COLOR
    ESFERA.Transparency = 0
    ESFERA.Parent = WS

    HIGHLIGHT_ESFERA = Instance.new("Highlight")
    HIGHLIGHT_ESFERA.FillColor = ESFERA_COLOR
    HIGHLIGHT_ESFERA.OutlineColor = Color3.fromRGB(255, 255, 255)
    HIGHLIGHT_ESFERA.FillTransparency = 0.5
    HIGHLIGHT_ESFERA.OutlineTransparency = 0
    HIGHLIGHT_ESFERA.Adornee = ESFERA
    HIGHLIGHT_ESFERA.Parent = ESFERA

    spinConnection = RS.Heartbeat:Connect(function()
        if ESFERA and ESFERA.Parent then
            ESFERA.CFrame = ESFERA.CFrame * CFrame.Angles(0, math.rad(5), 0)
        else
            spinConnection:Disconnect()
        end
    end)

    print("ESFERA CRIADA em:", pos)
end

local function teleportar()
    local hrp = getHRP()
    if not hrp or not TP_POSITION then return end
    hrp.CFrame = CFrame.new(TP_POSITION)
    limparEsfera()
    print("TELEPORTADO!")
end

local function resetTP()
    TP_ENABLED = false
    TP_POSITION = nil
    limparEsfera()
end

-- === INPUT HANDLER ===
UIS.InputBegan:Connect(function(i, gp)
    if gp then return end

    -- V = Toggle apenas Teleport
    if i.KeyCode == KEY_V then
        TP_ATIVO = not TP_ATIVO
        if not TP_ATIVO then resetTP() end
        print("Teleport:", TP_ATIVO and "ATIVADO (V)" or "DESATIVADO (V)")
        return
    end

    -- Se TP desativado, bloqueia C
    if not TP_ATIVO and i.KeyCode == KEY_C then
        print("Teleport desativado! (V para ativar)")
        return
    end

    -- Highlight (sempre)
    if i.KeyCode == KEY_T then
        highlightOn = not highlightOn
        for _, h in pairs(highlights) do if h then h.Enabled = highlightOn end end
        print("Highlight:", highlightOn and "ON" or "OFF")

    -- Aimlock (sempre)
    elseif i.KeyCode == KEY_R then
        aimOn = not aimOn
        if aimOn then
            local mouse = UIS:GetMouseLocation()
            local closest, minDist = nil, AIM_FOV
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= lp and plr.Character and plr.Character:FindFirstChild("Head") then
                    local headPos, onScreen = cam:WorldToViewportPoint(plr.Character.Head.Position)
                    if onScreen then
                        local dist = (Vector2.new(headPos.X, headPos.Y) - mouse).Magnitude
                        if dist < minDist then closest, minDist = plr, dist end
                    end
                end
            end
            target = closest
            if target then
                print("TRAVADO EM:", target.Name, "| Parte:", aimPart)
            else
                aimOn = false
                print("Nenhum alvo no FOV!")
            end
        else
            target = nil
            lockColor = false
            print("Aimlock DESATIVADO")
        end

    -- Lock Color (sempre)
    elseif i.KeyCode == KEY_G and aimOn and target then
        lockColor = not lockColor
        local h = highlights[target]
        if h then
            local color = lockColor and LOCKED or AURA
            h.FillColor, h.OutlineColor = color, color
        end

    -- X = Alterna Head / Peito (só se aimlock ativo)
    elseif i.KeyCode == KEY_X then
        if aimOn and target then
            aimPart = (aimPart == "Head") and "HumanoidRootPart" or "Head"
            print("Mira agora em:", aimPart)
        else
            print("Aimlock precisa estar ATIVO para usar X!")
        end

    -- C = Marca/Teleport (só se TP ativo)
    elseif i.KeyCode == KEY_C then
        local hrp = getHRP()
        if not hrp then
            print("Personagem não carregado!")
            return
        end
        TP_ENABLED = not TP_ENABLED
        if TP_ENABLED then
            TP_POSITION = hrp.Position
            criarEsfera(TP_POSITION)
            print("PONTO SALVO! Aperte C novamente para TP.")
        else
            teleportar()
        end
    end
end)

-- === AIMLOCK LOOP ===
RS.RenderStepped:Connect(function()
    if aimOn and target and target.Character and target.Character:FindFirstChild(aimPart) then
        cam.CFrame = CFrame.new(cam.CFrame.Position, target.Character[aimPart].Position)
    end
end)

-- === RESPAWN ===
lp.CharacterAdded:Connect(function()
    task.wait(1)
    resetTP()
    print("RESPAWN: TP resetado.")
end)

-- === LIMPEZA FINAL ===
game:BindToClose(function()
    limparEsfera()
    for _, h in pairs(highlights) do if h then h:Destroy() end end
end)

-- === INICIALIZAÇÃO ===
print("=== SCRIPT CARREGADO (X = Head/Peito) ===")
print("V = Liga/Desliga Teleport")
print("T = Toggle Highlight")
print("R = Aimlock (FOV 300)")
print("G = Cor de trava (verde)")
print("X = Alterna mira: Head <-> Peito (só com aimlock)")
print("C = Marca ponto / Teleporta (só se V ativo)")
print("STATUS: TP ATIVO | Aim/Highlight SEMPRE")
