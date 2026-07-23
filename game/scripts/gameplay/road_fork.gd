class_name RoadFork
extends Node2D

signal branch_selected(branch_name: String)
signal route_committed(route_center_x: float, branch_name: String)

## Player allowed to leave the current infinite road while this full-width
## exterior branch is alongside it.
@export var player: PlayerController
## Side of the current road used by this branch: -1 is left and 1 is right.
@export_enum("Left:-1", "Right:1") var branch_side: int = -1
## Half-width of both the current road and branch in world pixels.
@export var main_road_half_width: float = 200.0
## Horizontal distance between the current road and branch centerlines.
@export_range(400.0, 900.0, 1.0) var branch_center_offset: float = 480.0
## Length of the transition from the current road into the parallel branch.
@export_range(700.0, 1800.0, 10.0) var fork_length: float = 1200.0
## Marks this branch as the red-black Trial Hell route. Route commitment uses
## this identity to activate its persistent terrain and combat modifiers.
@export var trial_hell: bool = false

@onready var left_label: Label = $LeftLabel
@onready var right_label: Label = $RightLabel
@onready var choice_label: Label = $ChoiceLabel

var _selected_branch: String = ""
var _fork_enabled: bool = true
var _temporary_bounds_active: bool = false
var _route_was_committed: bool = false


func _ready() -> void:
	add_to_group("road_forks")
	_update_labels()
	queue_redraw()


func _exit_tree() -> void:
	_clear_player_bounds()


func _physics_process(_delta: float) -> void:
	if not _fork_enabled or not is_instance_valid(player):
		return
	var local_player := to_local(player.global_position)
	var half_length := fork_length * 0.5

	if (
		not _temporary_bounds_active
		and _selected_branch.is_empty()
		and local_player.y <= half_length + 160.0
		and local_player.y >= -half_length
	):
		_apply_player_bounds()

	# At this point the branch is already parallel and completely outside the
	# old road. Crossing it commits an infinite route migration.
	if _selected_branch.is_empty() and local_player.y <= half_length * 0.12:
		var fully_inside_branch := (
			absf(local_player.x - float(branch_side) * branch_center_offset)
			<= main_road_half_width - player.horizontal_clearance
		)
		if fully_inside_branch:
			_selected_branch = _get_branch_name()
			_commit_route()
		else:
			_selected_branch = "继续当前主路"
			_clear_player_bounds()
		choice_label.text = "已选择：%s" % _selected_branch
		choice_label.show()
		branch_selected.emit(_selected_branch)
		queue_redraw()

	if local_player.y < -half_length - 520.0:
		_clear_player_bounds()
		queue_free()


func _draw() -> void:
	var side := float(branch_side)
	var half_length := fork_length * 0.5
	var branch_x := side * branch_center_offset
	var current_entry := Vector2(
		side * (main_road_half_width * 0.45),
		half_length
	)
	var branch_entry := Vector2(branch_x, half_length * 0.3)
	var branch_forward := Vector2(branch_x, -half_length - 620.0)
	var road_width := main_road_half_width * 2.0
	var shoulder_color := (
		Color(0.42, 0.04, 0.03, 0.99)
		if trial_hell
		else Color(0.48, 0.4, 0.28, 0.98)
	)
	var road_color := (
		Color(0.13, 0.015, 0.02, 0.99)
		if trial_hell
		else Color(0.13, 0.16, 0.2, 0.99)
	)

	# The connector and new route use exactly the same width as the generated
	# current road. After commitment InfiniteWorld continues from branch_x.
	draw_line(
		current_entry,
		branch_entry,
		shoulder_color,
		road_width + 18.0,
		true
	)
	draw_line(
		branch_entry,
		branch_forward,
		shoulder_color,
		road_width + 18.0,
		true
	)
	draw_line(current_entry, branch_entry, road_color, road_width, true)
	draw_line(branch_entry, branch_forward, road_color, road_width, true)

	var guide_color := (
		Color(1.0, 0.20, 0.06, 0.98)
		if trial_hell
		else Color(0.84, 0.74, 0.5, 0.95)
	)
	if _selected_branch == _get_branch_name():
		guide_color = Color("7dffd8")
	elif not _selected_branch.is_empty():
		guide_color = Color(0.4, 0.4, 0.4, 0.55)
	draw_line(current_entry, branch_entry, guide_color, 6.0, true)
	draw_line(branch_entry, branch_forward, guide_color, 6.0, true)

	for marker_index in 5:
		var marker_y := half_length * 0.15 - marker_index * 125.0
		var marker_position := Vector2(branch_x, marker_y)
		draw_line(
			marker_position + Vector2(0.0, 24.0),
			marker_position - Vector2(0.0, 24.0),
			guide_color,
			4.0
		)
		draw_line(
			marker_position - Vector2(0.0, 24.0),
			marker_position + Vector2(-10.0, -9.0),
			guide_color,
			4.0
		)
		draw_line(
			marker_position - Vector2(0.0, 24.0),
			marker_position + Vector2(10.0, -9.0),
			guide_color,
			4.0
		)
		if trial_hell:
			draw_circle(
				marker_position + Vector2(0.0, 38.0),
				7.0,
				Color(1.0, 0.42, 0.04, 0.88)
			)


