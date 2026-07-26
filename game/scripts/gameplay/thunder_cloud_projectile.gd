class_name ThunderCloudProjectile
extends Area2D

const LIGHTNING_ICON_COUNT: int = 4
const DISCHARGE_ICON_COUNT: int = 3
static var _lightning_icon_points := PackedVector2Array([
	Vector2(-2.0, -9.0),
	Vector2(4.0, -9.0),
	Vector2(1.0, -2.0),
	Vector2(6.0, -2.0),
	Vector2(-4.0, 10.0),
	Vector2(-1.0, 2.0),
	Vector2(-6.0, 2.0),
])

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
var _lightning_icon_positions := PackedVector2Array()
var _lightning_icon_phases := PackedFloat32Array()
var _lightning_icon_rotations := PackedFloat32Array()
var _lightning_icon_scales := PackedFloat32Array()
var _discharge_icon_indices := PackedInt32Array()
var _discharge_connection_points := PackedVector2Array()
var _discharge_serial: int = 0
var _visual_seed: float = 0.0


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
	_visual_seed = (
		float(maxi(projectile_index, 0)) * 17.31
		+ global_position.x * 0.013
		+ global_position.y * 0.007
	)
	_initialize_lightning_icons()
	_apply_collision_radius()
	rotation = _direction.angle() + PI * 0.5
	queue_redraw()


func _physics_process(delta: float) -> void:
	_remaining -= delta
	_visual_time = fmod(_visual_time + delta, TAU)
	var discharge_was_active := _pulse_flash_remaining > 0.0
	_pulse_flash_remaining = maxf(_pulse_flash_remaining - delta, 0.0)
	if discharge_was_active and _pulse_flash_remaining <= 0.0:
		_replace_discharged_icons()
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
			_start_internal_discharge()
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
		enemy.take_melee_damage(
			pulse_damage,
			_is_critical,
			&"thunder_hammer"
		)
	for enemy_id in stale_enemy_ids:
		_tracked_enemies.erase(enemy_id)
		_enemy_damage_remainders.erase(enemy_id)


func _initialize_lightning_icons() -> void:
	_lightning_icon_positions.resize(LIGHTNING_ICON_COUNT)
	_lightning_icon_phases.resize(LIGHTNING_ICON_COUNT)
	_lightning_icon_rotations.resize(LIGHTNING_ICON_COUNT)
	_lightning_icon_scales.resize(LIGHTNING_ICON_COUNT)
	_discharge_icon_indices.resize(DISCHARGE_ICON_COUNT)
	for icon_index in LIGHTNING_ICON_COUNT:
		_replace_lightning_icon(icon_index, 0)
	for discharge_index in DISCHARGE_ICON_COUNT:
		_discharge_icon_indices[discharge_index] = -1
	_discharge_connection_points.clear()


func _replace_lightning_icon(icon_index: int, replacement_serial: int) -> void:
	var seed := (
		_visual_seed
		+ float(icon_index) * 7.13
		+ float(replacement_serial) * 19.71
	)
	var angle := _hash_unit(seed) * TAU
	var radial_distance := (
		sqrt(_hash_unit(seed + 1.37)) * _radius * 0.56
	)
	_lightning_icon_positions[icon_index] = (
		Vector2.from_angle(angle) * radial_distance
	)
	_lightning_icon_phases[icon_index] = _hash_unit(seed + 2.81) * TAU
	_lightning_icon_rotations[icon_index] = (
		_hash_unit(seed + 4.19) * 1.4 - 0.7
	)
	_lightning_icon_scales[icon_index] = (
		_radius / 112.0
		* lerpf(0.82, 1.2, _hash_unit(seed + 5.63))
	)


func _hash_unit(seed: float) -> float:
	return fposmod(sin(seed * 12.9898) * 43758.5453, 1.0)


func _get_lightning_icon_position(icon_index: int) -> Vector2:
	var phase := _lightning_icon_phases[icon_index]
	return (
		_lightning_icon_positions[icon_index]
		+ Vector2(
			sin(_visual_time * 2.7 + phase),
			cos(_visual_time * 3.1 + phase * 1.31)
		) * _radius * 0.035
	)


func _start_internal_discharge() -> void:
	if _lightning_icon_positions.size() < LIGHTNING_ICON_COUNT:
		return
	_discharge_serial += 1
	var first_index := _discharge_serial % LIGHTNING_ICON_COUNT
	var connection_direction := (
		1 if _discharge_serial % 2 == 0 else -1
	)
	var second_index := (
		first_index + connection_direction + LIGHTNING_ICON_COUNT
	) % LIGHTNING_ICON_COUNT
	var third_index := (
		second_index + connection_direction + LIGHTNING_ICON_COUNT
	) % LIGHTNING_ICON_COUNT
	_discharge_icon_indices[0] = first_index
	_discharge_icon_indices[1] = second_index
	_discharge_icon_indices[2] = third_index
	_discharge_connection_points.clear()
	_append_discharge_segment(
		_get_lightning_icon_position(first_index),
		_get_lightning_icon_position(second_index),
		0
	)
	_append_discharge_segment(
		_get_lightning_icon_position(second_index),
		_get_lightning_icon_position(third_index),
		1
	)


