extends Node2D

## Vertical camera lead in world pixels. Larger values show more road ahead and
## place the player lower on screen; smaller values move the player upward.
@export var camera_forward_look_ahead: float = 180.0
## Shows the runtime speed, traveled distance, and active chunk count overlay.
@export var show_debug_ui: bool = false
## Existing main-menu scene used by the run-ended Main Menu action. The scene
## tree is always unpaused before this path is opened.
@export_file("*.tscn") var main_menu_scene_path: String = (
	"res://game/scenes/menus/main_menu.tscn"
)

@onready var player: PlayerController = $Player
@onready var absorption_area: PlayerAbsorptionArea = $Player/QiAbsorptionArea
@onready var camera: Camera2D = $Camera2D
@onready var infinite_world: InfiniteWorld = $InfiniteWorld
@onready var run_resources: RunResources = $RunResources
@onready var gameplay_hud: GameplayHud = $GameplayHud
@onready var run_ended_overlay: RunEndedOverlay = $RunEndedOverlay
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var debug_layer: CanvasLayer = $DebugLayer
@onready var debug_label: Label = %DebugLabel

var _run_ended: bool = false
var _transition_started: bool = false


func _ready() -> void:
	get_tree().paused = false
	_run_ended = false
	_transition_started = false
	player.set_movement_enabled(true)
	absorption_area.set_absorption_enabled(true)
	infinite_world.set_progression_enabled(true)
	gameplay_hud.bind_resources(run_resources)
	infinite_world.qi_collected.connect(run_resources.add_qi)
	run_resources.lifespan_depleted.connect(_on_lifespan_depleted)
	run_ended_overlay.restart_requested.connect(_on_restart_requested)
	run_ended_overlay.main_menu_requested.connect(_on_main_menu_requested)
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


func _on_lifespan_depleted() -> void:
	if _run_ended:
		return
	_run_ended = true
	player.set_movement_enabled(false)
	absorption_area.set_absorption_enabled(false)
	infinite_world.set_progression_enabled(false)
	pause_menu.call("set_pause_enabled", false)
	run_ended_overlay.show_run_ended()


func _on_restart_requested() -> void:
	if not _begin_scene_transition():
		return
	var error := get_tree().reload_current_scene()
	if error != OK:
		_transition_started = false
		run_ended_overlay.show_run_ended()
		push_error("Could not restart gameplay scene: %s" % error_string(error))


func _on_main_menu_requested() -> void:
	if not _begin_scene_transition():
		return
	var error := get_tree().change_scene_to_file(main_menu_scene_path)
	if error != OK:
		_transition_started = false
		run_ended_overlay.show_run_ended()
		push_error("Could not open main menu scene: %s" % error_string(error))


func _begin_scene_transition() -> bool:
	if _transition_started:
		return false
	_transition_started = true
	run_ended_overlay.disable_actions()
	get_tree().paused = false
	return true
