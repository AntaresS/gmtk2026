class_name RealmDefinition
extends Resource

enum LocomotionMode {
	GROUND,
	TEMPORARY_FLIGHT,
	FLIGHT,
}

@export_category("Identity")
## Stable ID used by gameplay and future debug tools. Keep this unchanged when
## editing display text.
@export var realm_id: StringName = &"realm"
## Chinese realm name shown on the HUD and breakthrough presentation.
@export var display_name: String = "境界"
## Number of cultivation layers inside this realm.
@export_range(1, 99, 1) var layer_count: int = 9

@export_category("Capabilities")
## Grounded or airborne presentation used while this realm is active.
@export var locomotion_mode: LocomotionMode = LocomotionMode.GROUND
## Restricts equipment to WeaponData melee-domain definitions.
@export var melee_weapons_only: bool = false
## Makes a Qi shield available to the realm's active ability. The shield still
## starts inactive and only spends Qi while its stance is toggled on.
@export var qi_shield_enabled: bool = false
## Lifespan damage absorbed by one Qi while the shield is enabled.
@export_range(0.01, 100.0, 0.05) var shield_damage_per_qi: float = 1.0
## Enables the Space-key spirit-projection stance.
@export var spirit_projection_enabled: bool = false

@export_category("Presentation")
## Vertical visual lift in pixels while this realm uses flight locomotion.
@export_range(0.0, 240.0, 1.0) var flight_height: float = 0.0
## Character-model scale applied while this realm is active. Values above one
## make higher flight feel closer to the camera without changing collisions.
@export_range(0.5, 2.5, 0.05) var character_scale_multiplier: float = 1.0
## Seconds spent rising from the road to flight_height in temporary flight.
@export_range(0.05, 5.0, 0.05) var temporary_flight_ascent_duration: float = 0.45
## Seconds spent gliding at flight_height before descent begins.
@export_range(0.0, 10.0, 0.05) var temporary_flight_hold_duration: float = 1.1
## Seconds spent descending from flight_height back to the road.
@export_range(0.05, 5.0, 0.05) var temporary_flight_descent_duration: float = 0.65

@export_category("Spirit Projection")
## Final outgoing-damage multiplier while spirit projection is active.
@export_range(1.0, 10.0, 0.05) var spirit_damage_multiplier: float = 2.0
## Incoming-damage multiplier applied before Qi absorption while spirit
## projection is active. Values above one spend Qi faster and amplify overflow.
@export_range(1.0, 10.0, 0.05) var spirit_incoming_damage_multiplier: float = 1.5
## Whether attempting to leave this realm triggers the fatal breakthrough
## sequence instead of a normal tribulation.
@export var fatal_breakthrough: bool = false

@export_category("Breakthrough Tribulation")
## Number of lightning strikes used when attempting to leave this realm.
## Fatal realms may route this value to a separate unavoidable sequence.
@export_range(1, 20, 1) var tribulation_strike_count: int = 9
## Multiplier applied to the base warning duration of every lightning strike.
## Values above one give the player more preparation time.
@export_range(0.1, 10.0, 0.05) var tribulation_warning_duration_multiplier: float = 1.0
