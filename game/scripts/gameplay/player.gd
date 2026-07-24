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
signal weapon_power_upgraded(level: int, total_damage_bonus: int)
signal universal_upgrade_applied(upgrade_type: int, level: int)
## Publishes fresh read-only player-wide and current-weapon snapshots whenever
## equipment or cultivation progression changes.
signal combat_stats_changed(
	global_stats: PlayerGlobalCombatStatsResource,
	weapon_stats: WeaponCombatStatsResource
)
signal qi_shield_absorbed(
	blocked_damage: float,
	qi_spent: int,
	remaining_damage: float
)
signal spirit_projection_changed(active: bool)
signal spirit_projection_broken
signal realm_ability_state_changed(snapshot: Dictionary)
signal roll_state_changed(active: bool, cooldown_remaining: float)
signal echo_state_changed(active_count: int, cooldown_remaining: float)

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
const DEFAULT_PLAYER_ECHO_SCENE: PackedScene = preload(
	"res://game/scenes/gameplay/player_echo.tscn"
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

@export_category("Character Animation")
## Ground-running animation used during Qi Refining.
@export var qi_refining_grounded_animation: StringName = &"qi_walk"
## Ground-running animation used after reaching Foundation.
@export var grounded_animation: StringName = &"walk"
## Animation used whenever the player's visual elevation is above the road.
@export var airborne_animation: StringName = &"fly"
## Lowest playback multiplier allowed while the player is moving slowly.
@export_range(0.1, 1.0, 0.05) var minimum_animation_speed_scale: float = 0.45
## Highest playback multiplier allowed while the player is accelerating.
@export_range(1.0, 4.0, 0.05) var maximum_animation_speed_scale: float = 1.8
## Elevation in pixels above which the airborne animation becomes active.
@export_range(0.0, 20.0, 0.5) var airborne_animation_threshold: float = 1.0
## Non-looping animation played during the Qi Refining invulnerable roll.
@export var roll_animation: StringName = &"flip"

@export_category("Qi Refining Roll")
## Seconds during which one roll moves, disables attacks, and grants immunity.
@export_range(0.1, 2.0, 0.05) var roll_duration: float = 0.6
## Recovery seconds after the roll finishes before another roll may begin.
@export_range(0.0, 5.0, 0.05) var roll_cooldown: float = 0.8
## Travel speed in world pixels per second during the roll.
@export_range(100.0, 1200.0, 10.0) var roll_speed: float = 520.0

@export_category("Golden Core Echoes")
## Scene instantiated twice when Golden Core activates its Space ability.
@export var player_echo_scene: PackedScene = DEFAULT_PLAYER_ECHO_SCENE
## Fraction of current player health and weapon damage inherited by echoes.
@export_range(0.01, 1.0, 0.01) var echo_attribute_ratio: float = 0.20
## Seconds after either echo dies before the pair can be summoned again.
@export_range(1.0, 60.0, 0.5) var echo_respawn_cooldown: float = 12.0
## Cooldown seconds removed by pressing Space while accelerating.
@export_range(0.1, 10.0, 0.1) var echo_cooldown_reduction_per_press: float = 1.0
## Horizontal formation distance in world pixels from the player.
@export_range(20.0, 200.0, 5.0) var echo_formation_distance: float = 72.0

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

@export_category("Universal Upgrade Fragments")
## Additive attack-speed ratio granted by each global attack-speed fragment.
@export_range(0.0, 1.0, 0.01) var attack_speed_bonus_per_fragment: float = 0.06
## Flat damage granted to every weapon by each damage fragment.
@export_range(0, 100, 1) var damage_bonus_per_fragment: int = 1
## Horizontal speed gained from every movement fragment.
@export_range(0.0, 100.0, 1.0) var lateral_speed_per_fragment: float = 12.0
## Forward acceleration gained from every movement fragment.
@export_range(0.0, 500.0, 5.0) var forward_acceleration_per_fragment: float = 45.0
## Multiplicative damage-range ratio granted per range fragment.
@export_range(0.0, 1.0, 0.01) var range_bonus_per_fragment: float = 0.06
## Boosted forward speed gained per speed-control fragment.
@export_range(0.0, 200.0, 5.0) var boost_speed_per_control_fragment: float = 25.0
## Amount removed from slowed speed per speed-control fragment.
@export_range(0.0, 100.0, 1.0) var slow_speed_reduction_per_fragment: float = 18.0
## Lowest slowed speed reachable through repeated control fragments.
@export_range(1.0, 60.0, 1.0) var minimum_controlled_speed: float = 8.0

@export_category("Great Strength Palm Progression")
## Flat damage added to Great Strength Palm per small cultivation level.
@export_range(0.0, 10.0, 0.05) var palm_damage_per_level: float = 0.5
## Additive range ratio added to Great Strength Palm per small level.
@export_range(0.0, 0.2, 0.005) var palm_range_ratio_per_level: float = 0.025
## Additive attack-speed ratio added to Great Strength Palm per small level.
@export_range(0.0, 0.2, 0.005) var palm_speed_ratio_per_level: float = 0.025
## Delay between realm-unlocked directional palm waves.
@export_range(0.01, 0.5, 0.01) var palm_sequence_interval: float = 0.06

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
@onready var spirit_sprite: AnimatedSprite2D = $SpiritSprite
@onready var damage_taken_label: Label = $DamageTakenLabel
@onready var realm_abilities: RealmAbilityController = $RealmAbilities
@onready var golden_bell: GoldenBellController = $GoldenBell

var current_forward_speed: float = 0.0
var distance_traveled: float = 0.0
var current_attraction_range: float = 72.0
var road_center_x: float = 0.0
var current_cultivation_level: int = 1

var _movement_enabled: bool = true
var _roll_remaining: float = 0.0
var _roll_cooldown_remaining: float = 0.0
var _roll_direction: Vector2 = Vector2.UP
var _active_echoes: Array[PlayerEcho] = []
var _echo_cooldown_remaining: float = 0.0
var _last_echo_cooldown_report: int = -1
var _attack_cooldown_remaining: float = 0.0
var _attack_flash_remaining: float = 0.0
var _palm_attack_direction: Vector2 = Vector2.UP
var _damage_flash_remaining: float = 0.0
var _shield_flash_remaining: float = 0.0
var _last_damage_amount: float = 0.0
var _character_sprite_rest_position: Vector2 = Vector2.ZERO
var _character_sprite_rest_modulate: Color = Color.WHITE
var _dao_attack_remaining: float = 0.0
var _companion_phase: float = 0.0
var _equipment_inventory: Array[Dictionary] = []
var _current_equipment_index: int = 0
var _weapon_power_level: int = 0
var _universal_upgrade_levels: Array[int] = [0, 0, 0, 0, 0]
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
var _pending_qiankun_rings: int = 0
var _qiankun_ring_sequence_total: int = 0
var _qiankun_ring_sequence_launched: int = 0
var _qiankun_ring_sequence_damage: int = 1
var _qiankun_ring_sequence_is_critical: bool = false
var _qiankun_ring_sequence_timer: float = 0.0
var _active_qiankun_rings: int = 0
var _pending_palm_waves: int = 0
var _palm_sequence_total: int = 0
var _palm_sequence_launched: int = 0
var _palm_sequence_damage: int = 1
var _palm_sequence_is_critical: bool = false
var _palm_sequence_timer: float = 0.0
var _palm_sequence_base_direction: Vector2 = Vector2.UP
var _palm_sequence_primary: EnemyController
var _palm_sequence_hit_ids: Dictionary = {}
var _pending_special_projectiles: int = 0
var _special_sequence_kind: int = -1
var _special_sequence_launched: int = 0
var _special_sequence_damage: int = 1
var _special_sequence_is_critical: bool = false
var _special_sequence_timer: float = 0.0
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
	realm_abilities.qi_shield_absorbed.connect(_on_qi_shield_absorbed)
	realm_abilities.spirit_projection_changed.connect(
		_on_spirit_projection_changed
	)
	realm_abilities.spirit_projection_broken.connect(
		_on_spirit_projection_broken
	)
	realm_abilities.ability_state_changed.connect(
		_on_realm_ability_state_changed
	)
	realm_abilities.flight_elevation_changed.connect(
		_on_flight_elevation_changed
	)
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
	if (
		_movement_enabled
		and event.is_action_pressed("spirit_projection")
		and not event.is_echo()
	):
		var realm_index := _get_current_realm_index()
		var handled := false
		if realm_index == 0:
			handled = start_qi_refining_roll()
		elif realm_index == 2:
			handled = activate_golden_core_echoes()
		if handled:
			get_viewport().set_input_as_handled()
		return
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
	_update_echo_cooldown(delta)
	_roll_cooldown_remaining = maxf(_roll_cooldown_remaining - delta, 0.0)
	if _roll_remaining > 0.0:
		_roll_remaining = maxf(_roll_remaining - delta, 0.0)
		velocity = _roll_direction * maxf(roll_speed, 1.0)
		move_and_slide()
		var roll_bounds := get_active_lateral_bounds()
		global_position.x = clampf(global_position.x, roll_bounds.x, roll_bounds.y)
		distance_traveled += maxf(-velocity.y, 0.0) * delta
		_attract_collectibles(delta)
		if _roll_remaining <= 0.0:
			roll_state_changed.emit(false, get_roll_cooldown_remaining())
		return

	var lateral_input := Input.get_axis("move_left", "move_right")
	velocity.x = lateral_input * get_effective_lateral_speed()

	var target_forward_speed := _get_target_forward_speed()
	current_forward_speed = move_toward(
		current_forward_speed,
		target_forward_speed,
		_get_effective_forward_acceleration() * delta
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
	var attack_kind := _get_current_weapon_data().attack_kind
	if (
		attack_kind == WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM
	):
		_draw_palm_range(attack_range, range_color)
	elif attack_kind != WeaponDataResource.AttackKind.GOLDEN_BELL:
		if attack_kind == WeaponDataResource.AttackKind.FANTIAN_SEAL:
			var attack_square := Rect2(
				Vector2.ONE * -attack_range,
				Vector2.ONE * attack_range * 2.0
			)
			draw_rect(attack_square, Color(range_color, 0.035), true)
			draw_rect(attack_square, Color(range_color, 0.52), false, 2.0)
		else:
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
	if realm_abilities.is_qi_shield_enabled():
		var shield_alpha := (
			0.82 if _shield_flash_remaining > 0.0 else 0.26
		)
		var shield_radius := (
			58.0 + sin(Time.get_ticks_msec() * 0.004) * 3.0
		)
		draw_circle(
			Vector2.ZERO,
			shield_radius,
			Color(0.2, 0.78, 1.0, shield_alpha * 0.12)
		)
		draw_arc(
			Vector2.ZERO,
			shield_radius,
			0.0,
			TAU,
			64,
			Color(0.42, 0.9, 1.0, shield_alpha),
			4.0 if _shield_flash_remaining > 0.0 else 2.0,
			true
		)

	_draw_weapon_companions()
	if _attack_flash_remaining > 0.0:
		var palm_angle := _palm_attack_direction.angle()
		var half_arc := deg_to_rad(
			_get_current_weapon_data().directional_arc_degrees * 0.5
		)
		draw_arc(
			Vector2.ZERO,
			attack_range,
			palm_angle - half_arc,
			palm_angle + half_arc,
			28,
			Color(0.55, 1.0, 0.86, 0.98),
			8.0,
			true
		)
		for wave_index in 3:
			var wave_distance := (
				attack_range * (0.45 + float(wave_index) * 0.2)
			)
			draw_arc(
				Vector2.ZERO,
				wave_distance,
				palm_angle - half_arc,
				palm_angle + half_arc,
				20,
				Color(0.72, 1.0, 0.9, 0.7 - float(wave_index) * 0.15),
				4.0,
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


func _draw_palm_range(attack_range: float, range_color: Color) -> void:
	var direction_angle := _palm_attack_direction.angle()
	var half_arc := deg_to_rad(
		_get_current_weapon_data().directional_arc_degrees * 0.5
	)
	var sector_points := PackedVector2Array([Vector2.ZERO])
	for point_index in 17:
		var ratio := float(point_index) / 16.0
		var point_angle := lerpf(
			direction_angle - half_arc,
			direction_angle + half_arc,
			ratio
		)
		sector_points.append(Vector2.from_angle(point_angle) * attack_range)
	draw_colored_polygon(sector_points, Color(range_color, 0.055))
	draw_arc(
		Vector2.ZERO,
		attack_range,
		direction_angle - half_arc,
		direction_angle + half_arc,
		32,
		Color(range_color, 0.62),
		2.0,
		true
	)
	draw_line(
		Vector2.ZERO,
		Vector2.from_angle(direction_angle - half_arc) * attack_range,
		Color(range_color, 0.34),
		2.0
	)
	draw_line(
		Vector2.ZERO,
		Vector2.from_angle(direction_angle + half_arc) * attack_range,
		Color(range_color, 0.34),
		2.0
	)


## Enables or stops player locomotion and combat without resetting run state.
func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
	if not _movement_enabled:
		velocity = Vector2.ZERO
		_cancel_flying_sword_sequence()
		_cancel_palm_sequence()
		_cancel_qiankun_ring_sequence()
		_cancel_special_projectile_sequence()


## Receives direct damage and reports its cultivation-adjusted amount to the
## run resource owner. Known nearby sources receive 精 close-range mitigation;
## source-less hazards preserve their authored damage.
func take_melee_damage(amount: float, source: Node2D = null) -> void:
	if not _movement_enabled or amount <= 0.0 or is_rolling():
		return
	if (
		source is EnemyController
		and not realm_abilities.can_receive_damage_from_realm(
			(source as EnemyController).combat_realm_index
		)
	):
		return
	if golden_bell != null and golden_bell.is_damage_protection_active():
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
	var realm_result := realm_abilities.resolve_incoming_damage(
		resolved_amount
	)
	resolved_amount = float(realm_result["remaining_damage"])
	if resolved_amount <= 0.0:
		return
	_last_damage_amount = resolved_amount
	_damage_flash_remaining = maxf(damage_feedback_duration, 0.01)
	damage_taken_label.text = "-%.1f 寿元" % resolved_amount
	damage_taken_label.show()
	_update_damage_feedback_presentation()
	queue_redraw()
	melee_damage_received.emit(resolved_amount)


func take_enemy_damage(amount: float, source: Node2D = null) -> void:
	take_melee_damage(amount, source)


## Returns whether the player-centered direct-damage reaction is active.
func is_damage_feedback_active() -> bool:
	return _damage_flash_remaining > 0.0


## Adds a new weapon type or upgrades an existing type's delivery count.
## Duplicate pickups always add one copy; their damage roll only replaces the
## stored roll when it is stronger.
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
	var may_equip := realm_abilities.is_weapon_allowed(weapon_data)

	if existing_index >= 0:
		var existing_damage := int(_equipment_inventory[existing_index]["damage"])
		var existing_quantity := int(
			_equipment_inventory[existing_index].get("quantity", 1)
		)
		equipment["damage"] = maxi(existing_damage, damage)
		equipment["quantity"] = existing_quantity + 1
		_equipment_inventory[existing_index] = equipment
		if may_equip:
			_current_equipment_index = existing_index
	else:
		_equipment_inventory.append(equipment)
		if may_equip:
			_current_equipment_index = _equipment_inventory.size() - 1
	if may_equip:
		_on_current_equipment_changed()
	else:
		_publish_equipment()
	return true


## Adds flat base damage to every existing and future weapon in this run.
## Weapon definitions remain immutable; the bonus is player-owned run state.
func upgrade_all_weapons(amount: int = 1) -> void:
	apply_universal_upgrade(
		UniversalUpgradeTypes.UpgradeType.DAMAGE,
		amount
	)


## Applies one of the five run-wide fragment upgrades without mutating shared
## weapon resources.
func apply_universal_upgrade(upgrade_type: int, amount: int = 1) -> void:
	if (
		amount <= 0
		or upgrade_type < 0
		or upgrade_type >= UniversalUpgradeTypes.COUNT
	):
		return
	_universal_upgrade_levels[upgrade_type] += amount
	if upgrade_type == UniversalUpgradeTypes.UpgradeType.DAMAGE:
		_weapon_power_level += amount * maxi(damage_bonus_per_fragment, 0)
	if is_node_ready() and not _equipment_inventory.is_empty():
		_rebuild_combat_stats()
		_apply_attack_range()
		_publish_equipment()
		_level_up_effect_remaining = maxf(level_up_effect_duration, 0.01)
		queue_redraw()
	if upgrade_type == UniversalUpgradeTypes.UpgradeType.DAMAGE:
		weapon_power_upgraded.emit(
			_weapon_power_level,
			_weapon_power_level
		)
	universal_upgrade_applied.emit(
		upgrade_type,
		_universal_upgrade_levels[upgrade_type]
	)


## Debug-panel mutation boundary for adding or removing run-local fragments.
func debug_adjust_universal_upgrade(upgrade_type: int, delta: int) -> void:
	if upgrade_type < 0 or upgrade_type >= UniversalUpgradeTypes.COUNT:
		return
	var previous := _universal_upgrade_levels[upgrade_type]
	var next := maxi(previous + delta, 0)
	var applied_delta := next - previous
	if applied_delta == 0:
		return
	_universal_upgrade_levels[upgrade_type] = next
	if upgrade_type == UniversalUpgradeTypes.UpgradeType.DAMAGE:
		_weapon_power_level = maxi(
			_weapon_power_level
				+ applied_delta * maxi(damage_bonus_per_fragment, 0),
			0
		)
	_rebuild_combat_stats()
	_apply_attack_range()
	_publish_equipment()
	universal_upgrade_applied.emit(upgrade_type, next)


## Debug-panel mutation boundary for weapon quantity without touching resources.
func debug_adjust_weapon(
	weapon_data: WeaponDataResource,
	delta: int
) -> void:
	if weapon_data == null or delta == 0:
		return
	if delta > 0:
		for _copy in delta:
			collect_weapon(weapon_data, weapon_data.minimum_damage)
		return
	var index := _find_equipment_index(weapon_data.weapon_id)
	if index < 0:
		return
	var equipment := _equipment_inventory[index]
	var quantity := int(equipment.get("quantity", 1))
	if quantity + delta > 0:
		equipment["quantity"] = quantity + delta
		_equipment_inventory[index] = equipment
		_on_current_equipment_changed()
	elif weapon_data.weapon_id != starting_weapon_data.weapon_id:
		_equipment_inventory.remove_at(index)
		_current_equipment_index = clampi(
			_current_equipment_index,
			0,
			_equipment_inventory.size() - 1
		)
	_on_current_equipment_changed()


func debug_adjust_current_weapon_damage(delta: int) -> void:
	if _equipment_inventory.is_empty() or delta == 0:
		return
	var equipment := _get_current_equipment()
	equipment["damage"] = maxi(int(equipment["damage"]) + delta, 1)
	_equipment_inventory[_current_equipment_index] = equipment
	_rebuild_combat_stats()
	_publish_equipment()


func get_weapon_power_level() -> int:
	return _weapon_power_level


func get_universal_upgrade_level(upgrade_type: int) -> int:
	if upgrade_type < 0 or upgrade_type >= _universal_upgrade_levels.size():
		return 0
	return _universal_upgrade_levels[upgrade_type]


func get_universal_upgrade_snapshot() -> Dictionary:
	var snapshot := {}
	for upgrade_type in UniversalUpgradeTypes.COUNT:
		snapshot[UniversalUpgradeTypes.get_display_name(upgrade_type)] = (
			_universal_upgrade_levels[upgrade_type]
		)
	return snapshot


func get_effective_lateral_speed() -> float:
	return (
		lateral_speed
		+ float(
			_universal_upgrade_levels[
				UniversalUpgradeTypes.UpgradeType.MOVEMENT
			]
		) * lateral_speed_per_fragment
	)


func get_effective_forward_acceleration() -> float:
	return _get_effective_forward_acceleration()


func get_boosted_speed_target() -> float:
	return maxf(
		boosted_forward_speed
			+ float(
				_universal_upgrade_levels[
					UniversalUpgradeTypes.UpgradeType.SPEED_CONTROL
				]
			) * boost_speed_per_control_fragment,
		1.0
	)


func get_slowed_speed_target() -> float:
	return maxf(
		slowed_forward_speed
			- float(
				_universal_upgrade_levels[
					UniversalUpgradeTypes.UpgradeType.SPEED_CONTROL
				]
			) * slow_speed_reduction_per_fragment,
		maxf(minimum_controlled_speed, 1.0)
	)


## Cycles the equipped entry in collection order. Bound to Tab by default.
func cycle_equipment() -> void:
	if _equipment_inventory.size() <= 1:
		return
	for offset in range(1, _equipment_inventory.size() + 1):
		var candidate_index := (
			_current_equipment_index + offset
		) % _equipment_inventory.size()
		var candidate_data := (
			_equipment_inventory[candidate_index]["data"]
			as WeaponDataResource
		)
		if not realm_abilities.is_weapon_allowed(candidate_data):
			continue
		_current_equipment_index = candidate_index
		_on_current_equipment_changed()
		return


func get_technique_name() -> String:
	return (
		starting_weapon_data.display_name
		if starting_weapon_data != null
		else ""
	)


func get_weapon_name() -> String:
	return _get_current_weapon_data().display_name


func get_current_weapon_damage() -> int:
	return maxi(
		roundi(
			float(_current_weapon_combat_stats.resolved_damage)
				* realm_abilities.get_outgoing_damage_multiplier()
		),
		1
	)


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
	realm_abilities.bind_resources(resources)
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


## Returns the equipped weapon count accumulated from same-type pickups.
func get_current_delivery_count() -> int:
	return _current_weapon_combat_stats.delivery_count


func get_current_aoe_radius() -> float:
	return _current_weapon_combat_stats.aoe_radius


## Returns the immutable shared definition for the currently equipped weapon.
func get_current_weapon_data() -> WeaponDataResource:
	return _get_current_weapon_data()


## Every collected Dao copy occupies one persistent concentric orbit.
func get_dao_orbit_count() -> int:
	return get_current_delivery_count()


## Returns a stable radius for one dao path. Existing paths keep their radius
## when a later fragment adds the next outer path.
func get_dao_orbit_radius(orbit_index: int) -> float:
	return 52.0 + float(maxi(orbit_index, 0)) * 12.0


## Returns the number of projectiles launched by one flying-sword volley.
func get_flying_sword_projectile_count() -> int:
	return get_current_delivery_count()


## Returns two base bounces plus one per universal damage fragment.
func get_qiankun_ring_bounce_count() -> int:
	return maxi(
		_get_current_weapon_data().base_bounce_count
			+ _universal_upgrade_levels[
				UniversalUpgradeTypes.UpgradeType.DAMAGE
			],
		0
	)


## Returns Universe Rings launched sequentially by one automatic attack.
func get_qiankun_ring_projectile_count() -> int:
	return get_current_delivery_count()


func is_qiankun_ring_in_flight() -> bool:
	return _active_qiankun_rings > 0 or _pending_qiankun_rings > 0


## Returns Universe Rings waiting in the current sequential launch.
func get_pending_qiankun_ring_count() -> int:
	return _pending_qiankun_rings


## Returns Universe Rings currently moving through the world.
func get_active_qiankun_ring_count() -> int:
	return _active_qiankun_rings


## Returns swords still waiting to launch in the current sequential volley.
func get_pending_flying_sword_count() -> int:
	return _pending_flying_swords


## Returns the number of idle weapons visibly accompanying the player.
## Equipped weapons always use one companion regardless of upgrade level.
func get_visible_companion_weapon_count() -> int:
	var attack_kind := _get_current_weapon_data().attack_kind
	if (
		attack_kind == WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM
		or attack_kind == WeaponDataResource.AttackKind.GOLDEN_BELL
		or attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING
			and is_qiankun_ring_in_flight()
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
	return maxf(
		current_forward_speed / maxf(base_forward_speed, 1.0),
		1.0
	)


func get_equipment_inventory_entries() -> Array[String]:
	var entries: Array[String] = []
	for index in _equipment_inventory.size():
		var equipment := _equipment_inventory[index]
		var weapon_data := equipment["data"] as WeaponDataResource
		var marker := "▶ " if index == _current_equipment_index else "  "
		var lock_suffix := (
			"  [当前境界不可用]"
			if not realm_abilities.is_weapon_allowed(weapon_data)
			else ""
		)
		entries.append(
			"%s%s ×%d  伤害 %d%s" % [
				marker,
				weapon_data.display_name,
				int(equipment.get("quantity", 1)),
				_get_equipment_damage(equipment),
				lock_suffix,
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


## Starts the grounded Qi Refining dodge using current directional input.
func start_qi_refining_roll() -> bool:
	if (
		not _movement_enabled
		or _get_current_realm_index() != 0
		or _roll_remaining > 0.0
		or _roll_cooldown_remaining > 0.0
	):
		return false
	var lateral_input := Input.get_axis("move_left", "move_right")
	_roll_direction = Vector2(lateral_input, -1.0).normalized()
	if _roll_direction.is_zero_approx():
		_roll_direction = Vector2.UP
	_roll_remaining = maxf(roll_duration, 0.01)
	_roll_cooldown_remaining = (
		_roll_remaining + maxf(roll_cooldown, 0.0)
	)
	if (
		is_instance_valid(character_sprite)
		and character_sprite.sprite_frames.has_animation(roll_animation)
	):
		character_sprite.play(roll_animation)
		character_sprite.speed_scale = 1.0
	_cancel_flying_sword_sequence()
	_cancel_palm_sequence()
	_cancel_qiankun_ring_sequence()
	_cancel_special_projectile_sequence()
	roll_state_changed.emit(true, get_roll_cooldown_remaining())
	return true


func is_rolling() -> bool:
	return _roll_remaining > 0.0


## Returns only post-roll recovery time; active roll duration is excluded.
func get_roll_cooldown_remaining() -> float:
	return maxf(_roll_cooldown_remaining - _roll_remaining, 0.0)


## Summons both Golden Core echoes, or accelerates their recovery while the
## player is actively using the speed-up control.
func activate_golden_core_echoes() -> bool:
	if not _movement_enabled or _get_current_realm_index() != 2:
		return false
	_prune_echoes()
	if not _active_echoes.is_empty():
		return true
	if _echo_cooldown_remaining > 0.0:
		if Input.is_action_pressed("speed_up"):
			_echo_cooldown_remaining = maxf(
				_echo_cooldown_remaining
					- maxf(echo_cooldown_reduction_per_press, 0.0),
				0.0
			)
			_emit_echo_state()
		return true
	_spawn_echo_pair()
	return true


func _spawn_echo_pair() -> void:
	if player_echo_scene == null or get_parent() == null:
		return
	var health_basis := (
		_cultivation_resources.max_lifespan
		if _cultivation_resources != null
		else 100.0
	)
	for side in [-1.0, 1.0]:
		var echo := player_echo_scene.instantiate() as PlayerEcho
		if echo == null:
			continue
		get_parent().add_child(echo)
		echo.configure(
			self,
			Vector2(side * echo_formation_distance, 0.0),
			health_basis * echo_attribute_ratio,
			maxi(roundi(get_current_weapon_damage() * echo_attribute_ratio), 1),
			get_current_attack_range(),
			get_current_attack_interval()
		)
		echo.global_position = global_position
		echo.defeated.connect(_on_echo_defeated)
		_active_echoes.append(echo)
	_emit_echo_state()


func _on_echo_defeated() -> void:
	for echo in _active_echoes:
		if is_instance_valid(echo):
			echo.queue_free()
	_active_echoes.clear()
	_echo_cooldown_remaining = maxf(echo_respawn_cooldown, 0.0)
	_emit_echo_state()


func _prune_echoes() -> void:
	var living: Array[PlayerEcho] = []
	for echo in _active_echoes:
		if is_instance_valid(echo):
			living.append(echo)
	_active_echoes = living


func _update_echo_cooldown(delta: float) -> void:
	_prune_echoes()
	if _echo_cooldown_remaining <= 0.0:
		return
	_echo_cooldown_remaining = maxf(_echo_cooldown_remaining - delta, 0.0)
	var report := ceili(_echo_cooldown_remaining * 10.0)
	if report != _last_echo_cooldown_report:
		_emit_echo_state()


func _emit_echo_state() -> void:
	_last_echo_cooldown_report = ceili(_echo_cooldown_remaining * 10.0)
	echo_state_changed.emit(
		get_active_echo_count(),
		_echo_cooldown_remaining
	)


func get_active_echo_count() -> int:
	_prune_echoes()
	return _active_echoes.size()


func get_echo_cooldown_remaining() -> float:
	return _echo_cooldown_remaining


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
	if _pending_palm_waves > 0:
		_palm_sequence_timer -= delta
		if _palm_sequence_timer <= 0.0:
			_launch_next_palm_wave()
		return
	if _pending_qiankun_rings > 0:
		_qiankun_ring_sequence_timer -= delta
		if _qiankun_ring_sequence_timer <= 0.0:
			_launch_next_qiankun_ring()
		return
	if _pending_special_projectiles > 0:
		_special_sequence_timer -= delta
		if _special_sequence_timer <= 0.0:
			_launch_next_special_projectile()
		return
	if _attack_cooldown_remaining > 0.0:
		return

	var weapon_data := _get_current_weapon_data()
	if weapon_data.attack_kind == WeaponDataResource.AttackKind.GOLDEN_BELL:
		return
	var targets := _get_attack_targets()
	if targets.is_empty():
		return
	var attack_kind := weapon_data.attack_kind
	if (
		attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING
		and is_qiankun_ring_in_flight()
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
		_begin_qiankun_ring_sequence(attack_damage)
	elif (
		attack_kind == WeaponDataResource.AttackKind.THUNDER_HAMMER
		or attack_kind == WeaponDataResource.AttackKind.FANTIAN_SEAL
	):
		_begin_special_projectile_sequence(attack_kind, attack_damage)
	else:
		_begin_palm_sequence(targets[0], attack_damage)

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


func _release_great_strength_palm(
	primary_target: EnemyController,
	attack_damage: AttackDamageResultResource
) -> void:
	_palm_sequence_hit_ids.clear()
	_palm_attack_direction = global_position.direction_to(
		primary_target.global_position
	).normalized()
	_release_palm_wave(
		_palm_attack_direction,
		primary_target,
		attack_damage
	)


func _begin_palm_sequence(
	primary_target: EnemyController,
	attack_damage: AttackDamageResultResource
) -> void:
	_palm_sequence_total = _get_palm_direction_count()
	_pending_palm_waves = _palm_sequence_total
	_palm_sequence_launched = 0
	_palm_sequence_damage = maxi(attack_damage.damage, 1)
	_palm_sequence_is_critical = attack_damage.is_critical
	_palm_sequence_base_direction = global_position.direction_to(
		primary_target.global_position
	).normalized()
	_palm_sequence_primary = primary_target
	_palm_sequence_hit_ids.clear()
	_launch_next_palm_wave()


func _launch_next_palm_wave() -> void:
	if _pending_palm_waves <= 0:
		return
	var direction := _palm_sequence_base_direction.rotated(
		TAU
			* float(_palm_sequence_launched)
			/ float(maxi(_palm_sequence_total, 1))
	)
	var damage := AttackDamageResultResource.new(
		_palm_sequence_damage,
		_palm_sequence_is_critical
	)
	_release_palm_wave(
		direction,
		_palm_sequence_primary if _palm_sequence_launched == 0 else null,
		damage
	)
	_palm_sequence_launched += 1
	_pending_palm_waves -= 1
	_palm_sequence_timer = maxf(palm_sequence_interval, 0.01)


func _release_palm_wave(
	direction: Vector2,
	primary_target: EnemyController,
	attack_damage: AttackDamageResultResource
) -> void:
	_palm_attack_direction = direction.normalized()
	var minimum_dot := cos(
		deg_to_rad(
			_get_current_weapon_data().directional_arc_degrees * 0.5
		)
	)
	var attack_range_squared := pow(get_current_attack_range(), 2.0)
	if is_instance_valid(primary_target) and primary_target.is_combat_active():
		_apply_palm_hit(primary_target, attack_damage)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		if (
			not enemy.is_combat_active()
			or _palm_sequence_hit_ids.has(enemy.get_instance_id())
		):
			continue
		var offset := enemy.global_position - global_position
		if (
			offset.length_squared() <= attack_range_squared
			and _palm_attack_direction.dot(offset.normalized()) >= minimum_dot
		):
			_apply_palm_hit(enemy, attack_damage)
	_attack_flash_remaining = 0.2


func _apply_palm_hit(
	enemy: EnemyController,
	attack_damage: AttackDamageResultResource
) -> void:
	if not is_instance_valid(enemy) or not enemy.is_combat_active():
		return
	var enemy_id := enemy.get_instance_id()
	if _palm_sequence_hit_ids.has(enemy_id):
		return
	_palm_sequence_hit_ids[enemy_id] = true
	var realm_index := _get_current_realm_index()
	var knockback_speed := 0.0
	if realm_index == 1:
		knockback_speed = 110.0
	elif realm_index == 2:
		knockback_speed = 320.0
	elif realm_index >= 3:
		knockback_speed = 480.0
	if knockback_speed > 0.0:
		enemy.apply_knockback(
			global_position.direction_to(enemy.global_position),
			knockback_speed
		)
	if realm_index >= 3 and not enemy.is_elite_enemy():
		enemy.take_melee_damage(maxi(enemy.current_health, 1))
	else:
		enemy.take_melee_damage(
			attack_damage.damage,
			attack_damage.is_critical
		)


func _get_palm_direction_count() -> int:
	match _get_current_realm_index():
		1:
			return 2
		2:
			return 6
		3:
			return 18
		_:
			return 1


func _get_current_realm_index() -> int:
	return (
		_cultivation_resources.get_current_realm_index()
		if _cultivation_resources != null
		else 0
	)


func _cancel_palm_sequence() -> void:
	_pending_palm_waves = 0
	_palm_sequence_total = 0
	_palm_sequence_launched = 0
	_palm_sequence_primary = null
	_palm_sequence_hit_ids.clear()


func _begin_qiankun_ring_sequence(
	attack_damage: AttackDamageResultResource
) -> void:
	_qiankun_ring_sequence_total = get_qiankun_ring_projectile_count()
	_pending_qiankun_rings = _qiankun_ring_sequence_total
	_qiankun_ring_sequence_launched = 0
	_qiankun_ring_sequence_damage = maxi(attack_damage.damage, 1)
	_qiankun_ring_sequence_is_critical = attack_damage.is_critical
	_qiankun_ring_sequence_timer = 0.0
	_launch_next_qiankun_ring()


func _launch_next_qiankun_ring() -> void:
	if _pending_qiankun_rings <= 0:
		return
	var targets := _get_attack_targets()
	if targets.is_empty():
		_cancel_qiankun_ring_sequence()
		return
	var target := targets[
		_qiankun_ring_sequence_launched % targets.size()
	]
	var attack_damage := AttackDamageResultResource.new()
	attack_damage.damage = _qiankun_ring_sequence_damage
	attack_damage.is_critical = _qiankun_ring_sequence_is_critical
	_launch_qiankun_ring(target, attack_damage)
	_qiankun_ring_sequence_launched += 1
	_pending_qiankun_rings -= 1
	_qiankun_ring_sequence_timer = maxf(
		_get_current_weapon_data().projectile_sequence_interval,
		0.01
	)


func _cancel_qiankun_ring_sequence() -> void:
	_pending_qiankun_rings = 0
	_qiankun_ring_sequence_total = 0
	_qiankun_ring_sequence_launched = 0
	_qiankun_ring_sequence_is_critical = false
	_qiankun_ring_sequence_timer = 0.0


func _begin_special_projectile_sequence(
	attack_kind: int,
	attack_damage: AttackDamageResultResource
) -> void:
	_special_sequence_kind = attack_kind
	_pending_special_projectiles = get_current_delivery_count()
	_special_sequence_launched = 0
	_special_sequence_damage = maxi(attack_damage.damage, 1)
	_special_sequence_is_critical = attack_damage.is_critical
	_special_sequence_timer = 0.0
	_launch_next_special_projectile()


func _launch_next_special_projectile() -> void:
	if _pending_special_projectiles <= 0:
		return
	var targets := _get_attack_targets()
	if targets.is_empty():
		_cancel_special_projectile_sequence()
		return
	var target := targets[_special_sequence_launched % targets.size()]
	var weapon_data := _get_current_weapon_data()
	if weapon_data.projectile_scene == null:
		_cancel_special_projectile_sequence()
		return
	if _special_sequence_kind == WeaponDataResource.AttackKind.THUNDER_HAMMER:
		var cloud := (
			weapon_data.projectile_scene.instantiate()
			as ThunderCloudProjectile
		)
		if cloud != null:
			get_parent().add_child(cloud)
			cloud.global_position = global_position
			cloud.configure(
				global_position.direction_to(target.global_position),
				_special_sequence_damage,
				maxf(get_current_aoe_radius(), 48.0),
				_special_sequence_is_critical,
				velocity
			)
	elif _special_sequence_kind == WeaponDataResource.AttackKind.FANTIAN_SEAL:
		var seal := (
			weapon_data.projectile_scene.instantiate()
			as FantianSealProjectile
		)
		if seal != null:
			get_parent().add_child(seal)
			seal.global_position = target.global_position
			seal.configure(
				target,
				_special_sequence_damage,
				maxf(get_current_aoe_radius(), 48.0),
				_special_sequence_is_critical
			)
			if get_parent().has_method("request_camera_shake"):
				seal.impact_landed.connect(
					Callable(get_parent(), "request_camera_shake")
				)
	_special_sequence_launched += 1
	_pending_special_projectiles -= 1
	_special_sequence_timer = maxf(
		weapon_data.projectile_sequence_interval,
		0.01
	)


func _cancel_special_projectile_sequence() -> void:
	_pending_special_projectiles = 0
	_special_sequence_kind = -1
	_special_sequence_launched = 0
	_special_sequence_is_critical = false
	_special_sequence_timer = 0.0


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
	projectile.tree_exited.connect(_on_qiankun_ring_returned, CONNECT_ONE_SHOT)
	_active_qiankun_rings += 1
	queue_redraw()


func _on_qiankun_ring_returned() -> void:
	_active_qiankun_rings = maxi(_active_qiankun_rings - 1, 0)
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
	_shield_flash_remaining = maxf(_shield_flash_remaining - delta, 0.0)
	_dao_attack_remaining = maxf(_dao_attack_remaining - delta, 0.0)
	_level_up_effect_remaining = maxf(
		_level_up_effect_remaining - delta,
		0.0
	)
	_breakthrough_effect_remaining = maxf(
		_breakthrough_effect_remaining - delta,
		0.0
	)
	_update_palm_aim()
	_update_character_animation()
	_update_damage_feedback_presentation()
	queue_redraw()


func _update_character_animation() -> void:
	if is_rolling():
		if (
			character_sprite.sprite_frames != null
			and character_sprite.sprite_frames.has_animation(roll_animation)
		):
			if character_sprite.animation != roll_animation:
				character_sprite.play(roll_animation)
			elif not character_sprite.is_playing():
				character_sprite.play()
			character_sprite.speed_scale = 1.0
		return
	var animation_speed := clampf(
		current_forward_speed / maxf(base_forward_speed, 1.0),
		minimum_animation_speed_scale,
		maximum_animation_speed_scale
	)
	var is_airborne := (
		realm_abilities.get_current_flight_elevation()
		> maxf(airborne_animation_threshold, 0.0)
	)
	var grounded_target := grounded_animation
	if (
		_cultivation_resources == null
		or _cultivation_resources.get_current_realm_index() == 0
	):
		grounded_target = qi_refining_grounded_animation
	var target_animation := (
		airborne_animation if is_airborne else grounded_target
	)
	if (
		character_sprite.sprite_frames != null
		and character_sprite.sprite_frames.has_animation(target_animation)
	):
		if character_sprite.animation != target_animation:
			character_sprite.play(target_animation)
		elif not character_sprite.is_playing():
			character_sprite.play()
	character_sprite.speed_scale = animation_speed
	if (
		spirit_sprite.sprite_frames != null
		and spirit_sprite.sprite_frames.has_animation(airborne_animation)
	):
		if spirit_sprite.animation != airborne_animation:
			spirit_sprite.play(airborne_animation)
		elif not spirit_sprite.is_playing():
			spirit_sprite.play()
		spirit_sprite.speed_scale = animation_speed


func _update_palm_aim() -> void:
	if (
		_equipment_inventory.is_empty()
		or _get_current_weapon_data().attack_kind
			!= WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM
	):
		return
	var nearest_target: EnemyController = null
	var nearest_distance_squared := INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		if not enemy.is_combat_active():
			continue
		var distance_squared := global_position.distance_squared_to(
			enemy.global_position
		)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_target = enemy
	if is_instance_valid(nearest_target):
		_palm_attack_direction = global_position.direction_to(
			nearest_target.global_position
		).normalized()


## Returns the live Great Strength Palm aim used by range presentation and
## debug panels, including while the weapon is not currently attacking.
func get_palm_attack_direction() -> Vector2:
	return _palm_attack_direction


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
	if (
		attack_kind == WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM
		or attack_kind == WeaponDataResource.AttackKind.GOLDEN_BELL
	):
		return
	if (
		attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING
		and is_qiankun_ring_in_flight()
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
	elif attack_kind == WeaponDataResource.AttackKind.THUNDER_HAMMER:
		var hammer_position := Vector2.from_angle(angle) * 40.0
		draw_rect(
			Rect2(hammer_position - Vector2(8.0, 6.0), Vector2(16.0, 12.0)),
			Color("8ecbff")
		)
		draw_line(
			hammer_position + Vector2(0.0, 5.0),
			hammer_position + Vector2(0.0, 17.0),
			Color("e8d7ae"),
			4.0
		)
	elif attack_kind == WeaponDataResource.AttackKind.FANTIAN_SEAL:
		var seal_position := Vector2.from_angle(angle) * 40.0
		draw_rect(
			Rect2(seal_position - Vector2(9.0, 8.0), Vector2(18.0, 16.0)),
			Color("d85a24")
		)
		draw_rect(
			Rect2(seal_position - Vector2(9.0, 8.0), Vector2(18.0, 16.0)),
			Color("ffd166"),
			false,
			2.0
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
		"quantity": 1,
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
	var base_damage := _get_equipment_base_damage(equipment)
	return CombatStatsResolverResource.resolve_weapon(
		weapon_data,
		base_damage,
		_cultivation_resources,
		_global_combat_stats
	).resolved_damage


func _get_equipment_base_damage(equipment: Dictionary) -> int:
	var weapon_data := equipment["data"] as WeaponDataResource
	if weapon_data.attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING:
		return int(equipment["damage"])
	return int(equipment["damage"]) + _weapon_power_level


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
			_get_equipment_base_damage(equipment),
			_cultivation_resources,
			_global_combat_stats
		)
		_current_weapon_combat_stats.delivery_count = maxi(
			(
				(equipment["data"] as WeaponDataResource).base_delivery_count
				+ int(equipment.get("quantity", 1))
				- 1
			),
			1
		)
		var attack_speed_level := _universal_upgrade_levels[
			UniversalUpgradeTypes.UpgradeType.ATTACK_SPEED
		]
		var range_level := _universal_upgrade_levels[
			UniversalUpgradeTypes.UpgradeType.DAMAGE_RANGE
		]
		_current_weapon_combat_stats.attack_interval = maxf(
			_current_weapon_combat_stats.attack_interval
				/ (
					1.0
					+ float(attack_speed_level)
						* maxf(attack_speed_bonus_per_fragment, 0.0)
				),
			_global_combat_stats.minimum_attack_interval
		)
		var range_multiplier := (
			1.0
			+ float(range_level) * maxf(range_bonus_per_fragment, 0.0)
		)
		_current_weapon_combat_stats.attack_range *= range_multiplier
		_current_weapon_combat_stats.secondary_targeting_range *= range_multiplier
		_current_weapon_combat_stats.aoe_radius *= range_multiplier
		if (
			(equipment["data"] as WeaponDataResource).attack_kind
			== WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM
		):
			var completed_small_levels := maxi(current_cultivation_level - 1, 0)
			_current_weapon_combat_stats.resolved_damage += roundi(
				float(completed_small_levels) * palm_damage_per_level
			)
			_current_weapon_combat_stats.attack_range *= (
				1.0
				+ float(completed_small_levels)
					* palm_range_ratio_per_level
			)
			_current_weapon_combat_stats.attack_interval = maxf(
				_current_weapon_combat_stats.attack_interval
					/ (
						1.0
						+ float(completed_small_levels)
							* palm_speed_ratio_per_level
					),
				_global_combat_stats.minimum_attack_interval
			)
	if golden_bell != null:
		var golden_bell_equipped := (
			not _equipment_inventory.is_empty()
			and _get_current_weapon_data().attack_kind
				== WeaponDataResource.AttackKind.GOLDEN_BELL
		)
		golden_bell.configure_weapon(
			golden_bell_equipped,
			(
				get_current_delivery_count()
				if golden_bell_equipped
				else 0
			),
			(
				get_current_weapon_damage()
				if golden_bell_equipped
				else 1
			)
		)
	combat_stats_changed.emit(
		_global_combat_stats,
		_current_weapon_combat_stats
	)


func _roll_current_attack_damage() -> AttackDamageResultResource:
	var damage := maxi(
		roundi(
			float(_current_weapon_combat_stats.resolved_damage)
				* realm_abilities.get_outgoing_damage_multiplier()
		),
		1
	)
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


func _on_realm_ability_state_changed(snapshot: Dictionary) -> void:
	if not is_node_ready():
		return
	_character_sprite_rest_position.y = -float(
		snapshot.get("current_flight_elevation", 0.0)
	)
	if _equipment_inventory.is_empty():
		realm_ability_state_changed.emit(snapshot)
		return
	if not realm_abilities.is_weapon_allowed(_get_current_weapon_data()):
		_current_equipment_index = _find_first_allowed_equipment_index()
	_rebuild_combat_stats()
	_apply_attack_range()
	_publish_equipment()
	realm_ability_state_changed.emit(snapshot)
	queue_redraw()


func _on_flight_elevation_changed(elevation: float) -> void:
	_character_sprite_rest_position.y = -maxf(elevation, 0.0)


func _find_first_allowed_equipment_index() -> int:
	for index in _equipment_inventory.size():
		var weapon_data := (
			_equipment_inventory[index]["data"] as WeaponDataResource
		)
		if realm_abilities.is_weapon_allowed(weapon_data):
			return index
	return 0


func _on_qi_shield_absorbed(
	blocked_damage: float,
	qi_spent: int,
	remaining_damage: float
) -> void:
	_shield_flash_remaining = 0.28
	queue_redraw()
	qi_shield_absorbed.emit(blocked_damage, qi_spent, remaining_damage)


func _on_spirit_projection_changed(active: bool) -> void:
	_character_sprite_rest_modulate = (
		Color(0.72, 0.9, 1.0, 0.72)
		if active
		else Color.WHITE
	)
	if is_node_ready() and not _equipment_inventory.is_empty():
		_publish_equipment()
	spirit_projection_changed.emit(active)


func _on_spirit_projection_broken(
	_fallback_realm_index: int,
	_fallback_layer: int
) -> void:
	spirit_projection_broken.emit()


func get_debug_snapshot() -> Dictionary:
	return {
		"position": global_position,
		"forward_speed": current_forward_speed,
		"distance_traveled": distance_traveled,
		"current_weapon": _get_current_weapon_data().weapon_id,
		"current_weapon_quantity": get_current_delivery_count(),
		"current_damage": get_current_weapon_damage(),
		"weapon_power_level": _weapon_power_level,
		"universal_upgrades": get_universal_upgrade_snapshot(),
		"attack_interval": get_current_attack_interval(),
		"attack_range": get_current_attack_range(),
		"aoe_radius": get_current_aoe_radius(),
		"lateral_speed": get_effective_lateral_speed(),
		"forward_acceleration": get_effective_forward_acceleration(),
		"boosted_speed_target": get_boosted_speed_target(),
		"slowed_speed_target": get_slowed_speed_target(),
		"rolling": is_rolling(),
		"roll_cooldown": get_roll_cooldown_remaining(),
		"active_echoes": get_active_echo_count(),
		"echo_cooldown": get_echo_cooldown_remaining(),
		"realm_abilities": realm_abilities.get_debug_snapshot(),
	}


func _on_current_equipment_changed() -> void:
	_cancel_flying_sword_sequence()
	_cancel_palm_sequence()
	_cancel_qiankun_ring_sequence()
	_cancel_special_projectile_sequence()
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
	if (
		not _equipment_inventory.is_empty()
		and _get_current_weapon_data().attack_kind
			== WeaponDataResource.AttackKind.FANTIAN_SEAL
	):
		var square := RectangleShape2D.new()
		square.size = Vector2.ONE * get_current_attack_range() * 2.0
		attack_shape.shape = square
	else:
		var circle := CircleShape2D.new()
		circle.radius = get_current_attack_range()
		attack_shape.shape = circle


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
		return get_boosted_speed_target()
	return get_slowed_speed_target()


func _get_effective_forward_acceleration() -> float:
	return (
		forward_acceleration
		+ float(
			_universal_upgrade_levels[
				UniversalUpgradeTypes.UpgradeType.MOVEMENT
			]
		) * forward_acceleration_per_fragment
		+ float(
			_universal_upgrade_levels[
				UniversalUpgradeTypes.UpgradeType.SPEED_CONTROL
			]
		) * forward_acceleration_per_fragment
	)
