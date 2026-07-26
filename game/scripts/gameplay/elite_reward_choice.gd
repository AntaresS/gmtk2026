class_name EliteRewardChoice
extends Node2D

enum RewardKind {
	WEAPON,
	POWER_FRAGMENT,
}

## Runtime reward category used by placement checks and diagnostics.
var reward_kind: RewardKind = RewardKind.WEAPON

var _options: Array[Node2D] = []
var _focused_option: Node2D
var _committed: bool = false
var _initialized: bool = false
var _vertical_drift_speed: float = 140.0
var _road_x_clamp: Callable
var _link_phase: float = 0.0
var _tracking_camera: Camera2D
var _offscreen_despawn_margin: float = 200.0
var _maximum_lifetime_seconds: float = 30.0
var _elapsed_lifetime_seconds: float = 0.0


func _ready() -> void:
	add_to_group("elite_reward_choices")


func _process(delta: float) -> void:
	_elapsed_lifetime_seconds += maxf(delta, 0.0)
	if _has_lifetime_expired() or _is_beyond_camera_margin():
		queue_free()
		return
	if not _initialized:
		return
	_link_phase = fmod(_link_phase + maxf(delta, 0.0) * 2.8, TAU)
	queue_redraw()
	for option in _options:
		if is_instance_valid(option) and not option.is_queued_for_deletion():
			return
	queue_free()


func _draw() -> void:
	if _options.size() < 2:
		return
	var first_option := _options[0]
	var second_option := _options[1]
	if not is_instance_valid(first_option) or not is_instance_valid(second_option):
		return
	var left_x := minf(first_option.position.x, second_option.position.x)
	var right_x := maxf(first_option.position.x, second_option.position.x)
	var center_x := (left_x + right_x) * 0.5
	var bracket_y := -maxf(get_pair_link_span() * 0.56, 52.0)
	var stem_bottom_y := -34.0
	var center := Vector2(center_x, bracket_y)
	var pair_color := (
		Color("55d8ff")
		if reward_kind == RewardKind.WEAPON
		else Color("d98cff")
	)
	var pulse := 0.82 + sin(_link_phase) * 0.12
	var focused := is_instance_valid(_focused_option)
	var bracket_alpha := 0.4 if focused else pulse
	var bracket := PackedVector2Array([
		Vector2(left_x, stem_bottom_y),
		Vector2(left_x, bracket_y),
		Vector2(right_x, bracket_y),
		Vector2(right_x, stem_bottom_y),
	])
	draw_polyline(bracket, Color(0.02, 0.025, 0.06, 0.92), 9.0, true)
	draw_polyline(
		bracket,
		Color(pair_color, bracket_alpha),
		4.0,
		true
	)
	if focused:
		var focused_left := _focused_option.position.x < center_x
		var focused_bracket := (
			PackedVector2Array([
				Vector2(left_x, stem_bottom_y),
				Vector2(left_x, bracket_y),
				center,
			])
			if focused_left
			else PackedVector2Array([
				center,
				Vector2(right_x, bracket_y),
				Vector2(right_x, stem_bottom_y),
			])
		)
		draw_polyline(
			focused_bracket,
			Color(pair_color.lerp(Color.WHITE, 0.38), 1.0),
			5.0,
			true
		)
	draw_circle(center, 13.0, Color(0.02, 0.025, 0.06, 0.96))
	draw_arc(
		center + Vector2(-4.0, 0.0),
		6.5,
		-2.25,
		2.25,
		18,
		Color(pair_color, 0.98),
		3.0,
		true
	)
	draw_arc(
		center + Vector2(4.0, 0.0),
		6.5,
		PI - 2.25,
		PI + 2.25,
		18,
		Color(pair_color, 0.98),
		3.0,
		true
	)
	var label_rect := Rect2(
		Vector2(center_x - 27.0, bracket_y - 31.0),
		Vector2(54.0, 18.0)
	)
	draw_rect(label_rect, Color(0.02, 0.025, 0.06, 0.9), true)
	draw_rect(label_rect, Color(pair_color, 0.78), false, 1.5)
	draw_string(
		ThemeDB.fallback_font,
		label_rect.position + Vector2(0.0, 13.0),
		_get_lifetime_label(),
		HORIZONTAL_ALIGNMENT_CENTER,
		label_rect.size.x,
		12,
		Color(0.96, 0.98, 1.0, 1.0)
	)


func _physics_process(delta: float) -> void:
	global_position.y -= (
		maxf(_vertical_drift_speed, 1.0) * maxf(delta, 0.0)
	)
	if _road_x_clamp.is_valid():
		global_position.x = float(
			_road_x_clamp.call(global_position.x, global_position.y)
		)


