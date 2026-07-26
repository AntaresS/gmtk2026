class_name HeavenlyTribulation
extends Node2D

signal strike_warning_started(strike_index: int, landing_position: Vector2)
signal strike_landed(strike_index: int, hit_player: bool)
signal camera_shake_requested(strength: float)
signal tribulation_completed

enum Phase {
	IDLE,
	WARNING,
	FLASH,
	GAP,
}

const WARNING_LIGHTNING_ICON_COUNT: int = 11
const WARNING_ICON_GATHER_END: float = 0.82
const WARNING_ICON_DIVE_START: float = 0.82
const LIGHTNING_ICON_COLOR: Color = Color("58bfff")

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
## Duration, in seconds, that impact cracks remain visible after lightning.
@export_range(0.1, 2.0, 0.05) var crack_duration: float = 0.55
## Screen-shake magnitude requested exactly when the gathered icon lands and
## the tapered lightning bolt strikes.
@export_range(0.0, 24.0, 0.5) var camera_shake_strength: float = 8.0

@export_category("Audio")
## Sound played once for every lightning landing, regardless of whether it
## hits the player. The imported stream remains non-looping.
@export var strike_sfx: AudioStream = preload(
	"res://assets/sound/sfx/duejie_thunder.mp3"
)
## Lightning loudness in decibels. The negative default keeps repeated,
## overlapping strikes below the foreground weapon mix.
@export_range(-40.0, 12.0, 0.5) var strike_sfx_volume_db: float = -6.0
## Lightning playback-speed and pitch multiplier. One preserves the source.
@export_range(0.25, 4.0, 0.05) var strike_sfx_pitch_scale: float = 1.0
## Maximum overlapping lightning voices. At saturation, AudioStreamPlayer
## discards its oldest voice while keeping new strike feedback responsive.
@export_range(1, 20, 1) var strike_sfx_max_polyphony: int = 9
## Audio bus used by lightning. Missing bus names safely fall back to Master.
@export var strike_sfx_bus: StringName = &"SFX"

@onready var warning_label: Label = $WarningLabel
@onready var strike_sfx_player: AudioStreamPlayer = $StrikeSfx

var _player: PlayerController
var _phase: Phase = Phase.IDLE
var _phase_time_remaining: float = 0.0
var _warning_duration: float = 0.0
var _current_strike_index: int = 0
var _landing_position: Vector2 = Vector2.ZERO
var _crack_position: Vector2 = Vector2.ZERO
var _crack_remaining: float = 0.0
var _maximum_lifespan_snapshot: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("heavenly_tribulations")
	LanguageManager.language_changed.connect(_on_language_changed)
	_rng.randomize()
	warning_label.hide()
	strike_sfx_player.stream = strike_sfx
	strike_sfx_player.volume_db = strike_sfx_volume_db
	strike_sfx_player.pitch_scale = clampf(
		strike_sfx_pitch_scale,
		0.25,
		4.0
	)
	strike_sfx_player.max_polyphony = maxi(
		strike_sfx_max_polyphony,
		1
	)
	strike_sfx_player.bus = (
		strike_sfx_bus
		if AudioServer.get_bus_index(strike_sfx_bus) >= 0
		else &"Master"
	)
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
	_crack_remaining = maxf(_crack_remaining - delta, 0.0)
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
	_update_warning_label()
	warning_label.position = to_local(_landing_position) + Vector2(-68.0, 76.0)
	warning_label.show()
	strike_warning_started.emit(
		_current_strike_index + 1,
		_landing_position
	)
	queue_redraw()


func _update_warning_label() -> void:
	warning_label.text = LanguageManager.text(
		"heavenly_strike_format"
	) % [
		_current_strike_index + 1,
		maxi(strike_count, 1),
	]


func _on_language_changed(_locale: String) -> void:
	if _phase == Phase.WARNING:
		_update_warning_label()


