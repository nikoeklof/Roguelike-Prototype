extends Node
class_name State

var entity: Entity = null
var state_handler: StateHandler = null


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
