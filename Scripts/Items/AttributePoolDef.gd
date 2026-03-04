extends Resource
class_name AttributePoolDef

@export var include_global: bool = true

@export var global_attributes: Array[ItemAttribute] = []

@export var melee_common: Array[ItemAttribute] = []
@export var ranged_common: Array[ItemAttribute] = []
@export var spell_common: Array[ItemAttribute] = []
@export var shield_common: Array[ItemAttribute] = []

# Mode-specific pools (only used if item rolled into that mode)
@export var ranged_projectile: Array[ItemAttribute] = []
@export var ranged_hitscan: Array[ItemAttribute] = []
@export var ranged_beam: Array[ItemAttribute] = []

# Token-specific pools (SMG, PISTOL, etc.)
# Key: token string, Value: list of attributes
@export var weapon_token_pools: Dictionary = {} # String -> Array[ItemAttribute]

# Optional: explicit deny list (applies after building pool)
@export var exclude: Array[ItemAttribute] = []
