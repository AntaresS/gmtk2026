class_name ThunderHammerVisual
extends Node2D

const HAMMER_ENERGY_CENTER: Vector2 = Vector2(0.0, -18.0)
const HAMMER_BOLT_ORIGIN: Vector2 = Vector2(18.0, -18.0)

## Local position, in world pixels, relative to the player's visible character.
@export var equipped_offset: Vector2 = Vector2(46.0, -8.0)
## Base blue-white energy color used for charged outlines and lightning arcs.
@export var lightning_color: Color = Color("8fd8ff")
## Brighter critical-discharge color used to distinguish a critical volley.
@export var critical_lightning_color: Color = Color("f3c8ff")
## Neutral texture modulation at zero charge. Keep this near white to preserve
## the authored hammer artwork.
@export var hammer_idle_modulate: Color = Color.WHITE
## Subtle texture modulation at full charge. Brighter values make the hammer
## artwork itself participate in the readiness feedback.
@export var hammer_charged_modulate: Color = Color("d8f4ff")
## Maximum radius, in world pixels, of the readiness glow around the hammer head.
@export_range(8.0, 48.0, 1.0) var maximum_glow_radius: float = 25.0
## Number of deterministic lightning-shape refreshes per second while charged.
@export_range(1.0, 30.0, 1.0) var lightning_refresh_hz: float = 14.0
## Duration, in seconds, of the directional discharge flash for each cloud launch.
@export_range(0.05, 0.5, 0.01) var discharge_flash_duration: float = 0.16
## Short directional bolt length in world pixels. It indicates aim without
## drawing a misleading hitscan line all the way to the selected enemy.
@export_range(12.0, 96.0, 1.0) var target_bolt_length: float = 46.0

@onready var hammer_sprite: Sprite2D = $HammerPivot/HammerSprite
@onready var charge_arc: Line2D = $ChargeArc
@onready var target_arc: Line2D = $TargetArc

var _equipped: bool = false
var _charge_ratio: float = 0.0
var _target_ready: bool = false
var _aim_direction: Vector2 = Vector2.UP
var _discharge_direction: Vector2 = Vector2.UP
var _discharge_flash_remaining: float = 0.0
var _critical_discharge: bool = false
var _lightning_refresh_remaining: float = 0.0
var _lightning_shape_serial: int = 0


func _ready() -> void:
	hide()
	_refresh_lightning_geometry()


## Shows or hides the complete readiness presentation when equipment changes.
func set_equipped(equipped: bool) -> void:
	_equipped = equipped
	visible = _equipped
	if not _equipped:
		_charge_ratio = 0.0
		_target_ready = false
		_discharge_flash_remaining = 0.0
		target_arc.hide()
	queue_redraw()


## Synchronizes charge, target readiness, and volley discharge with live combat
## state. Cooldown progress begins only after the final cloud has launched.
func update_combat_state(
	delta: float,
	cooldown_remaining: float,
	cooldown_duration: float,
	volley_launched: int,
	volley_total: int,
	target_available: bool,
	aim_direction: Vector2
) -> void:
	if not _equipped:
		return
	_aim_direction = aim_direction.normalized()
	if _aim_direction.is_zero_approx():
		_aim_direction = Vector2.UP
	if volley_total > 0:
		_charge_ratio = clampf(
			1.0 - float(volley_launched) / float(maxi(volley_total, 1)),
			0.0,
			1.0
		)
	elif cooldown_remaining > 0.0:
		_charge_ratio = 1.0 - clampf(
			cooldown_remaining / maxf(cooldown_duration, 0.01),
			0.0,
			1.0
		)
	else:
		_charge_ratio = 1.0
	_target_ready = (
		target_available
		and volley_total <= 0
		and cooldown_remaining <= 0.0
	)
	var discharge_was_active := _discharge_flash_remaining > 0.0
	_discharge_flash_remaining = maxf(
		_discharge_flash_remaining - delta,
		0.0
	)
	if discharge_was_active and _discharge_flash_remaining <= 0.0:
		_critical_discharge = false
	_lightning_refresh_remaining -= delta
	if _lightning_refresh_remaining <= 0.0:
		_lightning_refresh_remaining += 1.0 / maxf(lightning_refresh_hz, 1.0)
		_lightning_shape_serial += 1
		_refresh_lightning_geometry()
	_update_presentation()


