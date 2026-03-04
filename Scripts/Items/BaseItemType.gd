extends Resource
class_name BaseItemType

@export var id: StringName = &""
@export var item_def: ItemDef

@export_range(0, 6, 1) var min_attribute_count: int = 0
@export_range(0, 6, 1) var max_attribute_count: int = 2

# StringName -> int (starting stat levels)
@export var start_stat_levels: Dictionary = {}

# Manual attribute pool override (optional). If non-empty, this pool is used.
@export var allowed_attributes: Array[ItemAttribute] = []
@export var attribute_weights: Array[float] = []

# Automatic pool building from resources folder (by prefix).
@export var use_auto_attribute_pool: bool = true
@export var auto_attribute_root: String = "res://Resources/Items/Attributes"
@export var auto_include_global: bool = true

# Optional “weapon token” used for weapon-specific pools:
# Example: "Pistol", "SMG", "Shotgun", "Sword", "Maul", "Dagger".
# If empty, we'll derive from (id) then (item_def.id) then (display_name).
@export var auto_weapon_token: String = ""

# ------------------------------------------------------------
# Ranged shot-mode roll configuration (only used when item_def.category == RANGED)
# ------------------------------------------------------------

@export var use_ranged_mode_roll: bool = true

# If true, the chosen mode’s mode-attribute is forced into the item.
@export var force_mode_attribute: bool = true

# Weights for picking a mode when rolling ranged items.
# (PROJECTILE is the “default” mode. HITSCAN and BEAM require mode attributes.)
@export_range(0.0, 100.0, 0.1) var weight_projectile: float = 1.0
@export_range(0.0, 100.0, 0.1) var weight_hitscan: float = 0.6
@export_range(0.0, 100.0, 0.1) var weight_beam: float = 0.35

# If you want to lock a base type to a specific mode, set this (optional).
# Use -1 for “random”.
@export var locked_ranged_mode: int = -1 # uses RangedShotData.ShotMode values


func has_manual_pool() -> bool:
	return allowed_attributes.size() > 0


func get_weapon_token() -> String:
	if auto_weapon_token.strip_edges() != "":
		return auto_weapon_token.strip_edges()

	if id != &"":
		return _to_token(str(id))

	if item_def != null and item_def.id != &"":
		return _to_token(str(item_def.id))

	if item_def != null and item_def.display_name.strip_edges() != "":
		return _to_token(item_def.display_name)

	return ""

func _to_token(s: String) -> String:
	var in_s: String = s.strip_edges()
	if in_s.is_empty():
		return ""

	var out: String = ""
	for i: int in range(in_s.length()):
		var ch: String = in_s[i]
		var code: int = ch.unicode_at(0)

		var is_alnum: bool = (
			(code >= 48 and code <= 57) or # 0-9
			(code >= 65 and code <= 90) or # A-Z
			(code >= 97 and code <= 122)   # a-z
		)

		if is_alnum:
			out += ch
		else:
			out += "_"

	# Collapse multiple underscores
	while out.find("__") != -1:
		out = out.replace("__", "_")

	# Manually trim leading/trailing underscores
	while out.begins_with("_"):
		out = out.substr(1)

	while out.ends_with("_"):
		out = out.substr(0, out.length() - 1)

	return out
