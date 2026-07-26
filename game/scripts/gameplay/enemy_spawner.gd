class_name EnemySpawner
extends Node2D

signal qi_collected(amount: int)
signal universal_upgrade_collected(upgrade_type: int, amount: int)
## Relays actual enemy health removed for the current run summary.
signal player_damage_recorded(source_id: StringName, amount: int)
## Relays one confirmed enemy defeat, including whether it was elite.
signal enemy_defeat_recorded(is_elite: bool)

enum EliteRoadWidthBand {
	VERY_NARROW,
	NARROW,
	STANDARD,
	WIDE,
}

const WeaponDataResource = preload(
	"res://game/scripts/gameplay/weapon_data.gd"
)
const EliteRewardChoiceResource = preload(
	"res://game/scripts/gameplay/elite_reward_choice.gd"
)
const DAO_DATA: WeaponDataResource = preload("res://game/resources/weapon/dao.tres")
const FLYING_SWORD_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/flying_sword.tres"
)
const QIANKUN_RING_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/qiankun_ring.tres"
)
const GOLDEN_BELL_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/golden_bell.tres"
)
const THUNDER_HAMMER_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/thunder_hammer.tres"
)
const FANTIAN_SEAL_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/fantian_seal.tres"
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
## Weapon pickup used twice for every defeated weapon-rewarding elite.
@export var weapon_pickup_scene: PackedScene = preload(
	"res://game/scenes/gameplay/weapon_pickup.tscn"
)
## Global-upgrade fragment used twice for every defeated fragment-rewarding elite.
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
## Lower bound, in seconds, for the complete warning-to-warning interval of
## normal-road ranged enemies after difficulty scaling.
@export_range(0.2, 4.0, 0.05) var minimum_enemy_ranged_attack_interval: float = 1.25
## Lower bound, in seconds, for ranged attack intervals in Trial Hell. This
## independently bounds its attack-frequency multiplier.
@export_range(0.2, 4.0, 0.05) var trial_minimum_enemy_ranged_attack_interval: float = 1.0
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
## Normal-road elite probability at the start of a run. It eases toward
## elite_spawn_chance as combined difficulty pressure rises.
@export_range(0.0, 1.0, 0.01) var initial_elite_spawn_chance: float = 0.10
## Normal-road elite probability after the progression curve reaches its cap.
@export_range(0.0, 1.0, 0.01) var elite_spawn_chance: float = 0.18
## Trial Hell elite probability at the start of a run.
@export_range(0.0, 1.0, 0.01) var trial_initial_elite_spawn_chance: float = 0.12
## Trial Hell elite probability after the progression curve reaches its cap.
@export_range(0.0, 1.0, 0.01) var trial_elite_spawn_chance: float = 0.30
## Combined time-and-cultivation difficulty steps required for the elite chance
## curve to mature. This synchronizes reward access with enemy pressure.
@export_range(1, 100, 1) var elite_ramp_difficulty_steps: int = 18
## Minimum seconds between non-guaranteed elite spawns on a normal road.
@export_range(0.0, 30.0, 0.5) var minimum_elite_spawn_interval: float = 6.0
## Minimum seconds between non-guaranteed elite spawns in Trial Hell.
@export_range(0.0, 30.0, 0.5) var trial_minimum_elite_spawn_interval: float = 4.0
## Maximum unpaused seconds without an elite spawn on a normal road before the
## next eligible spawn is forced elite. Pity never exceeds active caps.
@export_range(1.0, 180.0, 1.0) var normal_elite_pity_seconds: float = 30.0
## Maximum unpaused seconds without an elite spawn in Trial Hell before the
## next eligible spawn is forced elite. Pity never exceeds active caps.
@export_range(1.0, 180.0, 1.0) var trial_elite_pity_seconds: float = 20.0
## Ordinary defeats allowed between normal-road elite spawns before the next
## eligible spawn is forced elite.
@export_range(1, 100, 1) var normal_elite_pity_defeats: int = 8
## Ordinary defeats allowed between Trial Hell elite spawns before the next
## eligible spawn is forced elite.
@export_range(1, 100, 1) var trial_elite_pity_defeats: int = 6
## Maximum elite share of the current total-enemy cap on a normal road. This
## population cap is combined with the road-width cap below.
@export_range(0.01, 1.0, 0.01) var normal_elite_population_ratio: float = 0.16
## Maximum elite share of the current total-enemy cap in Trial Hell.
@export_range(0.01, 1.0, 0.01) var trial_elite_population_ratio: float = 0.18
## Half-width in world pixels at or below which a road is very narrow.
@export_range(60.0, 300.0, 5.0) var elite_very_narrow_half_width: float = 140.0
## Half-width in world pixels at or below which a road is narrow.
@export_range(80.0, 400.0, 5.0) var elite_narrow_half_width: float = 180.0
## Half-width in world pixels at or below which a road is standard. Larger
## roads use the wide-road elite cap.
@export_range(100.0, 600.0, 5.0) var elite_standard_half_width: float = 240.0
## Half-width hysteresis in world pixels that prevents repeated elite-cap
## changes when a generated road hovers near a width threshold.
@export_range(0.0, 50.0, 1.0) var elite_road_width_hysteresis: float = 10.0
## Maximum active elites on a very narrow normal road.
@export_range(1, 20, 1) var normal_very_narrow_elite_cap: int = 3
## Maximum active elites on a narrow normal road.
@export_range(1, 20, 1) var normal_narrow_elite_cap: int = 4
## Maximum active elites on a standard normal road.
@export_range(1, 20, 1) var normal_standard_elite_cap: int = 5
## Maximum active elites on a wide normal road.
@export_range(1, 20, 1) var normal_wide_elite_cap: int = 6
## Maximum active elites on a very narrow Trial Hell road.
@export_range(1, 30, 1) var trial_very_narrow_elite_cap: int = 3
## Maximum active elites on a narrow Trial Hell road.
@export_range(1, 30, 1) var trial_narrow_elite_cap: int = 4
## Maximum active elites on a standard Trial Hell road.
@export_range(1, 30, 1) var trial_standard_elite_cap: int = 6
## Maximum active elites on a wide Trial Hell road.
@export_range(1, 30, 1) var trial_wide_elite_cap: int = 7
## Health multiplier applied to normal-road elites after difficulty scaling.
## The reduced default avoids making a recovery reward a severe farming tax.
@export_range(1.1, 10.0, 0.1) var elite_health_multiplier: float = 2.5
## Health multiplier applied to Trial Hell elites after route difficulty.
## Trial Hell retains the former triple-health elite challenge.
@export_range(1.1, 10.0, 0.1) var trial_elite_health_multiplier: float = 3.0
## Melee-range multiplier applied to elite enemies.
@export_range(1.1, 4.0, 0.1) var elite_attack_range_multiplier: float = 1.6
## Visual and collision scale applied to elite enemy bodies.
@export_range(1.0, 2.0, 0.05) var elite_visual_scale: float = 1.25
## Chance that the first unsequenced elite grants a weapon choice. Later elite
## reward categories alternate to prevent weapon or power-fragment droughts.
@export_range(0.0, 1.0, 0.05) var weapon_reward_elite_ratio: float = 0.5
## Unpaused run time in seconds by which at least one weapon-rewarding elite
## must have spawned. Crossing this mark creates one immediately if needed.
@export_range(1.0, 120.0, 1.0) var first_weapon_elite_guarantee_seconds: float = 15.0
## Unpaused run time in seconds by which at least one fragment-rewarding elite
## must have spawned. Crossing this mark creates one immediately if needed.
@export_range(1.0, 120.0, 1.0) var first_fragment_elite_guarantee_seconds: float = 25.0

