class_name EnemyController
extends CharacterBody2D

signal defeated(drop_position: Vector2, inherited_velocity: Vector2)

enum EnemyArchetype {
	MELEE,
	BOMBER,
	HEALER,
}

enum EliteRewardType {
	NONE,
	WEAPON,
	POWER_FRAGMENT,
}

const ATTACK_FLASH_DURATION: float = 0.28
const THREAT_RING_DASH_COUNT: int = 18
const CriticalHitVfxResource = preload(
	"res://game/scripts/gameplay/critical_hit_vfx.gd"
)
const DEFAULT_CRITICAL_HIT_VFX_SCENE: PackedScene = preload(
	"res://game/scenes/gameplay/critical_hit_vfx.tscn"
)
const ENEMY_OUTLINE_SHADER: Shader = preload(
	"res://game/shaders/enemy_outline.gdshader"
)
const ENEMY_DISSOLVE_SHADER: Shader = preload(
	"res://game/shaders/enemy_dissolve.gdshader"
)
const NORMAL_WALK_ATLAS: Texture2D = preload(
	"res://assets/enemy_frames/normal_walk.png"
)
const NORMAL_HEAL_WALK_ATLAS: Texture2D = preload(
	"res://assets/enemy_frames/normal_heal_walk.png"
)
const BOOMER_WALK_ATLAS: Texture2D = preload(
	"res://assets/enemy_frames/boomer_walk.png"
)
const NORMAL_FLY_ATLAS: Texture2D = preload(
	"res://assets/enemy_frames/normal_fly.png"
)
const ELITE_WALK_ATLAS: Texture2D = preload(
	"res://assets/enemy_frames/elite_walk.png"
)
const ELITE_FLY_ATLAS: Texture2D = preload(
	"res://assets/enemy_frames/elite_fly.png"
)
const BOOMER_BOOM_ATLAS: Texture2D = preload(
	"res://assets/enemy_frames/boomer_boom.png"
)
const FLY_BOOMER_FLY_ATLAS: Texture2D = preload(
	"res://assets/enemy_frames/fly_boomer_fly.png"
)
const FLY_BOOMER_BOOM_ATLAS: Texture2D = preload(
	"res://assets/enemy_frames/fly_boomer_boom.png"
)
const NORMAL_MELEE_WEAPON_TEXTURE: Texture2D = preload(
	"res://assets/enemy_weapons/normal_knife.png"
)
const ELITE_MELEE_WEAPON_TEXTURE: Texture2D = preload(
	"res://assets/enemy_weapons/elite_knife.png"
)
const ENEMY_SPRITE_FRAME_SIZE: int = 544
const ENEMY_MOVE_FRAME_COUNT: int = 6
const FLY_BOOMER_MOVE_FRAME_COUNT: int = 9
const BOOMER_BOOM_FRAME_COUNT: int = 9
const ENEMY_MOVE_ANIMATION_SPEED: float = 10.0
const BOOMER_BOOM_ANIMATION_SPEED: float = 14.0
const BOMBER_WARNING_RANGE_MULTIPLIER: float = 2.25
const BOMBER_WARNING_SLOW_PULSE_SPEED: float = 5.0
const BOMBER_WARNING_FAST_PULSE_SPEED: float = 18.0
const BOMBER_FAST_WARNING_PROGRESS: float = 0.65
const BOMBER_WARNING_OUTLINE_COLOR: Color = Color("ff2020")
const HEALING_PULSE_DURATION: float = 0.9
const HEALING_PULSE_EXPANSION_FRACTION: float = 0.72
const HEALING_PULSE_MINIMUM_RADIUS: float = 14.0
const MELEE_WEAPON_TIP_OFFSET_PIXELS: float = 720.0
const MELEE_WEAPON_SCALE: float = 0.04
const MELEE_WEAPON_SUMMON_DURATION: float = 0.2
const MELEE_WEAPON_RETURN_DURATION: float = 0.18
const MELEE_WEAPON_HOVER_POSITION: Vector2 = Vector2(34.0, -12.0)
const MELEE_WEAPON_SHAKE_START: float = 0.65
const MELEE_WEAPON_OUTLINE_WORLD_WIDTH: float = 1.0
const MELEE_WEAPON_TRAIL_COUNT: int = 3
const MELEE_WEAPON_TRAIL_ANGLE_STEP: float = 0.16
const MELEE_WEAPON_DARK_OUTLINE: Color = Color("681018")
const MELEE_WEAPON_BRIGHT_OUTLINE: Color = Color("ffb347")
const DEATH_DISSOLVE_DURATION: float = 0.48
const IMMOBILIZED_STATUS_PULSE_SPEED: float = 15.0
const FANTIAN_ROOT_TINT: Color = Color("83dcff")
const FANTIAN_ROOT_RUNE_COLOR: Color = Color("6ee7ff")
const FANTIAN_ROOT_FLASH_DURATION: float = 0.14
const FANTIAN_ROOT_RELEASE_DURATION: float = 0.18