func _land_current_strike() -> void:
	_phase = Phase.FLASH
	_phase_time_remaining = maxf(flash_duration, 0.01)
	_crack_position = _landing_position
	_crack_remaining = maxf(crack_duration, flash_duration)
	warning_label.hide()
	if strike_sfx_player.stream != null:
		strike_sfx_player.play()
	var hit_player := (
		_player.global_position.distance_to(_landing_position)
		<= strike_radius
	)
	if hit_player:
		_player.take_melee_damage(get_current_strike_damage())
	camera_shake_requested.emit(maxf(camera_shake_strength, 0.0))
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
		_draw_impact_cracks()
		return
	var local_landing := to_local(_landing_position)
	if _phase == Phase.WARNING:
		_draw_warning_gather(local_landing)
		_draw_impact_cracks()
		return

	_draw_tapered_lightning(local_landing)
	_draw_impact_cracks()


func _get_warning_progress() -> float:
	if _phase != Phase.WARNING:
		return 0.0
	return 1.0 - clampf(
		_phase_time_remaining / maxf(_warning_duration, 0.01),
		0.0,
		1.0
	)


func _smooth_ratio(value: float) -> float:
	var ratio := clampf(value, 0.0, 1.0)
	return ratio * ratio * (3.0 - 2.0 * ratio)


func _draw_warning_gather(local_landing: Vector2) -> void:
	var progress := _get_warning_progress()
	var pulse := 0.94 + sin(Time.get_ticks_msec() * 0.012) * 0.04
	draw_circle(
		local_landing,
		strike_radius,
		Color(0.12, 0.48, 0.9, 0.1 + progress * 0.12)
	)
	draw_arc(
		local_landing,
		strike_radius * pulse,
		0.0,
		TAU,
		64,
		Color(0.38, 0.78, 1.0, 0.72 + progress * 0.23),
		3.0,
		true
	)

	var master_origin := (
		local_landing + Vector2(0.0, -strike_radius * 0.48)
	)
	var dive_ratio := _smooth_ratio(
		(progress - WARNING_ICON_DIVE_START)
			/ (1.0 - WARNING_ICON_DIVE_START)
	)
	var master_position := master_origin.lerp(local_landing, dive_ratio)
	var merged_count := 0
	for icon_index in WARNING_LIGHTNING_ICON_COUNT:
		var appearance_progress := (
			float(icon_index)
			/ float(WARNING_LIGHTNING_ICON_COUNT)
			* 0.54
		)
		if progress < appearance_progress:
			continue
		var angle := (
			float(icon_index) * 2.399963
			+ float(_current_strike_index) * 0.71
		)
		var radius_ratio := 0.22 + 0.68 * (
			float((icon_index * 7) % WARNING_LIGHTNING_ICON_COUNT)
			/ float(WARNING_LIGHTNING_ICON_COUNT - 1)
		)
		var start_position := (
			local_landing
			+ Vector2.from_angle(angle)
				* strike_radius * radius_ratio
		)
		var rise_ratio := clampf(
			(progress - appearance_progress) / 0.34,
			0.0,
			1.0
		)
		var rising_position := (
			start_position + Vector2(0.0, -28.0 * rise_ratio)
		)
		var merge_start := appearance_progress + 0.14
		var merge_ratio := _smooth_ratio(
			(progress - merge_start)
				/ maxf(WARNING_ICON_GATHER_END - merge_start, 0.01)
		)
		var icon_position := rising_position.lerp(
			master_origin,
			merge_ratio
		)
		var icon_alpha := 1.0 - _smooth_ratio(
			(merge_ratio - 0.72) / 0.28
		)
		if merge_ratio >= 0.98:
			merged_count += 1
		if icon_alpha <= 0.01:
			continue
		_draw_lightning_icon(
			icon_position,
			lerpf(8.0, 4.0, merge_ratio),
			Color(LIGHTNING_ICON_COLOR, icon_alpha)
		)

	var gather_ratio := clampf(
		float(merged_count) / float(WARNING_LIGHTNING_ICON_COUNT),
		0.0,
		1.0
	)
	var highlight_ratio := _smooth_ratio(
		(progress - 0.34) / 0.58
	)
	var final_charge := _smooth_ratio(
		(progress - 0.72) / 0.28
	)
	var master_color := LIGHTNING_ICON_COLOR.lerp(
		Color.WHITE,
		highlight_ratio
	)
	if final_charge > 0.0:
		draw_circle(
			master_position,
			18.0 + final_charge * 28.0,
			Color(0.65, 0.9, 1.0, final_charge * 0.08)
		)
		draw_circle(
			master_position,
			10.0 + final_charge * 14.0,
			Color(0.82, 0.95, 1.0, final_charge * 0.18)
		)
	_draw_lightning_icon(
		master_position,
		lerpf(13.0, 23.0, maxf(gather_ratio, final_charge)),
		master_color
	)


