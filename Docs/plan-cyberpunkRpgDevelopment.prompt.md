# Plan: Next-Generation Cyberpunk RPG Development

Building on the robust core architecture, transform PwshLeafMapGame into a modern cyberpunk crime-thriller with tactical unit-based gameplay, adding character progression, combat systems, faction warfare, and atmospheric world-building.

## Current State Analysis

### ✅ Fully Implemented Core Systems
- **EventSystem**: Event-driven communication with priority handling, deduplication, pattern matching
- **StateManager**: Entity persistence with change tracking, save/load, versioning, auto-save
- **CommandRegistry**: Dynamic command registration with validation, access control, middleware
- **DataModels**: Complete entity classes (Player, NPC, Item, Location, Quest, Faction) with property tracking
- **GameLogging**: Structured multi-output logging with rotation and performance metrics
- **DroneSystem**: Only fully implemented game module - drone deployment, movement, scanning, missions
- **CommunicationBridge**: Bidirectional PowerShell ↔ JavaScript communication via JSON queues
- **Frontend**: JavaScript entity models, event system, Leaflet map integration, basic game loop

### ⚠️ Partially Implemented
- **WorldSystem**: Basic map management, location points, but no terrain/resources/dynamic events

### ❌ Stub Only (Need Full Implementation)
- **CharacterSystem**: Only initialization stub
- **FactionSystem**: Only initialization stub
- **QuestSystem**: Only initialization stub (has entity model but no tracking logic)
- **ShopSystem**: Only initialization stub
- **TerminalSystem**: Only initialization stub

### 🚫 Missing Systems
- Combat/Battle System
- Character Progression (skill trees, abilities)
- NPC AI/Dialogue
- Inventory/Equipment mechanics
- Economy/Trading
- Crafting
- Unit/Squad management
- Vehicle system

## Development Steps

### Step 1: Define Theme & Core Systems

**Objective**: Establish the cyberpunk crime-underworld setting and decide on core gameplay mechanics.

**Tasks**:
- Define time period (2030s-2040s modern/near-future)
- Choose combat style: tactical squad-based vs solo vs hybrid
- Create atmosphere guidelines document in `Docs/GameDesign.md`
- Define unit types:
  - Player operatives (runners, netrunners, muscle, fixers)
  - Street gangs (various syndicates)
  - Corporate security (private military contractors)
  - Drones (surveillance, combat, support)
  - Vehicles (ground vehicles, aerial drones)
- Decide on combat mechanics: turn-based tactical, real-time with pause, or hybrid
- Define progression systems (skills, cyberware, reputation)

**Deliverables**:
- `Docs/GameDesign.md` - Core design document
- `Docs/CombatDesign.md` - Combat system specifications
- `Docs/SettingAndAtmosphere.md` - World-building guide
- `Docs/UnitTypes.md` - Unit definitions and stats

**Integration Points**:
- Review existing DataModels for compatibility
- Plan how units fit into entity system
- Consider faction relationships and conflicts

---

### Step 2: Implement Character & Unit Systems

**Objective**: Expand character progression and create unit management framework.

**Tasks**:
- Expand `Modules/CharacterSystem/CharacterSystem.psm1`:
  - Skill trees (Combat, Hacking, Social, Tech)
  - Attribute allocation
  - Level-up mechanics
  - Specialization/class system
  - Cyberware/augmentation slots

- Create `Unit` entity class in `Modules/CoreGame/DataModels.psm1`:
  - Extend `GameEntity` base class
  - Properties: UnitType, Class, Stats, Equipment, Skills, Morale, Status
  - Methods: ApplyDamage, Heal, ModifyMorale, EquipItem

- Create `Modules/SquadSystem/SquadSystem.psm1`:
  - Squad composition (max 4-6 units)
  - Formation management
  - Squad commands (move, hold, assault)
  - Squad AI coordination
  - Recruitment/dismissal

- Register commands via CommandRegistry:
  - `character.allocateSkillPoints`
  - `character.learnAbility`
  - `character.installCyberware`
  - `squad.recruit`
  - `squad.dismiss`
  - `squad.setFormation`
  - `unit.equip`
  - `unit.setTactics`

**Deliverables**:
- Enhanced `CharacterSystem.psm1` with full progression
- New `Unit` entity class in DataModels
- New `SquadSystem.psm1` module
- Unit tests: `Tests/Unit/SquadSystem.Tests.ps1`
- Frontend: `js/squadManager.js`, `js/characterSheet.js`

