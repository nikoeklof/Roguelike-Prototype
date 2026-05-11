extends Area2D
class_name AutoPickup

@export var pickup_def: Resource


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not (body.is_in_group("player") or body.name == "Player"):
		return
	if pickup_def == null:
		return
	if _collect(body):
		queue_free()


func _collect(entity: Node) -> bool:
	if pickup_def is HealthPickupDef:
		return _collect_health(entity, pickup_def as HealthPickupDef)
	if pickup_def is CurrencyPickupDef:
		return _collect_currency(pickup_def as CurrencyPickupDef)
	return false


func _collect_health(entity: Node, def: HealthPickupDef) -> bool:
	var health: Health = entity.get_node_or_null("Health") as Health
	if health == null:
		return false
	match def.heal_type:
		HealthPickupDef.HealType.FLAT:
			health.heal(def.value)
		HealthPickupDef.HealType.PERCENT:
			health.heal(health.max_hp * def.value / 100.0)
	return true


func _collect_currency(_def: CurrencyPickupDef) -> bool:
	var prd: PlayerRunData = GameManager.get_player_run_data()
	if prd == null:
		return false
	prd.add_currency(_def.amount)
	return true
