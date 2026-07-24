class_name PlayerController
extends CharacterBody2D

signal melee_damage_received(amount: float)
signal lifespan_decay_multiplier_changed(multiplier: float)
signal equipment_changed(
	technique_name: String,
	equipment_name: String,
	damage: int
)
signal equipment_inventory_changed(entries: Array[String], current_index: int)
## Publishes fresh read-only player-wide and current-weapon snapshots whenever
## equipment or cultivation progression changes.
signal combat_stats_changed(
	global_stats: PlayerGlobalCombatStatsResource,
	weapon_stats: WeaponCombatStatsResource
)

const WeaponDataResource = preload(
	"res://game/scripts/gameplay/weapon_data.gd"
)
const DEFAULT_STARTING_WEAPON_DATA: WeaponDataResource = preload(
	"res://game/resources/great_strength_palm.tres"
)
const CultivationTypesResource = preload(
	"res://game/scripts/gameplay/cultivation_types.gd"
)
const PlayerGlobalCombatStatsResource = preload(
	"res://game/scripts/gameplay/player_global_combat_stats.gd"
)
const WeaponCombatStatsResource = preload(
	"res://game/scripts/gameplay/weapon_combat_stats.gd"
)
const CombatStatsResolverResource = preload(
	"res://game/scripts/gameplay/combat_stats_resolver.gd"
)
const PlayerCombatConfigResource = preload(
	"res://game/scripts/gameplay/player_combat_config.gd"
)
const AttackDamageResultResource = preload(
	"res://game/scripts/gameplay/attack_damage_result.gd"
)
const DEFAULT_PLAYER_COMBAT_CONFIG: PlayerCombatConfigResource = preload(
	"res://game/resources/player_combat_config.tres"
)

@export_category("Forward Movement")
## Normal automatic forward travel speed in world pixels per second.
@export var base_forward_speed: float = 260.0
## Target forward speed, in pixels per second, while speed_up is held.
@export var boosted_forward_speed: float = 420.0
## Target forward speed, in pixels per second, while slow_down is held. Values
## at or below zero are clamped to preserve forward movement.
@export var slowed_forward_speed: float = 110.0
## Rate, in pixels per second squared, used to approach forward speed targets.
@export var forward_acceleration: float = 360.0

@export_category("Lateral Movement")
## Immediate left/right speed in world pixels per second. Horizontal input is
## applied directly with no acceleration or release inertia.
@export var lateral_speed: float = 300.0
## Playable half-width measured from road center in world pixels. InfiniteWorld
## replaces this at startup with its shared WorldChunkConfig road width.
@export var road_half_width: float = 224.0
## Margin, in world pixels, kept between the player's center and each road edge.
@export var horizontal_clearance: float = 22.0

@export_category("Starting Technique")
## Shared definition equipped at the beginning of every run. Its display name
## is also presented as the player's cultivation technique on the HUD.
@export var starting_weapon_data: WeaponDataResource = (
	DEFAULT_STARTING_WEAPON_DATA
)

@export_category("Combat Configuration")
## Designer-authored source of truth for player-wide base combat stats and
## global safety limits. Runtime snapshots read this Resource without mutating it.
@export var combat_config: PlayerCombatConfigResource = (
	DEFAULT_PLAYER_COMBAT_CONFIG
)

@export_category("Collectible Attraction")
## Invisible starting radius, in world pixels, that attracts qi and equipment.
## It is independent from the visible attack range.
@export_range(24.0, 240.0, 1.0) var base_attraction_range: float = 72.0
## Additional invisible attraction radius gained per cultivation level.
@export_range(0.0, 64.0, 1.0) var attraction_range_increase_per_level: float = 10.0
## Speed, in world pixels per second, at which collectibles home to the player.
@export var collectible_attraction_speed: float = 360.0

@export_category("Level-up Effect")
## Duration, in seconds, of the aura shown when cultivation level increases.
@export_range(0.2, 2.0, 0.05) var level_up_effect_duration: float = 0.8
## Final radius, in world pixels, reached by the expanding level-up ring.
@export_range(36.0, 140.0, 1.0) var level_up_effect_radius: float = 76.0
## Duration, in seconds, of the larger effect played after surviving any
## cultivation-realm breakthrough tribulation.
@export_range(0.5, 5.0, 0.1) var breakthrough_effect_duration: float = 2.4
## Outer radius, in world pixels, of the breakthrough rings and light rays.
@export_range(80.0, 260.0, 1.0) var breakthrough_effect_radius: float = 156.0

@export_category("Damage Feedback")
## Duration, in seconds, of the player blink, shake, expanding hit burst, and
## floating lifespan-loss number after taking direct damage.
@export_range(0.2, 1.5, 0.05) var damage_feedback_duration: float = 0.55
## Final radius, in world pixels, reached by the direct-damage impact burst.
## Larger values make hits more prominent among nearby combat effects.
@export_range(36.0, 120.0, 1.0) var damage_feedback_radius: float = 68.0

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var attraction_area: Area2D = $AttractionArea
@onready var attraction_shape: CollisionShape2D = (
	$AttractionArea/CollisionShape2D
)
@onready var character_sprite: AnimatedSprite2D = $CharacterSprite
@onready var damage_taken_label: Label = $DamageTakenLabel

