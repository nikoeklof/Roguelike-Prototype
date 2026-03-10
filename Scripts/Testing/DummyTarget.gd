extends CharacterBody2D

@export var reset_on_death := true
@export var respawn_delay_sec := 0.0
@export var stay_invulnerable := false

@onready var health = $Health

func _ready():
	if stay_invulnerable:
		health.max_hp = 999999
		health.hp = health.max_hp

	if health.has_signal("died"):
		health.died.connect(_on_died)


func _on_died():
	if not reset_on_death:
		return

	await get_tree().create_timer(respawn_delay_sec).timeout

	health.hp = health.max_hp
