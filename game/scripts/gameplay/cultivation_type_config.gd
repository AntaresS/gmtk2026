class_name CultivationTypeConfig
extends Resource

const CultivationTypesResource = preload(
	"res://game/scripts/gameplay/cultivation_types.gd"
)

## Cultivation track represented by this definition. A complete configuration
## contains exactly one definition for each valid CultivationType.
@export var cultivation_type: CultivationTypesResource.CultivationType = (
	CultivationTypesResource.CultivationType.JING
)
## Chinese glyph used by pickups and HUD labels.
@export var display_name: String = "精"
## Primary world and HUD color for this cultivation type.
@export var display_color: Color = Color("ffb45f")
## Optional bitmap icon. When omitted, presentation draws the type's distinct
## procedural shape and Chinese glyph.
@export var icon: Texture2D
## Additive matching-weapon damage ratio granted by every cultivation level.
## The default 0.10 means +10% base damage per level.
@export_range(0.0, 2.0, 0.01) var damage_bonus_per_level: float = 0.10
## Ordered secondary rewards. Level one grants entry zero and the order repeats
## after the final entry, allowing designers to change cycle length or order.
@export var rewards: Array[CultivationReward] = []


func get_reward_for_level(level: int) -> CultivationReward:
	if level <= 0 or rewards.is_empty():
		return null
	return rewards[(level - 1) % rewards.size()]


func get_reward_occurrences(level: int, reward_index: int) -> int:
	if level <= reward_index or reward_index < 0 or reward_index >= rewards.size():
		return 0
	return 1 + (level - reward_index - 1) / rewards.size()


## Returns all accumulated secondary stats and cap-conversion damage for a
## supplied type level without mutating this shared definition.
func resolve_level(level: int) -> Dictionary:
	var stats: Dictionary = {}
	var converted_damage_bonus := 0.0
	for reward_index in rewards.size():
		var reward := rewards[reward_index]
		if reward == null:
			continue
		var resolved := reward.resolve(
			get_reward_occurrences(maxi(level, 0), reward_index)
		)
		stats[reward.stat] = float(resolved["value"])
		converted_damage_bonus += float(resolved["damage_bonus"])
	return {
		"stats": stats,
		"damage_bonus": (
			float(maxi(level, 0)) * maxf(damage_bonus_per_level, 0.0)
			+ converted_damage_bonus
		),
	}
