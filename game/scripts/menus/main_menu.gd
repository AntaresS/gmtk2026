extends Control

## Gameplay scene opened by Start Game. The current scene is replaced, so
## repeated starts cannot accumulate duplicate gameplay roots.
@export_file("*.tscn") var game_scene_path: String = (
	"res://game/scenes/gameplay/game.tscn"
)

@onready var start_button: Button = %StartGameButton

var _starting_game: bool = false


func _ready() -> void:
	get_tree().paused = false
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
