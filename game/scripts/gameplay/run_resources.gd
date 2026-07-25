class_name RunResources
extends Node

signal lifespan_changed(current: float, maximum: float)
signal lifespan_decay_rate_changed(rate_per_second: float)
signal lifespan_depleted
signal qi_changed(current: int, required: int)
signal cultivation_level_changed(level: int)
signal level_up_occurred(level: int, restored_lifespan: float)
signal breakthrough_reward_granted(current: float, maximum: float)
signal cultivation_fragment_progress_changed(
	cultivation_type: int,
	current: int,
	required: int
)
signal cultivation_type_level_changed(
	cultivation_type: int,
	level: int,
	reward_name: String
)
signal cultivation_stats_changed(cultivation_type: int, level: int)
signal realm_state_changed(
	realm_index: int,
	realm_name: String,
	layer: int,
	layer_count: int
)
signal breakthrough_requested(
	from_realm_index: int,
	to_realm_index: int,
	fatal: bool
)
signal breakthrough_pending_changed(pending: bool, fatal: bool)
signal realm_demoted(
	from_realm_index: int,
	to_realm_index: int,
	to_layer: int
)

const CultivationTypesResource = preload(
	"res://game/scripts/gameplay/cultivation_types.gd"
)
const DEFAULT_CULTIVATION_CONFIG: CultivationConfig = preload(
	"res://game/resources/cultivation_config.tres"
)
const DEFAULT_REALM_PROGRESSION_CONFIG: RealmProgressionConfig = preload(
	"res://game/resources/realm_progression_config.tres"
)

@export_category("Lifespan")
## Maximum lifespan for the current run, measured in seconds. Lifespan restores
## are clamped to this value and do not increase it.
@export var max_lifespan: float = 180.0
## Hard upper bound for maximum lifespan during one run, measured in seconds.
## Level and breakthrough rewards are clamped to this designer safety limit.
@export_range(1.0, 10000.0, 1.0) var maximum_lifespan_cap: float = 900.0
## Lifespan assigned when a new run is initialized, measured in seconds. Values
## outside zero to max_lifespan are clamped.
@export var starting_lifespan: float = 180.0
## Lifespan consumed per unpaused real-time second while the run is active.
@export var lifespan_decay_per_second: float = 1.0

@export_category("Cultivation Progression")
## Lifespan restored by each cultivation level gained, measured in seconds.
@export var level_up_lifespan_restore: float = 10.0
## Maximum-lifespan increase granted by each cultivation level, in seconds.
@export var level_up_maxHP_increase: float = 2.0
## Qi consumed when advancing from cultivation level one to level two. Later
## requirements add qi_requirement_increase_per_level for every level already
## completed. Overflow is retained and one addition may award multiple levels.
@export var qi_required_per_level: int = 100
## Additional qi required for each successive cultivation level. At the
## default 25, requirements progress as 100, 125, 150, and so on.
@export_range(0, 10000, 1) var qi_requirement_increase_per_level: int = 25
## Cultivation levels between realm-breakthrough opportunities. With the
## default nine, breakthroughs unlock at levels 10, 19, 28, and so on.
@export_range(1, 100, 1) var breakthrough_level_interval: int = 9
## Compatibility cap used by the legacy interval helpers and direct reward API.
## Resource-driven realm transitions may repeat after demotion; their lifespan
## growth remains bounded by maximum_lifespan_cap instead.
@export_range(1, 20, 1) var maximum_breakthroughs: int = 3
## Permanent maximum-lifespan increase granted by a completed breakthrough.
## This additive reward avoids compounding previous realm rewards.
@export_range(0.0, 1000.0, 1.0) var breakthrough_max_lifespan_increase: float = 60.0
## Portion of the new maximum lifespan restored after a breakthrough.
@export_range(0.0, 1.0, 0.05) var breakthrough_lifespan_restore_ratio: float = 0.5
## Additional passive lifespan consumed per second for each completed realm.
## Forward-speed decay scaling is applied after this realm pressure.
@export_range(0.0, 10.0, 0.05) var lifespan_decay_increase_per_breakthrough: float = 0.25

@export_category("Threefold Cultivation")
## Shared reward, cap, color, and per-level tuning for 精, 气, and 神. This
## resource is read-only at runtime; fragment counts and levels remain run state.
@export var cultivation_config: CultivationConfig = DEFAULT_CULTIVATION_CONFIG

