extends SceneTree

const WeaponDataResource = preload(
	"res://game/scripts/gameplay/weapon_data.gd"
)
const PALM_DATA: WeaponDataResource = preload(
	"res://game/resources/great_strength_palm.tres"
)
const DAO_DATA: WeaponDataResource = preload("res://game/resources/weapon/dao.tres")
const FLYING_SWORD_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/flying_sword.tres"
)
const QIANKUN_RING_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/qiankun_ring.tres"
)
const GOLDEN_BELL_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/golden_bell.tres"
)
const THUNDER_HAMMER_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/thunder_hammer.tres"
)
const FANTIAN_SEAL_DATA: WeaponDataResource = preload(
	"res://game/resources/weapon/fantian_seal.tres"
)

var _failures: Array[String] = []
var _levels_emitted: int = 0
var _pickup_emissions: int = 0
var _last_pickup_value: int = 0
var _depletion_emissions: int = 0
var _thunder_strikes_landed: int = 0
var _thunder_strikes_hit: int = 0
var _tribulation_completions: int = 0
var _test_narrowing_boundary_y: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("GAMEPLAY LOOP TEST: %s" % message)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _get_test_road_half_width(world_y: float) -> float:
	return 70.0 if world_y < _test_narrowing_boundary_y else 200.0


