extends Resource
class_name ItemStats

# --- Combat stats ---
@export var damage: float = 0.0
@export var cooldown_sec: float = 0.0
@export var windup_time: float = 0.0
@export var recovery_time: float = 0.0

# --- Ranged stats ---
@export var is_automatic: bool = false
@export var projectile_count: int = 1
@export var pierce: int = 0
@export var spread_degrees: float = 0.0
@export var spread_pattern_degrees: float = 0.0
@export var muzzle_offset: Vector2 = Vector2.ZERO

# --- Movement / defense ---
@export var move_speed_mult: float = 1.0
@export var damage_taken_mult: float = 1.0
@export var flat_damage_reduction: float = 0.0

# --- Health effects ---
@export var bonus_max_hp: float = 0.0
@export var heal_on_equip: float = 0.0

# --- Melee / hitbox-oriented ---
@export var active_time: float = 0.0
@export var knockback: float = 0.0
@export var hitbox_offset: Vector2 = Vector2.ZERO
@export var hitbox_size: Vector2 = Vector2.ZERO


func duplicate_typed() -> ItemStats:
	return duplicate(true) as ItemStats


func apply_additive(other: ItemStats) -> void:
	if other == null:
		return

	damage += other.damage
	cooldown_sec += other.cooldown_sec
	windup_time += other.windup_time
	recovery_time += other.recovery_time

	is_automatic = is_automatic or other.is_automatic
	projectile_count += other.projectile_count
	pierce += other.pierce
	spread_degrees += other.spread_degrees
	spread_pattern_degrees += other.spread_pattern_degrees
	muzzle_offset += other.muzzle_offset

	flat_damage_reduction += other.flat_damage_reduction
	bonus_max_hp += other.bonus_max_hp
	heal_on_equip += other.heal_on_equip

	active_time += other.active_time
	knockback += other.knockback
	hitbox_offset += other.hitbox_offset
	hitbox_size += other.hitbox_size

	move_speed_mult *= other.move_speed_mult
	damage_taken_mult *= other.damage_taken_mult


static func add(a: ItemStats, b: ItemStats) -> ItemStats:
	var out := ItemStats.new()
	if a != null:
		out.apply_additive(a)
	if b != null:
		out.apply_additive(b)
	return out


static func mul(a: ItemStats, scalar: float) -> ItemStats:
	var out := ItemStats.new()
	if a == null:
		return out

	out.damage = a.damage * scalar
	out.cooldown_sec = a.cooldown_sec * scalar
	out.windup_time = a.windup_time * scalar
	out.recovery_time = a.recovery_time * scalar

	out.is_automatic = a.is_automatic
	out.projectile_count = int(round(float(a.projectile_count) * scalar))
	out.pierce = int(round(float(a.pierce) * scalar))
	out.spread_degrees = a.spread_degrees * scalar
	out.spread_pattern_degrees = a.spread_pattern_degrees * scalar
	out.muzzle_offset = a.muzzle_offset * scalar

	out.flat_damage_reduction = a.flat_damage_reduction * scalar
	out.bonus_max_hp = a.bonus_max_hp * scalar
	out.heal_on_equip = a.heal_on_equip * scalar

	out.active_time = a.active_time * scalar
	out.knockback = a.knockback * scalar
	out.hitbox_offset = a.hitbox_offset * scalar
	out.hitbox_size = a.hitbox_size * scalar

	out.move_speed_mult = a.move_speed_mult
	out.damage_taken_mult = a.damage_taken_mult

	return out
