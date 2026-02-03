--[[
    ProgressionService.lua
    PROGRESSION WITHOUT POWER CREEP

    DESIGN PHILOSOPHY:
    "A veteran player is scary because they KNOW when to act, not because they hit harder."

    Progression unlocks:
    - New interactions
    - New follow-ups
    - New counters
    - New mind games

    NOT:
    - Raw stat inflation
    - One-shot abilities
    - Passive wins
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CombatService = require(script.Parent.Parent.Combat.CombatService)

local ProgressionService = {}
ProgressionService.__index = ProgressionService

-- ============================================================================
-- PROGRESSION CONFIGURATION
-- ============================================================================

ProgressionService.Config = {
    -- Max level cap
    MaxLevel = 100,

    -- Experience requirements (exponential curve, but reasonable)
    BaseExpRequired = 100,
    ExpGrowthRate = 1.15,  -- Each level needs 15% more exp

    -- What progression UNLOCKS (not power increases)
    UnlockTypes = {
        "Technique",      -- New moves/abilities
        "Followup",       -- New combo routes
        "Counter",        -- New defensive options
        "Passive",        -- Subtle quality-of-life improvements
        "Cosmetic",       -- Visual effects, titles
    },

    -- What progression does NOT do
    Forbidden = {
        "DirectDamageIncrease",   -- No +damage per level
        "DirectHealthIncrease",   -- No +HP per level
        "StatInflation",          -- No stat growth
        "PassiveWins",            -- No "you win because high level"
    },
}

-- ============================================================================
-- UNLOCK REGISTRY
-- ============================================================================

-- Each unlock adds OPTIONS, not POWER
ProgressionService.UnlockRegistry = {

    -- ========== BASE COMBAT UNLOCKS (Available to everyone) ==========

    -- Level 5: Learn to read
    {
        Level = 5,
        Type = "Passive",
        Name = "Combat Instinct I",
        Description = "Slightly longer perfect block window (skill expression, not power)",
        Effect = { PerfectBlockWindowBonus = 0.02 },  -- 20ms more window
        Path = "Base",
    },

    -- Level 10: New option
    {
        Level = 10,
        Type = "Technique",
        Name = "Delayed Heavy",
        Description = "Can delay heavy attack release for timing mix-ups",
        Effect = { UnlocksDelayedHeavy = true },
        Path = "Base",
    },

    -- Level 15: Counter option
    {
        Level = 15,
        Type = "Counter",
        Name = "Sidestep Cancel",
        Description = "Can cancel sidestep into attack (punish reads)",
        Effect = { SidestepCancelWindow = 0.1 },
        Path = "Base",
    },

    -- Level 20: Followup option
    {
        Level = 20,
        Type = "Followup",
        Name = "Light-Heavy Link",
        Description = "New combo route: Light x2 -> Heavy",
        Effect = { UnlocksLightHeavyLink = true },
        Path = "Base",
    },

    -- Level 25: Mind game tool
    {
        Level = 25,
        Type = "Technique",
        Name = "Feint",
        Description = "Can cancel attack startup into block or dash",
        Effect = { FeintWindow = 0.1 },
        Path = "Base",
    },

    -- Level 30: Defensive mastery
    {
        Level = 30,
        Type = "Counter",
        Name = "Parry",
        Description = "Perfect block during attack startup = parry (frame advantage)",
        Effect = { UnlocksParry = true, ParryAdvantage = 0.3 },
        Path = "Base",
    },

    -- Level 40: Tech skill
    {
        Level = 40,
        Type = "Technique",
        Name = "Instant Recovery",
        Description = "Tech knockdown faster with precise timing",
        Effect = { InstantRecoveryWindow = 0.1 },
        Path = "Base",
    },

    -- Level 50: Advanced movement
    {
        Level = 50,
        Type = "Technique",
        Name = "Wave Dash",
        Description = "Cancel dash end-lag into another dash (costs more stamina)",
        Effect = { WaveDashCost = 15, WaveDashWindow = 0.05 },
        Path = "Base",
    },

    -- ========== STAND-SPECIFIC UNLOCKS ==========

    {
        Level = 10,
        Type = "Technique",
        Name = "Stand Leap",
        Description = "Quick movement while Stand is summoned",
        Effect = { StandLeapDistance = 10, StandLeapCost = 20 },
        Path = "Stand",
    },

    {
        Level = 20,
        Type = "Followup",
        Name = "Rush Cancel",
        Description = "Can cancel Stand rush into other Stand moves",
        Effect = { RushCancelWindow = 0.2 },
        Path = "Stand",
    },

    {
        Level = 30,
        Type = "Counter",
        Name = "Stand Guard",
        Description = "Stand can block while user attacks (costs energy)",
        Effect = { StandGuardCost = 3 },  -- Per second
        Path = "Stand",
    },

    {
        Level = 40,
        Type = "Technique",
        Name = "Stand Barrage Finisher",
        Description = "Powerful final hit after successful rush",
        Effect = { BarrageFinisherDamage = 15, BarrageFinisherRequiresFullRush = true },
        Path = "Stand",
    },

    {
        Level = 50,
        Type = "Passive",
        Name = "Stand Mastery",
        Description = "Reduced Stand summon time (reads become harder to punish)",
        Effect = { SummonTimeReduction = 0.1 },
        Path = "Stand",
    },

    {
        Level = 60,
        Type = "Technique",
        Name = "Remote Stand Control",
        Description = "Stand can operate slightly further from user",
        Effect = { RangeExtension = 3 },  -- Studs
        Path = "Stand",
    },

    -- ========== HAMON-SPECIFIC UNLOCKS ==========

    {
        Level = 10,
        Type = "Technique",
        Name = "Breathing Efficiency",
        Description = "Faster breath charging",
        Effect = { BreathChargeBonus = 5 },  -- Per second
        Path = "Hamon",
    },

    {
        Level = 20,
        Type = "Followup",
        Name = "Hamon Chain",
        Description = "Can link Hamon techniques together",
        Effect = { TechniqueChainWindow = 0.3 },
        Path = "Hamon",
    },

    {
        Level = 30,
        Type = "Counter",
        Name = "Defensive Hamon",
        Description = "Blocking with Hamon charged deals small damage to attacker",
        Effect = { BlockReflectDamage = 3, BlockReflectCost = 10 },
        Path = "Hamon",
    },

    {
        Level = 40,
        Type = "Technique",
        Name = "Hamon Hypnosis",
        Description = "Brief confusion effect on Hamon grab (visual only, no advantage)",
        Effect = { HypnosisDuration = 0.5 },
        Path = "Hamon",
    },

    {
        Level = 50,
        Type = "Passive",
        Name = "Breath Retention",
        Description = "Slower breath decay out of combat",
        Effect = { DecayReduction = 0.5 },  -- 50% slower
        Path = "Hamon",
    },

    {
        Level = 60,
        Type = "Technique",
        Name = "Hamon Clacker Volley",
        Description = "New ranged option using Hamon-infused projectiles",
        Effect = { ClackerDamage = 8, ClackerRange = 15, ClackerCooldown = 5 },
        Path = "Hamon",
    },

    -- ========== VAMPIRE-SPECIFIC UNLOCKS ==========

    {
        Level = 10,
        Type = "Passive",
        Name = "Enhanced Regeneration",
        Description = "Faster health regen from blood (not more healing, faster)",
        Effect = { RegenSpeedBonus = 1.2 },
        Path = "Vampire",
    },

    {
        Level = 20,
        Type = "Technique",
        Name = "Blood Sense",
        Description = "Briefly highlight low-health enemies (information, not damage)",
        Effect = { BloodSenseRange = 30, BloodSenseThreshold = 0.3 },  -- 30% HP
        Path = "Vampire",
    },

    {
        Level = 30,
        Type = "Followup",
        Name = "Drain Chain",
        Description = "Can link blood drain into freeze attack",
        Effect = { DrainChainWindow = 0.5 },
        Path = "Vampire",
    },

    {
        Level = 40,
        Type = "Counter",
        Name = "Undying Will",
        Description = "Once per life, survive lethal damage at 1 HP (long cooldown)",
        Effect = { UndyingCooldown = 120, UndyingInvulnFrames = 0.5 },
        Path = "Vampire",
    },

    {
        Level = 50,
        Type = "Technique",
        Name = "Mist Form",
        Description = "Brief invulnerability escape (costs lots of blood)",
        Effect = { MistDuration = 0.5, MistCost = 40 },
        Path = "Vampire",
    },

    {
        Level = 60,
        Type = "Passive",
        Name = "Night Lord",
        Description = "Enhanced night bonuses",
        Effect = { NightBonusMultiplier = 1.5 },
        Path = "Vampire",
    },
}

-- ============================================================================
-- PLAYER PROGRESSION STATE
-- ============================================================================

local PlayerProgression = {}

function ProgressionService.GetPlayerProgression(player: Player)
    if not PlayerProgression[player] then
        PlayerProgression[player] = {
            -- Overall player level (base combat mastery)
            Level = 1,
            Experience = 0,

            -- Unlocked abilities
            Unlocks = {},

            -- Path-specific progress tracked separately in manifestation services

            -- Statistics (for matchmaking, not power)
            Stats = {
                TotalFights = 0,
                Wins = 0,
                Losses = 0,
                PerfectBlocks = 0,
                CounterHits = 0,
                CombosCompleted = 0,
                LongestCombo = 0,
            },
        }
    end
    return PlayerProgression[player]
end

-- ============================================================================
-- EXPERIENCE & LEVELING
-- ============================================================================

function ProgressionService.GetExpRequired(level: number): number
    local config = ProgressionService.Config
    return math.floor(config.BaseExpRequired * (config.ExpGrowthRate ^ (level - 1)))
end

function ProgressionService.AddExperience(player: Player, amount: number, source: string?)
    local progression = ProgressionService.GetPlayerProgression(player)

    progression.Experience = progression.Experience + amount

    -- Check for level up
    local expRequired = ProgressionService.GetExpRequired(progression.Level)

    while progression.Experience >= expRequired and progression.Level < ProgressionService.Config.MaxLevel do
        progression.Experience = progression.Experience - expRequired
        progression.Level = progression.Level + 1

        ProgressionService.OnLevelUp(player, progression.Level)

        expRequired = ProgressionService.GetExpRequired(progression.Level)
    end

    ProgressionService.FireEvent("ExperienceGained", {
        Player = player,
        Amount = amount,
        Source = source,
        NewTotal = progression.Experience,
        Level = progression.Level,
    })
end

function ProgressionService.OnLevelUp(player: Player, newLevel: number)
    -- Check for new unlocks
    local newUnlocks = ProgressionService.GetUnlocksAtLevel(player, newLevel)

    for _, unlock in ipairs(newUnlocks) do
        ProgressionService.GrantUnlock(player, unlock)
    end

    ProgressionService.FireEvent("LevelUp", {
        Player = player,
        NewLevel = newLevel,
        NewUnlocks = newUnlocks,
    })
end

-- ============================================================================
-- UNLOCK SYSTEM
-- ============================================================================

function ProgressionService.GetUnlocksAtLevel(player: Player, level: number): { table }
    local unlocks = {}
    local progression = ProgressionService.GetPlayerProgression(player)

    for _, unlock in ipairs(ProgressionService.UnlockRegistry) do
        if unlock.Level == level then
            -- Check if player has the right path
            local pathValid = false

            if unlock.Path == "Base" then
                pathValid = true  -- Everyone gets base unlocks
            elseif unlock.Path == "Stand" then
                -- Check if player has Stand
                local combatState = CombatService.GetPlayerState(player)
                pathValid = combatState.Manifestations["Stand"] ~= nil
            elseif unlock.Path == "Hamon" then
                local combatState = CombatService.GetPlayerState(player)
                pathValid = combatState.Manifestations["Hamon"] ~= nil
            elseif unlock.Path == "Vampire" then
                local combatState = CombatService.GetPlayerState(player)
                pathValid = combatState.Manifestations["Vampire"] ~= nil
            end

            if pathValid then
                table.insert(unlocks, unlock)
            end
        end
    end

    return unlocks
end

function ProgressionService.GrantUnlock(player: Player, unlock: table)
    local progression = ProgressionService.GetPlayerProgression(player)

    -- Check if already unlocked
    if progression.Unlocks[unlock.Name] then
        return
    end

    progression.Unlocks[unlock.Name] = {
        Name = unlock.Name,
        Type = unlock.Type,
        Description = unlock.Description,
        Effect = unlock.Effect,
        UnlockedAt = tick(),
    }

    ProgressionService.ApplyUnlockEffect(player, unlock)

    ProgressionService.FireEvent("UnlockGranted", {
        Player = player,
        Unlock = unlock,
    })
end

function ProgressionService.HasUnlock(player: Player, unlockName: string): boolean
    local progression = ProgressionService.GetPlayerProgression(player)
    return progression.Unlocks[unlockName] ~= nil
end

function ProgressionService.ApplyUnlockEffect(player: Player, unlock: table)
    -- Apply the unlock effect to the player's combat state
    local combatState = CombatService.GetPlayerState(player)

    if not combatState.UnlockEffects then
        combatState.UnlockEffects = {}
    end

    combatState.UnlockEffects[unlock.Name] = unlock.Effect

    -- Specific effect applications would be handled by the combat service
    -- checking for these effects during relevant actions
end

-- ============================================================================
-- EXPERIENCE SOURCES (Skill-Based, not Grind-Based)
-- ============================================================================

ProgressionService.ExpSources = {
    -- Winning a fight
    FightWin = 50,

    -- Losing a fight (you still learn!)
    FightLoss = 20,

    -- Perfect block
    PerfectBlock = 5,

    -- Counter hit
    CounterHit = 3,

    -- Completing a combo
    ComboComplete = 2,

    -- Landing a finisher
    Finisher = 10,

    -- Surviving at low health
    ClutchSurvival = 15,

    -- First blood
    FirstBlood = 5,

    -- Comeback victory (won after being lower health)
    ComebackWin = 25,

    -- Flawless victory
    FlawlessWin = 30,

    -- Long fight survival (skill, not camping)
    LongFightBonus = 10,

    -- Using new techniques (encourages learning)
    NewTechniqueUsed = 8,
}

function ProgressionService.AwardFightExperience(winner: Player, loser: Player, fightData: table)
    local winnerProgression = ProgressionService.GetPlayerProgression(winner)
    local loserProgression = ProgressionService.GetPlayerProgression(loser)

    -- Base win/loss exp
    local winnerExp = ProgressionService.ExpSources.FightWin
    local loserExp = ProgressionService.ExpSources.FightLoss

    -- Bonus conditions
    if fightData.WasComeback then
        winnerExp = winnerExp + ProgressionService.ExpSources.ComebackWin
    end

    if fightData.WasFlawless then
        winnerExp = winnerExp + ProgressionService.ExpSources.FlawlessWin
    end

    if fightData.WasClutch then
        winnerExp = winnerExp + ProgressionService.ExpSources.ClutchSurvival
    end

    -- Underdog bonus (lower level beats higher level)
    if winnerProgression.Level < loserProgression.Level then
        local levelDiff = loserProgression.Level - winnerProgression.Level
        winnerExp = winnerExp + (levelDiff * 5)  -- Bonus for punching up
    end

    -- Apply experience
    ProgressionService.AddExperience(winner, winnerExp, "FightWin")
    ProgressionService.AddExperience(loser, loserExp, "FightLoss")

    -- Update stats
    winnerProgression.Stats.TotalFights = winnerProgression.Stats.TotalFights + 1
    winnerProgression.Stats.Wins = winnerProgression.Stats.Wins + 1

    loserProgression.Stats.TotalFights = loserProgression.Stats.TotalFights + 1
    loserProgression.Stats.Losses = loserProgression.Stats.Losses + 1
end

-- ============================================================================
-- COMBAT EVENT HOOKS (Experience from skill expression)
-- ============================================================================

function ProgressionService.SetupCombatHooks()
    CombatService.OnEvent("PerfectBlock", function(data)
        local player = data.Blocker
        local progression = ProgressionService.GetPlayerProgression(player)

        progression.Stats.PerfectBlocks = progression.Stats.PerfectBlocks + 1
        ProgressionService.AddExperience(player, ProgressionService.ExpSources.PerfectBlock, "PerfectBlock")
    end)

    CombatService.OnEvent("HitLanded", function(data)
        if data.IsCounterHit then
            local player = data.Attacker
            local progression = ProgressionService.GetPlayerProgression(player)

            progression.Stats.CounterHits = progression.Stats.CounterHits + 1
            ProgressionService.AddExperience(player, ProgressionService.ExpSources.CounterHit, "CounterHit")
        end
    end)

    CombatService.OnEvent("ComboCompleted", function(data)
        local player = data.Player
        local progression = ProgressionService.GetPlayerProgression(player)

        progression.Stats.CombosCompleted = progression.Stats.CombosCompleted + 1

        if data.ComboLength > progression.Stats.LongestCombo then
            progression.Stats.LongestCombo = data.ComboLength
        end

        ProgressionService.AddExperience(player, ProgressionService.ExpSources.ComboComplete, "Combo")
    end)

    CombatService.OnEvent("FinisherExecuted", function(data)
        ProgressionService.AddExperience(data.Attacker, ProgressionService.ExpSources.Finisher, "Finisher")
    end)
end

-- ============================================================================
-- MATCHMAKING CONSIDERATION (Not Power-Based)
-- ============================================================================

function ProgressionService.GetMatchmakingRating(player: Player): number
    local progression = ProgressionService.GetPlayerProgression(player)

    -- Rating based on skill metrics, not level
    local stats = progression.Stats

    if stats.TotalFights < 10 then
        return 1000  -- Default rating for new players
    end

    local winRate = stats.Wins / stats.TotalFights
    local skillMetrics = {
        PerfectBlockRate = stats.PerfectBlocks / stats.TotalFights,
        CounterHitRate = stats.CounterHits / stats.TotalFights,
        ComboRate = stats.CombosCompleted / stats.TotalFights,
    }

    -- Weighted rating (win rate matters most, but skill expression also counts)
    local rating = 1000
    rating = rating + (winRate * 500)
    rating = rating + (skillMetrics.PerfectBlockRate * 100)
    rating = rating + (skillMetrics.CounterHitRate * 50)
    rating = rating + (skillMetrics.ComboRate * 25)

    return math.floor(rating)
end

-- ============================================================================
-- EVENT SYSTEM
-- ============================================================================

local EventCallbacks = {}

function ProgressionService.OnEvent(eventName: string, callback: (data: table) -> ())
    if not EventCallbacks[eventName] then
        EventCallbacks[eventName] = {}
    end
    table.insert(EventCallbacks[eventName], callback)
end

function ProgressionService.FireEvent(eventName: string, data: table)
    local callbacks = EventCallbacks[eventName]
    if callbacks then
        for _, callback in ipairs(callbacks) do
            task.spawn(callback, data)
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function ProgressionService.Initialize()
    ProgressionService.SetupCombatHooks()

    Players.PlayerRemoving:Connect(function(player)
        -- Save progression data here
        PlayerProgression[player] = nil
    end)

    print("[ProgressionService] Initialized - Progression unlocks OPTIONS, not POWER")
end

-- ============================================================================
-- API
-- ============================================================================

function ProgressionService.GetPlayerStats(player: Player): table
    local progression = ProgressionService.GetPlayerProgression(player)

    return {
        Level = progression.Level,
        Experience = progression.Experience,
        ExpToNext = ProgressionService.GetExpRequired(progression.Level),
        TotalUnlocks = 0,  -- Count unlocks
        Stats = progression.Stats,
        MatchmakingRating = ProgressionService.GetMatchmakingRating(player),
    }
end

function ProgressionService.GetAvailableUnlocks(player: Player): { table }
    local progression = ProgressionService.GetPlayerProgression(player)
    local available = {}

    for _, unlock in ipairs(ProgressionService.UnlockRegistry) do
        if unlock.Level <= progression.Level and not progression.Unlocks[unlock.Name] then
            -- Check path validity
            local pathValid = false
            if unlock.Path == "Base" then
                pathValid = true
            else
                local combatState = CombatService.GetPlayerState(player)
                pathValid = combatState.Manifestations[unlock.Path] ~= nil
            end

            if pathValid then
                table.insert(available, unlock)
            end
        end
    end

    return available
end

return ProgressionService
