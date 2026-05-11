class_name Prop_Movable
extends RigidBody2D

## Movable obstacle. Physics layer 6 (Props).
## Does NOT block LoS (AILineOfSight only checks layer 1).
## Godot physics engine handles movement — no Mover needed.
## Pushed by player/enemies via Mover collision detection.
## Pushed by melee hitboxes via HitReceiver (no Health = Hitbox skips it otherwise).
## Pushed by projectiles via receive_projectile_impulse() in PlaceholderProjectile.

signal prop_moved(velocity: Vector2)

## Fraction of velocity remaining after 1 second (0 = stops instantly, 1 = no friction).
@export_range(0.0, 1.0, 0.01) var drag: float = 0.08

@onready var _hit_receiver: Area2D = $HitReceiver

func _ready() -> void:
	add_to_group(&"prop")
	z_as_relative = false
	z_index = int(global_position.y)
	_hit_receiver.area_entered.connect(_on_hit_receiver_area_entered)


func _process(_delta: float) -> void:
	z_index = int(global_position.y)

func apply_theme_spritesheet(spritesheet: Texture2D) -> void:
	($Sprite2D as Sprite2D).texture = spritesheet

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.linear_velocity *= pow(drag, state.step)
	if not state.linear_velocity.is_zero_approx():
		prop_moved.emit(state.linear_velocity)
		_notify_effects_moved(state.linear_velocity)

func receive_projectile_impulse(direction: Vector2, force: float) -> void:
	apply_central_impulse(direction.normalized() * force * mass)

func _on_hit_receiver_area_entered(area: Area2D) -> void:
	if not (area is Hitbox):
		return
	var dir := (global_position - area.global_position).normalized()
	if dir.is_zero_approx():
		dir = Vector2.RIGHT
	apply_central_impulse(dir * area.damage * mass)

func _notify_effects_moved(vel: Vector2) -> void:
	for child in get_children():
		if child is PropEffect:
			child.on_moved(vel)
