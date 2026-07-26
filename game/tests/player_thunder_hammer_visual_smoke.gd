extends SceneTree

const PLAYER_SCENE := preload("res://game/scenes/gameplay/player.tscn")
const ENEMY_SCENE := preload("res://game/scenes/gameplay/enemy.tscn")
const THUNDER_HAMMER_DATA := preload(
	"res://game/resources/weapon/thunder_hammer.tres"
)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("PLAYER THUNDER HAMMER VISUAL TEST: %s" % message)


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2.ZERO
	player.set_movement_enabled(false)
	player.collect_weapon(
		THUNDER_HAMMER_DATA,
		THUNDER_HAMMER_DATA.minimum_damage
	)
	player.collect_weapon(
		THUNDER_HAMMER_DATA,
		THUNDER_HAMMER_DATA.minimum_damage
	)
	_check(
		player.select_weapon_slot(0),
		"Thunder Hammer could not be equipped."
	)

	var target := ENEMY_SCENE.instantiate() as EnemyController
	target.player = player
	target.max_health = 500
	target.cruise_speed = 1.0
	target.melee_attack_interval = 99.0
	root.add_child(target)
	target.global_position = Vector2(120.0, 0.0)
	await _wait_physics_frames(3)
	await _wait_process_frames(2)

	var visual := player.thunder_hammer_visual
	_check(
		player.is_thunder_hammer_visual_equipped()
		and player.is_thunder_hammer_target_ready()
		and player.get_thunder_hammer_charge_ratio() > 0.99
		and visual.charge_arc.points.size() >= 20
		and visual.target_arc.visible
		and visual.target_arc.points.size() == 5,
		"Charged hammer did not expose its complete target-ready lightning state."
	)

	player.call(
		"_begin_special_projectile_sequence",
		WeaponData.AttackKind.THUNDER_HAMMER,
		AttackDamageResult.new(5, false, 5.0)
	)
	await _wait_process_frames(2)
	_check(
		int(player.get("_pending_special_projectiles")) == 1
		and absf(player.get_thunder_hammer_charge_ratio() - 0.5) < 0.05
		and player.get_thunder_hammer_discharge_strength() > 0.0
		and not player.is_thunder_hammer_target_ready(),
		"First cloud did not discharge half of the two-cloud readiness state."
	)

	player.call("_launch_next_special_projectile")
	await _wait_process_frames(2)
	var resolved_cooldown := player.get_current_attack_interval()
	_check(
		int(player.get("_pending_special_projectiles")) == 0
		and is_equal_approx(
			float(player.get("_attack_cooldown_remaining")),
			resolved_cooldown
		)
		and player.get_thunder_hammer_charge_ratio() < 0.05
		and not player.is_thunder_hammer_target_ready(),
		"Final cloud did not empty the hammer and begin post-volley cooldown."
	)

	player.set("_attack_cooldown_remaining", resolved_cooldown * 0.5)
	await _wait_process_frames(2)
	_check(
		absf(player.get_thunder_hammer_charge_ratio() - 0.5) < 0.05,
		"Hammer lightning did not represent half cooldown progress."
	)

	player.set("_attack_cooldown_remaining", 0.0)
	await _wait_process_frames(2)
	_check(
		player.get_thunder_hammer_charge_ratio() > 0.99
		and player.is_thunder_hammer_target_ready(),
		"Hammer did not return to charged target readiness after cooldown."
	)

	player.select_starting_weapon()
	await _wait_process_frames(2)
	_check(
		not player.is_thunder_hammer_visual_equipped()
		and not visual.visible,
		"Thunder Hammer readiness VFX remained visible after switching weapons."
	)

	target.queue_free()
	player.queue_free()
	if _failures.is_empty():
		print("PLAYER THUNDER HAMMER VISUAL TEST: PASS")
	else:
		print(
			"PLAYER THUNDER HAMMER VISUAL TEST: FAIL (%d failures)"
			% _failures.size()
		)
	quit()
