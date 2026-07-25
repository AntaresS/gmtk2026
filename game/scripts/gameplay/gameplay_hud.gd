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
const WeaponDataResource = preload(
	"res://game/scripts/gameplay/weapon_data.gd"
)
const WeaponSlotIconControl = preload(
	"res://game/scripts/gameplay/weapon_slot_icon.gd"
)
const ActiveAbilityIconControl = preload(
	"res://game/scripts/gameplay/active_ability_icon.gd"
)
const SHIELD_FEEDBACK_DURATION: float = 1.1

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
@onready var realm_ability_label: Label = %RealmAbilityLabel
@onready var qi_label: Label = %QiLabel
@onready var qi_bar: ProgressBar = %QiBar
@onready var qi_shield_status_label: Label = %QiShieldStatusLabel
@onready var cultivation_tracks_label: Label = %CultivationTracksLabel
@onready var echo_status_label: Label = %EchoStatusLabel
@onready var technique_label: Label = %TechniqueLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var player_stats_label: RichTextLabel = %PlayerStatsLabel
@onready var equipment_library_label: Label = %EquipmentLibraryLabel
@onready var palm_weapon_slot: WeaponSlotIconControl = %PalmWeaponSlot
@onready var weapon_slots: Array[WeaponSlotIconControl] = [
	%WeaponSlot1,
	%WeaponSlot2,
	%WeaponSlot3,
	%WeaponSlot4,
	%WeaponSlot5,
	%WeaponSlot6,
]
@onready var active_ability_icon: ActiveAbilityIconControl = (
	%ActiveAbilityIcon
)
@onready var active_ability_name_label: Label = %ActiveAbilityNameLabel
@onready var active_ability_description_label: Label = (
	%ActiveAbilityDescriptionLabel
)
@onready var active_ability_progress: ProgressBar = %ActiveAbilityProgress
@onready var active_ability_status_label: Label = %ActiveAbilityStatusLabel
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
var _weapon_quantities: Dictionary = {}
var _unselected_weapon_ids: Dictionary = {}
var _slot_inventory_initialized: bool = false
var _current_qi: int = 0
var _current_qi_required: int = 1
var _realm_ability_snapshot: Dictionary = {}
var _shield_feedback_remaining: float = 0.0


func _ready() -> void:
	damage_flash.color.a = 0.0
	danger_border.hide()
	danger_warning_label.hide()
	channel_feedback.hide()
	qi_shield_status_label.hide()
	cultivation_tracks_label.show()
	set_process(false)


func _process(delta: float) -> void:
	_refresh_active_ability_card()
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

	if _shield_feedback_remaining > 0.0:
		_shield_feedback_remaining = maxf(
			_shield_feedback_remaining - delta,
			0.0
		)
		var shield_pulse := (
			0.72 + 0.28 * sin(_shield_feedback_remaining * 18.0)
		)
		qi_shield_status_label.modulate = Color(
			0.72,
			0.96,
			1.0,
			shield_pulse
		)
		qi_bar.modulate = Color(
			0.72 + shield_pulse * 0.28,
			0.95,
			1.0,
			1.0
		)
		if _shield_feedback_remaining <= 0.0:
			_update_qi_shield_presentation()

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
	_resources.realm_state_changed.connect(_on_realm_state_changed)
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
	if _player != null and _player.realm_ability_state_changed.is_connected(
		_on_realm_ability_state_changed
	):
		_player.realm_ability_state_changed.disconnect(
			_on_realm_ability_state_changed
		)
	if _player != null and _player.spirit_projection_changed.is_connected(
		_on_spirit_projection_changed
	):
		_player.spirit_projection_changed.disconnect(
			_on_spirit_projection_changed
		)
	if _player != null and _player.spirit_projection_broken.is_connected(
		_on_spirit_projection_broken
	):
		_player.spirit_projection_broken.disconnect(
			_on_spirit_projection_broken
		)
	if _player != null and _player.weapon_power_upgraded.is_connected(
		_on_weapon_power_upgraded
	):
		_player.weapon_power_upgraded.disconnect(
			_on_weapon_power_upgraded
		)
	if _player != null and _player.universal_upgrade_applied.is_connected(
		_on_universal_upgrade_applied
	):
		_player.universal_upgrade_applied.disconnect(
			_on_universal_upgrade_applied
		)
	if _player != null and _player.echo_state_changed.is_connected(
		_on_echo_state_changed
	):
		_player.echo_state_changed.disconnect(_on_echo_state_changed)
	if _player != null and _player.qi_shield_absorbed.is_connected(
		_on_qi_shield_absorbed
	):
		_player.qi_shield_absorbed.disconnect(_on_qi_shield_absorbed)
	_player = player
	_weapon_quantities.clear()
	_unselected_weapon_ids.clear()
	_slot_inventory_initialized = false
	_realm_ability_snapshot.clear()
	_shield_feedback_remaining = 0.0
	if _player == null:
		_clear_weapon_slots()
		_update_qi_shield_presentation()
		return
	_player.equipment_changed.connect(_on_equipment_changed)
	_player.equipment_inventory_changed.connect(
		_on_equipment_inventory_changed
	)
	_player.melee_damage_received.connect(_on_player_damaged)
	_player.combat_stats_changed.connect(_on_combat_stats_changed)
	_player.realm_ability_state_changed.connect(
		_on_realm_ability_state_changed
	)
	_player.spirit_projection_changed.connect(
		_on_spirit_projection_changed
	)
	_player.spirit_projection_broken.connect(_on_spirit_projection_broken)
	_player.weapon_power_upgraded.connect(_on_weapon_power_upgraded)
	_player.universal_upgrade_applied.connect(_on_universal_upgrade_applied)
	_player.echo_state_changed.connect(_on_echo_state_changed)
	_player.qi_shield_absorbed.connect(_on_qi_shield_absorbed)
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
		_player.get_current_equipment_index()
	)
	_on_realm_ability_state_changed(
		_player.realm_abilities.get_debug_snapshot()
	)
	_refresh_active_ability_card()
	_render_cultivation_tracks()
	_refresh_processing()


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
	if _resources.realm_state_changed.is_connected(_on_realm_state_changed):
		_resources.realm_state_changed.disconnect(_on_realm_state_changed)
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
	_current_qi = maxi(current, 0)
	_current_qi_required = maxi(required, 1)
	qi_bar.max_value = required
	qi_bar.value = current
	_update_qi_shield_presentation()