## Applies the generated current-road half-width and makes the branch equally
## wide, separated by an 80-pixel ground gap between parallel road edges.
func set_road_half_width(value: float) -> void:
	main_road_half_width = maxf(value, 64.0)
	branch_center_offset = main_road_half_width * 2.0 + 80.0
	if is_node_ready():
		_update_labels()
	queue_redraw()


## Chooses which side receives the next infinite branch.
func configure_side(side: int) -> void:
	branch_side = -1 if side < 0 else 1
	if is_node_ready():
		_update_labels()
	queue_redraw()


## Selects the branch event variant before it is shown to the player.
func configure_trial_hell(enabled: bool) -> void:
	trial_hell = enabled
	if is_node_ready():
		_update_labels()
	queue_redraw()


## Enables branch selection during a run or restores committed-route bounds
## when the run ends.
func set_fork_enabled(enabled: bool) -> void:
	_fork_enabled = enabled
	if not enabled:
		_clear_player_bounds()


func get_selected_branch() -> String:
	return _selected_branch


func get_branch_center_x() -> float:
	return global_position.x + float(branch_side) * branch_center_offset


func is_trial_hell_branch() -> bool:
	return trial_hell


func _commit_route() -> void:
	if _route_was_committed:
		return
	_route_was_committed = true
	var new_route_center := get_branch_center_x()
	choice_label.text = "进入：%s" % _selected_branch
	choice_label.show()
	branch_selected.emit(_selected_branch)
	route_committed.emit(new_route_center, _selected_branch)
	_clear_player_bounds()
	queue_redraw()


func _apply_player_bounds() -> void:
	if not is_instance_valid(player):
		return
	var current_center := global_position.x
	var branch_center := get_branch_center_x()
	var minimum_center := minf(current_center, branch_center)
	var maximum_center := maxf(current_center, branch_center)
	player.set_temporary_lateral_bounds(
		minimum_center - main_road_half_width + player.horizontal_clearance,
		maximum_center + main_road_half_width - player.horizontal_clearance
	)
	_temporary_bounds_active = true


func _clear_player_bounds() -> void:
	if not _temporary_bounds_active or not is_instance_valid(player):
		return
	player.clear_temporary_lateral_bounds()
	_temporary_bounds_active = false


func _get_branch_name() -> String:
	if trial_hell:
		return "试炼地狱"
	return "左侧无尽岔路" if branch_side < 0 else "右侧无尽岔路"


func _update_labels() -> void:
	var branch_x := float(branch_side) * branch_center_offset
	left_label.visible = branch_side < 0
	right_label.visible = branch_side > 0
	var label_text := (
		"试炼地狱\n高压战斗区域"
		if trial_hell
		else "左侧无尽岔路" if branch_side < 0 else "右侧无尽岔路"
	)
	left_label.text = label_text
	right_label.text = label_text
	var label_color := (
		Color(1.0, 0.25, 0.12, 1.0)
		if trial_hell
		else Color(0.75, 1.0, 0.9, 1.0)
	)
	left_label.add_theme_color_override("font_color", label_color)
	right_label.add_theme_color_override("font_color", label_color)
	left_label.position = Vector2(branch_x - 70.0, 30.0)
	right_label.position = Vector2(branch_x - 70.0, 30.0)
	choice_label.position = Vector2(branch_x - 105.0, 145.0)
