class_name QiankunRingProjectile
extends Area2D

signal returned_to_player
signal enemy_hit(enemy: EnemyController)

const TRAIL_MAXIMUM_POINTS: int = 10
const TRAIL_SAMPLE_DISTANCE: float = 18.0
const HIT_AFTERIMAGE_DURATION: float = 0.2
const HIT_AFTERIMAGE_START_SCALE: float = 0.043
const HIT_AFTERIMAGE_END_SCALE: float = 0.11

## Outbound and bounce travel speed in world pixels per second.
@export var travel_speed: float = 760.0
## Homing speed in world pixels per second after the final bounce.
@export var return_speed: float = 920.0
## Maximum lifetime in seconds before a lost ring is safely removed.
@export_range(1.0, 20.0, 0.5) var maximum_lifetime: float = 8.0

@onready var trail_glow: Line2D = $TrailGlow
@onready var trail_core: Line2D = $TrailCore
@onready var hit_afterimages: Array[Sprite2D] = [
	$HitAfterimage1,
	$HitAfterimage2,
	$HitAfterimage3,
	$HitAfterimage4,
]

var _player: PlayerController
var _target: EnemyController
var _damage: int = 1
var _remaining_bounces: int = 0
var _bounce_search_range: float = 210.0
var _returning: bool = false
var _finished: bool = false
var _lifetime_remaining: float = 8.0
var _last_hit_enemy_id: int = 0
var _aoe_radius: float = 0.0
var _projectile_speed_multiplier: float = 1.0
var _is_critical: bool = false
var _trail_world_points := PackedVector2Array()
var _last_trail_sample_position := Vector2.ZERO
var _hit_afterimage_ages := PackedFloat32Array()
var _next_hit_afterimage_index: int = 0


func _ready() -> void:
	# Trail geometry is kept in world space so the spinning projectile never
	# rotates old trail points. Both lines share the same small point array.
	for trail in [trail_glow, trail_core]:
		trail.set_as_top_level(true)
		trail.global_transform = Transform2D.IDENTITY
	_hit_afterimage_ages.resize(hit_afterimages.size())
	for afterimage_index in hit_afterimages.size():
		var afterimage := hit_afterimages[afterimage_index]
		afterimage.set_as_top_level(true)
		afterimage.hide()
		_hit_afterimage_ages[afterimage_index] = HIT_AFTERIMAGE_DURATION


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
	_update_hit_afterimages(delta)
	_lifetime_remaining -= delta
	rotation += delta * 11.0
	if _lifetime_remaining <= 0.0 or not is_instance_valid(_player):
		_finish_return()
		return
	if _returning:
		_move_back_to_player(delta)
		_update_trail()
		return
	if not is_instance_valid(_target) or not _target.is_combat_active():
		_select_next_target_or_return()
		_update_trail()
		return
	_move_toward_enemy(delta)
	_update_trail()


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
	var return_position := _player.get_combat_anchor_position()
	global_position = global_position.move_toward(
		return_position,
		maxf(return_speed, 1.0) * _projectile_speed_multiplier * delta
	)
	if global_position.distance_to(return_position) <= 18.0:
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
	_spawn_hit_afterimage(enemy.global_position)
	enemy.take_melee_damage(_damage, _is_critical, &"qiankun_ring")
	_apply_aoe_damage(enemy, _damage)
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


func _update_trail() -> void:
	var current_position := global_position
	if _trail_world_points.is_empty():
		_trail_world_points.append(current_position)
		_trail_world_points.append(current_position)
		_last_trail_sample_position = current_position
	elif (
		current_position.distance_squared_to(
			_last_trail_sample_position
		)
		>= TRAIL_SAMPLE_DISTANCE * TRAIL_SAMPLE_DISTANCE
	):
		_trail_world_points.append(current_position)
		_last_trail_sample_position = current_position
		while _trail_world_points.size() > TRAIL_MAXIMUM_POINTS:
			_trail_world_points.remove_at(0)
	else:
		_trail_world_points[
			_trail_world_points.size() - 1
		] = current_position
	trail_glow.points = _trail_world_points
	trail_core.points = _trail_world_points


func _spawn_hit_afterimage(hit_position: Vector2) -> void:
	if hit_afterimages.is_empty():
		return
	var afterimage_index := (
		_next_hit_afterimage_index % hit_afterimages.size()
	)
	_next_hit_afterimage_index = (
		afterimage_index + 1
	) % hit_afterimages.size()
	var afterimage := hit_afterimages[afterimage_index]
	afterimage.global_position = hit_position
	afterimage.global_rotation = rotation
	afterimage.scale = Vector2.ONE * HIT_AFTERIMAGE_START_SCALE
	afterimage.self_modulate = Color(1.0, 0.82, 0.34, 0.9)
	afterimage.show()
	_hit_afterimage_ages[afterimage_index] = 0.0


func _update_hit_afterimages(delta: float) -> void:
	for afterimage_index in hit_afterimages.size():
		var age := (
			_hit_afterimage_ages[afterimage_index]
			+ maxf(delta, 0.0)
		)
		_hit_afterimage_ages[afterimage_index] = age
		var afterimage := hit_afterimages[afterimage_index]
		if age >= HIT_AFTERIMAGE_DURATION:
			afterimage.hide()
			continue
		var progress := age / HIT_AFTERIMAGE_DURATION
		var expansion := 1.0 - pow(1.0 - progress, 3.0)
		var current_scale := lerpf(
			HIT_AFTERIMAGE_START_SCALE,
			HIT_AFTERIMAGE_END_SCALE,
			expansion
		)
		afterimage.scale = Vector2.ONE * current_scale
		afterimage.rotation += delta * 4.0
		afterimage.self_modulate.a = pow(1.0 - progress, 2.0) * 0.9


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
		enemy.take_melee_damage(damage, _is_critical, &"qiankun_ring")


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