func _on_cultivation_level_changed(level: int) -> void:
	if _resources != null:
		cultivation_label.text = _resources.get_realm_display_text()
	else:
		cultivation_label.text = "境界 %d" % level


func _on_realm_state_changed(
	realm_index: int,
	realm_name: String,
	layer: int,
	layer_count: int
) -> void:
	cultivation_label.text = "%s %d/%d层" % [
		realm_name,
		layer,
		layer_count,
	]
	echo_status_label.visible = realm_index == 2
	if echo_status_label.visible and _player != null:
		_on_echo_state_changed(
			_player.get_active_echo_count(),
			_player.get_echo_cooldown_remaining()
		)


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
		"基础  %s · 全局伤害 +%.1f / +%s · %s伤害 %d" % [
			(
				_resources.get_realm_display_text()
				if _resources != null
				else "境界 Lv.%d" % global_stats.overall_cultivation_level
			),
			global_stats.global_damage_bonus,
			_format_percent(global_stats.overall_level_damage_ratio),
			weapon_stats.display_name,
			_player.get_current_weapon_damage()
			if _player != null
			else weapon_stats.resolved_damage,
		],
		"总览  暴击 %s / %s · 攻速 %s" % [
			_format_percent(global_stats.critical_chance, false),
			_format_percent(
				global_stats.critical_damage_multiplier,
				false
			),
			_format_percent(global_stats.attack_speed_bonus),
		],
		"投射  弹速 ×%.2f · 当前武器 ×%d · 范围 %s · 索敌 %s" % [
			global_stats.projectile_speed_multiplier,
			weapon_stats.delivery_count,
			_format_percent(global_stats.aoe_radius_bonus),
			_format_percent(global_stats.targeting_range_bonus),
		],
	]
	if _player != null:
		var levels := _player.get_universal_upgrade_snapshot()
		lines.append(
			"碎片  攻速 %d · 伤害 %d · 身法 %d · 范围 %d · 加减速 %d"
			% [
				int(levels.get("攻速", 0)),
				int(levels.get("伤害", 0)),
				int(levels.get("身法", 0)),
				int(levels.get("范围", 0)),
				int(levels.get("加减速", 0)),
			]
		)
		lines.append(
			"移动  横向 %.0f · 纵向加速度 %.0f · 减速目标 %.0f"
			% [
				_player.get_effective_lateral_speed(),
				_player.get_effective_forward_acceleration(),
				_player.get_slowed_speed_target(),
			]
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
			]
		CultivationTypesResource.CultivationType.SHEN:
			entries = [
				"范围 %s" % _format_percent(bonuses.aoe_radius_bonus),
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
	current_index: int
) -> void:
	_equipment_entries = entries
	_render_equipment_library()
	_sync_weapon_slots(current_index, _slot_inventory_initialized)
	_slot_inventory_initialized = true


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
	set_process(
		_player != null
		or _danger_active
		or _damage_flash_remaining > 0.0
		or _shield_feedback_remaining > 0.0
	)


