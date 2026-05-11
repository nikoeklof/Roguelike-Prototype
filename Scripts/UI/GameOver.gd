extends CanvasLayer
class_name GameOver

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	call_deferred("_bind_player")


func _bind_player() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	if player == null:
		push_warning("GameOver: no node in group 'player' found.")
		return
	var health: Health = player.get_node_or_null("Health") as Health
	if health == null:
		push_warning("GameOver: player has no Health component.")
		return
	health.died.connect(_on_player_died)


func _on_player_died() -> void:
	get_tree().paused = true
	visible = true


func _on_restart_pressed() -> void:
	GameManager.start_new_run()
