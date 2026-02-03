--[[
    StandService.lua
    STAND ARROW - MANIFESTATION OF WILL

    DESIGN PHILOSOPHY:
    A Stand is an external manifestation. It:
    - Extends reach
    - Adds pressure
    - Creates follow-ups
    - Controls space

    But:
    - Requires summoning
    - Can be interrupted
    - Transfers risk to the user

    Stand manifestation is a DECISION, not a toggle buff.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Get references (Rojo structure)
local ServerFolder = script.Parent.Parent
local SharedFolder = ReplicatedStorage:WaitForChild("JoJoFramework"):WaitForChild("Shared")

local CombatService = require(ServerFolder.Combat.CombatService)
local ManifestationConfig = require(SharedFolder.Constants.ManifestationConfig)
local CombatConfig = require(SharedFolder.Constants.CombatConfig)

local StandService = {}
StandService.__index = StandService

-- ============================================================================
-- STAND REGISTRY (Define your Stands here)
-- ============================================================================

StandService.StandRegistry = {
    -- Example Stand: Star Platinum (Close-Range Power Type)
    StarPlatinum = {
        Name = "Star Platinum",
        LocalizedName = "Star Platinum",
        Rarity = "Legendary",
        Stats = {
            Power = 1.0,      -- A
            Speed = 1.0,      -- A
            Range = 5,        -- C (2 meters)
            Durability = 1.0, -- A
            Precision = 1.0,  -- A
            Potential = 0.8,  -- A
        },
        Abilities = {
            {
                Name = "ORA Rush",
                Type = "Rush",
                EnergyCost = 40,
                Cooldown = 5.0,
                Damage = 3,
                HitsPerSecond = 10,
                Duration = 2.0,
            },
            {
                Name = "Star Finger",
                Type = "Ranged",
                EnergyCost = 25,
                Cooldown = 8.0,
                Damage = 18,
                Range = 15,
                Startup = 0.4,
            },
            {
                Name = "Time Stop",
                Type = "Ultimate",
                EnergyCost = 80,
                Cooldown = 60.0,
                Duration = 5.0,
                RequiresMastery = 80,
            },
        },
        Weaknesses = { "Close range required for full power", "User takes Stand damage" },
    },

    -- Example Stand: The World (Close-Range Power Type)
    TheWorld = {
        Name = "The World",
        LocalizedName = "The World",
        Rarity = "Legendary",
        Stats = {
            Power = 1.0,
            Speed = 1.0,
            Range = 10,
            Durability = 1.0,
            Precision = 0.8,
            Potential = 0.8,
        },
        Abilities = {
            {
                Name = "MUDA Rush",
                Type = "Rush",
                EnergyCost = 40,
                Cooldown = 5.0,
                Damage = 3,
                HitsPerSecond = 9,
                Duration = 2.0,
            },
            {
                Name = "Knife Throw",
                Type = "Ranged",
                EnergyCost = 15,
                Cooldown = 3.0,
                Damage = 10,
                Range = 25,
                Startup = 0.3,
            },
            {
                Name = "Time Stop",
                Type = "Ultimate",
                EnergyCost = 80,
                Cooldown = 60.0,
                Duration = 9.0,
                RequiresMastery = 80,
            },
        },
        Weaknesses = { "Arrogance in combat style", "User takes Stand damage" },
    },

    -- Example Stand: Crazy Diamond (Restoration Type)
    CrazyDiamond = {
        Name = "Crazy Diamond",
        LocalizedName = "Crazy Diamond",
        Rarity = "Epic",
        Stats = {
            Power = 0.9,
            Speed = 0.9,
            Range = 4,
            Durability = 0.9,
            Precision = 0.8,
            Potential = 0.8,
        },
        Abilities = {
            {
                Name = "DORA Rush",
                Type = "Rush",
                EnergyCost = 35,
                Cooldown = 4.5,
                Damage = 3,
                HitsPerSecond = 8,
                Duration = 1.8,
            },
            {
                Name = "Restoration",
                Type = "Utility",
                EnergyCost = 30,
                Cooldown = 10.0,
                HealAmount = 25,
                CanHealOthers = true,
            },
            {
                Name = "Trap Restoration",
                Type = "Special",
                EnergyCost = 45,
                Cooldown = 15.0,
                Description = "Restore broken object into trap",
            },
        },
        Weaknesses = { "Cannot heal self", "Restoration requires focus" },
    },

    -- Example Stand: Silver Chariot (Speed Type)
    SilverChariot = {
        Name = "Silver Chariot",
        LocalizedName = "Silver Chariot",
        Rarity = "Rare",
        Stats = {
            Power = 0.7,
            Speed = 1.0,
            Range = 4,
            Durability = 0.7,
            Precision = 1.0,
            Potential = 0.6,
        },
        Abilities = {
            {
                Name = "Rapid Thrust",
                Type = "Rush",
                EnergyCost = 30,
                Cooldown = 3.0,
                Damage = 2,
                HitsPerSecond = 12,
                Duration = 1.0,
            },
            {
                Name = "Armor Shed",
                Type = "Mode",
                EnergyCost = 50,
                Duration = 15.0,
                SpeedBoost = 1.5,
                DefenseReduction = 0.5,
            },
            {
                Name = "Shooting Star",
                Type = "Ranged",
                EnergyCost = 35,
                Cooldown = 12.0,
                Damage = 20,
                Range = 30,
                OneTimeUse = true,  -- Loses rapier
            },
        },
        Weaknesses = { "Lower durability", "Armor shed increases risk" },
    },
}

-- ============================================================================
-- PLAYER STAND STATE
-- ============================================================================

local StandStates = {}

function StandService.GetStandState(player: Player)
    if not StandStates[player] then
        StandStates[player] = {
            HasStand = false,
            StandId = nil,
            StandData = nil,

            -- Runtime state
            IsSummoned = false,
            Energy = ManifestationConfig.Stand.Energy.Max,
            MaxEnergy = ManifestationConfig.Stand.Energy.Max,

            -- Cooldowns
            SummonCooldown = 0,
            AbilityCooldowns = {},

            -- Current action
            CurrentAction = nil,
            ActionEndTime = 0,

            -- Mastery
            Mastery = 0,
            Experience = 0,
        }
    end
    return StandStates[player]
end

function StandService.ClearStandState(player: Player)
    StandStates[player] = nil
end

-- ============================================================================
-- STAND ACQUISITION
-- ============================================================================

function StandService.GiveStand(player: Player, standId: string): boolean
    local standData = StandService.StandRegistry[standId]
    if not standData then
        warn("[StandService] Invalid Stand ID:", standId)
        return false
    end

    local state = StandService.GetStandState(player)

    -- Check if already has a Stand
    if state.HasStand then
        warn("[StandService] Player already has a Stand")
        return false
    end

    state.HasStand = true
    state.StandId = standId
    state.StandData = standData
    state.Mastery = 0
    state.Experience = 0

    -- Initialize ability cooldowns
    for _, ability in ipairs(standData.Abilities) do
        state.AbilityCooldowns[ability.Name] = 0
    end

    -- Register with combat service for damage modifiers
    CombatService.RegisterManifestationModifier(player, "Stand", {
        DamageModifier = function(hitData, damage)
            return StandService.ApplyStandDamageModifier(player, hitData, damage)
        end,
    })

    StandService.FireEvent("StandAcquired", {
        Player = player,
        StandId = standId,
        StandData = standData,
    })

    print("[StandService] Stand acquired:", standId, "for", player.Name)
    return true
end

function StandService.RemoveStand(player: Player)
    local state = StandService.GetStandState(player)

    if state.IsSummoned then
        StandService.DismissStand(player)
    end

    state.HasStand = false
    state.StandId = nil
    state.StandData = nil

    CombatService.UnregisterManifestationModifier(player, "Stand")

    StandService.FireEvent("StandRemoved", { Player = player })
end

-- ============================================================================
-- STAND SUMMONING (THE CRITICAL DECISION)
-- ============================================================================

function StandService.CanSummonStand(player: Player): boolean
    local state = StandService.GetStandState(player)
    local combatState = CombatService.GetPlayerState(player)

    if not state.HasStand then
        return false
    end

    if state.IsSummoned then
        return false
    end

    if state.SummonCooldown > tick() then
        return false
    end

    -- Can't summon while stunned/knocked down
    local invalidStates = { "Stunned", "Knockdown", "GrabbedBy", "Exhausted" }
    for _, invalidState in ipairs(invalidStates) do
        if combatState.State == invalidState then
            return false
        end
    end

    return true
end

function StandService.SummonStand(player: Player): boolean
    if not StandService.CanSummonStand(player) then
        return false
    end

    local state = StandService.GetStandState(player)
    local combatState = CombatService.GetPlayerState(player)
    local config = ManifestationConfig.Stand

    -- VULNERABLE DURING SUMMON - This is the risk of manifestation
    combatState.State = "Attacking"  -- Can be hit during summon
    state.CurrentAction = "Summoning"

    -- After summon time, Stand appears
    task.delay(config.SummonTime, function()
        if StandStates[player] and state.CurrentAction == "Summoning" then
            state.IsSummoned = true
            state.CurrentAction = nil
            combatState.State = "Idle"

            StandService.FireEvent("StandSummoned", {
                Player = player,
                StandId = state.StandId,
            })
        end
    end)

    return true
end

function StandService.DismissStand(player: Player): boolean
    local state = StandService.GetStandState(player)

    if not state.IsSummoned then
        return false
    end

    local config = ManifestationConfig.Stand

    state.IsSummoned = false
    state.SummonCooldown = tick() + config.SummonCooldown
    state.CurrentAction = nil

    StandService.FireEvent("StandDismissed", { Player = player })

    return true
end

-- Forced dismiss (when user is hit hard)
function StandService.ForceDismiss(player: Player, stunDuration: number?)
    local state = StandService.GetStandState(player)
    local combatState = CombatService.GetPlayerState(player)
    local config = ManifestationConfig.Stand

    if not state.IsSummoned then
        return
    end

    state.IsSummoned = false
    state.SummonCooldown = tick() + (config.SummonCooldown * 1.5)  -- Longer cooldown on forced dismiss
    state.CurrentAction = nil

    -- Apply stand break stun
    if stunDuration then
        combatState.State = "Stunned"
        task.delay(stunDuration, function()
            if CombatService.GetPlayerState(player).State == "Stunned" then
                combatState.State = "Idle"
            end
        end)
    end

    StandService.FireEvent("StandForceDismissed", { Player = player })
end

-- ============================================================================
-- STAND ENERGY MANAGEMENT
-- ============================================================================

function StandService.ConsumeEnergy(player: Player, amount: number): boolean
    local state = StandService.GetStandState(player)

    if state.Energy < amount then
        return false
    end

    state.Energy = state.Energy - amount

    -- Auto-dismiss if energy depleted
    if state.Energy <= 0 and state.IsSummoned then
        StandService.ForceDismiss(player, ManifestationConfig.Stand.DamageTransfer.StandBreakStun)
    end

    return true
end

function StandService.RegenerateEnergy(player: Player, deltaTime: number)
    local state = StandService.GetStandState(player)
    local config = ManifestationConfig.Stand.Energy

    local regenRate = state.IsSummoned and config.RegenRateSummoned or config.RegenRate

    -- Drain while summoned
    if state.IsSummoned then
        state.Energy = state.Energy - (config.SummonDrain * deltaTime)
        if state.Energy <= 0 then
            StandService.ForceDismiss(player, ManifestationConfig.Stand.DamageTransfer.StandBreakStun)
            return
        end
    end

    -- Regenerate
    state.Energy = math.min(state.MaxEnergy, state.Energy + (regenRate * deltaTime))
end

-- ============================================================================
-- STAND ABILITIES
-- ============================================================================

function StandService.CanUseAbility(player: Player, abilityName: string): boolean
    local state = StandService.GetStandState(player)
    local combatState = CombatService.GetPlayerState(player)

    if not state.IsSummoned then
        return false
    end

    if state.CurrentAction then
        return false
    end

    -- Find ability
    local ability = nil
    for _, a in ipairs(state.StandData.Abilities) do
        if a.Name == abilityName then
            ability = a
            break
        end
    end

    if not ability then
        return false
    end

    -- Check cooldown
    if state.AbilityCooldowns[abilityName] and state.AbilityCooldowns[abilityName] > tick() then
        return false
    end

    -- Check energy
    if state.Energy < ability.EnergyCost then
        return false
    end

    -- Check mastery requirement
    if ability.RequiresMastery and state.Mastery < ability.RequiresMastery then
        return false
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

function StandService.UseAbility(player: Player, abilityName: string, targetData: table?): boolean
    if not StandService.CanUseAbility(player, abilityName) then
        return false
    end

    local state = StandService.GetStandState(player)

    -- Find ability
    local ability = nil
    for _, a in ipairs(state.StandData.Abilities) do
        if a.Name == abilityName then
            ability = a
            break
        end
    end

    -- Consume energy
    if not StandService.ConsumeEnergy(player, ability.EnergyCost) then
        return false
    end

    -- Set cooldown
    state.AbilityCooldowns[abilityName] = tick() + ability.Cooldown

    -- Execute based on type
    if ability.Type == "Rush" then
        return StandService.ExecuteRushAbility(player, ability, targetData)
    elseif ability.Type == "Ranged" then
        return StandService.ExecuteRangedAbility(player, ability, targetData)
    elseif ability.Type == "Utility" then
        return StandService.ExecuteUtilityAbility(player, ability, targetData)
    elseif ability.Type == "Ultimate" then
        return StandService.ExecuteUltimateAbility(player, ability, targetData)
    elseif ability.Type == "Mode" then
        return StandService.ExecuteModeAbility(player, ability, targetData)
    elseif ability.Type == "Special" then
        return StandService.ExecuteSpecialAbility(player, ability, targetData)
    end

    return false
end

-- ============================================================================
-- ABILITY EXECUTION
-- ============================================================================

function StandService.ExecuteRushAbility(player: Player, ability: table, targetData: table?): boolean
    local state = StandService.GetStandState(player)
    local combatState = CombatService.GetPlayerState(player)
    local config = ManifestationConfig.Stand.CombatExtensions.Rush

    state.CurrentAction = "Rush"
    combatState.State = "Attacking"

    local rushStartTime = tick()
    local rushEndTime = rushStartTime + ability.Duration
    local hitInterval = 1 / ability.HitsPerSecond
    local lastHitTime = 0

    -- Rush loop
    local rushConnection
    rushConnection = RunService.Heartbeat:Connect(function()
        if not StandStates[player] or tick() > rushEndTime then
            if rushConnection then
                rushConnection:Disconnect()
            end
            state.CurrentAction = nil
            combatState.State = "Idle"
            return
        end

        -- Check if interrupted (user got hit)
        if combatState.State == "Stunned" or combatState.State == "Knockdown" then
            if rushConnection then
                rushConnection:Disconnect()
            end
            state.CurrentAction = nil
            return
        end

        -- Hit check
        if tick() - lastHitTime >= hitInterval then
            lastHitTime = tick()

            -- Create hitbox for rush hit
            local hits = CombatService.CreateHitbox(player, "Light", {
                Size = Vector3.new(5, 6, 5),
                Offset = Vector3.new(0, 0, -4),
            })

            for _, target in ipairs(hits) do
                local targetState = CombatService.GetPlayerState(target)

                -- Check if blocked
                local blockResult = CombatService.CheckBlock(target, "Light")

                if blockResult.Blocked and not blockResult.PerfectBlock then
                    -- Chip damage on block
                    CombatService.TakeDamage(target, {
                        Attacker = player,
                        Damage = ability.Damage * 0.2,  -- Reduced chip
                        AttackType = "Light",
                        HitPosition = target.Character and target.Character.HumanoidRootPart.Position or Vector3.zero,
                        IsCounterHit = false,
                        ComboHitNumber = 0,
                        ManifestationType = "Stand",
                    })
                elseif blockResult.PerfectBlock then
                    -- Perfect block ends rush!
                    if rushConnection then
                        rushConnection:Disconnect()
                    end
                    state.CurrentAction = nil
                    combatState.State = "Stunned"
                    task.delay(0.5, function()
                        if combatState.State == "Stunned" then
                            combatState.State = "Idle"
                        end
                    end)
                    return
                else
                    -- Clean hit
                    CombatService.TakeDamage(target, {
                        Attacker = player,
                        Damage = ability.Damage * state.StandData.Stats.Power,
                        AttackType = "Light",
                        HitPosition = target.Character and target.Character.HumanoidRootPart.Position or Vector3.zero,
                        IsCounterHit = false,
                        ComboHitNumber = combatState.ComboHits + 1,
                        ManifestationType = "Stand",
                    })
                    CombatService.IncrementCombo(player, target)
                end
            end
        end
    end)

    StandService.FireEvent("AbilityUsed", {
        Player = player,
        AbilityName = ability.Name,
        AbilityType = "Rush",
    })

    return true
end

function StandService.ExecuteRangedAbility(player: Player, ability: table, targetData: table?): boolean
    local state = StandService.GetStandState(player)
    local combatState = CombatService.GetPlayerState(player)

    state.CurrentAction = "Ranged"
    combatState.State = "Attacking"

    -- Startup (reactable!)
    task.delay(ability.Startup or 0.3, function()
        if not StandStates[player] or state.CurrentAction ~= "Ranged" then
            return
        end

        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            return
        end

        -- Ranged hitbox
        local rootPart = character.HumanoidRootPart
        local direction = rootPart.CFrame.LookVector
        local range = ability.Range or ManifestationConfig.Stand.CombatExtensions.RangedOption.Range

        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                local otherChar = otherPlayer.Character
                if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
                    local otherRoot = otherChar.HumanoidRootPart
                    local toTarget = otherRoot.Position - rootPart.Position
                    local distance = toTarget.Magnitude

                    if distance <= range then
                        -- Check if in front of player (cone check)
                        local dotProduct = direction:Dot(toTarget.Unit)
                        if dotProduct > 0.5 then  -- Roughly 60 degree cone
                            local targetState = CombatService.GetPlayerState(otherPlayer)
                            local blockResult = CombatService.CheckBlock(otherPlayer, "Heavy")

                            if blockResult.Blocked then
                                CombatService.TakeDamage(otherPlayer, {
                                    Attacker = player,
                                    Damage = (ability.Damage or 15) * 0.15,
                                    AttackType = "Heavy",
                                    HitPosition = otherRoot.Position,
                                    IsCounterHit = false,
                                    ComboHitNumber = 0,
                                    ManifestationType = "Stand",
                                })
                            else
                                CombatService.TakeDamage(otherPlayer, {
                                    Attacker = player,
                                    Damage = (ability.Damage or 15) * state.StandData.Stats.Power,
                                    AttackType = "Heavy",
                                    HitPosition = otherRoot.Position,
                                    IsCounterHit = targetState.State == "Attacking",
                                    ComboHitNumber = combatState.ComboHits + 1,
                                    ManifestationType = "Stand",
                                })
                            end
                        end
                    end
                end
            end
        end

        state.CurrentAction = nil
        combatState.State = "Idle"
    end)

    StandService.FireEvent("AbilityUsed", {
        Player = player,
        AbilityName = ability.Name,
        AbilityType = "Ranged",
    })

    return true
end

function StandService.ExecuteUtilityAbility(player: Player, ability: table, targetData: table?): boolean
    local state = StandService.GetStandState(player)

    state.CurrentAction = "Utility"

    -- Example: Healing ability
    if ability.HealAmount then
        if ability.CanHealOthers and targetData and targetData.Target then
            CombatService.Heal(targetData.Target, ability.HealAmount)
        else
            -- Crazy Diamond can't heal self
            if state.StandData.Name == "Crazy Diamond" then
                state.CurrentAction = nil
                return false
            end
            CombatService.Heal(player, ability.HealAmount)
        end
    end

    state.CurrentAction = nil

    StandService.FireEvent("AbilityUsed", {
        Player = player,
        AbilityName = ability.Name,
        AbilityType = "Utility",
    })

    return true
end

function StandService.ExecuteUltimateAbility(player: Player, ability: table, targetData: table?): boolean
    local state = StandService.GetStandState(player)
    local combatState = CombatService.GetPlayerState(player)

    -- Ultimate abilities are special cases - Time Stop etc.
    if ability.Name == "Time Stop" then
        return StandService.ExecuteTimeStop(player, ability)
    end

    StandService.FireEvent("AbilityUsed", {
        Player = player,
        AbilityName = ability.Name,
        AbilityType = "Ultimate",
    })

    return true
end

function StandService.ExecuteTimeStop(player: Player, ability: table): boolean
    local state = StandService.GetStandState(player)

    state.CurrentAction = "TimeStop"

    -- Broadcast time stop start
    StandService.FireEvent("TimeStopStarted", {
        Player = player,
        Duration = ability.Duration,
    })

    -- During time stop, all other players are frozen
    -- This would be handled client-side for visuals
    -- Server still processes, but with special rules

    task.delay(ability.Duration, function()
        if StandStates[player] and state.CurrentAction == "TimeStop" then
            state.CurrentAction = nil

            StandService.FireEvent("TimeStopEnded", { Player = player })
        end
    end)

    return true
end

function StandService.ExecuteModeAbility(player: Player, ability: table, targetData: table?): boolean
    local state = StandService.GetStandState(player)

    -- Mode toggle (like Silver Chariot armor shed)
    state.CurrentAction = "ModeActive"
    state.ActiveMode = ability.Name

    -- Apply mode effects
    if ability.SpeedBoost then
        state.ModeSpeedBoost = ability.SpeedBoost
    end
    if ability.DefenseReduction then
        state.ModeDefenseReduction = ability.DefenseReduction
    end

    -- Mode duration
    task.delay(ability.Duration, function()
        if StandStates[player] and state.CurrentAction == "ModeActive" then
            state.CurrentAction = nil
            state.ActiveMode = nil
            state.ModeSpeedBoost = nil
            state.ModeDefenseReduction = nil
        end
    end)

    StandService.FireEvent("ModeActivated", {
        Player = player,
        ModeName = ability.Name,
        Duration = ability.Duration,
    })

    return true
end

function StandService.ExecuteSpecialAbility(player: Player, ability: table, targetData: table?): boolean
    -- Special abilities have unique implementations
    state.CurrentAction = "Special"

    -- Would be implemented per-Stand
    StandService.FireEvent("AbilityUsed", {
        Player = player,
        AbilityName = ability.Name,
        AbilityType = "Special",
    })

    state.CurrentAction = nil
    return true
end

-- ============================================================================
-- STAND DAMAGE TRANSFER (User takes damage when Stand is hit)
-- ============================================================================

function StandService.ApplyStandDamageModifier(player: Player, hitData: table, damage: number): number
    local state = StandService.GetStandState(player)
    local config = ManifestationConfig.Stand.DamageTransfer

    -- If Stand is summoned and hit, check if we should force dismiss
    if state.IsSummoned then
        -- Heavy hits while Stand is out cause forced dismiss
        if hitData.AttackType == "Heavy" or hitData.IsCounterHit then
            if config.ToUser then
                -- Chance to force dismiss based on damage
                if damage > 15 then
                    StandService.ForceDismiss(player, config.StandBreakStun)
                end
            end
        end

        -- Apply defense reduction if in vulnerable mode
        if state.ModeDefenseReduction then
            damage = damage / state.ModeDefenseReduction  -- Increase damage taken
        end
    end

    return damage
end

-- ============================================================================
-- STAND MASTERY & PROGRESSION
-- ============================================================================

function StandService.AddExperience(player: Player, amount: number)
    local state = StandService.GetStandState(player)

    if not state.HasStand then
        return
    end

    state.Experience = state.Experience + amount

    -- Check for level up (simple exponential curve)
    local expRequired = 100 * (1.5 ^ state.Mastery)

    while state.Experience >= expRequired do
        state.Experience = state.Experience - expRequired
        state.Mastery = math.min(state.Mastery + 1, 100)

        StandService.FireEvent("MasteryLevelUp", {
            Player = player,
            NewLevel = state.Mastery,
        })

        expRequired = 100 * (1.5 ^ state.Mastery)
    end
end

-- ============================================================================
-- EVENT SYSTEM
-- ============================================================================

local EventCallbacks = {}

function StandService.OnEvent(eventName: string, callback: (data: table) -> ())
    if not EventCallbacks[eventName] then
        EventCallbacks[eventName] = {}
    end
    table.insert(EventCallbacks[eventName], callback)
end

function StandService.FireEvent(eventName: string, data: table)
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

function StandService.Update(deltaTime: number)
    for player, _ in pairs(StandStates) do
        if player.Parent then
            StandService.RegenerateEnergy(player, deltaTime)
        else
            StandService.ClearStandState(player)
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function StandService.Initialize()
    Players.PlayerRemoving:Connect(function(player)
        StandService.ClearStandState(player)
    end)

    RunService.Heartbeat:Connect(function(deltaTime)
        StandService.Update(deltaTime)
    end)

    -- Grant experience on combat events
    CombatService.OnEvent("HitLanded", function(data)
        if data.Attacker then
            local state = StandService.GetStandState(data.Attacker)
            if state.HasStand and state.IsSummoned then
                StandService.AddExperience(data.Attacker, 5)
            end
        end
    end)

    print("[StandService] Initialized - Stand Arrow manifestation system ready")
end

return StandService
