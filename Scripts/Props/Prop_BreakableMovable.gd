class_name Prop_BreakableMovable
extends RigidBody2D

## Destructible movable obstacle. Physics layer 6 (Props).
## Godot physics engine handles movement — no Mover needed.
## Hurtbox lets Hitbox system find Health → AttackImpactResolver applies
## damage and impulse automatically. Mover collision push also works via RigidBody2D path.

signal prop_destroyed(source: Node)
signal prop_hit(damage: float, source: Node)
signal prop_moved(velocity: Vector2)

## Fraction of velocity remaining after 1 second (0 = stops instantly, 1 = no friction).
@export_range(0.0, 1.0, 0.01) var drag: float = 0.08

@onready var _health: Health = $Health

func _ready() -> void:
	add_to_group(&"prop")
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)

func apply_theme_spritesheet(spritesheet: Texture2D) -> void:
	($Sprite2D as Sprite2D).texture = spritesheet

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.linear_velocity *= pow(drag, state.step)
	if not state.linear_velocity.is_zero_approx():
		prop_moved.emit(state.linear_velocity)
		_notify_effects_moved(state.linear_velocity)

func receive_projectile_impulse(direction: Vector2, force: float) -> void:
	apply_central_impulse(direction.normalized() * force * mass)

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

func _notify_effects_moved(vel: Vector2) -> void:
	for child in get_children():
		if child is PropEffect:
			child.on_moved(vel)
