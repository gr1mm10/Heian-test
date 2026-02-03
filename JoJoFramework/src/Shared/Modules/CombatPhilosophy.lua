--[[
    CombatPhilosophy.lua
    THE RULES OF ENGAGEMENT - Combat Design Validation

    This module enforces the core design philosophy:
    "All fights revolve around: Spacing, Timing, Punishment"

    Use this to validate that any new abilities/systems
    adhere to the sacred principles.
]]

local CombatPhilosophy = {}

-- ============================================================================
-- CORE PRINCIPLES (The Sacred Rules)
-- ============================================================================

CombatPhilosophy.Principles = {
    -- PRINCIPLE 1: No Infinite Combos
    NO_INFINITES = {
        Name = "No Infinite Combos",
        Description = "Every combo must have an escape point. Max hits enforced.",
        ValidationFn = function(abilityData)
            -- Check if ability can loop infinitely
            if abilityData.CanChainIntoSelf and not abilityData.MaxChainCount then
                return false, "Ability can chain into itself without limit"
            end
            if abilityData.HitstunDuration and abilityData.Recovery then
                -- Hitstun should not exceed startup + active of followup
                -- This ensures opponent can escape
                local frameAdvantage = abilityData.HitstunDuration - abilityData.Recovery
                if frameAdvantage > 0.5 then  -- More than 0.5s advantage is too much
                    return false, "Frame advantage too high, enables infinites"
                end
            end
            return true
        end,
    },

    -- PRINCIPLE 2: Defense Matters
    DEFENSE_MATTERS = {
        Name = "Defense and Movement Matter",
        Description = "Blocking, dodging, and spacing must be viable counterplay.",
        ValidationFn = function(abilityData)
            -- Unblockables must be reactable
            if abilityData.Unblockable then
                if not abilityData.Startup or abilityData.Startup < 0.3 then
                    return false, "Unblockable attacks must have readable startup (>0.3s)"
                end
            end
            -- Undodgeable must be blockable
            if abilityData.Undodgeable and abilityData.Unblockable then
                return false, "Cannot be both unblockable AND undodgeable"
            end
            return true
        end,
    },

    -- PRINCIPLE 3: Punishable Mistakes
    PUNISHABLE_MISTAKES = {
        Name = "Mistakes Are Punishable",
        Description = "Every strong option must have recovery/vulnerability.",
        ValidationFn = function(abilityData)
            -- High damage must have high recovery
            if abilityData.Damage and abilityData.Damage > 20 then
                if not abilityData.Recovery or abilityData.Recovery < 0.3 then
                    return false, "High damage attacks must have punishable recovery"
                end
            end
            -- Long range must have committal startup
            if abilityData.Range and abilityData.Range > 15 then
                if not abilityData.Startup or abilityData.Startup < 0.4 then
                    return false, "Long range attacks must be committal"
                end
            end
            return true
        end,
    },

    -- PRINCIPLE 4: No Button Mashing
    NO_MASHING = {
        Name = "No Button Mashing",
        Description = "Spam should not be optimal. Timing and precision rewarded.",
        ValidationFn = function(abilityData)
            -- Check for spam prevention
            if abilityData.Cooldown and abilityData.Cooldown < 0.5 then
                if abilityData.Damage and abilityData.Damage > 10 then
                    return false, "Fast cooldown + high damage enables mashing"
                end
            end
            -- Resource cost prevents spam
            if not abilityData.ResourceCost and not abilityData.Cooldown then
                return false, "Ability needs resource cost or cooldown to prevent spam"
            end
            return true
        end,
    },

    -- PRINCIPLE 5: Knowledge Wins Fights
    KNOWLEDGE_WINS = {
        Name = "Knowledge Wins Fights",
        Description = "Understanding matchups should beat raw stats.",
        ValidationFn = function(abilityData)
            -- Hard counters must exist
            if abilityData.Weakness then
                return true
            end
            -- Strong abilities need counterplay
            if abilityData.PowerLevel and abilityData.PowerLevel > 7 then
                if not abilityData.CounterplayOptions then
                    return false, "Strong abilities must have documented counterplay"
                end
            end
            return true
        end,
    },

    -- PRINCIPLE 6: Spacing Matters
    SPACING_MATTERS = {
        Name = "Spacing Is Critical",
        Description = "Range advantages and disadvantages shape neutral game.",
        ValidationFn = function(abilityData)
            -- Range must be defined
            if abilityData.IsAttack and not abilityData.Range then
                return false, "Attacks must have defined range for spacing game"
            end
            return true
        end,
    },

    -- PRINCIPLE 7: Readable Gameplay
    READABLE = {
        Name = "Attacks Are Readable",
        Description = "Players can react to and learn patterns.",
        ValidationFn = function(abilityData)
            -- Minimum startup for powerful attacks
            if abilityData.Damage and abilityData.Damage > 15 then
                if not abilityData.Startup or abilityData.Startup < 0.2 then
                    return false, "Powerful attacks need readable startup"
                end
            end
            -- Visual/audio tells required
            if abilityData.RequiresTell == false then
                return false, "All attacks must have visual/audio tells"
            end
            return true
        end,
    },
}

