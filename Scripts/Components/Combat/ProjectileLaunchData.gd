extends RefCounted
class_name ProjectileLaunchData

var context: CombatContext
var snapshot: AttackSnapshot

var owner: Node
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO

var gravity: float = 0.0
var lifetime_sec: float = 2.0
var damage: float = 1.0
var pierce: int = 0
var radius: float = 6.0
var max_range: float = 0.0

var collision_mask: int = 0x7FFFFFFF

var sprite_texture: Texture2D
var sprite_tint: Color = Color.WHITE
