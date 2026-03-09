extends Resource
class_name ProjectileSpec

@export var scene: PackedScene = preload("res://Scenes/Templates/EquipmentItems/Projectile_template.tscn")

@export_range(0.0, 5000.0, 1.0) var speed: float = 450.0
@export_range(-5000.0, 5000.0, 1.0) var gravity: float = 0.0
@export_range(0.05, 30.0, 0.05) var lifetime_sec: float = 2.0
@export_range(1.0, 256.0, 1.0) var radius: float = 6.0

@export_range(0.0, 1.0, 0.01) var inherit_owner_velocity: float = 0.0
@export_range(0.0, 5000.0, 1.0) var range: float = 0.0

@export var collision_mask: int = 0x7FFFFFFF

@export var sprite_texture: Texture2D
@export var sprite_tint: Color = Color.WHITE
