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
@export_range(4.0, 60.0, 0.5) var spawn_interval: float = 14.0
## Extra world pixels beyond the camera top reserved for the fork artwork.
@export_range(100.0, 600.0, 1.0) var spawn_ahead_margin: float = 280.0
## Maximum simultaneous fork events retained in the scene.
@export_range(1, 4, 1) var max_active_forks: int = 2

var road_half_width: float = 200.0
var _spawn_time_remaining: float = 0.0
var _forks_enabled: bool = true
var _next_branch_side: int = -1
var _next_is_trial_hell: bool = false
var _route_center_x: float = 0.0


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
	add_child(road_fork)
	road_fork.set_road_half_width(road_half_width)
	road_fork.configure_side(_next_branch_side)
	road_fork.configure_trial_hell(_next_is_trial_hell)
	_next_branch_side *= -1
	_next_is_trial_hell = not _next_is_trial_hell
	road_fork.branch_selected.connect(_on_branch_selected)
	road_fork.route_committed.connect(_on_route_committed)

	var half_visible_height := (
		get_viewport_rect().size.y / maxf(camera.zoom.y, 0.01) * 0.5
	)
	road_fork.global_position = Vector2(
		_route_center_x,
		camera.global_position.y - half_visible_height - spawn_ahead_margin
	)


func _on_branch_selected(branch_name: String) -> void:
	branch_selected.emit(branch_name)


func _on_route_committed(
	route_center_x: float,
	branch_name: String
) -> void:
	_route_center_x = route_center_x
	route_committed.emit(route_center_x, branch_name)
