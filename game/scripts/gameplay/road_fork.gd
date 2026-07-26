class_name RoadFork
extends Node2D

signal branch_selected(branch_name: String)
signal route_committed(route_center_x: float, branch_name: String)

const MAIN_ROUTE_CHOICE := "继续当前主路"
const StaticCanvasCacheResource = preload(
	"res://game/scripts/gameplay/static_canvas_cache.gd"
)

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
## Number of samples used to turn the smooth center line into a road ribbon.
## Higher values improve edge smoothness without changing route collision.
@export_range(12, 64, 1) var curve_sample_count: int = 32
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
var _world_config: WorldChunkConfig
var _road_half_width_resolver: Callable
var _visual_cache: Node2D
var _visual_cache_ready: bool = false
var _is_visual_cache_painter: bool = false
var _visual_cache_world_origin: Vector2 = Vector2.ZERO
var _visual_cache_world_width: float = 0.0


func _ready() -> void:
	if _is_visual_cache_painter:
		return
	add_to_group("road_forks")
	LanguageManager.language_changed.connect(_on_language_changed)
	_update_labels()
	_rebuild_visual_cache()
	queue_redraw()


func _exit_tree() -> void:
	if _is_visual_cache_painter:
		return
	_clear_player_bounds()


func _physics_process(_delta: float) -> void:
	if _is_visual_cache_painter:
		return
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
			_selected_branch = MAIN_ROUTE_CHOICE
			_clear_player_bounds()
		choice_label.text = LanguageManager.text(
			"route_selected_format"
		) % LanguageManager.get_route_name(_selected_branch)
		choice_label.show()
		branch_selected.emit(_selected_branch)
		_rebuild_visual_cache()
		queue_redraw()

	var cleanup_y := -half_length - 520.0
	if _selected_branch == MAIN_ROUTE_CHOICE:
		cleanup_y = minf(
			cleanup_y,
			_get_rejected_branch_exit_y() - 240.0
		)
	if local_player.y < cleanup_y:
		_clear_player_bounds()
		queue_free()


func _draw() -> void:
	if _is_visual_cache_painter:
		_draw_static_surface()
		return
	if not _visual_cache_ready:
		_draw_static_surface()
	_draw_route_guidance()


func _draw_static_surface() -> void:
	var centerline := get_curve_centerline_points()
	var visible_road_polygons := _get_visible_road_polygons()
	var junction_polygons := _get_junction_road_polygons()
	for polygon in visible_road_polygons:
		draw_colored_polygon(polygon, Color("625f55"))
	for polygon in junction_polygons:
		draw_colored_polygon(polygon, Color("625f55"))
	if trial_hell:
		for polygon in _get_visible_road_polygons(-88.0):
			draw_colored_polygon(
				polygon,
				Color(0.085, 0.045, 0.032, 1.0)
			)
		for polygon in _get_visible_road_polygons(-12.0):
			draw_colored_polygon(
				polygon,
				Color(0.30, 0.105, 0.035, 1.0)
			)
		for polygon in visible_road_polygons:
			draw_colored_polygon(
				polygon,
				Color(0.19, 0.105, 0.060, 1.0)
			)
		_draw_trial_hell_surface(visible_road_polygons)
		_draw_bluestone_road_texture(junction_polygons)
		_draw_branch_surface_wear(junction_polygons)
	else:
		var textured_polygons: Array[PackedVector2Array] = []
		for polygon in visible_road_polygons:
			textured_polygons.append(polygon)
		for polygon in junction_polygons:
			textured_polygons.append(polygon)
		_draw_bluestone_road_texture(textured_polygons)
		_draw_branch_surface_wear(textured_polygons)

	if not trial_hell:
		var edge_points := _get_road_edge_points()
		_draw_irregular_branch_edges(centerline, edge_points)
		_draw_branch_edge_decorations(
			centerline,
			edge_points
		)


func _draw_route_guidance() -> void:
	var centerline := get_curve_centerline_points()
	var guide_color := (
		Color(1.0, 0.20, 0.06, 0.98)
		if trial_hell
		else Color(0.84, 0.74, 0.5, 0.95)
	)
	if _selected_branch == _get_branch_name():
		guide_color = Color("7dffd8")
	elif not _selected_branch.is_empty():
		guide_color = Color(0.4, 0.4, 0.4, 0.55)
	_draw_polyline_outside_current_road(centerline, guide_color, 5.0)

	var marker_start := mini(
		maxi(curve_sample_count, 12),
		centerline.size() - 1
	)
	for marker_index in 5:
		var marker_position := centerline[marker_start]
		marker_position.y -= float(marker_index) * 125.0
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


func _rebuild_visual_cache() -> void:
	if _is_visual_cache_painter or not is_inside_tree():
		return
	_ensure_visual_cache()
	_visual_cache_ready = false
	queue_redraw()

	var painter := RoadFork.new()
	painter._is_visual_cache_painter = true
	painter.set_physics_process(false)
	for label_name in [&"LeftLabel", &"RightLabel", &"ChoiceLabel"]:
		var placeholder_label := Label.new()
		placeholder_label.name = label_name
		painter.add_child(placeholder_label)
	painter._visual_cache_world_origin = global_position
	painter._visual_cache_world_width = _get_visible_world_width()
	painter.branch_side = branch_side
	painter.main_road_half_width = main_road_half_width
	painter.branch_center_offset = branch_center_offset
	painter.fork_length = fork_length
	painter.curve_sample_count = curve_sample_count
	painter.trial_hell = trial_hell
	painter._selected_branch = _selected_branch
	painter._world_config = _world_config
	painter._road_half_width_resolver = _road_half_width_resolver
	_visual_cache.call(
		"rebuild",
		painter,
		_get_static_visual_bounds(),
		_get_visual_cache_raster_scale()
	)


