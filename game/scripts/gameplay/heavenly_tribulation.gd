class_name HeavenlyTribulation
extends Node2D

signal strike_warning_started(strike_index: int, landing_position: Vector2)
signal strike_landed(strike_index: int, hit_player: bool)
signal tribulation_completed

enum Phase {
	IDLE,
	WARNING,
	FLASH,
	GAP,
}

## Default number of lightning strikes before realm-specific configuration.
@export_range(1, 20, 1) var strike_count: int = 9
## Minimum ground-warning duration, in seconds. The exact duration is random
## for each strike and is also used to predict the player's landing position.
@export_range(0.2, 2.0, 0.05) var warning_duration_min: float = 0.7
## Maximum ground-warning duration, in seconds.
@export_range(0.2, 3.0, 0.05) var warning_duration_max: float = 1.0
## Radius of both the visible warning and lightning damage, in world pixels.
@export_range(24.0, 160.0, 1.0) var strike_radius: float = 68.0
## Maximum random offset from the predicted player position, in world pixels.
## Runtime clamps it inside the damage radius so unchanged movement still hits.
@export_range(0.0, 80.0, 1.0) var random_landing_offset: float = 24.0
## Minimum lifespan removed by one lightning strike. The resolved damage is
## whichever is greater: this floor or maximum_lifespan_damage_ratio of the
## maximum lifespan snapshotted when the tribulation starts.
@export_range(0.1, 100.0, 0.5) var strike_damage: float = 12.0
## Portion of the player's maximum lifespan removed by each lightning strike.
## The default four percent begins exceeding the 12-point floor in later realms.
@export_range(0.0, 1.0, 0.005) var maximum_lifespan_damage_ratio: float = 0.04
## Duration of the bright lightning impact, in seconds.
@export_range(0.05, 0.8, 0.05) var flash_duration: float = 0.18
## Pause between one impact fading and the next warning, in seconds.
@export_range(0.0, 1.0, 0.05) var inter_strike_delay: float = 0.16

@onready var warning_label: Label = $WarningLabel

var _player: PlayerController
var _phase: Phase = Phase.IDLE
var _phase_time_remaining: float = 0.0
var _warning_duration: float = 0.0
var _current_strike_index: int = 0
var _landing_position: Vector2 = Vector2.ZERO
var _maximum_lifespan_snapshot: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("heavenly_tribulations")
	_rng.randomize()
	warning_label.hide()
	set_physics_process(false)


## Applies one source realm's strike count and warning-time multiplier to this
## scene instance without mutating the shared realm or scene resources.
func configure_for_realm(realm: RealmDefinition) -> void:
	if realm == null:
		return
	strike_count = maxi(realm.tribulation_strike_count, 1)
	var warning_multiplier := maxf(
		realm.tribulation_warning_duration_multiplier,
		0.01
	)
	warning_duration_min *= warning_multiplier
	warning_duration_max *= warning_multiplier


## Starts one complete strike sequence and snapshots the supplied maximum
## lifespan so damage remains stable throughout the configured sequence.
func start(
	active_player: PlayerController,
	maximum_lifespan: float = 0.0
) -> void:
	if not is_instance_valid(active_player):
		push_error("HeavenlyTribulation requires an active PlayerController.")
		queue_free()
		return
	_player = active_player
	_maximum_lifespan_snapshot = maxf(maximum_lifespan, 0.0)
	_current_strike_index = 0
	set_physics_process(true)
	_prepare_next_warning()


## Stops an unfinished tribulation without granting its completion reward.
func cancel() -> void:
	set_physics_process(false)
	queue_free()


## Returns the world-space center of the currently warned strike.
func get_current_landing_position() -> Vector2:
	return _landing_position


## Returns the damage one strike resolves from a supplied maximum lifespan.
## This pure helper is also the designer-facing preview of the scaling curve.
func get_strike_damage_for_maximum_lifespan(
	maximum_lifespan: float
) -> float:
	return maxf(
		maxf(strike_damage, 0.0),
		maxf(maximum_lifespan, 0.0)
			* clampf(maximum_lifespan_damage_ratio, 0.0, 1.0)
	)


## Returns the live sequence's damage using its start-time lifespan snapshot.
func get_current_strike_damage() -> float:
	return get_strike_damage_for_maximum_lifespan(
		_maximum_lifespan_snapshot
	)


