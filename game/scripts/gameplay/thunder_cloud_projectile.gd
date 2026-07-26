class_name ThunderCloudProjectile
extends Area2D

## Seconds the cloud remains visible before cleanup. Damage stops after
## maximum_damage_pulses even when the final visual fade is still active.
@export_range(0.5, 20.0, 0.1) var lifetime: float = 2.4
## Seconds between repeated damage pulses. Attack-speed bonuses never modify
## this interval, preserving readable and deterministic lightning timing.
@export_range(0.05, 2.0, 0.05) var damage_interval: float = 0.4
## Exact number of damaging strikes emitted by one cloud during its lifetime.
@export_range(1, 30, 1) var maximum_damage_pulses: int = 6
## Independent aimed travel speed in world pixels per second before the shared
## projectile-speed multiplier. Forward player travel is compensated separately.
@export_range(0.0, 600.0, 5.0) var aim_travel_speed: float = 160.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _direction: Vector2 = Vector2.UP
var _motion_anchor: Node2D
var _last_anchor_position: Vector2 = Vector2.ZERO
var _projectile_speed_multiplier: float = 1.0
var _exact_damage: float = 1.0
var _damage_phase: float = 0.0
var _radius: float = 72.0
var _remaining: float = 2.4
var _damage_timer: float = 0.0
var _pulses_emitted: int = 0
var _is_critical: bool = false
var _visual_time: float = 0.0
var _pulse_flash_remaining: float = 0.0
var _tracked_enemies: Dictionary = {}
var _enemy_damage_remainders: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Initializes one straight storm lane. The anchor contributes forward-Y
## displacement only, preventing cast-time lateral velocity from skewing the path.
func configure(
	direction: Vector2,
	exact_damage: float,
	radius: float,
	is_critical: bool = false,
	motion_anchor: Node2D = null,
	speed_multiplier: float = 1.0,
	projectile_index: int = 0
) -> void:
	_direction = direction.normalized()
	if _direction.is_zero_approx():
		_direction = Vector2.UP
	_motion_anchor = motion_anchor
	if is_instance_valid(_motion_anchor):
		_last_anchor_position = _motion_anchor.global_position
	_projectile_speed_multiplier = maxf(speed_multiplier, 0.01)
	_exact_damage = maxf(exact_damage, 1.0)
	var fractional_damage := _exact_damage - floorf(_exact_damage)
	_damage_phase = fmod(
		float(maxi(projectile_index, 0))
			* fractional_damage
			* float(maxi(maximum_damage_pulses, 1)),
		1.0
	)
	_radius = maxf(radius, 24.0)
	_is_critical = is_critical
	_remaining = maxf(lifetime, 0.1)
	_damage_timer = 0.0
	_pulses_emitted = 0
	_apply_collision_radius()
	rotation = _direction.angle() + PI * 0.5
	queue_redraw()


func _physics_process(delta: float) -> void:
	_remaining -= delta
	_visual_time = fmod(_visual_time + delta, TAU)
	_pulse_flash_remaining = maxf(_pulse_flash_remaining - delta, 0.0)
	_apply_forward_anchor_displacement()
	global_position += (
		_direction
		* aim_travel_speed
		* _projectile_speed_multiplier
		* delta
	)
	if _pulses_emitted < maximum_damage_pulses:
		_damage_timer -= delta
		if _damage_timer <= 0.0:
			_damage_timer += maxf(damage_interval, 0.05)
			_damage_enemies_in_cloud()
			_pulses_emitted += 1
			_pulse_flash_remaining = minf(damage_interval * 0.55, 0.18)
	queue_redraw()
	if _remaining <= 0.0:
		queue_free()


func _apply_forward_anchor_displacement() -> void:
	if not is_instance_valid(_motion_anchor):
		return
	var anchor_position := _motion_anchor.global_position
	global_position.y += anchor_position.y - _last_anchor_position.y
	_last_anchor_position = anchor_position