**Integration Points**:
- Use existing Player entity properties (Level, Experience, Skills, Attributes)
- Register entities with StateManager for persistence
- Emit events: `character.levelUp`, `squad.recruited`, `unit.equipped`
- Subscribe to: `combat.ended`, `quest.completed` for XP rewards

---

### Step 3: Build Combat & Tactical Systems

**Objective**: Create tactical combat engine with unit-based mechanics.

**Tasks**:
- Create `Modules/CombatSystem/CombatSystem.psm1`:
  - Turn-based initiative system (or real-time with action points)
  - Cover mechanics (full/partial/none)
  - Line of sight calculations
  - Range/accuracy modifiers
  - Damage types (kinetic, energy, EMP, chemical)
  - Status effects (bleeding, stunned, hacked, suppressed)

- Implement encounter system:
  - Encounter initialization from location/quest triggers
  - Enemy spawn based on faction/location danger level
  - Victory conditions (eliminate all, survive N turns, extract)
  - Defeat conditions (all units down, mission timer expires)
  - Loot distribution

- Combat actions:
  - Basic attack (ranged/melee)
  - Take cover
  - Overwatch/suppressive fire
  - Use ability/cyberware
  - Use item (heal, grenade, etc.)
  - Hack enemy (netrunner ability)
  - Call drone support (integrated with DroneSystem)
  - Retreat/flee

- Register commands:
  - `combat.initiate`
  - `combat.attack`
  - `combat.takeCover`
  - `combat.useAbility`
  - `combat.useItem`
  - `combat.callDrone`
  - `combat.flee`
  - `combat.endTurn`

**Deliverables**:
- New `CombatSystem.psm1` module
- Combat encounter manager
- Damage calculation engine
- Status effect handler
- Unit tests: `Tests/Unit/CombatSystem.Tests.ps1`
- Frontend: `js/combatUI.js`, combat map overlay on Leaflet

**Integration Points**:
- Use Player/NPC/Unit Health and Attributes from DataModels
- Integrate with DroneSystem for tactical drone support (scan, attack, distract)
- Emit events: `combat.started`, `combat.turnStart`, `combat.damageDealt`, `combat.unitDefeated`, `combat.ended`
- Subscribe to: `unit.positioned`, `drone.scan_completed`
- Update StateManager with combat results (HP, status, loot)

---

### Step 4: Expand Faction & Economy Systems

**Objective**: Implement faction warfare, reputation, and economic systems.

**Tasks**:
- Implement `Modules/FactionSystem/FactionSystem.psm1`:
  - Reputation system (Hostile < Unfriendly < Neutral < Friendly < Trusted < Allied)
  - Reputation effects:
    - Shop prices (-20% at Allied, +50% at Hostile)
    - Quest availability
    - Territory access (restricted zones)
    - Random encounters (attacks vs assistance)
  - Faction relationships (allied, neutral, at war)
  - Territory control on WorldSystem map
  - Dynamic faction conflicts

- Create rival factions using existing `Faction` entity:
  - **Corporate**: MegaCorp Security, TechGiants, Banking Consortiums
  - **Street Gangs**: Syndicates, Street Samurai, Data Runners
  - **Underworld**: Black Market Traders, Info Brokers, Fixers
  - **Government**: Police, Federal Agents, Military
  - **Underground**: Hacktivists, Anarchists, Freedom Fighters

- Implement `Modules/ShopSystem/ShopSystem.psm1`:
  - Vendor inventory management (stock, refresh timers)
  - Buy/sell transactions
  - Dynamic pricing based on:
    - Faction reputation
    - Item rarity
    - Supply/demand
    - Location (black market vs corp store)
  - Fence for stolen goods (reduced prices)
  - Special faction vendors (exclusive gear)

- Register commands:
  - `faction.getReputation`
  - `faction.modifyReputation`
  - `faction.getRelationships`
  - `faction.claimTerritory`
  - `shop.open`
  - `shop.buy`
  - `shop.sell`
  - `shop.refresh`

