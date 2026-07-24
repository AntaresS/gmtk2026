class_name EnemyController
extends CharacterBody2D

signal defeated(drop_position: Vector2, inherited_velocity: Vector2)

enum EnemyArchetype {
	MELEE,
	BOMBER,
	HEALER,
}

const ATTACK_FLASH_DURATION: float = 0.28
const THREAT_RING_DASH_COUNT: int = 18
const CriticalHitVfxResource = preload(
	"res://game/scripts/gameplay/critical_hit_vfx.gd"
)
const DEFAULT_CRITICAL_HIT_VFX_SCENE: PackedScene = preload(
	"res://game/scenes/gameplay/critical_hit_vfx.tscn"
)

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
## Zero-based cultivation realm tier of this enemy. The existing enemy scene
## uses zero for Qi Refining and cannot damage players in higher realms.
@export_range(0, 20, 1) var combat_realm_index: int = 0
## Distance behind the player, in world pixels, at which this enemy is removed
## if it was passed without being defeated.
@export var despawn_behind_distance: float = 900.0

@export_category("Enemy Variant")
## Gameplay role selected by EnemySpawner for this instance.
@export var archetype: EnemyArchetype = EnemyArchetype.MELEE
## Whether this enemy flies above ground units and renders visible wings.
@export var is_flying: bool = false
## Whether this flying enemy attacks at range instead of contact distance.
@export var uses_ranged_attack: bool = false
## Ranged attack radius in world pixels.
@export_range(80.0, 800.0, 5.0) var ranged_attack_range: float = 260.0
## Lateral autonomous movement speed in pixels per second. Zero stays straight.
@export_range(0.0, 800.0, 5.0) var autonomous_lateral_speed: float = 0.0
## Seconds between left-right autonomous direction changes.
@export_range(0.2, 8.0, 0.1) var autonomous_turn_interval: float = 1.8
## Radius in world pixels at which a bomber detonates.
@export_range(20.0, 200.0, 5.0) var explosion_radius: float = 70.0
## Damage dealt by a bomber before it destroys itself.
@export_range(0.1, 100.0, 0.5) var explosion_damage: float = 12.0
## Healing radius in world pixels for support enemies.
@export_range(40.0, 600.0, 5.0) var healing_radius: float = 150.0
## Health restored to each nearby enemy per pulse.
@export_range(1, 100, 1) var healing_amount: int = 2
## Seconds between area-healing pulses.
@export_range(0.2, 10.0, 0.1) var healing_interval: float = 2.0

@export_category("Impact Recovery")
## Default speed per second used when external knockback does not provide its
## own recovery value.
@export_range(10.0, 5000.0, 10.0) var default_knockback_recovery: float = 920.0

@export_category("Damage Feedback")
## World-space presentation spawned for confirmed player critical hits. The
## shared scene survives long enough to remain readable after enemy defeat.
@export var critical_hit_vfx_scene: PackedScene = (
	DEFAULT_CRITICAL_HIT_VFX_SCENE
)

