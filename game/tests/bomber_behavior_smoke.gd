extends SceneTree

const PLAYER_SCENE := preload("res://game/scenes/gameplay/player.tscn")
const ENEMY_SCENE := preload("res://game/scenes/gameplay/enemy.tscn")


class DamageProbe:
	extends Node2D

	var received_damage: float = 0.0


	func take_enemy_damage(amount: float, _source: Node2D = null) -> void:
		received_damage += amount


var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("BOMBER BEHAVIOR TEST: %s" % message)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _run() -> void:
	var health_bomber := ENEMY_SCENE.instantiate() as EnemyController
	health_bomber.max_health = 17
	health_bomber.configure_archetype(
		EnemyController.EnemyArchetype.BOMBER
	)
	_check(
		health_bomber.max_health == 17,
		"Bomber health no longer matches an equivalent ordinary enemy."
	)
	_check(
		is_equal_approx(health_bomber.explosion_radius, 100.0)
		and is_equal_approx(
			health_bomber.explosion_damage_radius,
			100.0
		),
		"Bomber trigger and damage radii are not both 100 pixels."
	)
	health_bomber.free()

	var blast_bomber := ENEMY_SCENE.instantiate() as EnemyController
	blast_bomber.configure_archetype(
		EnemyController.EnemyArchetype.BOMBER
	)
	root.add_child(blast_bomber)
	blast_bomber.global_position = Vector2.ZERO
	var inside_probe := DamageProbe.new()
	root.add_child(inside_probe)
	inside_probe.add_to_group("player_echoes")
	inside_probe.global_position = Vector2(99.0, 0.0)
	var outside_probe := DamageProbe.new()
	root.add_child(outside_probe)
	outside_probe.add_to_group("player_echoes")
	outside_probe.global_position = Vector2(101.0, 0.0)
	blast_bomber.call("_explode", inside_probe)
	_check(
		is_equal_approx(
			inside_probe.received_damage,
			blast_bomber.explosion_damage
		)
		and is_zero_approx(outside_probe.received_damage),
		"Bomber explosion did not respect its 100-pixel area."
	)
	inside_probe.queue_free()
	outside_probe.queue_free()
	blast_bomber.queue_free()

	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.base_forward_speed = 1.0
	root.add_child(player)
	player.global_position = Vector2(0.0, 120.0)
	var warning_bomber := ENEMY_SCENE.instantiate() as EnemyController
	warning_bomber.player = player
	warning_bomber.cruise_speed = 1.0
	warning_bomber.configure_archetype(
		EnemyController.EnemyArchetype.BOMBER
	)
	root.add_child(warning_bomber)
	warning_bomber.global_position = Vector2.ZERO
	await _wait_physics_frames(2)
	var warning_material := (
		warning_bomber.enemy_sprite.material as ShaderMaterial
	)
	var warning_outline_color := Color.TRANSPARENT
	if warning_material != null:
		warning_outline_color = warning_material.get_shader_parameter(
			&"outline_color"
		)
	_check(
		warning_material != null
		and warning_outline_color.is_equal_approx(
			EnemyController.BOMBER_WARNING_OUTLINE_COLOR
		),
		"Fast bomber warning did not add the red sprite outline."
	)
	warning_bomber.queue_free()

	player.global_position = Vector2(180.0, 500.0)
	player.set_movement_enabled(true)
	var tracking_bomber := ENEMY_SCENE.instantiate() as EnemyController
	tracking_bomber.player = player
	tracking_bomber.max_health = 100
	tracking_bomber.cruise_speed = 1.0
	tracking_bomber.configure_archetype(
		EnemyController.EnemyArchetype.BOMBER
	)
	root.add_child(tracking_bomber)
	tracking_bomber.global_position = Vector2.ZERO
	await _wait_physics_frames(8)
	_check(
		tracking_bomber.global_position.x > 1.0
		and tracking_bomber.velocity.x
			<= tracking_bomber.bomber_tracking_speed + 0.01,
		"Bomber did not gently track the player's lateral position."
	)
	player.queue_free()
	tracking_bomber.queue_free()
	await _wait_physics_frames(2)

	if _failures.is_empty():
		print("BOMBER BEHAVIOR TEST: PASS")
	else:
		print(
			"BOMBER BEHAVIOR TEST: FAIL (%d failures)"
			% _failures.size()
		)
	quit()