@onready var enemy_sprite: AnimatedSprite2D = $EnemySprite
@onready var melee_weapon: Sprite2D = $MeleeWeapon
@onready var enemy_shadow: Node2D = $EnemyShadow
@onready var elite_label: Label = $EliteLabel
@onready var attack_warning_label: Label = $AttackWarningLabel
@onready var immobilized_status_label: Label = $ImmobilizedStatusLabel
@onready var health_value_label: Label = $HealthValueLabel

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
## Radius in world pixels at which a bomber detonates near its combat target.
@export_range(20.0, 300.0, 5.0) var explosion_radius: float = 100.0
## World-space radius in pixels damaged when a bomber detonates.
@export_range(20.0, 300.0, 5.0) var explosion_damage_radius: float = 100.0
## Damage dealt by a bomber before it destroys itself.
@export_range(0.1, 100.0, 0.5) var explosion_damage: float = 12.0
## Maximum sideways tracking speed in pixels per second for bombers. This is
## intentionally much lower than player movement so bombers only adjust gently.
@export_range(0.0, 300.0, 5.0) var bomber_tracking_speed: float = 60.0
## Healing radius in world pixels for support enemies.
@export_range(40.0, 600.0, 5.0) var healing_radius: float = 150.0
## Health restored to every nearby enemy per pulse. The six-point default makes
## one support enemy materially extend a damaged group's survival.
@export_range(1, 100, 1) var healing_amount: int = 6
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
var elite_reward_type: EliteRewardType = EliteRewardType.NONE
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
var _healing_pulse_remaining: float = 0.0
var _melee_weapon_visibility: float = 0.0
var _melee_weapon_attack_start_rotation: float = 0.0
var _melee_weapon_return_remaining: float = 0.0
var _melee_weapon_return_start_position: Vector2 = Vector2.ZERO
var _melee_weapon_return_start_rotation: float = 0.0
var _enemy_outline_material: ShaderMaterial
var _melee_weapon_outline_material: ShaderMaterial
var _melee_weapon_trails: Array[Sprite2D] = []
var _fantian_seal_immobilized_remaining: float = 0.0
var _fantian_seal_immobilized_position: Vector2 = Vector2.ZERO
var _fantian_seal_root_flash_remaining: float = 0.0
var _fantian_seal_root_release_remaining: float = 0.0
var _last_fantian_seal_root_volley_id: int = -1
var _temporary_health_readout_remaining: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	if _ordinary_health_equivalent <= 0:
		_ordinary_health_equivalent = maxi(max_health, 1)
	current_health = maxi(max_health, 1)
	_update_elite_identity()
	attack_warning_label.hide()
	immobilized_status_label.hide()
	health_value_label.hide()
	_melee_cooldown_remaining = _get_recovery_duration()
	_autonomous_time_remaining = maxf(autonomous_turn_interval, 0.2)
	_healing_time_remaining = maxf(healing_interval, 0.2)
	z_index = 12 if is_flying else 4
	_configure_sprite_animation()
	_configure_melee_weapon()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _combat_active or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	_autonomous_time_remaining -= delta
	if _autonomous_time_remaining <= 0.0:
		_autonomous_direction *= -1.0
		_autonomous_time_remaining = maxf(autonomous_turn_interval, 0.2)
	_update_fantian_seal_immobilization(delta)
	_update_temporary_health_readout(delta)
	if is_fantian_seal_immobilized():
		velocity = Vector2.ZERO
		_knockback_velocity = Vector2.ZERO
		global_position = _fantian_seal_immobilized_position
	else:
		var lateral_velocity := (
			_autonomous_direction * autonomous_lateral_speed
		)
		if archetype == EnemyArchetype.BOMBER:
			lateral_velocity += _get_bomber_tracking_velocity(player)
		velocity = Vector2(
			lateral_velocity,
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
		global_position.distance_to(_get_target_combat_position(target))
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
		_update_healing_pulse(delta)

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
	if (
		archetype == EnemyArchetype.BOMBER
		and _get_bomber_warning_progress() > 0.0
	):
		queue_redraw()
	_update_sprite_feedback()
	_update_melee_weapon_presentation(delta)


func _draw() -> void:
	if not _combat_active:
		return
	_draw_threat_indicator()
	_draw_fantian_seal_root_vfx()

	var has_authored_sprite := is_instance_valid(enemy_sprite)
	var body_color := _get_elite_identity_color() if is_elite else Color("d94b55")
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
	elif is_fantian_seal_immobilized():
		body_color = body_color.lerp(FANTIAN_ROOT_TINT, 0.3)
	if is_flying and not has_authored_sprite:
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
	if not has_authored_sprite:
		draw_circle(Vector2.ZERO, 22.0, Color(0.2, 0.02, 0.03, 0.8))
		draw_circle(Vector2.ZERO, 17.0, body_color)
		draw_line(
			Vector2(-10.0, -4.0),
			Vector2(10.0, -4.0),
			Color.WHITE,
			3.0
		)
		draw_line(Vector2.ZERO, Vector2(0.0, 9.0), Color("57141a"), 3.0)
	if uses_ranged_attack:
		draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 28, Color("84dcff"), 3.0)
	if archetype == EnemyArchetype.BOMBER and not has_authored_sprite:
		draw_circle(Vector2.ZERO, 8.0, Color("fff18a"))
	elif archetype == EnemyArchetype.HEALER:
		if not has_authored_sprite:
			draw_line(
				Vector2(-8.0, 0.0),
				Vector2(8.0, 0.0),
				Color.WHITE,
				4.0
			)
			draw_line(
				Vector2(0.0, -8.0),
				Vector2(0.0, 8.0),
				Color.WHITE,
				4.0
			)
		_draw_healing_pulse()

	var health_ratio := (
		float(current_health) / float(maxi(max_health, 1))
	)
	draw_rect(Rect2(-22.0, -34.0, 44.0, 5.0), Color(0.08, 0.02, 0.03, 0.9))
	draw_rect(
		Rect2(-22.0, -34.0, 44.0 * health_ratio, 5.0),
		Color("6aff86")
	)
	if _attack_flash_remaining > 0.0 and not _uses_melee_weapon():
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