## Returns whether the persistent below-threshold lifespan warning is visible.
func is_danger_warning_active() -> bool:
	return _danger_active


## Returns whether the short full-screen direct-damage flash is active.
func is_damage_flash_active() -> bool:
	return _damage_flash_remaining > 0.0


func _render_equipment_library() -> void:
	equipment_library_label.text = (
		"装备库（Tab / 1–6 / ` 切换）\n%s" % "\n".join(_equipment_entries)
	)


func _sync_weapon_slots(
	current_index: int,
	announce_changes: bool
) -> void:
	if _player == null:
		_clear_weapon_slots()
		return
	var snapshots := _player.get_equipment_inventory_snapshot()
	var collectible_snapshots: Array[Dictionary] = []
	var palm_snapshot: Dictionary = {}
	for snapshot in snapshots:
		var weapon_data := snapshot["data"] as WeaponDataResource
		if weapon_data.weapon_id == _player.starting_weapon_data.weapon_id:
			palm_snapshot = snapshot
		else:
			collectible_snapshots.append(snapshot)

	var current_weapon_id := _player.get_current_weapon_data().weapon_id
	if _unselected_weapon_ids.has(current_weapon_id):
		_unselected_weapon_ids.erase(current_weapon_id)

	if not palm_snapshot.is_empty():
		var palm_data := palm_snapshot["data"] as WeaponDataResource
		palm_weapon_slot.configure(
			palm_data,
			int(palm_snapshot["quantity"]),
			"`",
			int(palm_snapshot["inventory_index"]) == current_index,
			not bool(palm_snapshot["available"]),
			false
		)

	for slot_index in weapon_slots.size():
		var slot := weapon_slots[slot_index]
		if slot_index >= collectible_snapshots.size():
			slot.configure(
				null,
				0,
				str(slot_index + 1),
				false,
				false,
				false
			)
			continue
		var snapshot := collectible_snapshots[slot_index]
		var weapon_data := snapshot["data"] as WeaponDataResource
		var weapon_id := weapon_data.weapon_id
		var new_quantity := int(snapshot["quantity"])
		var previous_quantity := int(_weapon_quantities.get(weapon_id, 0))
		if announce_changes and previous_quantity == 0:
			_unselected_weapon_ids[weapon_id] = true
		elif announce_changes and new_quantity > previous_quantity:
			slot.play_power_up()
		_weapon_quantities[weapon_id] = new_quantity
		slot.configure(
			weapon_data,
			new_quantity,
			str(slot_index + 1),
			int(snapshot["inventory_index"]) == current_index,
			not bool(snapshot["available"]),
			_unselected_weapon_ids.has(weapon_id)
		)


func _clear_weapon_slots() -> void:
	palm_weapon_slot.configure(null, 0, "`", false, false, false)
	for slot_index in weapon_slots.size():
		weapon_slots[slot_index].configure(
			null,
			0,
			str(slot_index + 1),
			false,
			false,
			false
		)


## Returns one collectible slot control for focused HUD verification.
func get_weapon_slot_control(slot_index: int) -> WeaponSlotIconControl:
	if slot_index < 0 or slot_index >= weapon_slots.size():
		return null
	return weapon_slots[slot_index]


func _render_cultivation_tracks() -> void:
	if _player == null:
		cultivation_tracks_label.text = "通用碎片：尚未绑定"
		return
	var levels := _player.get_universal_upgrade_snapshot()
	cultivation_tracks_label.text = (
		"通用碎片\n"
		+ "攻速 Lv.%d：每级 +%.0f%%\n"
		+ "伤害 Lv.%d：常规武器 +%d / 乾坤圈弹射 +1\n"
		+ "身法 Lv.%d：横移 +%.0f / 纵向加速度 +%.0f\n"
		+ "范围 Lv.%d：每级全武器 +%.0f%%\n"
		+ "加减速 Lv.%d：加速 +%.0f / 减速目标 -%.0f（最低 %.0f）"
	) % [
		int(levels.get("攻速", 0)),
		_player.attack_speed_bonus_per_fragment * 100.0,
		int(levels.get("伤害", 0)),
		_player.damage_bonus_per_fragment,
		int(levels.get("身法", 0)),
		_player.lateral_speed_per_fragment,
		_player.forward_acceleration_per_fragment,
		int(levels.get("范围", 0)),
		_player.range_bonus_per_fragment * 100.0,
		int(levels.get("加减速", 0)),
		_player.boost_speed_per_control_fragment,
		_player.slow_speed_reduction_per_fragment,
		_player.minimum_controlled_speed,
	]


