class_name RunEndedOverlay
extends CanvasLayer

signal restart_requested
signal main_menu_requested

const SLOW_MOTION_SCALE: float = 0.22
const SLOW_MOTION_DURATION: float = 0.7
const EPITAPH_IMPACT_DURATION: float = 0.22
const EPITAPH_HOLD_DURATION: float = 1.15
const DIM_DURATION: float = 0.42
const PANEL_REVEAL_DURATION: float = 0.48
const PANEL_SLIDE_DISTANCE: float = 220.0

@onready var overlay: Control = $Overlay
@onready var dim_rect: ColorRect = $Overlay/Dim
@onready var panel: PanelContainer = %Panel
@onready var epitaph_label: Label = %Epitaph
@onready var skip_hint_label: Label = %SkipHint
@onready var title_label: Label = %Title
@onready var outcome_message_label: Label = %OutcomeMessage
@onready var summary_title_label: Label = %SummaryTitle
@onready var duration_caption_label: Label = %DurationCaption
@onready var duration_value_label: Label = %DurationValue
@onready var damage_caption_label: Label = %DamageCaption
@onready var damage_value_label: Label = %DamageValue
@onready var enemies_caption_label: Label = %EnemiesCaption
@onready var enemies_value_label: Label = %EnemiesValue
@onready var loadout_title_label: Label = %LoadoutTitle
@onready var loadout_value_label: Label = %LoadoutValue
@onready var ranking_title_label: Label = %RankingTitle
@onready var ranking_label: RichTextLabel = %Ranking
@onready var leaderboard_title_label: Label = %LeaderboardTitle
@onready var leaderboard_label: RichTextLabel = %Leaderboard
@onready var restart_button: Button = %RestartButton
@onready var main_menu_button: Button = %MainMenuButton

var _outcome_key: String = ""
var _summary: Dictionary = {}
var _leaderboard_entries: Array[Dictionary] = []
var _current_run_id: String = ""
var _leaderboard_recorded: bool = false
var _current_cycle_number: int = 1
var _reveal_tween: Tween
var _sequence_playing: bool = false
var _can_skip_reveal: bool = false
var _panel_rest_position: Vector2 = Vector2.ZERO
var _panel_rest_position_recorded: bool = false
var _previous_time_scale: float = 1.0
var _slow_motion_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	LanguageManager.language_changed.connect(_on_language_changed)
	_refresh_language()
	hide()


func _exit_tree() -> void:
	_stop_reveal_tween()
	_restore_time_scale()


func _input(event: InputEvent) -> void:
	if not visible or not _sequence_playing or not _can_skip_reveal:
		return
	var pointer_pressed: bool = false
	if event is InputEventMouseButton:
		pointer_pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pointer_pressed = (event as InputEventScreenTouch).pressed
	if not pointer_pressed:
		return
	get_viewport().set_input_as_handled()
	_complete_reveal_immediately()


## Reveals the non-pausing controls for a lifespan-depletion defeat and records
## the supplied immutable run summary in the local survival leaderboard.
func show_defeat(summary: Dictionary = {}) -> void:
	_show_outcome("lifespan_depleted", summary)


## Reveals the non-pausing controls for completing the ninth breakthrough.
func show_ascension(summary: Dictionary = {}) -> void:
	_show_outcome("ascension_complete", summary)


## Reveals the authored endpoint reached by attempting to break through beyond
## Nascent Soul layer nine.
func show_fatal_breakthrough(summary: Dictionary = {}) -> void:
	_show_outcome("fatal_breakthrough", summary)


func _show_outcome(outcome_key: String, summary: Dictionary) -> void:
	_outcome_key = outcome_key
	_summary = summary.duplicate(true)
	_record_leaderboard_entry()
	_refresh_language()
	_prepare_reveal()
	show()
	call_deferred("_play_reveal_sequence")