func _configure_sprite_animation() -> void:
	if not is_instance_valid(enemy_sprite):
		return
	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation(&"default"):
		sprite_frames.remove_animation(&"default")
	var move_frame_count := (
		FLY_BOOMER_MOVE_FRAME_COUNT
		if is_flying and archetype == EnemyArchetype.BOMBER
		else ENEMY_MOVE_FRAME_COUNT
	)
	_add_atlas_animation(
		sprite_frames,
		&"move",
		_get_move_animation_atlas(),
		move_frame_count,
		ENEMY_MOVE_ANIMATION_SPEED,
		true
	)
	if archetype == EnemyArchetype.BOMBER:
		var explosion_atlas := (
			FLY_BOOMER_BOOM_ATLAS if is_flying else BOOMER_BOOM_ATLAS
		)
		_add_atlas_animation(
			sprite_frames,
			&"explode",
			explosion_atlas,
			BOOMER_BOOM_FRAME_COUNT,
			BOOMER_BOOM_ANIMATION_SPEED,
			false
		)
	enemy_sprite.sprite_frames = sprite_frames
	_update_enemy_outline()
	enemy_sprite.play(&"move")
	_update_sprite_feedback()


func _update_enemy_outline() -> void:
	if not is_instance_valid(enemy_sprite):
		return
	var outline_color := (
		_get_elite_identity_color() if is_elite else Color.TRANSPARENT
	)
	if (
		archetype == EnemyArchetype.BOMBER
		and _get_bomber_warning_progress()
			>= BOMBER_FAST_WARNING_PROGRESS
	):
		outline_color = BOMBER_WARNING_OUTLINE_COLOR
	if outline_color.a <= 0.0:
		enemy_sprite.material = null
		return
	if _enemy_outline_material == null:
		_enemy_outline_material = ShaderMaterial.new()
		_enemy_outline_material.shader = ENEMY_OUTLINE_SHADER
	_enemy_outline_material.set_shader_parameter(
		&"outline_color",
		outline_color
	)
	enemy_sprite.material = _enemy_outline_material


func _configure_melee_weapon() -> void:
	if not is_instance_valid(melee_weapon):
		return
	if not _uses_melee_weapon():
		melee_weapon.hide()
		_hide_melee_weapon_trails()
		_melee_weapon_visibility = 0.0
		return
	melee_weapon.texture = (
		ELITE_MELEE_WEAPON_TEXTURE
		if is_elite
		else NORMAL_MELEE_WEAPON_TEXTURE
	)
	if _melee_weapon_outline_material == null:
		_melee_weapon_outline_material = ShaderMaterial.new()
		_melee_weapon_outline_material.shader = ENEMY_OUTLINE_SHADER
	var enemy_world_scale := maxf(
		absf(global_transform.get_scale().x),
		0.01
	)
	_melee_weapon_outline_material.set_shader_parameter(
		&"outline_width",
		MELEE_WEAPON_OUTLINE_WORLD_WIDTH
			/ (MELEE_WEAPON_SCALE * enemy_world_scale)
	)
	melee_weapon.material = _melee_weapon_outline_material
	_set_melee_weapon_outline(Color.TRANSPARENT)
	_ensure_melee_weapon_trails()
	for trail in _melee_weapon_trails:
		trail.texture = melee_weapon.texture
	melee_weapon.position = MELEE_WEAPON_HOVER_POSITION
	melee_weapon.rotation = 0.0
	melee_weapon.scale = Vector2.ONE * MELEE_WEAPON_SCALE
	melee_weapon.modulate = Color(1.0, 1.0, 1.0, 0.0)
	melee_weapon.hide()


func _uses_melee_weapon() -> bool:
	return (
		archetype != EnemyArchetype.BOMBER
		and not uses_ranged_attack
	)


func _ensure_melee_weapon_trails() -> void:
	if not _melee_weapon_trails.is_empty():
		return
	for trail_index in MELEE_WEAPON_TRAIL_COUNT:
		var trail := Sprite2D.new()
		trail.name = "MeleeWeaponTrail%d" % (trail_index + 1)
		trail.z_index = melee_weapon.z_index - 1
		trail.hide()
		add_child(trail)
		_melee_weapon_trails.append(trail)


func _hide_melee_weapon_trails() -> void:
	for trail in _melee_weapon_trails:
		if is_instance_valid(trail):
			trail.hide()


func _set_melee_weapon_outline(color: Color) -> void:
	if _melee_weapon_outline_material == null:
		return
	_melee_weapon_outline_material.set_shader_parameter(
		&"outline_color",
		color
	)


func _get_melee_weapon_proximity() -> float:
	if not _uses_melee_weapon():
		return 0.0
	var target := _get_combat_target()
	if not is_instance_valid(target):
		return 0.0
	var attack_range := _get_attack_range()
	var distance_to_target := global_position.distance_to(
		_get_target_combat_position(target)
	)
	return 1.0 - clampf(
		(distance_to_target - attack_range)
			/ maxf(threat_indicator_margin, 1.0),
		0.0,
		1.0
	)


func _get_melee_weapon_orbit_radius() -> float:
	var local_tip_length := (
		MELEE_WEAPON_TIP_OFFSET_PIXELS * MELEE_WEAPON_SCALE
	)
	return maxf(
		_get_local_melee_range() - local_tip_length - 0.5,
		18.0
	)


func _get_melee_weapon_shake_strength(proximity: float) -> float:
	return clampf(
		(proximity - MELEE_WEAPON_SHAKE_START)
			/ (1.0 - MELEE_WEAPON_SHAKE_START),
		0.0,
		1.0
	)


