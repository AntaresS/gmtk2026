class_name ActiveAbilityIcon
extends Control

const ICON_SIZE := Vector2(76.0, 76.0)

var ability_id: StringName = &"roll"
var active: bool = false
var ability_ready: bool = true
var progress: float = 1.0
var _animation_time: float = 0.0


func _ready() -> void:
	custom_minimum_size = ICON_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


## Updates the realm ability illustration from the player's read-only active
## ability snapshot. Cooldown authority remains with PlayerController.
func configure(
	new_ability_id: StringName,
	is_active: bool,
	is_ready: bool,
	cooldown_progress: float
) -> void:
	ability_id = new_ability_id
	active = is_active
	ability_ready = is_ready
	progress = clampf(cooldown_progress, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_animation_time = fmod(_animation_time + maxf(delta, 0.0), TAU)
	if active or ability_ready:
		queue_redraw()


func _draw() -> void:
	var center := ICON_SIZE * 0.5
	var color := _get_ability_color()
	draw_circle(center, 35.0, Color(0.025, 0.045, 0.075, 0.96))
	draw_circle(
		center,
		29.0,
		Color(color, 0.1 if ability_ready else 0.035)
	)
	draw_arc(
		center,
		35.0,
		-PI * 0.5,
		-PI * 0.5 + TAU * progress,
		48,
		color if ability_ready or active else Color(0.35, 0.4, 0.48),
		5.0,
		true
	)
	if active:
		var pulse := 0.5 + 0.5 * sin(_animation_time * 7.0)
		draw_arc(
			center,
			29.0 + pulse * 3.0,
			0.0,
			TAU,
			40,
			Color(color, 0.36 + pulse * 0.5),
			2.0 + pulse * 2.0,
			true
		)
	elif ability_ready:
		draw_circle(center, 26.0, Color(color, 0.035))

	match ability_id:
		&"roll":
			_draw_roll(center, color)
		&"temporary_flight":
			_draw_flight(center, color)
		&"golden_core_echoes":
			_draw_echoes(center, color)
		&"spirit_projection":
			_draw_spirit(center, color)
		_:
			draw_circle(center, 11.0, color)


func _get_ability_color() -> Color:
	match ability_id:
		&"roll":
			return Color("72e8ff")
		&"temporary_flight":
			return Color("8fffd6")
		&"golden_core_echoes":
			return Color("ffd35a")
		&"spirit_projection":
			return Color("c6a2ff")
		_:
			return Color("b7c5d8")


func _draw_roll(center: Vector2, color: Color) -> void:
	draw_arc(center, 14.0, -PI * 0.9, PI * 0.65, 24, color, 5.0, true)
	var arrow_tip := center + Vector2(14.0, 9.0)
	draw_colored_polygon(
		PackedVector2Array([
			arrow_tip,
			arrow_tip + Vector2(-10.0, -1.0),
			arrow_tip + Vector2(-3.0, -9.0),
		]),
		color
	)
	for line_index in 3:
		var y := -11.0 + float(line_index) * 11.0
		draw_line(
			center + Vector2(-27.0, y),
			center + Vector2(-18.0, y),
			Color(color, 0.55 + float(line_index) * 0.15),
			2.0
		)


func _draw_flight(center: Vector2, color: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(-2.0, 4.0),
			center + Vector2(-27.0, -10.0),
			center + Vector2(-18.0, 13.0),
		]),
		Color(color, 0.82)
	)
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(2.0, 4.0),
			center + Vector2(27.0, -10.0),
			center + Vector2(18.0, 13.0),
		]),
		Color(color, 0.82)
	)
	draw_line(
		center + Vector2(0.0, 17.0),
		center + Vector2(0.0, -18.0),
		color,
		4.0
	)
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -22.0),
			center + Vector2(-7.0, -12.0),
			center + Vector2(7.0, -12.0),
		]),
		color
	)


func _draw_echoes(center: Vector2, color: Color) -> void:
	for offset in [Vector2(-16.0, 5.0), Vector2.ZERO, Vector2(16.0, 5.0)]:
		draw_circle(center + offset + Vector2(0.0, -9.0), 6.0, color)
		draw_arc(
			center + offset + Vector2(0.0, 7.0),
			10.0,
			PI,
			TAU,
			16,
			Color(color, 0.82),
			4.0,
			true
		)


func _draw_spirit(center: Vector2, color: Color) -> void:
	draw_circle(center + Vector2(-7.0, -9.0), 8.0, color)
	draw_arc(
		center + Vector2(-7.0, 9.0),
		13.0,
		PI,
		TAU,
		20,
		color,
		5.0,
		true
	)
	draw_circle(
		center + Vector2(10.0, -13.0),
		7.0,
		Color(color, 0.42)
	)
	draw_arc(
		center + Vector2(10.0, 4.0),
		12.0,
		PI,
		TAU,
		20,
		Color(color, 0.42),
		4.0,
		true
	)
