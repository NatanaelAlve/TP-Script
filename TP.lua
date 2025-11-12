local Players,UIS,RS,WS=game:GetService("Players"),game:GetService("UserInputService"),game:GetService("RunService"),game:GetService("Workspace")
local lp,cam=Players.LocalPlayer,WS.CurrentCamera
local highlights,highlightOn={},true
local AURA,LOCKED=Color3.fromRGB(255,0,0),Color3.fromRGB(0,255,0)
local FILL_T,OUT_T=0.6,0.2
local KEY_T,KEY_R,KEY_G,KEY_C=Enum.KeyCode.T,Enum.KeyCode.R,Enum.KeyCode.G,Enum.KeyCode.C
local AIM_FOV,aimOn,lockColor,target=300,false,false,nil
local aimPart="Head"
local function makeHighlight(char)
    if not char or not char:IsA("Model")then return end
    local h=Instance.new("Highlight")
    h.Adornee,h.FillColor,h.OutlineColor=char,AURA,AURA
    h.FillTransparency,h.OutlineTransparency,h.Enabled=FILL_T,OUT_T,highlightOn
    h.Parent=char
    return h
end
local function cleanup(p)
    if highlights[p]then highlights[p]:Destroy()highlights[p]=nil end
end
local function setup(p)
    if p==lp then return end
    local function add(char)
        if not char then return end
        cleanup(p)
        local h=makeHighlight(char)
        highlights[p]=h
        char.AncestryChanged:Connect(function(_,parent)if not parent then cleanup(p)end end)
    end
    if p.Character then add(p.Character)end
    p.CharacterAdded:Connect(add)
end
for _,p in ipairs(Players:GetPlayers())do setup(p)end
Players.PlayerAdded:Connect(setup)
Players.PlayerRemoving:Connect(cleanup)
UIS.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode==KEY_T then
        highlightOn=not highlightOn
        for _,h in pairs(highlights)do if h then h.Enabled=highlightOn end end
    elseif i.KeyCode==KEY_R then
        aimOn=not aimOn
        target=aimOn and(function()
            local mouse,closest,min=UIS:GetMouseLocation(),nil,AIM_FOV
            for _,plr in ipairs(Players:GetPlayers())do
                local ch=plr.Character if plr~=lp and ch and ch:FindFirstChild("Head")then
                    local pos,onScreen=cam:WorldToViewportPoint(ch.Head.Position)
                    if onScreen then
                        local d=(Vector2.new(pos.X,pos.Y)-mouse).Magnitude
                        if d<min then closest,min=plr,d end
                    end
                end
            end
            return closest
        end)()or nil
        if not aimOn then lockColor=false end
    elseif i.KeyCode==KEY_G and aimOn and target then
        lockColor=not lockColor
        local h=highlights[target]
        if h then h.FillColor,h.OutlineColor=lockColor and LOCKED or AURA,lockColor and LOCKED or AURA end
    elseif i.KeyCode==KEY_C then
        aimPart=(aimPart=="Head")and"HumanoidRootPart"or"Head"
        print("Mira agora trava no: "..aimPart)
    end
end)
RS.RenderStepped:Connect(function()
    if aimOn and target and target.Character and target.Character:FindFirstChild(aimPart)then
        cam.CFrame=CFrame.new(cam.CFrame.Position,target.Character[aimPart].Position)
    end
end)
print("🟢 ZBLACK ESP/AIM carregado!")
print("T=ESP | R=Aim | G=Lock | C=Head/Body")