@export_category("Enemy Variants")
## Chance for an ordinary spawn to become a low-health self-destruct enemy.
@export_range(0.0, 1.0, 0.01) var bomber_spawn_chance: float = 0.12
## Chance for an ordinary ground spawn to heal nearby enemies periodically.
## Healers never receive elite or flying packages.
@export_range(0.0, 1.0, 0.01) var healer_spawn_chance: float = 0.10
## Flying-variant chance after its realm/layer threshold is unlocked.
@export_range(0.0, 1.0, 0.01) var flying_spawn_chance: float = 0.38
## Ranged flying chance at Golden Core layer one. It ramps toward
## ranged_flying_spawn_chance over the rest of Golden Core.
@export_range(0.0, 1.0, 0.01) var initial_ranged_flying_spawn_chance: float = 0.12
## Ranged flying chance reached at Golden Core layer nine.
@export_range(0.0, 1.0, 0.01) var ranged_flying_spawn_chance: float = 0.22
## Ranged flying chance from Nascent Soul layer one onward.
@export_range(0.0, 1.0, 0.01) var nascent_ranged_flying_spawn_chance: float = 0.30
## Overall cultivation level that first unlocks ranged flying enemies.
@export_range(1, 100, 1) var ranged_unlock_cultivation_level: int = 19
## Overall cultivation level that switches from the introductory to the
## established Golden Core active-ranged cap.
@export_range(1, 100, 1) var ranged_cap_increase_cultivation_level: int = 22
## Overall cultivation level that begins Nascent Soul ranged tuning.
@export_range(1, 100, 1) var nascent_ranged_cultivation_level: int = 28
## Maximum active ranged enemies during introductory Golden Core layers.
@export_range(1, 12, 1) var golden_initial_ranged_enemy_cap: int = 1
## Maximum active ranged enemies during established Golden Core layers.
@export_range(1, 12, 1) var golden_late_ranged_enemy_cap: int = 2
## Maximum active ranged enemies from Nascent Soul onward.
@export_range(1, 12, 1) var nascent_ranged_enemy_cap: int = 3
## Extra active ranged enemies allowed while Trial Hell is active.
@export_range(0, 8, 1) var trial_ranged_enemy_cap_bonus: int = 1
## Maximum simultaneous high-salience ranged wind-ups on normal roads.
@export_range(1, 8, 1) var ranged_windup_cap: int = 1
## Maximum simultaneous high-salience ranged wind-ups in Trial Hell.
@export_range(1, 8, 1) var trial_ranged_windup_cap: int = 2
## Overall cultivation level that unlocks slow autonomous movement for eligible
## flying elites.
@export_range(1, 100, 1) var slow_autonomous_unlock_cultivation_level: int = 23
## Overall cultivation level that unlocks fast autonomous movement for eligible
## flying enemies.
@export_range(1, 100, 1) var fast_autonomous_unlock_cultivation_level: int = 28
## Slow lateral speed granted to flying elites from Golden Core layer five.
@export_range(0.0, 500.0, 5.0) var slow_autonomous_speed: float = 80.0
## Fast lateral speed available to all flying enemies from Nascent Soul one.
@export_range(0.0, 800.0, 5.0) var fast_autonomous_speed: float = 220.0
## Chance that an eligible Golden Core elite receives slow autonomous movement.
@export_range(0.0, 1.0, 0.01) var slow_autonomous_spawn_chance: float = 0.55
## Chance that an eligible Nascent Soul spawn uses fast autonomous movement.
@export_range(0.0, 1.0, 0.01) var fast_autonomous_spawn_chance: float = 0.72

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
## enemy-type multipliers. This compensates more of the rising farming pressure.
@export_range(0.0, 20.0, 0.05) var qi_drop_increase_per_difficulty_step: float = 0.75
## Qi multiplier for elite enemies. This deliberately compensates only part of
## their increased health because elites also grant one exclusive reward choice.
@export_range(0.0, 5.0, 0.05) var elite_qi_drop_multiplier: float = 2.0
## Qi multiplier for enemies spawned while Trial Hell is active. It stacks with
## elite and rear-pursuer multipliers and rewards the route's added danger.
@export_range(0.0, 5.0, 0.05) var trial_qi_drop_multiplier: float = 1.2
## Qi multiplier for faster enemies spawned behind the player.
@export_range(0.0, 5.0, 0.05) var rear_qi_drop_multiplier: float = 1.15
## Hard upper bound for one enemy's Qi reward after every modifier.
@export_range(1, 5000, 1) var maximum_enemy_qi_drop: int = 200
## Designer-managed definitions eligible for enemy drops. Invalid or null
## entries are ignored; damage, identity, and combat tuning belong to each
## shared WeaponData resource rather than this spawner.
@export var weapon_drop_pool: Array[WeaponDataResource] = [
	DAO_DATA,
	FLYING_SWORD_DATA,
	QIANKUN_RING_DATA,
	GOLDEN_BELL_DATA,
	THUNDER_HAMMER_DATA,
	FANTIAN_SEAL_DATA,
]
## Center-to-center separation in world pixels between the two reward options.
## This must remain larger than twice reward_choice_radius so focus areas never
## overlap and both choices remain distinct.
@export_range(80.0, 240.0, 2.0) var reward_choice_separation: float = 96.0
## Channel radius in world pixels for each elite reward option. The paired
## default is smaller than the former single-drop circles.
@export_range(24.0, 80.0, 1.0) var reward_choice_radius: float = 38.0
## Minimum world-space distance between the centers of active reward pairs.
## New pairs are moved farther ahead until this clearance is available.
@export_range(100.0, 400.0, 5.0) var reward_group_minimum_spacing: float = 180.0
## Minimum distance in world pixels that a reward pair is placed ahead of the
## player. This makes rewards from enemies defeated behind the player reachable.
@export_range(0.0, 300.0, 5.0) var reward_minimum_forward_distance: float = 80.0
## Clearance in world pixels retained between either reward circle and the
## generated road edge after accounting for the pair's full horizontal extent.
@export_range(0.0, 80.0, 1.0) var reward_road_edge_clearance: float = 8.0
## Independent forward speed in world pixels per second for every reward pair.
## Focus never changes this speed; players synchronize by regulating their own
## movement while remaining inside one option's channel radius.
@export_range(40.0, 400.0, 5.0) var reward_vertical_drift_speed: float = 140.0
## Extra world pixels beyond each camera edge allowed before an unclaimed
## reward-choice group's center is removed.
@export_range(0.0, 1000.0, 10.0) var reward_offscreen_despawn_margin: float = 200.0
## Maximum unpaused seconds an unclaimed reward-choice group remains alive.
## Set to zero to disable lifetime cleanup while retaining offscreen cleanup.
@export_range(0.0, 180.0, 1.0) var reward_choice_lifetime_seconds: float = 30.0

