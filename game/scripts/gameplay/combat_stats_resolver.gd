class_name CombatStatsResolver
extends RefCounted

const CultivationTypesResource = preload(
	"res://game/scripts/gameplay/cultivation_types.gd"
)
const CultivationRewardResource = preload(
	"res://game/scripts/gameplay/cultivation_reward.gd"
)
const PlayerGlobalCombatStatsResource = preload(
	"res://game/scripts/gameplay/player_global_combat_stats.gd"
)
const WeaponCombatStatsResource = preload(
	"res://game/scripts/gameplay/weapon_combat_stats.gd"
)
const PlayerCombatConfigResource = preload(
	"res://game/scripts/gameplay/player_combat_config.gd"
)
const CultivationBonusStatsResource = preload(
	"res://game/scripts/gameplay/cultivation_bonus_stats.gd"
)


## Produces player-wide values from base configuration and every cultivation
## secondary reward. Matching-type damage is intentionally excluded here.
static func resolve_global(
	resources: RunResources,
	config: PlayerCombatConfigResource
) -> PlayerGlobalCombatStatsResource:
	var snapshot := PlayerGlobalCombatStatsResource.new()
	if config == null:
		return snapshot

	snapshot.overall_cultivation_level = (
		maxi(resources.cultivation_level, 1)
		if resources != null
		else 1
	)
	snapshot.overall_level_damage_bonus = (
		float(snapshot.overall_cultivation_level - 1)
		* maxf(config.global_damage_bonus_per_overall_level, 0.0)
	)
	snapshot.overall_level_damage_ratio = (
		float(snapshot.overall_cultivation_level - 1)
		* maxf(config.global_damage_ratio_per_overall_level, 0.0)
	)
	snapshot.global_damage_bonus = (
		maxf(config.global_damage_bonus, 0.0)
		+ snapshot.overall_level_damage_bonus
	)
	snapshot.jing_bonuses = _resolve_type_bonuses(
		resources,
		CultivationTypesResource.CultivationType.JING
	)
	snapshot.qi_bonuses = _resolve_type_bonuses(
		resources,
		CultivationTypesResource.CultivationType.QI
	)
	snapshot.shen_bonuses = _resolve_type_bonuses(
		resources,
		CultivationTypesResource.CultivationType.SHEN
	)
	var type_bonuses: Array[CultivationBonusStatsResource] = [
		snapshot.jing_bonuses,
		snapshot.qi_bonuses,
		snapshot.shen_bonuses,
	]

	snapshot.maximum_critical_chance = clampf(
		config.maximum_critical_chance,
		0.0,
		1.0
	)
	snapshot.maximum_critical_damage_multiplier = maxf(
		config.maximum_critical_damage_multiplier,
		1.0
	)
	snapshot.maximum_close_range_damage_reduction = clampf(
		config.maximum_close_range_damage_reduction,
		0.0,
		0.99
	)
	snapshot.close_range_mitigation_radius = maxf(
		config.close_range_mitigation_radius,
		0.0
	)
	snapshot.critical_chance = maxf(config.base_critical_chance, 0.0)
	snapshot.critical_damage_multiplier = maxf(
		config.base_critical_damage_multiplier,
		1.0
	)
	snapshot.attack_speed_bonus = maxf(
		config.base_attack_speed_bonus,
		0.0
	)
	snapshot.projectile_speed_bonus = maxf(
		config.base_projectile_speed_bonus,
		0.0
	)
	# Weapon-copy delivery is owned by PlayerController's duplicate inventory.
	# Cultivation and player-global stats cannot increase projectile quantity.
	snapshot.delivery_count_bonus = 0
	snapshot.aoe_radius_bonus = maxf(
		config.base_aoe_radius_bonus,
		0.0
	)
	snapshot.targeting_range_bonus = maxf(
		config.base_targeting_range_bonus,
		0.0
	)
	snapshot.close_range_damage_reduction = maxf(
		config.base_close_range_damage_reduction,
		0.0
	)
	for bonus in type_bonuses:
		snapshot.critical_chance += bonus.critical_chance
		snapshot.critical_damage_multiplier += bonus.critical_damage_bonus
		snapshot.attack_speed_bonus += bonus.attack_speed_bonus
		snapshot.projectile_speed_bonus += bonus.projectile_speed_bonus
		snapshot.aoe_radius_bonus += bonus.aoe_radius_bonus
		snapshot.targeting_range_bonus += bonus.targeting_range_bonus
		snapshot.close_range_damage_reduction += (
			bonus.close_range_damage_reduction
		)
	snapshot.critical_chance = clampf(
		snapshot.critical_chance,
		0.0,
		snapshot.maximum_critical_chance
	)
	snapshot.critical_damage_multiplier = clampf(
		snapshot.critical_damage_multiplier,
		1.0,
		snapshot.maximum_critical_damage_multiplier
	)
	snapshot.projectile_speed_multiplier = (
		1.0 + snapshot.projectile_speed_bonus
	)
	snapshot.close_range_damage_reduction = clampf(
		snapshot.close_range_damage_reduction,
		0.0,
		snapshot.maximum_close_range_damage_reduction
	)
	snapshot.minimum_attack_interval = clampf(
		config.minimum_attack_interval,
		0.01,
		1.0
	)
	return snapshot


