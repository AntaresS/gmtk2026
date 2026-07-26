extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("PLAYER FLIGHT ANCHOR TEST: %s" % message)


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _check_airborne_anchor(
	player: PlayerController,
	expected_elevation: float,
	context: String
) -> void:
	var expected_local_position := Vector2(0.0, -expected_elevation)
	var expected_global_position := (
		player.global_position + expected_local_position
	)
	_check(
		player.combat_anchor.position.is_equal_approx(
			expected_local_position
		)
		and player.get_combat_anchor_position().is_equal_approx(
			expected_global_position
		)
		and player.get_reward_interaction_position().is_equal_approx(
			expected_global_position
		)
		and player.character_sprite.global_position.is_equal_approx(
			expected_global_position
		),
		"%s did not align the visible player and shared combat anchor."
			% context
	)
	_check(
		player.body_shape.global_position.is_equal_approx(
			expected_global_position
		)
		and player.attack_area.global_position.is_equal_approx(
			expected_global_position
		)
		and player.attraction_area.global_position.is_equal_approx(
			expected_global_position
		)
		and player.golden_bell.global_position.is_equal_approx(
			expected_global_position
		),
		"%s did not align player collision and interaction hitboxes."
			% context
	)
	_check(
		player.dao_weapon_layer.global_position.is_equal_approx(
			expected_global_position
		)
		and player.flying_sword_layer.global_position.is_equal_approx(
			expected_global_position
		)
		and player.palm_weapon.get_parent() == player.combat_anchor
		and player.palm_echo_layer.get_parent() == player.combat_anchor
		and player.fantian_seal_weapon.get_parent() == player.combat_anchor
		and player.thunder_hammer_visual.get_parent()
			== player.combat_anchor,
		"%s did not align every player-owned weapon visual."
			% context
	)


func _run() -> void:
	var change_error := change_scene_to_file(
		"res://game/scenes/gameplay/game.tscn"
	)
	_check(change_error == OK, "Gameplay scene could not be opened.")
	await _wait_process_frames(4)

	var game := current_scene
	var player := game.get_node("Player") as PlayerController
	var resources := game.get_node("RunResources") as RunResources
	var spawner := game.get_node("EnemySpawner") as EnemySpawner
	spawner.set_spawning_enabled(false)
	player.set_movement_enabled(false)

	_check_airborne_anchor(player, 0.0, "Grounded state")

	resources.demote_to_realm(1, 1)
	await _wait_physics_frames(12)
	var foundation_elevation := (
		player.realm_abilities.get_current_flight_elevation()
	)
	_check(
		foundation_elevation > 0.0,
		"Foundation did not begin its automatic flight demonstration."
	)
	_check_airborne_anchor(
		player,
		foundation_elevation,
		"Foundation active flight"
	)

	for _frame in 180:
		if not player.realm_abilities.is_temporary_flight_active():
			break
		await physics_frame
	_check(
		not player.realm_abilities.is_temporary_flight_active(),
		"Foundation flight did not finish for landing verification."
	)
	_check_airborne_anchor(player, 0.0, "Foundation landing")

	resources.demote_to_realm(2, 1)
	await _wait_process_frames(2)
	var golden_core_elevation := (
		player.realm_abilities.get_current_flight_elevation()
	)
	_check(
		golden_core_elevation > 0.0,
		"Golden Core did not enter continuous flight."
	)
	_check_airborne_anchor(
		player,
		golden_core_elevation,
		"Golden Core continuous flight"
	)

	if _failures.is_empty():
		print("PLAYER FLIGHT ANCHOR TEST PASSED")
		quit(0)
		return
	quit(1)
