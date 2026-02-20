extends Node
class_name AttackExecutor

signal finished(success: bool)

var context: CombatContext
var variant: AttackVariant

func setup(ctx: CombatContext, v: AttackVariant) -> void:
	context = ctx
	variant = v

# Called by Combat once the executor is parented in the scene tree.
func start() -> void:
	execute()

# Override in subclasses to perform the attack.
# Implementations should eventually call finish().
func execute() -> void:
	finish(true)

func finish(success: bool = true) -> void:
	finished.emit(success)
	queue_free()
