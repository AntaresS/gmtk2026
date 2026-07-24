class_name RunResources
extends Node

signal lifespan_changed(current: float, maximum: float)
signal lifespan_decay_rate_changed(rate_per_second: float)
signal lifespan_depleted
signal qi_changed(current: int, required: int)
signal cultivation_level_changed(level: int)
signal level_up_occurred(level: int, restored_lifespan: float)
signal breakthrough_reward_granted(current: float, maximum: float)

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
## Maximum realm breakthroughs and bounded lifespan rewards available in one
## run. This is the shared cap used by both eligibility and reward granting.
@export_range(1, 20, 1) var maximum_breakthroughs: int = 9
## Permanent maximum-lifespan increase granted by a completed breakthrough.
## This additive reward avoids compounding previous realm rewards.
@export_range(0.0, 1000.0, 1.0) var breakthrough_max_lifespan_increase: float = 60.0
## Portion of the new maximum lifespan restored after a breakthrough.
@export_range(0.0, 1.0, 0.05) var breakthrough_lifespan_restore_ratio: float = 0.5
## Additional passive lifespan consumed per second for each completed realm.
## Forward-speed decay scaling is applied after this realm pressure.
@export_range(0.0, 10.0, 0.05) var lifespan_decay_increase_per_breakthrough: float = 0.25

var current_lifespan: float = 0.0
var current_qi: int = 0
var cultivation_level: int = 1
var breakthroughs_completed: int = 0

var _run_active: bool = false
var _depletion_emitted: bool = false
var _lifespan_decay_multiplier: float = 1.0
var _initial_max_lifespan: float = 0.0


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


## Grants one completed-tribulation reward by additively increasing maximum
## lifespan, then restoring a configured portion of the new maximum. This
## resource records completion and enforces the shared realm and lifespan caps.
func grant_breakthrough_reward() -> void:
	if (
		not _run_active
		or breakthroughs_completed >= maxi(maximum_breakthroughs, 1)
	):
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
	var required := get_current_qi_requirement()
	while current_qi >= required:
		current_qi -= required
		level_up()
		required = get_current_qi_requirement()
	qi_changed.emit(current_qi, required)

## Increases maximum lifespan within its run cap and restores the configured
## amount.
func level_up() -> void:
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
	_run_active = current_lifespan > 0.0
	_depletion_emitted = false
	lifespan_changed.emit(current_lifespan, maximum)
	lifespan_decay_rate_changed.emit(get_current_lifespan_decay_rate())
	qi_changed.emit(current_qi, get_current_qi_requirement())
	cultivation_level_changed.emit(cultivation_level)


func is_run_active() -> bool:
	return _run_active


## Stops resource decay and rejects later rewards without emitting depletion.
## Game uses this for a successful ninth-realm ascension.
func complete_run() -> void:
	_run_active = false


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
