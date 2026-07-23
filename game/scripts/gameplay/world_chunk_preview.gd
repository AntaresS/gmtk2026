@tool
extends Node2D

const DEFAULT_CONFIG: WorldChunkConfig = preload(
	"res://game/resources/default_world_chunk_config.tres"
)

## Shared definition displayed by all three preview chunks. Dimension changes
## automatically reposition the adjacent chunks to preserve exact seams.
@export var config: WorldChunkConfig = DEFAULT_CONFIG:
	set(value):
		_disconnect_config()
		config = value
		_connect_config()
		_queue_layout()

var _layout_queued: bool = false


func _enter_tree() -> void:
	_connect_config()
	_queue_layout()


func _exit_tree() -> void:
	_disconnect_config()


func _connect_config() -> void:
	if (
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
	_queue_layout()


func _queue_layout() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or _layout_queued:
		return
	_layout_queued = true
	call_deferred("_apply_layout")


func _apply_layout() -> void:
	_layout_queued = false
	if config == null:
		return

	var chunks: Array[WorldChunk] = [
		get_node_or_null("PreviousChunk") as WorldChunk,
		get_node_or_null("CurrentChunk") as WorldChunk,
		get_node_or_null("NextChunk") as WorldChunk,
	]
	var chunk_height := config.get_pixel_size().y
	for array_index in chunks.size():
		var chunk := chunks[array_index]
		if chunk == null:
			continue
		var preview_index := array_index - 1
		chunk.config = config
		chunk.preview_chunk_index = preview_index
		chunk.position = Vector2(0.0, preview_index * chunk_height)
