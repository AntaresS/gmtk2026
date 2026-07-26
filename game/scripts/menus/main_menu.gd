extends Control

## Gameplay scene opened by Start Game. The current scene is replaced, so
## repeated starts cannot accumulate duplicate gameplay roots.
@export_file("*.tscn") var game_scene_path: String = (
	"res://game/scenes/gameplay/game.tscn"
)

@onready var start_button: Button = %StartGameButton
@onready var title_label: Label = %Title
@onready var quick_start_button: Button = %QuickStartButton
@onready var gallery_button: Button = %WeaponGalleryButton
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var quit_button: Button = %QuitGameButton
@onready var language_label: Label = %LanguageLabel
@onready var language_option: OptionButton = %LanguageOption
@onready var game_info_overlay: GameInfoOverlay = %GameInfoOverlay

var _starting_game: bool = false
var _syncing_language_option: bool = false
var _info_return_focus: Button


func _ready() -> void:
	get_tree().paused = false
	language_option.add_item(LanguageManager.text("chinese"))
	language_option.add_item(LanguageManager.text("english"))
	LanguageManager.language_changed.connect(_on_language_changed)
	game_info_overlay.closed.connect(_on_info_overlay_closed)
	_refresh_language()
	start_button.grab_focus()


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
