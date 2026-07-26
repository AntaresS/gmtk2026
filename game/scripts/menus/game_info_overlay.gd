class_name GameInfoOverlay
extends Control

signal closed

enum Page {
	INSTRUCTIONS,
	WEAPON_GALLERY,
	LEADERBOARD,
}

const WeaponDataResource = preload(
	"res://game/scripts/gameplay/weapon_data.gd"
)
const WEAPONS: Array[WeaponData] = [
	preload("res://game/resources/great_strength_palm.tres"),
	preload("res://game/resources/weapon/dao.tres"),
	preload("res://game/resources/weapon/flying_sword.tres"),
	preload("res://game/resources/weapon/qiankun_ring.tres"),
	preload("res://game/resources/weapon/golden_bell.tres"),
	preload("res://game/resources/weapon/thunder_hammer.tres"),
	preload("res://game/resources/weapon/fantian_seal.tres"),
]
const FRAGMENT_EFFECT_KEYS: Array[String] = [
	"fragment_effect_attack_speed",
	"fragment_effect_damage",
	"fragment_effect_mobility",
	"fragment_effect_range",
	"fragment_effect_speed_control",
]
const QUICK_SECTION_KEYS: Array[String] = [
	"objective",
	"controls",
	"combat",
	"growth",
	"tribulation",
	"routes",
]

@onready var title_label: Label = %TitleLabel
@onready var kicker_label: Label = %KickerLabel
@onready var back_button: Button = %BackButton
@onready var instructions_panel: Control = %InstructionsPanel
@onready var instructions_hint: Label = %InstructionsHint
@onready var quick_section_titles: Array[Label] = [
	%QuickObjectiveTitle,
	%QuickControlsTitle,
	%QuickCombatTitle,
	%QuickGrowthTitle,
	%QuickTribulationTitle,
	%QuickRoutesTitle,
]
@onready var quick_section_bodies: Array[RichTextLabel] = [
	%QuickObjectiveBody,
	%QuickControlsBody,
	%QuickCombatBody,
	%QuickGrowthBody,
	%QuickTribulationBody,
	%QuickRoutesBody,
]
@onready var gallery_panel: Control = %GalleryPanel
@onready var leaderboard_panel: Control = %LeaderboardPanel
@onready var leaderboard_hint: Label = %LeaderboardHint
@onready var record_count_label: Label = %RecordCountLabel
@onready var leaderboard_text: RichTextLabel = %LeaderboardText
@onready var gallery_hint: Label = %GalleryHint
@onready var gallery_archive_label: Label = %GalleryArchiveLabel
@onready var weapon_list: ItemList = %WeaponList
@onready var weapon_icon: WeaponSlotIcon = %WeaponIcon
@onready var weapon_name_label: Label = %WeaponNameLabel
@onready var weapon_meta_label: Label = %WeaponMetaLabel
@onready var weapon_stats_label: Label = %WeaponStatsLabel
@onready var damage_caption: Label = %DamageCaption
@onready var damage_value: Label = %DamageValue
@onready var range_caption: Label = %RangeCaption
@onready var range_value: Label = %RangeValue
@onready var interval_caption: Label = %IntervalCaption
@onready var interval_value: Label = %IntervalValue
@onready var trait_title: Label = %TraitTitle
@onready var trait_body: Label = %TraitBody
@onready var growth_title: Label = %GrowthTitle
@onready var growth_body: Label = %GrowthBody
@onready var weapon_detail_sections: Array[Control] = [
	%WeaponHeader,
	%WeaponStatsLabel,
	%StatsGrid,
	%DescriptionGrid,
]
@onready var fragment_details: VBoxContainer = %FragmentDetails
@onready var fragment_glyph_label: Label = %FragmentGlyphLabel
@onready var fragment_name_label: Label = %FragmentNameLabel
@onready var fragment_meta_label: Label = %FragmentMetaLabel
@onready var fragment_effect_title: Label = %FragmentEffectTitle
@onready var fragment_effect_body: Label = %FragmentEffectBody
@onready var fragment_acquisition_title: Label = %FragmentAcquisitionTitle
@onready var fragment_acquisition_body: Label = %FragmentAcquisitionBody

