# TODO — Pickup System Wiring (do in Godot editor)

## 1. Add PlayerRunData to player entity
- Open `Scenes/Templates/Entities/Player_Entity_Template.tscn`
- Add child node → attach script `Scripts/Components/Player/PlayerRunData.gd`

## 2. Verify GameManager autoload
- Project → Project Settings → Autoloads
- Confirm `GameManager` entry points to `res://Scripts/GameManager.gd`
- If missing, add it manually

## 3. Create AutoPickup scene
- New scene, root = `Area2D`, name it `AutoPickup`
- Add `CollisionShape2D` (CircleShape2D, radius ~16px)
- Add `Sprite2D` (placeholder or art)
- Attach script `Scripts/World/Pickups/AutoPickup.gd`
- Collision layer: **none** | Collision mask: **layer 2 (Player)**
- Save as `Scenes/Props/WorldProps/AutoPickup.tscn`

## 4. Create StatUpPickup scene
- New scene, root = `Area2D`, name it `StatUpPickup`
- Add `CollisionShape2D` (CircleShape2D, radius ~24px)
- Add `Sprite2D` (placeholder or art)
- Attach script `Scripts/World/Pickups/StatUpPickup.gd`
- Collision layer: **same layer as EquipmentSwapPickup** (check existing pickup scene)
- Collision mask: **none**
- Save as `Scenes/Props/WorldProps/StatUpPickup.tscn`

## 5. Create pickup .tres resources
- Directory: `Resources/Items/Pickups/`
- Create `HealthPickupDef` instances:
  - `Health_Small.tres` — FLAT, value = 25
  - `Health_Large.tres` — FLAT, value = 60
  - `Health_Percent.tres` — PERCENT, value = 25
- Create `CurrencyPickupDef` instances:
  - `Coin_Small.tres` — amount = 5
  - `Coin_Large.tres` — amount = 25
- Create example `StatUpDef`:
  - `StatUp_HeavyArmor.tres` — add two `StatModEntry`:
    - FLAT_DAMAGE_REDUCTION, value = 3.0, label = "+3 Armor"
    - MOVE_SPEED_MULT, value = 0.85, label = "-15% Move Speed"
