extends Resource
class_name AnimSet

@export var library_name := "" # optional AnimationLibrary name, e.g. "obj_player"

# Locomotion keys (base, without direction)
@export var idle_key := "idle"
@export var walk_key := "walk"

# Action keys: "attack", "hurt", "die", "interact", etc.
@export var actions: Dictionary = {
	"attack": "attack",
	"hurt": "hurt"
}

# If true, driver will append _up/_down/_left/_right
@export var directional := true

# Animation name pattern options
@export var idle_prefix := "idle_"
@export var walk_prefix := "walking_"

# For action animations, you can also choose directional naming or not
@export var action_prefix := ""  # e.g. "" or "act_"
@export var actions_are_directional := true
