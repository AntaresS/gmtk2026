class_name FantianSealProjectile
extends Node2D

signal impact_landed(strength: float)
signal shadow_contract_finished

## Time used to contract the weapon-range shadow into the locked damage area.
@export_range(0.05, 1.0, 0.01) var shadow_contract_duration: float = 0.3
## Fast descent duration before impact.
@export_range(0.05, 1.0, 0.01) var descent_duration: float = 0.18
## Visual height above the locked damage area at the start of descent.
@export_range(80.0, 600.0, 10.0) var maximum_height: float = 280.0
## Brief impact hold before the landed stamp begins dissolving behind actors.
@export_range(0.0, 2.0, 0.01) var landed_hold_duration: float = 0.08
## Fade duration after the landed hold completes.
@export_range(0.05, 1.0, 0.01) var landed_fade_duration: float = 0.14
## Light camera-shake magnitude requested on impact.
@export_range(0.0, 20.0, 0.5) var camera_shake_strength: float = 4.0

const SEAL_VISIBLE_WIDTH_PIXELS: float = 715.0
const SHADOW_LIGHT_COLOR: Color = Color(0.055, 0.09, 0.055, 0.055)
const SHADOW_DARK_COLOR: Color = Color(0.025, 0.04, 0.025, 0.42)
const SHADOW_EDGE_COLOR: Color = Color(0.46, 0.78, 0.52, 0.58)
const IMPACT_WARNING_FILL_COLOR: Color = Color(0.025, 0.04, 0.025, 0.24)
const IMPACT_WARNING_EDGE_COLOR: Color = Color(0.74, 0.96, 0.66, 0.86)
const FANTIAN_SEAL_IMMOBILIZE_DURATION: float = 0.3
const FANTIAN_SEAL_HEALTH_READOUT_DURATION: float = 0.75
const FALLING_SEAL_Z_INDEX: int = 20
const LANDED_SEAL_Z_INDEX: int = 3

@onready var seal_sprite: Sprite2D = $SealSprite

var _damage: int = 1
var _radius: float = 84.0
var _is_critical: bool = false
var _elapsed: float = 0.0
var _impacted: bool = false
var _shadow_contract_emitted: bool = false
var _attack_range: float = 84.0
var _attack_origin_global_position: Vector2 = Vector2.ZERO
var _target: EnemyController
var _volley_id: int = -1


func configure(
	target: EnemyController,
	damage: int,
	radius: float,
	is_critical: bool = false,
	attack_origin_global_position: Vector2 = Vector2.ZERO,
	attack_range: float = 0.0,
	volley_id: int = -1
) -> void:
	_target = target
	_damage = maxi(damage, 1)
	_radius = maxf(radius, 24.0)
	_is_critical = is_critical
	_attack_origin_global_position = (
		attack_origin_global_position
		if attack_range > 0.0
		else global_position
	)
	_attack_range = maxf(attack_range, _radius)
	_volley_id = volley_id
	seal_sprite.z_as_relative = false
	seal_sprite.z_index = FALLING_SEAL_Z_INDEX
	var impact_scale := (
		_radius * 2.0 / SEAL_VISIBLE_WIDTH_PIXELS
	)
	seal_sprite.scale = Vector2.ONE * impact_scale
	seal_sprite.position = Vector2(0.0, -maximum_height)
	seal_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _impacted:
		_update_landed_visual()
		queue_redraw()
		return
	if is_instance_valid(_target) and _target.is_combat_active():
		global_position = _target.global_position
	if _elapsed <= shadow_contract_duration:
		seal_sprite.position = Vector2(0.0, -maximum_height)
		seal_sprite.modulate = Color.TRANSPARENT
	else:
		_emit_shadow_contract_finished()
		var descent_progress := clampf(
			(_elapsed - shadow_contract_duration)
				/ maxf(descent_duration, 0.01),
			0.0,
			1.0
		)
		var descent_eased := descent_progress * descent_progress
		seal_sprite.position = Vector2(
			0.0,
			lerpf(-maximum_height, 0.0, descent_eased)
		)
		seal_sprite.modulate = Color(
			1.0,
			1.0,
			1.0,
			lerpf(0.56, 1.0, descent_progress)
		)
		if descent_progress >= 1.0:
			_impact()
	queue_redraw()


func _update_landed_visual() -> void:
	seal_sprite.position = Vector2.ZERO
	if _elapsed <= landed_hold_duration:
		seal_sprite.modulate = Color.WHITE
		return
	var fade_progress := clampf(
		(_elapsed - landed_hold_duration)
			/ maxf(landed_fade_duration, 0.01),
		0.0,
		1.0
	)
	seal_sprite.modulate = Color(
		1.0,
		1.0,
		1.0,
		1.0 - fade_progress
	)
	if fade_progress >= 1.0:
		queue_free()


