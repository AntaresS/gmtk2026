class_name FantianSealProjectile
extends Node2D

signal impact_landed(strength: float)

## Time spent rising as a translucent high-altitude image.
@export_range(0.1, 3.0, 0.05) var ascent_duration: float = 0.65
## Fast descent duration before impact.
@export_range(0.05, 2.0, 0.05) var descent_duration: float = 0.22
## Maximum visual height above the target point.
@export_range(40.0, 500.0, 10.0) var maximum_height: float = 220.0
## Light camera-shake magnitude requested on impact.
@export_range(0.0, 20.0, 0.5) var camera_shake_strength: float = 4.0

var _damage: int = 1
var _radius: float = 84.0
var _is_critical: bool = false
var _elapsed: float = 0.0
var _impacted: bool = false
var _visual_height: float = 0.0
var _impact_flash: float = 0.0
var _target: EnemyController


func configure(
	target: EnemyController,
	damage: int,
	radius: float,
	is_critical: bool = false
) -> void:
	_target = target
	_damage = maxi(damage, 1)
	_radius = maxf(radius, 24.0)
	_is_critical = is_critical


func _physics_process(delta: float) -> void:
	if _impacted:
		_impact_flash -= delta
		queue_redraw()
		if _impact_flash <= 0.0:
			queue_free()
		return
	if is_instance_valid(_target) and _target.is_combat_active():
		global_position = _target.global_position
	_elapsed += delta
	if _elapsed <= ascent_duration:
		_visual_height = lerpf(
			0.0,
			maximum_height,
			clampf(_elapsed / maxf(ascent_duration, 0.01), 0.0, 1.0)
		)
	else:
		var descent_ratio := clampf(
			(_elapsed - ascent_duration) / maxf(descent_duration, 0.01),
			0.0,
			1.0
		)
		_visual_height = lerpf(maximum_height, 0.0, descent_ratio)
		if descent_ratio >= 1.0:
			_impact()
	queue_redraw()


func _impact() -> void:
	if _impacted:
		return
	_impacted = true
	_visual_height = 0.0
	_impact_flash = 0.22
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		if (
			not enemy.is_combat_active()
			or absf(enemy.global_position.x - global_position.x) > _radius
			or absf(enemy.global_position.y - global_position.y) > _radius
		):
			continue
		if enemy.is_elite_enemy():
			enemy.take_melee_damage(_damage, _is_critical)
		else:
			enemy.take_melee_damage(maxi(enemy.current_health, 1), _is_critical)
	impact_landed.emit(camera_shake_strength)


func _draw() -> void:
	var impact_square := Rect2(
		Vector2.ONE * -_radius,
		Vector2.ONE * _radius * 2.0
	)
	draw_rect(impact_square, Color(0.75, 0.38, 0.12, 0.08), true)
	draw_rect(impact_square, Color(1.0, 0.58, 0.16, 0.48), false, 2.0)
	if _impacted:
		draw_circle(
			Vector2.ZERO,
			_radius * (1.0 - _impact_flash),
			Color(1.0, 0.72, 0.22, _impact_flash * 2.4)
		)
		return
	var block_position := Vector2(0.0, -_visual_height)
	var alpha := lerpf(0.38, 0.95, 1.0 - _visual_height / maximum_height)
	draw_rect(
		Rect2(block_position - Vector2(24.0, 20.0), Vector2(48.0, 40.0)),
		Color(0.72, 0.3, 0.12, alpha),
		true
	)
	draw_rect(
		Rect2(block_position - Vector2(24.0, 20.0), Vector2(48.0, 40.0)),
		Color(1.0, 0.72, 0.28, alpha),
		false,
		4.0
	)
