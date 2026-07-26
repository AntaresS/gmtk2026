extends SceneTree

const PLAYER_SCENE := preload("res://game/scenes/gameplay/player.tscn")
const ENEMY_SCENE := preload("res://game/scenes/gameplay/enemy.tscn")
const WEAPON_PICKUP_SCENE := preload(
	"res://game/scenes/gameplay/weapon_pickup.tscn"
)
const DAO_DATA := preload("res://game/resources/weapon/dao.tres")
const FLYING_SWORD_DATA := preload(
	"res://game/resources/weapon/flying_sword.tres"
)
const THUNDER_HAMMER_DATA := preload(
	"res://game/resources/weapon/thunder_hammer.tres"
)
const FANTIAN_SEAL_DATA := preload(
	"res://game/resources/weapon/fantian_seal.tres"
)
const PALM_DATA := preload("res://game/resources/great_strength_palm.tres")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("LATEST WEAPON TEST: %s" % message)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _make_enemy(
	player: PlayerController,
	position: Vector2,
	health: int = 99
) -> EnemyController:
	var enemy := ENEMY_SCENE.instantiate() as EnemyController
	enemy.player = player
	enemy.max_health = health
	enemy.cruise_speed = 1.0
	enemy.melee_attack_interval = 99.0
	root.add_child(enemy)
	enemy.global_position = position
	return enemy