func _impact() -> void:
	if _impacted:
		return
	_impacted = true
	_elapsed = 0.0
	seal_sprite.position = Vector2.ZERO
	seal_sprite.modulate = Color.WHITE
	seal_sprite.z_index = LANDED_SEAL_Z_INDEX
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		if (
			not enemy.is_combat_active()
			or not _does_enemy_overlap_impact(enemy)
		):
			continue
		enemy.take_melee_damage(_damage, _is_critical, &"fantian_seal")
		if enemy.is_combat_active():
			enemy.show_temporary_health_readout(
				FANTIAN_SEAL_HEALTH_READOUT_DURATION
			)
			enemy.apply_fantian_seal_immobilize(
				FANTIAN_SEAL_IMMOBILIZE_DURATION,
				_volley_id
			)
	impact_landed.emit(camera_shake_strength)


## Returns whether the enemy's collision body overlaps the visible square,
## including edge contacts where the enemy center remains outside the footprint.
func _does_enemy_overlap_impact(enemy: EnemyController) -> bool:
	var impact_rect := Rect2(
		global_position - Vector2.ONE * _radius,
		Vector2.ONE * _radius * 2.0
	)
	var collision_shape := enemy.get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return impact_rect.has_point(enemy.global_position)
	if collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		var circle_radius := circle.radius * maxf(
			absf(collision_shape.global_scale.x),
			absf(collision_shape.global_scale.y)
		)
		var circle_center := collision_shape.global_position
		var closest_point := Vector2(
			clampf(circle_center.x, impact_rect.position.x, impact_rect.end.x),
			clampf(circle_center.y, impact_rect.position.y, impact_rect.end.y)
		)
		return (
			circle_center.distance_squared_to(closest_point)
			<= circle_radius * circle_radius
		)
	if collision_shape.shape is RectangleShape2D:
		var rectangle := collision_shape.shape as RectangleShape2D
		var half_size := rectangle.size * 0.5
		var corners := [
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		]
		var first_corner: Vector2 = collision_shape.global_transform * corners[0]
		var minimum := first_corner
		var maximum := first_corner
		for corner in corners.slice(1):
			var world_corner: Vector2 = collision_shape.global_transform * corner
			minimum = minimum.min(world_corner)
			maximum = maximum.max(world_corner)
		var enemy_rect := Rect2(minimum, maximum - minimum)
		return (
			enemy_rect.position.x <= impact_rect.end.x
			and enemy_rect.end.x >= impact_rect.position.x
			and enemy_rect.position.y <= impact_rect.end.y
			and enemy_rect.end.y >= impact_rect.position.y
		)
	return impact_rect.has_point(collision_shape.global_position)


func _emit_shadow_contract_finished() -> void:
	if _shadow_contract_emitted:
		return
	_shadow_contract_emitted = true
	shadow_contract_finished.emit()


func _draw() -> void:
	var shadow_alpha := 1.0
	if _impacted and _elapsed > landed_hold_duration:
		shadow_alpha = 1.0 - clampf(
			(_elapsed - landed_hold_duration)
				/ maxf(landed_fade_duration, 0.01),
			0.0,
			1.0
		)
	var shadow_center := Vector2.ZERO
	var shadow_half_extent := _radius
	var shadow_color := SHADOW_DARK_COLOR
	if not _impacted:
		var contract_progress := clampf(
			_elapsed / maxf(shadow_contract_duration, 0.01),
			0.0,
			1.0
		)
		var contract_eased := (
			contract_progress
			* contract_progress
			* (3.0 - 2.0 * contract_progress)
		)
		var attack_origin_local := to_local(
			_attack_origin_global_position
		)
		shadow_center = attack_origin_local.lerp(
			Vector2.ZERO,
			contract_eased
		)
		shadow_half_extent = lerpf(
			_attack_range,
			_radius,
			contract_eased
		)
		shadow_color = SHADOW_LIGHT_COLOR.lerp(
			SHADOW_DARK_COLOR,
			contract_eased
		)
	var shadow_rect := Rect2(
		shadow_center - Vector2.ONE * shadow_half_extent,
		Vector2.ONE * shadow_half_extent * 2.0
	)
	draw_rect(
		shadow_rect,
		Color(shadow_color, shadow_color.a * shadow_alpha),
		true
	)
	draw_rect(
		shadow_rect,
		Color(SHADOW_EDGE_COLOR, SHADOW_EDGE_COLOR.a * shadow_alpha),
		false,
		2.0
	)
	if not _impacted:
		var impact_rect := Rect2(
			Vector2.ONE * -_radius,
			Vector2.ONE * _radius * 2.0
		)
		draw_rect(impact_rect, IMPACT_WARNING_FILL_COLOR, true)
		draw_rect(impact_rect, IMPACT_WARNING_EDGE_COLOR, false, 3.0)
