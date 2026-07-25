extends SceneTree

const PLAYER_SCENE := preload("res://game/scenes/gameplay/player.tscn")
const ENEMY_SCENE := preload("res://game/scenes/gameplay/enemy.tscn")
const NORMAL_KNIFE := preload(
	"res://assets/enemy_weapons/normal_knife.png"
)
const ELITE_KNIFE := preload(
	"res://assets/enemy_weapons/elite_knife.png"
)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("ENEMY MELEE WEAPON TEST: %s" % message)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2.ZERO
	player.set_movement_enabled(false)

	var enemy := ENEMY_SCENE.instantiate() as EnemyController
	enemy.player = player
	enemy.cruise_speed = 1.0
	enemy.melee_attack_interval = 99.0
	root.add_child(enemy)
	enemy.global_position = Vector2(220.0, 0.0)
	await _wait_physics_frames(15)
	_check(
		not enemy.melee_weapon.visible,
		"The ordinary knife remained visible outside its warning distance."
	)

	enemy.global_position = Vector2(130.0, 0.0)
	await _wait_physics_frames(15)
	_check(
		enemy.melee_weapon.visible
		and enemy.melee_weapon.texture == NORMAL_KNIFE
		and enemy.melee_weapon.modulate.a > 0.95,
		"Approaching melee range did not summon the ordinary knife."
	)

	enemy.global_position = Vector2(65.0, 0.0)
	await _wait_physics_frames(2)
	var first_shake_position := enemy.melee_weapon.position
	await _wait_physics_frames(2)
	var weapon_material := enemy.melee_weapon.material as ShaderMaterial
	var shake_outline: Color = (
		weapon_material.get_shader_parameter(&"outline_color")
	)
	_check(
		enemy.melee_weapon.position.distance_to(first_shake_position) > 0.5
		and shake_outline.a > 0.5
		and shake_outline.r > shake_outline.g,
		"The knife did not shake with a dark-red outline near melee range."
	)

	enemy.set("_melee_cooldown_remaining", 0.0)
	enemy.global_position = Vector2(40.0, 0.0)
	await _wait_physics_frames(2)
	var first_attack_rotation := enemy.melee_weapon.rotation
	await _wait_physics_frames(8)
	var attack_outline: Color = (
		weapon_material.get_shader_parameter(&"outline_color")
	)
	var first_trail := enemy.get_node(
		"MeleeWeaponTrail1"
	) as Sprite2D
	var knife_tip_distance := (
		enemy.melee_weapon.position.length() + 720.0 * 0.04
	)
	_check(
		enemy.is_attack_winding_up()
		and absf(
			angle_difference(
				first_attack_rotation,
				enemy.melee_weapon.rotation
			)
		) > 0.5,
		"Entering melee range did not begin the orbiting knife attack."
	)
	_check(
		attack_outline.a > 0.8
		and attack_outline.g > shake_outline.g
		and first_trail.visible
		and absf(
			knife_tip_distance - enemy.melee_attack_range
		) < 1.0,
		"The attack lacked its bright outline, edge reach, or knife trail."
	)
	await _wait_physics_frames(42)
	_check(
		not enemy.is_attack_winding_up()
		and enemy.melee_weapon.position.distance_to(
			Vector2(34.0, -12.0)
		) < 8.0,
		"The knife did not return to its hover position after attacking."
	)

	var elite := ENEMY_SCENE.instantiate() as EnemyController
	elite.player = player
	elite.configure_elite(2.0, 1.2, 1.2)
	root.add_child(elite)
	_check(
		elite.melee_weapon.texture == ELITE_KNIFE,
		"Elite melee enemies did not select the elite knife."
	)

	enemy.queue_free()
	elite.queue_free()
	player.queue_free()
	await _wait_physics_frames(2)
	if _failures.is_empty():
		print("ENEMY MELEE WEAPON TEST: PASS")
	else:
		print(
			"ENEMY MELEE WEAPON TEST: FAIL (%d failures)"
			% _failures.size()
		)
	quit()