func _run() -> void:
	var resources := RunResources.new()
	root.add_child(resources)
	resources.set_process(false)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(5000.0, 5000.0)
	player.set_movement_enabled(false)
	player.bind_cultivation(resources)
	resources.cultivation_level_changed.connect(player.apply_cultivation_level)

	var base_interval := player.get_current_attack_interval()
	var base_damage := player.get_current_weapon_damage()
	var base_range := player.get_current_attack_range()
	var base_lateral_speed := player.get_effective_lateral_speed()
	var base_acceleration := player.get_effective_forward_acceleration()
	var base_boost := player.get_boosted_speed_target()
	var base_slow := player.get_slowed_speed_target()
	player.apply_universal_upgrade(
		UniversalUpgradeTypes.UpgradeType.ATTACK_SPEED
	)
	player.apply_universal_upgrade(UniversalUpgradeTypes.UpgradeType.DAMAGE)
	player.apply_universal_upgrade(UniversalUpgradeTypes.UpgradeType.MOVEMENT)
	player.apply_universal_upgrade(
		UniversalUpgradeTypes.UpgradeType.DAMAGE_RANGE
	)
	player.apply_universal_upgrade(
		UniversalUpgradeTypes.UpgradeType.SPEED_CONTROL,
		20
	)
	_check(
		player.get_current_attack_interval() < base_interval
		and player.get_current_weapon_damage() > base_damage
		and player.get_current_attack_range() > base_range
		and player.get_effective_lateral_speed() > base_lateral_speed
		and player.get_effective_forward_acceleration() > base_acceleration
		and player.get_boosted_speed_target() > base_boost
		and player.get_slowed_speed_target() < base_slow
		and is_equal_approx(
			player.get_slowed_speed_target(),
			player.minimum_controlled_speed
		),
		"Five universal fragments did not affect their shared combat/movement stats."
	)
	_check(
		player.get_universal_upgrade_snapshot().size()
			== UniversalUpgradeTypes.COUNT,
		"Universal fragment state is not exposed for a future debug panel."
	)
	var dao_player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(dao_player)
	dao_player.set_movement_enabled(false)
	dao_player.collect_weapon(DAO_DATA, DAO_DATA.minimum_damage)
	_check(
		dao_player.select_weapon_slot(0),
		"Dao could not be selected for level-progression validation."
	)
	var dao_level_one_damage := dao_player.get_current_weapon_damage()
	for _level in 9:
		dao_player.collect_weapon(DAO_DATA, DAO_DATA.minimum_damage)
	var dao_level_ten_range := (
		DAO_DATA.attack_range
		+ DAO_DATA.attack_range_increase_per_level * 9.0
	)
	_check(
		dao_player.get_current_delivery_count() == 10
		and is_equal_approx(
			dao_player.get_current_attack_range(),
			dao_level_ten_range
		)
		and dao_player.get_current_weapon_damage() == dao_level_one_damage
		and dao_player.attack_shape.shape is CircleShape2D
		and is_equal_approx(
			(dao_player.attack_shape.shape as CircleShape2D).radius,
			dao_level_ten_range
		)
		and is_equal_approx(
			dao_player.get_dao_orbit_radius(9)
				+ dao_player.get_dao_weapon_tip_length(),
			dao_level_ten_range
		),
		"Dao Lv.10 range, orbit, collision, and preview radius diverged."
	)
	dao_player.collect_weapon(DAO_DATA, DAO_DATA.minimum_damage)
	var dao_level_eleven_damage := roundi(
		float(dao_level_one_damage)
			* (1.0 + DAO_DATA.damage_ratio_per_level_above_range_cap)
	)
	var dao_inventory_snapshot := dao_player.get_equipment_inventory_snapshot()
	var dao_owned_count := 0
	for equipment_snapshot in dao_inventory_snapshot:
		if (
			(equipment_snapshot["data"] as WeaponData).weapon_id
			== DAO_DATA.weapon_id
		):
			dao_owned_count = int(equipment_snapshot["quantity"])
			break
	_check(
		dao_player.get_current_delivery_count() == 10
		and dao_player.get_dao_orbit_count() == 10
		and dao_owned_count == 11
		and is_equal_approx(
			dao_player.get_current_attack_range(),
			dao_level_ten_range
		)
		and is_equal_approx(
			dao_player.get_dao_orbit_radius(10),
			dao_player.get_dao_orbit_radius(9)
		)
		and dao_player.get_current_weapon_damage() == dao_level_eleven_damage,
		"Post-cap Dao created an eleventh blade, expanded its base range, or missed its +10% damage conversion."
	)
	dao_player.apply_universal_upgrade(
		UniversalUpgradeTypes.UpgradeType.DAMAGE_RANGE
	)
	var dao_fragment_range := (
		dao_level_ten_range
		* (1.0 + dao_player.range_bonus_per_fragment)
	)
	var dao_inner_fragment_boundary := (
		DAO_DATA.attack_range
		* dao_fragment_range
		/ dao_level_ten_range
	)
	_check(
		dao_player.get_current_delivery_count() == 10
		and is_equal_approx(
			dao_player.get_current_attack_range(),
			dao_fragment_range
		)
		and is_equal_approx(
			(dao_player.attack_shape.shape as CircleShape2D).radius,
			dao_fragment_range
		)
		and is_equal_approx(
			dao_player.get_dao_orbit_radius(9)
				+ dao_player.get_dao_weapon_tip_length(),
			dao_fragment_range
		)
		and is_equal_approx(
			dao_player.get_dao_orbit_radius(0)
				+ dao_player.get_dao_weapon_tip_length(),
			dao_inner_fragment_boundary
		),
		"Range fragment did not expand Dao collision and all capped orbit paths together."
	)
	dao_player.queue_free()
	var ring_player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(ring_player)
	ring_player.global_position = Vector2(7000.0, 7000.0)
	ring_player.set_movement_enabled(false)
	ring_player.collect_weapon(
		preload("res://game/resources/weapon/qiankun_ring.tres"),
		5
	)
	_check(
		ring_player.select_weapon_slot(0),
		"Universe Ring could not be selected from weapon slot 1."
	)
	var fixed_ring_damage := ring_player.get_current_weapon_damage()
	ring_player.apply_universal_upgrade(
		UniversalUpgradeTypes.UpgradeType.DAMAGE,
		2
	)
	_check(
		ring_player.get_current_weapon_damage() == fixed_ring_damage
		and ring_player.get_qiankun_ring_bounce_count() == 4,
		"Damage fragments did not convert into Ring bounces at fixed damage."
	)
	ring_player.queue_free()

	var palm_damage_before_level := player.get_current_weapon_damage()
	var palm_range_before_level := player.get_current_attack_range()
	var palm_interval_before_level := player.get_current_attack_interval()
	resources.add_qi(resources.get_current_qi_requirement())
	_check(
		player.get_current_weapon_damage() > palm_damage_before_level
		and player.get_current_attack_range() > palm_range_before_level
		and player.get_current_attack_interval() < palm_interval_before_level,
		"One small cultivation level did not improve Palm damage/range/frequency."
	)

	resources.demote_to_realm(0, 1)
	_check(
		int(player.call("_get_palm_direction_count")) == 1
		and not bool(player.call("_is_palm_full_circle")),
		"Qi Refining Palm did not keep one direction."
	)
	var palm_edge_target := _make_enemy(
		player,
		player.get_combat_anchor_position()
			+ Vector2(player.get_current_attack_range() + 19.0, 0.0),
		99
	)
	var palm_outside_target := _make_enemy(
		player,
		player.get_combat_anchor_position()
			+ Vector2(player.get_current_attack_range() + 21.0, 0.0),
		99
	)
	palm_edge_target.set_physics_process(false)
	palm_outside_target.set_physics_process(false)
	player.call(
		"_release_great_strength_palm",
		palm_edge_target,
		AttackDamageResult.new(5, false)
	)
	await _wait_physics_frames(10)
	_check(
		palm_edge_target.current_health == 94
		and palm_outside_target.current_health == 99,
		"Palm did not honor the enemy collider at its outer range boundary."
	)
	await _wait_physics_frames(10)
	palm_edge_target.queue_free()
	palm_outside_target.queue_free()
	resources.demote_to_realm(1, 1)
	_check(
		int(player.call("_get_palm_direction_count")) == 1
		and not bool(player.call("_is_palm_full_circle")),
		"Foundation Palm did not keep one nearest-target direction."
	)
	var foundation_visual_target := _make_enemy(
		player,
		player.get_combat_anchor_position() + Vector2(50.0, 0.0)
	)
	player.call(
		"_release_great_strength_palm",
		foundation_visual_target,
		AttackDamageResult.new(2, false)
	)
	_check(
		player.get_visible_palm_sprite_count() == 1,
		"Foundation Palm did not begin its nearest-target palms sequentially."
	)
	await _wait_physics_frames(30)
	foundation_visual_target.queue_free()
	var foundation_target := _make_enemy(
		player,
		player.get_combat_anchor_position() + Vector2(50.0, 0.0)
	)
	player.call(
		"_apply_palm_damage",
		foundation_target,
		AttackDamageResult.new(2, false)
	)
	_check(
		is_equal_approx(
			foundation_target.get_knockback_velocity().length(),
			320.0
		)
		and is_equal_approx(
			float(foundation_target.get("_knockback_recovery")),
			1800.0
		),
		"Foundation Palm did not apply its tuned 320 knockback."
	)
	foundation_target.queue_free()
	resources.demote_to_realm(2, 1)
	_check(
		int(player.call("_get_palm_direction_count")) == 1
		and not bool(player.call("_is_palm_full_circle"))
		and not bool(
			player.call(
				"_is_offset_in_palm_coverage",
				Vector2(0.0, player.get_current_attack_range() - 1.0),
				Vector2.UP
			)
		),
		"Golden Core Palm did not keep nearest-target directional coverage."
	)
	var golden_high_target := _make_enemy(
		player,
		player.get_combat_anchor_position() + Vector2(50.0, 0.0),
		100
	)
	player.call(
		"_apply_palm_damage",
		golden_high_target,
		AttackDamageResult.new(20, false)
	)
	_check(
		golden_high_target.current_health == 70
		and is_equal_approx(
			golden_high_target.get_knockback_velocity().length(),
			320.0
		),
		"Golden Core Palm did not apply +50% opener damage and retained knockback."
	)
	var golden_threshold_target := _make_enemy(
		player,
		player.get_combat_anchor_position() + Vector2(50.0, 0.0),
		100
	)
	golden_threshold_target.take_melee_damage(25)
	player.call(
		"_apply_palm_damage",
		golden_threshold_target,
		AttackDamageResult.new(20, false)
	)
	_check(
		golden_threshold_target.current_health == 55,
		"Golden Core Palm applied its opener at exactly 75% health."
	)
	golden_high_target.queue_free()
	golden_threshold_target.queue_free()
	var golden_front_target := _make_enemy(
		player,
		player.get_combat_anchor_position() + Vector2(50.0, 0.0),
		100
	)
	var golden_rear_target := _make_enemy(
		player,
		player.get_combat_anchor_position() + Vector2(-70.0, 0.0),
		100
	)
	golden_front_target.set_physics_process(false)
	golden_rear_target.set_physics_process(false)
	player.call(
		"_release_great_strength_palm",
		golden_front_target,
		AttackDamageResult.new(20, false)
	)
	_check(
		golden_front_target.current_health == 100
		and golden_rear_target.current_health == 100,
		"Golden Core Palm applied area damage before the hand impact."
	)
	_check(
		player.get_visible_palm_sprite_count() == 1,
		"Golden Core Palm did not begin its nearest-target sequence one palm at a time."
	)
	await _wait_physics_frames(10)
	_check(
		golden_front_target.current_health == 70
		and golden_rear_target.current_health == 100,
		"Golden Core Palm's first hand did not hit only the nearest enemy."
	)
	await _wait_physics_frames(50)
	_check(
		not golden_front_target.is_combat_active()
		and golden_rear_target.current_health == 70,
		"Later Golden Core palms did not retarget after defeating the nearest enemy."
	)
	golden_front_target.queue_free()
	golden_rear_target.queue_free()
	resources.demote_to_realm(3, 1)
	_check(
		int(player.call("_get_palm_direction_count")) == 1
		and not bool(player.call("_is_palm_full_circle")),
		"Nascent Soul Palm did not keep one nearest-target direction."
	)
	var nascent_visual_target := _make_enemy(
		player,
		player.get_combat_anchor_position() + Vector2(50.0, 0.0),
		100
	)
	nascent_visual_target.set_physics_process(false)
	player.call(
		"_release_great_strength_palm",
		nascent_visual_target,
		AttackDamageResult.new(1, false)
	)
	_check(
		player.get_visible_palm_sprite_count() == 1,
		"Nascent Soul Palm did not begin its nearest-target sequence one palm at a time."
	)
	await _wait_physics_frames(80)
	nascent_visual_target.queue_free()
	var execute_resources := RunResources.new()
	root.add_child(execute_resources)
	execute_resources.set_process(false)
	var execute_player := PLAYER_SCENE.instantiate() as PlayerController
	var execute_palm := PALM_DATA.duplicate(true) as WeaponData
	execute_palm.palm_execute_chance = 1.0
	execute_player.starting_weapon_data = execute_palm
	root.add_child(execute_player)
	execute_player.global_position = Vector2(8000.0, 8000.0)
	execute_player.set_movement_enabled(false)
	execute_player.bind_cultivation(execute_resources)
	execute_resources.demote_to_realm(3, 1)
	var nascent_target := _make_enemy(
		execute_player,
		execute_player.get_combat_anchor_position() + Vector2(50.0, 0.0),
		100
	)
	nascent_target.take_melee_damage(51)
	execute_player.call(
		"_apply_palm_damage",
		nascent_target,
		AttackDamageResult.new(1, false)
	)
	_check(
		not nascent_target.is_combat_active()
		and not get_nodes_in_group("palm_execute_vfx").is_empty(),
		"Nascent Soul Palm did not execute an eligible ordinary target below 50%."
	)
	var threshold_target := _make_enemy(
		execute_player,
		execute_player.get_combat_anchor_position() + Vector2(50.0, 0.0),
		100
	)
	threshold_target.take_melee_damage(50)
	execute_player.call(
		"_apply_palm_damage",
		threshold_target,
		AttackDamageResult.new(10, false)
	)
	_check(
		threshold_target.is_combat_active()
		and threshold_target.current_health == 40,
		"Nascent Soul Palm executed an ordinary target at exactly 50% health."
	)
	var palm_elite_target := _make_enemy(
		execute_player,
		execute_player.get_combat_anchor_position() + Vector2(50.0, 0.0),
		100
	)
	palm_elite_target.configure_elite(2.0, 1.2, 1.2)
	palm_elite_target.take_melee_damage(101)
	execute_player.call(
		"_apply_palm_damage",
		palm_elite_target,
		AttackDamageResult.new(1, false)
	)
	_check(
		palm_elite_target.is_combat_active()
		and palm_elite_target.current_health == 98,
		"Nascent Soul Palm executed an elite target."
	)
	var nascent_high_target := _make_enemy(
		execute_player,
		execute_player.get_combat_anchor_position() + Vector2(50.0, 0.0),
		100
	)
	execute_player.call(
		"_apply_palm_damage",
		nascent_high_target,
		AttackDamageResult.new(20, false)
	)
	_check(
		nascent_high_target.current_health == 70
		and is_equal_approx(
			nascent_high_target.get_knockback_velocity().length(),
			320.0
		),
		"Nascent Soul did not retain Golden opener damage and 320 knockback."
	)
	threshold_target.queue_free()
	palm_elite_target.queue_free()
	nascent_high_target.queue_free()
	execute_player.queue_free()
	execute_resources.queue_free()

	var pickup := WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
	pickup.configure(FLYING_SWORD_DATA, 6, Vector2.ZERO, player)
	root.add_child(pickup)
	pickup.global_position = player.get_reward_interaction_position()
	await _wait_physics_frames(30)
	_check(
		player.get_weapon_name() != "飞剑"
		and pickup.get_channel_progress() > 0.0
		and pickup.get_channel_progress() < 1.0,
		"Elite weapon was collected before one full second of synchronization."
	)
	await _wait_physics_frames(35)
	_check(
		player.get_weapon_name() != "飞剑"
		and player.get_equipment_inventory_snapshot().size() == 2,
		"Elite weapon was not collected without changing the equipped weapon."
	)
	_check(
		player.select_weapon_slot(0)
		and player.get_weapon_name() == "飞剑",
		"Flying Sword could not be selected from weapon slot 1."
	)

	player.collect_weapon(
		THUNDER_HAMMER_DATA,
		THUNDER_HAMMER_DATA.minimum_damage
	)
	player.collect_weapon(
		THUNDER_HAMMER_DATA,
		THUNDER_HAMMER_DATA.minimum_damage
	)
	_check(
		player.select_weapon_slot(1),
		"Thunder Hammer could not be selected from weapon slot 2."
	)
	_check(
		player.get_current_delivery_count() == 2,
		"Duplicate Thunder Hammer did not add one sequential cloud."
	)
	var thunder_acquisition_range_before_upgrade := (
		player.get_current_attack_range()
	)
	var thunder_cloud_radius_before_upgrade := player.get_current_aoe_radius()
	player.apply_universal_upgrade(
		UniversalUpgradeTypes.UpgradeType.DAMAGE_RANGE
	)
	_check(
		player.get_current_attack_range()
			> thunder_acquisition_range_before_upgrade
		and is_equal_approx(
			player.get_current_aoe_radius(),
			thunder_cloud_radius_before_upgrade
		)
		and is_equal_approx(
			player.get_current_aoe_radius(),
			THUNDER_HAMMER_DATA.base_aoe_radius
		),
		(
			"Thunder range upgrade did not exclusively expand acquisition "
			+ "(range=%.2f/%.2f, cloud=%.2f/%.2f)."
		) % [
			player.get_current_attack_range(),
			thunder_acquisition_range_before_upgrade,
			player.get_current_aoe_radius(),
			THUNDER_HAMMER_DATA.base_aoe_radius,
		]
	)
	var thunder_target := _make_enemy(
		player,
		player.get_combat_anchor_position() + Vector2(60.0, 0.0)
	)
	await _wait_physics_frames(2)
	await process_frame
	await process_frame
	_check(
		THUNDER_HAMMER_DATA.minimum_damage == 5
		and is_equal_approx(THUNDER_HAMMER_DATA.attack_interval, 2.0)
		and is_equal_approx(
			THUNDER_HAMMER_DATA.projectile_sequence_interval,
			0.2
		)
		and THUNDER_HAMMER_DATA.delivery_count_cap == 10
		and player.is_thunder_hammer_visual_equipped()
		and player.is_thunder_hammer_target_ready()
		and player.get_thunder_hammer_charge_ratio() > 0.99,
		(
			"Thunder Hammer tuning/readiness mismatch "
			+ "(damage=%d, cooldown=%.3f, gap=%.3f, cap=%d, "
			+ "equipped=%s, ready=%s, charge=%.3f)."
		) % [
			THUNDER_HAMMER_DATA.minimum_damage,
			THUNDER_HAMMER_DATA.attack_interval,
			THUNDER_HAMMER_DATA.projectile_sequence_interval,
			THUNDER_HAMMER_DATA.delivery_count_cap,
			player.is_thunder_hammer_visual_equipped(),
			player.is_thunder_hammer_target_ready(),
			player.get_thunder_hammer_charge_ratio(),
		]
	)
	player.velocity = Vector2(24.0, -260.0)
	player.call(
		"_begin_special_projectile_sequence",
		WeaponData.AttackKind.THUNDER_HAMMER,
		AttackDamageResult.new(5, false, 5.0)
	)
	var resolved_thunder_sequence_interval := float(
		player.get("_special_sequence_interval")
	)
	var cooldown_after_first_cloud := float(
		player.get("_attack_cooldown_remaining")
	)
	var volley_discharge_visible := (
		player.get_thunder_hammer_discharge_strength() > 0.0
	)
	player.call("_launch_next_special_projectile")
	var cooldown_after_final_cloud := float(
		player.get("_attack_cooldown_remaining")
	)
	var cloud_count := 0
	var spawned_clouds: Array[ThunderCloudProjectile] = []
	for node in root.get_children():
		if node is ThunderCloudProjectile:
			cloud_count += 1
			spawned_clouds.append(node as ThunderCloudProjectile)
	var first_cloud_start := (
		spawned_clouds[0].global_position
		if not spawned_clouds.is_empty()
		else Vector2.ZERO
	)
	await _wait_physics_frames(35)
	_check(
		cloud_count == 2
		and thunder_target.current_health <= 89
		and THUNDER_HAMMER_DATA.base_aoe_radius >= 112.0
		and is_equal_approx(resolved_thunder_sequence_interval, 0.2)
		and is_zero_approx(cooldown_after_first_cloud)
		and is_equal_approx(
			cooldown_after_final_cloud,
			player.get_current_attack_interval()
		)
		and volley_discharge_visible
		and not spawned_clouds.is_empty()
		and spawned_clouds[0].get_travel_direction().x > 0.99
		and absf(spawned_clouds[0].get_travel_direction().y) < 0.01
		and spawned_clouds[0].global_position.x
			> first_cloud_start.x + 80.0
		and absf(
			spawned_clouds[0].global_position.y - first_cloud_start.y
		) < 4.0
		and spawned_clouds[0].collision_shape.shape is CircleShape2D
		and is_equal_approx(spawned_clouds[0].damage_interval, 0.4)
		and is_equal_approx(spawned_clouds[0].lifetime, 2.4)
		and spawned_clouds[0].maximum_damage_pulses == 6
		and is_equal_approx(spawned_clouds[0].aim_travel_speed, 160.0)
		and is_equal_approx(
			(spawned_clouds[0].collision_shape.shape as CircleShape2D).radius,
			player.get_current_aoe_radius()
		),
		(
			"Thunder Hammer mismatch (clouds=%d, health=%d, gap=%.3f, "
			+ "first_cd=%.3f, final_cd=%.3f/%.3f, discharge=%s, direction=%s, "
			+ "travel=%s, radius=%.2f/%.2f)."
		) % [
			cloud_count,
			thunder_target.current_health,
			resolved_thunder_sequence_interval,
			cooldown_after_first_cloud,
			cooldown_after_final_cloud,
			player.get_current_attack_interval(),
			volley_discharge_visible,
			(
				str(spawned_clouds[0].get_travel_direction())
				if not spawned_clouds.is_empty()
				else "missing"
			),
			(
				str(spawned_clouds[0].global_position - first_cloud_start)
				if not spawned_clouds.is_empty()
				else "missing"
			),
			(
				(spawned_clouds[0].collision_shape.shape as CircleShape2D).radius
				if (
					not spawned_clouds.is_empty()
					and spawned_clouds[0].collision_shape.shape is CircleShape2D
				)
				else -1.0
			),
			player.get_current_aoe_radius(),
		]
	)
	thunder_target.queue_free()
	for node in root.get_children():
		if node is ThunderCloudProjectile:
			node.queue_free()
	await _wait_physics_frames(2)

	var capped_thunder_player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(capped_thunder_player)
	capped_thunder_player.global_position = Vector2(12000.0, 12000.0)
	capped_thunder_player.set_movement_enabled(false)
	for _level in 11:
		capped_thunder_player.collect_weapon(
			THUNDER_HAMMER_DATA,
			THUNDER_HAMMER_DATA.minimum_damage
		)
	_check(
		capped_thunder_player.select_weapon_slot(0),
		"Thunder Hammer could not be selected for cap validation."
	)
	var capped_thunder_stats := (
		capped_thunder_player.get_current_weapon_combat_stats()
	)
	_check(
		capped_thunder_player.get_current_delivery_count() == 10
		and capped_thunder_player.get_current_weapon_damage() == 6
		and is_equal_approx(capped_thunder_stats.resolved_damage_exact, 5.5),
		"Thunder Hammer Lv.11 did not cap at ten clouds with exact +10% damage."
	)
	var exact_damage_target := _make_enemy(
		capped_thunder_player,
		capped_thunder_player.get_combat_anchor_position(),
		100
	)
	var exact_damage_cloud := (
		THUNDER_HAMMER_DATA.projectile_scene.instantiate()
		as ThunderCloudProjectile
	)
	root.add_child(exact_damage_cloud)
	exact_damage_cloud.global_position = exact_damage_target.global_position
	exact_damage_cloud.configure(
		Vector2.UP,
		5.5,
		THUNDER_HAMMER_DATA.base_aoe_radius,
		false,
		null,
		1.0,
		0
	)
	exact_damage_cloud.call("_on_body_entered", exact_damage_target)
	for _pulse in 6:
		exact_damage_cloud.call("_damage_enemies_in_cloud")
	_check(
		exact_damage_target.current_health == 67,
		"Six Lv.11 Thunder pulses did not preserve exact 33 integrated damage."
	)
	exact_damage_cloud.queue_free()
	exact_damage_target.queue_free()
	capped_thunder_player.queue_free()
	await _wait_physics_frames(2)

	player.collect_weapon(
		FANTIAN_SEAL_DATA,
		FANTIAN_SEAL_DATA.minimum_damage
	)
	player.collect_weapon(
		FANTIAN_SEAL_DATA,
		FANTIAN_SEAL_DATA.minimum_damage
	)
	_check(
		player.select_weapon_slot(2),
		"Fantian Seal could not be selected from weapon slot 3."
	)
	_check(
		player.get_current_delivery_count() == 2
		and FANTIAN_SEAL_DATA.minimum_damage == 6
		and FANTIAN_SEAL_DATA.delivery_count_cap == 10
		and not FANTIAN_SEAL_DATA.bonuses_scale_aoe_radius
		and is_equal_approx(FANTIAN_SEAL_DATA.attack_interval, 1.5)
		and is_equal_approx(FANTIAN_SEAL_DATA.attack_range, 320.0)
		and is_equal_approx(
			FANTIAN_SEAL_DATA.projectile_sequence_interval,
			0.35
		)
		and player.attack_shape.shape is RectangleShape2D
		and (
			player.attack_shape.shape as RectangleShape2D
		).size.is_equal_approx(
			Vector2.ONE * player.get_current_attack_range() * 2.0
		),
		"Fantian Seal damage, cadence, count, or square range is wrong."
	)
	var six_seal_gap_before_speed := float(
		player.call(
			"_resolve_special_sequence_interval",
			WeaponData.AttackKind.FANTIAN_SEAL,
			6
		)
	)
	player.apply_universal_upgrade(
		UniversalUpgradeTypes.UpgradeType.ATTACK_SPEED
	)
	var six_seal_gap_after_speed := float(
		player.call(
			"_resolve_special_sequence_interval",
			WeaponData.AttackKind.FANTIAN_SEAL,
			6
		)
	)
	_check(
		six_seal_gap_after_speed < six_seal_gap_before_speed
		and six_seal_gap_after_speed * 5.0
			<= player.get_current_attack_interval() * 0.7 + 0.001,
		"Attack speed did not compress a high-level Fantian Seal volley."
	)
	var normal_target := _make_enemy(
		player,
		player.get_combat_anchor_position() + Vector2(-100.0, 0.0),
		500
	)
	var elite_target := _make_enemy(
		player,
		player.get_combat_anchor_position() + Vector2(100.0, 0.0),
		100
	)
	elite_target.configure_elite(2.0, 1.2, 1.2)
	var normal_health_before := normal_target.current_health
	var elite_health_before := elite_target.current_health
	await _wait_physics_frames(2)
	player.call(
		"_begin_special_projectile_sequence",
		WeaponData.AttackKind.FANTIAN_SEAL,
		AttackDamageResult.new(FANTIAN_SEAL_DATA.minimum_damage, false)
	)
	_check(
		is_equal_approx(float(player.get("_special_sequence_interval")), 0.35),
		"Fantian Seal Lv.2 did not use its readable 0.35s duplicate gap."
	)
	player.call("_launch_next_special_projectile")
	var seal_count := 0
	for node in root.get_children():
		if node is FantianSealProjectile:
			seal_count += 1
	await _wait_physics_frames(60)
	_check(
		seal_count == 2
		and normal_target.is_combat_active()
		and normal_target.current_health
			== normal_health_before - FANTIAN_SEAL_DATA.minimum_damage
		and elite_target.current_health
			== elite_health_before - FANTIAN_SEAL_DATA.minimum_damage,
		(
			"Fantian Seal mismatch (seals=%d, normal_valid=%s, elite=%d/%d)."
			% [
				seal_count,
				is_instance_valid(normal_target),
				elite_target.current_health,
				elite_health_before,
			]
		)
	)

	var level_four_player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(level_four_player)
	level_four_player.global_position = Vector2(9000.0, 9000.0)
	level_four_player.set_movement_enabled(false)
	for _level in 4:
		level_four_player.collect_weapon(
			FANTIAN_SEAL_DATA,
			FANTIAN_SEAL_DATA.minimum_damage
		)
	_check(
		level_four_player.select_weapon_slot(0)
		and level_four_player.get_current_delivery_count() == 4,
		"Fantian Seal Lv.4 could not be prepared for cooldown validation."
	)
	level_four_player.set("_attack_cooldown_remaining", 999.0)
	var level_four_target := _make_enemy(
		level_four_player,
		level_four_player.get_combat_anchor_position() + Vector2(80.0, 0.0),
		500
	)
	await _wait_physics_frames(2)
	level_four_player.set("_attack_cooldown_remaining", 0.0)
	level_four_player.call(
		"_begin_special_projectile_sequence",
		WeaponData.AttackKind.FANTIAN_SEAL,
		AttackDamageResult.new(FANTIAN_SEAL_DATA.minimum_damage, false)
	)
	var cooldown_after_first_launch := float(
		level_four_player.get("_attack_cooldown_remaining")
	)
	for _duplicate in 3:
		level_four_player.call("_launch_next_special_projectile")
	var level_four_gap := float(
		level_four_player.get("_special_sequence_interval")
	)
	var cooldown_after_final_launch := float(
		level_four_player.get("_attack_cooldown_remaining")
	)
	_check(
		is_zero_approx(cooldown_after_first_launch)
		and is_equal_approx(
			cooldown_after_final_launch,
			level_four_player.get_current_attack_interval()
		)
		and is_equal_approx(
			level_four_gap * 3.0 + cooldown_after_final_launch,
			2.55
		),
		"Fantian Seal Lv.4 cooldown overlapped its duplicate volley."
	)
	level_four_target.queue_free()
	level_four_player.queue_free()

	var capped_seal_player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(capped_seal_player)
	capped_seal_player.set_movement_enabled(false)
	for _level in 11:
		capped_seal_player.collect_weapon(
			FANTIAN_SEAL_DATA,
			FANTIAN_SEAL_DATA.minimum_damage
		)
	_check(
		capped_seal_player.select_weapon_slot(0),
		"Fantian Seal could not be selected for cap validation."
	)
	var capped_seal_aoe := capped_seal_player.get_current_aoe_radius()
	var capped_seal_range := capped_seal_player.get_current_attack_range()
	capped_seal_player.apply_universal_upgrade(
		UniversalUpgradeTypes.UpgradeType.DAMAGE_RANGE
	)
	_check(
		capped_seal_player.get_current_delivery_count() == 10
		and capped_seal_player.get_current_weapon_damage()
			== roundi(
				float(FANTIAN_SEAL_DATA.minimum_damage)
				* (
					1.0
					+ FANTIAN_SEAL_DATA.damage_ratio_per_level_above_range_cap
				)
			)
		and capped_seal_player.get_current_attack_range() > capped_seal_range
		and is_equal_approx(
			capped_seal_player.get_current_aoe_radius(),
			capped_seal_aoe
		)
		and is_equal_approx(
			capped_seal_aoe,
			FANTIAN_SEAL_DATA.base_aoe_radius
		),
		"Fantian Seal post-cap damage or fixed footprint progression is wrong."
	)
	capped_seal_player.queue_free()

	if _failures.is_empty():
		print("LATEST WEAPON TEST: PASS")
	else:
		print("LATEST WEAPON TEST: FAIL (%d failures)" % _failures.size())
	quit()
