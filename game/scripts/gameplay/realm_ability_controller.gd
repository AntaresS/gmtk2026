class_name RealmAbilityController
extends Node

signal ability_state_changed(snapshot: Dictionary)
signal qi_shield_absorbed(
	blocked_damage: float,
	qi_spent: int,
	remaining_damage: float
)
signal spirit_projection_changed(active: bool)
signal spirit_projection_broken(
	fallback_realm_index: int,
	fallback_layer: int
)
signal flight_elevation_changed(elevation: float)
signal temporary_flight_changed(active: bool, phase: StringName)

enum TemporaryFlightPhase {
	GROUNDED,
	ASCENDING,
	HOLDING,
	DESCENDING,
}

## Player sprite lifted for flight presentation.
@export var character_sprite: AnimatedSprite2D
## Ground shadow that remains fixed while the character sprite rises.
@export var player_shadow: PlayerShadow
## Optional translucent duplicate shown during spirit projection.
@export var spirit_sprite: AnimatedSprite2D
## Character sprite z-index used while standing or running on the road.
@export var grounded_character_z_index: int = 0
## Character sprite z-index used above the road. Keep this above the current
## ground-enemy z-index so enemies cannot cover an airborne player.
@export var airborne_character_z_index: int = 8

var _resources: RunResources
var _current_realm: RealmDefinition
var _current_realm_index: int = -1
var _spirit_projection_active: bool = false
var _character_base_scale: Vector2 = Vector2.ONE
var _spirit_base_scale: Vector2 = Vector2.ONE
var _temporary_flight_phase: TemporaryFlightPhase = (
	TemporaryFlightPhase.GROUNDED
)
var _temporary_flight_phase_elapsed: float = 0.0
var _current_flight_elevation: float = 0.0


func _ready() -> void:
	if character_sprite != null:
		_character_base_scale = character_sprite.scale
	if spirit_sprite != null:
		_spirit_base_scale = spirit_sprite.scale
		spirit_sprite.hide()


func _physics_process(delta: float) -> void:
	if (
		_current_realm != null
		and _current_realm.locomotion_mode
			== RealmDefinition.LocomotionMode.TEMPORARY_FLIGHT
		and _temporary_flight_phase
			!= TemporaryFlightPhase.GROUNDED
	):
		_advance_temporary_flight(delta)


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("spirit_projection")
		and not event.is_echo()
	):
		var handled := false
		if (
			_current_realm != null
			and _current_realm.locomotion_mode
				== RealmDefinition.LocomotionMode.TEMPORARY_FLIGHT
		):
			start_temporary_flight()
			handled = true
		else:
			handled = toggle_spirit_projection()
		if handled:
			get_viewport().set_input_as_handled()


func bind_resources(resources: RunResources) -> void:
	if (
		_resources != null
		and _resources.realm_state_changed.is_connected(_on_realm_state_changed)
	):
		_resources.realm_state_changed.disconnect(_on_realm_state_changed)
	_resources = resources
	if _resources != null:
		_resources.realm_state_changed.connect(_on_realm_state_changed)
	_refresh_realm()


func toggle_spirit_projection() -> bool:
	if _current_realm == null or not _current_realm.spirit_projection_enabled:
		return false
	_set_spirit_projection_active(not _spirit_projection_active)
	return true


func is_spirit_projection_active() -> bool:
	return _spirit_projection_active


func is_qi_shield_enabled() -> bool:
	return _current_realm != null and _current_realm.qi_shield_enabled


## Starts one configured ascent-hold-descent cycle when the active realm uses
## temporary flight. Repeated input while airborne does not reset the cycle.
func start_temporary_flight() -> bool:
	if (
		_current_realm == null
		or _current_realm.locomotion_mode
			!= RealmDefinition.LocomotionMode.TEMPORARY_FLIGHT
		or _temporary_flight_phase
			!= TemporaryFlightPhase.GROUNDED
	):
		return false
	_set_temporary_flight_phase(TemporaryFlightPhase.ASCENDING)
	return true


func is_temporary_flight_active() -> bool:
	return _temporary_flight_phase != TemporaryFlightPhase.GROUNDED


func get_current_flight_elevation() -> float:
	return _current_flight_elevation


## Returns whether an attacker from the supplied zero-based realm tier can
## damage the player. Lower-realm enemies cannot affect a higher-realm player.
func can_receive_damage_from_realm(attacker_realm_index: int) -> bool:
	if _resources == null:
		return true
	return attacker_realm_index >= _resources.get_current_realm_index()


