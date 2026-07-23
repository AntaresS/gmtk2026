class_name WeaponPowerFragment
extends Node2D

signal power_fragment_collected(amount: int)

## Radius, in world pixels, of the visible power-fragment recognition circle.
@export_range(32.0, 240.0, 1.0) var recognition_radius: float = 90.0
## Continuous seconds required inside the circle. Leaving resets progress.
@export_range(0.2, 5.0, 0.1) var recognition_duration: float = 1.5
## Flat base damage granted to every player weapon when absorbed.
@export_range(1, 20, 1) var base_damage_increase: int = 1
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
## No collision body is used, so recognition time cannot be bypassed.
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
	_visual_phase = fmod(_visual_phase + delta * 3.0, TAU)
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
	draw_circle(
		Vector2.ZERO,
		radius,
		Color(1.0, 0.16, 0.03, 0.11 + sin(_visual_phase) * 0.025)
	)
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		80,
		Color(1.0, 0.32, 0.08, 0.96),
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
			Color(1.0, 0.86, 0.22, 1.0),
			7.0,
			true
		)
	var core_radius := 14.0 + sin(_visual_phase * 1.5) * 2.0
	draw_circle(Vector2.ZERO, core_radius, Color(1.0, 0.30, 0.05, 0.98))
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.92, 0.38, 1.0))
	for ray_index in 8:
		var direction := Vector2.from_angle(float(ray_index) / 8.0 * TAU)
		draw_line(
			direction * 18.0,
			direction * 27.0,
			Color(1.0, 0.64, 0.16, 0.92),
			3.0
		)


func get_recognition_progress() -> float:
	return _recognition_progress


func _update_label(player_inside: bool) -> void:
	if not is_instance_valid(description_label):
		return
	if player_inside:
		description_label.text = "武器威能碎片\n识别中 %.1f / %.1f秒" % [
			minf(_recognition_progress, recognition_duration),
			recognition_duration,
		]
	else:
		description_label.text = (
			"武器威能碎片\n基础攻击 +%d · 维持 %.1f秒"
			% [base_damage_increase, recognition_duration]
		)


func _collect() -> void:
	if _collected:
		return
	_collected = true
	power_fragment_collected.emit(maxi(base_damage_increase, 1))
	queue_free()
