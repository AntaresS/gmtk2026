@tool
class_name WorldChunk
extends Node2D

signal qi_collected(amount: int)

const QI_PROFILE: QiDensityProfile = preload(
	"res://game/resources/qi_profile.tres"
)
const StaticCanvasCacheResource = preload(
	"res://game/scripts/gameplay/static_canvas_cache.gd"
)

@export_category("Chunk Definition")
## Shared source of chunk dimensions, road width, seed, TileSet, and tile IDs.
## InfiniteWorld supplies the same resource to every runtime chunk.
@export var config: WorldChunkConfig:
	set(value):
		_disconnect_config()
		config = value
		_connect_config()
		_request_editor_preview()

@export_category("Pickup Generation")
## Reusable Area2D scene placed into this chunk at runtime. It must instantiate
## a QiPickup so collection can be routed through the pooled world.
@export var qi_pickup_scene: PackedScene = preload(
	"res://game/scenes/gameplay/qi_pickup.tscn"
)

## Minimum candidate positions tested in each regenerated chunk. The single qi
## profile's spawn percentage determines how many become real pickups.
@export_range(1, 40, 1) var min_pickups_per_chunk: int = 10
## Maximum candidate positions tested in each regenerated chunk.
@export_range(1, 40, 1) var max_pickups_per_chunk: int = 18
## Probability that the next placement operation creates a local cluster
## instead of one independent pickup.
@export_range(0.0, 1.0, 0.05) var pickup_group_chance: float = 0.68
## Minimum number of pickups requested when a cluster is generated.
@export_range(2, 8, 1) var min_pickups_per_group: int = 2
## Maximum number of pickups requested when a cluster is generated.
@export_range(2, 8, 1) var max_pickups_per_group: int = 5
## Maximum radial scatter, in world pixels, around a generated cluster center.
@export_range(8.0, 160.0, 1.0) var pickup_group_scatter_radius: float = 58.0
## Preferred center-to-center spacing, in world pixels. Placement retries keep
## visuals readable while retaining visibly grouped distributions.
@export_range(8.0, 80.0, 1.0) var minimum_pickup_spacing: float = 24.0
## Clearance, in world pixels, between pickup centers and each road edge.
@export_range(8.0, 100.0, 1.0) var pickup_edge_clearance: float = 34.0

@export_category("Editor Preview")
## Draws generated terrain in the 2D editor. This affects editor visualization
## only and does not disable runtime terrain generation.
@export var preview_enabled: bool = true:
	set(value):
		preview_enabled = value
		if preview_enabled:
			_request_editor_preview()
		else:
			_clear_editor_preview()
## Seed index used by this scene's deterministic editor preview. Adjacent
## preview instances use consecutive indices to expose visible seams.
@export var preview_chunk_index: int = 0:
	set(value):
		preview_chunk_index = value
		_request_editor_preview()
## Shows cyan chunk bounds, origin cross, and negative-Y forward arrow in the
## editor. These helpers are never drawn during gameplay.
@export var show_editor_helpers: bool = true:
	set(value):
		show_editor_helpers = value
		queue_redraw()

var chunk_index: int = 0
var _tile_map_layer: TileMapLayer
var _pickup_container: Node2D
var _show_fallback: bool = true
var _preview_update_queued: bool = false
var _trial_hell_active: bool = false
var _visual_cache: Node2D
var _visual_cache_ready: bool = false
var _is_visual_cache_painter: bool = false
var _visual_cache_rebuild_queued: bool = false


func _enter_tree() -> void:
	if _is_visual_cache_painter:
		return
	_ensure_tile_map_layer()
	_connect_config()
	_request_editor_preview()


func _exit_tree() -> void:
	if _is_visual_cache_painter:
		return
	_disconnect_config()


func configure(new_chunk_index: int, new_config: WorldChunkConfig) -> void:
	chunk_index = new_chunk_index
	config = new_config

	if not is_node_ready():
		await ready
	_build_terrain()
	_regenerate_pickups()


func _ensure_tile_map_layer() -> void:
	if is_instance_valid(_tile_map_layer):
		return
	_tile_map_layer = TileMapLayer.new()
	_tile_map_layer.name = "GeneratedTileMapLayer"
	_tile_map_layer.show_behind_parent = true
	add_child(_tile_map_layer, false, Node.INTERNAL_MODE_FRONT)


func _build_terrain() -> void:
	_ensure_tile_map_layer()
	if not Engine.is_editor_hint():
		_prepare_runtime_terrain()
		_request_visual_cache_rebuild()
		return

	_tile_map_layer.clear()

	if config == null:
		_tile_map_layer.tile_set = null
		_tile_map_layer.visible = false
		_show_fallback = true
		queue_redraw()
		return

	_tile_map_layer.tile_set = config.terrain_tileset
	_tile_map_layer.position = -config.get_pixel_size() * 0.5

	if config.terrain_tileset == null:
		_show_fallback = true
	elif config.use_terrain_painting:
		_show_fallback = not _paint_terrain_set()
	else:
		_show_fallback = not _paint_atlas_tiles()

	_tile_map_layer.visible = not _show_fallback
	queue_redraw()


## Runtime visuals are fully opaque, so the generated atlas layer beneath them
## was invisible while still rebuilding and submitting all 4,096 tile cells.
## Keep editor atlas previews intact and validate only the runtime source here.
func _prepare_runtime_terrain() -> void:
	_tile_map_layer.clear()
	_tile_map_layer.visible = false
	_tile_map_layer.tile_set = null

	if config == null:
		_show_fallback = true
		queue_redraw()
		return

	if config.use_terrain_painting:
		_show_fallback = not _terrain_definition_is_valid()
	else:
		_show_fallback = not (
			_atlas_tile_exists(
				config.road_source_id,
				config.road_atlas_coordinates
			)
			and _atlas_tile_exists(
				config.ground_source_id,
				config.ground_atlas_coordinates
			)
		)
	queue_redraw()


func _terrain_definition_is_valid() -> bool:
	if config.terrain_tileset == null:
		return false
	if (
		config.terrain_set < 0
		or config.terrain_set >= config.terrain_tileset.get_terrain_sets_count()
	):
		return false
	var terrain_count := config.terrain_tileset.get_terrains_count(
		config.terrain_set
	)
	return (
		config.road_terrain >= 0
		and config.road_terrain < terrain_count
		and config.ground_terrain >= 0
		and config.ground_terrain < terrain_count
	)