-- ============================================================================
-- MATCHUP PHILOSOPHY
-- ============================================================================

CombatPhilosophy.MatchupRules = {
    -- Nothing is unbeatable
    ROCK_PAPER_SCISSORS = {
        Description = "Every build/playstyle has counters",
        Examples = {
            "Hamon counters Vampire",
            "Stand range counters Hamon approach",
            "Pure Human speed counters Stand commitment",
            "Vampire aggression pressures Stand resource",
        },
    },

    -- Skill expression always exists
    SKILL_EXPRESSION = {
        Description = "Even in bad matchups, skill can overcome",
        Mechanisms = {
            "Perfect blocks create opportunities",
            "Spacing can neutralize range disadvantage",
            "Resource management matters",
            "Read-based gameplay rewards knowledge",
        },
    },

    -- Counter strength should be earned
    EARNED_COUNTERS = {
        Description = "Hard counters require execution, not just having the type",
        Examples = {
            "Hamon user must land clean hits to counter Vampire",
            "Stand user must summon (vulnerable) to use abilities",
            "Vampire must maintain blood to stay powerful",
        },
    },
}

-- ============================================================================
-- MANIFESTATION BALANCE RULES
-- ============================================================================

CombatPhilosophy.ManifestationRules = {
    -- Extensions, not replacements
    EXTENDS_NOT_REPLACES = {
        Description = "Manifestations extend base combat, never replace it",
        Validation = function(manifestationData)
            -- Must use base combat inputs
            if manifestationData.ReplacesLightAttack then
                return false, "Cannot replace base combat moves"
            end
            if manifestationData.ReplacesBlock then
                return false, "Cannot replace defensive options"
            end
            return true
        end,
    },

    -- Resource gated
    RESOURCE_GATED = {
        Description = "Manifestation abilities require resource management",
        Validation = function(manifestationData)
            for _, ability in ipairs(manifestationData.Abilities or {}) do
                if not ability.ResourceCost or ability.ResourceCost <= 0 then
                    return false, "Manifestation abilities must cost resources"
                end
            end
            return true
        end,
    },

    -- Creates new weaknesses
    NEW_WEAKNESSES = {
        Description = "Gaining a manifestation must introduce new vulnerabilities",
        Validation = function(manifestationData)
            if not manifestationData.Weaknesses or #manifestationData.Weaknesses == 0 then
                return false, "Manifestations must have weaknesses"
            end
            return true
        end,
    },
}

-- ============================================================================
-- VALIDATION FUNCTIONS
-- ============================================================================

function CombatPhilosophy.ValidateAbility(abilityData: table): (boolean, { string })
    local errors = {}

    for principleName, principle in pairs(CombatPhilosophy.Principles) do
        local success, errorMsg = principle.ValidationFn(abilityData)
        if not success then
            table.insert(errors, string.format("[%s] %s", principleName, errorMsg))
        end
    end

    return #errors == 0, errors
end

function CombatPhilosophy.ValidateManifestation(manifestationData: table): (boolean, { string })
    local errors = {}

    for ruleName, rule in pairs(CombatPhilosophy.ManifestationRules) do
        local success, errorMsg = rule.Validation(manifestationData)
        if not success then
            table.insert(errors, string.format("[%s] %s", ruleName, errorMsg))
        end
    end

    -- Also validate each ability
    for _, ability in ipairs(manifestationData.Abilities or {}) do
        local abilityValid, abilityErrors = CombatPhilosophy.ValidateAbility(ability)
        if not abilityValid then
            for _, err in ipairs(abilityErrors) do
                table.insert(errors, string.format("Ability '%s': %s", ability.Name or "Unknown", err))
            end
        end
    end

    return #errors == 0, errors