func _ensure_visual_cache() -> void:
	if is_instance_valid(_visual_cache):
		return
	_visual_cache = StaticCanvasCacheResource.new()
	_visual_cache.name = "VisualCache"
	_visual_cache.z_index = -1
	add_child(_visual_cache, false, Node.INTERNAL_MODE_FRONT)
	_visual_cache.cache_ready.connect(_on_visual_cache_ready)


func _on_visual_cache_ready() -> void:
	_visual_cache_ready = true
	queue_redraw()


func _get_visual_cache_raster_scale() -> float:
	var active_camera := get_viewport().get_camera_2d()
	if not is_instance_valid(active_camera):
		return 1.0
	return clampf(
		minf(absf(active_camera.zoom.x), absf(active_camera.zoom.y)),
		0.25,
		2.0
	)


func _get_static_visual_bounds() -> Rect2:
	var polygons := _get_visible_road_polygons()
	polygons.append_array(_get_junction_road_polygons())
	if trial_hell:
		polygons.append_array(_get_visible_road_polygons(-88.0))

	var has_point := false
	var bounds := Rect2()
	for polygon in polygons:
		for point in polygon:
			if not has_point:
				bounds = Rect2(point, Vector2.ZERO)
				has_point = true
			else:
				bounds = bounds.expand(point)
	if not has_point:
		return Rect2(-Vector2.ONE * 64.0, Vector2.ONE * 128.0)
	return bounds.grow(128.0)


## Supplies the same atlas definition used by generated world chunks so the
## branch is textured as part of the road instead of a flat-color overlay.
func set_world_config(value: WorldChunkConfig) -> void:
	_world_config = value
	_rebuild_visual_cache()
	queue_redraw()


## Supplies InfiniteWorld's deterministic width sampler. The branch samples it
## along the whole curve rather than freezing one width at its spawn point.
func set_road_half_width_resolver(resolver: Callable) -> void:
	_road_half_width_resolver = resolver
	_rebuild_visual_cache()
	queue_redraw()


## Refreshes labels and cached drawing after runtime configuration changes.
func refresh_visuals() -> void:
	if is_node_ready():
		_update_labels()
	_rebuild_visual_cache()
	queue_redraw()


## Applies the generated current-road half-width and makes the branch equally
## wide, separated by an 80-pixel ground gap between parallel road edges.
func set_road_half_width(value: float) -> void:
	main_road_half_width = maxf(value, 64.0)
	var tile_size := 16.0
	if _world_config != null:
		tile_size = float(_world_config.tile_size)
	branch_center_offset = snappedf(
		main_road_half_width * 2.0 + 80.0,
		tile_size
	)
	if is_node_ready():
		_update_labels()
	_rebuild_visual_cache()
	queue_redraw()


## Chooses which side receives the next infinite branch.
func configure_side(side: int) -> void:
	branch_side = -1 if side < 0 else 1
	if is_node_ready():
		_update_labels()
	_rebuild_visual_cache()
	queue_redraw()


## Selects the branch event variant before it is shown to the player.
func configure_trial_hell(enabled: bool) -> void:
	trial_hell = enabled
	if is_node_ready():
		_update_labels()
	_rebuild_visual_cache()
	queue_redraw()


## Enables branch selection during a run or restores committed-route bounds
## when the run ends.
func set_fork_enabled(enabled: bool) -> void:
	_fork_enabled = enabled
	if not enabled:
		_clear_player_bounds()


func get_selected_branch() -> String:
	return _selected_branch


## Lowest local-Y extent of the fork entrance, including decorative clearance.
## The spawner uses this to construct the full fork beyond the camera edge.
func get_visual_entry_bottom_y() -> float:
	return fork_length * 0.5 + 160.0 + 96.0


func get_branch_center_x() -> float:
	return global_position.x + float(branch_side) * branch_center_offset


func is_trial_hell_branch() -> bool:
	return trial_hell


## Center points for the continuous branch. An unselected branch stays
## parallel; after the player keeps the main road it bends beyond the outer
## viewport edge so the rejected route leaves the map instead of being cut.
func get_curve_centerline_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var sample_count := maxi(curve_sample_count, 12)
	for sample_index in sample_count + 1:
		var ratio := float(sample_index) / float(sample_count)
		points.append(_sample_curve_center(ratio))
	var curve_end := points[points.size() - 1]
	var forward_y := _get_parallel_extension_end_y()
	for straight_index in range(1, 13):
		points.append(Vector2(
			float(branch_side) * branch_center_offset,
			lerpf(
				curve_end.y,
				forward_y,
				float(straight_index) / 12.0
			)
		))
	if _selected_branch == MAIN_ROUTE_CHOICE:
		_append_rejected_branch_exit(points, points[-1])
	return points


