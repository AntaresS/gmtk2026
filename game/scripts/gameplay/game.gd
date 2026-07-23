extends Node2D

## Vertical camera lead in world pixels. Larger values show more road ahead and
## place the player lower on screen; smaller values move the player upward.
@export var camera_forward_look_ahead: float = 180.0
## Shows the runtime speed, traveled distance, and active chunk count overlay.
@export var show_debug_ui: bool = false

@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var infinite_world: InfiniteWorld = $InfiniteWorld
@onready var debug_layer: CanvasLayer = $DebugLayer
@onready var debug_label: Label = %DebugLabel


func _ready() -> void:
	get_tree().paused = false
	camera.global_position = _get_camera_target()
	camera.reset_smoothing()
	debug_layer.visible = show_debug_ui


func _physics_process(_delta: float) -> void:
	camera.global_position = _get_camera_target()


func _process(_delta: float) -> void:
	if not show_debug_ui:
		return
	debug_label.text = "Speed: %d\nDistance: %d\nChunks: %d" % [
		roundi(player.current_forward_speed),
		roundi(player.distance_traveled),
		infinite_world.get_active_chunk_count(),
	]


func _get_camera_target() -> Vector2:
	return Vector2(0.0, player.global_position.y - camera_forward_look_ahead)
