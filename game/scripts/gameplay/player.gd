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
signal weapon_upgrade_changed(level: int)
signal weapon_power_changed(bonus_damage: int)

const WeaponDataResource = preload(
	"res://game/scripts/gameplay/weapon_data.gd"
)
const DEFAULT_STARTING_WEAPON_DATA: WeaponDataResource = preload(
	"res://game/resources/great_strength_palm.tres"
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
## Duration, in seconds, of the larger effect played after surviving the
## level-nine breakthrough tribulation.
@export_range(0.5, 5.0, 0.1) var breakthrough_effect_duration: float = 2.4
## Outer radius, in world pixels, of the breakthrough rings and light rays.
@export_range(80.0, 260.0, 1.0) var breakthrough_effect_radius: float = 156.0

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var attraction_area: Area2D = $AttractionArea
@onready var attraction_shape: CollisionShape2D = (
	$AttractionArea/CollisionShape2D
)

var current_forward_speed: float = 0.0
var distance_traveled: float = 0.0
var current_attraction_range: float = 72.0
var road_center_x: float = 0.0
var current_cultivation_level: int = 1
var weapon_upgrade_level: int = 0
var weapon_power_bonus: int = 0

var _movement_enabled: bool = true
var _attack_cooldown_remaining: float = 0.0
var _attack_flash_remaining: float = 0.0
var _damage_flash_remaining: float = 0.0
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
var _flying_sword_sequence_timer: float = 0.0
var _level_up_effect_remaining: float = 0.0
var _breakthrough_effect_remaining: float = 0.0
var _qiankun_ring_in_flight: bool = false


func _ready() -> void:
	_movement_enabled = true
	current_forward_speed = maxf(base_forward_speed, 1.0)
	_last_lifespan_decay_multiplier = get_lifespan_decay_multiplier()
	current_attraction_range = base_attraction_range
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
	_apply_attack_range()
	_apply_attraction_range()
	_publish_equipment()
	queue_redraw()


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
	_update_visual_state(delta)


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
		draw_circle(Vector2.ZERO, 30.0, Color(1.0, 0.12, 0.12, 0.38))
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


## Receives enemy melee damage and reports it to the run resource owner.
func take_melee_damage(amount: float) -> void:
	if not _movement_enabled or amount <= 0.0:
		return
	_damage_flash_remaining = 0.2
	queue_redraw()
	melee_damage_received.emit(amount)


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
	return (
		int(_get_current_equipment()["damage"])
		+ maxi(weapon_power_bonus, 0)
	)


func get_current_attack_range() -> float:
	var weapon_data := _get_current_weapon_data()
	return (
		weapon_data.attack_range
		+ float(maxi(weapon_upgrade_level, 0))
			* weapon_data.range_increase_per_upgrade
	)


## Returns the immutable shared definition for the currently equipped weapon.
func get_current_weapon_data() -> WeaponDataResource:
	return _get_current_weapon_data()


## Returns the original inner dao path plus one new concentric path per
## absorbed technique fragment.
func get_dao_orbit_count() -> int:
	var weapon_data := _get_current_weapon_data()
	return (
		1
		+ maxi(weapon_upgrade_level, 0)
			* maxi(weapon_data.additional_effects_per_upgrade, 0)
	)


## Returns a stable radius for one dao path. Existing paths keep their radius
## when a later fragment adds the next outer path.
func get_dao_orbit_radius(orbit_index: int) -> float:
	if orbit_index <= 0:
		return 52.0
	var weapon_data := _get_current_weapon_data()
	return maxf(
		weapon_data.attack_range - 12.0
			+ float(orbit_index) * weapon_data.range_increase_per_upgrade,
		62.0
	)


## Returns the number of projectiles launched by one flying-sword volley.
func get_flying_sword_projectile_count() -> int:
	var weapon_data := _get_current_weapon_data()
	return (
		1
		+ maxi(weapon_upgrade_level, 0)
			* maxi(weapon_data.additional_effects_per_upgrade, 0)
	)


## Returns extra enemy-to-enemy bounces before the Universe Ring comes back.
func get_qiankun_ring_bounce_count() -> int:
	var weapon_data := _get_current_weapon_data()
	return (
		maxi(weapon_upgrade_level, 0)
		* maxi(weapon_data.additional_effects_per_upgrade, 0)
	)


func get_weapon_upgrade_level() -> int:
	return weapon_upgrade_level


## Absorbs one or more elite technique fragments. This is the only path that
## upgrades dao, flying-sword, and Universe Ring attack behavior.
func add_weapon_upgrade_fragments(amount: int = 1) -> void:
	if amount <= 0:
		return
	weapon_upgrade_level += amount
	_apply_attack_range()
	_level_up_effect_remaining = maxf(level_up_effect_duration, 0.01)
	weapon_upgrade_changed.emit(weapon_upgrade_level)
	_publish_equipment()
	queue_redraw()


func get_weapon_power_bonus() -> int:
	return weapon_power_bonus


## Adds flat base damage to every existing and future weapon. Elite weapon
## power fragments are the only normal gameplay source of this bonus.
func add_weapon_power_fragments(amount: int = 1) -> void:
	if amount <= 0:
		return
	weapon_power_bonus += amount
	_level_up_effect_remaining = maxf(level_up_effect_duration, 0.01)
	weapon_power_changed.emit(weapon_power_bonus)
	_publish_equipment()
	queue_redraw()


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


## Starts the elaborate aura reserved for a successful level-nine breakthrough.
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
## speed. Boosting raises it while slowing lowers it.
func get_lifespan_decay_multiplier() -> float:
	return current_forward_speed / maxf(base_forward_speed, 1.0)


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
				int(equipment["damage"]) + maxi(weapon_power_bonus, 0),
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


## Cultivation expands only collectible attraction. Weapon behavior is
## upgraded independently by elite technique fragments.
func apply_cultivation_level(level: int) -> void:
	var previous_level := current_cultivation_level
	current_cultivation_level = maxi(level, 1)
	current_attraction_range = (
		base_attraction_range
		+ float(current_cultivation_level - 1)
			* attraction_range_increase_per_level
	)
	_apply_attraction_range()
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
	var damage := get_current_weapon_damage()

	if attack_kind == WeaponDataResource.AttackKind.DAO:
		for enemy in targets:
			enemy.take_melee_damage(damage)
		_dao_attack_remaining = 0.28
	elif attack_kind == WeaponDataResource.AttackKind.FLYING_SWORD:
		_begin_flying_sword_sequence(damage)
	elif attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING:
		_launch_qiankun_ring(targets[0], damage)
	else:
		targets[0].take_melee_damage(damage)
		_attack_flash_remaining = 0.12

	_attack_cooldown_remaining = maxf(weapon_data.attack_interval, 0.1)
	queue_redraw()


func _begin_flying_sword_sequence(damage: int) -> void:
	_flying_sword_sequence_total = get_flying_sword_projectile_count()
	_pending_flying_swords = _flying_sword_sequence_total
	_flying_sword_sequence_launched = 0
	_flying_sword_sequence_damage = maxi(damage, 1)
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
	projectile.configure(direction, damage, get_current_attack_range())


func _launch_qiankun_ring(
	target: EnemyController,
	damage: int
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
		damage,
		get_qiankun_ring_bounce_count(),
		weapon_data.secondary_range
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
	queue_redraw()


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


func _on_current_equipment_changed() -> void:
	_attack_cooldown_remaining = 0.0
	_cancel_flying_sword_sequence()
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
