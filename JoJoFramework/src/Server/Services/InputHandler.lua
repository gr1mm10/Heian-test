--[[
    InputHandler.lua
    SERVER-SIDE INPUT VALIDATION AND ROUTING

    The server receives input requests from clients,
    validates them, and executes the appropriate actions.

    SECURITY: All combat actions are validated server-side.
    The client can only REQUEST actions, never execute them directly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Get references (Rojo structure)
-- script = InputHandler, script.Parent = Services, script.Parent.Parent = JoJoFramework
local JoJoFramework = script.Parent.Parent

local CombatService = require(JoJoFramework.Combat.CombatService)
local StandService = require(JoJoFramework.Manifestations.StandService)
local HamonService = require(JoJoFramework.Manifestations.HamonService)
local VampireService = require(JoJoFramework.Manifestations.VampireService)

local InputHandler = {}

-- ============================================================================
-- REMOTE CONNECTIONS
-- ============================================================================

function InputHandler.Initialize(remotesFolder: Folder)
    -- ===== COMBAT REMOTES =====

    remotesFolder.LightAttack.OnServerEvent:Connect(function(player, direction)
        if typeof(direction) ~= "Vector3" then
            direction = nil
        end
        CombatService.ExecuteLight(player, direction)
    end)

    remotesFolder.HeavyAttack.OnServerEvent:Connect(function(player, direction, chargeTime)
        if typeof(direction) ~= "Vector3" then
            direction = nil
        end
        if typeof(chargeTime) ~= "number" then
            chargeTime = 0
        end
        CombatService.ExecuteHeavy(player, math.min(chargeTime, 2))  -- Cap charge time
    end)

    remotesFolder.Block.OnServerEvent:Connect(function(player, isBlocking)
        if isBlocking then
            CombatService.StartBlock(player)
        else
            CombatService.EndBlock(player)
        end
    end)

    remotesFolder.Dash.OnServerEvent:Connect(function(player, direction)
        if typeof(direction) ~= "Vector3" then
            direction = Vector3.new(0, 0, -1)
        end
        CombatService.ExecuteDash(player, direction.Unit)
    end)

    remotesFolder.Sidestep.OnServerEvent:Connect(function(player, direction)
        if typeof(direction) ~= "Vector3" then
            direction = Vector3.new(1, 0, 0)
        end
        CombatService.ExecuteSidestep(player, direction.Unit)
    end)

    remotesFolder.Grab.OnServerEvent:Connect(function(player)
        CombatService.ExecuteGrab(player)
    end)

    remotesFolder.Burst.OnServerEvent:Connect(function(player)
        CombatService.ExecuteBurst(player)
    end)

    remotesFolder.Finisher.OnServerEvent:Connect(function(player, targetPlayer)
        if typeof(targetPlayer) ~= "Instance" or not targetPlayer:IsA("Player") then
            return
        end
        CombatService.ExecuteFinisher(player, targetPlayer)
    end)

    -- ===== STAND REMOTES =====

    remotesFolder.SummonStand.OnServerEvent:Connect(function(player)
        local standState = StandService.GetStandState(player)

        if standState.IsSummoned then
            StandService.DismissStand(player)
        else
            StandService.SummonStand(player)
        end
    end)

    remotesFolder.StandAbility.OnServerEvent:Connect(function(player, slot, targetData)
        local standState = StandService.GetStandState(player)

        if not standState.HasStand or not standState.StandData then
            return
        end

        local abilities = standState.StandData.Abilities
        if not abilities or not abilities[slot] then
            return
        end

        local ability = abilities[slot]

        -- Validate target data
        local validatedTarget = nil
        if targetData and typeof(targetData) == "table" then
            if targetData.Target and typeof(targetData.Target) == "Instance" and targetData.Target:IsA("Player") then
                validatedTarget = { Target = targetData.Target }
            end
        end

        StandService.UseAbility(player, ability.Name, validatedTarget)
    end)

    -- ===== HAMON REMOTES =====

    remotesFolder.StartBreathing.OnServerEvent:Connect(function(player)
        HamonService.StartBreathing(player)
    end)

    remotesFolder.StopBreathing.OnServerEvent:Connect(function(player)
        HamonService.StopBreathing(player)
    end)

    remotesFolder.HamonTechnique.OnServerEvent:Connect(function(player, slot, targetData)
        local hamonState = HamonService.GetHamonState(player)

        if not hamonState.HasHamon then
            return
        end

        -- Map slot to technique name
        local techniqueMap = {
            [1] = "ZoomPunch",
            [2] = "SendouWaveKick",
            [3] = "OverdriveBarrage",
        }

        local techniqueName = techniqueMap[slot]
        if not techniqueName then
            return
        end

        -- Validate target data
        local validatedTarget = nil
        if targetData and typeof(targetData) == "table" then
            if targetData.Target and typeof(targetData.Target) == "Instance" and targetData.Target:IsA("Player") then
                validatedTarget = { Target = targetData.Target }
            end
        end

        HamonService.UseTechnique(player, techniqueName, validatedTarget)
    end)

    -- ===== VAMPIRE REMOTES =====

    remotesFolder.VampireAbility.OnServerEvent:Connect(function(player, slot, targetData)
        local vampireState = VampireService.GetVampireState(player)

        if not vampireState.IsVampire then
            return
        end

        -- Map slot to ability name
        local abilityMap = {
            [1] = "VaporizationFreeze",
            [2] = "SpaceRipperStingyEyes",
            [3] = "RegenerationBurst",
        }

        local abilityName = abilityMap[slot]
        if not abilityName then
            return
        end

        -- Validate target data
        local validatedTarget = nil
        if targetData and typeof(targetData) == "table" then
            if targetData.Target and typeof(targetData.Target) == "Instance" and targetData.Target:IsA("Player") then
                validatedTarget = { Target = targetData.Target }
            end
        end

        VampireService.UseAbility(player, abilityName, validatedTarget)
    end)

    print("[InputHandler] All remote handlers connected")
end

-- ============================================================================
-- STATE BROADCASTING
-- ============================================================================

function InputHandler.BroadcastStateUpdate(player: Player, stateData: table)
    local remotesFolder = ReplicatedStorage:FindFirstChild("CombatRemotes")
    if not remotesFolder then return end

    local stateUpdateRemote = remotesFolder:FindFirstChild("StateUpdate")
    if stateUpdateRemote then
        stateUpdateRemote:FireClient(player, stateData)
    end
end

function InputHandler.BroadcastToAll(stateData: table)
    local remotesFolder = ReplicatedStorage:FindFirstChild("CombatRemotes")
    if not remotesFolder then return end

    local stateUpdateRemote = remotesFolder:FindFirstChild("StateUpdate")
    if stateUpdateRemote then
        stateUpdateRemote:FireAllClients(stateData)
    end
end

return InputHandler
