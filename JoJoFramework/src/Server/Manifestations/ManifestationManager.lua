--[[
    ManifestationManager.lua
    MANIFESTATION STACKING & INTERACTION MANAGER

    DESIGN PHILOSOPHY:
    "Nothing is unbeatable — knowledge wins fights."

    You can have:
    - Stand only
    - Hamon only
    - Vampire only
    - Stand + Hamon (strong synergy, limited sustain, requires mastery)
    - Stand + Vampire (extremely powerful, extremely risky, hard counters exist)

    INVALID: Hamon + Vampire (lore-accurate incompatibility)

    Each path adds:
    - Strengths
    - New options
    - NEW WEAKNESSES
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Get references (Rojo structure)
-- script = ManifestationManager, script.Parent = Manifestations, script.Parent.Parent = JoJoFramework
local JoJoFramework = script.Parent.Parent
local SharedFolder = ReplicatedStorage:WaitForChild("JoJoFramework"):WaitForChild("Shared")

local CombatService = require(JoJoFramework.Combat.CombatService)
local StandService = require(script.Parent.StandService)
local HamonService = require(script.Parent.HamonService)
local VampireService = require(script.Parent.VampireService)
local ManifestationConfig = require(SharedFolder.Constants.ManifestationConfig)

local ManifestationManager = {}
ManifestationManager.__index = ManifestationManager

-- ============================================================================
-- PLAYER MANIFESTATION STATE
-- ============================================================================

local PlayerManifestations = {}

function ManifestationManager.GetPlayerManifestations(player: Player)
    if not PlayerManifestations[player] then
        PlayerManifestations[player] = {
            Stand = false,
            Hamon = false,
            Vampire = false,

            -- Combination state
            IsDualManifestation = false,
            CombinationType = nil,

            -- Synergy/Penalty tracking
            ActiveSynergies = {},
            ActivePenalties = {},
        }
    end
    return PlayerManifestations[player]
end

-- ============================================================================
-- MANIFESTATION VALIDATION
-- ============================================================================

function ManifestationManager.CanAcquireManifestation(player: Player, manifestationType: string): (boolean, string?)
    local current = ManifestationManager.GetPlayerManifestations(player)

    -- Check invalid combinations
    if manifestationType == "Hamon" and current.Vampire then
        return false, "Cannot learn Hamon as a Vampire - the sun's breath rejects the undead"
    end

    if manifestationType == "Vampire" and current.Hamon then
        return false, "Cannot become a Vampire with Hamon - the Ripple would destroy you"
    end

    -- Check max manifestations
    local currentCount = 0
    if current.Stand then currentCount = currentCount + 1 end
    if current.Hamon then currentCount = currentCount + 1 end
    if current.Vampire then currentCount = currentCount + 1 end

    if currentCount >= ManifestationConfig.StackingRules.MaxManifestations then
        return false, "Cannot acquire more manifestations - you have reached the limit"
    end

    -- Check mastery requirement for dual manifestation
    if currentCount > 0 then
        local requiredMastery = ManifestationConfig.StackingRules.DualManifestationCosts.RequiresMasteryLevel

        -- Check existing mastery
        if current.Stand then
            local standState = StandService.GetStandState(player)
            if standState.Mastery < requiredMastery then
                return false, string.format("Requires mastery level %d to acquire second manifestation", requiredMastery)
            end
        end

        if current.Hamon then
            local hamonState = HamonService.GetHamonState(player)
            if hamonState.Mastery < requiredMastery then
                return false, string.format("Requires mastery level %d to acquire second manifestation", requiredMastery)
            end
        end

        if current.Vampire then
            local vampireState = VampireService.GetVampireState(player)
            if vampireState.Mastery < requiredMastery then
                return false, string.format("Requires mastery level %d to acquire second manifestation", requiredMastery)
            end
        end
    end

    return true, nil
end

-- ============================================================================
-- MANIFESTATION ACQUISITION
-- ============================================================================

function ManifestationManager.AcquireManifestation(player: Player, manifestationType: string, data: table?): boolean
    local canAcquire, reason = ManifestationManager.CanAcquireManifestation(player, manifestationType)

    if not canAcquire then
        warn("[ManifestationManager]", reason)
        ManifestationManager.FireEvent("AcquisitionFailed", {
            Player = player,
            Type = manifestationType,
            Reason = reason,
        })
        return false
    end

    local current = ManifestationManager.GetPlayerManifestations(player)
    local success = false

    if manifestationType == "Stand" then
        local standId = data and data.StandId or "StarPlatinum"  -- Default for testing
        success = StandService.GiveStand(player, standId)
        if success then
            current.Stand = true
        end

    elseif manifestationType == "Hamon" then
        success = HamonService.GiveHamon(player)
        if success then
            current.Hamon = true
        end

    elseif manifestationType == "Vampire" then
        success = VampireService.GiveVampirism(player)
        if success then
            current.Vampire = true
        end
    end

    if success then
        -- Check for dual manifestation
        ManifestationManager.UpdateCombinationState(player)

        ManifestationManager.FireEvent("ManifestationAcquired", {
            Player = player,
            Type = manifestationType,
        })
    end

    return success
end

function ManifestationManager.RemoveManifestation(player: Player, manifestationType: string)
    local current = ManifestationManager.GetPlayerManifestations(player)

    if manifestationType == "Stand" and current.Stand then
        StandService.RemoveStand(player)
        current.Stand = false

    elseif manifestationType == "Hamon" and current.Hamon then
        HamonService.RemoveHamon(player)
        current.Hamon = false

    elseif manifestationType == "Vampire" and current.Vampire then
        VampireService.RemoveVampirism(player)
        current.Vampire = false
    end

    ManifestationManager.UpdateCombinationState(player)

    ManifestationManager.FireEvent("ManifestationRemoved", {
        Player = player,
        Type = manifestationType,
    })
end

-- ============================================================================
-- COMBINATION STATE & SYNERGIES
-- ============================================================================

function ManifestationManager.UpdateCombinationState(player: Player)
    local current = ManifestationManager.GetPlayerManifestations(player)

    -- Clear old synergies/penalties
    current.ActiveSynergies = {}
    current.ActivePenalties = {}
    current.IsDualManifestation = false
    current.CombinationType = nil

    -- Count manifestations
    local count = 0
    local types = {}
    if current.Stand then count = count + 1; table.insert(types, "Stand") end
    if current.Hamon then count = count + 1; table.insert(types, "Hamon") end
    if current.Vampire then count = count + 1; table.insert(types, "Vampire") end

    if count >= 2 then
        current.IsDualManifestation = true
        current.CombinationType = table.concat(types, "+")

        -- Apply combination effects
        if current.Stand and current.Hamon then
            ManifestationManager.ApplyStandHamonSynergy(player)
        elseif current.Stand and current.Vampire then
            ManifestationManager.ApplyStandVampireSynergy(player)
        end
    end
end

-- ============================================================================
-- STAND + HAMON SYNERGY
-- ============================================================================
--[[
    STAND + HAMON:
    - Strong synergy
    - Limited sustain
    - Requires mastery

    Synergy:
    - Stand attacks can be Hamon charged
    - 20% bonus damage on charged Stand attacks

    Drawbacks:
    - Additional breath decay while Stand is active
    - Reduced Stand energy regeneration
]]

function ManifestationManager.ApplyStandHamonSynergy(player: Player)
    local current = ManifestationManager.GetPlayerManifestations(player)
    local config = ManifestationConfig.Interactions.StandPlusHamon

    -- Synergy: Stand attacks can be Hamon charged
    table.insert(current.ActiveSynergies, {
        Name = "Hamon-Charged Stand",
        Description = "Stand attacks gain Hamon properties when breath is available",
        Effect = "StandHamonCharge",
    })

    -- Penalty: Increased resource drain
    table.insert(current.ActivePenalties, {
        Name = "Split Focus",
        Description = "Maintaining both powers drains resources faster",
        Effect = "IncreasedDrain",
    })

    -- Hook into Stand attacks to apply Hamon
    ManifestationManager.SetupStandHamonHooks(player)

    ManifestationManager.FireEvent("SynergyActivated", {
        Player = player,
        Combination = "Stand+Hamon",
        Synergies = current.ActiveSynergies,
        Penalties = current.ActivePenalties,
    })
end

function ManifestationManager.SetupStandHamonHooks(player: Player)
    -- Modify Stand damage when Hamon breath is available
    local hamonState = HamonService.GetHamonState(player)
    local config = ManifestationConfig.Interactions.StandPlusHamon.Synergy

    -- This would hook into StandService.OnEvent("AbilityUsed")
    StandService.OnEvent("AbilityUsed", function(data)
        if data.Player ~= player then return end

        -- Check if Hamon charging is possible
        if hamonState.Breath >= 10 then
            -- Apply Hamon bonus to Stand damage
            ManifestationManager.FireEvent("StandHamonCharged", {
                Player = player,
                AbilityName = data.AbilityName,
                BonusDamage = config.HamonChargedStandDamageBonus,
            })
        end
    end)
end

-- ============================================================================
-- STAND + VAMPIRE SYNERGY
-- ============================================================================
--[[
    STAND + VAMPIRE:
    - Extremely powerful
    - Extremely risky
    - Hard counters exist

    Synergy:
    - Stand can life steal
    - Blood regenerates from Stand hits

    Drawbacks:
    - DOUBLE Hamon damage
    - Sunlight damages both Stand and User
    - Blood decays faster while Stand is active
]]

function ManifestationManager.ApplyStandVampireSynergy(player: Player)
    local current = ManifestationManager.GetPlayerManifestations(player)
    local config = ManifestationConfig.Interactions.StandPlusVampire

    -- Synergy: Stand life steal
    table.insert(current.ActiveSynergies, {
        Name = "Vampiric Stand",
        Description = "Stand attacks drain life from victims",
        Effect = "StandLifeSteal",
    })

    -- Major Penalty: Extreme Hamon vulnerability
    table.insert(current.ActivePenalties, {
        Name = "Hamon Vulnerability",
        Description = "Take DOUBLE damage from Hamon attacks",
        Effect = "DoubleHamonDamage",
    })

    -- Penalty: Sunlight affects both
    table.insert(current.ActivePenalties, {
        Name = "Solar Weakness",
        Description = "Sunlight damages both you and your Stand",
        Effect = "StandSunlightDamage",
    })

    -- Setup hooks
    ManifestationManager.SetupStandVampireHooks(player)

    ManifestationManager.FireEvent("SynergyActivated", {
        Player = player,
        Combination = "Stand+Vampire",
        Synergies = current.ActiveSynergies,
        Penalties = current.ActivePenalties,
    })
end

function ManifestationManager.SetupStandVampireHooks(player: Player)
    local vampireState = VampireService.GetVampireState(player)
    local standState = StandService.GetStandState(player)
    local config = ManifestationConfig.Interactions.StandPlusVampire

    -- Stand life steal on hit
    StandService.OnEvent("AbilityUsed", function(data)
        if data.Player ~= player then return end

        -- If Stand is summoned, life steal is enabled
        if standState.IsSummoned then
            ManifestationManager.FireEvent("StandLifeStealEnabled", {
                Player = player,
            })
        end
    end)

    -- Increased Hamon vulnerability is handled by modifying the damage modifier
    -- Register enhanced damage modifier
    CombatService.RegisterManifestationModifier(player, "StandVampire", {
        DamageModifier = function(hitData, damage)
            if hitData.ManifestationType == "Hamon" then
                return damage * config.Drawbacks.HamonDamageMultiplier
            end
            return damage
        end,
    })
end

-- ============================================================================
-- MATCHUP CALCULATIONS
-- ============================================================================

function ManifestationManager.GetMatchupAdvantage(attacker: Player, defender: Player): table
    local attackerManif = ManifestationManager.GetPlayerManifestations(attacker)
    local defenderManif = ManifestationManager.GetPlayerManifestations(defender)

    local result = {
        Advantage = "Neutral",
        DamageModifier = 1.0,
        SpecialNotes = {},
    }

    -- Hamon vs Vampire (Hard counter)
    if attackerManif.Hamon and defenderManif.Vampire then
        result.Advantage = "Strong Attacker Advantage"
        result.DamageModifier = ManifestationConfig.Vampire.Weaknesses.HamonDamageMultiplier
        table.insert(result.SpecialNotes, "Hamon counters Vampire - attacks apply burn")

        -- Even stronger if defender is Stand+Vampire
        if defenderManif.Stand then
            result.DamageModifier = ManifestationConfig.Interactions.StandPlusVampire.Drawbacks.HamonDamageMultiplier
            table.insert(result.SpecialNotes, "Stand+Vampire takes DOUBLE Hamon damage")
        end
    end

    -- Vampire vs Non-Stand Human
    if attackerManif.Vampire and not defenderManif.Stand and not defenderManif.Hamon and not defenderManif.Vampire then
        result.Advantage = "Attacker Advantage (Early)"
        result.DamageModifier = ManifestationConfig.Vampire.Passives.DamageMultiplier
        table.insert(result.SpecialNotes, "Vampire dominates early - skilled defense turns tide")
    end

    -- Stand vs Stand
    if attackerManif.Stand and defenderManif.Stand then
        result.Advantage = "Even - Mind Games"
        table.insert(result.SpecialNotes, "Space control and punish overextensions")
    end

    -- Stand + Hamon vs Vampire
    if attackerManif.Stand and attackerManif.Hamon and defenderManif.Vampire then
        result.Advantage = "Strong Attacker Advantage"
        result.DamageModifier = 1.8  -- Combined bonuses
        table.insert(result.SpecialNotes, "Stand+Hamon synergy shreds Vampires")
    end

    -- Pure Human vs Stand User
    if not attackerManif.Stand and not attackerManif.Hamon and not attackerManif.Vampire then
        if defenderManif.Stand then
            result.Advantage = "Defender Advantage"
            table.insert(result.SpecialNotes, "Pure Human has fastest neutral - exploit Stand summon windows")
        end
    end

    return result
end

-- ============================================================================
-- RESOURCE DRAIN MANAGEMENT (Dual Manifestation Cost)
-- ============================================================================

function ManifestationManager.UpdateDualManifestationDrain(player: Player, deltaTime: number)
    local current = ManifestationManager.GetPlayerManifestations(player)

    if not current.IsDualManifestation then
        return
    end

    local drainMultiplier = ManifestationConfig.StackingRules.DualManifestationCosts.IncreasedResourceDrain

    -- Stand + Hamon: Extra breath decay when Stand is summoned
    if current.Stand and current.Hamon then
        local standState = StandService.GetStandState(player)
        local hamonState = HamonService.GetHamonState(player)

        if standState.IsSummoned then
            local extraDecay = ManifestationConfig.Interactions.StandPlusHamon.Drawbacks.BreathDecayWhileStandActive
            hamonState.Breath = math.max(0, hamonState.Breath - (extraDecay * deltaTime))
        end
    end

    -- Stand + Vampire: Extra blood decay when Stand is summoned
    if current.Stand and current.Vampire then
        local standState = StandService.GetStandState(player)
        local vampireState = VampireService.GetVampireState(player)

        if standState.IsSummoned then
            local extraDecay = ManifestationConfig.Interactions.StandPlusVampire.Drawbacks.BloodDecayWhileStandActive
            vampireState.Blood = math.max(0, vampireState.Blood - (extraDecay * deltaTime))
        end
    end
end

-- ============================================================================
-- PURE HUMAN ADVANTAGE
-- ============================================================================
--[[
    PURE HUMAN (No Manifestations):
    - Fastest neutral control
    - No resource management
    - No special weaknesses
    - Base combat mastery is the focus

    A veteran Pure Human is scary because they KNOW when to act.
]]

function ManifestationManager.GetPureHumanBonus(player: Player): table?
    local current = ManifestationManager.GetPlayerManifestations(player)

    if not current.Stand and not current.Hamon and not current.Vampire then
        return {
            Name = "Pure Human Mastery",
            Description = "Focus on base combat grants advantages",
            Bonuses = {
                "No resource management required",
                "No special weaknesses to exploit",
                "Fastest state transitions",
                "Full stamina efficiency",
            },
        }
    end

    return nil
end

-- ============================================================================
-- EVENT SYSTEM
-- ============================================================================

local EventCallbacks = {}

function ManifestationManager.OnEvent(eventName: string, callback: (data: table) -> ())
    if not EventCallbacks[eventName] then
        EventCallbacks[eventName] = {}
    end
    table.insert(EventCallbacks[eventName], callback)
end

function ManifestationManager.FireEvent(eventName: string, data: table)
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

function ManifestationManager.Update(deltaTime: number)
    for player, _ in pairs(PlayerManifestations) do
        if player.Parent then
            ManifestationManager.UpdateDualManifestationDrain(player, deltaTime)
        else
            PlayerManifestations[player] = nil
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function ManifestationManager.Initialize()
    -- Initialize sub-services
    StandService.Initialize()
    HamonService.Initialize()
    VampireService.Initialize()

    -- Clean up on player leave
    Players.PlayerRemoving:Connect(function(player)
        PlayerManifestations[player] = nil
    end)

    -- Update loop
    RunService.Heartbeat:Connect(function(deltaTime)
        ManifestationManager.Update(deltaTime)
    end)

    print("[ManifestationManager] Initialized - Three paths await")
end

-- ============================================================================
-- API: Get Player Status
-- ============================================================================

function ManifestationManager.GetPlayerStatus(player: Player): table
    local current = ManifestationManager.GetPlayerManifestations(player)
    local standState = current.Stand and StandService.GetStandState(player) or nil
    local hamonState = current.Hamon and HamonService.GetHamonState(player) or nil
    local vampireState = current.Vampire and VampireService.GetVampireState(player) or nil

    return {
        Manifestations = {
            Stand = current.Stand,
            Hamon = current.Hamon,
            Vampire = current.Vampire,
        },
        IsDual = current.IsDualManifestation,
        CombinationType = current.CombinationType,
        Synergies = current.ActiveSynergies,
        Penalties = current.ActivePenalties,
        PureHumanBonus = ManifestationManager.GetPureHumanBonus(player),

        -- Resource states
        Stand = standState and {
            Name = standState.StandData and standState.StandData.Name or nil,
            IsSummoned = standState.IsSummoned,
            Energy = standState.Energy,
            Mastery = standState.Mastery,
        } or nil,

        Hamon = hamonState and {
            Breath = hamonState.Breath,
            IsBreathing = hamonState.IsBreathing,
            Mastery = hamonState.Mastery,
        } or nil,

        Vampire = vampireState and {
            Blood = vampireState.Blood,
            IsInSunlight = vampireState.IsInSunlight,
            Mastery = vampireState.Mastery,
        } or nil,
    }
end

return ManifestationManager