var current_health: int = 0
var is_elite: bool = false
var _ordinary_health_equivalent: int = 0
var _combat_active: bool = true
var _melee_cooldown_remaining: float = 0.0
var _attack_windup_remaining: float = 0.0
var _is_attack_winding_up: bool = false
var _hit_flash_remaining: float = 0.0
var _attack_flash_remaining: float = 0.0
var _attack_direction: Vector2 = Vector2.DOWN
var _indicator_time: float = 0.0
var _road_center_x: float = 0.0
var _road_edge_clearance: float = 0.0
var _road_half_width_resolver: Callable
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_recovery: float = 920.0
var _autonomous_time_remaining: float = 0.0
var _autonomous_direction: float = 1.0
var _healing_time_remaining: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	if _ordinary_health_equivalent <= 0:
		_ordinary_health_equivalent = maxi(max_health, 1)
	current_health = maxi(max_health, 1)
	elite_label.visible = is_elite
	attack_warning_label.hide()
	_melee_cooldown_remaining = _get_recovery_duration()
	_autonomous_time_remaining = maxf(autonomous_turn_interval, 0.2)
	_healing_time_remaining = maxf(healing_interval, 0.2)
	z_index = 12 if is_flying else 4
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _combat_active or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	_autonomous_time_remaining -= delta
	if _autonomous_time_remaining <= 0.0:
		_autonomous_direction *= -1.0
		_autonomous_time_remaining = maxf(autonomous_turn_interval, 0.2)
	velocity = Vector2(
		_autonomous_direction * autonomous_lateral_speed,
		-maxf(cruise_speed, 1.0)
	) + _knockback_velocity
	move_and_slide()
	_constrain_to_road()
	_knockback_velocity = _knockback_velocity.move_toward(
		Vector2.ZERO,
		maxf(_knockback_recovery, 1.0) * delta
	)

	var target := _get_combat_target()
	var distance_to_target := (
		global_position.distance_to(target.global_position)
		if is_instance_valid(target)
		else INF
	)
	if archetype == EnemyArchetype.BOMBER:
		if distance_to_target <= explosion_radius:
			_explode(target)
			return
	else:
		_update_melee_attack(delta, distance_to_target, target)
	if archetype == EnemyArchetype.HEALER:
		_update_healing(delta)

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
	if archetype == EnemyArchetype.BOMBER:
		body_color = Color("ff6438")
	elif archetype == EnemyArchetype.HEALER:
		body_color = Color("54e59b") if not is_elite else Color("b5ff75")
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
	if is_flying:
		var flap := 4.0 + sin(_indicator_time * 9.0) * 5.0
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-13.0, -4.0),
				Vector2(-42.0, -18.0 - flap),
				Vector2(-34.0, 7.0),
			]),
			Color(0.72, 0.86, 1.0, 0.82)
		)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(13.0, -4.0),
				Vector2(42.0, -18.0 - flap),
				Vector2(34.0, 7.0),
			]),
			Color(0.72, 0.86, 1.0, 0.82)
		)
	draw_circle(Vector2.ZERO, 22.0, Color(0.2, 0.02, 0.03, 0.8))
	draw_circle(Vector2.ZERO, 17.0, body_color)
	draw_line(Vector2(-10.0, -4.0), Vector2(10.0, -4.0), Color.WHITE, 3.0)
	draw_line(Vector2.ZERO, Vector2(0.0, 9.0), Color("57141a"), 3.0)
	if uses_ranged_attack:
		draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 28, Color("84dcff"), 3.0)
	if archetype == EnemyArchetype.BOMBER:
		draw_circle(Vector2.ZERO, 8.0, Color("fff18a"))
	elif archetype == EnemyArchetype.HEALER:
		draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0), Color.WHITE, 4.0)
		draw_line(Vector2(0.0, -8.0), Vector2(0.0, 8.0), Color.WHITE, 4.0)
		draw_arc(
			Vector2.ZERO,
			_get_local_healing_radius(),
			0.0,
			TAU,
			56,
			Color(0.35, 1.0, 0.62, 0.24),
			2.0
		)

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


func _update_melee_attack(
	delta: float,
	distance_to_target: float,
	target: Node2D
) -> void:
	if _is_attack_winding_up:
		if is_instance_valid(target):
			_attack_direction = global_position.direction_to(target.global_position)
		_attack_windup_remaining = maxf(
			_attack_windup_remaining - delta,
			0.0
		)
		_update_attack_warning_label()
		if _attack_windup_remaining <= 0.0:
			_finish_melee_attack(distance_to_target, target)
		return

	_melee_cooldown_remaining = maxf(
		_melee_cooldown_remaining - delta,
		0.0
	)
	if (
		distance_to_target <= _get_attack_range()
		and _melee_cooldown_remaining <= 0.0
	):
		_begin_melee_attack()


func _begin_melee_attack() -> void:
	_is_attack_winding_up = true
	_attack_windup_remaining = maxf(melee_windup_duration, 0.2)
	var target := _get_combat_target()
	if is_instance_valid(target):
		_attack_direction = global_position.direction_to(target.global_position)
	attack_warning_label.show()
	_update_attack_warning_label()
	queue_redraw()


func _finish_melee_attack(distance_to_target: float, target: Node2D) -> void:
	_is_attack_winding_up = false
	_attack_windup_remaining = 0.0
	attack_warning_label.hide()
	_attack_flash_remaining = ATTACK_FLASH_DURATION
	if distance_to_target <= _get_attack_range() and is_instance_valid(target):
		if target.has_method("take_enemy_damage"):
			target.call("take_enemy_damage", melee_damage, self)
		elif target is PlayerController:
			(target as PlayerController).take_melee_damage(melee_damage, self)
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
	return _get_attack_range() / world_scale_x


func _get_threat_indicator_visibility() -> float:
	var target := _get_combat_target()
	if not is_instance_valid(target):
		return 0.0
	var attack_range := _get_attack_range()
	var distance_to_player := global_position.distance_to(target.global_position)
	return 1.0 - clampf(
		(distance_to_player - attack_range)
			/ maxf(threat_indicator_margin, 1.0),
		0.0,
		1.0
	)


func _get_attack_range() -> float:
	return ranged_attack_range if uses_ranged_attack else melee_attack_range


func _get_combat_target() -> Node2D:
	var closest: Node2D = player
	var closest_distance := (
		global_position.distance_squared_to(player.global_position)
		if is_instance_valid(player)
		else INF
	)
	for echo_node in get_tree().get_nodes_in_group("player_echoes"):
		if echo_node is not Node2D or not echo_node.has_method("take_enemy_damage"):
			continue
		var distance := global_position.distance_squared_to(
			(echo_node as Node2D).global_position
		)
		if distance < closest_distance:
			closest = echo_node as Node2D
			closest_distance = distance
	return closest


