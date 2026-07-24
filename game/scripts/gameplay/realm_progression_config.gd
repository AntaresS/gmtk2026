class_name RealmProgressionConfig
extends Resource

## Ordered realm definitions from the starting realm to the final realm.
@export var realms: Array[RealmDefinition] = []


func get_realm_count() -> int:
	return realms.size()


func get_realm(realm_index: int) -> RealmDefinition:
	if realm_index < 0 or realm_index >= realms.size():
		return null
	return realms[realm_index]


func get_total_levels() -> int:
	var total := 0
	for realm in realms:
		if realm != null:
			total += maxi(realm.layer_count, 1)
	return total


## Converts a one-based overall cultivation level into a zero-based realm.
func get_realm_index_for_level(overall_level: int) -> int:
	if realms.is_empty():
		return 0
	var remaining := maxi(overall_level, 1)
	for realm_index in realms.size():
		var realm := realms[realm_index]
		var layer_count := maxi(realm.layer_count, 1) if realm != null else 1
		if remaining <= layer_count:
			return realm_index
		remaining -= layer_count
	return realms.size() - 1


## Converts a one-based overall cultivation level into a one-based layer.
func get_layer_for_level(overall_level: int) -> int:
	if realms.is_empty():
		return maxi(overall_level, 1)
	var remaining := maxi(overall_level, 1)
	for realm in realms:
		var layer_count := maxi(realm.layer_count, 1) if realm != null else 1
		if remaining <= layer_count:
			return remaining
		remaining -= layer_count
	var final_realm: RealmDefinition = realms.back() as RealmDefinition
	return maxi(final_realm.layer_count, 1) if final_realm != null else 1


func get_overall_level(realm_index: int, layer: int) -> int:
	if realms.is_empty():
		return maxi(layer, 1)
	var safe_realm_index := clampi(realm_index, 0, realms.size() - 1)
	var overall_level := 0
	for index in safe_realm_index:
		var realm := realms[index]
		overall_level += maxi(realm.layer_count, 1) if realm != null else 1
	var target_realm := realms[safe_realm_index]
	var layer_count := (
		maxi(target_realm.layer_count, 1)
		if target_realm != null
		else 1
	)
	return overall_level + clampi(layer, 1, layer_count)


func is_last_layer(overall_level: int) -> bool:
	var realm := get_realm(get_realm_index_for_level(overall_level))
	if realm == null:
		return false
	return get_layer_for_level(overall_level) >= maxi(realm.layer_count, 1)


func has_next_realm(overall_level: int) -> bool:
	return get_realm_index_for_level(overall_level) + 1 < realms.size()


func get_debug_snapshot(overall_level: int) -> Dictionary:
	var realm_index := get_realm_index_for_level(overall_level)
	var realm := get_realm(realm_index)
	return {
		"overall_level": maxi(overall_level, 1),
		"realm_index": realm_index,
		"realm_id": realm.realm_id if realm != null else &"",
		"realm_name": realm.display_name if realm != null else "",
		"layer": get_layer_for_level(overall_level),
		"layer_count": maxi(realm.layer_count, 1) if realm != null else 1,
		"melee_only": realm.melee_weapons_only if realm != null else false,
		"qi_shield": realm.qi_shield_enabled if realm != null else false,
		"flight": (
			realm != null
			and realm.locomotion_mode != RealmDefinition.LocomotionMode.GROUND
		),
		"continuous_flight": (
			realm != null
			and realm.locomotion_mode == RealmDefinition.LocomotionMode.FLIGHT
		),
		"tribulation_strike_count": (
			maxi(realm.tribulation_strike_count, 1)
			if realm != null
			else 1
		),
		"tribulation_warning_duration_multiplier": (
			realm.tribulation_warning_duration_multiplier
			if realm != null
			else 1.0
		),
		"spirit_projection": (
			realm.spirit_projection_enabled if realm != null else false
		),
		"fatal_breakthrough": (
			realm.fatal_breakthrough if realm != null else false
		),
	}
