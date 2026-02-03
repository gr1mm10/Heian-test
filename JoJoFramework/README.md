# JoJo R6 Game Framework

## "Base Combat → Manifest Extension" Framework

The game has one universal combat system. Nothing replaces it — everything builds on top of it.

**Core Philosophy:**
- Before any power, you are dangerous
- After gaining one, you are dangerous in a *new* way
- If you delete Stands, Hamon, and Vampires, the combat is still fun

---

## Project Structure

```
JoJoFramework/
├── src/
│   ├── Server/
│   │   ├── Combat/
│   │   │   └── CombatService.lua       # THE SACRED FOUNDATION
│   │   ├── Manifestations/
│   │   │   ├── StandService.lua        # Stand Arrow system
│   │   │   ├── HamonService.lua        # Hamon/Ripple system
│   │   │   ├── VampireService.lua      # Stone Mask system
│   │   │   └── ManifestationManager.lua # Stacking & interactions
│   │   ├── Progression/
│   │   │   └── ProgressionService.lua  # No power creep progression
│   │   └── Services/
│   │       ├── RemoteSetup.lua         # Network setup
│   │       └── InputHandler.lua        # Server input validation
│   ├── Client/
│   │   └── Combat/
│   │       └── CombatController.lua    # Client input & visuals
│   ├── Shared/
│   │   ├── Constants/
│   │   │   ├── CombatConfig.lua        # Combat timings & values
│   │   │   └── ManifestationConfig.lua # Stand/Hamon/Vampire config
│   │   ├── Modules/
│   │   │   └── CombatPhilosophy.lua    # Design validation rules
│   │   └── Types/
│   │       ├── CombatTypes.lua
│   │       └── ManifestationTypes.lua
│   ├── init.server.lua                 # Server entry point
│   └── init.client.lua                 # Client entry point
└── README.md
```

---

## Base Combat System (Everyone Has This)

Every player always has:
- **Light Combo** - Fast attacks, chainable (max 4 hits)
- **Heavy Attack** - Slow, powerful, punishable on whiff
- **Block / Perfect Block** - Defensive options with skill expression
- **Dash / Sidestep** - Movement with i-frames
- **Grab / Shove** - Beats block, loses to attacks
- **Context Finisher** - High damage on staggered opponents
- **Burst** - Combo escape (long cooldown)

### Combat Philosophy

All fights revolve around:
1. **Spacing** - Range advantages and disadvantages
2. **Timing** - Startup, active, recovery frames
3. **Punishment** - Mistakes are exploitable

**Rules:**
- No infinite combos (max 8 hits, combo scaling)
- No button mashing (stamina costs, cooldowns)
- Defense and movement matter (perfect block, i-frames)
- Everything is readable (startup frames on attacks)
- Everything is punishable (recovery frames)

---

## Three Manifest Paths

### 🟣 Stand User (Stand Arrow)

**What a Stand Does:**
- Extends reach
- Adds pressure
- Creates follow-ups
- Controls space

**Limitations:**
- Requires summoning (vulnerable during summon)
- Can be interrupted (user hit = Stand dismissed)
- Transfers risk to user (Stand damage → User damage)

**Available Stands:**
- Star Platinum - Close-range power, ORA Rush, Time Stop
- The World - Close-range power, MUDA Rush, Time Stop
- Crazy Diamond - Restoration type, healing, DORA Rush
- Silver Chariot - Speed type, rapid thrusts, armor shed

### 🟡 Hamon User (Training)

**Hamon flows through base combat:**
- Light attacks gain sunlight properties
- Perfect blocks trigger counter shocks
- Grabs become nerve-locks
- Finishers deal bonus damage to Vampires & Stands

**Limitations:**
- Requires breath charging (must actively breathe)
- Weaker if spammed (consecutive use penalty)
- Poor sustain if mistimed

**Techniques:**
- Zoom Punch, Sendou Wave Kick, Overdrive Barrage
- Sunlight Yellow Overdrive, Hamon Cutter, Scarlet Overdrive

### 🔴 Vampire (Stone Mask)