func _explode(target: Node2D) -> void:
	if not _combat_active:
		return
	if is_instance_valid(target):
		if target.has_method("take_enemy_damage"):
			target.call("take_enemy_damage", explosion_damage, self)
		elif target is PlayerController:
			(target as PlayerController).take_melee_damage(explosion_damage, self)
	_combat_active = false
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 2.4, 0.16)
	tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.05, 0.0), 0.16)
	tween.chain().tween_callback(queue_free)


func _update_healing(delta: float) -> void:
	_healing_time_remaining = maxf(_healing_time_remaining - delta, 0.0)
	if _healing_time_remaining > 0.0:
		return
	_healing_time_remaining = maxf(healing_interval, 0.2)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController or enemy_node == self:
			continue
		var ally := enemy_node as EnemyController
		if (
			ally.is_combat_active()
			and ally.global_position.distance_to(global_position) <= healing_radius
		):
			ally.heal(healing_amount)
	queue_redraw()


func _get_local_healing_radius() -> float:
	var world_scale_x := maxf(absf(global_transform.get_scale().x), 0.01)
	return healing_radius / world_scale_x


func heal(amount: int) -> void:
	if not _combat_active or amount <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	queue_redraw()


## Applies one progression-gated aerial combat package.
func configure_flying(
	enemy_realm_index: int,
	ranged: bool,
	lateral_speed_value: float
) -> void:
	is_flying = true
	combat_realm_index = maxi(enemy_realm_index, 1)
	uses_ranged_attack = ranged
	autonomous_lateral_speed = maxf(lateral_speed_value, 0.0)
	if is_node_ready():
		z_index = 12
		queue_redraw()


## Selects a normal, self-destruct, or healing role.
func configure_archetype(new_archetype: EnemyArchetype) -> void:
	archetype = new_archetype
	if archetype == EnemyArchetype.BOMBER:
		max_health = maxi(1, roundi(float(max_health) * 0.38))
	elif archetype == EnemyArchetype.HEALER and is_elite:
		healing_radius *= 1.65
	if is_node_ready():
		current_health = max_health
		queue_redraw()


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


## Keeps this enemy inside a dynamic road whose width is sampled at the
## enemy's live world Y. EnemySpawner owns the resolver and route center;
## clearance is measured in world pixels from either visible road edge.
func configure_road_constraint(
	road_center_x: float,
	road_half_width_resolver: Callable,
	road_edge_clearance: float
) -> void:
	_road_center_x = road_center_x
	_road_half_width_resolver = road_half_width_resolver
	_road_edge_clearance = maxf(road_edge_clearance, 0.0)


func _constrain_to_road() -> void:
	if not _road_half_width_resolver.is_valid():
		return
	var road_half_width := maxf(
		float(_road_half_width_resolver.call(global_position.y)),
		1.0
	)
	var usable_half_width := maxf(
		road_half_width - _road_edge_clearance,
		1.0
	)
	global_position.x = clampf(
		global_position.x,
		_road_center_x - usable_half_width,
		_road_center_x + usable_half_width
	)


## Converts this enemy into a visibly larger elite while preserving all
## time-based difficulty already applied by EnemySpawner.
func configure_elite(
	health_multiplier: float,
	attack_range_multiplier: float,
	visual_scale: float
) -> void:
	_ordinary_health_equivalent = maxi(max_health, 1)
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


## Returns this enemy's pre-elite maximum health at the same difficulty.
func get_ordinary_health_equivalent() -> int:
	return maxi(_ordinary_health_equivalent, 1)


## Applies an angle-preserving external impulse. The enemy blends back toward
## its authored straight-running velocity instead of snapping immediately.
func apply_knockback(
	direction: Vector2,
	speed: float,
	recovery: float = 0.0
) -> void:
	if not _combat_active or speed <= 0.0:
		return
	var resolved_direction := direction.normalized()
	if resolved_direction.is_zero_approx():
		resolved_direction = Vector2.DOWN
	_knockback_velocity = resolved_direction * speed
	_knockback_recovery = (
		recovery
		if recovery > 0.0
		else maxf(default_knockback_recovery, 1.0)
	)


func get_knockback_velocity() -> Vector2:
	return _knockback_velocity


## Applies player damage exactly once per hit and removes the enemy after its
## health reaches zero. Critical metadata changes presentation only.
func take_melee_damage(amount: int, is_critical: bool = false) -> void:
	if not _combat_active or amount <= 0:
		return
	if is_critical:
		_spawn_critical_hit_vfx(amount)
	current_health = maxi(current_health - amount, 0)
	_hit_flash_remaining = 0.2 if is_critical else 0.12
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


func _spawn_critical_hit_vfx(amount: int) -> void:
	if critical_hit_vfx_scene == null or get_parent() == null:
		return
	var critical_vfx := (
		critical_hit_vfx_scene.instantiate()
		as CriticalHitVfxResource
	)
	if critical_vfx == null:
		push_error(
			"Enemy critical_hit_vfx_scene must instantiate CriticalHitVfx."
		)
		return
	get_parent().add_child(critical_vfx)
	critical_vfx.global_position = global_position
	critical_vfx.play(amount)


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
