class_name WeaponPickup
extends Area2D

signal choice_focus_changed(option: Node2D, focused: bool)
signal choice_committed(option: Node2D)

const WeaponDataResource = preload(
	"res://game/scripts/gameplay/weapon_data.gd"
)
const DEFAULT_WEAPON_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/dao.tres"
)

## Shared definition used for this pickup's identity, display, and combat
## tuning. EnemySpawner assigns one definition before adding the pickup.
@export var weapon_data: WeaponDataResource = DEFAULT_WEAPON_DATA
## Optional world velocity for standalone drops. Elite reward choices override
## this with zero and ignore attraction so both alternatives remain fixed.
@export var inherited_velocity: Vector2 = Vector2(0.0, -140.0)
## Randomized attack damage rolled when this weapon drops. Every duplicate adds
## quantity, while only a stronger roll replaces that type's stored damage.
@export_range(1, 100, 1) var weapon_damage: int = 2
## Radius within which the player must remain to synchronize this elite drop.
@export_range(24.0, 200.0, 1.0) var channel_radius: float = 72.0
## Continuous synchronization time required before the weapon is collected.
@export_range(0.2, 5.0, 0.1) var channel_duration: float = 1.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var description_label: Label = $DescriptionLabel

var _attraction_target: PlayerController
var _owner_player: PlayerController
var _attraction_speed: float = 360.0
var _collected: bool = false
var _animation_phase: float = 0.0
var _channel_elapsed: float = 0.0
var _channeling: bool = false
var _exclusive_choice: bool = false
var _choice_selected: bool = false
var _choice_dimmed: bool = false


func _ready() -> void:
	LanguageManager.language_changed.connect(_on_language_changed)
	_update_description()
	queue_redraw()


func _process(delta: float) -> void:
	if _collected:
		return
	_animation_phase = fmod(_animation_phase + delta, TAU)
	if is_instance_valid(_attraction_target):
		global_position = global_position.move_toward(
			_attraction_target.global_position,
			_attraction_speed * delta
		)
	else:
		global_position += inherited_velocity * delta
	var visual_scale := 1.0
	if _choice_selected:
		visual_scale = 1.18
	elif _choice_dimmed:
		visual_scale = 0.9
	scale = scale.lerp(
		Vector2.ONE * visual_scale,
		clampf(delta * 12.0, 0.0, 1.0)
	)
	rotation = sin(_animation_phase * 2.4) * 0.12
	description_label.rotation = -rotation
	if (
		is_instance_valid(_owner_player)
		and global_position.y > _owner_player.global_position.y + 900.0
	):
		queue_free()
	_update_channel(delta)
	queue_redraw()


func _draw() -> void:
	if weapon_data == null:
		return
	var weapon_color := weapon_data.pickup_color
	draw_circle(
		Vector2.ZERO,
		channel_radius,
		Color(weapon_color, 0.2 if _exclusive_choice else 0.055)
	)
	if not _exclusive_choice:
		draw_arc(
			Vector2.ZERO,
			channel_radius,
			0.0,
			TAU,
			64,
			Color(weapon_color, 0.72),
			2.0,
			true
		)
	if _channeling:
		draw_arc(
			Vector2.ZERO,
			channel_radius - 5.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * get_channel_progress(),
			64,
			Color.WHITE,
			6.0,
			true
		)
	if _exclusive_choice and weapon_data.icon_texture != null:
		_draw_choice_texture_icon(
			weapon_data.icon_texture
		)
		return
	if weapon_data.attack_kind == WeaponDataResource.AttackKind.GOLDEN_BELL:
		draw_circle(Vector2.ZERO, 19.0, Color(weapon_color, 0.1))
		for ring_index in 3:
			draw_arc(
				Vector2.ZERO,
				8.0 + float(ring_index) * 2.5,
				0.0,
				TAU,
				36,
				Color(weapon_color, 0.95 - float(ring_index) * 0.18),
				1.5,
				true
			)
		return
	if weapon_data.attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING:
		draw_circle(Vector2.ZERO, 19.0, Color(weapon_color, 0.14))
		if weapon_data.icon_texture != null:
			draw_texture_rect(
				weapon_data.icon_texture,
				Rect2(-18.0, -18.0, 36.0, 36.0),
				false
			)
		return
	if weapon_data.attack_kind == WeaponDataResource.AttackKind.THUNDER_HAMMER:
		draw_circle(Vector2.ZERO, 19.0, Color(weapon_color, 0.14))
		draw_line(Vector2(-8.0, 13.0), Vector2(5.0, -5.0), Color("c7a47b"), 5.0)
		draw_rect(
			Rect2(Vector2(-2.0, -13.0), Vector2(20.0, 12.0)),
			weapon_color,
			true
		)
		draw_polyline(
			PackedVector2Array([
				Vector2(-15.0, -8.0),
				Vector2(-8.0, -1.0),
				Vector2(-13.0, 7.0),
			]),
			Color("d9f7ff"),
			2.0
		)
		return
	if weapon_data.attack_kind == WeaponDataResource.AttackKind.FANTIAN_SEAL:
		draw_circle(Vector2.ZERO, 19.0, Color(weapon_color, 0.14))
		draw_rect(
			Rect2(Vector2(-12.0, -11.0), Vector2(24.0, 22.0)),
			weapon_color,
			true
		)
		draw_rect(
			Rect2(Vector2(-12.0, -11.0), Vector2(24.0, 22.0)),
			Color("ffd47a"),
			false,
			3.0
		)
		return
	draw_circle(Vector2.ZERO, 19.0, Color(weapon_color, 0.14))
	draw_line(Vector2(-11.0, 9.0), Vector2(10.0, -12.0), weapon_color, 6.0)
	draw_line(Vector2(-14.0, 5.0), Vector2(-7.0, 12.0), Color("e8d7ae"), 4.0)
	if weapon_data.attack_kind == WeaponDataResource.AttackKind.FLYING_SWORD:
		draw_line(
			Vector2(10.0, -12.0),
			Vector2(15.0, -17.0),
			Color.WHITE,
			3.0
		)