**Vampirism alters the body:**
- Faster recovery
- Life-steal on clean hits
- Enhanced grabs (blood drain)
- Strong night presence

**Limitations:**
- Hamon is TERRIFYING (1.5x-2x damage)
- Overextending gets punished hard
- Daylight/sunlight mechanics apply pressure
- Low blood = major penalties

**Abilities:**
- Vaporization Freeze, Space Ripper Stingy Eyes
- Blood Drain, Zombie Creation, Regeneration Burst

---

## Valid Combinations

| Combination | Description |
|-------------|-------------|
| Stand only | Standard Stand user |
| Hamon only | Pure martial artist |
| Vampire only | Undead predator |
| Stand + Hamon | Strong synergy, limited sustain, requires mastery |
| Stand + Vampire | Extremely powerful, extremely risky, hard counters exist |

**Invalid:** Hamon + Vampire (lore-accurate - they're opposites)

---

## Matchup Interactions

| Matchup | Result |
|---------|--------|
| Stand vs Stand | Space control, mind games, punish overextensions |
| Hamon vs Vampire | **Hard counter** - High reward for skill, mistakes fatal |
| Vampire vs Non-Stand | Vampire dominates early, skilled defense turns tide |
| Stand + Hamon vs Vampire | Devastating combination |
| Pure Human vs Stand | Exploit summon windows, fastest neutral |

**Nothing is unbeatable — knowledge wins fights.**

---

## Progression System

### What Progression Unlocks:
- New interactions
- New follow-ups
- New counters
- New mind games

### What Progression Does NOT Do:
- ❌ Raw stat inflation
- ❌ One-shot abilities
- ❌ Passive wins

**A veteran player is scary because they KNOW when to act, not because they hit harder.**

### Example Unlocks:
- Level 10: Delayed Heavy (timing mix-ups)
- Level 15: Sidestep Cancel (punish reads)
- Level 25: Feint (cancel attack into block/dash)
- Level 30: Parry (perfect block during attack = frame advantage)
- Level 50: Wave Dash (dash cancel into dash)

---

## Controls (Default)

| Key | Action |
|-----|--------|
| LMB | Light Attack |
| RMB (Hold) | Heavy Attack (charge for more damage) |
| F | Block |
| Q | Dash |
| E | Sidestep |
| G | Grab |
| B | Burst (escape combos) |
| T | Summon/Dismiss Stand |
| C | Hamon Breathing |
| Z/X/V | Abilities (Stand/Hamon/Vampire) |
| Tab | Target Lock |

---

## Debug Commands

In Roblox Studio command bar:
```lua
-- Give a player Star Platinum
_G.JoJoDebug.GiveStand(player, "StarPlatinum")

-- Give a player Hamon
_G.JoJoDebug.GiveHamon(player)

-- Give a player Vampirism
_G.JoJoDebug.GiveVampire(player)

-- Check player status
_G.JoJoDebug.GetPlayerStatus(player)
```

---

## Design Checklist (For Adding New Content)

When adding new abilities, ask:
- [ ] Can this be blocked or dodged?
- [ ] Is the startup readable for the damage it deals?
- [ ] Does it have punishable recovery?
- [ ] Does it require resources or have a cooldown?
- [ ] Does it create a new weakness?
- [ ] Can it infinite? If yes, fix it.
- [ ] Does it have clear visual/audio tells?
- [ ] Is the range appropriate for its speed?
- [ ] Does it extend base combat or replace it?
- [ ] What counters this?
- [ ] What does this counter?
- [ ] Is there skill expression in using it?
- [ ] Can a skilled player play around this?
- [ ] Does spamming it get punished?
- [ ] Is the risk/reward balanced?

---

## Installation

1. Copy the `src` folder contents into your Roblox game
2. Place server scripts in `ServerScriptService`
3. Place client scripts in `StarterPlayerScripts` or `ReplicatedFirst`
4. Place shared modules in `ReplicatedStorage`
5. Test with debug commands

---

## License

Framework design based on canonical JoJo's Bizarre Adventure mechanics.
Built for educational and game development purposes.
