extends SceneTree

const PLAYER_SCENE := preload("res://game/scenes/gameplay/player.tscn")
const ENEMY_SCENE := preload("res://game/scenes/gameplay/enemy.tscn")
const WEAPON_PICKUP_SCENE := preload(
	"res://game/scenes/gameplay/weapon_pickup.tscn"
)
const FLYING_SWORD_DATA := preload(
	"res://game/resources/weapon/flying_sword.tres"
)
const THUNDER_HAMMER_DATA := preload(
	"res://game/resources/weapon/thunder_hammer.tres"
)
const FANTIAN_SEAL_DATA := preload(
	"res://game/resources/weapon/fantian_seal.tres"
)

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
	var ring_player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(ring_player)
	ring_player.global_position = Vector2(7000.0, 7000.0)
	ring_player.set_movement_enabled(false)
	ring_player.collect_weapon(
		preload("res://game/resources/weapon/qiankun_ring.tres"),
		5
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
		int(player.call("_get_palm_direction_count")) == 1,
		"Qi Refining Palm did not keep one direction."
	)
	resources.demote_to_realm(1, 1)
	_check(
		int(player.call("_get_palm_direction_count")) == 2,
		"Foundation Palm did not use two sequential directions."
	)
	var foundation_target := _make_enemy(
		player,
		player.global_position + Vector2(50.0, 0.0)
	)
	player.set("_palm_sequence_hit_ids", {})
	player.call(
		"_apply_palm_hit",
		foundation_target,
		AttackDamageResult.new(2, false)
	)
	_check(
		foundation_target.get_knockback_velocity().length() > 0.0,
		"Foundation Palm did not apply its light knockback."
	)
	foundation_target.queue_free()
	resources.demote_to_realm(2, 1)
	_check(
		int(player.call("_get_palm_direction_count")) == 6,
		"Golden Core Palm did not use six sequential directions."
	)
	resources.demote_to_realm(3, 1)
	_check(
		int(player.call("_get_palm_direction_count")) == 18,
		"Nascent Soul Palm did not use eighteen sequential directions."
	)
	var nascent_target := _make_enemy(
		player,
		player.global_position + Vector2(50.0, 0.0),
		500
	)
	player.set("_palm_sequence_hit_ids", {})
	player.call(
		"_apply_palm_hit",
		nascent_target,
		AttackDamageResult.new(1, false)
	)
	await _wait_physics_frames(2)
	_check(
		not is_instance_valid(nascent_target)
			or not nascent_target.is_combat_active(),
		"Nascent Soul Palm did not instantly defeat an ordinary enemy."
	)

	var pickup := WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
	pickup.configure(FLYING_SWORD_DATA, 6, Vector2.ZERO, player)
	root.add_child(pickup)
	pickup.global_position = player.global_position
	await _wait_physics_frames(30)
	_check(
		player.get_weapon_name() != "飞剑"
		and pickup.get_channel_progress() > 0.0
		and pickup.get_channel_progress() < 1.0,
		"Elite weapon was collected before one full second of synchronization."
	)
	await _wait_physics_frames(35)
	_check(
		player.get_weapon_name() == "飞剑",
		"Elite weapon was not collected after one uninterrupted second."
	)

	player.collect_weapon(THUNDER_HAMMER_DATA, 2)
	player.collect_weapon(THUNDER_HAMMER_DATA, 2)
	_check(
		player.get_current_delivery_count() == 2,
		"Duplicate Thunder Hammer did not add one sequential cloud."
	)
	var thunder_target := _make_enemy(
		player,
		player.global_position + Vector2(60.0, 0.0)
	)
	await _wait_physics_frames(2)
	player.velocity = Vector2(24.0, -260.0)
	player.call(
		"_begin_special_projectile_sequence",
		WeaponData.AttackKind.THUNDER_HAMMER,
		AttackDamageResult.new(2, false)
	)
	player.call("_launch_next_special_projectile")
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
		and thunder_target.current_health <= 95
		and THUNDER_HAMMER_DATA.base_aoe_radius >= 112.0
		and not spawned_clouds.is_empty()
		and spawned_clouds[0].global_position.y
			< first_cloud_start.y - 100.0,
		(
			"Thunder Hammer cloud count, inherited velocity, radius, or damage mismatch."
		)
	)
	thunder_target.queue_free()
	for node in root.get_children():
		if node is ThunderCloudProjectile:
			node.queue_free()
	await _wait_physics_frames(2)

	player.collect_weapon(FANTIAN_SEAL_DATA, 18)
	player.collect_weapon(FANTIAN_SEAL_DATA, 18)
	_check(
		player.get_current_delivery_count() == 2
		and is_equal_approx(FANTIAN_SEAL_DATA.attack_interval, 2.25)
		and is_equal_approx(FANTIAN_SEAL_DATA.attack_range, 462.0)
		and player.attack_shape.shape is RectangleShape2D,
		"Fantian Seal count, doubled speed, or square 1.65x range is wrong."
	)
	var normal_target := _make_enemy(
		player,
		player.global_position + Vector2(-100.0, 0.0),
		500
	)
	var elite_target := _make_enemy(
		player,
		player.global_position + Vector2(100.0, 0.0),
		100
	)
	elite_target.configure_elite(2.0, 1.2, 1.2)
	var elite_health_before := elite_target.current_health
	await _wait_physics_frames(2)
	player.call(
		"_begin_special_projectile_sequence",
		WeaponData.AttackKind.FANTIAN_SEAL,
		AttackDamageResult.new(18, false)
	)
	player.call("_launch_next_special_projectile")
	var seal_count := 0
	for node in root.get_children():
		if node is FantianSealProjectile:
			seal_count += 1
	await _wait_physics_frames(60)
	_check(
		seal_count == 2
		and (
			not is_instance_valid(normal_target)
			or not normal_target.is_combat_active()
		)
		and elite_target.current_health == elite_health_before - 18,
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

	if _failures.is_empty():
		print("LATEST WEAPON TEST: PASS")
	else:
		print("LATEST WEAPON TEST: FAIL (%d failures)" % _failures.size())
	quit()
