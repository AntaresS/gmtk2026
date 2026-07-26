class_name RunEndedOverlay
extends CanvasLayer

signal restart_requested
signal main_menu_requested

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	LanguageManager.language_changed.connect(_on_language_changed)
	_refresh_language()
	hide()


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
	restart_button.disabled = false
	main_menu_button.disabled = false
	show()
	restart_button.grab_focus()


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
	restart_button.disabled = true
	main_menu_button.disabled = true


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()
