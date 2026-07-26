extends Node2D

const BackgroundMusicPlayerResource = preload(
	"res://game/scripts/audio/background_music_player.gd"
)
const WeaponDataResource = preload(
	"res://game/scripts/gameplay/weapon_data.gd"
)

@export_category("Camera")
## Intended world-space coverage in pixels. The runtime camera derives a
## uniform zoom from the configured render target so 1280x720 keeps the original
## 1920x1080 gameplay area and spawn density.
@export var camera_world_view_size: Vector2 = Vector2(1920.0, 1080.0)
## Vertical camera lead in world pixels. Larger values show more road ahead and
## place the player lower on screen; smaller values move the player upward.
@export var camera_forward_look_ahead: float = 180.0
## Seconds used to ease the camera horizontally onto a committed branch.
@export_range(0.1, 2.0, 0.05) var route_camera_pan_duration: float = 0.75

@export_category("Performance Diagnostics")
## Shows the runtime speed, traveled distance, and active chunk count overlay.
@export var show_debug_ui: bool = false
## Prints one timestamped performance sample per interval in debug builds.
## Release exports ignore this flag so diagnostics cannot add shipping overhead.
@export var log_performance_samples: bool = false
## Seconds between debug overlay and console performance samples.
@export_range(0.25, 5.0, 0.25) var performance_sample_interval: float = 1.0

@export_category("Run Flow")
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

@export_category("Background Music")
## Ordered looping tracks for 练气, 筑基, 金丹, and 元婴. Realm indexes beyond
## the configured list reuse the last valid entry.
@export var realm_bgm_tracks: Array[AudioStream] = [
	preload("res://assets/sound/track/stage_1.wav"),
	preload("res://assets/sound/track/stage_2.wav"),
	preload("res://assets/sound/track/stage_3.wav"),
	preload("res://assets/sound/track/stage_4.wav"),
]
## Looping track used only while a non-fatal Heavenly Tribulation is active.
@export var heavenly_tribulation_bgm: AudioStream = preload(
	"res://assets/sound/track/lei_jie.wav"
)

@export_category("Breakthrough Audio")
## Non-looping celebration played only after a pending realm breakthrough is
## successfully committed.
@export var breakthrough_success_sfx: AudioStream = preload(
	"res://assets/sound/sfx/dujie_success.mp3"
)
## Breakthrough-success loudness in decibels.
@export_range(-40.0, 12.0, 0.5) var breakthrough_success_volume_db: float = -4.0
## Breakthrough-success playback-speed and pitch multiplier.
@export_range(0.25, 4.0, 0.05) var breakthrough_success_pitch_scale: float = 1.0
## Audio bus used by the breakthrough-success cue. Missing bus names safely
## fall back to Master.
@export var breakthrough_success_bus: StringName = &"SFX"