## Resolves weapon-facing values from the player-global snapshot, then applies
## only the equipped weapon's matching-type damage percentage.
static func resolve_weapon(
	weapon_data: WeaponData,
	rolled_damage: int,
	resources: RunResources,
	global_stats: PlayerGlobalCombatStatsResource
) -> WeaponCombatStatsResource:
	var snapshot := WeaponCombatStatsResource.new()
	if weapon_data == null:
		return snapshot

	snapshot.weapon_id = weapon_data.weapon_id
	snapshot.display_name = weapon_data.display_name
	snapshot.attack_kind = int(weapon_data.attack_kind)
	snapshot.cultivation_types = weapon_data.get_cultivation_types().duplicate()
	snapshot.rolled_damage = maxi(rolled_damage, 1)
	snapshot.matching_damage_bonus = _get_weapon_damage_bonus(
		resources,
		weapon_data
	)
	var global_damage_bonus := (
		maxf(global_stats.global_damage_bonus, 0.0)
		if global_stats != null
		else 0.0
	)
	snapshot.resolved_damage = maxi(
		roundi(
			(float(snapshot.rolled_damage) + global_damage_bonus)
				* (
					1.0
					+ (
						maxf(global_stats.overall_level_damage_ratio, 0.0)
						if global_stats != null
						else 0.0
					)
				)
				* (1.0 + snapshot.matching_damage_bonus)
		),
		1
	)

	snapshot.critical_chance = (
		global_stats.critical_chance
		if global_stats != null
		else 0.0
	)
	snapshot.critical_damage_multiplier = (
		global_stats.critical_damage_multiplier
		if global_stats != null
		else 1.0
	)
	snapshot.attack_speed_bonus = (
		global_stats.attack_speed_bonus
		if global_stats != null
		else 0.0
	)
	snapshot.attack_interval = maxf(
		weapon_data.attack_interval / (1.0 + snapshot.attack_speed_bonus),
		(
			global_stats.minimum_attack_interval
			if global_stats != null
			else 0.05
		)
	)
	snapshot.targeting_range_bonus = (
		global_stats.targeting_range_bonus
		if global_stats != null
		else 0.0
	)
	var primary_range_bonus := snapshot.targeting_range_bonus
	if weapon_data.aoe_bonus_scales_attack_range and global_stats != null:
		primary_range_bonus += global_stats.aoe_radius_bonus
	snapshot.attack_range = maxf(weapon_data.attack_range, 0.0) * (
		1.0 + primary_range_bonus
	)
	snapshot.secondary_targeting_range = maxf(
		weapon_data.secondary_range,
		0.0
	) * (1.0 + snapshot.targeting_range_bonus)
	snapshot.projectile_speed_multiplier = (
		global_stats.projectile_speed_multiplier
		if global_stats != null
		else 1.0
	)
	snapshot.delivery_count = maxi(
		weapon_data.base_delivery_count,
		1
	)

	var aoe_bonus := (
		global_stats.aoe_radius_bonus
		if global_stats != null and weapon_data.bonuses_scale_aoe_radius
		else 0.0
	)
	snapshot.aoe_radius_bonus = aoe_bonus
	snapshot.aoe_radius = maxf(weapon_data.base_aoe_radius, 0.0) * (
		1.0 + aoe_bonus
	)
	return snapshot


static func _get_weapon_damage_bonus(
	resources: RunResources,
	weapon_data: WeaponData
) -> float:
	if resources == null or weapon_data == null:
		return 0.0
	var total := 0.0
	for cultivation_type in weapon_data.get_cultivation_types():
		if not CultivationTypesResource.is_valid_type(cultivation_type):
			continue
		var resolved := resources.get_cultivation_stats(cultivation_type)
		total += maxf(float(resolved.get("damage_bonus", 0.0)), 0.0)
	return total


static func _resolve_type_bonuses(
	resources: RunResources,
	cultivation_type: int
) -> CultivationBonusStatsResource:
	var bonuses := CultivationBonusStatsResource.new()
	bonuses.critical_chance = _get_type_stat(
		resources,
		cultivation_type,
		CultivationRewardResource.Stat.CRITICAL_CHANCE
	)
	bonuses.critical_damage_bonus = _get_type_stat(
		resources,
		cultivation_type,
		CultivationRewardResource.Stat.CRITICAL_DAMAGE
	)
	bonuses.close_range_damage_reduction = _get_type_stat(
		resources,
		cultivation_type,
		CultivationRewardResource.Stat.CLOSE_RANGE_DAMAGE_REDUCTION
	)
	bonuses.attack_speed_bonus = _get_type_stat(
		resources,
		cultivation_type,
		CultivationRewardResource.Stat.ATTACK_SPEED
	)
	bonuses.projectile_speed_bonus = _get_type_stat(
		resources,
		cultivation_type,
		CultivationRewardResource.Stat.PROJECTILE_SPEED
	)
	bonuses.delivery_count_bonus = 0
	bonuses.aoe_radius_bonus = _get_type_stat(
		resources,
		cultivation_type,
		CultivationRewardResource.Stat.AOE_RADIUS
	)
	bonuses.targeting_range_bonus = _get_type_stat(
		resources,
		cultivation_type,
		CultivationRewardResource.Stat.TARGETING_RANGE
	)
	return bonuses


static func _get_type_stat(
	resources: RunResources,
	cultivation_type: int,
	stat: CultivationRewardResource.Stat
) -> float:
	if resources == null:
		return 0.0
	var resolved := resources.get_cultivation_stats(cultivation_type)
	var stats := resolved.get("stats", {}) as Dictionary
	return maxf(float(stats.get(stat, 0.0)), 0.0)
