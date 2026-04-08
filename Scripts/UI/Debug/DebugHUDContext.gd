extends RefCounted
class_name DebugHUDContext
## Snapshot of references passed to every DebugHUDSection each tick.
## Sections read from this — they never search the tree themselves.

var player: Node2D = null
var player_equipment: Equipment = null
var player_stats: Stats = null
var player_health: Health = null
var player_passive_shield: PassiveShieldAttributeActivator = null
var enemies: Array[Node] = []
var tree: SceneTree = null