@export_category("Realm Progression")
## Ordered realm definitions and capability unlocks. Runtime state stores only
## the overall level and resolves realm/layer through this immutable resource.
@export var realm_progression_config: RealmProgressionConfig = (
	DEFAULT_REALM_PROGRESSION_CONFIG
)

var current_lifespan: float = 0.0
var current_qi: int = 0
var cultivation_level: int = 1
var breakthroughs_completed: int = 0
var cultivation_fragments: Array[int] = [0, 0, 0]
var cultivation_levels: Array[int] = [0, 0, 0]

var _run_active: bool = false
var _depletion_emitted: bool = false
var _lifespan_decay_multiplier: float = 1.0
var _initial_max_lifespan: float = 0.0
var _breakthrough_pending: bool = false
var _pending_breakthrough_fatal: bool = false
var _pending_target_realm_index: int = -1


func _ready() -> void:
	_initial_max_lifespan = clampf(
		max_lifespan,
		0.0,
		maxf(maximum_lifespan_cap, 0.0)
	)
	max_lifespan = _initial_max_lifespan
	reset_resources()


func _process(delta: float) -> void:
	if not _run_active:
		return
	apply_lifespan_damage(get_current_lifespan_decay_rate() * delta)


## Applies the player's live forward-speed multiplier to passive lifespan
## decay and publishes the current per-second rate for the HUD.
func set_lifespan_decay_multiplier(multiplier: float) -> void:
	var next_multiplier := maxf(multiplier, 0.0)
	if is_equal_approx(next_multiplier, _lifespan_decay_multiplier):
		return
	_lifespan_decay_multiplier = next_multiplier
	lifespan_decay_rate_changed.emit(get_current_lifespan_decay_rate())


func get_current_lifespan_decay_rate() -> float:
	return (
		(
			maxf(lifespan_decay_per_second, 0.0)
			+ float(breakthroughs_completed)
				* maxf(lifespan_decay_increase_per_breakthrough, 0.0)
		)
		* _lifespan_decay_multiplier
	)


## Removes lifespan without allowing it below zero. Depletion permanently stops
## this component for the current run and is emitted exactly once.
func apply_lifespan_damage(amount: float) -> void:
	if not _run_active or amount <= 0.0:
		return

	var maximum := _get_maximum_lifespan()
	var next_lifespan := clampf(current_lifespan - amount, 0.0, maximum)
	# Approximate equality scales its tolerance with current_lifespan and can
	# swallow per-frame decay after large breakthrough rewards at high FPS.
	if next_lifespan >= current_lifespan:
		return

	current_lifespan = next_lifespan
	lifespan_changed.emit(current_lifespan, maximum)
	if current_lifespan <= 0.0:
		_run_active = false
		if not _depletion_emitted:
			_depletion_emitted = true
			lifespan_depleted.emit()


## Adds lifespan without allowing it above max_lifespan. Restores are ignored
## after the run ends so progression cannot resume a depleted run.
func restore_lifespan(amount: float) -> void:
	if not _run_active or amount <= 0.0:
		return

	var maximum := _get_maximum_lifespan()
	var next_lifespan := clampf(current_lifespan + amount, 0.0, maximum)
	if next_lifespan <= current_lifespan:
		return

	current_lifespan = next_lifespan
	lifespan_changed.emit(current_lifespan, maximum)


## Grants one legacy completed-tribulation reward by additively increasing
## maximum lifespan, then restoring a configured portion of the new maximum.
## Direct grants enforce maximum_breakthroughs and maximum_lifespan_cap.
func grant_breakthrough_reward() -> void:
	if (
		not _run_active
		or breakthroughs_completed >= maxi(maximum_breakthroughs, 1)
	):
		return
	_apply_breakthrough_reward()


## Applies one survived realm-transition reward. Resource-driven realm
## transitions may repeat after a demotion, so their rewards are bounded by the
## lifespan cap rather than the legacy number-of-breakthroughs compatibility cap.
func _apply_breakthrough_reward() -> void:
	if not _run_active:
		return
	breakthroughs_completed += 1
	max_lifespan = minf(
		maxf(
			max_lifespan
				+ maxf(breakthrough_max_lifespan_increase, 0.0),
			0.0
		),
		maxf(maximum_lifespan_cap, 0.0)
	)
	current_lifespan = clampf(
		current_lifespan
			+ max_lifespan
				* clampf(breakthrough_lifespan_restore_ratio, 0.0, 1.0),
		0.0,
		max_lifespan
	)
	lifespan_changed.emit(current_lifespan, max_lifespan)
	lifespan_decay_rate_changed.emit(get_current_lifespan_decay_rate())
	breakthrough_reward_granted.emit(current_lifespan, max_lifespan)


