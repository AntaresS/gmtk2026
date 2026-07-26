extends CanvasLayer

const DEBUG_UNLOCK_SEQUENCE := [
	KEY_UP,
	KEY_UP,
	KEY_DOWN,
	KEY_DOWN,
	KEY_LEFT,
	KEY_LEFT,
	KEY_RIGHT,
	KEY_RIGHT,
	KEY_B,
	KEY_A,
	KEY_B,
	KEY_A,
]

## Main-menu scene opened by Return to Main Menu. The tree is unpaused before
## this scene is loaded.
@export_file("*.tscn") var main_menu_scene_path: String = (
	"res://game/scenes/menus/main_menu.tscn"
)

@onready var resume_button: Button = %ResumeButton
@onready var title_label: Label = %Title
@onready var instructions_button: Button = %InstructionsButton
@onready var gallery_button: Button = %WeaponGalleryButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var language_label: Label = %LanguageLabel
@onready var language_option: OptionButton = %LanguageOption
@onready var game_info_overlay: GameInfoOverlay = %GameInfoOverlay
@onready var debug_panel: PanelContainer = %DebugPanel
@onready var debug_status: Label = %DebugStatus
@onready var palm_geometry_check: CheckButton = %PalmGeometryCheck
@onready var weapon_option: OptionButton = %WeaponOption
@onready var fragment_option: OptionButton = %FragmentOption
@onready var base_speed_spin: SpinBox = %BaseSpeedSpin
@onready var lateral_speed_spin: SpinBox = %LateralSpeedSpin
@onready var acceleration_spin: SpinBox = %AccelerationSpin
@onready var debug_title: Label = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/DebugTitle
)
@onready var debug_palm_geometry: CheckButton = %PalmGeometryCheck
@onready var debug_add_qi: Button = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/ProgressButtons/AddQi
)
@onready var debug_add_level: Button = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/ProgressButtons/LevelUp
)
@onready var debug_lifespan_add: Button = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/LifespanButtons/AddLifespan
)
@onready var debug_lifespan_remove: Button = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/LifespanButtons/RemoveLifespan
)
@onready var debug_weapon_label: Label = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/WeaponLabel
)
@onready var debug_add_weapon: Button = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/WeaponButtons/AddWeapon
)
@onready var debug_remove_weapon: Button = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/WeaponButtons/RemoveWeapon
)
@onready var debug_damage_add: Button = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/WeaponButtons/AddDamage
)
@onready var debug_damage_remove: Button = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/WeaponButtons/RemoveDamage
)
@onready var debug_fragment_label: Label = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/FragmentLabel
)
@onready var debug_add_fragment: Button = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/FragmentButtons/AddFragment
)
@onready var debug_remove_fragment: Button = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/FragmentButtons/RemoveFragment
)
@onready var debug_base_stats_label: Label = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/BaseStatsLabel
)
@onready var debug_apply_stats: Button = (
	$Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/ApplyBaseStats
)