func _append_rejected_branch_exit(
	points: PackedVector2Array,
	bend_start: Vector2
) -> void:
	var side := float(branch_side)
	var viewport_width := maxf(_get_visible_world_width(), 960.0)
	var exit_x := side * (
		branch_center_offset
		+ viewport_width
		+ main_road_half_width
	)
	var exit_end := Vector2(exit_x, _get_rejected_branch_exit_y())
	var start_control := bend_start + Vector2(0.0, -fork_length * 0.24)
	var end_control := exit_end + Vector2(
		-side * viewport_width * 0.28,
		fork_length * 0.16
	)
	for exit_index in range(1, 17):
		var ratio := float(exit_index) / 16.0
		var inverse := 1.0 - ratio
		points.append(
			bend_start * inverse * inverse * inverse
			+ start_control * 3.0 * inverse * inverse * ratio
			+ end_control * 3.0 * inverse * ratio * ratio
			+ exit_end * ratio * ratio * ratio
		)


func _get_visible_world_width() -> float:
	if _is_visual_cache_painter and _visual_cache_world_width > 0.0:
		return _visual_cache_world_width
	var viewport_width := get_viewport_rect().size.x
	var active_camera := get_viewport().get_camera_2d()
	if not is_instance_valid(active_camera):
		return viewport_width
	return viewport_width / maxf(absf(active_camera.zoom.x), 0.01)


func _get_parallel_extension_end_y() -> float:
	return -fork_length * 0.5 - 760.0


func _get_rejected_branch_exit_y() -> float:
	return (
		_get_parallel_extension_end_y()
		- maxf(fork_length * 0.85, 900.0)
	)


func get_road_polygon() -> PackedVector2Array:
	return _get_road_polygon_with_inset(0.0)


func _commit_route() -> void:
	if _route_was_committed:
		return
	_route_was_committed = true
	var new_route_center := get_branch_center_x()
	choice_label.text = LanguageManager.text(
		"route_entering_format"
	) % LanguageManager.get_route_name(_selected_branch)
	choice_label.show()
	branch_selected.emit(_selected_branch)
	route_committed.emit(new_route_center, _selected_branch)
	_clear_player_bounds()
	_rebuild_visual_cache()
	queue_redraw()


func _sample_curve_center(ratio: float) -> Vector2:
	var t := clampf(ratio, 0.0, 1.0)
	var inverse := 1.0 - t
	var half_length := fork_length * 0.5
	var branch_x := float(branch_side) * branch_center_offset
	var start := Vector2(0.0, half_length + 160.0)
	var start_control := Vector2(0.0, half_length * 0.55)
	var end_control := Vector2(branch_x, half_length * 0.25)
	var end := Vector2(branch_x, -half_length * 0.18)
	return (
		start * inverse * inverse * inverse
		+ start_control * 3.0 * inverse * inverse * t
		+ end_control * 3.0 * inverse * t * t
		+ end * t * t * t
	)


func _get_road_edge_points(
	edge_inset: float = 0.0
) -> Array[PackedVector2Array]:
	var centerline := get_curve_centerline_points()
	var left_points := PackedVector2Array()
	var right_points := PackedVector2Array()
	for point_index in centerline.size():
		var previous := centerline[maxi(point_index - 1, 0)]
		var next := centerline[mini(point_index + 1, centerline.size() - 1)]
		var tangent := (next - previous).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var half_width := maxf(
			_get_road_half_width_at_local_y(centerline[point_index].y)
				- edge_inset,
			1.0
		)
		var left_width := maxf(
			half_width + _get_visual_edge_delta(
				centerline[point_index].y,
				0
			),
			32.0
		)
		var right_width := maxf(
			half_width + _get_visual_edge_delta(
				centerline[point_index].y,
				1
			),
			32.0
		)
		left_points.append(centerline[point_index] - normal * left_width)
		right_points.append(centerline[point_index] + normal * right_width)
	return [left_points, right_points]


func _get_road_polygon_with_inset(
	edge_inset: float
) -> PackedVector2Array:
	var edges := _get_road_edge_points(edge_inset)
	var polygon := PackedVector2Array()
	for point in edges[0]:
		polygon.append(point)
	for point_index in range(edges[1].size() - 1, -1, -1):
		polygon.append(edges[1][point_index])
	return polygon


## Removes the part shared with the current road. The branch is still rendered
## above the opaque ground, but visually emerges from beneath the main route
## instead of repainting its surface.
func _get_visible_road_polygons(
	edge_inset: float = 0.0
) -> Array[PackedVector2Array]:
	var branch_polygon := _get_road_polygon_with_inset(edge_inset)
	var current_road_polygon := _get_current_road_polygon()
	var clipped := Geometry2D.clip_polygons(
		branch_polygon,
		current_road_polygon
	)
	return clipped


func _get_junction_road_polygons() -> Array[PackedVector2Array]:
	return Geometry2D.intersect_polygons(
		get_road_polygon(),
		_get_current_road_polygon()
	)


