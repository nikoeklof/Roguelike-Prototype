extends ItemDef
class_name SpellItemDef

enum SpellType { BUFF, DEBUFF }

@export var spell_type: SpellType = SpellType.BUFF

func _init() -> void:
	category = Category.SPELL