func _regenerate_pickups() -> void:
	if Engine.is_editor_hint():
		return
	_ensure_pickup_container()
	_clear_pickups()
	if config == null or qi_pickup_scene == null:
		return

	var rng := _create_pickup_rng()
	for pickup_position in _get_scattered_pickup_positions(rng):
		if rng.randf() > clampf(QI_PROFILE.spawn_weight / 100.0, 0.0, 1.0):
			continue
		var pickup := qi_pickup_scene.instantiate() as QiPickup
		if pickup == null:
			push_error("WorldChunk qi_pickup_scene must instantiate a QiPickup.")
			return
		_pickup_container.add_child(pickup)
		pickup.position = pickup_position
		pickup.configure_density(QI_PROFILE)
		pickup.qi_collected.connect(_on_qi_pickup_collected)


func _ensure_pickup_container() -> void:
	if is_instance_valid(_pickup_container):
		return
	_pickup_container = Node2D.new()
	_pickup_container.name = "Pickups"
	add_child(_pickup_container)


func _clear_pickups() -> void:
	if not is_instance_valid(_pickup_container):
		return
	for child in _pickup_container.get_children():
		if child is QiPickup:
			(child as QiPickup).disable_collection()
		_pickup_container.remove_child(child)
		child.queue_free()


func _create_pickup_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(config.world_seed, chunk_index, 7919))
	return rng


func _get_scattered_pickup_positions(
	rng: RandomNumberGenerator
) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var chunk_height := config.get_pixel_size().y
	var maximum_count := maxi(max_pickups_per_chunk, 1)
	var minimum_count := clampi(
		min_pickups_per_chunk,
		1,
		maximum_count
	)
	var target_count := rng.randi_range(minimum_count, maximum_count)
	var usable_half_height := maxf(chunk_height * 0.5 - 34.0, 1.0)
	var minimum_group_size := maxi(min_pickups_per_group, 2)
	var maximum_group_size := maxi(
		max_pickups_per_group,
		minimum_group_size
	)

	while positions.size() < target_count:
		var grouped := rng.randf() < clampf(pickup_group_chance, 0.0, 1.0)
		var requested_count := 1
		if grouped:
			requested_count = rng.randi_range(
				minimum_group_size,
				maximum_group_size
			)
		var group_y := rng.randf_range(
			-usable_half_height,
			usable_half_height
		)
		var group_half_width := _get_usable_pickup_half_width(group_y)
		var group_center := Vector2(
			rng.randf_range(-group_half_width, group_half_width),
			group_y
		)

		for member_index in requested_count:
			if positions.size() >= target_count:
				break
			var candidate := group_center
			if grouped and member_index > 0:
				var angle := rng.randf_range(0.0, TAU)
				var scatter := rng.randf_range(
					minimum_pickup_spacing,
					maxf(
						pickup_group_scatter_radius,
						minimum_pickup_spacing
					)
				)
				candidate += Vector2.from_angle(angle) * scatter
			candidate.y = clampf(
				candidate.y,
				-usable_half_height,
				usable_half_height
			)
			var candidate_half_width := _get_usable_pickup_half_width(
				candidate.y
			)
			candidate.x = clampf(
				candidate.x,
				-candidate_half_width,
				candidate_half_width
			)
			positions.append(
				_find_readable_pickup_position(
					candidate,
					positions,
					rng,
					usable_half_height
				)
			)
	return positions


func _find_readable_pickup_position(
	initial_position: Vector2,
	existing_positions: Array[Vector2],
	rng: RandomNumberGenerator,
	usable_half_height: float
) -> Vector2:
	var candidate := initial_position
	for _attempt in 8:
		if _is_position_separated(candidate, existing_positions):
			return candidate
		var angle := rng.randf_range(0.0, TAU)
		candidate += Vector2.from_angle(angle) * minimum_pickup_spacing
		candidate.y = clampf(
			candidate.y,
			-usable_half_height,
			usable_half_height
		)
		var candidate_half_width := _get_usable_pickup_half_width(
			candidate.y
		)
		candidate.x = clampf(
			candidate.x,
			-candidate_half_width,
			candidate_half_width
		)
	return candidate


func _get_usable_pickup_half_width(local_y: float) -> float:
	return maxf(
		_get_road_half_width_for_local_y(local_y) - pickup_edge_clearance,
		1.0
	)


func _is_position_separated(
	candidate: Vector2,
	existing_positions: Array[Vector2]
) -> bool:
	var required_spacing_squared := minimum_pickup_spacing * minimum_pickup_spacing
	for existing_position in existing_positions:
		if candidate.distance_squared_to(existing_position) < required_spacing_squared:
			return false
	return true


func _on_qi_pickup_collected(amount: int) -> void:
	qi_collected.emit(amount)


func get_pickup_count() -> int:
	if not is_instance_valid(_pickup_container):
		return 0
	return _pickup_container.get_child_count()


## Public deterministic width sampler for tests, previews, and future debug UI.
func get_road_half_width_at_local_y(local_y: float) -> float:
	return _get_road_half_width_for_local_y(local_y)


## Switches the runtime road between its normal palette and Trial Hell's
## dark volcanic surface without rebuilding deterministic contents.
func set_trial_hell_active(active: bool) -> void:
	if _trial_hell_active == active:
		return
	_trial_hell_active = active
	if not Engine.is_editor_hint() and not _is_visual_cache_painter:
		_request_visual_cache_rebuild()
	queue_redraw()


func is_trial_hell_active() -> bool:
	return _trial_hell_active


func _paint_terrain_set() -> bool:
	if (
		config.terrain_set < 0
		or config.terrain_set >= config.terrain_tileset.get_terrain_sets_count()
	):
		push_warning("WorldChunk terrain_set is not valid; using the fallback terrain.")
		return false

	var terrain_count := config.terrain_tileset.get_terrains_count(config.terrain_set)
	if (
		config.road_terrain < 0
		or config.road_terrain >= terrain_count
		or config.ground_terrain < 0
		or config.ground_terrain >= terrain_count
	):
		push_warning("WorldChunk terrain IDs are not valid; using the fallback terrain.")
		return false

	var road_cells: Array[Vector2i] = []
	var ground_cells: Array[Vector2i] = []
	for y in config.size_tiles.y:
		var local_y := (
			(float(y) + 0.5) * config.tile_size
			- config.get_pixel_size().y * 0.5
		)
		var row_road_half_width := _get_road_half_width_for_local_y(local_y)
		for x in config.size_tiles.x:
			var local_x := (
				(float(x) + 0.5) * config.tile_size
				- config.get_pixel_size().x * 0.5
			)
			if absf(local_x) <= row_road_half_width:
				road_cells.append(Vector2i(x, y))
			else:
				ground_cells.append(Vector2i(x, y))

	_tile_map_layer.set_cells_terrain_connect(
		ground_cells,
		config.terrain_set,
		config.ground_terrain,
		true
	)
	_tile_map_layer.set_cells_terrain_connect(
		road_cells,
		config.terrain_set,
		config.road_terrain,
		true
	)
	return true


