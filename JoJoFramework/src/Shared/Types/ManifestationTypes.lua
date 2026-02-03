--[[
    ManifestationTypes.lua
    Type definitions for manifestation systems (Stand, Hamon, Vampire)
]]

-- ============================================================================
-- CORE MANIFESTATION TYPES
-- ============================================================================

export type ManifestationType = "None" | "Stand" | "Hamon" | "Vampire"

export type ManifestationState = {
    Primary: ManifestationType,
    Secondary: ManifestationType?,
    MasteryLevels: { [ManifestationType]: number },
}

-- ============================================================================
-- STAND TYPES
-- ============================================================================

export type StandStats = {
    Power: number,        -- A-E scale internally 1.0-0.2
    Speed: number,
    Range: number,        -- In studs
    Durability: number,
    Precision: number,
    Potential: number,    -- Growth rate
}

export type StandState = {
    IsSummoned: boolean,
    Energy: number,
    MaxEnergy: number,
    IsOnCooldown: boolean,
    CooldownRemaining: number,
    CurrentAction: string?,
}

export type StandAbility = {
    Name: string,
    Description: string,
    EnergyCost: number,
    Cooldown: number,
    Startup: number,
    Active: number,
    Recovery: number,
    CanBeInterrupted: boolean,
}

export type StandDefinition = {
    Name: string,
    LocalizedName: string,
    Stats: StandStats,
    Abilities: { StandAbility },
    PassiveEffects: { string }?,
    Rarity: "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary",
}

-- ============================================================================
-- HAMON TYPES
-- ============================================================================

export type HamonState = {
    Breath: number,
    MaxBreath: number,
    IsBreathing: boolean,
    BreathingInterrupted: boolean,
    ConsecutiveUseStacks: number,
    LastTechniqueTime: number,
}

export type HamonTechnique = {
    Name: string,
    Description: string,
    BreathCost: number,
    Cooldown: number,
    Damage: number?,
    BonusVsVampire: number?,
    BonusVsStand: number?,
    Effect: string?,
}

export type HamonEnhancement = {
    AttackType: string,      -- Which attack it enhances
    BreathCost: number,
    BonusDamage: number?,
    BonusEffect: string?,
}

-- ============================================================================
-- VAMPIRE TYPES
-- ============================================================================

export type VampireState = {
    Blood: number,
    MaxBlood: number,
    IsInSunlight: boolean,
    SunlightDamageAccumulated: number,
    ActiveMinions: number,
    BloodDrainActive: boolean,
}

export type VampireAbility = {
    Name: string,
    Description: string,
    BloodCost: number,
    Cooldown: number,
    Damage: number?,
    Range: number?,
    Effect: string?,
}

export type VampirePassive = {
    Name: string,
    Description: string,
    Effect: string,
    Magnitude: number,
    Condition: string?,
}

-- ============================================================================
-- INTERACTION TYPES
-- ============================================================================

export type MatchupModifier = {
    AttackerType: ManifestationType,
    DefenderType: ManifestationType,
    DamageMultiplier: number,
    SpecialEffect: string?,
}

export type CombinationBonus = {
    Types: { ManifestationType },
    Bonuses: { string },
    Penalties: { string },
}

-- ============================================================================
-- PROGRESSION TYPES
-- ============================================================================

export type MasteryProgress = {
    Level: number,
    Experience: number,
    ExperienceToNext: number,
    UnlockedAbilities: { string },
    UnlockedTechniques: { string },
}

export type ProgressionReward = {
    Level: number,
    RewardType: "Ability" | "Technique" | "Passive" | "StatBonus",
    RewardId: string,
    Description: string,
}

return {
    -- Type exports for documentation
}
