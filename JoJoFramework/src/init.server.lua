--[[
    JoJo Game Framework - Server Initialization
    ============================================

    "Base Combat → Manifest Extension" Framework

    The game has one universal combat system.
    Nothing replaces it — everything builds on top of it.

    DESIGN PHILOSOPHY:
    - Before any power, you are dangerous.
    - After gaining one, you are dangerous in a new way.
    - If you delete Stands, Hamon, and Vampires, the combat is still fun.
    - Knowledge wins fights, not stats.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("========================================")
print("  JoJo Game Framework - Initializing")
print("========================================")

-- ============================================================================
-- SETUP REMOTES FIRST
-- ============================================================================

local RemoteSetup = require(script.Server.Services.RemoteSetup)
local remotesFolder = RemoteSetup.Initialize()

-- ============================================================================
-- INITIALIZE CORE SYSTEMS
-- ============================================================================

-- Combat Service (The Sacred Foundation)
local CombatService = require(script.Server.Combat.CombatService)
CombatService.Initialize()

-- Manifestation Manager (Stand, Hamon, Vampire)
local ManifestationManager = require(script.Server.Manifestations.ManifestationManager)
ManifestationManager.Initialize()

-- Progression Service (No Power Creep)
local ProgressionService = require(script.Server.Progression.ProgressionService)
ProgressionService.Initialize()

-- Input Handler (Client-Server Communication)
local InputHandler = require(script.Server.Services.InputHandler)
InputHandler.Initialize(remotesFolder)

-- ============================================================================
-- PLAYER SETUP
-- ============================================================================

local function OnPlayerAdded(player: Player)
    -- Initialize combat state
    CombatService.GetPlayerState(player)

    -- Initialize progression
    ProgressionService.GetPlayerProgression(player)

    -- Wait for character
    player.CharacterAdded:Connect(function(character)
        -- Reset combat state on respawn
        local state = CombatService.GetPlayerState(player)
        state.Health = state.MaxHealth
        state.Stamina = state.MaxStamina
        state.State = "Idle"
        state.ComboHits = 0

        print("[JoJoFramework] Player respawned:", player.Name)
    end)

    print("[JoJoFramework] Player joined:", player.Name)
end

local function OnPlayerRemoving(player: Player)
    -- Cleanup is handled by individual services
    print("[JoJoFramework] Player left:", player.Name)
end

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-- Handle existing players
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(OnPlayerAdded, player)
end

-- ============================================================================
-- DEBUG COMMANDS (Remove in production)
-- ============================================================================

-- Give a player a Stand for testing
local function GiveTestStand(player: Player, standId: string)
    ManifestationManager.AcquireManifestation(player, "Stand", { StandId = standId })
end

-- Give a player Hamon for testing
local function GiveTestHamon(player: Player)
    ManifestationManager.AcquireManifestation(player, "Hamon")
end

-- Give a player Vampirism for testing
local function GiveTestVampire(player: Player)
    ManifestationManager.AcquireManifestation(player, "Vampire")
end

-- Expose to command bar for testing
_G.JoJoDebug = {
    GiveStand = GiveTestStand,
    GiveHamon = GiveTestHamon,
    GiveVampire = GiveTestVampire,
    GetPlayerStatus = ManifestationManager.GetPlayerStatus,
    GetCombatState = CombatService.GetPlayerState,
}

print("========================================")
print("  JoJo Game Framework - Ready!")
print("========================================")
print("")
print("Debug commands available in _G.JoJoDebug:")
print("  _G.JoJoDebug.GiveStand(player, 'StarPlatinum')")
print("  _G.JoJoDebug.GiveHamon(player)")
print("  _G.JoJoDebug.GiveVampire(player)")
print("  _G.JoJoDebug.GetPlayerStatus(player)")
print("")
print("Available Stands: StarPlatinum, TheWorld, CrazyDiamond, SilverChariot")
print("")
