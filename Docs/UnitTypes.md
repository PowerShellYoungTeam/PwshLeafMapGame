# Unit Types & Classes

> **Version**: 0.1.0
> **Last Updated**: November 14, 2025
> **Purpose**: Define all unit classes, stats, progression, and balance

---

## Table of Contents
1. [Unit System Overview](#unit-system-overview)
2. [Base Stats & Attributes](#base-stats--attributes)
3. [Player Character](#player-character)
4. [Recruitable Unit Classes](#recruitable-unit-classes)
5. [Enemy Unit Types](#enemy-unit-types)
6. [Special Units](#special-units)
7. [Unit Progression](#unit-progression)
8. [Balance Guidelines](#balance-guidelines)

---

## Unit System Overview

### Unit Categories

**Player Character**:
- Unique, customizable, main protagonist
- Can specialize but remains versatile
- Never dies permanently (downed = mission failure or revive cost)

**Recruitable Units (Squad Members)**:
- AI-controlled companions
- Class-based with specializations
- Can die permanently (optional hardcore mode)
- Loyalty system affects performance

**Enemy Units**:
- AI-controlled hostiles
- Faction-specific types
- Scale with player level

**Special Units**:
- Drones (existing DroneSystem)
- Vehicles (transport, not combat units themselves)
- Boss enemies (unique mechanics)

### Unit Roles

**Tank**: High HP, draws fire, protects allies
**DPS**: Damage dealer, fragile but lethal
**Support**: Heals, buffs allies, debuffs enemies
**Specialist**: Hacking, stealth, utility

---

## Base Stats & Attributes

### Primary Attributes (Player & Units)

**Body** (10-20):
- Affects: Health, melee damage, carry capacity, intimidation
- Combat: +10 HP per point, +5% melee damage
- Non-Combat: Lift heavy objects, break doors, intimidate NPCs

**Reflexes** (10-20):
- Affects: Accuracy, dodge chance, initiative, movement speed
- Combat: +2% accuracy per point, +1% dodge, +0.5% crit chance
- Non-Combat: Reaction challenges, stealth movement speed

**Intelligence** (10-20):
- Affects: Hacking, tech skills, ability cooldowns, drone control
- Combat: +3% hack success per point, -5% ability cooldown
- Non-Combat: Dialogue options, tech interaction, drone commands

**Cool** (10-20):
- Affects: Critical chance, social skills, stress resistance, leadership
- Combat: +1% crit chance per point, +5% crit damage
- Non-Combat: Persuasion, deception, keep squad morale high

**Attribute Totals**:
- Starting: 50 points to distribute (min 10, max 15 at start)
- Per Level: +1 attribute point (player choice)
- Max Level Cap: 80 total attributes (average 20 each)

### Derived Stats (Calculated)

**Health Points (HP)**:
```
Base HP = 50 + (Body × 10) + (Level × 5)
Example: Level 10, Body 15 = 50 + 150 + 50 = 250 HP
```

**Action Points (AP)**:
- Base: 100 AP
- Regeneration: 10 AP/second in real-time
- Abilities cost 20-50 AP
- Movement costs 5 AP per unit distance

**Accuracy** (Hit Chance):
```
Base Accuracy = 50% + (Reflexes × 2%) + Weapon Bonus - Range Penalty - Cover Penalty
Example: Reflexes 15, Weapon +10%, Range -5%, Cover -25% = 50 + 30 + 10 - 5 - 25 = 60%
```

**Critical Chance**:
```
Base Crit = 5% + (Cool × 1%) + (Reflexes × 0.5%)
Critical Damage = 2.0x + (Cool × 0.05x)
Example: Cool 15, Reflexes 12 = 5 + 15 + 6 = 26% crit chance, 2.75x crit damage
```

**Movement Speed**:
```
Base Speed = 5 units/second + (Reflexes × 0.2)
Example: Reflexes 15 = 5 + 3 = 8 units/second
```

**Dodge Chance** (Avoid Damage):
```
Base Dodge = 0% + (Reflexes × 1%) - Armor Weight Penalty
Example: Reflexes 15, Heavy Armor -5% = 10%
```

---

## Player Character

### Overview
- **Role**: Versatile protagonist
- **Starting Attributes**: Player choice (50 points)
- **Specialization**: Can learn all skills but benefits from focusing

### Progression Path

**Level 1-10 (Early Game)**:
- Generalist - learn basics of all systems
- Focus: Survival, basic combat, exploration
- Unlock: First cyberware slot, basic abilities

**Level 11-20 (Mid Game)**:
- Specialization - choose primary role
- Focus: Advanced abilities, squad building
- Unlock: Second cyberware slot, advanced abilities, leadership skills

**Level 21-30 (Late Game)**:
- Master - become elite in chosen path
- Focus: Faction influence, territory control
- Unlock: Third cyberware slot, ultimate abilities, command multiple squads

### Unique Abilities (Player Only)

**Leadership** (Passive):
- Squad members within 10 units gain +10% stats per player Cool stat
- Unlock at Level 10

**Tactical Pause** (Active):
- Pause game in combat to issue orders
- No cooldown (player can pause any time)

**Respawn**:
- Player cannot die permanently (story purposes)
- Downed = Mission Failure or Pay Revival Cost
- Consequence: Reputation loss, loot lost, time passed

---

## Recruitable Unit Classes

### Class Template Structure

For each class below:
- **Role**: Tactical role
- **Primary Attributes**: Key stats
- **Starting Stats**: Level 1 base
- **Equipment**: Default gear
- **Abilities**: 3 active, 2 passive
- **Progression**: How they improve
- **Recruitment**: Where to find

---

### 1. Enforcer (Tank)

**Role**: Frontline tank, absorbs damage, protects squad

**Primary Attributes**:
- Body: 18 (high)
- Reflexes: 12 (medium)
- Intelligence: 10 (low)
- Cool: 13 (medium)

**Starting Stats (Level 1)**:
- HP: 280
- Accuracy: 60%
- Dodge: 7%
- Crit Chance: 15%
- Move Speed: 6.4 units/sec

**Equipment**:
- Weapon: Shotgun (close range, high damage)
- Armor: Heavy (60 armor, -3% dodge penalty)
- Cyberware: Bone Reinforcement (Skeletal)

**Abilities**:

**Active**:
1. **Taunt** (30 AP, 15s cooldown): Force enemies within 10 units to target this unit for 5s
2. **Charge** (40 AP, 20s cooldown): Rush forward 15 units, knock down enemies, gain temporary shield
3. **Last Stand** (50 AP, 60s cooldown): Immune to damage for 5s, but HP can't go above 1

**Passive**:
1. **Thick Skinned**: +20% max HP
2. **Protector**: Allies within 5 units take -20% damage

**Progression**:
- **Tier 2 (Lv 10)**: Unlock "Shieldwall" - Create deployable cover
- **Tier 3 (Lv 20)**: Unlock "Juggernaut" - Cannot be stunned or knocked down

**Recruitment**:
- **Location**: Hired from security contractors, rescue from gang fight
- **Cost**: ₡5,000
- **Loyalty Start**: 50/100

**Character Archetype**: *"Ex-corpo security who got tired of protecting cowards. Looking for a crew that fights back."*

---

### 2. Operative (Balanced DPS)

**Role**: Versatile soldier, balanced offense/defense

**Primary Attributes**:
- Body: 13 (medium)
- Reflexes: 17 (high)
- Intelligence: 12 (medium)
- Cool: 14 (medium)

**Starting Stats (Level 1)**:
- HP: 180
- Accuracy: 74%
- Dodge: 12%
- Crit Chance: 22.5%
- Move Speed: 8.4 units/sec

**Equipment**:
- Weapon: Assault Rifle (medium range, balanced)
- Armor: Medium (40 armor, -1% dodge)
- Cyberware: Reflex Booster (Neural)

**Abilities**:

**Active**:
1. **Suppressing Fire** (30 AP, 12s cooldown): Pin target behind cover, reduce their accuracy by 50% for 6s
2. **Tactical Roll** (20 AP, 8s cooldown): Quick dodge, +50% dodge chance for 3s
3. **Headshot** (40 AP, 15s cooldown): Guaranteed crit if hit, +100% crit damage

**Passive**:
1. **Combat Reflexes**: +15% accuracy
2. **Adaptable**: Can use any weapon type without penalty

**Progression**:
- **Tier 2 (Lv 10)**: Unlock "Dual Wield" - Equip two one-handed weapons
- **Tier 3 (Lv 20)**: Unlock "Assassinate" - Stealth kills from behind

**Recruitment**:
- **Location**: Found during missions, respond to job postings
- **Cost**: ₡3,000
- **Loyalty Start**: 60/100

**Character Archetype**: *"Former Runner who's seen it all. Professional, efficient, doesn't ask questions."*

---

### 3. Netrunner (Hacker/Support)

**Role**: Hacking specialist, disables enemies, controls battlefield

**Primary Attributes**:
- Body: 10 (low)
- Reflexes: 13 (medium)
- Intelligence: 19 (high)
- Cool: 12 (medium)

**Starting Stats (Level 1)**:
- HP: 150
- Accuracy: 62%
- Dodge: 8%
- Crit Chance: 18.5%
- Move Speed: 7.6 units/sec
- Hack Success: 87%

**Equipment**:
- Weapon: SMG (close range, low damage)
- Armor: Light (20 armor, +2% dodge)
- Cyberware: Neural Interface (Neural), Hacking Deck

**Abilities**:

**Active**:
1. **Disable Weapon** (25 AP, 10s cooldown): Hack enemy weapon, 80% chance to jam for 8s
2. **Hijack Drone** (40 AP, 20s cooldown): Take control of enemy drone for 30s
3. **System Shock** (50 AP, 25s cooldown): AoE hack, stun all enemies with cyberware in 12 unit radius for 4s

**Passive**:
1. **Tech Expert**: +20% hack success, -20% ability cooldowns
2. **Data Runner**: Can see enemy stats and equipment

**Progression**:
- **Tier 2 (Lv 10)**: Unlock "Turret Control" - Hack security turrets
- **Tier 3 (Lv 20)**: Unlock "Neural Fry" - Instant kill low-level enemies with cyberware

**Recruitment**:
- **Location**: The Undercity, hacker hideouts, rescued from corp raid
- **Cost**: ₡4,000
- **Loyalty Start**: 40/100 (paranoid, trust issues)

**Character Archetype**: *"Paranoid genius who sees the world in code. Believes information should be free. Will betray you if you work for corps."*

---

### 4. Medic (Support/Healer)

**Role**: Healing, buffs, keeps squad alive

**Primary Attributes**:
- Body: 12 (medium)
- Reflexes: 14 (medium)
- Intelligence: 16 (high)
- Cool: 15 (high)

**Starting Stats (Level 1)**:
- HP: 170
- Accuracy: 66%
- Dodge: 9%
- Crit Chance: 22%
- Move Speed: 7.8 units/sec

**Equipment**:
- Weapon: Pistol (medium range, low damage)
- Armor: Medium (35 armor, -1% dodge)
- Cyberware: Medical Injector (Arms), Enhanced Senses (Optical)

**Abilities**:

**Active**:
1. **Field Medic** (30 AP, 8s cooldown): Heal ally for 100 HP
2. **Stimpack** (35 AP, 15s cooldown): Inject ally with combat drugs, +25% damage for 10s
3. **Stabilize** (40 AP, 10s cooldown): Revive downed ally at 50% HP

**Passive**:
1. **Healer**: All healing +50% effectiveness
2. **Triage**: Automatically heal nearby allies for 5 HP/second in combat

**Progression**:
- **Tier 2 (Lv 10)**: Unlock "Area Heal" - Heal all allies in radius
- **Tier 3 (Lv 20)**: Unlock "Resurrection" - Revive ally at full HP once per mission

**Recruitment**:
- **Location**: Free Clinic, rescued from ambush, hired from medical background
- **Cost**: ₡3,500
- **Loyalty Start**: 70/100 (helpful, but wary)

**Character Archetype**: *"Former corpo medic who couldn't stand watching people die for profit margins. Heals anyone who needs it."*

---

### 5. Sniper (Long-Range DPS)

**Role**: Eliminate high-value targets from distance

**Primary Attributes**:
- Body: 11 (low)
- Reflexes: 18 (high)
- Intelligence: 14 (medium)
- Cool: 16 (high)

**Starting Stats (Level 1)**:
- HP: 160
- Accuracy: 76%
- Dodge: 13%
- Crit Chance: 25%
- Crit Damage: 2.8x
- Move Speed: 8.6 units/sec

**Equipment**:
- Weapon: Sniper Rifle (extreme range, very high damage, slow fire rate)
- Armor: Light (25 armor, +1% dodge)
- Cyberware: Targeting System (Optical), Stabilized Grip (Skeletal)

**Abilities**:

**Active**:
1. **Perfect Shot** (50 AP, 20s cooldown): Next shot guaranteed hit, guaranteed crit, +200% damage
2. **Cloak** (30 AP, 30s cooldown): Become invisible for 10s or until firing
3. **Disruption Round** (35 AP, 15s cooldown): EMP shot disables target's cyberware and abilities for 12s

**Passive**:
1. **Eagle Eye**: +50% accuracy at long range (>30 units)
2. **Patient Hunter**: +10% damage per second spent aiming (max 50%)

**Progression**:
- **Tier 2 (Lv 10)**: Unlock "Penetration Shot" - Bullet pierces through multiple enemies
- **Tier 3 (Lv 20)**: Unlock "Orbital Strike" - Call in satellite laser (once per mission, massive damage)

**Recruitment**:
- **Location**: Elite mercenary, found through reputation
- **Cost**: ₡6,000
- **Loyalty Start**: 30/100 (cold, professional, not personal)

**Character Archetype**: *"Silent killer who speaks through rifle scope. Reputation precedes them. Very expensive, very effective."*

---

### 6. Brawler (Melee DPS)

**Role**: Close combat specialist, high risk/high reward

**Primary Attributes**:
- Body: 17 (high)
- Reflexes: 16 (high)
- Intelligence: 10 (low)
- Cool: 13 (medium)

**Starting Stats (Level 1)**:
- HP: 220
- Melee Damage: +85%
- Accuracy: 72% (ranged)
- Dodge: 11%
- Crit Chance: 21%
- Move Speed: 8.2 units/sec

**Equipment**:
- Weapon: Mantis Blades (cyberware melee), backup pistol
- Armor: Medium (45 armor, -1% dodge)
- Cyberware: Mantis Blades (Arms), Reflex Booster (Neural)

**Abilities**:

**Active**:
1. **Blade Flurry** (40 AP, 12s cooldown): Hit all enemies in melee range 3 times rapidly
2. **Leap Attack** (35 AP, 15s cooldown): Jump to target 20 units away, deal massive damage on landing
3. **Berserker** (50 AP, 45s cooldown): Gain +100% damage, +50% speed, lose -50% defense for 15s

**Passive**:
1. **Melee Master**: +50% melee damage
2. **Momentum**: Each kill grants +10% speed (stacks 5 times)

**Progression**:
- **Tier 2 (Lv 10)**: Unlock "Execution" - Instant kill enemies below 25% HP
- **Tier 3 (Lv 20)**: Unlock "Whirlwind" - Spin attack hits all nearby enemies

**Recruitment**:
- **Location**: Fighting pits, gang territories, street brawls
- **Cost**: ₡4,500
- **Loyalty Start**: 50/100 (respects strength)

**Character Archetype**: *"Street fighter who turned violence into art form. Loyalty through combat. Challenge them to earn respect."*

---

## Enemy Unit Types

### Enemy Categories

**Tier 1: Street Thugs** (Levels 1-5):
- Basic criminals, low gear, poor training
- Found in: Sprawl, random encounters

**Tier 2: Gang Members** (Levels 5-15):
- Organized, moderate gear, tactics
- Found in: Gang territories, faction missions

**Tier 3: Corporate Security** (Levels 10-20):
- Professional, high-end gear, advanced tactics
- Found in: Corporate districts, infiltration missions

**Tier 4: Elite Operatives** (Levels 15-25):
- Military-trained, prototype gear, coordinated
- Found in: High-level missions, boss encounters

**Tier 5: Bosses** (Levels 20-30):
- Unique enemies, special abilities, high rewards
- Found in: Story missions, faction leaders

---

### Enemy Templates

#### Street Thug

**Level**: 1-5
**HP**: 80-150
**Damage**: 10-25
**Armor**: 5-15
**Weapons**: Pistol, knife, pipe
**Abilities**: None
**Tactics**: Rush player, no cover use
**Loot**: ₡50-200, basic ammo

---

#### Gang Enforcer

**Level**: 5-10
**HP**: 150-250
**Damage**: 25-50
**Armor**: 30-50
**Weapons**: Shotgun, SMG
**Abilities**:
- **Aggressive Rush**: Charge at player
- **Intimidate**: Reduce player accuracy briefly
**Tactics**: Use half-cover, flank if possible
**Loot**: ₡300-800, gang colors, medium weapons

---

#### Corporate Security

**Level**: 10-15
**HP**: 200-350
**Damage**: 40-70
**Armor**: 60-80
**Weapons**: Assault rifle, combat drones
**Abilities**:
- **Drone Support**: Call combat drone
- **Tactical Shield**: Deploy cover
- **Flashbang**: Blind player squad
**Tactics**: Coordinated, use full cover, call reinforcements
**Loot**: ₡1,000-3,000, corporate weapons, keycards

---

#### Elite Netrunner (Enemy)

**Level**: 15-20
**HP**: 150-250 (low HP, high threat)
**Damage**: 30-50 (ranged)
**Armor**: 20-40
**Weapons**: SMG
**Abilities**:
- **Hack Weapon**: Disable player weapon
- **Hijack Cyberware**: Stun player with cyberware
- **System Override**: Take control of player's drone
- **Emergency Cloak**: Become invisible when damaged
**Tactics**: Stay at distance, hack from cover, flee if approached
**Loot**: ₡2,000-5,000, hacking software, cyberware components

---

#### Boss: "The Chrome Reaper" (Gang Leader)

**Level**: 20
**HP**: 5,000
**Damage**: 100-200
**Armor**: 120
**Weapons**: Dual arm-mounted cannons, melee blades
**Abilities**:
- **Phase 1 (100%-60% HP)**:
  - Artillery Barrage: AoE damage across map
  - Summon Reinforcements: Calls 4 gang members
- **Phase 2 (60%-30% HP)**:
  - Berserker Mode: +50% damage, +50% speed
  - EMP Pulse: Disables all electronics in radius
- **Phase 3 (<30% HP)**:
  - Desperation: Random ability spam
  - Regeneration: Heals 100 HP/sec
**Tactics**: Aggressive, chases player, area denial
**Loot**: ₡25,000, legendary cyberware, gang reputation++

---

## Special Units

### Drones (Integrated with DroneSystem)

**Player-Controlled Drones**:

**Scout Drone**:
- HP: 50
- Speed: 10 units/sec
- Abilities: Scan (reveal enemies), Patrol (auto-scout)
- Cost: ₡1,000
- Fuel: 5 minutes

**Combat Drone**:
- HP: 100
- Speed: 8 units/sec
- Damage: 20-40
- Abilities: Attack, Suppressing Fire
- Cost: ₡3,000
- Fuel: 3 minutes

**Support Drone**:
- HP: 75
- Speed: 7 units/sec
- Abilities: Heal Allies (20 HP/sec), Shield Projection (+50 temp HP)
- Cost: ₡2,500
- Fuel: 4 minutes

**EMP Drone**:
- HP: 60
- Speed: 9 units/sec
- Abilities: EMP Burst (disable electronics), Hack Enemy Drones
- Cost: ₡2,000
- Fuel: 3 minutes

**Drone Management**:
- Max Active: 2 drones at once (3 with Intelligence 18+)
- Refuel: At safe house or black market
- Repair: Costs ₡500 + 10% of purchase price
- Lost: Must repurchase

---

### Vehicles (Transport Units)

**Vehicles are not combat units** - They transport squad members

**Motorcycle**:
- Capacity: 1 unit (solo only)
- Speed: 15 units/sec
- Fuel: 50 km range
- Durability: 200 HP
- Cost: ₡10,000
- Special: Can weave through traffic, escape easily

**Car**:
- Capacity: 4 units (player + 3 squad)
- Speed: 12 units/sec
- Fuel: 100 km range
- Durability: 400 HP
- Cost: ₡25,000
- Special: Moderate protection, balanced

**Van**:
- Capacity: 6 units (player + 5 squad)
- Speed: 9 units/sec
- Fuel: 80 km range
- Durability: 600 HP
- Cost: ₡40,000
- Special: High capacity, can store extra gear

**APC (Armored Personnel Carrier)**:
- Capacity: 6 units + mounted turret
- Speed: 7 units/sec
- Fuel: 60 km range
- Durability: 1,200 HP
- Cost: ₡100,000
- Special: Heavy armor, can be used as mobile cover in combat

**Aerial Transport**:
- Capacity: 4 units
- Speed: 20 units/sec (ignores roads, direct pathfinding)
- Fuel: 30 km range (expensive fuel)
- Durability: 300 HP
- Cost: ₡150,000
- Special: Fast, ignores terrain, but conspicuous (draws attention)

**Vehicle Mechanics**:
- **Damaged**: Below 50% HP, speed reduced by 25%
- **Critical**: Below 25% HP, may break down randomly
- **Destroyed**: 0 HP, must be repaired (₡5,000-50,000) or replaced
- **Refuel**: ₡50-200 depending on type
- **Repair Kits**: Consumable items restore 100 HP (₡500)

---

## Unit Progression

### Experience & Leveling

**XP Gains**:
- Combat Kill: 50-500 XP (based on enemy level)
- Mission Complete: 1,000-10,000 XP (based on difficulty)
- Objective Complete: 200-1,000 XP
- Discovery: 100-500 XP (new locations, secrets)

**XP Required Per Level**:
```
Level 2: 1,000 XP
Level 3: 2,500 XP
Level 4: 4,500 XP
Level 5: 7,000 XP
...
Level N: (N × 500) + ((N-1) × 500) XP

Total to Level 30: ~250,000 XP
```

**Level-Up Rewards**:
- +1 Attribute Point (player allocates)
- +5 Max HP
- +1 Skill Point (spend in skill tree)
- Every 5 levels: Unlock ability tier

### Skill Trees (Per Class)

**Example: Enforcer Skill Tree**

**Tier 1 (Levels 1-10)**:
- `Tough`: +10% max HP per rank (5 ranks)
- `Armor Expert`: +5 armor per rank (5 ranks)
- `Melee Damage`: +10% melee damage per rank (3 ranks)

**Tier 2 (Levels 10-20)**:
- `Unbreakable`: Immune to stun/knockdown
- `Shieldwall`: Deploy portable cover (active ability)
- `Intimidating Presence`: Enemies hesitate before attacking

**Tier 3 (Levels 20-30)**:
- `Juggernaut`: Cannot be stopped, +50% HP
- `Last Stand Master`: Last Stand ability lasts 10s instead of 5s
- `Protector Supreme`: Allies within 10 units take -30% damage

**Skill Points**:
- Gain 1 per level
- Max: 30 skill points at level 30
- Cannot max all skills (choices matter)

### Equipment Progression

**Weapon Tiers**:
- **Street** (Lv 1-10): Basic, cheap, common
- **Military** (Lv 10-20): Professional, expensive, uncommon
- **Corporate** (Lv 15-25): Advanced, very expensive, rare
- **Prototype** (Lv 20-30): Unique, quest rewards, legendary

**Armor Tiers**:
- Same as weapons

**Cyberware Tiers**:
- **Street**: +10% stat bonus
- **Military**: +25% stat bonus
- **Corporate**: +50% stat bonus + special effect
- **Prototype**: +100% stat bonus + unique ability

---

## Balance Guidelines

### Combat Power Scaling

**Player Power Curve** (Expected Stats at Level):
- **Level 1**: 150 HP, 60% accuracy, 15% crit
- **Level 10**: 250 HP, 70% accuracy, 25% crit
- **Level 20**: 400 HP, 80% accuracy, 35% crit
- **Level 30**: 600 HP, 90% accuracy, 45% crit

**Enemy Scaling** (Match Player Level ± 2):
- **Same Level**: Fair fight (50/50 with good tactics)
- **+2 Levels**: Hard (requires strategy)
- **+5 Levels**: Very Hard (avoid or need full squad)
- **-2 Levels**: Easy (clear quickly)
- **-5 Levels**: Trivial (one-shot kills)

### Squad Balance

**Ideal Squad Composition**:
- 1 Tank (Enforcer)
- 2 DPS (Operative, Sniper, or Brawler)
- 1 Support (Medic or Netrunner)

**Solo Viability**:
- Player can complete missions solo (harder, more rewarding)
- Squad makes content easier but costs upkeep

**AI Squad Missions** (Late Game):
- AI-controlled squads 80% effective as player-controlled
- Success chance based on: Squad level, composition, loyalty, equipment
- High-risk missions may result in casualties

### Economy Balance

**Income vs Expenses** (Per Hour of Gameplay):

**Early Game (Lv 1-10)**:
- Income: ₡5,000-10,000/hr
- Expenses: ₡2,000-5,000/hr (ammo, repairs, basic gear)
- Net: ₡3,000-5,000/hr

**Mid Game (Lv 10-20)**:
- Income: ₡15,000-30,000/hr
- Expenses: ₡8,000-15,000/hr (squad salaries, fuel, better gear)
- Net: ₡7,000-15,000/hr

**Late Game (Lv 20-30)**:
- Income: ₡50,000-100,000/hr
- Expenses: ₡20,000-40,000/hr (cyberware, vehicles, safe house upgrades)
- Net: ₡30,000-60,000/hr

**Squad Upkeep Costs**:
- Basic Unit: ₡500/week
- Skilled Unit: ₡2,000/week
- Elite Unit: ₡5,000/week

---

## Instructions for Expansion

### Adding New Unit Classes

1. **Define Role**: What tactical niche does it fill?
2. **Set Attributes**: Use existing balance as baseline
3. **Design Abilities**: 3 active, 2 passive (scale with level)
4. **Equipment**: What gear fits the fantasy?
5. **Recruitment**: Where/how does player find them?
6. **Character**: Give them personality and backstory hook

### Creating Enemy Variants

1. **Base Type**: Start with template (Thug, Gang, Security, Elite)
2. **Faction Flavor**: Add faction-specific ability or weapon
3. **Level Scaling**: Adjust HP/damage for target level range
4. **Loot Table**: What do they drop? Faction-specific items?

### Balancing New Content

**Testing Checklist**:
- [ ] Can player solo this with tactics?
- [ ] Is squad composition required or just helpful?
- [ ] Are abilities fun to use (not just stat boosts)?
- [ ] Does this unit have strengths AND weaknesses?
- [ ] Is cost appropriate for power level?
- [ ] Does this fit the cyberpunk theme?

---

## Changelog

### Version 0.1.0 (2025-11-14)
- Initial template created
- Defined 6 recruitable classes
- Created enemy scaling system
- Integrated drone and vehicle units
- Established progression framework
