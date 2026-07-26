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

@onready var title_label: Label = %TitleLabel
@onready var back_button: Button = %BackButton
@onready var instructions_panel: Control = %InstructionsPanel
@onready var instructions_text: RichTextLabel = %InstructionsText
@onready var gallery_panel: Control = %GalleryPanel
@onready var leaderboard_panel: Control = %LeaderboardPanel
@onready var leaderboard_text: RichTextLabel = %LeaderboardText
@onready var gallery_hint: Label = %GalleryHint
@onready var weapon_list: ItemList = %WeaponList
@onready var weapon_icon: WeaponSlotIcon = %WeaponIcon
@onready var weapon_name_label: Label = %WeaponNameLabel
@onready var weapon_meta_label: Label = %WeaponMetaLabel
@onready var weapon_stats_label: Label = %WeaponStatsLabel
@onready var trait_title: Label = %TraitTitle
@onready var trait_body: Label = %TraitBody
@onready var growth_title: Label = %GrowthTitle
@onready var growth_body: Label = %GrowthBody

var _current_page := Page.INSTRUCTIONS
var _selected_weapon_index: int = 0


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
	_selected_weapon_index = clampi(index, 0, WEAPONS.size() - 1)
	_refresh_weapon_details()


func _on_language_changed(_locale: String) -> void:
	_refresh_language()


func _refresh_language() -> void:
	back_button.text = LanguageManager.text("back")
	instructions_text.text = LanguageManager.text("instructions_body")
	gallery_hint.text = LanguageManager.text("gallery_hint")
	trait_title.text = LanguageManager.text("weapon_trait")
	growth_title.text = LanguageManager.text("weapon_growth")
	_refresh_weapon_list()
	_refresh_page()


func _refresh_page() -> void:
	instructions_panel.visible = _current_page == Page.INSTRUCTIONS
	gallery_panel.visible = _current_page == Page.WEAPON_GALLERY
	leaderboard_panel.visible = _current_page == Page.LEADERBOARD
	match _current_page:
		Page.INSTRUCTIONS:
			title_label.text = LanguageManager.text("quick_start")
		Page.WEAPON_GALLERY:
			title_label.text = LanguageManager.text("weapon_gallery")
		Page.LEADERBOARD:
			title_label.text = LanguageManager.text("leaderboard")
	if _current_page == Page.WEAPON_GALLERY:
		_refresh_weapon_details()
	elif _current_page == Page.LEADERBOARD:
		_refresh_leaderboard()


func _refresh_weapon_list() -> void:
	weapon_list.clear()
	for weapon in WEAPONS:
		weapon_list.add_item(
			LanguageManager.get_weapon_name(
				weapon.weapon_id,
				weapon.display_name
			)
		)
	_selected_weapon_index = clampi(
		_selected_weapon_index,
		0,
		WEAPONS.size() - 1
	)
	weapon_list.select(_selected_weapon_index)


func _refresh_weapon_details() -> void:
	var weapon := WEAPONS[_selected_weapon_index]
	var localized_name := LanguageManager.get_weapon_name(
		weapon.weapon_id,
		weapon.display_name
	)
	weapon_name_label.text = localized_name
	weapon_icon.configure(weapon, 1, "", false, false, false)
	weapon_meta_label.text = "%s: %s    ·    %s: %s" % [
		LanguageManager.text("domain"),
		LanguageManager.text(
			"melee"
			if weapon.attack_domain == WeaponDataResource.AttackDomain.MELEE
			else "ranged"
		),
		LanguageManager.text("affinity"),
		_get_affinity_name(weapon.cultivation_type),
	]
	var damage_text := (
		str(weapon.minimum_damage)
		if weapon.minimum_damage == weapon.maximum_damage
		else "%d–%d" % [weapon.minimum_damage, weapon.maximum_damage]
	)
	weapon_stats_label.text = (
		"%s\n%s  %s\n%s  %.0f\n%s  %.2f %s"
	) % [
		LanguageManager.text("weapon_stats"),
		LanguageManager.text("damage"),
		damage_text,
		LanguageManager.text("range"),
		weapon.attack_range,
		LanguageManager.text("interval"),
		weapon.attack_interval,
		LanguageManager.text("seconds"),
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
	var lines := PackedStringArray([
		"[color=#91a4bd]%s[/color]"
		% LanguageManager.text("leaderboard_columns")
	])
	for entry_index in entries.size():
		var entry := entries[entry_index]
		lines.append(
			"[font_size=24][b]%d.[/b][/font_size]  %s  ·  %s  ·  %s  ·  [color=#ffdf8f]%s[/color]%s"
			% [
				entry_index + 1,
				LanguageManager.text("cycle_number_format") % int(
					entry.get("cycle_number", entry_index + 1)
				),
				_format_duration(
					float(entry.get("duration_seconds", 0.0))
				),
				LanguageManager.text("damage_value_format") % int(
					entry.get("total_damage", 0)
				),
				_get_top_weapon_name(entry),
				(
					"  ·  %s"
					% LanguageManager.text("heaven_suppressed")
					if bool(entry.get("fatal_breakthrough", false))
					else ""
				),
			]
		)
	if entries.is_empty():
		lines.append(LanguageManager.text("no_local_records"))
	leaderboard_text.text = "\n\n".join(lines)


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
