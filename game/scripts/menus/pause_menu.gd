extends CanvasLayer

## Main-menu scene opened by Return to Main Menu. The tree is unpaused before
## this scene is loaded.
@export_file("*.tscn") var main_menu_scene_path: String = (
	"res://game/scenes/menus/main_menu.tscn"
)

@onready var resume_button: Button = %ResumeButton
@onready var debug_status: Label = %DebugStatus
@onready var palm_geometry_check: CheckButton = %PalmGeometryCheck
@onready var weapon_option: OptionButton = %WeaponOption
@onready var fragment_option: OptionButton = %FragmentOption
@onready var base_speed_spin: SpinBox = %BaseSpeedSpin
@onready var lateral_speed_spin: SpinBox = %LateralSpeedSpin
@onready var acceleration_spin: SpinBox = %AccelerationSpin

var _pause_enabled: bool = true
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
	for weapon in _debug_weapons:
		weapon_option.add_item(weapon.display_name)
	for upgrade_type in UniversalUpgradeTypes.COUNT:
		fragment_option.add_item(
			UniversalUpgradeTypes.get_display_name(upgrade_type)
		)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _pause_enabled:
		return
	if not event.is_action_pressed("pause") or event.is_echo():
		return

	if get_tree().paused:
		resume_game()
	else:
		pause_game()
	get_viewport().set_input_as_handled()


func pause_game() -> void:
	if not _pause_enabled:
		return
	show()
	get_tree().paused = true
	resume_button.grab_focus()
	_refresh_debug_panel()


func resume_game() -> void:
	get_tree().paused = false
	hide()


## Enables normal pause input or dismisses and locks the pause menu. The
## gameplay controller locks pausing after run depletion.
func set_pause_enabled(enabled: bool) -> void:
	_pause_enabled = enabled
	if not _pause_enabled:
		get_tree().paused = false
		hide()


func _on_resume_pressed() -> void:
	resume_game()


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
		debug_status.text = "等待游戏状态"
		return
	debug_status.text = (
		"%s · 灵气 %d/%d · 寿元 %.1f\n"
		+ "当前 %s ×%d · 伤害 %d\n碎片 %s"
	) % [
		_debug_resources.get_realm_display_text(),
		_debug_resources.current_qi,
		_debug_resources.get_current_qi_requirement(),
		_debug_resources.current_lifespan,
		_debug_player.get_weapon_name(),
		_debug_player.get_current_delivery_count(),
		_debug_player.get_current_weapon_damage(),
		str(_debug_player.get_universal_upgrade_snapshot()),
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