## Adds qi, preserves overflow, and resolves every level earned by this
## addition. Each resolved level restores the configured lifespan amount.
func add_qi(amount: int) -> void:
	if not _run_active or amount <= 0:
		return

	current_qi += amount
	_resolve_qi_progression()
	qi_changed.emit(current_qi, get_current_qi_requirement())


## Converts accumulated Qi into ordinary layers until a realm boundary is
## reached. Boundary Qi is consumed once and gameplay receives one explicit
## breakthrough request; capabilities change only after successful completion.
func _resolve_qi_progression() -> void:
	while (
		_run_active
		and not _breakthrough_pending
		and current_qi >= get_current_qi_requirement()
	):
		current_qi -= get_current_qi_requirement()
		if (
			realm_progression_config != null
			and realm_progression_config.is_last_layer(cultivation_level)
		):
			_request_realm_breakthrough()
			return
		_advance_one_layer()


## Adds run-local fragments to one cultivation track. Every third fragment
## advances only that type, resets its progress, and publishes the generic
## reward selected by the shared repeating cycle.
func add_cultivation_fragment(
	cultivation_type: int,
	amount: int = 1
) -> void:
	if (
		not _run_active
		or amount <= 0
		or not CultivationTypesResource.is_valid_type(cultivation_type)
	):
		return
	var required := get_cultivation_fragments_required()
	for _fragment in amount:
		cultivation_fragments[cultivation_type] += 1
		if cultivation_fragments[cultivation_type] < required:
			cultivation_fragment_progress_changed.emit(
				cultivation_type,
				cultivation_fragments[cultivation_type],
				required
			)
			continue
		cultivation_fragments[cultivation_type] = 0
		cultivation_levels[cultivation_type] += 1
		cultivation_fragment_progress_changed.emit(
			cultivation_type,
			0,
			required
		)
		var level := cultivation_levels[cultivation_type]
		var reward_name := (
			cultivation_config.get_reward_message(cultivation_type, level)
			if cultivation_config != null
			else ""
		)
		cultivation_type_level_changed.emit(
			cultivation_type,
			level,
			reward_name
		)
		cultivation_stats_changed.emit(cultivation_type, level)


func get_cultivation_fragments(cultivation_type: int) -> int:
	if not CultivationTypesResource.is_valid_type(cultivation_type):
		return 0
	return cultivation_fragments[cultivation_type]


func get_cultivation_level(cultivation_type: int) -> int:
	if not CultivationTypesResource.is_valid_type(cultivation_type):
		return 0
	return cultivation_levels[cultivation_type]


func get_cultivation_fragments_required() -> int:
	if cultivation_config == null:
		return 3
	return cultivation_config.get_fragments_required()


## Returns the generic stat snapshot for one cultivation type at its live run
## level. Weapon scripts do not branch on type-specific reward order.
func get_cultivation_stats(cultivation_type: int) -> Dictionary:
	if (
		cultivation_config == null
		or not CultivationTypesResource.is_valid_type(cultivation_type)
	):
		return {"stats": {}, "damage_bonus": 0.0}
	return cultivation_config.resolve_level(
		cultivation_type,
		get_cultivation_level(cultivation_type)
	)

## Increases maximum lifespan within its run cap and restores the configured
## amount.
func level_up() -> void:
	_advance_one_layer()


func _advance_one_layer() -> void:
	cultivation_level += 1
	max_lifespan = minf(
		max_lifespan + maxf(level_up_maxHP_increase, 0.0),
		maxf(maximum_lifespan_cap, 0.0)
	)
	restore_lifespan(level_up_lifespan_restore)
	cultivation_level_changed.emit(cultivation_level)
	lifespan_decay_rate_changed.emit(get_current_lifespan_decay_rate())
	level_up_occurred.emit(
		cultivation_level,
		maxf(level_up_lifespan_restore, 0.0)
	)
	_emit_realm_state()