func _get_current_road_polygon() -> PackedVector2Array:
	var centerline := get_curve_centerline_points()
	var minimum_y := centerline[0].y
	var maximum_y := centerline[0].y
	for point in centerline:
		minimum_y = minf(minimum_y, point.y)
		maximum_y = maxf(maximum_y, point.y)
	var left_points := PackedVector2Array()
	var right_points := PackedVector2Array()
	var sample_count := maxi(curve_sample_count * 2, 24)
	for sample_index in sample_count + 1:
		var ratio := float(sample_index) / float(sample_count)
		var local_y := lerpf(minimum_y, maximum_y, ratio)
		var half_width := _get_road_half_width_at_local_y(local_y)
		left_points.append(Vector2(
			-maxf(
				half_width + _get_visual_edge_delta(local_y, 0),
				32.0
			),
			local_y
		))
		right_points.append(Vector2(
			maxf(
				half_width + _get_visual_edge_delta(local_y, 1),
				32.0
			),
			local_y
		))
	var polygon := PackedVector2Array()
	for point in left_points:
		polygon.append(point)
	for point_index in range(right_points.size() - 1, -1, -1):
		polygon.append(right_points[point_index])
	return polygon


func _is_inside_current_road(local_position: Vector2) -> bool:
	var half_width := _get_road_half_width_at_local_y(local_position.y)
	var left_edge := -maxf(
		half_width + _get_visual_edge_delta(local_position.y, 0),
		32.0
	)
	var right_edge := maxf(
		half_width + _get_visual_edge_delta(local_position.y, 1),
		32.0
	)
	return (
		local_position.x >= left_edge
		and local_position.x <= right_edge
	)


func _is_near_current_road(
	local_position: Vector2,
	margin: float
) -> bool:
	var half_width := _get_road_half_width_at_local_y(local_position.y)
	var left_edge := -maxf(
		half_width + _get_visual_edge_delta(local_position.y, 0),
		32.0
	)
	var right_edge := maxf(
		half_width + _get_visual_edge_delta(local_position.y, 1),
		32.0
	)
	return (
		local_position.x >= left_edge - margin
		and local_position.x <= right_edge + margin
	)


func _draw_polyline_outside_current_road(
	points: PackedVector2Array,
	color: Color,
	width: float
) -> void:
	for point_index in range(1, points.size()):
		var start := points[point_index - 1]
		var end := points[point_index]
		if _is_inside_current_road((start + end) * 0.5):
			continue
		draw_line(start, end, color, width, true)


func _draw_bluestone_road_texture(
	visible_polygons: Array[PackedVector2Array]
) -> void:
	if visible_polygons.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	var visual_world_origin := _get_visual_world_origin()
	rng.seed = hash(Vector3i(
		roundi(visual_world_origin.x),
		roundi(visual_world_origin.y),
		31469
	))
	for polygon in visible_polygons:
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			bounds = bounds.expand(point)
		var row_y := bounds.position.y + rng.randf_range(5.0, 15.0)
		while row_y < bounds.end.y:
			var small_row := rng.randf() < 0.68
			var slab_height := (
				rng.randf_range(10.0, 22.0)
				if small_row
				else rng.randf_range(22.0, 32.0)
			)
			var slab_x := bounds.position.x + rng.randf_range(-20.0, 10.0)
			while slab_x < bounds.end.x:
				var small_slab := rng.randf() < 0.68
				var slab_width := (
					rng.randf_range(14.0, 48.0)
					if small_slab
					else rng.randf_range(48.0, 98.0)
				)
				var rect := Rect2(
					Vector2(slab_x, row_y),
					Vector2(slab_width, slab_height)
				)
				if (
					rng.randf() > 0.10
					and _rect_is_inside_polygon(rect, polygon)
				):
					_draw_bluestone_slab(rect, rng)
				slab_x += slab_width + rng.randf_range(1.5, 22.0)
			row_y += slab_height + rng.randf_range(2.0, 16.0)


func _rect_is_inside_polygon(
	rect: Rect2,
	polygon: PackedVector2Array
) -> bool:
	return (
		Geometry2D.is_point_in_polygon(rect.position, polygon)
		and Geometry2D.is_point_in_polygon(
			Vector2(rect.end.x, rect.position.y),
			polygon
		)
		and Geometry2D.is_point_in_polygon(rect.end, polygon)
		and Geometry2D.is_point_in_polygon(
			Vector2(rect.position.x, rect.end.y),
			polygon
		)
	)