end

-- ============================================================================
-- COMBO THEORY
-- ============================================================================

CombatPhilosophy.ComboTheory = {
    -- True combo: guaranteed followup
    TRUE_COMBO = {
        Description = "Hitstun exceeds startup of next move",
        MaxLength = 3,  -- True combos should be short
    },

    -- Link: tight timing followup
    LINK = {
        Description = "Hitstun ends near startup of next move",
        FrameWindow = 0.1,  -- 100ms window
    },

    -- Reset: force a new decision point
    RESET = {
        Description = "End combo to force opponent guess",
        Purpose = "Rewards reads, prevents auto-pilot",
    },

    -- Stale moves: repeated moves deal less
    STALE_SCALING = {
        Description = "Same move in combo deals reduced damage",
        PerHitReduction = 0.1,  -- 10% less each repeat
    },
}

-- ============================================================================
-- FRAME DATA GUIDELINES
-- ============================================================================

CombatPhilosophy.FrameDataGuidelines = {
    -- Light attacks: fast but low reward
    LightAttack = {
        StartupRange = { 0.08, 0.15 },
        ActiveRange = { 0.1, 0.2 },
        RecoveryRange = { 0.15, 0.25 },
        OnBlockAdvantage = { -0.1, 0.05 },  -- Slightly minus to plus
    },

    -- Heavy attacks: slow but rewarding
    HeavyAttack = {
        StartupRange = { 0.3, 0.5 },
        ActiveRange = { 0.15, 0.25 },
        RecoveryRange = { 0.3, 0.5 },
        OnBlockAdvantage = { -0.3, -0.15 },  -- Minus, punishable
    },

    -- Special moves: varies by purpose
    SpecialMove = {
        StartupRange = { 0.2, 0.6 },
        RecoveryRange = { 0.2, 0.8 },
        MustHaveCooldown = true,
        MustHaveResourceCost = true,
    },

    -- Grabs: beats block, loses to attack
    Grab = {
        StartupRange = { 0.15, 0.25 },
        RecoveryOnWhiff = { 0.5, 0.8 },  -- Very punishable
    },
}

-- ============================================================================
-- DESIGN CHECKLIST
-- ============================================================================

function CombatPhilosophy.GetDesignChecklist(): { string }
    return {
        "[ ] Can this be blocked or dodged?",
        "[ ] Is the startup readable for the damage it deals?",
        "[ ] Does it have punishable recovery?",
        "[ ] Does it require resources or have a cooldown?",
        "[ ] Does it create a new weakness?",
        "[ ] Can it infinite? If yes, fix it.",
        "[ ] Does it have clear visual/audio tells?",
        "[ ] Is the range appropriate for its speed?",
        "[ ] Does it extend base combat or replace it?",
        "[ ] What counters this?",
        "[ ] What does this counter?",
        "[ ] Is there skill expression in using it?",
        "[ ] Can a skilled player play around this?",
        "[ ] Does spamming it get punished?",
        "[ ] Is the risk/reward balanced?",
    }
end

-- ============================================================================
-- BALANCE TIERS
-- ============================================================================

CombatPhilosophy.BalanceTiers = {
    -- For understanding relative power levels
    S = {
        Description = "Extremely powerful, multiple hard counters must exist",
        Examples = "Ultimate abilities, Stand requiem forms",
        Limitations = "Long cooldown, high resource cost, vulnerability windows",
    },

    A = {
        Description = "Strong, reliable options with clear weaknesses",
        Examples = "Stand rushes, Hamon techniques, Vampire abilities",
        Limitations = "Resource cost, reactable startup, recovery",
    },

    B = {
        Description = "Solid tools that form the backbone of gameplay",
        Examples = "Heavy attacks, dashes, blocks",
        Limitations = "Standard frame data, stamina costs",
    },

    C = {
        Description = "Situational tools with specific use cases",
        Examples = "Sidesteps, specific counters",
        Limitations = "Limited application, requires reads",
    },
}

return CombatPhilosophy
