# Modular Top‑Down Action Game — Technical Design Document (Godot 4.x)

---

## Project Goal

Create a fully modular, reusable entity architecture where player and enemies share the exact same systems:

* No special‑case player code
* Items exist as real scene nodes (not data blobs)
* Combat is equipment‑driven
* States never control physics
* Animation never controls gameplay

The project prioritizes **architecture stability over content speed**.

---

## Core Principles

### 1) Entity Is Only an Orchestrator

The root entity does not contain gameplay rules.
It only wires components together.

Entity responsibilities:

* Initialize components
* Route events
* Provide component lookup

It does NOT:

* Move the character
* Perform attacks
* Apply damage
* Decide animation

---

### 2) Components Own Behavior

All gameplay logic lives in components:

| System               | Owned By                    |
| -------------------- | --------------------------- |
| Movement physics     | Mover                       |
| Health rules         | Health                      |
| Damage modifiers     | Stats                       |
| Facing visuals       | FacingPointer               |
| Aim direction        | AimRay                      |
| Combat execution     | Combat                      |
| Equipment management | Equipment                   |
| Input/AI             | ControlSource               |
| Logic flow           | FSM (StateHandler + States) |

---

### 3) Items Are Real Scene Nodes

Items are instanced Nodes that:

* can exist in world
* can be equipped
* can be dropped
* can act independently

No duplicated logic between ground and equipped forms.

---

### 4) Physics Authority Rule

Only one system controls velocity:

> Mover is the sole owner of movement physics.

States request permissions via Capabilities, never directly modify velocity.

---

### 5) Aim Separation Rule

| System        | Purpose                      |
| ------------- | ---------------------------- |
| AimRay        | Gameplay targeting direction |
| FacingPointer | Animation direction          |

Gameplay never depends on animation facing.

---

## Entity Architecture

```
CharacterBody2D (Entity)
 ├─ Mover
 ├─ Stats
 ├─ Health
 ├─ FacingPointer
 ├─ AimRay
 ├─ AnimDriver
 ├─ ControlSource
 ├─ Combat
 ├─ Equipment
 ├─ Capabilities
 ├─ Faction/Tags
 └─ StateHandler
```

---

## Finite State Machine

### Core Flow

```
Locomotion
   ↓ attack input
AttackState
   ↓
Combat.try_attack()
   ↓ wait signal
Locomotion
```

States do NOT:

* move entity
* apply forces
* change velocity

States only:

* lock capabilities
* choose actions

---

## Movement System

Movement is permission‑based.

| Capability | Effect                            |
| ---------- | --------------------------------- |
| CAN_MOVE   | Player input acceleration allowed |
| BLOCKED    | Input ignored                     |
| ALWAYS     | Friction still applies            |
| NEVER      | Velocity not zeroed               |

This enables momentum‑preserving attacks.

---

## Combat System

Combat acts as executor only.

```
State → Combat → Equipped Item → Action
```

Combat never knows weapon type details.
Weapons never know FSM state.

---

## Equipment System

Equipment holds slot nodes:

```
Equipment
 ├─ MeleeSlot
 ├─ RangedSlot
 ├─ SpellSlot
 └─ ShieldSlot
```

Slots validate items before equipping.

### Slot Validation Rules

| Slot   | Accepts         |
| ------ | --------------- |
| MELEE  | Weapon (melee)  |
| RANGED | Weapon (ranged) |
| SPELL  | Spell           |
| SHIELD | Shield          |

Invalid swaps are rejected safely.

---

## Item Architecture

### Weapon

Provides:

* try_attack(direction, owner)
* allow_move_during_attack
* pickup_slot_kind

### Spell

Provides:

* try_cast(owner, direction)
* allow_move_during_cast

### Shield

Applies passive stat modifiers on equip.

---

## Interaction System

Interactor Area detects nearby interactables.

```
Player
 └─ InteractionArea (Interactor)
```

Flow:

```
Input → Interactor → interactable.interact(entity)
```

Interactables include:

* pickups
* doors
* NPCs
* future UI prompts

---

## Pickup System

GroundItemPickup contains an actual item node internally.

Swap algorithm:

```
player presses interact
→ pickup determines slot
→ equipment.swap_item_in_slot()
→ old item becomes new pickup
```

Visuals are inherited automatically from the item sprite.

---

## Combat Movement Policy

Movement permissions come from the item, not the state.

| Item Property            | Effect           |
| ------------------------ | ---------------- |
| allow_move_during_attack | Steering allowed |
| false                    | momentum only    |

---

## Current Working Features

* Equipment swapping
* Shared player/enemy combat
* Melee hitboxes
* Projectile weapons
* Spell casting
* Shields applying stats
* Momentum‑preserving attacks
* Interaction system
* Initial loadouts

---

## Planned Systems

### Combat Expansion

* Attack variants (light/heavy/charged)
* Combos
* Stagger / interrupt
* AI combat behavior

### Player Systems

* UI prompts
* Inventory UI
* Equipment screen

### World Systems

* Doors
* NPC dialogue
* Chests

---

## Architectural Rules (Strict)

1. States never control physics
2. Weapons never talk to FSM
3. Animation never drives gameplay
4. AimRay is gameplay authority
5. FacingPointer is visual only
6. Items are nodes, not resources
7. Entity contains no gameplay logic

---

## Long‑Term Scalability Goal

This architecture should support:

* hundreds of enemies
* procedural weapons
* deterministic simulation

without rewriting core systems.

