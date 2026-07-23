extends CanvasLayer

## Main-menu scene opened by Return to Main Menu. The tree is unpaused before
## this scene is loaded.
@export_file("*.tscn") var main_menu_scene_path: String = (
	"res://game/scenes/menus/main_menu.tscn"
)

@onready var resume_button: Button = %ResumeButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or event.is_echo():
		return

	if get_tree().paused:
		resume_game()
	else:
		pause_game()
	get_viewport().set_input_as_handled()


func pause_game() -> void:
	show()
	get_tree().paused = true
	resume_button.grab_focus()


func resume_game() -> void:
	get_tree().paused = false
	hide()


func _on_resume_pressed() -> void:
	resume_game()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(main_menu_scene_path)
	if error != OK:
		push_error("Could not open main menu scene: %s" % error_string(error))
