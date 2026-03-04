extends Resource
class_name AttackVariant

@export var executor_scene: PackedScene
@export var windup_time: float = 0.0
@export var recovery_time: float = 0.1


func create_executor(context: CombatContext) -> AttackExecutor:
	if executor_scene == null:
		return null

	var instanced: Node = executor_scene.instantiate()
	var exec: AttackExecutor = instanced as AttackExecutor
	if exec == null:
		push_warning("AttackVariant: executor_scene is not an AttackExecutor.")
		if is_instance_valid(instanced):
			instanced.queue_free()
		return null

	exec.setup(context, self)
	return exec
