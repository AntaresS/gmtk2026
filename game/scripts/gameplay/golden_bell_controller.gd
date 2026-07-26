class_name GoldenBellController
extends Node2D

signal layer_state_changed(ready: int, flashing: int, recovering: int)
signal enemy_hit(enemy: EnemyController)

enum LayerPhase {
	READY,
	FLASHING,
	RECOVERING,
}

## Radius of the innermost bell layer around the player.
@export_range(20.0, 100.0, 1.0) var base_radius: float = 29.0
## Small radial separation between layers. This deliberately stays much
## thinner than the spacing between additional Dao orbits.
@export_range(1.0, 12.0, 0.5) var layer_spacing: float = 4.0
## Visible line width of each golden layer.
@export_range(0.5, 8.0, 0.5) var layer_width: float = 2.5
## Grace period after impact during which the consumed layer flashes and
## blocks incoming damage without damaging or knocking another enemy.
@export_range(0.1, 2.0, 0.05) var flash_duration: float = 0.5
## Time after the flashing layer disappears before it becomes ready again.
@export_range(0.1, 20.0, 0.1) var recovery_duration: float = 0.8
## Minimum fraction of a non-elite enemy's maximum health dealt on impact.
## The 0.9 default leaves a fresh ordinary enemy at roughly ten percent.
@export_range(0.0, 1.0, 0.01) var ordinary_enemy_damage_ratio: float = 0.90
## Initial enemy knockback speed applied away from the player.
@export_range(10.0, 2000.0, 10.0) var knockback_speed: float = 460.0
## Speed per second with which an impacted enemy returns to steady movement.
@export_range(10.0, 5000.0, 10.0) var knockback_recovery: float = 920.0

@onready var impact_area: Area2D = $ImpactArea
@onready var impact_shape: CollisionShape2D = $ImpactArea/CollisionShape2D

var _equipped: bool = false
var _resolved_damage: int = 1
var _layers: Array[Dictionary] = []
var _contact_enemy_ids: Dictionary = {}


func _physics_process(delta: float) -> void:
	_update_layers(delta)
	if not _equipped:
		_contact_enemy_ids.clear()
		return
	if get_parent() is PlayerController and (get_parent() as PlayerController).is_rolling():
		_contact_enemy_ids.clear()
		return
	_process_new_enemy_contacts()
	queue_redraw()


func _draw() -> void:
	if not _equipped:
		return
	for layer_index in _layers.size():
		var layer := _layers[layer_index]
		var phase := int(layer["phase"])
		if phase == LayerPhase.RECOVERING:
			continue
		var radius := base_radius + float(layer_index) * layer_spacing
		var color := Color(1.0, 0.78, 0.16, 0.92)
		var width := layer_width
		if phase == LayerPhase.FLASHING:
			var remaining := float(layer["remaining"])
			var ratio := clampf(
				remaining / maxf(flash_duration, 0.01),
				0.0,
				1.0
			)
			var pulse := 0.45 + 0.55 * absf(sin(remaining * 34.0))
			color = Color(1.0, 0.94, 0.48, ratio * pulse)
			width += 1.0
		draw_arc(
			Vector2.ZERO,
			radius,
			0.0,
			TAU,
			64,
			Color(1.0, 0.62, 0.05, color.a * 0.24),
			width + 3.0,
			true
		)
		draw_arc(
			Vector2.ZERO,
			radius,
			0.0,
			TAU,
			64,
			color,
			width,
			true
		)


## Synchronizes the currently equipped Golden Bell and its duplicate count.
## Existing layer cooldowns survive weapon switching.
func configure_weapon(equipped: bool, layer_count: int, damage: int) -> void:
	_equipped = equipped
	_resolved_damage = maxi(damage, 1)
	if _equipped:
		var resolved_layer_count := maxi(layer_count, 0)
		while _layers.size() < resolved_layer_count:
			_layers.append({
				"phase": LayerPhase.READY,
				"remaining": 0.0,
			})
		while _layers.size() > resolved_layer_count:
			_layers.pop_back()
	_update_collision_radius()
	if not _equipped:
		_contact_enemy_ids.clear()
	queue_redraw()
	_emit_state()


