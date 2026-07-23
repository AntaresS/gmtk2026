class_name GameplayHud
extends CanvasLayer

@onready var lifespan_label: Label = %LifespanLabel
@onready var lifespan_bar: ProgressBar = %LifespanBar
@onready var cultivation_label: Label = %CultivationLabel
@onready var qi_label: Label = %QiLabel
@onready var qi_bar: ProgressBar = %QiBar
@onready var level_up_message: Label = %LevelUpMessage
@onready var level_up_timer: Timer = %LevelUpTimer

var _resources: RunResources


## Connects this presentation layer to one run-state owner and immediately
## synchronizes every displayed value without frame polling.
func bind_resources(resources: RunResources) -> void:
	if _resources == resources:
		_sync_all()
		return
	_disconnect_resources()
	_resources = resources
	if _resources == null:
		return
	_resources.lifespan_changed.connect(_on_lifespan_changed)
	_resources.qi_changed.connect(_on_qi_changed)
	_resources.cultivation_level_changed.connect(
		_on_cultivation_level_changed
	)
	_resources.level_up_occurred.connect(_on_level_up_occurred)
	_sync_all()


func _disconnect_resources() -> void:
	if _resources == null:
		return
	if _resources.lifespan_changed.is_connected(_on_lifespan_changed):
		_resources.lifespan_changed.disconnect(_on_lifespan_changed)
	if _resources.qi_changed.is_connected(_on_qi_changed):
		_resources.qi_changed.disconnect(_on_qi_changed)
	if (
		_resources.cultivation_level_changed.is_connected(
			_on_cultivation_level_changed
		)
	):
		_resources.cultivation_level_changed.disconnect(
			_on_cultivation_level_changed
		)
	if _resources.level_up_occurred.is_connected(_on_level_up_occurred):
		_resources.level_up_occurred.disconnect(_on_level_up_occurred)
	_resources = null


func _sync_all() -> void:
	if _resources == null:
		return
	_on_lifespan_changed(
		_resources.current_lifespan,
		maxf(_resources.max_lifespan, 0.0)
	)
	_on_qi_changed(
		_resources.current_qi,
		maxi(_resources.qi_required_per_level, 1)
	)
	_on_cultivation_level_changed(_resources.cultivation_level)


func _on_lifespan_changed(current: float, maximum: float) -> void:
	lifespan_label.text = "寿元  %.1fs" % current
	lifespan_bar.max_value = maximum
	lifespan_bar.value = current


func _on_qi_changed(current: int, required: int) -> void:
	qi_label.text = "灵气  %d / %d" % [current, required]
	qi_bar.max_value = required
	qi_bar.value = current


func _on_cultivation_level_changed(level: int) -> void:
	cultivation_label.text = "练气 %d" % level


func _on_level_up_occurred(level: int, restored_lifespan: float) -> void:
	level_up_message.text = "练气 %d\n寿元 +%.0f" % [
		level,
		restored_lifespan,
	]
	level_up_message.show()
	level_up_timer.start()


func _on_level_up_timer_timeout() -> void:
	level_up_message.hide()
