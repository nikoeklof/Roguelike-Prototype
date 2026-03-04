extends RefCounted
class_name AttributePoolBuilder

static func build_pool(
	bt: BaseItemType,
	category: int,
	ranged_mode: int,
	weapon_token: String
) -> Array[ItemAttribute]:
	var pool: Array[ItemAttribute] = []

	var pd := bt.pool_def
	if pd == null:
		return pool

	# Global
	if pd.include_global and bt.auto_include_global:
		pool.append_array(pd.global_attributes)

	# Category common
	match category:
		ItemDef.Category.MELEE:
			pool.append_array(pd.melee_common)
		ItemDef.Category.RANGED:
			pool.append_array(pd.ranged_common)
		ItemDef.Category.SPELL:
			pool.append_array(pd.spell_common)
		ItemDef.Category.SHIELD:
			pool.append_array(pd.shield_common)

	# Ranged mode pool
	if category == ItemDef.Category.RANGED:
		match ranged_mode:
			RangedShotData.ShotMode.PROJECTILE:
				pool.append_array(pd.ranged_projectile)
			RangedShotData.ShotMode.HITSCAN:
				pool.append_array(pd.ranged_hitscan)
			RangedShotData.ShotMode.BEAM:
				pool.append_array(pd.ranged_beam)

	# Token pool
	# NOTE: BaseItemType.auto_weapon_token is a String override (not a bool).
	# Passing in an empty token means "skip token pools".
	if weapon_token != "":
		var token_key := weapon_token.to_lower()
		if pd.weapon_token_pools.has(token_key):
			var arr: Variant = pd.weapon_token_pools[token_key]
			# Enforce expected shape
			if arr is Array:
				for a in arr:
					if a is ItemAttribute:
						pool.append(a)

	# Apply excludes (by resource identity)
	if pd.exclude.size() > 0:
		var filtered: Array[ItemAttribute] = []
		for a in pool:
			if not pd.exclude.has(a):
				filtered.append(a)
		pool = filtered

	# De-dupe deterministically, preserving first occurrence order
	var seen: Dictionary = {}
	var deduped: Array[ItemAttribute] = []
	for a in pool:
		if a == null:
			continue
		var key := a.resource_path
		if not seen.has(key):
			seen[key] = true
			deduped.append(a)

	return deduped