var road_half_width: float = 200.0
var _spawn_time_remaining: float = 0.0
var _rear_spawn_time_remaining: float = 0.0
var _spawning_enabled: bool = true
var _rng := RandomNumberGenerator.new()
var _route_center_x: float = 0.0
var _elapsed_run_time: float = 0.0
var _cultivation_level: int = 1
var _trial_hell_active: bool = false
var _road_half_width_resolver: Callable
var _weapon_reward_elite_spawned: bool = false
var _fragment_reward_elite_spawned: bool = false
var _elite_spawn_time_remaining: float = 0.0
var _elite_pity_time_elapsed: float = 0.0
var _ordinary_defeats_since_elite: int = 0
var _last_elite_reward_type: int = EnemyController.EliteRewardType.NONE
var _forward_elite_road_band: int = -1
var _rear_elite_road_band: int = -1
var _active_ranged_attackers: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_elapsed_run_time = 0.0
	_cultivation_level = 1
	_weapon_reward_elite_spawned = false
	_fragment_reward_elite_spawned = false
	_elite_spawn_time_remaining = 0.0
	_elite_pity_time_elapsed = 0.0
	_ordinary_defeats_since_elite = 0
	_last_elite_reward_type = EnemyController.EliteRewardType.NONE
	_forward_elite_road_band = -1
	_rear_elite_road_band = -1
	_active_ranged_attackers.clear()
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
	_elite_pity_time_elapsed += delta
	_spawn_time_remaining -= delta
	_rear_spawn_time_remaining -= delta
	_elite_spawn_time_remaining = maxf(
		_elite_spawn_time_remaining - delta,
		0.0
	)
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
	_spawn_due_elite_guarantees()


## Synchronizes enemy placement with the generated road.
func set_road_half_width(value: float) -> void:
	road_half_width = maxf(value, road_edge_clearance + 1.0)


## Supplies a world-Y to half-width resolver owned by InfiniteWorld. Keeping the
## callable optional preserves isolated spawner scenes and tests.
func set_road_half_width_resolver(resolver: Callable) -> void:
	_road_half_width_resolver = resolver
	_refresh_enemy_road_constraints()


