class_name GameplayHud
extends CanvasLayer

signal pause_requested

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
@onready var pause_button: Button = %PauseButton
@onready var detail_shortcut_hint: Label = %DetailShortcutHint
@onready var detail_drawer: PanelContainer = %DetailDrawer
@onready var detail_title_label: Label = %DetailTitleLabel
@onready var detail_hint_label: Label = %DetailHintLabel
@onready var damage_stat_title: Label = %DamageStatTitle
@onready var damage_stat_value: Label = %DamageStatValue
@onready var movement_stat_title: Label = %MovementStatTitle
@onready var movement_stat_value: Label = %MovementStatValue
@onready var range_stat_title: Label = %RangeStatTitle
@onready var range_stat_value: Label = %RangeStatValue
@onready var fragment_section_label: Label = %FragmentSectionLabel
@onready var attack_speed_level_name: Label = %AttackSpeedLevelName
@onready var attack_speed_level_label: Label = %AttackSpeedLevelLabel
@onready var damage_level_name: Label = %DamageLevelName
@onready var damage_level_label: Label = %DamageLevelLabel
@onready var movement_level_name: Label = %MovementLevelName
@onready var movement_level_label: Label = %MovementLevelLabel
@onready var range_level_name: Label = %RangeLevelName
@onready var range_level_label: Label = %RangeLevelLabel
@onready var speed_control_level_name: Label = %SpeedControlLevelName
@onready var speed_control_level_label: Label = %SpeedControlLevelLabel
@onready var danger_border: Control = %DangerBorder
@onready var danger_warning_label: Label = %DangerWarningLabel
@onready var lifespan_label: Label = %LifespanLabel
@onready var lifespan_bar: ProgressBar = %LifespanBar
@onready var lifespan_rate_label: Label = %LifespanRateLabel
@onready var cultivation_label: Label = %CultivationLabel
@onready var realm_progress_bar: RealmProgressBar = %RealmProgressBar
@onready var realm_ability_label: Label = %RealmAbilityLabel
@onready var qi_label: Label = %QiLabel
@onready var qi_bar: ProgressBar = %QiBar
@onready var qi_shield_status_label: Label = %QiShieldStatusLabel
@onready var cultivation_tracks_label: Label = %CultivationTracksLabel
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
@onready var start_prompt_label: Label = %StartPromptLabel
@onready var start_prompt_timer: Timer = %StartPromptTimer
@onready var level_up_message: Label = %LevelUpMessage
@onready var level_up_timer: Timer = %LevelUpTimer
@onready var tribulation_warning_label: Label = %TribulationWarningLabel
@onready var tribulation_warning_timer: Timer = %TribulationWarningTimer
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
var _pending_qi_presentation: Vector2i = Vector2i.ZERO
var _has_pending_qi_presentation: bool = false


func _ready() -> void:
	LanguageManager.language_changed.connect(_on_language_changed)
	pause_button.text = LanguageManager.text("pause")
	detail_shortcut_hint.text = LanguageManager.text(
		"detail_shortcut_hint"
	)
	detail_title_label.text = LanguageManager.text("character_details")
	detail_hint_label.text = LanguageManager.text("release_tab_to_close")
	_localize_detail_stat_titles()
	start_prompt_label.text = LanguageManager.text("start_survival_prompt")
	danger_warning_label.text = LanguageManager.text("danger_lifespan")
	damage_flash.color.a = 0.0
	detail_drawer.hide()
	danger_border.hide()
	danger_warning_label.hide()
	tribulation_warning_label.hide()
	channel_feedback.hide()
	qi_shield_status_label.hide()
	cultivation_tracks_label.hide()
	start_prompt_label.show()
	start_prompt_timer.start()
	realm_progress_bar.infusion_finished.connect(
		_on_realm_infusion_finished
	)
	set_process(false)


func _on_pause_button_pressed() -> void:
	pause_requested.emit()


