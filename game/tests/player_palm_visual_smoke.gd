extends SceneTree

const PLAYER_SCENE := preload("res://game/scenes/gameplay/player.tscn")
const ENEMY_SCENE := preload("res://game/scenes/gameplay/enemy.tscn")
const PALM_TEXTURE := preload(
	"res://assets/player_weapons/great_strength_palm.png"
)
const AttackDamageResultResource := preload(
	"res://game/scripts/gameplay/attack_damage_result.gd"
)
const PALM_CENTER_OFFSET_PIXELS: float = 10.448311

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("PLAYER PALM VISUAL TEST: %s" % message)


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _wait_seconds(duration: float) -> void:
	await create_timer(duration).timeout


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2.ZERO
	player.set_movement_enabled(false)
	await _wait_seconds(0.32)

	var palm := player.palm_weapon
	_check(
		palm.visible
		and palm.texture == PALM_TEXTURE
		and player.get_palm_visual_state() == 3
		and player.get_visible_palm_sprite_count() == 1
		and not player.is_palm_debug_geometry_visible()
		and absf(palm.scale.x - 0.294784) < 0.001
		and absf(palm.position.length() - 68.0) < 1.0,
		"Equipping Great Strength Palm did not show its floating aim indicator."
	)

	var enemy := ENEMY_SCENE.instantiate() as EnemyController
	enemy.player = player
	enemy.max_health = 99
	enemy.cruise_speed = 1.0
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(
		player.get_current_attack_range() + 20.0,
		0.0
	)
	await _wait_seconds(0.18)
	var outline_material := palm.material as ShaderMaterial
	var warning_outline: Color = (
		outline_material.get_shader_parameter(&"outline_color")
	)
	var finger_direction := Vector2.UP.rotated(palm.rotation).normalized()
	_check(
		player.get_palm_warning_strength() > 0.65
		and palm.visible
		and palm.position.length() < 42.0
		and palm.scale.x < 0.294784
		and palm.modulate.r > 1.15
		and warning_outline.a > 0.65
		and palm.position.normalized().dot(Vector2.RIGHT) > 0.95
		and finger_direction.dot(Vector2.RIGHT) > 0.98,
		"Floating Palm did not aim and charge toward the nearest enemy."
	)
	player.debug_set_palm_geometry_visible(true)
	_check(
		player.is_palm_debug_geometry_visible(),
		"Palm debug geometry could not be enabled."
	)

	enemy.global_position = Vector2(
		player.get_current_attack_range() - 12.0,
		0.0
	)
	var idle_launch_position := palm.position
	player.call(
		"_release_great_strength_palm",
		enemy,
		AttackDamageResultResource.new(5, false)
	)
	_check(
		player.get_palm_visual_state() == 1
		and palm.visible
		and player.get_visible_palm_sprite_count() == 1
		and palm.position.distance_to(idle_launch_position) < 0.1
		and enemy.current_health == 99,
		"Great Strength Palm did not launch from its floating aim position."
	)
	await _wait_seconds(0.15)
	var impact_palm_center := player.to_global(
		palm.position
		+ Vector2.DOWN.rotated(PI * 0.5)
			* PALM_CENTER_OFFSET_PIXELS
			* 0.884353
	)
	var dissolve_material := palm.material as ShaderMaterial
	_check(
		player.get_palm_visual_state() == 2
		and enemy.current_health == 94
		and dissolve_material != null
		and dissolve_material.shader.resource_path
			== "res://game/shaders/enemy_dissolve.gdshader"
		and impact_palm_center.distance_to(enemy.global_position) < 2.5,
		"Great Strength Palm did not land, deal one synchronized hit, and dissolve."
	)
	await _wait_seconds(0.16)
	_check(
		player.get_palm_visual_state() == 3 and palm.visible,
		"Great Strength Palm did not rematerialize as the idle aim indicator."
	)

	enemy.queue_free()
	await _wait_process_frames(2)
	await _wait_seconds(0.28)
	var weak_enemy := ENEMY_SCENE.instantiate() as EnemyController
	weak_enemy.player = player
	weak_enemy.max_health = 1
	weak_enemy.cruise_speed = 1.0
	root.add_child(weak_enemy)
	weak_enemy.set_physics_process(false)
	weak_enemy.global_position = Vector2(
		player.get_current_attack_range() - 12.0,
		0.0
	)
	player.call(
		"_release_great_strength_palm",
		weak_enemy,
		AttackDamageResultResource.new(5, false)
	)
	await _wait_seconds(0.15)
	_check(
		not is_instance_valid(weak_enemy)
		or not weak_enemy.is_combat_active(),
		"Great Strength Palm did not defeat the weak target."
	)
	_check(
		player.get_palm_visual_state() == 2
		or player.get_palm_visual_state() == 3,
		"Great Strength Palm did not dissolve after defeating its target."
	)

	if is_instance_valid(weak_enemy):
		weak_enemy.queue_free()
	player.queue_free()
	await _wait_process_frames(2)
	if _failures.is_empty():
		print("PLAYER PALM VISUAL TEST: PASS")
	else:
		print(
			"PLAYER PALM VISUAL TEST: FAIL (%d failures)"
			% _failures.size()
		)
	quit()
