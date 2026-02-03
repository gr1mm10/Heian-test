--[[
    HamonService.lua
    HAMON - MANIFESTATION OF BREATH & DISCIPLINE

    DESIGN PHILOSOPHY:
    Hamon does NOT summon anything. It flows through base combat.

    Hamon rewards:
    - Precision
    - Timing
    - Defensive mastery

    Hamon users feel: clean, technical, deadly - NOT flashy.

    How Hamon Extends Combat:
    - Light attacks gain sunlight properties
    - Perfect blocks trigger counter shocks
    - Grabs become nerve-locks
    - Finishers deal bonus damage to Vampires & Stands
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Get references (Rojo structure)
local ServerFolder = script.Parent.Parent
local SharedFolder = ReplicatedStorage:WaitForChild("JoJoFramework"):WaitForChild("Shared")

local CombatService = require(ServerFolder.Combat.CombatService)
local ManifestationConfig = require(SharedFolder.Constants.ManifestationConfig)

local HamonService = {}
HamonService.__index = HamonService

-- ============================================================================
-- HAMON TECHNIQUE REGISTRY
-- ============================================================================

HamonService.TechniqueRegistry = {
    -- Zoom Punch - Extended reach attack
    ZoomPunch = {
        Name = "Zoom Punch",
        Description = "Dislocate arm to extend punch range",
        BreathCost = 25,
        Cooldown = 4.0,
        Damage = 12,
        RangeMultiplier = 2.0,
        Startup = 0.25,
        Recovery = 0.35,
        RequiresMastery = 10,
    },

    -- Sendou Wave Kick
    SendouWaveKick = {
        Name = "Sendou Wave Kick",
        Description = "Powerful kick infused with Hamon",
        BreathCost = 30,
        Cooldown = 5.0,
        Damage = 18,
        Knockback = 25,
        Startup = 0.3,
        Recovery = 0.4,
        RequiresMastery = 20,
    },

    -- Overdrive Barrage
    OverdriveBarrage = {
        Name = "Overdrive Barrage",
        Description = "Rapid Hamon-infused strikes",
        BreathCost = 50,
        Cooldown = 8.0,
        Duration = 1.5,
        HitsPerSecond = 6,
        DamagePerHit = 4,
        Startup = 0.2,
        RequiresMastery = 35,
    },

    -- Sunlight Yellow Overdrive
    SunlightYellowOverdrive = {
        Name = "Sunlight Yellow Overdrive",
        Description = "Concentrated sunlight energy strike",
        BreathCost = 60,
        Cooldown = 12.0,
        Damage = 30,
        VampireDamageMultiplier = 2.5,
        AppliesBurn = true,
        BurnDamage = 8,
        BurnDuration = 4.0,
        Startup = 0.5,
        Recovery = 0.6,
        RequiresMastery = 50,
    },

    -- Hamon Cutter
    HamonCutter = {
        Name = "Hamon Cutter",
        Description = "Project Hamon through liquid",
        BreathCost = 20,
        Cooldown = 6.0,
        Damage = 10,
        Range = 20,
        Projectile = true,
        Startup = 0.3,
        RequiresMastery = 25,
    },

    -- Scarlet Overdrive
    ScarletOverdrive = {
        Name = "Scarlet Overdrive",
        Description = "Fire-enhanced Hamon strike",
        BreathCost = 45,
        Cooldown = 10.0,
        Damage = 22,
        AppliesBurn = true,
        BurnDamage = 5,
        BurnDuration = 3.0,
        Startup = 0.35,
        Recovery = 0.4,
        RequiresMastery = 40,
    },

    -- Turquoise Blue Overdrive
    TurquoiseBlueOverdrive = {
        Name = "Turquoise Blue Overdrive",
        Description = "Underwater Hamon technique",
        BreathCost = 35,
        Cooldown = 7.0,
        Damage = 15,
        Range = 15,
        WaterEnhanced = true,  -- Bonus near water
        Startup = 0.25,
        RequiresMastery = 30,
    },
}

-- ============================================================================
-- PLAYER HAMON STATE
-- ============================================================================

local HamonStates = {}

function HamonService.GetHamonState(player: Player)
    if not HamonStates[player] then
        HamonStates[player] = {
            HasHamon = false,

            -- Breath System
            Breath = 0,
            MaxBreath = ManifestationConfig.Hamon.Breath.Max,

            -- Breathing State
            IsBreathing = false,
            BreathingStartTime = 0,

            -- Combat Enhancement State
            IsEnhanced = false,  -- Currently channeling Hamon into attacks
            EnhancementEndTime = 0,

            -- Consecutive Use Penalty (anti-spam)
            ConsecutiveUseStacks = 0,
            LastTechniqueTime = 0,

            -- Technique Cooldowns
            TechniqueCooldowns = {},

            -- Mastery
            Mastery = 0,
            Experience = 0,

            -- Burn Effects (applied to enemies)
            ActiveBurns = {},
        }
    end
    return HamonStates[player]
end

function HamonService.ClearHamonState(player: Player)
    HamonStates[player] = nil
end

-- ============================================================================
-- HAMON ACQUISITION (Training-based, not random)
-- ============================================================================

function HamonService.GiveHamon(player: Player): boolean
    local state = HamonService.GetHamonState(player)

    if state.HasHamon then
        warn("[HamonService] Player already has Hamon")
        return false
    end

    state.HasHamon = true
    state.Breath = 0  -- Must earn breath through training
    state.Mastery = 0
    state.Experience = 0

    -- Initialize cooldowns
    for techName, _ in pairs(HamonService.TechniqueRegistry) do
        state.TechniqueCooldowns[techName] = 0
    end

    -- Register with combat service for damage modifiers
    CombatService.RegisterManifestationModifier(player, "Hamon", {
        DamageModifier = function(hitData, damage)
            return HamonService.ApplyHamonDefenseModifier(player, hitData, damage)
        end,
    })

    -- Hook into combat events
    HamonService.SetupCombatHooks(player)

    HamonService.FireEvent("HamonAcquired", { Player = player })

    print("[HamonService] Hamon training complete for", player.Name)
    return true
end

function HamonService.RemoveHamon(player: Player)
    local state = HamonService.GetHamonState(player)

    state.HasHamon = false
    state.Breath = 0

    CombatService.UnregisterManifestationModifier(player, "Hamon")

    HamonService.FireEvent("HamonRemoved", { Player = player })
end

-- ============================================================================
-- BREATH SYSTEM (Hamon's Core Resource)
-- ============================================================================

function HamonService.StartBreathing(player: Player): boolean
    local state = HamonService.GetHamonState(player)
    local combatState = CombatService.GetPlayerState(player)
    local config = ManifestationConfig.Hamon.Breathing

    if not state.HasHamon then
        return false
    end

    if state.IsBreathing then
        return false
    end

    -- Can't breathe in certain states
    local invalidStates = { "Stunned", "Knockdown", "GrabbedBy", "Attacking" }
    for _, invalidState in ipairs(invalidStates) do
        if combatState.State == invalidState then
            return false
        end
    end

    state.IsBreathing = true
    state.BreathingStartTime = tick()

    -- Apply movement penalty while breathing
    HamonService.FireEvent("BreathingStarted", {
        Player = player,
        SpeedMultiplier = config.MovementSpeedWhileBreathing,
    })

    return true
end

function HamonService.StopBreathing(player: Player)
    local state = HamonService.GetHamonState(player)

    if not state.IsBreathing then
        return
    end

    local config = ManifestationConfig.Hamon.Breathing
    local breathingDuration = tick() - state.BreathingStartTime

    -- Minimum breathing time requirement
    if breathingDuration < config.MinimumBreathTime then
        -- Wasted breath attempt
        state.IsBreathing = false
        return
    end

    state.IsBreathing = false

    HamonService.FireEvent("BreathingStopped", { Player = player })
end

function HamonService.InterruptBreathing(player: Player)
    local state = HamonService.GetHamonState(player)
    local config = ManifestationConfig.Hamon.Breath

    if state.IsBreathing then
        state.IsBreathing = false

        -- Lose breath when interrupted
        state.Breath = math.max(0, state.Breath - config.DecayOnHit)

        HamonService.FireEvent("BreathingInterrupted", { Player = player })
    end
end

function HamonService.ConsumeBreath(player: Player, amount: number): boolean
    local state = HamonService.GetHamonState(player)

    if state.Breath < amount then
        return false
    end

    state.Breath = state.Breath - amount

    -- Update consecutive use stacks (anti-spam)
    state.ConsecutiveUseStacks = math.min(
        state.ConsecutiveUseStacks + 1,
        ManifestationConfig.Hamon.Limitations.ConsecutiveUsePenalty.MaxStacks
    )
    state.LastTechniqueTime = tick()

    return true
end

function HamonService.UpdateBreath(player: Player, deltaTime: number)
    local state = HamonService.GetHamonState(player)
    local config = ManifestationConfig.Hamon.Breath

    -- Charge breath while breathing
    if state.IsBreathing then
        state.Breath = math.min(
            state.MaxBreath,
            state.Breath + (config.BreathingChargeRate * deltaTime)
        )
    else
        -- Passive decay
        state.Breath = math.max(0, state.Breath - (config.DecayRate * deltaTime))
    end

    -- Decay consecutive use stacks
    local stackDecay = ManifestationConfig.Hamon.Limitations.ConsecutiveUsePenalty.StackDecayTime
    if state.ConsecutiveUseStacks > 0 and (tick() - state.LastTechniqueTime) > stackDecay then
        state.ConsecutiveUseStacks = state.ConsecutiveUseStacks - 1
        state.LastTechniqueTime = tick()
    end
end

-- ============================================================================
-- COMBAT HOOKS (Hamon flows through base combat)
-- ============================================================================

function HamonService.SetupCombatHooks(player: Player)
    -- Hook into perfect blocks for Overdrive Counter
    CombatService.OnEvent("PerfectBlock", function(data)
        if data.Blocker == player then
            HamonService.AttemptOverdriveCounter(player, data.Attacker)
        end
    end)

    -- Hook into successful hits for Hamon enhancement
    CombatService.OnEvent("HitLanded", function(data)
        if data.Attacker == player then
            HamonService.OnHitLanded(player, data)
        end
    end)

    -- Hook into grabs for nerve lock
    CombatService.OnEvent("GrabSuccess", function(data)
        if data.Attacker == player then
            HamonService.AttemptNerveLock(player, data.Target)
        end
    end)

    -- Hook into finishers for sunlight bonus
    CombatService.OnEvent("FinisherExecuted", function(data)
        if data.Attacker == player then
            HamonService.ApplySunlightFinisher(player, data.Target, data)
        end
    end)

    -- Interrupt breathing when hit
    CombatService.OnEvent("DamageDealt", function(data)
        if data.Target == player then
            HamonService.InterruptBreathing(player)
        end
    end)
end

-- ============================================================================
-- COMBAT ENHANCEMENTS (The core of Hamon fighting)
-- ============================================================================

-- Light attacks gain sunlight properties
function HamonService.GetEnhancedLightDamage(player: Player, baseDamage: number, target: Player): number
    local state = HamonService.GetHamonState(player)
    local config = ManifestationConfig.Hamon.CombatExtensions.SunlightLights

    if not state.HasHamon then
        return baseDamage
    end

    -- Need breath to enhance
    if state.Breath < config.BreathCost then
        return baseDamage
    end

    -- Check if target is vampire or stand user
    local targetManifestations = CombatService.GetPlayerState(target).Manifestations

    local multiplier = 1.0
    if targetManifestations["Vampire"] then
        multiplier = config.BonusDamageVsVampire
    elseif targetManifestations["Stand"] then
        multiplier = config.BonusDamageVsStand
    end

    -- Only consume breath if hitting a valid target
    if multiplier > 1.0 then
        HamonService.ConsumeBreath(player, config.BreathCost)
    end

    return baseDamage * multiplier
end

-- Perfect blocks trigger Overdrive Counter
function HamonService.AttemptOverdriveCounter(player: Player, attacker: Player)
    local state = HamonService.GetHamonState(player)
    local config = ManifestationConfig.Hamon.CombatExtensions.OverdriveCounter

    if not state.HasHamon then
        return
    end

    if state.Breath < config.BreathCost then
        return
    end

    -- Consume breath
    if not HamonService.ConsumeBreath(player, config.BreathCost) then
        return
    end

    -- Deal counter damage
    local attackerState = CombatService.GetPlayerState(attacker)
    local attackerManifestations = attackerState.Manifestations

    local damage = config.Damage
    if attackerManifestations["Vampire"] then
        damage = damage * 1.5  -- Bonus vs vampire
    end

    CombatService.TakeDamage(attacker, {
        Attacker = player,
        Damage = damage,
        AttackType = "Counter",
        HitPosition = attacker.Character and attacker.Character.HumanoidRootPart.Position or Vector3.zero,
        IsCounterHit = true,
        ComboHitNumber = 1,
        ManifestationType = "Hamon",
    })

    -- Stun the attacker
    attackerState.State = "Stunned"
    task.delay(config.StunDuration, function()
        if CombatService.GetPlayerState(attacker).State == "Stunned" then
            attackerState.State = "Idle"
        end
    end)

    HamonService.FireEvent("OverdriveCounterTriggered", {
        Player = player,
        Target = attacker,
        Damage = damage,
    })
end

-- Grabs become nerve-locks
function HamonService.AttemptNerveLock(player: Player, target: Player)
    local state = HamonService.GetHamonState(player)
    local config = ManifestationConfig.Hamon.CombatExtensions.NerveLock

    if not state.HasHamon then
        return
    end

    if state.Breath < config.BreathCost then
        return
    end

    if not HamonService.ConsumeBreath(player, config.BreathCost) then
        return
    end

    -- Additional grab damage
    CombatService.TakeDamage(target, {
        Attacker = player,
        Damage = config.AdditionalGrabDamage,
        AttackType = "Grab",
        HitPosition = target.Character and target.Character.HumanoidRootPart.Position or Vector3.zero,
        IsCounterHit = false,
        ComboHitNumber = 1,
        ManifestationType = "Hamon",
    })

    -- Apply weaken debuff
    if config.AppliesWeaken then
        HamonService.ApplyWeaken(target, config.WeakenDuration, config.WeakenAmount)
    end

    HamonService.FireEvent("NerveLockApplied", {
        Player = player,
        Target = target,
    })
end

-- Finishers deal bonus to Vampires & Stands
function HamonService.ApplySunlightFinisher(player: Player, target: Player, finisherData: table)
    local state = HamonService.GetHamonState(player)
    local config = ManifestationConfig.Hamon.CombatExtensions.SunlightFinisher

    if not state.HasHamon then
        return
    end

    if state.Breath < config.BreathCost then
        return
    end

    local targetManifestations = CombatService.GetPlayerState(target).Manifestations

    local multiplier = 1.0
    local applyBurn = false

    if targetManifestations["Vampire"] then
        multiplier = config.BonusDamageVsVampire
        applyBurn = config.AppliesBurn
    elseif targetManifestations["Stand"] then
        multiplier = config.BonusDamageVsStand
    end

    if multiplier > 1.0 then
        HamonService.ConsumeBreath(player, config.BreathCost)

        -- Bonus damage (finisher already dealt base damage)
        local bonusDamage = finisherData.Damage * (multiplier - 1)
        CombatService.TakeDamage(target, {
            Attacker = player,
            Damage = bonusDamage,
            AttackType = "Finisher",
            HitPosition = target.Character and target.Character.HumanoidRootPart.Position or Vector3.zero,
            IsCounterHit = false,
            ComboHitNumber = 0,
            ManifestationType = "Hamon",
        })

        -- Apply burn to vampires
        if applyBurn then
            HamonService.ApplyBurn(target, config.BurnDuration, config.BurnDamage)
        end
    end
end

-- Hook for when Hamon user lands a hit
function HamonService.OnHitLanded(player: Player, hitData: table)
    local state = HamonService.GetHamonState(player)

    if not state.HasHamon then
        return
    end

    -- Grant experience
    HamonService.AddExperience(player, 3)
end

-- ============================================================================
-- DEBUFF SYSTEM
-- ============================================================================

function HamonService.ApplyWeaken(target: Player, duration: number, amount: number)
    local targetState = CombatService.GetPlayerState(target)

    -- Store weaken data
    if not targetState.Debuffs then
        targetState.Debuffs = {}
    end

    targetState.Debuffs.Weaken = {
        Amount = amount,
        EndTime = tick() + duration,
    }

    -- Clean up after duration
    task.delay(duration, function()
        if targetState.Debuffs and targetState.Debuffs.Weaken then
            if targetState.Debuffs.Weaken.EndTime <= tick() then
                targetState.Debuffs.Weaken = nil
            end
        end
    end)

    HamonService.FireEvent("WeakenApplied", {
        Target = target,
        Duration = duration,
        Amount = amount,
    })
end

function HamonService.ApplyBurn(target: Player, duration: number, damagePerSecond: number)
    local state = HamonService.GetHamonState(target) or {}

    -- Track burn
    if not state.ActiveBurns then
        state.ActiveBurns = {}
    end

    local burnId = tick()
    state.ActiveBurns[burnId] = {
        DamagePerSecond = damagePerSecond,
        EndTime = tick() + duration,
    }

    -- Burn tick loop
    local burnConnection
    burnConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not state.ActiveBurns or not state.ActiveBurns[burnId] then
            if burnConnection then
                burnConnection:Disconnect()
            end
            return
        end

        if tick() > state.ActiveBurns[burnId].EndTime then
            state.ActiveBurns[burnId] = nil
            if burnConnection then
                burnConnection:Disconnect()
            end
            return
        end

        -- Deal burn damage
        CombatService.TakeDamage(target, {
            Attacker = nil,  -- Environmental/DoT damage
            Damage = damagePerSecond * deltaTime,
            AttackType = "Burn",
            HitPosition = Vector3.zero,
            IsCounterHit = false,
            ComboHitNumber = 0,
            ManifestationType = "Hamon",
        })
    end)

    HamonService.FireEvent("BurnApplied", {
        Target = target,
        Duration = duration,
        DamagePerSecond = damagePerSecond,
    })
end

-- ============================================================================
-- TECHNIQUES
-- ============================================================================

function HamonService.CanUseTechnique(player: Player, techniqueName: string): boolean
    local state = HamonService.GetHamonState(player)
    local combatState = CombatService.GetPlayerState(player)

    if not state.HasHamon then
        return false
    end

    local technique = HamonService.TechniqueRegistry[techniqueName]
    if not technique then
        return false
    end

    -- Check cooldown
    if state.TechniqueCooldowns[techniqueName] and state.TechniqueCooldowns[techniqueName] > tick() then
        return false
    end

    -- Check breath
    if state.Breath < technique.BreathCost then
        return false
    end

    -- Check mastery
    if technique.RequiresMastery and state.Mastery < technique.RequiresMastery then
        return false
    end

    -- Check low breath penalty
    local lowBreathThreshold = ManifestationConfig.Hamon.Limitations.LowBreathPenalty.Threshold
    if state.Breath < (state.MaxBreath * lowBreathThreshold / 100) then
        if ManifestationConfig.Hamon.Limitations.LowBreathPenalty.TechniquesFail then
            return false
        end
    end

    -- Check combat state
    local invalidStates = { "Stunned", "Knockdown", "GrabbedBy", "Exhausted" }
    for _, invalidState in ipairs(invalidStates) do
        if combatState.State == invalidState then
            return false
        end
    end

    return true
end

function HamonService.UseTechnique(player: Player, techniqueName: string, targetData: table?): boolean
    if not HamonService.CanUseTechnique(player, techniqueName) then
        return false
    end

    local state = HamonService.GetHamonState(player)
    local technique = HamonService.TechniqueRegistry[techniqueName]

    -- Consume breath
    if not HamonService.ConsumeBreath(player, technique.BreathCost) then
        return false
    end

    -- Set cooldown
    state.TechniqueCooldowns[techniqueName] = tick() + technique.Cooldown

    -- Execute technique
    if technique.Duration then
        -- Multi-hit technique (barrage)
        return HamonService.ExecuteBarrageTechnique(player, technique, targetData)
    elseif technique.Projectile then
        return HamonService.ExecuteProjectileTechnique(player, technique, targetData)
    else
        -- Single hit technique
        return HamonService.ExecuteStrikeTechnique(player, technique, targetData)
    end
end

function HamonService.ExecuteStrikeTechnique(player: Player, technique: table, targetData: table?): boolean
    local state = HamonService.GetHamonState(player)
    local combatState = CombatService.GetPlayerState(player)

    combatState.State = "Attacking"

    -- Startup
    task.delay(technique.Startup or 0.25, function()
        if combatState.State ~= "Attacking" then
            return  -- Interrupted
        end

        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            return
        end

        -- Calculate range
        local baseRange = 5
        local range = technique.RangeMultiplier and (baseRange * technique.RangeMultiplier) or technique.Range or baseRange

        -- Find targets
        local rootPart = character.HumanoidRootPart

        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                local otherChar = otherPlayer.Character
                if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
                    local otherRoot = otherChar.HumanoidRootPart
                    local distance = (otherRoot.Position - rootPart.Position).Magnitude

                    if distance <= range then
                        local direction = rootPart.CFrame.LookVector
                        local toTarget = (otherRoot.Position - rootPart.Position).Unit
                        local dotProduct = direction:Dot(toTarget)

                        if dotProduct > 0.5 then  -- In front
                            local targetState = CombatService.GetPlayerState(otherPlayer)
                            local targetManifestations = targetState.Manifestations

                            -- Calculate damage with vampire bonus
                            local damage = technique.Damage
                            if technique.VampireDamageMultiplier and targetManifestations["Vampire"] then
                                damage = damage * technique.VampireDamageMultiplier
                            end

                            -- Apply consecutive use penalty
                            local penalty = state.ConsecutiveUseStacks *
                                ManifestationConfig.Hamon.Limitations.ConsecutiveUsePenalty.DamageReductionPerStack
                            damage = damage * (1 - penalty)

                            -- Check block
                            local blockResult = CombatService.CheckBlock(otherPlayer, "Heavy")

                            if blockResult.Blocked and not blockResult.PerfectBlock then
                                CombatService.TakeDamage(otherPlayer, {
                                    Attacker = player,
                                    Damage = damage * 0.2,
                                    AttackType = "Heavy",
                                    HitPosition = otherRoot.Position,
                                    IsCounterHit = false,
                                    ComboHitNumber = 0,
                                    ManifestationType = "Hamon",
                                })
                            elseif not blockResult.Blocked then
                                CombatService.TakeDamage(otherPlayer, {
                                    Attacker = player,
                                    Damage = damage,
                                    AttackType = "Heavy",
                                    HitPosition = otherRoot.Position,
                                    IsCounterHit = targetState.State == "Attacking",
                                    ComboHitNumber = combatState.ComboHits + 1,
                                    ManifestationType = "Hamon",
                                })

                                -- Apply knockback
                                if technique.Knockback then
                                    HamonService.FireEvent("KnockbackApplied", {
                                        Target = otherPlayer,
                                        Force = technique.Knockback,
                                        Direction = toTarget,
                                    })
                                end

                                -- Apply burn if applicable
                                if technique.AppliesBurn and targetManifestations["Vampire"] then
                                    HamonService.ApplyBurn(otherPlayer, technique.BurnDuration, technique.BurnDamage)
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Recovery
        task.delay(technique.Recovery or 0.3, function()
            if combatState.State == "Attacking" then
                combatState.State = "Idle"
            end
        end)
    end)

    HamonService.FireEvent("TechniqueUsed", {
        Player = player,
        TechniqueName = technique.Name,
    })

    return true
end

function HamonService.ExecuteBarrageTechnique(player: Player, technique: table, targetData: table?): boolean
    local state = HamonService.GetHamonState(player)
    local combatState = CombatService.GetPlayerState(player)

    combatState.State = "Attacking"

    local barrageStartTime = tick()
    local barrageEndTime = barrageStartTime + technique.Duration
    local hitInterval = 1 / technique.HitsPerSecond
    local lastHitTime = 0

    task.delay(technique.Startup or 0.2, function()
        local barrageConnection
        barrageConnection = RunService.Heartbeat:Connect(function()
            if not HamonStates[player] or tick() > barrageEndTime then
                if barrageConnection then
                    barrageConnection:Disconnect()
                end
                combatState.State = "Idle"
                return
            end

            if combatState.State ~= "Attacking" then
                if barrageConnection then
                    barrageConnection:Disconnect()
                end
                return
            end

            if tick() - lastHitTime >= hitInterval then
                lastHitTime = tick()

                local hits = CombatService.CreateHitbox(player, "Light", {
                    Size = Vector3.new(4, 5, 4),
                    Offset = Vector3.new(0, 0, -3),
                })

                for _, target in ipairs(hits) do
                    local targetState = CombatService.GetPlayerState(target)
                    local blockResult = CombatService.CheckBlock(target, "Light")

                    if blockResult.PerfectBlock then
                        -- Perfect block ends barrage
                        if barrageConnection then
                            barrageConnection:Disconnect()
                        end
                        combatState.State = "Stunned"
                        task.delay(0.3, function()
                            if combatState.State == "Stunned" then
                                combatState.State = "Idle"
                            end
                        end)
                        return
                    elseif not blockResult.Blocked then
                        local damage = technique.DamagePerHit
                        local targetManifestations = targetState.Manifestations

                        if targetManifestations["Vampire"] then
                            damage = damage * 1.3  -- Hamon bonus
                        end

                        CombatService.TakeDamage(target, {
                            Attacker = player,
                            Damage = damage,
                            AttackType = "Light",
                            HitPosition = target.Character and target.Character.HumanoidRootPart.Position or Vector3.zero,
                            IsCounterHit = false,
                            ComboHitNumber = combatState.ComboHits + 1,
                            ManifestationType = "Hamon",
                        })
                        CombatService.IncrementCombo(player, target)
                    end
                end
            end
        end)
    end)

    HamonService.FireEvent("TechniqueUsed", {
        Player = player,
        TechniqueName = technique.Name,
    })

    return true
end

function HamonService.ExecuteProjectileTechnique(player: Player, technique: table, targetData: table?): boolean
    local state = HamonService.GetHamonState(player)
    local combatState = CombatService.GetPlayerState(player)

    combatState.State = "Attacking"

    task.delay(technique.Startup or 0.3, function()
        if combatState.State ~= "Attacking" then
            return
        end

        -- Fire projectile event (client handles visuals)
        HamonService.FireEvent("ProjectileFired", {
            Player = player,
            TechniqueName = technique.Name,
            Range = technique.Range,
            Damage = technique.Damage,
        })

        -- Simplified projectile hit detection (server-side)
        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            return
        end

        local rootPart = character.HumanoidRootPart
        local direction = rootPart.CFrame.LookVector

        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                local otherChar = otherPlayer.Character
                if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
                    local otherRoot = otherChar.HumanoidRootPart
                    local toTarget = otherRoot.Position - rootPart.Position
                    local distance = toTarget.Magnitude

                    if distance <= technique.Range then
                        local dotProduct = direction:Dot(toTarget.Unit)
                        if dotProduct > 0.7 then  -- Tighter cone for projectile
                            local targetState = CombatService.GetPlayerState(otherPlayer)
                            local blockResult = CombatService.CheckBlock(otherPlayer, "Heavy")

                            if not blockResult.Blocked then
                                CombatService.TakeDamage(otherPlayer, {
                                    Attacker = player,
                                    Damage = technique.Damage,
                                    AttackType = "Heavy",
                                    HitPosition = otherRoot.Position,
                                    IsCounterHit = false,
                                    ComboHitNumber = 1,
                                    ManifestationType = "Hamon",
                                })
                            end
                        end
                    end
                end
            end
        end

        combatState.State = "Idle"
    end)

    return true
end

-- ============================================================================
-- DEFENSE MODIFIER (Hamon users are skilled defensively)
-- ============================================================================

function HamonService.ApplyHamonDefenseModifier(player: Player, hitData: table, damage: number): number
    local state = HamonService.GetHamonState(player)

    if not state.HasHamon then
        return damage
    end

    -- Interrupt breathing when hit
    if hitData.Damage > 0 then
        HamonService.InterruptBreathing(player)
    end

    return damage
end

-- ============================================================================
-- MASTERY & PROGRESSION
-- ============================================================================

function HamonService.AddExperience(player: Player, amount: number)
    local state = HamonService.GetHamonState(player)

    if not state.HasHamon then
        return
    end

    state.Experience = state.Experience + amount

    local expRequired = 80 * (1.4 ^ state.Mastery)

    while state.Experience >= expRequired do
        state.Experience = state.Experience - expRequired
        state.Mastery = math.min(state.Mastery + 1, 100)

        HamonService.FireEvent("MasteryLevelUp", {
            Player = player,
            NewLevel = state.Mastery,
        })

        expRequired = 80 * (1.4 ^ state.Mastery)
    end
end

-- ============================================================================
-- EVENT SYSTEM
-- ============================================================================

local EventCallbacks = {}

function HamonService.OnEvent(eventName: string, callback: (data: table) -> ())
    if not EventCallbacks[eventName] then
        EventCallbacks[eventName] = {}
    end
    table.insert(EventCallbacks[eventName], callback)
end

function HamonService.FireEvent(eventName: string, data: table)
    local callbacks = EventCallbacks[eventName]
    if callbacks then
        for _, callback in ipairs(callbacks) do
            task.spawn(callback, data)
        end
    end
end

-- ============================================================================
-- UPDATE LOOP
-- ============================================================================

function HamonService.Update(deltaTime: number)
    for player, _ in pairs(HamonStates) do
        if player.Parent then
            HamonService.UpdateBreath(player, deltaTime)
        else
            HamonService.ClearHamonState(player)
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function HamonService.Initialize()
    Players.PlayerRemoving:Connect(function(player)
        HamonService.ClearHamonState(player)
    end)

    RunService.Heartbeat:Connect(function(deltaTime)
        HamonService.Update(deltaTime)
    end)

    print("[HamonService] Initialized - Breath of the Sun flows through combat")
end

return HamonService
