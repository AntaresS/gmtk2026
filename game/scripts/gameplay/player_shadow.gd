class_name PlayerShadow
extends Node2D

## Ground-contact shadow radius in local pixels before elevation scaling.
@export var base_size: Vector2 = Vector2(34.0, 13.0)
## Shadow color at ground level.
@export var shadow_color: Color = Color(0.02, 0.025, 0.035, 0.42)
## Smallest visual scale used at high flight elevations.
@export_range(0.1, 1.0, 0.05) var minimum_scale: float = 0.48
## Lowest opacity ratio used at high flight elevations.
@export_range(0.05, 1.0, 0.05) var minimum_opacity: float = 0.35
## Elevation in pixels at which minimum scale and opacity are reached.
@export_range(1.0, 300.0, 1.0) var maximum_visual_elevation: float = 100.0

var _elevation: float = 0.0


func set_elevation(value: float) -> void:
	_elevation = maxf(value, 0.0)
	queue_redraw()


func get_elevation() -> float:
	return _elevation


func _draw() -> void:
	var elevation_ratio := clampf(
		_elevation / maxf(maximum_visual_elevation, 1.0),
		0.0,
		1.0
	)
	var size_multiplier := lerpf(1.0, minimum_scale, elevation_ratio)
	var color := shadow_color
	color.a *= lerpf(1.0, minimum_opacity, elevation_ratio)
	var points := PackedVector2Array()
	for point_index in 32:
		var angle := float(point_index) / 32.0 * TAU
		points.append(
			Vector2(cos(angle), sin(angle))
			* base_size
			* size_multiplier
		)
	draw_colored_polygon(points, color)
