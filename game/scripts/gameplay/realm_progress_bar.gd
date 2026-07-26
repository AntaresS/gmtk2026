class_name RealmProgressBar
extends Control

signal infusion_finished

const SEGMENT_COUNT: int = 9
const LABEL_WIDTH: float = 148.0
const SEGMENT_GAP: float = 5.0
const SEGMENT_HEIGHT: float = 24.0
const INFUSION_DURATION: float = 1.08
const COMPLETION_FLASH_DURATION: float = 0.52
const REALM_COLORS: Array[Color] = [
	Color("ffffff"),
	Color("2788ff"),
	Color("45f3ff"),
	Color("ffd35a"),
]

var _realm_index: int = 0
var _realm_name: String = "练气境"
var _layer: int = 1
var _pending_state: Dictionary = {}
var _infusion_elapsed: float = 0.0
var _completion_flash_remaining: float = 0.0
var _preview_current_completed: bool = false
var _last_completed_segment: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 46.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	queue_redraw()


## Updates the displayed major realm and its current one-based minor layer.
## During a Qi infusion, the new state waits until the energy reaches the
## outlined segment so the fill change reads as the result of that animation.
func configure_state(
	realm_index: int,
	realm_name: String,
	layer: int,
	_layer_count: int
) -> void:
	var state := {
		"realm_index": clampi(realm_index, 0, REALM_COLORS.size() - 1),
		"realm_name": realm_name,
		"layer": clampi(layer, 1, SEGMENT_COUNT),
	}
	if is_infusion_active():
		_pending_state = state
		return
	_apply_state(state)


## Starts a bottom-up Qi stream into the currently outlined minor-realm slot.
func play_qi_infusion() -> void:
	if is_infusion_active():
		return
	_infusion_elapsed = 0.0001
	_completion_flash_remaining = 0.0
	set_process(true)
	queue_redraw()


func is_infusion_active() -> bool:
	return _infusion_elapsed > 0.0


## Returns normalized progress for synchronizing the separate Qi bar fade with
## this control's gather, stream, and impact phases.
func get_infusion_progress() -> float:
	if not is_infusion_active():
		return 0.0
	return clampf(_infusion_elapsed / INFUSION_DURATION, 0.0, 1.0)


## Returns the active major-realm color used by both the nine segments and the
## separate Qi bar so their progression language remains consistent.
func get_current_realm_color() -> Color:
	return REALM_COLORS[clampi(_realm_index, 0, REALM_COLORS.size() - 1)]


func _process(delta: float) -> void:
	if is_infusion_active():
		_infusion_elapsed += maxf(delta, 0.0)
		if _infusion_elapsed >= INFUSION_DURATION:
			_infusion_elapsed = 0.0
			if not _pending_state.is_empty():
				_apply_state(_pending_state)
				_pending_state = {}
				_last_completed_segment = clampi(
					_layer - 2,
					0,
					SEGMENT_COUNT - 1
				)
			else:
				_preview_current_completed = true
				_last_completed_segment = clampi(
					_layer - 1,
					0,
					SEGMENT_COUNT - 1
				)
			_completion_flash_remaining = COMPLETION_FLASH_DURATION
			infusion_finished.emit()
	if _completion_flash_remaining > 0.0:
		_completion_flash_remaining = maxf(
			_completion_flash_remaining - delta,
			0.0
		)
	queue_redraw()
	if not is_infusion_active() and _completion_flash_remaining <= 0.0:
		set_process(false)


