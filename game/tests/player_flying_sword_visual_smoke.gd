extends SceneTree

const PLAYER_SCENE := preload("res://game/scenes/gameplay/player.tscn")
const ENEMY_SCENE := preload("res://game/scenes/gameplay/enemy.tscn")
const FLYING_SWORD_DATA := preload(
	"res://game/resources/weapon/flying_sword.tres"
)
const FLYING_SWORD_TEXTURE := preload(
	"res://assets/player_weapons/flying_sword.png"
)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("PLAYER FLYING SWORD VISUAL TEST: %s" % message)


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _wait_seconds(duration: float) -> void:
	await create_timer(duration).timeout


func _find_flying_sword_projectile() -> FlyingSwordProjectile:
	for child in root.get_children():
		if child is FlyingSwordProjectile:
			return child as FlyingSwordProjectile
	return null


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2.ZERO
	player.base_forward_speed = 1.0
	player.boosted_forward_speed = 1.0
	player.slowed_forward_speed = 1.0
	player.current_forward_speed = 1.0
	for _copy in 3:
		player.collect_weapon(
			FLYING_SWORD_DATA,
			FLYING_SWORD_DATA.minimum_damage
		)
	_check(player.select_weapon_slot(0), "Flying Sword could not be equipped.")
	player.set("_attack_cooldown_remaining", 999.0)
	await _wait_seconds(0.58)

	var sword_layer := player.flying_sword_layer
	var sword_sprites: Array[Sprite2D] = []
	for child in sword_layer.get_children():
		if child is Sprite2D:
			sword_sprites.append(child as Sprite2D)
	var summon_ok := sword_sprites.size() == 3
	for sword_sprite in sword_sprites:
		summon_ok = (
			summon_ok
			and sword_sprite.visible
			and sword_sprite.texture == FLYING_SWORD_TEXTURE
			and absf(sword_sprite.position.length() - 96.0) < 1.0
		)
	_check(
		summon_ok and sword_sprites[0].position.y < -95.0,
		"Flying Swords did not sequentially occupy their idle ring."
	)
	var attack_range := player.get_current_attack_range()
	var minimum_ring_position: Vector2 = player.call(
		"_get_flying_sword_slot_position",
		0,
		1
	)
	var maximum_ring_position: Vector2 = player.call(
		"_get_flying_sword_slot_position",
		0,
		100
	)
	_check(
		absf(minimum_ring_position.length() - attack_range / 3.0) < 0.1
		and absf(
			maximum_ring_position.length() - attack_range * 2.0 / 3.0
		) < 0.1,
		"Flying Sword ring did not respect its one-third/two-thirds bounds."
	)

	var enemy := ENEMY_SCENE.instantiate() as EnemyController
	enemy.player = player
	enemy.max_health = 999
	enemy.cruise_speed = 1.0
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(
		player.get_current_attack_range()
			+ 120.0,
		0.0
	)
	await _wait_seconds(0.20)
	var static_positions: Array[Vector2] = []
	var aimed_forward := true
	for sword_sprite in sword_sprites:
		static_positions.append(sword_sprite.position)
		aimed_forward = (
			aimed_forward
			and Vector2.UP.rotated(sword_sprite.rotation)
				.dot(Vector2.UP) > 0.98
		)
	await _wait_seconds(0.20)
	var remained_static := true
	for sword_index in sword_sprites.size():
		remained_static = (
			remained_static
			and sword_sprites[sword_index].position.distance_to(
				static_positions[sword_index]
			) < 0.5
		)
	_check(
		aimed_forward and remained_static,
		"Idle Flying Swords did not stay still while facing forward."
	)

	enemy.global_position = Vector2(
		player.get_current_attack_range() + 30.0,
		0.0
	)
	await _wait_seconds(0.18)
	var outline_material := sword_sprites[0].material as ShaderMaterial
	var warning_outline: Color = (
		outline_material.get_shader_parameter(&"outline_color")
	)
	var warning_position := sword_sprites[0].position
	await _wait_seconds(0.28)
	_check(
		player.get_flying_sword_warning_strength() > 0.60
		and warning_outline.a > 0.60
		and sword_sprites[0].position.length() > 108.0
		and sword_sprites[0].position.distance_to(warning_position) > 0.5,
		"Nearby enemies did not expand, outline, and slowly rotate the sword ring."
	)

	enemy.global_position = Vector2(
		player.get_current_attack_range() - 16.0,
		0.0
	)
	await _wait_physics_frames(2)
	var first_launch_position := sword_sprites[0].global_position
	player.set("_attack_cooldown_remaining", 0.9)
	player.call(
		"_launch_flying_sword",
		enemy,
		8,
		false,
		0,
		3
	)
	var projectile := _find_flying_sword_projectile()
	var projectile_sprite := (
		projectile.get_node("SwordSprite") as Sprite2D
		if is_instance_valid(projectile)
		else null
	)
	_check(
		player.get_flying_sword_visual_filled_count() == 2
		and not sword_sprites[0].visible
		and sword_sprites[1].visible
		and sword_sprites[2].visible
		and is_instance_valid(projectile)
		and projectile.global_position.distance_to(first_launch_position) < 1.0
		and projectile_sprite.texture == FLYING_SWORD_TEXTURE,
		(
			"The first Flying Sword launch mismatched: filled=%d, "
			+ "visible=%s/%s/%s, projectile=%s."
		) % [
			player.get_flying_sword_visual_filled_count(),
			sword_sprites[0].visible,
			sword_sprites[1].visible,
			sword_sprites[2].visible,
			is_instance_valid(projectile),
		]
	)
	await _wait_seconds(0.08)
	player.call("_launch_flying_sword", enemy, 8, false, 1, 3)
	_check(
		not sword_sprites[0].visible
		and not sword_sprites[1].visible
		and sword_sprites[2].visible,
		"Remaining Flying Swords reflowed after the second launch."
	)
	await _wait_seconds(0.08)
	player.call("_launch_flying_sword", enemy, 8, false, 2, 3)
	await _wait_process_frames(1)
	_check(
		player.get_flying_sword_visual_filled_count() == 0,
		"Flying Sword volley left %d filled visual slots."
			% player.get_flying_sword_visual_filled_count()
	)

	enemy.queue_free()
	await _wait_process_frames(2)
	player.set("_attack_cooldown_remaining", 0.18)
	await _wait_seconds(0.34)
	_check(
		player.get_flying_sword_visual_filled_count() == 3,
		"Missing Flying Swords were not replenished when cooldown completed."
	)

	player.queue_free()
	await _wait_process_frames(2)
	if _failures.is_empty():
		print("PLAYER FLYING SWORD VISUAL TEST: PASS")
	else:
		print(
			"PLAYER FLYING SWORD VISUAL TEST: FAIL (%d failures)"
			% _failures.size()
		)
	quit()
