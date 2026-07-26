extends SceneTree

const PLAYER_SCENE := preload("res://game/scenes/gameplay/player.tscn")
const ENEMY_SCENE := preload("res://game/scenes/gameplay/enemy.tscn")
const SEAL_SCENE := preload(
	"res://game/scenes/gameplay/fantian_seal_projectile.tscn"
)
const FANTIAN_SEAL_DATA := preload(
	"res://game/resources/weapon/fantian_seal.tres"
)
const FANTIAN_SEAL_TEXTURE := preload(
	"res://assets/player_weapons/fantian_seal.png"
)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("PLAYER FANTIAN SEAL VISUAL TEST: %s" % message)


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
	player.collect_weapon(
		FANTIAN_SEAL_DATA,
		FANTIAN_SEAL_DATA.minimum_damage
	)
	_check(player.select_weapon_slot(0), "Fantian Seal could not be equipped.")
	var held_seal := player.fantian_seal_weapon
	_check(
		player.get_fantian_seal_visual_state() == 1
		and not player.is_fantian_seal_switch_shadow_active()
		and held_seal.visible
		and held_seal.texture == FANTIAN_SEAL_TEXTURE
		and is_zero_approx(held_seal.rotation),
		"Fantian Seal did not begin its one-shot switch summon."
	)
	await _wait_seconds(0.24)
	_check(
		player.get_fantian_seal_visual_state() == 2
		and held_seal.visible
		and held_seal.position.y < -8.0
		and is_zero_approx(held_seal.rotation),
		"Fantian Seal did not leave its fixed side position by flying upward."
	)
	var early_ascent_position := held_seal.position
	var early_ascent_scale := held_seal.scale.x
	await _wait_seconds(0.18)
	_check(
		player.get_fantian_seal_visual_state() == 2
		and held_seal.position.y < early_ascent_position.y
		and held_seal.scale.x > early_ascent_scale,
		"Fantian Seal did not grow gradually while rising."
	)
	await _wait_seconds(0.30)
	_check(
		player.get_fantian_seal_visual_state() == 4
		and not held_seal.visible
		and not player.is_fantian_seal_switch_shadow_active(),
		"Fantian Seal did not wait after leaving the screen."
	)
	await _wait_seconds(0.25)
	_check(
		player.get_fantian_seal_visual_state() == 5
		and player.is_fantian_seal_switch_shadow_active(),
		"Fantian Seal did not begin its delayed 0.3s shadow contraction."
	)
	await _wait_seconds(0.34)
	_check(
		player.get_fantian_seal_visual_state() == 3
		and not player.is_fantian_seal_switch_shadow_active()
		and not held_seal.visible,
		"Fantian Seal switch shadow did not finish at its attack range."
	)
	await _wait_seconds(0.18)
	_check(
		player.get_fantian_seal_visual_state() == 3,
		"Fantian Seal switch animation repeated without switching weapons."
	)
	player.select_starting_weapon()
	player.select_weapon_slot(0)
	_check(
		player.get_fantian_seal_visual_state() == 1
		and held_seal.visible,
		"Switching back to Fantian Seal did not restart its one-shot summon."
	)

	var target := ENEMY_SCENE.instantiate() as EnemyController
	target.player = player
	target.max_health = 100
	target.cruise_speed = 1.0
	target.configure_elite(2.0, 1.0, 1.0)
	root.add_child(target)
	target.global_position = Vector2(180.0, 90.0)
	var edge_target := ENEMY_SCENE.instantiate() as EnemyController
	edge_target.player = player
	edge_target.max_health = 100
	edge_target.cruise_speed = 1.0
	root.add_child(edge_target)
	var seal := SEAL_SCENE.instantiate() as FantianSealProjectile
	root.add_child(seal)
	seal.global_position = target.global_position
	seal.configure(
		target,
		FANTIAN_SEAL_DATA.minimum_damage,
		80.0,
		false,
		player.global_position,
		FANTIAN_SEAL_DATA.attack_range,
		77
	)
	var attack_sprite := seal.seal_sprite
	_check(
		attack_sprite.texture == FANTIAN_SEAL_TEXTURE
		and absf(attack_sprite.scale.x - 160.0 / 173.164063) < 0.001
		and attack_sprite.position.y < -270.0
		and attack_sprite.modulate.a < 0.01
		and seal.z_index < target.z_index
		and attack_sprite.z_index > target.z_index,
		"Fantian Seal attack sprite did not match its damage region."
	)
	await _wait_physics_frames(2)
	target.global_position += Vector2(42.0, 24.0)
	await _wait_physics_frames(2)
	_check(
		seal.global_position.distance_to(target.global_position) < 1.0,
		"Fantian Seal did not track its locked area before impact."
	)
	edge_target.global_position = target.global_position + Vector2(99.0, 0.0)
	var edge_health_before := edge_target.current_health
	await _wait_seconds(0.20)
	_check(
		not bool(seal.get("_impacted"))
		and attack_sprite.modulate.a < 0.01,
		"Fantian Seal descended before its shadow finished contracting."
	)
	await _wait_seconds(0.15)
	_check(
		not bool(seal.get("_impacted"))
		and bool(seal.get("_shadow_contract_emitted"))
		and attack_sprite.position.y < 0.0,
		"Fantian Seal did not descend after the shadow contraction."
	)
	for _frame in 30:
		if bool(seal.get("_impacted")):
			break
		await physics_frame
	var impact_position := seal.global_position
	var immobilized_position := target.global_position
	_check(
		bool(seal.get("_impacted"))
		and target.is_combat_active()
		and target.is_fantian_seal_immobilized()
		and target.immobilized_status_label.visible
		and target.immobilized_status_label.text == "定"
		and target.health_value_label.visible
		and target.health_value_label.text
			== "%d/%d" % [target.current_health, target.max_health]
		and target.is_fantian_seal_root_vfx_active()
		and edge_target.current_health
			== edge_health_before - FANTIAN_SEAL_DATA.minimum_damage
		and attack_sprite.position.is_zero_approx()
		and attack_sprite.modulate.a > 0.99
		and attack_sprite.z_index < target.z_index,
		"Fantian Seal damage overlap or root feedback was not readable."
	)
	target.global_position += Vector2(90.0, 40.0)
	await _wait_physics_frames(2)
	_check(
		seal.global_position.is_equal_approx(impact_position)
		and target.global_position.is_equal_approx(immobilized_position),
		"Fantian Seal or its immobilized target left its absolute position."
	)
	await _wait_seconds(0.16)
	_check(
		target.is_fantian_seal_immobilized()
		and target.is_fantian_seal_root_vfx_active()
		and target.immobilized_status_label.visible
		and target.health_value_label.visible
		and not target.enemy_sprite.self_modulate.is_equal_approx(Color.WHITE),
		"Fantian Seal root tint, glyph, rune, or health readout ended early."
	)
	await _wait_seconds(0.20)
	_check(
		target.health_value_label.visible
		and (
			not is_instance_valid(seal)
			or attack_sprite.z_index < target.z_index
		),
		"Fantian Seal did not expose its surviving target after impact."
	)
	var first_volley_applied := target.apply_fantian_seal_immobilize(0.3, 91)
	await _wait_seconds(0.10)
	var root_before_duplicate := target.get_fantian_seal_immobilized_remaining()
	var duplicate_refreshed := target.apply_fantian_seal_immobilize(0.3, 91)
	var root_after_duplicate := target.get_fantian_seal_immobilized_remaining()
	var next_volley_applied := target.apply_fantian_seal_immobilize(0.3, 92)
	_check(
		first_volley_applied
		and not duplicate_refreshed
		and root_after_duplicate <= root_before_duplicate + 0.01
		and next_volley_applied
		and target.get_fantian_seal_immobilized_remaining()
			> root_after_duplicate,
		"Fantian Seal duplicate roots refreshed within one volley."
	)
	await _wait_seconds(0.33)
	_check(
		not target.is_fantian_seal_immobilized()
		and not target.is_temporary_health_readout_visible()
		and target.immobilized_status_label.visible
		and target.is_fantian_seal_root_vfx_active(),
		"Fantian Seal survivor health outlived its intended readout."
	)
	await _wait_seconds(0.20)
	_check(
		not target.immobilized_status_label.visible
		and not target.is_fantian_seal_root_vfx_active()
		and not is_instance_valid(seal),
		"Fantian Seal root release feedback did not finish cleanly."
	)

	if is_instance_valid(target):
		target.queue_free()
	if is_instance_valid(edge_target):
		edge_target.queue_free()
	player.queue_free()
	await _wait_process_frames(2)
	if _failures.is_empty():
		print("PLAYER FANTIAN SEAL VISUAL TEST: PASS")
	else:
		print(
			"PLAYER FANTIAN SEAL VISUAL TEST: FAIL (%d failures)"
			% _failures.size()
		)
	quit()
