--[[
    VampireService.lua
    VAMPIRE MASK - MANIFESTATION OF INSTINCT

    DESIGN PHILOSOPHY:
    Vampirism alters the body, not combat rules.

    Vampires win through:
    - Aggression
    - Momentum
    - Attrition

    Vampires feel: overwhelming, but UNSTABLE.

    KEY WEAKNESSES:
    - Hamon is TERRIFYING
    - Overextending gets punished HARD
    - Daylight/sunlight mechanics apply pressure
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- Get references (Rojo structure)
-- script = VampireService, script.Parent = Manifestations, script.Parent.Parent = JoJoFramework (main script)
local JoJoFramework = script.Parent.Parent
local SharedFolder = ReplicatedStorage:WaitForChild("JoJoFramework"):WaitForChild("Shared")

local CombatService = require(JoJoFramework.Combat.CombatService)
local ManifestationConfig = require(SharedFolder.Constants.ManifestationConfig)

local VampireService = {}
VampireService.__index = VampireService

-- ============================================================================
-- VAMPIRE ABILITY REGISTRY
-- ============================================================================

VampireService.AbilityRegistry = {
    -- Vaporization Freeze
    VaporizationFreeze = {
        Name = "Vaporization Freeze",
        Description = "Freeze target on contact through rapid heat absorption",
        BloodCost = 30,
        Cooldown = 6.0,
        Damage = 15,
        FreezeDuration = 1.0,
        Range = 8,
        Startup = 0.4,
        Recovery = 0.3,
        RequiresMastery = 0,
    },

    -- Space Ripper Stingy Eyes
    SpaceRipperStingyEyes = {
        Name = "Space Ripper Stingy Eyes",
        Description = "High-pressure fluid jets from eyes",
        BloodCost = 40,
        Cooldown = 8.0,
        Damage = 25,
        Range = 30,
        Startup = 0.5,
        Recovery = 0.4,
        Blockable = true,
        RequiresMastery = 20,
    },

    -- Blood Drain (enhanced grab)
    BloodDrain = {
        Name = "Blood Drain",
        Description = "Drain blood and life from grabbed victim",
        BloodCost = 0,  -- Gains blood instead
        Cooldown = 3.0,
        BloodGain = 25,
        Damage = 10,
        HealAmount = 15,
        RequiresMastery = 0,
    },

    -- Zombie Creation
    ZombieMinion = {
        Name = "Zombie Creation",
        Description = "Create a zombie minion from defeated foe",
        BloodCost = 60,
        Cooldown = 30.0,
        MinionHealth = 30,
        MinionDamage = 5,
        Duration = 15.0,
        RequiresMastery = 40,
    },

    -- Flesh Bud (advanced)
    FleshBud = {
        Name = "Flesh Bud",
        Description = "Implant a flesh bud to control target",
        BloodCost = 80,
        Cooldown = 60.0,
        ControlDuration = 10.0,
        Range = 3,
        Startup = 1.0,  -- Very slow, must be earned
        RequiresMastery = 70,
    },

    -- Regeneration Burst
    RegenerationBurst = {
        Name = "Regeneration Burst",
        Description = "Rapidly heal at the cost of blood",
        BloodCost = 50,
        Cooldown = 15.0,
        HealAmount = 40,
        HealDuration = 2.0,
        RequiresMastery = 30,
    },
}

-- ============================================================================
-- PLAYER VAMPIRE STATE
-- ============================================================================

local VampireStates = {}

function VampireService.GetVampireState(player: Player)
    if not VampireStates[player] then
        VampireStates[player] = {
            IsVampire = false,

            -- Blood System
            Blood = ManifestationConfig.Vampire.Blood.StartingBlood,
            MaxBlood = ManifestationConfig.Vampire.Blood.Max,

            -- Environment State
            IsInSunlight = false,
            SunlightDamageAccumulated = 0,
            LastSunlightCheck = 0,

            -- Combat State
            LifeStealActive = true,
            ConsecutiveHeavyHits = 0,  -- For stagger mechanic

            -- Minions
            ActiveMinions = {},
            MaxMinions = 1,

            -- Cooldowns
            AbilityCooldowns = {},

            -- Night Bonus Active
            IsNightTime = false,

            -- Mastery
            Mastery = 0,
            Experience = 0,

            -- Debuffs from Hamon
            HamonBurnActive = false,
            HamonBurnEndTime = 0,
        }
    end
    return VampireStates[player]
end

function VampireService.ClearVampireState(player: Player)
    local state = VampireStates[player]
    if state then
        -- Clean up minions
        for _, minion in ipairs(state.ActiveMinions) do
            if minion and minion.Parent then
                minion:Destroy()
            end
        end
    end
    VampireStates[player] = nil
end

-- ============================================================================
-- VAMPIRE ACQUISITION (Stone Mask)
-- ============================================================================

function VampireService.GiveVampirism(player: Player): boolean
    local state = VampireService.GetVampireState(player)

    if state.IsVampire then
        warn("[VampireService] Player is already a Vampire")
        return false
    end

    -- Check for Hamon (incompatible)
    local combatState = CombatService.GetPlayerState(player)
    if combatState.Manifestations["Hamon"] then
        warn("[VampireService] Cannot become Vampire - has Hamon (incompatible)")
        return false
    end

    state.IsVampire = true
    state.Blood = ManifestationConfig.Vampire.Blood.StartingBlood

    -- Initialize cooldowns
    for abilityName, _ in pairs(VampireService.AbilityRegistry) do
        state.AbilityCooldowns[abilityName] = 0
    end

    -- Register with combat service
    CombatService.RegisterManifestationModifier(player, "Vampire", {
        DamageModifier = function(hitData, damage)
            return VampireService.ApplyVampireDamageModifier(player, hitData, damage)
        end,
    })

    -- Setup combat hooks
    VampireService.SetupCombatHooks(player)

    -- Apply passive stat changes
    VampireService.ApplyPassives(player)

    VampireService.FireEvent("VampirismAcquired", { Player = player })

    print("[VampireService] Player transformed into Vampire:", player.Name)
    return true
end

function VampireService.RemoveVampirism(player: Player)
    local state = VampireService.GetVampireState(player)

    -- Clean up minions
    for _, minion in ipairs(state.ActiveMinions) do
        if minion and minion.Parent then
            minion:Destroy()
        end
    end

    state.IsVampire = false
    state.Blood = 0

    CombatService.UnregisterManifestationModifier(player, "Vampire")

    VampireService.FireEvent("VampirismRemoved", { Player = player })
end

-- ============================================================================
-- PASSIVE ABILITIES
-- ============================================================================

function VampireService.ApplyPassives(player: Player)
    local config = ManifestationConfig.Vampire.Passives

    -- These would modify the humanoid or be checked during combat
    VampireService.FireEvent("PassivesApplied", {
        Player = player,
        DamageMultiplier = config.DamageMultiplier,
        SpeedMultiplier = config.SpeedMultiplier,
        RecoveryMultiplier = config.RecoverySpeedMultiplier,
    })
end

-- Life steal on clean hits
function VampireService.ProcessLifeSteal(player: Player, damage: number, target: Player)
    local state = VampireService.GetVampireState(player)
    local config = ManifestationConfig.Vampire.Passives.LifeSteal

    if not state.IsVampire then
        return
    end

    if not state.LifeStealActive then
        return
    end

    -- Can't life steal from other vampires
    local targetState = VampireService.GetVampireState(target)
    if targetState and targetState.IsVampire then
        return
    end

    local healAmount = damage * config.Percent

    -- Night bonus
    if state.IsNightTime then
        healAmount = healAmount * (1 + ManifestationConfig.Vampire.Passives.NightBonus.AdditionalLifeSteal)
    end

    CombatService.Heal(player, healAmount)

    VampireService.FireEvent("LifeStealProc", {
        Player = player,
        Target = target,
        Amount = healAmount,
    })
end

-- ============================================================================
-- BLOOD SYSTEM
-- ============================================================================

function VampireService.ConsumeBlood(player: Player, amount: number): boolean
    local state = VampireService.GetVampireState(player)

    if state.Blood < amount then
        return false
    end

    state.Blood = state.Blood - amount
    return true
end

function VampireService.GainBlood(player: Player, amount: number)
    local state = VampireService.GetVampireState(player)
    state.Blood = math.min(state.MaxBlood, state.Blood + amount)
end

function VampireService.UpdateBlood(player: Player, deltaTime: number)
    local state = VampireService.GetVampireState(player)
    local config = ManifestationConfig.Vampire.Blood

    if not state.IsVampire then
        return
    end

    -- Determine decay rate based on sunlight
    local decayRate = state.IsInSunlight and config.DecayRateDay or config.DecayRate

    -- Apply decay
    state.Blood = math.max(0, state.Blood - (decayRate * deltaTime))

    -- Check low blood penalty
    VampireService.CheckLowBloodPenalty(player)
end

function VampireService.CheckLowBloodPenalty(player: Player)
    local state = VampireService.GetVampireState(player)
    local config = ManifestationConfig.Vampire.Weaknesses.LowBloodPenalty

    local bloodPercent = (state.Blood / state.MaxBlood) * 100

    if bloodPercent < config.Threshold then
        -- Apply penalties
        state.LifeStealActive = false

        VampireService.FireEvent("LowBloodPenalty", {
            Player = player,
            SpeedReduction = config.SpeedReduction,
            DamageTakenIncrease = config.DamageTakenIncrease,
        })
    else
        state.LifeStealActive = true
    end
end

-- ============================================================================
-- SUNLIGHT SYSTEM (Critical Weakness)
-- ============================================================================

function VampireService.CheckSunlight(player: Player)
    local state = VampireService.GetVampireState(player)

    if not state.IsVampire then
        return
    end

    -- Check time of day
    local clockTime = Lighting.ClockTime
    local isDaytime = clockTime >= 6 and clockTime <= 18

    state.IsNightTime = not isDaytime

    if not isDaytime then
        state.IsInSunlight = false
        return
    end

    -- Check if player is exposed to sun (simplified - would use raycasting in full implementation)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return
    end

    -- Simple check: if outside and daytime, in sunlight
    -- Full implementation would raycast to check for cover
    local rootPart = character.HumanoidRootPart

    -- Check if under cover (simplified)
    local rayOrigin = rootPart.Position
    local rayDirection = Vector3.new(0, 50, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = { character }
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

    -- If nothing above, exposed to sun
    state.IsInSunlight = (result == nil) and isDaytime
end

function VampireService.ApplySunlightDamage(player: Player, deltaTime: number)
    local state = VampireService.GetVampireState(player)
    local config = ManifestationConfig.Vampire.Weaknesses.Daylight

    if not state.IsVampire or not state.IsInSunlight then
        return
    end

    -- Deal sunlight damage
    local damage = config.DamagePerSecond * deltaTime

    state.SunlightDamageAccumulated = state.SunlightDamageAccumulated + damage

    -- Apply accumulated damage in chunks to avoid spam
    if state.SunlightDamageAccumulated >= 1 then
        local damageToApply = math.floor(state.SunlightDamageAccumulated)
        state.SunlightDamageAccumulated = state.SunlightDamageAccumulated - damageToApply

        CombatService.TakeDamage(player, {
            Attacker = nil,
            Damage = damageToApply,
            AttackType = "Sunlight",
            HitPosition = Vector3.zero,
            IsCounterHit = false,
            ComboHitNumber = 0,
            ManifestationType = "Environment",
        })

        VampireService.FireEvent("SunlightDamage", {
            Player = player,
            Damage = damageToApply,
        })
    end
end

-- ============================================================================
-- COMBAT HOOKS
-- ============================================================================

function VampireService.SetupCombatHooks(player: Player)
    -- Hook into successful hits for life steal
    CombatService.OnEvent("HitLanded", function(data)
        if data.Attacker == player then
            VampireService.OnHitLanded(player, data)
        end
    end)

    -- Hook into grabs for blood drain
    CombatService.OnEvent("GrabSuccess", function(data)
        if data.Attacker == player then
            VampireService.AttemptBloodDrain(player, data.Target)
        end
    end)

    -- Track consecutive heavy hits for stagger
    CombatService.OnEvent("DamageDealt", function(data)
        if data.Target == player then
            VampireService.OnDamageTaken(player, data)
        end
    end)
end

function VampireService.OnHitLanded(player: Player, hitData: table)
    local state = VampireService.GetVampireState(player)

    if not state.IsVampire then
        return
    end

    -- Life steal on clean hits
    if not hitData.Blocked then
        VampireService.ProcessLifeSteal(player, hitData.Damage, hitData.Target)
    end

    -- Grant experience
    VampireService.AddExperience(player, 4)
end

function VampireService.OnDamageTaken(player: Player, damageData: table)
    local state = VampireService.GetVampireState(player)

    if not state.IsVampire then
        return
    end

    -- Check if damage is from Hamon
    if damageData.ManifestationType == "Hamon" then
        VampireService.ApplyHamonVulnerability(player, damageData)
    end

    -- Track consecutive heavy hits for stagger
    if damageData.AttackType == "Heavy" then
        state.ConsecutiveHeavyHits = state.ConsecutiveHeavyHits + 1

        local config = ManifestationConfig.Vampire.Weaknesses.HeavyHitStagger
        if state.ConsecutiveHeavyHits >= config.HeavyHitsRequiredForStagger then
            VampireService.ApplyStagger(player, config.StaggerDuration)
            state.ConsecutiveHeavyHits = 0
        end
    else
        -- Reset on non-heavy hit
        state.ConsecutiveHeavyHits = 0
    end
end

-- ============================================================================
-- HAMON VULNERABILITY (THE TERROR)
-- ============================================================================

function VampireService.ApplyVampireDamageModifier(player: Player, hitData: table, damage: number): number
    local state = VampireService.GetVampireState(player)
    local config = ManifestationConfig.Vampire.Weaknesses

    if not state.IsVampire then
        return damage
    end

    local modifiedDamage = damage

    -- Hamon is TERRIFYING
    if hitData.ManifestationType == "Hamon" then
        modifiedDamage = modifiedDamage * config.HamonDamageMultiplier

        -- Apply Hamon burn
        VampireService.ApplyHamonBurn(player, config.HamonBurnDuration, config.HamonBurnDamage)
    end

    -- Low blood increases damage taken
    local bloodPercent = (state.Blood / state.MaxBlood) * 100
    if bloodPercent < config.LowBloodPenalty.Threshold then
        modifiedDamage = modifiedDamage * (1 + config.LowBloodPenalty.DamageTakenIncrease)
    end

    -- Stagger state increases damage
    local combatState = CombatService.GetPlayerState(player)
    if combatState.State == "Staggered" then
        modifiedDamage = modifiedDamage * config.HeavyHitStagger.StaggerDamageTaken
    end

    return modifiedDamage
end

function VampireService.ApplyHamonVulnerability(player: Player, damageData: table)
    -- Extra effects when hit by Hamon
    local state = VampireService.GetVampireState(player)

    -- Drain blood on Hamon hit
    state.Blood = math.max(0, state.Blood - 10)

    VampireService.FireEvent("HamonHit", {
        Player = player,
        Damage = damageData.Damage,
    })
end

function VampireService.ApplyHamonBurn(player: Player, duration: number, damagePerSecond: number)
    local state = VampireService.GetVampireState(player)

    state.HamonBurnActive = true
    state.HamonBurnEndTime = tick() + duration

    VampireService.FireEvent("HamonBurnApplied", {
        Player = player,
        Duration = duration,
        DamagePerSecond = damagePerSecond,
    })
end

function VampireService.ProcessHamonBurn(player: Player, deltaTime: number)
    local state = VampireService.GetVampireState(player)
    local config = ManifestationConfig.Vampire.Weaknesses

    if not state.HamonBurnActive then
        return
    end

    if tick() > state.HamonBurnEndTime then
        state.HamonBurnActive = false
        return
    end

    -- Deal burn damage
    CombatService.TakeDamage(player, {
        Attacker = nil,
        Damage = config.HamonBurnDamage * deltaTime,
        AttackType = "Burn",
        HitPosition = Vector3.zero,
        IsCounterHit = false,
        ComboHitNumber = 0,
        ManifestationType = "Hamon",
    })
end

function VampireService.ApplyStagger(player: Player, duration: number)
    local combatState = CombatService.GetPlayerState(player)

    combatState.State = "Staggered"

    task.delay(duration, function()
        if CombatService.GetPlayerState(player).State == "Staggered" then
            combatState.State = "Idle"
        end
    end)

    VampireService.FireEvent("Staggered", {
        Player = player,
        Duration = duration,
    })
end

-- ============================================================================
-- VAMPIRE ABILITIES
-- ============================================================================

function VampireService.CanUseAbility(player: Player, abilityName: string): boolean
    local state = VampireService.GetVampireState(player)
    local combatState = CombatService.GetPlayerState(player)

    if not state.IsVampire then
        return false
    end

    local ability = VampireService.AbilityRegistry[abilityName]
    if not ability then
        return false
    end

    -- Check cooldown
    if state.AbilityCooldowns[abilityName] and state.AbilityCooldowns[abilityName] > tick() then
        return false
    end

    -- Check blood (if costs blood)
    if ability.BloodCost > 0 and state.Blood < ability.BloodCost then
        return false
    end

    -- Check mastery
    if ability.RequiresMastery and state.Mastery < ability.RequiresMastery then
        return false
    end

    -- Check combat state
    local invalidStates = { "Stunned", "Knockdown", "GrabbedBy", "Staggered" }
    for _, invalidState in ipairs(invalidStates) do
        if combatState.State == invalidState then
            return false
        end
    end

    return true
end

function VampireService.UseAbility(player: Player, abilityName: string, targetData: table?): boolean
    if not VampireService.CanUseAbility(player, abilityName) then
        return false
    end

    local state = VampireService.GetVampireState(player)
    local ability = VampireService.AbilityRegistry[abilityName]

    -- Consume blood
    if ability.BloodCost > 0 then
        if not VampireService.ConsumeBlood(player, ability.BloodCost) then
            return false
        end
    end

    -- Set cooldown
    state.AbilityCooldowns[abilityName] = tick() + ability.Cooldown

    -- Execute ability
    if abilityName == "VaporizationFreeze" then
        return VampireService.ExecuteVaporizationFreeze(player, ability, targetData)
    elseif abilityName == "SpaceRipperStingyEyes" then
        return VampireService.ExecuteSpaceRipperStingyEyes(player, ability, targetData)
    elseif abilityName == "BloodDrain" then
        return VampireService.ExecuteBloodDrain(player, ability, targetData)
    elseif abilityName == "ZombieMinion" then
        return VampireService.ExecuteZombieMinion(player, ability, targetData)
    elseif abilityName == "RegenerationBurst" then
        return VampireService.ExecuteRegenerationBurst(player, ability)
    elseif abilityName == "FleshBud" then
        return VampireService.ExecuteFleshBud(player, ability, targetData)
    end

    return false
end

-- ============================================================================
-- ABILITY IMPLEMENTATIONS
-- ============================================================================

function VampireService.ExecuteVaporizationFreeze(player: Player, ability: table, targetData: table?): boolean
    local combatState = CombatService.GetPlayerState(player)

    combatState.State = "Attacking"

    -- Startup (reactable)
    task.delay(ability.Startup, function()
        if combatState.State ~= "Attacking" then
            return
        end

        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            return
        end

        local rootPart = character.HumanoidRootPart

        -- Find targets in range
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                local otherChar = otherPlayer.Character
                if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
                    local otherRoot = otherChar.HumanoidRootPart
                    local distance = (otherRoot.Position - rootPart.Position).Magnitude

                    if distance <= ability.Range then
                        local direction = rootPart.CFrame.LookVector
                        local toTarget = (otherRoot.Position - rootPart.Position).Unit
                        local dotProduct = direction:Dot(toTarget)

                        if dotProduct > 0.6 then
                            local targetState = CombatService.GetPlayerState(otherPlayer)

                            -- Deal damage
                            CombatService.TakeDamage(otherPlayer, {
                                Attacker = player,
                                Damage = ability.Damage,
                                AttackType = "Heavy",
                                HitPosition = otherRoot.Position,
                                IsCounterHit = false,
                                ComboHitNumber = 1,
                                ManifestationType = "Vampire",
                            })

                            -- Apply freeze (stun)
                            targetState.State = "Frozen"
                            task.delay(ability.FreezeDuration, function()
                                if CombatService.GetPlayerState(otherPlayer).State == "Frozen" then
                                    targetState.State = "Idle"
                                end
                            end)

                            VampireService.FireEvent("FreezeApplied", {
                                Player = player,
                                Target = otherPlayer,
                                Duration = ability.FreezeDuration,
                            })
                        end
                    end
                end
            end
        end

        -- Recovery
        task.delay(ability.Recovery, function()
            if combatState.State == "Attacking" then
                combatState.State = "Idle"
            end
        end)
    end)

    VampireService.FireEvent("AbilityUsed", {
        Player = player,
        AbilityName = ability.Name,
    })

    return true
end

function VampireService.ExecuteSpaceRipperStingyEyes(player: Player, ability: table, targetData: table?): boolean
    local combatState = CombatService.GetPlayerState(player)

    combatState.State = "Attacking"

    task.delay(ability.Startup, function()
        if combatState.State ~= "Attacking" then
            return
        end

        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            return
        end

        local rootPart = character.HumanoidRootPart
        local direction = rootPart.CFrame.LookVector

        -- Fire projectile event
        VampireService.FireEvent("EyeBeamFired", {
            Player = player,
            Origin = rootPart.Position,
            Direction = direction,
            Range = ability.Range,
        })

        -- Hit detection (linear projectile)
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                local otherChar = otherPlayer.Character
                if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
                    local otherRoot = otherChar.HumanoidRootPart
                    local toTarget = otherRoot.Position - rootPart.Position
                    local distance = toTarget.Magnitude

                    if distance <= ability.Range then
                        local dotProduct = direction:Dot(toTarget.Unit)

                        if dotProduct > 0.85 then  -- Very narrow cone for beam
                            local targetState = CombatService.GetPlayerState(otherPlayer)
                            local blockResult = CombatService.CheckBlock(otherPlayer, "Heavy")

                            if ability.Blockable and blockResult.Blocked then
                                -- Chip damage on block
                                CombatService.TakeDamage(otherPlayer, {
                                    Attacker = player,
                                    Damage = ability.Damage * 0.2,
                                    AttackType = "Heavy",
                                    HitPosition = otherRoot.Position,
                                    IsCounterHit = false,
                                    ComboHitNumber = 0,
                                    ManifestationType = "Vampire",
                                })
                            else
                                CombatService.TakeDamage(otherPlayer, {
                                    Attacker = player,
                                    Damage = ability.Damage,
                                    AttackType = "Heavy",
                                    HitPosition = otherRoot.Position,
                                    IsCounterHit = targetState.State == "Attacking",
                                    ComboHitNumber = combatState.ComboHits + 1,
                                    ManifestationType = "Vampire",
                                })
                            end
                        end
                    end
                end
            end
        end

        task.delay(ability.Recovery, function()
            if combatState.State == "Attacking" then
                combatState.State = "Idle"
            end
        end)
    end)

    VampireService.FireEvent("AbilityUsed", {
        Player = player,
        AbilityName = ability.Name,
    })

    return true
end

function VampireService.AttemptBloodDrain(player: Player, target: Player)
    -- Called automatically during grab
    local state = VampireService.GetVampireState(player)
    local ability = VampireService.AbilityRegistry.BloodDrain

    if not state.IsVampire then
        return
    end

    -- Check cooldown
    if state.AbilityCooldowns.BloodDrain and state.AbilityCooldowns.BloodDrain > tick() then
        return
    end

    state.AbilityCooldowns.BloodDrain = tick() + ability.Cooldown

    -- Gain blood
    VampireService.GainBlood(player, ability.BloodGain)

    -- Deal extra damage
    CombatService.TakeDamage(target, {
        Attacker = player,
        Damage = ability.Damage,
        AttackType = "Grab",
        HitPosition = target.Character and target.Character.HumanoidRootPart.Position or Vector3.zero,
        IsCounterHit = false,
        ComboHitNumber = 0,
        ManifestationType = "Vampire",
    })

    -- Heal
    CombatService.Heal(player, ability.HealAmount)

    VampireService.FireEvent("BloodDrained", {
        Player = player,
        Target = target,
        BloodGained = ability.BloodGain,
        HealthGained = ability.HealAmount,
    })
end

function VampireService.ExecuteBloodDrain(player: Player, ability: table, targetData: table?): boolean
    -- Manual blood drain (if not in grab)
    -- This would require being close to target
    return true
end

function VampireService.ExecuteZombieMinion(player: Player, ability: table, targetData: table?): boolean
    local state = VampireService.GetVampireState(player)

    -- Check minion limit
    if #state.ActiveMinions >= state.MaxMinions then
        return false
    end

    -- Create zombie minion (simplified - would be full NPC in real implementation)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false
    end

    local spawnPosition = character.HumanoidRootPart.Position + Vector3.new(5, 0, 0)

    -- Fire event for client to create visual
    VampireService.FireEvent("ZombieMinionCreated", {
        Player = player,
        Position = spawnPosition,
        Health = ability.MinionHealth,
        Damage = ability.MinionDamage,
        Duration = ability.Duration,
    })

    -- Track minion (placeholder reference)
    local minionId = tick()
    table.insert(state.ActiveMinions, minionId)

    -- Remove after duration
    task.delay(ability.Duration, function()
        if VampireStates[player] then
            for i, id in ipairs(state.ActiveMinions) do
                if id == minionId then
                    table.remove(state.ActiveMinions, i)
                    break
                end
            end
        end
    end)

    return true
end

function VampireService.ExecuteRegenerationBurst(player: Player, ability: table): boolean
    local combatState = CombatService.GetPlayerState(player)

    -- Heal over time
    local healPerSecond = ability.HealAmount / ability.HealDuration
    local healStartTime = tick()
    local healEndTime = healStartTime + ability.HealDuration

    local healConnection
    healConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not VampireStates[player] or tick() > healEndTime then
            if healConnection then
                healConnection:Disconnect()
            end
            return
        end

        -- Interrupt if hit during heal
        if combatState.State == "Stunned" or combatState.State == "Knockdown" then
            if healConnection then
                healConnection:Disconnect()
            end
            return
        end

        CombatService.Heal(player, healPerSecond * deltaTime)
    end)

    VampireService.FireEvent("RegenerationBurstStarted", {
        Player = player,
        Duration = ability.HealDuration,
        TotalHeal = ability.HealAmount,
    })

    return true
end

function VampireService.ExecuteFleshBud(player: Player, ability: table, targetData: table?): boolean
    local combatState = CombatService.GetPlayerState(player)

    combatState.State = "Attacking"

    -- Very slow startup (must be earned)
    task.delay(ability.Startup, function()
        if combatState.State ~= "Attacking" then
            return
        end

        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            return
        end

        local rootPart = character.HumanoidRootPart

        -- Find target in very close range
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                local otherChar = otherPlayer.Character
                if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
                    local otherRoot = otherChar.HumanoidRootPart
                    local distance = (otherRoot.Position - rootPart.Position).Magnitude

                    if distance <= ability.Range then
                        -- Apply flesh bud control
                        VampireService.FireEvent("FleshBudApplied", {
                            Player = player,
                            Target = otherPlayer,
                            Duration = ability.ControlDuration,
                        })

                        -- Control effect (simplified - target can't attack player)
                        local targetState = CombatService.GetPlayerState(otherPlayer)
                        targetState.FleshBudController = player

                        task.delay(ability.ControlDuration, function()
                            if CombatService.GetPlayerState(otherPlayer).FleshBudController == player then
                                targetState.FleshBudController = nil
                            end
                        end)

                        break
                    end
                end
            end
        end

        combatState.State = "Idle"
    end)

    return true
end

-- ============================================================================
-- MASTERY & PROGRESSION
-- ============================================================================

function VampireService.AddExperience(player: Player, amount: number)
    local state = VampireService.GetVampireState(player)

    if not state.IsVampire then
        return
    end

    state.Experience = state.Experience + amount

    local expRequired = 90 * (1.45 ^ state.Mastery)

    while state.Experience >= expRequired do
        state.Experience = state.Experience - expRequired
        state.Mastery = math.min(state.Mastery + 1, 100)

        VampireService.FireEvent("MasteryLevelUp", {
            Player = player,
            NewLevel = state.Mastery,
        })

        expRequired = 90 * (1.45 ^ state.Mastery)
    end
end

-- ============================================================================
-- EVENT SYSTEM
-- ============================================================================

local EventCallbacks = {}

function VampireService.OnEvent(eventName: string, callback: (data: table) -> ())
    if not EventCallbacks[eventName] then
        EventCallbacks[eventName] = {}
    end
    table.insert(EventCallbacks[eventName], callback)
end

function VampireService.FireEvent(eventName: string, data: table)
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

function VampireService.Update(deltaTime: number)
    for player, state in pairs(VampireStates) do
        if player.Parent and state.IsVampire then
            -- Update blood
            VampireService.UpdateBlood(player, deltaTime)

            -- Check sunlight (every 0.5 seconds to save performance)
            if tick() - state.LastSunlightCheck > 0.5 then
                VampireService.CheckSunlight(player)
                state.LastSunlightCheck = tick()
            end

            -- Apply sunlight damage
            VampireService.ApplySunlightDamage(player, deltaTime)

            -- Process Hamon burn
            VampireService.ProcessHamonBurn(player, deltaTime)
        elseif not player.Parent then
            VampireService.ClearVampireState(player)
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function VampireService.Initialize()
    Players.PlayerRemoving:Connect(function(player)
        VampireService.ClearVampireState(player)
    end)

    RunService.Heartbeat:Connect(function(deltaTime)
        VampireService.Update(deltaTime)
    end)

    print("[VampireService] Initialized - The Stone Mask awaits")
end

return VampireService