func _update_melee_weapon_trails(
	attack_rotation: float,
	attack_progress: float
) -> void:
	var trail_strength := minf(
		clampf(attack_progress / 0.12, 0.0, 1.0),
		clampf((1.0 - attack_progress) / 0.12, 0.0, 1.0)
	)
	var orbit_radius := _get_melee_weapon_orbit_radius()
	for trail_index in _melee_weapon_trails.size():
		var trail := _melee_weapon_trails[trail_index]
		var trail_rotation := (
			attack_rotation
			- MELEE_WEAPON_TRAIL_ANGLE_STEP * float(trail_index + 1)
		)
		trail.position = (
			Vector2.UP.rotated(trail_rotation) * orbit_radius
		)
		trail.rotation = trail_rotation
		trail.scale = Vector2.ONE * (
			MELEE_WEAPON_SCALE
			* (1.0 - float(trail_index + 1) * 0.04)
		)
		trail.modulate = Color(
			1.0,
			0.34,
			0.18,
			maxf(
				0.26 - float(trail_index) * 0.055,
				0.08
			) * trail_strength
		)
		trail.visible = trail_strength > 0.0


func _update_melee_weapon_presentation(delta: float) -> void:
	if not is_instance_valid(melee_weapon):
		return
	if not _uses_melee_weapon():
		melee_weapon.hide()
		_hide_melee_weapon_trails()
		_melee_weapon_visibility = 0.0
		return
	var proximity := _get_melee_weapon_proximity()
	var shake_strength := _get_melee_weapon_shake_strength(proximity)
	var should_show := (
		proximity > 0.0
		or _is_attack_winding_up
		or _melee_weapon_return_remaining > 0.0
	)
	_melee_weapon_visibility = move_toward(
		_melee_weapon_visibility,
		1.0 if should_show else 0.0,
		delta / MELEE_WEAPON_SUMMON_DURATION
	)
	if _melee_weapon_visibility <= 0.0:
		melee_weapon.hide()
		_hide_melee_weapon_trails()
		_set_melee_weapon_outline(Color.TRANSPARENT)
		return
	melee_weapon.show()
	melee_weapon.modulate = Color(
		1.0,
		1.0,
		1.0,
		_melee_weapon_visibility
	)

	if _is_attack_winding_up:
		_melee_weapon_visibility = 1.0
		melee_weapon.modulate = Color.WHITE
		_melee_weapon_return_remaining = 0.0
		var attack_progress := get_attack_windup_progress()
		var attack_rotation := (
			_melee_weapon_attack_start_rotation
			+ TAU * attack_progress
		)
		melee_weapon.position = (
			Vector2.UP.rotated(attack_rotation)
			* _get_melee_weapon_orbit_radius()
		)
		melee_weapon.rotation = attack_rotation
		melee_weapon.scale = Vector2.ONE * (
			MELEE_WEAPON_SCALE
			* (1.0 + sin(attack_progress * PI) * 0.1)
		)
		var outline_pulse := 0.82 + 0.18 * sin(
			attack_progress * PI
		)
		_set_melee_weapon_outline(
			Color(
				MELEE_WEAPON_BRIGHT_OUTLINE,
				outline_pulse
			)
		)
		_update_melee_weapon_trails(
			attack_rotation,
			attack_progress
		)
		return

	_hide_melee_weapon_trails()
	var hover_position := (
		MELEE_WEAPON_HOVER_POSITION
		+ Vector2(0.0, sin(_indicator_time * 5.0) * 2.5)
	)
	var hover_rotation := sin(_indicator_time * 3.5) * 0.045
	_set_melee_weapon_outline(
		Color(MELEE_WEAPON_DARK_OUTLINE, shake_strength)
	)
	if _melee_weapon_return_remaining > 0.0:
		_melee_weapon_return_remaining = maxf(
			_melee_weapon_return_remaining - delta,
			0.0
		)
		var return_progress := 1.0 - (
			_melee_weapon_return_remaining
			/ MELEE_WEAPON_RETURN_DURATION
		)
		var eased_return := (
			return_progress
			* return_progress
			* (3.0 - 2.0 * return_progress)
		)
		melee_weapon.position = (
			_melee_weapon_return_start_position.lerp(
				hover_position,
				eased_return
			)
		)
		melee_weapon.rotation = lerp_angle(
			_melee_weapon_return_start_rotation,
			hover_rotation,
			eased_return
		)
		melee_weapon.scale = Vector2.ONE * MELEE_WEAPON_SCALE
		return

	var shake_offset := Vector2(
		sin(_indicator_time * 43.0),
		cos(_indicator_time * 37.0)
	) * (5.0 * shake_strength)
	melee_weapon.position = hover_position + shake_offset
	melee_weapon.rotation = (
		hover_rotation
		+ sin(_indicator_time * 57.0) * 0.13 * shake_strength
	)
	var summon_scale := (
		lerpf(0.5, 1.0, _melee_weapon_visibility)
		+ sin(_melee_weapon_visibility * PI) * 0.22
	)
	melee_weapon.scale = (
		Vector2.ONE * MELEE_WEAPON_SCALE * summon_scale
	)


func _get_move_animation_atlas() -> Texture2D:
	if is_flying and archetype == EnemyArchetype.BOMBER:
		return FLY_BOOMER_FLY_ATLAS
	if is_flying:
		return ELITE_FLY_ATLAS if is_elite else NORMAL_FLY_ATLAS
	if is_elite:
		return ELITE_WALK_ATLAS
	if archetype == EnemyArchetype.BOMBER:
		return BOOMER_WALK_ATLAS
	if archetype == EnemyArchetype.HEALER:
		return NORMAL_HEAL_WALK_ATLAS
	return NORMAL_WALK_ATLAS


func _add_atlas_animation(
	sprite_frames: SpriteFrames,
	animation_name: StringName,
	atlas: Texture2D,
	frame_count: int,
	speed: float,
	loop: bool
) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, speed)
	sprite_frames.set_animation_loop(animation_name, loop)
	for frame_index in frame_count:
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = atlas
		frame_texture.region = Rect2(
			float(frame_index * ENEMY_SPRITE_FRAME_SIZE),
			0.0,
			float(ENEMY_SPRITE_FRAME_SIZE),
			float(ENEMY_SPRITE_FRAME_SIZE)
		)
		sprite_frames.add_frame(animation_name, frame_texture)


