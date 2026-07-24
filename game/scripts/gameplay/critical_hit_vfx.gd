class_name CriticalHitVfx
extends Node2D

## Short world-space burst spawned by an enemy when critical damage lands.
## The scene owns presentation while EnemyController only supplies the damage.

## Total lifetime of the critical-hit burst in seconds.
@export_range(0.2, 1.5, 0.05) var duration: float = 0.55
## Final radius in world pixels reached by the expanding impact rings.
@export_range(20.0, 120.0, 1.0) var burst_radius: float = 48.0
## Upward distance in world pixels traveled by the critical damage label.
@export_range(8.0, 100.0, 1.0) var label_rise_distance: float = 42.0
## Primary color shared by impact rays, rings, and the critical label.
@export var critical_color: Color = Color("ffd447")

@onready var critical_hit_label: Label = %CriticalHitLabel

var _elapsed: float = 0.0
var _label_origin_position: Vector2 = Vector2.ZERO
var _started: bool = false


func _ready() -> void:
	add_to_group("critical_hit_vfx")
	_label_origin_position = critical_hit_label.position
	critical_hit_label.hide()
	set_process(false)


## Starts one self-cleaning critical burst after the caller positions it in the
## world. Damage is presentation-only and never applied by this VFX.
func play(damage: int) -> void:
	_elapsed = 0.0
	_started = true
	critical_hit_label.text = "暴击!  -%d" % maxi(damage, 1)
	critical_hit_label.modulate = critical_color
	critical_hit_label.show()
	modulate = Color.WHITE
	scale = Vector2.ONE * 0.72
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not _started:
		return
	_elapsed = minf(_elapsed + delta, maxf(duration, 0.01))
	var progress := _elapsed / maxf(duration, 0.01)
	var eased_progress := ease(progress, -1.7)
	critical_hit_label.position = _label_origin_position + Vector2(
		0.0,
		-label_rise_distance * eased_progress
	)
	scale = Vector2.ONE * lerpf(0.72, 1.08, minf(progress * 3.0, 1.0))
	modulate.a = 1.0 - pow(progress, 2.2)
	queue_redraw()
	if progress >= 1.0:
		queue_free()


func _draw() -> void:
	if not _started:
		return
	var progress := _elapsed / maxf(duration, 0.01)
	var impact_alpha := 1.0 - progress
	var radius := lerpf(10.0, burst_radius, ease(progress, -1.4))
	var ring_color := critical_color
	ring_color.a = impact_alpha * 0.9
	draw_circle(Vector2.ZERO, radius * 0.38, Color(
		critical_color.r,
		critical_color.g,
		critical_color.b,
		impact_alpha * 0.12
	))
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		32,
		ring_color,
		4.0,
		true
	)
	var inner_color := Color.WHITE
	inner_color.a = impact_alpha * 0.8
	draw_arc(
		Vector2.ZERO,
		radius * 0.58,
		0.0,
		TAU,
		24,
		inner_color,
		2.0,
		true
	)
	for ray_index in 8:
		var direction := Vector2.from_angle(
			float(ray_index) / 8.0 * TAU
		)
		draw_line(
			direction * radius * 0.42,
			direction * radius * 1.18,
			ring_color,
			3.0,
			true
		)