func _draw() -> void:
	var realm_color := get_current_realm_color()
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(0.0, 31.0),
		LanguageManager.text("realm_progress_format") % [
			_realm_name,
			_layer,
		],
		HORIZONTAL_ALIGNMENT_LEFT,
		LABEL_WIDTH - 8.0,
		22,
		Color.WHITE
	)
	var segment_area_width := maxf(size.x - LABEL_WIDTH, 180.0)
	var segment_width := (
		segment_area_width - SEGMENT_GAP * float(SEGMENT_COUNT - 1)
	) / float(SEGMENT_COUNT)
	var segment_y := 10.0
	var completed_count := clampi(
		_layer if _preview_current_completed else _layer - 1,
		0,
		SEGMENT_COUNT
	)
	var current_index := clampi(_layer - 1, 0, SEGMENT_COUNT - 1)
	for segment_index in SEGMENT_COUNT:
		var rect := Rect2(
			Vector2(
				LABEL_WIDTH
					+ float(segment_index) * (segment_width + SEGMENT_GAP),
				segment_y
			),
			Vector2(segment_width, SEGMENT_HEIGHT)
		)
		if segment_index < completed_count:
			draw_rect(rect, Color(realm_color, 0.9), true)
			draw_rect(rect, realm_color.lightened(0.25), false, 2.0)
		elif segment_index == current_index and not _preview_current_completed:
			draw_rect(rect, Color(0.02, 0.04, 0.065, 0.38), true)
			draw_rect(rect, realm_color, false, 3.0)
		else:
			draw_rect(rect, Color(0.02, 0.04, 0.065, 0.28), true)
			draw_rect(rect, Color(0.5, 0.58, 0.68, 0.42), false, 1.0)
	if is_infusion_active():
		_draw_infusion(
			_get_segment_center(current_index, segment_width, segment_y),
			realm_color
		)
	elif _completion_flash_remaining > 0.0:
		var flash_ratio := (
			_completion_flash_remaining / COMPLETION_FLASH_DURATION
		)
		var completed_center := _get_segment_center(
			_last_completed_segment,
			segment_width,
			segment_y
		)
		draw_circle(
			completed_center,
			16.0 + (1.0 - flash_ratio) * 14.0,
			Color(realm_color, flash_ratio * 0.28)
		)
		draw_arc(
			completed_center,
			11.0 + (1.0 - flash_ratio) * 10.0,
			0.0,
			TAU,
			32,
			Color(realm_color.lightened(0.35), flash_ratio * 0.8),
			2.0,
			true
		)


func _draw_infusion(target: Vector2, realm_color: Color) -> void:
	var progress := get_infusion_progress()
	var source_y := size.y + 17.0
	var source := Vector2(target.x, source_y)
	var gather_progress := _ease_in_out(
		clampf(progress / 0.28, 0.0, 1.0)
	)
	var bar_left := LABEL_WIDTH + 2.0
	var bar_right := size.x - 2.0
	var gathered_left := lerpf(bar_left, target.x - 5.0, gather_progress)
	var gathered_right := lerpf(bar_right, target.x + 5.0, gather_progress)
	var gather_width := lerpf(13.0, 8.0, gather_progress)
	draw_line(
		Vector2(gathered_left, source_y),
		Vector2(gathered_right, source_y),
		Color(realm_color, 0.18 + gather_progress * 0.4),
		gather_width + 8.0,
		true
	)
	draw_line(
		Vector2(gathered_left, source_y),
		Vector2(gathered_right, source_y),
		Color(realm_color.lightened(0.18), 0.9),
		gather_width,
		true
	)

	if progress < 0.16:
		var surface_wave := sin(progress * 42.0) * 2.0
		draw_circle(
			Vector2(target.x, source_y + surface_wave),
			5.0 + gather_progress * 3.0,
			Color(realm_color.lightened(0.35), 0.65)
		)
		return

	var rise_progress := clampf((progress - 0.16) / 0.68, 0.0, 1.0)
	var head_t := 1.0 - pow(1.0 - rise_progress, 3.0)
	var tail_t := clampf((rise_progress - 0.48) / 0.52, 0.0, 1.0)
	tail_t = _ease_in_out(tail_t) * 0.93
	var center_x := (LABEL_WIDTH + size.x) * 0.5
	var bend_direction := -1.0 if target.x >= center_x else 1.0
	var bend := 24.0 + absf(target.x - center_x) * 0.08
	var control_a := source + Vector2(bend_direction * bend, -14.0)
	var control_b := target + Vector2(-bend_direction * bend * 0.72, 22.0)
	_draw_tapered_stream(
		source,
		control_a,
		control_b,
		target,
		tail_t,
		head_t,
		15.0,
		Color(realm_color, 0.16)
	)
	_draw_tapered_stream(
		source,
		control_a,
		control_b,
		target,
		tail_t,
		head_t,
		7.0,
		Color(realm_color.lightened(0.16), 0.78)
	)
	_draw_tapered_stream(
		source,
		control_a,
		control_b,
		target,
		tail_t,
		head_t,
		2.0,
		Color(1.0, 1.0, 1.0, 0.86)
	)

	for particle_index in 4:
		var particle_t := head_t - 0.07 * float(particle_index + 1)
		if particle_t <= tail_t:
			continue
		var particle_position := _cubic_bezier(
			source,
			control_a,
			control_b,
			target,
			particle_t
		)
		var drift := sin(
			progress * 25.0 + float(particle_index) * 2.1
		) * 3.0
		particle_position.x += drift
		draw_circle(
			particle_position,
			2.8 - float(particle_index) * 0.38,
			Color(realm_color.lightened(0.42), 0.72)
		)

	var head := _cubic_bezier(
		source,
		control_a,
		control_b,
		target,
		head_t
	)
	var head_pulse := 0.5 + sin(progress * 34.0) * 0.5
	draw_circle(
		head,
		8.0 + head_pulse * 2.5,
		Color(realm_color, 0.2)
	)
	draw_circle(
		head,
		4.2 + head_pulse,
		Color(realm_color.lightened(0.52), 0.95)
	)

	if progress > 0.72:
		var impact := _ease_out(clampf((progress - 0.72) / 0.28, 0.0, 1.0))
		draw_circle(
			target,
			5.0 + impact * 16.0,
			Color(realm_color, (1.0 - impact) * 0.34)
		)
		draw_arc(
			target,
			7.0 + impact * 13.0,
			0.0,
			TAU,
			28,
			Color(
				realm_color.lightened(0.42),
				(1.0 - impact) * 0.92
			),
			2.2,
			true
		)