**Deliverables**:
- Enhanced `FactionSystem.psm1` with reputation mechanics
- Enhanced `ShopSystem.psm1` with economy
- Territory control system integrated with WorldSystem
- Unit tests: `Tests/Unit/FactionSystem.Tests.ps1`, `Tests/Unit/ShopSystem.Tests.ps1`
- Frontend: `js/factionUI.js`, `js/shopUI.js`, territory overlay on map

**Integration Points**:
- Use existing Faction entity and Player.FactionStandings
- Update Player.Currency on transactions
- Emit events: `faction.reputationChanged`, `faction.territoryChanged`, `shop.transactionCompleted`
- Subscribe to: `combat.ended` (reputation from kills), `quest.completed` (reputation rewards)
- Integrate with QuestSystem for faction-specific missions

---

### Step 5: Implement Quest & Dialogue Systems

**Objective**: Create dynamic quest system with branching narratives and NPC interactions.

**Tasks**:
- Expand `Modules/QuestSystem/QuestSystem.psm1`:
  - Quest types:
    - **Heist**: Infiltrate, steal data/items, extract
    - **Assassination**: Eliminate target(s)
    - **Escort**: Protect NPC through dangerous area
    - **Investigation**: Gather clues, interrogate NPCs
    - **Territory**: Capture/defend faction zones
    - **Delivery**: Transport cargo (may be ambushed)
  - Objective tracking system (kill X, collect Y, reach Z)
  - Objective types: location, combat, item, interaction, time-based
  - Quest chains with branching paths
  - Faction consequences (reputation changes)
  - Dynamic quest generation based on faction standing

- Create `Modules/DialogueSystem/DialogueSystem.psm1`:
  - Branching conversation trees using NPC `DialogOptions`
  - Dialogue conditions (reputation, items, quest progress)
  - Skill checks in dialogue (Social skill, Hacking knowledge)
  - Dialogue outcomes:
    - Start quest
    - Reveal information
    - Open shop
    - Change faction reputation
    - Provide quest hints
    - Combat initiation
  - Voice/personality system for NPC characterization

- Register commands:
  - `quest.accept`
  - `quest.abandon`
  - `quest.complete`
  - `quest.updateObjective`
  - `quest.getActive`
  - `dialogue.start`
  - `dialogue.chooseOption`
  - `dialogue.end`

**Deliverables**:
- Enhanced `QuestSystem.psm1` with full tracking
- New `DialogueSystem.psm1` module
- Quest template system for dynamic generation
- Unit tests: `Tests/Unit/QuestSystem.Tests.ps1`, `Tests/Unit/DialogueSystem.Tests.ps1`
- Frontend: `js/questLog.js`, `js/dialogueUI.js`

**Integration Points**:
- Use existing Quest entity with objectives
- Update Player.Quests array
- Emit events: `quest.accepted`, `quest.objectiveCompleted`, `quest.completed`, `dialogue.started`, `dialogue.optionChosen`
- Subscribe to: `location.entered`, `npc.defeated`, `item.acquired`, `combat.ended`
- Trigger quests from NPC dialogue
- Check faction reputation for quest availability

---

### Step 6: Enhance Frontend & Atmosphere

**Objective**: Create immersive cyberpunk UI and atmospheric world presentation.

**Tasks**:
- Update `js/game.js` with cyberpunk theme:
  - Dark UI with neon accent colors (cyan, magenta, yellow)
  - CRT/terminal aesthetic with scanlines
  - Glitch effects on transitions
  - Holographic UI panels
  - Data stream animations

- Create combat visualization:
  - Unit positions on Leaflet map
  - Cover indicators
  - Range/LOS indicators
  - Health bars above units
  - Action animations (muzzle flash, explosions)
  - Damage numbers

- Create UI panels:
  - Squad management panel (unit roster, stats, equipment)
  - Character sheet with skill trees
  - Faction reputation dashboard
  - Quest log with objective tracking
  - Dialogue box with branching options
  - Shop interface with inventory comparison
  - Map with territory overlay (faction-controlled zones)