var current_forward_speed: float = 0.0
var distance_traveled: float = 0.0
var current_attraction_range: float = 72.0
var road_center_x: float = 0.0
var current_cultivation_level: int = 1

var _movement_enabled: bool = true
var _attack_cooldown_remaining: float = 0.0
var _attack_flash_remaining: float = 0.0
var _damage_flash_remaining: float = 0.0
var _last_damage_amount: float = 0.0
var _character_sprite_rest_position: Vector2 = Vector2.ZERO
var _character_sprite_rest_modulate: Color = Color.WHITE
var _dao_attack_remaining: float = 0.0
var _companion_phase: float = 0.0
var _equipment_inventory: Array[Dictionary] = []
var _current_equipment_index: int = 0
var _temporary_lateral_bounds_enabled: bool = false
var _temporary_lateral_min_x: float = 0.0
var _temporary_lateral_max_x: float = 0.0
var _last_lifespan_decay_multiplier: float = 1.0
var _pending_flying_swords: int = 0
var _flying_sword_sequence_total: int = 0
var _flying_sword_sequence_launched: int = 0
var _flying_sword_sequence_damage: int = 1
var _flying_sword_sequence_is_critical: bool = false
var _flying_sword_sequence_timer: float = 0.0
var _level_up_effect_remaining: float = 0.0
var _breakthrough_effect_remaining: float = 0.0
var _qiankun_ring_in_flight: bool = false
var _cultivation_resources: RunResources
var _global_combat_stats: PlayerGlobalCombatStatsResource = (
	PlayerGlobalCombatStatsResource.new()
)
var _current_weapon_combat_stats: WeaponCombatStatsResource = (
	WeaponCombatStatsResource.new()
)


func _ready() -> void:
	_movement_enabled = true
	_character_sprite_rest_position = character_sprite.position
	_character_sprite_rest_modulate = character_sprite.modulate
	damage_taken_label.hide()
	current_forward_speed = maxf(base_forward_speed, 1.0)
	_last_lifespan_decay_multiplier = get_lifespan_decay_multiplier()
	current_attraction_range = base_attraction_range
	if combat_config == null:
		push_error("Player combat_config must contain a PlayerCombatConfig.")
		combat_config = DEFAULT_PLAYER_COMBAT_CONFIG
	if starting_weapon_data == null or not starting_weapon_data.is_valid_definition():
		push_error("Player starting_weapon_data must contain a valid WeaponData.")
		starting_weapon_data = DEFAULT_STARTING_WEAPON_DATA
	_equipment_inventory = [
		_create_equipment(
			starting_weapon_data,
			starting_weapon_data.minimum_damage
		)
	]
	_current_equipment_index = 0
	_rebuild_combat_stats()
	_apply_attack_range()
	_apply_attraction_range()
	_publish_equipment()
	queue_redraw()


func _process(delta: float) -> void:
	_update_visual_state(delta)


func _input(event: InputEvent) -> void:
	var tab_pressed: bool = (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_TAB
	)
	if (
		not _movement_enabled
		or (
			not tab_pressed
			and not event.is_action_pressed("switch_equipment")
		)
	):
		return
	cycle_equipment()
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not _movement_enabled:
		velocity = Vector2.ZERO
		return

	var lateral_input := Input.get_axis("move_left", "move_right")
	velocity.x = lateral_input * lateral_speed

	var target_forward_speed := _get_target_forward_speed()
	current_forward_speed = move_toward(
		current_forward_speed,
		target_forward_speed,
		forward_acceleration * delta
	)
	current_forward_speed = maxf(current_forward_speed, 1.0)
	_publish_lifespan_decay_multiplier()
	velocity.y = -current_forward_speed

	move_and_slide()
	var lateral_bounds := get_active_lateral_bounds()
	global_position.x = clampf(
		global_position.x,
		lateral_bounds.x,
		lateral_bounds.y
	)
	distance_traveled += current_forward_speed * delta
	_update_weapon_attack(delta)
	_attract_collectibles(delta)