func _update_sprite_feedback() -> void:
	if not is_instance_valid(enemy_sprite):
		return
	_update_enemy_outline()
	if _hit_flash_remaining > 0.0:
		enemy_sprite.self_modulate = Color("fff2a8")
		return
	if _is_attack_winding_up:
		var warning_pulse := 0.5 + 0.5 * sin(_indicator_time * 9.0)
		enemy_sprite.self_modulate = Color.WHITE.lerp(
			Color("fff0a6"),
			0.35 + warning_pulse * 0.35
		)
		return
	if archetype == EnemyArchetype.BOMBER:
		var warning_flash := _get_bomber_warning_flash()
		if warning_flash > 0.0:
			enemy_sprite.self_modulate = Color.WHITE.lerp(
				Color("ff3b24"),
				warning_flash
			)
			return
	if is_fantian_seal_immobilized():
		enemy_sprite.self_modulate = Color.WHITE.lerp(
			FANTIAN_ROOT_TINT,
			0.28
		)
		return
	enemy_sprite.self_modulate = Color.WHITE


func _get_bomber_warning_progress() -> float:
	if archetype != EnemyArchetype.BOMBER:
		return 0.0
	var target := _get_combat_target()
	if not is_instance_valid(target):
		return 0.0
	var trigger_radius := maxf(explosion_radius, 1.0)
	var warning_radius := (
		trigger_radius * BOMBER_WARNING_RANGE_MULTIPLIER
	)
	var distance_to_target := global_position.distance_to(
		_get_target_combat_position(target)
	)
	return 1.0 - clampf(
		(distance_to_target - trigger_radius)
			/ maxf(warning_radius - trigger_radius, 1.0),
		0.0,
		1.0
	)


func _get_bomber_warning_flash() -> float:
	var warning_progress := _get_bomber_warning_progress()
	if warning_progress <= 0.0:
		return 0.0
	var pulse_speed := lerpf(
		BOMBER_WARNING_SLOW_PULSE_SPEED,
		BOMBER_WARNING_FAST_PULSE_SPEED,
		warning_progress
	)
	var pulse := 0.5 + 0.5 * sin(_indicator_time * pulse_speed)
	return pulse * lerpf(0.22, 0.82, warning_progress)


func _update_melee_attack(
	delta: float,
	distance_to_target: float,
	target: Node2D
) -> void:
	if _is_attack_winding_up:
		if is_instance_valid(target):
			_attack_direction = global_position.direction_to(
				_get_target_combat_position(target)
			)
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
		_attack_direction = global_position.direction_to(
			_get_target_combat_position(target)
		)
	_melee_weapon_attack_start_rotation = (
		_attack_direction.angle() + PI * 0.5
	)
	_melee_weapon_visibility = 1.0
	_melee_weapon_return_remaining = 0.0
	attack_warning_label.show()
	_update_attack_warning_label()
	_update_sprite_feedback()
	queue_redraw()


func _finish_melee_attack(distance_to_target: float, target: Node2D) -> void:
	if _uses_melee_weapon() and is_instance_valid(melee_weapon):
		var final_rotation := (
			_melee_weapon_attack_start_rotation + TAU
		)
		_melee_weapon_return_start_position = (
			Vector2.UP.rotated(final_rotation)
			* _get_melee_weapon_orbit_radius()
		)
		_melee_weapon_return_start_rotation = final_rotation
		melee_weapon.position = _melee_weapon_return_start_position
		melee_weapon.rotation = final_rotation
		_melee_weapon_return_remaining = MELEE_WEAPON_RETURN_DURATION
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
	_update_sprite_feedback()
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
	if _uses_melee_weapon():
		return
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
	var distance_to_player := global_position.distance_to(
		_get_target_combat_position(target)
	)
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
		global_position.distance_squared_to(
			_get_target_combat_position(player)
		)
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


## Resolves the visible combat center for the player while keeping echoes and
## other future combat targets on their ordinary Node2D origins.
func _get_target_combat_position(target: Node2D) -> Vector2:
	if target is PlayerController:
		return (target as PlayerController).get_combat_anchor_position()
	if is_instance_valid(target):
		return target.global_position
	return global_position


func _get_bomber_tracking_velocity(target: Node2D) -> float:
	if not is_instance_valid(target) or bomber_tracking_speed <= 0.0:
		return 0.0
	var lateral_offset := (
		_get_target_combat_position(target).x - global_position.x
	)
	return clampf(
		lateral_offset,
		-bomber_tracking_speed,
		bomber_tracking_speed
	)


func _get_explosion_damage_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	if is_instance_valid(player):
		targets.append(player)
	for echo_node in get_tree().get_nodes_in_group("player_echoes"):
		if (
			echo_node is Node2D
			and echo_node.has_method("take_enemy_damage")
			and not targets.has(echo_node as Node2D)
		):
			targets.append(echo_node as Node2D)
	return targets


func _explode(_trigger_target: Node2D) -> void:
	if not _combat_active:
		return
	for damage_target in _get_explosion_damage_targets():
		if (
			global_position.distance_to(
				_get_target_combat_position(damage_target)
			)
			> explosion_damage_radius
		):
			continue
		if damage_target.has_method("take_enemy_damage"):
			damage_target.call(
				"take_enemy_damage",
				explosion_damage,
				self
			)
		elif damage_target is PlayerController:
			(damage_target as PlayerController).take_melee_damage(
				explosion_damage,
				self
			)
	_clear_fantian_seal_root_state()
	_combat_active = false
	collision_layer = 0
	collision_mask = 0
	if (
		is_instance_valid(enemy_sprite)
		and enemy_sprite.sprite_frames != null
		and enemy_sprite.sprite_frames.has_animation(&"explode")
	):
		enemy_sprite.self_modulate = Color.WHITE
		enemy_sprite.play(&"explode")
		var explosion_duration := (
			float(BOOMER_BOOM_FRAME_COUNT)
			/ BOOMER_BOOM_ANIMATION_SPEED
		)
		_begin_dissolve_disappearance(explosion_duration)
		return
	_begin_dissolve_disappearance()


