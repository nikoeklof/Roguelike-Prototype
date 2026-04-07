class_name AIBehaviorModule

extends Node

var _entity: Entity
var _target: Node2D
var _combat: Combat
var _mover: Mover
var _stats: Stats
var _health: Health
var _equipment: Equipment


func _setup(entity: Entity, target: Node2D, combat: Combat, mover: Mover, stats: Stats, health: Health, equipment: Equipment) -> void:
	"""Setup all required components"""
	_entity = entity
	_target = target
	_combat = combat
	_mover = mover
	_stats = stats
	_health = health
	_equipment = equipment


func decide(context: Dictionary) -> AIDecision:
	"""Make decision based on context. Override in subclasses."""
	return null


func physics_update(_delta: float, _decision: AIDecision) -> void:
	"""Continuous updates. Override if needed."""
	pass
