extends ItemDef
class_name SpellItemDef

enum SpellType { BUFF, DEBUFF }

enum DeliveryMode { PROJECTILE, AOE }

@export var stats: SpellItemStats

@export_group("Spell Config")
@export var spell_type: SpellType = SpellType.BUFF
@export var delivery_mode: DeliveryMode = DeliveryMode.PROJECTILE

@export_group("Projectile")
@export var projectile_scene: PackedScene = preload("res://Scenes/Templates/EquipmentItems/Projectile_template.tscn")
@export_range(0.0, 5000.0, 1.0) var projectile_speed: float = 450.0
@export_range(-5000.0, 5000.0, 1.0) var projectile_gravity: float = 0.0
@export_range(0.05, 30.0, 0.05) var projectile_lifetime_sec: float = 2.0
@export_range(1.0, 256.0, 1.0) var projectile_radius: float = 6.0
@export_range(0.0, 1.0, 0.01) var inherit_owner_velocity: float = 0.0
@export_range(0.0, 5000.0, 1.0) var projectile_range: float = 0.0
@export var projectile_collision_mask: int = 0x7FFFFFFF
@export var projectile_sprite_texture: Texture2D
@export var projectile_sprite_tint: Color = Color.WHITE

@export_group("AOE")
@export_range(50.0, 500.0, 10.0) var aoe_radius: float = 150.0
@export var aoe_instant: bool = true
@export_range(0.1, 5.0, 0.1) var aoe_travel_time: float = 0.5

func _init() -> void:
	category = Category.SPELL

func _validate_property(property: Dictionary) -> void:
	if property["name"] == "base_stats":
		property["usage"] = PROPERTY_USAGE_NONE


func get_projectile_config() -> Dictionary:
	return {
		"speed": projectile_speed,
		"gravity": projectile_gravity,
		"lifetime": projectile_lifetime_sec,
		"radius": projectile_radius,
		"inherit_velocity": inherit_owner_velocity,
		"range": projectile_range,
		"collision_mask": projectile_collision_mask,
		"texture": projectile_sprite_texture,
		"tint": projectile_sprite_tint,
		"scene": projectile_scene
	}


func get_aoe_config() -> Dictionary:
	return {
		"radius": aoe_radius,
		"instant": aoe_instant,
		"travel_time": aoe_travel_time
	}
