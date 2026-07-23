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

@export_category("Technique Strengthening")
## Attack-radius increase in world pixels per absorbed technique fragment.
@export_range(0.0, 80.0, 1.0) var range_increase_per_upgrade: float = 0.0
## Weapon-specific extra effects per technique level: persistent dao orbits,
## sequential flying-sword projectiles, or Universe Ring bounces.
@export_range(0, 4, 1) var additional_effects_per_upgrade: int = 0

@export_category("Delivery")
## Optional projectile scene used by projectile-based attack kinds.
@export var projectile_scene: PackedScene
## Seconds between projectiles in one sequential volley. Used by Flying Sword.
@export_range(0.01, 0.5, 0.01) var projectile_sequence_interval: float = 0.12
## Weapon-specific secondary search radius in world pixels. Used for Universe
## Ring bounce targeting; zero disables a secondary search.
@export_range(0.0, 600.0, 1.0) var secondary_range: float = 0.0


## Returns one normalized inclusive damage roll without mutating this shared
## definition.
func roll_damage(rng: RandomNumberGenerator) -> int:
	var lower_bound := mini(minimum_damage, maximum_damage)
	var upper_bound := maxi(minimum_damage, maximum_damage)
	return rng.randi_range(maxi(lower_bound, 1), maxi(upper_bound, 1))


func is_valid_definition() -> bool:
	return not weapon_id.is_empty() and not display_name.is_empty()
