extends SceneTree

const PLAYER_SCENE := preload("res://game/scenes/gameplay/player.tscn")
const ENEMY_SCENE := preload("res://game/scenes/gameplay/enemy.tscn")
const EnemyFlyingSwordProjectileResource = preload(
	"res://game/scripts/gameplay/enemy_flying_sword_projectile.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("ENEMY RANGED VISUAL TEST: %s" % message)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _make_ranged_enemy(
	player: PlayerController,
	elite: bool = false
) -> EnemyController:
	var enemy := ENEMY_SCENE.instantiate() as EnemyController
	enemy.player = player
	enemy.max_health = 100
	enemy.cruise_speed = 1.0
	enemy.melee_attack_interval = 0.8
	enemy.threat_indicator_margin = 100.0
	root.add_child(enemy)
	if elite:
		enemy.configure_elite(2.0, 1.2, 1.2)
	enemy.configure_flying(2, true, 0.0)
	enemy.set_physics_process(false)
	return enemy


func _run() -> void:
	var resources := RunResources.new()
	root.add_child(resources)
	resources.set_process(false)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(3000.0, 3000.0)
	player.bind_cultivation(resources)
	player.set_movement_enabled(true)
	player.set_physics_process(false)

	var enemy := _make_ranged_enemy(player)
	enemy.global_position = (
		player.get_combat_anchor_position()
		+ Vector2(0.0, -enemy.ranged_attack_range - 150.0)
	)
	var ranged_weapon := enemy.ranged_weapon
	var weapon_material := ranged_weapon.material as ShaderMaterial
	_check(
		ranged_weapon.visible
		and is_equal_approx(ranged_weapon.rotation, PI)
		and weapon_material != null
		and (
			weapon_material.get_shader_parameter(&"outline_color") as Color
		).is_equal_approx(EnemyController.RANGED_WEAPON_OUTLINE_COLOR),
		"Ranged enemy did not idle with one upward bright-purple sword."
	)

	enemy.global_position = (
		player.get_combat_anchor_position()
		+ Vector2(
			0.0,
			-enemy.ranged_attack_range
				- enemy.threat_indicator_margin * 0.75
		)
	)
	enemy.set("_melee_cooldown_remaining", 0.0)
	enemy.set_physics_process(true)
	await _wait_physics_frames(2)
	_check(
		enemy.is_attack_winding_up()
		and not enemy.attack_warning_label.visible
		and absf(enemy.get_ranged_aim_fill() - 0.25) <= 0.04,
		"Outer warning distance did not begin the partially filled aim line."
	)

	enemy.global_position = (
		player.get_combat_anchor_position()
		+ Vector2(0.0, -enemy.ranged_attack_range - 25.0)
	)
	await _wait_physics_frames(2)
	_check(
		absf(enemy.get_ranged_aim_fill() - 0.75) <= 0.04,
		"Aim-line fill did not increase with proximity to attack range."
	)

	enemy.global_position = (
		player.get_combat_anchor_position()
		+ Vector2(0.0, -enemy.ranged_attack_range + 8.0)
	)
	await _wait_physics_frames(2)
	_check(
		enemy.is_attack_winding_up()
		and is_equal_approx(enemy.get_ranged_aim_fill(), 1.0),
		"Ranged aim line did not visibly reach full charge before launch."
	)
	await _wait_physics_frames(8)
	var normal_projectiles := get_nodes_in_group(
		"enemy_flying_sword_projectiles"
	)
	_check(
		not enemy.is_attack_winding_up()
		and is_zero_approx(enemy.get_ranged_aim_fill())
		and is_zero_approx(float(enemy.get("_attack_flash_remaining")))
		and normal_projectiles.size() == 1,
		"Entering ranged attack radius did not replace all rings with one sword."
	)
	var normal_projectile := (
		normal_projectiles[0] as EnemyFlyingSwordProjectileResource
	)
	_check(
		normal_projectile != null
		and not normal_projectile.has_elite_afterimages()
		and is_equal_approx(
			normal_projectile.get_travel_speed(),
			EnemyController.RANGED_WEAPON_NORMAL_SPEED
		),
		"Ordinary ranged enemy did not launch the plain-speed sword."
	)
	await _wait_physics_frames(30)
	_check(
		player.is_damage_feedback_active()
		and bool(player.get("_damage_feedback_is_projectile")),
		"Ranged sword hit did not select the compact crossing-slash feedback."
	)

	enemy.queue_free()
	await _wait_physics_frames(2)
	var elite_enemy := _make_ranged_enemy(player, true)
	elite_enemy.global_position = (
		player.get_combat_anchor_position()
		+ Vector2(0.0, -elite_enemy.ranged_attack_range + 8.0)
	)
	elite_enemy.set("_melee_cooldown_remaining", 0.0)
	elite_enemy.set_physics_process(true)
	await _wait_physics_frames(10)
	var elite_projectiles := get_nodes_in_group(
		"enemy_flying_sword_projectiles"
	)
	_check(
		elite_projectiles.size() == 1
		and (
			elite_projectiles[0] as EnemyFlyingSwordProjectileResource
		).has_elite_afterimages()
		and is_equal_approx(
			(
				elite_projectiles[0] as EnemyFlyingSwordProjectileResource
			).get_travel_speed(),
			EnemyController.RANGED_WEAPON_ELITE_SPEED
		),
		"Elite ranged enemy did not launch the faster three-afterimage sword."
	)

	if _failures.is_empty():
		print("ENEMY RANGED VISUAL TEST: PASS")
	else:
		print(
			"ENEMY RANGED VISUAL TEST: FAIL (%d failures)"
			% _failures.size()
		)
	quit()
