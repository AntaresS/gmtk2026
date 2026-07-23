class_name RunResources
extends Node

signal lifespan_changed(current: float, maximum: float)
signal lifespan_depleted
signal qi_changed(current: int, required: int)
signal cultivation_level_changed(level: int)
signal level_up_occurred(level: int, restored_lifespan: float)

## Maximum lifespan for the current run, measured in seconds. Lifespan restores
## are clamped to this value and do not increase it.
@export var max_lifespan: float = 45.0
## Lifespan assigned when a new run is initialized, measured in seconds. Values
## outside zero to max_lifespan are clamped.
@export var starting_lifespan: float = 45.0
## Lifespan consumed per unpaused real-time second while the run is active.
@export var lifespan_decay_per_second: float = 1.0
## Lifespan restored by each cultivation level gained, measured in seconds.
@export var level_up_lifespan_restore: float = 10.0
## Max Lifespan amount after level up
@export var level_up_maxHP_increase: float = 10.0
## Qi consumed for each cultivation level. Overflow is retained and a single
## addition may award multiple levels.
@export var qi_required_per_level: int = 100

var current_lifespan: float = 0.0
var current_qi: int = 0
var cultivation_level: int = 1

var _run_active: bool = false
var _depletion_emitted: bool = false


func _ready() -> void:
	reset_resources()


func _process(delta: float) -> void:
	if not _run_active:
		return
	apply_lifespan_damage(maxf(lifespan_decay_per_second, 0.0) * delta)


## Removes lifespan without allowing it below zero. Depletion permanently stops
## this component for the current run and is emitted exactly once.
func apply_lifespan_damage(amount: float) -> void:
	if not _run_active or amount <= 0.0:
		return

	var maximum := _get_maximum_lifespan()
	var next_lifespan := clampf(current_lifespan - amount, 0.0, maximum)
	if is_equal_approx(next_lifespan, current_lifespan):
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
	if is_equal_approx(next_lifespan, current_lifespan):
		return

	current_lifespan = next_lifespan
	lifespan_changed.emit(current_lifespan, maximum)


## Adds qi, preserves overflow, and resolves every level earned by this
## addition. Each resolved level restores the configured lifespan amount.
func add_qi(amount: int) -> void:
	if not _run_active or amount <= 0:
		return

	current_qi += amount
	var required := _get_qi_requirement()
	while current_qi >= required:
		current_qi -= required
		level_up()
	qi_changed.emit(current_qi, required)

## level up increases the max HP and also restores the 
func level_up():
	cultivation_level += 1
	max_lifespan += level_up_maxHP_increase
	restore_lifespan(level_up_lifespan_restore)
	cultivation_level_changed.emit(cultivation_level)
	level_up_occurred.emit(
		cultivation_level,
		maxf(level_up_lifespan_restore, 0.0)
	)

## Restores this component to one clean run and publishes a complete initial
## snapshot for newly connected presentation or gameplay systems.
func reset_resources() -> void:
	var maximum := _get_maximum_lifespan()
	current_lifespan = clampf(starting_lifespan, 0.0, maximum)
	current_qi = 0
	cultivation_level = 1
	_run_active = current_lifespan > 0.0
	_depletion_emitted = false
	lifespan_changed.emit(current_lifespan, maximum)
	qi_changed.emit(current_qi, _get_qi_requirement())
	cultivation_level_changed.emit(cultivation_level)


func is_run_active() -> bool:
	return _run_active


func _get_maximum_lifespan() -> float:
	return maxf(max_lifespan, 0.0)


func _get_qi_requirement() -> int:
	return maxi(qi_required_per_level, 1)
