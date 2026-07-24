class_name EnemyController
extends CharacterBody2D

signal defeated(drop_position: Vector2, inherited_velocity: Vector2)

const ATTACK_FLASH_DURATION: float = 0.28
const THREAT_RING_DASH_COUNT: int = 18

@onready var elite_label: Label = $EliteLabel
@onready var attack_warning_label: Label = $AttackWarningLabel

## Player pursued and attacked by this enemy. EnemySpawner injects the active
## player when the enemy is created.
@export var player: PlayerController
## Constant forward speed in world pixels per second. Forward enemies use a
## slower value and rear pursuers receive a slightly faster value; neither
## accelerates, turns, or moves laterally toward the player.
@export var cruise_speed: float = 140.0
## Damage the enemy can receive before being defeated.
@export_range(1, 100, 1) var max_health: int = 3
## Radius, in world pixels, within which the enemy can strike the player.
@export_range(20.0, 120.0, 1.0) var melee_attack_range: float = 55.0
## Seconds from one enemy melee strike to the next, including its telegraphed
## wind-up. This is longer than the player's interval, giving the player a
## deliberate frequency advantage.
@export_range(0.1, 5.0, 0.05) var melee_attack_interval: float = 1.0
## Warning time, in seconds, between committing to a melee attack and applying
## damage. The target may escape the visible threat circle during this window.
@export_range(0.2, 2.0, 0.05) var melee_windup_duration: float = 0.6
## Extra distance, in world pixels, outside melee range over which the threat
## boundary fades into view. Larger values reveal dangerous enemies sooner.
@export_range(20.0, 240.0, 1.0) var threat_indicator_margin: float = 100.0
## Lifespan removed by each successful enemy melee attack.
@export_range(0.1, 30.0, 0.1) var melee_damage: float = 3.0
## Distance behind the player, in world pixels, at which this enemy is removed
## if it was passed without being defeated.
@export var despawn_behind_distance: float = 900.0