func _apply_collision_radius() -> void:
	if not is_instance_valid(collision_shape):
		return
	var circle := collision_shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		collision_shape.shape = circle
	circle.radius = _radius


func _on_body_entered(body: Node2D) -> void:
	if body is not EnemyController:
		return
	var enemy := body as EnemyController
	_tracked_enemies[enemy.get_instance_id()] = enemy


func _on_body_exited(body: Node2D) -> void:
	if body is not EnemyController:
		return
	var enemy_id := body.get_instance_id()
	_tracked_enemies.erase(enemy_id)


func _damage_enemies_in_cloud() -> void:
	var stale_enemy_ids: Array[int] = []
	for enemy_id_variant in _tracked_enemies:
		var enemy_id := int(enemy_id_variant)
		var enemy := _tracked_enemies[enemy_id] as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_combat_active():
			stale_enemy_ids.append(enemy_id)
			continue
		var remainder := float(
			_enemy_damage_remainders.get(enemy_id, _damage_phase)
		)
		var accumulated_damage := _exact_damage + remainder
		var pulse_damage := maxi(floori(accumulated_damage + 0.0001), 1)
		_enemy_damage_remainders[enemy_id] = (
			accumulated_damage - float(pulse_damage)
		)
		enemy.take_melee_damage(pulse_damage, _is_critical)
	for enemy_id in stale_enemy_ids:
		_tracked_enemies.erase(enemy_id)
		_enemy_damage_remainders.erase(enemy_id)


func _draw() -> void:
	var fade := clampf(_remaining / minf(maxf(lifetime, 0.1), 0.55), 0.0, 1.0)
	var pulse_strength := clampf(
		_pulse_flash_remaining / maxf(minf(damage_interval * 0.55, 0.18), 0.01),
		0.0,
		1.0
	)
	draw_circle(
		Vector2.ZERO,
		_radius,
		Color(0.16, 0.18, 0.32, (0.07 + pulse_strength * 0.04) * fade)
	)
	draw_arc(
		Vector2.ZERO,
		_radius * (0.92 + pulse_strength * 0.08),
		0.0,
		TAU,
		72,
		Color(0.54, 0.82, 1.0, (0.18 + pulse_strength * 0.52) * fade),
		1.5 + pulse_strength * 2.0,
		true
	)
	for cloud_index in 6:
		var angle := float(cloud_index) / 6.0 * TAU + _visual_time * 0.12
		var position := Vector2.from_angle(angle) * _radius * 0.34
		position.y += _radius * 0.08
		draw_circle(
			position,
			_radius * (0.24 + float(cloud_index % 3) * 0.03),
			Color(0.27, 0.3, 0.43, 0.48 * fade)
		)
	var travel_tail := Vector2(0.0, _radius * 0.76)
	draw_line(
		travel_tail,
		travel_tail + Vector2(0.0, _radius * 0.34),
		Color(0.46, 0.72, 1.0, 0.24 * fade),
		_radius * 0.16,
		true
	)
	for bolt_index in 3:
		var x := sin(_visual_time * 5.0 + float(bolt_index) * 2.1) * _radius * 0.5
		draw_polyline(
			PackedVector2Array([
				Vector2(x, -_radius * 0.3),
				Vector2(x + 8.0, -4.0),
				Vector2(x - 4.0, 18.0),
				Vector2(x + 5.0, _radius * 0.36),
			]),
			Color(
				0.76 if not _is_critical else 0.94,
				0.9 if not _is_critical else 0.76,
				1.0,
				(0.72 + pulse_strength * 0.28) * fade
			),
			2.4 + pulse_strength * 1.8,
			true
		)


## Returns emitted damage-pulse count for focused gameplay validation.
func get_damage_pulses_emitted() -> int:
	return _pulses_emitted


## Returns the snapshotted straight-line travel direction.
func get_travel_direction() -> Vector2:
	return _direction
