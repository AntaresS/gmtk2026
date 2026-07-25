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
var _collecting_player: PlayerController
var _vertical_drift_speed: float = 140.0
var _road_x_clamp: Callable
var _link_phase: float = 0.0


func _ready() -> void:
	add_to_group("elite_reward_choices")


func _process(delta: float) -> void:
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
		"二选一",
		HORIZONTAL_ALIGNMENT_CENTER,
		label_rect.size.x,
		12,
		Color(0.96, 0.98, 1.0, 1.0)
	)


func _physics_process(delta: float) -> void:
	var vertical_velocity := -maxf(_vertical_drift_speed, 1.0)
	for group_node in get_tree().get_nodes_in_group("elite_reward_choices"):
		if group_node is not EliteRewardChoice:
			continue
		var choice_group := group_node as EliteRewardChoice
		if choice_group.has_focused_option():
			vertical_velocity = choice_group.get_player_vertical_velocity()
			break
	global_position.y += vertical_velocity * maxf(delta, 0.0)
	if _road_x_clamp.is_valid():
		global_position.x = float(
			_road_x_clamp.call(global_position.x, global_position.y)
		)


## Configures shared forward motion for this pair. Every active pair adopts the
## collecting player's live vertical velocity while any option is focused,
## preserving inter-pair spacing throughout the one-second channel.
func configure_motion(
	player: PlayerController,
	vertical_drift_speed: float,
	road_x_clamp: Callable
) -> void:
	_collecting_player = player
	_vertical_drift_speed = maxf(vertical_drift_speed, 1.0)
	_road_x_clamp = road_x_clamp


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


## Reports whether the player is currently channeling either option.
func has_focused_option() -> bool:
	return is_instance_valid(_focused_option)


## Returns the collecting player's forward-only vertical velocity in world
## pixels per second. Zero pauses all pairs if the player is momentarily still.
func get_player_vertical_velocity() -> float:
	if not is_instance_valid(_collecting_player):
		return -maxf(_vertical_drift_speed, 1.0)
	return minf(_collecting_player.velocity.y, 0.0)


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
