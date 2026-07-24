class_name PlayerGlobalCombatStats
extends RefCounted

const CultivationBonusStatsResource = preload(
	"res://game/scripts/gameplay/cultivation_bonus_stats.gd"
)
const CultivationTypesResource = preload(
	"res://game/scripts/gameplay/cultivation_types.gd"
)

## Read-only runtime snapshot of player-wide combat values. A resolver creates
## a fresh instance whenever progression changes; consumers must not mutate it.

## Current overall Qi cultivation level used by global damage growth.
var overall_cultivation_level: int = 1
## Portion of global damage granted by completed overall cultivation levels.
var overall_level_damage_bonus: float = 0.0
## Flat damage added to every weapon before affinity multipliers.
var global_damage_bonus: float = 0.0
## Final player critical-hit chance after global cultivation rewards.
var critical_chance: float = 0.0
## Final player critical damage multiplier after global cultivation rewards.
var critical_damage_multiplier: float = 1.0
## Absolute final critical-hit chance cap from the player combat configuration.
var maximum_critical_chance: float = 1.0
## Absolute final critical-damage multiplier cap from player configuration.
var maximum_critical_damage_multiplier: float = 5.0
## Final player-wide additive attack-speed ratio.
var attack_speed_bonus: float = 0.0
## Final player-wide additive projectile-speed ratio.
var projectile_speed_bonus: float = 0.0
## Final projectile-speed multiplier derived from projectile_speed_bonus.
var projectile_speed_multiplier: float = 1.0
## Final player-wide count added to each weapon's base delivery count.
var delivery_count_bonus: int = 0
## Final player-wide additive area-radius ratio.
var aoe_radius_bonus: float = 0.0
## Final player-wide additive targeting-range ratio.
var targeting_range_bonus: float = 0.0
## Player-wide reduction applied to damage from known nearby sources.
var close_range_damage_reduction: float = 0.0
## Absolute final close-range damage-reduction cap from player configuration.
var maximum_close_range_damage_reduction: float = 0.95
## Maximum source distance in world pixels for close-range damage reduction.
var close_range_mitigation_radius: float = 0.0
## Smallest automatic-attack interval permitted after all speed bonuses.
var minimum_attack_interval: float = 0.05

## Secondary-stat contributions from 精 only, excluding matching-type damage.
var jing_bonuses: CultivationBonusStatsResource = (
	CultivationBonusStatsResource.new()
)
## Secondary-stat contributions from 气 only, excluding matching-type damage.
var qi_bonuses: CultivationBonusStatsResource = (
	CultivationBonusStatsResource.new()
)
## Secondary-stat contributions from 神 only, excluding matching-type damage.
var shen_bonuses: CultivationBonusStatsResource = (
	CultivationBonusStatsResource.new()
)


## Returns the source-specific secondary bonus snapshot for HUD presentation
## and diagnostics. Invalid or neutral types return an empty snapshot.
func get_cultivation_bonuses(
	cultivation_type: int
) -> CultivationBonusStatsResource:
	match cultivation_type:
		CultivationTypesResource.CultivationType.JING:
			return jing_bonuses
		CultivationTypesResource.CultivationType.QI:
			return qi_bonuses
		CultivationTypesResource.CultivationType.SHEN:
			return shen_bonuses
	return CultivationBonusStatsResource.new()
