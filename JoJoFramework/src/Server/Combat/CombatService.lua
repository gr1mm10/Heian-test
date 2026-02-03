--[[
    CombatService.lua
    THE SACRED FOUNDATION - Core Combat System

    DESIGN PHILOSOPHY:
    "If you delete Stands, Hamon, and Vampires from the game, the combat is still fun."

    All fights revolve around:
    - Spacing
    - Timing
    - Punishment

    No infinite combos. No button mashing. Defense and movement matter.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CombatConfig = require(script.Parent.Parent.Parent.Shared.Constants.CombatConfig)

local CombatService = {}
CombatService.__index = CombatService

-- ============================================================================
-- PLAYER COMBAT STATE MANAGEMENT
-- ============================================================================

local PlayerStates = {}

function CombatService.GetPlayerState(player: Player)
    if not PlayerStates[player] then
        PlayerStates[player] = {
            -- Health & Stamina
            Health = CombatConfig.Health.BaseHealth,
            MaxHealth = CombatConfig.Health.BaseHealth,
            Stamina = CombatConfig.Stamina.MaxStamina,
            MaxStamina = CombatConfig.Stamina.MaxStamina,

            -- Combat State
            State = "Idle",
            IsBlocking = false,
            IsPerfectBlocking = false,
            IsExhausted = false,

            -- Combo Tracking (Anti-Infinite)
            ComboHits = 0,
            ComboStartTime = 0,
            ComboDamageDealt = 0,
            CurrentScaling = 1.0,

            -- Cooldowns
            DashCooldown = 0,
            SidestepCooldown = 0,
            BurstCooldown = 0,
            TechCooldown = 0,
            GrabCooldown = 0,

            -- Timing Windows
            PerfectBlockWindowStart = 0,
            ChainWindowEnd = 0,
            FinisherWindowEnd = 0,

            -- Input Buffer
            InputBuffer = {},

            -- Stamina Regen Tracking
            LastStaminaUseTime = 0,

            -- Health Regen Tracking
            LastDamageTime = 0,

            -- Attack Chain Tracking
            LightChainCount = 0,

            -- Manifestation references (set by ManifestationService)
            Manifestations = {},
        }
    end
    return PlayerStates[player]
end

function CombatService.ClearPlayerState(player: Player)
    PlayerStates[player] = nil
end

-- ============================================================================
-- STAMINA SYSTEM
-- ============================================================================

function CombatService.ConsumeStamina(player: Player, amount: number): boolean
    local state = CombatService.GetPlayerState(player)

    if state.IsExhausted then
        return false
    end

    if state.Stamina < amount then
        -- Enter exhaustion
        CombatService.EnterExhaustion(player)
        return false
    end

    state.Stamina = state.Stamina - amount
    state.LastStaminaUseTime = tick()

    -- Check for exhaustion threshold
    if state.Stamina <= 0 then
        CombatService.EnterExhaustion(player)
    end

    return true
end

function CombatService.EnterExhaustion(player: Player)
    local state = CombatService.GetPlayerState(player)
    state.IsExhausted = true
    state.State = "Exhausted"

    -- Schedule recovery
    task.delay(CombatConfig.Stamina.Exhaustion.Duration, function()
        if PlayerStates[player] then
            state.IsExhausted = false
            state.Stamina = 20  -- Recover some stamina
            if state.State == "Exhausted" then
                state.State = "Idle"
            end
        end
    end)
end

function CombatService.RegenerateStamina(player: Player, deltaTime: number)
    local state = CombatService.GetPlayerState(player)

    if state.IsExhausted then return end

    local timeSinceUse = tick() - state.LastStaminaUseTime
    if timeSinceUse >= CombatConfig.Stamina.RegenDelay then
        state.Stamina = math.min(
            state.MaxStamina,
            state.Stamina + (CombatConfig.Stamina.RegenRate * deltaTime)
        )
    end
end

-- ============================================================================
-- HEALTH SYSTEM
-- ============================================================================

function CombatService.TakeDamage(player: Player, hitData: table): number
    local state = CombatService.GetPlayerState(player)

    -- Apply combo scaling
    local scaledDamage = hitData.Damage * CombatService.GetComboScaling(hitData.ComboHitNumber)

    -- Apply counter hit bonus
    if hitData.IsCounterHit then
        scaledDamage = scaledDamage * CombatConfig.Damage.CounterHitMultiplier
    end

    -- Apply exhaustion vulnerability
    if state.IsExhausted then
        scaledDamage = scaledDamage * CombatConfig.Stamina.Exhaustion.DamageTakenMultiplier
    end

    -- Apply manifestation modifiers (hook for Hamon/Vampire/Stand interactions)
    scaledDamage = CombatService.ApplyManifestationDamageModifiers(player, hitData, scaledDamage)

    -- Deal damage
    state.Health = math.max(0, state.Health - scaledDamage)
    state.LastDamageTime = tick()

    -- Fire damage event
    CombatService.FireEvent("DamageDealt", {
        Target = player,
        Attacker = hitData.Attacker,
        Damage = scaledDamage,
        RawDamage = hitData.Damage,
        AttackType = hitData.AttackType,
        IsCounterHit = hitData.IsCounterHit,
    })

    -- Check for death
    if state.Health <= 0 then
        CombatService.HandleDeath(player, hitData.Attacker)
    end

    return scaledDamage
end

function CombatService.Heal(player: Player, amount: number)
    local state = CombatService.GetPlayerState(player)
    state.Health = math.min(state.MaxHealth, state.Health + amount)
end

function CombatService.RegenerateHealth(player: Player, deltaTime: number)
    local state = CombatService.GetPlayerState(player)

    local timeSinceDamage = tick() - state.LastDamageTime
    if timeSinceDamage >= CombatConfig.Health.OutOfCombatDelay then
        CombatService.Heal(player, CombatConfig.Health.RegenRate * deltaTime)
    end
end

-- ============================================================================
-- COMBO SCALING (ANTI-INFINITE SYSTEM)
-- ============================================================================

function CombatService.GetComboScaling(hitNumber: number): number
    local scaling = CombatConfig.Damage.ComboScaling

    if hitNumber == 1 then return scaling.Hit1 end
    if hitNumber == 2 then return scaling.Hit2 end
    if hitNumber == 3 then return scaling.Hit3 end
    if hitNumber == 4 then return scaling.Hit4 end
    return scaling.Hit5Plus
end

function CombatService.IncrementCombo(attacker: Player, target: Player)
    local attackerState = CombatService.GetPlayerState(attacker)
    local targetState = CombatService.GetPlayerState(target)

    attackerState.ComboHits = attackerState.ComboHits + 1

    -- Force combo drop if max hits reached (anti-infinite)
    if attackerState.ComboHits >= CombatConfig.ComboRules.MaxComboHits then
        CombatService.ForceComboReset(attacker, target)
    end
end

function CombatService.ForceComboReset(attacker: Player, target: Player)
    local attackerState = CombatService.GetPlayerState(attacker)

    -- Reset attacker combo
    attackerState.ComboHits = 0
    attackerState.ComboStartTime = 0
    attackerState.ComboDamageDealt = 0

    -- Give target brief immunity / tech opportunity
    local targetState = CombatService.GetPlayerState(target)
    targetState.State = "TechRecovery"

    task.delay(CombatConfig.ComboRules.TechWindow, function()
        if PlayerStates[target] and targetState.State == "TechRecovery" then
            targetState.State = "Idle"
        end
    end)
end

function CombatService.ResetCombo(attacker: Player)
    local state = CombatService.GetPlayerState(attacker)
    state.ComboHits = 0
    state.ComboStartTime = 0
    state.ComboDamageDealt = 0
    state.CurrentScaling = 1.0
end

-- ============================================================================
-- ATTACK SYSTEM
-- ============================================================================

function CombatService.CanAttack(player: Player, attackType: string): boolean
    local state = CombatService.GetPlayerState(player)

    -- Can't attack in certain states
    local invalidStates = {
        "Stunned", "Knockdown", "GrabbedBy", "Exhausted", "TechRecovery"
    }

    for _, invalidState in ipairs(invalidStates) do
        if state.State == invalidState then
            return false
        end
    end

    -- Check stamina
    local staminaCost = CombatConfig.Stamina.Costs[attackType] or 0
    if state.Stamina < staminaCost then
        return false
    end

    return true
end

function CombatService.ExecuteLight(player: Player, targetPosition: Vector3?)
    if not CombatService.CanAttack(player, "LightAttack") then
        return false
    end

    local state = CombatService.GetPlayerState(player)
    local config = CombatConfig.Timings.LightAttack

    -- Check chain limit (anti-infinite)
    if state.LightChainCount >= config.MaxChainLength then
        state.LightChainCount = 0
        return false
    end

    -- Consume stamina
    if not CombatService.ConsumeStamina(player, CombatConfig.Stamina.Costs.LightAttack) then
        return false
    end

    -- Set state
    state.State = "Attacking"
    state.LightChainCount = state.LightChainCount + 1

    -- Schedule hitbox activation
    task.delay(config.Startup, function()
        if PlayerStates[player] and state.State == "Attacking" then
            local hits = CombatService.CreateHitbox(player, "Light", CombatConfig.Hitboxes.Light)
            CombatService.ProcessHits(player, hits, "Light")
        end
    end)

    -- Schedule recovery
    task.delay(config.Startup + config.Active, function()
        if PlayerStates[player] then
            state.ChainWindowEnd = tick() + config.ChainWindow

            -- If no chain input, reset
            task.delay(config.ChainWindow + config.Recovery, function()
                if PlayerStates[player] and state.State == "Attacking" then
                    state.State = "Idle"
                    state.LightChainCount = 0
                end
            end)
        end
    end)

    return true
end

function CombatService.ExecuteHeavy(player: Player, chargeTime: number?)
    if not CombatService.CanAttack(player, "HeavyAttack") then
        return false
    end

    local state = CombatService.GetPlayerState(player)
    local config = CombatConfig.Timings.HeavyAttack

    -- Consume stamina
    if not CombatService.ConsumeStamina(player, CombatConfig.Stamina.Costs.HeavyAttack) then
        return false
    end

    -- Reset light chain
    state.LightChainCount = 0

    -- Set state
    state.State = "Attacking"

    -- Calculate charge bonus
    local chargeMultiplier = 1.0
    if chargeTime and chargeTime >= config.ChargeTime then
        chargeMultiplier = 1.3  -- 30% bonus for full charge
    end

    -- Schedule hitbox
    task.delay(config.Startup, function()
        if PlayerStates[player] and state.State == "Attacking" then
            local hits = CombatService.CreateHitbox(player, "Heavy", CombatConfig.Hitboxes.Heavy)
            CombatService.ProcessHits(player, hits, "Heavy", chargeMultiplier)
        end
    end)

    -- Schedule recovery (punishable!)
    task.delay(config.Startup + config.Active + config.Recovery, function()
        if PlayerStates[player] and state.State == "Attacking" then
            state.State = "Idle"
        end
    end)

    return true
end

function CombatService.ExecuteGrab(player: Player)
    if not CombatService.CanAttack(player, "Grab") then
        return false
    end

    local state = CombatService.GetPlayerState(player)
    local config = CombatConfig.Timings.Grab

    -- Check cooldown
    if state.GrabCooldown > tick() then
        return false
    end

    -- Consume stamina
    if not CombatService.ConsumeStamina(player, CombatConfig.Stamina.Costs.Grab) then
        return false
    end

    state.State = "Grabbing"

    -- Schedule grab attempt
    task.delay(config.Startup, function()
        if not PlayerStates[player] or state.State ~= "Grabbing" then
            return
        end

        local hits = CombatService.CreateHitbox(player, "Grab", CombatConfig.Hitboxes.Grab)

        if #hits > 0 then
            local target = hits[1]  -- Grab first valid target
            CombatService.ExecuteGrabSuccess(player, target)
        else
            -- Whiff - very punishable!
            CombatService.ExecuteGrabWhiff(player)
        end
    end)

    return true
end

function CombatService.ExecuteGrabSuccess(attacker: Player, target: Player)
    local attackerState = CombatService.GetPlayerState(attacker)
    local targetState = CombatService.GetPlayerState(target)

    -- Check if target is blocking (grabs beat block)
    -- Check if target is in ungrabbable state
    local ungrabbableStates = { "Dashing", "Sidestepping", "GrabbedBy", "Knockdown" }
    for _, invalidState in ipairs(ungrabbableStates) do
        if targetState.State == invalidState then
            CombatService.ExecuteGrabWhiff(attacker)
            return
        end
    end

    -- Successful grab
    targetState.State = "GrabbedBy"
    attackerState.State = "Grabbing"

    -- Execute throw after duration
    task.delay(CombatConfig.Timings.Grab.ThrowDuration, function()
        if PlayerStates[attacker] and PlayerStates[target] then
            -- Deal damage
            CombatService.TakeDamage(target, {
                Attacker = attacker,
                Damage = CombatConfig.Damage.GrabThrow,
                AttackType = "Grab",
                HitPosition = target.Character and target.Character.HumanoidRootPart.Position or Vector3.zero,
                IsCounterHit = false,
                ComboHitNumber = attackerState.ComboHits + 1,
            })

            CombatService.IncrementCombo(attacker, target)

            -- Apply knockdown
            targetState.State = "Knockdown"
            attackerState.State = "Idle"

            -- Knockdown recovery
            task.delay(CombatConfig.Timings.Knockdown.Duration, function()
                if PlayerStates[target] and targetState.State == "Knockdown" then
                    targetState.State = "Idle"
                end
            end)
        end
    end)
end

function CombatService.ExecuteGrabWhiff(player: Player)
    local state = CombatService.GetPlayerState(player)
    local config = CombatConfig.Timings.Grab

    state.State = "Attacking"  -- In recovery, vulnerable

    -- Very punishable recovery
    task.delay(config.WhiffRecovery, function()
        if PlayerStates[player] and state.State == "Attacking" then
            state.State = "Idle"
        end
    end)

    state.GrabCooldown = tick() + 1.0  -- Brief cooldown
end

-- ============================================================================
-- BLOCK SYSTEM
-- ============================================================================

function CombatService.StartBlock(player: Player)
    local state = CombatService.GetPlayerState(player)

    if state.State ~= "Idle" and state.State ~= "Blocking" then
        return false
    end

    state.State = "Blocking"
    state.IsBlocking = true
    state.PerfectBlockWindowStart = tick()

    return true
end

function CombatService.EndBlock(player: Player)
    local state = CombatService.GetPlayerState(player)

    state.IsBlocking = false
    state.IsPerfectBlocking = false

    if state.State == "Blocking" or state.State == "PerfectBlocking" then
        state.State = "Idle"
    end
end

function CombatService.CheckBlock(defender: Player, attackType: string): table
    local state = CombatService.GetPlayerState(defender)
    local config = CombatConfig.Timings.Block

    local result = {
        Blocked = false,
        PerfectBlock = false,
        ChipDamage = 0,
        Blockstun = 0,
        CounterWindowOpen = false,
    }

    if not state.IsBlocking then
        return result
    end

    -- Check for perfect block timing
    local timeSinceBlockStart = tick() - state.PerfectBlockWindowStart
    local isPerfect = timeSinceBlockStart <= config.PerfectBlockWindow

    result.Blocked = true
    result.PerfectBlock = isPerfect

    if isPerfect then
        -- Perfect block: no chip, counter opportunity
        result.ChipDamage = 0
        result.Blockstun = 0
        result.CounterWindowOpen = true
        state.IsPerfectBlocking = true
    else
        -- Normal block: chip damage, blockstun
        local baseDamage = attackType == "Heavy"
            and CombatConfig.Damage.Heavy
            or CombatConfig.Damage.Light

        result.ChipDamage = baseDamage * config.ChipDamagePercent
        result.Blockstun = attackType == "Heavy"
            and config.BlockstunHeavy
            or config.BlockstunLight
    end

    return result
end

-- ============================================================================
-- MOVEMENT SYSTEM
-- ============================================================================

function CombatService.ExecuteDash(player: Player, direction: Vector3)
    local state = CombatService.GetPlayerState(player)
    local config = CombatConfig.Timings.Dash

    -- Check cooldown
    if state.DashCooldown > tick() then
        return false
    end

    -- Check state
    if state.State == "Stunned" or state.State == "Knockdown" or state.State == "GrabbedBy" then
        return false
    end

    -- Consume stamina
    if not CombatService.ConsumeStamina(player, CombatConfig.Stamina.Costs.Dash) then
        return false
    end

    state.State = "Dashing"
    state.DashCooldown = tick() + config.Cooldown

    -- Apply dash velocity (client-side will handle actual movement)
    CombatService.FireEvent("DashStarted", {
        Player = player,
        Direction = direction,
        Duration = config.Duration,
        Speed = CombatConfig.Movement.DashSpeed,
        IFrameDuration = config.IFrames,
    })

    -- End dash state
    task.delay(config.Duration, function()
        if PlayerStates[player] and state.State == "Dashing" then
            state.State = "Idle"
        end
    end)

    return true
end

function CombatService.ExecuteSidestep(player: Player, direction: Vector3)
    local state = CombatService.GetPlayerState(player)
    local config = CombatConfig.Timings.Sidestep

    -- Check cooldown
    if state.SidestepCooldown > tick() then
        return false
    end

    -- Check state
    if state.State == "Stunned" or state.State == "Knockdown" or state.State == "GrabbedBy" then
        return false
    end

    -- Consume stamina
    if not CombatService.ConsumeStamina(player, CombatConfig.Stamina.Costs.Sidestep) then
        return false
    end

    state.State = "Sidestepping"
    state.SidestepCooldown = tick() + config.Cooldown

    CombatService.FireEvent("SidestepStarted", {
        Player = player,
        Direction = direction,
        Duration = config.Duration,
        Speed = CombatConfig.Movement.SidestepSpeed,
        IFrameDuration = config.IFrames,
    })

    task.delay(config.Duration, function()
        if PlayerStates[player] and state.State == "Sidestepping" then
            state.State = "Idle"
        end
    end)

    return true
end

-- ============================================================================
-- BURST SYSTEM (Combo Escape)
-- ============================================================================

function CombatService.ExecuteBurst(player: Player)
    local state = CombatService.GetPlayerState(player)
    local config = CombatConfig.ComboRules.Burst

    -- Check cooldown
    if state.BurstCooldown > tick() then
        return false
    end

    -- Check if in a state that can burst
    local burstableStates = { "Stunned", "GrabbedBy" }
    local canBurst = false
    for _, validState in ipairs(burstableStates) do
        if state.State == validState then
            canBurst = true
            break
        end
    end

    if not canBurst then
        return false
    end

    -- Check stamina
    if state.Stamina < config.StaminaCost then
        return false
    end

    -- Execute burst
    state.Stamina = state.Stamina - config.StaminaCost
    state.BurstCooldown = tick() + config.Cooldown
    state.State = "Idle"

    -- Push back nearby enemies
    CombatService.FireEvent("BurstExecuted", {
        Player = player,
        PushbackForce = config.PushbackForce,
    })

    return true
end

-- ============================================================================
-- FINISHER SYSTEM
-- ============================================================================

function CombatService.CanExecuteFinisher(player: Player, target: Player): boolean
    local attackerState = CombatService.GetPlayerState(player)
    local targetState = CombatService.GetPlayerState(target)

    -- Target must be in stagger/knockdown state
    if targetState.State ~= "Knockdown" and targetState.State ~= "Stunned" then
        return false
    end

    -- Check finisher window
    if targetState.FinisherWindowEnd and tick() > targetState.FinisherWindowEnd then
        return false
    end

    return true
end

function CombatService.ExecuteFinisher(player: Player, target: Player)
    if not CombatService.CanExecuteFinisher(player, target) then
        return false
    end

    local attackerState = CombatService.GetPlayerState(player)
    local targetState = CombatService.GetPlayerState(target)
    local config = CombatConfig.Timings.Finisher

    attackerState.State = "Attacking"
    targetState.State = "GrabbedBy"  -- Can't escape during finisher

    -- Execute finisher after animation
    task.delay(config.ExecutionTime, function()
        if PlayerStates[player] and PlayerStates[target] then
            CombatService.TakeDamage(target, {
                Attacker = player,
                Damage = CombatConfig.Damage.Finisher,
                AttackType = "Finisher",
                HitPosition = target.Character and target.Character.HumanoidRootPart.Position or Vector3.zero,
                IsCounterHit = false,
                ComboHitNumber = 1,  -- Finisher resets combo
            })

            -- Reset states
            attackerState.State = "Idle"
            targetState.State = "Knockdown"
            CombatService.ResetCombo(player)
        end
    end)

    return true
end

-- ============================================================================
-- HITBOX CREATION
-- ============================================================================

function CombatService.CreateHitbox(player: Player, attackType: string, hitboxConfig: table): { Player }
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return {}
    end

    local rootPart = character.HumanoidRootPart
    local hitboxCenter = rootPart.CFrame * CFrame.new(hitboxConfig.Offset)

    local hits = {}

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local otherChar = otherPlayer.Character
            if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
                local otherRoot = otherChar.HumanoidRootPart
                local distance = (otherRoot.Position - hitboxCenter.Position).Magnitude

                -- Simple sphere check (can be made more precise)
                local hitboxRadius = hitboxConfig.Size.Magnitude / 2
                if distance <= hitboxRadius then
                    table.insert(hits, otherPlayer)
                end
            end
        end
    end

    return hits
end

function CombatService.ProcessHits(attacker: Player, hits: { Player }, attackType: string, damageMultiplier: number?)
    local attackerState = CombatService.GetPlayerState(attacker)
    damageMultiplier = damageMultiplier or 1.0

    for _, target in ipairs(hits) do
        local targetState = CombatService.GetPlayerState(target)

        -- Check block
        local blockResult = CombatService.CheckBlock(target, attackType)

        if blockResult.Blocked then
            if blockResult.PerfectBlock then
                -- Perfect block - counter opportunity
                CombatService.FireEvent("PerfectBlock", {
                    Blocker = target,
                    Attacker = attacker,
                    AttackType = attackType,
                })

                -- Attacker is briefly vulnerable
                attackerState.State = "Stunned"
                task.delay(CombatConfig.Timings.Hitstun.Counter, function()
                    if PlayerStates[attacker] and attackerState.State == "Stunned" then
                        attackerState.State = "Idle"
                    end
                end)
            else
                -- Normal block - chip damage and blockstun
                if blockResult.ChipDamage > 0 then
                    CombatService.TakeDamage(target, {
                        Attacker = attacker,
                        Damage = blockResult.ChipDamage,
                        AttackType = attackType,
                        HitPosition = target.Character and target.Character.HumanoidRootPart.Position or Vector3.zero,
                        IsCounterHit = false,
                        ComboHitNumber = 0,  -- Chip doesn't count for combo
                    })
                end

                -- Apply blockstun
                task.delay(blockResult.Blockstun, function()
                    if PlayerStates[target] and targetState.State == "Blocking" then
                        -- Still blocking, recover
                    end
                end)
            end
        else
            -- Clean hit
            local baseDamage = attackType == "Heavy"
                and CombatConfig.Damage.Heavy
                or CombatConfig.Damage.Light

            -- Check for counter hit (hit during their attack startup)
            local isCounterHit = targetState.State == "Attacking"

            -- Apply damage
            local hitData = {
                Attacker = attacker,
                Damage = baseDamage * damageMultiplier,
                AttackType = attackType,
                HitPosition = target.Character and target.Character.HumanoidRootPart.Position or Vector3.zero,
                IsCounterHit = isCounterHit,
                ComboHitNumber = attackerState.ComboHits + 1,
            }

            CombatService.TakeDamage(target, hitData)
            CombatService.IncrementCombo(attacker, target)

            -- Apply hitstun
            targetState.State = "Stunned"
            local hitstun = isCounterHit
                and CombatConfig.Timings.Hitstun.Counter
                or (attackType == "Heavy" and CombatConfig.Timings.Hitstun.Heavy or CombatConfig.Timings.Hitstun.Light)

            -- Open finisher window on heavy hit stun
            if attackType == "Heavy" or isCounterHit then
                targetState.FinisherWindowEnd = tick() + CombatConfig.Timings.Finisher.ActivationWindow
            end

            task.delay(hitstun, function()
                if PlayerStates[target] and targetState.State == "Stunned" then
                    targetState.State = "Idle"
                end
            end)

            CombatService.FireEvent("HitLanded", {
                Attacker = attacker,
                Target = target,
                AttackType = attackType,
                IsCounterHit = isCounterHit,
                Damage = hitData.Damage,
            })
        end
    end
end

-- ============================================================================
-- MANIFESTATION HOOKS
-- ============================================================================

function CombatService.ApplyManifestationDamageModifiers(target: Player, hitData: table, damage: number): number
    -- This is a hook for the manifestation systems to modify damage
    -- Called by Hamon, Vampire, and Stand services
    local modifiedDamage = damage

    -- Get target's manifestations
    local state = CombatService.GetPlayerState(target)
    local manifestations = state.Manifestations or {}

    -- Apply each manifestation's damage modifiers
    for manifestationType, manifestationData in pairs(manifestations) do
        if manifestationData.DamageModifier then
            modifiedDamage = manifestationData.DamageModifier(hitData, modifiedDamage)
        end
    end

    return modifiedDamage
end

function CombatService.RegisterManifestationModifier(player: Player, manifestationType: string, modifierData: table)
    local state = CombatService.GetPlayerState(player)
    state.Manifestations[manifestationType] = modifierData
end

function CombatService.UnregisterManifestationModifier(player: Player, manifestationType: string)
    local state = CombatService.GetPlayerState(player)
    state.Manifestations[manifestationType] = nil
end

-- ============================================================================
-- DEATH HANDLING
-- ============================================================================

function CombatService.HandleDeath(player: Player, killer: Player?)
    local state = CombatService.GetPlayerState(player)

    state.State = "Dead"

    CombatService.FireEvent("PlayerDied", {
        Player = player,
        Killer = killer,
    })

    -- Respawn logic would be handled elsewhere
end

-- ============================================================================
-- EVENT SYSTEM
-- ============================================================================

local EventCallbacks = {}

function CombatService.OnEvent(eventName: string, callback: (data: table) -> ())
    if not EventCallbacks[eventName] then
        EventCallbacks[eventName] = {}
    end
    table.insert(EventCallbacks[eventName], callback)
end

function CombatService.FireEvent(eventName: string, data: table)
    local callbacks = EventCallbacks[eventName]
    if callbacks then
        for _, callback in ipairs(callbacks) do
            task.spawn(callback, data)
        end
    end
end

-- ============================================================================
-- INPUT BUFFER SYSTEM
-- ============================================================================

function CombatService.BufferInput(player: Player, inputType: string, direction: Vector3?)
    local state = CombatService.GetPlayerState(player)
    local config = CombatConfig.InputBuffer

    -- Clean old inputs
    local currentTime = tick()
    local validInputs = {}
    for _, input in ipairs(state.InputBuffer) do
        if currentTime - input.Timestamp <= config.BufferWindow then
            table.insert(validInputs, input)
        end
    end

    -- Add new input (respect max buffer)
    if #validInputs < config.MaxBufferedInputs then
        table.insert(validInputs, {
            InputType = inputType,
            Timestamp = currentTime,
            Direction = direction,
        })
    end

    state.InputBuffer = validInputs
end

function CombatService.ProcessBufferedInputs(player: Player)
    local state = CombatService.GetPlayerState(player)

    if state.State ~= "Idle" then
        return  -- Can only process buffer when idle
    end

    local currentTime = tick()
    local config = CombatConfig.InputBuffer

    for i, input in ipairs(state.InputBuffer) do
        if currentTime - input.Timestamp <= config.BufferWindow then
            -- Attempt to execute buffered input
            local success = false

            if input.InputType == "LightAttack" then
                success = CombatService.ExecuteLight(player)
            elseif input.InputType == "HeavyAttack" then
                success = CombatService.ExecuteHeavy(player)
            elseif input.InputType == "Dash" then
                success = CombatService.ExecuteDash(player, input.Direction or Vector3.new(0, 0, -1))
            elseif input.InputType == "Sidestep" then
                success = CombatService.ExecuteSidestep(player, input.Direction or Vector3.new(1, 0, 0))
            elseif input.InputType == "Grab" then
                success = CombatService.ExecuteGrab(player)
            elseif input.InputType == "Burst" then
                success = CombatService.ExecuteBurst(player)
            end

            if success then
                table.remove(state.InputBuffer, i)
                break
            end
        end
    end
end

-- ============================================================================
-- GAME LOOP INTEGRATION
-- ============================================================================

function CombatService.Update(deltaTime: number)
    for player, _ in pairs(PlayerStates) do
        if player.Parent then  -- Player still in game
            CombatService.RegenerateStamina(player, deltaTime)
            CombatService.RegenerateHealth(player, deltaTime)
            CombatService.ProcessBufferedInputs(player)
        else
            CombatService.ClearPlayerState(player)
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function CombatService.Initialize()
    -- Clean up player states on leave
    Players.PlayerRemoving:Connect(function(player)
        CombatService.ClearPlayerState(player)
    end)

    -- Initialize states for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        CombatService.GetPlayerState(player)
    end

    -- Initialize states for new players
    Players.PlayerAdded:Connect(function(player)
        CombatService.GetPlayerState(player)
    end)

    -- Start update loop
    RunService.Heartbeat:Connect(function(deltaTime)
        CombatService.Update(deltaTime)
    end)

    print("[CombatService] Initialized - The Sacred Foundation is ready")
end

return CombatService