## Plays one reused directional lightning snap without allocating transient nodes.
func play_discharge(direction: Vector2, is_critical: bool = false) -> void:
	if not _equipped:
		return
	_discharge_direction = direction.normalized()
	if _discharge_direction.is_zero_approx():
		_discharge_direction = Vector2.UP
	_critical_discharge = is_critical
	_discharge_flash_remaining = maxf(discharge_flash_duration, 0.01)
	_lightning_shape_serial += 1
	_refresh_lightning_geometry()
	_update_presentation()


func _update_presentation() -> void:
	var pulse := 0.5 + 0.5 * sin(
		float(_lightning_shape_serial) * 1.73
	)
	var ready_boost := 0.18 if _target_ready else 0.0
	var energy := clampf(_charge_ratio + ready_boost * pulse, 0.0, 1.0)
	hammer_sprite.modulate = hammer_idle_modulate.lerp(
		hammer_charged_modulate,
		energy
	)
	var flash_strength := get_discharge_flash_strength()
	target_arc.visible = _target_ready or flash_strength > 0.0
	target_arc.width = 1.8 + energy * 1.4 + flash_strength * 2.6
	target_arc.default_color = Color(
		critical_lightning_color if _critical_discharge else lightning_color,
		clampf(0.22 + energy * 0.52 + flash_strength * 0.35, 0.0, 1.0)
	)
	charge_arc.width = 1.4 + energy * 1.8
	charge_arc.default_color = Color(
		lightning_color,
		0.16 + energy * 0.62
	)
	queue_redraw()


func _refresh_lightning_geometry() -> void:
	var flash_strength := get_discharge_flash_strength()
	var direction := (
		_discharge_direction
		if flash_strength > 0.0
		else _aim_direction
	)
	var bolt_length := target_bolt_length * (
		1.0 + flash_strength * 0.45
	)
	var perpendicular := direction.orthogonal()
	var bolt_points := PackedVector2Array()
	for point_index in 5:
		var progress := float(point_index) / 4.0
		var jitter := (
			sin(
				float(_lightning_shape_serial) * 2.17
					+ float(point_index) * 4.11
			)
			* (1.0 - absf(progress * 2.0 - 1.0))
			* 7.0
		)
		bolt_points.append(
			HAMMER_BOLT_ORIGIN
				+ direction * bolt_length * progress
				+ perpendicular * jitter
		)
	target_arc.points = bolt_points

	var arc_points := PackedVector2Array()
	var arc_segments := 24
	var visible_segments := maxi(
		ceili(float(arc_segments) * clampf(_charge_ratio, 0.02, 1.0)),
		2
	)
	for segment_index in visible_segments:
		var progress := float(segment_index) / float(arc_segments - 1)
		var angle := -PI * 0.5 + TAU * progress
		var radius_jitter := sin(
			float(_lightning_shape_serial) * 1.31
				+ float(segment_index) * 3.7
		) * 1.5
		arc_points.append(
			HAMMER_ENERGY_CENTER
				+ Vector2.from_angle(angle) * (19.0 + radius_jitter)
		)
	charge_arc.points = arc_points


func _draw() -> void:
	if not _equipped:
		return
	var flash_strength := get_discharge_flash_strength()
	var pulse := 0.5 + 0.5 * sin(float(_lightning_shape_serial) * 1.73)
	var glow_strength := clampf(
		_charge_ratio * (0.72 + pulse * 0.28) + flash_strength * 0.5,
		0.0,
		1.0
	)
	draw_circle(
		HAMMER_ENERGY_CENTER,
		lerpf(9.0, maximum_glow_radius, glow_strength),
		Color(lightning_color, 0.05 + glow_strength * 0.16)
	)
	if _target_ready:
		for spark_index in 3:
			var spark_angle := (
				float(spark_index) / 3.0 * TAU
				+ float(_lightning_shape_serial) * 0.73
			)
			var start := (
				HAMMER_ENERGY_CENTER
				+ Vector2.from_angle(spark_angle) * 19.0
			)
			draw_line(
				start,
				start + Vector2.from_angle(spark_angle + 0.4) * 7.0,
				Color(lightning_color, 0.55 + pulse * 0.35),
				1.5,
				true
			)


## Returns whether the dedicated hammer presentation is currently equipped.
func is_equipped_visual() -> bool:
	return _equipped


## Returns normalized recharge/discharge state for HUD and smoke validation.
func get_charge_ratio() -> float:
	return _charge_ratio


## Returns whether a valid target can immediately trigger a charged volley.
func is_target_ready() -> bool:
	return _target_ready


## Returns normalized strength of the reused launch flash.
func get_discharge_flash_strength() -> float:
	return clampf(
		_discharge_flash_remaining / maxf(discharge_flash_duration, 0.01),
		0.0,
		1.0
	)