## Configures this pair's independent forward drift and road clamping. Focus
## affects only selection feedback and never inherits player or sibling-pair
## motion, so the player must regulate their own speed to synchronize.
func configure_motion(
	vertical_drift_speed: float,
	road_x_clamp: Callable
) -> void:
	_vertical_drift_speed = maxf(vertical_drift_speed, 1.0)
	_road_x_clamp = road_x_clamp


## Configures cleanup for an unclaimed pair. The group is removed when its
## center leaves the camera bounds by more than offscreen_margin world pixels,
## or when lifetime_seconds elapses. A zero lifetime disables only the timer.
func configure_lifecycle(
	tracking_camera: Camera2D,
	offscreen_margin: float,
	lifetime_seconds: float
) -> void:
	_tracking_camera = tracking_camera
	_offscreen_despawn_margin = maxf(offscreen_margin, 0.0)
	_maximum_lifetime_seconds = maxf(lifetime_seconds, 0.0)
	_elapsed_lifetime_seconds = 0.0


## Adds one mutually exclusive reward at a fixed local offset. Reward scripts
## publish focus and commitment signals so this owner can coordinate both
## visuals and remove the unchosen counterpart.
func add_option(option: Node2D, local_offset: Vector2) -> void:
	if option == null:
		return
	_initialized = true
	_options.append(option)
	add_child(option)
	option.position = local_offset
	queue_redraw()
	if option.has_method("enable_exclusive_choice"):
		option.call("enable_exclusive_choice")
	if option.has_signal("choice_focus_changed"):
		option.connect(
			"choice_focus_changed",
			Callable(self, "_on_option_focus_changed")
		)
	if option.has_signal("choice_committed"):
		option.connect(
			"choice_committed",
			Callable(self, "_on_option_committed")
		)


## Returns the two runtime reward nodes for diagnostics and focused tests.
func get_options() -> Array[Node2D]:
	return _options.duplicate()


## Reports whether one option has completed its channel.
func is_committed() -> bool:
	return _committed


## Returns the horizontal world-pixel span joined by the pair bracket.
func get_pair_link_span() -> float:
	if _options.size() < 2:
		return 0.0
	if not is_instance_valid(_options[0]) or not is_instance_valid(_options[1]):
		return 0.0
	return absf(_options[0].position.x - _options[1].position.x)


## Returns the remaining timer life in seconds, or -1 when timer cleanup is
## disabled.
func get_remaining_lifetime_seconds() -> float:
	if _maximum_lifetime_seconds <= 0.0:
		return -1.0
	return maxf(
		_maximum_lifetime_seconds - _elapsed_lifetime_seconds,
		0.0
	)


func _get_lifetime_label() -> String:
	var remaining_seconds := get_remaining_lifetime_seconds()
	if remaining_seconds < 0.0:
		return "∞"
	return LanguageManager.text("countdown_seconds") % ceili(
		remaining_seconds
	)


func _has_lifetime_expired() -> bool:
	return (
		_maximum_lifetime_seconds > 0.0
		and _elapsed_lifetime_seconds >= _maximum_lifetime_seconds
	)


func _is_beyond_camera_margin() -> bool:
	if not is_instance_valid(_tracking_camera):
		return false
	var viewport_size := get_viewport_rect().size
	var camera_zoom := Vector2(
		maxf(absf(_tracking_camera.zoom.x), 0.01),
		maxf(absf(_tracking_camera.zoom.y), 0.01)
	)
	var half_visible_size := viewport_size / camera_zoom * 0.5
	var expanded_half_size := (
		half_visible_size
		+ Vector2.ONE * _offscreen_despawn_margin
	)
	var offset := global_position - _tracking_camera.global_position
	return (
		absf(offset.x) > expanded_half_size.x
		or absf(offset.y) > expanded_half_size.y
	)


func _on_option_focus_changed(option: Node2D, focused: bool) -> void:
	if _committed or not is_instance_valid(option):
		return
	if focused:
		_focused_option = option
	elif _focused_option == option:
		_focused_option = null
	else:
		return
	_refresh_option_visuals()
	queue_redraw()


func _on_option_committed(option: Node2D) -> void:
	if _committed or not is_instance_valid(option):
		return
	_committed = true
	_focused_option = option
	for candidate in _options:
		if not is_instance_valid(candidate):
			continue
		if candidate == option:
			if candidate.has_method("set_choice_visual_state"):
				candidate.call("set_choice_visual_state", true, false)
			continue
		if candidate.has_method("dismiss_choice"):
			candidate.call("dismiss_choice")
	queue_redraw()


func _refresh_option_visuals() -> void:
	for option in _options:
		if not is_instance_valid(option):
			continue
		if option.has_method("set_choice_visual_state"):
			option.call(
				"set_choice_visual_state",
				option == _focused_option,
				_focused_option != null and option != _focused_option
			)
