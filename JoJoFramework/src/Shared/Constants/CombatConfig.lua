--[[
    CombatConfig.lua
    Core combat configuration - THE SACRED FOUNDATION

    DESIGN PHILOSOPHY:
    "If you delete Stands, Hamon, and Vampires from the game, the combat is still fun."

    All fights revolve around:
    - Spacing
    - Timing
    - Punishment

    No infinite combos. No button mashing. Defense and movement matter.
]]

local CombatConfig = {}

-- ============================================================================
-- BASE COMBAT TIMINGS (in seconds)
-- ============================================================================
CombatConfig.Timings = {
    -- Light Attack Chain
    LightAttack = {
        Startup = 0.1,           -- Wind-up before hitbox
        Active = 0.15,           -- Hitbox duration
        Recovery = 0.2,          -- End lag
        ChainWindow = 0.3,       -- Window to chain next light
        MaxChainLength = 4,      -- Maximum combo length (prevents infinites)
    },

    -- Heavy Attack
    HeavyAttack = {
        Startup = 0.35,          -- Slower startup, readable
        Active = 0.2,
        Recovery = 0.4,          -- Punishable on whiff
        ChargeTime = 0.5,        -- Optional charge for more damage
    },

    -- Block System
    Block = {
        StartupToActive = 0.05,  -- Near instant
        PerfectBlockWindow = 0.15, -- Tight timing for skill expression
        BlockstunLight = 0.15,   -- Stun when blocking light
        BlockstunHeavy = 0.3,    -- More stun from heavy
        ChipDamagePercent = 0.1, -- 10% damage through block
    },

    -- Movement
    Dash = {
        Duration = 0.25,
        Cooldown = 0.8,
        IFrames = 0.1,           -- Brief invincibility at start
    },

    Sidestep = {
        Duration = 0.2,
        Cooldown = 0.5,
        IFrames = 0.15,
    },

    -- Grab System
    Grab = {
        Startup = 0.2,           -- Reactable
        Range = 5,               -- Studs
        WhiffRecovery = 0.6,     -- Very punishable on miss
        ThrowDuration = 0.8,
    },

    -- Context Finisher
    Finisher = {
        ActivationWindow = 1.0,  -- Time to input after stagger
        ExecutionTime = 1.5,
        ImmunityDuringExecution = true,
    },

    -- Stagger/Hitstun
    Hitstun = {
        Light = 0.2,
        Heavy = 0.4,
        Counter = 0.6,           -- From perfect block punish
    },

    -- Recovery after knockdown
    Knockdown = {
        Duration = 1.0,
        GetupIFrames = 0.3,      -- Can't be hit immediately on wakeup
    },
}

-- ============================================================================
-- BASE DAMAGE VALUES
-- ============================================================================
CombatConfig.Damage = {
    -- Base Human Damage (no manifestation)
    Light = 8,
    Heavy = 18,
    GrabThrow = 12,
    Finisher = 25,

    -- Combo Scaling (prevents infinite damage loops)
    ComboScaling = {
        Hit1 = 1.0,    -- 100% damage
        Hit2 = 0.9,    -- 90%
        Hit3 = 0.8,    -- 80%
        Hit4 = 0.7,    -- 70%
        Hit5Plus = 0.5, -- 50% cap
    },

    -- Counter Hit Multiplier (punishing bad timing)
    CounterHitMultiplier = 1.3,
}

-- ============================================================================
-- STAMINA / RESOURCE SYSTEM
-- ============================================================================
CombatConfig.Stamina = {
    MaxStamina = 100,
    RegenRate = 15,              -- Per second
    RegenDelay = 1.0,            -- Delay after using stamina

    Costs = {
        LightAttack = 5,
        HeavyAttack = 15,
        Dash = 20,
        Sidestep = 12,
        Block = 0,               -- Blocking is free but has chip
        PerfectBlock = 0,        -- Rewarded for skill
        Grab = 18,
    },

    -- Exhaustion state (out of stamina)
    Exhaustion = {
        Duration = 1.5,          -- Vulnerable period
        SpeedReduction = 0.5,    -- 50% slower
        DamageTakenMultiplier = 1.2,
    },
}

-- ============================================================================
-- MOVEMENT VALUES
-- ============================================================================
CombatConfig.Movement = {
    WalkSpeed = 16,
    RunSpeed = 24,
    DashSpeed = 50,
    SidestepSpeed = 40,
    BackpedalSpeed = 12,         -- Walking backward is slower

    -- Combat Movement Penalties
    BlockingSpeedMultiplier = 0.4,
    AttackingSpeedMultiplier = 0.2,
}

-- ============================================================================
-- HEALTH SYSTEM
-- ============================================================================
CombatConfig.Health = {
    BaseHealth = 100,

    -- Health regeneration (out of combat only)
    OutOfCombatDelay = 10,       -- Seconds before regen starts
    RegenRate = 5,               -- Per second
}

-- ============================================================================
-- HIT DETECTION / HITBOXES
-- ============================================================================
CombatConfig.Hitboxes = {
    Light = {
        Size = Vector3.new(4, 5, 4),
        Offset = Vector3.new(0, 0, -3),
    },
    Heavy = {
        Size = Vector3.new(5, 6, 5),
        Offset = Vector3.new(0, 0, -3.5),
    },
    Grab = {
        Size = Vector3.new(3, 4, 3),
        Offset = Vector3.new(0, 0, -2.5),
    },
}

-- ============================================================================
-- COMBO RULES (ANTI-INFINITE SYSTEM)
-- ============================================================================
CombatConfig.ComboRules = {
    -- Maximum hits before forced reset
    MaxComboHits = 8,

    -- Burst mechanic (escape tool)
    Burst = {
        Cooldown = 30,           -- Long cooldown, strategic use
        StaminaCost = 50,
        PushbackForce = 30,
    },

    -- Tech/Recovery options
    TechWindow = 0.3,            -- Window to tech out of knockdown
    TechCooldown = 2.0,
}

-- ============================================================================
-- INPUT BUFFER
-- ============================================================================
CombatConfig.InputBuffer = {
    BufferWindow = 0.15,         -- Time to buffer next input
    MaxBufferedInputs = 2,
}

return CombatConfig
