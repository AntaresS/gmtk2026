class_name QiPickup
extends Area2D

signal qi_collected(amount: int)

## The single qi definition used for value, appearance, and generation chance.
@export var density_profile: QiDensityProfile = preload(
	"res://game/resources/qi_profile.tres"
)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_root: Node2D = $Visual
@onready var outer_glow: Polygon2D = $Visual/OuterGlow
@onready var core: Polygon2D = $Visual/Core
@onready var orbit_dot: Polygon2D = $Visual/OrbitDot
@onready var glyph: Label = $Visual/Glyph

var _animation_phase: float = 0.0
var _collected: bool = false
var _qi_value_override: int = -1


func _ready() -> void:
	_apply_density_visuals()


func _process(delta: float) -> void:
	_animation_phase = fmod(_animation_phase + delta, TAU)
	if _collected:
		return

	var pulse := (sin(_animation_phase * 4.0) + 1.0) * 0.5
	var activity_scale := 1.0 + 0.04 * pulse
	visual_root.scale = Vector2.ONE * _get_visual_scale() * activity_scale
	visual_root.position.y = sin(_animation_phase * 2.2) * 3.0
	visual_root.rotation = sin(_animation_phase * 1.3) * 0.08
	outer_glow.modulate.a = 0.55 + 0.2 * pulse


## Assigns the shared qi definition to a freshly generated pickup.
func configure_density(profile: QiDensityProfile) -> void:
	if profile == null:
		return
	density_profile = profile
	if is_node_ready():
		_apply_density_visuals()


## Overrides the shared qi amount for enemy drops without mutating the shared
## profile used by generated world pickups.
func configure_value(amount: int) -> void:
	_qi_value_override = maxi(amount, 0)


func get_qi_value() -> int:
	if _qi_value_override >= 0:
		return _qi_value_override
	if density_profile == null:
		return 10
	return maxi(density_profile.qi_value, 0)


## Pulls this pickup toward the player while it remains inside the player's
## invisible collectible-attraction radius.
func attract_to_player(
	player: PlayerController,
	speed: float,
	delta: float
) -> void:
	if _collected or not is_instance_valid(player):
		return
	global_position = global_position.move_toward(
		player.global_position,
		maxf(speed, 1.0) * delta
	)


## Prevents a recycled chunk's stale pickup from completing while it is being
## detached and safely queued for deletion.
func disable_collection() -> void:
	if _collected:
		return
	_collected = true
	_disable_collisions()


func _on_player_body_entered(body: Node2D) -> void:
	if _collected or body is not PlayerController:
		return
	_complete_collection()


func _complete_collection() -> void:
	if _collected:
		return
	_collected = true
	_disable_collisions()
	qi_collected.emit(get_qi_value())

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


func _apply_density_visuals() -> void:
	var profile_color := _get_profile_color()
	outer_glow.color = Color(profile_color, 0.34)
	core.color = profile_color.lightened(0.22)
	orbit_dot.color = profile_color.lightened(0.4)
	glyph.modulate = profile_color.lightened(0.45)
	visual_root.scale = Vector2.ONE * _get_visual_scale()
	queue_redraw()


func _get_visual_scale() -> float:
	if density_profile == null:
		return 0.72
	return maxf(density_profile.visual_scale, 0.1)


func _get_profile_color() -> Color:
	if density_profile == null:
		return Color("7dffd8")
	return density_profile.color
