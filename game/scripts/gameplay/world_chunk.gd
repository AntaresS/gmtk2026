@tool
class_name WorldChunk
extends Node2D

signal qi_collected(amount: int)

const QI_PROFILE: QiDensityProfile = preload(
	"res://game/resources/qi_profile.tres"
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


func _enter_tree() -> void:
	_ensure_tile_map_layer()
	_connect_config()
	_request_editor_preview()


func _exit_tree() -> void:
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
## persistent red-black palette without rebuilding deterministic contents.
func set_trial_hell_active(active: bool) -> void:
	_trial_hell_active = active
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
	if config == null:
		return

	var chunk_size := config.get_pixel_size()
	if not _show_fallback:
		_draw_road_guides(chunk_size)
		if _trial_hell_active:
			_draw_trial_hell_overlay(chunk_size)
		return
	_draw_fallback_terrain(chunk_size)
	if _trial_hell_active:
		_draw_trial_hell_overlay(chunk_size)


func _draw_trial_hell_overlay(chunk_size: Vector2) -> void:
	var chunk_rect := Rect2(-chunk_size * 0.5, chunk_size)
	draw_rect(chunk_rect, Color(0.22, 0.0, 0.015, 0.58))
	draw_colored_polygon(
		_get_road_polygon(chunk_size, -10.0),
		Color(0.34, 0.025, 0.015, 0.92)
	)
	draw_colored_polygon(
		_get_road_polygon(chunk_size),
		Color(0.10, 0.008, 0.012, 0.88)
	)
	var first_mark_y := -chunk_size.y * 0.5 + 34.0
	for mark_index in int(ceilf(chunk_size.y / 92.0)):
		var mark_y := first_mark_y + float(mark_index) * 92.0
		var mark_color := Color(1.0, 0.20, 0.04, 0.80)
		var mark_half_width := _get_road_half_width_for_local_y(mark_y)
		draw_line(
			Vector2(-mark_half_width + 12.0, mark_y),
			Vector2(-mark_half_width + 34.0, mark_y - 20.0),
			mark_color,
			3.0
		)
		draw_line(
			Vector2(mark_half_width - 12.0, mark_y),
			Vector2(mark_half_width - 34.0, mark_y - 20.0),
			mark_color,
			3.0
		)


func _draw_fallback_terrain(chunk_size: Vector2) -> void:
	var chunk_rect := Rect2(-chunk_size * 0.5, chunk_size)
	draw_rect(chunk_rect, Color("31523a"))
	_draw_ground_variation(chunk_size)
	draw_colored_polygon(
		_get_road_polygon(chunk_size, -8.0),
		Color("806f50")
	)
	draw_colored_polygon(_get_road_polygon(chunk_size), Color("3e4248"))
	_draw_road_guides(chunk_size, 8.0)


func _draw_editor_preview() -> void:
	if not preview_enabled or config == null:
		return

	var chunk_size := config.get_pixel_size()
	var drew_atlas := false
	if not config.use_terrain_painting:
		drew_atlas = _draw_atlas_preview(chunk_size)

	if drew_atlas:
		_draw_road_guides(chunk_size)
	elif config.use_terrain_painting and _tile_map_layer.visible:
		_draw_road_guides(chunk_size)
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


func _draw_road_guides(chunk_size: Vector2, edge_inset: float = 0.0) -> void:
	var edge_points := _get_road_edge_points(chunk_size, edge_inset)
	draw_polyline(edge_points[0], Color("d7c7a2"), 2.0, true)
	draw_polyline(edge_points[1], Color("d7c7a2"), 2.0, true)

	var first_dash_y := -chunk_size.y * 0.5
	for dash_index in int(ceilf(chunk_size.y / 64.0)):
		var dash_y := first_dash_y + dash_index * 64.0
		draw_rect(
			Rect2(Vector2(-2.0, dash_y + 16.0), Vector2(4.0, 28.0)),
			Color("d9d5b8")
		)


func _draw_ground_variation(chunk_size: Vector2) -> void:
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
			if absf(local_x) <= row_road_half_width + 8.0:
				continue
			if rng.randf() > config.ground_variation_chance:
				continue
			var tile_position := (
				top_left + Vector2(x, y) * config.tile_size
			)
			var variation_color := (
				Color("395d42")
				if rng.randf() < 0.5
				else Color("294832")
			)
			draw_rect(
				Rect2(
					tile_position,
					Vector2(config.tile_size, config.tile_size)
				),
				variation_color
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
		var half_width := maxf(
			_get_road_half_width_for_local_y(local_y) - edge_inset,
			1.0
		)
		left_points.append(Vector2(-half_width, local_y))
		right_points.append(Vector2(half_width, local_y))
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
