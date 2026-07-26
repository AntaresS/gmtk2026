extends Node

const GAME_SCENE := preload("res://game/scenes/gameplay/game.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("WORLD RENDER CACHE TEST: %s" % message)


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame


func _run() -> void:
	var game := GAME_SCENE.instantiate()
	add_child(game)
	await _wait_process_frames(4)

	var world := game.get_node("InfiniteWorld") as InfiniteWorld
	var player := game.get_node("Player") as PlayerController
	var fork_spawner := game.get_node("RoadForkSpawner") as RoadForkSpawner
	_check(world != null, "Gameplay has no InfiniteWorld.")
	_check(player != null, "Gameplay has no player.")
	_check(fork_spawner != null, "Gameplay has no RoadForkSpawner.")
	if world == null or player == null or fork_spawner == null:
		_finish()
		return

	_check(
		world.get_active_chunk_count() == world.active_chunk_count,
		"Runtime chunk pool did not retain its configured fixed size."
	)
	_check(
		world.active_chunk_count == 8,
		"Optimization changed the established eight-chunk pool."
	)
	_check_world_chunk_caches(world)

	var chunk_height := world.chunk_config.get_pixel_size().y
	player.global_position.y -= chunk_height * 2.0
	await _wait_physics_frames(3)
	await _wait_process_frames(3)
	_check(
		world.get_active_chunk_count() == 8,
		"Chunk recycling changed the fixed pool size."
	)
	_check_world_chunk_caches(world)

	fork_spawner.set_forks_enabled(false)
	fork_spawner.call("_spawn_fork")
	await _wait_process_frames(4)
	var forks := get_tree().get_nodes_in_group("road_forks")
	_check(not forks.is_empty(), "Focused setup did not create a road fork.")
	if not forks.is_empty():
		var road_fork := forks[0] as RoadFork
		var visual_cache := road_fork.get_node_or_null("VisualCache")
		_check(
			visual_cache != null
			and bool(visual_cache.call("is_cache_visible")),
			"Road fork static surface did not finish its one-time cache."
		)
		_check(
			visual_cache != null
			and visual_cache.call("get_cache_size").x <= 4096
			and visual_cache.call("get_cache_size").y <= 4096,
			"Road fork cache exceeded the WebGL-safe texture bound."
		)
		_check(
			road_fork.get_curve_centerline_points().size() > 20
			and not road_fork.call("_get_visible_road_polygons").is_empty(),
			"Road fork cache changed its route geometry."
		)
		var normal_curve_size := road_fork.get_curve_centerline_points().size()
		road_fork.set("_selected_branch", "继续当前主路")
		road_fork.call("_rebuild_visual_cache")
		await _wait_process_frames(4)
		_check(
			road_fork.get_curve_centerline_points().size() > normal_curve_size
			and bool(visual_cache.call("is_cache_visible")),
			"Rejected branch did not rebuild its offscreen exit cache."
		)
		_check(
			visual_cache.call("get_cache_size").x <= 4096
			and visual_cache.call("get_cache_size").y <= 4096,
			"Rejected branch cache exceeded the WebGL-safe texture bound."
		)
		road_fork.set("_selected_branch", "")
		road_fork.set("_route_was_committed", false)
		road_fork.global_position = Vector2(
			world.get_route_center_x(),
			player.global_position.y - 200.0
		)
		road_fork.call("_rebuild_visual_cache")
		road_fork.set_fork_enabled(true)
		await _wait_physics_frames(2)
		player.global_position = Vector2(
			road_fork.get_branch_center_x() + 24.0,
			road_fork.global_position.y + 50.0
		)
		await _wait_physics_frames(2)
		_check(
			not road_fork.get_selected_branch().is_empty()
			and road_fork.get_selected_branch() != "继续当前主路"
			and is_equal_approx(
				world.get_route_center_x(),
				road_fork.get_branch_center_x()
			),
			(
				"Cached fork did not preserve branch selection and route "
				+ "commitment (selected=%s, world=%.1f, branch=%.1f)."
			) % [
				road_fork.get_selected_branch(),
				world.get_route_center_x(),
				road_fork.get_branch_center_x(),
			]
		)

	world.set_trial_hell_active(true)
	await _wait_process_frames(4)
	_check(world.is_trial_hell_active(), "Trial Hell state was not retained.")
	_check_world_chunk_caches(world)
	_finish()


func _check_world_chunk_caches(world: InfiniteWorld) -> void:
	for child in world.get_children():
		if child is not WorldChunk:
			continue
		var chunk := child as WorldChunk
		var tile_layer := chunk.get_node_or_null("GeneratedTileMapLayer")
		var visual_cache := chunk.get_node_or_null("VisualCache")
		_check(
			tile_layer is TileMapLayer
			and (tile_layer as TileMapLayer).get_used_cells().is_empty(),
			"Runtime chunk still rebuilt hidden generated tile cells."
		)
		_check(
			visual_cache != null
			and bool(visual_cache.call("is_cache_visible")),
			"Runtime chunk visual cache was not ready."
		)
		_check(
			visual_cache != null
			and is_equal_approx(
				float(visual_cache.call("get_raster_scale")),
				minf(
					absf(get_viewport().get_camera_2d().zoom.x),
					absf(get_viewport().get_camera_2d().zoom.y)
				)
			),
			"Runtime chunk cache did not use the displayed pixel density."
		)
		_check(
			visual_cache != null
			and visual_cache.call("get_cache_size").x
				< roundi(world.chunk_config.get_pixel_size().x)
			and visual_cache.call("get_cache_size").y
				< roundi(world.chunk_config.get_pixel_size().y),
			"Runtime chunk cache retained full world-resolution texture cost."
		)


func _finish() -> void:
	if _failures.is_empty():
		print("WORLD RENDER CACHE SMOKE: PASS")
		get_tree().quit(0)
		return
	print("WORLD RENDER CACHE SMOKE: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