var _current_page := Page.INSTRUCTIONS
var _selected_weapon_index: int = 0
var _selected_catalog_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	LanguageManager.language_changed.connect(_on_language_changed)
	_refresh_language()
	hide()


func open_instructions() -> void:
	_current_page = Page.INSTRUCTIONS
	_refresh_page()
	show()
	back_button.grab_focus()


func open_weapon_gallery() -> void:
	_current_page = Page.WEAPON_GALLERY
	_refresh_page()
	show()
	weapon_list.grab_focus()


func open_leaderboard() -> void:
	_current_page = Page.LEADERBOARD
	_refresh_page()
	show()
	back_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("pause") or event.is_echo():
		return
	close()
	get_viewport().set_input_as_handled()


func _on_back_button_pressed() -> void:
	close()


func _on_weapon_list_item_selected(index: int) -> void:
	if index == WEAPONS.size():
		return
	_selected_catalog_index = clampi(index, 0, weapon_list.item_count - 1)
	_refresh_catalog_details()


func _on_language_changed(_locale: String) -> void:
	_refresh_language()


func _refresh_language() -> void:
	back_button.text = "ESC   %s" % LanguageManager.text("back").to_upper()
	instructions_hint.text = LanguageManager.text("quick_start_hint")
	for section_index in QUICK_SECTION_KEYS.size():
		var section_key := QUICK_SECTION_KEYS[section_index]
		quick_section_titles[section_index].text = LanguageManager.text(
			"quick_%s_title" % section_key
		)
		quick_section_bodies[section_index].text = LanguageManager.text(
			"quick_%s_body" % section_key
		)
	gallery_hint.text = LanguageManager.text("gallery_hint")
	gallery_archive_label.text = LanguageManager.text(
		"gallery_archive_label"
	).to_upper()
	leaderboard_hint.text = LanguageManager.text("leaderboard_hint")
	weapon_stats_label.text = LanguageManager.text("weapon_stats").to_upper()
	damage_caption.text = LanguageManager.text("damage").to_upper()
	range_caption.text = LanguageManager.text("range").to_upper()
	interval_caption.text = LanguageManager.text("interval").to_upper()
	trait_title.text = LanguageManager.text("weapon_trait").to_upper()
	growth_title.text = LanguageManager.text("weapon_growth").to_upper()
	fragment_meta_label.text = LanguageManager.text("fragment_meta").to_upper()
	fragment_effect_title.text = LanguageManager.text(
		"fragment_effect_profile"
	).to_upper()
	fragment_acquisition_title.text = LanguageManager.text(
		"fragment_acquisition"
	).to_upper()
	fragment_acquisition_body.text = LanguageManager.text(
		"fragment_acquisition_body"
	)
	_refresh_weapon_list()
	_refresh_page()


func _refresh_page() -> void:
	instructions_panel.visible = _current_page == Page.INSTRUCTIONS
	gallery_panel.visible = _current_page == Page.WEAPON_GALLERY
	leaderboard_panel.visible = _current_page == Page.LEADERBOARD
	match _current_page:
		Page.INSTRUCTIONS:
			kicker_label.text = LanguageManager.text(
				"quick_start_kicker"
			).to_upper()
			title_label.text = LanguageManager.text("quick_start")
		Page.WEAPON_GALLERY:
			kicker_label.text = LanguageManager.text(
				"weapon_gallery_kicker"
			).to_upper()
			title_label.text = LanguageManager.text("weapon_gallery")
		Page.LEADERBOARD:
			kicker_label.text = LanguageManager.text(
				"leaderboard_kicker"
			).to_upper()
			title_label.text = LanguageManager.text("leaderboard")
	if _current_page == Page.WEAPON_GALLERY:
		_refresh_catalog_details()
	elif _current_page == Page.LEADERBOARD:
		_refresh_leaderboard()