func _on_level_up_occurred(level: int, restored_lifespan: float) -> void:
	var realm_text := (
		_resources.get_realm_display_text()
		if _resources != null
		else "境界 %d" % level
	)
	level_up_message.text = "%s\n寿元 +%.0f" % [
		realm_text,
		restored_lifespan,
	]
	level_up_message.show()
	level_up_timer.start()


func _on_realm_ability_state_changed(snapshot: Dictionary) -> void:
	_realm_ability_snapshot = snapshot.duplicate()
	var entries: Array[String] = []
	if StringName(snapshot.get("realm_id", &"")) == &"qi_refining":
		entries.append("Space 翻滚无敌 · CD 0.8s")
	if bool(snapshot.get("qi_shield_enabled", false)):
		entries.append("灵气护盾")
	if bool(snapshot.get("temporary_flight_available", false)):
		var flight_phase := StringName(
			snapshot.get("temporary_flight_phase", &"grounded")
		)
		var phase_text: String = str({
			&"ascending": "上升",
			&"holding": "驭空滑行",
			&"descending": "下降",
		}.get(flight_phase, ""))
		entries.append(
			"驭空%s" % phase_text
			if bool(snapshot.get("temporary_flight_active", false))
			else "Space 跃起驭空"
		)
	elif float(snapshot.get("flight_height", 0.0)) > 0.0:
		entries.append("御空飞行")
	if StringName(snapshot.get("realm_id", &"")) == &"golden_core":
		entries.append("Space 双生虚影")
	if bool(snapshot.get("spirit_projection_available", false)):
		entries.append(
			"灵体出窍 ×2 [Space]"
			if bool(snapshot.get("spirit_projection_active", false))
			else "Space 灵体出窍"
		)
	if entries.is_empty():
		entries.append("地上修行")
	realm_ability_label.text = " · ".join(entries)
	_update_qi_shield_presentation()
	_refresh_active_ability_card()


func _refresh_active_ability_card() -> void:
	if _player == null:
		return
	var snapshot := _player.get_active_ability_snapshot()
	var ability_id := StringName(snapshot.get("ability_id", &"none"))
	var is_active := bool(snapshot.get("active", false))
	var is_ready := bool(snapshot.get("ready", false))
	var progress := float(snapshot.get("progress", 0.0))
	var cooldown_remaining := float(
		snapshot.get("cooldown_remaining", 0.0)
	)
	var ability_name := "尚未领悟"
	var description := "突破境界后解锁主动能力"
	var status := "不可用"
	match ability_id:
		&"roll":
			ability_name = "翻滚无敌"
			description = "向前翻滚并短暂无视伤害"
			status = (
				"翻滚中"
				if is_active
				else (
					"冷却 %.1fs" % cooldown_remaining
					if cooldown_remaining > 0.0
					else "可用"
				)
			)
		&"temporary_flight":
			ability_name = "跃起驭空"
			description = "短暂升空，避开地面威胁"
			var phase := StringName(snapshot.get("phase", &"grounded"))
			status = str({
				&"ascending": "正在上升",
				&"holding": "驭空滑行",
				&"descending": "正在落地",
			}.get(phase, "可用"))
		&"golden_core_echoes":
			ability_name = "双生虚影"
			description = "召唤两道继承属性的战斗虚影"
			var echo_count := int(snapshot.get("active_count", 0))
			status = (
				"虚影战斗中 %d/2" % echo_count
				if echo_count > 0
				else (
					"冷却 %.1fs" % cooldown_remaining
					if cooldown_remaining > 0.0
					else "可用"
				)
			)
		&"spirit_projection":
			ability_name = "灵体出窍"
			description = "切换灵体姿态，伤害提升至 200%"
			status = "灵体已出窍 · 再按收回" if is_active else "可用"
	active_ability_name_label.text = ability_name
	active_ability_description_label.text = description
	active_ability_status_label.text = status
	active_ability_status_label.modulate = (
		Color("8fffd6")
		if is_ready
		else Color("72e8ff") if is_active else Color("ffd35a")
	)
	active_ability_progress.value = clampf(progress, 0.0, 1.0)
	active_ability_progress.modulate = (
		Color("8fffd6")
		if is_ready
		else Color("72e8ff") if is_active else Color("ffd35a")
	)
	active_ability_icon.configure(
		ability_id,
		is_active,
		is_ready,
		progress
	)