func _draw_bluestone_slab(
	rect: Rect2,
	rng: RandomNumberGenerator
) -> void:
	var jitter := minf(rect.size.y * 0.16, 3.5)
	var points := PackedVector2Array([
		rect.position + Vector2(
			rng.randf_range(0.0, jitter),
			rng.randf_range(0.0, jitter)
		),
		Vector2(rect.end.x, rect.position.y) + Vector2(
			-rng.randf_range(0.0, jitter),
			rng.randf_range(0.0, jitter)
		),
		rect.end - Vector2(
			rng.randf_range(0.0, jitter),
			rng.randf_range(0.0, jitter)
		),
		Vector2(rect.position.x, rect.end.y) + Vector2(
			rng.randf_range(0.0, jitter),
			-rng.randf_range(0.0, jitter)
		),
	])
	var base_color := Color(0.57, 0.55, 0.49, 1.0)
	match rng.randi_range(0, 5):
		1:
			base_color = Color(0.52, 0.51, 0.47, 1.0)
		2:
			base_color = Color(0.62, 0.59, 0.51, 1.0)
		3:
			base_color = Color(0.65, 0.61, 0.53, 1.0)
		4:
			base_color = Color(0.55, 0.54, 0.50, 1.0)
		5:
			base_color = Color(0.60, 0.56, 0.49, 1.0)
	var shade := rng.randf_range(-0.028, 0.035)
	draw_colored_polygon(
		points,
		Color(
			base_color.r + shade,
			base_color.g + shade,
			base_color.b + shade,
			rng.randf_range(0.62, 0.80)
		)
	)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color(0.18, 0.17, 0.14, 0.34), 1.0, true)
	var detail_variant := rng.randi_range(0, 4)
	match detail_variant:
		0:
			var grain_y := rect.position.y + rect.size.y * 0.58
			draw_line(
				Vector2(rect.position.x + 7.0, grain_y),
				Vector2(rect.end.x - 7.0, grain_y + rng.randf_range(-2.0, 2.0)),
				Color(0.68, 0.66, 0.57, 0.22),
				1.0,
				true
			)
		1:
			for _pit in rng.randi_range(1, 3):
				draw_circle(
					rect.get_center() + Vector2(
						rng.randf_range(-rect.size.x * 0.32, rect.size.x * 0.32),
						rng.randf_range(-rect.size.y * 0.26, rect.size.y * 0.26)
					),
					rng.randf_range(0.7, 1.6),
					Color(0.08, 0.14, 0.15, 0.20)
				)
		2:
			draw_line(
				Vector2(rect.position.x + 5.0, rect.end.y - 3.0),
				Vector2(
					rect.position.x + rect.size.x * rng.randf_range(0.35, 0.78),
					rect.end.y - 2.0
				),
				Color(0.24, 0.39, 0.25, 0.24),
				2.0,
				true
			)
		3:
			if rect.size.x > 28.0:
				var crack_start := rect.get_center() + Vector2(
					rng.randf_range(-rect.size.x * 0.18, rect.size.x * 0.12),
					-rng.randf_range(1.0, rect.size.y * 0.22)
				)
				draw_line(
					crack_start,
					crack_start + Vector2(
						rng.randf_range(5.0, 13.0),
						rng.randf_range(3.0, 8.0)
					),
					Color(0.07, 0.12, 0.13, 0.28),
					1.0,
					true
				)
	if (
		detail_variant != 3
		and rect.size.x > 24.0
		and rng.randf() < 0.38
	):
		var extra_crack_start := rect.get_center() + Vector2(
			rng.randf_range(-rect.size.x * 0.24, rect.size.x * 0.14),
			rng.randf_range(-rect.size.y * 0.20, rect.size.y * 0.10)
		)
		var extra_crack_middle := extra_crack_start + Vector2(
			rng.randf_range(3.0, minf(10.0, rect.size.x * 0.24)),
			rng.randf_range(2.0, minf(6.0, rect.size.y * 0.30))
		)
		draw_polyline(
			PackedVector2Array([
				extra_crack_start,
				extra_crack_middle,
				extra_crack_middle + Vector2(
					rng.randf_range(-3.0, 5.0),
					rng.randf_range(2.0, 5.0)
				),
			]),
			Color(0.07, 0.12, 0.13, 0.32),
			1.0,
			true
		)


func _draw_trial_hell_surface(
	visible_polygons: Array[PackedVector2Array]
) -> void:
	var rng := RandomNumberGenerator.new()
	var visual_world_origin := _get_visual_world_origin()
	rng.seed = hash(Vector3i(
		roundi(visual_world_origin.x),
		roundi(visual_world_origin.y),
		84011
	))
	for polygon in visible_polygons:
		if polygon.is_empty():
			continue
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			bounds = bounds.expand(point)
		var patch_attempts := rng.randi_range(1, 3)
		for patch_index in patch_attempts:
			var center := Vector2(
				rng.randf_range(bounds.position.x, bounds.end.x),
				rng.randf_range(bounds.position.y, bounds.end.y)
			)
			var radii := Vector2(
				rng.randf_range(7.0, minf(46.0, bounds.size.x * 0.30)),
				rng.randf_range(3.5, minf(22.0, bounds.size.y * 0.38))
			)
			if patch_index == 0 and rng.randf() < 0.30:
				radii *= rng.randf_range(1.25, 1.65)
			var patch := _make_hell_irregular_ellipse(
				center,
				radii,
				Vector2.RIGHT,
				Vector2.DOWN,
				rng
			)
			var patch_color := Color(0.255, 0.135, 0.068, 0.62)
			match rng.randi_range(0, 4):
				1:
					patch_color = Color(0.125, 0.060, 0.035, 0.76)
				2:
					patch_color = Color(0.34, 0.155, 0.055, 0.46)
				3:
					patch_color = Color(0.215, 0.085, 0.035, 0.68)
				4:
					patch_color = Color(0.29, 0.19, 0.105, 0.44)
			for clipped_patch in Geometry2D.intersect_polygons(
				patch,
				polygon
			):
				draw_colored_polygon(clipped_patch, patch_color)

		if rng.randf() < 0.52:
			var pit_center := Vector2(
				rng.randf_range(bounds.position.x, bounds.end.x),
				rng.randf_range(bounds.position.y, bounds.end.y)
			)
			var pit_radii := Vector2(
				rng.randf_range(5.0, minf(18.0, bounds.size.x * 0.18)),
				rng.randf_range(2.5, minf(9.0, bounds.size.y * 0.24))
			)
			var pit_rim := _make_hell_irregular_ellipse(
				pit_center + Vector2(0.0, 1.5),
				pit_radii * 1.22,
				Vector2.RIGHT,
				Vector2.DOWN,
				rng
			)
			for clipped_rim in Geometry2D.intersect_polygons(
				pit_rim,
				polygon
			):
				draw_colored_polygon(
					clipped_rim,
					Color(0.38, 0.19, 0.075, 0.42)
				)
			var pit := _make_hell_irregular_ellipse(
				pit_center,
				pit_radii,
				Vector2.RIGHT,
				Vector2.DOWN,
				rng
			)
			for clipped_pit in Geometry2D.intersect_polygons(pit, polygon):
				draw_colored_polygon(
					clipped_pit,
					Color(0.075, 0.035, 0.024, 0.84)
				)


