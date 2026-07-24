extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("FOUNDATION TEST: %s" % message)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _send_pause_action() -> void:
	var press := InputEventAction.new()
	press.action = "pause"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame

	var release := InputEventAction.new()
	release.action = "pause"
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _run() -> void:
	var change_error := change_scene_to_file(
		"res://game/scenes/menus/main_menu.tscn"
	)
	_check(change_error == OK, "Main menu scene could not be opened.")
	await _wait_process_frames(3)

	var main_menu := current_scene
	_check(main_menu != null and main_menu.name == "MainMenu", "Main menu is not the boot flow.")
	main_menu.call("_on_start_game_pressed")
	await _wait_process_frames(4)

	var game := current_scene
	_check(game != null and game.name == "Game", "Start Game did not replace the main menu.")
	var player := game.get_node("Player") as PlayerController
	var world := game.get_node("InfiniteWorld") as InfiniteWorld
	var pause_menu := game.get_node("PauseMenu")
	_check(player != null, "Gameplay has no PlayerController.")
	_check(world != null, "Gameplay has no InfiniteWorld.")
	var character_sprite := (
		player.get_node("CharacterSprite") as AnimatedSprite2D
	)
	_check(
		character_sprite.animation == &"qi_walk"
		and character_sprite.sprite_frames.get_frame_count(&"qi_walk") == 9
		and character_sprite.sprite_frames.get_frame_count(&"walk") == 9
		and character_sprite.sprite_frames.get_frame_count(&"fly") == 9,
		"Player did not load both realm running sets and the flying set."
	)

	var starting_y := player.global_position.y
	await _wait_physics_frames(20)
	_check(player.global_position.y < starting_y, "Player does not move forward automatically.")

	Input.action_press("speed_up")
	await _wait_physics_frames(40)
	Input.action_release("speed_up")
	_check(
		player.current_forward_speed > player.base_forward_speed + 40.0,
		"Forward input did not smoothly raise travel speed."
	)
	_check(
		character_sprite.speed_scale > 1.0,
		"Accelerating did not speed up animation playback."
	)
	await _wait_physics_frames(40)
	_check(
		absf(player.current_forward_speed - player.base_forward_speed) < 2.0,
		"Forward speed did not return to base after release."
	)

	Input.action_press("slow_down")
	await _wait_physics_frames(40)
	Input.action_release("slow_down")
	_check(
		player.current_forward_speed < player.base_forward_speed - 40.0,
		"Backward input did not reduce forward travel speed."
	)
	_check(
		character_sprite.speed_scale < 1.0,
		"Slowing did not reduce animation playback speed."
	)
	_check(player.current_forward_speed > 0.0, "Player was allowed to reverse or stop.")

	Input.action_press("move_right")
	await _wait_physics_frames(180)
	Input.action_release("move_right")
	await _wait_physics_frames(1)
	_check(
		is_zero_approx(player.velocity.x),
		"Lateral movement retained inertia after input release."
	)
	var right_bound := player.road_half_width - player.horizontal_clearance
	_check(
		player.global_position.x <= right_bound + 0.01,
		"Player escaped the road's right bound."
	)
	_check(
		player.global_position.x >= right_bound - 1.0,
		"Player did not reach the road's clamped right bound."
	)

	var chunk_count := world.get_active_chunk_count()
	# More than four minutes of distance at the configured maximum speed.
	player.global_position.y = -100000.0
	await _wait_physics_frames(2)
	_check(
		world.get_active_chunk_count() == chunk_count,
		"Chunk recycling changed the active pool size."
	)
	var chunk_positions: Array[float] = []
	for child in world.get_children():
		if child is WorldChunk:
			chunk_positions.append(child.position.y)
	chunk_positions.sort()
	var expected_chunk_height := world.chunk_config.get_pixel_size().y
	for index in range(1, chunk_positions.size()):
		_check(
			is_equal_approx(
				chunk_positions[index] - chunk_positions[index - 1],
				expected_chunk_height
			),
			"Recycled chunks contain a gap or overlap."
		)

	await _send_pause_action()
	_check(paused, "Pause input did not pause the scene tree.")
	var paused_position := player.global_position
	await _wait_process_frames(10)
	_check(
		player.global_position.is_equal_approx(paused_position),
		"Player continued moving while paused."
	)
	await _send_pause_action()
	_check(not paused, "Pause input did not resume the scene tree.")
	await _wait_physics_frames(3)
	_check(
		player.global_position.y < paused_position.y,
		"Player did not continue after resume."
	)

	pause_menu.call("pause_game")
	pause_menu.call("_on_main_menu_pressed")
	await _wait_process_frames(4)
	_check(not paused, "Return to Main Menu left the tree paused.")
	_check(
		current_scene != null and current_scene.name == "MainMenu",
		"Return to Main Menu did not open a responsive menu."
	)

	if _failures.is_empty():
		print("FOUNDATION TEST: PASS")
		quit(0)
	else:
		print("FOUNDATION TEST: FAIL (%d failures)" % _failures.size())
		quit(1)
