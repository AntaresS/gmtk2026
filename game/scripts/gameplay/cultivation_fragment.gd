class_name CultivationFragment
extends Node2D

signal fragment_collected(cultivation_type: int)
signal type_changed(cultivation_type: int, time_until_next: float)
signal channel_changed(
	cultivation_type: int,
	progress: float,
	active: bool,
	cancelled: bool
)

const CultivationTypesResource = preload(
	"res://game/scripts/gameplay/cultivation_types.gd"
)
const DEFAULT_CULTIVATION_CONFIG: CultivationConfig = preload(
	"res://game/resources/cultivation_config.tres"
)

## Shared type colors, icons, and labels. The fragment never mutates it.
@export var cultivation_config: CultivationConfig = DEFAULT_CULTIVATION_CONFIG
## Seconds each unlocked type remains active before deterministically advancing
## 精 → 气 → 神. The elapsed point is preserved across cancelled channels.
@export_range(0.2, 10.0, 0.1) var cycle_interval: float = 1.0
## Radius in world pixels inside which remaining continuously begins and
## continues channeling automatically.
@export_range(32.0, 240.0, 1.0) var pickup_radius: float = 96.0
## Continuous time in seconds required inside the pickup radius to collect the
## locked type.
@export_range(0.2, 5.0, 0.1) var channel_duration: float = 1.2
## Distance behind the player in world pixels after which an ignored fragment
## is removed to keep long runs bounded.
@export_range(200.0, 2000.0, 10.0) var despawn_behind_distance: float = 900.0

@onready var description_label: Label = $DescriptionLabel
@onready var type_glyph: Label = $TypeGlyph

var current_type: CultivationTypesResource.CultivationType = (
	CultivationTypesResource.CultivationType.JING
)
var _player: PlayerController
var _inherited_velocity: Vector2 = Vector2.ZERO
var _cycle_elapsed: float = 0.0
var _channel_elapsed: float = 0.0
var _locked: bool = false
var _completed: bool = false
var _visual_phase: float = 0.0


## Assigns the collecting player and preserves the defeated elite's movement.
func configure(
	player: PlayerController,
	inherited_velocity: Vector2
) -> void:
	_player = player
	_inherited_velocity = inherited_velocity


func _ready() -> void:
	_refresh_presentation()
	type_changed.emit(current_type, get_time_until_next_type())


func _physics_process(delta: float) -> void:
	if _completed:
		return
	global_position += _inherited_velocity * delta
	_visual_phase = fmod(_visual_phase + delta * 3.0, TAU)

	if not _locked:
		_advance_cycle(delta)

	if not is_instance_valid(_player):
		_cancel_channel()
		queue_redraw()
		return

	var player_inside := (
		global_position.distance_to(_player.global_position)
		<= maxf(pickup_radius, 1.0)
	)
	if player_inside:
		if not _locked:
			_begin_channel()
		_channel_elapsed = minf(
			_channel_elapsed + delta,
			maxf(channel_duration, 0.01)
		)
		channel_changed.emit(
			current_type,
			get_channel_progress(),
			true,
			false
		)
		if _channel_elapsed >= maxf(channel_duration, 0.01):
			_complete_channel()
			return
	elif _locked:
		_cancel_channel()

	_update_label(player_inside)
	queue_redraw()
	if (
		global_position.y - _player.global_position.y
		> maxf(despawn_behind_distance, 1.0)
	):
		_cancel_channel()
		queue_free()


func _draw() -> void:
	var type_config := _get_type_config()
	var color := (
		type_config.display_color
		if type_config != null
		else Color.WHITE
	)
	var radius := maxf(pickup_radius, 1.0)
	var pulse := 0.9 + sin(_visual_phase) * 0.08
	draw_circle(Vector2.ZERO, radius, Color(color, 0.08))
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		80,
		Color(color, 0.85),
		3.0,
		true
	)
	if _locked:
		draw_arc(
			Vector2.ZERO,
			radius - 7.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * get_channel_progress(),
			80,
			Color.WHITE,
			7.0,
			true
		)
	_draw_type_shape(color, pulse)
	if type_config != null and type_config.icon != null:
		draw_texture_rect(
			type_config.icon,
			Rect2(-18.0, -18.0, 36.0, 36.0),
			false,
			Color.WHITE
		)