## Moves future enemy spawn X positions to the active infinite route.
func set_route_center_x(value: float) -> void:
	_route_center_x = value
	_remove_enemies_outside_active_route()
	_refresh_enemy_road_constraints()
	_reposition_reward_groups_to_active_route()


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


## Returns the number of living elite enemies sharing this spawner's scene tree.
func get_active_elite_count() -> int:
	var active_elites := 0
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if (
			enemy_node is EnemyController
			and (enemy_node as EnemyController).is_elite_enemy()
		):
			active_elites += 1
	return active_elites


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


func get_debug_snapshot() -> Dictionary:
	return {
		"elapsed_run_time": _elapsed_run_time,
		"cultivation_level": _cultivation_level,
		"difficulty_step": get_difficulty_step(),
		"active_enemies": get_active_enemy_count(),
		"maximum_enemies": get_current_max_active_enemies(),
		"active_elites": get_active_elite_count(),
		"active_ranged_enemies": get_active_ranged_enemy_count(),
		"ranged_enemy_cap": get_current_ranged_enemy_cap(),
		"ranged_spawn_chance": get_current_ranged_flying_spawn_chance(),
		"active_ranged_windups": get_active_ranged_windup_count(),
		"ranged_windup_cap": get_current_ranged_windup_cap(),
		"elite_spawn_chance": get_current_elite_spawn_chance(),
		"elite_spawn_cooldown": _elite_spawn_time_remaining,
		"elite_pity_time": _elite_pity_time_elapsed,
		"ordinary_defeats_since_elite": _ordinary_defeats_since_elite,
		"elite_pity_due": is_elite_pity_due(),
		"forward_elite_cap": get_current_elite_cap(
			_get_spawn_y(false)
		),
		"rear_elite_cap": get_current_elite_cap(
			_get_spawn_y(true)
		),
		"forward_spawn_interval": get_current_spawn_interval(false),
		"rear_spawn_interval": get_current_spawn_interval(true),
		"trial_hell_active": _trial_hell_active,
		"route_center_x": _route_center_x,
		"weapon_reward_elite_spawned": _weapon_reward_elite_spawned,
		"fragment_reward_elite_spawned": _fragment_reward_elite_spawned,
	}


func get_time_difficulty_step() -> int:
	return floori(
		_elapsed_run_time / maxf(difficulty_step_seconds, 1.0)
	)


## Returns the current progression-ramped chance for an eligible enemy to use
## the ranged package. Active population caps are checked separately.
func get_current_ranged_flying_spawn_chance() -> float:
	var unlock_level := maxi(ranged_unlock_cultivation_level, 1)
	if _cultivation_level < unlock_level:
		return 0.0
	var nascent_level := maxi(
		nascent_ranged_cultivation_level,
		unlock_level + 1
	)
	if _cultivation_level >= nascent_level:
		return clampf(nascent_ranged_flying_spawn_chance, 0.0, 1.0)
	var golden_end_level := nascent_level - 1
	var progress := clampf(
		float(_cultivation_level - unlock_level)
			/ float(maxi(golden_end_level - unlock_level, 1)),
		0.0,
		1.0
	)
	return lerpf(
		clampf(initial_ranged_flying_spawn_chance, 0.0, 1.0),
		clampf(ranged_flying_spawn_chance, 0.0, 1.0),
		progress
	)


## Returns the current active-ranged population cap before a new variant is
## admitted. Trial Hell adds its explicit designer-tunable bonus.
func get_current_ranged_enemy_cap() -> int:
	if _cultivation_level < maxi(ranged_unlock_cultivation_level, 1):
		return 0
	var cap := golden_initial_ranged_enemy_cap
	if _cultivation_level >= maxi(nascent_ranged_cultivation_level, 1):
		cap = nascent_ranged_enemy_cap
	elif _cultivation_level >= maxi(
		ranged_cap_increase_cultivation_level,
		ranged_unlock_cultivation_level
	):
		cap = golden_late_ranged_enemy_cap
	if _trial_hell_active:
		cap += maxi(trial_ranged_enemy_cap_bonus, 0)
	return maxi(cap, 1)


## Counts living ranged enemies across the active scene tree.
func get_active_ranged_enemy_count() -> int:
	var active_ranged := 0
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if (
			enemy_node is EnemyController
			and (enemy_node as EnemyController).is_combat_active()
			and (enemy_node as EnemyController).uses_ranged_attack
		):
			active_ranged += 1
	return active_ranged


func _can_add_ranged_enemy() -> bool:
	return (
		get_current_ranged_enemy_cap() > 0
		and get_active_ranged_enemy_count() < get_current_ranged_enemy_cap()
	)


## Returns the warning-admission cap for the active route.
func get_current_ranged_windup_cap() -> int:
	return maxi(
		trial_ranged_windup_cap if _trial_hell_active else ranged_windup_cap,
		1
	)


## Returns the number of ranged enemies currently holding a warning slot.
func get_active_ranged_windup_count() -> int:
	_prune_ranged_attackers()
	return _active_ranged_attackers.size()


## Grants one ranged warning slot when the active route has presentation room.
func try_acquire_ranged_attack_slot(enemy: EnemyController) -> bool:
	_prune_ranged_attackers()
	if not is_instance_valid(enemy) or not enemy.is_combat_active():
		return false
	var enemy_id := enemy.get_instance_id()
	if _active_ranged_attackers.has(enemy_id):
		return true
	if _active_ranged_attackers.size() >= get_current_ranged_windup_cap():
		return false
	_active_ranged_attackers[enemy_id] = weakref(enemy)
	return true


## Releases a warning slot after attack completion, cancellation, or removal.
func release_ranged_attack_slot(enemy: EnemyController) -> void:
	if not is_instance_valid(enemy):
		_prune_ranged_attackers()
		return
	_active_ranged_attackers.erase(enemy.get_instance_id())