func _draw_lightning_icon(
	center: Vector2,
	icon_size: float,
	color: Color
) -> void:
	var icon_points := PackedVector2Array([
		center + Vector2(-0.18, -0.56) * icon_size,
		center + Vector2(0.24, -0.56) * icon_size,
		center + Vector2(0.02, -0.08) * icon_size,
		center + Vector2(0.34, -0.08) * icon_size,
		center + Vector2(-0.28, 0.62) * icon_size,
		center + Vector2(-0.08, 0.12) * icon_size,
		center + Vector2(-0.36, 0.12) * icon_size,
	])
	draw_colored_polygon(icon_points, color)


func _draw_tapered_lightning(local_landing: Vector2) -> void:
	var flash_ratio := clampf(
		_phase_time_remaining / maxf(flash_duration, 0.01),
		0.0,
		1.0
	)
	draw_circle(
		local_landing,
		strike_radius,
		Color(0.72, 0.92, 1.0, 0.34 + flash_ratio * 0.34)
	)
	var bolt_points := PackedVector2Array([
		local_landing + Vector2(-22.0, -300.0),
		local_landing + Vector2(18.0, -238.0),
		local_landing + Vector2(-14.0, -178.0),
		local_landing + Vector2(11.0, -119.0),
		local_landing + Vector2(-6.0, -60.0),
		local_landing,
	])
	for point_index in bolt_points.size() - 1:
		var width_ratio := (
			float(point_index) / float(bolt_points.size() - 2)
		)
		var outer_width := lerpf(30.0, 8.0, width_ratio)
		var inner_width := lerpf(18.0, 4.0, width_ratio)
		draw_line(
			bolt_points[point_index],
			bolt_points[point_index + 1],
			Color(0.22, 0.68, 1.0, 0.9),
			outer_width,
			true
		)
		draw_line(
			bolt_points[point_index],
			bolt_points[point_index + 1],
			Color(0.94, 0.99, 1.0, 1.0),
			inner_width,
			true
		)


func _draw_impact_cracks() -> void:
	if _crack_remaining <= 0.0:
		return
	var local_crack := to_local(_crack_position)
	var crack_alpha := clampf(
		_crack_remaining / maxf(crack_duration, 0.01),
		0.0,
		1.0
	)
	for branch_index in 7:
		var angle := (
			float(branch_index) / 7.0 * TAU
			+ float(_current_strike_index) * 0.19
		)
		var direction := Vector2.from_angle(angle)
		var tangent := direction.rotated(PI * 0.5)
		var first_end := (
			local_crack
			+ direction * (18.0 + float(branch_index % 3) * 3.0)
			+ tangent * (3.0 if branch_index % 2 == 0 else -3.0)
		)
		var second_end := (
			first_end
			+ direction * (15.0 + float((branch_index + 1) % 3) * 4.0)
			- tangent * (5.0 if branch_index % 2 == 0 else -5.0)
		)
		draw_line(
			local_crack,
			first_end,
			Color(0.02, 0.035, 0.08, crack_alpha * 0.92),
			4.0,
			true
		)
		draw_line(
			first_end,
			second_end,
			Color(0.02, 0.035, 0.08, crack_alpha * 0.82),
			3.0,
			true
		)
		draw_line(
			first_end,
			first_end
				+ direction.rotated(0.62 if branch_index % 2 == 0 else -0.62)
					* 11.0,
			Color(0.04, 0.09, 0.18, crack_alpha * 0.68),
			2.0,
			true
		)