func _prepare_reveal() -> void:
	_stop_reveal_tween()
	_restore_time_scale()
	_sequence_playing = true
	_can_skip_reveal = _current_cycle_number >= 2
	restart_button.disabled = true
	main_menu_button.disabled = true
	dim_rect.modulate.a = 0.0
	panel.modulate.a = 0.0
	epitaph_label.modulate.a = 0.0
	epitaph_label.scale = Vector2.ONE * 1.55
	skip_hint_label.visible = _can_skip_reveal
	skip_hint_label.modulate.a = 0.0


func _play_reveal_sequence() -> void:
	if not visible or not _sequence_playing:
		return
	if not _panel_rest_position_recorded:
		_panel_rest_position = panel.position
		_panel_rest_position_recorded = true
	panel.position = (
		_panel_rest_position + Vector2(0.0, PANEL_SLIDE_DISTANCE)
	)
	epitaph_label.pivot_offset = epitaph_label.size * 0.5
	_begin_slow_motion()

	_reveal_tween = create_tween()
	_reveal_tween.set_ignore_time_scale(true)
	_reveal_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _can_skip_reveal:
		_reveal_tween.tween_property(
			skip_hint_label,
			"modulate:a",
			1.0,
			0.25
		)
	else:
		_reveal_tween.tween_interval(0.25)
	_reveal_tween.tween_interval(
		maxf(SLOW_MOTION_DURATION - 0.25, 0.0)
	)
	_reveal_tween.tween_callback(_trigger_epitaph_impact)
	_reveal_tween.tween_property(
		epitaph_label,
		"scale",
		Vector2.ONE * 0.94,
		EPITAPH_IMPACT_DURATION
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_reveal_tween.parallel().tween_property(
		epitaph_label,
		"modulate:a",
		1.0,
		EPITAPH_IMPACT_DURATION * 0.45
	)
	_reveal_tween.tween_property(
		epitaph_label,
		"scale",
		Vector2.ONE,
		0.12
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_callback(_restore_time_scale)
	_reveal_tween.tween_interval(EPITAPH_HOLD_DURATION)
	_reveal_tween.tween_property(
		dim_rect,
		"modulate:a",
		1.0,
		DIM_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reveal_tween.parallel().tween_property(
		epitaph_label,
		"modulate:a",
		0.42,
		DIM_DURATION
	)
	_reveal_tween.tween_property(
		panel,
		"position",
		_panel_rest_position,
		PANEL_REVEAL_DURATION
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_reveal_tween.parallel().tween_property(
		panel,
		"modulate:a",
		1.0,
		PANEL_REVEAL_DURATION * 0.75
	)
	_reveal_tween.parallel().tween_property(
		epitaph_label,
		"modulate:a",
		0.0,
		PANEL_REVEAL_DURATION * 0.65
	)
	_reveal_tween.parallel().tween_property(
		skip_hint_label,
		"modulate:a",
		0.0,
		PANEL_REVEAL_DURATION * 0.5
	)
	_reveal_tween.tween_callback(_complete_reveal)


func _trigger_epitaph_impact() -> void:
	var gameplay := get_parent()
	if gameplay != null and gameplay.has_method("request_camera_shake"):
		gameplay.call("request_camera_shake", 10.0)


func _begin_slow_motion() -> void:
	if _slow_motion_active:
		return
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = minf(
		maxf(_previous_time_scale, 0.01),
		SLOW_MOTION_SCALE
	)
	_slow_motion_active = true


func _restore_time_scale() -> void:
	if not _slow_motion_active:
		return
	Engine.time_scale = _previous_time_scale
	_slow_motion_active = false


func _complete_reveal_immediately() -> void:
	_stop_reveal_tween()
	_restore_time_scale()
	if not _panel_rest_position_recorded:
		_panel_rest_position = panel.position
		_panel_rest_position_recorded = true
	dim_rect.modulate.a = 1.0
	epitaph_label.modulate.a = 0.0
	epitaph_label.scale = Vector2.ONE
	panel.position = _panel_rest_position
	panel.modulate.a = 1.0
	skip_hint_label.modulate.a = 0.0
	_complete_reveal()


func _complete_reveal() -> void:
	_restore_time_scale()
	_sequence_playing = false
	skip_hint_label.hide()
	restart_button.disabled = false
	main_menu_button.disabled = false
	restart_button.grab_focus()


func _stop_reveal_tween() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null


func _on_language_changed(_locale: String) -> void:
	_refresh_language()


func _refresh_language() -> void:
	restart_button.text = LanguageManager.text("restart")
	main_menu_button.text = LanguageManager.text("main_menu")
	if not _outcome_key.is_empty():
		title_label.text = LanguageManager.text(_outcome_key)
	outcome_message_label.text = (
		LanguageManager.text("fatal_world_unstable")
		if bool(_summary.get("fatal_breakthrough", false))
		else LanguageManager.text("ordinary_run_ended")
	)
	epitaph_label.text = _build_epitaph_text()
	skip_hint_label.text = LanguageManager.text("skip_run_reveal")
	summary_title_label.text = LanguageManager.text("run_summary")
	duration_caption_label.text = LanguageManager.text("result_duration")
	damage_caption_label.text = LanguageManager.text("result_damage")
	enemies_caption_label.text = LanguageManager.text("result_enemies")
	loadout_title_label.text = LanguageManager.text("result_loadout")
	ranking_title_label.text = LanguageManager.text(
		"result_damage_breakdown"
	)
	leaderboard_title_label.text = LanguageManager.text(
		"local_survival_leaderboard"
	)
	_refresh_summary_text()
	_refresh_leaderboard_text()


func _build_epitaph_text() -> String:
	var lifespan_text := _format_duration(
		float(_summary.get("duration_seconds", 0.0))
	)
	var realm_name := LanguageManager.get_realm_name(
		str(_summary.get("realm_name", "境界"))
	)
	var realm_text := LanguageManager.text("epitaph_realm_format") % [
		realm_name,
		maxi(int(_summary.get("realm_layer", 1)), 1),
	]
	var epitaph_key := (
		"fatal_death_epitaph"
		if bool(_summary.get("fatal_breakthrough", false))
		else "death_epitaph"
	)
	return LanguageManager.text(epitaph_key) % [
		lifespan_text,
		realm_text,
	]


func _refresh_summary_text() -> void:
	if _summary.is_empty():
		duration_value_label.text = "—"
		damage_value_label.text = "—"
		enemies_value_label.text = "—"
		loadout_value_label.text = "—"
		ranking_label.text = ""
		return

	duration_value_label.text = _format_duration(
		float(_summary.get("duration_seconds", 0.0))
	)
	damage_value_label.text = "%d" % int(
		_summary.get("total_damage", 0)
	)
	enemies_value_label.text = "%d  ·  %s %d" % [
		int(_summary.get("enemies_defeated", 0)),
		LanguageManager.text("elite").to_upper(),
		int(_summary.get("elite_enemies_defeated", 0)),
	]

	var weapon_level_parts: PackedStringArray = []
	for weapon_variant in _summary.get("weapon_levels", []):
		var weapon := weapon_variant as Dictionary
		weapon_level_parts.append(
			"%s Lv.%d" % [
				_get_source_name(weapon),
				int(weapon.get("level", 1)),
			]
		)
	loadout_value_label.text = (
		"  ·  ".join(weapon_level_parts)
		if not weapon_level_parts.is_empty()
		else "—"
	)

	var ranking_cells := PackedStringArray(["[table=2]"])
	var ranking_index := 1
	for ranking_variant in _summary.get("weapon_damage_ranking", []):
		var ranking := ranking_variant as Dictionary
		ranking_cells.append(
			(
				"[cell][color=#77798a]%02d[/color]  "
				+ "[color=#d4d5df]%s[/color][/cell]"
			) % [
				ranking_index,
				_get_source_name(ranking),
			]
		)
		ranking_cells.append(
			"[cell][right][color=#aeb0ff][b]%d[/b][/color][/right][/cell]"
			% int(ranking.get("damage", 0))
		)
		ranking_index += 1
	ranking_cells.append("[/table]")
	ranking_label.text = (
		"\n".join(ranking_cells)
		if ranking_index > 1
		else LanguageManager.text("no_damage_recorded")
	)


func _get_source_name(entry: Dictionary) -> String:
	var source_id := StringName(entry.get("weapon_id", &""))
	if source_id == &"realm_echo":
		return LanguageManager.text("realm_echo")
	if source_id == &"other":
		return LanguageManager.text("other_damage")
	return LanguageManager.get_weapon_name(
		source_id,
		str(entry.get("fallback_name", source_id))
	)


func _record_leaderboard_entry() -> void:
	if _leaderboard_recorded or _summary.is_empty():
		return
	_leaderboard_recorded = true
	var result := LeaderboardStore.record_summary(_summary)
	var current_entry := result.get("entry", {}) as Dictionary
	_current_run_id = str(current_entry.get("run_id", ""))
	_current_cycle_number = maxi(
		int(current_entry.get("cycle_number", 1)),
		1
	)
	_leaderboard_entries.assign(result.get("entries", []))


func _refresh_leaderboard_text() -> void:
	if _leaderboard_entries.is_empty():
		leaderboard_label.text = (
			"[center][color=#77798a]%s[/color][/center]"
			% LanguageManager.text("no_local_records")
		)
		return

	var lines := PackedStringArray(["[table=5]"])
	for heading_key in [
		"leaderboard_rank",
		"leaderboard_cycle",
		"leaderboard_survival",
		"leaderboard_damage",
		"leaderboard_top_weapon",
	]:
		lines.append(_table_cell(
			LanguageManager.text(heading_key).to_upper(),
			"#77798a",
			true
		))
	for entry_index in _leaderboard_entries.size():
		var entry := _leaderboard_entries[entry_index]
		var is_current := str(entry.get("run_id", "")) == _current_run_id
		var row_color := "#b8b9ff" if is_current else "#c8c9d3"
		var rank_text := (
			"▶ %02d" % (entry_index + 1)
			if is_current
			else "%02d" % (entry_index + 1)
		)
		lines.append(_table_cell(rank_text, row_color, is_current))
		var cycle_text := LanguageManager.text("cycle_number_format") % int(
			entry.get("cycle_number", entry_index + 1)
		)
		if bool(entry.get("fatal_breakthrough", false)):
			cycle_text += "\n[color=#c88f87][font_size=11]%s[/font_size][/color]" % (
				LanguageManager.text("heaven_suppressed").to_upper()
			)
		lines.append(_table_cell(cycle_text, row_color, false))
		lines.append(_table_cell(
			_format_duration(float(entry.get("duration_seconds", 0.0))),
			"#aeb0ff" if is_current else "#d6d7df",
			true
		))
		lines.append(_table_cell(
			"%d" % int(entry.get("total_damage", 0)),
			row_color,
			false
		))
		lines.append(_table_cell(
			_get_entry_top_weapon_name(entry),
			row_color,
			false
		))
	lines.append("[/table]")
	leaderboard_label.text = "".join(lines)


func _table_cell(value: String, color: String, bold: bool) -> String:
	var content := "[b]%s[/b]" % value if bold else value
	return "[cell][color=%s]%s[/color][/cell]" % [color, content]


func _get_entry_top_weapon_name(entry: Dictionary) -> String:
	var weapon_id := StringName(entry.get("top_weapon_id", &""))
	if weapon_id.is_empty():
		return LanguageManager.text("no_damage_recorded")
	return LanguageManager.get_weapon_name(
		weapon_id,
		str(entry.get("top_weapon_fallback", weapon_id))
	)


func _format_duration(seconds: float) -> String:
	var total_seconds := maxi(floori(maxf(seconds, 0.0)), 0)
	var hours := floori(float(total_seconds) / 3600.0)
	var minutes := floori(float(total_seconds % 3600) / 60.0)
	var remaining_seconds := total_seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, remaining_seconds]
	return "%02d:%02d" % [minutes, remaining_seconds]


func disable_actions() -> void:
	_stop_reveal_tween()
	_restore_time_scale()
	_sequence_playing = false
	restart_button.disabled = true
	main_menu_button.disabled = true


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()
