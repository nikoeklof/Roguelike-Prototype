extends Node

@export var dps_window_sec := 1.0
@export var beam_tick_gap_sec := 0.12
@export var auto_heal_per_second := 0.0

var total_damage := 0.0
var hit_count := 0
var beam_ticks := 0

var damage_events := []
var last_hit_time := 0.0

var label : Label


func _ready():
	label = Label.new()
	label.position = Vector2(-40, -60)
	add_child(label)

	var health = get_parent().get_node("Health")

	if health.has_signal("damaged"):
		health.damaged.connect(_on_damage)

	if health.has_signal("healed"):
		health.healed.connect(_on_heal)


func _process(delta):

	if auto_heal_per_second > 0:
		var health = get_parent().get_node("Health")
		health.hp = min(health.hp + auto_heal_per_second * delta, health.max_hp)

	var now = Time.get_ticks_msec() / 1000.0

	damage_events = damage_events.filter(func(e):
		return now - e.time < dps_window_sec
	)

	var window_damage := 0.0
	for e in damage_events:
		window_damage += e.damage

	var dps : float = window_damage / max(dps_window_sec, 0.001)

	var avg_hit := 0.0
	if hit_count > 0:
		avg_hit = total_damage / hit_count

	label.text = \
	"Hits: %d\n" % hit_count + \
	"Avg Hit: %.1f\n" % avg_hit + \
	"DPS: %.1f\n" % dps + \
	"BeamTicks: %d" % beam_ticks


func _on_damage(amount, _source):

	var now = Time.get_ticks_msec() / 1000.0

	total_damage += amount
	hit_count += 1

	damage_events.append({
		"time": now,
		"damage": amount
	})

	if now - last_hit_time < beam_tick_gap_sec:
		beam_ticks += 1

	last_hit_time = now


func _on_heal(_amount):
	pass
