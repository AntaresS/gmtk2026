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
	await _wait_seconds(0.48)
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
	var seal := SEAL_SCENE.instantiate() as FantianSealProjectile
	root.add_child(seal)
	seal.global_position = target.global_position
	seal.configure(
		target,
		18,
		80.0,
		false,
		player.global_position,
		FANTIAN_SEAL_DATA.attack_range
	)
	var attack_sprite := seal.seal_sprite
	_check(
		attack_sprite.texture == FANTIAN_SEAL_TEXTURE
		and absf(attack_sprite.scale.x - 160.0 / 715.0) < 0.001
		and attack_sprite.position.y < -270.0
		and attack_sprite.modulate.a < 0.01
		and seal.z_index > target.z_index,
		"Fantian Seal attack sprite did not match its damage region."
	)
	await _wait_physics_frames(2)
	target.global_position += Vector2(42.0, 24.0)
	await _wait_physics_frames(2)
	_check(
		seal.global_position.distance_to(target.global_position) < 1.0,
		"Fantian Seal did not track its locked area before impact."
	)
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
		and target.immobilized_status_label.text.contains("定身")
		and attack_sprite.position.is_zero_approx()
		and attack_sprite.modulate.a > 0.99,
		"Fantian Seal did not immobilize its surviving target with UI feedback."
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
		and target.immobilized_status_label.visible,
		"Fantian Seal immobilization ended before 0.3s."
	)
	await _wait_seconds(0.20)
	_check(
		not target.is_fantian_seal_immobilized()
		and not target.immobilized_status_label.visible,
		"Fantian Seal immobilization UI did not clear after 0.3s."
	)
	_check(
		is_instance_valid(seal) and attack_sprite.modulate.a > 0.95,
		"Landed Fantian Seal did not remain opaque for 0.5s."
	)
	await _wait_seconds(0.38)
	_check(
		not is_instance_valid(seal),
		"Landed Fantian Seal did not fade out after its 0.5s hold."
	)

	if is_instance_valid(target):
		target.queue_free()
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