func _prune_ranged_attackers() -> void:
	var stale_ids: Array[int] = []
	for enemy_id_variant in _active_ranged_attackers:
		var enemy_id := int(enemy_id_variant)
		var enemy_reference := (
			_active_ranged_attackers[enemy_id] as WeakRef
		)
		var enemy := (
			enemy_reference.get_ref() as EnemyController
			if enemy_reference != null
			else null
		)
		if (
			not is_instance_valid(enemy)
			or not enemy.is_combat_active()
			or not enemy.is_attack_winding_up()
		):
			stale_ids.append(enemy_id)
	for stale_id in stale_ids:
		_active_ranged_attackers.erase(stale_id)


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


## Returns the smoothly ramped elite probability for the active route.
func get_current_elite_spawn_chance() -> float:
	var difficulty_progress := clampf(
		float(get_difficulty_step())
			/ float(maxi(elite_ramp_difficulty_steps, 1)),
		0.0,
		1.0
	)
	var progress := smoothstep(
		0.0,
		1.0,
		difficulty_progress
	)
	var start_chance := (
		trial_initial_elite_spawn_chance
		if _trial_hell_active
		else initial_elite_spawn_chance
	)
	var end_chance := (
		trial_elite_spawn_chance
		if _trial_hell_active
		else elite_spawn_chance
	)
	return clampf(
		lerpf(start_chance, end_chance, progress),
		0.0,
		1.0
	)


## Returns whether elapsed time or ordinary defeats have activated the current
## route's bad-luck protection. Admission still requires no living elite and
## room under the active road-width and population caps.
func is_elite_pity_due() -> bool:
	var pity_seconds := (
		trial_elite_pity_seconds
		if _trial_hell_active
		else normal_elite_pity_seconds
	)
	var pity_defeats := (
		trial_elite_pity_defeats
		if _trial_hell_active
		else normal_elite_pity_defeats
	)
	return (
		_elite_pity_time_elapsed >= maxf(pity_seconds, 1.0)
		or _ordinary_defeats_since_elite >= maxi(pity_defeats, 1)
	)


## Returns the current global elite cooldown for the active route.
func get_current_minimum_elite_spawn_interval() -> float:
	return maxf(
		trial_minimum_elite_spawn_interval
			if _trial_hell_active
			else minimum_elite_spawn_interval,
		0.0
	)


## Returns the dynamic active-elite cap at one world Y. The lower of the
## road-width cap and the current total-population ratio cap wins.
func get_current_elite_cap(world_y: float) -> int:
	var road_band := _get_nominal_elite_road_band(
		_get_road_half_width_at(world_y)
	)
	return _get_elite_cap_for_band(road_band)


func _get_elite_cap_for_band(road_band: int) -> int:
	var width_cap := 1
	if _trial_hell_active:
		match road_band:
			EliteRoadWidthBand.VERY_NARROW:
				width_cap = trial_very_narrow_elite_cap
			EliteRoadWidthBand.NARROW:
				width_cap = trial_narrow_elite_cap
			EliteRoadWidthBand.STANDARD:
				width_cap = trial_standard_elite_cap
			_:
				width_cap = trial_wide_elite_cap
	else:
		match road_band:
			EliteRoadWidthBand.VERY_NARROW:
				width_cap = normal_very_narrow_elite_cap
			EliteRoadWidthBand.NARROW:
				width_cap = normal_narrow_elite_cap
			EliteRoadWidthBand.STANDARD:
				width_cap = normal_standard_elite_cap
			_:
				width_cap = normal_wide_elite_cap
	var population_ratio := (
		trial_elite_population_ratio
		if _trial_hell_active
		else normal_elite_population_ratio
	)
	var population_cap := maxi(
		ceili(
			float(get_current_max_active_enemies())
				* clampf(population_ratio, 0.01, 1.0)
		),
		1
	)
	return mini(maxi(width_cap, 1), population_cap)


func _get_nominal_elite_road_band(half_width: float) -> int:
	if half_width <= elite_very_narrow_half_width:
		return EliteRoadWidthBand.VERY_NARROW
	if half_width <= elite_narrow_half_width:
		return EliteRoadWidthBand.NARROW
	if half_width <= elite_standard_half_width:
		return EliteRoadWidthBand.STANDARD
	return EliteRoadWidthBand.WIDE


func _resolve_elite_road_band(
	half_width: float,
	from_behind: bool
) -> int:
	var current_band := (
		_rear_elite_road_band
		if from_behind
		else _forward_elite_road_band
	)
	var candidate := _get_nominal_elite_road_band(half_width)
	var hysteresis := maxf(elite_road_width_hysteresis, 0.0)
	if current_band >= 0 and candidate != current_band and hysteresis > 0.0:
		var boundary := elite_very_narrow_half_width
		if mini(candidate, current_band) == EliteRoadWidthBand.NARROW:
			boundary = elite_narrow_half_width
		elif mini(candidate, current_band) == EliteRoadWidthBand.STANDARD:
			boundary = elite_standard_half_width
		if candidate > current_band and half_width <= boundary + hysteresis:
			candidate = current_band
		elif candidate < current_band and half_width >= boundary - hysteresis:
			candidate = current_band
	if from_behind:
		_rear_elite_road_band = candidate
	else:
		_forward_elite_road_band = candidate
	return candidate