func _refresh_weapon_list() -> void:
	weapon_list.clear()
	for weapon_index in WEAPONS.size():
		var weapon := WEAPONS[weapon_index]
		weapon_list.add_item(
			"%02d    %s" % [
				weapon_index + 1,
				LanguageManager.get_weapon_name(
					weapon.weapon_id,
					weapon.display_name
				).to_upper(),
			]
		)
	var separator_index := weapon_list.item_count
	weapon_list.add_item(
		LanguageManager.text("fragment_gallery_label").to_upper()
	)
	weapon_list.set_item_disabled(separator_index, true)
	weapon_list.set_item_selectable(separator_index, false)
	weapon_list.set_item_custom_fg_color(
		separator_index,
		Color(0.34, 0.55, 0.64, 1.0)
	)
	for upgrade_type in UniversalUpgradeTypes.COUNT:
		var item_index := weapon_list.item_count
		weapon_list.add_item(
			"%s    %s" % [
				LanguageManager.get_universal_upgrade_glyph(upgrade_type),
				LanguageManager.get_universal_upgrade_name(
					upgrade_type
				).to_upper(),
			]
		)
		weapon_list.set_item_custom_fg_color(
			item_index,
			UniversalUpgradeTypes.get_color(upgrade_type)
		)
	_selected_catalog_index = clampi(
		_selected_catalog_index,
		0,
		weapon_list.item_count - 1
	)
	if _selected_catalog_index == separator_index:
		_selected_catalog_index = 0
	weapon_list.select(_selected_catalog_index)


func _refresh_catalog_details() -> void:
	if _selected_catalog_index < WEAPONS.size():
		_selected_weapon_index = _selected_catalog_index
		_show_weapon_details()
		_refresh_weapon_details()
		return
	var fragment_index := (
		_selected_catalog_index - WEAPONS.size() - 1
	)
	_refresh_fragment_details(
		clampi(fragment_index, 0, UniversalUpgradeTypes.COUNT - 1)
	)


func _show_weapon_details() -> void:
	fragment_details.hide()
	for section in weapon_detail_sections:
		section.show()


func _refresh_fragment_details(fragment_index: int) -> void:
	for section in weapon_detail_sections:
		section.hide()
	fragment_details.show()
	fragment_glyph_label.text = (
		LanguageManager.get_universal_upgrade_glyph(fragment_index)
	)
	fragment_glyph_label.add_theme_color_override(
		"font_color",
		UniversalUpgradeTypes.get_color(fragment_index)
	)
	fragment_name_label.text = LanguageManager.get_universal_upgrade_name(
		fragment_index
	)
	fragment_effect_body.text = LanguageManager.text(
		FRAGMENT_EFFECT_KEYS[fragment_index]
	)


func _refresh_weapon_details() -> void:
	var weapon := WEAPONS[_selected_weapon_index]
	var localized_name := LanguageManager.get_weapon_name(
		weapon.weapon_id,
		weapon.display_name
	)
	weapon_name_label.text = localized_name
	weapon_icon.configure(weapon, 1, "", false, false, false)
	weapon_meta_label.text = "%s: %s    ·    %s: %s" % [
		LanguageManager.text("domain").to_upper(),
		LanguageManager.text(
			"melee"
			if weapon.attack_domain == WeaponDataResource.AttackDomain.MELEE
			else "ranged"
		).to_upper(),
		LanguageManager.text("affinity").to_upper(),
		_get_affinity_name(weapon.cultivation_type).to_upper(),
	]
	var damage_text := (
		str(weapon.minimum_damage)
		if weapon.minimum_damage == weapon.maximum_damage
		else "%d–%d" % [weapon.minimum_damage, weapon.maximum_damage]
	)
	damage_value.text = damage_text
	range_value.text = "%.0f" % weapon.attack_range
	interval_value.text = "%.2f %s" % [
		weapon.attack_interval,
		LanguageManager.text("seconds").to_upper(),
	]
	trait_body.text = LanguageManager.text(
		"trait_%s" % String(weapon.weapon_id)
	)
	growth_body.text = LanguageManager.text(
		"growth_%s" % String(weapon.weapon_id)
	)


