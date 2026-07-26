class_name EnemyFlyingSwordProjectile
extends Node2D

const OUTLINE_SHADER: Shader = preload(
	"res://game/shaders/flying_sword_readiness.gdshader"
)
const PURPLE_OUTLINE_COLOR: Color = Color("d873ff")
const PURPLE_GLOW_COLOR: Color = Color("a43cff")
const ELITE_TRAIL_COLOR: Color = Color("8f102f")
const OUTLINE_TEXTURE_WIDTH: float = 0.742188
const GLOW_TEXTURE_WIDTH: float = 2.152344

## Radius, in world pixels, used to resolve a sword crossing its locked target.
## This script performs a swept segment check so fast elite swords cannot skip
## the visible player body between physics frames.
@export_range(4.0, 48.0, 1.0) var hit_radius: float = 20.0
## Maximum lifetime in seconds. This bounds swords whose locked target becomes
## invalid or moves away from the straight launch path.
@export_range(0.2, 4.0, 0.05) var maximum_lifetime: float = 1.4

@onready var sword_sprite: Sprite2D = $SwordSprite
@onready var trail_sprites: Array[Sprite2D] = [
	$Trail1,
	$Trail2,
	$Trail3,
]

var _direction: Vector2 = Vector2.DOWN
var _travel_speed: float = 900.0
var _damage: float = 1.0
var _maximum_distance: float = 600.0
var _distance_traveled: float = 0.0
var _elapsed: float = 0.0
var _source_enemy: Node2D
var _target: Node2D
var _is_elite: bool = false


func _ready() -> void:
	add_to_group("enemy_flying_sword_projectiles")
	_refresh_presentation()


func _refresh_presentation() -> void:
	var outline_material := ShaderMaterial.new()
	outline_material.shader = OUTLINE_SHADER
	outline_material.set_shader_parameter(
		&"outline_color",
		PURPLE_OUTLINE_COLOR
	)
	outline_material.set_shader_parameter(
		&"outline_width",
		OUTLINE_TEXTURE_WIDTH
	)
	outline_material.set_shader_parameter(&"glow_color", PURPLE_GLOW_COLOR)
	outline_material.set_shader_parameter(&"glow_width", GLOW_TEXTURE_WIDTH)
	outline_material.set_shader_parameter(&"glow_strength", 0.22)
	outline_material.set_shader_parameter(&"readiness_strength", 1.0)
	outline_material.set_shader_parameter(&"warning_energy", 0.0)
	sword_sprite.material = outline_material
	for trail_index in trail_sprites.size():
		var trail := trail_sprites[trail_index]
		trail.visible = _is_elite
		trail.position = Vector2(-18.0 * float(trail_index + 1), 0.0)
		trail.self_modulate = Color(
			ELITE_TRAIL_COLOR,
			0.34 / float(trail_index + 1)
		)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= maxf(maximum_lifetime, 0.2):
		queue_free()
		return
	var step := _direction * maxf(_travel_speed, 1.0) * delta
	var next_position := global_position + step
	if _crosses_locked_target(global_position, next_position):
		_apply_locked_target_hit()
		return
	global_position = next_position
	_distance_traveled += step.length()
	if _distance_traveled >= _maximum_distance:
		queue_free()


## Launches one straight enemy sword at a snapshotted direction while retaining
## the locked target only for swept hit detection. Elite swords travel faster
## and expose three restrained dark-red afterimages.
func configure(
	source_enemy: Node2D,
	target: Node2D,
	direction: Vector2,
	damage: float,
	travel_speed: float,
	maximum_distance: float,
	elite: bool
) -> void:
	_source_enemy = source_enemy
	_target = target
	_direction = direction.normalized()
	if _direction.is_zero_approx():
		_direction = Vector2.DOWN
	_damage = maxf(damage, 0.1)
	_travel_speed = maxf(travel_speed, 1.0)
	_maximum_distance = maxf(maximum_distance, 1.0)
	_is_elite = elite
	rotation = _direction.angle()
	if is_node_ready():
		_refresh_presentation()


func _crosses_locked_target(
	segment_start: Vector2,
	segment_end: Vector2
) -> bool:
	if not is_instance_valid(_target):
		return false
	var target_position := _get_target_combat_position()
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return segment_start.distance_to(target_position) <= hit_radius
	var target_fraction := clampf(
		(target_position - segment_start).dot(segment)
			/ segment_length_squared,
		0.0,
		1.0
	)
	var closest_point := segment_start + segment * target_fraction
	return closest_point.distance_to(target_position) <= hit_radius


func _get_target_combat_position() -> Vector2:
	if _target.has_method("get_combat_anchor_position"):
		return _target.call("get_combat_anchor_position") as Vector2
	return _target.global_position


func _apply_locked_target_hit() -> void:
	if not is_instance_valid(_target):
		queue_free()
		return
	if _target.has_method("take_enemy_projectile_damage"):
		_target.call(
			"take_enemy_projectile_damage",
			_damage,
			_source_enemy
		)
	elif _target.has_method("take_enemy_damage"):
		_target.call("take_enemy_damage", _damage, _source_enemy)
	queue_free()


## Returns whether this projectile is presenting the elite-only afterimages.
func has_elite_afterimages() -> bool:
	return (
		_is_elite
		and not trail_sprites.is_empty()
		and trail_sprites.all(
			func(trail: Sprite2D) -> bool: return trail.visible
		)
	)


## Returns the configured straight-line speed for combat presentation tests.
func get_travel_speed() -> float:
	return _travel_speed