func _draw() -> void:
	var attack_range := get_current_attack_range()
	var range_color := _get_current_range_color()
	draw_circle(Vector2.ZERO, attack_range, Color(range_color, 0.035))
	draw_arc(
		Vector2.ZERO,
		attack_range,
		0.0,
		TAU,
		80,
		Color(range_color, 0.52),
		2.0,
		true
	)

	_draw_weapon_companions()
	if _attack_flash_remaining > 0.0:
		draw_arc(
			Vector2.ZERO,
			attack_range,
			-PI * 0.9,
			PI * 0.1,
			28,
			Color(1.0, 0.88, 0.35, 0.95),
			5.0,
			true
		)
	if _dao_attack_remaining > 0.0:
		var progress := 1.0 - _dao_attack_remaining / 0.28
		var dao_angle := progress * TAU - PI * 0.5
		var orbit_count := get_dao_orbit_count()
		for orbit_index in orbit_count:
			var orbit_angle := (
				dao_angle
				+ TAU * float(orbit_index) / float(orbit_count)
			)
			var orbit_radius := get_dao_orbit_radius(orbit_index)
			var dao_position := (
				Vector2.from_angle(orbit_angle) * orbit_radius
			)
			var orbit_color := Color(1.0, 0.72, 0.18, 0.9).lerp(
				Color(1.0, 0.94, 0.48, 0.95),
				float(orbit_index) / float(maxi(orbit_count - 1, 1))
			)
			draw_arc(
				Vector2.ZERO,
				orbit_radius,
				orbit_angle - 1.15,
				orbit_angle,
				20,
				orbit_color,
				6.0,
				true
			)
			_draw_dao(
				dao_position,
				orbit_angle + PI * 0.5,
				true
			)
	if _damage_flash_remaining > 0.0:
		_draw_damage_feedback()
	if _level_up_effect_remaining > 0.0:
		_draw_level_up_effect()
	if _breakthrough_effect_remaining > 0.0:
		_draw_breakthrough_effect()


## Enables or stops player locomotion and combat without resetting run state.
func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
	if not _movement_enabled:
		velocity = Vector2.ZERO
		_cancel_flying_sword_sequence()


## Receives direct damage and reports its cultivation-adjusted amount to the
## run resource owner. Known nearby sources receive 精 close-range mitigation;
## source-less hazards preserve their authored damage.
func take_melee_damage(amount: float, source: Node2D = null) -> void:
	if not _movement_enabled or amount <= 0.0:
		return
	var resolved_amount := amount
	if (
		is_instance_valid(source)
		and global_position.distance_to(source.global_position)
			<= _global_combat_stats.close_range_mitigation_radius
	):
		resolved_amount *= (
			1.0 - _global_combat_stats.close_range_damage_reduction
		)
	_last_damage_amount = resolved_amount
	_damage_flash_remaining = maxf(damage_feedback_duration, 0.01)
	damage_taken_label.text = "-%.1f 寿元" % resolved_amount
	damage_taken_label.show()
	_update_damage_feedback_presentation()
	queue_redraw()
	melee_damage_received.emit(resolved_amount)


## Returns whether the player-centered direct-damage reaction is active.
func is_damage_feedback_active() -> bool:
	return _damage_flash_remaining > 0.0


## Keeps only the strongest collected copy of each weapon type. A new or
## improved weapon is equipped immediately; weaker duplicates are discarded.
func collect_weapon(
	weapon_data: WeaponDataResource,
	damage: int
) -> bool:
	if (
		weapon_data == null
		or not weapon_data.is_valid_definition()
		or damage <= 0
	):
		return false

	var existing_index := _find_equipment_index(weapon_data.weapon_id)
	var equipment := _create_equipment(weapon_data, damage)

	if existing_index >= 0:
		var existing_damage := int(_equipment_inventory[existing_index]["damage"])
		if existing_damage >= damage:
			return false
		_equipment_inventory[existing_index] = equipment
		_current_equipment_index = existing_index
	else:
		_equipment_inventory.append(equipment)
		_current_equipment_index = _equipment_inventory.size() - 1
	_on_current_equipment_changed()
	return true


## Cycles the equipped entry in collection order. Bound to Tab by default.
func cycle_equipment() -> void:
	if _equipment_inventory.size() <= 1:
		return
	_current_equipment_index = (
		_current_equipment_index + 1
	) % _equipment_inventory.size()
	_on_current_equipment_changed()


func get_technique_name() -> String:
	return (
		starting_weapon_data.display_name
		if starting_weapon_data != null
		else ""
	)


func get_weapon_name() -> String:
	return _get_current_weapon_data().display_name


func get_current_weapon_damage() -> int:
	return _current_weapon_combat_stats.resolved_damage


func get_current_attack_range() -> float:
	return _current_weapon_combat_stats.attack_range


## Returns the latest player-wide read-only combat snapshot.
func get_global_combat_stats() -> PlayerGlobalCombatStatsResource:
	return _global_combat_stats


## Returns the latest read-only snapshot for the equipped weapon.
func get_current_weapon_combat_stats() -> WeaponCombatStatsResource:
	return _current_weapon_combat_stats


## Connects final weapon-stat calculation to the existing run-state owner.
## Progression remains in RunResources; this class only consumes snapshots.
func bind_cultivation(resources: RunResources) -> void:
	if (
		_cultivation_resources != null
		and _cultivation_resources.cultivation_stats_changed.is_connected(
			_on_cultivation_stats_changed
		)
	):
		_cultivation_resources.cultivation_stats_changed.disconnect(
			_on_cultivation_stats_changed
		)
	_cultivation_resources = resources
	if _cultivation_resources != null:
		_cultivation_resources.cultivation_stats_changed.connect(
			_on_cultivation_stats_changed
		)
	_on_cultivation_stats_changed(
		CultivationTypesResource.CultivationType.JING,
		0
	)


