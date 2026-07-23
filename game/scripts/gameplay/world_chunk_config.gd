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
