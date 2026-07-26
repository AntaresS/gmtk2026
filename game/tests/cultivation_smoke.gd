extends SceneTree

const CultivationTypesResource = preload(
	"res://game/scripts/gameplay/cultivation_types.gd"
)
const CultivationRewardResource = preload(
	"res://game/scripts/gameplay/cultivation_reward.gd"
)
const PlayerGlobalCombatStatsResource = preload(
	"res://game/scripts/gameplay/player_global_combat_stats.gd"
)
const WeaponCombatStatsResource = preload(
	"res://game/scripts/gameplay/weapon_combat_stats.gd"
)
const PlayerCombatConfigResource = preload(
	"res://game/scripts/gameplay/player_combat_config.gd"
)
const CombatStatsResolverResource = preload(
	"res://game/scripts/gameplay/combat_stats_resolver.gd"
)
const PALM_DATA: WeaponData = preload(
	"res://game/resources/great_strength_palm.tres"
)
const DAO_DATA: WeaponData = preload(
	"res://game/resources/weapon/dao.tres"
)
const FLYING_SWORD_DATA: WeaponData = preload(
	"res://game/resources/weapon/flying_sword.tres"
)
const QIANKUN_RING_DATA: WeaponData = preload(
	"res://game/resources/weapon/qiankun_ring.tres"
)
const GOLDEN_BELL_DATA: WeaponData = preload(
	"res://game/resources/weapon/golden_bell.tres"
)
const THUNDER_HAMMER_DATA: WeaponData = preload(
	"res://game/resources/weapon/thunder_hammer.tres"
)
const FANTIAN_SEAL_DATA: WeaponData = preload(
	"res://game/resources/weapon/fantian_seal.tres"
)

