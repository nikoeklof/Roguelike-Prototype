class_name Prop_Static
extends StaticBody2D

## Inert obstacle. Physics layer 1 (World) — blocks LoS, movement, and projectiles.
## No health, no movement. Add PropEffect children for special destroy behaviors
## triggered externally via trigger_destroy().

signal prop_destroyed()

func _ready() -> void:
	add_to_group(&"prop")
	z_as_relative = false
	z_index = int(global_position.y)

func apply_theme_spritesheet(spritesheet: Texture2D) -> void:
	($Sprite2D as Sprite2D).texture = spritesheet

func trigger_destroy(source: Node = null) -> void:
	_notify_effects_destroyed(source)
	prop_destroyed.emit()
	queue_free()

func _notify_effects_destroyed(source: Node) -> void:
	for child in get_children():
		if child is PropEffect:
			child.on_destroyed(source)
