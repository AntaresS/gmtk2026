class_name WeaponPickup
extends Area2D

const WeaponDataResource = preload(
	"res://game/scripts/gameplay/weapon_data.gd"
)
const DEFAULT_WEAPON_DATA: WeaponDataResource = preload(
	"res://game/resources/dao.tres"
)

## Shared definition used for this pickup's identity, display, and combat
## tuning. EnemySpawner assigns one definition before adding the pickup.
@export var weapon_data: WeaponDataResource = DEFAULT_WEAPON_DATA
## World velocity inherited from the defeated enemy. The drop keeps this
## velocity until it enters the player's attraction circle.
@export var inherited_velocity: Vector2 = Vector2(0.0, -140.0)
## Randomized attack damage rolled when this weapon drops. The player keeps
## only the highest damage collected for each weapon type.
@export_range(1, 100, 1) var weapon_damage: int = 2

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var description_label: Label = $DescriptionLabel

var _attraction_target: PlayerController
var _owner_player: PlayerController
var _attraction_speed: float = 360.0
var _collected: bool = false
var _animation_phase: float = 0.0


func _ready() -> void:
	description_label.text = "%s  %d" % [
		weapon_data.display_name if weapon_data != null else "无效武器",
		weapon_damage,
	]
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
	rotation = sin(_animation_phase * 2.4) * 0.12
	description_label.rotation = -rotation
	if (
		is_instance_valid(_owner_player)
		and global_position.y > _owner_player.global_position.y + 900.0
	):
		queue_free()
	queue_redraw()


func _draw() -> void:
	if weapon_data == null:
		return
	var weapon_color := weapon_data.pickup_color
	if weapon_data.attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING:
		draw_circle(Vector2.ZERO, 19.0, Color(weapon_color, 0.14))
		draw_arc(
			Vector2.ZERO,
			11.0,
			0.0,
			TAU,
			36,
			weapon_color,
			5.0,
			true
		)
		draw_arc(
			Vector2.ZERO,
			6.0,
			0.0,
			TAU,
			30,
			Color("ffe9a8"),
			2.0,
			true
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
	_attraction_target = player
	_attraction_speed = maxf(speed, 1.0)


func get_weapon_name() -> String:
	return weapon_data.display_name if weapon_data != null else ""


func get_weapon_id() -> StringName:
	return weapon_data.weapon_id if weapon_data != null else &""


func _on_player_body_entered(body: Node2D) -> void:
	if _collected or body is not PlayerController:
		return
	_collected = true
	(body as PlayerController).collect_weapon(
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
