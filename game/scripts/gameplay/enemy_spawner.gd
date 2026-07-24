class_name EnemySpawner
extends Node2D

signal qi_collected(amount: int)
signal technique_fragment_collected(amount: int)
signal weapon_power_fragment_collected(amount: int)

const WeaponDataResource = preload(
	"res://game/scripts/gameplay/weapon_data.gd"
)
const DAO_DATA: WeaponDataResource = preload("res://game/resources/weapon/dao.tres")
const FLYING_SWORD_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/flying_sword.tres"
)
const QIANKUN_RING_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/qiankun_ring.tres"
)

## Enemy scene created beyond either camera edge. It must instantiate an
## EnemyController.
@export var enemy_scene: PackedScene = preload(
	"res://game/scenes/gameplay/enemy.tscn"
)
## Qi pickup created whenever an enemy is defeated.
@export var qi_pickup_scene: PackedScene = preload(
	"res://game/scenes/gameplay/qi_pickup.tscn"
)
## Weapon pickup optionally created when an enemy is defeated.
@export var weapon_pickup_scene: PackedScene = preload(
	"res://game/scenes/gameplay/weapon_pickup.tscn"
)
## Technique fragment created once for every defeated elite enemy.
@export var technique_fragment_scene: PackedScene = preload(
	"res://game/scenes/gameplay/technique_fragment.tscn"
)
## Weapon-power fragment created once for every defeated elite enemy.
@export var weapon_power_fragment_scene: PackedScene = preload(
	"res://game/scenes/gameplay/weapon_power_fragment.tscn"
)
## Player reference injected into each spawned enemy.
@export var player: PlayerController
## Camera used to place enemies beyond the visible forward screen edge.
@export var camera: Camera2D
## Seconds between enemy spawn attempts during an active run.
@export_range(0.5, 20.0, 0.1) var spawn_interval: float = 3.5
## Delay in seconds before the first enemy appears.
@export_range(0.0, 20.0, 0.1) var initial_spawn_delay: float = 2.0
## Extra distance in world pixels beyond the camera's top edge.
@export_range(16.0, 500.0, 1.0) var spawn_ahead_margin: float = 120.0
## Clearance in world pixels between a spawned enemy and either road edge.
@export_range(0.0, 100.0, 1.0) var road_edge_clearance: float = 32.0
## Maximum living enemies retained at once.
@export_range(1, 30, 1) var max_active_enemies: int = 8

@export_category("Difficulty Progression")
## Unpaused gameplay seconds between enemy difficulty increases.
@export_range(10.0, 180.0, 1.0) var difficulty_step_seconds: float = 20.0
## Difficulty steps contributed by every cultivation level above one. This
## keeps ordinary enemies aligned with rapid player progression.
@export_range(0, 4, 1) var cultivation_steps_per_level: int = 1
## Maximum-health points added to newly spawned enemies per difficulty step.
@export_range(0, 20, 1) var health_increase_per_step: int = 2
## Melee damage added to newly spawned enemies per difficulty step.
@export_range(0.0, 10.0, 0.1) var damage_increase_per_step: float = 0.75
## Multiplier applied once per step to enemy melee intervals. Values below one
## make later enemies attack more frequently.
@export_range(0.5, 1.0, 0.01) var attack_interval_multiplier_per_step: float = 0.88
## Lower bound, in seconds, for scaled enemy melee intervals.
@export_range(0.1, 2.0, 0.05) var minimum_enemy_attack_interval: float = 0.35
## Additional simultaneous enemy slots unlocked per difficulty step.
@export_range(0, 5, 1) var max_enemies_increase_per_step: int = 1
## Hard safety cap for the time-and-level-scaled simultaneous enemy count.
@export_range(8, 60, 1) var maximum_scaled_enemies: int = 32
## Multiplier applied once per step to both spawn intervals. Values below one
## steadily increase the number of enemies entering play.
@export_range(0.5, 1.0, 0.01) var spawn_interval_multiplier_per_step: float = 0.9
## Minimum forward-enemy spawn interval, in seconds, after scaling.
@export_range(0.5, 10.0, 0.1) var minimum_spawn_interval: float = 1.0
## Minimum rear-pursuer spawn interval, in seconds, after scaling.
@export_range(1.0, 15.0, 0.1) var minimum_rear_spawn_interval: float = 2.5

