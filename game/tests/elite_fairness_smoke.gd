extends Node

const EnemySpawnerResource = preload(
	"res://game/scripts/gameplay/enemy_spawner.gd"
)
const PLAYER_SCENE: PackedScene = preload(
	"res://game/scenes/gameplay/player.tscn"
)

var _failures: Array[String] = []


func _ready() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	var camera := Camera2D.new()
	var spawner := EnemySpawnerResource.new() as EnemySpawner
	add_child(player)
	add_child(camera)
	spawner.player = player
	spawner.camera = camera
	add_child(spawner)
	spawner.set_spawning_enabled(false)
	player.set_movement_enabled(false)
	await get_tree().process_frame

	_check(
		is_equal_approx(spawner.initial_elite_spawn_chance, 0.10)
		and is_equal_approx(spawner.elite_spawn_chance, 0.18)
		and is_equal_approx(spawner.trial_initial_elite_spawn_chance, 0.12)
		and is_equal_approx(spawner.trial_elite_spawn_chance, 0.30)
		and spawner.elite_ramp_difficulty_steps == 18
		and is_equal_approx(spawner.normal_elite_population_ratio, 0.16)
		and is_equal_approx(spawner.elite_health_multiplier, 2.5)
		and is_equal_approx(spawner.trial_elite_health_multiplier, 3.0),
		"Elite fairness defaults are not configured."
	)
	_check(
		is_equal_approx(spawner.qi_drop_increase_per_difficulty_step, 0.75)
		and is_equal_approx(spawner.elite_qi_drop_multiplier, 2.0)
		and spawner.get_enemy_qi_drop_amount(18, false, false, false) == 29
		and spawner.get_enemy_qi_drop_amount(18, true, false, false) == 57
		and spawner.get_enemy_qi_drop_amount(18, false, true, false) == 34
		and spawner.get_enemy_qi_drop_amount(18, false, false, true) == 33
		and spawner.get_enemy_qi_drop_amount(18, true, true, true) == 79,
		"Elite and difficulty-scaled Qi rewards are incorrect."
	)

	spawner.set("_elapsed_run_time", 0.0)
	spawner.set_cultivation_level(1)
	_check(
		is_equal_approx(spawner.get_current_elite_spawn_chance(), 0.10),
		"Normal elite chance does not start at ten percent."
	)
	spawner.set_cultivation_level(spawner.elite_ramp_difficulty_steps + 1)
	_check(
		is_equal_approx(spawner.get_current_elite_spawn_chance(), 0.18)
		and spawner.call(
			"_get_elite_cap_for_band",
			EnemySpawner.EliteRoadWidthBand.VERY_NARROW
		) == 3
		and spawner.call(
			"_get_elite_cap_for_band",
			EnemySpawner.EliteRoadWidthBand.NARROW
		) == 4
		and spawner.call(
			"_get_elite_cap_for_band",
			EnemySpawner.EliteRoadWidthBand.STANDARD
		) == 5,
		"Normal elite chance and road caps do not mature with difficulty."
	)
	spawner.set_trial_hell_active(true)
	_check(
		is_equal_approx(spawner.get_current_elite_spawn_chance(), 0.30)
		and spawner.call(
			"_get_elite_cap_for_band",
			EnemySpawner.EliteRoadWidthBand.STANDARD
		) == 6,
		"Trial Hell elite chance or population cap is incorrect."
	)
	spawner.set_trial_hell_active(false)

	for _roll in 64:
		var choices := spawner.call("_roll_power_fragment_choice_types") as Array
		var has_combat_output := false
		for upgrade_type_variant in choices:
			var upgrade_type := int(upgrade_type_variant)
			if upgrade_type in [
				UniversalUpgradeTypes.UpgradeType.ATTACK_SPEED,
				UniversalUpgradeTypes.UpgradeType.DAMAGE,
				UniversalUpgradeTypes.UpgradeType.DAMAGE_RANGE,
			]:
				has_combat_output = true
		_check(
			choices.size() == 2
			and int(choices[0]) != int(choices[1])
			and has_combat_output,
			"Power-fragment choice produced a duplicate or utility-only pair."
		)

	spawner.initial_elite_spawn_chance = 0.0
	spawner.elite_spawn_chance = 0.0
	spawner.set_cultivation_level(1)
	spawner.set("_elapsed_run_time", 0.0)
	spawner.set("_ordinary_defeats_since_elite", 0)
	spawner.set(
		"_last_elite_reward_type",
		EnemyController.EliteRewardType.POWER_FRAGMENT
	)
	spawner.set("_elite_spawn_time_remaining", 0.0)
	spawner.set(
		"_elite_pity_time_elapsed",
		spawner.normal_elite_pity_seconds
	)
	_check(
		spawner.is_elite_pity_due(),
		"Thirty seconds without an elite did not activate normal elite pity."
	)
	spawner.set("_elite_pity_time_elapsed", 0.0)
	var ordinary_enemy := spawner.enemy_scene.instantiate() as EnemyController
	for ordinary_defeat in spawner.normal_elite_pity_defeats:
		spawner.call(
			"_on_enemy_defeated",
			Vector2(float(ordinary_defeat), 0.0),
			Vector2.ZERO,
			ordinary_enemy,
			spawner.enemy_qi_drop_amount
		)
	_check(
		spawner.is_elite_pity_due(),
		"Eight ordinary defeats did not activate normal elite pity."
	)
	ordinary_enemy.queue_free()
	spawner.call("_spawn_enemy")
	await get_tree().process_frame
	var pity_enemy: EnemyController = null
	for child in spawner.get_children():
		if child is EnemyController:
			pity_enemy = child as EnemyController
			break
	var pity_snapshot := spawner.get_debug_snapshot()
	_check(
		pity_enemy != null
		and pity_enemy.is_elite_enemy()
		and pity_enemy.get_elite_reward_type()
			== EnemyController.EliteRewardType.WEAPON
		and pity_enemy.max_health == 8
		and not bool(pity_snapshot["elite_pity_due"])
		and int(pity_snapshot["ordinary_defeats_since_elite"]) == 0
		and spawner.call("_get_next_elite_reward_type")
			== EnemyController.EliteRewardType.POWER_FRAGMENT,
		"Elite pity did not force and reset one affordable alternating elite."
	)

	if _failures.is_empty():
		print("ELITE FAIRNESS TEST: PASS")
		get_tree().quit()
		return
	for failure in _failures:
		push_error("ELITE FAIRNESS TEST: %s" % failure)
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
