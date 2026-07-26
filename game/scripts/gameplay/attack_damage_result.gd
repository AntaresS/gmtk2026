class_name AttackDamageResult
extends RefCounted

## Immutable-by-convention result of one player attack roll. Delivery systems
## carry this metadata to every hit without recalculating critical chance.

var damage: int = 1
## Exact damage before per-hit integer allocation. Repeated-hit delivery systems
## may carry fractional progress between strikes while ordinary attacks use damage.
var exact_damage: float = 1.0
var is_critical: bool = false


func _init(
	resolved_damage: int = 1,
	critical: bool = false,
	resolved_exact_damage: float = -1.0
) -> void:
	damage = maxi(resolved_damage, 1)
	exact_damage = (
		maxf(resolved_exact_damage, 1.0)
		if resolved_exact_damage >= 0.0
		else float(damage)
	)
	is_critical = critical
