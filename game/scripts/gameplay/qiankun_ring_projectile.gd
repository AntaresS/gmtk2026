class_name QiankunRingProjectile
extends Area2D

signal returned_to_player
signal enemy_hit(enemy: EnemyController)

## Outbound and bounce travel speed in world pixels per second.
@export var travel_speed: float = 760.0
## Homing speed in world pixels per second after the final bounce.
@export var return_speed: float = 920.0
## Maximum lifetime in seconds before a lost ring is safely removed.
@export_range(1.0, 20.0, 0.5) var maximum_lifetime: float = 8.0
## Damage multiplier applied once for every completed enemy bounce. A value of
## 1.2 makes successive hits deal 100%, 120%, 144%, and so on.
@export_range(1.0, 2.0, 0.05) var bounce_damage_multiplier: float = 1.2

var _player: PlayerController
var _target: EnemyController
var _damage: int = 1
var _remaining_bounces: int = 0
var _bounce_search_range: float = 210.0
var _returning: bool = false
var _finished: bool = false
var _lifetime_remaining: float = 8.0
var _last_hit_enemy_id: int = 0
var _successful_hit_count: int = 0
var _aoe_radius: float = 0.0
var _projectile_speed_multiplier: float = 1.0
var _is_critical: bool = false


## Launches the ring at one enemy. `bounce_count` counts extra enemy hits
## before it changes to the returning state.
func configure(
	player: PlayerController,
	initial_target: EnemyController,
	damage: int,
	bounce_count: int,
	bounce_search_range: float,
	aoe_radius: float = 0.0,
	projectile_speed_multiplier: float = 1.0,
	is_critical: bool = false
) -> void:
	_player = player
	_target = initial_target
	_damage = maxi(damage, 1)
	_remaining_bounces = maxi(bounce_count, 0)
	_bounce_search_range = maxf(bounce_search_range, 1.0)
	_aoe_radius = maxf(aoe_radius, 0.0)
	_projectile_speed_multiplier = maxf(
		projectile_speed_multiplier,
		0.01
	)
	_is_critical = is_critical
	_lifetime_remaining = maxf(maximum_lifetime, 1.0)


func _physics_process(delta: float) -> void:
	if _finished:
		return
	_lifetime_remaining -= delta
	rotation += delta * 11.0
	if _lifetime_remaining <= 0.0 or not is_instance_valid(_player):
		_finish_return()
		return
	if _returning:
		_move_back_to_player(delta)
		return
	if not is_instance_valid(_target) or not _target.is_combat_active():
		_select_next_target_or_return()
		return
	_move_toward_enemy(delta)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.3, 0.82, 0.14))
	draw_arc(
		Vector2.ZERO,
		11.0,
		0.0,
		TAU,
		40,
		Color("ff8ee7"),
		5.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		6.0,
		0.0,
		TAU,
		32,
		Color("ffe9a8"),
		2.0,
		true
	)
	for spark_index in 4:
		var spark_angle := float(spark_index) / 4.0 * TAU
		draw_circle(
			Vector2.from_angle(spark_angle) * 14.0,
			2.2,
			Color.WHITE
		)


func _move_toward_enemy(delta: float) -> void:
	var step_distance := (
		maxf(travel_speed, 1.0) * _projectile_speed_multiplier * delta
	)
	var next_position := global_position.move_toward(
		_target.global_position,
		step_distance
	)
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		next_position,
		8
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit["collider"] is EnemyController:
		var hit_enemy := hit["collider"] as EnemyController
		if hit_enemy.get_instance_id() == _last_hit_enemy_id:
			# Continue out of the previous target's body instead of repeatedly
			# ray-hitting it at the start of the next bounce.
			global_position = next_position
			return
		global_position = hit["position"]
		_hit_enemy(hit_enemy)
		return
	global_position = next_position
	if global_position.distance_to(_target.global_position) <= 18.0:
		_hit_enemy(_target)


func _move_back_to_player(delta: float) -> void:
	global_position = global_position.move_toward(
		_player.global_position,
		maxf(return_speed, 1.0) * _projectile_speed_multiplier * delta
	)
	if global_position.distance_to(_player.global_position) <= 18.0:
		_finish_return()


func _hit_enemy(enemy: EnemyController) -> void:
	if (
		_finished
		or _returning
		or not is_instance_valid(enemy)
		or not enemy.is_combat_active()
	):
		return
	var enemy_id := enemy.get_instance_id()
	if enemy_id == _last_hit_enemy_id:
		return
	_last_hit_enemy_id = enemy_id
	var scaled_damage := maxi(
		roundi(
			float(_damage)
				* pow(
					maxf(bounce_damage_multiplier, 1.0),
					float(_successful_hit_count)
				)
		),
		1
	)
	_successful_hit_count += 1
	enemy.take_melee_damage(scaled_damage, _is_critical)
	_apply_aoe_damage(enemy, scaled_damage)
	enemy_hit.emit(enemy)
	if _remaining_bounces <= 0:
		_begin_return()
		return
	var next_target := _find_nearest_bounce_enemy()
	if next_target == null:
		_begin_return()
		return
	_remaining_bounces -= 1
	_target = next_target


func _apply_aoe_damage(primary_enemy: EnemyController, damage: int) -> void:
	if _aoe_radius <= 0.0:
		return
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		if (
			enemy == primary_enemy
			or not enemy.is_combat_active()
			or enemy.global_position.distance_to(global_position) > _aoe_radius
		):
			continue
		enemy.take_melee_damage(damage, _is_critical)


func _select_next_target_or_return() -> void:
	var next_target := _find_nearest_bounce_enemy()
	if next_target == null or _remaining_bounces <= 0:
		_begin_return()
		return
	_remaining_bounces -= 1
	_target = next_target


## Selects any active enemy except the one just hit. Older targets remain
## eligible, allowing the ring to alternate A-B-A-B up to its bounce cap.
func _find_nearest_bounce_enemy() -> EnemyController:
	var nearest_enemy: EnemyController = null
	var nearest_distance_squared := INF
	var maximum_distance_squared := _bounce_search_range * _bounce_search_range
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		if (
			not enemy.is_combat_active()
			or enemy.get_instance_id() == _last_hit_enemy_id
		):
			continue
		var distance_squared := global_position.distance_squared_to(
			enemy.global_position
		)
		if (
			distance_squared <= maximum_distance_squared
			and distance_squared < nearest_distance_squared
		):
			nearest_distance_squared = distance_squared
			nearest_enemy = enemy
	return nearest_enemy


func _begin_return() -> void:
	_returning = true
	_target = null
	collision_mask = 0


func _finish_return() -> void:
	if _finished:
		return
	_finished = true
	returned_to_player.emit()
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is EnemyController:
		_hit_enemy(body as EnemyController)
