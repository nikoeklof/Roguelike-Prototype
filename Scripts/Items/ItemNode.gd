extends Node
class_name ItemNode

static var _icon_cache: Dictionary = {}

var _inst: ItemInstance = null


func set_item_instance(inst: ItemInstance) -> void:
	_inst = inst


func get_item_instance() -> ItemInstance:
	return _inst


# Helps EquipmentSwapPickup infer slot without any inspector overrides.
func get_pickup_slot_kind() -> int:
	if _inst == null or _inst.def == null:
		return 0
	return int(_inst.def.category)


# Provides a visible icon for ground pickups (EquipmentSwapPickup looks for this).
# Until real art is wired, we generate a tiny colored square per item category.
func get_pickup_icon() -> Texture2D:
	if _inst == null or _inst.def == null:
		return null

	var cat: int = int(_inst.def.category)
	if _icon_cache.has(cat):
		return _icon_cache[cat] as Texture2D

	var c: Color = Color.WHITE
	match cat:
		ItemDef.Category.MELEE:
			c = Color(0.90, 0.25, 0.25)
		ItemDef.Category.RANGED:
			c = Color(0.25, 0.55, 0.95)
		ItemDef.Category.SPELL:
			c = Color(0.70, 0.35, 0.95)
		ItemDef.Category.SHIELD:
			c = Color(0.25, 0.85, 0.45)

	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(c)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_icon_cache[cat] = tex
	return tex
