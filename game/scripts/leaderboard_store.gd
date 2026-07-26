class_name LeaderboardStore
extends RefCounted

const LEADERBOARD_PATH: String = "user://survival_leaderboard.cfg"
const MAX_LEADERBOARD_ENTRIES: int = 10


## Records one completed cycle and returns both the saved entry and the newly
## sorted leaderboard. The lifetime cycle counter remains monotonic even when
## an older entry falls outside the displayed top ten.
static func record_summary(summary: Dictionary) -> Dictionary:
	var config := ConfigFile.new()
	var load_error := config.load(LEADERBOARD_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning(
			"Could not load local survival leaderboard: %s"
			% error_string(load_error)
		)
	var entries := _read_entries(config)
	var cycle_number := (
		int(
			config.get_value(
				"leaderboard",
				"total_cycles",
				_infer_total_cycles(entries)
			)
		)
		+ 1
	)
	var top_weapon := _get_top_weapon(summary)
	var entry := {
		"run_id": "%d_%d" % [
			int(Time.get_unix_time_from_system()),
			Time.get_ticks_msec(),
		],
		"cycle_number": cycle_number,
		"duration_seconds": float(summary.get("duration_seconds", 0.0)),
		"total_damage": maxi(int(summary.get("total_damage", 0)), 0),
		"top_weapon_id": str(top_weapon.get("weapon_id", "")),
		"top_weapon_fallback": str(
			top_weapon.get("fallback_name", "")
		),
		"top_weapon_damage": maxi(int(top_weapon.get("damage", 0)), 0),
		"fatal_breakthrough": bool(
			summary.get("fatal_breakthrough", false)
		),
	}
	entries.append(entry)
	_sort_entries(entries)
	if entries.size() > MAX_LEADERBOARD_ENTRIES:
		entries.resize(MAX_LEADERBOARD_ENTRIES)
	config.set_value("leaderboard", "total_cycles", cycle_number)
	config.set_value("leaderboard", "entries", entries)
	var save_error := config.save(LEADERBOARD_PATH)
	if save_error != OK:
		push_warning(
			"Could not save local survival leaderboard: %s"
			% error_string(save_error)
		)
	return {
		"entry": entry,
		"entries": entries,
	}


## Returns defensive copies of locally saved leaderboard rows, normalized for
## records created before damage and cycle metadata were introduced.
static func load_entries() -> Array[Dictionary]:
	var config := ConfigFile.new()
	var load_error := config.load(LEADERBOARD_PATH)
	if load_error != OK:
		return []
	var entries := _read_entries(config)
	_sort_entries(entries)
	return entries


static func _read_entries(config: ConfigFile) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var stored_entries: Array = config.get_value(
		"leaderboard",
		"entries",
		[]
	)
	for entry_variant in stored_entries:
		if entry_variant is not Dictionary:
			continue
		var entry := (entry_variant as Dictionary).duplicate(true)
		entry["cycle_number"] = maxi(
			int(entry.get("cycle_number", entries.size() + 1)),
			1
		)
		entry["total_damage"] = maxi(
			int(entry.get("total_damage", 0)),
			0
		)
		entry["top_weapon_id"] = str(entry.get("top_weapon_id", ""))
		entry["top_weapon_fallback"] = str(
			entry.get("top_weapon_fallback", "")
		)
		entry["top_weapon_damage"] = maxi(
			int(entry.get("top_weapon_damage", 0)),
			0
		)
		entries.append(entry)
	return entries


static func _infer_total_cycles(entries: Array[Dictionary]) -> int:
	var total_cycles := 0
	for entry in entries:
		total_cycles = maxi(
			total_cycles,
			int(entry.get("cycle_number", 0))
		)
	return total_cycles


static func _get_top_weapon(summary: Dictionary) -> Dictionary:
	var owned_weapon_ids: Dictionary = {}
	for weapon_variant in summary.get("weapon_levels", []):
		if weapon_variant is Dictionary:
			var weapon := weapon_variant as Dictionary
			owned_weapon_ids[str(weapon.get("weapon_id", ""))] = true
	for ranking_variant in summary.get("weapon_damage_ranking", []):
		if ranking_variant is not Dictionary:
			continue
		var ranking := ranking_variant as Dictionary
		if (
			owned_weapon_ids.has(str(ranking.get("weapon_id", "")))
			and int(ranking.get("damage", 0)) > 0
		):
			return ranking.duplicate(true)
	return {}


static func _sort_entries(entries: Array[Dictionary]) -> void:
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_duration := float(a.get("duration_seconds", 0.0))
			var b_duration := float(b.get("duration_seconds", 0.0))
			if not is_equal_approx(a_duration, b_duration):
				return a_duration > b_duration
			var a_damage := int(a.get("total_damage", 0))
			var b_damage := int(b.get("total_damage", 0))
			if a_damage != b_damage:
				return a_damage > b_damage
			return (
				int(a.get("cycle_number", 0))
				< int(b.get("cycle_number", 0))
			)
	)
