class_name WeaponCombatStats
extends RefCounted

## Read-only runtime snapshot for one equipped weapon. It combines immutable
## WeaponData, the collected damage roll, player-wide values, and matching
## cultivation rewards without changing any source object.

var weapon_id: StringName = &""
var display_name: String = ""
var attack_kind: int = 0
var cultivation_types: Array[int] = []

## Per-drop damage stored by the equipment inventory before run modifiers.
var rolled_damage: int = 1
## Additive matching-type damage ratio resolved from cultivation progression.
var matching_damage_bonus: float = 0.0
## Current integer damage after preserving the existing rounding behavior.
var resolved_damage: int = 1
## Exact pre-round damage used by repeated-hit weapons to preserve fractional
## progression across multiple strikes without changing ordinary hit behavior.
var resolved_damage_exact: float = 1.0

var critical_chance: float = 0.0
var critical_damage_multiplier: float = 1.0
var attack_speed_bonus: float = 0.0
## Resolved automatic-attack interval, or Flying Sword magazine reload time.
var attack_interval: float = 0.7
var attack_range: float = 72.0
var targeting_range_bonus: float = 0.0
var secondary_targeting_range: float = 0.0
var projectile_speed_multiplier: float = 1.0
## Total delivery count after combining the weapon base and player bonus.
var delivery_count: int = 1
var aoe_radius_bonus: float = 0.0
var aoe_radius: float = 0.0
