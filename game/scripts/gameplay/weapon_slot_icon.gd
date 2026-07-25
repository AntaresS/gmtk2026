class_name WeaponSlotIcon
extends Control

const WeaponDataResource = preload(
	"res://game/scripts/gameplay/weapon_data.gd"
)
const SLOT_SIZE := Vector2(92.0, 92.0)
const POWER_UP_DURATION: float = 0.72

var weapon_data: WeaponDataResource
var quantity: int = 0
var hotkey_text: String = ""
var selected: bool = false
var locked: bool = false
var new_unselected: bool = false
var _animation_time: float = 0.0
var _power_up_remaining: float = 0.0


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = SLOT_SIZE * 0.5
	set_process(false)
	queue_redraw()


## Replaces the slot's read-only presentation snapshot. Runtime weapon state
## remains owned by PlayerController; this control only draws the supplied data.
func configure(
	new_weapon_data: WeaponDataResource,
	new_quantity: int,
	new_hotkey_text: String,
	is_selected: bool,
	is_locked: bool,
	is_new_unselected: bool
) -> void:
	weapon_data = new_weapon_data
	quantity = maxi(new_quantity, 0)
	hotkey_text = new_hotkey_text
	selected = is_selected
	locked = is_locked
	new_unselected = is_new_unselected
	tooltip_text = (
		"%s  ×%d" % [weapon_data.display_name, quantity]
		if weapon_data != null
		else "尚未获得"
	)
	set_process(new_unselected or _power_up_remaining > 0.0)
	queue_redraw()


## Starts the short count-increase burst used for duplicate weapon pickups.
func play_power_up() -> void:
	_power_up_remaining = POWER_UP_DURATION
	_animation_time = 0.0
	set_process(true)
	queue_redraw()


func is_new_weapon_flashing() -> bool:
	return new_unselected


func is_power_up_effect_active() -> bool:
	return _power_up_remaining > 0.0


func get_weapon_id() -> StringName:
	return weapon_data.weapon_id if weapon_data != null else &""


func get_quantity() -> int:
	return quantity


func _process(delta: float) -> void:
	_animation_time += maxf(delta, 0.0)
	_power_up_remaining = maxf(_power_up_remaining - delta, 0.0)
	queue_redraw()
	if not new_unselected and _power_up_remaining <= 0.0:
		set_process(false)


func _draw() -> void:
	var bounds := Rect2(Vector2.ONE, SLOT_SIZE - Vector2.ONE * 2.0)
	var weapon_color := (
		weapon_data.pickup_color
		if weapon_data != null
		else Color("637083")
	)
	var fill_color := (
		Color(0.035, 0.055, 0.08, 0.94)
		if weapon_data != null
		else Color(0.025, 0.035, 0.05, 0.72)
	)
	draw_rect(bounds, fill_color, true)
	draw_rect(bounds, Color(0.34, 0.42, 0.52, 0.82), false, 2.0)

	if selected:
		draw_rect(
			Rect2(Vector2(3.0, 3.0), SLOT_SIZE - Vector2(6.0, 6.0)),
			Color("7dffd8"),
			false,
			5.0
		)
		draw_rect(
			Rect2(Vector2(8.0, 8.0), SLOT_SIZE - Vector2(16.0, 16.0)),
			Color(weapon_color, 0.32),
			false,
			2.0
		)

	if new_unselected:
		var flash := 0.5 + 0.5 * sin(_animation_time * 8.5)
		draw_rect(
			Rect2(Vector2(2.0, 2.0), SLOT_SIZE - Vector2(4.0, 4.0)),
			Color(1.0, 0.76, 0.18, 0.38 + flash * 0.62),
			false,
			4.0 + flash * 2.0
		)
		draw_circle(
			SLOT_SIZE * 0.5,
			38.0 + flash * 4.0,
			Color(1.0, 0.62, 0.12, 0.04 + flash * 0.08)
		)

	if _power_up_remaining > 0.0:
		var progress := 1.0 - _power_up_remaining / POWER_UP_DURATION
		var burst_alpha := 1.0 - progress
		draw_arc(
			SLOT_SIZE * 0.5,
			27.0 + progress * 25.0,
			0.0,
			TAU,
			40,
			Color(1.0, 0.82, 0.26, burst_alpha),
			5.0 * burst_alpha + 1.0,
			true
		)
		draw_circle(
			SLOT_SIZE * 0.5,
			30.0,
			Color(1.0, 0.66, 0.12, burst_alpha * 0.18)
		)

	_draw_hotkey()
	if weapon_data == null:
		_draw_placeholder()
		return

	_draw_weapon_icon(weapon_data.attack_kind, weapon_color)
	_draw_weapon_name()
	_draw_quantity()
	if locked:
		draw_rect(bounds, Color(0.12, 0.02, 0.03, 0.62), true)
		_draw_centered_text("境界锁定", 51.0, 14, Color("ff8b83"))
	if selected:
		_draw_centered_text("当前", 17.0, 13, Color("7dffd8"))
	elif new_unselected:
		_draw_centered_text("新武器", 17.0, 13, Color("ffd35a"))
	if _power_up_remaining > 0.0:
		var rise := (
			1.0 - _power_up_remaining / POWER_UP_DURATION
		) * 15.0
		_draw_centered_text(
			"+1",
			40.0 - rise,
			22,
			Color(1.0, 0.9, 0.38, 1.0 - rise / 18.0)
		)