func _can_spawn_random_elite(spawn_y: float, from_behind: bool) -> bool:
	if _elite_spawn_time_remaining > 0.0:
		return false
	var road_band := _resolve_elite_road_band(
		_get_road_half_width_at(spawn_y),
		from_behind
	)
	if get_active_elite_count() >= _get_elite_cap_for_band(road_band):
		return false
	if get_active_elite_count() == 0 and is_elite_pity_due():
		return true
	return _rng.randf() <= get_current_elite_spawn_chance()


func _get_spawn_y(from_behind: bool) -> float:
	var viewport_height := get_viewport_rect().size.y
	var vertical_zoom := maxf(camera.zoom.y, 0.01)
	var half_visible_height := viewport_height / vertical_zoom * 0.5
	if from_behind:
		return (
			camera.global_position.y
			+ half_visible_height
			+ rear_spawn_margin
		)
	return (
		camera.global_position.y
		- half_visible_height
		- spawn_ahead_margin
	)


func _spawn_enemy(
	from_behind: bool = false,
	forced_elite_reward_type: int = EnemyController.EliteRewardType.NONE
) -> void:
	if enemy_scene == null:
		return
	var enemy := enemy_scene.instantiate() as EnemyController
	if enemy == null:
		push_error("EnemySpawner enemy_scene must instantiate EnemyController.")
		return
	enemy.player = player
	enemy.configure_ranged_attack_slots(
		Callable(self, "try_acquire_ranged_attack_slot"),
		Callable(self, "release_ranged_attack_slot")
	)
	_apply_current_difficulty(enemy)
	var has_forced_elite_reward := (
		forced_elite_reward_type == EnemyController.EliteRewardType.WEAPON
		or forced_elite_reward_type
			== EnemyController.EliteRewardType.POWER_FRAGMENT
	)
	var spawn_y := _get_spawn_y(from_behind)
	var elite := (
		has_forced_elite_reward
		or _can_spawn_random_elite(spawn_y, from_behind)
	)
	if elite:
		var reward_type := (
			forced_elite_reward_type
			if has_forced_elite_reward
			else _get_next_elite_reward_type()
		)
		enemy.configure_elite(
			(
				trial_elite_health_multiplier
				if _trial_hell_active
				else elite_health_multiplier
			),
			elite_attack_range_multiplier,
			elite_visual_scale,
			reward_type
		)
		_record_elite_reward_spawn(reward_type)
		_elite_spawn_time_remaining = (
			get_current_minimum_elite_spawn_interval()
		)
	_configure_enemy_variant(enemy, elite)
	var qi_reward := get_enemy_qi_drop_amount(
		get_difficulty_step(),
		enemy.is_elite_enemy(),
		_trial_hell_active,
		from_behind
	)
	enemy.defeated.connect(
		_on_enemy_defeated.bind(enemy, qi_reward)
	)
	enemy.damage_recorded.connect(_on_enemy_damage_recorded)

	if from_behind:
		enemy.cruise_speed = maxf(rear_enemy_forward_speed, 1.0)
	var usable_half_width := maxf(
		_get_road_half_width_at(spawn_y) - road_edge_clearance,
		1.0
	)
	enemy.global_position = Vector2(
		_route_center_x
			+ _rng.randf_range(-usable_half_width, usable_half_width),
		spawn_y
	)
	enemy.configure_road_constraint(
		_route_center_x,
		Callable(self, "_get_road_half_width_at"),
		road_edge_clearance
	)
	add_child(enemy)


func _spawn_due_elite_guarantees() -> void:
	if (
		not _weapon_reward_elite_spawned
		and _elapsed_run_time
			>= maxf(first_weapon_elite_guarantee_seconds, 1.0)
	):
		_spawn_enemy(false, EnemyController.EliteRewardType.WEAPON)
	if (
		not _fragment_reward_elite_spawned
		and _elapsed_run_time
			>= maxf(first_fragment_elite_guarantee_seconds, 1.0)
	):
		_spawn_enemy(false, EnemyController.EliteRewardType.POWER_FRAGMENT)


func _record_elite_reward_spawn(reward_type: int) -> void:
	_elite_pity_time_elapsed = 0.0
	_ordinary_defeats_since_elite = 0
	_last_elite_reward_type = reward_type
	match reward_type:
		EnemyController.EliteRewardType.WEAPON:
			_weapon_reward_elite_spawned = true
		EnemyController.EliteRewardType.POWER_FRAGMENT:
			_fragment_reward_elite_spawned = true


func _get_next_elite_reward_type() -> int:
	match _last_elite_reward_type:
		EnemyController.EliteRewardType.WEAPON:
			return EnemyController.EliteRewardType.POWER_FRAGMENT
		EnemyController.EliteRewardType.POWER_FRAGMENT:
			return EnemyController.EliteRewardType.WEAPON
		_:
			return (
				EnemyController.EliteRewardType.WEAPON
				if _rng.randf()
					<= clampf(weapon_reward_elite_ratio, 0.0, 1.0)
				else EnemyController.EliteRewardType.POWER_FRAGMENT
			)


