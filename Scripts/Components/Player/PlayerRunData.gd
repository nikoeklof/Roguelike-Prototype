extends Node
class_name PlayerRunData

signal currency_changed(amount: int)

var currency: int = 0


func _ready() -> void:
	GameManager.register_player_run_data(self)


func add_currency(amount: int) -> void:
	currency += amount
	currency_changed.emit(currency)


func spend_currency(amount: int) -> bool:
	if currency < amount:
		return false
	currency -= amount
	currency_changed.emit(currency)
	return true


func reset() -> void:
	currency = 0
	currency_changed.emit(currency)
