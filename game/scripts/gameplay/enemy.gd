class_name EnemyController
extends CharacterBody2D

signal defeated(drop_position: Vector2, inherited_velocity: Vector2)

@onready var elite_label: Label = $EliteLabel

## Player pursued and attacked by this enemy. EnemySpawner injects the active
## player when the enemy is created.
@export var player: PlayerController
## Constant forward speed in world pixels per second. Forward enemies use a
## slower value and rear pursuers receive a slightly faster value; neither
## accelerates, turns, or moves laterally toward the player.
@export var cruise_speed: float = 140.0
## Damage the enemy can receive before being defeated.
@export_range(1, 100, 1) var max_health: int = 3
## Radius, in world pixels, within which the enemy can strike the player.
@export_range(20.0, 120.0, 1.0) var melee_attack_range: float = 55.0
## Seconds between enemy melee attacks. This is longer than the player's
## interval, giving the player a deliberate frequency advantage.
@export_range(0.1, 5.0, 0.05) var melee_attack_interval: float = 1.0
## Lifespan removed by each successful enemy melee attack.
@export_range(0.1, 30.0, 0.1) var melee_damage: float = 3.0
## Distance behind the player, in world pixels, at which this enemy is removed
## if it was passed without being defeated.
@export var despawn_behind_distance: float = 900.0

var current_health: int = 0
var is_elite: bool = false
var _combat_active: bool = true
var _melee_cooldown_remaining: float = 0.0
var _hit_flash_remaining: float = 0.0
var _attack_flash_remaining: float = 0.0
var _attack_direction: Vector2 = Vector2.DOWN


func _ready() -> void:
	add_to_group("enemies")
	current_health = maxi(max_health, 1)
	elite_label.visible = is_elite
	_melee_cooldown_remaining = maxf(melee_attack_interval, 0.1)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _combat_active or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	velocity = Vector2(0.0, -maxf(cruise_speed, 1.0))
	move_and_slide()

	var distance_to_player := global_position.distance_to(player.global_position)
	_melee_cooldown_remaining = maxf(
		_melee_cooldown_remaining - delta,
		0.0
	)
	if (
		distance_to_player <= melee_attack_range
		and _melee_cooldown_remaining <= 0.0
	):
		_attack_direction = global_position.direction_to(player.global_position)
		_attack_flash_remaining = 0.24
		player.take_melee_damage(melee_damage)
		_melee_cooldown_remaining = maxf(melee_attack_interval, 0.1)
		queue_redraw()

	if global_position.y > player.global_position.y + despawn_behind_distance:
		queue_free()

	if _hit_flash_remaining > 0.0:
		_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
		queue_redraw()
	if _attack_flash_remaining > 0.0:
		_attack_flash_remaining = maxf(_attack_flash_remaining - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	var body_color := (
		Color("fff2a8")
		if _hit_flash_remaining > 0.0
		else Color("e6a326") if is_elite else Color("d94b55")
	)
	if is_elite:
		draw_circle(Vector2.ZERO, 28.0, Color(1.0, 0.68, 0.12, 0.18))
		draw_arc(
			Vector2.ZERO,
			27.0,
			0.0,
			TAU,
			40,
			Color(1.0, 0.82, 0.28, 0.9),
			3.0,
			true
		)
	draw_circle(Vector2.ZERO, 22.0, Color(0.2, 0.02, 0.03, 0.8))
	draw_circle(Vector2.ZERO, 17.0, body_color)
	draw_line(Vector2(-10.0, -4.0), Vector2(10.0, -4.0), Color.WHITE, 3.0)
	draw_line(Vector2.ZERO, Vector2(0.0, 9.0), Color("57141a"), 3.0)

	var health_ratio := (
		float(current_health) / float(maxi(max_health, 1))
	)
	draw_rect(Rect2(-22.0, -34.0, 44.0, 5.0), Color(0.08, 0.02, 0.03, 0.9))
	draw_rect(
		Rect2(-22.0, -34.0, 44.0 * health_ratio, 5.0),
		Color("6aff86")
	)
	if _attack_flash_remaining > 0.0:
		var attack_angle := _attack_direction.angle()
		draw_arc(
			Vector2.ZERO,
			38.0,
			attack_angle - 0.72,
			attack_angle + 0.72,
			20,
			Color(1.0, 0.18, 0.12, 0.95),
			7.0,
			true
		)
		draw_line(
			Vector2.ZERO,
			_attack_direction * melee_attack_range,
			Color(1.0, 0.5, 0.18, 0.8),
			3.0
		)


## Converts this enemy into a visibly larger elite while preserving all
## time-based difficulty already applied by EnemySpawner.
func configure_elite(
	health_multiplier: float,
	attack_range_multiplier: float,
	visual_scale: float
) -> void:
	is_elite = true
	max_health = maxi(
		roundi(float(max_health) * maxf(health_multiplier, 1.0)),
		max_health + 1
	)
	melee_attack_range *= maxf(attack_range_multiplier, 1.0)
	scale = Vector2.ONE * maxf(visual_scale, 1.0)
	if is_node_ready():
		current_health = max_health
		elite_label.show()
		queue_redraw()


func is_elite_enemy() -> bool:
	return is_elite


## Applies player melee damage exactly once per strike and removes the enemy
## after its health reaches zero.
func take_melee_damage(amount: int) -> void:
	if not _combat_active or amount <= 0:
		return
	current_health = maxi(current_health - amount, 0)
	_hit_flash_remaining = 0.12
	queue_redraw()
	if current_health > 0:
		return
	var defeat_position := global_position
	var defeat_velocity := velocity
	_combat_active = false
	collision_layer = 0
	collision_mask = 0
	defeated.emit(defeat_position, defeat_velocity)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.4, 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)


## Returns whether this enemy may be targeted or attack.
func is_combat_active() -> bool:
	return _combat_active


## Stops movement and attacks when the run ends.
func set_combat_enabled(enabled: bool) -> void:
	_combat_active = enabled and current_health > 0
	if not _combat_active:
		velocity = Vector2.ZERO
