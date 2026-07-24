class_name PlayerEcho
extends CharacterBody2D

signal defeated

## Player whose movement and combat snapshot this echo follows.
var owner_player: PlayerController
## Persistent left/right formation offset in world pixels.
var formation_offset: Vector2 = Vector2.ZERO

var max_health: float = 1.0
var current_health: float = 1.0
var attack_damage: int = 1
var attack_range: float = 80.0
var attack_interval: float = 1.0
var _attack_cooldown: float = 0.0
var _active: bool = true


func configure(
	player: PlayerController,
	offset: Vector2,
	health: float,
	damage: int,
	range_value: float,
	interval: float
) -> void:
	owner_player = player
	formation_offset = offset
	max_health = maxf(health, 1.0)
	current_health = max_health
	attack_damage = maxi(damage, 1)
	attack_range = maxf(range_value, 24.0)
	attack_interval = maxf(interval, 0.08)


func _ready() -> void:
	add_to_group("player_echoes")
	z_index = 14
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(owner_player):
		queue_free()
		return
	var desired := owner_player.global_position + formation_offset
	global_position = global_position.move_toward(
		desired,
		maxf(owner_player.current_forward_speed * 2.2, 520.0) * delta
	)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if _attack_cooldown <= 0.0:
		var target := _find_nearest_enemy()
		if is_instance_valid(target):
			target.take_melee_damage(attack_damage)
			_attack_cooldown = attack_interval
	queue_redraw()


func _find_nearest_enemy() -> EnemyController:
	var nearest: EnemyController
	var nearest_distance := pow(attack_range, 2.0)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		var distance := global_position.distance_squared_to(enemy.global_position)
		if enemy.is_combat_active() and distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func take_enemy_damage(amount: float, _source: Node2D = null) -> void:
	if not _active or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	queue_redraw()
	if current_health > 0.0:
		return
	_active = false
	remove_from_group("player_echoes")
	defeated.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var ratio := current_health / maxf(max_health, 1.0)
	draw_circle(Vector2.ZERO, 22.0, Color(0.25, 0.82, 1.0, 0.12))
	draw_circle(Vector2.ZERO, 14.0, Color(0.52, 0.9, 1.0, 0.5))
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 40, Color(0.7, 0.95, 1.0, 0.72), 2.0)
	draw_line(Vector2(-12.0, 28.0), Vector2(12.0, 28.0), Color(0.04, 0.1, 0.14, 0.8), 4.0)
	draw_line(
		Vector2(-12.0, 28.0),
		Vector2(-12.0 + 24.0 * ratio, 28.0),
		Color(0.36, 1.0, 0.78, 0.9),
		4.0
	)