func _run() -> void:
	var change_error := change_scene_to_file(
		"res://game/scenes/gameplay/game.tscn"
	)
	_check(change_error == OK, "Gameplay scene could not be opened.")
	await _wait_process_frames(4)

	var game := current_scene
	var player := game.get_node("Player") as PlayerController
	var world := game.get_node("InfiniteWorld") as InfiniteWorld
	var enemy_spawner := game.get_node("EnemySpawner") as EnemySpawner
	var road_fork_spawner := (
		game.get_node("RoadForkSpawner") as RoadForkSpawner
	)
	var resources := game.get_node("RunResources") as RunResources
	var hud := game.get_node("GameplayHud") as GameplayHud
	var end_overlay := game.get_node("RunEndedOverlay") as RunEndedOverlay
	var pause_menu := game.get_node("PauseMenu")
	_check(player != null, "Gameplay has no player.")
	_check(world != null, "Gameplay has no infinite world.")
	_check(enemy_spawner != null, "Gameplay has no enemy spawner.")
	_check(road_fork_spawner != null, "Gameplay has no road-fork spawner.")
	_check(resources != null, "Gameplay has no run resources.")
	_check(hud != null, "Gameplay has no HUD.")
	_check(end_overlay != null, "Gameplay has no run-ended overlay.")
	var character_sprite := (
		player.get_node_or_null("CharacterSprite") as AnimatedSprite2D
	)
	_check(
		character_sprite != null
		and character_sprite.sprite_frames.get_frame_count(&"fly") == 9
		and character_sprite.sprite_frames.get_frame_count(&"walk") == 9
		and character_sprite.sprite_frames.get_frame_count(&"qi_walk") == 9
		and character_sprite.animation == &"qi_walk"
		and character_sprite.is_playing(),
		"Player did not start with the nine-frame running animation."
	)
	var grounded_character_scale := character_sprite.scale
	_check(
		player.get_current_attack_range() > 55.0,
		"Player melee range is not stronger than the enemy default."
	)
	_check(
		player.get_current_weapon_data() == PALM_DATA
		and PALM_DATA.attack_interval < 1.0
		and is_equal_approx(PALM_DATA.attack_range, 108.0)
		and PALM_DATA.directional_arc_degrees < 180.0,
		"Player melee frequency is not stronger than the enemy default."
	)
	var palm_aim_target := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	palm_aim_target.player = player
	palm_aim_target.max_health = 99
	palm_aim_target.cruise_speed = 1.0
	root.add_child(palm_aim_target)
	palm_aim_target.global_position = (
		player.global_position + Vector2(180.0, 0.0)
	)
	await _wait_process_frames(2)
	_check(
		player.get_palm_attack_direction().dot(Vector2.RIGHT) > 0.98,
		"Idle Great Strength Palm range did not aim at the nearest enemy."
	)
	palm_aim_target.queue_free()
	await _wait_process_frames(1)
	var palm_forward_target := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	var palm_rear_target := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	for palm_target in [palm_forward_target, palm_rear_target]:
		palm_target.player = player
		palm_target.max_health = 99
		palm_target.cruise_speed = 1.0
		root.add_child(palm_target)
	palm_forward_target.global_position = (
		player.global_position + Vector2(0.0, -80.0)
	)
	palm_rear_target.global_position = (
		player.global_position + Vector2(0.0, 80.0)
	)
	player.set("_attack_cooldown_remaining", 999.0)
	await _wait_physics_frames(3)
	player.call(
		"_release_great_strength_palm",
		palm_forward_target,
		player.call("_roll_current_attack_damage")
	)
	_check(
		palm_forward_target.current_health < 99
		and palm_rear_target.current_health == 99,
		"Great Strength Palm did not damage only its directional qi-wave sector."
	)
	player.set("_attack_cooldown_remaining", 0.0)
	palm_forward_target.queue_free()
	palm_rear_target.queue_free()
	_check(
		absf(resources.current_lifespan - 180.0) < 0.5,
		"Lifespan did not start at three minutes."
	)
	_check(
		hud.lifespan_label.text
			== "寿元  %.1fs / %.1fs" % [
				resources.current_lifespan,
				resources.max_lifespan,
			],
		"HUD did not show current and maximum lifespan."
	)
	_check(
		is_equal_approx(resources.maximum_lifespan_cap, 900.0)
		and is_equal_approx(resources.level_up_maxHP_increase, 2.0)
		and is_equal_approx(
			resources.breakthrough_max_lifespan_increase,
			60.0
		),
		"Bounded lifespan progression did not use the tuned MVP defaults."
	)
	_check(
		hud.technique_label.text == "功法  大力掌",
		"HUD did not show the starting Great Strength Palm technique."
	)
	_check(
		hud.weapon_label.text == "当前装备  大力掌  · 伤害 5",
		"HUD did not show the starting equipment."
	)
	_check(
		hud.lifespan_rate_label.text == "寿元消耗  -1.00 / 秒",
		"HUD did not show the current lifespan consumption rate."
	)
	var upgrade_player := preload(
		"res://game/scenes/gameplay/player.tscn"
	).instantiate() as PlayerController
	get_root().add_child(upgrade_player)
	upgrade_player.global_position = Vector2(5000.0, 5000.0)
	upgrade_player.set_movement_enabled(false)
	var upgrade_damage_before := upgrade_player.get_current_weapon_damage()
	var power_fragment := preload(
		"res://game/scenes/gameplay/weapon_power_fragment.tscn"
	).instantiate() as WeaponPowerFragment
	power_fragment.configure(upgrade_player, Vector2.ZERO)
	power_fragment.power_collected.connect(
		upgrade_player.upgrade_all_weapons
	)
	get_root().add_child(power_fragment)
	power_fragment.global_position = upgrade_player.global_position
	await _wait_physics_frames(70)
	_check(
		upgrade_player.get_weapon_power_level() == 1
		and upgrade_player.get_current_weapon_damage()
			== upgrade_damage_before + 1,
		"Weapon-power fragment did not strengthen the existing weapon."
	)
	upgrade_player.collect_weapon(FLYING_SWORD_DATA, 6)
	upgrade_player.cycle_equipment()
	_check(
		upgrade_player.get_current_weapon_damage() == 7,
		"Weapon-power bonus did not apply to a future collected weapon."
	)
	upgrade_player.queue_free()
	if is_instance_valid(power_fragment):
		power_fragment.queue_free()
	await _wait_process_frames(2)

	var initial_attraction_range: float = player.get_attraction_range()
	var initial_attack_range: float = player.get_current_attack_range()
	var initial_attack_interval: float = player.get_current_attack_interval()
	var initial_attack_damage: int = player.get_current_weapon_damage()
	resources.add_qi(100)
	_check(
		player.is_level_up_effect_active(),
		"Cultivation level-up did not start the player aura effect."
	)
	_check(
		resources.get_current_qi_requirement() == 125
		and hud.qi_label.text == "灵气  0 / 125",
		"Qi requirement did not increase after the first level."
	)
	_check(
		player.get_attraction_range()
			== initial_attraction_range
				+ player.attraction_range_increase_per_level,
		"Cultivation level-up did not expand collectible attraction."
	)
	_check(
		player.get_current_attack_range() > initial_attack_range
		and player.get_current_attack_interval() < initial_attack_interval
		and player.get_current_weapon_damage() > initial_attack_damage,
		"Small-level cultivation did not improve Palm range, frequency, and damage."
	)
	resources.reset_resources()
	_check(
		is_equal_approx(
			player.get_attraction_range(),
			initial_attraction_range
		),
		"Resetting cultivation did not restore initial attraction range."
	)
	_check(InputMap.has_action("switch_equipment"), "Tab switch action is missing.")
	_check(
		is_equal_approx(FLYING_SWORD_DATA.attack_interval, 0.9)
		and FLYING_SWORD_DATA.attack_interval > DAO_DATA.attack_interval,
		"Flying-sword volley interval was not lengthened beyond dao attacks."
	)
	_check(
		enemy_spawner.weapon_drop_pool == [
			DAO_DATA,
			FLYING_SWORD_DATA,
			QIANKUN_RING_DATA,
			GOLDEN_BELL_DATA,
			THUNDER_HAMMER_DATA,
			FANTIAN_SEAL_DATA,
		],
		"EnemySpawner did not use the six shared weapon definitions."
	)
	_check(
		is_equal_approx(enemy_spawner.spawn_interval, 3.5)
		and is_equal_approx(enemy_spawner.rear_spawn_interval, 8.0),
		"Enemy spawn frequency was not slightly increased."
	)
	_check(
		enemy_spawner.enemy_qi_drop_amount == 15
		and is_equal_approx(
			enemy_spawner.qi_drop_increase_per_difficulty_step,
			0.5
		)
		and is_equal_approx(
			enemy_spawner.elite_qi_drop_multiplier,
			1.5
		)
		and is_equal_approx(
			enemy_spawner.trial_qi_drop_multiplier,
			1.2
		)
		and is_equal_approx(
			enemy_spawner.rear_qi_drop_multiplier,
			1.15
		)
		and enemy_spawner.maximum_enemy_qi_drop == 88,
		"Enemy Qi progression defaults were not configured."
	)
	_check(
		enemy_spawner.get_enemy_qi_drop_amount(
			0,
			false,
			false,
			false
		) == 15
		and enemy_spawner.get_enemy_qi_drop_amount(
			18,
			false,
			false,
			false
		) == 24
		and enemy_spawner.get_enemy_qi_drop_amount(
			18,
			true,
			false,
			false
		) == 36
		and enemy_spawner.get_enemy_qi_drop_amount(
			18,
			false,
			true,
			false
		) == 29
		and enemy_spawner.get_enemy_qi_drop_amount(
			18,
			false,
			false,
			true
		) == 28
		and enemy_spawner.get_enemy_qi_drop_amount(
			18,
			true,
			true,
			true
		) == 50
		and enemy_spawner.get_enemy_qi_drop_amount(
			10000,
			true,
			true,
			true
		) == enemy_spawner.maximum_enemy_qi_drop,
		"Enemy Qi progression did not apply step, type, and cap modifiers."
	)
	_check(
		is_equal_approx(enemy_spawner.elite_spawn_chance, 0.20)
		and is_equal_approx(enemy_spawner.weapon_drop_chance, 0.75),
		"Elite or weapon-drop probability was not substantially increased."
	)

	var lifespan_before_pause := resources.current_lifespan
	pause_menu.call("pause_game")
	await _wait_process_frames(8)
	_check(
		is_equal_approx(resources.current_lifespan, lifespan_before_pause),
		"Lifespan changed while the scene tree was paused."
	)
	pause_menu.call("resume_game")
	await _wait_process_frames(8)
	_check(
		resources.current_lifespan < lifespan_before_pause,
		"Lifespan did not resume decaying after unpausing."
	)
	var normal_decay_rate := resources.get_current_lifespan_decay_rate()
	Input.action_press("speed_up")
	await _wait_physics_frames(30)
	_check(
		resources.get_current_lifespan_decay_rate() > normal_decay_rate,
		"Accelerating did not increase lifespan consumption."
	)
	_check(
		hud.lifespan_rate_label.text != "寿元消耗  -1.00 / 秒",
		"HUD did not show the accelerated lifespan consumption rate."
	)
	Input.action_release("speed_up")
	await _wait_physics_frames(30)
	Input.action_press("slow_down")
	await _wait_physics_frames(30)
	_check(
		absf(
			resources.get_current_lifespan_decay_rate() - normal_decay_rate
		) < 0.02,
		"Slowing down reduced baseline lifespan consumption."
	)
	Input.action_release("slow_down")
	await _wait_physics_frames(30)
	_check(
		absf(
			resources.get_current_lifespan_decay_rate() - normal_decay_rate
		) < 0.02,
		"Releasing speed controls did not restore normal lifespan consumption."
	)

	var max_pickups_per_chunk := 0
	for child in world.get_children():
		if child is WorldChunk:
			max_pickups_per_chunk = (child as WorldChunk).max_pickups_per_chunk
			break
	var initial_pickup_count := world.get_active_pickup_count()
	var saw_narrow_width := false
	var saw_wide_width := false
	for boundary_index in range(-24, 25):
		var multiplier := (
			world.chunk_config.get_road_width_multiplier_at_boundary(
				boundary_index
			)
		)
		saw_narrow_width = saw_narrow_width or multiplier < 0.99
		saw_wide_width = saw_wide_width or multiplier > 1.01
		_check(
			multiplier
				>= world.chunk_config.minimum_road_width_multiplier
			and multiplier
				<= world.chunk_config.maximum_road_width_multiplier,
			"Generated road width exceeded its configured multiplier range."
		)
	_check(
		saw_narrow_width and saw_wide_width,
		"Deterministic road samples did not include narrow and wide sections."
	)
	var transition_span := (
		world.chunk_config.road_width_transition_chunk_span
	)
	var transition_start := (
		world.chunk_config.get_road_half_width_for_chunk(0, 0.0)
	)
	var transition_end := (
		world.chunk_config.get_road_half_width_for_chunk(
			transition_span,
			0.0
		)
	)
	var first_chunk_end := (
		world.chunk_config.get_road_half_width_for_chunk(0, 1.0)
	)
	var first_ratio := 1.0 / float(transition_span)
	var first_smooth_ratio := first_ratio * first_ratio * (
		3.0 - 2.0 * first_ratio
	)
	_check(
		transition_span >= 3
		and transition_span <= 5
		and is_equal_approx(
			first_chunk_end,
			lerpf(
				transition_start,
				transition_end,
				first_smooth_ratio
			)
		),
		"Road width transition was not stretched across three to five chunks."
	)
	_check(
		initial_pickup_count
		<= world.active_chunk_count * max_pickups_per_chunk,
		"Initial pickup count exceeded the fixed chunk-pool bound."
	)
	_check(
		initial_pickup_count
		< world.active_chunk_count * max_pickups_per_chunk / 4,
		"Five-percent qi generation still produced a dense field."
	)
	for child in world.get_children():
		if child is not WorldChunk:
			continue
		var chunk := child as WorldChunk
		var pickup_container := chunk.get_node_or_null("Pickups")
		_check(pickup_container != null, "A pooled chunk has no pickup container.")
		if pickup_container == null:
			continue
		var pickup_nodes := pickup_container.get_children()
		for pickup_index in pickup_nodes.size():
			var pickup_node := pickup_nodes[pickup_index] as QiPickup
			var local_x: float = pickup_node.position.x
			_check(
				absf(local_x)
				<= chunk.get_road_half_width_at_local_y(
					pickup_node.position.y
				)
				- chunk.pickup_edge_clearance
				+ 0.01,
				"A generated pickup is outside the safe road bounds."
			)
			_check(
				pickup_node.density_profile
				== preload("res://game/resources/qi_profile.tres"),
				"Generated qi did not use the single shared profile."
			)

	player.global_position.y -= world.chunk_config.get_pixel_size().y * 2.0
	await _wait_physics_frames(3)
	_check(
		world.get_active_pickup_count()
		<= world.active_chunk_count * max_pickups_per_chunk,
		"Chunk recycling retained stale pickups beyond the fixed pool bound."
	)
	for child in world.get_children():
		if child is WorldChunk:
			_check(
				(child as WorldChunk).get_pickup_count()
				<= (child as WorldChunk).max_pickups_per_chunk,
				"A recycled chunk retained more than one generated pickup set."
			)

	var isolated_resources := RunResources.new()
	root.add_child(isolated_resources)
	await process_frame
	isolated_resources.set_process(false)

	var precision_resources := RunResources.new()
	precision_resources.max_lifespan = 2000.0
	precision_resources.starting_lifespan = 1000.0
	precision_resources.maximum_lifespan_cap = 2000.0
	root.add_child(precision_resources)
	await process_frame
	precision_resources.set_process(false)
	precision_resources.apply_lifespan_damage(1.0 / 120.0)
	_check(
		precision_resources.current_lifespan < 1000.0,
		"High lifespan swallowed one 120 FPS countdown decrement."
	)
	precision_resources.queue_free()

	var balance_resources := RunResources.new()
	root.add_child(balance_resources)
	await process_frame
	balance_resources.set_process(false)
	for _realm in 3:
		for _level in 9:
			balance_resources.level_up()
		balance_resources.grant_breakthrough_reward()
	_check(
		is_equal_approx(balance_resources.max_lifespan, 414.0)
		and is_equal_approx(
			balance_resources.get_current_lifespan_decay_rate(),
			1.75
		),
		"Three successful realm breakthroughs did not use tuned lifespan growth."
	)
	balance_resources.queue_free()

	isolated_resources.apply_lifespan_damage(25.0)
	_levels_emitted = 0
	isolated_resources.level_up_occurred.connect(_on_isolated_level_up)
	isolated_resources.add_qi(250)
	_check(
		isolated_resources.cultivation_level == 3,
		"A single qi addition did not support multiple level-ups."
	)
	_check(
		isolated_resources.current_qi == 25
		and isolated_resources.get_current_qi_requirement() == 150,
		"Progressive qi thresholds did not preserve the correct overflow."
	)
	_check(_levels_emitted == 2, "Level-up signals did not match levels gained.")
	_check(
		is_equal_approx(isolated_resources.current_lifespan, 175.0),
		"Each level-up did not restore ten lifespan."
	)
	isolated_resources.add_qi(125)
	_check(
		isolated_resources.cultivation_level == 4
		and isolated_resources.current_qi == 0
		and isolated_resources.get_current_qi_requirement() == 175,
		"Overflow did not resolve against each successive qi threshold."
	)
	_check(
		isolated_resources.current_lifespan <= isolated_resources.max_lifespan,
		"Lifespan restore exceeded the configured maximum."
	)
	_depletion_emissions = 0
	isolated_resources.lifespan_depleted.connect(_on_isolated_depleted)
	isolated_resources.apply_lifespan_damage(1000.0)
	isolated_resources.apply_lifespan_damage(1000.0)
	_check(
		_depletion_emissions == 1,
		"Lifespan depletion was emitted more than once."
	)

	var one_shot_pickup := preload(
		"res://game/scenes/gameplay/qi_pickup.tscn"
	).instantiate() as QiPickup
	root.add_child(one_shot_pickup)
	player.base_forward_speed = 1.0
	player.boosted_forward_speed = 1.0
	player.slowed_forward_speed = 1.0
	player.current_forward_speed = 1.0
	var test_density := QiDensityProfile.new()
	test_density.qi_value = 17
	test_density.visual_scale = 1.0
	one_shot_pickup.configure_density(test_density)
	one_shot_pickup.global_position = (
		player.global_position
		+ Vector2(player.get_attraction_range() - 12.0, 0.0)
	)
	_pickup_emissions = 0
	_last_pickup_value = 0
	one_shot_pickup.qi_collected.connect(_on_isolated_pickup_collected)
	_check(
		one_shot_pickup.get_node("DescriptionLabel").text == "灵气",
		"Qi pickup did not carry its small description label."
	)
	await _wait_physics_frames(30)
	_check(
		_pickup_emissions == 1,
		"Qi inside the shared range was not attracted and collected."
	)
	_check(_last_pickup_value == 17, "Contact collection emitted the wrong value.")

	enemy_spawner.set_spawning_enabled(false)
	for existing_enemy in get_nodes_in_group("enemies"):
		existing_enemy.queue_free()
	await _wait_process_frames(2)
	enemy_spawner.set("_elapsed_run_time", 0.0)
	enemy_spawner.set_cultivation_level(5)
	_check(
		enemy_spawner.get_difficulty_step() == 4
		and enemy_spawner.get_current_max_active_enemies()
			== enemy_spawner.max_active_enemies + 4,
		"Enemy quantity did not scale quickly with cultivation level."
	)
	_check(
		enemy_spawner.get_current_spawn_interval(false)
			< enemy_spawner.spawn_interval * 0.7,
		"Enemy spawn frequency did not keep pace with cultivation level."
	)
	var level_scaled_normal := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	level_scaled_normal.player = player
	enemy_spawner.call("_apply_current_difficulty", level_scaled_normal)
	root.add_child(level_scaled_normal)
	_check(
		level_scaled_normal.max_health >= 11
		and level_scaled_normal.melee_damage >= 6.0
		and level_scaled_normal.melee_attack_interval < 0.7,
		"Ordinary enemy stats did not keep pace with cultivation level."
	)
	level_scaled_normal.queue_free()
	await _wait_process_frames(2)
	enemy_spawner.set_cultivation_level(1)
	enemy_spawner.set(
		"_elapsed_run_time",
		enemy_spawner.difficulty_step_seconds * 2.0
	)
	_check(
		enemy_spawner.get_difficulty_step() == 2
		and enemy_spawner.get_current_max_active_enemies()
			== enemy_spawner.max_active_enemies
				+ enemy_spawner.max_enemies_increase_per_step * 2,
		"Elapsed time did not increase the enemy quantity cap."
	)
	_check(
		enemy_spawner.get_current_spawn_interval(false)
			< enemy_spawner.spawn_interval,
		"Elapsed time did not increase enemy spawn frequency."
	)
	enemy_spawner.elite_spawn_chance = 1.0
	var camera := game.get_node("Camera2D") as Camera2D
	var spawned_enemy_qi_reward := enemy_spawner.get_enemy_qi_drop_amount(
		enemy_spawner.get_difficulty_step(),
		true,
		false,
		false
	)
	enemy_spawner.call("_spawn_enemy")
	await _wait_physics_frames(2)
	var spawned_enemies := get_nodes_in_group("enemies")
	_check(not spawned_enemies.is_empty(), "EnemySpawner did not create an enemy.")
	if not spawned_enemies.is_empty():
		var spawned_enemy := spawned_enemies[0] as EnemyController
		var camera_top := (
			camera.global_position.y
			- get_root().get_viewport().get_visible_rect().size.y
				/ camera.zoom.y
				* 0.5
		)
		_check(
			spawned_enemy.global_position.y < camera_top,
			"Enemy was not spawned beyond the forward screen edge."
		)
		_check(
			spawned_enemy.max_health > 3
			and spawned_enemy.melee_damage > 3.0
			and spawned_enemy.melee_attack_interval < 1.0,
			"Elapsed time did not strengthen enemy health, damage, and frequency."
		)
		_check(
			spawned_enemy.is_elite_enemy()
			and spawned_enemy.max_health > 5
			and spawned_enemy.melee_attack_range > 55.0
			and spawned_enemy.elite_label.visible,
			"Elite enemy lacked its larger health, range, or visible identity."
		)
		enemy_spawner.weapon_drop_chance = 1.0
		var inherited_enemy_velocity := spawned_enemy.velocity
		enemy_spawner.set(
			"_elapsed_run_time",
			enemy_spawner.difficulty_step_seconds * 8.0
		)
		spawned_enemy.take_melee_damage(999)
		await _wait_process_frames(2)
		var saw_enemy_qi_drop := false
		var saw_weapon_drop := false
		var weapon_power_fragment_count := 0
		var saw_weapon_power_fragment := false
		for drop_node in enemy_spawner.get_children():
			if drop_node is QiPickup:
				var qi_drop := drop_node as QiPickup
				saw_enemy_qi_drop = (
					qi_drop.get_qi_value()
					== spawned_enemy_qi_reward
				)
			elif drop_node is WeaponPickup:
				var weapon_drop := drop_node as WeaponPickup
				saw_weapon_drop = (
					weapon_drop.inherited_velocity
						.is_equal_approx(inherited_enemy_velocity)
					and weapon_drop.weapon_data
						in enemy_spawner.weapon_drop_pool
					and weapon_drop.description_label.text.begins_with(
						weapon_drop.weapon_data.display_name
					)
					and weapon_drop.description_label.text.contains(
						"圈内同步1秒"
					)
					and weapon_drop.weapon_damage >= 2
				)
			elif drop_node is WeaponPowerFragment:
				var dropped_power_fragment := drop_node as WeaponPowerFragment
				weapon_power_fragment_count += 1
				saw_weapon_power_fragment = (
					dropped_power_fragment.power_amount == 1
					and is_equal_approx(
						dropped_power_fragment.channel_duration,
						1.0
					)
					and dropped_power_fragment.pickup_radius >= 90.0
					and dropped_power_fragment.upgrade_type >= 0
					and dropped_power_fragment.upgrade_type
						< UniversalUpgradeTypes.COUNT
					and dropped_power_fragment.description_label.text.contains(
						"强化碎片"
					)
				)
		_check(saw_enemy_qi_drop, "Defeated enemy did not drop configured qi.")
		_check(
			saw_weapon_drop,
			"Weapon drop did not inherit enemy velocity or show its label."
		)
		_check(
			saw_weapon_power_fragment and weapon_power_fragment_count == 1,
			"Elite enemy did not drop exactly one universal-upgrade fragment."
		)
	enemy_spawner.set(
		"_elapsed_run_time",
		enemy_spawner.difficulty_step_seconds * 2.0
	)
	await _wait_process_frames(12)
	enemy_spawner.elite_spawn_chance = 0.0

	enemy_spawner.call("_spawn_enemy", true)
	await _wait_physics_frames(2)
	var camera_bottom := (
		camera.global_position.y
		+ get_root().get_viewport().get_visible_rect().size.y
			/ camera.zoom.y
			* 0.5
	)
	var rear_enemy: EnemyController = null
	for enemy_node in get_nodes_in_group("enemies"):
		if (
			enemy_node is EnemyController
			and enemy_node.global_position.y > camera_bottom
		):
			rear_enemy = enemy_node as EnemyController
			break
	_check(rear_enemy != null, "Rear enemy was not spawned behind the screen.")
	if rear_enemy != null:
		_check(
			rear_enemy.cruise_speed > player.base_forward_speed,
			"Rear enemy was not faster than the player's normal speed."
		)
		_check(
			rear_enemy.velocity.is_equal_approx(
				Vector2(0.0, -rear_enemy.cruise_speed)
			),
			"Rear enemy did not keep one constant forward velocity."
		)
		rear_enemy.queue_free()
	await _wait_process_frames(2)

	var straight_enemy := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	straight_enemy.player = player
	straight_enemy.cruise_speed = 100.0
	root.add_child(straight_enemy)
	straight_enemy.global_position = (
		player.global_position + Vector2(110.0, -400.0)
	)
	var straight_enemy_start_x := straight_enemy.global_position.x
	await _wait_physics_frames(10)
	_check(
		is_equal_approx(straight_enemy.global_position.x, straight_enemy_start_x),
		"Enemy steered laterally toward the player."
	)
	_check(
		straight_enemy.velocity.is_equal_approx(Vector2(0.0, -100.0)),
		"Enemy changed speed or direction while moving forward."
	)
	straight_enemy.queue_free()
	await _wait_process_frames(2)

	var constrained_enemy := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	constrained_enemy.player = player
	constrained_enemy.cruise_speed = 100.0
	root.add_child(constrained_enemy)
	var constrained_enemy_start_y := player.global_position.y - 400.0
	_test_narrowing_boundary_y = constrained_enemy_start_y - 1.0
	constrained_enemy.global_position = Vector2(
		world.get_route_center_x() + 100.0,
		constrained_enemy_start_y
	)
	constrained_enemy.configure_road_constraint(
		world.get_route_center_x(),
		Callable(self, "_get_test_road_half_width"),
		32.0
	)
	await _wait_physics_frames(3)
	_check(
		absf(
			constrained_enemy.global_position.x
			- world.get_route_center_x()
		) <= 38.01,
		"Enemy was not clamped when it entered a narrower road section."
	)
	constrained_enemy.queue_free()
	await _wait_process_frames(2)

	road_fork_spawner.set_forks_enabled(false)
	for old_fork_node in get_nodes_in_group("road_forks"):
		old_fork_node.queue_free()
	await _wait_process_frames(2)
	road_fork_spawner.set("_next_is_trial_hell", false)
	road_fork_spawner.call("_spawn_fork")
	await _wait_process_frames(2)
	var fork_nodes := get_nodes_in_group("road_forks")
	_check(not fork_nodes.is_empty(), "RoadForkSpawner did not create a fork.")
	if not fork_nodes.is_empty():
		var road_fork := fork_nodes[0] as RoadFork
		road_fork.configure_side(-1)
		_check(
			is_equal_approx(
				road_fork.main_road_half_width,
				world.get_road_half_width_at_world_y(
					road_fork.global_position.y
				)
			),
			"Branch road width did not match the infinite main road."
		)
		road_fork.global_position = Vector2(
			world.get_route_center_x(),
			player.global_position.y - 200.0
		)
		road_fork.set_fork_enabled(true)
		await _wait_physics_frames(2)
		var committed_center := road_fork.get_branch_center_x()
		var old_route_enemy := preload(
			"res://game/scenes/gameplay/enemy.tscn"
		).instantiate() as EnemyController
		old_route_enemy.player = player
		old_route_enemy.cruise_speed = 1.0
		root.add_child(old_route_enemy)
		old_route_enemy.global_position = Vector2(
			world.get_route_center_x(),
			player.global_position.y - 400.0
		)
		await _wait_process_frames(2)
		player.global_position.x = committed_center
		player.global_position.y = road_fork.global_position.y + 50.0
		await _wait_physics_frames(2)
		_check(
			road_fork.get_selected_branch() == "左侧无尽岔路",
			"Player could not commit to the full-width exterior branch."
		)
		_check(
			is_equal_approx(world.get_route_center_x(), committed_center)
			and is_equal_approx(player.road_center_x, committed_center),
			"Committed branch did not become the new infinite road center."
		)
		_check(
			is_equal_approx(player.global_position.x, committed_center)
			and is_equal_approx(camera.global_position.x, committed_center),
			"Player and camera were not recentered on the committed branch."
		)
		_check(
			not is_instance_valid(old_route_enemy),
			"An enemy remained on a road outside the player's active route."
		)
		enemy_spawner.call("_spawn_enemy")
		await _wait_physics_frames(2)
		var spawned_on_committed_route := false
		for committed_enemy_node in get_nodes_in_group("enemies"):
			if (
				committed_enemy_node is EnemyController
				and absf(
					committed_enemy_node.global_position.x
					- committed_center
				) <= (
					world.get_road_half_width_at_world_y(
						committed_enemy_node.global_position.y
					)
					- enemy_spawner.road_edge_clearance
				)
			):
				spawned_on_committed_route = true
				committed_enemy_node.queue_free()
		_check(
			spawned_on_committed_route,
			"Enemy spawning did not follow the player's committed road."
		)
		road_fork_spawner.call("_spawn_fork")
		await _wait_process_frames(2)
		var saw_nested_fork := false
		var trial_fork: RoadFork = null
		for nested_fork_node in get_nodes_in_group("road_forks"):
			if (
				nested_fork_node is RoadFork
				and nested_fork_node != road_fork
				and is_equal_approx(
					nested_fork_node.global_position.x,
					committed_center
				)
			):
				saw_nested_fork = true
				trial_fork = nested_fork_node as RoadFork
		_check(
			saw_nested_fork
			and trial_fork != null
			and trial_fork.is_trial_hell_branch()
			and (
				trial_fork.left_label.text.contains("试炼地狱")
				or trial_fork.right_label.text.contains("试炼地狱")
			),
			"Normal branch was not followed by a distinct Trial Hell branch."
		)
		var normal_enemy_cap := enemy_spawner.get_current_max_active_enemies()
		var normal_spawn_interval := (
			enemy_spawner.get_current_spawn_interval(false)
		)
		var normal_difficulty_enemy := preload(
			"res://game/scenes/gameplay/enemy.tscn"
		).instantiate() as EnemyController
		enemy_spawner.call(
			"_apply_current_difficulty",
			normal_difficulty_enemy
		)
		game.call("_on_route_committed", committed_center, "试炼地狱")
		var trial_difficulty_enemy := preload(
			"res://game/scenes/gameplay/enemy.tscn"
		).instantiate() as EnemyController
		enemy_spawner.call(
			"_apply_current_difficulty",
			trial_difficulty_enemy
		)
		var trial_chunks_are_colored := true
		for world_child in world.get_children():
			if (
				world_child is WorldChunk
				and not (world_child as WorldChunk).is_trial_hell_active()
			):
				trial_chunks_are_colored = false
		_check(
			world.is_trial_hell_active()
			and enemy_spawner.is_trial_hell_active()
			and trial_chunks_are_colored,
			"Trial Hell did not persist its unique palette on the infinite road."
		)
		_check(
			enemy_spawner.get_current_max_active_enemies()
				> normal_enemy_cap
			and enemy_spawner.get_current_spawn_interval(false)
				< normal_spawn_interval
			and trial_difficulty_enemy.max_health
				> normal_difficulty_enemy.max_health
			and trial_difficulty_enemy.melee_damage
				> normal_difficulty_enemy.melee_damage
			and trial_difficulty_enemy.melee_attack_interval
				< normal_difficulty_enemy.melee_attack_interval,
			"Trial Hell did not increase enemy density and combat pressure."
		)
		game.call(
			"_on_route_committed",
			committed_center,
			"左侧无尽岔路"
		)
		_check(
			not world.is_trial_hell_active()
			and not enemy_spawner.is_trial_hell_active(),
			"Returning to a normal branch did not clear Trial Hell modifiers."
		)
		if trial_fork != null:
			trial_fork.queue_free()
		normal_difficulty_enemy.queue_free()
		trial_difficulty_enemy.queue_free()
		road_fork.queue_free()
	await _wait_process_frames(2)
	player.global_position.x = world.get_route_center_x()

	resources.reset_resources()
	resources.set_process(false)
	var combat_enemy := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	combat_enemy.player = player
	combat_enemy.max_health = 99
	combat_enemy.cruise_speed = 1.0
	combat_enemy.melee_attack_interval = 0.1
	combat_enemy.melee_windup_duration = 0.6
	root.add_child(combat_enemy)
	combat_enemy.global_position = player.global_position + Vector2(0.0, -30.0)
	var lifespan_before_enemy_attack := resources.current_lifespan
	await _wait_physics_frames(10)
	_check(
		is_equal_approx(
			resources.current_lifespan,
			lifespan_before_enemy_attack
		),
		"Enemy melee dealt damage before its wind-up completed."
	)
	_check(
		combat_enemy.is_threat_indicator_visible()
		and combat_enemy.is_attack_winding_up()
		and combat_enemy.attack_warning_label.visible,
		"Nearby enemy did not expose its range and active wind-up warning."
	)
	var early_windup_progress := combat_enemy.get_attack_windup_progress()
	await _wait_physics_frames(8)
	_check(
		combat_enemy.get_attack_windup_progress() > early_windup_progress,
		"Enemy melee warning did not visibly advance toward its strike."
	)
	combat_enemy.global_position = (
		player.global_position
		+ Vector2(combat_enemy.melee_attack_range + 24.0, 0.0)
	)
	await _wait_physics_frames(70)
	_check(
		is_equal_approx(
			resources.current_lifespan,
			lifespan_before_enemy_attack
		),
		"Escaping the announced enemy threat range did not dodge the strike."
	)
	combat_enemy.global_position = player.global_position + Vector2(0.0, -30.0)
	await _wait_physics_frames(48)
	_check(
		resources.current_lifespan < lifespan_before_enemy_attack,
		"Enemy melee did not deal lifespan damage after its warning completed."
	)
	_check(
		float(combat_enemy.get("_attack_flash_remaining")) > 0.0,
		"Enemy melee attack did not expose a visible attack flash."
	)
	_check(
		player.is_damage_feedback_active()
		and player.damage_taken_label.visible
		and player.damage_taken_label.text.contains("寿元"),
		"Taking direct damage did not show the player hit reaction and loss."
	)
	_check(
		hud.is_damage_flash_active(),
		"Taking direct damage did not flash the HUD screen edge."
	)
	combat_enemy.queue_free()
	await _wait_process_frames(2)

	var danger_lifespan := resources.max_lifespan * 0.14
	resources.apply_lifespan_damage(
		resources.current_lifespan - danger_lifespan
	)
	await _wait_process_frames(2)
	_check(
		hud.is_danger_warning_active()
		and hud.danger_border.visible
		and hud.danger_warning_label.visible
		and hud.lifespan_label.modulate.r > hud.lifespan_label.modulate.g,
		"Below-fifteen-percent lifespan did not activate the danger warning."
	)
	resources.restore_lifespan(resources.max_lifespan)
	await _wait_process_frames(2)
	_check(
		not hud.is_danger_warning_active()
		and not hud.danger_border.visible
		and not hud.danger_warning_label.visible,
		"Restoring lifespan above fifteen percent did not clear the warning."
	)

	var player_target := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	player_target.player = player
	player_target.max_health = 2
	player_target.cruise_speed = 1.0
	player_target.melee_attack_interval = 10.0
	root.add_child(player_target)
	player_target.global_position = player.global_position + Vector2(0.0, -30.0)
	await _wait_physics_frames(100)
	_check(
		not is_instance_valid(player_target)
		or not player_target.is_combat_active(),
		"Player automatic melee did not defeat a nearby enemy."
	)

	var weapon_pickup := preload(
		"res://game/scenes/gameplay/weapon_pickup.tscn"
	).instantiate() as WeaponPickup
	weapon_pickup.configure(
		FLYING_SWORD_DATA,
		6,
		Vector2.ZERO,
		player
	)
	var equipped_before_pickup := player.get_current_weapon_data()
	var inventory_size_before_pickup := (
		player.get_equipment_inventory_entries().size()
	)
	root.add_child(weapon_pickup)
	weapon_pickup.global_position = player.global_position
	await _wait_physics_frames(70)
	_check(
		player.get_current_weapon_data() == equipped_before_pickup
		and player.get_equipment_inventory_entries().size()
			== inventory_size_before_pickup + 1,
		"Collected weapon did not enter inventory while preserving equipment."
	)
	player.cycle_equipment()
	_check(
		player.get_weapon_name() == "飞剑",
		"Tab-style cycling did not equip the collected ranged weapon."
	)
	var level_one_sword_damage := player.get_current_weapon_damage()
	_check(
		level_one_sword_damage == 6,
		"Collected weapon did not retain its rolled damage."
	)
	_check(
		hud.weapon_label.text == (
			"当前装备  飞剑  · 伤害 %d" % level_one_sword_damage
		),
		"HUD did not update after equipping a weapon drop."
	)
	_check(
		player.collect_weapon(FLYING_SWORD_DATA, 5)
		and player.get_current_weapon_damage() == level_one_sword_damage
		and player.get_flying_sword_projectile_count() == 2,
		"Weaker duplicate weapon did not add quantity while preserving damage."
	)
	var level_one_sword_range := player.get_current_attack_range()
	resources.add_qi(resources.get_current_qi_requirement())
	_check(
		player.get_flying_sword_projectile_count() == 2
		and player.get_current_weapon_damage() == level_one_sword_damage
		and is_equal_approx(
			player.get_global_combat_stats().global_damage_bonus,
			0.0
		)
		and is_equal_approx(
			player.get_current_attack_range(),
			level_one_sword_range
		),
		"Small-level cultivation incorrectly changed non-Palm weapon stats."
	)
	var flying_target := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	flying_target.player = player
	flying_target.max_health = 99
	flying_target.cruise_speed = 1.0
	root.add_child(flying_target)
	flying_target.global_position = (
		player.global_position + Vector2(0.0, -80.0)
	)
	await _wait_physics_frames(70)
	_check(
		flying_target.current_health < 99,
		"Base Flying Sword did not launch its single projectile."
	)
	flying_target.queue_free()
	await _wait_process_frames(2)

	_check(
		player.collect_weapon(DAO_DATA, 4),
		"First dao was not added to the equipment library."
	)
	player.cycle_equipment()
	_check(
		player.get_dao_orbit_count() == 1
		and player.get_visible_companion_weapon_count() == 1
		and is_equal_approx(
			player.get_current_attack_range(),
			DAO_DATA.attack_range
		),
		"Dao did not retain its base single-orbit behavior."
	)
	var dao_target := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	dao_target.player = player
	dao_target.max_health = 99
	dao_target.cruise_speed = 1.0
	root.add_child(dao_target)
	dao_target.global_position = (
		player.global_position + Vector2(0.0, -70.0)
	)
	await _wait_physics_frames(120)
	_check(
		dao_target.current_health < 99,
		"Dao orbit attack did not damage a nearby enemy."
	)
	dao_target.queue_free()
	await _wait_process_frames(2)

	var slow_ring_data := QIANKUN_RING_DATA.duplicate() as WeaponDataResource
	slow_ring_data.attack_interval = 10.0
	var ring_pickup := preload(
		"res://game/scenes/gameplay/weapon_pickup.tscn"
	).instantiate() as WeaponPickup
	ring_pickup.configure(
		slow_ring_data,
		5,
		Vector2.ZERO,
		player
	)
	root.add_child(ring_pickup)
	ring_pickup.global_position = player.global_position
	await _wait_physics_frames(70)
	_check(
		player.get_weapon_name() == "刀",
		"Universe Ring pickup unexpectedly changed the equipped weapon."
	)
	player.cycle_equipment()
	var ring_damage := player.get_current_weapon_damage()
	_check(
		player.get_weapon_name() == "乾坤圈"
		and ring_damage == 5
		and player.get_qiankun_ring_bounce_count() == 2,
		"Universe Ring did not retain its fixed bounce count."
	)
	var ring_target := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	ring_target.player = player
	ring_target.max_health = 99
	ring_target.cruise_speed = 1.0
	root.add_child(ring_target)
	ring_target.global_position = (
		player.global_position + Vector2(0.0, -70.0)
	)
	await _wait_physics_frames(70)
	_check(
		ring_target.current_health <= 99 - ring_damage,
		"Base Universe Ring did not deal constant damage before returning."
	)
	ring_target.queue_free()
	_check(
		not player.is_qiankun_ring_in_flight()
		and player.get_visible_companion_weapon_count() == 1,
		"Universe Ring did not return as the single companion weapon."
	)
	await _wait_process_frames(2)

	var tab_press := InputEventKey.new()
	tab_press.keycode = KEY_TAB
	tab_press.physical_keycode = KEY_TAB
	tab_press.pressed = true
	Input.parse_input_event(tab_press)
	await _wait_process_frames(2)
	var tab_release := InputEventKey.new()
	tab_release.keycode = KEY_TAB
	tab_release.physical_keycode = KEY_TAB
	tab_release.pressed = false
	Input.parse_input_event(tab_release)
	_check(
		player.get_weapon_name() == "大力掌",
		"Tab did not cycle to the next equipment-library entry."
	)
	_check(
		hud.equipment_library_label.text.contains("刀 ×1  伤害 4")
			and hud.equipment_library_label.text.contains("飞剑 ×2  伤害 6")
			and hud.equipment_library_label.text.contains(
				"乾坤圈 ×1  伤害 5"
			),
			"HUD equipment library mismatch: %s"
				% hud.equipment_library_label.text
		)

	var realm_config := resources.realm_progression_config
	_check(
		realm_config != null
		and realm_config.get_realm_count() == 4
		and realm_config.get_realm(0).display_name == "练气"
		and realm_config.get_realm(1).display_name == "筑基"
		and realm_config.get_realm(2).display_name == "金丹"
		and realm_config.get_realm(3).display_name == "元婴"
		and realm_config.get_total_levels() == 36,
		"Realm configuration did not define four ordered nine-layer realms."
	)
	_check(
		not realm_config.get_realm(0).melee_weapons_only
		and realm_config.get_realm(1).qi_shield_enabled
		and realm_config.get_realm(1).locomotion_mode
			== RealmDefinition.LocomotionMode.TEMPORARY_FLIGHT
		and realm_config.get_realm(2).locomotion_mode
			== RealmDefinition.LocomotionMode.FLIGHT
		and realm_config.get_realm(3).spirit_projection_enabled
		and realm_config.get_realm(3).fatal_breakthrough
		and realm_config.get_realm(0).tribulation_strike_count == 3
		and realm_config.get_realm(1).tribulation_strike_count == 6
		and realm_config.get_realm(2).tribulation_strike_count == 12
		and realm_config.get_realm(3).tribulation_strike_count == 1,
		"Realm capability progression did not match the design contract."
	)
	var player_shadow := player.get_node("PlayerShadow") as PlayerShadow
	_check(
		player_shadow != null
		and is_zero_approx(player_shadow.get_elevation()),
		"Grounded Qi Refining player did not keep a ground-contact shadow."
	)

	resources.demote_to_realm(0, 9)
	var lifespan_before_tribulation := resources.current_lifespan
	var maximum_before_tribulation := resources.max_lifespan
	var decay_before_tribulation := (
		resources.get_current_lifespan_decay_rate()
	)
	resources.add_qi(resources.get_current_qi_requirement())
	await _wait_process_frames(2)
	var tribulation_nodes := get_nodes_in_group("heavenly_tribulations")
	var qi_tribulation_warning_min := 0.0
	var qi_tribulation_warning_max := 0.0
	_check(
		tribulation_nodes.size() == 1,
		"Attempting to leave Qi Refining layer nine did not start tribulation."
	)
	if not tribulation_nodes.is_empty():
		var tribulation := tribulation_nodes[0] as HeavenlyTribulation
		qi_tribulation_warning_min = tribulation.warning_duration_min
		qi_tribulation_warning_max = tribulation.warning_duration_max
		_check(
			tribulation.strike_count == 3
			and tribulation.warning_label.visible
			and is_equal_approx(qi_tribulation_warning_min, 2.1)
			and is_equal_approx(qi_tribulation_warning_max, 3.0),
			"Qi Refining tribulation did not use three strikes and triple warning time."
		)
		_check(
			is_equal_approx(
				tribulation.get_current_strike_damage(),
				maxf(
					tribulation.strike_damage,
					maximum_before_tribulation
						* tribulation.maximum_lifespan_damage_ratio
				)
			)
			and is_equal_approx(
				tribulation.get_strike_damage_for_maximum_lifespan(354.0),
				14.16
			),
			"Tribulation damage did not use its 12-point or four-percent maximum."
		)
		tribulation.warning_duration_min = 0.03
		tribulation.warning_duration_max = 0.03
		tribulation.flash_duration = 0.02
		tribulation.inter_strike_delay = 0.01
		tribulation.random_landing_offset = 0.0
		tribulation.strike_damage = 1.0
		tribulation.maximum_lifespan_damage_ratio = 0.0
		# The first warning was prepared before the smoke test shortened the
		# exported durations, so shorten that already-active phase as well.
		tribulation.set("_warning_duration", 0.03)
		tribulation.set("_phase_time_remaining", 0.03)
		_thunder_strikes_landed = 0
		_thunder_strikes_hit = 0
		_tribulation_completions = 0
		tribulation.strike_landed.connect(_on_thunder_strike_landed)
		tribulation.tribulation_completed.connect(
			_on_test_tribulation_completed
		)
		await _wait_physics_frames(150)
		_check(
			_thunder_strikes_landed == 3
			and _thunder_strikes_hit == 3,
			"Standing on the predicted path did not receive all three strikes."
		)
		_check(
			_tribulation_completions == 1,
			"Three lightning strikes did not complete the tribulation."
		)
		_check(
			player.is_breakthrough_effect_active(),
			"Successful realm breakthrough did not start its grand effect."
		)
		_check(
			is_equal_approx(
				resources.max_lifespan,
				minf(
					maximum_before_tribulation
						+ resources.level_up_maxHP_increase
						+ resources.breakthrough_max_lifespan_increase,
					resources.maximum_lifespan_cap
				)
			)
			and is_equal_approx(
				resources.current_lifespan,
				minf(
					lifespan_before_tribulation
						- 3.0
						+ resources.max_lifespan
							* resources.breakthrough_lifespan_restore_ratio,
					resources.max_lifespan
				)
			),
			"Breakthrough did not add bounded maximum lifespan and restore half."
		)
		_check(
			resources.get_current_lifespan_decay_rate()
				> decay_before_tribulation,
			"Breakthrough did not increase passive lifespan pressure."
		)
		_check(
			resources.breakthroughs_completed == 1,
			"First tribulation completion was not recorded."
		)
		_check(
			resources.get_current_realm_index() == 1
			and resources.get_current_realm_layer() == 1
			and player.realm_abilities.is_qi_shield_enabled()
			and player.realm_abilities.is_temporary_flight_active(),
			"Entering Foundation did not automatically demonstrate temporary flight."
		)
		for _frame in 120:
			if not player.realm_abilities.is_temporary_flight_active():
				break
			await physics_frame
		_check(
			player.realm_abilities.start_temporary_flight(),
			"Foundation Space action did not start another temporary flight."
		)
		await _wait_physics_frames(15)
		var rising_elevation := (
			player.realm_abilities.get_current_flight_elevation()
		)
		_check(
			rising_elevation > 0.0
			and rising_elevation
				< realm_config.get_realm(1).flight_height
			and is_equal_approx(
				player_shadow.get_elevation(),
				rising_elevation
			)
			and character_sprite.position.y < -1.0
			and character_sprite.scale.x > grounded_character_scale.x
			and character_sprite.animation == &"fly"
			and character_sprite.z_index > 4,
			"Foundation temporary flight did not rise progressively."
		)
		var holding_snapshot := player.realm_abilities.get_debug_snapshot()
		for _frame in 45:
			if holding_snapshot["temporary_flight_phase"] == &"holding":
				break
			await physics_frame
			holding_snapshot = player.realm_abilities.get_debug_snapshot()
		_check(
			holding_snapshot["temporary_flight_phase"] == &"holding"
			and is_equal_approx(
				player.realm_abilities.get_current_flight_elevation(),
				realm_config.get_realm(1).flight_height
			),
			"Foundation temporary flight did not hold its maximum height."
		)
		await _wait_physics_frames(120)
		_check(
			not player.realm_abilities.is_temporary_flight_active()
			and is_zero_approx(
				player.realm_abilities.get_current_flight_elevation()
			)
			and is_zero_approx(player_shadow.get_elevation())
			and character_sprite.scale.is_equal_approx(
				grounded_character_scale
			)
			and character_sprite.animation == &"walk"
			and character_sprite.z_index < 4,
			"Foundation temporary flight did not descend and land."
		)

		resources.current_qi = 8
		var lifespan_before_shield := resources.current_lifespan
		var qi_refining_enemy := preload(
			"res://game/scenes/gameplay/enemy.tscn"
		).instantiate() as EnemyController
		qi_refining_enemy.player = player
		get_root().add_child(qi_refining_enemy)
		qi_refining_enemy.global_position = (
			player.global_position + Vector2(0.0, 180.0)
		)
		await _wait_process_frames(1)
		qi_refining_enemy.set_combat_enabled(false)
		player.take_melee_damage(3.0, qi_refining_enemy)
		_check(
			resources.current_qi == 8
			and is_equal_approx(
				resources.current_lifespan,
				lifespan_before_shield
			),
			"Qi Refining enemy damaged a Foundation-realm player."
		)
		qi_refining_enemy.queue_free()
		player.take_melee_damage(3.0)
		_check(
			resources.current_qi == 5
			and is_equal_approx(
				resources.current_lifespan,
				lifespan_before_shield
			),
			"Foundation Qi shield did not spend Qi to absorb damage."
		)

		for source_realm_index in [1, 2]:
			resources.demote_to_realm(source_realm_index, 9)
			resources.current_lifespan = 50.0
			var transition_maximum_before := resources.max_lifespan
			resources.add_qi(resources.get_current_qi_requirement())
			await _wait_process_frames(2)
			var repeat_tribulation := (
				game.get("_active_tribulation") as HeavenlyTribulation
			)
			_check(
				repeat_tribulation != null,
				"Realm layer nine did not request its normal tribulation."
			)
			if repeat_tribulation == null:
				continue
			var expected_strike_count := (
				6 if source_realm_index == 1 else 12
			)
			var expected_warning_ratio := (
				0.75 if source_realm_index == 1 else 0.35
			)
			_check(
				repeat_tribulation.strike_count == expected_strike_count
				and is_equal_approx(
					repeat_tribulation.warning_duration_min,
					qi_tribulation_warning_min
						* expected_warning_ratio
				)
				and is_equal_approx(
					repeat_tribulation.warning_duration_max,
					qi_tribulation_warning_max
						* expected_warning_ratio
				),
				"Realm tribulation did not use its configured strike count and warning ratio."
			)
			repeat_tribulation.cancel()
			game.call("_on_heavenly_tribulation_completed")
			await _wait_process_frames(2)
			var expected_transition_maximum := minf(
				transition_maximum_before
					+ resources.level_up_maxHP_increase
					+ resources.breakthrough_max_lifespan_increase,
				resources.maximum_lifespan_cap
			)
			var expected_transition_lifespan := minf(
				50.0
					+ expected_transition_maximum
						* resources.breakthrough_lifespan_restore_ratio,
				expected_transition_maximum
			)
			_check(
				is_equal_approx(
					resources.max_lifespan,
					expected_transition_maximum
				)
				and absf(
					resources.current_lifespan
						- expected_transition_lifespan
				) < 0.25
				and resources.breakthroughs_completed
					== source_realm_index + 1,
				"Realm transition did not grant maximum lifespan and restoration."
			)
			if source_realm_index == 1:
				var golden_core_elevation := (
					player.realm_abilities.get_current_flight_elevation()
				)
				await _wait_physics_frames(10)
				_check(
					resources.get_current_realm_index() == 2
					and golden_core_elevation > 0.0
					and is_equal_approx(
						golden_core_elevation,
						player.realm_abilities
							.get_current_flight_elevation()
					)
					and not player.realm_abilities
						.is_temporary_flight_active()
					and character_sprite.animation == &"fly"
					and character_sprite.z_index > 4,
					"Golden Core did not maintain continuous flight."
				)

		_check(
			resources.get_current_realm_index() == 3
			and resources.get_current_realm_layer() == 1
			and player.realm_abilities.get_debug_snapshot()[
				"flight_height"
			] > 0.0
			and player_shadow.get_elevation() > 0.0,
			"Golden Core and Nascent Soul transitions did not unlock flight."
		)
		_check(
			player.realm_abilities.toggle_spirit_projection()
			and is_equal_approx(
				player.realm_abilities.get_outgoing_damage_multiplier(),
				2.0
			),
			"Nascent Soul Space stance did not enable 200-percent power."
		)
		resources.current_qi = 0
		player.take_melee_damage(1.0)
		_check(
			resources.get_current_realm_index() == 2
			and resources.get_current_realm_layer() == 9
			and not player.realm_abilities.is_spirit_projection_active(),
			"Taking damage during spirit projection did not fall to Golden Core."
		)
		resources.current_lifespan = 50.0
		var repeated_nascent_soul_maximum_before := resources.max_lifespan
		resources.add_qi(resources.get_current_qi_requirement())
		await _wait_process_frames(2)
		var repeated_nascent_soul_tribulation := (
			game.get("_active_tribulation") as HeavenlyTribulation
		)
		_check(
			repeated_nascent_soul_tribulation != null,
			"Re-entering Nascent Soul did not request a tribulation."
		)
		if repeated_nascent_soul_tribulation != null:
			repeated_nascent_soul_tribulation.cancel()
			game.call("_on_heavenly_tribulation_completed")
			await _wait_process_frames(2)
			var expected_repeated_maximum := minf(
				repeated_nascent_soul_maximum_before
					+ resources.level_up_maxHP_increase
					+ resources.breakthrough_max_lifespan_increase,
				resources.maximum_lifespan_cap
			)
			var expected_repeated_lifespan := minf(
				50.0
					+ expected_repeated_maximum
						* resources.breakthrough_lifespan_restore_ratio,
				expected_repeated_maximum
			)
			_check(
				resources.get_current_realm_index() == 3
				and resources.breakthroughs_completed == 4
				and is_equal_approx(
					resources.max_lifespan,
					expected_repeated_maximum
				)
				and absf(
					resources.current_lifespan
						- expected_repeated_lifespan
				) < 0.25,
				"Repeat Nascent Soul breakthrough did not grant its lifespan reward."
			)

		resources.demote_to_realm(3, 9)
		resources.add_qi(resources.get_current_qi_requirement())
		await _wait_process_frames(2)
		var annihilation := game.get("_active_annihilation") as RealmAnnihilation
		_check(
			annihilation != null
			and resources.is_pending_breakthrough_fatal()
			and realm_config.get_realm(3).tribulation_strike_count == 1,
			"Nascent Soul layer-nine breakthrough did not start fatal strike."
		)
		if annihilation != null:
			annihilation.set("_remaining", 0.01)
			await _wait_process_frames(4)
		_check(
			not resources.is_run_active()
			and end_overlay.visible
			and end_overlay.title_label.text.contains("突破陨落"),
			"Fatal Nascent Soul breakthrough did not end the run."
		)

	game.call("_on_restart_requested")
	await _wait_process_frames(5)
	_check(
		current_scene != null and current_scene.name == "Game",
		"Restart did not reload gameplay."
	)
	var restarted_resources := current_scene.get_node("RunResources") as RunResources
	var restarted_player := current_scene.get_node("Player") as PlayerController
	var restarted_overlay := (
		current_scene.get_node("RunEndedOverlay") as RunEndedOverlay
	)
	_check(
		absf(restarted_resources.current_lifespan - 180.0) < 0.5,
		"Restart did not create a clean resource state."
	)
	_check(
		get_root().get_node_or_null("Game") == current_scene,
		"Restart left a duplicate gameplay root."
	)

	restarted_resources.apply_lifespan_damage(1000.0)
	await _wait_process_frames(2)
	_check(
		not restarted_resources.is_run_active(),
		"Run resources remained active at zero."
	)
	_check(
		restarted_overlay.visible
		and restarted_overlay.title_label.text == "Lifespan Depleted",
		"Lifespan depletion did not display the defeat outcome."
	)
	var ended_position := restarted_player.global_position
	await _wait_physics_frames(4)
	_check(
		restarted_player.global_position.is_equal_approx(ended_position),
		"Player movement continued after lifespan depletion."
	)
	current_scene.call("_on_main_menu_requested")
	await _wait_process_frames(5)
	_check(not paused, "Run-ended Main Menu left the tree paused.")
	_check(
		current_scene != null and current_scene.name == "MainMenu",
		"Run-ended Main Menu did not open the existing menu."
	)

	if _failures.is_empty():
		print("GAMEPLAY LOOP TEST: PASS")
		quit(0)
	else:
		print("GAMEPLAY LOOP TEST: FAIL (%d failures)" % _failures.size())
		quit(1)


func _on_isolated_level_up(_level: int, _restore: float) -> void:
	_levels_emitted += 1


func _on_isolated_pickup_collected(amount: int) -> void:
	_pickup_emissions += 1
	_last_pickup_value = amount


func _on_isolated_depleted() -> void:
	_depletion_emissions += 1


func _on_thunder_strike_landed(
	_strike_index: int,
	hit_player: bool
) -> void:
	_thunder_strikes_landed += 1
	if hit_player:
		_thunder_strikes_hit += 1


func _on_test_tribulation_completed() -> void:
	_tribulation_completions += 1
