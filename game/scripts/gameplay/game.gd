extends Node2D

## Vertical camera lead in world pixels. Larger values show more road ahead and
## place the player lower on screen; smaller values move the player upward.
@export var camera_forward_look_ahead: float = 180.0
## Shows the runtime speed, traveled distance, and active chunk count overlay.
@export var show_debug_ui: bool = false
## Nine-strike warning and lightning sequence used when advancing beyond
## cultivation level nine.
@export var heavenly_tribulation_scene: PackedScene = preload(
	"res://game/scenes/gameplay/heavenly_tribulation.tscn"
)
## Existing main-menu scene used by the run-ended Main Menu action. The scene
## tree is always unpaused before this path is opened.
@export_file("*.tscn") var main_menu_scene_path: String = (
	"res://game/scenes/menus/main_menu.tscn"
)

@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var infinite_world: InfiniteWorld = $InfiniteWorld
@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var road_fork_spawner: RoadForkSpawner = $RoadForkSpawner
@onready var run_resources: RunResources = $RunResources
@onready var gameplay_hud: GameplayHud = $GameplayHud
@onready var run_ended_overlay: RunEndedOverlay = $RunEndedOverlay
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var debug_layer: CanvasLayer = $DebugLayer
@onready var debug_label: Label = %DebugLabel

var _run_ended: bool = false
var _transition_started: bool = false
var _active_route_center_x: float = 0.0
var _tribulation_triggered: bool = false
var _active_tribulation: HeavenlyTribulation


func _ready() -> void:
	get_tree().paused = false
	_run_ended = false
	_transition_started = false
	_tribulation_triggered = false
	_active_tribulation = null
	_active_route_center_x = infinite_world.get_route_center_x()
	player.set_movement_enabled(true)
	infinite_world.set_progression_enabled(true)
	enemy_spawner.set_road_half_width(infinite_world.chunk_config.road_half_width)
	enemy_spawner.set_spawning_enabled(true)
	road_fork_spawner.set_road_half_width(
		infinite_world.chunk_config.road_half_width
	)
	road_fork_spawner.set_route_center_x(_active_route_center_x)
	road_fork_spawner.set_forks_enabled(true)
	enemy_spawner.set_route_center_x(_active_route_center_x)
	gameplay_hud.bind_resources(run_resources)
	gameplay_hud.bind_player(player)
	infinite_world.qi_collected.connect(run_resources.add_qi)
	enemy_spawner.qi_collected.connect(run_resources.add_qi)
	enemy_spawner.technique_fragment_collected.connect(
		player.add_weapon_upgrade_fragments
	)
	enemy_spawner.weapon_power_fragment_collected.connect(
		player.add_weapon_power_fragments
	)
	player.melee_damage_received.connect(run_resources.apply_lifespan_damage)
	player.lifespan_decay_multiplier_changed.connect(
		run_resources.set_lifespan_decay_multiplier
	)
	run_resources.set_lifespan_decay_multiplier(
		player.get_lifespan_decay_multiplier()
	)
	run_resources.cultivation_level_changed.connect(
		player.apply_cultivation_level
	)
	run_resources.cultivation_level_changed.connect(
		enemy_spawner.set_cultivation_level
	)
	run_resources.cultivation_level_changed.connect(
		_on_cultivation_level_changed
	)
	player.apply_cultivation_level(run_resources.cultivation_level)
	enemy_spawner.set_cultivation_level(run_resources.cultivation_level)
	road_fork_spawner.route_committed.connect(_on_route_committed)
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
	debug_label.text = "Speed: %d\nDistance: %d\nChunks: %d\nEnemies: %d" % [
		roundi(player.current_forward_speed),
		roundi(player.distance_traveled),
		infinite_world.get_active_chunk_count(),
		enemy_spawner.get_active_enemy_count(),
	]


func _get_camera_target() -> Vector2:
	return Vector2(
		_active_route_center_x,
		player.global_position.y - camera_forward_look_ahead
	)


func _on_route_committed(
	route_center_x: float,
	branch_name: String
) -> void:
	_active_route_center_x = route_center_x
	infinite_world.set_route_center_x(route_center_x)
	enemy_spawner.set_route_center_x(route_center_x)
	var trial_hell_active := branch_name == "试炼地狱"
	infinite_world.set_trial_hell_active(trial_hell_active)
	enemy_spawner.set_trial_hell_active(trial_hell_active)
	player.global_position.x = route_center_x
	camera.global_position.x = route_center_x


func _on_cultivation_level_changed(level: int) -> void:
	if (
		level <= 9
		or _tribulation_triggered
		or heavenly_tribulation_scene == null
	):
		return
	var tribulation := (
		heavenly_tribulation_scene.instantiate()
		as HeavenlyTribulation
	)
	if tribulation == null:
		push_error(
			"Game heavenly_tribulation_scene must create HeavenlyTribulation."
		)
		return
	_tribulation_triggered = true
	_active_tribulation = tribulation
	add_child(tribulation)
	tribulation.tribulation_completed.connect(
		_on_heavenly_tribulation_completed
	)
	tribulation.start(player)


func _on_heavenly_tribulation_completed() -> void:
	_active_tribulation = null
	run_resources.double_lifespan_after_breakthrough()
	player.play_breakthrough_effect()


func _on_lifespan_depleted() -> void:
	if _run_ended:
		return
	_run_ended = true
	player.set_movement_enabled(false)
	infinite_world.set_progression_enabled(false)
	enemy_spawner.set_spawning_enabled(false)
	road_fork_spawner.set_forks_enabled(false)
	if is_instance_valid(_active_tribulation):
		_active_tribulation.cancel()
		_active_tribulation = null
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
