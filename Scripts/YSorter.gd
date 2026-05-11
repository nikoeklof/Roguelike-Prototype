extends Node
class_name YSorter

## Drop as child of any Node2D (entity, prop, pickup, projectile).
## Sets z_as_relative=false on parent and tracks global_position.y as z_index.
## Works across any scene tree hierarchy.

func _ready() -> void:
	var p := get_parent() as Node2D
	if p:
		p.z_as_relative = false

func _process(_delta: float) -> void:
	var p := get_parent() as Node2D
	if p:
		# Scale by 0.25 so the full multi-room floor fits in z_index range [-4096,4095].
		# Tiles are pinned at z=-4096; entities stay above them across all room coordinates.
		p.z_index = clampi(int(p.global_position.y * 0.25), -4096, 4095)
