class_name AttackDamageResult
extends RefCounted

## Immutable-by-convention result of one player attack roll. Delivery systems
## carry this metadata to every hit without recalculating critical chance.

var damage: int = 1
var is_critical: bool = false


func _init(resolved_damage: int = 1, critical: bool = false) -> void:
	damage = maxi(resolved_damage, 1)
	is_critical = critical
