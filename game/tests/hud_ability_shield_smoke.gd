extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("HUD ABILITY/SHIELD TEST: %s" % message)


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _run() -> void:
	var change_error := change_scene_to_file(
		"res://game/scenes/gameplay/game.tscn"
	)
	_check(change_error == OK, "Gameplay scene could not be opened.")
	await _wait_process_frames(4)

	var game := current_scene
	var player := game.get_node("Player") as PlayerController
	var hud := game.get_node("GameplayHud") as GameplayHud
	var resources := game.get_node("RunResources") as RunResources
	var spawner := game.get_node("EnemySpawner") as EnemySpawner
	spawner.set_spawning_enabled(false)

	_check(
		hud.active_ability_name_label.text == "翻滚无敌"
		and hud.active_ability_status_label.text == "可用"
		and is_equal_approx(hud.active_ability_progress.value, 1.0),
		"Qi Refining active ability card was not ready."
	)
	_check(
		player.start_qi_refining_roll(),
		"Qi Refining roll could not start for HUD verification."
	)
	await _wait_process_frames(2)
	_check(
		hud.active_ability_status_label.text == "翻滚中"
		and hud.active_ability_progress.value < 1.0,
		"Roll activation did not update the active ability card."
	)

	resources.demote_to_realm(1, 1)
	await _wait_process_frames(2)
	_check(
		hud.active_ability_name_label.text == "跃起驭空"
		and hud.qi_shield_status_label.visible,
		"Foundation did not expose flight and the Qi shield on the HUD."
	)

	resources.add_qi(50)
	await _wait_process_frames(2)
	_check(
		is_equal_approx(player.get_qi_shield_capacity(), 50.0)
		and hud.qi_label.text.contains("灵盾 50")
		and hud.qi_shield_status_label.text.contains("50 点"),
		"Qi shield capacity was not communicated as damage absorption."
	)

	await _wait_physics_frames(40)
	player.take_melee_damage(12.0)
	await _wait_process_frames(2)
	_check(
		resources.current_qi == 38
		and is_equal_approx(player.get_qi_shield_capacity(), 38.0)
		and player.is_qi_shield_feedback_active()
		and hud.qi_shield_status_label.text.contains("护盾吸收 12")
		and hud.qi_shield_status_label.text.contains("剩余 38"),
		"Shield hit feedback did not show blocked damage, Qi cost, and remainder."
	)

	resources.demote_to_realm(2, 1)
	await _wait_process_frames(2)
	_check(
		hud.active_ability_name_label.text == "双生虚影"
		and hud.active_ability_status_label.text == "可用",
		"Golden Core did not expose the echo active ability."
	)
	resources.demote_to_realm(3, 1)
	await _wait_process_frames(2)
	_check(
		hud.active_ability_name_label.text == "灵体出窍"
		and hud.active_ability_status_label.text == "可用",
		"Nascent Soul did not expose spirit projection."
	)

	if _failures.is_empty():
		print("HUD ABILITY/SHIELD TEST: PASS")
		quit(0)
	else:
		print(
			"HUD ABILITY/SHIELD TEST: FAIL (%d failures)"
			% _failures.size()
		)
		quit(1)