@export_category("Elite Enemies")
## Probability from zero to one that any new enemy becomes an elite variant.
@export_range(0.0, 1.0, 0.01) var elite_spawn_chance: float = 0.08
## Health multiplier applied after elapsed-time difficulty scaling.
@export_range(1.1, 10.0, 0.1) var elite_health_multiplier: float = 3.0
## Melee-range multiplier applied to elite enemies.
@export_range(1.1, 4.0, 0.1) var elite_attack_range_multiplier: float = 1.6
## Visual and collision scale applied to elite enemy bodies.
@export_range(1.0, 2.0, 0.05) var elite_visual_scale: float = 1.25

@export_category("Trial Hell")
## Multiplier applied to the simultaneous enemy cap on a Trial Hell route.
@export_range(1.0, 3.0, 0.05) var trial_enemy_count_multiplier: float = 1.75
## Multiplier applied to spawn intervals in Trial Hell. Lower values produce
## denser waves; the default creates enemies almost twice as often.
@export_range(0.25, 1.0, 0.05) var trial_spawn_interval_multiplier: float = 0.55
## Maximum-health multiplier for enemies created in Trial Hell.
@export_range(1.0, 4.0, 0.05) var trial_enemy_health_multiplier: float = 1.5
## Melee-damage multiplier for enemies created in Trial Hell.
@export_range(1.0, 3.0, 0.05) var trial_enemy_damage_multiplier: float = 1.35
## Melee-interval multiplier for enemies created in Trial Hell. Lower values
## make their attacks more frequent.
@export_range(0.35, 1.0, 0.05) var trial_attack_interval_multiplier: float = 0.75

@export_category("Rear Pursuers")
## Delay in seconds before the first faster enemy appears behind the player.
@export_range(0.0, 30.0, 0.5) var rear_initial_spawn_delay: float = 6.0
## Seconds between enemies generated behind the camera.
@export_range(2.0, 30.0, 0.5) var rear_spawn_interval: float = 8.0
## Extra distance in world pixels below the camera's visible bottom edge.
@export_range(16.0, 500.0, 1.0) var rear_spawn_margin: float = 100.0
## Constant forward speed of rear enemies in pixels per second. The 300-pixel
## default closes on the player's 260-pixel base speed gradually.
@export var rear_enemy_forward_speed: float = 300.0

@export_category("Enemy Drops")
## Base Qi granted by a normal enemy before difficulty and type adjustments.
@export_range(1, 1000, 1) var enemy_qi_drop_amount: int = 15
## Additional Qi added per combined time-and-cultivation difficulty step before
## enemy-type multipliers. The default adds one Qi every two steps after rounding.
@export_range(0.0, 20.0, 0.05) var qi_drop_increase_per_difficulty_step: float = 0.5
## Qi multiplier for elite enemies. This deliberately compensates only part of
## their triple health because elites also grant two permanent upgrade fragments.
@export_range(0.0, 5.0, 0.05) var elite_qi_drop_multiplier: float = 1.5
## Qi multiplier for enemies spawned while Trial Hell is active. It stacks with
## elite and rear-pursuer multipliers and rewards the route's added danger.
@export_range(0.0, 5.0, 0.05) var trial_qi_drop_multiplier: float = 1.2
## Qi multiplier for faster enemies spawned behind the player.
@export_range(0.0, 5.0, 0.05) var rear_qi_drop_multiplier: float = 1.15
## Hard upper bound for one enemy's Qi reward after every modifier.
@export_range(1, 5000, 1) var maximum_enemy_qi_drop: int = 200
## Probability from zero to one that a defeated enemy also drops one definition
## selected evenly from weapon_drop_pool.
@export_range(0.0, 1.0, 0.05) var weapon_drop_chance: float = 0.35
## Designer-managed definitions eligible for enemy drops. Invalid or null
## entries are ignored; damage, identity, and combat tuning belong to each
## shared WeaponData resource rather than this spawner.
@export var weapon_drop_pool: Array[WeaponDataResource] = [
	DAO_DATA,
	FLYING_SWORD_DATA,
	QIANKUN_RING_DATA,
]

