class_name CultivationConfig
extends Resource

const CultivationTypesResource = preload(
	"res://game/scripts/gameplay/cultivation_types.gd"
)

## Fragment count required for every type level. The cultivation contract uses
## three; this remains visible for validation and future balancing data.
@export_range(1, 20, 1) var fragments_per_level: int = 3
## Complete designer-managed definitions for 精, 气, and 神.
@export var type_configs: Array[CultivationTypeConfig] = []


func get_type_config(cultivation_type: int) -> CultivationTypeConfig:
	for type_config in type_configs:
		if (
			type_config != null
			and int(type_config.cultivation_type) == cultivation_type
		):
			return type_config
	return null


func get_fragments_required() -> int:
	return maxi(fragments_per_level, 1)


func resolve_level(cultivation_type: int, level: int) -> Dictionary:
	var type_config := get_type_config(cultivation_type)
	if type_config == null:
		return {"stats": {}, "damage_bonus": 0.0}
	return type_config.resolve_level(level)


func get_reward_message(cultivation_type: int, level: int) -> String:
	var type_config := get_type_config(cultivation_type)
	if type_config == null:
		return ""
	var reward := type_config.get_reward_for_level(level)
	if reward == null:
		return "同类武器伤害提升"
	var reward_index := (level - 1) % type_config.rewards.size()
	var occurrences := type_config.get_reward_occurrences(level, reward_index)
	var resolved := reward.resolve(occurrences)
	if int(resolved["converted_occurrences"]) > 0:
		return "%s已达上限 → 同类伤害提升" % reward.display_name
	return reward.display_name