var _pause_enabled: bool = true
var _syncing_language_option: bool = false
var _debug_unlock_index: int = 0
var _debug_player: PlayerController
var _debug_resources: RunResources
var _debug_weapons: Array[WeaponData] = [
	preload("res://game/resources/great_strength_palm.tres"),
	preload("res://game/resources/weapon/dao.tres"),
	preload("res://game/resources/weapon/flying_sword.tres"),
	preload("res://game/resources/weapon/qiankun_ring.tres"),
	preload("res://game/resources/weapon/golden_bell.tres"),
	preload("res://game/resources/weapon/thunder_hammer.tres"),
	preload("res://game/resources/weapon/fantian_seal.tres"),
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_enabled = true
	language_option.add_item(LanguageManager.text("chinese"))
	language_option.add_item(LanguageManager.text("english"))
	LanguageManager.language_changed.connect(_on_language_changed)
	game_info_overlay.closed.connect(_on_info_overlay_closed)
	for weapon in _debug_weapons:
		weapon_option.add_item(
			LanguageManager.get_weapon_name(
				weapon.weapon_id,
				weapon.display_name
			)
		)
	for upgrade_type in UniversalUpgradeTypes.COUNT:
		fragment_option.add_item(
			UniversalUpgradeTypes.get_display_name(upgrade_type)
		)
	_refresh_language()
	debug_panel.hide()
	hide()


func _input(event: InputEvent) -> void:
	if (
		not _pause_enabled
		or not visible
		or not get_tree().paused
		or game_info_overlay.visible
		or debug_panel.visible
		or not (event is InputEventKey)
	):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.is_echo():
		return
	var pressed_key := key_event.keycode
	if pressed_key == KEY_NONE:
		pressed_key = key_event.physical_keycode
	if pressed_key == DEBUG_UNLOCK_SEQUENCE[_debug_unlock_index]:
		_debug_unlock_index += 1
	else:
		_debug_unlock_index = (
			1 if pressed_key == DEBUG_UNLOCK_SEQUENCE[0] else 0
		)
	if _debug_unlock_index < DEBUG_UNLOCK_SEQUENCE.size():
		return
	_debug_unlock_index = 0
	debug_panel.show()
	_refresh_debug_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not _pause_enabled:
		return
	if not event.is_action_pressed("pause") or event.is_echo():
		return
	if game_info_overlay.visible:
		return

	if get_tree().paused:
		resume_game()
	else:
		pause_game()
	get_viewport().set_input_as_handled()


func pause_game() -> void:
	if not _pause_enabled:
		return
	_debug_unlock_index = 0
	debug_panel.hide()
	show()
	get_tree().paused = true
	resume_button.grab_focus()
	_refresh_debug_panel()


func resume_game() -> void:
	_debug_unlock_index = 0
	debug_panel.hide()
	get_tree().paused = false
	hide()


## Enables normal pause input or dismisses and locks the pause menu. The
## gameplay controller locks pausing after run depletion.
func set_pause_enabled(enabled: bool) -> void:
	_pause_enabled = enabled
	if not _pause_enabled:
		_debug_unlock_index = 0
		debug_panel.hide()
		get_tree().paused = false
		hide()


## Returns whether the pause-only debug controls have been unlocked.
func is_debug_panel_visible() -> bool:
	return debug_panel.visible


func _on_resume_pressed() -> void:
	resume_game()


func _on_instructions_pressed() -> void:
	game_info_overlay.open_instructions()


func _on_weapon_gallery_pressed() -> void:
	game_info_overlay.open_weapon_gallery()


func _on_language_selected(index: int) -> void:
	if _syncing_language_option:
		return
	LanguageManager.set_locale(
		LanguageManager.SUPPORTED_LOCALES[
			clampi(index, 0, LanguageManager.SUPPORTED_LOCALES.size() - 1)
		]
	)


func _on_language_changed(_locale: String) -> void:
	_refresh_language()


func _on_info_overlay_closed() -> void:
	resume_button.grab_focus()


func _refresh_language() -> void:
	title_label.text = LanguageManager.text("paused")
	resume_button.text = LanguageManager.text("resume")
	instructions_button.text = LanguageManager.text("quick_start")
	gallery_button.text = LanguageManager.text("weapon_gallery")
	main_menu_button.text = LanguageManager.text("main_menu")
	language_label.text = LanguageManager.text("language")
	_syncing_language_option = true
	language_option.select(LanguageManager.get_locale_index())
	_syncing_language_option = false
	var selected_weapon := weapon_option.selected
	weapon_option.clear()
	for weapon in _debug_weapons:
		weapon_option.add_item(
			LanguageManager.get_weapon_name(
				weapon.weapon_id,
				weapon.display_name
			)
		)
	if weapon_option.item_count > 0:
		weapon_option.select(clampi(selected_weapon, 0, weapon_option.item_count - 1))
	var selected_fragment := fragment_option.selected
	fragment_option.clear()
	for upgrade_type in UniversalUpgradeTypes.COUNT:
		fragment_option.add_item(
			LanguageManager.get_universal_upgrade_name(upgrade_type)
		)
	if fragment_option.item_count > 0:
		fragment_option.select(
			clampi(selected_fragment, 0, fragment_option.item_count - 1)
		)
	debug_title.text = LanguageManager.text("debug_title")
	debug_palm_geometry.text = LanguageManager.text("debug_palm_geometry")
	debug_add_qi.text = LanguageManager.text("debug_add_qi")
	debug_add_level.text = LanguageManager.text("debug_add_level")
	debug_lifespan_add.text = LanguageManager.text("debug_lifespan_add")
	debug_lifespan_remove.text = LanguageManager.text(
		"debug_lifespan_remove"
	)
	debug_weapon_label.text = LanguageManager.text("debug_weapon_count")
	debug_add_weapon.text = LanguageManager.text("debug_add_weapon")
	debug_remove_weapon.text = LanguageManager.text("debug_remove_weapon")
	debug_damage_add.text = LanguageManager.text("debug_damage_add")
	debug_damage_remove.text = LanguageManager.text("debug_damage_remove")
	debug_fragment_label.text = LanguageManager.text(
		"debug_fragment_levels"
	)
	debug_add_fragment.text = LanguageManager.text("debug_add_fragment")
	debug_remove_fragment.text = LanguageManager.text(
		"debug_remove_fragment"
	)
	debug_base_stats_label.text = LanguageManager.text("debug_base_stats")
	base_speed_spin.prefix = LanguageManager.text("debug_forward_speed")
	lateral_speed_spin.prefix = LanguageManager.text("debug_lateral_speed")
	acceleration_spin.prefix = LanguageManager.text("debug_acceleration")
	debug_apply_stats.text = LanguageManager.text("debug_apply_stats")
	_refresh_debug_panel()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(main_menu_scene_path)
	if error != OK:
		push_error("Could not open main menu scene: %s" % error_string(error))


## Supplies the pause-only debug panel with explicit mutation targets.
func bind_debug_targets(
	player: PlayerController,
	resources: RunResources
) -> void:
	_debug_player = player
	_debug_resources = resources
	if is_instance_valid(_debug_player):
		base_speed_spin.value = _debug_player.base_forward_speed
		lateral_speed_spin.value = _debug_player.lateral_speed
		acceleration_spin.value = _debug_player.forward_acceleration
		palm_geometry_check.button_pressed = (
			_debug_player.is_palm_debug_geometry_visible()
		)
	_refresh_debug_panel()


func _refresh_debug_panel() -> void:
	if not is_instance_valid(_debug_player) or not is_instance_valid(_debug_resources):
		debug_status.text = LanguageManager.text("debug_waiting")
		return
	var realm := _debug_resources.get_current_realm_definition()
	var realm_text := (
		LanguageManager.format_realm_display(
			realm.display_name,
			_debug_resources.get_current_realm_layer()
		)
		if realm != null
		else (
			LanguageManager.text("realm_level_format")
			% _debug_resources.cultivation_level
		)
	)
	var upgrade_levels := _debug_player.get_universal_upgrade_snapshot()
	var localized_upgrades: Array[String] = []
	for upgrade_type in UniversalUpgradeTypes.COUNT:
		localized_upgrades.append(
			"%s %d" % [
				LanguageManager.get_universal_upgrade_name(upgrade_type),
				int(
					upgrade_levels.get(
						UniversalUpgradeTypes.get_display_name(upgrade_type),
						0
					)
				),
			]
		)
	var current_weapon := _debug_player.get_current_weapon_data()
	var localized_weapon_name := (
		LanguageManager.get_weapon_name(
			current_weapon.weapon_id,
			current_weapon.display_name
		)
		if current_weapon != null
		else _debug_player.get_weapon_name()
	)
	debug_status.text = LanguageManager.text("debug_status_format") % [
		realm_text,
		_debug_resources.current_qi,
		_debug_resources.get_current_qi_requirement(),
		_debug_resources.current_lifespan,
		localized_weapon_name,
		_debug_player.get_current_delivery_count(),
		_debug_player.get_current_weapon_damage(),
		", ".join(localized_upgrades),
	]


func _on_debug_add_qi_pressed() -> void:
	_debug_resources.add_qi(_debug_resources.get_current_qi_requirement())
	_refresh_debug_panel()


func _on_debug_level_pressed() -> void:
	_debug_resources.level_up()
	_refresh_debug_panel()


func _on_debug_lifespan_add_pressed() -> void:
	_debug_resources.restore_lifespan(20.0)
	_refresh_debug_panel()


func _on_debug_lifespan_remove_pressed() -> void:
	_debug_resources.apply_lifespan_damage(20.0)
	_refresh_debug_panel()


func _on_palm_geometry_toggled(enabled: bool) -> void:
	if not is_instance_valid(_debug_player):
		return
	_debug_player.debug_set_palm_geometry_visible(enabled)


func _on_debug_weapon_add_pressed() -> void:
	_debug_player.debug_adjust_weapon(
		_debug_weapons[weapon_option.selected],
		1
	)
	_refresh_debug_panel()


func _on_debug_weapon_remove_pressed() -> void:
	_debug_player.debug_adjust_weapon(
		_debug_weapons[weapon_option.selected],
		-1
	)
	_refresh_debug_panel()


func _on_debug_fragment_add_pressed() -> void:
	_debug_player.debug_adjust_universal_upgrade(
		fragment_option.selected,
		1
	)
	_refresh_debug_panel()


func _on_debug_fragment_remove_pressed() -> void:
	_debug_player.debug_adjust_universal_upgrade(
		fragment_option.selected,
		-1
	)
	_refresh_debug_panel()


func _on_debug_damage_add_pressed() -> void:
	_debug_player.debug_adjust_current_weapon_damage(1)
	_refresh_debug_panel()


func _on_debug_damage_remove_pressed() -> void:
	_debug_player.debug_adjust_current_weapon_damage(-1)
	_refresh_debug_panel()


func _on_debug_apply_base_pressed() -> void:
	_debug_player.base_forward_speed = float(base_speed_spin.value)
	_debug_player.lateral_speed = float(lateral_speed_spin.value)
	_debug_player.forward_acceleration = float(acceleration_spin.value)
	_refresh_debug_panel()