@onready var background_music: BackgroundMusicPlayerResource = $BackgroundMusic
@onready var breakthrough_success_player: AudioStreamPlayer = (
	$BreakthroughSuccessSfx
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
var _camera_route_center_x: float = 0.0
var _camera_pan_start_x: float = 0.0
var _camera_pan_target_x: float = 0.0
var _camera_pan_elapsed: float = 0.0
var _camera_pan_active: bool = false
var _elapsed_run_time: float = 0.0
var _total_damage_dealt: int = 0
var _enemies_defeated: int = 0
var _elite_enemies_defeated: int = 0
var _weapon_damage_dealt: Dictionary = {}
var _performance_sample_remaining: float = 0.0


func _ready() -> void:
	get_tree().paused = false
	_run_ended = false
	_run_won = false
	_transition_started = false
	_active_tribulation = null
	_active_annihilation = null
	_fatal_breakthrough_triggered = false
	breakthrough_success_player.stream = breakthrough_success_sfx
	breakthrough_success_player.volume_db = breakthrough_success_volume_db
	breakthrough_success_player.pitch_scale = clampf(
		breakthrough_success_pitch_scale,
		0.25,
		4.0
	)
	breakthrough_success_player.bus = (
		breakthrough_success_bus
		if AudioServer.get_bus_index(breakthrough_success_bus) >= 0
		else &"Master"
	)
	_active_route_center_x = infinite_world.get_route_center_x()
	_camera_route_center_x = _active_route_center_x
	_camera_pan_start_x = _active_route_center_x
	_camera_pan_target_x = _active_route_center_x
	_camera_pan_elapsed = 0.0
	_camera_pan_active = false
	_elapsed_run_time = 0.0
	_total_damage_dealt = 0
	_enemies_defeated = 0
	_elite_enemies_defeated = 0
	_weapon_damage_dealt.clear()
	_performance_sample_remaining = 0.0
	_apply_camera_world_view_size()
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
	road_fork_spawner.set_world_config(infinite_world.chunk_config)
	road_fork_spawner.set_route_center_x(_active_route_center_x)
	road_fork_spawner.set_forks_enabled(true)
	enemy_spawner.set_route_center_x(_active_route_center_x)
	gameplay_hud.bind_resources(run_resources)
	gameplay_hud.bind_player(player)
	gameplay_hud.pause_requested.connect(
		Callable(pause_menu, "pause_game")
	)
	pause_menu.call("bind_debug_targets", player, run_resources)
	player.bind_cultivation(run_resources)
	infinite_world.qi_collected.connect(run_resources.add_qi)
	enemy_spawner.qi_collected.connect(run_resources.add_qi)
	enemy_spawner.universal_upgrade_collected.connect(
		player.apply_universal_upgrade
	)
	enemy_spawner.player_damage_recorded.connect(
		_on_player_damage_recorded
	)
	enemy_spawner.enemy_defeat_recorded.connect(
		_on_enemy_defeat_recorded
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
	run_resources.realm_state_changed.connect(_on_realm_state_changed)
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
	_play_realm_bgm(run_resources.get_current_realm_index(), true)


func _physics_process(delta: float) -> void:
	_update_route_camera_pan(delta)
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


func _process(delta: float) -> void:
	if not _run_ended:
		_elapsed_run_time += maxf(delta, 0.0)
	if (
		not OS.is_debug_build()
		or (not show_debug_ui and not log_performance_samples)
	):
		return
	_performance_sample_remaining -= maxf(delta, 0.0)
	if _performance_sample_remaining > 0.0:
		return
	_performance_sample_remaining = maxf(
		performance_sample_interval,
		0.25
	)
	var sample_text := _build_performance_sample()
	if show_debug_ui:
		debug_label.text = sample_text
	if log_performance_samples:
		print("[PERF] ", sample_text.replace("\n", " | "))


func _build_performance_sample() -> String:
	var viewport_size := get_viewport_rect().size
	var window_size := DisplayServer.window_get_size()
	var world_view_size := Vector2(
		viewport_size.x / maxf(absf(camera.zoom.x), 0.01),
		viewport_size.y / maxf(absf(camera.zoom.y), 0.01)
	)
	var process_ms := (
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	)
	var physics_ms := (
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	)
	var video_memory_mib := (
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
		/ 1048576.0
	)
	return (
		"Time %.1fs | FPS %d | Process %.2fms | Physics %.2fms\n"
		+ "Draws %d | Primitives %d | VRAM %.1f MiB | Nodes %d\n"
		+ "Chunks %d | Pickups %d | Enemies %d | Forks %d\n"
		+ "Viewport %dx%d | World %dx%d | Zoom %.3f | Window %dx%d"
	) % [
		_elapsed_run_time,
		roundi(Performance.get_monitor(Performance.TIME_FPS)),
		process_ms,
		physics_ms,
		roundi(Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME
		)),
		roundi(Performance.get_monitor(
			Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME
		)),
		video_memory_mib,
		roundi(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		infinite_world.get_active_chunk_count(),
		infinite_world.get_active_pickup_count(),
		enemy_spawner.get_active_enemy_count(),
		get_tree().get_nodes_in_group("road_forks").size(),
		roundi(viewport_size.x),
		roundi(viewport_size.y),
		roundi(world_view_size.x),
		roundi(world_view_size.y),
		camera.zoom.x,
		window_size.x,
		window_size.y,
	]


func _apply_camera_world_view_size() -> void:
	var viewport_size := Vector2(
		float(ProjectSettings.get_setting(
			"display/window/size/viewport_width",
			1280
		)),
		float(ProjectSettings.get_setting(
			"display/window/size/viewport_height",
			720
		))
	)
	var safe_world_size := Vector2(
		maxf(camera_world_view_size.x, 1.0),
		maxf(camera_world_view_size.y, 1.0)
	)
	var uniform_zoom := minf(
		viewport_size.x / safe_world_size.x,
		viewport_size.y / safe_world_size.y
	)
	camera.zoom = Vector2.ONE * maxf(uniform_zoom, 0.01)


func _get_camera_target() -> Vector2:
	return Vector2(
		_camera_route_center_x,
		player.global_position.y - camera_forward_look_ahead
	)


func _on_route_committed(
	route_center_x: float,
	branch_name: String
) -> void:
	_active_route_center_x = route_center_x
	_start_route_camera_pan(route_center_x)
	infinite_world.set_route_center_x(route_center_x)
	enemy_spawner.set_route_center_x(route_center_x)
	var trial_hell_active := branch_name == "试炼地狱"
	infinite_world.set_trial_hell_active(trial_hell_active)
	enemy_spawner.set_trial_hell_active(trial_hell_active)


func _start_route_camera_pan(target_x: float) -> void:
	_camera_pan_start_x = _camera_route_center_x
	_camera_pan_target_x = target_x
	_camera_pan_elapsed = 0.0
	_camera_pan_active = not is_equal_approx(
		_camera_pan_start_x,
		_camera_pan_target_x
	)
	if not _camera_pan_active:
		_camera_route_center_x = target_x


func _update_route_camera_pan(delta: float) -> void:
	if not _camera_pan_active:
		return
	_camera_pan_elapsed += maxf(delta, 0.0)
	var ratio := clampf(
		_camera_pan_elapsed / maxf(route_camera_pan_duration, 0.01),
		0.0,
		1.0
	)
	var smooth_ratio := ratio * ratio * (3.0 - 2.0 * ratio)
	_camera_route_center_x = lerpf(
		_camera_pan_start_x,
		_camera_pan_target_x,
		smooth_ratio
	)
	if ratio >= 1.0:
		_camera_route_center_x = _camera_pan_target_x
		_camera_pan_active = false


func _on_breakthrough_requested(
	_from_realm_index: int,
	_to_realm_index: int,
	fatal: bool
) -> void:
	if fatal:
		_start_realm_annihilation()
	else:
		_try_start_next_tribulation()


func _on_realm_state_changed(
	realm_index: int,
	_realm_name: String,
	_layer: int,
	_layer_count: int
) -> void:
	if is_instance_valid(_active_tribulation):
		return
	_play_realm_bgm(realm_index)


func _play_realm_bgm(realm_index: int, immediate: bool = false) -> void:
	if realm_bgm_tracks.is_empty():
		background_music.play_track(null, immediate)
		return
	var track_index := clampi(realm_index, 0, realm_bgm_tracks.size() - 1)
	background_music.play_track(realm_bgm_tracks[track_index], immediate)


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
	background_music.play_track(heavenly_tribulation_bgm)
	tribulation.camera_shake_requested.connect(request_camera_shake)
	gameplay_hud.show_tribulation_warning()
	tribulation.start(player, run_resources.max_lifespan)


func _on_heavenly_tribulation_completed() -> void:
	_active_tribulation = null
	if run_resources.complete_pending_breakthrough():
		player.play_breakthrough_effect()
		if breakthrough_success_player.stream != null:
			breakthrough_success_player.play()
	_play_realm_bgm(run_resources.get_current_realm_index())


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
	annihilation.fatal_sequence_completed.connect(
		_on_realm_annihilation_completed,
		CONNECT_ONE_SHOT
	)
	annihilation.tree_exited.connect(
		_on_realm_annihilation_exited,
		CONNECT_ONE_SHOT
	)
	annihilation.start(player)


func _on_realm_annihilation_landed() -> void:
	player.set_movement_enabled(false)
	infinite_world.set_progression_enabled(false)
	enemy_spawner.set_spawning_enabled(false)
	road_fork_spawner.set_forks_enabled(false)
	request_camera_shake(18.0)


func _on_realm_annihilation_completed() -> void:
	# Clear the active guard before depletion emits synchronously. The visual
	# node queues itself afterward, so the complete impact remains on screen.
	_active_annihilation = null
	if run_resources.is_run_active():
		run_resources.force_deplete()
	else:
		_finish_run(false)


func _on_realm_annihilation_exited() -> void:
	_active_annihilation = null


func _on_lifespan_depleted() -> void:
	if _run_ended:
		return
	# Once the final unavoidable sequence begins, all depletion paths wait for
	# its visible impact to complete instead of replacing it with the overlay.
	if is_instance_valid(_active_annihilation):
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
		_play_realm_bgm(run_resources.get_current_realm_index())
	if is_instance_valid(_active_annihilation):
		_active_annihilation.queue_free()
		_active_annihilation = null
	pause_menu.call("set_pause_enabled", false)
	_show_run_outcome()


func _show_run_outcome() -> void:
	var summary := _build_run_summary()
	if _run_won:
		run_ended_overlay.show_ascension(summary)
	elif _fatal_breakthrough_triggered:
		run_ended_overlay.show_fatal_breakthrough(summary)
	else:
		run_ended_overlay.show_defeat(summary)


func _on_player_damage_recorded(
	source_id: StringName,
	amount: int
) -> void:
	var actual_amount := maxi(amount, 0)
	_total_damage_dealt += actual_amount
	var resolved_source := source_id if not source_id.is_empty() else &"other"
	_weapon_damage_dealt[resolved_source] = (
		int(_weapon_damage_dealt.get(resolved_source, 0))
		+ actual_amount
	)


func _on_enemy_defeat_recorded(is_elite: bool) -> void:
	_enemies_defeated += 1
	if is_elite:
		_elite_enemies_defeated += 1


func _build_run_summary() -> Dictionary:
	var weapon_levels: Array[Dictionary] = []
	var weapon_names: Dictionary = {}
	for equipment in player.get_equipment_inventory_snapshot():
		var weapon_data := equipment.get("data") as WeaponDataResource
		if weapon_data == null:
			continue
		weapon_names[weapon_data.weapon_id] = weapon_data.display_name
		weapon_levels.append({
			"weapon_id": weapon_data.weapon_id,
			"fallback_name": weapon_data.display_name,
			"level": maxi(int(equipment.get("quantity", 1)), 1),
		})
	var damage_ranking: Array[Dictionary] = []
	var ranked_sources: Dictionary = {}
	for weapon_id_variant in weapon_names:
		var weapon_id := StringName(weapon_id_variant)
		ranked_sources[weapon_id] = true
		damage_ranking.append({
			"weapon_id": weapon_id,
			"fallback_name": str(weapon_names[weapon_id]),
			"damage": int(_weapon_damage_dealt.get(weapon_id, 0)),
		})
	for source_variant in _weapon_damage_dealt:
		var source_id := StringName(source_variant)
		if ranked_sources.has(source_id):
			continue
		damage_ranking.append({
			"weapon_id": source_id,
			"fallback_name": str(
				weapon_names.get(
					source_id,
					"境界化身" if source_id == &"realm_echo" else "其他"
				)
			),
			"damage": int(_weapon_damage_dealt[source_id]),
		})
	damage_ranking.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["damage"]) > int(b["damage"])
	)
	return {
		"duration_seconds": _elapsed_run_time,
		"weapon_levels": weapon_levels,
		"total_damage": _total_damage_dealt,
		"enemies_defeated": _enemies_defeated,
		"elite_enemies_defeated": _elite_enemies_defeated,
		"weapon_damage_ranking": damage_ranking,
		"fatal_breakthrough": _fatal_breakthrough_triggered,
	}


## Aggregates read-only subsystem snapshots for a future in-run debug panel.
func get_debug_snapshot() -> Dictionary:
	return {
		"run": run_resources.get_debug_snapshot(),
		"player": player.get_debug_snapshot(),
		"world": infinite_world.get_debug_snapshot(),
		"enemies": enemy_spawner.get_debug_snapshot(),
		"active_route_center_x": _active_route_center_x,
		"camera_route_center_x": _camera_route_center_x,
		"camera_route_pan_active": _camera_pan_active,
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
