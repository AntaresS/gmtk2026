extends Node

const HUD_SCENE := preload(
	"res://game/scenes/gameplay/gameplay_hud.tscn"
)
const REALM_CONFIG: RealmProgressionConfig = preload(
	"res://game/resources/realm_progression_config.tres"
)
const RealmProgressBarResource = preload(
	"res://game/scripts/gameplay/realm_progress_bar.gd"
)

var _failures: Array[String] = []


func _ready() -> void:
	var original_locale := LanguageManager.current_locale
	LanguageManager.current_locale = "en"
	TranslationServer.set_locale("en")

	var expected_names := [
		"Qi Refining",
		"Foundation Establishment",
		"Golden Core",
		"Nascent Soul",
	]
	var bar := RealmProgressBarResource.new() as RealmProgressBar
	bar.size = Vector2(532.0, 46.0)
	add_child(bar)
	await get_tree().process_frame

	for realm_index in REALM_CONFIG.get_realm_count():
		var realm := REALM_CONFIG.get_realm(realm_index)
		var localized_name := LanguageManager.get_realm_name(
			realm.display_name
		)
		var stage_name := LanguageManager.text("realm_stage_format") % (
			localized_name
		)
		bar.configure_state(realm_index, stage_name, 1, realm.layer_count)
		var label_text := str(bar.call("_get_realm_label_text"))
		var font_size := int(
			bar.call(
				"_get_realm_label_font_size",
				ThemeDB.fallback_font,
				label_text
			)
		)
		var rendered_width := ThemeDB.fallback_font.get_string_size(
			label_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size
		).x
		_check(
			stage_name == expected_names[realm_index]
			and not stage_name.ends_with(" Realm"),
			"Realm %d kept the English Realm suffix." % (realm_index + 1)
		)
		_check(
			rendered_width <= RealmProgressBar.LABEL_TEXT_WIDTH + 0.5,
			"Realm %d name did not fit its label lane." % (realm_index + 1)
		)

	var hud := HUD_SCENE.instantiate()
	var panel := hud.get_node("HudRoot/TopStatusPanel") as Control
	var panel_inner_width := panel.size.x - 40.0
	var segment_area_width := (
		panel_inner_width - RealmProgressBar.LABEL_WIDTH
	)
	var segment_width := (
		segment_area_width
		- RealmProgressBar.SEGMENT_GAP
			* float(RealmProgressBar.SEGMENT_COUNT - 1)
	) / float(RealmProgressBar.SEGMENT_COUNT)
	_check(
		segment_width >= 30.0,
		"Wider realm names squeezed the nine layer boxes."
	)

	hud.free()
	bar.queue_free()
	LanguageManager.current_locale = original_locale
	TranslationServer.set_locale(original_locale)
	if _failures.is_empty():
		print("REALM PROGRESS LABEL TEST: PASS")
		get_tree().quit(0)
	else:
		print(
			"REALM PROGRESS LABEL TEST: FAIL (%d failures)"
			% _failures.size()
		)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("REALM PROGRESS LABEL TEST: %s" % message)
