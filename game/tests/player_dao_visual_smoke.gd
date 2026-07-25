extends SceneTree

const PLAYER_SCENE := preload("res://game/scenes/gameplay/player.tscn")
const ENEMY_SCENE := preload("res://game/scenes/gameplay/enemy.tscn")
const DAO_DATA := preload("res://game/resources/weapon/dao.tres")
const DAO_TEXTURE := preload("res://assets/player_weapons/dao_knife.png")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("PLAYER DAO VISUAL TEST: %s" % message)


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _wait_seconds(duration: float) -> void:
	await create_timer(duration).timeout


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2.ZERO
	player.set_movement_enabled(false)
	for _copy in 3:
		player.collect_weapon(DAO_DATA, DAO_DATA.minimum_damage)
	_check(player.select_weapon_slot(0), "Dao could not be equipped.")
	await _wait_seconds(0.4)

	var main_blade := player.dao_weapon_layer.get_node(
		"DaoWeapon1"
	) as Sprite2D
	var main_tip_distance := (
		main_blade.position.length()
		+ player.get_dao_weapon_tip_length()
	)
	var blade_tip_direction := Vector2.UP.rotated(
		main_blade.rotation
	).normalized()
	var orbit_tangent := (
		-main_blade.position.normalized().orthogonal()
	)
	_check(
		player.get_visible_dao_weapon_count() == 1
		and not player.is_dao_combat_visual_active()
		and main_blade.texture == DAO_TEXTURE
		and absf(
			main_tip_distance - player.get_current_attack_range()
		) < 1.0
		and blade_tip_direction.dot(orbit_tangent) > 0.99,
		"Idle Dao did not patrol the outer boundary with tangent orientation."
	)

	var enemy := ENEMY_SCENE.instantiate() as EnemyController
	enemy.player = player
	enemy.cruise_speed = 1.0
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(
		player.get_current_attack_range() + 30.0,
		0.0
	)
	await _wait_seconds(0.08)
	var outline_material := main_blade.material as ShaderMaterial
	var warning_outline: Color = (
		outline_material.get_shader_parameter(&"outline_color")
	)
	_check(
		player.get_dao_warning_strength() > 0.5
		and warning_outline.a > 0.5,
		"An approaching enemy did not activate the golden Dao warning."
	)

	enemy.global_position = Vector2(
		player.get_current_attack_range() - 10.0,
		0.0
	)
	await _wait_seconds(0.5)
	_check(
		player.is_dao_combat_visual_active()
		and player.get_visible_dao_weapon_count() == 3,
		"Entering Dao range did not rapidly deploy every collected blade."
	)

	enemy.global_position = Vector2(
		player.get_current_attack_range() + 120.0,
		0.0
	)
	await _wait_process_frames(2)
	var recall_progress: Array[float] = player.get(
		"_dao_weapon_visibility"
	)
	_check(
		recall_progress[1] < recall_progress[2],
		"Auxiliary Dao blades did not begin recalling in sequence."
	)
	await _wait_seconds(0.45)
	_check(
		not player.is_dao_combat_visual_active()
		and player.get_visible_dao_weapon_count() == 1,
		"Auxiliary Dao blades did not return and disappear after combat."
	)

	player.select_starting_weapon()
	await _wait_process_frames(2)
	_check(
		player.get_visible_dao_weapon_count() == 0,
		"Switching away from Dao left a blade visible."
	)
	enemy.global_position = Vector2(
		player.get_current_attack_range() - 10.0,
		0.0
	)
	player.select_weapon_slot(0)
	await _wait_seconds(0.5)
	_check(
		player.is_dao_combat_visual_active()
		and player.get_visible_dao_weapon_count() == 3,
		"Switching to Dao near an enemy did not enter combat directly."
	)
	await _wait_physics_frames(2)
	player.set("_attack_cooldown_remaining", 0.0)
	player.call("_update_weapon_attack", 0.01)
	await _wait_process_frames(2)
	_check(
		not enemy.is_combat_active()
		and player.is_dao_combat_visual_active()
		and float(player.get("_dao_attack_visual_hold_remaining")) > 0.0,
		"An instant Dao kill did not retain a readable attack orbit."
	)
	await _wait_seconds(0.8)
	_check(
		not player.is_dao_combat_visual_active(),
		"Dao attack visuals did not leave combat after their retained orbit."
	)

	for _copy in 97:
		player.collect_weapon(DAO_DATA, DAO_DATA.minimum_damage)
	var stress_enemy := ENEMY_SCENE.instantiate() as EnemyController
	stress_enemy.player = player
	stress_enemy.max_health = 1_000_000
	stress_enemy.cruise_speed = 1.0
	root.add_child(stress_enemy)
	stress_enemy.set_physics_process(false)
	stress_enemy.global_position = Vector2(
		player.get_current_attack_range() - 10.0,
		0.0
	)
	await _wait_seconds(0.65)
	var stress_visibility: Array[float] = player.get(
		"_dao_weapon_visibility"
	)
	var all_stress_blades_deployed := stress_visibility.size() == 100
	for visibility in stress_visibility:
		all_stress_blades_deployed = (
			all_stress_blades_deployed
			and visibility > 0.99
		)
	_check(
		all_stress_blades_deployed
		and player.get_visible_dao_weapon_count() == 100,
		"Maximum Dao count did not finish its bounded deployment."
	)
	await _wait_process_frames(30)

	if is_instance_valid(stress_enemy):
		stress_enemy.queue_free()
	if is_instance_valid(enemy):
		enemy.queue_free()
	player.queue_free()
	await _wait_process_frames(2)
	if _failures.is_empty():
		print("PLAYER DAO VISUAL TEST: PASS")
	else:
		print(
			"PLAYER DAO VISUAL TEST: FAIL (%d failures)"
			% _failures.size()
		)
	quit()