func _configure_enemy_variant(enemy: EnemyController, elite: bool) -> void:
	if not elite:
		var role_roll := _rng.randf()
		if role_roll <= bomber_spawn_chance:
			enemy.configure_archetype(EnemyController.EnemyArchetype.BOMBER)
		elif role_roll <= bomber_spawn_chance + healer_spawn_chance:
			enemy.configure_archetype(EnemyController.EnemyArchetype.HEALER)

	# Healers are deliberately ordinary ground support enemies. Returning
	# before the flight rolls prevents every aerial package from being stacked
	# onto them as progression advances.
	if enemy.archetype == EnemyController.EnemyArchetype.HEALER:
		return

	var use_fast_autonomous := (
		_cultivation_level >= fast_autonomous_unlock_cultivation_level
		and _rng.randf() <= fast_autonomous_spawn_chance
	)
	var use_slow_autonomous := (
		not use_fast_autonomous
		and elite
		and _cultivation_level >= slow_autonomous_unlock_cultivation_level
		and _rng.randf() <= slow_autonomous_spawn_chance
	)
	var use_ranged_attack := (
		_can_add_ranged_enemy()
		and _rng.randf() <= get_current_ranged_flying_spawn_chance()
	)
	if use_fast_autonomous:
		enemy.configure_flying(3, use_ranged_attack, fast_autonomous_speed)
	elif use_slow_autonomous:
		enemy.configure_flying(2, use_ranged_attack, slow_autonomous_speed)
	elif use_ranged_attack:
		enemy.configure_flying(
			3 if _cultivation_level >= nascent_ranged_cultivation_level else 2,
			true,
			0.0
		)
	elif (
		(
			not elite and _cultivation_level >= 12
			or elite and _cultivation_level >= 14
		)
		and _rng.randf() <= flying_spawn_chance
	):
		enemy.configure_flying(1, false, 0.0)


