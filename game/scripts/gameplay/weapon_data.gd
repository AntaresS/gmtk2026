class_name WeaponData
extends Resource

enum AttackKind {
	GREAT_STRENGTH_PALM,
	DAO,
	FLYING_SWORD,
	QIANKUN_RING,
}

@export_category("Identity")
## Stable identifier used to keep the strongest collected copy of this weapon.
## IDs must be unique across every WeaponData available in one run.
@export var weapon_id: StringName = &"weapon"
## Designer-facing name shown on pickups and the equipment HUD.
@export var display_name: String = "Weapon"
## Existing attack implementation selected when this weapon is equipped.
@export var attack_kind: AttackKind = AttackKind.GREAT_STRENGTH_PALM
## Primary color used by the player's current attack-range presentation.
@export var display_color: Color = Color("7dffd8")
## Color used by the world pickup representation. This may differ slightly
## from display_color to preserve contrast against terrain.
@export var pickup_color: Color = Color("7dffd8")
## Single cultivation track used by the shared stat pipeline. -1 is neutral and
## preserves unchanged behavior for legacy or future untyped weapons.
@export_enum("Neutral:-1", "JING 精:0", "QI 气:1", "SHEN 神:2")
var cultivation_type: int = -1

@export_category("Core Combat")
## Inclusive minimum damage rolled when this weapon drops. Starting equipment
## uses this value directly, so fixed-damage definitions should set both bounds
## to the same value.
@export_range(1, 100, 1) var minimum_damage: int = 1
## Inclusive maximum damage rolled when this weapon drops. Reversed bounds are
## normalized at runtime.
@export_range(1, 100, 1) var maximum_damage: int = 1
## Base automatic-attack radius in world pixels before technique strengthening.
@export_range(24.0, 600.0, 1.0) var attack_range: float = 72.0
## Minimum seconds between automatic attacks while a valid target is present.
@export_range(0.05, 5.0, 0.01) var attack_interval: float = 0.7

@export_category("Delivery")
## Optional projectile scene used by projectile-based attack kinds.
@export var projectile_scene: PackedScene
## Seconds between projectiles in one sequential volley. Used by Flying Sword.
@export_range(0.01, 0.5, 0.01) var projectile_sequence_interval: float = 0.12
## Base number of deliveries in one attack before player bonuses. Flying Sword
## uses total volley projectiles; Universe Ring counts its initial target as one.
@export_range(1, 100, 1) var base_delivery_count: int = 1
## Weapon-specific secondary search radius in world pixels. Used for Universe
## Ring bounce targeting; zero disables a secondary search.
@export_range(0.0, 600.0, 1.0) var secondary_range: float = 0.0
## Base impact radius in world pixels for weapons with area damage. Zero keeps
## the existing single-target behavior before cultivation modifiers.
@export_range(0.0, 300.0, 1.0) var base_aoe_radius: float = 0.0
## Whether the player-wide AoE radius bonus also expands this weapon's primary
## attack/detection circle. Enable for area attacks such as Dao.
@export var aoe_bonus_scales_attack_range: bool = false


## Returns one normalized inclusive damage roll without mutating this shared
## definition.
func roll_damage(rng: RandomNumberGenerator) -> int:
	var lower_bound := mini(minimum_damage, maximum_damage)
	var upper_bound := maxi(minimum_damage, maximum_damage)
	return rng.randi_range(maxi(lower_bound, 1), maxi(upper_bound, 1))


func is_valid_definition() -> bool:
	return not weapon_id.is_empty() and not display_name.is_empty()


## Returns this weapon's current single cultivation affinity. The stat pipeline
## consumes a collection so a future data revision can add hybrid affinities
## without changing individual attack implementations.
func get_cultivation_types() -> Array[int]:
	if cultivation_type < 0:
		return []
	return [cultivation_type]
