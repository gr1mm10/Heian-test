--[[
    JoJo Game Framework - Client Initialization
    ============================================

    Client-side systems:
    - Input handling
    - Visual feedback
    - UI updates
    - Animation control
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

print("[JoJoClient] Initializing...")

-- Wait for remotes to be created by server
local remotesFolder = ReplicatedStorage:WaitForChild("CombatRemotes", 30)
if not remotesFolder then
    warn("[JoJoClient] Failed to find CombatRemotes - server may not have initialized")
    return
end

-- ============================================================================
-- INITIALIZE CLIENT SYSTEMS
-- ============================================================================

local CombatController = require(script.Client.Combat.CombatController)
CombatController.Initialize()

-- ============================================================================
-- UI SETUP (Placeholder - implement actual UI)
-- ============================================================================

local function CreateSimpleUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "JoJoCombatUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Health bar (placeholder)
    local healthFrame = Instance.new("Frame")
    healthFrame.Name = "HealthBar"
    healthFrame.Size = UDim2.new(0, 200, 0, 20)
    healthFrame.Position = UDim2.new(0, 20, 1, -100)
    healthFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    healthFrame.Parent = screenGui

    local healthFill = Instance.new("Frame")
    healthFill.Name = "Fill"
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthFrame

    -- Stamina bar (placeholder)
    local staminaFrame = Instance.new("Frame")
    staminaFrame.Name = "StaminaBar"
    staminaFrame.Size = UDim2.new(0, 200, 0, 10)
    staminaFrame.Position = UDim2.new(0, 20, 1, -75)
    staminaFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    staminaFrame.Parent = screenGui

    local staminaFill = Instance.new("Frame")
    staminaFill.Name = "Fill"
    staminaFill.Size = UDim2.new(1, 0, 1, 0)
    staminaFill.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    staminaFill.BorderSizePixel = 0
    staminaFill.Parent = staminaFrame

    -- Resource bar (for Stand Energy / Hamon Breath / Vampire Blood)
    local resourceFrame = Instance.new("Frame")
    resourceFrame.Name = "ResourceBar"
    resourceFrame.Size = UDim2.new(0, 200, 0, 10)
    resourceFrame.Position = UDim2.new(0, 20, 1, -60)
    resourceFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    resourceFrame.Parent = screenGui

    local resourceFill = Instance.new("Frame")
    resourceFill.Name = "Fill"
    resourceFill.Size = UDim2.new(1, 0, 1, 0)
    resourceFill.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    resourceFill.BorderSizePixel = 0
    resourceFill.Parent = resourceFrame

    -- Controls hint
    local controlsLabel = Instance.new("TextLabel")
    controlsLabel.Name = "ControlsHint"
    controlsLabel.Size = UDim2.new(0, 300, 0, 150)
    controlsLabel.Position = UDim2.new(1, -320, 1, -170)
    controlsLabel.BackgroundTransparency = 0.5
    controlsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    controlsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    controlsLabel.TextSize = 12
    controlsLabel.Font = Enum.Font.Code
    controlsLabel.TextXAlignment = Enum.TextXAlignment.Left
    controlsLabel.TextYAlignment = Enum.TextYAlignment.Top
    controlsLabel.Text = [[
CONTROLS:
LMB - Light Attack
RMB (Hold) - Heavy Attack
F - Block
Q - Dash
E - Sidestep
G - Grab
B - Burst (escape)
T - Stand Summon
C - Hamon Breathe
Z/X/V - Abilities
Tab - Target Lock
]]
    controlsLabel.Parent = screenGui

    return screenGui
end

CreateSimpleUI()

-- ============================================================================
-- STATE SYNC HANDLING
-- ============================================================================

local function OnHealthUpdate(currentHealth: number, maxHealth: number)
    local ui = LocalPlayer:FindFirstChild("PlayerGui")
    if not ui then return end

    local jojoUI = ui:FindFirstChild("JoJoCombatUI")
    if not jojoUI then return end

    local healthBar = jojoUI:FindFirstChild("HealthBar")
    if healthBar then
        local fill = healthBar:FindFirstChild("Fill")
        if fill then
            fill.Size = UDim2.new(currentHealth / maxHealth, 0, 1, 0)
        end
    end
end

local function OnStaminaUpdate(currentStamina: number, maxStamina: number)
    local ui = LocalPlayer:FindFirstChild("PlayerGui")
    if not ui then return end

    local jojoUI = ui:FindFirstChild("JoJoCombatUI")
    if not jojoUI then return end

    local staminaBar = jojoUI:FindFirstChild("StaminaBar")
    if staminaBar then
        local fill = staminaBar:FindFirstChild("Fill")
        if fill then
            fill.Size = UDim2.new(currentStamina / maxStamina, 0, 1, 0)
        end
    end
end

local function OnResourceUpdate(current: number, max: number, resourceType: string)
    local ui = LocalPlayer:FindFirstChild("PlayerGui")
    if not ui then return end

    local jojoUI = ui:FindFirstChild("JoJoCombatUI")
    if not jojoUI then return end

    local resourceBar = jojoUI:FindFirstChild("ResourceBar")
    if resourceBar then
        local fill = resourceBar:FindFirstChild("Fill")
        if fill then
            fill.Size = UDim2.new(current / max, 0, 1, 0)

            -- Color based on type
            if resourceType == "Stand" then
                fill.BackgroundColor3 = Color3.fromRGB(150, 100, 255)  -- Purple
            elseif resourceType == "Hamon" then
                fill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)   -- Yellow/Gold
            elseif resourceType == "Vampire" then
                fill.BackgroundColor3 = Color3.fromRGB(200, 50, 50)    -- Red
            end
        end
    end
end

-- Connect to state updates
if remotesFolder:FindFirstChild("HealthUpdate") then
    remotesFolder.HealthUpdate.OnClientEvent:Connect(OnHealthUpdate)
end

if remotesFolder:FindFirstChild("StaminaUpdate") then
    remotesFolder.StaminaUpdate.OnClientEvent:Connect(OnStaminaUpdate)
end

if remotesFolder:FindFirstChild("ManifestationUpdate") then
    remotesFolder.ManifestationUpdate.OnClientEvent:Connect(OnResourceUpdate)
end

print("[JoJoClient] Client systems initialized!")
print("[JoJoClient] Ready to fight!")
