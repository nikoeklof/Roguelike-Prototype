class_name Prop_Breakable
extends StaticBody2D

## Destructible static obstacle. Physics layer 1 (World) — blocks LoS and movement.
## Requires child nodes: Health, Hurtbox (Area2D on layer 5).
## PropEffect children are notified on hit and destroy.

signal prop_destroyed(source: Node)
signal prop_hit(damage: float, source: Node)

@onready var _health: Health = $Health

func _ready() -> void:
	add_to_group(&"prop")
	z_as_relative = false
	z_index = int(global_position.y)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)

func apply_theme_spritesheet(spritesheet: Texture2D) -> void:
	($Sprite2D as Sprite2D).texture = spritesheet

func _on_damaged(amount: float, source: Node) -> void:
	prop_hit.emit(amount, source)
	for child in get_children():
		if child is PropEffect:
			child.on_hit(amount, source)

func _on_died() -> void:
	prop_destroyed.emit(null)
	for child in get_children():
		if child is PropEffect:
			child.on_destroyed(null)
	queue_free()
