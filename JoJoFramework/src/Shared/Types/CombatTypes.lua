--[[
    CombatTypes.lua
    Type definitions for the combat system
]]

export type AttackType = "Light" | "Heavy" | "Grab" | "Finisher"

export type CombatState =
    "Idle"
    | "Attacking"
    | "Blocking"
    | "PerfectBlocking"
    | "Dashing"
    | "Sidestepping"
    | "Stunned"
    | "Knockdown"
    | "GrabbedBy"
    | "Grabbing"
    | "Exhausted"
    | "TechRecovery"

export type InputType =
    "LightAttack"
    | "HeavyAttack"
    | "Block"
    | "Dash"
    | "Sidestep"
    | "Grab"
    | "Finisher"
    | "Burst"
    | "Tech"

export type BufferedInput = {
    InputType: InputType,
    Timestamp: number,
    Direction: Vector3?,
}

export type HitData = {
    Attacker: Player,
    Damage: number,
    AttackType: AttackType,
    HitPosition: Vector3,
    Knockback: Vector3?,
    IsCounterHit: boolean,
    ComboHitNumber: number,
    ManifestationType: string?,
}

export type CombatStats = {
    Health: number,
    MaxHealth: number,
    Stamina: number,
    MaxStamina: number,
    IsExhausted: boolean,
    ComboHits: number,
    LastHitTime: number,
    BurstCooldown: number,
    TechCooldown: number,
}

export type AttackData = {
    AttackType: AttackType,
    Damage: number,
    Startup: number,
    Active: number,
    Recovery: number,
    Hitstun: number,
    Knockback: number?,
    HitboxSize: Vector3,
    HitboxOffset: Vector3,
    StaminaCost: number,
    CanChain: boolean,
    ChainWindow: number?,
}

export type BlockResult = {
    Blocked: boolean,
    PerfectBlock: boolean,
    ChipDamage: number,
    Blockstun: number,
    CounterWindowOpen: boolean,
}

export type ComboState = {
    CurrentHits: number,
    TotalDamage: number,
    ScalingMultiplier: number,
    CanContinue: boolean,
    TimeToReset: number,
}

return {
    -- Type exports for documentation purposes
    -- Actual types are exported via `export type` above
}
