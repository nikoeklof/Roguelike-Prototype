extends Node
class_name IInteractable

# Return false to prevent interaction (locked, cooldown, etc.)
func can_interact(_interactor: Node) -> bool:
	return true

# Called when the interactor triggers interaction.
func interact(_interactor: Node) -> void:
	pass

# Optional: UI prompt text
func get_interact_prompt() -> String:
	return "Interact"
