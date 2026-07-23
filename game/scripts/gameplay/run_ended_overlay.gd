class_name RunEndedOverlay
extends CanvasLayer

signal restart_requested
signal main_menu_requested

@onready var restart_button: Button = %RestartButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


## Reveals the non-pausing end-of-run controls and moves keyboard focus to
## Restart.
func show_run_ended() -> void:
	restart_button.disabled = false
	main_menu_button.disabled = false
	show()
	restart_button.grab_focus()


func disable_actions() -> void:
	restart_button.disabled = true
	main_menu_button.disabled = true


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()
