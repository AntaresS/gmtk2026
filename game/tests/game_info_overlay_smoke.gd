extends Node

const OVERLAY_SCENE := preload(
	"res://game/scenes/menus/game_info_overlay.tscn"
)

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("GAME INFO OVERLAY TEST: %s" % message)


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _set_test_locale(locale: String) -> void:
	LanguageManager.current_locale = locale
	TranslationServer.set_locale(locale)
	LanguageManager.language_changed.emit(locale)


func _run() -> void:
	var original_locale := LanguageManager.current_locale
	_set_test_locale("en")
	var overlay := OVERLAY_SCENE.instantiate() as GameInfoOverlay
	add_child(overlay)
	await _wait_process_frames(2)
	overlay.open_instructions()
	await _wait_process_frames(2)
	_check(
		overlay.quick_section_titles[3].text == "Realm Advancement"
		and overlay.quick_section_bodies[3].text.contains("9 layers")
		and overlay.quick_section_bodies[3].text.contains("60s")
		and overlay.quick_section_titles[4].text == "Unique Realm Abilities"
		and overlay.quick_section_bodies[4].text.contains("Qi Refining")
		and overlay.quick_section_bodies[4].text.contains("Foundation")
		and overlay.quick_section_bodies[4].text.contains("Golden Core")
		and overlay.quick_section_bodies[4].text.contains("Nascent Soul"),
		"Quick Start did not explain realm advancement and every unique ability."
	)
	_check(
		overlay.quick_section_bodies[3].get_content_height()
			<= overlay.quick_section_bodies[3].size.y
		and overlay.quick_section_bodies[4].get_content_height()
			<= overlay.quick_section_bodies[4].size.y,
		"English realm guidance overflowed its Quick Start cards."
	)
	overlay.open_weapon_gallery()

	var expected_item_count := (
		overlay.WEAPONS.size()
		+ 1
		+ overlay.REALM_CONFIG.get_realm_count()
		+ 1
		+ UniversalUpgradeTypes.COUNT
	)
	_check(
		overlay.weapon_list.item_count == expected_item_count,
		"Gallery did not include all weapons, realm skills, and fragments."
	)
	var realm_section_index := overlay.WEAPONS.size()
	_check(
		not overlay.weapon_list.is_item_selectable(realm_section_index)
		and overlay.weapon_list.get_item_text(realm_section_index)
			== "REALM SKILLS",
		"Realm Skills section heading was missing or selectable."
	)

	var expected_abilities := [
		"Invincible Roll",
		"Skyward Leap",
		"Spiritual Qi Shield",
		"Spirit Projection",
	]
	for realm_index in overlay.REALM_CONFIG.get_realm_count():
		var item_index := realm_section_index + 1 + realm_index
		overlay.weapon_list.select(item_index)
		overlay._on_weapon_list_item_selected(item_index)
		var metadata := (
			overlay.weapon_list.get_item_metadata(item_index) as Dictionary
		)
		_check(
			StringName(metadata.get("kind", &"")) == &"realm"
			and int(metadata.get("index", -1)) == realm_index
			and overlay.realm_details.visible
			and not overlay.fragment_details.visible
			and overlay.realm_skill_body.text
				== expected_abilities[realm_index]
			and overlay.realm_mechanics_body.text.contains("Space"),
			"Realm %d did not show its unique Space skill details."
			% (realm_index + 1)
		)

	var fragment_section_index := (
		realm_section_index
		+ 1
		+ overlay.REALM_CONFIG.get_realm_count()
	)
	var first_fragment_index := fragment_section_index + 1
	overlay.weapon_list.select(first_fragment_index)
	overlay._on_weapon_list_item_selected(first_fragment_index)
	_check(
		overlay.fragment_details.visible
		and not overlay.realm_details.visible,
		"Fragment selection did not remain separate from realm skills."
	)

	_set_test_locale("zh")
	overlay.open_instructions()
	await _wait_process_frames(2)
	_check(
		overlay.quick_section_titles[3].text == "境界升级"
		and overlay.quick_section_bodies[3].text.contains("每个境界共 9 层")
		and overlay.quick_section_titles[4].text == "境界独有能力"
		and overlay.quick_section_bodies[4].text.contains("练气")
		and overlay.quick_section_bodies[4].text.contains("筑基")
		and overlay.quick_section_bodies[4].text.contains("金丹")
		and overlay.quick_section_bodies[4].text.contains("元婴"),
		"快速入门没有完整介绍境界升级与各境界独有能力。"
	)
	_check(
		overlay.quick_section_bodies[3].get_content_height()
			<= overlay.quick_section_bodies[3].size.y
		and overlay.quick_section_bodies[4].get_content_height()
			<= overlay.quick_section_bodies[4].size.y,
		"中文境界介绍超出了快速入门卡片。"
	)
	overlay.open_weapon_gallery()
	var nascent_soul_index := (
		realm_section_index + overlay.REALM_CONFIG.get_realm_count()
	)
	overlay.weapon_list.select(nascent_soul_index)
	overlay._on_weapon_list_item_selected(nascent_soul_index)
	await _wait_process_frames(2)
	_check(
		overlay.weapon_list.get_item_text(realm_section_index)
			== "境界能力"
		and overlay.realm_skill_body.text == "灵体出窍"
		and overlay.realm_mechanics_body.text.contains("200%")
		and overlay.realm_breakthrough_body.text.contains("致命天劫"),
		"Chinese realm skill details were incomplete or unclear."
	)
	var realm_details_parent := overlay.realm_details.get_parent() as Control
	_check(
		overlay.realm_details.size.x <= realm_details_parent.size.x + 0.5
		and overlay.realm_details.size.y <= realm_details_parent.size.y + 0.5,
		"Realm skill cards overflowed the gallery detail panel."
	)

	_set_test_locale(original_locale)
	overlay.queue_free()
	if _failures.is_empty():
		print("GAME INFO OVERLAY TEST: PASS")
		get_tree().quit(0)
	else:
		print(
			"GAME INFO OVERLAY TEST: FAIL (%d failures)"
			% _failures.size()
		)
		get_tree().quit(1)
