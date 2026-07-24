class_name GameplayHud
extends CanvasLayer

const DAMAGE_FLASH_DURATION: float = 0.38
const CultivationTypesResource = preload(
	"res://game/scripts/gameplay/cultivation_types.gd"
)
const CultivationBonusStatsResource = preload(
	"res://game/scripts/gameplay/cultivation_bonus_stats.gd"
)
const PlayerGlobalCombatStatsResource = preload(
	"res://game/scripts/gameplay/player_global_combat_stats.gd"
)
const WeaponCombatStatsResource = preload(
	"res://game/scripts/gameplay/weapon_combat_stats.gd"
)

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
@onready var cultivation_tracks_label: Label = %CultivationTracksLabel
@onready var technique_label: Label = %TechniqueLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var player_stats_label: RichTextLabel = %PlayerStatsLabel
@onready var equipment_library_label: Label = %EquipmentLibraryLabel
@onready var level_up_message: Label = %LevelUpMessage
@onready var level_up_timer: Timer = %LevelUpTimer
@onready var channel_feedback: VBoxContainer = %ChannelFeedback
@onready var channel_label: Label = %ChannelLabel
@onready var channel_progress: ProgressBar = %ChannelProgress
@onready var channel_feedback_timer: Timer = %ChannelFeedbackTimer

var _resources: RunResources
var _player: PlayerController
var _equipment_entries: Array[String] = []
var _damage_flash_remaining: float = 0.0
var _damage_flash_strength: float = 0.0
var _danger_active: bool = false
var _danger_pulse_time: float = 0.0
var _cultivation_levels: Array[int] = [0, 0, 0]
var _cultivation_fragments: Array[int] = [0, 0, 0]
var _cultivation_required: int = 3


