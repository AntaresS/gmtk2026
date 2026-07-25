class_name PlayerCombatConfig
extends Resource

@export_category("Global Damage")
## Flat damage added to every equipped weapon before matching cultivation
## multipliers. This is a run-independent player base value.
@export_range(0.0, 1000.0, 0.1) var global_damage_bonus: float = 0.0
## Additional flat damage granted for each completed overall cultivation level
## after level one. The resolver adds this player-global growth before any
## matching 精/气/神 weapon multiplier.
@export_range(0.0, 1000.0, 0.1) var global_damage_bonus_per_overall_level: float = 1.0
## Multiplicative damage ratio granted to every weapon for each completed
## overall cultivation level after level one. A value of 0.01 grants one
## percent per completed level and scales flat run upgrades fairly.
@export_range(0.0, 1.0, 0.005) var global_damage_ratio_per_overall_level: float = 0.01

@export_category("Critical Hits")
## Player critical-hit chance before global cultivation rewards. Values are
## ratios, so 0.05 represents five percent.
@export_range(0.0, 1.0, 0.01) var base_critical_chance: float = 0.0
## Player critical damage multiplier before global cultivation rewards. A value
## of 1.5 makes a critical hit deal 150 percent damage.
@export_range(1.0, 10.0, 0.05) var base_critical_damage_multiplier: float = 1.5
## Absolute final critical-chance cap after all weapon and cultivation bonuses.
## Values are ratios and cannot exceed one hundred percent.
@export_range(0.0, 1.0, 0.01) var maximum_critical_chance: float = 1.0
## Absolute final critical-damage cap after all cultivation bonuses. This is a
## safety limit; individual rewards may use lower caps.
@export_range(1.0, 20.0, 0.05) var maximum_critical_damage_multiplier: float = 5.0

@export_category("Attack Delivery")
## Player-wide additive attack-speed ratio before 气 progression. This reduces
## every weapon's automatic-attack interval through the shared resolver.
@export_range(0.0, 10.0, 0.01) var base_attack_speed_bonus: float = 0.0
## Player-wide additive projectile-speed ratio before 气 progression. Projectile
## weapons opt into the resolved multiplier through their attack implementation.
@export_range(0.0, 10.0, 0.01) var base_projectile_speed_bonus: float = 0.0
## Deprecated compatibility field. Weapon quantity now grows exclusively from
## collecting duplicate weapon pickups and this value is intentionally ignored.
@export_range(0, 100, 1) var base_delivery_count_bonus: int = 0

@export_category("Area and Targeting")
## Player-wide additive area-radius ratio before 神 progression. Weapons with a
## positive base area radius consume the resolved value.
@export_range(0.0, 10.0, 0.01) var base_aoe_radius_bonus: float = 0.0
## Player-wide additive targeting-range ratio before 神 progression. This
## affects primary attack range and supported secondary target searches.
@export_range(0.0, 10.0, 0.01) var base_targeting_range_bonus: float = 0.0

@export_category("Close-range Defense")
## Player close-range damage reduction before 精 progression. Values are
## ratios, so 0.10 represents ten percent reduction.
@export_range(0.0, 0.95, 0.01) var base_close_range_damage_reduction: float = 0.0
## Absolute final close-range reduction cap after 精 bonuses. Keeping this below
## one guarantees known nearby attacks can still deal damage.
@export_range(0.0, 0.99, 0.01) var maximum_close_range_damage_reduction: float = 0.95
## Maximum source distance in world pixels at which close-range damage
## reduction applies. Source-less hazards do not use this defensive stat.
@export_range(0.0, 600.0, 1.0) var close_range_mitigation_radius: float = 96.0

@export_category("Combat Safety Limits")
## Smallest permitted automatic-attack interval in seconds after all attack
## speed bonuses. This bounds firing frequency for every weapon.
@export_range(0.01, 1.0, 0.01) var minimum_attack_interval: float = 0.05