func _update_qi_shield_presentation() -> void:
	var shield_enabled := bool(
		_realm_ability_snapshot.get("qi_shield_enabled", false)
	)
	if not shield_enabled:
		qi_label.text = "灵气  %d / %d" % [
			_current_qi,
			_current_qi_required,
		]
		qi_bar.modulate = Color.WHITE
		qi_shield_status_label.hide()
		return
	var efficiency := maxf(
		float(
			_realm_ability_snapshot.get("shield_damage_per_qi", 1.0)
		),
		0.01
	)
	var capacity := float(_current_qi) * efficiency
	qi_label.text = "灵气  %d / %d  ·  灵盾 %.0f" % [
		_current_qi,
		_current_qi_required,
		capacity,
	]
	qi_bar.modulate = Color("72e8ff")
	qi_shield_status_label.show()
	if _shield_feedback_remaining > 0.0:
		return
	qi_shield_status_label.modulate = Color.WHITE
	qi_shield_status_label.text = (
		"◉ 灵气护盾  %.0f 点  ·  1 灵气抵挡 %.1f 伤害"
		% [capacity, efficiency]
		if capacity > 0.0
		else "◇ 灵气护盾耗尽  ·  收集灵气即可恢复"
	)


func _on_qi_shield_absorbed(
	blocked_damage: float,
	qi_spent: int,
	remaining_damage: float
) -> void:
	_shield_feedback_remaining = SHIELD_FEEDBACK_DURATION
	var capacity := (
		_player.get_qi_shield_capacity()
		if _player != null
		else 0.0
	)
	qi_shield_status_label.text = (
		"护盾吸收 %.0f  ·  消耗 %d 灵气  ·  剩余 %.0f"
		% [blocked_damage, qi_spent, capacity]
	)
	if remaining_damage > 0.0:
		qi_shield_status_label.text += "  ·  穿透 %.1f" % remaining_damage
	qi_shield_status_label.show()
	_refresh_processing()


func _on_spirit_projection_changed(active: bool) -> void:
	if _player != null:
		_on_realm_ability_state_changed(
			_player.realm_abilities.get_debug_snapshot()
		)
	level_up_message.text = (
		"灵体出窍\n威力提升至 200%"
		if active
		else "灵体归窍"
	)
	level_up_message.show()
	level_up_timer.start()


func _on_spirit_projection_broken() -> void:
	level_up_message.text = "灵体受创\n境界跌落至金丹九层"
	level_up_message.show()
	level_up_timer.start()


func _on_weapon_power_upgraded(level: int, total_damage_bonus: int) -> void:
	level_up_message.text = (
		"伤害强化 %d级\n常规武器伤害 +%d · 乾坤圈弹射 +%d"
	) % [
		level,
		total_damage_bonus,
		level,
	]
	level_up_message.show()
	level_up_timer.start()


func _on_universal_upgrade_applied(upgrade_type: int, level: int) -> void:
	if upgrade_type == UniversalUpgradeTypes.UpgradeType.DAMAGE:
		level_up_message.text = (
			"伤害强化 %d级\n常规武器伤害 +%d · 乾坤圈弹射 +%d"
			% [
				level,
				level * _player.damage_bonus_per_fragment,
				level,
			]
		)
	else:
		level_up_message.text = "%s强化 %d级\n全局生效" % [
			UniversalUpgradeTypes.get_display_name(upgrade_type),
			level,
		]
	level_up_message.show()
	level_up_timer.start()
	_render_cultivation_tracks()


func _on_echo_state_changed(
	active_count: int,
	cooldown_remaining: float
) -> void:
	echo_status_label.visible = (
		_player != null
		and _resources != null
		and _resources.get_current_realm_index() == 2
	)
	if not echo_status_label.visible:
		return
	if active_count > 0:
		echo_status_label.text = "金丹虚影：%d/2 战斗中" % active_count
	elif cooldown_remaining > 0.0:
		echo_status_label.text = (
			"金丹虚影：%.1fs\n加速时连按 Space 可缩短冷却"
			% cooldown_remaining
		)
	else:
		echo_status_label.text = "金丹虚影：可按 Space 召唤"


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