func _draw_tapered_stream(
	start: Vector2,
	control_a: Vector2,
	control_b: Vector2,
	end: Vector2,
	from_t: float,
	to_t: float,
	maximum_width: float,
	color: Color
) -> void:
	if to_t <= from_t:
		return
	const SAMPLE_COUNT: int = 16
	var previous_point := _cubic_bezier(
		start,
		control_a,
		control_b,
		end,
		from_t
	)
	for sample_index in SAMPLE_COUNT + 1:
		var ratio := float(sample_index) / float(SAMPLE_COUNT)
		var curve_t := lerpf(from_t, to_t, ratio)
		var point := _cubic_bezier(
			start,
			control_a,
			control_b,
			end,
			curve_t
		)
		var taper := sin(ratio * PI)
		var width := maximum_width * (0.22 + taper * 0.78)
		if sample_index > 0:
			draw_line(previous_point, point, color, width, true)
		previous_point = point


func _cubic_bezier(
	start: Vector2,
	control_a: Vector2,
	control_b: Vector2,
	end: Vector2,
	t: float
) -> Vector2:
	var inverse := 1.0 - t
	return (
		start * inverse * inverse * inverse
		+ control_a * 3.0 * inverse * inverse * t
		+ control_b * 3.0 * inverse * t * t
		+ end * t * t * t
	)


func _ease_in_out(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


func _ease_out(value: float) -> float:
	return 1.0 - pow(1.0 - value, 3.0)


func _get_segment_center(
	segment_index: int,
	segment_width: float,
	segment_y: float
) -> Vector2:
	return Vector2(
		LABEL_WIDTH
			+ float(segment_index) * (segment_width + SEGMENT_GAP)
			+ segment_width * 0.5,
		segment_y + SEGMENT_HEIGHT * 0.5
	)


func _apply_state(state: Dictionary) -> void:
	_realm_index = int(state.get("realm_index", 0))
	_realm_name = str(state.get("realm_name", "境界"))
	_layer = int(state.get("layer", 1))
	_preview_current_completed = false
	queue_redraw()
