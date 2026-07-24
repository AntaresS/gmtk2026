class_name CultivationBonusStats
extends RefCounted

## Read-only runtime breakdown of secondary bonuses contributed by one
## cultivation track. Matching-type damage is intentionally not represented
## here because it remains weapon-specific.

var critical_chance: float = 0.0
var critical_damage_bonus: float = 0.0
var close_range_damage_reduction: float = 0.0
var attack_speed_bonus: float = 0.0
var projectile_speed_bonus: float = 0.0
var delivery_count_bonus: int = 0
var aoe_radius_bonus: float = 0.0
var targeting_range_bonus: float = 0.0


func has_any_bonus() -> bool:
	return (
		not is_zero_approx(critical_chance)
		or not is_zero_approx(critical_damage_bonus)
		or not is_zero_approx(close_range_damage_reduction)
		or not is_zero_approx(attack_speed_bonus)
		or not is_zero_approx(projectile_speed_bonus)
		or delivery_count_bonus != 0
		or not is_zero_approx(aoe_radius_bonus)
		or not is_zero_approx(targeting_range_bonus)
	)