func _draw_choice_texture_icon(
	texture: Texture2D
) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var maximum_size := Vector2(44.0, 44.0)
	var scale_factor := minf(
		maximum_size.x / texture_size.x,
		maximum_size.y / texture_size.y
	)
	var draw_size := texture_size * scale_factor
	draw_texture_rect(
		texture,
		Rect2(-draw_size * 0.5, draw_size),
		false,
		Color.WHITE
	)


## Configures one enemy drop before it enters the scene tree.
func configure(
	new_weapon_data: WeaponDataResource,
	new_weapon_damage: int,
	enemy_velocity: Vector2,
	player: PlayerController
) -> void:
	weapon_data = new_weapon_data
	weapon_damage = maxi(new_weapon_damage, 1)
	inherited_velocity = enemy_velocity
	_owner_player = player


## Starts homing once the drop enters the player's invisible attraction radius.
func attract_to_player(
	player: PlayerController,
	speed: float,
	_delta: float
) -> void:
	if _collected or not is_instance_valid(player):
		return
	if _exclusive_choice:
		return
	_attraction_target = player
	_attraction_speed = maxf(speed, 1.0)


func get_weapon_name() -> String:
	return weapon_data.display_name if weapon_data != null else ""


func get_weapon_id() -> StringName:
	return weapon_data.weapon_id if weapon_data != null else &""


func _on_player_body_entered(body: Node2D) -> void:
	if _collected or body is not PlayerController:
		return
	_owner_player = body as PlayerController


func _update_channel(delta: float) -> void:
	if _collected or not is_instance_valid(_owner_player):
		return
	var inside := (
		global_position.distance_to(
			_owner_player.get_reward_interaction_position()
		)
		<= maxf(channel_radius, 1.0)
	)
	if not inside:
		if _channeling:
			_channeling = false
			_channel_elapsed = 0.0
			if _exclusive_choice:
				choice_focus_changed.emit(self, false)
		_update_description()
		return
	if not _channeling:
		_channeling = true
		if _exclusive_choice:
			choice_focus_changed.emit(self, true)
	_channel_elapsed = minf(
		_channel_elapsed + maxf(delta, 0.0),
		maxf(channel_duration, 0.01)
	)
	_update_description()
	if _channel_elapsed < maxf(channel_duration, 0.01):
		return
	_collect_weapon()


func _collect_weapon() -> void:
	if _collected or not is_instance_valid(_owner_player):
		return
	_collected = true
	if _exclusive_choice:
		choice_committed.emit(self)
	_owner_player.collect_weapon(
		weapon_data,
		weapon_damage
	)
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.35, 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)


func get_channel_progress() -> float:
	return clampf(
		_channel_elapsed / maxf(channel_duration, 0.01),
		0.0,
		1.0
	)


## Marks this pickup as one half of a stationary elite-reward choice.
func enable_exclusive_choice() -> void:
	_exclusive_choice = true
	inherited_velocity = Vector2.ZERO
	_attraction_target = null
	if is_node_ready():
		description_label.offset_left = -46.0
		description_label.offset_top = channel_radius + 7.0
		description_label.offset_right = 46.0
		description_label.offset_bottom = channel_radius + 49.0
		description_label.add_theme_font_size_override("font_size", 12)
		_update_description()


## Applies the group-owned selected/dimmed presentation. Leaving both options
## restores their normal size and brightness.
func set_choice_visual_state(selected: bool, dimmed: bool) -> void:
	_choice_selected = selected
	_choice_dimmed = dimmed
	modulate = (
		Color(0.38, 0.42, 0.5, 0.48)
		if dimmed
		else Color.WHITE
	)
	_update_description()
	queue_redraw()


## Removes an unchosen option without granting or equipping it.
func dismiss_choice() -> void:
	if _collected:
		return
	_collected = true
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 0.72, 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)


## Reports whether this option currently owns its group's visible focus.
func is_choice_focused() -> bool:
	return _choice_selected and _channeling


func _update_description() -> void:
	if not is_instance_valid(description_label):
		return
	var weapon_name := (
		LanguageManager.get_weapon_name(
			weapon_data.weapon_id,
			weapon_data.display_name
		)
		if weapon_data != null
		else LanguageManager.text("invalid_weapon")
	)
	if _channeling:
		description_label.text = LanguageManager.text(
			"weapon_channeling_format"
		) % [
			"▶ " if _exclusive_choice else "",
			weapon_name,
			weapon_damage,
			_channel_elapsed,
			channel_duration,
		]
	elif _exclusive_choice and _choice_dimmed:
		description_label.text = LanguageManager.text(
			"weapon_choice_dimmed_format"
		) % [
			weapon_name,
			weapon_damage,
		]
	elif _exclusive_choice:
		description_label.text = LanguageManager.text(
			"weapon_choice_idle_format"
		) % [
			weapon_name,
			weapon_damage,
		]
	else:
		description_label.text = LanguageManager.text(
			"weapon_pickup_idle_format"
		) % [
			weapon_name,
			weapon_damage,
		]


func _on_language_changed(_locale: String) -> void:
	_update_description()