- Update `css/style.css`:
  - Dark theme (#0a0e27, #1a1f3a)
  - Neon colors for accents
  - Monospace fonts for terminal feel
  - Box shadows with glow effects
  - Animated borders

- Enhance WorldSystem location generation:
  - Location types: corporate tower, underground club, data haven, black market, safe house, abandoned district, police station, corpo-plaza
  - Atmospheric descriptions:
    - "Rain-slicked streets reflect neon signs..."
    - "Corporate security drones patrol overhead..."
    - "The underground club pulses with synth beats..."
    - "Abandoned warehouses hide black market deals..."
  - Dynamic events: police raids, gang wars, drone swarms

- Update map markers:
  - Faction-colored markers
  - Animated icons for active missions
  - Danger level indicators
  - Territory boundaries

**Deliverables**:
- Cyberpunk-themed UI overhaul
- Combat map visualization system
- New UI components for all game systems
- Enhanced location generation in WorldSystem
- Atmospheric location descriptions database
- Updated CSS with cyberpunk styling

**Integration Points**:
- Integrate all new JS modules (squadManager, combatUI, questLog, etc.)
- Connect UI to EventSystem for real-time updates
- Use StateManager for UI state persistence
- Render faction territories on map from FactionSystem
- Display quest markers from QuestSystem

---

## Further Considerations

### 1. Vehicle System

**Options**:
- **A) Controllable Units** (like DroneSystem):
  - Create `Modules/VehicleSystem/VehicleSystem.psm1`
  - Vehicles as separate entities with fuel, damage, speed
  - Commands: `vehicle.deploy`, `vehicle.drive`, `vehicle.mount`, `vehicle.dismount`
  - Combat vehicles provide mobile cover and heavy weapons
  - Missions: vehicle chases, convoy escorts

- **B) Equipment Items**:
  - Vehicles as inventory items that modify player movement
  - No separate entity tracking
  - Simpler implementation
  - Vehicles provide fast travel between locations

- **C) Hybrid Approach**:
  - Light vehicles (bikes, cars) as equipment items
  - Heavy vehicles (APCs, gunships) as controllable units
  - Balance complexity with gameplay value

**Recommendation**: Start with **Option B** (equipment items) for simplicity, then add **Option A** for mission-critical vehicles (armored transport, mobile command center).

---

### 2. Enemy AI & Encounter Design

**Complexity Levels**:

- **A) Simple Aggression** (Minimal):
  - NPC `BehaviorType` property: Passive, Defensive, Aggressive, Berserk
  - Basic target selection (nearest, lowest HP, highest threat)
  - Random action selection weighted by behavior
  - **Pros**: Easy to implement, low performance impact
  - **Cons**: Predictable, no tactical depth

- **B) State Machine AI** (Moderate):
  - States: Idle, Patrol, Alert, Combat, Retreat
  - Transitions based on: player detection, health threshold, ally status
  - Patrol routes for NPCs
  - Alert state calls reinforcements
  - **Pros**: More believable behavior, manageable complexity
  - **Cons**: Still somewhat predictable, needs careful balancing

- **C) Full Tactical AI** (Complex):
  - Cover evaluation and selection
  - Flanking maneuvers
  - Ability usage (grenades, cyberware)
  - Team coordination (suppression + flank)
  - Dynamic threat assessment
  - **Pros**: Challenging, replayable combat
  - **Cons**: Computationally expensive, complex to debug

**Recommendation**: Start with **Option B** (state machine), add tactical behaviors incrementally. PowerShell performance should handle moderate AI. Consider moving AI calculations to JavaScript for real-time combat.

---

### 3. Crafting & Tech Upgrades

**Options**:

- **A) Full Crafting System**:
  - Create `Modules/CraftingSystem/CraftingSystem.psm1`
  - Use `Item.CraftingRecipe` property
  - Recipe discovery through exploration/quests
  - Material gathering from dismantling items
  - Crafting skill affects success/quality
  - **Pros**: Deep progression, player agency
  - **Cons**: Adds complexity, needs extensive item database

- **B) Upgrade Vendors Only**:
  - No crafting, only purchase/upgrade at vendors
  - Weapon mods and cyberware installed by NPCs
  - Faction reputation unlocks higher tiers
  - **Pros**: Simpler implementation, faction-focused
  - **Cons**: Less player agency, gold-sink only

- **C) Hybrid Tech Upgrade System**:
  - No weapon crafting (buy from shops)
  - Cyberware installation requires Tech skill + vendor
  - Hacking minigame for stealing blueprints/tech
  - Modify weapons with attachments (no full crafting)
  - **Pros**: Balanced complexity, fits cyberpunk theme
  - **Cons**: Middle ground may lack identity

**Recommendation**: **Option C** (hybrid) - Focus on cyberware upgrades and weapon modifications rather than full crafting. Add hacking minigames for tech acquisition (fits cyberpunk theme).