func get_outgoing_damage_multiplier() -> float:
	if not _spirit_projection_active or _current_realm == null:
		return 1.0
	return maxf(_current_realm.spirit_damage_multiplier, 1.0)


func is_weapon_allowed(weapon_data: WeaponData) -> bool:
	if weapon_data == null:
		return false
	if _current_realm == null or not _current_realm.melee_weapons_only:
		return true
	return weapon_data.attack_domain == WeaponData.AttackDomain.MELEE


## Resolves realm defenses before PlayerController publishes lifespan damage.
## The returned dictionary is intentionally presentation-neutral for HUD and
## future runtime debugging consumers.
func resolve_incoming_damage(amount: float) -> Dictionary:
	var remaining_damage := maxf(amount, 0.0)
	var blocked_damage := 0.0
	var qi_spent := 0
	if (
		remaining_damage > 0.0
		and _current_realm != null
		and _current_realm.qi_shield_enabled
		and _resources != null
	):
		var shield_result := _resources.absorb_damage_with_qi(
			remaining_damage,
			_current_realm.shield_damage_per_qi
		)
		remaining_damage = float(shield_result["remaining_damage"])
		blocked_damage = float(shield_result["blocked_damage"])
		qi_spent = int(shield_result["qi_spent"])
		if blocked_damage > 0.0:
			qi_shield_absorbed.emit(
				blocked_damage,
				qi_spent,
				remaining_damage
			)

	var projection_broken := false
	if remaining_damage > 0.0 and _spirit_projection_active:
		projection_broken = true
		var fallback_realm_index := _current_realm.spirit_fallback_realm_index
		var fallback_layer := _current_realm.spirit_fallback_layer
		_set_spirit_projection_active(false)
		if _resources != null:
			_resources.demote_to_realm(
				fallback_realm_index,
				fallback_layer
			)
		spirit_projection_broken.emit(
			fallback_realm_index,
			fallback_layer
		)

	return {
		"incoming_damage": maxf(amount, 0.0),
		"blocked_damage": blocked_damage,
		"qi_spent": qi_spent,
		"remaining_damage": remaining_damage,
		"projection_broken": projection_broken,
	}


func get_debug_snapshot() -> Dictionary:
	return {
		"realm_id": _current_realm.realm_id if _current_realm != null else &"",
		"qi_shield_enabled": (
			_current_realm.qi_shield_enabled
			if _current_realm != null
			else false
		),
		"flight_height": (
			_current_realm.flight_height if _current_realm != null else 0.0
		),
		"current_flight_elevation": _current_flight_elevation,
		"temporary_flight_available": (
			_current_realm != null
			and _current_realm.locomotion_mode
				== RealmDefinition.LocomotionMode.TEMPORARY_FLIGHT
		),
		"temporary_flight_active": is_temporary_flight_active(),
		"temporary_flight_phase": _get_temporary_flight_phase_name(),
		"character_scale_multiplier": (
			_current_realm.character_scale_multiplier
			if _current_realm != null
			else 1.0
		),
		"spirit_projection_available": (
			_current_realm.spirit_projection_enabled
			if _current_realm != null
			else false
		),
		"spirit_projection_active": _spirit_projection_active,
		"outgoing_damage_multiplier": get_outgoing_damage_multiplier(),
	}


func _on_realm_state_changed(
	realm_index: int,
	_realm_name: String,
	_layer: int,
	_layer_count: int
) -> void:
	var previous_realm_index := _current_realm_index
	_refresh_realm()
	if previous_realm_index == 0 and realm_index == 1:
		start_temporary_flight()


func _refresh_realm() -> void:
	_current_realm_index = (
		_resources.get_current_realm_index()
		if _resources != null
		else -1
	)
	_current_realm = (
		_resources.get_current_realm_definition()
		if _resources != null
		else null
	)
	if _current_realm == null or not _current_realm.spirit_projection_enabled:
		_set_spirit_projection_active(false)
	_temporary_flight_phase = TemporaryFlightPhase.GROUNDED
	_temporary_flight_phase_elapsed = 0.0
	_current_flight_elevation = (
		maxf(_current_realm.flight_height, 0.0)
		if (
			_current_realm != null
			and _current_realm.locomotion_mode
				== RealmDefinition.LocomotionMode.FLIGHT
		)
		else 0.0
	)
	_apply_presentation()
	ability_state_changed.emit(get_debug_snapshot())