func _apply_current_difficulty(enemy: EnemyController) -> void:
	var difficulty_step := get_difficulty_step()
	enemy.max_health += difficulty_step * maxi(health_increase_per_step, 0)
	enemy.melee_damage += (
		float(difficulty_step) * maxf(damage_increase_per_step, 0.0)
	)
	var attack_interval_scale := pow(
		clampf(
			attack_interval_multiplier_per_step,
			0.01,
			1.0
		),
		float(difficulty_step)
	)
	enemy.melee_attack_interval = maxf(
		enemy.melee_attack_interval * attack_interval_scale,
		minimum_enemy_attack_interval
	)
	enemy.ranged_attack_interval = maxf(
		enemy.ranged_attack_interval * attack_interval_scale,
		minimum_enemy_ranged_attack_interval
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
		enemy.ranged_attack_interval = maxf(
			enemy.ranged_attack_interval
				* trial_attack_interval_multiplier,
			trial_minimum_enemy_ranged_attack_interval
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
	_inherited_velocity: Vector2,
	defeated_enemy: EnemyController,
	qi_reward: int
) -> void:
	var defeated_elite := (
		is_instance_valid(defeated_enemy)
		and defeated_enemy.is_elite_enemy()
	)
	enemy_defeat_recorded.emit(defeated_elite)
	if not defeated_elite:
		_ordinary_defeats_since_elite += 1
	_drop_qi(drop_position, qi_reward)
	if defeated_elite:
		match defeated_enemy.get_elite_reward_type():
			EnemyController.EliteRewardType.WEAPON:
				_drop_weapon_choice(drop_position)
			EnemyController.EliteRewardType.POWER_FRAGMENT:
				_drop_weapon_power_fragment_choice(drop_position)


func _on_enemy_damage_recorded(
	source_id: StringName,
	amount: int
) -> void:
	player_damage_recorded.emit(source_id, amount)


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


func _get_available_weapons() -> Array[WeaponDataResource]:
	var available_weapons: Array[WeaponDataResource] = []
	for weapon_data in weapon_drop_pool:
		if weapon_data != null and weapon_data.is_valid_definition():
			available_weapons.append(weapon_data)
	if available_weapons.is_empty():
		push_warning("EnemySpawner weapon_drop_pool has no valid WeaponData.")
	return available_weapons


func _drop_weapon_choice(drop_position: Vector2) -> void:
	if weapon_pickup_scene == null:
		return
	var available_weapons := _get_available_weapons()
	if available_weapons.is_empty():
		return
	var first_index := _rng.randi_range(0, available_weapons.size() - 1)
	var first_weapon := available_weapons[first_index]
	var second_weapon := first_weapon
	if available_weapons.size() > 1:
		available_weapons.remove_at(first_index)
		second_weapon = available_weapons[
			_rng.randi_range(0, available_weapons.size() - 1)
		]
	var choice_group := _create_reward_choice_group(
		drop_position,
		EliteRewardChoiceResource.RewardKind.WEAPON
	)
	if choice_group == null:
		return
	var choices: Array[WeaponDataResource] = [first_weapon, second_weapon]
	for choice_index in choices.size():
		var weapon_pickup := weapon_pickup_scene.instantiate() as WeaponPickup
		if weapon_pickup == null:
			push_error(
				"EnemySpawner weapon_pickup_scene must instantiate WeaponPickup."
			)
			continue
		var weapon_data := choices[choice_index]
		weapon_pickup.channel_radius = _get_safe_reward_choice_radius()
		weapon_pickup.configure(
			weapon_data,
			weapon_data.roll_damage(_rng),
			Vector2.ZERO,
			player
		)
		choice_group.add_option(
			weapon_pickup,
			Vector2(
				_get_reward_choice_offset(choice_index),
				0.0
			)
		)


func _drop_weapon_power_fragment_choice(drop_position: Vector2) -> void:
	if weapon_power_fragment_scene == null:
		return
	var upgrade_types := _roll_power_fragment_choice_types()
	var choice_group := _create_reward_choice_group(
		drop_position,
		EliteRewardChoiceResource.RewardKind.POWER_FRAGMENT
	)
	if choice_group == null:
		return
	for choice_index in upgrade_types.size():
		var fragment := (
			weapon_power_fragment_scene.instantiate()
			as WeaponPowerFragment
		)
		if fragment == null:
			push_error(
				"EnemySpawner weapon_power_fragment_scene must instantiate "
				+ "WeaponPowerFragment."
			)
			continue
		fragment.pickup_radius = _get_safe_reward_choice_radius()
		fragment.configure(
			player,
			Vector2.ZERO,
			upgrade_types[choice_index]
		)
		fragment.upgrade_collected.connect(_on_universal_upgrade_collected)
		choice_group.add_option(
			fragment,
			Vector2(
				_get_reward_choice_offset(choice_index),
				0.0
			)
		)


## Rolls two distinct universal upgrades with at least one direct farming
## output option: attack speed, damage, or damage range.
func _roll_power_fragment_choice_types() -> Array[int]:
	var combat_types: Array[int] = [
		UniversalUpgradeTypes.UpgradeType.ATTACK_SPEED,
		UniversalUpgradeTypes.UpgradeType.DAMAGE,
		UniversalUpgradeTypes.UpgradeType.DAMAGE_RANGE,
	]
	var first_type := combat_types[
		_rng.randi_range(0, combat_types.size() - 1)
	]
	var second_type := _rng.randi_range(
		0,
		UniversalUpgradeTypes.COUNT - 2
	)
	if second_type >= first_type:
		second_type += 1
	if _rng.randf() <= 0.5:
		return [first_type, second_type]
	return [second_type, first_type]


func _create_reward_choice_group(
	drop_position: Vector2,
	reward_kind: int
) -> EliteRewardChoice:
	var choice_group := EliteRewardChoiceResource.new()
	choice_group.reward_kind = reward_kind
	choice_group.configure_motion(
		reward_vertical_drift_speed,
		Callable(self, "_clamp_reward_group_x")
	)
	choice_group.configure_lifecycle(
		camera,
		reward_offscreen_despawn_margin,
		reward_choice_lifetime_seconds
	)
	var reward_position := _find_reward_choice_position(drop_position)
	add_child(choice_group)
	choice_group.global_position = reward_position
	return choice_group


func _find_reward_choice_position(drop_position: Vector2) -> Vector2:
	var base_y := drop_position.y
	if is_instance_valid(player):
		base_y = minf(
			base_y,
			player.global_position.y
				- maxf(reward_minimum_forward_distance, 0.0)
		)
	var row_spacing := maxf(reward_group_minimum_spacing, 100.0)
	for row in 64:
		var candidate_y := base_y - float(row) * row_spacing
		var candidate := Vector2(
			_clamp_reward_group_x(drop_position.x, candidate_y),
			candidate_y
		)
		if _is_reward_group_position_clear(candidate):
			return candidate
	var fallback_y := base_y - 64.0 * row_spacing
	return Vector2(
		_clamp_reward_group_x(drop_position.x, fallback_y),
		fallback_y
	)


func _is_reward_group_position_clear(candidate: Vector2) -> bool:
	var minimum_spacing := maxf(reward_group_minimum_spacing, 100.0)
	for group_node in get_tree().get_nodes_in_group("elite_reward_choices"):
		if (
			group_node is Node2D
			and group_node != null
			and not group_node.is_queued_for_deletion()
			and candidate.distance_to(group_node.global_position)
				< minimum_spacing
		):
			return false
	return true


func _get_safe_reward_choice_radius() -> float:
	return minf(
		maxf(reward_choice_radius, 24.0),
		maxf(reward_choice_separation * 0.5 - 8.0, 24.0)
	)


func _get_reward_choice_offset(choice_index: int) -> float:
	var direction := -1.0 if choice_index == 0 else 1.0
	return direction * maxf(reward_choice_separation, 80.0) * 0.5


func _clamp_reward_group_x(desired_x: float, world_y: float) -> float:
	var pair_extent := (
		maxf(reward_choice_separation, 80.0) * 0.5
		+ _get_safe_reward_choice_radius()
		+ maxf(reward_road_edge_clearance, 0.0)
	)
	var usable_center_half_width := maxf(
		_get_road_half_width_at(world_y) - pair_extent,
		0.0
	)
	return clampf(
		desired_x,
		_route_center_x - usable_center_half_width,
		_route_center_x + usable_center_half_width
	)


func _reposition_reward_groups_to_active_route() -> void:
	for group_node in get_tree().get_nodes_in_group("elite_reward_choices"):
		if (
			group_node is Node2D
			and is_ancestor_of(group_node)
			and not group_node.is_queued_for_deletion()
		):
			var reward_group := group_node as Node2D
			reward_group.global_position.x = _clamp_reward_group_x(
				reward_group.global_position.x,
				reward_group.global_position.y
			)


func _on_dropped_qi_collected(amount: int) -> void:
	qi_collected.emit(amount)


func _on_universal_upgrade_collected(
	upgrade_type: int,
	amount: int
) -> void:
	universal_upgrade_collected.emit(upgrade_type, amount)


func _remove_enemies_outside_active_route() -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if (
			enemy_node is EnemyController
			and absf(enemy_node.global_position.x - _route_center_x)
				> maxf(
					_get_road_half_width_at(enemy_node.global_position.y)
						- road_edge_clearance,
					1.0
				)
		):
			(enemy_node as EnemyController).set_combat_enabled(false)
			enemy_node.queue_free()


func _refresh_enemy_road_constraints() -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is EnemyController:
			(enemy_node as EnemyController).configure_road_constraint(
				_route_center_x,
				Callable(self, "_get_road_half_width_at"),
				road_edge_clearance
			)


func _get_road_half_width_at(world_y: float) -> float:
	if _road_half_width_resolver.is_valid():
		return maxf(
			float(_road_half_width_resolver.call(world_y)),
			road_edge_clearance + 1.0
		)
	return maxf(road_half_width, road_edge_clearance + 1.0)
