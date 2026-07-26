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
	var menu_bgm := main_menu.get_node("BackgroundMusic") as AudioStreamPlayer
	var menu_bgm_source := menu_bgm.call("get_source_stream") as AudioStream
	_check(
		menu_bgm_source != null
		and menu_bgm_source.resource_path
			== "res://assets/sound/track/stage_1.wav"
		and menu_bgm.stream is AudioStreamWAV
		and bool(menu_bgm.get("loop_tracks"))
		and menu_bgm.playing,
		"Main menu did not start looping stage_1 music."
	)
	var bgm_bus_index := AudioServer.get_bus_index(&"BGM")
	var sfx_bus_index := AudioServer.get_bus_index(&"SFX")
	_check(
		bgm_bus_index >= 0
		and sfx_bus_index >= 0
		and menu_bgm.bus == &"BGM",
		"Dedicated BGM/SFX buses are missing or menu music is misrouted."
	)
	main_menu.call("_on_sound_settings_pressed")
	var sound_menu := main_menu.get_node("CenterContainer/SoundMenu")
	var main_menu_panel := main_menu.get_node("CenterContainer/Menu")
	_check(
		sound_menu.visible and not main_menu_panel.visible,
		"Sound button did not open its dedicated submenu."
	)
	main_menu.call("_on_bgm_volume_changed", 37.0)
	main_menu.call("_on_bgm_mute_toggled", true)
	main_menu.call("_on_sfx_volume_changed", 61.0)
	main_menu.call("_on_sfx_mute_toggled", true)
	_check(
		is_equal_approx(
			AudioServer.get_bus_volume_db(bgm_bus_index),
			linear_to_db(0.37)
		)
		and AudioServer.is_bus_mute(bgm_bus_index)
		and is_equal_approx(
			AudioServer.get_bus_volume_db(sfx_bus_index),
			linear_to_db(0.61)
		)
		and AudioServer.is_bus_mute(sfx_bus_index)
		and (main_menu.get_node("%BgmPercent") as Label).text == "37%"
		and (main_menu.get_node("%SfxPercent") as Label).text == "61%",
		"Sound submenu did not independently apply BGM and SFX controls."
	)
	main_menu.call("_on_bgm_mute_toggled", false)
	main_menu.call("_on_sfx_mute_toggled", false)
	main_menu.call("_on_bgm_volume_changed", 100.0)
	main_menu.call("_on_sfx_volume_changed", 100.0)
	main_menu.call("_on_sound_back_pressed")
	_check(
		not sound_menu.visible and main_menu_panel.visible,
		"Sound Back button did not restore the main menu."
	)
	main_menu.call("_on_start_game_pressed")
	await _wait_process_frames(4)

	var game := current_scene
	_check(game != null and game.name == "Game", "Start Game did not replace the main menu.")
	var player := game.get_node("Player") as PlayerController
	var world := game.get_node("InfiniteWorld") as InfiniteWorld
	var pause_menu := game.get_node("PauseMenu")
	var game_bgm := game.get_node("BackgroundMusic") as AudioStreamPlayer
	var realm_bgm_tracks := game.get("realm_bgm_tracks") as Array[AudioStream]
	_check(
		realm_bgm_tracks.size() == 4
		and realm_bgm_tracks[0].resource_path.ends_with("stage_1.wav")
		and realm_bgm_tracks[1].resource_path.ends_with("stage_2.wav")
		and realm_bgm_tracks[2].resource_path.ends_with("stage_3.wav")
		and realm_bgm_tracks[3].resource_path.ends_with("stage_4.wav")
		and (
			game.get("heavenly_tribulation_bgm") as AudioStream
		).resource_path.ends_with("lei_jie.wav"),
		"Gameplay BGM tracks do not match the four realms and tribulation."
	)
	_check(
		game_bgm.bus == &"BGM"
		and player.weapon_sfx_bus == &"SFX",
		"Gameplay music or weapon effects bypassed their dedicated audio bus."
	)
	var breakthrough_success_player := (
		game.get_node("BreakthroughSuccessSfx") as AudioStreamPlayer
	)
	_check(
		breakthrough_success_player.stream != null
		and breakthrough_success_player.stream.resource_path
			== "res://assets/sound/sfx/dujie_success.mp3"
		and is_equal_approx(
			breakthrough_success_player.volume_db,
			float(game.get("breakthrough_success_volume_db"))
		),
		"Successful breakthrough SFX is missing or ignored its volume tuning."
	)
	for realm_index in realm_bgm_tracks.size():
		game.call("_play_realm_bgm", realm_index, true)
		var active_source := game_bgm.call("get_source_stream") as AudioStream
		_check(
			active_source == realm_bgm_tracks[realm_index]
			and game_bgm.stream is AudioStreamWAV
			and bool(game_bgm.get("loop_tracks"))
			and game_bgm.playing,
			"Realm %d did not select its looping BGM." % realm_index
		)
	game.call("_play_realm_bgm", 0, true)
	var tribulation_preview := (
		load(
			"res://game/scenes/gameplay/heavenly_tribulation.tscn"
		).instantiate() as HeavenlyTribulation
	)
	root.add_child(tribulation_preview)
	await process_frame
	_check(
		tribulation_preview.strike_sfx != null
		and tribulation_preview.strike_sfx.resource_path
			== "res://assets/sound/sfx/duejie_thunder.mp3"
		and tribulation_preview.strike_sfx_volume_db < 0.0
		and tribulation_preview.strike_sfx_player.max_polyphony
			== tribulation_preview.strike_sfx_max_polyphony,
		"Heavenly Tribulation thunder SFX is missing, unattenuated, or not polyphonic."
	)
	_check(
		tribulation_preview.strike_sfx_player.bus == &"SFX",
		"Heavenly Tribulation thunder bypassed the SFX bus."
	)
	tribulation_preview.queue_free()
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
		"Player did not load both grounded sets and Foundation flight."
	)
	_check(
		character_sprite.sprite_frames.get_frame_count(
			&"golden_core_fly"
		) == 9
		and character_sprite.sprite_frames.get_frame_count(
			&"nascent_soul_fly"
		) == 9,
		"Player did not load both advanced-realm flying sets."
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
