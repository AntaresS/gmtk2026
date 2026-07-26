class_name PlayerAbsorptionArea
extends Area2D

const ACTIVE_REDRAW_INTERVAL: float = 1.0 / 30.0

## World-space radius, in pixels, inside which qi may accumulate absorption
## progress. This component owns the radius so player movement remains focused.
@export_range(24.0, 240.0, 1.0) var absorb_radius: float = 96.0:
	set(value):
		absorb_radius = maxf(value, 1.0)
		if is_node_ready():
			_apply_radius()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _overlapping_pickups: Dictionary[int, bool] = {}
var _animation_phase: float = 0.0
var _redraw_elapsed: float = 0.0
var _absorption_enabled: bool = true


func _ready() -> void:
	_absorption_enabled = true
	_apply_radius()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_animation_phase = fmod(_animation_phase + delta, TAU)
	_redraw_elapsed += delta
	if _redraw_elapsed < ACTIVE_REDRAW_INTERVAL:
		return
	_redraw_elapsed = 0.0
	queue_redraw()


func _draw() -> void:
	var active := not _overlapping_pickups.is_empty()
	var pulse := (sin(_animation_phase * 3.0) + 1.0) * 0.5
	var fill_alpha := 0.055 + (0.035 * pulse if active else 0.0)
	var line_alpha := 0.32 + (0.2 * pulse if active else 0.0)
	draw_circle(
		Vector2.ZERO,
		absorb_radius,
		Color(0.3, 1.0, 0.78, fill_alpha)
	)
	draw_arc(
		Vector2.ZERO,
		absorb_radius,
		0.0,
		TAU,
		96,
		Color(0.5, 1.0, 0.85, line_alpha),
		2.0,
		true
	)
	if active:
		var sweep := PI * (0.35 + pulse * 0.35)
		draw_arc(
			Vector2.ZERO,
			absorb_radius - 5.0,
			_animation_phase * 1.5,
			_animation_phase * 1.5 + sweep,
			32,
			Color(0.75, 1.0, 0.9, 0.8),
			3.0,
			true
		)


## Marker used by qi pickups to accept only the player's injected absorption
## area without searching the scene tree.
func is_qi_absorption_area() -> bool:
	return _absorption_enabled


## Enables the absorption field for an active run or disables it when run
## progression stops. The radius visual follows the same state.
func set_absorption_enabled(enabled: bool) -> void:
	_absorption_enabled = enabled
	visible = enabled
	collision_layer = 4 if enabled else 0
	collision_mask = 2 if enabled else 0
	set_deferred("monitoring", enabled)
	set_deferred("monitorable", enabled)
	if not enabled:
		_overlapping_pickups.clear()
		set_process(false)
	_redraw_elapsed = 0.0
	queue_redraw()


func _apply_radius() -> void:
	if collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = absorb_radius


func _on_area_entered(area: Area2D) -> void:
	if area is not QiPickup:
		return
	var instance_id := area.get_instance_id()
	if _overlapping_pickups.has(instance_id):
		return
	_overlapping_pickups[instance_id] = true
	_redraw_elapsed = 0.0
	set_process(_absorption_enabled)
	queue_redraw()
	var exit_callable := _on_pickup_tree_exited.bind(instance_id)
	if not area.tree_exited.is_connected(exit_callable):
		area.tree_exited.connect(exit_callable, CONNECT_ONE_SHOT)


func _on_area_exited(area: Area2D) -> void:
	_remove_overlap(area.get_instance_id())


func _on_pickup_tree_exited(instance_id: int) -> void:
	_remove_overlap(instance_id)


func _remove_overlap(instance_id: int) -> void:
	if not _overlapping_pickups.erase(instance_id):
		return
	if _overlapping_pickups.is_empty():
		set_process(false)
		_redraw_elapsed = 0.0
	queue_redraw()