func _ready() -> void:
	damage_flash.color.a = 0.0
	danger_border.hide()
	danger_warning_label.hide()
	channel_feedback.hide()
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
	_resources.cultivation_fragment_progress_changed.connect(
		_on_cultivation_fragment_progress_changed
	)
	_resources.cultivation_type_level_changed.connect(
		_on_cultivation_type_level_changed
	)
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
	if _player != null and _player.melee_damage_received.is_connected(
		_on_player_damaged
	):
		_player.melee_damage_received.disconnect(_on_player_damaged)
	if _player != null and _player.combat_stats_changed.is_connected(
		_on_combat_stats_changed
	):
		_player.combat_stats_changed.disconnect(_on_combat_stats_changed)
	_player = player
	if _player == null:
		return
	_player.equipment_changed.connect(_on_equipment_changed)
	_player.equipment_inventory_changed.connect(
		_on_equipment_inventory_changed
	)
	_player.melee_damage_received.connect(_on_player_damaged)
	_player.combat_stats_changed.connect(_on_combat_stats_changed)
	_on_equipment_changed(
		_player.get_technique_name(),
		_player.get_weapon_name(),
		_player.get_current_weapon_damage()
	)
	_on_combat_stats_changed(
		_player.get_global_combat_stats(),
		_player.get_current_weapon_combat_stats()
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
	if _resources.cultivation_fragment_progress_changed.is_connected(
		_on_cultivation_fragment_progress_changed
	):
		_resources.cultivation_fragment_progress_changed.disconnect(
			_on_cultivation_fragment_progress_changed
		)
	if _resources.cultivation_type_level_changed.is_connected(
		_on_cultivation_type_level_changed
	):
		_resources.cultivation_type_level_changed.disconnect(
			_on_cultivation_type_level_changed
		)
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
	_cultivation_required = _resources.get_cultivation_fragments_required()
	for cultivation_type in CultivationTypesResource.ORDER:
		_cultivation_levels[cultivation_type] = (
			_resources.get_cultivation_level(cultivation_type)
		)
		_cultivation_fragments[cultivation_type] = (
			_resources.get_cultivation_fragments(cultivation_type)
		)
	_render_cultivation_tracks()


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


func _on_cultivation_fragment_progress_changed(
	cultivation_type: int,
	current: int,
	required: int
) -> void:
	if not CultivationTypesResource.is_valid_type(cultivation_type):
		return
	_cultivation_fragments[cultivation_type] = maxi(current, 0)
	_cultivation_required = maxi(required, 1)
	_render_cultivation_tracks()


func _on_cultivation_type_level_changed(
	cultivation_type: int,
	level: int,
	reward_name: String
) -> void:
	if not CultivationTypesResource.is_valid_type(cultivation_type):
		return
	_cultivation_levels[cultivation_type] = maxi(level, 0)
	_render_cultivation_tracks()
	level_up_message.text = "%s Lv.%d\n%s" % [
		CultivationTypesResource.get_name_zh(cultivation_type),
		level,
		reward_name,
	]
	level_up_message.show()
	level_up_timer.start()


## Receives routed pickup-channel state without holding a direct fragment
## reference. Cancellation remains visible briefly as explicit feedback.
func on_cultivation_channel_changed(
	cultivation_type: int,
	progress: float,
	active: bool,
	cancelled: bool
) -> void:
	var type_name := CultivationTypesResource.get_name_zh(cultivation_type)
	if cancelled:
		channel_label.text = "%s之碎片 · 引导中断" % type_name
		channel_progress.value = 0.0
		channel_feedback.show()
		channel_feedback_timer.start()
		return
	channel_feedback_timer.stop()
	if not active:
		channel_feedback.hide()
		return
	channel_label.text = "%s之碎片 · 引导中" % type_name
	channel_progress.value = clampf(progress, 0.0, 1.0)
	channel_feedback.show()


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


func _on_combat_stats_changed(
	global_stats: PlayerGlobalCombatStatsResource,
	weapon_stats: WeaponCombatStatsResource
) -> void:
	if global_stats == null or weapon_stats == null:
		player_stats_label.text = "角色属性\n暂无战斗数据"
		return
	var lines: Array[String] = [
		"[b]角色属性[/b]",
		"基础  练气 Lv.%d · 全局伤害 +%.1f · %s伤害 %d" % [
			global_stats.overall_cultivation_level,
			global_stats.global_damage_bonus,
			weapon_stats.display_name,
			weapon_stats.resolved_damage,
		],
		"总览  暴击 %s / %s · 攻速 %s" % [
			_format_percent(global_stats.critical_chance, false),
			_format_percent(
				global_stats.critical_damage_multiplier,
				false
			),
			_format_percent(global_stats.attack_speed_bonus),
		],
		"投射  弹速 ×%.2f · 御器 +%d · 范围 %s · 索敌 %s" % [
			global_stats.projectile_speed_multiplier,
			global_stats.delivery_count_bonus,
			_format_percent(global_stats.aoe_radius_bonus),
			_format_percent(global_stats.targeting_range_bonus),
		],
	]
	for cultivation_type in CultivationTypesResource.ORDER:
		lines.append(
			_render_cultivation_bonus_line(
				cultivation_type,
				global_stats.get_cultivation_bonuses(cultivation_type),
				weapon_stats
			)
		)
	player_stats_label.text = "\n".join(lines)


func _render_cultivation_bonus_line(
	cultivation_type: int,
	bonuses: CultivationBonusStatsResource,
	weapon_stats: WeaponCombatStatsResource
) -> String:
	var entries: Array[String] = []
	match cultivation_type:
		CultivationTypesResource.CultivationType.JING:
			entries = [
				"暴击 %s" % _format_percent(bonuses.critical_chance),
				"暴伤 %s" % _format_percent(
					bonuses.critical_damage_bonus
				),
				"近减 %s" % _format_percent(
					bonuses.close_range_damage_reduction
				),
			]
		CultivationTypesResource.CultivationType.QI:
			entries = [
				"攻速 %s" % _format_percent(bonuses.attack_speed_bonus),
				"弹速 %s" % _format_percent(
					bonuses.projectile_speed_bonus
				),
				"御器 +%d" % bonuses.delivery_count_bonus,
			]
		CultivationTypesResource.CultivationType.SHEN:
			entries = [
				"范围 %s" % _format_percent(bonuses.aoe_radius_bonus),
				"御器 +%d" % bonuses.delivery_count_bonus,
				"索敌 %s" % _format_percent(
					bonuses.targeting_range_bonus
				),
			]
	if (
		weapon_stats != null
		and cultivation_type in weapon_stats.cultivation_types
	):
		entries.append(
			"同源伤害 %s" % _format_percent(
				weapon_stats.matching_damage_bonus
			)
		)
	var color := _get_cultivation_color(cultivation_type)
	return "[color=#%s]%s  %s[/color]" % [
		color.to_html(false),
		CultivationTypesResource.get_name_zh(cultivation_type),
		" · ".join(entries),
	]


func _get_cultivation_color(cultivation_type: int) -> Color:
	if _resources != null and _resources.cultivation_config != null:
		var type_config := (
			_resources.cultivation_config.get_type_config(cultivation_type)
		)
		if type_config != null:
			return type_config.display_color
	match cultivation_type:
		CultivationTypesResource.CultivationType.JING:
			return Color("ff7d40")
		CultivationTypesResource.CultivationType.QI:
			return Color("38d1ff")
		CultivationTypesResource.CultivationType.SHEN:
			return Color("c763ff")
	return Color.WHITE


func _format_percent(value: float, include_sign: bool = true) -> String:
	var percentage := value * 100.0
	var formatted := (
		"%.0f%%" % percentage
		if is_equal_approx(percentage, roundf(percentage))
		else "%.1f%%" % percentage
	)
	return "+%s" % formatted if include_sign else formatted


func _on_equipment_inventory_changed(
	entries: Array[String],
	_current_index: int
) -> void:
	_equipment_entries = entries
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
		"装备库（Tab 切换）\n%s" % "\n".join(_equipment_entries)
	)


func _render_cultivation_tracks() -> void:
	var lines: Array[String] = []
	for cultivation_type in CultivationTypesResource.ORDER:
		lines.append("%s Lv.%d  %d/%d" % [
			CultivationTypesResource.get_name_zh(cultivation_type),
			_cultivation_levels[cultivation_type],
			_cultivation_fragments[cultivation_type],
			_cultivation_required,
		])
	cultivation_tracks_label.text = "\n".join(lines)


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


func _on_channel_feedback_timer_timeout() -> void:
	channel_feedback.hide()
