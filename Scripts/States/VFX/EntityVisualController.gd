extends Node
class_name EntityVisualController

@export var sprite_path: NodePath = ^"../Visual/AnimatedSprite2D"
@export var health_path: NodePath = ^"../Health"

@export var duplicate_material_on_ready: bool = true

@export var default_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var hurt_flash_duration: float = 0.08

var _hurt_tween: Tween

@onready var sprite: CanvasItem = get_node_or_null(sprite_path)
@onready var health: Node = get_node_or_null(health_path)

func _ready() -> void:
	if sprite == null:
		push_warning("EntityVisualController: sprite not found at path %s" % sprite_path)
		return

	if duplicate_material_on_ready and sprite.material:
		sprite.material = sprite.material.duplicate()

	_ensure_shader_material()
	set_base_tint(default_tint)
	set_hurt_flash(0.0)
	set_freeze_amount(0.0)
	set_poison_amount(0.0)
	set_burn_amount(0.0)
	set_shield_amount(0.0)

	if health and health.has_signal("damaged"):
		health.damaged.connect(_on_damaged)

func _ensure_shader_material() -> void:
	if sprite == null:
		return

	if sprite.material is ShaderMaterial:
		return

	push_warning("EntityVisualController: sprite has no ShaderMaterial assigned.")

func _get_shader_material() -> ShaderMaterial:
	if sprite == null:
		return null
	return sprite.material as ShaderMaterial

func _on_damaged(_amount: float, _source: Node) -> void:
	trigger_hurt_flash()

func trigger_hurt_flash() -> void:
	var mat := _get_shader_material()
	if mat == null:
		return

	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()

	mat.set_shader_parameter("hurt_flash", 1.0)

	_hurt_tween = create_tween()
	_hurt_tween.tween_method(_set_hurt_flash_from_tween, 1.0, 0.0, hurt_flash_duration)

func _set_hurt_flash_from_tween(value: float) -> void:
	set_hurt_flash(value)

func set_base_tint(color: Color) -> void:
	var mat := _get_shader_material()
	if mat == null:
		return
	mat.set_shader_parameter("base_tint", color)

func set_hurt_flash(value: float) -> void:
	var mat := _get_shader_material()
	if mat == null:
		return
	mat.set_shader_parameter("hurt_flash", clampf(value, 0.0, 1.0))

func set_freeze_amount(value: float) -> void:
	var mat := _get_shader_material()
	if mat == null:
		return
	mat.set_shader_parameter("freeze_amount", clampf(value, 0.0, 1.0))

func set_poison_amount(value: float) -> void:
	var mat := _get_shader_material()
	if mat == null:
		return
	mat.set_shader_parameter("poison_amount", clampf(value, 0.0, 1.0))

func set_burn_amount(value: float) -> void:
	var mat := _get_shader_material()
	if mat == null:
		return
	mat.set_shader_parameter("burn_amount", clampf(value, 0.0, 1.0))

func set_shield_amount(value: float) -> void:
	var mat := _get_shader_material()
	if mat == null:
		return
	mat.set_shader_parameter("shield_amount", clampf(value, 0.0, 1.0))