func _begin_dissolve_disappearance(delay: float = 0.0) -> void:
	_is_attack_winding_up = false
	attack_warning_label.hide()
	elite_label.hide()
	melee_weapon.set_process(false)
	queue_redraw()

	var dissolve_material := ShaderMaterial.new()
	dissolve_material.shader = ENEMY_DISSOLVE_SHADER
	dissolve_material.set_shader_parameter(&"dissolve_amount", 0.0)
	enemy_sprite.material = dissolve_material
	melee_weapon.material = dissolve_material

	var dissolve_tween := create_tween()
	if delay > 0.0:
		dissolve_tween.tween_interval(delay)
	dissolve_tween.tween_callback(enemy_sprite.pause)
	dissolve_tween.tween_method(
		func(amount: float) -> void:
			dissolve_material.set_shader_parameter(
				&"dissolve_amount",
				amount
			),
		0.0,
		1.0,
		DEATH_DISSOLVE_DURATION
	)
	if is_instance_valid(enemy_shadow):
		dissolve_tween.parallel().tween_property(
			enemy_shadow,
			"modulate:a",
			0.0,
			DEATH_DISSOLVE_DURATION
		)
	dissolve_tween.tween_callback(queue_free)


func _update_healing(delta: float) -> void:
	_healing_time_remaining = maxf(_healing_time_remaining - delta, 0.0)
	if _healing_time_remaining > 0.0:
		return
	_healing_time_remaining = maxf(healing_interval, 0.2)
	_healing_pulse_remaining = HEALING_PULSE_DURATION
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


func _update_healing_pulse(delta: float) -> void:
	if _healing_pulse_remaining <= 0.0:
		return
	_healing_pulse_remaining = maxf(
		_healing_pulse_remaining - delta,
		0.0
	)
	queue_redraw()


func _draw_healing_pulse() -> void:
	if _healing_pulse_remaining <= 0.0:
		return
	var pulse_progress := 1.0 - clampf(
		_healing_pulse_remaining / HEALING_PULSE_DURATION,
		0.0,
		1.0
	)
	var expansion_progress := clampf(
		pulse_progress / HEALING_PULSE_EXPANSION_FRACTION,
		0.0,
		1.0
	)
	var eased_expansion := (
		expansion_progress
		* expansion_progress
		* (3.0 - 2.0 * expansion_progress)
	)
	var pulse_radius := lerpf(
		HEALING_PULSE_MINIMUM_RADIUS,
		_get_local_healing_radius(),
		eased_expansion
	)
	var ring_alpha := lerpf(0.7, 0.3, eased_expansion)
	var finish_progress := 0.0
	if pulse_progress > HEALING_PULSE_EXPANSION_FRACTION:
		finish_progress = clampf(
			(
				pulse_progress - HEALING_PULSE_EXPANSION_FRACTION
			) / (1.0 - HEALING_PULSE_EXPANSION_FRACTION),
			0.0,
			1.0
		)
		var soft_highlight := sin(finish_progress * PI)
		ring_alpha = (
			lerpf(0.3, 0.0, finish_progress)
			+ soft_highlight * 0.14
		)
		draw_circle(
			Vector2.ZERO,
			pulse_radius,
			Color(
				0.3,
				1.0,
				0.58,
				(1.0 - finish_progress) * 0.025
					+ soft_highlight * 0.018
			)
		)
	var pulse_color := Color(0.32, 1.0, 0.6, ring_alpha)
	draw_arc(
		Vector2.ZERO,
		pulse_radius,
		0.0,
		TAU,
		64,
		Color(pulse_color, ring_alpha * 0.24),
		10.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		pulse_radius,
		0.0,
		TAU,
		64,
		pulse_color,
		3.0,
		true
	)


func _get_local_healing_radius() -> float:
	var world_scale_x := maxf(absf(global_transform.get_scale().x), 0.01)
	return healing_radius / world_scale_x


func heal(amount: int) -> void:
	if not _combat_active or amount <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	queue_redraw()


## Applies one progression-gated aerial combat package. Ground-only healers
## reject this package and retain their Qi Refining combat tier.
func configure_flying(
	enemy_realm_index: int,
	ranged: bool,
	lateral_speed_value: float
) -> void:
	if archetype == EnemyArchetype.HEALER:
		is_flying = false
		uses_ranged_attack = false
		autonomous_lateral_speed = 0.0
		combat_realm_index = 0
		if is_node_ready():
			z_index = 4
			_configure_sprite_animation()
			_configure_melee_weapon()
			queue_redraw()
		return
	is_flying = true
	combat_realm_index = maxi(enemy_realm_index, 1)
	uses_ranged_attack = ranged
	autonomous_lateral_speed = maxf(lateral_speed_value, 0.0)
	if is_node_ready():
		z_index = 12
		_configure_sprite_animation()
		_configure_melee_weapon()
		queue_redraw()