func _append_discharge_segment(
	from_position: Vector2,
	to_position: Vector2,
	segment_index: int
) -> void:
	if _discharge_connection_points.is_empty():
		_discharge_connection_points.append(from_position)
	var segment_direction := to_position - from_position
	var segment_normal := segment_direction.normalized().orthogonal()
	for point_index in range(1, 3):
		var progress := float(point_index) / 3.0
		var jitter := (
			_hash_unit(
				_visual_seed
				+ float(_discharge_serial) * 11.7
				+ float(segment_index) * 3.9
				+ float(point_index)
			)
			- 0.5
		) * _radius * 0.17
		_discharge_connection_points.append(
			from_position.lerp(to_position, progress)
			+ segment_normal * jitter
		)
	_discharge_connection_points.append(to_position)


func _replace_discharged_icons() -> void:
	for icon_index in _discharge_icon_indices:
		if icon_index < 0 or icon_index >= LIGHTNING_ICON_COUNT:
			continue
		_replace_lightning_icon(icon_index, _discharge_serial)
	for discharge_index in DISCHARGE_ICON_COUNT:
		_discharge_icon_indices[discharge_index] = -1
	_discharge_connection_points.clear()


func _is_discharge_icon(icon_index: int) -> bool:
	for discharge_icon_index in _discharge_icon_indices:
		if discharge_icon_index == icon_index:
			return true
	return false


func _draw() -> void:
	var fade := clampf(_remaining / minf(maxf(lifetime, 0.1), 0.55), 0.0, 1.0)
	var pulse_strength := clampf(
		_pulse_flash_remaining / maxf(minf(damage_interval * 0.55, 0.18), 0.01),
		0.0,
		1.0
	)
	draw_circle(
		Vector2.ZERO,
		_radius * 0.62,
		Color(0.21, 0.23, 0.36, (0.34 + pulse_strength * 0.05) * fade)
	)
	for cloud_index in 8:
		var angle := float(cloud_index) / 8.0 * TAU + _visual_time * 0.08
		var position := Vector2.from_angle(angle) * _radius * 0.45
		var lobe_radius := (
			_radius
			* (0.49 + float(cloud_index % 3) * 0.03)
		)
		draw_circle(
			position,
			lobe_radius,
			Color(
				0.25,
				0.27,
				0.41,
				(0.17 + pulse_strength * 0.025) * fade
			)
		)
	_draw_internal_discharge(fade, pulse_strength)
	_draw_floating_lightning_icons(fade, pulse_strength)


func _draw_internal_discharge(
	fade: float,
	pulse_strength: float
) -> void:
	if (
		pulse_strength <= 0.0
		or _discharge_connection_points.size() < 2
	):
		return
	var lightning_color := (
		Color("f3c8ff") if _is_critical else Color("8fd8ff")
	)
	var flash_strength := pow(pulse_strength, 0.65)
	draw_polyline(
		_discharge_connection_points,
		Color(lightning_color, 0.34 * flash_strength * fade),
		9.0,
		true
	)
	draw_polyline(
		_discharge_connection_points,
		Color(
			lightning_color.lerp(Color.WHITE, 0.72),
			0.98 * flash_strength * fade
		),
		2.8,
		true
	)


func _draw_floating_lightning_icons(
	fade: float,
	pulse_strength: float
) -> void:
	var lightning_color := (
		Color("f3c8ff") if _is_critical else Color("8fd8ff")
	)
	for icon_index in _lightning_icon_positions.size():
		var is_discharging := _is_discharge_icon(icon_index)
		var icon_flash := pulse_strength if is_discharging else 0.0
		var icon_position := _get_lightning_icon_position(icon_index)
		var icon_rotation := (
			_lightning_icon_rotations[icon_index]
			+ sin(
				_visual_time * 2.2
				+ _lightning_icon_phases[icon_index]
			) * 0.16
		)
		var icon_scale := (
			_lightning_icon_scales[icon_index]
			* (1.0 + icon_flash * 0.52)
		)
		draw_set_transform(
			icon_position,
			icon_rotation,
			Vector2.ONE * icon_scale * 1.42
		)
		draw_colored_polygon(
			_lightning_icon_points,
			Color(lightning_color, (0.12 + icon_flash * 0.3) * fade)
		)
		draw_set_transform(
			icon_position,
			icon_rotation,
			Vector2.ONE * icon_scale
		)
		draw_colored_polygon(
			_lightning_icon_points,
			Color(
				lightning_color.lerp(Color.WHITE, icon_flash * 0.78),
				(0.68 + icon_flash * 0.32) * fade
			)
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Returns emitted damage-pulse count for focused gameplay validation.
func get_damage_pulses_emitted() -> int:
	return _pulses_emitted


## Returns the snapshotted straight-line travel direction.
func get_travel_direction() -> Vector2:
	return _direction