func _input(event: InputEvent) -> void:
	var is_tab_key := false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		is_tab_key = (
			key_event.keycode == KEY_TAB
			or key_event.physical_keycode == KEY_TAB
		)
	if is_tab_key:
		if event.pressed and not event.is_echo():
			detail_drawer.show()
			detail_shortcut_hint.hide()
		elif not event.pressed:
			detail_drawer.hide()
			detail_shortcut_hint.show()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("show_details"):
		detail_drawer.show()
		detail_shortcut_hint.hide()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("show_details"):
		detail_drawer.hide()
		detail_shortcut_hint.show()
		get_viewport().set_input_as_handled()


func _on_language_changed(_locale: String) -> void:
	pause_button.text = LanguageManager.text("pause")
	detail_shortcut_hint.text = LanguageManager.text(
		"detail_shortcut_hint"
	)
	detail_title_label.text = LanguageManager.text("character_details")
	detail_hint_label.text = LanguageManager.text("release_tab_to_close")
	_localize_detail_stat_titles()
	start_prompt_label.text = LanguageManager.text("start_survival_prompt")
	danger_warning_label.text = LanguageManager.text("danger_lifespan")
	if _resources != null:
		_sync_all()
	if _player != null:
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


func _process(delta: float) -> void:
	_refresh_active_ability_card()
	if detail_drawer.visible:
		_refresh_detail_core_stats()
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
			1.0,
			1.0,
			1.0,
			0.76 + shield_pulse * 0.24
		)
		if _shield_feedback_remaining <= 0.0:
			_update_qi_shield_presentation()

	_update_qi_infusion_opacity()
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
	_resources.breakthrough_pending_changed.connect(
		_on_breakthrough_pending_changed
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
	_player.weapon_power_upgraded.connect(_on_weapon_power_upgraded)
	_player.universal_upgrade_applied.connect(_on_universal_upgrade_applied)
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
	if _resources.breakthrough_pending_changed.is_connected(
		_on_breakthrough_pending_changed
	):
		_resources.breakthrough_pending_changed.disconnect(
			_on_breakthrough_pending_changed
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
	_sync_realm_progress()
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
	lifespan_label.text = LanguageManager.text("lifespan_format") % [
		current,
		maximum,
	]
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
	lifespan_rate_label.text = (
		LanguageManager.text("lifespan_drain_format") % rate_per_second
	)


func _on_qi_changed(current: int, required: int) -> void:
	_current_qi = maxi(current, 0)
	_current_qi_required = maxi(required, 1)
	if realm_progress_bar.is_infusion_active():
		_pending_qi_presentation = Vector2i(
			_current_qi,
			_current_qi_required
		)
		_has_pending_qi_presentation = true
		return
	_apply_qi_presentation(_current_qi, _current_qi_required)
	_update_qi_shield_presentation()


func _on_cultivation_level_changed(level: int) -> void:
	if _resources != null:
		var realm := _resources.get_current_realm_definition()
		cultivation_label.text = LanguageManager.text(
			"realm_layer_format"
		) % [
			LanguageManager.get_realm_name(
				realm.display_name if realm != null else ""
			),
			_resources.get_current_realm_layer(),
			maxi(realm.layer_count, 1) if realm != null else 1,
		]
	else:
		cultivation_label.text = (
			LanguageManager.text("realm_format") % level
		)


func _on_realm_state_changed(
	realm_index: int,
	realm_name: String,
	layer: int,
	layer_count: int
) -> void:
	cultivation_label.text = LanguageManager.text("realm_layer_format") % [
		LanguageManager.get_realm_name(realm_name),
		layer,
		layer_count,
	]
	realm_progress_bar.configure_state(
		realm_index,
		_format_realm_stage_name(realm_name),
		layer,
		layer_count
	)
	if not realm_progress_bar.is_infusion_active():
		_apply_realm_qi_color()


func _sync_realm_progress() -> void:
	if _resources == null:
		return
	var realm := _resources.get_current_realm_definition()
	_on_realm_state_changed(
		_resources.get_current_realm_index(),
		realm.display_name
		if realm != null
		else LanguageManager.text("realm_default"),
		_resources.get_current_realm_layer(),
		maxi(realm.layer_count, 1) if realm != null else 1
	)


func _format_realm_stage_name(realm_name: String) -> String:
	return LanguageManager.text("realm_stage_format") % (
		LanguageManager.get_realm_name(realm_name)
	)


func _get_localized_realm_display_text(level: int = 1) -> String:
	if _resources == null:
		return LanguageManager.text("realm_level_format") % level
	var realm := _resources.get_current_realm_definition()
	if realm == null:
		return LanguageManager.text("realm_level_format") % level
	return LanguageManager.format_realm_display(
		realm.display_name,
		_resources.get_current_realm_layer()
	)


func _apply_qi_presentation(current: int, required: int) -> void:
	qi_bar.max_value = maxi(required, 1)
	qi_bar.value = maxi(current, 0)


func _apply_realm_qi_color() -> void:
	var realm_color := realm_progress_bar.get_current_realm_color()
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = realm_color
	fill_style.corner_radius_top_left = 5
	fill_style.corner_radius_top_right = 5
	fill_style.corner_radius_bottom_right = 5
	fill_style.corner_radius_bottom_left = 5
	fill_style.shadow_color = Color(realm_color, 0.3)
	fill_style.shadow_size = 4
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.015, 0.025, 0.045, 0.46)
	background_style.border_width_left = 1
	background_style.border_width_top = 1
	background_style.border_width_right = 1
	background_style.border_width_bottom = 1
	background_style.border_color = Color(realm_color, 0.48)
	background_style.corner_radius_top_left = 5
	background_style.corner_radius_top_right = 5
	background_style.corner_radius_bottom_right = 5
	background_style.corner_radius_bottom_left = 5
	qi_bar.add_theme_stylebox_override("fill", fill_style)
	qi_bar.add_theme_stylebox_override("background", background_style)


func _update_qi_infusion_opacity() -> void:
	if not realm_progress_bar.is_infusion_active():
		if _shield_feedback_remaining <= 0.0:
			qi_bar.modulate = Color.WHITE
		return
	var progress := realm_progress_bar.get_infusion_progress()
	var gather := clampf(progress / 0.3, 0.0, 1.0)
	gather = gather * gather * (3.0 - 2.0 * gather)
	qi_bar.modulate = Color(1.0, 1.0, 1.0, lerpf(1.0, 0.08, gather))


func _start_qi_infusion() -> void:
	if realm_progress_bar.is_infusion_active():
		return
	qi_bar.max_value = maxi(_current_qi_required, 1)
	qi_bar.value = qi_bar.max_value
	qi_label.text = LanguageManager.text("qi_format") % [
		_current_qi_required,
		_current_qi_required,
	]
	realm_progress_bar.play_qi_infusion()
	_refresh_processing()


func _on_realm_infusion_finished() -> void:
	if _has_pending_qi_presentation:
		_apply_qi_presentation(
			_pending_qi_presentation.x,
			_pending_qi_presentation.y
		)
		_has_pending_qi_presentation = false
	_apply_realm_qi_color()
	_update_qi_shield_presentation()
	qi_bar.modulate = Color.WHITE
	_refresh_processing()


func _on_breakthrough_pending_changed(
	active: bool,
	_fatal: bool
) -> void:
	if active:
		_start_qi_infusion()


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
	var localized_technique := (
		LanguageManager.get_weapon_name(
			_player.starting_weapon_data.weapon_id,
			technique_name
		)
		if _player != null and _player.starting_weapon_data != null
		else technique_name
	)
	var localized_equipment := (
		LanguageManager.get_weapon_name(
			_player.get_current_weapon_data().weapon_id,
			equipment_name
		)
		if _player != null
		else equipment_name
	)
	technique_label.text = (
		LanguageManager.text("technique_format") % localized_technique
	)
	weapon_label.text = LanguageManager.text("equipped_format") % [
		localized_equipment,
		damage,
	]


func _on_combat_stats_changed(
	global_stats: PlayerGlobalCombatStatsResource,
	weapon_stats: WeaponCombatStatsResource
) -> void:
	_refresh_detail_core_stats()
	if global_stats == null or weapon_stats == null:
		player_stats_label.text = LanguageManager.text("player_stats_empty")
		return
	var localized_weapon_name := weapon_stats.display_name
	if _player != null and _player.get_current_weapon_data() != null:
		var current_weapon_data := _player.get_current_weapon_data()
		localized_weapon_name = LanguageManager.get_weapon_name(
			current_weapon_data.weapon_id,
			current_weapon_data.display_name
		)
	var lines: Array[String] = [
		"[b]%s[/b]" % LanguageManager.text("player_stats_title"),
		LanguageManager.text("stats_base_format") % [
			_get_localized_realm_display_text(
				global_stats.overall_cultivation_level
			),
			global_stats.global_damage_bonus,
			_format_percent(global_stats.overall_level_damage_ratio),
			localized_weapon_name,
			_player.get_current_weapon_damage()
			if _player != null
			else weapon_stats.resolved_damage,
		],
		LanguageManager.text("stats_overview_format") % [
			_format_percent(global_stats.critical_chance, false),
			_format_percent(
				global_stats.critical_damage_multiplier,
				false
			),
			_format_percent(global_stats.attack_speed_bonus),
		],
		LanguageManager.text("stats_projectile_format") % [
			global_stats.projectile_speed_multiplier,
			weapon_stats.delivery_count,
			_format_percent(global_stats.aoe_radius_bonus),
			_format_percent(global_stats.targeting_range_bonus),
		],
	]
	if _player != null:
		var levels := _player.get_universal_upgrade_snapshot()
		lines.append(
			LanguageManager.text("stats_fragments_format") % [
				int(levels.get("攻速", 0)),
				int(levels.get("伤害", 0)),
				int(levels.get("身法", 0)),
				int(levels.get("范围", 0)),
				int(levels.get("加减速", 0)),
			]
		)
		lines.append(
			LanguageManager.text("stats_movement_format") % [
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
		or realm_progress_bar.is_infusion_active()
	)


## Returns whether the persistent below-threshold lifespan warning is visible.
func is_danger_warning_active() -> bool:
	return _danger_active


## Returns whether the short full-screen direct-damage flash is active.
func is_damage_flash_active() -> bool:
	return _damage_flash_remaining > 0.0


## Returns whether the hold-to-inspect character drawer is currently visible.
func is_detail_drawer_visible() -> bool:
	return detail_drawer.visible


func _render_equipment_library() -> void:
	equipment_library_label.text = (
		"%s\n%s" % [
			LanguageManager.text("complete_weapon_data"),
			"\n".join(_equipment_entries),
		]
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
			"Q",
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
	palm_weapon_slot.configure(null, 0, "Q", false, false, false)
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
		cultivation_tracks_label.text = LanguageManager.text(
			"fragments_unbound"
		)
		_set_fragment_level_labels({})
		return
	var levels := _player.get_universal_upgrade_snapshot()
	_set_fragment_level_labels(levels)
	cultivation_tracks_label.text = LanguageManager.text(
		"fragments_details_format"
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


func _localize_detail_stat_titles() -> void:
	damage_stat_title.text = LanguageManager.text("detail_current_damage")
	movement_stat_title.text = LanguageManager.text("detail_movement_speed")
	range_stat_title.text = LanguageManager.text("detail_attack_range")
	fragment_section_label.text = LanguageManager.text(
		"detail_upgrade_levels"
	)
	_render_cultivation_tracks()


func _refresh_detail_core_stats() -> void:
	if _player == null:
		damage_stat_value.text = "0"
		movement_stat_value.text = "0"
		range_stat_value.text = "0"
		return
	damage_stat_value.text = str(_player.get_current_weapon_damage())
	movement_stat_value.text = "%.0f" % _player.current_forward_speed
	range_stat_value.text = "%.0f" % _player.get_current_attack_range()


func _set_fragment_level_labels(levels: Dictionary) -> void:
	attack_speed_level_name.text = LanguageManager.text(
		"upgrade_attack_speed"
	)
	damage_level_name.text = LanguageManager.text("upgrade_damage")
	movement_level_name.text = LanguageManager.text("upgrade_mobility")
	range_level_name.text = LanguageManager.text("upgrade_range")
	speed_control_level_name.text = LanguageManager.text(
		"upgrade_speed_control"
	)
	attack_speed_level_label.text = "Lv.%d" % int(levels.get("攻速", 0))
	damage_level_label.text = "Lv.%d" % int(levels.get("伤害", 0))
	movement_level_label.text = "Lv.%d" % int(levels.get("身法", 0))
	range_level_label.text = "Lv.%d" % int(levels.get("范围", 0))
	speed_control_level_label.text = "Lv.%d" % int(
		levels.get("加减速", 0)
	)


func _on_level_up_occurred(level: int, restored_lifespan: float) -> void:
	_start_qi_infusion()
	var realm_text := _get_localized_realm_display_text(level)
	level_up_message.text = LanguageManager.text("level_up_format") % [
		realm_text,
		restored_lifespan,
	]
	level_up_message.show()
	level_up_timer.start()


func _on_realm_ability_state_changed(snapshot: Dictionary) -> void:
	_realm_ability_snapshot = snapshot.duplicate()
	var entries: Array[String] = []
	if StringName(snapshot.get("realm_id", &"")) == &"qi_refining":
		entries.append(LanguageManager.text("ability_roll_summary"))
	var shield_active := bool(snapshot.get("qi_shield_active", false))
	if bool(snapshot.get("temporary_flight_available", false)):
		var flight_phase := StringName(
			snapshot.get("temporary_flight_phase", &"grounded")
		)
		var phase_text: String = str({
			&"ascending": LanguageManager.text("flight_ascending"),
			&"holding": LanguageManager.text("flight_holding"),
			&"descending": LanguageManager.text("flight_descending"),
		}.get(flight_phase, ""))
		entries.append(
			LanguageManager.text("flight_active_format") % phase_text
			if bool(snapshot.get("temporary_flight_active", false))
			else LanguageManager.text("flight_prompt")
		)
	elif float(snapshot.get("flight_height", 0.0)) > 0.0:
		entries.append(LanguageManager.text("flight_permanent"))
	if StringName(snapshot.get("realm_id", &"")) == &"golden_core":
		entries.append(
			LanguageManager.text("shield_active_summary")
			if shield_active
			else LanguageManager.text("shield_prompt")
		)
	if bool(snapshot.get("spirit_projection_available", false)):
		entries.append(
			LanguageManager.text("projection_active_summary")
			if bool(snapshot.get("spirit_projection_active", false))
			else LanguageManager.text("projection_prompt")
		)
	if entries.is_empty():
		entries.append(LanguageManager.text("ability_ground_training"))
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
	var ability_name := LanguageManager.text("ability_unknown")
	var description := LanguageManager.text("ability_unlock_hint")
	var status := LanguageManager.text("status_unavailable")
	match ability_id:
		&"roll":
			ability_name = LanguageManager.text("ability_roll")
			description = LanguageManager.text("ability_roll_description")
			status = (
				LanguageManager.text("status_rolling")
				if is_active
				else (
					LanguageManager.text("cooldown_format") % cooldown_remaining
					if cooldown_remaining > 0.0
					else LanguageManager.text("status_ready")
				)
			)
		&"temporary_flight":
			ability_name = LanguageManager.text("ability_flight")
			description = LanguageManager.text("ability_flight_description")
			var phase := StringName(snapshot.get("phase", &"grounded"))
			status = str({
				&"ascending": LanguageManager.text("status_ascending"),
				&"holding": LanguageManager.text("status_holding"),
				&"descending": LanguageManager.text("status_descending"),
			}.get(phase, LanguageManager.text("status_ready")))
		&"qi_shield":
			ability_name = LanguageManager.text("ability_qi_shield")
			description = LanguageManager.text(
				"ability_qi_shield_description"
			)
			status = (
				LanguageManager.text("status_shield_active")
				if is_active
				else LanguageManager.text("status_shield_inactive")
			)
		&"spirit_projection":
			ability_name = LanguageManager.text(
				"ability_spirit_projection"
			)
			description = LanguageManager.text(
				"ability_spirit_projection_description"
			)
			status = (
				LanguageManager.text("status_projection_active")
				if is_active
				else LanguageManager.text("status_ready")
			)
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
	var shield_available := bool(
		_realm_ability_snapshot.get("qi_shield_enabled", false)
	)
	var shield_active := bool(
		_realm_ability_snapshot.get("qi_shield_active", false)
	)
	if not shield_available:
		qi_label.text = LanguageManager.text("qi_format") % [
			_current_qi,
			_current_qi_required,
		]
		if not realm_progress_bar.is_infusion_active():
			qi_bar.modulate = Color.WHITE
		qi_shield_status_label.hide()
		return
	if not shield_active:
		qi_label.text = LanguageManager.text("qi_format") % [
			_current_qi,
			_current_qi_required,
		]
		if not realm_progress_bar.is_infusion_active():
			qi_bar.modulate = Color.WHITE
		qi_shield_status_label.modulate = Color("9aa8b8")
		qi_shield_status_label.text = (
			LanguageManager.text("shield_off_projection")
			if bool(
				_realm_ability_snapshot.get(
					"spirit_projection_available",
					false
				)
			)
			else LanguageManager.text("shield_off_prompt")
		)
		qi_shield_status_label.show()
		return
	var efficiency := maxf(
		float(
			_realm_ability_snapshot.get("shield_damage_per_qi", 1.0)
		),
		0.01
	)
	var capacity := float(_current_qi) * efficiency
	qi_label.text = LanguageManager.text("qi_shield_capacity_format") % [
		_current_qi,
		_current_qi_required,
		capacity,
	]
	if not realm_progress_bar.is_infusion_active():
		qi_bar.modulate = Color.WHITE
	qi_shield_status_label.show()
	if _shield_feedback_remaining > 0.0:
		return
	qi_shield_status_label.modulate = Color.WHITE
	qi_shield_status_label.text = (
		LanguageManager.text("shield_status_format") % [capacity, efficiency]
		if capacity > 0.0
		else LanguageManager.text("shield_depleted")
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
	qi_shield_status_label.text = LanguageManager.text(
		"shield_absorbed_format"
	) % [blocked_damage, qi_spent, capacity]
	if remaining_damage > 0.0:
		qi_shield_status_label.text += LanguageManager.text(
			"shield_penetrated_format"
		) % remaining_damage
	qi_shield_status_label.show()
	_refresh_processing()


func _on_spirit_projection_changed(active: bool) -> void:
	if _player != null:
		_on_realm_ability_state_changed(
			_player.realm_abilities.get_debug_snapshot()
		)
	level_up_message.text = (
		LanguageManager.text("projection_entered")
		if active
		else LanguageManager.text("projection_returned")
	)
	level_up_message.show()
	level_up_timer.start()


func _on_weapon_power_upgraded(level: int, total_damage_bonus: int) -> void:
	level_up_message.text = LanguageManager.text(
		"damage_upgrade_format"
	) % [
		level,
		total_damage_bonus,
		level,
	]
	level_up_message.show()
	level_up_timer.start()


func _on_universal_upgrade_applied(upgrade_type: int, level: int) -> void:
	if upgrade_type == UniversalUpgradeTypes.UpgradeType.DAMAGE:
		level_up_message.text = LanguageManager.text(
			"damage_upgrade_format"
		) % [
			level,
			level * _player.damage_bonus_per_fragment,
			level,
		]
	else:
		level_up_message.text = LanguageManager.text(
			"generic_upgrade_format"
		) % [
			LanguageManager.get_universal_upgrade_name(upgrade_type),
			level,
		]
	level_up_message.show()
	level_up_timer.start()
	_render_cultivation_tracks()


func _on_breakthrough_reward_granted(
	_current: float,
	_maximum: float
) -> void:
	level_up_message.text = LanguageManager.text("tribulation_success")
	level_up_message.show()
	level_up_timer.start()


## Shows the dedicated two-line realm-advance warning without replacing level
## rewards or the later successful-tribulation message.
func show_tribulation_warning() -> void:
	tribulation_warning_label.text = LanguageManager.text(
		"tribulation_warning"
	)
	tribulation_warning_label.show()
	tribulation_warning_timer.start()


## Returns whether the realm-advance lightning warning is currently visible.
func is_tribulation_warning_active() -> bool:
	return tribulation_warning_label.visible


func _on_level_up_timer_timeout() -> void:
	level_up_message.hide()


func _on_tribulation_warning_timer_timeout() -> void:
	tribulation_warning_label.hide()


func _on_channel_feedback_timer_timeout() -> void:
	channel_feedback.hide()


func _on_start_prompt_timer_timeout() -> void:
	start_prompt_label.hide()