## Selects a normal, self-destruct, or healing role. Healing is restricted to
## ordinary ground enemies; elite requests fall back to melee.
func configure_archetype(new_archetype: EnemyArchetype) -> void:
	archetype = (
		EnemyArchetype.MELEE
		if is_elite and new_archetype == EnemyArchetype.HEALER
		else new_archetype
	)
	if archetype == EnemyArchetype.HEALER:
		is_flying = false
		uses_ranged_attack = false
		autonomous_lateral_speed = 0.0
		combat_realm_index = 0
	if is_node_ready():
		current_health = max_health
		z_index = 12 if is_flying else 4
		_configure_sprite_animation()
		_configure_melee_weapon()
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
	visual_scale: float,
	reward_type: int = EliteRewardType.WEAPON
) -> void:
	_ordinary_health_equivalent = maxi(max_health, 1)
	is_elite = true
	if archetype == EnemyArchetype.HEALER:
		archetype = EnemyArchetype.MELEE
	elite_reward_type = clampi(
		reward_type,
		EliteRewardType.WEAPON,
		EliteRewardType.POWER_FRAGMENT
	)
	max_health = maxi(
		roundi(float(max_health) * maxf(health_multiplier, 1.0)),
		max_health + 1
	)
	melee_attack_range *= maxf(attack_range_multiplier, 1.0)
	scale = Vector2.ONE * maxf(visual_scale, 1.0)
	if is_node_ready():
		current_health = max_health
		_update_elite_identity()
		_configure_sprite_animation()
		_configure_melee_weapon()
		queue_redraw()


func is_elite_enemy() -> bool:
	return is_elite


## Returns the reward category advertised by this elite's label and outline.
func get_elite_reward_type() -> EliteRewardType:
	return elite_reward_type


func _update_elite_identity() -> void:
	if not is_instance_valid(elite_label):
		return
	elite_label.visible = is_elite
	if not is_elite:
		return
	elite_label.text = (
		"武器精英"
		if elite_reward_type == EliteRewardType.WEAPON
		else "强化精英"
	)
	elite_label.add_theme_color_override(
		"font_color",
		_get_elite_identity_color()
	)


func _get_elite_identity_color() -> Color:
	return (
		Color("55d8ff")
		if elite_reward_type == EliteRewardType.WEAPON
		else Color("d98cff")
	)


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


## Anchors a surviving enemy to one absolute world position. The effect only
## blocks movement; attacks and archetype abilities continue updating. A
## non-negative volley ID may apply the root only once, preventing duplicate
## seals from refreshing the same enemy until the next volley.
func apply_fantian_seal_immobilize(
	duration: float = 0.3,
	volley_id: int = -1
) -> bool:
	if not _combat_active or duration <= 0.0:
		return false
	if (
		volley_id >= 0
		and volley_id == _last_fantian_seal_root_volley_id
	):
		return false
	if volley_id >= 0:
		_last_fantian_seal_root_volley_id = volley_id
	_fantian_seal_immobilized_remaining = maxf(
		_fantian_seal_immobilized_remaining,
		duration
	)
	_fantian_seal_immobilized_position = global_position
	_fantian_seal_root_flash_remaining = FANTIAN_ROOT_FLASH_DURATION
	_fantian_seal_root_release_remaining = 0.0
	_knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	_update_fantian_seal_immobilized_status()
	queue_redraw()
	return true


func is_fantian_seal_immobilized() -> bool:
	return (
		_combat_active
		and _fantian_seal_immobilized_remaining > 0.0
	)


func get_fantian_seal_immobilized_remaining() -> float:
	return _fantian_seal_immobilized_remaining


## Returns whether the anchored rune, application glyph, or release fracture is
## currently visible for focused gameplay and presentation validation.
func is_fantian_seal_root_vfx_active() -> bool:
	return (
		is_fantian_seal_immobilized()
		or _fantian_seal_root_flash_remaining > 0.0
		or _fantian_seal_root_release_remaining > 0.0
	)


func _clear_fantian_seal_root_state() -> void:
	_fantian_seal_immobilized_remaining = 0.0
	_fantian_seal_root_flash_remaining = 0.0
	_fantian_seal_root_release_remaining = 0.0
	_last_fantian_seal_root_volley_id = -1
	if is_instance_valid(immobilized_status_label):
		immobilized_status_label.hide()
		immobilized_status_label.scale = Vector2.ONE
		immobilized_status_label.modulate = Color.WHITE
	_temporary_health_readout_remaining = 0.0
	if is_instance_valid(health_value_label):
		health_value_label.hide()


func _update_fantian_seal_immobilization(delta: float) -> void:
	var was_immobilized := _fantian_seal_immobilized_remaining > 0.0
	if was_immobilized:
		_fantian_seal_immobilized_remaining = maxf(
			_fantian_seal_immobilized_remaining - delta,
			0.0
		)
	_fantian_seal_root_flash_remaining = maxf(
		_fantian_seal_root_flash_remaining - delta,
		0.0
	)
	if (
		was_immobilized
		and _fantian_seal_immobilized_remaining <= 0.0
	):
		_fantian_seal_root_release_remaining = FANTIAN_ROOT_RELEASE_DURATION
	elif _fantian_seal_root_release_remaining > 0.0:
		_fantian_seal_root_release_remaining = maxf(
			_fantian_seal_root_release_remaining - delta,
			0.0
		)
	_update_fantian_seal_immobilized_status()
	if (
		was_immobilized
		or _fantian_seal_root_flash_remaining > 0.0
		or _fantian_seal_root_release_remaining > 0.0
	):
		queue_redraw()


