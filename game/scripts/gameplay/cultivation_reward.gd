class_name CultivationReward
extends Resource

enum Stat {
	CRITICAL_CHANCE,
	CRITICAL_DAMAGE,
	CLOSE_RANGE_DAMAGE_REDUCTION,
	ATTACK_SPEED,
	PROJECTILE_SPEED,
	DELIVERY_COUNT,
	AOE_RADIUS,
	TARGETING_RANGE,
}

## Generic stat modified when this reward's slot is reached in the repeating
## type-specific cycle.
@export var stat: Stat = Stat.CRITICAL_CHANCE
## Short designer-facing reward name shown by the cultivation level-up HUD.
@export var display_name: String = "奖励"
## Additive value granted per occurrence. Percentage stats use decimal ratios;
## delivery-count rewards use whole-number values.
@export var amount: float = 0.0
## Maximum accumulated value for this reward. Negative values disable the cap.
@export var cap: float = -1.0
## Matching-type additive damage granted for every occurrence that cannot add
## its normal value because the configured cap has already been reached.
@export_range(0.0, 1.0, 0.005) var capped_damage_bonus: float = 0.02


## Resolves this reward after a number of completed cycle occurrences.
func resolve(occurrences: int) -> Dictionary:
	var safe_occurrences := maxi(occurrences, 0)
	var total := maxf(amount, 0.0) * float(safe_occurrences)
	if cap < 0.0 or amount <= 0.0:
		return {
			"value": total,
			"converted_occurrences": 0,
			"damage_bonus": 0.0,
		}
	var applied := minf(total, maxf(cap, 0.0))
	var applied_occurrences := mini(
		ceili(applied / amount) if amount > 0.0 else 0,
		safe_occurrences
	)
	var converted := maxi(safe_occurrences - applied_occurrences, 0)
	return {
		"value": applied,
		"converted_occurrences": converted,
		"damage_bonus": float(converted) * maxf(capped_damage_bonus, 0.0),
	}
