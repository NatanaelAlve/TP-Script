-- TELEPORTE INSTANTÂNEO + MINI ESFERA + TOGGLE GLOBAL COM V
-- VERSÃO CORRIGIDA E TESTADA

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Variáveis globais
local SCRIPT_ATIVO = true
local TP_ENABLED = false
local TP_POSITION = nil
local ESFERA = nil
local HIGHLIGHT = nil
local spinConnection = nil

local ESFERA_SIZE = 1.5
local ESFERA_COLOR = Color3.fromRGB(0, 255, 0)

-- Função segura para obter HumanoidRootPart
local function getHRP()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return LocalPlayer.Character.HumanoidRootPart
    end
    return nil
end

-- Limpar tudo
local function limparTudo()
    if ESFERA and ESFERA.Parent then ESFERA:Destroy() end
    if HIGHLIGHT and HIGHLIGHT.Parent then HIGHLIGHT:Destroy() end
    if spinConnection then spinConnection:Disconnect() end
    ESFERA = nil
    HIGHLIGHT = nil
    spinConnection = nil
end

-- Criar esfera
local function criarEsfera(pos)
    limparTudo()

    local hrp = getHRP()
    if not hrp then return end

    ESFERA = Instance.new("Part")
    ESFERA.Name = "TP_Esfera_" .. LocalPlayer.Name
    ESFERA.Shape = Enum.PartType.Ball
    ESFERA.Size = Vector3.new(ESFERA_SIZE, ESFERA_SIZE, ESFERA_SIZE)
    ESFERA.Position = pos + Vector3.new(0, ESFERA_SIZE/2, 0)
    ESFERA.Anchored = true
    ESFERA.CanCollide = false
    ESFERA.Material = Enum.Material.Neon
    ESFERA.Color = ESFERA_COLOR
    ESFERA.Transparency = 0
    ESFERA.Parent = workspace

    HIGHLIGHT = Instance.new("Highlight")
    HIGHLIGHT.FillColor = ESFERA_COLOR
    HIGHLIGHT.OutlineColor = Color3.fromRGB(255, 255, 255)
    HIGHLIGHT.FillTransparency = 0.5
    HIGHLIGHT.OutlineTransparency = 0
    HIGHLIGHT.Adornee = ESFERA
    HIGHLIGHT.Parent = ESFERA

    -- Rotação
    spinConnection = RunService.Heartbeat:Connect(function()
        if ESFERA and ESFERA.Parent then
            ESFERA.CFrame = ESFERA.CFrame * CFrame.Angles(0, math.rad(5), 0)
        else
            spinConnection:Disconnect()
        end
    end)

    print("ESFERA CRIADA em:", pos)
end

-- Teleportar
local function teleportar()
    local hrp = getHRP()
    if not hrp or not TP_POSITION then return end

    hrp.CFrame = CFrame.new(TP_POSITION)
    limparTudo()
    print("TELEPORTADO!")
end

-- Reset TP
local function resetTP()
    TP_ENABLED = false
    TP_POSITION = nil
    limparTudo()
end

-- Input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    local hrp = getHRP()

    -- TOGGLE GLOBAL COM V
    if input.KeyCode == Enum.KeyCode.V then
        SCRIPT_ATIVO = not SCRIPT_ATIVO
        if SCRIPT_ATIVO then
            print("SCRIPT ATIVADO (V)")
        else
            print("SCRIPT DESATIVADO (V)")
            resetTP()
        end
        return
    end

    -- Se desativado, bloqueia C
    if not SCRIPT_ATIVO then return end

    -- TECLA C
    if input.KeyCode == Enum.KeyCode.C then
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

-- Respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1) -- Espera carregar
    resetTP()
    print("RESPAWN: Script resetado.")
end)

-- Limpeza
game:BindToClose(function()
    limparTudo()
end)

-- Inicialização
print("SCRIPT CARREGADO!")
print("V = Liga/Desliga | C = Marca/TP (só se ativado)")
print("STATUS: ATIVADO")
