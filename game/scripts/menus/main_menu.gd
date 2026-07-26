extends Control

const BGM_BUS: StringName = &"BGM"
const SFX_BUS: StringName = &"SFX"
const SILENT_VOLUME_DB: float = -80.0

## Gameplay scene opened by Start Game. The current scene is replaced, so
## repeated starts cannot accumulate duplicate gameplay roots.
@export_file("*.tscn") var game_scene_path: String = (
	"res://game/scenes/gameplay/game.tscn"
)

@onready var start_button: Button = %StartGameButton
@onready var main_menu_panel: VBoxContainer = $CenterContainer/Menu
@onready var sound_settings_button: Button = %SoundSettingsButton
@onready var sound_menu: VBoxContainer = %SoundMenu
@onready var bgm_mute: CheckButton = %BgmMute
@onready var bgm_volume: HSlider = %BgmVolume
@onready var bgm_percent: Label = %BgmPercent
@onready var sfx_mute: CheckButton = %SfxMute
@onready var sfx_volume: HSlider = %SfxVolume
@onready var sfx_percent: Label = %SfxPercent
@onready var sound_back_button: Button = %SoundBackButton
@onready var title_label: Label = %Title
@onready var quick_start_button: Button = %QuickStartButton
@onready var gallery_button: Button = %WeaponGalleryButton
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var quit_button: Button = %QuitGameButton
@onready var language_label: Label = %LanguageLabel
@onready var language_option: OptionButton = %LanguageOption
@onready var game_info_overlay: GameInfoOverlay = %GameInfoOverlay

var _starting_game: bool = false
var _syncing_sound_controls: bool = false
var _syncing_language_option: bool = false
var _info_return_focus: Button


func _ready() -> void:
	get_tree().paused = false
	_sync_sound_controls()
	language_option.add_item(LanguageManager.text("chinese"))
	language_option.add_item(LanguageManager.text("english"))
	LanguageManager.language_changed.connect(_on_language_changed)
	game_info_overlay.closed.connect(_on_info_overlay_closed)
	_refresh_language()
	start_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if (
		sound_menu.visible
		and not event.is_echo()
		and (
			event.is_action_pressed("ui_cancel")
			or event.is_action_pressed("pause")
		)
	):
		_on_sound_back_pressed()
		get_viewport().set_input_as_handled()


func _on_start_game_pressed() -> void:
	if _starting_game:
		return
	_starting_game = true
	start_button.disabled = true
	var error := get_tree().change_scene_to_file(game_scene_path)
	if error != OK:
		_starting_game = false
		start_button.disabled = false
		push_error("Could not open gameplay scene: %s" % error_string(error))


func _on_quit_game_pressed() -> void:
	get_tree().quit()


func _on_sound_settings_pressed() -> void:
	_sync_sound_controls()
	main_menu_panel.hide()
	sound_menu.show()
	bgm_mute.grab_focus()


func _on_sound_back_pressed() -> void:
	sound_menu.hide()
	main_menu_panel.show()
	sound_settings_button.grab_focus()


func _on_bgm_mute_toggled(muted: bool) -> void:
	if _syncing_sound_controls:
		return
	_set_bus_muted(BGM_BUS, muted)
	_update_mute_text(bgm_mute, muted)


func _on_sfx_mute_toggled(muted: bool) -> void:
	if _syncing_sound_controls:
		return
	_set_bus_muted(SFX_BUS, muted)
	_update_mute_text(sfx_mute, muted)


func _on_bgm_volume_changed(value: float) -> void:
	if _syncing_sound_controls:
		return
	_set_bus_volume_percent(BGM_BUS, value)
	_update_percent_label(bgm_percent, value)


func _on_sfx_volume_changed(value: float) -> void:
	if _syncing_sound_controls:
		return
	_set_bus_volume_percent(SFX_BUS, value)
	_update_percent_label(sfx_percent, value)


func _sync_sound_controls() -> void:
	_syncing_sound_controls = true
	_sync_bus_controls(BGM_BUS, bgm_mute, bgm_volume, bgm_percent)
	_sync_bus_controls(SFX_BUS, sfx_mute, sfx_volume, sfx_percent)
	_syncing_sound_controls = false


func _sync_bus_controls(
	bus_name: StringName,
	mute_button: CheckButton,
	volume_slider: HSlider,
	percent_label: Label
) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_error("Missing audio bus: %s" % bus_name)
		mute_button.disabled = true
		volume_slider.editable = false
		return
	var muted := AudioServer.is_bus_mute(bus_index)
	var volume_percent := clampf(
		db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0,
		0.0,
		100.0
	)
	mute_button.disabled = false
	volume_slider.editable = true
	mute_button.button_pressed = muted
	volume_slider.value = volume_percent
	_update_mute_text(mute_button, muted)
	_update_percent_label(percent_label, volume_percent)


func _set_bus_muted(bus_name: StringName, muted: bool) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, muted)


func _set_bus_volume_percent(
	bus_name: StringName,
	volume_percent: float
) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var linear_volume := clampf(volume_percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(linear_volume)
			if linear_volume > 0.0
			else SILENT_VOLUME_DB
	)


func _update_mute_text(button: CheckButton, muted: bool) -> void:
	button.text = "Muted" if muted else "Mute"


func _update_percent_label(label: Label, value: float) -> void:
	label.text = "%d%%" % roundi(value)


func _on_quick_start_pressed() -> void:
	_info_return_focus = quick_start_button
	game_info_overlay.open_instructions()


func _on_weapon_gallery_pressed() -> void:
	_info_return_focus = gallery_button
	game_info_overlay.open_weapon_gallery()


func _on_leaderboard_pressed() -> void:
	_info_return_focus = leaderboard_button
	game_info_overlay.open_leaderboard()


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
	if is_instance_valid(_info_return_focus):
		_info_return_focus.grab_focus()
	else:
		start_button.grab_focus()


func _refresh_language() -> void:
	title_label.text = LanguageManager.text("main_title")
	start_button.text = LanguageManager.text("start_game")
	quick_start_button.text = LanguageManager.text("quick_start")
	gallery_button.text = LanguageManager.text("weapon_gallery")
	leaderboard_button.text = LanguageManager.text("leaderboard")
	quit_button.text = LanguageManager.text("quit_game")
	language_label.text = LanguageManager.text("language")
	_syncing_language_option = true
	language_option.select(LanguageManager.get_locale_index())
	_syncing_language_option = false
