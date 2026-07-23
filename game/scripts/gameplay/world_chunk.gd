@tool
class_name WorldChunk
extends Node2D

@export_category("Chunk Definition")
## Shared source of chunk dimensions, road width, seed, TileSet, and tile IDs.
## InfiniteWorld supplies the same resource to every runtime chunk.
@export var config: WorldChunkConfig:
	set(value):
		_disconnect_config()
		config = value
		_connect_config()
		_request_editor_preview()

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
var _show_fallback: bool = true
var _preview_update_queued: bool = false


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
		for x in config.size_tiles.x:
			var local_x := (
				(float(x) + 0.5) * config.tile_size
				- config.get_pixel_size().x * 0.5
			)
			if absf(local_x) <= config.road_half_width:
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
		for x in config.size_tiles.x:
			var local_x := (
				(float(x) + 0.5) * config.tile_size
				- config.get_pixel_size().x * 0.5
			)
			var cell := Vector2i(x, y)
			if absf(local_x) <= config.road_half_width:
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
		return
	_draw_fallback_terrain(chunk_size)


func _draw_fallback_terrain(chunk_size: Vector2) -> void:
	var chunk_rect := Rect2(-chunk_size * 0.5, chunk_size)
	var road_rect := Rect2(
		-config.road_half_width,
		-chunk_size.y * 0.5,
		config.road_half_width * 2.0,
		chunk_size.y
	)
	var shoulder_rect := Rect2(
		-config.road_half_width - 8.0,
		-chunk_size.y * 0.5,
		config.road_half_width * 2.0 + 16.0,
		chunk_size.y
	)

	draw_rect(chunk_rect, Color("31523a"))
	_draw_ground_variation(chunk_size)
	draw_rect(shoulder_rect, Color("806f50"))
	draw_rect(road_rect, Color("3e4248"))
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
		for x in config.size_tiles.x:
			var local_x := (
				(float(x) + 0.5) * config.tile_size
				- chunk_size.x * 0.5
			)
			var atlas_source := ground_source
			var atlas_coordinates := config.ground_atlas_coordinates
			if absf(local_x) <= config.road_half_width:
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
	draw_line(
		Vector2(
			-config.road_half_width + edge_inset,
			-chunk_size.y * 0.5
		),
		Vector2(
			-config.road_half_width + edge_inset,
			chunk_size.y * 0.5
		),
		Color("d7c7a2"),
		2.0
	)
	draw_line(
		Vector2(
			config.road_half_width - edge_inset,
			-chunk_size.y * 0.5
		),
		Vector2(
			config.road_half_width - edge_inset,
			chunk_size.y * 0.5
		),
		Color("d7c7a2"),
		2.0
	)

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
		for x in config.size_tiles.x:
			var local_x := (
				(float(x) + 0.5) * config.tile_size
				- chunk_size.x * 0.5
			)
			if absf(local_x) <= config.road_half_width + 8.0:
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
