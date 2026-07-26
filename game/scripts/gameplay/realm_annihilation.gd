class_name RealmAnnihilation
extends Node2D

signal fatal_strike_landed
## Emitted only after the unavoidable impact has remained visible for its full
## authored duration. Game waits for this before opening run results.
signal fatal_sequence_completed

## Unavoidable warning duration before the final heavenly strike.
@export_range(0.2, 5.0, 0.05) var warning_duration: float = 1.35
## Bright impact duration before the node removes itself.
@export_range(0.05, 2.0, 0.05) var impact_duration: float = 0.85
## Radius in pixels used by the visible annihilation seal.
@export_range(80.0, 900.0, 5.0) var seal_radius: float = 280.0

@onready var warning_label: Label = $WarningLabel

var _player: PlayerController
var _remaining: float = 0.0
var _impacting: bool = false


func _ready() -> void:
	LanguageManager.language_changed.connect(_on_language_changed)


func start(player: PlayerController) -> void:
	_player = player
	_remaining = maxf(warning_duration, 0.05)
	warning_label.text = LanguageManager.text("annihilation_warning")
	queue_redraw()


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		queue_free()
		return
	global_position = _player.global_position
	_remaining -= delta
	queue_redraw()
	if _remaining > 0.0:
		return
	if not _impacting:
		_impacting = true
		_remaining = maxf(impact_duration, 0.05)
		warning_label.text = LanguageManager.text("annihilation_impact")
		warning_label.modulate = Color(1.0, 0.88, 0.9, 1.0)
		fatal_strike_landed.emit()
		return
	fatal_sequence_completed.emit()
	queue_free()


func _on_language_changed(_locale: String) -> void:
	warning_label.text = LanguageManager.text(
		"annihilation_impact"
		if _impacting
		else "annihilation_warning"
	)


func _draw() -> void:
	if _impacting:
		draw_circle(Vector2.ZERO, seal_radius, Color(1.0, 1.0, 1.0, 0.78))
		var bolt_points := PackedVector2Array([
			Vector2(-34.0, -900.0),
			Vector2(22.0, -680.0),
			Vector2(-18.0, -470.0),
			Vector2(28.0, -250.0),
			Vector2.ZERO,
		])
		draw_polyline(
			bolt_points,
			Color(0.42, 0.7, 1.0, 0.48),
			34.0,
			true
		)
		draw_polyline(
			bolt_points,
			Color(0.92, 0.98, 1.0, 1.0),
			12.0,
			true
		)
		for ray_index in 16:
			var direction := Vector2.from_angle(float(ray_index) / 16.0 * TAU)
			draw_line(
				direction * 30.0,
				direction * seal_radius * 1.6,
				Color(0.65, 0.82, 1.0, 0.94),
				12.0,
				true
			)
		return
	var progress := 1.0 - clampf(
		_remaining / maxf(warning_duration, 0.05),
		0.0,
		1.0
	)
	draw_circle(Vector2.ZERO, seal_radius, Color(0.14, 0.3, 0.6, 0.12))
	draw_arc(
		Vector2.ZERO,
		seal_radius * lerpf(1.0, 0.32, progress),
		0.0,
		TAU,
		96,
		Color(0.62, 0.88, 1.0, 0.95),
		8.0,
		true
	)