func get_current_attack_interval() -> float:
	return _current_weapon_combat_stats.attack_interval


func get_current_projectile_speed_multiplier() -> float:
	return _current_weapon_combat_stats.projectile_speed_multiplier


## Returns the equipped weapon's total delivery count after global bonuses.
func get_current_delivery_count() -> int:
	return _current_weapon_combat_stats.delivery_count


func get_current_aoe_radius() -> float:
	return _current_weapon_combat_stats.aoe_radius


## Returns the immutable shared definition for the currently equipped weapon.
func get_current_weapon_data() -> WeaponDataResource:
	return _get_current_weapon_data()


## Dao uses its original single orbit; cultivation now modifies generic stats
## rather than adding weapon-specific legacy paths.
func get_dao_orbit_count() -> int:
	return 1


## Returns a stable radius for one dao path. Existing paths keep their radius
## when a later fragment adds the next outer path.
func get_dao_orbit_radius(orbit_index: int) -> float:
	return 52.0 + float(maxi(orbit_index, 0)) * 12.0


## Returns the number of projectiles launched by one flying-sword volley.
func get_flying_sword_projectile_count() -> int:
	return get_current_delivery_count()


## Returns extra enemy-to-enemy bounces before the Universe Ring comes back.
func get_qiankun_ring_bounce_count() -> int:
	return maxi(get_current_delivery_count() - 1, 0)


func is_qiankun_ring_in_flight() -> bool:
	return _qiankun_ring_in_flight


## Returns swords still waiting to launch in the current sequential volley.
func get_pending_flying_sword_count() -> int:
	return _pending_flying_swords


## Returns the number of idle weapons visibly accompanying the player.
## Equipped weapons always use one companion regardless of upgrade level.
func get_visible_companion_weapon_count() -> int:
	var attack_kind := _get_current_weapon_data().attack_kind
	if (
		attack_kind == WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM
		or attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING
			and _qiankun_ring_in_flight
	):
		return 0
	return 1


func is_level_up_effect_active() -> bool:
	return _level_up_effect_remaining > 0.0


## Starts the elaborate aura reserved for a successful realm breakthrough.
func play_breakthrough_effect() -> void:
	_breakthrough_effect_remaining = maxf(
		breakthrough_effect_duration,
		0.01
	)
	queue_redraw()


func is_breakthrough_effect_active() -> bool:
	return _breakthrough_effect_remaining > 0.0


func get_attraction_range() -> float:
	return current_attraction_range


## Returns lifespan-decay scaling from actual forward speed relative to normal
## speed. Boosting raises it, while slowing never reduces baseline decay.
func get_lifespan_decay_multiplier() -> float:
	return 1.0
	#return maxf(
		#current_forward_speed / maxf(base_forward_speed, 1.0),
		#1.0
	#)


func get_equipment_inventory_entries() -> Array[String]:
	var entries: Array[String] = []
	for index in _equipment_inventory.size():
		var equipment := _equipment_inventory[index]
		var weapon_data := equipment["data"] as WeaponDataResource
		var marker := "▶ " if index == _current_equipment_index else "  "
		entries.append(
			"%s%s  伤害 %d" % [
				marker,
				weapon_data.display_name,
					_get_equipment_damage(equipment),
			]
		)
	return entries


## Temporarily replaces the main-road horizontal clamp while the player is
## alongside an exterior branch road.
func set_temporary_lateral_bounds(minimum_x: float, maximum_x: float) -> void:
	_temporary_lateral_min_x = minf(minimum_x, maximum_x)
	_temporary_lateral_max_x = maxf(minimum_x, maximum_x)
	_temporary_lateral_bounds_enabled = true


## Removes temporary connector bounds and restores the active-route clamp.
func clear_temporary_lateral_bounds() -> void:
	_temporary_lateral_bounds_enabled = false


## Moves the normal infinite-road clamp to a newly committed branch center.
func set_road_center_x(value: float) -> void:
	road_center_x = value
	_temporary_lateral_bounds_enabled = false


func get_active_lateral_bounds() -> Vector2:
	if _temporary_lateral_bounds_enabled:
		return Vector2(
			_temporary_lateral_min_x,
			_temporary_lateral_max_x
		)
	return Vector2(
		road_center_x - road_half_width + horizontal_clearance,
		road_center_x + road_half_width - horizontal_clearance
	)


## Overall Qi cultivation continues to expand collectible attraction. The
## independent 精/气/神 tracks are consumed through bind_cultivation().
func apply_cultivation_level(level: int) -> void:
	var previous_level := current_cultivation_level
	current_cultivation_level = maxi(level, 1)
	current_attraction_range = (
		base_attraction_range
		+ float(current_cultivation_level - 1)
			* attraction_range_increase_per_level
	)
	_apply_attraction_range()
	if is_node_ready() and not _equipment_inventory.is_empty():
		_rebuild_combat_stats()
		_apply_attack_range()
		_publish_equipment()
	if current_cultivation_level > previous_level:
		_level_up_effect_remaining = maxf(level_up_effect_duration, 0.01)
	queue_redraw()