func _make_hell_irregular_ellipse(
	center: Vector2,
	radii: Vector2,
	axis_x: Vector2,
	axis_y: Vector2,
	rng: RandomNumberGenerator
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var point_count := rng.randi_range(8, 12)
	for point_index in point_count:
		var angle := TAU * float(point_index) / float(point_count)
		var distortion := rng.randf_range(0.76, 1.18)
		points.append(
			center
			+ axis_x * cos(angle) * radii.x * distortion
			+ axis_y * sin(angle) * radii.y * distortion
		)
	return points


func _draw_branch_edge_decorations(
	centerline: PackedVector2Array,
	edge_points: Array[PackedVector2Array]
) -> void:
	var rng := RandomNumberGenerator.new()
	var visual_world_origin := _get_visual_world_origin()
	rng.seed = hash(Vector3i(
		roundi(visual_world_origin.x),
		roundi(visual_world_origin.y),
		57203
	))
	for edge_index in 2:
		var distance_until_next := rng.randf_range(6.0, 18.0)
		for point_index in range(1, centerline.size()):
			var edge_start := edge_points[edge_index][point_index - 1]
			var edge_end := edge_points[edge_index][point_index]
			var center_start := centerline[point_index - 1]
			var center_end := centerline[point_index]
			var segment_length := edge_start.distance_to(edge_end)
			while distance_until_next <= segment_length:
				var ratio := distance_until_next / maxf(segment_length, 0.001)
				var edge := edge_start.lerp(edge_end, ratio)
				var center := center_start.lerp(center_end, ratio)
				if not _is_near_current_road(edge, 64.0):
					var outward := (edge - center).normalized()
					var tangent := Vector2(-outward.y, outward.x)
					var root := edge + outward * rng.randf_range(1.0, 7.0)
					root += tangent * rng.randf_range(-5.0, 5.0)
					if rng.randf() < 0.90:
						_draw_loess_cluster(root, outward, rng)
					else:
						_draw_rock_cluster(root, rng)
				distance_until_next += rng.randf_range(28.0, 42.0)
			distance_until_next -= segment_length


func _draw_loess_cluster(
	root: Vector2,
	outward: Vector2,
	rng: RandomNumberGenerator
) -> void:
	var scale := rng.randf_range(0.78, 1.55)
	var tangent := Vector2(-outward.y, outward.x)
	draw_line(
		root - tangent * 15.0 * scale,
		root + tangent * 15.0 * scale,
		Color(0.24, 0.14, 0.045, 0.92),
		8.0 * scale,
		true
	)
	draw_circle(
		root + outward * 2.0 + Vector2(2.0, 3.0),
		13.0 * scale,
		Color(0.08, 0.045, 0.015, 0.38)
	)
	for layer_index in 3:
		var clod_count := rng.randi_range(4, 7)
		if layer_index == 0:
			clod_count = rng.randi_range(1, 2)
		elif layer_index == 1:
			clod_count = rng.randi_range(2, 4)
		for _clod in clod_count:
			var size := rng.randf_range(2.4, 5.5) * scale
			if layer_index == 0:
				size = rng.randf_range(13.0, 23.0) * scale
			elif layer_index == 1:
				size = rng.randf_range(6.0, 12.0) * scale
			var outward_offset := rng.randf_range(-5.0, 4.0) * scale
			if layer_index == 0:
				outward_offset = rng.randf_range(3.0, 10.0) * scale
			elif layer_index == 1:
				outward_offset = rng.randf_range(-1.0, 7.0) * scale
			var center := (
				root
				+ tangent * rng.randf_range(-16.0, 16.0) * scale
				+ outward * outward_offset
				+ Vector2(0.0, float(layer_index) * 2.0)
			)
			_draw_single_loess_clod(center, size, rng)


func _draw_single_loess_clod(
	center: Vector2,
	size: float,
	rng: RandomNumberGenerator
) -> void:
	var points := PackedVector2Array()
	var point_count := rng.randi_range(6, 9)
	for point_index in point_count:
		var angle := TAU * float(point_index) / float(point_count)
		var radius := size * rng.randf_range(0.72, 1.16)
		points.append(
			center + Vector2(
				cos(angle) * radius,
				sin(angle) * radius * rng.randf_range(0.58, 0.82)
			)
		)
	var base_color := Color(0.43, 0.27, 0.09, 0.98)
	match rng.randi_range(0, 3):
		1:
			base_color = Color(0.49, 0.32, 0.12, 0.98)
		2:
			base_color = Color(0.36, 0.21, 0.065, 0.98)
		3:
			base_color = Color(0.53, 0.36, 0.15, 0.98)
	draw_colored_polygon(points, base_color)
	if size > 5.5 and rng.randf() < 0.58:
		draw_line(
			center + Vector2(-size * 0.48, -size * 0.20),
			center + Vector2(size * 0.12, -size * 0.34),
			Color(0.67, 0.46, 0.21, 0.38),
			maxf(size * 0.10, 1.0),
			true
		)
	if size > 10.0 and rng.randf() < 0.36:
		draw_line(
			center + Vector2(-size * 0.05, -size * 0.10),
			center + Vector2(size * 0.24, size * 0.20),
			Color(0.20, 0.11, 0.03, 0.65),
			1.0,
			true
		)
	if size > 6.0 and rng.randf() < 0.32:
		draw_circle(
			center + Vector2(
				rng.randf_range(-size * 0.42, size * 0.42),
				rng.randf_range(-size * 0.24, size * 0.24)
			),
			rng.randf_range(0.6, 1.25),
			Color(0.22, 0.13, 0.035, 0.54)
		)


func _draw_branch_surface_wear(
	visible_polygons: Array[PackedVector2Array]
) -> void:
	var rng := RandomNumberGenerator.new()
	var visual_world_origin := _get_visual_world_origin()
	rng.seed = hash(Vector3i(
		roundi(visual_world_origin.x),
		roundi(visual_world_origin.y),
		64709
	))
	for polygon in visible_polygons:
		if polygon.is_empty():
			continue
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			bounds = bounds.expand(point)
		var stain_count := clampi(
			roundi(bounds.size.y / 95.0),
			4,
			18
		)
		for _stain in stain_count:
			var center := Vector2(
				rng.randf_range(bounds.position.x, bounds.end.x),
				rng.randf_range(bounds.position.y, bounds.end.y)
			)
			if not Geometry2D.is_point_in_polygon(center, polygon):
				continue
			var radius_x := rng.randf_range(10.0, 36.0)
			var radius_y := rng.randf_range(5.0, 16.0)
			var stain_points := PackedVector2Array()
			var point_count := rng.randi_range(7, 10)
			for point_index in point_count:
				var angle := TAU * float(point_index) / float(point_count)
				var distortion := rng.randf_range(0.68, 1.18)
				stain_points.append(
					center + Vector2(
						cos(angle) * radius_x * distortion,
						sin(angle) * radius_y * distortion
					)
				)
			draw_colored_polygon(
				stain_points,
				Color(0.15, 0.12, 0.085, rng.randf_range(0.08, 0.17))
			)

		var crack_count := clampi(
			roundi(bounds.size.y / 85.0),
			5,
			18
		)
		for _crack in crack_count:
			var current := Vector2(
				rng.randf_range(bounds.position.x, bounds.end.x),
				rng.randf_range(bounds.position.y, bounds.end.y)
			)
			if not Geometry2D.is_point_in_polygon(current, polygon):
				continue
			var crack_points := PackedVector2Array([current])
			for _segment in rng.randi_range(2, 4):
				current += Vector2(
					rng.randf_range(-8.0, 8.0),
					rng.randf_range(4.0, 10.0)
				)
				crack_points.append(current)
			draw_polyline(
				crack_points,
				Color(0.07, 0.075, 0.07, rng.randf_range(0.28, 0.46)),
				rng.randf_range(0.8, 1.4),
				true
			)


func _draw_irregular_branch_edges(
	centerline: PackedVector2Array,
	edge_points: Array[PackedVector2Array]
) -> void:
	var visual_world_origin := _get_visual_world_origin()
	for edge_index in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector3i(
			roundi(visual_world_origin.x),
			roundi(visual_world_origin.y),
			66103 + edge_index * 997
		))
		var distance_until_next := rng.randf_range(7.0, 24.0)
		for point_index in range(1, centerline.size()):
			var edge_start := edge_points[edge_index][point_index - 1]
			var edge_end := edge_points[edge_index][point_index]
			var center_start := centerline[point_index - 1]
			var center_end := centerline[point_index]
			var segment_length := edge_start.distance_to(edge_end)
			var tangent := (edge_end - edge_start).normalized()
			while distance_until_next <= segment_length:
				var ratio := distance_until_next / maxf(segment_length, 0.001)
				var edge := edge_start.lerp(edge_end, ratio)
				var center := center_start.lerp(center_end, ratio)
				if not _is_near_current_road(edge, 64.0):
					var outward := (edge - center).normalized()
					var block_length := (
						rng.randf_range(6.0, 16.0)
						if rng.randf() < 0.68
						else rng.randf_range(18.0, 30.0)
					)
					var half_length := block_length * 0.5
					var missing := rng.randf() < 0.43
					var inner_depth := (
						rng.randf_range(6.0, 30.0)
						if missing
						else rng.randf_range(1.0, 7.0)
					)
					var outer_depth := (
						rng.randf_range(2.0, 8.0)
						if missing
						else rng.randf_range(4.0, 24.0)
					)
					var inner := edge - outward * inner_depth
					var outer := edge + outward * outer_depth
					var jitter := rng.randf_range(
						0.5,
						minf(4.0, half_length * 0.70)
					)
					var block := PackedVector2Array([
						inner - tangent * (
							half_length - rng.randf_range(0.0, jitter)
						),
						outer - tangent * (
							half_length - rng.randf_range(0.0, jitter)
						),
						outer + tangent * (
							half_length - rng.randf_range(0.0, jitter)
						),
						inner + tangent * (
							half_length - rng.randf_range(0.0, jitter)
						),
					])
					if missing:
						draw_colored_polygon(
							block,
							Color(
								rng.randf_range(0.37, 0.47),
								rng.randf_range(0.255, 0.335),
								rng.randf_range(0.105, 0.17),
								0.98
							)
						)
					else:
						var stone_tint := rng.randf_range(-0.035, 0.04)
						draw_colored_polygon(
							block,
							Color(
								0.53 + stone_tint,
								0.52 + stone_tint,
								0.47 + stone_tint,
								0.96
							)
						)
						if rng.randf() < 0.52:
							draw_line(
								edge - tangent * half_length * 0.55,
								edge + outward * outer_depth * 0.72,
								Color(0.12, 0.18, 0.18, 0.38),
								1.0,
								true
							)
				distance_until_next += rng.randf_range(18.0, 68.0)
			distance_until_next -= segment_length


