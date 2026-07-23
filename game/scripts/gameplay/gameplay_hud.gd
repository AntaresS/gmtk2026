class_name GameplayHud
extends CanvasLayer

@onready var lifespan_label: Label = %LifespanLabel
@onready var lifespan_bar: ProgressBar = %LifespanBar
@onready var lifespan_rate_label: Label = %LifespanRateLabel
@onready var cultivation_label: Label = %CultivationLabel
@onready var qi_label: Label = %QiLabel
@onready var qi_bar: ProgressBar = %QiBar
@onready var technique_label: Label = %TechniqueLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var equipment_library_label: Label = %EquipmentLibraryLabel
@onready var level_up_message: Label = %LevelUpMessage
@onready var level_up_timer: Timer = %LevelUpTimer

var _resources: RunResources
var _player: PlayerController
var _equipment_entries: Array[String] = []
var _weapon_upgrade_level: int = 0
var _weapon_power_bonus: int = 0


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
	_resources.lifespan_decay_rate_changed.connect(
		_on_lifespan_decay_rate_changed
	)
	_resources.qi_changed.connect(_on_qi_changed)
	_resources.cultivation_level_changed.connect(
		_on_cultivation_level_changed
	)
	_resources.level_up_occurred.connect(_on_level_up_occurred)
	_resources.lifespan_doubled.connect(_on_lifespan_doubled)
	_sync_all()


## Connects equipment presentation to the active player and immediately shows
## the starting technique and currently equipped weapon.
func bind_player(player: PlayerController) -> void:
	if _player != null and _player.equipment_changed.is_connected(
		_on_equipment_changed
	):
		_player.equipment_changed.disconnect(_on_equipment_changed)
	if _player != null and _player.equipment_inventory_changed.is_connected(
		_on_equipment_inventory_changed
	):
		_player.equipment_inventory_changed.disconnect(
			_on_equipment_inventory_changed
		)
	if _player != null and _player.weapon_upgrade_changed.is_connected(
		_on_weapon_upgrade_changed
	):
		_player.weapon_upgrade_changed.disconnect(_on_weapon_upgrade_changed)
	if _player != null and _player.weapon_power_changed.is_connected(
		_on_weapon_power_changed
	):
		_player.weapon_power_changed.disconnect(_on_weapon_power_changed)
	_player = player
	if _player == null:
		return
	_player.equipment_changed.connect(_on_equipment_changed)
	_player.equipment_inventory_changed.connect(
		_on_equipment_inventory_changed
	)
	_player.weapon_upgrade_changed.connect(_on_weapon_upgrade_changed)
	_player.weapon_power_changed.connect(_on_weapon_power_changed)
	_weapon_upgrade_level = _player.get_weapon_upgrade_level()
	_weapon_power_bonus = _player.get_weapon_power_bonus()
	_on_equipment_changed(
		_player.get_technique_name(),
		_player.get_weapon_name(),
		_player.get_current_weapon_damage()
	)
	_on_equipment_inventory_changed(
		_player.get_equipment_inventory_entries(),
		0
	)


func _disconnect_resources() -> void:
	if _resources == null:
		return
	if _resources.lifespan_changed.is_connected(_on_lifespan_changed):
		_resources.lifespan_changed.disconnect(_on_lifespan_changed)
	if _resources.lifespan_decay_rate_changed.is_connected(
		_on_lifespan_decay_rate_changed
	):
		_resources.lifespan_decay_rate_changed.disconnect(
			_on_lifespan_decay_rate_changed
		)
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
	if _resources.lifespan_doubled.is_connected(_on_lifespan_doubled):
		_resources.lifespan_doubled.disconnect(_on_lifespan_doubled)
	_resources = null


func _sync_all() -> void:
	if _resources == null:
		return
	_on_lifespan_changed(
		_resources.current_lifespan,
		maxf(_resources.max_lifespan, 0.0)
	)
	_on_lifespan_decay_rate_changed(
		_resources.get_current_lifespan_decay_rate()
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


func _on_lifespan_decay_rate_changed(rate_per_second: float) -> void:
	lifespan_rate_label.text = "寿元消耗  -%.2f / 秒" % rate_per_second


func _on_qi_changed(current: int, required: int) -> void:
	qi_label.text = "灵气  %d / %d" % [current, required]
	qi_bar.max_value = required
	qi_bar.value = current


func _on_cultivation_level_changed(level: int) -> void:
	cultivation_label.text = "练气 %d" % level


func _on_equipment_changed(
	technique_name: String,
	equipment_name: String,
	damage: int
) -> void:
	technique_label.text = "功法  %s" % technique_name
	weapon_label.text = "当前装备  %s  · 伤害 %d" % [
		equipment_name,
		damage,
	]


func _on_equipment_inventory_changed(
	entries: Array[String],
	_current_index: int
) -> void:
	_equipment_entries = entries
	_render_equipment_library()


func _on_weapon_upgrade_changed(level: int) -> void:
	_weapon_upgrade_level = maxi(level, 0)
	_render_equipment_library()


func _on_weapon_power_changed(bonus_damage: int) -> void:
	_weapon_power_bonus = maxi(bonus_damage, 0)
	_render_equipment_library()


func _render_equipment_library() -> void:
	equipment_library_label.text = (
		"功法碎片强化 +%d · 武器威能 +%d\n装备库（Tab 切换）\n%s"
		% [
		_weapon_upgrade_level,
		_weapon_power_bonus,
		"\n".join(_equipment_entries),
		]
	)


func _on_level_up_occurred(level: int, restored_lifespan: float) -> void:
	level_up_message.text = "练气 %d\n寿元 +%.0f" % [
		level,
		restored_lifespan,
	]
	level_up_message.show()
	level_up_timer.start()


func _on_lifespan_doubled(_current: float, _maximum: float) -> void:
	level_up_message.text = "渡劫成功\n寿元翻倍"
	level_up_message.show()
	level_up_timer.start()


func _on_level_up_timer_timeout() -> void:
	level_up_message.hide()
