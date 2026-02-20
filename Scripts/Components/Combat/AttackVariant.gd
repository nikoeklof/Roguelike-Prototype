extends Resource
class_name AttackVariant

# Data-only description of an attack.
#
# Weapons/Spells choose a variant; Combat spawns an executor scene to run it.

@export var executor_scene: PackedScene

# Optional timings that an executor may choose to respect.
@export var windup_time: float = 0.0
@export var recovery_time: float = 0.1

func create_executor(context: CombatContext) -> AttackExecutor:
	if executor_scene == null:
		return null
	var exec := executor_scene.instantiate() as AttackExecutor
	if exec == null:
		push_warning("AttackVariant: executor_scene is not an AttackExecutor.")
		return null
	exec.setup(context, self)
	return exec