func _update_weapon_attack(delta: float) -> void:
	_attack_cooldown_remaining = maxf(
		_attack_cooldown_remaining - delta,
		0.0
	)
	if _pending_flying_swords > 0:
		_flying_sword_sequence_timer -= delta
		if _flying_sword_sequence_timer <= 0.0:
			_launch_next_flying_sword()
		return
	if _attack_cooldown_remaining > 0.0:
		return

	var targets := _get_attack_targets()
	if targets.is_empty():
		return
	var weapon_data := _get_current_weapon_data()
	var attack_kind := weapon_data.attack_kind
	if (
		attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING
		and _qiankun_ring_in_flight
	):
		return
	var attack_damage := _roll_current_attack_damage()

	if attack_kind == WeaponDataResource.AttackKind.DAO:
		for enemy in targets:
			enemy.take_melee_damage(
				attack_damage.damage,
				attack_damage.is_critical
			)
		_dao_attack_remaining = 0.28
	elif attack_kind == WeaponDataResource.AttackKind.FLYING_SWORD:
		_begin_flying_sword_sequence(attack_damage)
	elif attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING:
		_launch_qiankun_ring(targets[0], attack_damage)
	else:
		targets[0].take_melee_damage(
			attack_damage.damage,
			attack_damage.is_critical
		)
		_attack_flash_remaining = 0.12

	_attack_cooldown_remaining = get_current_attack_interval()
	queue_redraw()


func _begin_flying_sword_sequence(
	attack_damage: AttackDamageResultResource
) -> void:
	_flying_sword_sequence_total = get_flying_sword_projectile_count()
	_pending_flying_swords = _flying_sword_sequence_total
	_flying_sword_sequence_launched = 0
	_flying_sword_sequence_damage = maxi(attack_damage.damage, 1)
	_flying_sword_sequence_is_critical = attack_damage.is_critical
	_flying_sword_sequence_timer = 0.0
	_launch_next_flying_sword()


func _launch_next_flying_sword() -> void:
	if _pending_flying_swords <= 0:
		return
	var targets := _get_attack_targets()
	if targets.is_empty():
		_cancel_flying_sword_sequence()
		return
	var target := targets[
		_flying_sword_sequence_launched % targets.size()
	]
	_launch_flying_sword(
		target,
		_flying_sword_sequence_damage,
		_flying_sword_sequence_is_critical,
		_flying_sword_sequence_launched,
		_flying_sword_sequence_total
	)
	_flying_sword_sequence_launched += 1
	_pending_flying_swords -= 1
	var weapon_data := _get_current_weapon_data()
	_flying_sword_sequence_timer = maxf(
		weapon_data.projectile_sequence_interval,
		0.01
	)


func _cancel_flying_sword_sequence() -> void:
	_pending_flying_swords = 0
	_flying_sword_sequence_total = 0
	_flying_sword_sequence_launched = 0
	_flying_sword_sequence_is_critical = false
	_flying_sword_sequence_timer = 0.0


func _get_attack_targets() -> Array[EnemyController]:
	var targets: Array[EnemyController] = []
	for body in attack_area.get_overlapping_bodies():
		if body is EnemyController and body.is_combat_active():
			targets.append(body as EnemyController)
	targets.sort_custom(
		func(a: EnemyController, b: EnemyController) -> bool:
			return global_position.distance_squared_to(a.global_position) < (
				global_position.distance_squared_to(b.global_position)
			)
	)
	return targets


func _launch_flying_sword(
	target: EnemyController,
	damage: int,
	is_critical: bool,
	projectile_index: int,
	projectile_count: int
) -> void:
	var weapon_data := _get_current_weapon_data()
	if weapon_data.projectile_scene == null:
		return
	var projectile := (
		weapon_data.projectile_scene.instantiate()
		as FlyingSwordProjectile
	)
	if projectile == null:
		push_error(
			"Flying Sword WeaponData projectile_scene must create "
			+ "FlyingSwordProjectile."
		)
		return
	var lateral_offset := (
		float(projectile_index) - float(projectile_count - 1) * 0.5
	) * 9.0
	var forward_direction := global_position.direction_to(target.global_position)
	var spawn_position := (
		global_position
		+ forward_direction.orthogonal() * lateral_offset
	)
	var direction := spawn_position.direction_to(target.global_position)
	get_parent().add_child(projectile)
	projectile.global_position = spawn_position
	projectile.configure(
		direction,
		damage,
		get_current_attack_range(),
		get_current_projectile_speed_multiplier(),
		is_critical
	)


