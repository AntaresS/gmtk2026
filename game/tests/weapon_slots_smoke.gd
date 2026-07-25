extends SceneTree

const WeaponDataResource = preload(
	"res://game/scripts/gameplay/weapon_data.gd"
)
const DAO_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/dao.tres"
)
const FLYING_SWORD_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/flying_sword.tres"
)
const QIANKUN_RING_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/qiankun_ring.tres"
)
const GOLDEN_BELL_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/golden_bell.tres"
)
const THUNDER_HAMMER_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/thunder_hammer.tres"
)
const FANTIAN_SEAL_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/fantian_seal.tres"
)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("WEAPON SLOTS TEST: %s" % message)


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _send_key(key_value: int) -> void:
	var press := InputEventKey.new()
	press.keycode = key_value as Key
	press.physical_keycode = key_value as Key
	press.unicode = key_value
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = key_value as Key
	release.physical_keycode = key_value as Key
	release.unicode = key_value
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _run() -> void:
	var change_error := change_scene_to_file(
		"res://game/scenes/gameplay/game.tscn"
	)
	_check(change_error == OK, "Gameplay scene could not be opened.")
	await _wait_process_frames(4)

	var game := current_scene
	var player := game.get_node("Player") as PlayerController
	var hud := game.get_node("GameplayHud") as GameplayHud
	var spawner := game.get_node("EnemySpawner") as EnemySpawner
	spawner.set_spawning_enabled(false)

	var slots_layout := hud.get_node("HudRoot/WeaponSlotsLayout") as Control
	_check(
		slots_layout != null
		and slots_layout.anchor_top == 1.0
		and slots_layout.offset_left < 800.0,
		"Weapon layout was not anchored near the lower-left/mid HUD."
	)
	_check(
		hud.palm_weapon_slot.selected
		and hud.palm_weapon_slot.get_weapon_id() == &"great_strength_palm",
		"Great Strength Palm did not start in its separate selected slot."
	)
	for slot_index in 6:
		_check(
			hud.get_weapon_slot_control(slot_index).get_weapon_id().is_empty(),
			"Collectible slot %d was not initially empty." % (slot_index + 1)
		)

	_check(
		player.collect_weapon(DAO_DATA, DAO_DATA.minimum_damage),
		"First Dao pickup was rejected."
	)
	await _wait_process_frames(2)
	var first_slot := hud.get_weapon_slot_control(0)
	_check(
		first_slot.get_weapon_id() == &"dao"
		and first_slot.get_quantity() == 1
		and first_slot.is_new_weapon_flashing(),
		"First acquired weapon did not enter slot 1 with persistent flash."
	)

	player.collect_weapon(DAO_DATA, DAO_DATA.minimum_damage)
	await _wait_process_frames(1)
	_check(
		first_slot.get_quantity() == 2
		and first_slot.is_power_up_effect_active(),
		"Duplicate pickup did not update count and play power-up feedback."
	)

	await _send_key(49)
	_check(
		player.get_current_weapon_data() == DAO_DATA
		and first_slot.selected
		and not first_slot.is_new_weapon_flashing(),
		"Key 1 did not select slot 1 and clear its first-selection flash."
	)

	var remaining_weapons: Array[WeaponDataResource] = [
		FLYING_SWORD_DATA,
		QIANKUN_RING_DATA,
		GOLDEN_BELL_DATA,
		THUNDER_HAMMER_DATA,
		FANTIAN_SEAL_DATA,
	]
	for weapon_data in remaining_weapons:
		player.collect_weapon(weapon_data, weapon_data.minimum_damage)
		await _wait_process_frames(1)

	var expected_ids: Array[StringName] = [
		&"dao",
		&"flying_sword",
		&"qiankun_ring",
		&"golden_bell",
		&"thunder_hammer",
		&"fantian_seal",
	]
	for slot_index in 6:
		_check(
			hud.get_weapon_slot_control(slot_index).get_weapon_id()
				== expected_ids[slot_index],
			"Weapon acquisition order mismatch in slot %d."
				% (slot_index + 1)
		)

	await _send_key(54)
	_check(
		player.get_current_weapon_data() == FANTIAN_SEAL_DATA
		and hud.get_weapon_slot_control(5).selected,
		"Key 6 did not select the sixth acquired weapon."
	)
	await _send_key(96)
	_check(
		player.get_current_weapon_data().weapon_id == &"great_strength_palm"
		and hud.palm_weapon_slot.selected,
		"Backtick did not select Great Strength Palm."
	)
	player.cycle_equipment()
	_check(
		player.get_current_weapon_data() == DAO_DATA,
		"Tab-style cycling did not remain compatible with direct slots."
	)

	if _failures.is_empty():
		print("WEAPON SLOTS TEST: PASS")
		quit(0)
	else:
		print("WEAPON SLOTS TEST: FAIL (%d failures)" % _failures.size())
		quit(1)
