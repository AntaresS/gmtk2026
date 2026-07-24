extends Node2D

## Vertical camera lead in world pixels. Larger values show more road ahead and
## place the player lower on screen; smaller values move the player upward.
@export var camera_forward_look_ahead: float = 180.0
## Shows the runtime speed, traveled distance, and active chunk count overlay.
@export var show_debug_ui: bool = false
## Configurable warning and lightning sequence used at non-fatal realm
## breakthrough milestones.
@export var heavenly_tribulation_scene: PackedScene = preload(
	"res://game/scenes/gameplay/heavenly_tribulation.tscn"
)
## Unavoidable final strike used when attempting to leave Nascent Soul layer
## nine. It must instantiate RealmAnnihilation.
@export var realm_annihilation_scene: PackedScene = preload(
	"res://game/scenes/gameplay/realm_annihilation.tscn"
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
var _run_won: bool = false
var _transition_started: bool = false
var _active_route_center_x: float = 0.0
var _active_tribulation: HeavenlyTribulation
var _active_annihilation: RealmAnnihilation
var _fatal_breakthrough_triggered: bool = false
var _camera_shake_remaining: float = 0.0
var _camera_shake_strength: float = 0.0


func _ready() -> void:
	get_tree().paused = false
	_run_ended = false
	_run_won = false
	_transition_started = false
	_active_tribulation = null
	_active_annihilation = null
	_fatal_breakthrough_triggered = false
	_active_route_center_x = infinite_world.get_route_center_x()
	player.set_movement_enabled(true)
	infinite_world.set_progression_enabled(true)
	enemy_spawner.set_road_half_width(infinite_world.chunk_config.road_half_width)
	enemy_spawner.set_road_half_width_resolver(
		Callable(infinite_world, "get_road_half_width_at_world_y")
	)
	enemy_spawner.set_spawning_enabled(true)
	road_fork_spawner.set_road_half_width(
		infinite_world.chunk_config.road_half_width
	)
	road_fork_spawner.set_road_half_width_resolver(
		Callable(infinite_world, "get_road_half_width_at_world_y")
	)
	road_fork_spawner.set_route_center_x(_active_route_center_x)
	road_fork_spawner.set_forks_enabled(true)
	enemy_spawner.set_route_center_x(_active_route_center_x)
	gameplay_hud.bind_resources(run_resources)
	gameplay_hud.bind_player(player)
	pause_menu.call("bind_debug_targets", player, run_resources)
	player.bind_cultivation(run_resources)
	infinite_world.qi_collected.connect(run_resources.add_qi)
	enemy_spawner.qi_collected.connect(run_resources.add_qi)
	enemy_spawner.universal_upgrade_collected.connect(
		player.apply_universal_upgrade
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
	run_resources.breakthrough_requested.connect(_on_breakthrough_requested)
	player.apply_cultivation_level(run_resources.cultivation_level)
	enemy_spawner.set_cultivation_level(run_resources.cultivation_level)
	road_fork_spawner.route_committed.connect(_on_route_committed)
	run_resources.lifespan_depleted.connect(_on_lifespan_depleted)
	run_ended_overlay.restart_requested.connect(_on_restart_requested)
	run_ended_overlay.main_menu_requested.connect(_on_main_menu_requested)
	camera.global_position = _get_camera_target()
	camera.reset_smoothing()
	debug_layer.visible = show_debug_ui


func _physics_process(delta: float) -> void:
	var camera_target := _get_camera_target()
	if _camera_shake_remaining > 0.0:
		_camera_shake_remaining = maxf(_camera_shake_remaining - delta, 0.0)
		camera_target += Vector2(
			randf_range(-_camera_shake_strength, _camera_shake_strength),
			randf_range(-_camera_shake_strength, _camera_shake_strength)
		)
	camera.global_position = camera_target


## Adds a short bounded shake used by heavy impacts such as Fantian Seal.
func request_camera_shake(strength: float) -> void:
	_camera_shake_strength = maxf(_camera_shake_strength, maxf(strength, 0.0))
	_camera_shake_remaining = maxf(_camera_shake_remaining, 0.18)


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


func _on_breakthrough_requested(
	_from_realm_index: int,
	_to_realm_index: int,
	fatal: bool
) -> void:
	if fatal:
		_start_realm_annihilation()
	else:
		_try_start_next_tribulation()


func _try_start_next_tribulation() -> void:
	if (
		_run_ended
		or is_instance_valid(_active_tribulation)
		or heavenly_tribulation_scene == null
		or not run_resources.has_pending_realm_breakthrough()
		or run_resources.is_pending_breakthrough_fatal()
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
	_active_tribulation = tribulation
	add_child(tribulation)
	tribulation.configure_for_realm(
		run_resources.get_current_realm_definition()
	)
	tribulation.tribulation_completed.connect(
		_on_heavenly_tribulation_completed
	)
	tribulation.start(player, run_resources.max_lifespan)


func _on_heavenly_tribulation_completed() -> void:
	_active_tribulation = null
	if run_resources.complete_pending_breakthrough():
		player.play_breakthrough_effect()


func _start_realm_annihilation() -> void:
	if (
		_run_ended
		or is_instance_valid(_active_annihilation)
		or realm_annihilation_scene == null
	):
		return
	var annihilation := (
		realm_annihilation_scene.instantiate() as RealmAnnihilation
	)
	if annihilation == null:
		push_error(
			"Game realm_annihilation_scene must create RealmAnnihilation."
		)
		return
	_active_annihilation = annihilation
	_fatal_breakthrough_triggered = true
	add_child(annihilation)
	annihilation.fatal_strike_landed.connect(
		_on_realm_annihilation_landed,
		CONNECT_ONE_SHOT
	)
	annihilation.tree_exited.connect(
		_on_realm_annihilation_exited,
		CONNECT_ONE_SHOT
	)
	annihilation.start(player)


func _on_realm_annihilation_landed() -> void:
	run_resources.force_deplete()


func _on_realm_annihilation_exited() -> void:
	_active_annihilation = null


func _on_lifespan_depleted() -> void:
	if _run_ended:
		return
	_finish_run(false)


func _finish_run(ascended: bool) -> void:
	_run_ended = true
	_run_won = ascended
	run_resources.complete_run()
	player.set_movement_enabled(false)
	infinite_world.set_progression_enabled(false)
	enemy_spawner.set_spawning_enabled(false)
	road_fork_spawner.set_forks_enabled(false)
	if is_instance_valid(_active_tribulation):
		_active_tribulation.cancel()
		_active_tribulation = null
	if is_instance_valid(_active_annihilation):
		_active_annihilation.queue_free()
		_active_annihilation = null
	pause_menu.call("set_pause_enabled", false)
	_show_run_outcome()


func _show_run_outcome() -> void:
	if _run_won:
		run_ended_overlay.show_ascension()
	elif _fatal_breakthrough_triggered:
		run_ended_overlay.show_fatal_breakthrough()
	else:
		run_ended_overlay.show_defeat()


## Aggregates read-only subsystem snapshots for a future in-run debug panel.
func get_debug_snapshot() -> Dictionary:
	return {
		"run": run_resources.get_debug_snapshot(),
		"player": player.get_debug_snapshot(),
		"world": infinite_world.get_debug_snapshot(),
		"enemies": enemy_spawner.get_debug_snapshot(),
		"active_route_center_x": _active_route_center_x,
		"trial_hell_active": enemy_spawner.is_trial_hell_active(),
	}


func _on_restart_requested() -> void:
	if not _begin_scene_transition():
		return
	var error := get_tree().reload_current_scene()
	if error != OK:
		_transition_started = false
		_show_run_outcome()
		push_error("Could not restart gameplay scene: %s" % error_string(error))


func _on_main_menu_requested() -> void:
	if not _begin_scene_transition():
		return
	var error := get_tree().change_scene_to_file(main_menu_scene_path)
	if error != OK:
		_transition_started = false
		_show_run_outcome()
		push_error("Could not open main menu scene: %s" % error_string(error))


func _begin_scene_transition() -> bool:
	if _transition_started:
		return false
	_transition_started = true
	run_ended_overlay.disable_actions()
	get_tree().paused = false
	return true