func _launch_qiankun_ring(
	target: EnemyController,
	attack_damage: AttackDamageResultResource
) -> void:
	var weapon_data := _get_current_weapon_data()
	if weapon_data.projectile_scene == null:
		return
	var projectile := (
		weapon_data.projectile_scene.instantiate()
		as QiankunRingProjectile
	)
	if projectile == null:
		push_error(
			"Universe Ring WeaponData projectile_scene must create "
			+ "QiankunRingProjectile."
		)
		return
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	projectile.configure(
		self,
		target,
		attack_damage.damage,
		get_qiankun_ring_bounce_count(),
		_current_weapon_combat_stats.secondary_targeting_range,
		get_current_aoe_radius(),
		get_current_projectile_speed_multiplier(),
		attack_damage.is_critical
	)
	projectile.returned_to_player.connect(
		_on_qiankun_ring_returned,
		CONNECT_ONE_SHOT
	)
	projectile.tree_exited.connect(
		_on_qiankun_ring_returned,
		CONNECT_ONE_SHOT
	)
	_qiankun_ring_in_flight = true
	queue_redraw()


func _on_qiankun_ring_returned() -> void:
	_qiankun_ring_in_flight = false
	queue_redraw()


func _attract_collectibles(delta: float) -> void:
	for area in attraction_area.get_overlapping_areas():
		if area.has_method("attract_to_player"):
			area.call(
				"attract_to_player",
				self,
				maxf(collectible_attraction_speed, 1.0),
				delta
			)


func _update_visual_state(delta: float) -> void:
	_companion_phase = fmod(_companion_phase + delta * 1.6, TAU)
	_attack_flash_remaining = maxf(_attack_flash_remaining - delta, 0.0)
	_damage_flash_remaining = maxf(_damage_flash_remaining - delta, 0.0)
	_dao_attack_remaining = maxf(_dao_attack_remaining - delta, 0.0)
	_level_up_effect_remaining = maxf(
		_level_up_effect_remaining - delta,
		0.0
	)
	_breakthrough_effect_remaining = maxf(
		_breakthrough_effect_remaining - delta,
		0.0
	)
	_update_damage_feedback_presentation()
	queue_redraw()


func _update_damage_feedback_presentation() -> void:
	if _damage_flash_remaining <= 0.0:
		character_sprite.position = _character_sprite_rest_position
		character_sprite.modulate = _character_sprite_rest_modulate
		damage_taken_label.hide()
		return
	var duration := maxf(damage_feedback_duration, 0.01)
	var progress := 1.0 - clampf(
		_damage_flash_remaining / duration,
		0.0,
		1.0
	)
	var shake_strength := (1.0 - progress) * 6.0
	character_sprite.position = (
		_character_sprite_rest_position
		+ Vector2(
			sin(progress * TAU * 7.0),
			cos(progress * TAU * 5.0)
		) * shake_strength
	)
	var blink_on := int(progress * 12.0) % 2 == 0
	character_sprite.modulate = (
		Color(1.0, 0.18, 0.16, 1.0)
		if blink_on
		else Color(1.0, 0.92, 0.72, 1.0)
	)
	damage_taken_label.position = Vector2(-52.0, lerpf(-70.0, -102.0, progress))
	damage_taken_label.modulate = Color(
		1.0,
		lerpf(0.78, 0.22, progress),
		0.18,
		1.0 - pow(progress, 2.0)
	)


func _draw_damage_feedback() -> void:
	var duration := maxf(damage_feedback_duration, 0.01)
	var progress := 1.0 - clampf(
		_damage_flash_remaining / duration,
		0.0,
		1.0
	)
	var alpha := 1.0 - progress
	var burst_radius := lerpf(26.0, damage_feedback_radius, progress)
	draw_circle(
		Vector2.ZERO,
		burst_radius * 0.82,
		Color(1.0, 0.03, 0.02, alpha * 0.2)
	)
	draw_arc(
		Vector2.ZERO,
		burst_radius,
		0.0,
		TAU,
		56,
		Color(1.0, 0.18, 0.08, alpha * 0.95),
		lerpf(8.0, 3.0, progress),
		true
	)
	draw_arc(
		Vector2.ZERO,
		burst_radius * 0.64,
		-progress * TAU,
		TAU - progress * TAU,
		40,
		Color(1.0, 0.9, 0.62, alpha * 0.9),
		3.0,
		true
	)
	for ray_index in 8:
		var ray_angle := float(ray_index) / 8.0 * TAU + progress * 0.5
		var ray_direction := Vector2.from_angle(ray_angle)
		draw_line(
			ray_direction * (burst_radius * 0.78),
			ray_direction * (burst_radius + 12.0 + _last_damage_amount * 0.4),
			Color(1.0, 0.34, 0.12, alpha * 0.9),
			3.0
		)


