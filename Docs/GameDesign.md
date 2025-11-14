# Game Design Document: [Your Game Title]

> **Version**: 0.1.0
> **Last Updated**: November 14, 2025
> **Author**: [Your Name]

---

## Table of Contents
1. [Game Overview](#game-overview)
2. [Setting & Atmosphere](#setting--atmosphere)
3. [Core Gameplay Loop](#core-gameplay-loop)
4. [Progression Systems](#progression-systems)
5. [Combat System](#combat-system)
6. [Unit & Party Management](#unit--party-management)
7. [World & Travel](#world--travel)
8. [Economy & Resources](#economy--resources)
9. [Technical Notes](#technical-notes)

---

## Game Overview

### High Concept
**[Fill this in]** - Describe your game in 1-2 sentences.

**Example**: *"A real-time-with-pause cyberpunk RPG where you start as a lone mercenary and build a crew of specialists to take on high-stakes heists, territory control, and faction warfare in a neon-soaked near-future city."*

### Genre
- **Primary**: Real-Time Tactical RPG with Pause
- **Secondary**: Strategy, Narrative-Driven
- **Setting**: Cyberpunk Crime-Underworld (2030s-2040s)

### Target Audience
**[Fill this in]** - Who is this game for?

**Example**: *Players who enjoy tactical depth (XCOM, Shadowrun), narrative choices (Disco Elysium), and cyberpunk atmosphere (Cyberpunk 2077, Deus Ex).*

### Unique Selling Points
**[Fill this in]** - What makes your game stand out?

**Examples**:
- Start solo, grow into commanding a criminal empire
- Real-time tactical combat with strategic pause
- Dynamic faction reputation affects world state
- OpenStreetMap integration for real-world city exploration
- Drone and vehicle tactical support

---

## Setting & Atmosphere

> **Note**: See [SettingAndAtmosphere.md](./SettingAndAtmosphere.md) for full world-building details.

### Time Period
**[Define your timeline]**

**Example**: *The year is 2042. Twenty years after the "Network Collapse" crippled global communications, megacorporations have rebuilt society in their image. Governments are shadows of their former selves, and the streets belong to those who can take them.*

### Location
**[Choose your city/region]**

**Example**:
- **Primary**: Neo-London (fictional near-future version of London)
- **Why London?**: Existing OpenStreetMap data, architectural blend (historic + modern), Thames river for strategic zones
- **Districts**: Corporate City (financial), Undercity (abandoned Underground stations), Docklands (smuggling), Hackney Sprawl (gang territory)

### Tone & Atmosphere
**[Define the emotional experience]**

**Tone Keywords**:
- Gritty and morally grey
- High-tech, low-life
- Noir-influenced thriller
- Dark humor moments
- Hope vs despair tension

**Visual Atmosphere**:
- Perpetual twilight (pollution blocks sunlight)
- Neon signs reflected in rain-slicked streets
- Holographic advertisements everywhere
- Surveillance drones patrolling
- Corporate towers loom over slums

**Audio Atmosphere**:
- Synthwave / Cyberpunk soundtrack
- Ambient rain and traffic
- Police sirens and drone hum
- Radio chatter (corp announcements, pirate broadcasts)

### Key Themes
**[What is your game about thematically?]**

**Examples**:
- **Survival vs Morality**: Do you betray allies to survive?
- **Corporate Oppression**: Fighting against / working for the system
- **Identity**: What does it mean to be human when you're 60% machine?
- **Community**: Building a crew in a world that isolates everyone

---

## Core Gameplay Loop

### Moment-to-Moment (Minute-by-Minute)
**[What is the player doing second-to-second?]**

**Example**:
1. Explore the city map in real-time
2. Encounter NPCs, shops, mission givers
3. Enter combat encounters (real-time with pause)
4. Manage squad positioning, abilities, cover
5. Loot rewards, gain experience
6. Return to safe house / vendor

### Short-Term Loop (Hour-by-Hour)
**[What does a play session look like?]**

**Example**:
1. Accept mission from fixer
2. Gather intel / prepare loadout
3. Travel to mission location (may encounter random events)
4. Complete mission objectives (combat, stealth, dialogue)
5. Resolve mission outcome (success/partial/failure)
6. Collect rewards and reputation changes
7. Spend resources on upgrades
8. Recruit/train squad members

### Long-Term Loop (Campaign)
**[What drives progression over many hours?]**

**Example**:
1. Build reputation with factions
2. Unlock new districts and mission types
3. Recruit and specialize squad members
4. Upgrade safe house / acquire vehicles
5. Influence faction wars and territory control
6. Make major story decisions
7. Reach endgame: Unite factions, take down megacorp, or seize power

---

## Progression Systems

### Character Progression (Player)

#### Level & Experience
- **XP Sources**: Combat kills, quest completion, exploration, hacking, social success
- **Level Cap**: [Define max level, e.g., 30]
- **Per Level**: [Define rewards, e.g., +5 Health, +2 Skill Points, +1 Attribute Point]

#### Attributes (Core Stats)
**[Define your attribute system]**

**Example**:
- **Body** (10-20): Health, melee damage, carry weight, intimidation
- **Reflexes** (10-20): Accuracy, dodge chance, initiative, movement speed
- **Intelligence** (10-20): Hacking success, tech skills, dialogue options, drone control
- **Cool** (10-20): Critical chance, social skills, stress resistance, leadership

**Attribute Effects**:
```
Health = 50 + (Body × 10)
Accuracy = 50% + (Reflexes × 2%)
Hack Success = 30% + (Intelligence × 3%)
Critical Chance = 5% + (Cool × 1%)
```

#### Skills (Learned Abilities)
**[Define skill categories and progression]**

**Example Skill Trees**:

**Combat Skills** (scales with Body/Reflexes):
- `Weapons Mastery` (5 ranks): +10% damage per rank
- `Tactical Movement`: Reduce action point cost for movement
- `Close Quarters`: +20% melee damage, execute downed enemies
- `Suppression Fire`: Pin enemies behind cover

**Hacking Skills** (scales with Intelligence):
- `Network Intrusion` (5 ranks): +15% hack success per rank
- `Drone Override`: Take control of enemy drones
- `Turret Control`: Hack security systems
- `Data Theft`: Steal credits from corporate accounts

**Social Skills** (scales with Cool):
- `Negotiation` (5 ranks): Better shop prices, dialogue options
- `Leadership`: Squad members gain +10% stats
- `Intimidation`: Bypass combat through threats
- `Seduction`: Extract information, distract guards

**Tech Skills** (scales with Intelligence):
- `Engineering`: Craft/modify weapons
- `Medical`: Heal more effectively
- `Vehicle Repair`: Maintain vehicles, reduce fuel costs
- `Drone Tech`: Deploy advanced drones

#### Cyberware & Augmentations
**[Define body modification system]**

**Example Slots**:
- **Neural** (1 slot): Reflex boosters, tactical HUD, skill chips
- **Optical** (1 slot): Targeting system, night vision, threat detection
- **Skeletal** (1 slot): Bone reinforcement, jump boost, melee damage
- **Circulatory** (1 slot): Regeneration, toxin filter, adrenaline boost
- **Dermal** (1 slot): Armor plating, thermal camo, EMP shielding
- **Arms** (2 slots): Weapon implants, tool arms, grappling hook

**Cyberware Grades**:
- Street (cheap, minor bonuses)
- Military (balanced)
- Corporate (expensive, major bonuses)
- Prototype (unique effects, quest rewards)

**Humanity Cost** (Optional):
- Each cyberware reduces "Humanity" stat
- At 0 Humanity: [Define consequence, e.g., locked out of certain endings, NPC reactions change]

### Squad Progression

#### Recruitment
- **How**: Find in world, rescue from missions, hire from fixers
- **Initial State**: Level 1, basic equipment, single specialization
- **Limit**: [Define max squad size active on missions, e.g., 4 units including player]

#### Specialization
**[Define unit classes]** - See [UnitTypes.md](./UnitTypes.md) for full details.

**Example Classes**:
- **Enforcer**: Tank, high HP, close combat
- **Operative**: Balanced, versatile
- **Netrunner**: Hacker, drone controller, low HP
- **Medic**: Support, healing, buff/debuffs
- **Sniper**: Long-range, high damage, fragile

#### Loyalty & Morale
- **Loyalty** (0-100): Affects chance of leaving squad, combat effectiveness
- **Influenced By**: Mission success/failure, player choices, salary paid, squad member deaths
- **Low Loyalty**: Unit may refuse orders, flee combat, betray you
- **High Loyalty**: Bonus combat stats, special dialogue, unique missions

---

## Combat System

> **Note**: See [CombatDesign.md](./CombatDesign.md) for full technical specifications.

### Core Mechanics
- **Type**: Real-Time with Tactical Pause
- **Pause Triggers**: Manual (spacebar), enemy spotted, ally downed, ability ready
- **Action System**: Action Points (AP) regenerate over time, abilities cost AP
- **Initiative**: All units act simultaneously in real-time, but player can pause to issue orders

### Combat Flow
1. **Encounter Trigger**: Player enters hostile zone or mission area
2. **Deployment**: Player positions squad before combat starts (or ambushed in place)
3. **Real-Time Phase**: Units execute orders, combat unfolds
4. **Tactical Pause**: Player pauses to reassess, issue new orders
5. **Victory/Defeat**: Combat ends when one side eliminated or flees

### Core Actions
**Movement**:
- Click to move (pathfinding via OpenStreetMap)
- Sprint (faster, but exposed)
- Take cover (reduce incoming damage)

**Attacking**:
- Auto-attack when in range (can disable)
- Manual target selection
- Abilities (hacking, grenades, special attacks)

**Abilities** (Cooldown-based):
- **Grenade**: AoE damage
- **Overwatch**: Auto-fire at moving enemies
- **Hack**: Disable enemy weapon/cyberware
- **Heal**: Restore ally HP
- **Tactical Shield**: Temporary cover

### Cover System
- **Full Cover** (walls, vehicles): -50% accuracy against you
- **Half Cover** (crates, barriers): -25% accuracy against you
- **No Cover** (open ground): +25% accuracy against you
- **Flanking**: Attacking from side/rear ignores cover

### Damage & Health
**Damage Types**:
- **Kinetic**: Standard bullets, physical attacks
- **Energy**: Lasers, plasma
- **EMP**: Disables cyberware, drones, vehicles
- **Chemical**: Toxin, acid (damage over time)

**Health System**:
- **Health Pool**: 0 HP = Downed (not dead)
- **Downed State**: Can be revived by ally or stabilized with medkit
- **Death**: If not revived within [X turns/seconds], unit dies permanently
- **Permadeath**: [Decide: Can squad members die permanently? Only in hardcore mode?]

### Enemy AI
**Behavior States**:
- **Idle**: Patrol route or stand guard
- **Alert**: Heard noise, searching
- **Combat**: Engaged with player squad
- **Retreat**: Low HP, falling back
- **Call Reinforcements**: Radio for backup

**Tactics**:
- Use cover when available
- Flank if player is pinned
- Focus fire on weakest target
- Netrunners prioritize hacking
- Heavies push forward

---

## Unit & Party Management

### Party Composition
**Solo → Squad → Strategy Transition**:

**Phase 1: Solo (Early Game)**
- Player character only
- Missions designed for 1 unit
- Drones provide tactical support (deploy via DroneSystem)

**Phase 2: Squad (Mid Game)**
- Player + 1-3 recruited units
- Direct control: Issue orders, manage positioning
- Units have AI behavior when not given orders (follow, defend, aggressive)

**Phase 3: Strategy (Late Game)**
- Player can assign squads to missions without direct control
- AI-controlled squads complete objectives based on:
  - Squad composition
  - Unit levels/equipment
  - Mission difficulty
- Player receives outcome reports (success/failure/casualties)
- Can still directly control one squad at a time

### Squad Commands
**Direct Control Mode** (Player controls in combat):
- `Move Here`: Pathfind to location
- `Attack Target`: Focus fire on enemy
- `Use Ability`: Activate special ability
- `Take Cover`: Find nearest cover
- `Hold Position`: Stop and defend
- `Follow Me`: Follow player character

**Strategic Command Mode** (AI-controlled missions):
- `Assign Mission`: Send squad to location/objective
- `Set Tactics`: Aggressive / Balanced / Defensive / Stealth
- `Abort Mission`: Recall squad immediately (may fail objective)

### Unit Behavior AI
**When not given direct orders, units follow behavior setting**:

- **Follow**: Stay near player, engage enemies in range
- **Defend**: Hold position, only fire if approached
- **Aggressive**: Push forward, seek enemies
- **Support**: Prioritize healing/buffing allies
- **Overwatch**: Cover advance, suppress enemies

### Vehicle Integration
**Vehicles as Transport**:
- Player can move character or entire squad into vehicle
- Vehicle appears on map as mobile unit
- Travel speed increased based on vehicle type
- **Vehicle Types**:
  - **Ground**: Car, van, motorcycle (roads only, fast)
  - **All-Terrain**: Truck, APC (can leave roads, slower)
  - **Aerial**: Drone transport (direct pathfinding, expensive)

**Vehicle Mechanics**:
- **Fuel**: Limited range, refuel at stations or black market
- **Durability**: Can take damage, requires repairs
- **Capacity**: Limits squad size (e.g., car = 2 units, van = 4 units, APC = 6 units)
- **Combat**: [Decide: Can vehicles be used in combat? As cover? Mobile turret?]

### Drone Commands (Integration with DroneSystem)
**Player can deploy drones for tactical support**:
- `drone.launch`: Deploy reconnaissance/combat drone
- `drone.scan`: Reveal enemy positions in radius
- `drone.patrol`: Automate area surveillance
- `drone.attack`: Combat drone engages enemies
- `drone.recall`: Return drone to inventory

**Drone Types**:
- **Scout**: Long range, reveals map, spots enemies
- **Combat**: Armed, provides fire support
- **Support**: Heals allies, provides buffs
- **EMP**: Disables enemy electronics

---

## World & Travel

### Map System
**Technology**: OpenStreetMap (OSM) data rendered with Leaflet.js

**Current Implementation**:
- Real-world coordinates (latitude/longitude)
- Custom markers for locations
- Layered map display

**Enhancements Needed**:
- Pathfinding on road network
- District/territory boundaries
- Dynamic events/encounters

### Pathfinding with OpenStreetMap

#### Option 1: Client-Side Pathfinding (Recommended)
**Use Leaflet Routing Machine (LRM)**:
```javascript
// Integration example
L.Routing.control({
  waypoints: [
    L.latLng(playerLat, playerLng),
    L.latLng(destinationLat, destinationLng)
  ],
  router: L.Routing.osrmv1({
    serviceUrl: 'https://router.project-osrm.org/route/v1'
  }),
  routeWhileDragging: false,
  show: false // Don't show instructions UI
}).addTo(map);
```

**Pros**:
- Free OSRM routing service
- Real road network pathfinding
- Works with existing Leaflet integration

**Cons**:
- Requires internet connection
- Limited control over routing algorithm
- May need offline fallback

#### Option 2: Offline Pathfinding
**Use Turf.js for geometry calculations**:
```javascript
// Simplified pathfinding without road network
const destination = turf.point([destLng, destLat]);
const player = turf.point([playerLng, playerLat]);
const distance = turf.distance(player, destination);
const bearing = turf.bearing(player, destination);
```

**Pros**:
- Works offline
- Full control over pathfinding
- Lighter weight

**Cons**:
- Not true road pathfinding (direct line)
- Less realistic movement

#### Option 3: Hybrid Approach (Recommended for This Game)
**Strategy**:
1. **On Foot / Small Area**: Direct line pathfinding (simple, fast)
2. **Vehicle / Long Distance**: Use OSRM road network routing
3. **Cache routes**: Store frequently used paths to reduce API calls
4. **Encounter System**: Random events occur at points along route

**Implementation Plan**:
```javascript
// Pseudo-code
if (distance < 500m) {
  // Short distance: direct pathfinding
  path = straightLine(player, destination);
} else if (hasVehicle) {
  // Long distance with vehicle: use roads
  path = await fetchOSRMRoute(player, destination);
} else {
  // Long distance on foot: suggest vehicle or show "this will take X minutes"
  warnPlayer("Long journey - consider using a vehicle");
}
```

### Districts & Territories
**[Define your city districts]**

**Example Districts**:

**Corporate City** (Central):
- Clean streets, heavy security
- Corporate offices, luxury shops
- High danger if low rep with corps
- Missions: Infiltration, data theft, sabotage

**The Undercity** (Underground):
- Abandoned tube stations, sewers
- Black markets, illegal cyberware clinics
- Safe haven from surface surveillance
- Missions: Smuggling, hideout raids, rescue

**Docklands** (East):
- Shipping yards, warehouses
- Smuggling operations, gang turf wars
- Vehicle chop shops
- Missions: Cargo heists, gang contracts

**Hackney Sprawl** (North):
- Residential slums, street markets
- Faction territories (visible on map)
- NPC recruitment hub
- Missions: Protection rackets, faction wars

### Travel Mechanics
**Movement Speed**:
- **On Foot**: 1 unit/second (base speed × Reflexes modifier)
- **Bicycle**: 3 units/second
- **Car**: 8 units/second (road network only)
- **Aerial Drone**: 5 units/second (direct line, ignores roads)

**Travel Events**:
- **Random Encounters**: % chance based on district danger level
- **Ambushes**: Enemy factions may attack during travel
- **Opportunities**: Stumble upon hidden shops, NPCs, loot
- **Faction Patrols**: Get stopped if in hostile territory

**Fast Travel**:
- **Unlock**: Discover safe houses across city
- **Requirement**: Must be outside of combat
- **Cost**: [Optional: Credits for transport fee?]
- **Restriction**: Cannot fast travel if carrying stolen goods or wanted by faction

### Dynamic World Events
**[Define events that change the world state]**

**Examples**:
- **Faction Territory Shift**: Gang war results in new borders
- **Police Raids**: Shops/NPCs unavailable temporarily
- **Corporate Lockdown**: District sealed off (requires hacking/reputation to enter)
- **Market Fluctuations**: Item prices change based on supply
- **Weather**: Rain (reduced visibility), fog (stealth bonus), clear (drone detection+)

---

## Economy & Resources

### Currency
**Primary Currency**: Credits (₡)
- Earned from: Missions, looting, selling items, hacking
- Spent on: Equipment, cyberware, vehicle fuel, squad salaries, bribes

**Secondary Resources**:
- **Intel**: Information on missions/targets (trade with fixers)
- **Components**: Crafting materials for tech items
- **Reputation**: Faction standing (unlocks access, not spent)

### Income Sources
1. **Mission Rewards**: Primary income (₡500 - ₡50,000 per mission)
2. **Loot**: Enemy drops, containers (₡50 - ₡5,000)
3. **Hacking**: Steal from corpo accounts (₡100 - ₡10,000, risky)
4. **Smuggling**: Transport illegal goods (high reward, high risk)
5. **Protection Rackets**: Passive income from controlled territory (late game)

### Expenses
1. **Equipment**: Weapons (₡1,000 - ₡100,000), Armor (₡500 - ₡50,000)
2. **Cyberware**: Augmentations (₡5,000 - ₡500,000)
3. **Squad Salaries**: Pay units weekly (₡500 - ₡5,000 per unit)
4. **Vehicle Costs**: Purchase (₡10,000 - ₡200,000), fuel (₡50 per trip), repairs
5. **Safe House Upgrades**: Better facilities (₡25,000 - ₡500,000)

### Shop System
**Vendor Types**:
- **Black Market**: Illegal weapons, stolen cyberware (requires reputation)
- **Corporate Store**: Legal items, overpriced, available to all
- **Street Vendors**: Basic supplies, fair prices
- **Fixers**: Intel, mission equipment, specialized gear
- **Chop Shops**: Vehicles, vehicle mods, stolen parts

**Dynamic Pricing**:
```
Final Price = Base Price × Faction Modifier × Rarity Modifier × Supply Modifier

Faction Modifier:
- Hostile: 2.0x (if they even sell to you)
- Unfriendly: 1.5x
- Neutral: 1.0x
- Friendly: 0.9x
- Allied: 0.8x

Rarity Modifier:
- Common: 1.0x
- Uncommon: 2.0x
- Rare: 5.0x
- Legendary: 20.0x

Supply Modifier:
- After major combat: Weapon prices increase
- After police raid: Black market prices increase
```

---

## Technical Notes

### Integration with Existing Systems

#### DataModels Compatibility
**Existing Entities to Use**:
- `Player`: Health, Level, Experience, Skills, Inventory, Currency
- `NPC`: For enemy units and recruitable characters
- `Item`: Equipment, consumables
- `Location`: Mission sites, shops, safe houses
- `Quest`: Missions with objectives
- `Faction`: Reputation system

**New Entities to Create**:
- `Unit`: Squad members (extend NPC with combat stats)
- `Vehicle`: Transport entities
- `Squad`: Container for units

#### Event System Hooks
**Events to Emit**:
- `player.moved`: Update map position
- `combat.initiated`: Trigger combat mode
- `squad.recruited`: Add unit to roster
- `faction.reputationChanged`: Update UI
- `mission.assigned`: AI squad sent on objective
- `vehicle.entered`: Player/squad boards vehicle
- `travel.completed`: Arrival at destination

#### StateManager Integration
**State to Track**:
- Player/unit current position (lat/lng)
- Squad composition and assignments
- Vehicle locations and fuel levels
- Faction reputation values
- Active missions (player-controlled vs AI-controlled)
- World event states (territory ownership, weather, etc.)

### Performance Considerations
**Pathfinding**:
- Cache OSRM routes to reduce API calls
- Limit route recalculation frequency
- Use simplified pathfinding for AI-controlled units

**Combat**:
- Real-time calculations in JavaScript (faster than PowerShell)
- PowerShell handles state updates, not frame-by-frame logic
- Limit active units in combat scene (max 20 total?)

**Map Updates**:
- Only render visible map area
- Use clustering for distant markers
- Update positions every [X milliseconds], not every frame

---

## Instructions for Completion

### How to Fill Out This Template

1. **Replace placeholders** marked with `[Fill this in]` or `**[Define...]**`
2. **Choose examples** that fit your vision or create your own
3. **Delete sections** you don't want (e.g., if no cyberware, remove that section)
4. **Add sections** for unique mechanics your game needs
5. **Be specific** with numbers - easier to balance later than vague descriptions
6. **Link to other docs** - Don't duplicate, reference (e.g., "See UnitTypes.md")

### Next Steps After Completing This Document

1. **Create supporting docs**:
   - `SettingAndAtmosphere.md` - Expand lore and world-building
   - `UnitTypes.md` - Define all unit classes with stats
   - `CombatDesign.md` - Detail combat formulas and mechanics
   - `Docs/Lore/*.md` - Write faction stories, location descriptions, character backstories

2. **Review with team/community**: Get feedback on balance, scope, clarity

3. **Begin implementation**: Use this as reference for coding

4. **Update regularly**: As you implement, update this doc with discoveries and changes

### Tips for World-Building Files

**Create a `Docs/Lore/` directory** for setting details:

**Faction Files** (`Docs/Lore/Factions/`):
- `CorporateFactions.md` - MegaCorps, their goals, notable NPCs
- `StreetGangs.md` - Gang territories, leaders, motivations
- `Underground.md` - Hacker collectives, freedom fighters

**Location Files** (`Docs/Lore/Locations/`):
- `CorporateCity.md` - Notable buildings, shops, NPCs, atmosphere
- `Undercity.md` - Key hideouts, black markets, secrets
- `Docklands.md` - Warehouses, chop shops, smuggling routes

**Character Files** (`Docs/Lore/Characters/`):
- `MainNPCs.md` - Fixers, quest givers, rivals
- `SquadCompanions.md` - Recruitable characters with backstories

**Timeline** (`Docs/Lore/Timeline.md`):
- Major historical events (Network Collapse, Corp Wars, etc.)
- How the world got to its current state

**Example Story Format** (see next steps for template):
```markdown
# Character: "Cipher" - Street Netrunner

**Faction**: Underground Hacktivists
**Role**: Recruitable Netrunner
**Location**: Found during "Data Breach" mission

## Background
Cipher was a corporate security expert until she discovered her employer
was trafficking stolen memories...

## Abilities
- Elite Hacking (+5 Intelligence)
- Network Infiltration Master
- Drone Override Specialist

## Loyalty Events
- +20: Complete "Free the Network" quest
- -30: Betray hackers to corporations
```

---

## Changelog

### Version 0.1.0 (2025-11-14)
- Initial template created
- Defined real-time with pause combat
- Established solo→squad→strategy progression
- Integrated OpenStreetMap pathfinding options
- Added vehicle transport mechanics
