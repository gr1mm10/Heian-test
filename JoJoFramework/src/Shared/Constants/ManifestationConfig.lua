--[[
    ManifestationConfig.lua
    Configuration for the THREE MANIFEST PATHS

    DESIGN PHILOSOPHY:
    "Before any power, you are dangerous. After gaining one, you are dangerous in a new way."

    Each path EXTENDS combat, not REPLACES it.
    Nothing is unbeatable - knowledge wins fights.
]]

local ManifestationConfig = {}

-- ============================================================================
-- MANIFESTATION TYPES
-- ============================================================================
ManifestationConfig.Types = {
    NONE = "None",
    STAND = "Stand",
    HAMON = "Hamon",
    VAMPIRE = "Vampire",
}

-- ============================================================================
-- VALID COMBINATIONS
-- ============================================================================
ManifestationConfig.ValidCombinations = {
    -- Single paths
    { "None" },
    { "Stand" },
    { "Hamon" },
    { "Vampire" },

    -- Dual paths
    { "Stand", "Hamon" },    -- Strong synergy, limited sustain, requires mastery
    { "Stand", "Vampire" },  -- Extremely powerful, extremely risky, hard counters exist

    -- INVALID: Hamon + Vampire (lore-accurate - they're opposites)
}

-- ============================================================================
-- STAND CONFIGURATION
-- ============================================================================
--[[
    STAND PHILOSOPHY:
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
ManifestationConfig.Stand = {
    -- Summoning
    SummonTime = 0.4,            -- Vulnerable during summon
    DismissTime = 0.2,
    SummonCooldown = 1.0,        -- After dismiss

    -- Stand Stats (Base - modified by specific Stand type)
    BaseStats = {
        Power = 1.0,             -- Damage multiplier
        Speed = 1.0,             -- Attack speed multiplier
        Range = 10,              -- Operating distance in studs
        Durability = 1.0,        -- How much damage Stand can take
        Precision = 1.0,         -- Hitbox accuracy
    },

    -- Stand Damage Transfer
    DamageTransfer = {
        ToUser = 0.7,            -- 70% of Stand damage goes to user
        StandBreakStun = 1.5,    -- Stun duration when Stand breaks
    },

    -- Stand Energy (limits Stand usage)
    Energy = {
        Max = 100,
        RegenRate = 8,           -- Per second when Stand is dismissed
        RegenRateSummoned = 2,   -- Much slower when active
        SummonDrain = 5,         -- Per second while summoned
    },

    -- Stand Combat Extensions
    CombatExtensions = {
        -- Stand Rush (barrage attack)
        Rush = {
            EnergyCost = 40,
            Duration = 2.0,
            HitsPerSecond = 8,
            DamagePerHit = 3,
            CanBeBlocked = true,
            CanBeInterrupted = true,  -- If user is hit
        },

        -- Stand Strike (single powerful hit)
        Strike = {
            EnergyCost = 25,
            Startup = 0.3,
            Damage = 22,
            Knockback = 20,
        },

        -- Ranged Pressure
        RangedOption = {
            EnergyCost = 15,
            Range = 25,
            Damage = 10,
            Cooldown = 2.0,
        },
    },

    -- Vulnerability Windows
    Vulnerabilities = {
        SummoningInterruptible = true,
        UserStunnedDismisses = true,  -- Getting hit hard dismisses Stand
        StandDestroyedStuns = true,
    },
}

-- ============================================================================
-- HAMON CONFIGURATION
-- ============================================================================
--[[
    HAMON PHILOSOPHY:
    Hamon does NOT summon anything. It flows through base combat.

    Hamon rewards:
    - Precision
    - Timing
    - Defensive mastery

    Hamon users feel: clean, technical, deadly - NOT flashy.
]]
ManifestationConfig.Hamon = {
    -- Breath System (Hamon's Resource)
    Breath = {
        Max = 100,
        RegenRate = 0,           -- Must actively breathe to charge
        BreathingChargeRate = 20, -- Per second while breathing
        DecayRate = 3,           -- Passive decay per second
        DecayOnHit = 15,         -- Lose breath when hit
    },

    -- Breathing State
    Breathing = {
        CanMoveWhileBreathing = true,
        MovementSpeedWhileBreathing = 0.6,  -- 60% speed
        InterruptibleByDamage = true,
        MinimumBreathTime = 0.5, -- Must breathe at least this long
    },

    -- Combat Extensions (flows through base combat)
    CombatExtensions = {
        -- Light attacks gain sunlight properties
        SunlightLights = {
            BreathCost = 5,
            BonusDamageVsVampire = 1.5,  -- 50% more
            BonusDamageVsStand = 1.1,    -- 10% more (disrupts manifestation)
        },

        -- Perfect blocks trigger counter shocks
        OverdriveCounter = {
            BreathCost = 15,
            RequiresPerfectBlock = true,
            Damage = 15,
            StunDuration = 0.5,
            AutoTrigger = false,  -- Must input, not automatic
        },

        -- Grabs become nerve-locks
        NerveLock = {
            BreathCost = 20,
            AdditionalGrabDamage = 8,
            AppliesWeaken = true,
            WeakenDuration = 3.0,
            WeakenAmount = 0.15,  -- 15% more damage taken
        },

        -- Finishers deal bonus damage to Vampires & Stands
        SunlightFinisher = {
            BreathCost = 30,
            BonusDamageVsVampire = 2.0,  -- Double damage
            BonusDamageVsStand = 1.3,
            AppliesBurn = true,   -- DoT to vampires
            BurnDamage = 5,
            BurnDuration = 3.0,
        },

        -- Hamon Breathing Techniques
        Techniques = {
            -- Zoom Punch (extended reach)
            ZoomPunch = {
                BreathCost = 25,
                RangeMultiplier = 2.0,
                Damage = 12,
                Cooldown = 4.0,
            },

            -- Sendou Wave Kick
            WaveKick = {
                BreathCost = 30,
                Damage = 18,
                Knockback = 25,
                Cooldown = 5.0,
            },

            -- Overdrive Barrage
            OverdriveBarrage = {
                BreathCost = 50,
                Duration = 1.5,
                HitsPerSecond = 6,
                DamagePerHit = 4,
                Cooldown = 8.0,
            },
        },
    },

    -- Limitations (Hamon is weaker if spammed)
    Limitations = {
        LowBreathPenalty = {
            Threshold = 20,          -- Below 20% breath
            DamageReduction = 0.3,   -- 30% less damage
            TechniquesFail = true,   -- Can't use techniques
        },
        ConsecutiveUsePenalty = {
            StacksPerUse = 1,
            MaxStacks = 5,
            DamageReductionPerStack = 0.05,  -- 5% per stack
            StackDecayTime = 2.0,    -- Seconds to lose a stack
        },
    },
}

-- ============================================================================
-- VAMPIRE CONFIGURATION
-- ============================================================================
--[[
    VAMPIRE PHILOSOPHY:
    Vampirism alters the body, not combat rules.

    Vampires win through:
    - Aggression
    - Momentum
    - Attrition

    Vampires feel: overwhelming, but unstable.
]]
ManifestationConfig.Vampire = {
    -- Blood System (Vampire's Resource)
    Blood = {
        Max = 100,
        StartingBlood = 50,
        DecayRate = 2,           -- Passive decay per second
        DecayRateDay = 8,        -- Much faster during day
    },

    -- Passive Enhancements
    Passives = {
        -- Faster recovery
        RecoverySpeedMultiplier = 1.3,   -- 30% faster recovery frames
        HitstunReduction = 0.15,         -- 15% less hitstun taken

        -- Life-steal on clean hits (not blocked)
        LifeSteal = {
            Percent = 0.2,        -- 20% of damage dealt
            RequiresCleanHit = true,
            DoesNotWorkOnVampires = true,
        },

        -- Enhanced base stats
        DamageMultiplier = 1.1,  -- 10% more damage
        SpeedMultiplier = 1.15,  -- 15% faster

        -- Night bonus
        NightBonus = {
            AdditionalDamage = 0.1,
            AdditionalSpeed = 0.1,
            AdditionalLifeSteal = 0.1,
        },
    },

    -- Combat Extensions
    CombatExtensions = {
        -- Enhanced grabs (blood drain)
        BloodDrain = {
            BloodGain = 25,
            AdditionalDamage = 10,
            HealAmount = 15,
            ExtendedGrabDuration = 0.5,  -- Longer grab animation
        },

        -- Vaporization Freeze
        Freeze = {
            BloodCost = 30,
            Damage = 15,
            FreezesDuration = 1.0,  -- Target can't act
            Range = 8,
            Cooldown = 6.0,
            Startup = 0.4,         -- Reactable
        },

        -- Space Ripper Stingy Eyes
        EyeBeam = {
            BloodCost = 40,
            Damage = 25,
            Range = 30,
            Cooldown = 8.0,
            Startup = 0.5,
            Blockable = true,
        },

        -- Zombie Creation (minion, limited)
        ZombieMinion = {
            BloodCost = 60,
            MinionHealth = 30,
            MinionDamage = 5,
            MaxMinions = 1,
            Duration = 15.0,
        },
    },

    -- WEAKNESSES (Critical for balance)
    Weaknesses = {
        -- Hamon is TERRIFYING
        HamonDamageMultiplier = 1.5,     -- 50% more damage from Hamon
        HamonBurnDamage = 8,             -- DoT from Hamon hits
        HamonBurnDuration = 3.0,

        -- Sunlight/Daylight
        Daylight = {
            DamagePerSecond = 5,
            InSunlight = true,           -- Direct sunlight
            SpeedReduction = 0.2,        -- 20% slower
            LifeStealDisabled = true,
            CanBeLethal = true,          -- Can kill if no cover
        },

        -- Overextension punishment
        LowBloodPenalty = {
            Threshold = 20,
            SpeedReduction = 0.3,
            DamageTakenIncrease = 0.25,
            NoLifeSteal = true,
        },

        -- Recovery vulnerability
        HeavyHitStagger = {
            HeavyHitsRequiredForStagger = 2,  -- Consecutive heavies
            StaggerDuration = 0.8,
            StaggerDamageTaken = 1.5,
        },
    },
}

-- ============================================================================
-- INTERACTION RULES (JoJo Core Matchups)
-- ============================================================================
ManifestationConfig.Interactions = {
    -- Stand vs Stand
    StandVsStand = {
        Description = "Space control, mind games, punish overextensions",
        StandClashEnabled = true,
        ClashDetermination = "Power stat comparison",
    },

    -- Hamon vs Vampire
    HamonVsVampire = {
        Description = "Hard counter, high reward for skill, mistakes fatal",
        HamonAdvantage = true,
        VampireRisk = "High",
    },

    -- Vampire vs Non-Stand
    VampireVsHuman = {
        Description = "Vampire dominates early, skilled defense turns tide",
        EarlyAdvantage = "Vampire",
        CounterPlay = "Perfect blocks, spacing, attrition",
    },

    -- Stand + Hamon
    StandPlusHamon = {
        Description = "Strong synergy, limited sustain, requires mastery",
        Synergy = {
            StandAttacksCanBeHamonCharged = true,
            HamonChargedStandDamageBonus = 0.2,
        },
        Drawbacks = {
            BreathDecayWhileStandActive = 5,  -- Additional decay
            StandEnergyRegenReduction = 0.3,
        },
    },

    -- Stand + Vampire
    StandPlusVampire = {
        Description = "Extremely powerful, extremely risky, hard counters exist",
        Synergy = {
            StandLifeStealEnabled = true,
            BloodRegenFromStandHits = 0.1,
        },
        Drawbacks = {
            HamonDamageMultiplier = 2.0,      -- DOUBLE Hamon damage
            SunlightDamageToStandAndUser = true,
            BloodDecayWhileStandActive = 3,
        },
    },
}

-- ============================================================================
-- STACKING RULES
-- ============================================================================
ManifestationConfig.StackingRules = {
    -- Maximum manifestations
    MaxManifestations = 2,

    -- Invalid combinations
    InvalidCombinations = {
        { "Hamon", "Vampire" },  -- Lore-accurate incompatibility
    },

    -- Combination costs (balance mechanism)
    DualManifestationCosts = {
        IncreasedResourceDrain = 1.5,    -- 50% more resource usage
        IncreasedWeaknesses = true,
        RequiresMasteryLevel = 50,       -- Must be experienced
    },
}

return ManifestationConfig