func _draw_level_up_effect() -> void:
	var duration := maxf(level_up_effect_duration, 0.01)
	var progress := 1.0 - _level_up_effect_remaining / duration
	var effect_radius := lerpf(28.0, level_up_effect_radius, progress)
	var alpha := 1.0 - progress
	draw_circle(
		Vector2.ZERO,
		effect_radius * 0.72,
		Color(0.35, 0.95, 1.0, alpha * 0.11)
	)
	draw_arc(
		Vector2.ZERO,
		effect_radius,
		0.0,
		TAU,
		64,
		Color(0.55, 0.96, 1.0, alpha),
		4.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		effect_radius * 0.62,
		-progress * TAU,
		TAU - progress * TAU,
		48,
		Color(1.0, 0.88, 0.38, alpha * 0.9),
		3.0,
		true
	)
	for ray_index in 8:
		var ray_angle := float(ray_index) / 8.0 * TAU + progress
		var ray_direction := Vector2.from_angle(ray_angle)
		draw_line(
			ray_direction * (effect_radius * 0.72),
			ray_direction * (effect_radius + 12.0),
			Color(0.75, 1.0, 1.0, alpha * 0.8),
			2.0
		)


func _draw_breakthrough_effect() -> void:
	var duration := maxf(breakthrough_effect_duration, 0.01)
	var progress := 1.0 - _breakthrough_effect_remaining / duration
	var fade := minf(
		clampf(progress / 0.12, 0.0, 1.0),
		clampf((1.0 - progress) / 0.22, 0.0, 1.0)
	)
	var pulse := 0.88 + sin(progress * TAU * 6.0) * 0.08
	var outer_radius := breakthrough_effect_radius * pulse
	draw_rect(
		Rect2(
			Vector2(-24.0, -outer_radius * 1.35),
			Vector2(48.0, outer_radius * 2.7)
		),
		Color(0.55, 0.95, 1.0, fade * 0.09)
	)
	draw_circle(
		Vector2.ZERO,
		outer_radius * 0.78,
		Color(0.2, 0.85, 1.0, fade * 0.12)
	)
	for ring_index in 3:
		var ring_phase := fmod(
			progress * 1.8 + float(ring_index) / 3.0,
			1.0
		)
		var ring_radius := lerpf(42.0, outer_radius, ring_phase)
		draw_arc(
			Vector2.ZERO,
			ring_radius,
			0.0,
			TAU,
			80,
			Color(0.5, 0.94, 1.0, fade * (1.0 - ring_phase)),
			5.0 - float(ring_index),
			true
		)
	for ray_index in 16:
		var ray_angle := (
			float(ray_index) / 16.0 * TAU
			+ progress * (0.8 if ray_index % 2 == 0 else -0.55)
		)
		var direction := Vector2.from_angle(ray_angle)
		var ray_inner := outer_radius * (0.48 if ray_index % 2 == 0 else 0.64)
		var ray_outer := outer_radius * (1.08 if ray_index % 2 == 0 else 0.94)
		draw_line(
			direction * ray_inner,
			direction * ray_outer,
			Color(1.0, 0.85, 0.3, fade * 0.78),
			3.0
		)
	for mote_index in 12:
		var mote_angle := (
			float(mote_index) / 12.0 * TAU
			- progress * TAU * 1.5
		)
		var mote_radius := outer_radius * (
			0.52 + 0.22 * sin(progress * TAU + float(mote_index))
		)
		draw_circle(
			Vector2.from_angle(mote_angle) * mote_radius,
			4.0 + float(mote_index % 3),
			Color(0.78, 0.98, 1.0, fade * 0.9)
		)
	draw_arc(
		Vector2.ZERO,
		outer_radius * 0.38,
		-progress * TAU * 2.0,
		TAU - progress * TAU * 2.0,
		64,
		Color.WHITE,
		6.0,
		true
	)


func _publish_lifespan_decay_multiplier() -> void:
	var multiplier := get_lifespan_decay_multiplier()
	if absf(multiplier - _last_lifespan_decay_multiplier) < 0.002:
		return
	_last_lifespan_decay_multiplier = multiplier
	lifespan_decay_multiplier_changed.emit(multiplier)


func _draw_weapon_companions() -> void:
	var attack_kind := _get_current_weapon_data().attack_kind
	if attack_kind == WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM:
		return
	if (
		attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING
		and _qiankun_ring_in_flight
	):
		return
	var angle := _companion_phase
	if attack_kind == WeaponDataResource.AttackKind.DAO:
		var inner_position := Vector2.from_angle(angle) * 52.0
		draw_circle(
			inner_position,
			12.0,
			Color(1.0, 0.9, 0.4, 0.2)
		)
		_draw_dao(inner_position, angle + PI * 0.5, true)
	elif attack_kind == WeaponDataResource.AttackKind.FLYING_SWORD:
		var companion_position := Vector2.from_angle(angle) * 38.0
		draw_circle(
			companion_position,
			12.0,
			Color(1.0, 0.9, 0.4, 0.2)
		)
		_draw_flying_sword(
			companion_position,
			angle + PI * 0.5,
			true
		)
	else:
		var ring_position := Vector2.from_angle(angle) * 40.0
		draw_circle(
			ring_position,
			15.0,
			Color(1.0, 0.35, 0.82, 0.16)
		)
		_draw_qiankun_ring(ring_position)


