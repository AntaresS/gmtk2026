extends SceneTree

const PLAYER_SCENE := preload("res://game/scenes/gameplay/player.tscn")
const ENEMY_SCENE := preload("res://game/scenes/gameplay/enemy.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("RANGED ENEMY READABILITY TEST: %s" % message)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _ranged_enemy(
	player: PlayerController,
	spawner: EnemySpawner,
	position: Vector2
) -> EnemyController:
	var enemy := ENEMY_SCENE.instantiate() as EnemyController
	enemy.player = player
	enemy.cruise_speed = 1.0
	enemy.configure_flying(2, true, 0.0)
	enemy.configure_ranged_attack_slots(
		Callable(spawner, "try_acquire_ranged_attack_slot"),
		Callable(spawner, "release_ranged_attack_slot")
	)
	root.add_child(enemy)
	enemy.global_position = position
	enemy.set("_melee_cooldown_remaining", 0.0)
	return enemy


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2.ZERO
	player.set_movement_enabled(false)

	var spawner := EnemySpawner.new()
	spawner.player = player
	root.add_child(spawner)

	spawner.set_cultivation_level(18)
	_check(
		is_zero_approx(spawner.get_current_ranged_flying_spawn_chance())
		and spawner.get_current_ranged_enemy_cap() == 0,
		"Ranged enemies unlocked before Golden Core."
	)
	spawner.set_cultivation_level(19)
	_check(
		is_equal_approx(
			spawner.get_current_ranged_flying_spawn_chance(),
			spawner.initial_ranged_flying_spawn_chance
		)
		and spawner.get_current_ranged_enemy_cap()
			== spawner.golden_initial_ranged_enemy_cap,
		"Golden Core layer one did not use its introductory chance and cap."
	)
	spawner.set_cultivation_level(27)
	_check(
		is_equal_approx(
			spawner.get_current_ranged_flying_spawn_chance(),
			spawner.ranged_flying_spawn_chance
		)
		and spawner.get_current_ranged_enemy_cap()
			== spawner.golden_late_ranged_enemy_cap,
		"Late Golden Core did not reach its configured chance and cap."
	)
	spawner.set_cultivation_level(28)
	_check(
		is_equal_approx(
			spawner.get_current_ranged_flying_spawn_chance(),
			spawner.nascent_ranged_flying_spawn_chance
		)
		and spawner.get_current_ranged_enemy_cap()
			== spawner.nascent_ranged_enemy_cap,
		"Nascent Soul did not select its ranged chance and cap."
	)
	spawner.set_trial_hell_active(true)
	_check(
		spawner.get_current_ranged_enemy_cap()
			== (
				spawner.nascent_ranged_enemy_cap
				+ spawner.trial_ranged_enemy_cap_bonus
			)
		and spawner.get_current_ranged_windup_cap()
			== spawner.trial_ranged_windup_cap,
		"Trial Hell did not apply its ranged population and warning caps."
	)
	spawner.set_trial_hell_active(false)

	spawner.set_cultivation_level(19)
	spawner.bomber_spawn_chance = 0.0
	spawner.healer_spawn_chance = 0.0
	spawner.initial_ranged_flying_spawn_chance = 1.0
	var admitted_variant := ENEMY_SCENE.instantiate() as EnemyController
	admitted_variant.player = player
	spawner.call("_configure_enemy_variant", admitted_variant, false)
	root.add_child(admitted_variant)
	var capped_variant := ENEMY_SCENE.instantiate() as EnemyController
	capped_variant.player = player
	spawner.call("_configure_enemy_variant", capped_variant, false)
	_check(
		admitted_variant.uses_ranged_attack
		and not capped_variant.uses_ranged_attack,
		"Golden Core introductory population exceeded its active ranged cap."
	)
	admitted_variant.queue_free()
	capped_variant.free()
	await _wait_physics_frames(2)

	var scaled_enemy := ENEMY_SCENE.instantiate() as EnemyController
	scaled_enemy.configure_flying(2, true, 0.0)
	spawner.call("_apply_current_difficulty", scaled_enemy)
	_check(
		is_equal_approx(
			scaled_enemy.ranged_attack_interval,
			spawner.minimum_enemy_ranged_attack_interval
		)
		and is_equal_approx(scaled_enemy.melee_damage, 16.5)
		and is_equal_approx(
			float(scaled_enemy.call("_get_attack_damage")),
			16.5 * scaled_enemy.ranged_damage_multiplier
		),
		"Golden Core ranged cadence or damage did not use its separate tuning."
	)
	scaled_enemy.free()

	spawner.ranged_windup_cap = 1
	var first_enemy := _ranged_enemy(
		player,
		spawner,
		Vector2(-80.0, 0.0)
	)
	var second_enemy := _ranged_enemy(
		player,
		spawner,
		Vector2(80.0, 0.0)
	)
	_check(
		not first_enemy.is_threat_indicator_visible()
		and not second_enemy.is_threat_indicator_visible(),
		"An idle ranged enemy still exposed a full passive threat indicator."
	)
	await _wait_physics_frames(2)
	_check(
		spawner.get_active_ranged_windup_count() == 1
		and first_enemy.is_attack_winding_up()
			!= second_enemy.is_attack_winding_up(),
		"Normal-road ranged enemies exceeded the one-warning readability cap."
	)
	var first_attacker := (
		first_enemy if first_enemy.is_attack_winding_up() else second_enemy
	)
	var waiting_attacker := (
		second_enemy if first_attacker == first_enemy else first_enemy
	)
	first_attacker.set_combat_enabled(false)
	await _wait_physics_frames(2)
	_check(
		spawner.get_active_ranged_windup_count() == 1
		and waiting_attacker.is_attack_winding_up(),
		"Canceling one ranged warning did not release its slot to another enemy."
	)

	first_enemy.queue_free()
	second_enemy.queue_free()
	player.queue_free()
	spawner.queue_free()
	await _wait_physics_frames(2)
	if _failures.is_empty():
		print("RANGED ENEMY READABILITY TEST: PASS")
	else:
		print(
			"RANGED ENEMY READABILITY TEST: FAIL (%d failures)"
			% _failures.size()
		)
	quit()
