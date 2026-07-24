@tool
class_name WorldChunkConfig
extends Resource

@export_category("Chunk Layout")
## Chunk width and height measured in tile cells. The pixel dimensions are this
## value multiplied by tile_size.
@export var size_tiles: Vector2i = Vector2i(128, 32):
	set(value):
		size_tiles = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		emit_changed()
## Width and height of one generated tile in world pixels. This should match
## the configured TileSet atlas region size to avoid scaling artifacts.
@export_range(1, 128, 1) var tile_size: int = 16:
	set(value):
		tile_size = maxi(value, 1)
		emit_changed()
## Playable distance from road center to either edge in world pixels. The world
## applies this value to the player so terrain and movement bounds stay aligned.
@export var road_half_width: float = 224.0:
	set(value):
		road_half_width = maxf(value, 1.0)
		emit_changed()

@export_category("Road Width Variation")
## Enables deterministic narrowing and widening along the infinite road.
@export var vary_road_width: bool = true:
	set(value):
		vary_road_width = value
		emit_changed()
## Narrowest road-width multiplier. The default permits half-width sections.
@export_range(0.1, 1.0, 0.05) var minimum_road_width_multiplier: float = 0.5:
	set(value):
		minimum_road_width_multiplier = clampf(value, 0.1, 1.0)
		emit_changed()
## Widest road-width multiplier. The default permits double-width sections.
@export_range(1.0, 4.0, 0.05) var maximum_road_width_multiplier: float = 2.0:
	set(value):
		maximum_road_width_multiplier = maxf(value, 1.0)
		emit_changed()
## Probability that one transition anchor keeps the original road width.
## Higher values create more calm stretches between narrow and wide sections.
@export_range(0.0, 1.0, 0.05) var normal_width_boundary_chance: float = 0.35:
	set(value):
		normal_width_boundary_chance = clampf(value, 0.0, 1.0)
		emit_changed()
## Number of chunks used by one complete width transition. The default four
## makes narrowing and widening four times longer than a one-chunk transition;
## values from three to five provide the intended pacing range.
@export_range(1, 12, 1) var road_width_transition_chunk_span: int = 4:
	set(value):
		road_width_transition_chunk_span = maxi(value, 1)
		emit_changed()

@export_category("Generation")
## Base seed used with each chunk index to reproduce decorative tile choices.
@export var world_seed: int = 20260722:
	set(value):
		world_seed = value
		emit_changed()
## Probability from 0 to 1 that an eligible ground cell uses the configured
## ground variant instead of the normal ground tile.
@export_range(0.0, 1.0, 0.01) var ground_variation_chance: float = 0.08:
	set(value):
		ground_variation_chance = clampf(value, 0.0, 1.0)
		emit_changed()

@export_category("TileSet")
## TileSet used by editor previews and runtime TileMapLayer generation. Invalid
## or missing resources fall back to the built-in deterministic road rendering.
@export var terrain_tileset: TileSet:
	set(value):
		terrain_tileset = value
		emit_changed()
## Uses TileSet terrain-connect painting instead of explicit atlas coordinates.
## Enable this only when terrain sets and peering bits are configured.
@export var use_terrain_painting: bool = false:
	set(value):
		use_terrain_painting = value
		emit_changed()
## Zero-based terrain-set ID used when terrain painting is enabled.
@export var terrain_set: int = 0:
	set(value):
		terrain_set = value
		emit_changed()
## Zero-based terrain ID painted inside the playable road strip.
@export var road_terrain: int = 0:
	set(value):
		road_terrain = value
		emit_changed()
## Zero-based terrain ID painted outside the playable road strip.
@export var ground_terrain: int = 1:
	set(value):
		ground_terrain = value
		emit_changed()

@export_category("Atlas Tile IDs")
## TileSet source ID containing the road tile when explicit atlas mode is used.
@export var road_source_id: int = 0:
	set(value):
		road_source_id = value
		emit_changed()
## Atlas cell used for every road tile in explicit atlas mode.
@export var road_atlas_coordinates: Vector2i = Vector2i.ZERO:
	set(value):
		road_atlas_coordinates = value
		emit_changed()
## TileSet source ID containing normal and variant outside-ground tiles.
@export var ground_source_id: int = 0:
	set(value):
		ground_source_id = value
		emit_changed()
## Default atlas cell used outside the playable road strip.
@export var ground_atlas_coordinates: Vector2i = Vector2i(1, 0):
	set(value):
		ground_atlas_coordinates = value
		emit_changed()
## Optional decorative atlas cell selected according to
## ground_variation_chance. An invalid cell simply disables variation.
@export var ground_variant_atlas_coordinates: Vector2i = Vector2i(2, 0):
	set(value):
		ground_variant_atlas_coordinates = value
		emit_changed()


func get_pixel_size() -> Vector2:
	return Vector2(size_tiles * tile_size)


## Returns one deterministic road-width multiplier at a shared transition
## anchor. Adjacent chunks sample the same anchors, guaranteeing seamless edges.
func get_road_width_multiplier_at_boundary(boundary_index: int) -> float:
	if not vary_road_width:
		return 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world_seed, boundary_index, 421))
	if rng.randf() < normal_width_boundary_chance:
		return 1.0
	if rng.randf() < 0.5:
		return rng.randf_range(
			clampf(minimum_road_width_multiplier, 0.1, 1.0),
			1.0
		)
	return rng.randf_range(
		1.0,
		maxf(maximum_road_width_multiplier, 1.0)
	)


## Samples road half-width inside one chunk. Normalized Y is zero at the top
## edge and one at the bottom edge.
func get_road_half_width_for_chunk(
	chunk_index: int,
	normalized_y: float
) -> float:
	var transition_span := maxi(road_width_transition_chunk_span, 1)
	var chunk_coordinate := (
		float(chunk_index) + clampf(normalized_y, 0.0, 1.0)
	)
	var anchor_coordinate := chunk_coordinate / float(transition_span)
	var anchor_index := floori(anchor_coordinate)
	var top_multiplier := get_road_width_multiplier_at_boundary(anchor_index)
	var bottom_multiplier := get_road_width_multiplier_at_boundary(
		anchor_index + 1
	)
	var ratio := anchor_coordinate - float(anchor_index)
	var smooth_ratio := ratio * ratio * (3.0 - 2.0 * ratio)
	var multiplier := lerpf(
		top_multiplier,
		bottom_multiplier,
		smooth_ratio
	)
	var maximum_half_width := maxf(
		get_pixel_size().x * 0.5 - float(tile_size),
		1.0
	)
	return clampf(
		road_half_width * multiplier,
		1.0,
		maximum_half_width
	)


## Samples the deterministic road width from local world Y, where chunk center
## positions are integer multiples of chunk height.
func get_road_half_width_at_world_y(local_world_y: float) -> float:
	var chunk_height := maxf(get_pixel_size().y, 1.0)
	var chunk_index := floori(local_world_y / chunk_height + 0.5)
	var chunk_top := float(chunk_index) * chunk_height - chunk_height * 0.5
	var normalized_y := (local_world_y - chunk_top) / chunk_height
	return get_road_half_width_for_chunk(chunk_index, normalized_y)


func get_minimum_road_half_width() -> float:
	return road_half_width * clampf(
		minimum_road_width_multiplier,
		0.1,
		1.0
	)


func get_maximum_road_half_width() -> float:
	return road_half_width * maxf(maximum_road_width_multiplier, 1.0)
