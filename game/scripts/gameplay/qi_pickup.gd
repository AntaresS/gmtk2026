class_name QiPickup
extends Area2D

signal qi_collected(amount: int)

## Density profile defining this pickup's identity, qi value, absorption time,
## size, color, and deterministic generation weight.
@export var density_profile: QiDensityProfile = preload(
	"res://game/resources/qi_density_small.tres"
)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_root: Node2D = $Visual
@onready var outer_glow: Polygon2D = $Visual/OuterGlow
@onready var core: Polygon2D = $Visual/Core
@onready var orbit_dot: Polygon2D = $Visual/OrbitDot
@onready var glyph: Label = $Visual/Glyph

var _absorbers: Array[Area2D] = []
var _absorption_progress_seconds: float = 0.0
var _animation_phase: float = 0.0
var _collected: bool = false


func _ready() -> void:
	_apply_density_visuals()


func _process(delta: float) -> void:
	_animation_phase = fmod(_animation_phase + delta, TAU)
	_prune_invalid_absorbers()
	if _collected:
		return

	if not _absorbers.is_empty():
		_absorption_progress_seconds += delta
		if _absorption_progress_seconds >= _get_absorption_duration():
			_complete_absorption()
			return

	var active := not _absorbers.is_empty()
	var pulse := (sin(_animation_phase * 4.0) + 1.0) * 0.5
	var activity_scale := 1.0 + (0.1 * pulse if active else 0.025 * pulse)
	visual_root.scale = Vector2.ONE * _get_visual_scale() * activity_scale
	visual_root.position.y = sin(_animation_phase * 2.2) * 3.0
	visual_root.rotation = sin(_animation_phase * 1.3) * 0.08
	outer_glow.modulate.a = 0.55 + (0.4 * pulse if active else 0.15 * pulse)
	queue_redraw()


func _draw() -> void:
	if _collected:
		return
	var progress := get_absorption_progress_ratio()
	var ring_radius := 27.0 * _get_visual_scale()
	var profile_color := _get_profile_color()
	var active := not _absorbers.is_empty()

	if progress > 0.0 or active:
		draw_arc(
			Vector2.ZERO,
			ring_radius,
			0.0,
			TAU,
			48,
			Color(0.05, 0.1, 0.12, 0.72),
			5.0,
			true
		)
		draw_arc(
			Vector2.ZERO,
			ring_radius,
			-PI * 0.5,
			-PI * 0.5 + TAU * progress,
			48,
			Color(profile_color, 0.95 if active else 0.58),
			4.0,
			true
		)

	if active:
		var absorber_position := to_local(_absorbers[0].global_position)
		draw_dashed_line(
			Vector2.ZERO,
			absorber_position,
			Color(profile_color, 0.5),
			2.0,
			8.0,
			true
		)


## Assigns one density identity to a freshly generated pickup. Existing
## absorption progress is cleared because chunks configure only new instances.
func configure_density(profile: QiDensityProfile) -> void:
	if profile == null:
		return
	density_profile = profile
	_absorption_progress_seconds = 0.0
	if is_node_ready():
		_apply_density_visuals()


## Returns normalized retained absorption progress for presentation and tests.
func get_absorption_progress_ratio() -> float:
	return clampf(
		_absorption_progress_seconds / _get_absorption_duration(),
		0.0,
		1.0
	)


func get_qi_value() -> int:
	if density_profile == null:
		return 10
	return maxi(density_profile.qi_value, 0)


## Prevents a recycled chunk's stale pickup from completing while it is being
## detached and safely queued for deletion.
func disable_collection() -> void:
	if _collected:
		return
	_collected = true
	_disable_collisions()


func _on_absorption_area_entered(area: Area2D) -> void:
	if (
		_collected
		or not area.has_method("is_qi_absorption_area")
		or not area.call("is_qi_absorption_area")
		or _absorbers.has(area)
	):
		return
	_absorbers.append(area)


func _on_absorption_area_exited(area: Area2D) -> void:
	_absorbers.erase(area)


func _complete_absorption() -> void:
	if _collected:
		return
	_collected = true
	_absorption_progress_seconds = _get_absorption_duration()
	_disable_collisions()
	qi_collected.emit(get_qi_value())
	queue_redraw()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		visual_root,
		"scale",
		Vector2.ONE * _get_visual_scale() * 1.65,
		0.22
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(queue_free)


func _disable_collisions() -> void:
	collision_layer = 0
	collision_mask = 0
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)


func _prune_invalid_absorbers() -> void:
	for index in range(_absorbers.size() - 1, -1, -1):
		if not is_instance_valid(_absorbers[index]):
			_absorbers.remove_at(index)


func _apply_density_visuals() -> void:
	var profile_color := _get_profile_color()
	outer_glow.color = Color(profile_color, 0.34)
	core.color = profile_color.lightened(0.22)
	orbit_dot.color = profile_color.lightened(0.4)
	glyph.modulate = profile_color.lightened(0.45)
	visual_root.scale = Vector2.ONE * _get_visual_scale()
	queue_redraw()


func _get_absorption_duration() -> float:
	if density_profile == null:
		return 0.45
	return maxf(density_profile.absorption_duration_seconds, 0.05)


func _get_visual_scale() -> float:
	if density_profile == null:
		return 0.72
	return maxf(density_profile.visual_scale, 0.1)


func _get_profile_color() -> Color:
	if density_profile == null:
		return Color("7dffd8")
	return density_profile.color
