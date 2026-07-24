class_name WeaponPowerFragment
extends Node2D

signal power_collected(amount: int)
signal upgrade_collected(upgrade_type: int, amount: int)
signal channel_changed(
	progress: float,
	active: bool,
	cancelled: bool
)

## Flat base damage granted to every existing and future weapon on collection.
@export_range(1, 100, 1) var power_amount: int = 1
## Global upgrade category selected by EnemySpawner before this drop appears.
@export var upgrade_type: UniversalUpgradeTypes.UpgradeType = (
	UniversalUpgradeTypes.UpgradeType.DAMAGE
)
## Radius in world pixels inside which the player channels this fragment.
@export_range(32.0, 240.0, 1.0) var pickup_radius: float = 96.0
## Continuous seconds the player must remain inside the radius to collect it.
@export_range(0.2, 5.0, 0.1) var channel_duration: float = 1.0
## Distance behind the player in world pixels after which this fragment is
## removed to keep long runs bounded.
@export_range(200.0, 2000.0, 10.0) var despawn_behind_distance: float = 900.0

@onready var description_label: Label = $DescriptionLabel
@onready var power_glyph: Label = $PowerGlyph

var _player: PlayerController
var _inherited_velocity: Vector2 = Vector2.ZERO
var _channel_elapsed: float = 0.0
var _channeling: bool = false
var _completed: bool = false
var _visual_phase: float = 0.0


## Assigns the collecting player and preserves the defeated elite's movement.
func configure(
	player: PlayerController,
	inherited_velocity: Vector2,
	new_upgrade_type: int = UniversalUpgradeTypes.UpgradeType.DAMAGE
) -> void:
	_player = player
	_inherited_velocity = inherited_velocity
	upgrade_type = clampi(new_upgrade_type, 0, UniversalUpgradeTypes.COUNT - 1)


func _ready() -> void:
	power_glyph.text = UniversalUpgradeTypes.get_display_name(upgrade_type)
	_update_label()


func _physics_process(delta: float) -> void:
	if _completed:
		return
	global_position += _inherited_velocity * delta
	_visual_phase = fmod(_visual_phase + delta * 3.4, TAU)
	if not is_instance_valid(_player):
		_cancel_channel()
		queue_redraw()
		return

	var player_inside := (
		global_position.distance_to(_player.global_position)
		<= maxf(pickup_radius, 1.0)
	)
	if player_inside:
		if not _channeling:
			_channeling = true
			_channel_elapsed = 0.0
			channel_changed.emit(0.0, true, false)
		_channel_elapsed = minf(
			_channel_elapsed + delta,
			maxf(channel_duration, 0.01)
		)
		channel_changed.emit(get_channel_progress(), true, false)
		if _channel_elapsed >= maxf(channel_duration, 0.01):
			_complete_channel()
			return
	elif _channeling:
		_cancel_channel()

	_update_label()
	queue_redraw()
	if (
		global_position.y - _player.global_position.y
		> maxf(despawn_behind_distance, 1.0)
	):
		_cancel_channel()
		queue_free()


func _draw() -> void:
	var color := UniversalUpgradeTypes.get_color(upgrade_type)
	var radius := maxf(pickup_radius, 1.0)
	var pulse := 0.9 + sin(_visual_phase) * 0.08
	draw_circle(Vector2.ZERO, radius, Color(color, 0.08))
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		80,
		Color(color, 0.88),
		3.0,
		true
	)
	if _channeling:
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
	var shape_radius := 24.0 * pulse
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


func _cancel_channel() -> void:
	if not _channeling or _completed:
		return
	_channeling = false
	_channel_elapsed = 0.0
	channel_changed.emit(0.0, false, true)


func _complete_channel() -> void:
	if _completed:
		return
	_completed = true
	_channeling = false
	channel_changed.emit(1.0, false, false)
	upgrade_collected.emit(upgrade_type, maxi(power_amount, 1))
	power_collected.emit(maxi(power_amount, 1))
	queue_free()


func _update_label() -> void:
	if not is_instance_valid(description_label):
		return
	if _channeling:
		description_label.text = "%s强化碎片\n引导 %.1f / %.1f秒" % [
			UniversalUpgradeTypes.get_display_name(upgrade_type),
			minf(_channel_elapsed, channel_duration),
			channel_duration,
		]
	else:
		description_label.text = "%s强化碎片\n靠近并持续停留" % (
			UniversalUpgradeTypes.get_display_name(upgrade_type)
		)


func get_channel_progress() -> float:
	return clampf(
		_channel_elapsed / maxf(channel_duration, 0.01),
		0.0,
		1.0
	)
