extends CanvasLayer
class_name PauseMenu

@export var pause_action: StringName = &"Pause"


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(pause_action):
		if visible:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()


func _open() -> void:
	get_tree().paused = true
	visible = true


func _close() -> void:
	get_tree().paused = false
	visible = false


func _on_resume_pressed() -> void:
	_close()


func _on_restart_pressed() -> void:
	GameManager.start_new_run()


func _on_quit_pressed() -> void:
	get_tree().quit()