func _draw_type_shape(color: Color, pulse: float) -> void:
	var shape_radius := 22.0 * pulse
	match current_type:
		CultivationTypesResource.CultivationType.JING:
			var triangle := PackedVector2Array([
				Vector2(0.0, -shape_radius),
				Vector2(shape_radius * 0.9, shape_radius * 0.75),
				Vector2(-shape_radius * 0.9, shape_radius * 0.75),
			])
			draw_colored_polygon(triangle, Color(color, 0.9))
			draw_polyline(
				PackedVector2Array([
					triangle[0],
					triangle[1],
					triangle[2],
					triangle[0],
				]),
				Color.WHITE,
				2.5
			)
		CultivationTypesResource.CultivationType.QI:
			var diamond := PackedVector2Array([
				Vector2(0.0, -shape_radius),
				Vector2(shape_radius, 0.0),
				Vector2(0.0, shape_radius),
				Vector2(-shape_radius, 0.0),
			])
			draw_colored_polygon(diamond, Color(color, 0.9))
			draw_polyline(
				PackedVector2Array([
					diamond[0],
					diamond[1],
					diamond[2],
					diamond[3],
					diamond[0],
				]),
				Color.WHITE,
				2.5
			)
		CultivationTypesResource.CultivationType.SHEN:
			draw_circle(Vector2.ZERO, shape_radius, Color(color, 0.88))
			draw_arc(
				Vector2.ZERO,
				shape_radius * 0.65,
				0.0,
				TAU,
				32,
				Color.WHITE,
				3.0,
				true
			)
			for spoke_index in 6:
				var direction := Vector2.from_angle(
					float(spoke_index) / 6.0 * TAU
				)
				draw_line(
					direction * shape_radius,
					direction * (shape_radius + 8.0),
					Color(color, 0.95),
					3.0
				)


func _advance_cycle(delta: float) -> void:
	_cycle_elapsed += delta
	var interval := maxf(cycle_interval, 0.01)
	var changed := false
	while _cycle_elapsed >= interval:
		_cycle_elapsed -= interval
		current_type = CultivationTypesResource.get_next_type(current_type)
		changed = true
	if changed:
		_refresh_presentation()
	type_changed.emit(current_type, get_time_until_next_type())


func _begin_channel() -> void:
	_locked = true
	_channel_elapsed = 0.0
	channel_changed.emit(current_type, 0.0, true, false)


func _cancel_channel() -> void:
	if not _locked or _completed:
		return
	var cancelled_type := current_type
	_locked = false
	_channel_elapsed = 0.0
	channel_changed.emit(cancelled_type, 0.0, false, true)


func _complete_channel() -> void:
	if _completed:
		return
	_completed = true
	_locked = true
	channel_changed.emit(current_type, 1.0, false, false)
	fragment_collected.emit(current_type)
	queue_free()


func _refresh_presentation() -> void:
	var type_config := _get_type_config()
	var type_name := CultivationTypesResource.get_name_zh(current_type)
	type_glyph.text = type_name
	type_glyph.modulate = (
		type_config.display_color
		if type_config != null
		else Color.WHITE
	)
	_update_label(false)
	queue_redraw()


func _update_label(player_inside: bool) -> void:
	if not is_instance_valid(description_label):
		return
	var type_name := CultivationTypesResource.get_name_zh(current_type)
	if _locked:
		description_label.text = "%s之碎片 · 已锁定\n引导 %.1f / %.1f秒" % [
			type_name,
			minf(_channel_elapsed, channel_duration),
			channel_duration,
		]
	elif player_inside:
		description_label.text = "%s之碎片\n停留范围内引导吸收" % type_name
	else:
		description_label.text = "%s之碎片 · %.1f秒后轮转\n靠近并持续停留" % [
			type_name,
			get_time_until_next_type(),
		]


func _get_type_config() -> CultivationTypeConfig:
	if cultivation_config == null:
		return null
	return cultivation_config.get_type_config(current_type)


func get_time_until_next_type() -> float:
	return maxf(maxf(cycle_interval, 0.01) - _cycle_elapsed, 0.0)


func get_channel_progress() -> float:
	return clampf(
		_channel_elapsed / maxf(channel_duration, 0.01),
		0.0,
		1.0
	)


func is_type_locked() -> bool:
	return _locked
