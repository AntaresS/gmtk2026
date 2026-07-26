extends Node

const GAME_SCENE := preload("res://game/scenes/gameplay/game.tscn")
const MAIN_MENU_SCENE := preload("res://game/scenes/menus/main_menu.tscn")
const LOGICAL_UI_SIZE := Vector2(1920.0, 1080.0)

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("LOGICAL UI SCALE TEST: %s" % message)


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _run() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var expected_scale := minf(
		viewport_size.x / LOGICAL_UI_SIZE.x,
		viewport_size.y / LOGICAL_UI_SIZE.y
	)

	var main_menu := MAIN_MENU_SCENE.instantiate() as Control
	add_child(main_menu)
	await _wait_process_frames(2)
	_check(
		main_menu.size.is_equal_approx(LOGICAL_UI_SIZE),
		"Main menu did not retain its authored 1920x1080 layout."
	)
	_check(
		main_menu.scale.is_equal_approx(Vector2.ONE * expected_scale),
		"Main menu did not scale uniformly to the render viewport."
	)
	main_menu.queue_free()
	await _wait_process_frames(2)

	var game := GAME_SCENE.instantiate()
	add_child(game)
	await _wait_process_frames(4)
	var camera := game.get_node("Camera2D") as Camera2D
	var hud := game.get_node("GameplayHud") as CanvasLayer
	var pause_menu := game.get_node("PauseMenu") as CanvasLayer
	var run_ended := game.get_node("RunEndedOverlay") as CanvasLayer
	var debug_layer := game.get_node("DebugLayer") as CanvasLayer
	_check(
		camera.zoom.is_equal_approx(Vector2.ONE * expected_scale),
		"UI work changed the established 1920x1080 world coverage."
	)
	_check_canvas_layer(
		hud,
		hud.get_node("HudRoot") as Control,
		expected_scale,
		"Gameplay HUD"
	)
	_check_canvas_layer(
		pause_menu,
		pause_menu.get_node("Overlay") as Control,
		expected_scale,
		"Pause menu"
	)
	_check_canvas_layer(
		run_ended,
		run_ended.get_node("Overlay") as Control,
		expected_scale,
		"Run-ended overlay"
	)
	_check_canvas_layer(
		debug_layer,
		debug_layer.get_node("DebugRoot") as Control,
		expected_scale,
		"Debug overlay"
	)

	var pause_button := hud.get_node("HudRoot/PauseButton") as Button
	var pause_button_rect := _get_screen_rect(pause_button)
	_check(
		pause_button_rect.end.x <= viewport_size.x + 0.5
		and pause_button_rect.end.x >= viewport_size.x - 17.0,
		"Right-anchored pause button did not remain at the screen edge."
	)
	_check(
		is_equal_approx(
			pause_button_rect.size.x,
			pause_button.size.x * expected_scale
		),
		"Pause-button mouse and visual bounds did not scale together."
	)
	_finish()


func _check_canvas_layer(
	layer: CanvasLayer,
	content_root: Control,
	expected_scale: float,
	display_name: String
) -> void:
	_check(
		content_root.size.is_equal_approx(LOGICAL_UI_SIZE),
		"%s did not retain its authored 1920x1080 layout." % display_name
	)
	_check(
		layer.scale.is_equal_approx(Vector2.ONE * expected_scale),
		"%s did not scale uniformly to the render viewport." % display_name
	)


func _get_screen_rect(control: Control) -> Rect2:
	var screen_transform := control.get_global_transform_with_canvas()
	return Rect2(
		screen_transform * Vector2.ZERO,
		screen_transform.basis_xform(control.size)
	)


func _finish() -> void:
	if _failures.is_empty():
		print("LOGICAL UI SCALE SMOKE: PASS")
		get_tree().quit(0)
		return
	print("LOGICAL UI SCALE SMOKE: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
