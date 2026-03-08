extends RefCounted
class_name AttackSnapshot

var context: CombatContext
var item_instance: ItemInstance
var stats: ItemStats

var damage: float = 0.0
var cooldown_sec: float = 0.0
var windup_time: float = 0.0
var active_time: float = 0.0
var recovery_time: float = 0.0
var knockback: float = 0.0

var hitbox_offset: Vector2 = Vector2.ZERO
var hitbox_size: Vector2 = Vector2.ZERO

var projectile_count: int = 1
var pierce: int = 0
var ranged_mode: int = 0
