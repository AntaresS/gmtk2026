class_name FlyingSwordProjectile
extends Area2D

## Straight-line travel speed in world pixels per second.
@export var travel_speed: float = 2200.0
## Energy available at launch. Each distinct enemy pierced consumes energy.
@export_range(0.1, 100.0, 0.1) var initial_energy: float = 3.0
## Energy consumed after damaging one distinct enemy.
@export_range(0.1, 100.0, 0.1) var energy_cost_per_hit: float = 1.0
## Maximum travel distance as a multiple of the weapon's resolved attack range.
@export_range(1.0, 10.0, 0.1) var maximum_range_multiplier: float = 2.0

var _direction: Vector2 = Vector2.UP
var _damage: int = 1
var _maximum_distance: float = 240.0
var _distance_traveled: float = 0.0
var _is_critical: bool = false
var _energy: float = 3.0
var _hit_enemy_ids: Dictionary = {}


func _physics_process(delta: float) -> void:
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
		_hit_enemy(hit["collider"] as EnemyController)
		if _energy <= 0.0:
			return
	global_position = next_position
	_distance_traveled += step.length()
	if _distance_traveled >= _maximum_distance:
		queue_free()


func _draw() -> void:
	var energy_ratio := clampf(
		_energy / maxf(initial_energy, 0.1),
		0.0,
		1.0
	)
	draw_line(
		Vector2(-52.0, 0.0),
		Vector2(18.0, 0.0),
		Color(0.2, 0.72, 1.0, 0.06 + energy_ratio * 0.18),
		14.0
	)
	draw_line(
		Vector2(-42.0, 0.0),
		Vector2(20.0, 0.0),
		Color(0.52, 0.92, 1.0, 0.18 + energy_ratio * 0.72),
		6.0
	)
	draw_line(
		Vector2(-18.0, 0.0),
		Vector2(22.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.28 + energy_ratio * 0.72),
		2.5
	)
	draw_circle(
		Vector2(22.0, 0.0),
		3.0,
		Color(1.0, 1.0, 1.0, 0.28 + energy_ratio * 0.72)
	)


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
	_maximum_distance = (
		maxf(maximum_distance, 1.0)
		* maxf(maximum_range_multiplier, 1.0)
	)
	travel_speed *= maxf(speed_multiplier, 0.01)
	_is_critical = is_critical
	_energy = maxf(initial_energy, 0.1)
	rotation = _direction.angle()
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is not EnemyController:
		return
	var enemy := body as EnemyController
	if not enemy.is_combat_active():
		return
	_hit_enemy(enemy)


func _hit_enemy(enemy: EnemyController) -> void:
	if not enemy.is_combat_active():
		return
	var enemy_id := enemy.get_instance_id()
	if _hit_enemy_ids.has(enemy_id):
		return
	_hit_enemy_ids[enemy_id] = true
	enemy.take_melee_damage(_damage, _is_critical)
	_energy = maxf(_energy - maxf(energy_cost_per_hit, 0.1), 0.0)
	queue_redraw()
	if _energy <= 0.0:
		queue_free()


## Returns remaining piercing energy for gameplay tests and debug panels.
func get_remaining_energy() -> float:
	return _energy