func _paint_atlas_tiles() -> bool:
	if not _atlas_tile_exists(
		config.road_source_id,
		config.road_atlas_coordinates
	):
		push_warning("WorldChunk road atlas tile is not valid; using the fallback terrain.")
		return false
	if not _atlas_tile_exists(
		config.ground_source_id,
		config.ground_atlas_coordinates
	):
		push_warning("WorldChunk ground atlas tile is not valid; using the fallback terrain.")
		return false

	var has_ground_variant := _atlas_tile_exists(
		config.ground_source_id,
		config.ground_variant_atlas_coordinates
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed()

	for y in config.size_tiles.y:
		var local_y := (
			(float(y) + 0.5) * config.tile_size
			- config.get_pixel_size().y * 0.5
		)
		var row_road_half_width := _get_road_half_width_for_local_y(local_y)
		for x in config.size_tiles.x:
			var local_x := (
				(float(x) + 0.5) * config.tile_size
				- config.get_pixel_size().x * 0.5
			)
			var cell := Vector2i(x, y)
			if absf(local_x) <= row_road_half_width:
				_tile_map_layer.set_cell(
					cell,
					config.road_source_id,
					config.road_atlas_coordinates
				)
			else:
				var atlas_coordinates := config.ground_atlas_coordinates
				if (
					has_ground_variant
					and rng.randf() < config.ground_variation_chance
				):
					atlas_coordinates = config.ground_variant_atlas_coordinates
				_tile_map_layer.set_cell(
					cell,
					config.ground_source_id,
					atlas_coordinates
				)
	return true


func _atlas_tile_exists(source_id: int, atlas_coordinates: Vector2i) -> bool:
	if (
		config == null
		or config.terrain_tileset == null
		or not config.terrain_tileset.has_source(source_id)
	):
		return false
	var source := config.terrain_tileset.get_source(source_id)
	return source is TileSetAtlasSource and source.has_tile(atlas_coordinates)


func _chunk_seed() -> int:
	return hash(Vector2i(config.world_seed, chunk_index))


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_editor_preview()
		return
	if not _is_visual_cache_painter and _visual_cache_ready:
		return
	_draw_runtime_visual()


func _draw_runtime_visual() -> void:
	if config == null:
		return

	var chunk_size := config.get_pixel_size()
	if not _show_fallback:
		_draw_loess_terrain_base(chunk_size)
		if _trial_hell_active:
			_draw_trial_hell_overlay(chunk_size)
		else:
			_draw_bluestone_road_texture(chunk_size)
			_draw_road_surface_wear(chunk_size)
			_draw_irregular_road_edges(chunk_size)
			_draw_road_edge_decorations(chunk_size)
		return
	_draw_fallback_terrain(chunk_size)
	if _trial_hell_active:
		_draw_trial_hell_overlay(chunk_size)


func _request_visual_cache_rebuild() -> void:
	if _visual_cache_rebuild_queued:
		return
	_visual_cache_rebuild_queued = true
	call_deferred("_rebuild_visual_cache")


func _rebuild_visual_cache() -> void:
	_visual_cache_rebuild_queued = false
	if Engine.is_editor_hint() or _is_visual_cache_painter or config == null:
		return
	_ensure_visual_cache()
	_visual_cache_ready = false
	queue_redraw()

	var painter := WorldChunk.new()
	painter._is_visual_cache_painter = true
	painter.chunk_index = chunk_index
	painter.config = config
	painter._show_fallback = _show_fallback
	painter._trial_hell_active = _trial_hell_active
	var chunk_size := config.get_pixel_size()
	_visual_cache.call(
		"rebuild",
		painter,
		Rect2(-chunk_size * 0.5, chunk_size),
		_get_visual_cache_raster_scale()
	)


func _ensure_visual_cache() -> void:
	if is_instance_valid(_visual_cache):
		return
	_visual_cache = StaticCanvasCacheResource.new()
	_visual_cache.name = "VisualCache"
	_visual_cache.z_index = -1
	add_child(_visual_cache, false, Node.INTERNAL_MODE_FRONT)
	_visual_cache.cache_ready.connect(_on_visual_cache_ready)


func _on_visual_cache_ready() -> void:
	_visual_cache_ready = true
	queue_redraw()


func _get_visual_cache_raster_scale() -> float:
	var active_camera := get_viewport().get_camera_2d()
	if not is_instance_valid(active_camera):
		return 1.0
	return clampf(
		minf(absf(active_camera.zoom.x), absf(active_camera.zoom.y)),
		0.25,
		2.0
	)


func _draw_trial_hell_overlay(chunk_size: Vector2) -> void:
	var chunk_rect := Rect2(-chunk_size * 0.5, chunk_size)
	draw_rect(chunk_rect, Color(0.085, 0.045, 0.032, 1.0))
	_draw_trial_hell_background_variation(chunk_size)
	draw_colored_polygon(
		_get_road_polygon(chunk_size, -12.0),
		Color(0.30, 0.105, 0.035, 1.0)
	)
	draw_colored_polygon(
		_get_road_polygon(chunk_size),
		Color(0.19, 0.105, 0.060, 1.0)
	)
	_draw_trial_hell_surface(chunk_size)


func _draw_trial_hell_background_variation(chunk_size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(config.world_seed, chunk_index, 82981))
	var patch_count := maxi(roundi(chunk_size.y / 44.0), 14)
	for _patch in patch_count:
		var center := Vector2(
			rng.randf_range(-chunk_size.x * 0.5, chunk_size.x * 0.5),
			rng.randf_range(-chunk_size.y * 0.5, chunk_size.y * 0.5)
		)
		var radii := Vector2(
			rng.randf_range(18.0, 96.0),
			rng.randf_range(9.0, 42.0)
		)
		var color := Color(0.13, 0.063, 0.040, 0.62)
		match rng.randi_range(0, 3):
			1:
				color = Color(0.055, 0.030, 0.026, 0.72)
			2:
				color = Color(0.17, 0.075, 0.038, 0.42)
			3:
				color = Color(0.105, 0.080, 0.066, 0.45)
		draw_colored_polygon(
			_make_irregular_ellipse(
				center,
				radii,
				Vector2.RIGHT,
				Vector2.DOWN,
				rng
			),
			color
		)


func _draw_trial_hell_surface(chunk_size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(config.world_seed, chunk_index, 84011))
	var patch_count := maxi(roundi(chunk_size.y / 34.0), 16)
	for patch_index in patch_count:
		var center_y := rng.randf_range(
			-chunk_size.y * 0.5 + 14.0,
			chunk_size.y * 0.5 - 14.0
		)
		var limits := _get_visual_road_x_limits(center_y, 18.0)
		var radius_x := rng.randf_range(7.0, 44.0)
		var radius_y := rng.randf_range(4.0, 24.0)
		if patch_index % 4 == 0:
			radius_x = rng.randf_range(30.0, 68.0)
			radius_y = rng.randf_range(12.0, 31.0)
		var center := Vector2(
			rng.randf_range(
				limits.x + radius_x,
				limits.y - radius_x
			),
			center_y
		)
		var patch_color := Color(0.255, 0.135, 0.068, 0.62)
		match rng.randi_range(0, 4):
			1:
				patch_color = Color(0.125, 0.060, 0.035, 0.76)
			2:
				patch_color = Color(0.34, 0.155, 0.055, 0.46)
			3:
				patch_color = Color(0.215, 0.085, 0.035, 0.68)
			4:
				patch_color = Color(0.29, 0.19, 0.105, 0.44)
		draw_colored_polygon(
			_make_irregular_ellipse(
				center,
				Vector2(radius_x, radius_y),
				Vector2.RIGHT,
				Vector2.DOWN,
				rng
			),
			patch_color
		)

	var pit_count := maxi(roundi(chunk_size.y / 58.0), 10)
	for _pit in pit_count:
		var pit_y := rng.randf_range(
			-chunk_size.y * 0.5 + 12.0,
			chunk_size.y * 0.5 - 12.0
		)
		var pit_limits := _get_visual_road_x_limits(pit_y, 28.0)
		var pit_center := Vector2(
			rng.randf_range(pit_limits.x, pit_limits.y),
			pit_y
		)
		var pit_radius := Vector2(
			rng.randf_range(5.0, 19.0),
			rng.randf_range(3.0, 10.0)
		)
		draw_colored_polygon(
			_make_irregular_ellipse(
				pit_center + Vector2(0.0, 1.5),
				pit_radius * 1.22,
				Vector2.RIGHT,
				Vector2.DOWN,
				rng
			),
			Color(0.38, 0.19, 0.075, 0.42)
		)
		draw_colored_polygon(
			_make_irregular_ellipse(
				pit_center,
				pit_radius,
				Vector2.RIGHT,
				Vector2.DOWN,
				rng
			),
			Color(0.075, 0.035, 0.024, 0.84)
		)


func _make_irregular_ellipse(
	center: Vector2,
	radii: Vector2,
	axis_x: Vector2,
	axis_y: Vector2,
	rng: RandomNumberGenerator
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var point_count := rng.randi_range(8, 12)
	for point_index in point_count:
		var angle := TAU * float(point_index) / float(point_count)
		var distortion := rng.randf_range(0.76, 1.18)
		points.append(
			center
			+ axis_x * cos(angle) * radii.x * distortion
			+ axis_y * sin(angle) * radii.y * distortion
		)
	return points


func _draw_fallback_terrain(chunk_size: Vector2) -> void:
	_draw_loess_terrain_base(chunk_size)
	if not _trial_hell_active:
		_draw_bluestone_road_texture(chunk_size)
		_draw_road_surface_wear(chunk_size)
		_draw_irregular_road_edges(chunk_size, 8.0)
		_draw_road_edge_decorations(chunk_size, 8.0)


func _draw_loess_terrain_base(chunk_size: Vector2) -> void:
	var chunk_rect := Rect2(-chunk_size * 0.5, chunk_size)
	draw_rect(chunk_rect, Color(0.43, 0.31, 0.145, 1.0))
	_draw_ground_variation(chunk_size)
	draw_colored_polygon(
		_get_road_polygon(chunk_size, -8.0),
		Color(0.34, 0.25, 0.14, 1.0)
	)
	draw_colored_polygon(_get_road_polygon(chunk_size), Color("625f55"))


func _draw_editor_preview() -> void:
	if not preview_enabled or config == null:
		return

	var chunk_size := config.get_pixel_size()
	var drew_atlas := false
	if not config.use_terrain_painting:
		drew_atlas = _draw_atlas_preview(chunk_size)

	if drew_atlas:
		_draw_loess_terrain_base(chunk_size)
		_draw_bluestone_road_texture(chunk_size)
		_draw_road_surface_wear(chunk_size)
		_draw_irregular_road_edges(chunk_size)
		_draw_road_edge_decorations(chunk_size)
	elif config.use_terrain_painting and _tile_map_layer.visible:
		_draw_loess_terrain_base(chunk_size)
		_draw_bluestone_road_texture(chunk_size)
		_draw_road_surface_wear(chunk_size)
		_draw_irregular_road_edges(chunk_size)
		_draw_road_edge_decorations(chunk_size)
	else:
		_draw_fallback_terrain(chunk_size)
	_draw_editor_helpers(chunk_size)


func _draw_atlas_preview(chunk_size: Vector2) -> bool:
	if (
		config.terrain_tileset == null
		or not config.terrain_tileset.has_source(config.road_source_id)
		or not config.terrain_tileset.has_source(config.ground_source_id)
	):
		return false

	var road_source := (
		config.terrain_tileset.get_source(config.road_source_id)
		as TileSetAtlasSource
	)
	var ground_source := (
		config.terrain_tileset.get_source(config.ground_source_id)
		as TileSetAtlasSource
	)
	if (
		road_source == null
		or ground_source == null
		or not road_source.has_tile(config.road_atlas_coordinates)
		or not ground_source.has_tile(config.ground_atlas_coordinates)
	):
		return false

	var has_ground_variant := ground_source.has_tile(
		config.ground_variant_atlas_coordinates
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed()
	var top_left := -chunk_size * 0.5

	for y in config.size_tiles.y:
		var local_y := (
			(float(y) + 0.5) * config.tile_size
			- chunk_size.y * 0.5
		)
		var row_road_half_width := _get_road_half_width_for_local_y(local_y)
		for x in config.size_tiles.x:
			var local_x := (
				(float(x) + 0.5) * config.tile_size
				- chunk_size.x * 0.5
			)
			var atlas_source := ground_source
			var atlas_coordinates := config.ground_atlas_coordinates
			if absf(local_x) <= row_road_half_width:
				atlas_source = road_source
				atlas_coordinates = config.road_atlas_coordinates
			elif (
				has_ground_variant
				and rng.randf() < config.ground_variation_chance
			):
				atlas_coordinates = config.ground_variant_atlas_coordinates
			_draw_atlas_tile(
				atlas_source,
				atlas_coordinates,
				top_left + Vector2(x, y) * config.tile_size
			)
	return true


func _draw_atlas_tile(
	atlas_source: TileSetAtlasSource,
	atlas_coordinates: Vector2i,
	destination: Vector2
) -> void:
	var region_size := atlas_source.texture_region_size
	var source_position := (
		atlas_source.margins
		+ atlas_coordinates * (region_size + atlas_source.separation)
	)
	draw_texture_rect_region(
		atlas_source.texture,
		Rect2(
			destination,
			Vector2(config.tile_size, config.tile_size)
		),
		Rect2(Vector2(source_position), Vector2(region_size))
	)


## Adds deterministic, staggered bluestone slabs without repeating one atlas
## cell across the whole road. Each chunk keeps a stable pattern for its seed.
func _draw_bluestone_road_texture(chunk_size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(config.world_seed, chunk_index, 24859))
	var row_y := -chunk_size.y * 0.5 + rng.randf_range(6.0, 16.0)
	while row_y < chunk_size.y * 0.5:
		var small_row := rng.randf() < 0.68
		var slab_height := (
			rng.randf_range(10.0, 22.0)
			if small_row
			else rng.randf_range(22.0, 32.0)
		)
		var road_limits := _get_visual_road_x_limits(
			row_y + slab_height * 0.5,
			10.0
		)
		var slab_x := road_limits.x + rng.randf_range(-24.0, 10.0)
		while slab_x < road_limits.y:
			var small_slab := rng.randf() < 0.68
			var slab_width := (
				rng.randf_range(14.0, 48.0)
				if small_slab
				else rng.randf_range(48.0, 98.0)
			)
			var gap := rng.randf_range(1.5, 22.0)
			var left := maxf(slab_x, road_limits.x)
			var right := minf(slab_x + slab_width, road_limits.y)
			if right - left >= 8.0 and rng.randf() > 0.10:
				_draw_bluestone_slab(
					Rect2(
						Vector2(left, row_y),
						Vector2(right - left, slab_height)
					),
					rng
				)
			slab_x += slab_width + gap
		row_y += slab_height + rng.randf_range(2.0, 16.0)


func _draw_bluestone_slab(
	rect: Rect2,
	rng: RandomNumberGenerator
) -> void:
	var corner_jitter := minf(rect.size.y * 0.16, 3.5)
	var points := PackedVector2Array([
		rect.position + Vector2(
			rng.randf_range(0.0, corner_jitter),
			rng.randf_range(0.0, corner_jitter)
		),
		Vector2(rect.end.x, rect.position.y) + Vector2(
			-rng.randf_range(0.0, corner_jitter),
			rng.randf_range(0.0, corner_jitter)
		),
		rect.end - Vector2(
			rng.randf_range(0.0, corner_jitter),
			rng.randf_range(0.0, corner_jitter)
		),
		Vector2(rect.position.x, rect.end.y) + Vector2(
			rng.randf_range(0.0, corner_jitter),
			-rng.randf_range(0.0, corner_jitter)
		),
	])
	var base_color := Color(0.57, 0.55, 0.49, 1.0)
	match rng.randi_range(0, 4):
		1:
			base_color = Color(0.52, 0.51, 0.47, 1.0)
		2:
			base_color = Color(0.62, 0.59, 0.51, 1.0)
		3:
			base_color = Color(0.65, 0.61, 0.53, 1.0)
		4:
			base_color = Color(0.55, 0.54, 0.50, 1.0)
	var shade := rng.randf_range(-0.028, 0.035)
	var fill_color := Color(
		base_color.r + shade,
		base_color.g + shade,
		base_color.b + shade,
		rng.randf_range(0.62, 0.80)
	)
	draw_colored_polygon(points, fill_color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color(0.18, 0.17, 0.14, 0.34), 1.0, true)
	var detail_variant := rng.randi_range(0, 4)
	match detail_variant:
		0:
			var grain_y := rect.position.y + rect.size.y * 0.58
			draw_line(
				Vector2(rect.position.x + 7.0, grain_y),
				Vector2(rect.end.x - 7.0, grain_y + rng.randf_range(-2.0, 2.0)),
				Color(0.68, 0.66, 0.57, 0.22),
				1.0,
				true
			)
		1:
			for _pit in rng.randi_range(1, 3):
				draw_circle(
					rect.get_center() + Vector2(
						rng.randf_range(-rect.size.x * 0.32, rect.size.x * 0.32),
						rng.randf_range(-rect.size.y * 0.26, rect.size.y * 0.26)
					),
					rng.randf_range(0.7, 1.6),
					Color(0.08, 0.14, 0.15, 0.20)
				)
		2:
			draw_line(
				Vector2(rect.position.x + 5.0, rect.end.y - 3.0),
				Vector2(
					rect.position.x + rect.size.x * rng.randf_range(0.35, 0.78),
					rect.end.y - 2.0
				),
				Color(0.24, 0.39, 0.25, 0.24),
				2.0,
				true
			)
		3:
			if rect.size.x > 28.0:
				var crack_start := rect.get_center() + Vector2(
					rng.randf_range(-rect.size.x * 0.18, rect.size.x * 0.12),
					-rng.randf_range(1.0, rect.size.y * 0.22)
				)
				draw_line(
					crack_start,
					crack_start + Vector2(
						rng.randf_range(5.0, 13.0),
						rng.randf_range(3.0, 8.0)
					),
					Color(0.07, 0.12, 0.13, 0.28),
					1.0,
					true
				)
	if (
		detail_variant != 3
		and rect.size.x > 24.0
		and rng.randf() < 0.38
	):
		var extra_crack_start := rect.get_center() + Vector2(
			rng.randf_range(-rect.size.x * 0.24, rect.size.x * 0.14),
			rng.randf_range(-rect.size.y * 0.20, rect.size.y * 0.10)
		)
		var extra_crack_middle := extra_crack_start + Vector2(
			rng.randf_range(3.0, minf(10.0, rect.size.x * 0.24)),
			rng.randf_range(2.0, minf(6.0, rect.size.y * 0.30))
		)
		draw_polyline(
			PackedVector2Array([
				extra_crack_start,
				extra_crack_middle,
				extra_crack_middle + Vector2(
					rng.randf_range(-3.0, 5.0),
					rng.randf_range(2.0, 5.0)
				),
			]),
			Color(0.07, 0.12, 0.13, 0.32),
			1.0,
			true
		)


func _draw_road_edge_decorations(
	chunk_size: Vector2,
	edge_inset: float = 0.0
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(config.world_seed, chunk_index, 51071))
	var local_y := -chunk_size.y * 0.5 + rng.randf_range(8.0, 20.0)
	while local_y < chunk_size.y * 0.5 - 10.0:
		for side_value in [-1.0, 1.0]:
			if rng.randf() > 0.92:
				continue
			var road_limits := _get_visual_road_x_limits(
				local_y,
				edge_inset
			)
			var outward := Vector2(side_value, 0.0)
			var edge_x := (
				road_limits.x if side_value < 0.0 else road_limits.y
			)
			var root := Vector2(edge_x, local_y)
			root += outward * rng.randf_range(1.0, 7.0)
			root.y += rng.randf_range(-5.0, 5.0)
			if rng.randf() < 0.90:
				_draw_loess_cluster(root, outward, rng)
			else:
				_draw_rock_cluster(root, rng)
		local_y += rng.randf_range(24.0, 36.0)


func _draw_loess_cluster(
	root: Vector2,
	outward: Vector2,
	rng: RandomNumberGenerator
) -> void:
	var scale := rng.randf_range(0.78, 1.55)
	var tangent := Vector2(-outward.y, outward.x)
	draw_line(
		root - tangent * 15.0 * scale,
		root + tangent * 15.0 * scale,
		Color(0.24, 0.14, 0.045, 0.92),
		8.0 * scale,
		true
	)
	draw_circle(
		root + outward * 2.0 + Vector2(2.0, 3.0),
		13.0 * scale,
		Color(0.08, 0.045, 0.015, 0.38)
	)
	for layer_index in 3:
		var clod_count := rng.randi_range(4, 7)
		if layer_index == 0:
			clod_count = rng.randi_range(1, 2)
		elif layer_index == 1:
			clod_count = rng.randi_range(2, 4)
		for _clod in clod_count:
			var size := rng.randf_range(2.4, 5.5) * scale
			if layer_index == 0:
				size = rng.randf_range(13.0, 23.0) * scale
			elif layer_index == 1:
				size = rng.randf_range(6.0, 12.0) * scale
			var outward_offset := rng.randf_range(-5.0, 4.0) * scale
			if layer_index == 0:
				outward_offset = rng.randf_range(3.0, 10.0) * scale
			elif layer_index == 1:
				outward_offset = rng.randf_range(-1.0, 7.0) * scale
			var center := (
				root
				+ tangent * rng.randf_range(-16.0, 16.0) * scale
				+ outward * outward_offset
				+ Vector2(0.0, float(layer_index) * 2.0)
			)
			_draw_single_loess_clod(center, size, rng)


func _draw_single_loess_clod(
	center: Vector2,
	size: float,
	rng: RandomNumberGenerator
) -> void:
	var points := PackedVector2Array()
	var point_count := rng.randi_range(6, 9)
	for point_index in point_count:
		var angle := TAU * float(point_index) / float(point_count)
		var radius := size * rng.randf_range(0.72, 1.16)
		points.append(
			center + Vector2(
				cos(angle) * radius,
				sin(angle) * radius * rng.randf_range(0.58, 0.82)
			)
		)
	var base_color := Color(0.43, 0.27, 0.09, 0.98)
	match rng.randi_range(0, 3):
		1:
			base_color = Color(0.49, 0.32, 0.12, 0.98)
		2:
			base_color = Color(0.36, 0.21, 0.065, 0.98)
		3:
			base_color = Color(0.53, 0.36, 0.15, 0.98)
	draw_colored_polygon(points, base_color)
	if size > 5.5 and rng.randf() < 0.58:
		draw_line(
			center + Vector2(-size * 0.48, -size * 0.20),
			center + Vector2(size * 0.12, -size * 0.34),
			Color(0.67, 0.46, 0.21, 0.38),
			maxf(size * 0.10, 1.0),
			true
		)
	if size > 10.0 and rng.randf() < 0.36:
		draw_line(
			center + Vector2(-size * 0.05, -size * 0.10),
			center + Vector2(size * 0.24, size * 0.20),
			Color(0.20, 0.11, 0.03, 0.65),
			1.0,
			true
		)
	if size > 6.0 and rng.randf() < 0.32:
		draw_circle(
			center + Vector2(
				rng.randf_range(-size * 0.42, size * 0.42),
				rng.randf_range(-size * 0.24, size * 0.24)
			),
			rng.randf_range(0.6, 1.25),
			Color(0.22, 0.13, 0.035, 0.54)
		)


func _draw_road_surface_wear(chunk_size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(config.world_seed, chunk_index, 60493))
	var stain_count := maxi(roundi(chunk_size.y / 48.0), 6)
	for _stain in stain_count:
		var center_y := rng.randf_range(
			-chunk_size.y * 0.5 + 12.0,
			chunk_size.y * 0.5 - 12.0
		)
		var road_limits := _get_visual_road_x_limits(center_y, 18.0)
		var center := Vector2(
			rng.randf_range(road_limits.x, road_limits.y),
			center_y
		)
		var radius_x := rng.randf_range(10.0, 38.0)
		var radius_y := rng.randf_range(5.0, 17.0)
		var stain_points := PackedVector2Array()
		var point_count := rng.randi_range(7, 10)
		for point_index in point_count:
			var angle := TAU * float(point_index) / float(point_count)
			var distortion := rng.randf_range(0.68, 1.18)
			stain_points.append(
				center + Vector2(
					cos(angle) * radius_x * distortion,
					sin(angle) * radius_y * distortion
				)
			)
		draw_colored_polygon(
			stain_points,
			Color(0.15, 0.12, 0.085, rng.randf_range(0.08, 0.17))
		)

	var crack_count := maxi(roundi(chunk_size.y / 44.0), 7)
	for _crack in crack_count:
		var crack_y := rng.randf_range(
			-chunk_size.y * 0.5 + 16.0,
			chunk_size.y * 0.5 - 28.0
		)
		var road_limits := _get_visual_road_x_limits(crack_y, 24.0)
		var crack_points := PackedVector2Array()
		var current := Vector2(
			rng.randf_range(road_limits.x, road_limits.y),
			crack_y
		)
		crack_points.append(current)
		for _segment in rng.randi_range(2, 4):
			current += Vector2(
				rng.randf_range(-8.0, 8.0),
				rng.randf_range(4.0, 10.0)
			)
			crack_points.append(current)
		draw_polyline(
			crack_points,
			Color(0.07, 0.075, 0.07, rng.randf_range(0.28, 0.46)),
			rng.randf_range(0.8, 1.4),
			true
		)
		if rng.randf() < 0.45 and crack_points.size() >= 3:
			var branch_start := crack_points[rng.randi_range(
				1,
				crack_points.size() - 2
			)]
			draw_line(
				branch_start,
				branch_start + Vector2(
					rng.randf_range(-7.0, 7.0),
					rng.randf_range(3.0, 7.0)
				),
				Color(0.07, 0.075, 0.07, 0.34),
				1.0,
				true
			)


func _draw_irregular_road_edges(
	chunk_size: Vector2,
	edge_inset: float = 0.0
) -> void:
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector3i(
			config.world_seed,
			chunk_index,
			61879 + side_index * 997
		))
		var local_y := (
			-chunk_size.y * 0.5 + rng.randf_range(5.0, 28.0)
		)
		while local_y < chunk_size.y * 0.5:
			var road_limits := _get_visual_road_x_limits(
				local_y,
				edge_inset
			)
			var edge_x := (
				road_limits.x if side < 0.0 else road_limits.y
			)
			var outward := Vector2(side, 0.0)
			var tangent := Vector2(0.0, 1.0)
			var block_length := (
				rng.randf_range(6.0, 16.0)
				if rng.randf() < 0.68
				else rng.randf_range(18.0, 30.0)
			)
			var half_length := block_length * 0.5
			var missing := rng.randf() < 0.43
			var inner_depth := (
				rng.randf_range(6.0, 30.0)
				if missing
				else rng.randf_range(1.0, 7.0)
			)
			var outer_depth := (
				rng.randf_range(2.0, 8.0)
				if missing
				else rng.randf_range(4.0, 24.0)
			)
			var edge := Vector2(edge_x, local_y)
			var inner := edge - outward * inner_depth
			var outer := edge + outward * outer_depth
			var jitter := rng.randf_range(
				0.5,
				minf(4.0, half_length * 0.70)
			)
			var block := PackedVector2Array([
				inner - tangent * (half_length - rng.randf_range(0.0, jitter)),
				outer - tangent * (half_length - rng.randf_range(0.0, jitter)),
				outer + tangent * (half_length - rng.randf_range(0.0, jitter)),
				inner + tangent * (half_length - rng.randf_range(0.0, jitter)),
			])
			if missing:
				draw_colored_polygon(
					block,
					Color(
						rng.randf_range(0.37, 0.47),
						rng.randf_range(0.255, 0.335),
						rng.randf_range(0.105, 0.17),
						0.98
					)
				)
				if rng.randf() < 0.55:
					draw_circle(
						edge - outward * rng.randf_range(5.0, inner_depth),
						rng.randf_range(1.2, 2.8),
						Color(0.24, 0.145, 0.045, 0.48)
					)
			else:
				var stone_tint := rng.randf_range(-0.035, 0.04)
				draw_colored_polygon(
					block,
					Color(
						0.53 + stone_tint,
						0.52 + stone_tint,
						0.47 + stone_tint,
						0.96
					)
				)
				if rng.randf() < 0.52:
					draw_line(
						edge - tangent * half_length * 0.55,
						edge + outward * outer_depth * 0.72,
						Color(0.12, 0.18, 0.18, 0.38),
						1.0,
						true
					)
			local_y += rng.randf_range(18.0, 68.0)


func _draw_rock_cluster(
	root: Vector2,
	rng: RandomNumberGenerator
) -> void:
	var cluster_scale := rng.randf_range(0.75, 1.4)
	var rock_count := rng.randi_range(1, 3)
	draw_circle(
		root + Vector2(2.0, 3.0),
		10.0 * cluster_scale,
		Color(0.04, 0.08, 0.07, 0.25)
	)
	for rock_index in rock_count:
		var radius := rng.randf_range(5.0, 11.0) * cluster_scale
		if rock_index > 0:
			radius *= rng.randf_range(0.48, 0.72)
		var center := root + Vector2(
			rng.randf_range(-7.0, 8.0),
			float(rock_index) * 3.0 + rng.randf_range(-3.0, 3.0)
		)
		_draw_single_rock(center, radius, rng)


func _draw_single_rock(
	center: Vector2,
	radius: float,
	rng: RandomNumberGenerator
) -> void:
	var points := PackedVector2Array()
	var point_count := rng.randi_range(6, 8)
	for point_index in point_count:
		var angle := TAU * float(point_index) / float(point_count)
		var point_radius := radius * rng.randf_range(0.78, 1.12)
		points.append(
			center + Vector2(
				cos(angle) * point_radius,
				sin(angle) * point_radius * rng.randf_range(0.58, 0.76)
			)
		)
	var tint := rng.randf_range(-0.05, 0.06)
	draw_colored_polygon(
		points,
		Color(0.35 + tint, 0.39 + tint, 0.38 + tint, 0.98)
	)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color(0.12, 0.15, 0.14, 0.75), 1.2, true)
	draw_line(
		center + Vector2(-radius * 0.45, -radius * 0.20),
		center + Vector2(radius * 0.18, -radius * 0.34),
		Color(0.65, 0.69, 0.64, 0.42),
		maxf(radius * 0.12, 1.0),
		true
	)
	if radius > 7.0 and rng.randf() < 0.55:
		draw_line(
			center + Vector2(-radius * 0.08, -radius * 0.12),
			center + Vector2(radius * 0.28, radius * 0.22),
			Color(0.16, 0.19, 0.18, 0.55),
			1.0,
			true
		)


func _draw_ground_variation(chunk_size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed()
	var patch_count := maxi(roundi(chunk_size.y / 12.0), 28)
	for _patch in patch_count:
		var center := Vector2(
			rng.randf_range(-chunk_size.x * 0.5, chunk_size.x * 0.5),
			rng.randf_range(-chunk_size.y * 0.5, chunk_size.y * 0.5)
		)
		var road_limits := _get_visual_road_x_limits(center.y, -12.0)
		if center.x >= road_limits.x and center.x <= road_limits.y:
			continue
		var radius_x := rng.randf_range(7.0, 28.0)
		var radius_y := rng.randf_range(4.0, 16.0)
		var points := PackedVector2Array()
		var point_count := rng.randi_range(6, 9)
		for point_index in point_count:
			var angle := TAU * float(point_index) / float(point_count)
			var distortion := rng.randf_range(0.70, 1.22)
			points.append(
				center + Vector2(
					cos(angle) * radius_x * distortion,
					sin(angle) * radius_y * distortion
				)
			)
		var variation_color := (
			Color(0.50, 0.37, 0.18, 0.48)
			if rng.randf() < 0.5
			else Color(0.34, 0.225, 0.085, 0.42)
		)
		draw_colored_polygon(points, variation_color)
		if rng.randf() < 0.18:
			draw_line(
				center + Vector2(-radius_x * 0.25, -1.0),
				center + Vector2(radius_x * 0.22, radius_y * 0.20),
				Color(0.23, 0.14, 0.045, 0.34),
				1.0,
				true
			)


func _get_road_half_width_for_local_y(local_y: float) -> float:
	if config == null:
		return 1.0
	var chunk_height := maxf(config.get_pixel_size().y, 1.0)
	var normalized_y := (local_y + chunk_height * 0.5) / chunk_height
	return config.get_road_half_width_for_chunk(
		chunk_index,
		normalized_y
	)


func _get_visual_road_x_limits(
	local_y: float,
	edge_inset: float = 0.0
) -> Vector2:
	var half_width := maxf(
		_get_road_half_width_for_local_y(local_y) - edge_inset,
		1.0
	)
	var left_radius := maxf(
		half_width + _get_visual_edge_delta(local_y, 0),
		32.0
	)
	var right_radius := maxf(
		half_width + _get_visual_edge_delta(local_y, 1),
		32.0
	)
	var maximum_radius := maxf(
		config.get_pixel_size().x * 0.5 - float(config.tile_size),
		32.0
	)
	return Vector2(
		-clampf(left_radius, 32.0, maximum_radius),
		clampf(right_radius, 32.0, maximum_radius)
	)


## Uses independent continuous noise on the two sides. Sampling absolute
## generated-world Y keeps the asymmetry seamless across recycled chunks.
func _get_visual_edge_delta(local_y: float, side_index: int) -> float:
	var chunk_height := maxf(config.get_pixel_size().y, 1.0)
	var generated_world_y := float(chunk_index) * chunk_height + local_y
	var segment_length := 64.0
	var coordinate := generated_world_y / segment_length
	var anchor_index := floori(coordinate)
	var ratio := coordinate - float(anchor_index)
	var smooth_ratio := ratio * ratio * (3.0 - 2.0 * ratio)
	var first := _get_visual_edge_anchor(anchor_index, side_index)
	var second := _get_visual_edge_anchor(anchor_index + 1, side_index)
	return lerpf(first, second, smooth_ratio)


func _get_visual_edge_anchor(anchor_index: int, side_index: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(
		config.world_seed,
		anchor_index,
		7319 + side_index * 104729
	))
	return rng.randf_range(-24.0, 34.0)


func _get_road_edge_points(
	chunk_size: Vector2,
	edge_inset: float = 0.0
) -> Array[PackedVector2Array]:
	var left_points := PackedVector2Array()
	var right_points := PackedVector2Array()
	var sample_count := maxi(config.size_tiles.y + 1, 2)
	for sample_index in sample_count:
		var ratio := float(sample_index) / float(sample_count - 1)
		var local_y := lerpf(
			-chunk_size.y * 0.5,
			chunk_size.y * 0.5,
			ratio
		)
		var limits := _get_visual_road_x_limits(local_y, edge_inset)
		left_points.append(Vector2(limits.x, local_y))
		right_points.append(Vector2(limits.y, local_y))
	return [left_points, right_points]


func _get_road_polygon(
	chunk_size: Vector2,
	edge_inset: float = 0.0
) -> PackedVector2Array:
	var edges := _get_road_edge_points(chunk_size, edge_inset)
	var polygon := PackedVector2Array()
	for point in edges[0]:
		polygon.append(point)
	for point_index in range(edges[1].size() - 1, -1, -1):
		polygon.append(edges[1][point_index])
	return polygon


func _draw_editor_helpers(chunk_size: Vector2) -> void:
	if not Engine.is_editor_hint() or not show_editor_helpers:
		return

	var chunk_rect := Rect2(-chunk_size * 0.5, chunk_size)
	var helper_color := Color(0.2, 0.85, 1.0, 0.9)
	draw_rect(chunk_rect, helper_color, false, 2.0)
	draw_line(Vector2(-12.0, 0.0), Vector2(12.0, 0.0), helper_color, 2.0)
	draw_line(Vector2(0.0, -12.0), Vector2(0.0, 12.0), helper_color, 2.0)

	var arrow_tip := Vector2(0.0, -chunk_size.y * 0.5 + 20.0)
	draw_line(arrow_tip + Vector2(0.0, 30.0), arrow_tip, helper_color, 3.0)
	draw_line(arrow_tip, arrow_tip + Vector2(-8.0, 10.0), helper_color, 3.0)
	draw_line(arrow_tip, arrow_tip + Vector2(8.0, 10.0), helper_color, 3.0)


func _connect_config() -> void:
	if (
		Engine.is_editor_hint()
		and
		config != null
		and is_inside_tree()
		and not config.changed.is_connected(_on_config_changed)
	):
		config.changed.connect(_on_config_changed)


func _disconnect_config() -> void:
	if (
		config != null
		and config.changed.is_connected(_on_config_changed)
	):
		config.changed.disconnect(_on_config_changed)


func _on_config_changed() -> void:
	_request_editor_preview()


func _request_editor_preview() -> void:
	if (
		not Engine.is_editor_hint()
		or not is_inside_tree()
		or _preview_update_queued
	):
		return
	if not preview_enabled:
		_clear_editor_preview()
		return
	_preview_update_queued = true
	call_deferred("_refresh_editor_preview")


func _refresh_editor_preview() -> void:
	_preview_update_queued = false
	if not Engine.is_editor_hint() or not preview_enabled:
		return
	chunk_index = preview_chunk_index
	if config != null and config.use_terrain_painting:
		_build_terrain()
	else:
		_ensure_tile_map_layer()
		_tile_map_layer.clear()
		_tile_map_layer.visible = false
		queue_redraw()


func _clear_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_ensure_tile_map_layer()
	_tile_map_layer.clear()
	_tile_map_layer.visible = false
	queue_redraw()
