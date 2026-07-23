extends SceneTree

var _failures: Array[String] = []
var _levels_emitted: int = 0
var _pickup_emissions: int = 0
var _last_pickup_value: int = 0
var _depletion_emissions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("GAMEPLAY LOOP TEST: %s" % message)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _run() -> void:
	var change_error := change_scene_to_file(
		"res://game/scenes/gameplay/game.tscn"
	)
	_check(change_error == OK, "Gameplay scene could not be opened.")
	await _wait_process_frames(4)

	var game := current_scene
	var player := game.get_node("Player") as PlayerController
	var world := game.get_node("InfiniteWorld") as InfiniteWorld
	var resources := game.get_node("RunResources") as RunResources
	var hud := game.get_node("GameplayHud") as GameplayHud
	var end_overlay := game.get_node("RunEndedOverlay") as RunEndedOverlay
	var pause_menu := game.get_node("PauseMenu")
	var absorption_area := (
		player.get_node("QiAbsorptionArea") as PlayerAbsorptionArea
	)
	_check(player != null, "Gameplay has no player.")
	_check(world != null, "Gameplay has no infinite world.")
	_check(resources != null, "Gameplay has no run resources.")
	_check(hud != null, "Gameplay has no HUD.")
	_check(end_overlay != null, "Gameplay has no run-ended overlay.")
	_check(absorption_area != null, "Player has no qi absorption area.")
	_check(
		is_equal_approx(absorption_area.absorb_radius, 96.0),
		"Player absorption radius did not use the expected tuning."
	)
	_check(
		absf(resources.current_lifespan - 45.0) < 0.5,
		"Lifespan did not start at 45."
	)

	var lifespan_before_pause := resources.current_lifespan
	pause_menu.call("pause_game")
	await _wait_process_frames(8)
	_check(
		is_equal_approx(resources.current_lifespan, lifespan_before_pause),
		"Lifespan changed while the scene tree was paused."
	)
	pause_menu.call("resume_game")
	await _wait_process_frames(8)
	_check(
		resources.current_lifespan < lifespan_before_pause,
		"Lifespan did not resume decaying after unpausing."
	)

	var max_pickups_per_chunk := 0
	for child in world.get_children():
		if child is WorldChunk:
			max_pickups_per_chunk = (child as WorldChunk).max_pickups_per_chunk
			break
	_check(
		world.get_active_pickup_count()
		<= world.active_chunk_count * max_pickups_per_chunk
		and world.get_active_pickup_count() > 0,
		"Initial pickup count exceeded the fixed chunk-pool bound."
	)
	var saw_small := false
	var saw_medium := false
	var saw_large := false
	var saw_grouped_pair := false
	for child in world.get_children():
		if child is not WorldChunk:
			continue
		var chunk := child as WorldChunk
		var pickup_container := chunk.get_node_or_null("Pickups")
		_check(pickup_container != null, "A pooled chunk has no pickup container.")
		if pickup_container == null:
			continue
		var pickup_nodes := pickup_container.get_children()
		for pickup_index in pickup_nodes.size():
			var pickup_node := pickup_nodes[pickup_index] as QiPickup
			var local_x: float = pickup_node.position.x
			_check(
				absf(local_x)
				<= world.chunk_config.road_half_width
				- chunk.pickup_edge_clearance
				+ 0.01,
				"A generated pickup is outside the safe road bounds."
			)
			var density := pickup_node.density_profile.density
			saw_small = saw_small or density == QiDensityProfile.Density.SMALL
			saw_medium = saw_medium or density == QiDensityProfile.Density.MEDIUM
			saw_large = saw_large or density == QiDensityProfile.Density.LARGE
			for comparison_index in range(pickup_index):
				var other_pickup := pickup_nodes[comparison_index] as QiPickup
				if (
					pickup_node.position.distance_to(other_pickup.position)
					<= chunk.pickup_group_scatter_radius + 1.0
				):
					saw_grouped_pair = true
	_check(saw_small, "Small-density qi was not generated.")
	_check(saw_medium, "Medium-density qi was not generated.")
	_check(saw_large, "Large-density qi was not generated.")
	_check(saw_grouped_pair, "No grouped qi placement was generated.")

	player.global_position.y -= world.chunk_config.get_pixel_size().y * 2.0
	await _wait_physics_frames(3)
	_check(
		world.get_active_pickup_count()
		<= world.active_chunk_count * max_pickups_per_chunk,
		"Chunk recycling retained stale pickups beyond the fixed pool bound."
	)
	for child in world.get_children():
		if child is WorldChunk:
			_check(
				(child as WorldChunk).get_pickup_count()
				<= (child as WorldChunk).max_pickups_per_chunk,
				"A recycled chunk retained more than one generated pickup set."
			)

	var isolated_resources := RunResources.new()
	root.add_child(isolated_resources)
	await process_frame
	isolated_resources.set_process(false)
	isolated_resources.apply_lifespan_damage(25.0)
	_levels_emitted = 0
	isolated_resources.level_up_occurred.connect(_on_isolated_level_up)
	isolated_resources.add_qi(250)
	_check(
		isolated_resources.cultivation_level == 3,
		"A single qi addition did not support multiple level-ups."
	)
	_check(
		isolated_resources.current_qi == 50,
		"Qi overflow was not preserved."
	)
	_check(_levels_emitted == 2, "Level-up signals did not match levels gained.")
	_check(
		is_equal_approx(isolated_resources.current_lifespan, 40.0),
		"Each level-up did not restore ten lifespan."
	)
	isolated_resources.add_qi(100)
	_check(
		isolated_resources.current_lifespan
		<= isolated_resources.max_lifespan,
		"Lifespan restore exceeded the configured maximum."
	)
	_depletion_emissions = 0
	isolated_resources.lifespan_depleted.connect(_on_isolated_depleted)
	isolated_resources.apply_lifespan_damage(1000.0)
	isolated_resources.apply_lifespan_damage(1000.0)
	_check(
		_depletion_emissions == 1,
		"Lifespan depletion was emitted more than once."
	)

	var one_shot_pickup := preload(
		"res://game/scenes/gameplay/qi_pickup.tscn"
	).instantiate() as QiPickup
	root.add_child(one_shot_pickup)
	var test_density := QiDensityProfile.new()
	test_density.qi_value = 17
	test_density.absorption_duration_seconds = 0.2
	test_density.visual_scale = 1.0
	one_shot_pickup.configure_density(test_density)
	player.set_movement_enabled(false)
	one_shot_pickup.global_position = player.global_position
	_pickup_emissions = 0
	_last_pickup_value = 0
	one_shot_pickup.qi_collected.connect(_on_isolated_pickup_collected)
	await _wait_physics_frames(3)
	_check(
		one_shot_pickup.get_absorption_progress_ratio() > 0.0,
		"Pickup did not begin absorbing inside the player radius."
	)
	one_shot_pickup.global_position = (
		player.global_position
		+ Vector2(absorption_area.absorb_radius * 2.0, 0.0)
	)
	await _wait_physics_frames(2)
	var retained_progress := one_shot_pickup.get_absorption_progress_ratio()
	await _wait_physics_frames(4)
	_check(
		is_equal_approx(
			one_shot_pickup.get_absorption_progress_ratio(),
			retained_progress
		),
		"Absorption progressed while the player was outside the radius."
	)
	one_shot_pickup.global_position = player.global_position
	await _wait_physics_frames(20)
	_check(
		_pickup_emissions == 1,
		"A qi pickup did not complete exactly once after resumed absorption."
	)
	_check(_last_pickup_value == 17, "Absorption emitted the wrong density value.")

	resources.reset_resources()
	resources.add_qi(30)
	_check(
		hud.qi_label.text == "灵气  30 / 100",
		"HUD qi text did not synchronize through resource signals."
	)
	resources.apply_lifespan_damage(1000.0)
	await _wait_process_frames(2)
	_check(not resources.is_run_active(), "Run resources remained active at zero.")
	_check(end_overlay.visible, "Run-ended overlay was not displayed.")
	var ended_position := player.global_position
	await _wait_physics_frames(4)
	_check(
		player.global_position.is_equal_approx(ended_position),
		"Player movement continued after lifespan depletion."
	)

	game.call("_on_restart_requested")
	await _wait_process_frames(5)
	_check(
		current_scene != null and current_scene.name == "Game",
		"Restart did not reload gameplay."
	)
	var restarted_resources := current_scene.get_node("RunResources") as RunResources
	_check(
		absf(restarted_resources.current_lifespan - 45.0) < 0.5,
		"Restart did not create a clean resource state."
	)
	_check(
		get_root().get_node_or_null("Game") == current_scene,
		"Restart left a duplicate gameplay root."
	)

	restarted_resources.apply_lifespan_damage(1000.0)
	await _wait_process_frames(2)
	current_scene.call("_on_main_menu_requested")
	await _wait_process_frames(5)
	_check(not paused, "Run-ended Main Menu left the tree paused.")
	_check(
		current_scene != null and current_scene.name == "MainMenu",
		"Run-ended Main Menu did not open the existing menu."
	)

	if _failures.is_empty():
		print("GAMEPLAY LOOP TEST: PASS")
		quit(0)
	else:
		print("GAMEPLAY LOOP TEST: FAIL (%d failures)" % _failures.size())
		quit(1)


func _on_isolated_level_up(_level: int, _restore: float) -> void:
	_levels_emitted += 1


func _on_isolated_pickup_collected(amount: int) -> void:
	_pickup_emissions += 1
	_last_pickup_value = amount


func _on_isolated_depleted() -> void:
	_depletion_emissions += 1
