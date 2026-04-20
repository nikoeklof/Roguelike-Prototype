extends Resource
class_name RangedItemStats

@export_group("Attack")
@export var damage: float = 10.0
@export_range(0.05, 10.0, 0.05) var cooldown_sec: float = 0.5
@export_range(0.0, 2.0, 0.01) var windup_time: float = 0.0
@export_range(0.0, 2.0, 0.01) var recovery_time: float = 0.10
@export var is_automatic: bool = false
@export_range(0.1, 2.0, 0.01) var move_speed_mult: float = 1.0

@export_group("Projectile Stats")
@export_range(1, 20, 1) var projectile_count: int = 1
@export_range(0, 10, 1) var pierce: int = 0
@export_range(0.0, 60.0, 0.5) var spread_degrees: float = 0.0
@export_range(0.0, 60.0, 0.5) var spread_pattern_degrees: float = 0.0
@export var muzzle_offset: Vector2 = Vector2.ZERO
@export var knockback: float = 0.0

@export_group("Fire Mode")
@export var default_mode: RangedShotData.ShotMode = RangedShotData.ShotMode.PROJECTILE

@export_group("Projectile Delivery")
@export var projectile_scene: PackedScene = preload("res://Scenes/Templates/EquipmentItems/Projectile_template.tscn")
@export_range(10.0, 5000.0, 10.0) var projectile_speed: float = 450.0
@export_range(-500.0, 500.0, 1.0) var projectile_gravity: float = 0.0
@export_range(0.05, 30.0, 0.05) var projectile_lifetime_sec: float = 2.0
@export_range(1.0, 64.0, 0.5) var projectile_radius: float = 6.0
@export_range(0.0, 1.0, 0.01) var inherit_owner_velocity: float = 0.0
@export_range(0.0, 5000.0, 10.0) var projectile_range: float = 0.0
@export var projectile_collision_mask: int = 0x7FFFFFFF
@export var projectile_sprite_texture: Texture2D
@export var projectile_sprite_tint: Color = Color.WHITE

@export_group("Hitscan")
@export_range(50.0, 5000.0, 10.0) var hitscan_range: float = 900.0

@export_group("Beam")
@export_range(50.0, 5000.0, 10.0) var beam_range: float = 900.0
@export_range(0.05, 5.0, 0.01) var beam_duration_sec: float = 0.35
@export_range(0.02, 1.0, 0.01) var beam_tick_sec: float = 0.10