var road_half_width: float = 200.0
var _spawn_time_remaining: float = 0.0
var _rear_spawn_time_remaining: float = 0.0
var _spawning_enabled: bool = true
var _rng := RandomNumberGenerator.new()
var _route_center_x: float = 0.0
var _elapsed_run_time: float = 0.0
var _cultivation_level: int = 1
var _trial_hell_active: bool = false


func _ready() -> void:
	_rng.randomize()
	_elapsed_run_time = 0.0
	_cultivation_level = 1
	_spawn_time_remaining = maxf(initial_spawn_delay, 0.0)
	_rear_spawn_time_remaining = maxf(rear_initial_spawn_delay, 0.0)


func _physics_process(delta: float) -> void:
	if (
		not _spawning_enabled
		or not is_instance_valid(player)
		or not is_instance_valid(camera)
	):
		return

	_elapsed_run_time += delta
	_spawn_time_remaining -= delta
	_rear_spawn_time_remaining -= delta
	if (
		_spawn_time_remaining <= 0.0
		and get_active_enemy_count() < get_current_max_active_enemies()
	):
		_spawn_time_remaining = get_current_spawn_interval(false)
		_spawn_enemy(false)
	if (
		_rear_spawn_time_remaining <= 0.0
		and get_active_enemy_count() < get_current_max_active_enemies()
	):
		_rear_spawn_time_remaining = get_current_spawn_interval(true)
		_spawn_enemy(true)


## Synchronizes enemy placement with the generated road.
func set_road_half_width(value: float) -> void:
	road_half_width = maxf(value, road_edge_clearance + 1.0)


## Moves future enemy spawn X positions to the active infinite route.
func set_route_center_x(value: float) -> void:
	_route_center_x = value
	_remove_enemies_outside_active_route()


## Enables normal spawning or freezes all enemies when the run ends.
func set_spawning_enabled(enabled: bool) -> void:
	_spawning_enabled = enabled
	if enabled:
		return
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is EnemyController:
			(enemy_node as EnemyController).set_combat_enabled(false)


func get_active_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()


## Synchronizes ordinary enemy scaling with the player's current cultivation.
func set_cultivation_level(level: int) -> void:
	_cultivation_level = maxi(level, 1)


## Enables the higher density and stronger enemy package for Trial Hell.
func set_trial_hell_active(active: bool) -> void:
	_trial_hell_active = active
	if active:
		_spawn_time_remaining = minf(
			_spawn_time_remaining,
			get_current_spawn_interval(false)
		)
		_rear_spawn_time_remaining = minf(
			_rear_spawn_time_remaining,
			get_current_spawn_interval(true)
		)


func is_trial_hell_active() -> bool:
	return _trial_hell_active


func get_time_difficulty_step() -> int:
	return floori(
		_elapsed_run_time / maxf(difficulty_step_seconds, 1.0)
	)


## Returns combined time and cultivation difficulty intervals.
func get_difficulty_step() -> int:
	return (
		get_time_difficulty_step()
		+ maxi(_cultivation_level - 1, 0)
			* maxi(cultivation_steps_per_level, 0)
	)


## Returns the current time-scaled simultaneous-enemy cap.
func get_current_max_active_enemies() -> int:
	var normal_maximum := mini(
		maxi(max_active_enemies, 1)
			+ get_difficulty_step()
				* maxi(max_enemies_increase_per_step, 0),
		maxi(maximum_scaled_enemies, max_active_enemies)
	)
	if not _trial_hell_active:
		return normal_maximum
	return mini(
		ceili(float(normal_maximum) * trial_enemy_count_multiplier),
		maxi(maximum_scaled_enemies, max_active_enemies)
	)