var _failures: Array[String] = []
var _fragment_completions: int = 0
var _completed_fragment_type: int = -1
var _combat_stats_updates: int = 0
var _ring_delivery_hits: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("CULTIVATION TEST: %s" % message)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _run() -> void:
	var change_error := change_scene_to_file(
		"res://game/scenes/gameplay/game.tscn"
	)
	_check(change_error == OK, "Gameplay scene could not be opened.")
	await _wait_process_frames(4)

	var game := current_scene
	var player := game.get_node("Player") as PlayerController
	var resources := game.get_node("RunResources") as RunResources
	var enemy_spawner := game.get_node("EnemySpawner") as EnemySpawner
	var hud := game.get_node("GameplayHud") as GameplayHud
	enemy_spawner.set_spawning_enabled(false)
	player.combat_stats_changed.connect(_on_combat_stats_changed)
	var test_player_combat_config := (
		player.combat_config.duplicate(true) as PlayerCombatConfigResource
	)
	test_player_combat_config.base_critical_chance = 0.0
	player.combat_config = test_player_combat_config
	var test_cultivation_config := (
		resources.cultivation_config.duplicate(true) as CultivationConfig
	)
	test_cultivation_config.fragments_per_level = 3
	resources.cultivation_config = test_cultivation_config
	var test_realm_config := (
		resources.realm_progression_config.duplicate(true)
		as RealmProgressionConfig
	)
	test_realm_config.get_realm(0).melee_weapons_only = false
	resources.realm_progression_config = test_realm_config
	resources.reset_resources()
	player.call(
		"_on_cultivation_stats_changed",
		CultivationTypesResource.CultivationType.JING,
		0
	)

	var initial_global_stats := player.get_global_combat_stats()
	var initial_weapon_stats := player.get_current_weapon_combat_stats()
	_check(
		player.combat_config != null
		and is_zero_approx(initial_global_stats.global_damage_bonus)
		and is_zero_approx(initial_global_stats.critical_chance)
		and is_equal_approx(
			initial_global_stats.critical_damage_multiplier,
			1.5
		)
		and is_zero_approx(initial_global_stats.attack_speed_bonus)
		and is_equal_approx(
			initial_global_stats.projectile_speed_multiplier,
			1.0
		)
		and initial_global_stats.delivery_count_bonus == 0
		and is_zero_approx(initial_global_stats.aoe_radius_bonus)
		and is_zero_approx(initial_global_stats.targeting_range_bonus)
		and initial_global_stats.overall_cultivation_level == 1
		and is_zero_approx(
			initial_global_stats.overall_level_damage_bonus
		)
		and is_zero_approx(
			initial_global_stats.overall_level_damage_ratio
		)
		and not initial_global_stats.jing_bonuses.has_any_bonus()
		and not initial_global_stats.qi_bonuses.has_any_bonus()
		and not initial_global_stats.shen_bonuses.has_any_bonus()
		and is_zero_approx(
			initial_global_stats.close_range_damage_reduction
		)
		and initial_weapon_stats.weapon_id == PALM_DATA.weapon_id
		and initial_weapon_stats.cultivation_types.is_empty()
		and initial_weapon_stats.resolved_damage
			== player.get_current_weapon_damage(),
		"Initial typed combat-stat snapshots did not mirror live player state."
	)

	var original_combat_config := player.combat_config
	var guaranteed_crit_config := (
		original_combat_config.duplicate(true) as PlayerCombatConfigResource
	)
	guaranteed_crit_config.base_critical_chance = 1.0
	guaranteed_crit_config.base_critical_damage_multiplier = 2.0
	player.combat_config = guaranteed_crit_config
	player.apply_cultivation_level(resources.cultivation_level)
	var critical_base_damage := player.get_current_weapon_damage()
	var guaranteed_critical := player._roll_current_attack_damage()
	var critical_target := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	critical_target.player = player
	critical_target.max_health = 999
	critical_target.cruise_speed = 1.0
	game.add_child(critical_target)
	critical_target.global_position = (
		player.global_position + Vector2(320.0, 0.0)
	)
	critical_target.take_melee_damage(
		guaranteed_critical.damage,
		guaranteed_critical.is_critical
	)
	await _wait_process_frames(1)
	var critical_vfx_nodes := get_nodes_in_group("critical_hit_vfx")
	var critical_vfx_label: Label = null
	if not critical_vfx_nodes.is_empty():
		critical_vfx_label = (
			critical_vfx_nodes[0].get_node("CriticalHitLabel") as Label
		)
	_check(
		guaranteed_critical.is_critical
		and guaranteed_critical.damage == critical_base_damage * 2
		and critical_target.current_health
			== 999 - guaranteed_critical.damage,
		"Guaranteed critical roll did not multiply and apply final damage."
	)
	_check(
		critical_vfx_nodes.size() == 1
		and critical_vfx_label != null
		and critical_vfx_label.visible
		and critical_vfx_label.text.contains("暴击!")
		and critical_vfx_label.text.contains(
			str(guaranteed_critical.damage)
		),
		"Critical damage did not spawn readable world-space feedback."
	)
	critical_target.queue_free()
	for critical_vfx in critical_vfx_nodes:
		critical_vfx.queue_free()
	player.combat_config = original_combat_config
	player.apply_cultivation_level(resources.cultivation_level)
	await _wait_process_frames(1)

	var tuned_combat_config := PlayerCombatConfigResource.new()
	tuned_combat_config.global_damage_bonus = 2.0
	tuned_combat_config.base_critical_chance = 0.10
	tuned_combat_config.base_critical_damage_multiplier = 1.75
	tuned_combat_config.maximum_critical_chance = 0.12
	tuned_combat_config.maximum_critical_damage_multiplier = 1.8
	tuned_combat_config.base_attack_speed_bonus = 0.20
	tuned_combat_config.base_projectile_speed_bonus = 0.25
	tuned_combat_config.base_delivery_count_bonus = 2
	tuned_combat_config.base_aoe_radius_bonus = 0.30
	tuned_combat_config.base_targeting_range_bonus = 0.50
	tuned_combat_config.base_close_range_damage_reduction = 0.04
	tuned_combat_config.maximum_close_range_damage_reduction = 0.05
	tuned_combat_config.close_range_mitigation_radius = 120.0
	tuned_combat_config.minimum_attack_interval = 0.6
	var tuned_global_stats := CombatStatsResolverResource.resolve_global(
		resources,
		tuned_combat_config
	)
	var tuned_weapon_stats := CombatStatsResolverResource.resolve_weapon(
		DAO_DATA,
		10,
		resources,
		tuned_global_stats
	)
	_check(
		is_equal_approx(tuned_global_stats.global_damage_bonus, 2.0)
		and is_equal_approx(tuned_global_stats.critical_chance, 0.10)
		and is_equal_approx(
			tuned_global_stats.critical_damage_multiplier,
			1.75
		)
		and is_equal_approx(tuned_global_stats.attack_speed_bonus, 0.20)
		and is_equal_approx(
			tuned_global_stats.projectile_speed_multiplier,
			1.25
		)
		and tuned_global_stats.delivery_count_bonus == 0
		and is_equal_approx(tuned_global_stats.aoe_radius_bonus, 0.30)
		and is_equal_approx(
			tuned_global_stats.targeting_range_bonus,
			0.50
		)
		and is_equal_approx(
			tuned_global_stats.close_range_damage_reduction,
			0.04
		)
		and is_equal_approx(
			tuned_global_stats.close_range_mitigation_radius,
			120.0
		)
		and tuned_weapon_stats.resolved_damage == 12
		and is_equal_approx(tuned_weapon_stats.critical_chance, 0.10)
		and is_equal_approx(
			tuned_weapon_stats.critical_damage_multiplier,
			1.75
		)
		and is_equal_approx(tuned_weapon_stats.attack_speed_bonus, 0.20)
		and is_equal_approx(
			tuned_weapon_stats.projectile_speed_multiplier,
			1.25
		)
		and tuned_weapon_stats.delivery_count == 1
		and is_equal_approx(
			tuned_weapon_stats.attack_range,
			DAO_DATA.attack_range * 1.8
		)
		and is_equal_approx(tuned_weapon_stats.attack_interval, 0.6),
		"PlayerCombatConfig was not the source of resolved global combat stats."
	)

	_check(
		PALM_DATA.cultivation_type == CultivationTypesResource.NEUTRAL
		and DAO_DATA.cultivation_type
			== CultivationTypesResource.CultivationType.JING
		and FLYING_SWORD_DATA.cultivation_type
			== CultivationTypesResource.CultivationType.QI
		and QIANKUN_RING_DATA.cultivation_type
			== CultivationTypesResource.CultivationType.SHEN,
		"Weapon resources did not map neutral/精/气/神 correctly."
	)
	_check(
		resources.get_cultivation_fragments_required() == 3
		and resources.cultivation_config.type_configs.size() == 3,
		"Cultivation did not load its three-fragment data resource."
	)
	_check(
		not hud.cultivation_tracks_label.visible
		and hud.attack_speed_level_name.text == "攻速"
		and hud.attack_speed_level_label.text == "Lv.0"
		and hud.speed_control_level_name.text == "加减速"
		and hud.speed_control_level_label.text == "Lv.0",
		"HUD did not present the compact fragment-level summary."
	)

	_check(player.collect_weapon(DAO_DATA, 10), "Dao could not be equipped.")
	_check(
		player.select_weapon_slot(0),
		"Dao could not be selected from weapon slot 1."
	)
	var dao_before_level := player.get_current_weapon_combat_stats()
	_check(
		dao_before_level.weapon_id == DAO_DATA.weapon_id
		and dao_before_level.rolled_damage == 10
		and dao_before_level.resolved_damage == 10
		and is_zero_approx(dao_before_level.matching_damage_bonus)
		and dao_before_level.cultivation_types == [
			CultivationTypesResource.CultivationType.JING
		],
		"Dao snapshot did not preserve its roll, affinity, and base values."
	)
	resources.add_cultivation_fragment(
		CultivationTypesResource.CultivationType.JING,
		2
	)
	_check(
		resources.get_cultivation_level(
			CultivationTypesResource.CultivationType.JING
		) == 0
		and resources.get_cultivation_fragments(
			CultivationTypesResource.CultivationType.JING
		) == 2
		and player.get_current_weapon_damage() == 10,
		"精 advanced or changed damage before its third fragment."
	)
	resources.add_cultivation_fragment(
		CultivationTypesResource.CultivationType.JING
	)
	var jing_level_one := resources.get_cultivation_stats(
		CultivationTypesResource.CultivationType.JING
	)
	var dao_level_one := player.get_current_weapon_combat_stats()
	_check(
		resources.get_cultivation_level(
			CultivationTypesResource.CultivationType.JING
		) == 1
		and resources.get_cultivation_fragments(
			CultivationTypesResource.CultivationType.JING
		) == 0
		and player.get_current_weapon_damage() == 11
		and is_equal_approx(
			float(jing_level_one["damage_bonus"]),
			0.10
		)
		and is_equal_approx(
			float(
				(jing_level_one["stats"] as Dictionary).get(
					CultivationRewardResource.Stat.CRITICAL_CHANCE,
					0.0
				)
			),
			0.02
		),
		"Third 精 fragment did not reset progress and grant level-one stats."
	)
	_check(
		dao_level_one != dao_before_level
		and is_zero_approx(dao_before_level.matching_damage_bonus)
		and is_equal_approx(dao_level_one.matching_damage_bonus, 0.10)
		and dao_level_one.resolved_damage == 11
		and is_equal_approx(dao_level_one.critical_chance, 0.02)
		and is_equal_approx(
			dao_level_one.critical_damage_multiplier,
			1.5
		)
		and _combat_stats_updates >= 2,
		"Cultivation did not publish a fresh typed Dao stat snapshot."
	)
	_check(
		hud.level_up_message.text.contains("精 Lv.1")
		and hud.level_up_message.text.contains("暴击率"),
		"HUD did not show the 精 level and newly granted reward."
	)

	_check(
		player.collect_weapon(FLYING_SWORD_DATA, 10),
		"Flying Sword could not be equipped."
	)
	_check(
		player.select_weapon_slot(1),
		"Flying Sword could not be selected from weapon slot 2."
	)
	var flying_before_qi := player.get_current_weapon_combat_stats()
	_check(
		is_zero_approx(flying_before_qi.matching_damage_bonus)
		and is_equal_approx(flying_before_qi.critical_chance, 0.02),
		"精 critical chance did not remain a player-global weapon stat."
	)
	resources.add_cultivation_fragment(
		CultivationTypesResource.CultivationType.QI,
		3
	)
	_check(
		player.get_current_weapon_damage() == 11
		and is_equal_approx(
			player.get_global_combat_stats().attack_speed_bonus,
			0.05
		)
		and player.get_current_attack_interval()
			< FLYING_SWORD_DATA.attack_interval
		and is_equal_approx(
			player.get_current_projectile_speed_multiplier(),
			1.0
		)
		and player.get_flying_sword_projectile_count() == 1,
		"气 level one did not grant only damage and attack speed."
	)
	resources.add_cultivation_fragment(
		CultivationTypesResource.CultivationType.QI,
		6
	)
	var qi_global_stats := player.get_global_combat_stats()
	_check(
		resources.get_cultivation_level(
			CultivationTypesResource.CultivationType.QI
		) == 3
		and is_equal_approx(qi_global_stats.attack_speed_bonus, 0.10)
		and is_equal_approx(
			qi_global_stats.projectile_speed_multiplier,
			1.10
		)
		and qi_global_stats.delivery_count_bonus == 0
		and is_zero_approx(qi_global_stats.global_damage_bonus)
		and player.get_current_projectile_speed_multiplier() > 1.0
		and player.get_flying_sword_projectile_count() == 1,
		"气 reward cycle changed weapon quantity without a duplicate pickup."
	)

	_check(
		player.collect_weapon(QIANKUN_RING_DATA, 10),
		"Universe Ring could not be equipped."
	)
	_check(
		player.select_weapon_slot(2),
		"Universe Ring could not be selected from weapon slot 3."
	)
	var ring_before_shen := player.get_current_weapon_combat_stats()
	_check(
		is_zero_approx(ring_before_shen.matching_damage_bonus)
		and is_equal_approx(ring_before_shen.critical_chance, 0.02)
		and is_equal_approx(ring_before_shen.attack_speed_bonus, 0.10)
		and is_equal_approx(
			ring_before_shen.projectile_speed_multiplier,
			1.10
		)
		and ring_before_shen.delivery_count == 1
		and is_equal_approx(
			ring_before_shen.aoe_radius,
			QIANKUN_RING_DATA.base_aoe_radius
		)
		and player.get_qiankun_ring_bounce_count() == 2,
		"Player-global 精/气 bonuses did not carry to the Universe Ring."
	)
	resources.add_cultivation_fragment(
		CultivationTypesResource.CultivationType.SHEN,
		3
	)
	var dao_aoe_stats := CombatStatsResolverResource.resolve_weapon(
		DAO_DATA,
		10,
		resources,
		player.get_global_combat_stats()
	)
	_check(
		player.get_current_weapon_damage() == 11
		and player.get_current_aoe_radius()
			> QIANKUN_RING_DATA.base_aoe_radius
		and is_equal_approx(
			dao_aoe_stats.attack_range,
			DAO_DATA.attack_range * 1.06
		),
		"神 level one did not expand Ring and Dao area radii."
	)
	resources.add_cultivation_fragment(
		CultivationTypesResource.CultivationType.SHEN,
		6
	)
	var shen_global_stats := player.get_global_combat_stats()
	_check(
		player.get_current_attack_range()
			> QIANKUN_RING_DATA.attack_range
		and is_equal_approx(shen_global_stats.aoe_radius_bonus, 0.12)
		and shen_global_stats.delivery_count_bonus == 0
		and player.get_current_delivery_count() == 1
		and player.get_qiankun_ring_bounce_count() == 2
		and is_equal_approx(
			shen_global_stats.targeting_range_bonus,
			0.05
		)
		and is_zero_approx(shen_global_stats.global_damage_bonus),
		"神 reward cycle changed weapon quantity without a duplicate pickup."
	)
	_check(
		resources.get_cultivation_level(
			CultivationTypesResource.CultivationType.JING
		) == 1
		and resources.get_cultivation_level(
			CultivationTypesResource.CultivationType.QI
		) == 3
		and resources.get_cultivation_level(
			CultivationTypesResource.CultivationType.SHEN
		) == 3,
		"Cultivation types did not remain independent."
	)

	resources.add_cultivation_fragment(
		CultivationTypesResource.CultivationType.JING,
		6
	)
	var close_source := Node2D.new()
	game.add_child(close_source)
	close_source.global_position = player.global_position
	var received_damage: Array[float] = []
	player.melee_damage_received.connect(
		func(amount: float) -> void:
			received_damage.append(amount),
		CONNECT_ONE_SHOT
	)
	player.take_melee_damage(10.0, close_source)
	var defensive_stats := player.get_global_combat_stats()
	_check(
		received_damage.size() == 1
		and is_equal_approx(received_damage[0], 9.7),
		"精 close-range damage reduction was not applied centrally."
	)
	_check(
		is_equal_approx(
			defensive_stats.close_range_damage_reduction,
			0.03
		)
		and is_equal_approx(defensive_stats.critical_chance, 0.02)
		and is_equal_approx(
			defensive_stats.critical_damage_multiplier,
			1.65
		)
		and is_equal_approx(
			defensive_stats.close_range_mitigation_radius,
			player.combat_config.close_range_mitigation_radius
		),
		"Global combat snapshot did not expose 精 defensive progression."
	)
	close_source.queue_free()

	var stats_updates_before_overall := _combat_stats_updates
	var damage_before_overall := player.get_current_weapon_damage()
	resources.add_qi(100)
	var overall_global_stats := player.get_global_combat_stats()
	var weapon_definitions: Array[WeaponData] = [
		PALM_DATA,
		DAO_DATA,
		FLYING_SWORD_DATA,
		QIANKUN_RING_DATA,
		GOLDEN_BELL_DATA,
		THUNDER_HAMMER_DATA,
		FANTIAN_SEAL_DATA,
	]
	var expected_damage_after_overall: Array[int] = [10, 13, 13, 13, 13, 10, 10]
	for weapon_index in weapon_definitions.size():
		var resolved_weapon := CombatStatsResolverResource.resolve_weapon(
			weapon_definitions[weapon_index],
			10,
			resources,
			overall_global_stats
		)
		_check(
			resolved_weapon.resolved_damage
				== expected_damage_after_overall[weapon_index],
			"Overall-level global damage did not reach %s." % (
				weapon_definitions[weapon_index].display_name
			)
		)
		var ratio_scaled_weapon := CombatStatsResolverResource.resolve_weapon(
			weapon_definitions[weapon_index],
			100,
			resources,
			overall_global_stats
		)
		var damage_without_overall_ratio := roundi(
			100.0 * (1.0 + ratio_scaled_weapon.matching_damage_bonus)
		)
		_check(
			ratio_scaled_weapon.resolved_damage > damage_without_overall_ratio,
			"Overall-level ratio did not scale %s." % (
				weapon_definitions[weapon_index].display_name
			)
		)
	var ratio_probe := CombatStatsResolverResource.resolve_weapon(
		PALM_DATA,
		100,
		resources,
		overall_global_stats
	)
	var stats_panel_text := hud.player_stats_label.text
	_check(
		resources.cultivation_level == 2
		and overall_global_stats.overall_cultivation_level == 2
		and is_equal_approx(
			overall_global_stats.overall_level_damage_bonus,
			player.combat_config.global_damage_bonus_per_overall_level
		)
		and is_equal_approx(
			overall_global_stats.overall_level_damage_ratio,
			player.combat_config.global_damage_ratio_per_overall_level
		)
		and is_equal_approx(overall_global_stats.global_damage_bonus, 0.0)
		and ratio_probe.resolved_damage == 101
		and damage_before_overall == 13
		and player.get_current_weapon_damage() == 13
		and _combat_stats_updates > stats_updates_before_overall,
		(
			"Overall cultivation ratio mismatch: level=%d ratio=%.3f/%.3f probe=%d "
			+ "flat_level=%.2f/%.2f flat=%.2f before=%d after=%d updates=%d/%d."
		) % [
			overall_global_stats.overall_cultivation_level,
			overall_global_stats.overall_level_damage_ratio,
			player.combat_config.global_damage_ratio_per_overall_level,
			ratio_probe.resolved_damage,
			overall_global_stats.overall_level_damage_bonus,
			player.combat_config.global_damage_bonus_per_overall_level,
			overall_global_stats.global_damage_bonus,
			damage_before_overall,
			player.get_current_weapon_damage(),
			_combat_stats_updates,
			stats_updates_before_overall,
		]
	)
	_check(
		is_equal_approx(
			overall_global_stats.jing_bonuses.critical_chance,
			0.02
		)
		and is_equal_approx(
			overall_global_stats.jing_bonuses.critical_damage_bonus,
			0.15
		)
		and is_equal_approx(
			overall_global_stats.jing_bonuses.close_range_damage_reduction,
			0.03
		)
		and is_equal_approx(
			overall_global_stats.qi_bonuses.attack_speed_bonus,
			0.10
		)
		and is_equal_approx(
			overall_global_stats.qi_bonuses.projectile_speed_bonus,
			0.10
		)
		and overall_global_stats.qi_bonuses.delivery_count_bonus == 0
		and is_equal_approx(
			overall_global_stats.shen_bonuses.aoe_radius_bonus,
			0.12
		)
		and overall_global_stats.shen_bonuses.delivery_count_bonus == 0
		and is_equal_approx(
			overall_global_stats.shen_bonuses.targeting_range_bonus,
			0.05
		),
		"Source-specific global bonus snapshots did not preserve every reward."
	)
	_check(
		stats_panel_text.contains("碎片  攻速")
		and stats_panel_text.contains("身法")
		and stats_panel_text.contains("加减速")
		and stats_panel_text.contains("移动  横向"),
		"Compact player-stat panel did not replace 精气神 with universal stats."
	)

	var capped_resources := RunResources.new()
	capped_resources.cultivation_config = test_cultivation_config
	game.add_child(capped_resources)
	capped_resources.add_cultivation_fragment(
		CultivationTypesResource.CultivationType.JING,
		31 * 3
	)
	var capped_jing := capped_resources.get_cultivation_stats(
		CultivationTypesResource.CultivationType.JING
	)
	var capped_jing_stats := capped_jing["stats"] as Dictionary
	_check(
		capped_resources.get_cultivation_level(
			CultivationTypesResource.CultivationType.JING
		) == 31
		and is_equal_approx(
			float(
				capped_jing_stats.get(
					CultivationRewardResource.Stat.CRITICAL_CHANCE,
					0.0
				)
			),
			0.2
		)
		and is_equal_approx(
			float(capped_jing["damage_bonus"]),
			3.12
		),
		"Capped rewards did not convert later occurrences to type damage."
	)

	_check(
		player.collect_weapon(FLYING_SWORD_DATA, 11),
		"Flying Sword could not be re-equipped for delivery testing."
	)
	_check(
		player.collect_weapon(FLYING_SWORD_DATA, 9),
		"Weaker duplicate Flying Sword did not add another projectile."
	)
	_check(
		player.select_weapon_slot(1),
		"Flying Sword delivery test could not select weapon slot 2."
	)
	var volley_target := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	volley_target.player = player
	volley_target.max_health = 999
	volley_target.cruise_speed = 1.0
	game.add_child(volley_target)
	volley_target.global_position = (
		player.global_position + Vector2(0.0, -40.0)
	)
	var saw_multi_sword_sequence := false
	for _frame in 30:
		await physics_frame
		saw_multi_sword_sequence = (
			saw_multi_sword_sequence
			or player.get_pending_flying_sword_count() >= 2
		)
	_check(
		player.get_flying_sword_projectile_count() == 3
		and saw_multi_sword_sequence,
		"Duplicate pickups did not produce a three-sword sequential volley."
	)
	volley_target.queue_free()
	await _wait_process_frames(2)

	_check(
		player.collect_weapon(QIANKUN_RING_DATA, 11),
		"Universe Ring could not be re-equipped for delivery testing."
	)
	_check(
		player.collect_weapon(QIANKUN_RING_DATA, 9),
		"Weaker duplicate Universe Ring did not add another projectile."
	)
	_check(
		player.select_weapon_slot(2),
		"Universe Ring delivery test could not select weapon slot 3."
	)
	var ring_target_a := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	var ring_target_b := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	for ring_target in [ring_target_a, ring_target_b]:
		ring_target.player = player
		ring_target.max_health = 999
		ring_target.cruise_speed = 1.0
		game.add_child(ring_target)
	ring_target_a.global_position = (
		player.global_position + Vector2(0.0, -70.0)
	)
	ring_target_b.global_position = (
		player.global_position + Vector2(70.0, -90.0)
	)
	player.set("_attack_cooldown_remaining", 999.0)
	await _wait_physics_frames(3)
	player.call(
		"_begin_qiankun_ring_sequence",
		player.call("_roll_current_attack_damage")
	)
	_check(
		player.get_current_delivery_count() == 3
		and player.get_active_qiankun_ring_count() == 1
		and player.get_pending_qiankun_ring_count() == 2,
		"Duplicate Universe Rings did not begin a sequential three-ring volley."
	)
	player.call("_cancel_qiankun_ring_sequence")
	for projectile_node in game.get_children():
		if projectile_node is QiankunRingProjectile:
			projectile_node.queue_free()
	await _wait_process_frames(2)
	player.set_movement_enabled(false)
	var test_ring := preload(
		"res://game/scenes/gameplay/qiankun_ring_projectile.tscn"
	).instantiate() as QiankunRingProjectile
	game.add_child(test_ring)
	test_ring.global_position = player.global_position
	test_ring.enemy_hit.connect(_on_test_ring_enemy_hit)
	test_ring.configure(
		player,
		ring_target_a,
		1,
		player.get_qiankun_ring_bounce_count(),
		player.get_current_weapon_combat_stats().secondary_targeting_range,
		0.0
	)
	await _wait_physics_frames(120)
	_check(
		player.get_current_delivery_count() == 3
		and player.get_qiankun_ring_bounce_count() == 2
		and _ring_delivery_hits == 3,
		"Universe Ring did not keep two constant-damage bounces."
	)
	if is_instance_valid(test_ring):
		test_ring.queue_free()
	ring_target_a.queue_free()
	ring_target_b.queue_free()
	await _wait_process_frames(2)

	var splash_primary := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	var splash_secondary := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	for splash_target in [splash_primary, splash_secondary]:
		splash_target.player = player
		splash_target.max_health = 999
		splash_target.cruise_speed = 1.0
		game.add_child(splash_target)
	splash_primary.global_position = (
		player.global_position + Vector2(0.0, -70.0)
	)
	splash_secondary.global_position = (
		splash_primary.global_position + Vector2(24.0, 0.0)
	)
	var splash_ring := preload(
		"res://game/scenes/gameplay/qiankun_ring_projectile.tscn"
	).instantiate() as QiankunRingProjectile
	game.add_child(splash_ring)
	splash_ring.global_position = player.global_position
	splash_ring.configure(
		player,
		splash_primary,
		1,
		0,
		player.get_current_weapon_combat_stats().secondary_targeting_range,
		player.get_current_aoe_radius(),
		player.get_current_projectile_speed_multiplier()
	)
	await _wait_physics_frames(80)
	_check(
		splash_primary.current_health == 998
		and splash_secondary.current_health == 998,
		"Resolved 神 area radius did not produce Universe Ring splash damage."
	)
	if is_instance_valid(splash_ring):
		splash_ring.queue_free()
	splash_primary.queue_free()
	splash_secondary.queue_free()
	await _wait_process_frames(2)

	var sword_energy_target_a := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	var sword_energy_target_b := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	for sword_energy_target in [
		sword_energy_target_a,
		sword_energy_target_b,
	]:
		sword_energy_target.player = player
		sword_energy_target.max_health = 999
		sword_energy_target.cruise_speed = 1.0
		game.add_child(sword_energy_target)
	sword_energy_target_a.global_position = (
		player.global_position + Vector2(45.0, 0.0)
	)
	sword_energy_target_b.global_position = (
		player.global_position + Vector2(90.0, 0.0)
	)
	var energy_sword := preload(
		"res://game/scenes/gameplay/flying_sword_projectile.tscn"
	).instantiate() as FlyingSwordProjectile
	energy_sword.initial_energy = 2.0
	energy_sword.energy_cost_per_hit = 1.0
	energy_sword.travel_speed = 600.0
	game.add_child(energy_sword)
	energy_sword.global_position = player.global_position
	energy_sword.configure(Vector2.RIGHT, 1, 200.0)
	await _wait_physics_frames(20)
	_check(
		sword_energy_target_a.current_health == 998
		and sword_energy_target_b.current_health == 998
		and not is_instance_valid(energy_sword),
		"Flying Sword did not pierce until its configured energy was exhausted."
	)
	sword_energy_target_a.queue_free()
	sword_energy_target_b.queue_free()
	await _wait_process_frames(2)

	var range_sword := preload(
		"res://game/scenes/gameplay/flying_sword_projectile.tscn"
	).instantiate() as FlyingSwordProjectile
	range_sword.travel_speed = 600.0
	game.add_child(range_sword)
	range_sword.global_position = player.global_position
	range_sword.configure(Vector2.LEFT, 1, 40.0)
	await _wait_physics_frames(12)
	_check(
		not is_instance_valid(range_sword),
		"Flying Sword survived beyond twice its resolved attack range."
	)

	player.set_movement_enabled(true)
	_check(
		player.collect_weapon(GOLDEN_BELL_DATA, 4)
		and player.collect_weapon(GOLDEN_BELL_DATA, 3),
		"Golden Bell pickups did not equip and add a second layer."
	)
	_check(
		player.select_weapon_slot(3),
		"Golden Bell could not be selected from weapon slot 4."
	)
	var golden_bell := player.get_node("GoldenBell") as GoldenBellController
	var bell_target := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	bell_target.player = player
	bell_target.max_health = 999
	bell_target.cruise_speed = 1.0
	bell_target.melee_attack_interval = 10.0
	game.add_child(bell_target)
	bell_target.global_position = player.global_position + Vector2(30.0, 0.0)
	var bell_damage := player.get_current_weapon_damage()
	var expected_bell_damage := maxi(
		bell_damage,
		ceili(
			float(bell_target.max_health)
				* golden_bell.ordinary_enemy_damage_ratio
		)
	)
	await _wait_physics_frames(4)
	var initial_knockback_speed := bell_target.get_knockback_velocity().length()
	_check(
		golden_bell.get_layer_count() == 2
		and golden_bell.get_ready_layer_count() == 1
		and golden_bell.get_flashing_layer_count() == 1
		and golden_bell.get_layer_phase(0)
			== GoldenBellController.LayerPhase.READY
		and golden_bell.get_layer_phase(1)
			== GoldenBellController.LayerPhase.FLASHING
		and golden_bell.layer_width >= 2.5
		and golden_bell.layer_spacing >= 4.0
		and bell_target.current_health == 999 - expected_bell_damage
		and initial_knockback_speed > 0.0,
		"Golden Bell impact did not consume one layer, damage, and angle-knock the enemy."
	)
	var lifespan_before_bell_block := resources.current_lifespan
	player.take_melee_damage(5.0, bell_target)
	_check(
		is_equal_approx(
			resources.current_lifespan,
			lifespan_before_bell_block
		),
		"Flashing Golden Bell layer did not protect the player."
	)
	await _wait_physics_frames(12)
	_check(
		bell_target.get_knockback_velocity().length()
			< initial_knockback_speed,
		"Knocked enemy did not gradually return toward steady movement."
	)
	await _wait_physics_frames(24)
	_check(
		golden_bell.get_flashing_layer_count() == 0
		and golden_bell.get_recovering_layer_count() == 1,
		"Consumed Golden Bell layer did not disappear after its 0.5-second flash."
	)
	await _wait_physics_frames(190)
	_check(
		golden_bell.get_ready_layer_count() == 2
		and is_equal_approx(golden_bell.recovery_duration, 0.8),
		"Golden Bell layer did not use its much faster recovery."
	)
	golden_bell.configure_weapon(true, 7, bell_damage)
	golden_bell.configure_weapon(true, 4, bell_damage)
	_check(
		golden_bell.get_layer_count() == 4,
		"Golden Bell visuals retained more layers than the equipped quantity."
	)
	golden_bell.configure_weapon(true, 2, bell_damage)
	if is_instance_valid(bell_target):
		bell_target.queue_free()
	await _wait_process_frames(2)
	var elite_bell_target := preload(
		"res://game/scenes/gameplay/enemy.tscn"
	).instantiate() as EnemyController
	elite_bell_target.player = player
	elite_bell_target.max_health = 100
	elite_bell_target.cruise_speed = 1.0
	elite_bell_target.melee_attack_interval = 10.0
	game.add_child(elite_bell_target)
	elite_bell_target.configure_elite(3.0, 1.2, 1.2)
	elite_bell_target.global_position = (
		player.global_position + Vector2(30.0, 0.0)
	)
	await _wait_physics_frames(4)
	_check(
		elite_bell_target.get_ordinary_health_equivalent() == 100
		and elite_bell_target.current_health == 210,
		"Golden Bell elite damage did not equal 90% of ordinary health."
	)
	elite_bell_target.queue_free()
	await _wait_process_frames(2)
	player.set_movement_enabled(false)

	var fragment := preload(
		"res://game/scenes/gameplay/cultivation_fragment.tscn"
	).instantiate() as CultivationFragment
	fragment.cycle_interval = 0.1
	fragment.channel_duration = 0.6
	fragment.configure(player, Vector2.ZERO)
	fragment.fragment_collected.connect(_on_fragment_collected)
	fragment.fragment_collected.connect(resources.add_cultivation_fragment)
	fragment.channel_changed.connect(hud.on_cultivation_channel_changed)
	game.add_child(fragment)
	fragment.global_position = player.global_position + Vector2(300.0, 0.0)
	await _wait_physics_frames(8)
	_check(
		fragment.current_type
			== CultivationTypesResource.CultivationType.QI,
		"Fragment did not cycle deterministically from 精 to 气."
	)

	fragment.cycle_interval = 1.0
	fragment.global_position = player.global_position
	await _wait_physics_frames(2)
	var locked_type := int(fragment.current_type)
	await _wait_physics_frames(10)
	_check(
		fragment.is_type_locked()
		and int(fragment.current_type) == locked_type
		and fragment.get_channel_progress() > 0.0
		and hud.channel_feedback.visible,
		"Remaining in range did not lock the fragment and publish progress."
	)
	fragment.global_position = player.global_position + Vector2(300.0, 0.0)
	await _wait_physics_frames(1)
	_check(
		not fragment.is_type_locked()
		and is_zero_approx(fragment.get_channel_progress())
		and int(fragment.current_type) == locked_type
		and hud.channel_label.text.contains("引导中断"),
		"Leaving range did not cancel, unlock, and preserve cycle position."
	)

	var fragments_before_completion := resources.get_cultivation_fragments(
		locked_type
	)
	fragment.global_position = player.global_position
	await _wait_physics_frames(40)
	await _wait_process_frames(2)
	_check(
		_fragment_completions == 1
		and _completed_fragment_type == locked_type
		and not is_instance_valid(fragment)
		and resources.get_cultivation_fragments(locked_type)
			== (fragments_before_completion + 1) % 3,
		"Completed channel did not collect exactly once and clean up safely."
	)
	player.set_movement_enabled(true)

	if _failures.is_empty():
		print("CULTIVATION TEST: PASS")
		quit(0)
	else:
		print("CULTIVATION TEST: FAIL (%d failures)" % _failures.size())
		quit(1)


func _on_fragment_collected(cultivation_type: int) -> void:
	_fragment_completions += 1
	_completed_fragment_type = cultivation_type


func _on_combat_stats_changed(
	_global_stats: PlayerGlobalCombatStatsResource,
	_weapon_stats: WeaponCombatStatsResource
) -> void:
	_combat_stats_updates += 1


func _on_test_ring_enemy_hit(_enemy: EnemyController) -> void:
	_ring_delivery_hits += 1
