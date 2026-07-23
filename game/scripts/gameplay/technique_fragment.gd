class_name TechniqueFragment
extends Node2D

signal fragment_collected(amount: int)

## Radius, in world pixels, of the visible circle the player must remain in.
@export_range(32.0, 240.0, 1.0) var recognition_radius: float = 90.0
## Continuous seconds required inside the circle before absorption completes.
## Leaving the circle resets all recognition progress.
@export_range(0.2, 5.0, 0.1) var recognition_duration: float = 1.5
## Distance behind the player, in world pixels, after which an ignored fragment
## is removed to keep a long run bounded.
@export_range(200.0, 2000.0, 10.0) var despawn_behind_distance: float = 900.0

@onready var description_label: Label = $DescriptionLabel

var _player: PlayerController
var _inherited_velocity: Vector2 = Vector2.ZERO
var _recognition_progress: float = 0.0
var _collected: bool = false
var _visual_phase: float = 0.0


## Assigns the collecting player and preserves the defeated elite's movement.
## This object intentionally has no collision body; proximity time is its only
## collection path.
func configure(
	player: PlayerController,
	inherited_velocity: Vector2
) -> void:
	_player = player
	_inherited_velocity = inherited_velocity


func _ready() -> void:
	_update_label(false)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _collected:
		return
	global_position += _inherited_velocity * delta
	_visual_phase = fmod(_visual_phase + delta * 2.4, TAU)
	if not is_instance_valid(_player):
		_recognition_progress = 0.0
		_update_label(false)
		queue_redraw()
		return

	var player_inside := (
		global_position.distance_to(_player.global_position)
		<= maxf(recognition_radius, 1.0)
	)
	if player_inside:
		_recognition_progress += delta
	else:
		_recognition_progress = 0.0
	_update_label(player_inside)
	queue_redraw()

	if _recognition_progress >= maxf(recognition_duration, 0.01):
		_collect()
	elif (
		global_position.y - _player.global_position.y
		> maxf(despawn_behind_distance, 1.0)
	):
		queue_free()


func _draw() -> void:
	var radius := maxf(recognition_radius, 1.0)
	var progress_ratio := clampf(
		_recognition_progress / maxf(recognition_duration, 0.01),
		0.0,
		1.0
	)
	var pulse_alpha := 0.10 + sin(_visual_phase) * 0.025
	draw_circle(Vector2.ZERO, radius, Color(0.48, 0.24, 1.0, pulse_alpha))
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		80,
		Color(0.72, 0.50, 1.0, 0.92),
		3.5,
		true
	)
	if progress_ratio > 0.0:
		draw_arc(
			Vector2.ZERO,
			radius - 6.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * progress_ratio,
			80,
			Color(0.25, 1.0, 0.90, 1.0),
			7.0,
			true
		)
	var diamond := PackedVector2Array([
		Vector2(0.0, -15.0),
		Vector2(13.0, 0.0),
		Vector2(0.0, 15.0),
		Vector2(-13.0, 0.0),
	])
	draw_colored_polygon(diamond, Color(0.88, 0.72, 1.0, 0.98))
	draw_polyline(
		PackedVector2Array([
			diamond[0],
			diamond[1],
			diamond[2],
			diamond[3],
			diamond[0],
		]),
		Color.WHITE,
		2.0,
		true
	)


func get_recognition_progress() -> float:
	return _recognition_progress


func _update_label(player_inside: bool) -> void:
	if not is_instance_valid(description_label):
		return
	if player_inside:
		description_label.text = "功法碎片\n识别中 %.1f / %.1f秒" % [
			minf(_recognition_progress, recognition_duration),
			recognition_duration,
		]
	else:
		description_label.text = "功法碎片\n进入识别圈维持 %.1f秒" % (
			recognition_duration
		)


func _collect() -> void:
	if _collected:
		return
	_collected = true
	fragment_collected.emit(1)
	queue_free()