---

### 4. Multiplayer/Co-op Considerations

**Current Architecture Compatibility**:
- ✅ **StateManager** supports synchronized state
- ✅ **EventSystem** can broadcast across instances
- ✅ **CommunicationBridge** is message-based (could extend to network)
- ⚠️ **Save system** is single-player focused
- ❌ **No conflict resolution** for simultaneous actions

**Options**:

- **A) Single-Player First** (Recommended):
  - Focus on solo + AI squad gameplay
  - Keep architecture clean for future multiplayer
  - Avoid premature optimization

- **B) Co-op Planning Now**:
  - Design squad system for player-controlled units
  - Each player controls 1-2 units in shared squad
  - Synchronized state via server (Node.js/SignalR)
  - Shared mission progression
  - **Impact**: Affects squad design, command structure, save format

- **C) Async Multiplayer** (PvP):
  - Players compete for territory control
  - Asynchronous faction warfare
  - Raid other players' bases when offline
  - Leaderboards for reputation/territory
  - **Impact**: Needs server backend, security, balancing

**Recommendation**: **Option A** - Build single-player first, keep architecture multiplayer-friendly (event-driven, synchronized state), add co-op in Phase 2 if successful.

---

### 5. Atmospheric Elements & Cyberpunk Sub-genre

**Sub-genre Options**:

- **A) Corporate Dystopia** (Cyberpunk 2077-style):
  - MegaCorps control everything
  - High-tech, low-life contrast
  - Body modification central to identity
  - Themes: transhumanism, corporate oppression, rebellion
  - Locations: glittering corporate towers, filthy slums

- **B) Street-Level Crime** (Shadowrun-esque):
  - Focus on criminal underworld
  - Heist missions, gang warfare
  - Magic/fantasy elements optional
  - Themes: survival, loyalty, betrayal
  - Locations: dive bars, chop shops, back alleys

- **C) Noir Detective Thriller** (Blade Runner atmosphere):
  - Mystery and investigation focus
  - Dark, rain-soaked streets
  - Moral ambiguity
  - Themes: identity, humanity, detective work
  - Locations: dystopian urban sprawl, neon-lit night city

- **D) Anarchist Hacker Underground** (Mr. Robot vibes):
  - Focus on information warfare
  - Hacking as primary mechanic
  - Collective vs individual
  - Themes: surveillance, freedom, revolution
  - Locations: data havens, server farms, underground networks

**Recommendation**: **Blend A + B** - Corporate dystopia setting with street-level criminal gameplay. Player is a "runner" (mercenary operative) doing jobs for fixers, navigating between corporate and underworld factions. Allows tactical combat AND intrigue missions.

**Atmospheric Details**:
- **Visuals**: Perpetual twilight, neon reflections on wet streets, holographic ads, drone surveillance
- **Audio**: Synthwave soundtrack, rain ambience, police sirens, corporate announcements
- **Tone**: Gritty, morally grey, high-stakes, noir-influenced
- **Technology**: Cyberware implants, brain-computer interfaces, holographic displays, AI assistants
- **Society**: Corporate citizenship, social credit, underground economies, privacy extinct

---

## Implementation Priorities

### Phase 1: Foundation (Core Gameplay Loop)
1. ✅ Theme definition (Step 1)
2. ✅ Character progression (Step 2)
3. ✅ Combat system (Step 3)
4. ✅ Basic shop economy (Step 4)

**Goal**: Playable combat encounters with character progression

---

### Phase 2: Content Systems
5. ✅ Quest system (Step 5)
6. ✅ Dialogue system (Step 5)
7. ✅ Faction reputation (Step 4)
8. ⚠️ NPC AI (moderate state machine)

**Goal**: Mission-driven gameplay with narrative depth

---

### Phase 3: Polish & Atmosphere
9. ✅ Frontend UI overhaul (Step 6)
10. ✅ Location atmosphere (Step 6)
11. ⚠️ Vehicle system (equipment-based)
12. ⚠️ Cyberware upgrade system

**Goal**: Immersive cyberpunk experience

---

### Phase 4: Advanced Features (Optional)
- Full tactical AI
- Crafting system
- Territory warfare
- Co-op multiplayer
- Hacking minigames
- Random events/encounters

---

## Technical Architecture Notes