func _draw_rock_cluster(
	root: Vector2,
	rng: RandomNumberGenerator
) -> void:
	var cluster_scale := rng.randf_range(0.75, 1.4)
	var rock_count := rng.randi_range(1, 3)
	draw_circle(
		root + Vector2(2.0, 3.0),
		10.0 * cluster_scale,
		Color(0.04, 0.08, 0.07, 0.25)
	)
	for rock_index in rock_count:
		var radius := rng.randf_range(5.0, 11.0) * cluster_scale
		if rock_index > 0:
			radius *= rng.randf_range(0.48, 0.72)
		var center := root + Vector2(
			rng.randf_range(-7.0, 8.0),
			float(rock_index) * 3.0 + rng.randf_range(-3.0, 3.0)
		)
		_draw_single_rock(center, radius, rng)


func _draw_single_rock(
	center: Vector2,
	radius: float,
	rng: RandomNumberGenerator
) -> void:
	var points := PackedVector2Array()
	var point_count := rng.randi_range(6, 8)
	for point_index in point_count:
		var angle := TAU * float(point_index) / float(point_count)
		var point_radius := radius * rng.randf_range(0.78, 1.12)
		points.append(
			center + Vector2(
				cos(angle) * point_radius,
				sin(angle) * point_radius * rng.randf_range(0.58, 0.76)
			)
		)
	var tint := rng.randf_range(-0.05, 0.06)
	draw_colored_polygon(
		points,
		Color(0.35 + tint, 0.39 + tint, 0.38 + tint, 0.98)
	)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color(0.12, 0.15, 0.14, 0.75), 1.2, true)
	draw_line(
		center + Vector2(-radius * 0.45, -radius * 0.20),
		center + Vector2(radius * 0.18, -radius * 0.34),
		Color(0.65, 0.69, 0.64, 0.42),
		maxf(radius * 0.12, 1.0),
		true
	)
	if radius > 7.0 and rng.randf() < 0.55:
		draw_line(
			center + Vector2(-radius * 0.08, -radius * 0.12),
			center + Vector2(radius * 0.28, radius * 0.22),
			Color(0.16, 0.19, 0.18, 0.55),
			1.0,
			true
		)


