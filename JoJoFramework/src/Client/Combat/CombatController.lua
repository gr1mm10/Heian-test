--[[
    CombatController.lua
    CLIENT-SIDE COMBAT INPUT HANDLING

    Handles:
    - Input detection and buffering
    - Animation triggering
    - Visual feedback
    - Network communication with server

    The client REQUESTS actions, the server VALIDATES and EXECUTES them.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local CombatController = {}
CombatController.__index = CombatController

-- ============================================================================
-- INPUT CONFIGURATION
-- ============================================================================

CombatController.Keybinds = {
    -- Base Combat
    LightAttack = Enum.UserInputType.MouseButton1,
    HeavyAttack = Enum.UserInputType.MouseButton2,
    Block = Enum.KeyCode.F,
    Dash = Enum.KeyCode.Q,
    Sidestep = Enum.KeyCode.E,
    Grab = Enum.KeyCode.G,
    Burst = Enum.KeyCode.B,

    -- Manifestation Controls
    SummonStand = Enum.KeyCode.T,
    StandAbility1 = Enum.KeyCode.R,
    StandAbility2 = Enum.KeyCode.Y,
    StandAbility3 = Enum.KeyCode.U,

    HamonBreathe = Enum.KeyCode.C,
    HamonTechnique1 = Enum.KeyCode.Z,
    HamonTechnique2 = Enum.KeyCode.X,
    HamonTechnique3 = Enum.KeyCode.V,

    VampireAbility1 = Enum.KeyCode.Z,
    VampireAbility2 = Enum.KeyCode.X,
    VampireAbility3 = Enum.KeyCode.V,

    -- Utility
    Lock = Enum.KeyCode.Tab,
}

-- ============================================================================
-- STATE
-- ============================================================================

local CurrentState = {
    IsBlocking = false,
    IsBreathing = false,
    TargetLock = nil,
    InputBuffer = {},
    LastInputTime = 0,
    HeavyChargeStart = nil,
}

-- ============================================================================
-- REMOTE EVENTS
-- ============================================================================

local CombatRemotes = {}

function CombatController.SetupRemotes()
    -- Wait for remotes folder
    local remotesFolder = ReplicatedStorage:WaitForChild("CombatRemotes", 10)

    if not remotesFolder then
        warn("[CombatController] CombatRemotes folder not found - creating client-side stubs")
        return
    end

    CombatRemotes = {
        -- Combat actions
        LightAttack = remotesFolder:WaitForChild("LightAttack"),
        HeavyAttack = remotesFolder:WaitForChild("HeavyAttack"),
        Block = remotesFolder:WaitForChild("Block"),
        Dash = remotesFolder:WaitForChild("Dash"),
        Sidestep = remotesFolder:WaitForChild("Sidestep"),
        Grab = remotesFolder:WaitForChild("Grab"),
        Burst = remotesFolder:WaitForChild("Burst"),
        Finisher = remotesFolder:WaitForChild("Finisher"),

        -- Stand actions
        SummonStand = remotesFolder:WaitForChild("SummonStand"),
        DismissStand = remotesFolder:WaitForChild("DismissStand"),
        StandAbility = remotesFolder:WaitForChild("StandAbility"),

        -- Hamon actions
        StartBreathing = remotesFolder:WaitForChild("StartBreathing"),
        StopBreathing = remotesFolder:WaitForChild("StopBreathing"),
        HamonTechnique = remotesFolder:WaitForChild("HamonTechnique"),

        -- Vampire actions
        VampireAbility = remotesFolder:WaitForChild("VampireAbility"),

        -- State sync
        StateUpdate = remotesFolder:WaitForChild("StateUpdate"),
    }
end

-- ============================================================================
-- INPUT HANDLING
-- ============================================================================

function CombatController.HandleInput(input: InputObject, gameProcessed: boolean)
    if gameProcessed then
        return  -- Ignore if typing in chat etc.
    end

    local keyCode = input.KeyCode
    local inputType = input.UserInputType
    local keybinds = CombatController.Keybinds

    -- ===== LIGHT ATTACK =====
    if inputType == keybinds.LightAttack then
        CombatController.RequestLightAttack()

    -- ===== HEAVY ATTACK START =====
    elseif inputType == keybinds.HeavyAttack then
        CurrentState.HeavyChargeStart = tick()

    -- ===== BLOCK START =====
    elseif keyCode == keybinds.Block then
        CombatController.RequestBlockStart()

    -- ===== DASH =====
    elseif keyCode == keybinds.Dash then
        CombatController.RequestDash()

    -- ===== SIDESTEP =====
    elseif keyCode == keybinds.Sidestep then
        CombatController.RequestSidestep()

    -- ===== GRAB =====
    elseif keyCode == keybinds.Grab then
        CombatController.RequestGrab()

    -- ===== BURST =====
    elseif keyCode == keybinds.Burst then
        CombatController.RequestBurst()

    -- ===== STAND SUMMON =====
    elseif keyCode == keybinds.SummonStand then
        CombatController.ToggleStand()

    -- ===== STAND ABILITIES =====
    elseif keyCode == keybinds.StandAbility1 then
        CombatController.RequestStandAbility(1)
    elseif keyCode == keybinds.StandAbility2 then
        CombatController.RequestStandAbility(2)
    elseif keyCode == keybinds.StandAbility3 then
        CombatController.RequestStandAbility(3)

    -- ===== HAMON BREATHING =====
    elseif keyCode == keybinds.HamonBreathe then
        CombatController.ToggleBreathing()

    -- ===== HAMON TECHNIQUES =====
    elseif keyCode == keybinds.HamonTechnique1 then
        CombatController.RequestHamonTechnique(1)
    elseif keyCode == keybinds.HamonTechnique2 then
        CombatController.RequestHamonTechnique(2)
    elseif keyCode == keybinds.HamonTechnique3 then
        CombatController.RequestHamonTechnique(3)

    -- ===== VAMPIRE ABILITIES =====
    elseif keyCode == keybinds.VampireAbility1 then
        CombatController.RequestVampireAbility(1)
    elseif keyCode == keybinds.VampireAbility2 then
        CombatController.RequestVampireAbility(2)
    elseif keyCode == keybinds.VampireAbility3 then
        CombatController.RequestVampireAbility(3)

    -- ===== TARGET LOCK =====
    elseif keyCode == keybinds.Lock then
        CombatController.ToggleTargetLock()
    end
end

function CombatController.HandleInputEnd(input: InputObject, gameProcessed: boolean)
    if gameProcessed then
        return
    end

    local keyCode = input.KeyCode
    local inputType = input.UserInputType
    local keybinds = CombatController.Keybinds

    -- ===== HEAVY ATTACK RELEASE =====
    if inputType == keybinds.HeavyAttack then
        if CurrentState.HeavyChargeStart then
            local chargeTime = tick() - CurrentState.HeavyChargeStart
            CombatController.RequestHeavyAttack(chargeTime)
            CurrentState.HeavyChargeStart = nil
        end

    -- ===== BLOCK END =====
    elseif keyCode == keybinds.Block then
        CombatController.RequestBlockEnd()

    -- ===== BREATHING END =====
    elseif keyCode == keybinds.HamonBreathe then
        if CurrentState.IsBreathing then
            CombatController.RequestBreathingStop()
        end
    end
end

-- ============================================================================
-- COMBAT ACTION REQUESTS
-- ============================================================================

function CombatController.RequestLightAttack()
    local direction = CombatController.GetAimDirection()

    if CombatRemotes.LightAttack then
        CombatRemotes.LightAttack:FireServer(direction)
    end

    CombatController.BufferInput("LightAttack", direction)
end

function CombatController.RequestHeavyAttack(chargeTime: number)
    local direction = CombatController.GetAimDirection()

    if CombatRemotes.HeavyAttack then
        CombatRemotes.HeavyAttack:FireServer(direction, chargeTime)
    end

    CombatController.BufferInput("HeavyAttack", direction)
end

function CombatController.RequestBlockStart()
    CurrentState.IsBlocking = true

    if CombatRemotes.Block then
        CombatRemotes.Block:FireServer(true)
    end
end

function CombatController.RequestBlockEnd()
    CurrentState.IsBlocking = false

    if CombatRemotes.Block then
        CombatRemotes.Block:FireServer(false)
    end
end

function CombatController.RequestDash()
    local direction = CombatController.GetMoveDirection()

    if CombatRemotes.Dash then
        CombatRemotes.Dash:FireServer(direction)
    end

    CombatController.BufferInput("Dash", direction)
end

function CombatController.RequestSidestep()
    local direction = CombatController.GetSidestepDirection()

    if CombatRemotes.Sidestep then
        CombatRemotes.Sidestep:FireServer(direction)
    end

    CombatController.BufferInput("Sidestep", direction)
end

function CombatController.RequestGrab()
    if CombatRemotes.Grab then
        CombatRemotes.Grab:FireServer()
    end
end

function CombatController.RequestBurst()
    if CombatRemotes.Burst then
        CombatRemotes.Burst:FireServer()
    end
end

-- ============================================================================
-- STAND ACTION REQUESTS
-- ============================================================================

function CombatController.ToggleStand()
    if CombatRemotes.SummonStand then
        CombatRemotes.SummonStand:FireServer()
    end
end

function CombatController.RequestStandAbility(slot: number)
    if CombatRemotes.StandAbility then
        local targetData = CombatController.GetTargetData()
        CombatRemotes.StandAbility:FireServer(slot, targetData)
    end
end

-- ============================================================================
-- HAMON ACTION REQUESTS
-- ============================================================================

function CombatController.ToggleBreathing()
    if not CurrentState.IsBreathing then
        CombatController.RequestBreathingStart()
    else
        CombatController.RequestBreathingStop()
    end
end

function CombatController.RequestBreathingStart()
    CurrentState.IsBreathing = true

    if CombatRemotes.StartBreathing then
        CombatRemotes.StartBreathing:FireServer()
    end
end

function CombatController.RequestBreathingStop()
    CurrentState.IsBreathing = false

    if CombatRemotes.StopBreathing then
        CombatRemotes.StopBreathing:FireServer()
    end
end

function CombatController.RequestHamonTechnique(slot: number)
    if CombatRemotes.HamonTechnique then
        local targetData = CombatController.GetTargetData()
        CombatRemotes.HamonTechnique:FireServer(slot, targetData)
    end
end

-- ============================================================================
-- VAMPIRE ACTION REQUESTS
-- ============================================================================

function CombatController.RequestVampireAbility(slot: number)
    if CombatRemotes.VampireAbility then
        local targetData = CombatController.GetTargetData()
        CombatRemotes.VampireAbility:FireServer(slot, targetData)
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function CombatController.GetAimDirection(): Vector3
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return Vector3.new(0, 0, -1)
    end

    local camera = workspace.CurrentCamera
    if camera then
        return camera.CFrame.LookVector
    end

    return character.HumanoidRootPart.CFrame.LookVector
end

function CombatController.GetMoveDirection(): Vector3
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("Humanoid") then
        return Vector3.new(0, 0, -1)
    end

    local humanoid = character.Humanoid
    local moveDirection = humanoid.MoveDirection

    if moveDirection.Magnitude > 0.1 then
        return moveDirection.Unit
    end

    return CombatController.GetAimDirection()
end

function CombatController.GetSidestepDirection(): Vector3
    local aimDir = CombatController.GetAimDirection()

    -- Default to right sidestep, can be modified based on input
    local rightVector = aimDir:Cross(Vector3.new(0, 1, 0)).Unit
    return rightVector
end

function CombatController.GetTargetData(): table?
    if CurrentState.TargetLock then
        return {
            Target = CurrentState.TargetLock,
            Position = CurrentState.TargetLock.Character and
                CurrentState.TargetLock.Character:FindFirstChild("HumanoidRootPart") and
                CurrentState.TargetLock.Character.HumanoidRootPart.Position or nil,
        }
    end
    return nil
end

function CombatController.ToggleTargetLock()
    if CurrentState.TargetLock then
        CurrentState.TargetLock = nil
        return
    end

    -- Find nearest enemy
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return
    end

    local myPosition = character.HumanoidRootPart.Position
    local nearestPlayer = nil
    local nearestDistance = 50  -- Max lock range

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local otherChar = player.Character
            if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
                local distance = (otherChar.HumanoidRootPart.Position - myPosition).Magnitude
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestPlayer = player
                end
            end
        end
    end

    CurrentState.TargetLock = nearestPlayer
end

-- ============================================================================
-- INPUT BUFFER
-- ============================================================================

function CombatController.BufferInput(inputType: string, direction: Vector3?)
    local bufferEntry = {
        Type = inputType,
        Direction = direction,
        Time = tick(),
    }

    table.insert(CurrentState.InputBuffer, bufferEntry)

    -- Clean old entries
    local cleanedBuffer = {}
    for _, entry in ipairs(CurrentState.InputBuffer) do
        if tick() - entry.Time < 0.15 then  -- 150ms buffer window
            table.insert(cleanedBuffer, entry)
        end
    end
    CurrentState.InputBuffer = cleanedBuffer
end

-- ============================================================================
-- STATE SYNC (Receive server updates)
-- ============================================================================

function CombatController.OnStateUpdate(stateData: table)
    -- Update local state based on server response
    -- This would handle things like:
    -- - Confirming attack execution
    -- - Syncing health/stamina display
    -- - Animation triggers

    if stateData.AnimationTrigger then
        CombatController.PlayAnimation(stateData.AnimationTrigger)
    end

    if stateData.Effect then
        CombatController.PlayEffect(stateData.Effect)
    end
end

-- ============================================================================
-- ANIMATION HANDLING
-- ============================================================================

function CombatController.PlayAnimation(animationId: string)
    local character = LocalPlayer.Character
    if not character then return end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end

    local animator = humanoid:FindFirstChild("Animator")
    if not animator then return end

    -- Animation loading would happen here
    -- For now, just log
    print("[CombatController] Would play animation:", animationId)
end

function CombatController.PlayEffect(effectData: table)
    -- Visual effects would be spawned here
    print("[CombatController] Would play effect:", effectData.Name or "Unknown")
end

-- ============================================================================
-- UPDATE LOOP
-- ============================================================================

function CombatController.Update(deltaTime: number)
    -- Handle continuous inputs (like holding block)

    -- Update target lock indicator
    if CurrentState.TargetLock then
        -- Visual indicator would be updated here
    end

    -- Process buffered inputs if in valid state
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function CombatController.Initialize()
    -- Setup remotes
    CombatController.SetupRemotes()

    -- Connect input events
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        CombatController.HandleInput(input, gameProcessed)
    end)

    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        CombatController.HandleInputEnd(input, gameProcessed)
    end)

    -- Connect state sync
    if CombatRemotes.StateUpdate then
        CombatRemotes.StateUpdate.OnClientEvent:Connect(function(stateData)
            CombatController.OnStateUpdate(stateData)
        end)
    end

    -- Update loop
    RunService.RenderStepped:Connect(function(deltaTime)
        CombatController.Update(deltaTime)
    end)

    print("[CombatController] Client combat system initialized")
    print("Controls:")
    print("  LMB - Light Attack")
    print("  RMB (Hold) - Heavy Attack (charge for more damage)")
    print("  F - Block")
    print("  Q - Dash")
    print("  E - Sidestep")
    print("  G - Grab")
    print("  B - Burst (escape combos)")
    print("  T - Summon/Dismiss Stand")
    print("  C - Hamon Breathing")
    print("  Tab - Target Lock")
end

return CombatController
