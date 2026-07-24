class_name RunEndedOverlay
extends CanvasLayer

signal restart_requested
signal main_menu_requested

@onready var title_label: Label = %Title
@onready var restart_button: Button = %RestartButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


## Reveals the non-pausing controls for a lifespan-depletion defeat.
func show_defeat() -> void:
	_show_outcome("Lifespan Depleted")


## Reveals the non-pausing controls for completing the ninth breakthrough.
func show_ascension() -> void:
	_show_outcome("Ascension Complete")


func _show_outcome(title: String) -> void:
	title_label.text = title
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