## Restores this component to one clean run and publishes a complete initial
## snapshot for newly connected presentation or gameplay systems.
func reset_resources() -> void:
	if _initial_max_lifespan > 0.0:
		max_lifespan = _initial_max_lifespan
	var maximum := _get_maximum_lifespan()
	current_lifespan = clampf(starting_lifespan, 0.0, maximum)
	current_qi = 0
	cultivation_level = 1
	breakthroughs_completed = 0
	_breakthrough_pending = false
	_pending_breakthrough_fatal = false
	_pending_target_realm_index = -1
	cultivation_fragments = [0, 0, 0]
	cultivation_levels = [0, 0, 0]
	_run_active = current_lifespan > 0.0
	_depletion_emitted = false
	lifespan_changed.emit(current_lifespan, maximum)
	lifespan_decay_rate_changed.emit(get_current_lifespan_decay_rate())
	qi_changed.emit(current_qi, get_current_qi_requirement())
	cultivation_level_changed.emit(cultivation_level)
	_emit_realm_state()
	for cultivation_type in CultivationTypesResource.ORDER:
		cultivation_fragment_progress_changed.emit(
			cultivation_type,
			0,
			get_cultivation_fragments_required()
		)
		cultivation_stats_changed.emit(cultivation_type, 0)


func is_run_active() -> bool:
	return _run_active


## Stops resource decay and rejects later rewards without emitting depletion.
## Game uses this for a successful ninth-realm ascension.
func complete_run() -> void:
	_run_active = false


## Completes a non-fatal realm transition after HeavenlyTribulation reports
## survival. The first layer of the new realm and its capabilities become
## active atomically with the breakthrough reward.
func complete_pending_breakthrough() -> bool:
	if (
		not _run_active
		or not _breakthrough_pending
		or _pending_breakthrough_fatal
		or realm_progression_config == null
	):
		return false
	var target_realm_index := _pending_target_realm_index
	_breakthrough_pending = false
	_pending_breakthrough_fatal = false
	_pending_target_realm_index = -1
	cultivation_level = realm_progression_config.get_overall_level(
		target_realm_index,
		1
	)
	max_lifespan = minf(
		max_lifespan + maxf(level_up_maxHP_increase, 0.0),
		maxf(maximum_lifespan_cap, 0.0)
	)
	_apply_breakthrough_reward()
	cultivation_level_changed.emit(cultivation_level)
	_emit_realm_state()
	breakthrough_pending_changed.emit(false, false)
	_resolve_qi_progression()
	qi_changed.emit(current_qi, get_current_qi_requirement())
	return true


func has_pending_realm_breakthrough() -> bool:
	return _breakthrough_pending


func is_pending_breakthrough_fatal() -> bool:
	return _breakthrough_pending and _pending_breakthrough_fatal


## Instantly ends the active run. Fatal breakthrough attacks use this direct
## resource operation so Qi shields and ordinary damage modifiers cannot
## accidentally negate the authored instant death.
func force_deplete() -> void:
	if not _run_active:
		return
	current_lifespan = 0.0
	_run_active = false
	lifespan_changed.emit(0.0, _get_maximum_lifespan())
	if not _depletion_emitted:
		_depletion_emitted = true
		lifespan_depleted.emit()


## Uses integer Qi to absorb floating-point damage and returns a neutral result
## object suitable for player presentation and future debug panels.
func absorb_damage_with_qi(
	damage: float,
	damage_per_qi: float
) -> Dictionary:
	var safe_damage := maxf(damage, 0.0)
	var efficiency := maxf(damage_per_qi, 0.01)
	if not _run_active or safe_damage <= 0.0 or current_qi <= 0:
		return {
			"blocked_damage": 0.0,
			"qi_spent": 0,
			"remaining_damage": safe_damage,
		}
	var blocked_damage := minf(
		safe_damage,
		float(current_qi) * efficiency
	)
	var qi_spent := mini(
		ceili(blocked_damage / efficiency),
		current_qi
	)
	current_qi -= qi_spent
	qi_changed.emit(current_qi, get_current_qi_requirement())
	return {
		"blocked_damage": blocked_damage,
		"qi_spent": qi_spent,
		"remaining_damage": maxf(safe_damage - blocked_damage, 0.0),
	}


