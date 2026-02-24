extends Shield
class_name TestShield

@export var label: String = "TestShield"

func _ready() -> void:
	# Keep the label for debugging / identifying in HUD.
	super._ready()