func _physics_process(delta: float) -> void:
	if _phase == Phase.IDLE or not is_instance_valid(_player):
		return
	_phase_time_remaining -= delta
	queue_redraw()
	if _phase_time_remaining > 0.0:
		return

	match _phase:
		Phase.WARNING:
			_land_current_strike()
		Phase.FLASH:
			_finish_current_strike()
		Phase.GAP:
			_prepare_next_warning()


func _prepare_next_warning() -> void:
	var minimum_warning := minf(
		warning_duration_min,
		warning_duration_max
	)
	var maximum_warning := maxf(
		warning_duration_min,
		warning_duration_max
	)
	_warning_duration = _rng.randf_range(
		maxf(minimum_warning, 0.05),
		maxf(maximum_warning, 0.05)
	)
	var predicted_position := (
		_player.global_position + _player.velocity * _warning_duration
	)
	var lateral_bounds := _player.get_active_lateral_bounds()
	predicted_position.x = clampf(
		predicted_position.x,
		lateral_bounds.x,
		lateral_bounds.y
	)
	var guaranteed_offset := minf(
		maxf(random_landing_offset, 0.0),
		maxf(strike_radius - 28.0, 0.0)
	)
	var random_offset := (
		Vector2.from_angle(_rng.randf_range(0.0, TAU))
		* _rng.randf_range(0.0, guaranteed_offset)
	)
	_landing_position = predicted_position + random_offset
	_phase = Phase.WARNING
	_phase_time_remaining = _warning_duration
	warning_label.text = "天雷落点  %d / %d" % [
		_current_strike_index + 1,
		maxi(strike_count, 1),
	]
	warning_label.position = to_local(_landing_position) + Vector2(-68.0, 76.0)
	warning_label.show()
	strike_warning_started.emit(
		_current_strike_index + 1,
		_landing_position
	)
	queue_redraw()


func _land_current_strike() -> void:
	_phase = Phase.FLASH
	_phase_time_remaining = maxf(flash_duration, 0.01)
	warning_label.hide()
	var hit_player := (
		_player.global_position.distance_to(_landing_position)
		<= strike_radius
	)
	if hit_player:
		_player.take_melee_damage(get_current_strike_damage())
	strike_landed.emit(_current_strike_index + 1, hit_player)
	queue_redraw()


func _finish_current_strike() -> void:
	_current_strike_index += 1
	if _current_strike_index >= maxi(strike_count, 1):
		_phase = Phase.IDLE
		set_physics_process(false)
		tribulation_completed.emit()
		queue_free()
		return
	_phase = Phase.GAP
	_phase_time_remaining = maxf(inter_strike_delay, 0.0)
	queue_redraw()


func _draw() -> void:
	if _phase == Phase.IDLE or _phase == Phase.GAP:
		return
	var local_landing := to_local(_landing_position)
	if _phase == Phase.WARNING:
		var warning_ratio := clampf(
			_phase_time_remaining / maxf(_warning_duration, 0.01),
			0.0,
			1.0
		)
		var pulse := 0.65 + sin(Time.get_ticks_msec() * 0.02) * 0.15
		draw_circle(
			local_landing,
			strike_radius,
			Color(0.2, 0.65, 1.0, 0.12 + (1.0 - warning_ratio) * 0.18)
		)
		draw_arc(
			local_landing,
			strike_radius * pulse,
			0.0,
			TAU,
			64,
			Color(0.5, 0.88, 1.0, 0.95),
			4.0,
			true
		)
		draw_line(
			local_landing + Vector2(-strike_radius, 0.0),
			local_landing + Vector2(strike_radius, 0.0),
			Color(0.65, 0.92, 1.0, 0.75),
			2.0
		)
		draw_line(
			local_landing + Vector2(0.0, -strike_radius),
			local_landing + Vector2(0.0, strike_radius),
			Color(0.65, 0.92, 1.0, 0.75),
			2.0
		)
		return

	draw_circle(
		local_landing,
		strike_radius,
		Color(0.75, 0.94, 1.0, 0.72)
	)
	var bolt_points := PackedVector2Array([
		local_landing + Vector2(-18.0, -260.0),
		local_landing + Vector2(16.0, -205.0),
		local_landing + Vector2(-11.0, -151.0),
		local_landing + Vector2(13.0, -96.0),
		local_landing + Vector2(-7.0, -44.0),
		local_landing,
	])
	draw_polyline(
		bolt_points,
		Color(0.28, 0.72, 1.0, 0.85),
		19.0,
		true
	)
	draw_polyline(
		bolt_points,
		Color.WHITE,
		11.0,
		true
	)
