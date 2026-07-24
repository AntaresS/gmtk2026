class_name FlyingSwordProjectile
extends Area2D

## Straight-line travel speed in world pixels per second.
@export var travel_speed: float = 2200.0

var _direction: Vector2 = Vector2.UP
var _damage: int = 1
var _maximum_distance: float = 240.0
var _distance_traveled: float = 0.0
var _spent: bool = false
var _is_critical: bool = false


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var step := _direction * maxf(travel_speed, 1.0) * delta
	var next_position := global_position + step
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		next_position,
		8
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit["collider"] is EnemyController:
		global_position = hit["position"]
		_hit_enemy(hit["collider"] as EnemyController)
		return
	global_position = next_position
	_distance_traveled += step.length()
	if _distance_traveled >= _maximum_distance:
		queue_free()


func _draw() -> void:
	draw_line(
		Vector2(-52.0, 0.0),
		Vector2(18.0, 0.0),
		Color(0.2, 0.72, 1.0, 0.18),
		14.0
	)
	draw_line(
		Vector2(-42.0, 0.0),
		Vector2(20.0, 0.0),
		Color(0.52, 0.92, 1.0, 0.7),
		6.0
	)
	draw_line(Vector2(-18.0, 0.0), Vector2(22.0, 0.0), Color.WHITE, 2.5)
	draw_circle(Vector2(22.0, 0.0), 3.0, Color.WHITE)


## Initializes one straight flying-sword attack with final cultivation-adjusted
## delivery stats supplied by PlayerController's centralized stat pipeline.
func configure(
	direction: Vector2,
	damage: int,
	maximum_distance: float,
	speed_multiplier: float = 1.0,
	is_critical: bool = false
) -> void:
	_direction = direction.normalized()
	_damage = maxi(damage, 1)
	_maximum_distance = maxf(maximum_distance, 1.0)
	travel_speed *= maxf(speed_multiplier, 0.01)
	_is_critical = is_critical
	rotation = _direction.angle()


func _on_body_entered(body: Node2D) -> void:
	if _spent or body is not EnemyController:
		return
	var enemy := body as EnemyController
	if not enemy.is_combat_active():
		return
	_hit_enemy(enemy)


func _hit_enemy(enemy: EnemyController) -> void:
	if _spent or not enemy.is_combat_active():
		return
	enemy.take_melee_damage(_damage, _is_critical)
	_spent = true
	collision_layer = 0
	collision_mask = 0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.5, 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)
