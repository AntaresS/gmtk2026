class_name ThunderCloudProjectile
extends Node2D

## Seconds the cloud remains active.
@export_range(0.5, 20.0, 0.1) var lifetime: float = 4.0
## Seconds between repeated damage pulses.
@export_range(0.05, 2.0, 0.05) var damage_interval: float = 0.4
## Slow forward drift speed in world pixels per second.
@export_range(0.0, 500.0, 5.0) var drift_speed: float = 70.0

var _direction: Vector2 = Vector2.UP
var _inherited_velocity: Vector2 = Vector2.ZERO
var _damage: int = 1
var _radius: float = 72.0
var _remaining: float = 4.0
var _damage_timer: float = 0.0
var _is_critical: bool = false
var _visual_time: float = 0.0


func configure(
	direction: Vector2,
	damage: int,
	radius: float,
	is_critical: bool = false,
	inherited_velocity: Vector2 = Vector2.ZERO
) -> void:
	_direction = direction.normalized()
	if _direction.is_zero_approx():
		_direction = Vector2.UP
	_inherited_velocity = inherited_velocity
	_damage = maxi(damage, 1)
	_radius = maxf(radius, 24.0)
	_is_critical = is_critical
	_remaining = maxf(lifetime, 0.1)
	_damage_timer = 0.0


func _physics_process(delta: float) -> void:
	_remaining -= delta
	_visual_time = fmod(_visual_time + delta, TAU)
	global_position += (
		_inherited_velocity + _direction * drift_speed
	) * delta
	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = maxf(damage_interval, 0.05)
		_damage_enemies_in_cloud()
	queue_redraw()
	if _remaining <= 0.0:
		queue_free()


func _damage_enemies_in_cloud() -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		if (
			enemy.is_combat_active()
			and enemy.global_position.distance_to(global_position) <= _radius
		):
			enemy.take_melee_damage(_damage, _is_critical)


func _draw() -> void:
	var fade := clampf(_remaining / minf(maxf(lifetime, 0.1), 0.8), 0.0, 1.0)
	draw_circle(Vector2.ZERO, _radius, Color(0.22, 0.2, 0.35, 0.13 * fade))
	for cloud_index in 7:
		var angle := float(cloud_index) / 7.0 * TAU + _visual_time * 0.12
		var position := Vector2.from_angle(angle) * _radius * 0.38
		draw_circle(
			position,
			_radius * (0.28 + float(cloud_index % 3) * 0.035),
			Color(0.28, 0.3, 0.42, 0.72 * fade)
		)
	for bolt_index in 3:
		var x := sin(_visual_time * 5.0 + float(bolt_index) * 2.1) * _radius * 0.55
		draw_polyline(
			PackedVector2Array([
				Vector2(x, -18.0),
				Vector2(x + 8.0, 0.0),
				Vector2(x - 4.0, 18.0),
				Vector2(x + 5.0, 34.0),
			]),
			Color(0.72, 0.9, 1.0, 0.9 * fade),
			3.0,
			true
		)
