class_name PropEffect
extends Node

## Base class for prop behaviors. Add as child of any prop scene.
## Override the relevant methods; unused ones are safe no-ops.

func on_hit(_damage: float, _source: Node) -> void:
	pass

func on_destroyed(_source: Node) -> void:
	pass

func on_moved(_new_velocity: Vector2) -> void:
	pass