## Drops the overall cultivation state to a configured realm/layer without
## rolling back run-local lifespan rewards or independent 精/气/神 progress.
func demote_to_realm(realm_index: int, layer: int) -> void:
	if not _run_active or realm_progression_config == null:
		return
	var from_realm_index := get_current_realm_index()
	var target_realm_index := clampi(
		realm_index,
		0,
		maxi(realm_progression_config.get_realm_count() - 1, 0)
	)
	cultivation_level = realm_progression_config.get_overall_level(
		target_realm_index,
		layer
	)
	current_qi = 0
	_breakthrough_pending = false
	_pending_breakthrough_fatal = false
	_pending_target_realm_index = -1
	cultivation_level_changed.emit(cultivation_level)
	_emit_realm_state()
	qi_changed.emit(current_qi, get_current_qi_requirement())
	breakthrough_pending_changed.emit(false, false)
	realm_demoted.emit(
		from_realm_index,
		target_realm_index,
		get_current_realm_layer()
	)


func get_current_realm_index() -> int:
	if realm_progression_config == null:
		return 0
	return realm_progression_config.get_realm_index_for_level(
		cultivation_level
	)


func get_current_realm_layer() -> int:
	if realm_progression_config == null:
		return cultivation_level
	return realm_progression_config.get_layer_for_level(cultivation_level)


func get_current_realm_definition() -> RealmDefinition:
	if realm_progression_config == null:
		return null
	return realm_progression_config.get_realm(get_current_realm_index())


func get_realm_display_text() -> String:
	var realm := get_current_realm_definition()
	if realm == null:
		return "境界 %d" % cultivation_level
	return "%s %d层" % [realm.display_name, get_current_realm_layer()]


func get_debug_snapshot() -> Dictionary:
	var realm_snapshot := (
		realm_progression_config.get_debug_snapshot(cultivation_level)
		if realm_progression_config != null
		else {}
	)
	realm_snapshot.merge({
		"current_qi": current_qi,
		"required_qi": get_current_qi_requirement(),
		"current_lifespan": current_lifespan,
		"maximum_lifespan": max_lifespan,
		"lifespan_decay_rate": get_current_lifespan_decay_rate(),
		"breakthroughs_completed": breakthroughs_completed,
		"breakthrough_pending": _breakthrough_pending,
		"fatal_breakthrough_pending": _pending_breakthrough_fatal,
	}, true)
	return realm_snapshot


func _request_realm_breakthrough() -> void:
	var from_realm_index := get_current_realm_index()
	var current_realm := get_current_realm_definition()
	var has_next := realm_progression_config.has_next_realm(cultivation_level)
	_breakthrough_pending = true
	_pending_breakthrough_fatal = (
		not has_next
		or (current_realm != null and current_realm.fatal_breakthrough)
	)
	_pending_target_realm_index = (
		from_realm_index + 1 if has_next else from_realm_index
	)
	breakthrough_pending_changed.emit(
		true,
		_pending_breakthrough_fatal
	)
	breakthrough_requested.emit(
		from_realm_index,
		_pending_target_realm_index,
		_pending_breakthrough_fatal
	)


func _emit_realm_state() -> void:
	var realm := get_current_realm_definition()
	realm_state_changed.emit(
		get_current_realm_index(),
		realm.display_name if realm != null else "境界",
		get_current_realm_layer(),
		maxi(realm.layer_count, 1) if realm != null else 1
	)


## Returns how many realm breakthroughs have unlocked at a cultivation level,
## capped by the configured maximum for this run.
func get_unlocked_breakthrough_count(level: int) -> int:
	var interval := maxi(breakthrough_level_interval, 1)
	var completed_level_bands := floori(
		float(maxi(level, 1) - 1) / float(interval)
	)
	return mini(completed_level_bands, maxi(maximum_breakthroughs, 1))


## Returns whether the supplied cultivation level has unlocked a breakthrough
## whose tribulation and reward have not yet been completed.
func has_pending_breakthrough(level: int) -> bool:
	return (
		breakthroughs_completed
		< get_unlocked_breakthrough_count(level)
	)


## Returns the qi needed to advance from the current cultivation level. The
## requirement grows linearly from qi_required_per_level and is never below one.
func get_current_qi_requirement() -> int:
	var completed_levels := maxi(cultivation_level - 1, 0)
	return maxi(
		maxi(qi_required_per_level, 1)
			+ maxi(qi_requirement_increase_per_level, 0)
				* completed_levels,
		1
	)


func _get_maximum_lifespan() -> float:
	return minf(
		maxf(max_lifespan, 0.0),
		maxf(maximum_lifespan_cap, 0.0)
	)
