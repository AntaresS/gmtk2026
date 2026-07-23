extends CanvasLayer

## Main-menu scene opened by Return to Main Menu. The tree is unpaused before
## this scene is loaded.
@export_file("*.tscn") var main_menu_scene_path: String = (
	"res://game/scenes/menus/main_menu.tscn"
)

@onready var resume_button: Button = %ResumeButton

var _pause_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_enabled = true
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