func _apply_presentation() -> void:
	var elevation := maxf(_current_flight_elevation, 0.0)
	var maximum_elevation := (
		maxf(_current_realm.flight_height, 0.0)
		if _current_realm != null
		else 0.0
	)
	var elevation_ratio := (
		clampf(elevation / maximum_elevation, 0.0, 1.0)
		if maximum_elevation > 0.0
		else 0.0
	)
	var maximum_scale_multiplier := (
		maxf(_current_realm.character_scale_multiplier, 0.1)
		if _current_realm != null
		else 1.0
	)
	var scale_multiplier := lerpf(
		1.0,
		maximum_scale_multiplier,
		elevation_ratio
	)
	if character_sprite != null:
		character_sprite.position.y = -elevation
		character_sprite.scale = _character_base_scale * scale_multiplier
		character_sprite.z_index = (
			airborne_character_z_index
			if elevation > 0.0
			else grounded_character_z_index
		)
	if player_shadow != null:
		player_shadow.set_elevation(elevation)
	if spirit_sprite != null:
		spirit_sprite.position.y = -elevation - 42.0
		spirit_sprite.scale = _spirit_base_scale * scale_multiplier
		spirit_sprite.z_index = airborne_character_z_index + 1
	flight_elevation_changed.emit(elevation)


func _advance_temporary_flight(delta: float) -> void:
	_temporary_flight_phase_elapsed += maxf(delta, 0.0)
	var maximum_elevation := maxf(_current_realm.flight_height, 0.0)
	match _temporary_flight_phase:
		TemporaryFlightPhase.ASCENDING:
			var ascent_duration := maxf(
				_current_realm.temporary_flight_ascent_duration,
				0.01
			)
			var ascent_ratio := clampf(
				_temporary_flight_phase_elapsed / ascent_duration,
				0.0,
				1.0
			)
			_current_flight_elevation = (
				maximum_elevation * _smooth_step(ascent_ratio)
			)
			if ascent_ratio >= 1.0:
				_set_temporary_flight_phase(
					TemporaryFlightPhase.HOLDING
				)
		TemporaryFlightPhase.HOLDING:
			_current_flight_elevation = maximum_elevation
			if (
				_temporary_flight_phase_elapsed
				>= maxf(
					_current_realm.temporary_flight_hold_duration,
					0.0
				)
			):
				_set_temporary_flight_phase(
					TemporaryFlightPhase.DESCENDING
				)
		TemporaryFlightPhase.DESCENDING:
			var descent_duration := maxf(
				_current_realm.temporary_flight_descent_duration,
				0.01
			)
			var descent_ratio := clampf(
				_temporary_flight_phase_elapsed / descent_duration,
				0.0,
				1.0
			)
			_current_flight_elevation = maximum_elevation * (
				1.0 - _smooth_step(descent_ratio)
			)
			if descent_ratio >= 1.0:
				_current_flight_elevation = 0.0
				_set_temporary_flight_phase(
					TemporaryFlightPhase.GROUNDED
				)
	_apply_presentation()


func _set_temporary_flight_phase(
	phase: TemporaryFlightPhase
) -> void:
	_temporary_flight_phase = phase
	_temporary_flight_phase_elapsed = 0.0
	temporary_flight_changed.emit(
		is_temporary_flight_active(),
		_get_temporary_flight_phase_name()
	)
	ability_state_changed.emit(get_debug_snapshot())


func _get_temporary_flight_phase_name() -> StringName:
	match _temporary_flight_phase:
		TemporaryFlightPhase.ASCENDING:
			return &"ascending"
		TemporaryFlightPhase.HOLDING:
			return &"holding"
		TemporaryFlightPhase.DESCENDING:
			return &"descending"
		_:
			return &"grounded"


func _smooth_step(value: float) -> float:
	var ratio := clampf(value, 0.0, 1.0)
	return ratio * ratio * (3.0 - 2.0 * ratio)


func _set_spirit_projection_active(active: bool) -> void:
	var next_active := (
		active
		and _current_realm != null
		and _current_realm.spirit_projection_enabled
	)
	if _spirit_projection_active == next_active:
		return
	_spirit_projection_active = next_active
	if character_sprite != null:
		character_sprite.modulate = (
			Color(0.72, 0.9, 1.0, 0.72)
			if _spirit_projection_active
			else Color.WHITE
		)
	if spirit_sprite != null:
		spirit_sprite.visible = _spirit_projection_active
	spirit_projection_changed.emit(_spirit_projection_active)
	ability_state_changed.emit(get_debug_snapshot())
