class_name RoadForkSpawner
extends Node2D

signal branch_selected(branch_name: String)
signal route_committed(route_center_x: float, branch_name: String)

## Fork scene created beyond the camera's forward edge.
@export var road_fork_scene: PackedScene = preload(
	"res://game/scenes/gameplay/road_fork.tscn"
)
## Player reference injected into each fork.
@export var player: PlayerController
## Camera used to place forks beyond the visible forward edge.
@export var camera: Camera2D
## Delay in seconds before the first fork is generated.
@export_range(0.0, 30.0, 0.5) var initial_spawn_delay: float = 4.0
## Seconds between generated fork choices.
@export_range(4.0, 60.0, 0.5) var spawn_interval: float = 28.0
## Extra world pixels beyond the camera top reserved for the fork artwork.
@export_range(100.0, 600.0, 1.0) var spawn_ahead_margin: float = 280.0
## Maximum simultaneous fork events retained in the scene.
@export_range(1, 4, 1) var max_active_forks: int = 2

var road_half_width: float = 200.0
var _spawn_time_remaining: float = 0.0
var _forks_enabled: bool = true
var _next_branch_side: int = -1
var _route_center_x: float = 0.0
var _road_half_width_resolver: Callable
var _world_config: WorldChunkConfig


func _ready() -> void:
	_spawn_time_remaining = maxf(initial_spawn_delay, 0.0)


func _physics_process(delta: float) -> void:
	if (
		not _forks_enabled
		or not is_instance_valid(player)
		or not is_instance_valid(camera)
	):
		return
	_spawn_time_remaining -= delta
	if _spawn_time_remaining > 0.0:
		return
	_spawn_time_remaining = maxf(spawn_interval, 0.1)
	if get_tree().get_nodes_in_group("road_forks").size() >= max_active_forks:
		return
	_spawn_fork()


func set_road_half_width(value: float) -> void:
	road_half_width = maxf(value, 64.0)


## Supplies InfiniteWorld's deterministic world-Y width sampler.
func set_road_half_width_resolver(resolver: Callable) -> void:
	_road_half_width_resolver = resolver


## Supplies the shared atlas and tile dimensions used by generated chunks.
func set_world_config(value: WorldChunkConfig) -> void:
	_world_config = value


## Moves later fork events to the active infinite route center.
func set_route_center_x(value: float) -> void:
	_route_center_x = value


## Enables new forks or freezes all choices when the run ends.
func set_forks_enabled(enabled: bool) -> void:
	_forks_enabled = enabled
	if enabled:
		return
	for fork_node in get_tree().get_nodes_in_group("road_forks"):
		if fork_node is RoadFork:
			(fork_node as RoadFork).set_fork_enabled(false)


func _spawn_fork() -> void:
	if road_fork_scene == null:
		return
	var road_fork := road_fork_scene.instantiate() as RoadFork
	if road_fork == null:
		push_error("RoadForkSpawner road_fork_scene must instantiate RoadFork.")
		return
	road_fork.player = player
	var half_visible_height := (
		get_viewport_rect().size.y / maxf(camera.zoom.y, 0.01) * 0.5
	)
	var camera_top_y := camera.global_position.y - half_visible_height
	road_fork.set_world_config(_world_config)
	road_fork.set_road_half_width_resolver(_road_half_width_resolver)
	var spawn_y := (
		camera_top_y
		- spawn_ahead_margin
		- road_fork.get_visual_entry_bottom_y()
	)
	road_fork.set_road_half_width(_get_road_half_width_at(spawn_y))
	road_fork.configure_side(_next_branch_side)
	road_fork.configure_trial_hell(true)
	_next_branch_side *= -1
	road_fork.branch_selected.connect(_on_branch_selected)
	road_fork.route_committed.connect(_on_route_committed)
	road_fork.position = to_local(Vector2(
		_route_center_x,
		spawn_y
	))
	add_child(road_fork)


func _on_branch_selected(branch_name: String) -> void:
	branch_selected.emit(branch_name)


func _on_route_committed(
	route_center_x: float,
	branch_name: String
) -> void:
	_route_center_x = route_center_x
	route_committed.emit(route_center_x, branch_name)


func _get_road_half_width_at(world_y: float) -> float:
	if _road_half_width_resolver.is_valid():
		return maxf(float(_road_half_width_resolver.call(world_y)), 64.0)
	return maxf(road_half_width, 64.0)