func _get_affinity_name(cultivation_type: int) -> String:
	match cultivation_type:
		0:
			return LanguageManager.text("jing")
		1:
			return LanguageManager.text("qi")
		2:
			return LanguageManager.text("shen")
	return LanguageManager.text("neutral")


func _refresh_leaderboard() -> void:
	var entries := LeaderboardStore.load_entries()
	record_count_label.text = LanguageManager.text(
		"leaderboard_record_count"
	) % entries.size()
	if entries.is_empty():
		leaderboard_text.text = (
			"[center][font_size=26][color=#607889]%s[/color][/font_size]"
			+ "[/center]"
		) % LanguageManager.text("no_local_records")
		return

	var lines := PackedStringArray(["[table=5]"])
	for heading_key in [
		"leaderboard_rank",
		"leaderboard_cycle",
		"leaderboard_survival",
		"leaderboard_damage",
		"leaderboard_top_weapon",
	]:
		lines.append(_leaderboard_cell(
			LanguageManager.text(heading_key).to_upper(),
			"#6f91a6",
			true,
			14
		))
	for _column_index in 5:
		lines.append(_leaderboard_cell("━━━━━━━━", "#234354", false, 11))
	for entry_index in entries.size():
		var entry := entries[entry_index]
		var rank_color := (
			"#f6d98c" if entry_index == 0
			else "#a9dce5" if entry_index < 3
			else "#7894a4"
		)
		lines.append(_leaderboard_cell(
			"%02d" % (entry_index + 1),
			rank_color,
			true,
			22
		))
		var cycle_text := LanguageManager.text("cycle_number_format") % int(
			entry.get("cycle_number", entry_index + 1)
		)
		if bool(entry.get("fatal_breakthrough", false)):
			cycle_text += (
				"\n[color=#d98978][font_size=11]%s[/font_size][/color]"
				% LanguageManager.text("heaven_suppressed").to_upper()
			)
		lines.append(_leaderboard_cell(cycle_text, "#d9e4ea", false, 18))
		lines.append(_leaderboard_cell(
			_format_duration(float(entry.get("duration_seconds", 0.0))),
			"#9adce3",
			true,
			19
		))
		lines.append(_leaderboard_cell(
			"%d" % int(entry.get("total_damage", 0)),
			"#d9e4ea",
			false,
			18
		))
		lines.append(_leaderboard_cell(
			_get_top_weapon_name(entry),
			"#f0d68e",
			false,
			18
		))
	lines.append("[/table]")
	leaderboard_text.text = "".join(lines)


func _leaderboard_cell(
	value: String,
	color: String,
	bold: bool,
	font_size: int
) -> String:
	var content := "[b]%s[/b]" % value if bold else value
	return (
		"[cell][color=%s][font_size=%d]%s[/font_size][/color][/cell]"
		% [color, font_size, content]
	)


func _get_top_weapon_name(entry: Dictionary) -> String:
	var weapon_id := StringName(entry.get("top_weapon_id", &""))
	if weapon_id.is_empty():
		return LanguageManager.text("no_damage_recorded")
	return LanguageManager.get_weapon_name(
		weapon_id,
		str(entry.get("top_weapon_fallback", weapon_id))
	)


func _format_duration(seconds: float) -> String:
	var total_seconds := maxi(floori(maxf(seconds, 0.0)), 0)
	var hours := floori(float(total_seconds) / 3600.0)
	var minutes := floori(float(total_seconds % 3600) / 60.0)
	var remaining_seconds := total_seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, remaining_seconds]
	return "%02d:%02d" % [minutes, remaining_seconds]
