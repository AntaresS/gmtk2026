class_name PalmExecuteVfx
extends Node2D

## Short world-space burst that distinguishes a Nascent Soul Palm execute from
## ordinary numeric or critical damage.

## Total lifetime of the execute burst in seconds.
@export_range(0.2, 1.5, 0.05) var duration: float = 0.6
## Final radius in world pixels reached by the dissolving soul rings.
@export_range(20.0, 140.0, 1.0) var burst_radius: float = 58.0
## Upward distance in world pixels traveled by the execute label.
@export_range(8.0, 100.0, 1.0) var label_rise_distance: float = 46.0
## Primary cyan color shared by the soul rings, rays, and execute label.
@export var execute_color: Color = Color("62f5ff")

@onready var execute_label: Label = %ExecuteLabel

var _elapsed: float = 0.0
var _label_origin_position: Vector2 = Vector2.ZERO
var _started: bool = false


func _ready() -> void:
	add_to_group("palm_execute_vfx")
	LanguageManager.language_changed.connect(_on_language_changed)
	_label_origin_position = execute_label.position
	execute_label.hide()
	set_process(false)


## Starts one self-cleaning execute burst after the caller positions it in the
## world. Damage and enemy removal remain owned by the combat system.
func play() -> void:
	_elapsed = 0.0
	_started = true
	execute_label.text = LanguageManager.text("body_break")
	execute_label.modulate = execute_color
	execute_label.show()
	modulate = Color.WHITE
	scale = Vector2.ONE * 0.68
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not _started:
		return
	_elapsed = minf(_elapsed + delta, maxf(duration, 0.01))
	var progress := _elapsed / maxf(duration, 0.01)
	var eased_progress := ease(progress, -1.8)
	execute_label.position = _label_origin_position + Vector2(
		0.0,
		-label_rise_distance * eased_progress
	)
	scale = Vector2.ONE * lerpf(0.68, 1.12, minf(progress * 3.2, 1.0))
	modulate.a = 1.0 - pow(progress, 2.0)
	queue_redraw()
	if progress >= 1.0:
		queue_free()


func _on_language_changed(_locale: String) -> void:
	if _started:
		execute_label.text = LanguageManager.text("body_break")


func _draw() -> void:
	if not _started:
		return
	var progress := _elapsed / maxf(duration, 0.01)
	var impact_alpha := 1.0 - progress
	var radius := lerpf(8.0, burst_radius, ease(progress, -1.5))
	var ring_color := Color(execute_color, impact_alpha * 0.92)
	draw_circle(
		Vector2.ZERO,
		radius * 0.42,
		Color(execute_color, impact_alpha * 0.14)
	)
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		36,
		ring_color,
		4.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		radius * 0.62,
		0.0,
		TAU,
		28,
		Color(0.92, 1.0, 1.0, impact_alpha * 0.86),
		2.0,
		true
	)
	for ray_index in 10:
		var direction := Vector2.from_angle(
			float(ray_index) / 10.0 * TAU
		)
		draw_line(
			direction * radius * 0.3,
			direction * radius * 1.12,
			ring_color,
			2.5,
			true
		)