### Entity Hierarchy
```
GameEntity (base)
├── Player (character with skills/inventory)
├── NPC (dialogue/schedule/vendor)
├── Unit (combat stats/tactics) ← NEW
├── Item (equipment/consumables)
├── Location (map points/resources)
├── Quest (objectives/rewards)
├── Faction (reputation/territory)
└── Drone (existing system)
```

### Module Dependencies
```
CharacterSystem ──► DataModels ──► StateManager
     │                  ↑              ↑
     ▼                  │              │
CombatSystem ──────────┤              │
     │                  │              │
     ▼                  │              │
SquadSystem ───────────┤              │
     │                                 │
     ▼                                 │
FactionSystem ─────────────────────────┤
     │                                 │
     ▼                                 │
QuestSystem ───────────────────────────┤
     │                                 │
     ▼                                 │
DialogueSystem ────────────────────────┤
     │                                 │
     ▼                                 │
ShopSystem ────────────────────────────┘

All modules ──► EventSystem ◄── CommunicationBridge
All modules ──► CommandRegistry
All modules ──► GameLogging
```

### Event Flow Example: Combat Encounter
```
1. Player enters hostile territory
   → EventSystem: location.entered

2. CombatSystem checks for encounters
   → Rolls encounter based on Location.DangerLevel

3. Encounter triggered
   → EventSystem: combat.started
   → CommunicationBridge sends to frontend

4. Frontend displays combat UI
   → js/combatUI.js renders units on map

5. Player takes action
   → Frontend: user clicks "Attack"
   → CommunicationBridge sends command to backend

6. CombatSystem processes attack
   → CommandRegistry: combat.attack
   → Calculates damage, applies to enemy
   → StateManager: updates Unit.Health
   → EventSystem: combat.damageDealt

7. Enemy defeated
   → CombatSystem checks victory
   → EventSystem: combat.unitDefeated, combat.ended
   → QuestSystem: checks quest objectives
   → FactionSystem: modifies reputation
   → ShopSystem: generates loot

8. Results sent to frontend
   → CommunicationBridge sends state update
   → Frontend updates UI (XP gain, loot, reputation)
   → StateManager: auto-save triggered
```

---

## Success Metrics

### Minimum Viable Product (MVP)
- [ ] Player can create character with skill choices
- [ ] Player can enter combat encounters
- [ ] Combat has tactical depth (cover, abilities, positioning)
- [ ] Player gains XP and levels up
- [ ] Basic shop for buying/selling items
- [ ] At least 3 factions with reputation system
- [ ] At least 5 quest types playable
- [ ] Cyberpunk UI theme implemented
- [ ] Map with atmospheric locations

### Full Release Goals
- [ ] 10+ hours of gameplay content
- [ ] 5+ distinct factions with branching quest lines
- [ ] 20+ unique locations with atmosphere
- [ ] Squad management with AI companions
- [ ] Dynamic faction warfare affects world state
- [ ] Multiple endings based on faction alignment
- [ ] Replayable with different character builds

---

## Risk Assessment

### High Risk
- **Combat complexity vs performance**: PowerShell may struggle with real-time tactical calculations
  - *Mitigation*: Move combat logic to JavaScript, use PowerShell for state management only

- **Scope creep**: Too many systems to implement
  - *Mitigation*: Prioritize Phase 1 & 2, make Phase 3 & 4 optional

### Medium Risk
- **Balance**: Combat, economy, progression balance is difficult
  - *Mitigation*: Playtesting, analytics, iterative tuning

- **Content creation**: Need many quests, dialogues, locations
  - *Mitigation*: Templates for procedural generation, focus on quality over quantity

### Low Risk
- **Architecture**: Core systems are solid
- **Integration**: Event-driven design makes adding systems straightforward
- **Persistence**: StateManager handles save/load reliably

---

## Conclusion

The foundation is excellent. The project has production-ready core architecture (EventSystem, StateManager, CommandRegistry, DataModels) and only needs game logic implementation. The plan above provides a clear roadmap from current state (location-based exploration with drones) to a full tactical cyberpunk RPG with squad combat, faction warfare, and atmospheric storytelling.

**Recommended Start**: Begin with Step 1 (theme definition) and Step 3 (combat system) to quickly create a playable combat loop, then add progression (Step 2) and content systems (Steps 4-5) to build out the game.
