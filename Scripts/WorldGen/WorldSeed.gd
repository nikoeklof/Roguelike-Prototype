extends Node

## Autoload: single source of truth for the current run's seed.
## Register as autoload named "WorldSeed" in Project Settings.

signal seed_changed(new_seed: int)

@export var default_seed: int = 12345
@export var randomize_on_start: bool = true
@export var print_to_console: bool = true

var current_seed: int = 0


func _ready() -> void:
	if randomize_on_start:
		randomize_seed()
	else:
		set_seed(default_seed)


func set_seed(new_seed: int) -> void:
	current_seed = new_seed
	if print_to_console:
		print("[WorldSeed] Seed set: %d" % current_seed)
	seed_changed.emit(current_seed)


func randomize_seed() -> void:
	var unix_time: int = int(Time.get_unix_time_from_system())
	var frames: int = int(Engine.get_frames_drawn())
	set_seed(unix_time ^ frames)


## Derive a sub-seed from the world seed + any number of string keys.
## Use this everywhere you need deterministic randomness tied to the run.
## Example: WorldSeed.derive("enemy", "loadout", str(entity.get_path()))
func derive(key_a: String, key_b: String = "", key_c: String = "") -> int:
	var h: int = 2166136261
	h = _fnv_mix(h, current_seed)
	h = _fnv_mix(h, key_a.hash())
	if key_b != "":
		h = _fnv_mix(h, key_b.hash())
	if key_c != "":
		h = _fnv_mix(h, key_c.hash())
	return h


func _fnv_mix(h: int, value: int) -> int:
	return int((h ^ value) * 16777619) & 0x7fffffff