func _update_fantian_seal_immobilized_status() -> void:
	if not is_instance_valid(immobilized_status_label):
		return
	var active := is_fantian_seal_immobilized()
	var releasing := (
		not active
		and _fantian_seal_root_release_remaining > 0.0
	)
	immobilized_status_label.visible = active or releasing
	if not immobilized_status_label.visible:
		immobilized_status_label.scale = Vector2.ONE
		immobilized_status_label.modulate = Color.WHITE
		return
	immobilized_status_label.text = "定"
	if active:
		var flash_progress := 1.0 - clampf(
			_fantian_seal_root_flash_remaining / FANTIAN_ROOT_FLASH_DURATION,
			0.0,
			1.0
		)
		immobilized_status_label.scale = Vector2.ONE * lerpf(
			1.28,
			1.0,
			flash_progress
		)
		immobilized_status_label.modulate = Color.WHITE
		return
	var release_alpha := clampf(
		_fantian_seal_root_release_remaining / FANTIAN_ROOT_RELEASE_DURATION,
		0.0,
		1.0
	)
	immobilized_status_label.scale = Vector2.ONE * lerpf(
		1.22,
		1.0,
		release_alpha
	)
	immobilized_status_label.modulate = Color(
		1.0,
		1.0,
		1.0,
		release_alpha
	)


## Shows exact survivor health briefly after a Fantian Seal hit. The readout
## remains visible throughout the root and stays above weapon presentation.
func show_temporary_health_readout(duration: float = 0.75) -> void:
	if not _combat_active or duration <= 0.0:
		return
	_temporary_health_readout_remaining = maxf(
		_temporary_health_readout_remaining,
		duration
	)
	_update_temporary_health_readout(0.0)


func is_temporary_health_readout_visible() -> bool:
	return (
		is_instance_valid(health_value_label)
		and health_value_label.visible
	)


func _update_temporary_health_readout(delta: float) -> void:
	_temporary_health_readout_remaining = maxf(
		_temporary_health_readout_remaining - delta,
		0.0
	)
	if not is_instance_valid(health_value_label):
		return
	health_value_label.visible = (
		_combat_active
		and (
			_temporary_health_readout_remaining > 0.0
			or is_fantian_seal_immobilized()
		)
	)
	if not health_value_label.visible:
		return
	health_value_label.text = "%d/%d" % [
		current_health,
		maxi(max_health, 1),
	]


func _draw_fantian_seal_root_vfx() -> void:
	if not is_fantian_seal_root_vfx_active():
		return
	var active := is_fantian_seal_immobilized()
	var alpha := 1.0
	var release_progress := 0.0
	if not active:
		alpha = clampf(
			_fantian_seal_root_release_remaining
				/ FANTIAN_ROOT_RELEASE_DURATION,
			0.0,
			1.0
		)
		release_progress = 1.0 - alpha
	var pulse := 0.5 + 0.5 * sin(_indicator_time * IMMOBILIZED_STATUS_PULSE_SPEED)
	var center := Vector2(0.0, 28.0)
	var half_size := Vector2(
		26.0 + release_progress * 10.0,
		10.0 + release_progress * 4.0
	)
	var corners := PackedVector2Array([
		center + Vector2(-half_size.x, 0.0),
		center + Vector2(0.0, -half_size.y),
		center + Vector2(half_size.x, 0.0),
		center + Vector2(0.0, half_size.y),
		center + Vector2(-half_size.x, 0.0),
	])
	draw_colored_polygon(
		PackedVector2Array([
			corners[0],
			corners[1],
			corners[2],
			corners[3],
		]),
		Color(FANTIAN_ROOT_RUNE_COLOR, alpha * (0.07 + pulse * 0.04))
	)
	draw_polyline(
		corners,
		Color(FANTIAN_ROOT_RUNE_COLOR, alpha * (0.72 + pulse * 0.2)),
		3.0,
		true
	)
	var bracket_length := 8.0
	for corner_index in 4:
		var corner := corners[corner_index]
		var next_corner := corners[(corner_index + 1) % 4]
		var previous_corner := corners[(corner_index + 3) % 4]
		draw_line(
			corner,
			corner.move_toward(next_corner, bracket_length),
			Color(0.82, 0.98, 1.0, alpha),
			4.0,
			true
		)
		draw_line(
			corner,
			corner.move_toward(previous_corner, bracket_length),
			Color(0.82, 0.98, 1.0, alpha),
			4.0,
			true
		)
	if active:
		draw_line(
			center + Vector2(-13.0, -5.0),
			Vector2(-8.0, -15.0),
			Color(FANTIAN_ROOT_RUNE_COLOR, 0.46 + pulse * 0.18),
			2.0,
			true
		)
		draw_line(
			center + Vector2(13.0, -5.0),
			Vector2(8.0, -15.0),
			Color(FANTIAN_ROOT_RUNE_COLOR, 0.46 + pulse * 0.18),
			2.0,
			true
		)


## Applies player damage exactly once per hit and removes the enemy after its
## health reaches zero. Critical metadata changes presentation only.
func take_melee_damage(amount: int, is_critical: bool = false) -> void:
	if not _combat_active or amount <= 0:
		return
	if is_critical:
		_spawn_critical_hit_vfx(amount)
	current_health = maxi(current_health - amount, 0)
	_hit_flash_remaining = 0.2 if is_critical else 0.12
	_update_sprite_feedback()
	queue_redraw()
	if current_health > 0:
		return
	var defeat_position := global_position
	var defeat_velocity := velocity
	_combat_active = false
	_clear_fantian_seal_root_state()
	collision_layer = 0
	collision_mask = 0
	defeated.emit(defeat_position, defeat_velocity)
	_begin_dissolve_disappearance()


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
		_clear_fantian_seal_root_state()
		_is_attack_winding_up = false
		_attack_windup_remaining = 0.0
		_melee_weapon_visibility = 0.0
		_melee_weapon_return_remaining = 0.0
		if is_node_ready():
			attack_warning_label.hide()
			melee_weapon.hide()
			_hide_melee_weapon_trails()
			_set_melee_weapon_outline(Color.TRANSPARENT)
		queue_redraw()