## Returns the current scaled interval for forward or rear enemy generation.
func get_current_spawn_interval(from_behind: bool) -> float:
	var base_interval := rear_spawn_interval if from_behind else spawn_interval
	var minimum_interval := (
		minimum_rear_spawn_interval
		if from_behind
		else minimum_spawn_interval
	)
	var normal_interval := maxf(
		base_interval
			* pow(
				clampf(spawn_interval_multiplier_per_step, 0.01, 1.0),
				float(get_difficulty_step())
			),
		minimum_interval
	)
	if not _trial_hell_active:
		return normal_interval
	return maxf(
		normal_interval * trial_spawn_interval_multiplier,
		minimum_interval * 0.5
	)


func _spawn_enemy(from_behind: bool = false) -> void:
	if enemy_scene == null:
		return
	var enemy := enemy_scene.instantiate() as EnemyController
	if enemy == null:
		push_error("EnemySpawner enemy_scene must instantiate EnemyController.")
		return
	enemy.player = player
	_apply_current_difficulty(enemy)
	if _rng.randf() <= clampf(elite_spawn_chance, 0.0, 1.0):
		enemy.configure_elite(
			elite_health_multiplier,
			elite_attack_range_multiplier,
			elite_visual_scale
		)
	var qi_reward := get_enemy_qi_drop_amount(
		get_difficulty_step(),
		enemy.is_elite_enemy(),
		_trial_hell_active,
		from_behind
	)
	enemy.defeated.connect(
		_on_enemy_defeated.bind(enemy, qi_reward)
	)

	var viewport_height := get_viewport_rect().size.y
	var vertical_zoom := maxf(camera.zoom.y, 0.01)
	var half_visible_height := viewport_height / vertical_zoom * 0.5
	var usable_half_width := maxf(
		road_half_width - road_edge_clearance,
		1.0
	)
	var spawn_y := (
		camera.global_position.y - half_visible_height - spawn_ahead_margin
	)
	if from_behind:
		spawn_y = (
			camera.global_position.y + half_visible_height + rear_spawn_margin
		)
		enemy.cruise_speed = maxf(rear_enemy_forward_speed, 1.0)
	enemy.global_position = Vector2(
		_route_center_x
			+ _rng.randf_range(-usable_half_width, usable_half_width),
		spawn_y
	)
	add_child(enemy)


func _apply_current_difficulty(enemy: EnemyController) -> void:
	var difficulty_step := get_difficulty_step()
	enemy.max_health += difficulty_step * maxi(health_increase_per_step, 0)
	enemy.melee_damage += (
		float(difficulty_step) * maxf(damage_increase_per_step, 0.0)
	)
	enemy.melee_attack_interval = maxf(
		enemy.melee_attack_interval
			* pow(
				clampf(
					attack_interval_multiplier_per_step,
					0.01,
					1.0
				),
				float(difficulty_step)
			),
		minimum_enemy_attack_interval
	)
	if _trial_hell_active:
		enemy.max_health = maxi(
			roundi(
				float(enemy.max_health) * trial_enemy_health_multiplier
			),
			enemy.max_health + 1
		)
		enemy.melee_damage *= trial_enemy_damage_multiplier
		enemy.melee_attack_interval = maxf(
			enemy.melee_attack_interval
				* trial_attack_interval_multiplier,
			minimum_enemy_attack_interval * 0.75
		)


## Calculates one spawn-time Qi reward from the combined difficulty step and
## enemy traits. EnemySpawner snapshots this value so later route or difficulty
## changes cannot alter an already spawned enemy's payout.
func get_enemy_qi_drop_amount(
	difficulty_step: int,
	is_elite: bool,
	is_trial_hell: bool,
	is_rear_pursuer: bool
) -> int:
	var reward := (
		float(maxi(enemy_qi_drop_amount, 1))
		+ float(maxi(difficulty_step, 0))
			* maxf(qi_drop_increase_per_difficulty_step, 0.0)
	)
	if is_elite:
		reward *= maxf(elite_qi_drop_multiplier, 0.0)
	if is_trial_hell:
		reward *= maxf(trial_qi_drop_multiplier, 0.0)
	if is_rear_pursuer:
		reward *= maxf(rear_qi_drop_multiplier, 0.0)
	return clampi(
		roundi(reward),
		1,
		maxi(maximum_enemy_qi_drop, 1)
	)


