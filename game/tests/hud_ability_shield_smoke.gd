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
		and not hud.qi_shield_status_label.visible,
		"Foundation did not expose flight without the Golden Core Qi shield."
	)

	resources.demote_to_realm(2, 1)
	resources.add_qi(50)
	await _wait_process_frames(2)
	_check(
		hud.active_ability_name_label.text == "灵气护盾"
		and hud.active_ability_status_label.text.contains("默认关闭")
		and player.get_qi_shield_capacity() == 0.0
		and hud.qi_shield_status_label.text.contains("护盾关闭"),
		"Golden Core shield was not presented as default-off."
	)

	await _wait_physics_frames(40)
	var unshielded_lifespan := resources.current_lifespan
	player.take_melee_damage(3.0)
	_check(
		resources.current_qi == 50
		and is_equal_approx(
			resources.current_lifespan,
			unshielded_lifespan - 3.0
		),
		"Default-off Golden Core shield consumed Qi or blocked health damage."
	)
	var shield_toggle_event := InputEventAction.new()
	shield_toggle_event.action = &"spirit_projection"
	shield_toggle_event.pressed = true
	Input.parse_input_event(shield_toggle_event)
	await _wait_process_frames(2)
	shield_toggle_event.pressed = false
	Input.parse_input_event(shield_toggle_event)
	_check(
		player.realm_abilities.is_qi_shield_active()
		and is_equal_approx(player.get_qi_shield_capacity(), 50.0)
		and hud.qi_label.text.contains("灵盾 50")
		and hud.qi_shield_status_label.text.contains("50 点"),
		"Space did not activate and present the Golden Core Qi shield."
	)
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

	resources.demote_to_realm(3, 1)
	await _wait_process_frames(2)
	_check(
		hud.active_ability_name_label.text == "灵体出窍"
		and hud.active_ability_status_label.text == "可用",
		"Nascent Soul did not expose spirit projection."
	)
	resources.add_qi(10)
	_check(
		player.realm_abilities.toggle_spirit_projection()
		and player.realm_abilities.is_qi_shield_active()
		and hud.active_ability_description_label.text.contains("承受 150%"),
		"Nascent Soul projection did not activate its shield and risk text."
	)
	var projected_lifespan := resources.current_lifespan
	player.take_melee_damage(4.0)
	_check(
		resources.current_qi == 4
		and is_equal_approx(resources.current_lifespan, projected_lifespan),
		"Nascent Soul shield did not absorb 150% incoming damage with Qi."
	)
	resources.current_qi = 0
	player.take_melee_damage(2.0)
	_check(
		resources.get_current_realm_index() == 3
		and player.realm_abilities.is_spirit_projection_active()
		and is_equal_approx(
			resources.current_lifespan,
			projected_lifespan - 3.0
		),
		"Empty-Qi Nascent Soul damage did not reach health without demotion."
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
