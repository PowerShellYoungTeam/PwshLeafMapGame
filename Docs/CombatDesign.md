# Combat Design: Real-Time with Pause

> **Version**: 0.1.0
> **Last Updated**: November 14, 2025
> **Purpose**: Technical specification for combat system implementation

---

## Table of Contents
1. [Combat Overview](#combat-overview)
2. [Real-Time with Pause Mechanics](#real-time-with-pause-mechanics)
3. [Action Point System](#action-point-system)
4. [Movement & Pathfinding](#movement--pathfinding)
5. [Combat Actions](#combat-actions)
6. [Cover System](#cover-system)
7. [Line of Sight & Fog of War](#line-of-sight--fog-of-war)
8. [Damage Calculation](#damage-calculation)
9. [Status Effects](#status-effects)
10. [AI Behavior](#ai-behavior)
11. [Combat Flow](#combat-flow)
12. [Technical Implementation](#technical-implementation)

---

## Combat Overview

### Core Philosophy
- **Real-Time**: Combat unfolds continuously, creating tension and urgency
- **Tactical Pause**: Player can pause anytime to assess and issue orders
- **Action Points**: Limit actions per unit to prevent ability spam
- **Positioning Matters**: Cover, flanking, and range affect outcomes
- **Squad Coordination**: Synergize unit abilities for tactical advantage

### Design Goals
- **Accessible**: Easy to learn basic combat (point and shoot)
- **Deep**: Mastery requires positioning, ability timing, squad synergy
- **Fast-Paced**: Encounters resolve in 1-5 minutes
- **Fair**: Player can always retreat or pause to think
- **Rewarding**: Tactical play significantly improves outcomes

---

## Real-Time with Pause Mechanics

### Time Flow States

**Real-Time Mode** (Default):
- Time flows at 1.0x speed
- All units act simultaneously
- Player can issue orders on-the-fly
- AP regenerates continuously (10 AP/second)
- Cooldowns tick down in real-time

**Tactical Pause** (Player-Activated):
- Time stops completely
- Player can:
  - Issue queued orders to units
  - Inspect enemy stats
  - Plan ability combinations
  - Assess battlefield situation
- No time limit on pause
- Can unpause to see orders execute

**Slow Motion** (Optional Feature):
- Time flows at 0.5x or 0.25x speed
- Gives player more reaction time without full pause
- AP regeneration slowed proportionally
- Useful for learning or high-difficulty

### Pause Triggers

**Automatic Pause** (Optional Setting):
- Enemy spotted for first time
- Ally downed
- Ability ready (if player enabled notifications)
- Ambush triggered
- Player HP below 25%

**Manual Pause**:
- Hotkey: `Spacebar` (default)
- UI Button: "Pause" button always visible
- No cooldown, unlimited use

### Order Queue System

**While Paused, player can queue orders**:

1. **Select Unit**: Click portrait or unit on map
2. **Issue Order**: Click ability or location
3. **Order Queued**: Icon appears above unit showing next action
4. **Unpause**: Orders execute in sequence

**Example Queue**:
```
Enforcer: Move to cover → Use Taunt → Attack nearest enemy
Sniper: Move to high ground → Use Cloak → Aim at target → Perfect Shot
Medic: Stay in position → Heal Enforcer when HP < 50%
```

**Queue Limits**:
- Max 3 queued orders per unit
- Can cancel/modify queue while paused
- Queue clears when changing plans

---

## Action Point System

### AP Mechanics

**Base Values**:
- **Max AP**: 100 (all units)
- **Starting AP**: 100 (full at combat start)
- **Regeneration Rate**: 10 AP/second in real-time
- **Pause Effect**: AP does not regenerate while paused

**AP Costs**:
- **Movement**: 0 AP (continuous, not action-based)
- **Basic Attack**: 0 AP (auto-attack, but limited by weapon fire rate)
- **Abilities**: 20-50 AP (varies by ability)
- **Item Use**: 20 AP (grenades, medkits, etc.)
- **Interact**: 10 AP (doors, terminals, loot)

### Ability Costs by Type

**Low Cost (20-25 AP)**: Tactical positioning, buffs
- Examples: Tactical Roll, Field Medic, Disable Weapon

**Medium Cost (30-40 AP)**: Strong attacks, debuffs
- Examples: Suppressing Fire, Blade Flurry, Hijack Drone

**High Cost (45-50 AP)**: Ultimate abilities, game-changers
- Examples: Perfect Shot, System Shock, Last Stand

### Cooldown System

**Cooldowns run independently of AP**:
- Cooldowns tick in real-time (not affected by AP)
- Ability available when: `AP >= Cost AND Cooldown == 0`
- Using ability: Consumes AP, starts cooldown timer

**Example**:
- **Perfect Shot**: 50 AP cost, 20-second cooldown
- Sniper uses Perfect Shot at 100 AP
- AP drops to 50
- Cooldown starts (20 seconds)
- After 5 seconds: AP regenerated to 100, cooldown still 15 seconds remaining
- After 20 seconds: Cooldown complete, ability ready again (if still have 50 AP)

---

## Movement & Pathfinding

### Movement Mechanics

**Real-Time Movement**:
- Click destination: Unit pathfinds and moves continuously
- No AP cost for movement (to keep combat flowing)
- Movement speed in units/second (based on Reflexes stat)
- Can change destination while moving (cancels previous order)

**Movement Speed**:
```
Base Speed = 5 units/sec + (Reflexes × 0.2)

Modifiers:
- Sprint: +50% speed, but cannot take cover or attack
- Crouched: -25% speed, but harder to detect
- Wounded (<25% HP): -30% speed
- In Water/Difficult Terrain: -50% speed
```

**Movement Actions**:
- **Walk**: Default, balanced
- **Sprint**: Hold `Shift`, faster but exposed
- **Crouch**: Hold `Ctrl`, slower but stealthier
- **Stop**: `S` key or right-click on self

### Pathfinding Implementation

#### Option 1: Leaflet Routing Machine (OSRM) - For Vehicle Travel

**Use Case**: Long-distance vehicle travel on roads

**Implementation**:
```javascript
// When player uses vehicle for long trip
if (travelDistance > 500 && playerHasVehicle) {
  const route = await L.Routing.osrmv1({
    serviceUrl: 'https://router.project-osrm.org/route/v1'
  }).route({
    waypoints: [
      L.latLng(startLat, startLng),
      L.latLng(endLat, endLng)
    ]
  });

  // Follow road network path
  return route.coordinates;
}
```

**Pros**: Realistic road navigation
**Cons**: Requires internet, API rate limits

#### Option 2: A* Pathfinding (Custom) - For Combat Movement

**Use Case**: Short-distance tactical movement, combat positioning

**Implementation**:
```javascript
// Simple A* for combat areas
function findPath(start, goal, obstacles) {
  // Grid-based A* algorithm
  // Cost function considers:
  // - Distance to goal
  // - Obstacles (walls, cover)
  // - Enemy line of sight
  // - Dangerous areas (grenades, fire)

  return shortestPathAvoidingObstacles;
}
```

**Pros**: Works offline, fast, controllable
**Cons**: Less realistic (doesn't use real roads)

#### Option 3: Hybrid Approach (Recommended)

**Strategy**:
```javascript
function getPathfinding(start, end, context) {
  const distance = calculateDistance(start, end);

  if (context.inCombat) {
    // Combat: Use A* for tactical movement
    return AStarPathfinding(start, end, combatObstacles);
  }
  else if (context.hasVehicle && distance > 500) {
    // Vehicle travel: Use OSRM for roads
    return OSRMPathfinding(start, end);
  }
  else {
    // On foot, short distance: Straight line
    return straightLinePath(start, end);
  }
}
```

### Collision & Obstacles

**Unit Collision**:
- Units cannot overlap
- Pathfinding routes around allies
- Enemies block path (must eliminate or go around)

**Environmental Obstacles**:
- **Walls**: Block movement and line of sight
- **Cover**: Can move behind, provides defense bonus
- **Doors**: Can open (10 AP), or destroy (if locked)
- **Vehicles**: Provide cover, can enter/exit
- **Water/Hazards**: Slow movement, may deal damage

---

## Combat Actions

### Basic Attack (Auto-Attack)

**Mechanics**:
- **Trigger**: Enemy in range and line of sight
- **Cost**: 0 AP (to keep combat fluid)
- **Fire Rate**: Limited by weapon type (0.5 - 3 seconds between shots)
- **Target**: Closest enemy (default) or player-selected target
- **Toggle**: Can disable auto-attack (manual targeting only)

**Attack Process**:
1. Check if enemy in weapon range
2. Check line of sight (not blocked by walls/cover)
3. Calculate hit chance (accuracy - cover - range)
4. Roll to hit
5. If hit: Calculate damage
6. Apply damage and status effects

### Weapon Types & Properties

**Pistol**:
- Range: 30 units
- Damage: 25-40
- Fire Rate: 1 shot/second
- Accuracy: +0%
- Special: Balanced, reliable

**SMG**:
- Range: 20 units
- Damage: 15-25
- Fire Rate: 3 shots/second
- Accuracy: -10%
- Special: High DPS, close range

**Assault Rifle**:
- Range: 50 units
- Damage: 35-55
- Fire Rate: 1.5 shots/second
- Accuracy: +5%
- Special: Versatile, medium range

**Sniper Rifle**:
- Range: 100 units
- Damage: 100-150
- Fire Rate: 0.5 shots/second
- Accuracy: +20% (at long range)
- Special: Extreme range, slow fire

**Shotgun**:
- Range: 15 units
- Damage: 60-90
- Fire Rate: 0.75 shots/second
- Accuracy: -20%
- Special: Devastating close-range, spreads to nearby targets

### Abilities

**See [UnitTypes.md](./UnitTypes.md) for full ability list per class**

**Ability Execution**:
1. Player selects unit (or it's queued)
2. Player clicks ability button
3. If targeted: Click target or location
4. Check AP cost and cooldown
5. If sufficient: Execute ability, consume AP, start cooldown
6. Apply effects (damage, buff, debuff, etc.)
7. Broadcast event to EventSystem

**Ability Categories**:

**Offensive**:
- Damage abilities (Headshot, Perfect Shot, Blade Flurry)
- Debuffs (Suppress, Disable Weapon, System Shock)

**Defensive**:
- Buffs (Tactical Shield, Berserker, Stimpack)
- Healing (Field Medic, Stabilize, Area Heal)

**Utility**:
- Movement (Charge, Leap Attack, Tactical Roll)
- Information (Scan, Data Runner, Eagle Eye)
- Control (Taunt, Cloak, Hijack Drone)

### Item Usage

**Consumable Items** (20 AP to use):

**Medkit**:
- Heal 150 HP instantly
- Can use on self or ally (5 unit range)
- Cost: ₡500

**Grenade (Frag)**:
- Throw up to 25 units
- AoE: 8 unit radius
- Damage: 100-150
- Cost: ₡200

**Grenade (EMP)**:
- AoE: 10 unit radius
- Effect: Disable cyberware and electronics for 10s
- Cost: ₡300

**Grenade (Smoke)**:
- AoE: 12 unit radius
- Effect: Block line of sight for 15s
- Cost: ₡150

**Stimpack**:
- Buff: +25% damage, +25% speed for 30s
- Debuff: -10% accuracy (jittery)
- Cost: ₡400

---

## Cover System

### Cover Types

**Full Cover** (Walls, Vehicles, Large Objects):
- **Effect**: -50% accuracy against unit in cover
- **Visual**: Icon shows full shield
- **Requirements**: Unit must be adjacent to cover, crouching

**Half Cover** (Crates, Barriers, Low Walls):
- **Effect**: -25% accuracy against unit in cover
- **Visual**: Icon shows half shield
- **Requirements**: Unit adjacent to cover

**No Cover** (Open Ground):
- **Effect**: +25% accuracy against exposed unit
- **Visual**: No icon
- **Risk**: High danger, should move to cover

### Cover Mechanics

**Taking Cover**:
- **Automatic**: When unit moves adjacent to cover object, automatically crouches
- **Manual**: Player can toggle crouch with `Ctrl` key
- **Breaking Cover**: Moving away or sprinting breaks cover

**Cover Direction**:
- Cover only protects from one side (the side facing the cover)
- Flanking (attacking from side/rear) ignores cover bonus

**Destructible Cover**:
- Some cover can be destroyed (crates, wooden barriers)
- Heavy fire or explosives damage cover
- Cover HP: 100-500 depending on type
- Destroyed cover becomes rubble (no protection)

### Flanking

**Flanking Bonus**:
- Attacking from **side** (90-180° from cover direction): Ignores 50% of cover
- Attacking from **rear** (180-270° from cover direction): Ignores 100% of cover + 15% accuracy bonus

**Tactical Implications**:
- Enemy in full cover from front = -50% accuracy
- Same enemy flanked = Full accuracy + 15% bonus
- Encourages squad positioning and coordination

---

## Line of Sight & Fog of War

### Line of Sight (LoS)

**LoS Check**:
- **Purpose**: Determine if unit can see target
- **Used For**: Shooting, abilities, detection
- **Algorithm**: Raycast from unit to target, check for obstructions

**Obstructions**:
- **Walls**: Block LoS completely
- **Cover**: Does not block LoS (can see and shoot over/around)
- **Smoke**: Blocks LoS for all units
- **Darkness**: Reduces LoS range (need night vision cyberware)

**LoS Range**:
- **Base**: 50 units (daytime, clear)
- **Modified By**: Weather, time of day, cyberware
- **Enhanced**: Optical cyberware extends to 75-100 units

### Fog of War

**Visibility Layers**:

**Fully Visible** (Green):
- Player squad has direct LoS
- Enemy positions shown
- Updated in real-time

**Recently Seen** (Gray):
- Last known position of enemies
- Fades after 10 seconds
- "?" icon shows uncertainty

**Unexplored** (Dark):
- Never visited by player
- Hidden until explored
- May contain surprises

**Fog of War Effects**:
- **Tactical Advantage**: Enemies can ambush from fog
- **Scouting**: Use scout drones or stealthy units to reveal areas
- **Memory**: Player must remember enemy positions when out of sight

---

## Damage Calculation

### Hit Chance Formula

```javascript
function calculateHitChance(attacker, target) {
  let baseAccuracy = 50; // Starting point

  // Attacker modifiers
  baseAccuracy += (attacker.reflexes * 2); // +2% per Reflexes
  baseAccuracy += attacker.weapon.accuracyBonus; // Weapon-specific
  baseAccuracy += attacker.skillBonus; // From skills/abilities

  // Target modifiers
  baseAccuracy -= target.dodgeChance; // Target's dodge
  baseAccuracy -= target.coverBonus; // Cover penalty (-25% or -50%)

  // Distance modifier
  const distance = getDistance(attacker, target);
  const optimalRange = attacker.weapon.optimalRange;
  if (distance > optimalRange) {
    const rangePenalty = (distance - optimalRange) * 0.5; // -0.5% per unit beyond optimal
    baseAccuracy -= rangePenalty;
  }

  // Clamp between 5% (min) and 95% (max)
  return Math.max(5, Math.min(95, baseAccuracy));
}
```

**Example Calculation**:
- Attacker: Reflexes 15, Assault Rifle (+5%), 40 units from target
- Target: In half cover (-25%), Dodge 10%
- Base: 50%
- Reflexes: +30%
- Weapon: +5%
- Cover: -25%
- Dodge: -10%
- Range: Optimal 50, current 40 = 0 penalty
- **Final: 50%**

### Damage Formula

```javascript
function calculateDamage(attacker, target, isCrit) {
  // Base weapon damage (random within range)
  let baseDamage = randomInt(attacker.weapon.minDamage, attacker.weapon.maxDamage);

  // Attacker modifiers
  baseDamage += attacker.damageBonus; // From skills/abilities
  baseDamage *= (1 + attacker.damageMult); // Percentage increases

  // Critical hit
  if (isCrit) {
    const critMult = 2.0 + (attacker.cool * 0.05); // Base 2x, +0.05x per Cool
    baseDamage *= critMult;
  }

  // Target armor reduction
  const armorReduction = target.armor * 0.5; // Each point of armor reduces 0.5 damage
  baseDamage -= armorReduction;

  // Minimum damage (always deal at least 1)
  baseDamage = Math.max(1, Math.floor(baseDamage));

  return {
    damage: baseDamage,
    isCrit: isCrit,
    armorBlocked: armorReduction
  };
}
```

**Example Calculation**:
- Attacker: Weapon (40-60 damage), roll 50
- Attacker bonuses: +10 flat, +25% mult
- Non-crit
- Target: 50 armor
- Damage: 50 + 10 = 60, × 1.25 = 75
- Armor: -25 reduction
- **Final: 50 damage**

### Damage Types

**Kinetic** (Physical):
- Most common (bullets, melee)
- Reduced by armor
- Deals full damage to health

**Energy** (Laser/Plasma):
- High-tech weapons
- Bypasses 50% of armor
- Slightly lower base damage

**EMP** (Electromagnetic):
- Only affects cyberware/electronics
- Disables instead of damaging
- No effect on unaugmented targets

**Chemical** (Toxin/Acid):
- Damage over time
- Ignores armor
- Continues for 5-10 seconds

---

## Status Effects

### Buffs (Positive)

**Stimmed**:
- Duration: 30 seconds
- Effect: +25% damage, +25% speed
- Source: Stimpack item, Medic ability

**Shielded**:
- Duration: 10 seconds or until damage absorbed
- Effect: +X temporary HP (absorbs damage first)
- Source: Tactical Shield ability

**Cloaked**:
- Duration: Until attacking or 10 seconds
- Effect: Invisible to enemies (cannot be targeted)
- Source: Sniper Cloak ability

**Inspired**:
- Duration: 60 seconds
- Effect: +10% all stats
- Source: Player leadership aura

### Debuffs (Negative)

**Stunned**:
- Duration: 3-5 seconds
- Effect: Cannot move, attack, or use abilities
- Source: System Shock, Flashbang

**Suppressed**:
- Duration: 6 seconds
- Effect: -50% accuracy, cannot leave cover without penalty
- Source: Suppressing Fire ability

**Bleeding**:
- Duration: 10 seconds or until healed
- Effect: -10 HP/second
- Source: Critical hits from bladed weapons

**Hacked**:
- Duration: 8-12 seconds
- Effect: Weapon/cyberware disabled
- Source: Netrunner abilities

**Burning**:
- Duration: 5 seconds
- Effect: -20 HP/second, panic (random movement)
- Source: Incendiary grenades, flamethrowers

### Status Effect Stacking

**Same Effect**:
- Duration refreshes (does not stack)
- Example: Stunned for 3s, get stunned again = 3s total (not 6s)

**Different Effects**:
- Multiple debuffs can apply simultaneously
- Example: Bleeding + Suppressed = Both effects active

**Status Resistance**:
- Some cyberware provides immunity (e.g., EMP shielding prevents Hacked)
- High Cool attribute reduces debuff duration by 10% per point above 15

---

## AI Behavior

### Behavior States

**Idle**:
- Patrol route or stand guard
- Low alertness
- Will investigate nearby noises

**Alert**:
- Heard gunfire or saw suspicious movement
- Search for threat
- Call nearby allies
- Transition to Combat if threat found

**Combat**:
- Engaged with player squad
- Execute combat tactics
- Attempt to eliminate or suppress enemies

**Retreat**:
- HP below 25% or squad outnumbered 3:1
- Fall back to defensive position
- Call reinforcements if available
- May flee map entirely if no backup

### Combat Tactics (AI)

**Aggressive** (Gang Enforcers, Brawlers):
- Push forward towards enemies
- Use abilities offensively
- Ignore cover (charge straight at player)
- Focus fire on weakest target

**Defensive** (Corporate Security):
- Take cover immediately
- Hold position, wait for player to approach
- Suppressing fire to keep player pinned
- Protect high-value targets (bosses, objectives)

**Tactical** (Elite Operatives):
- Coordinate flanking maneuvers
- Use cover effectively
- Prioritize high-threat targets (player, medic)
- Retreat if overwhelmed, regroup

**Support** (Enemy Netrunners, Medics):
- Stay at maximum range
- Use abilities to buff allies / debuff player
- Flee if approached by melee units
- Hide behind tanks

### Target Selection (AI)

**Priority System**:
1. **Highest Threat**: Unit dealing most damage
2. **Lowest HP**: Finish off wounded targets
3. **Closest**: If no other priority
4. **High-Value**: Player character, medics, netrunners

**Example AI Logic**:
```javascript
function selectTarget(aiUnit, enemies) {
  // Filter enemies in range and LoS
  const viableTargets = enemies.filter(e =>
    inRange(aiUnit, e) && hasLineOfSight(aiUnit, e)
  );

  // Prioritize
  let target = viableTargets.find(e => e.isPlayer); // Player first
  if (!target) target = viableTargets.find(e => e.hp < 50); // Wounded
  if (!target) target = viableTargets.find(e => e.class === 'Medic'); // High-value
  if (!target) target = viableTargets[0]; // Closest

  return target;
}
```

### Reinforcement System

**Trigger Conditions**:
- Combat lasts longer than 60 seconds
- AI unit reaches 25% HP and calls for help
- Player enters restricted zone without authorization

**Reinforcement Arrival**:
- Delay: 20-40 seconds after call
- Spawn: At map edges or designated spawn points
- Number: 2-4 units (scales with difficulty)
- Type: Matches faction and encounter level

---

## Combat Flow

### Encounter Start

**Trigger Events**:
1. **Player Initiates**: Player attacks enemy
2. **Detection**: Enemy spots player (failed stealth)
3. **Scripted**: Story mission trigger
4. **Ambush**: Player enters kill zone

**Encounter Start Sequence**:
1. Pause game (give player time to react)
2. Show "Combat Started" UI notification
3. Enemy positions revealed (if in LoS)
4. Music changes to combat track
5. Player can position squad before unpausing
6. Unpause: Combat begins in real-time

### During Combat

**Real-Time Execution**:
- Units execute orders continuously
- AP regenerates
- Cooldowns tick down
- Player can pause anytime to reassess

**Dynamic Events**:
- Reinforcements arrive
- Cover destroyed by explosions
- Fires spread (environmental hazards)
- Civilians flee (complications)

### Encounter End

**Victory Conditions**:
- All enemies eliminated
- All enemies retreated off map
- Objective completed (mission-specific)

**Defeat Conditions**:
- Player character downed (mission failure)
- All squad members downed
- Mission timer expired (timed missions)

**Post-Combat**:
1. Pause game (show results)
2. Display combat summary:
   - Enemies killed
   - XP gained
   - Loot collected
3. Heal squad (if medic available, partial healing)
4. Auto-save checkpoint
5. Resume exploration mode

---

## Technical Implementation

### Module Integration

**CombatSystem.psm1** (PowerShell Backend):
- Encounter initialization
- Damage calculation
- Status effect tracking
- AI behavior state machine
- Victory/defeat condition checking
- Loot distribution
- XP rewards

**combatUI.js** (JavaScript Frontend):
- Real-time rendering on Leaflet map
- Unit position updates (every 100ms)
- Health bars, AP bars, cooldown timers
- Ability buttons and tooltips
- Pause/unpause controls
- Combat log

**EventSystem Integration**:
```javascript
// Backend emits events
Publish-GameEvent -EventType "combat.started" -Data @{ EnemyCount = 5 }
Publish-GameEvent -EventType "combat.damageDealt" -Data @{ AttackerId, TargetId, Damage }
Publish-GameEvent -EventType "combat.unitDowned" -Data @{ UnitId }
Publish-GameEvent -EventType "combat.ended" -Data @{ Victory, XP, Loot }

// Frontend subscribes
eventSystem.on('combat.started', (data) => {
  combatUI.initialize(data.EnemyCount);
});
eventSystem.on('combat.damageDealt', (data) => {
  combatUI.showDamageNumber(data.TargetId, data.Damage);
});
```

### Performance Optimization

**Update Rates**:
- **Position Updates**: 10 Hz (every 100ms) - smooth enough for real-time
- **Combat Calculations**: On-demand (when attack/ability fires)
- **UI Updates**: 30 Hz (every 33ms) - smooth animations
- **AI Decisions**: 2 Hz (every 500ms) - frequent enough for reactive AI

**Optimization Strategies**:
- **Spatial Hashing**: Only check collisions with nearby units
- **LoS Caching**: Cache LoS checks for 500ms (recalculate only on movement)
- **Event Batching**: Group multiple small events into single update
- **Limit Active Units**: Max 20 units in combat simultaneously

### Pathfinding Performance

**A* Grid Size**:
- Combat area: 100×100 units
- Grid resolution: 1 unit per cell = 10,000 cells
- Optimization: Only recalculate path if target moves >5 units

**OSRM Routing**:
- Cache routes for common paths (safe house ↔ mission sites)
- Rate limit: Max 1 request per second
- Fallback: Use straight line if API fails

---

## Instructions for Implementation

### Phase 1: Core Combat (Weeks 1-2)
1. **Real-time loop**: Units move and attack in real-time
2. **Pause system**: Spacebar pauses/unpauses
3. **Basic attack**: Click to attack, auto-target nearest enemy
4. **HP tracking**: Damage reduces HP, 0 HP = downed
5. **Victory/defeat**: All enemies dead = win, player dead = lose

### Phase 2: Tactical Depth (Weeks 3-4)
6. **Cover system**: Take cover, -25%/-50% accuracy penalty for attackers
7. **Flanking**: Attacking from rear ignores cover
8. **AP system**: Abilities cost AP, regenerates over time
9. **Cooldowns**: Abilities have cooldown timers
10. **Status effects**: Implement stun, bleed, buff/debuff

### Phase 3: Squad & AI (Weeks 5-6)
11. **Squad control**: Issue orders to multiple units
12. **Order queue**: Queue actions while paused
13. **AI behavior**: Idle → Alert → Combat → Retreat states
14. **AI tactics**: Use cover, focus fire, call reinforcements
15. **Pathfinding**: A* for combat movement

### Phase 4: Polish & Balance (Week 7+)
16. **UI**: Health bars, ability icons, combat log
17. **Animations**: Muzzle flash, hit effects, explosions
18. **Sound**: Gunshots, abilities, damage feedback
19. **Balance**: Tune damage, HP, AP costs, cooldowns
20. **Integration**: Connect to existing systems (StateManager, EventSystem)

---

## Changelog

### Version 0.1.0 (2025-11-14)
- Initial combat design specification
- Defined real-time with pause mechanics
- Created damage calculation formulas
- Established AI behavior framework
- Integrated pathfinding options (OSRM + A*)