func _draw_hotkey() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(
		Rect2(Vector2(5.0, 5.0), Vector2(22.0, 20.0)),
		Color(0.08, 0.11, 0.16, 0.94),
		true
	)
	draw_string(
		font,
		Vector2(5.0, 20.0),
		hotkey_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		22.0,
		14,
		Color(0.94, 0.97, 1.0)
	)


func _draw_placeholder() -> void:
	var placeholder := Rect2(Vector2(25.0, 23.0), Vector2(42.0, 42.0))
	draw_rect(placeholder, Color(0.22, 0.27, 0.34, 0.24), true)
	draw_rect(placeholder, Color(0.44, 0.52, 0.62, 0.48), false, 2.0)
	_draw_centered_text("?", 54.0, 25, Color(0.5, 0.58, 0.68, 0.68))
	_draw_centered_text("空", 82.0, 13, Color(0.48, 0.55, 0.64, 0.78))


func _draw_weapon_name() -> void:
	_draw_centered_text(
		weapon_data.display_name,
		83.0,
		13,
		Color(0.94, 0.97, 1.0)
	)


func _draw_quantity() -> void:
	var badge_center := Vector2(76.0, 61.0)
	draw_circle(badge_center, 13.0, Color(0.04, 0.055, 0.08, 0.96))
	draw_arc(
		badge_center,
		13.0,
		0.0,
		TAU,
		28,
		Color("ffd35a"),
		2.0,
		true
	)
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(63.0, 66.0),
		"×%d" % quantity,
		HORIZONTAL_ALIGNMENT_CENTER,
		26.0,
		13,
		Color("fff1b0")
	)


func _draw_centered_text(
	text: String,
	baseline_y: float,
	font_size: int,
	color: Color
) -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(3.0, baseline_y),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		SLOT_SIZE.x - 6.0,
		font_size,
		color
	)


func _draw_weapon_icon(attack_kind: int, weapon_color: Color) -> void:
	var center := Vector2(46.0, 47.0)
	if attack_kind == WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM:
		draw_circle(center, 20.0, Color(weapon_color, 0.12))
		for ray_index in 6:
			var direction := Vector2.UP.rotated(
				float(ray_index) * TAU / 6.0
			)
			draw_line(
				center + direction * 9.0,
				center + direction * 20.0,
				Color(weapon_color, 0.9),
				3.0
			)
		draw_circle(center, 9.0, Color(weapon_color, 0.92))
		return
	if attack_kind == WeaponDataResource.AttackKind.GOLDEN_BELL:
		draw_circle(center, 19.0, Color(weapon_color, 0.1))
		for ring_index in 3:
			draw_arc(
				center,
				8.0 + float(ring_index) * 2.5,
				0.0,
				TAU,
				36,
				Color(weapon_color, 0.95 - float(ring_index) * 0.18),
				1.5,
				true
			)
		return
	if attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING:
		draw_circle(center, 19.0, Color(weapon_color, 0.14))
		draw_arc(center, 11.0, 0.0, TAU, 36, weapon_color, 5.0, true)
		draw_arc(
			center,
			6.0,
			0.0,
			TAU,
			30,
			Color("ffe9a8"),
			2.0,
			true
		)
		return
	if attack_kind == WeaponDataResource.AttackKind.THUNDER_HAMMER:
		draw_circle(center, 19.0, Color(weapon_color, 0.14))
		draw_line(
			center + Vector2(-8.0, 13.0),
			center + Vector2(5.0, -5.0),
			Color("c7a47b"),
			5.0
		)
		draw_rect(
			Rect2(center + Vector2(-2.0, -13.0), Vector2(20.0, 12.0)),
			weapon_color,
			true
		)
		draw_polyline(
			PackedVector2Array([
				center + Vector2(-15.0, -8.0),
				center + Vector2(-8.0, -1.0),
				center + Vector2(-13.0, 7.0),
			]),
			Color("d9f7ff"),
			2.0
		)
		return
	if attack_kind == WeaponDataResource.AttackKind.FANTIAN_SEAL:
		draw_circle(center, 19.0, Color(weapon_color, 0.14))
		draw_rect(
			Rect2(center + Vector2(-12.0, -11.0), Vector2(24.0, 22.0)),
			weapon_color,
			true
		)
		draw_rect(
			Rect2(center + Vector2(-12.0, -11.0), Vector2(24.0, 22.0)),
			Color("ffd47a"),
			false,
			3.0
		)
		return
	draw_circle(center, 19.0, Color(weapon_color, 0.14))
	draw_line(
		center + Vector2(-11.0, 9.0),
		center + Vector2(10.0, -12.0),
		weapon_color,
		6.0
	)
	draw_line(
		center + Vector2(-14.0, 5.0),
		center + Vector2(-7.0, 12.0),
		Color("e8d7ae"),
		4.0
	)
	if attack_kind == WeaponDataResource.AttackKind.FLYING_SWORD:
		draw_line(
			center + Vector2(10.0, -12.0),
			center + Vector2(15.0, -17.0),
			Color.WHITE,
			3.0
		)
