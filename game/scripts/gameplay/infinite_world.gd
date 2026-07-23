class_name InfiniteWorld
extends Node2D

signal qi_collected(amount: int)

## Reusable scene instantiated once per pool entry. It must create WorldChunk.
@export var chunk_scene: PackedScene = preload(
	"res://game/scenes/gameplay/world_chunk.tscn"
)
## Player whose world-space Y position drives distance-based chunk recycling.
## The configured road width is also applied to this player at startup.
@export var player: PlayerController
## Shared terrain, size, road, and deterministic-generation definition passed
## to every pooled chunk.
@export var chunk_config: WorldChunkConfig = preload(
	"res://game/resources/default_world_chunk_config.tres"
)

@export_category("Chunk Layout")
## Fixed number of chunks instantiated and reused for the entire run. Increase
## this only when the viewport or camera needs a larger ahead/behind buffer.
@export_range(4, 24, 1) var active_chunk_count: int = 8
## Distance in world pixels a chunk center may fall behind the player before it
## is moved ahead of the current leading chunk.
@export var recycle_behind_distance: float = 768.0

var _chunks: Array[WorldChunk] = []
var _progression_enabled: bool = true


func _ready() -> void:
	if player == null:
		push_error("InfiniteWorld requires a PlayerController reference.")
		set_physics_process(false)
		return
	if chunk_config == null:
		push_error("InfiniteWorld requires a WorldChunkConfig resource.")
		set_physics_process(false)
		return
	player.road_half_width = chunk_config.road_half_width
	_progression_enabled = true
	_create_chunk_pool()


func _physics_process(_delta: float) -> void:
	if not _progression_enabled or _chunks.is_empty():
		return

	var player_local_y := to_local(player.global_position).y
	var chunk_height := _chunk_height()
	var recycle_threshold := player_local_y + recycle_behind_distance
	var recycle_steps := ceili(
		(_chunks.back().position.y - recycle_threshold) / chunk_height
	)
	if recycle_steps >= _chunks.size():
		_reposition_pool_after_large_jump(recycle_steps, chunk_height)
		return

	while _chunks.back().position.y > player_local_y + recycle_behind_distance:
		var trailing_chunk: WorldChunk = _chunks.pop_back()
		var leading_chunk: WorldChunk = _chunks.front()
		var next_chunk_index: int = leading_chunk.chunk_index - 1
		trailing_chunk.position.y = leading_chunk.position.y - chunk_height
		trailing_chunk.configure(
			next_chunk_index,
			chunk_config
		)
		_chunks.push_front(trailing_chunk)


## Rebuilds each pooled chunk only once after teleports or test jumps spanning
## the entire pool, rather than generating discarded intermediate contents.
func _reposition_pool_after_large_jump(
	recycle_steps: int,
	chunk_height: float
) -> void:
	var back_chunk: WorldChunk = _chunks.back()
	var final_back_index: int = back_chunk.chunk_index - recycle_steps
	var first_index: int = final_back_index - _chunks.size() + 1
	for offset in _chunks.size():
		var chunk := _chunks[offset]
		var new_chunk_index: int = first_index + offset
		chunk.position = Vector2(0.0, new_chunk_index * chunk_height)
		chunk.configure(new_chunk_index, chunk_config)


func get_active_chunk_count() -> int:
	return _chunks.size()


func get_active_pickup_count() -> int:
	var pickup_count := 0
	for chunk in _chunks:
		pickup_count += chunk.get_pickup_count()
	return pickup_count


## Enables or stops distance-driven chunk recycling for the current run.
func set_progression_enabled(enabled: bool) -> void:
	_progression_enabled = enabled


func _create_chunk_pool() -> void:
	var first_chunk_index := -active_chunk_count + 2
	for offset in active_chunk_count:
		var chunk := chunk_scene.instantiate() as WorldChunk
		if chunk == null:
			push_error("InfiniteWorld chunk_scene must instantiate a WorldChunk.")
			return
		add_child(chunk)
		chunk.qi_collected.connect(_on_chunk_qi_collected)
		var chunk_index := first_chunk_index + offset
		chunk.position = Vector2(0.0, chunk_index * _chunk_height())
		chunk.configure(
			chunk_index,
			chunk_config
		)
		_chunks.append(chunk)


func _on_chunk_qi_collected(amount: int) -> void:
	qi_collected.emit(amount)


func _chunk_height() -> float:
	return chunk_config.get_pixel_size().y