## Returns true while at least one just-consumed layer is in its 0.5-second
## protective flash window.
func is_damage_protection_active() -> bool:
	if not _equipped:
		return false
	for layer in _layers:
		if int(layer["phase"]) == LayerPhase.FLASHING:
			return true
	return false


func get_ready_layer_count() -> int:
	return _count_phase(LayerPhase.READY)


func get_flashing_layer_count() -> int:
	return _count_phase(LayerPhase.FLASHING)


func get_recovering_layer_count() -> int:
	return _count_phase(LayerPhase.RECOVERING)


func get_layer_count() -> int:
	return _layers.size()


## Exposes one layer phase for debug UI and deterministic behavior checks.
func get_layer_phase(layer_index: int) -> int:
	if layer_index < 0 or layer_index >= _layers.size():
		return -1
	return int(_layers[layer_index]["phase"])


func _process_new_enemy_contacts() -> void:
	var current_contacts: Dictionary = {}
	for body in impact_area.get_overlapping_bodies():
		if body is not EnemyController:
			continue
		var enemy := body as EnemyController
		if not enemy.is_combat_active():
			continue
		var enemy_id := enemy.get_instance_id()
		current_contacts[enemy_id] = true
		if not _contact_enemy_ids.has(enemy_id):
			_try_impact_enemy(enemy)
	_contact_enemy_ids = current_contacts


func _try_impact_enemy(enemy: EnemyController) -> void:
	var ready_layer_index := _find_ready_layer()
	if ready_layer_index < 0:
		return
	var direction := global_position.direction_to(enemy.global_position)
	if direction.is_zero_approx():
		direction = Vector2.UP
	enemy.apply_knockback(
		direction,
		knockback_speed,
		knockback_recovery
	)
	var impact_damage := maxi(
		_resolved_damage,
		ceili(
			float(enemy.get_ordinary_health_equivalent())
				* clampf(ordinary_enemy_damage_ratio, 0.0, 1.0)
		)
	)
	enemy.take_melee_damage(impact_damage, false, &"golden_bell")
	enemy_hit.emit(enemy)
	_layers[ready_layer_index]["phase"] = LayerPhase.FLASHING
	_layers[ready_layer_index]["remaining"] = maxf(flash_duration, 0.01)
	_emit_state()
	queue_redraw()


func _update_layers(delta: float) -> void:
	var changed := false
	for layer in _layers:
		var phase := int(layer["phase"])
		if phase == LayerPhase.READY:
			continue
		layer["remaining"] = maxf(
			float(layer["remaining"]) - maxf(delta, 0.0),
			0.0
		)
		if float(layer["remaining"]) > 0.0:
			continue
		if phase == LayerPhase.FLASHING:
			layer["phase"] = LayerPhase.RECOVERING
			layer["remaining"] = maxf(recovery_duration, 0.01)
		else:
			layer["phase"] = LayerPhase.READY
			layer["remaining"] = 0.0
		changed = true
	if changed:
		_emit_state()
		queue_redraw()


func _find_ready_layer() -> int:
	for layer_index in range(_layers.size() - 1, -1, -1):
		if int(_layers[layer_index]["phase"]) == LayerPhase.READY:
			return layer_index
	return -1


func _count_phase(phase: LayerPhase) -> int:
	var count := 0
	for layer in _layers:
		if int(layer["phase"]) == phase:
			count += 1
	return count


func _update_collision_radius() -> void:
	if impact_shape == null or impact_shape.shape is not CircleShape2D:
		return
	var outer_radius := (
		base_radius
		+ float(maxi(_layers.size() - 1, 0)) * layer_spacing
	)
	(impact_shape.shape as CircleShape2D).radius = outer_radius + 4.0


func _emit_state() -> void:
	layer_state_changed.emit(
		get_ready_layer_count(),
		get_flashing_layer_count(),
		get_recovering_layer_count()
	)