func _draw_dao(position: Vector2, angle: float, active: bool) -> void:
	var direction := Vector2.from_angle(angle)
	var perpendicular := direction.orthogonal()
	var color := Color("ffd166") if active else Color("c9a75b")
	draw_line(
		position - direction * 9.0,
		position + direction * 9.0,
		color,
		4.0
	)
	draw_line(
		position - direction * 8.0 - perpendicular * 4.0,
		position - direction * 8.0 + perpendicular * 4.0,
		Color("e6d5af"),
		3.0
	)


func _draw_flying_sword(position: Vector2, angle: float, active: bool) -> void:
	var direction := Vector2.from_angle(angle)
	var color := Color("85e7ff") if active else Color("739baa")
	draw_line(
		position - direction * 11.0,
		position + direction * 11.0,
		color,
		3.0
	)
	draw_circle(position + direction * 11.0, 2.5, Color.WHITE)


func _draw_qiankun_ring(position: Vector2) -> void:
	draw_arc(
		position,
		10.0,
		0.0,
		TAU,
		36,
		Color("ff8ee7"),
		4.0,
		true
	)
	draw_arc(
		position,
		5.0,
		0.0,
		TAU,
		30,
		Color("ffe9a8"),
		2.0,
		true
	)


func _create_equipment(
	weapon_data: WeaponDataResource,
	damage: int
) -> Dictionary:
	return {
		"data": weapon_data,
		"damage": damage,
	}


func _find_equipment_index(equipment_id: StringName) -> int:
	for index in _equipment_inventory.size():
		var weapon_data := (
			_equipment_inventory[index]["data"] as WeaponDataResource
		)
		if weapon_data.weapon_id == equipment_id:
			return index
	return -1


func _get_current_equipment() -> Dictionary:
	return _equipment_inventory[_current_equipment_index]


func _get_current_weapon_data() -> WeaponDataResource:
	return _get_current_equipment()["data"] as WeaponDataResource


func _get_equipment_damage(equipment: Dictionary) -> int:
	var weapon_data := equipment["data"] as WeaponDataResource
	var base_damage := int(equipment["damage"])
	return CombatStatsResolverResource.resolve_weapon(
		weapon_data,
		base_damage,
		_cultivation_resources,
		_global_combat_stats
	).resolved_damage


func _rebuild_combat_stats() -> void:
	_global_combat_stats = CombatStatsResolverResource.resolve_global(
		_cultivation_resources,
		combat_config
	)
	if _equipment_inventory.is_empty():
		_current_weapon_combat_stats = WeaponCombatStatsResource.new()
	else:
		var equipment := _get_current_equipment()
		_current_weapon_combat_stats = CombatStatsResolverResource.resolve_weapon(
			equipment["data"] as WeaponDataResource,
			int(equipment["damage"]),
			_cultivation_resources,
			_global_combat_stats
		)
	combat_stats_changed.emit(
		_global_combat_stats,
		_current_weapon_combat_stats
	)


func _roll_current_attack_damage() -> AttackDamageResultResource:
	var damage := _current_weapon_combat_stats.resolved_damage
	var is_critical := (
		randf() < _current_weapon_combat_stats.critical_chance
	)
	if is_critical:
		damage = maxi(
			roundi(
				float(damage)
					* _current_weapon_combat_stats.critical_damage_multiplier
			),
			1
		)
	return AttackDamageResultResource.new(damage, is_critical)


func _on_cultivation_stats_changed(
	_cultivation_type: int,
	_level: int
) -> void:
	if not is_node_ready() or _equipment_inventory.is_empty():
		return
	_rebuild_combat_stats()
	_apply_attack_range()
	_level_up_effect_remaining = maxf(level_up_effect_duration, 0.01)
	_publish_equipment()
	queue_redraw()


func _on_current_equipment_changed() -> void:
	_attack_cooldown_remaining = 0.0
	_cancel_flying_sword_sequence()
	_rebuild_combat_stats()
	_apply_attack_range()
	_publish_equipment()
	queue_redraw()


func _publish_equipment() -> void:
	var weapon_data := _get_current_weapon_data()
	equipment_changed.emit(
		get_technique_name(),
		weapon_data.display_name,
		get_current_weapon_damage()
	)
	equipment_inventory_changed.emit(
		get_equipment_inventory_entries(),
		_current_equipment_index
	)


func _apply_attack_range() -> void:
	if attack_shape.shape is CircleShape2D:
		(attack_shape.shape as CircleShape2D).radius = get_current_attack_range()


func _apply_attraction_range() -> void:
	if attraction_shape.shape is CircleShape2D:
		(attraction_shape.shape as CircleShape2D).radius = current_attraction_range


func _get_current_range_color() -> Color:
	return _get_current_weapon_data().display_color


func _get_target_forward_speed() -> float:
	var speeding_up := Input.is_action_pressed("speed_up")
	var slowing_down := Input.is_action_pressed("slow_down")
	if speeding_up == slowing_down:
		return maxf(base_forward_speed, 1.0)
	if speeding_up:
		return maxf(boosted_forward_speed, 1.0)
	return maxf(slowed_forward_speed, 1.0)