var current_health: int = 0
var is_elite: bool = false
var _combat_active: bool = true
var _melee_cooldown_remaining: float = 0.0
var _attack_windup_remaining: float = 0.0
var _is_attack_winding_up: bool = false
var _hit_flash_remaining: float = 0.0
var _attack_flash_remaining: float = 0.0
var _attack_direction: Vector2 = Vector2.DOWN
var _indicator_time: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	current_health = maxi(max_health, 1)
	elite_label.visible = is_elite
	attack_warning_label.hide()
	_melee_cooldown_remaining = _get_recovery_duration()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _combat_active or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	velocity = Vector2(
		0.0,
		-maxf(cruise_speed, 1.0)
	)
	move_and_slide()

	var distance_to_player := global_position.distance_to(player.global_position)
	_update_melee_attack(delta, distance_to_player)

	if global_position.y > player.global_position.y + despawn_behind_distance:
		queue_free()

	_indicator_time = fmod(_indicator_time + delta, TAU)
	if is_threat_indicator_visible() or _is_attack_winding_up:
		queue_redraw()
	if _hit_flash_remaining > 0.0:
		_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
		queue_redraw()
	if _attack_flash_remaining > 0.0:
		_attack_flash_remaining = maxf(_attack_flash_remaining - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	_draw_threat_indicator()

	var body_color := Color("e6a326") if is_elite else Color("d94b55")
	if _is_attack_winding_up:
		var warning_pulse := 0.5 + 0.5 * sin(_indicator_time * 9.0)
		body_color = body_color.lerp(
			Color("fff0a6"),
			0.35 + warning_pulse * 0.5
		)
	if _hit_flash_remaining > 0.0:
		body_color = Color("fff2a8")
	if is_elite:
		draw_circle(Vector2.ZERO, 28.0, Color(1.0, 0.68, 0.12, 0.18))
		draw_arc(
			Vector2.ZERO,
			27.0,
			0.0,
			TAU,
			40,
			Color(1.0, 0.82, 0.28, 0.9),
			3.0,
			true
		)
	draw_circle(Vector2.ZERO, 22.0, Color(0.2, 0.02, 0.03, 0.8))
	draw_circle(Vector2.ZERO, 17.0, body_color)
	draw_line(Vector2(-10.0, -4.0), Vector2(10.0, -4.0), Color.WHITE, 3.0)
	draw_line(Vector2.ZERO, Vector2(0.0, 9.0), Color("57141a"), 3.0)

	var health_ratio := (
		float(current_health) / float(maxi(max_health, 1))
	)
	draw_rect(Rect2(-22.0, -34.0, 44.0, 5.0), Color(0.08, 0.02, 0.03, 0.9))
	draw_rect(
		Rect2(-22.0, -34.0, 44.0 * health_ratio, 5.0),
		Color("6aff86")
	)
	if _attack_flash_remaining > 0.0:
		var local_attack_range := _get_local_melee_range()
		var flash_progress := 1.0 - (
			_attack_flash_remaining / ATTACK_FLASH_DURATION
		)
		draw_circle(
			Vector2.ZERO,
			lerpf(10.0, local_attack_range, flash_progress),
			Color(1.0, 0.08, 0.04, (1.0 - flash_progress) * 0.26)
		)
		draw_arc(
			Vector2.ZERO,
			lerpf(local_attack_range * 0.7, local_attack_range, flash_progress),
			0.0,
			TAU,
			48,
			Color(1.0, 0.24, 0.08, 1.0 - flash_progress),
			6.0,
			true
		)
		var attack_angle := _attack_direction.angle()
		draw_arc(
			Vector2.ZERO,
			local_attack_range * 0.72,
			attack_angle - 0.72,
			attack_angle + 0.72,
			20,
			Color(1.0, 0.82, 0.25, 1.0 - flash_progress),
			8.0,
			true
		)
		draw_line(
			Vector2.ZERO,
			_attack_direction * local_attack_range,
			Color(1.0, 0.8, 0.18, 1.0 - flash_progress),
			4.0
		)


func _update_melee_attack(delta: float, distance_to_player: float) -> void:
	if _is_attack_winding_up:
		_attack_direction = global_position.direction_to(player.global_position)
		_attack_windup_remaining = maxf(
			_attack_windup_remaining - delta,
			0.0
		)
		_update_attack_warning_label()
		if _attack_windup_remaining <= 0.0:
			_finish_melee_attack(distance_to_player)
		return

	_melee_cooldown_remaining = maxf(
		_melee_cooldown_remaining - delta,
		0.0
	)
	if (
		distance_to_player <= melee_attack_range
		and _melee_cooldown_remaining <= 0.0
	):
		_begin_melee_attack()


func _begin_melee_attack() -> void:
	_is_attack_winding_up = true
	_attack_windup_remaining = maxf(melee_windup_duration, 0.2)
	_attack_direction = global_position.direction_to(player.global_position)
	attack_warning_label.show()
	_update_attack_warning_label()
	queue_redraw()


func _finish_melee_attack(distance_to_player: float) -> void:
	_is_attack_winding_up = false
	_attack_windup_remaining = 0.0
	attack_warning_label.hide()
	_attack_flash_remaining = ATTACK_FLASH_DURATION
	if distance_to_player <= melee_attack_range:
		player.take_melee_damage(melee_damage, self)
	_melee_cooldown_remaining = _get_recovery_duration()
	queue_redraw()


func _update_attack_warning_label() -> void:
	if not _is_attack_winding_up:
		attack_warning_label.hide()
		return
	var progress := get_attack_windup_progress()
	var pulse := 0.5 + 0.5 * sin(_indicator_time * 12.0)
	attack_warning_label.modulate = Color(
		1.0,
		lerpf(0.88, 0.2, progress),
		lerpf(0.25, 0.08, progress),
		0.78 + pulse * 0.22
	)
	attack_warning_label.scale = Vector2.ONE * lerpf(0.9, 1.3, progress)


func _draw_threat_indicator() -> void:
	var visibility := _get_threat_indicator_visibility()
	if visibility <= 0.0 and not _is_attack_winding_up:
		return
	var local_attack_range := _get_local_melee_range()
	var pulse := 0.5 + 0.5 * sin(_indicator_time * 7.0)
	var base_alpha := visibility * (0.3 + pulse * 0.12)
	var dash_step := TAU / float(THREAT_RING_DASH_COUNT)
	var dash_rotation := _indicator_time * 0.16
	for dash_index in THREAT_RING_DASH_COUNT:
		var dash_start := dash_rotation + float(dash_index) * dash_step
		draw_arc(
			Vector2.ZERO,
			local_attack_range,
			dash_start,
			dash_start + dash_step * 0.62,
			4,
			Color(1.0, 0.2, 0.12, base_alpha),
			3.0,
			true
		)

	var readiness := 1.0 - clampf(
		_melee_cooldown_remaining / _get_recovery_duration(),
		0.0,
		1.0
	)
	if not _is_attack_winding_up and readiness > 0.0:
		draw_arc(
			Vector2.ZERO,
			local_attack_range + 5.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * readiness,
			36,
			Color(1.0, 0.66, 0.16, visibility * 0.7),
			3.0,
			true
		)

	if not _is_attack_winding_up:
		return
	var windup_progress := get_attack_windup_progress()
	var warning_color := Color(
		1.0,
		lerpf(0.72, 0.08, windup_progress),
		0.05,
		lerpf(0.16, 0.34, windup_progress)
	)
	draw_circle(Vector2.ZERO, local_attack_range, warning_color)
	draw_arc(
		Vector2.ZERO,
		local_attack_range,
		-PI * 0.5,
		-PI * 0.5 + TAU * windup_progress,
		48,
		Color(1.0, 0.86, 0.2, 0.95),
		6.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		lerpf(local_attack_range, 18.0, windup_progress),
		0.0,
		TAU,
		40,
		Color(1.0, 0.92, 0.5, 0.85),
		3.0,
		true
	)


func _get_recovery_duration() -> float:
	return maxf(
		maxf(melee_attack_interval, 0.1)
			- maxf(melee_windup_duration, 0.2),
		0.1
	)


func _get_local_melee_range() -> float:
	var world_scale_x := maxf(absf(global_transform.get_scale().x), 0.01)
	return melee_attack_range / world_scale_x


func _get_threat_indicator_visibility() -> float:
	if not is_instance_valid(player):
		return 0.0
	var distance_to_player := global_position.distance_to(player.global_position)
	return 1.0 - clampf(
		(distance_to_player - melee_attack_range)
			/ maxf(threat_indicator_margin, 1.0),
		0.0,
		1.0
	)


## Returns whether the player is close enough to see this enemy's exact melee
## threat boundary.
func is_threat_indicator_visible() -> bool:
	return _combat_active and _get_threat_indicator_visibility() > 0.0


## Returns whether this enemy has committed to an announced melee strike.
func is_attack_winding_up() -> bool:
	return _combat_active and _is_attack_winding_up


## Returns the current wind-up completion from zero to one for presentation and
## automated combat-contract checks.
func get_attack_windup_progress() -> float:
	if not _is_attack_winding_up:
		return 0.0
	return 1.0 - clampf(
		_attack_windup_remaining / maxf(melee_windup_duration, 0.2),
		0.0,
		1.0
	)


## Converts this enemy into a visibly larger elite while preserving all
## time-based difficulty already applied by EnemySpawner.
func configure_elite(
	health_multiplier: float,
	attack_range_multiplier: float,
	visual_scale: float
) -> void:
	is_elite = true
	max_health = maxi(
		roundi(float(max_health) * maxf(health_multiplier, 1.0)),
		max_health + 1
	)
	melee_attack_range *= maxf(attack_range_multiplier, 1.0)
	scale = Vector2.ONE * maxf(visual_scale, 1.0)
	if is_node_ready():
		current_health = max_health
		elite_label.show()
		queue_redraw()


func is_elite_enemy() -> bool:
	return is_elite


## Applies player melee damage exactly once per strike and removes the enemy
## after its health reaches zero.
func take_melee_damage(amount: int) -> void:
	if not _combat_active or amount <= 0:
		return
	current_health = maxi(current_health - amount, 0)
	_hit_flash_remaining = 0.12
	queue_redraw()
	if current_health > 0:
		return
	var defeat_position := global_position
	var defeat_velocity := velocity
	_combat_active = false
	collision_layer = 0
	collision_mask = 0
	defeated.emit(defeat_position, defeat_velocity)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.4, 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)


## Returns whether this enemy may be targeted or attack.
func is_combat_active() -> bool:
	return _combat_active


## Stops movement and attacks when the run ends.
func set_combat_enabled(enabled: bool) -> void:
	_combat_active = enabled and current_health > 0
	if not _combat_active:
		velocity = Vector2.ZERO
		_is_attack_winding_up = false
		_attack_windup_remaining = 0.0
		if is_node_ready():
			attack_warning_label.hide()
		queue_redraw()