func _on_enemy_defeated(
	drop_position: Vector2,
	inherited_velocity: Vector2,
	defeated_enemy: EnemyController,
	qi_reward: int
) -> void:
	_drop_qi(drop_position, qi_reward)
	if (
		is_instance_valid(defeated_enemy)
		and defeated_enemy.is_elite_enemy()
	):
		_drop_technique_fragment(
			drop_position + Vector2(-72.0, 50.0),
			inherited_velocity
		)
		_drop_weapon_power_fragment(
			drop_position + Vector2(72.0, -50.0),
			inherited_velocity
		)
	if _rng.randf() <= clampf(weapon_drop_chance, 0.0, 1.0):
		_drop_weapon(drop_position, inherited_velocity)


func _drop_qi(drop_position: Vector2, qi_reward: int) -> void:
	if qi_pickup_scene == null:
		return
	var qi_pickup := qi_pickup_scene.instantiate() as QiPickup
	if qi_pickup == null:
		push_error("EnemySpawner qi_pickup_scene must instantiate QiPickup.")
		return
	call_deferred("add_child", qi_pickup)
	qi_pickup.global_position = drop_position
	qi_pickup.configure_value(qi_reward)
	qi_pickup.qi_collected.connect(_on_dropped_qi_collected)


func _drop_weapon(
	drop_position: Vector2,
	inherited_velocity: Vector2
) -> void:
	if weapon_pickup_scene == null:
		return
	var weapon_pickup := weapon_pickup_scene.instantiate() as WeaponPickup
	if weapon_pickup == null:
		push_error(
			"EnemySpawner weapon_pickup_scene must instantiate WeaponPickup."
		)
		return
	var available_weapons: Array[WeaponDataResource] = []
	for weapon_data in weapon_drop_pool:
		if weapon_data != null and weapon_data.is_valid_definition():
			available_weapons.append(weapon_data)
	if available_weapons.is_empty():
		push_warning("EnemySpawner weapon_drop_pool has no valid WeaponData.")
		weapon_pickup.queue_free()
		return
	var weapon_data := available_weapons[
		_rng.randi_range(0, available_weapons.size() - 1)
	]
	weapon_pickup.configure(
		weapon_data,
		weapon_data.roll_damage(_rng),
		inherited_velocity,
		player
	)
	call_deferred("add_child", weapon_pickup)
	weapon_pickup.global_position = drop_position


func _drop_technique_fragment(
	drop_position: Vector2,
	inherited_velocity: Vector2
) -> void:
	if technique_fragment_scene == null:
		return
	var fragment := technique_fragment_scene.instantiate()
	if fragment == null:
		push_error(
			"EnemySpawner technique_fragment_scene must instantiate "
			+ "TechniqueFragment."
		)
		return
	fragment.call("configure", player, inherited_velocity)
	add_child(fragment)
	fragment.global_position = drop_position
	fragment.connect(
		"fragment_collected",
		_on_technique_fragment_collected
	)


func _drop_weapon_power_fragment(
	drop_position: Vector2,
	inherited_velocity: Vector2
) -> void:
	if weapon_power_fragment_scene == null:
		return
	var fragment := weapon_power_fragment_scene.instantiate()
	if fragment == null:
		push_error(
			"EnemySpawner weapon_power_fragment_scene must instantiate "
			+ "WeaponPowerFragment."
		)
		return
	fragment.call("configure", player, inherited_velocity)
	add_child(fragment)
	fragment.global_position = drop_position
	fragment.connect(
		"power_fragment_collected",
		_on_weapon_power_fragment_collected
	)


func _on_dropped_qi_collected(amount: int) -> void:
	qi_collected.emit(amount)


func _on_technique_fragment_collected(amount: int) -> void:
	technique_fragment_collected.emit(amount)


func _on_weapon_power_fragment_collected(amount: int) -> void:
	weapon_power_fragment_collected.emit(amount)


func _remove_enemies_outside_active_route() -> void:
	var allowed_half_width := maxf(
		road_half_width - road_edge_clearance,
		1.0
	)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if (
			enemy_node is EnemyController
			and absf(enemy_node.global_position.x - _route_center_x)
				> allowed_half_width
		):
			(enemy_node as EnemyController).set_combat_enabled(false)
			enemy_node.queue_free()
