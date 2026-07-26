class_name WeaponData
extends Resource

enum AttackKind {
	GREAT_STRENGTH_PALM,
	DAO,
	FLYING_SWORD,
	QIANKUN_RING,
	GOLDEN_BELL,
	THUNDER_HAMMER,
	FANTIAN_SEAL,
}

enum AttackDomain {
	MELEE,
	RANGED,
}

@export_category("Identity")
## Stable identifier used to combine same-type pickups into weapon quantity.
## IDs must be unique across every WeaponData available in one run.
@export var weapon_id: StringName = &"weapon"
## Designer-facing name shown on pickups and the equipment HUD.
@export var display_name: String = "Weapon"
## Existing attack implementation selected when this weapon is equipped.
@export var attack_kind: AttackKind = AttackKind.GREAT_STRENGTH_PALM
## Optional realm-gating category. Current default realms permit both domains;
## future realm definitions can restrict equipment without checking weapon IDs.
@export var attack_domain: AttackDomain = AttackDomain.MELEE
## Primary color used by the player's current attack-range presentation.
@export var display_color: Color = Color("7dffd8")
## Color used by the world pickup representation. This may differ slightly
## from display_color to preserve contrast against terrain.
@export var pickup_color: Color = Color("7dffd8")
## Optional real weapon artwork shown by HUD slots. When omitted, the HUD
## renders the attack-kind fallback symbol so incomplete art sets stay usable.
@export var icon_texture: Texture2D
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
## Full angle, in degrees, of a directional attack. Great Strength Palm uses
## this cone instead of damaging through its complete detection circle.
@export_range(1.0, 180.0, 1.0) var directional_arc_degrees: float = 64.0
## Minimum seconds between automatic attacks while a valid target is present.
## Magazine-based weapons such as Flying Sword use this as reload time after
## their final sequential projectile instead of between individual shots.
@export_range(0.05, 5.0, 0.01) var attack_interval: float = 0.7

@export_category("Great Strength Palm")
## Outward impulse speed applied by Great Strength Palm from Foundation onward.
## Zero disables Palm knockback for definitions that do not use this technique.
@export_range(0.0, 1000.0, 10.0) var palm_knockback_speed: float = 0.0
## Speed removed from Palm knockback per second. Higher recovery preserves the
## initial impact while shortening displacement away from the player.
@export_range(10.0, 5000.0, 10.0) var palm_knockback_recovery: float = 920.0
## Pre-hit health ratio above which Golden Core and later Palm hits receive the
## high-health damage multiplier. A value of 0.75 means strictly above 75%.
@export_range(0.0, 1.0, 0.01) var palm_high_health_threshold_ratio: float = 0.75
## Final numeric Palm damage multiplier against targets above the configured
## high-health threshold. This multiplies resolved critical and realm damage.
@export_range(1.0, 5.0, 0.05) var palm_high_health_damage_multiplier: float = 1.0
## Pre-hit health ratio below which Nascent Soul ordinary enemies become
## eligible for Palm's execute roll. A value of 0.50 means strictly below 50%.
@export_range(0.0, 1.0, 0.01) var palm_execute_health_threshold_ratio: float = 0.5
## Per-hit Nascent Soul execute probability for eligible non-elite ordinary
## enemies. The roll occurs at most once for each enemy in one Palm cast.
@export_range(0.0, 1.0, 0.01) var palm_execute_chance: float = 0.0

@export_category("Delivery")
## Optional projectile scene used by projectile-based attack kinds.
@export var projectile_scene: PackedScene
## Seconds between projectiles in one sequential volley. Used by Flying Sword
## and Universe Ring duplicate-weapon volleys.
@export_range(0.01, 0.5, 0.01) var projectile_sequence_interval: float = 0.12
## Base number of weapon copies delivered in one attack. Runtime duplicate
## pickups add to this value without mutating the shared weapon definition.
@export_range(1, 100, 1) var base_delivery_count: int = 1
## Maximum weapon copies delivered in one attack after duplicate pickups.
## Definitions that do not need a practical cap may retain the default of 100.
@export_range(1, 100, 1) var delivery_count_cap: int = 100
## Fixed extra enemy-to-enemy bounces made by each Universe Ring projectile.
## This is deliberately independent from duplicate-weapon delivery count.
@export_range(0, 20, 1) var base_bounce_count: int = 0
## Weapon-specific secondary search radius in world pixels. Used for Universe
## Ring bounce targeting; zero disables a secondary search.
@export_range(0.0, 600.0, 1.0) var secondary_range: float = 0.0
## Base impact radius in world pixels for weapons with area damage. Zero keeps
## the existing single-target behavior before cultivation modifiers.
@export_range(0.0, 300.0, 1.0) var base_aoe_radius: float = 0.0
## Whether the player-wide AoE radius bonus also expands this weapon's primary
## attack/detection circle. Enable for area attacks such as Dao.
@export var aoe_bonus_scales_attack_range: bool = false
## Whether cultivation AoE bonuses and universal range fragments expand this
## weapon's per-hit area. Disable for fixed-footprint attacks such as the Seal.
@export var bonuses_scale_aoe_radius: bool = true

@export_category("Sound")
## Sound played when this weapon activates. Projectile weapons trigger this
## once for every projectile or cloud that is successfully spawned.
@export var activation_sfx: AudioStream
## Start of the activation cue inside activation_sfx, in seconds.
@export_range(0.0, 60.0, 0.01) var activation_sfx_start_time: float = 0.0
## End of the activation cue inside activation_sfx, in seconds. Values at or
## below the start time play through the remainder of the imported stream.
@export_range(0.0, 60.0, 0.01) var activation_sfx_end_time: float = 0.0
## Per-weapon activation loudness adjustment in decibels.
@export_range(-40.0, 12.0, 0.5) var activation_sfx_volume_db: float = 0.0
## Activation playback-speed and pitch multiplier. One preserves the source.
@export_range(0.25, 4.0, 0.05) var activation_sfx_pitch_scale: float = 1.0
## Optional second cue played by event-driven weapons. Universe Ring uses it
## on every enemy hit, Fantian Seal on impact, and Golden Bell on contact.
@export var impact_sfx: AudioStream
## Start of the impact cue inside impact_sfx, in seconds.
@export_range(0.0, 60.0, 0.01) var impact_sfx_start_time: float = 0.0
## End of the impact cue inside impact_sfx, in seconds. Values at or below the
## start time play through the remainder of the imported stream.
@export_range(0.0, 60.0, 0.01) var impact_sfx_end_time: float = 0.0
## Per-weapon impact loudness adjustment in decibels.
@export_range(-40.0, 12.0, 0.5) var impact_sfx_volume_db: float = 0.0
## Impact playback-speed and pitch multiplier. One preserves the source.
@export_range(0.25, 4.0, 0.05) var impact_sfx_pitch_scale: float = 1.0

@export_category("Weapon Level Progression")
## Flat attack-radius growth in world pixels for each duplicate level after
## Lv.1, up to attack_range_level_cap. Zero disables level-based range growth.
@export_range(0.0, 80.0, 1.0) var attack_range_increase_per_level: float = 0.0
## Highest displayed weapon level allowed to increase attack radius. Duplicate
## levels above this cap can instead use damage_ratio_per_level_above_range_cap.
@export_range(1, 100, 1) var attack_range_level_cap: int = 1
## Additive damage ratio granted by every displayed weapon level above the
## range cap. A value of 0.10 grants +10% per excess duplicate level.
@export_range(0.0, 1.0, 0.01) var damage_ratio_per_level_above_range_cap: float = 0.0


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