func _get_road_half_width_at_local_y(local_y: float) -> float:
	var visual_world_origin := _get_visual_world_origin()
	if _road_half_width_resolver.is_valid():
		return maxf(
			float(
				_road_half_width_resolver.call(
					visual_world_origin.y + local_y
				)
			),
			64.0
		)
	return main_road_half_width


func _get_visual_edge_delta(local_y: float, side_index: int) -> float:
	var world_seed := (
		_world_config.world_seed if _world_config != null else 20260722
	)
	var generated_world_y := _get_visual_world_origin().y + local_y
	var segment_length := 64.0
	var coordinate := generated_world_y / segment_length
	var anchor_index := floori(coordinate)
	var ratio := coordinate - float(anchor_index)
	var smooth_ratio := ratio * ratio * (3.0 - 2.0 * ratio)
	var first := _get_visual_edge_anchor(
		world_seed,
		anchor_index,
		side_index
	)
	var second := _get_visual_edge_anchor(
		world_seed,
		anchor_index + 1,
		side_index
	)
	return lerpf(first, second, smooth_ratio)


func _get_visual_world_origin() -> Vector2:
	if _is_visual_cache_painter:
		return _visual_cache_world_origin
	return global_position


func _get_visual_edge_anchor(
	world_seed: int,
	anchor_index: int,
	side_index: int
) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(
		world_seed,
		anchor_index,
		7319 + side_index * 104729
	))
	return rng.randf_range(-24.0, 34.0)


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
		LanguageManager.text("route_trial_description")
		if trial_hell
		else (
			LanguageManager.text("route_left")
			if branch_side < 0
			else LanguageManager.text("route_right")
		)
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


func _on_language_changed(_locale: String) -> void:
	_update_labels()
	if not choice_label.visible or _selected_branch.is_empty():
		return
	choice_label.text = LanguageManager.text(
		"route_entering_format"
		if _route_was_committed
		else "route_selected_format"
	) % LanguageManager.get_route_name(_selected_branch)
