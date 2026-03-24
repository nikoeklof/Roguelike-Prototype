extends Node
class_name EntityVisualController

@export_node_path("CanvasItem") var sprite_path: NodePath
@export var default_tint: Color = Color.WHITE

var sprite: CanvasItem
var _hurt_tween: Tween


func _ready() -> void:
	_ensure_shader_material()
	
	# Initialize shader parameters
	set_base_tint(default_tint)
	set_freeze_amount(0.0)
	set_poison_amount(0.0)
	set_burn_amount(0.0)
	set_shield_amount(0.0)
	set_debuff_intensity(0.0)

	if sprite == null:
		print("[EntityVisualController] Warning: sprite not found at path %s" % sprite_path)
		return

	var health: Health = get_parent().get_node_or_null("Health") as Health
	if health and health.has_signal("damaged"):
		health.damaged.connect(_on_damaged)


func _ensure_shader_material() -> void:
	# Resolve sprite path
	if sprite_path != NodePath():
		sprite = get_node_or_null(sprite_path) as CanvasItem
	
	# If no path set or path failed, try auto-finding
	if sprite == null:
		var visual: Node = get_parent().get_node_or_null("Visual")
		if visual != null:
			# Try common sprite names
			sprite = visual.get_node_or_null("Sprite") as CanvasItem
			if sprite == null:
				sprite = visual.get_node_or_null("AnimatedSprite2D") as CanvasItem
		
		# Fallback: search all children for first CanvasItem
		if sprite == null:
			for child in get_parent().get_children():
				if child is CanvasItem:
					sprite = child
					break
	
	if sprite == null:
		print("[EntityVisualController] ERROR: Could not find sprite!")
		return

	if sprite.material is ShaderMaterial:
		print("[EntityVisualController] ✓ Found ShaderMaterial on sprite: %s" % sprite.name)
		return

	print("[EntityVisualController] Warning: sprite %s has no ShaderMaterial assigned at %s" % [sprite.name, sprite.get_path()])


func _get_shader_material() -> ShaderMaterial:
	if sprite == null:
		_ensure_shader_material()
	
	if sprite == null:
		return null
	
	var mat = sprite.material as ShaderMaterial
	if mat == null:
		print("[EntityVisualController] ERROR: Sprite material is not ShaderMaterial!")
	return mat


func _on_damaged(_amount: float, _source: Node) -> void:
	trigger_hurt_flash()


func trigger_hurt_flash() -> void:
	var mat := _get_shader_material()
	if mat == null:
		print("[EntityVisualController] ERROR in trigger_hurt_flash: mat is null")
		return

	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()

	mat.set_shader_parameter("hurt_flash", 1.0)

	_hurt_tween = create_tween()
	_hurt_tween.tween_method(_set_hurt_flash_from_tween, 1.0, 0.0, 0.2)


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


func set_debuff_intensity(value: float) -> void:
	"""Set the overall debuff intensity (enables debuff shader effects)"""
	var mat := _get_shader_material()
	if mat == null:
		return
	print("[EntityVisualController] Setting debuff_intensity to: %f" % value)
	mat.set_shader_parameter("debuff_intensity", clampf(value, 0.0, 1.0))


func set_freeze_amount(value: float) -> void:
	var mat := _get_shader_material()
	if mat == null:
		return
	print("[EntityVisualController] Setting freeze_amount to: %f" % value)
	mat.set_shader_parameter("freeze_amount", clampf(value, 0.0, 1.0))


func set_poison_amount(value: float) -> void:
	var mat := _get_shader_material()
	if mat == null:
		return
	print("[EntityVisualController] Setting poison_amount to: %f" % value)
	mat.set_shader_parameter("poison_amount", clampf(value, 0.0, 1.0))


func set_burn_amount(value: float) -> void:
	var mat := _get_shader_material()
	if mat == null:
		return
	print("[EntityVisualController] Setting burn_amount to: %f" % value)
	mat.set_shader_parameter("burn_amount", clampf(value, 0.0, 1.0))


func set_shield_amount(value: float) -> void:
	var mat := _get_shader_material()
	if mat == null:
		return
	print("[EntityVisualController] Setting shield_amount to: %f" % value)
	mat.set_shader_parameter("shield_amount", clampf(value, 0.0, 1.0))
