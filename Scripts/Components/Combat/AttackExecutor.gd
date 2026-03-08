extends Node
class_name AttackExecutor

signal finished(success: bool)

var context: CombatContext
var variant: AttackVariant
var snapshot: AttackSnapshot


func setup(ctx: CombatContext, v: AttackVariant) -> void:
	context = ctx
	variant = v


func start() -> void:
	if snapshot == null:
		snapshot = AttackResolver.resolve(context, variant)
	execute()


func execute() -> void:
	finish(true)


func resolve_snapshot() -> AttackSnapshot:
	if snapshot == null:
		snapshot = AttackResolver.resolve(context, variant)
	return snapshot


func dispatch_attack_start() -> void:
	if context == null:
		return
	if context.item_instance == null:
		return
	ItemAttributeBus.dispatch_attack_start(context, context.item_instance)


func wait_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds, true, true).timeout


func finish(success: bool = true) -> void:
	finished.emit(success)
	queue_free()
