class_name GameplayHud
extends CanvasLayer

const DAMAGE_FLASH_DURATION: float = 0.38

## Current-to-maximum lifespan ratio below which the persistent screen-edge
## danger warning activates. The default represents fifteen percent.
@export_range(0.01, 0.5, 0.01) var danger_lifespan_ratio: float = 0.15

@onready var damage_flash: ColorRect = %DamageFlash
@onready var danger_border: Control = %DangerBorder
@onready var danger_warning_label: Label = %DangerWarningLabel
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
var _damage_flash_remaining: float = 0.0
var _damage_flash_strength: float = 0.0
var _danger_active: bool = false
var _danger_pulse_time: float = 0.0


func _ready() -> void:
	damage_flash.color.a = 0.0
	danger_border.hide()
	danger_warning_label.hide()
	set_process(false)


func _process(delta: float) -> void:
	if _damage_flash_remaining > 0.0:
		_damage_flash_remaining = maxf(
			_damage_flash_remaining - delta,
			0.0
		)
		var flash_ratio := (
			_damage_flash_remaining / DAMAGE_FLASH_DURATION
		)
		damage_flash.color.a = (
			pow(flash_ratio, 1.8) * 0.24 * _damage_flash_strength
		)
	else:
		damage_flash.color.a = 0.0

	if _danger_active:
		_danger_pulse_time = fmod(_danger_pulse_time + delta, TAU)
		var pulse := 0.5 + 0.5 * sin(_danger_pulse_time * 4.8)
		danger_border.modulate.a = 0.32 + pulse * 0.5
		danger_warning_label.modulate = Color(
			1.0,
			0.18 + pulse * 0.26,
			0.12,
			0.62 + pulse * 0.38
		)
		danger_warning_label.scale = Vector2.ONE * (0.96 + pulse * 0.08)

	_refresh_processing()


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
	_resources.breakthrough_reward_granted.connect(
		_on_breakthrough_reward_granted
	)
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
	if _player != null and _player.melee_damage_received.is_connected(
		_on_player_damaged
	):
		_player.melee_damage_received.disconnect(_on_player_damaged)
	_player = player
	if _player == null:
		return
	_player.equipment_changed.connect(_on_equipment_changed)
	_player.equipment_inventory_changed.connect(
		_on_equipment_inventory_changed
	)
	_player.weapon_upgrade_changed.connect(_on_weapon_upgrade_changed)
	_player.weapon_power_changed.connect(_on_weapon_power_changed)
	_player.melee_damage_received.connect(_on_player_damaged)
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
	if (
		_resources.breakthrough_reward_granted.is_connected(
			_on_breakthrough_reward_granted
		)
	):
		_resources.breakthrough_reward_granted.disconnect(
			_on_breakthrough_reward_granted
		)
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
		_resources.get_current_qi_requirement()
	)
	_on_cultivation_level_changed(_resources.cultivation_level)


func _on_lifespan_changed(current: float, maximum: float) -> void:
	lifespan_label.text = "寿元  %.1fs / %.1fs" % [current, maximum]
	lifespan_bar.max_value = maximum
	lifespan_bar.value = current
	var lifespan_ratio := (
		current / maximum
		if maximum > 0.0
		else 0.0
	)
	_set_danger_active(
		current > 0.0
		and lifespan_ratio < clampf(danger_lifespan_ratio, 0.01, 0.5)
	)


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


func _on_player_damaged(amount: float) -> void:
	_damage_flash_remaining = DAMAGE_FLASH_DURATION
	_damage_flash_strength = clampf(0.65 + amount / 30.0, 0.65, 1.0)
	_refresh_processing()


func _set_danger_active(active: bool) -> void:
	if _danger_active == active:
		return
	_danger_active = active
	danger_border.visible = active
	danger_warning_label.visible = active
	lifespan_label.modulate = (
		Color(1.0, 0.18, 0.12, 1.0)
		if active
		else Color.WHITE
	)
	lifespan_bar.modulate = (
		Color(1.0, 0.22, 0.16, 1.0)
		if active
		else Color.WHITE
	)
	if not active:
		_danger_pulse_time = 0.0
		danger_border.modulate = Color.WHITE
		danger_warning_label.modulate = Color.WHITE
		danger_warning_label.scale = Vector2.ONE
	_refresh_processing()


func _refresh_processing() -> void:
	set_process(_danger_active or _damage_flash_remaining > 0.0)


## Returns whether the persistent below-threshold lifespan warning is visible.
func is_danger_warning_active() -> bool:
	return _danger_active


## Returns whether the short full-screen direct-damage flash is active.
func is_damage_flash_active() -> bool:
	return _damage_flash_remaining > 0.0


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


func _on_breakthrough_reward_granted(
	_current: float,
	_maximum: float
) -> void:
	level_up_message.text = "渡劫成功\n寿元上限提升"
	level_up_message.show()
	level_up_timer.start()


func _on_level_up_timer_timeout() -> void:
	level_up_message.hide()
