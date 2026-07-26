extends SceneTree

const PLAYER_SCENE := preload("res://game/scenes/gameplay/player.tscn")
const ENEMY_SCENE := preload("res://game/scenes/gameplay/enemy.tscn")
const SEAL_SCENE := preload(
	"res://game/scenes/gameplay/fantian_seal_projectile.tscn"
)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("REALM VARIANT TEST: %s" % message)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _enemy(player: PlayerController, health: int = 20) -> EnemyController:
	var enemy := ENEMY_SCENE.instantiate() as EnemyController
	enemy.player = player
	enemy.max_health = health
	enemy.cruise_speed = 1.0
	enemy.melee_attack_interval = 99.0
	root.add_child(enemy)
	return enemy


func _run() -> void:
	var resources := RunResources.new()
	root.add_child(resources)
	resources.set_process(false)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(4000.0, 4000.0)
	player.bind_cultivation(resources)
	resources.cultivation_level_changed.connect(player.apply_cultivation_level)
	player.set_movement_enabled(true)
	_check(
		player.character_sprite.sprite_frames.get_frame_count(&"flip") == 9,
		"Qi Refining roll did not load all nine flip frames."
	)
	var received_damage := 0.0
	player.melee_damage_received.connect(
		func(amount: float) -> void: received_damage += amount
	)
	_check(player.start_qi_refining_roll(), "Qi Refining roll did not start.")
	await _wait_physics_frames(2)
	_check(
		player.is_rolling()
		and player.character_sprite.animation == &"flip",
		"Roll state/animation mismatch (%s, %s)."
			% [player.is_rolling(), player.character_sprite.animation]
	)
	player.take_melee_damage(50.0)
	_check(
		is_zero_approx(received_damage),
		"Roll did not grant complete damage immunity."
	)
	var roll_target := _enemy(player, 50)
	roll_target.global_position = player.global_position + Vector2(0.0, -30.0)
	await _wait_physics_frames(10)
	_check(
		roll_target.current_health == 50,
		"Player attacked while rolling."
	)
	await _wait_physics_frames(30)
	_check(
		not player.is_rolling()
		and player.get_roll_cooldown_remaining() > 0.7
		and not player.start_qi_refining_roll(),
		"Roll did not enforce its 0.8-second post-roll cooldown."
	)
	roll_target.queue_free()

	var spawner := EnemySpawner.new()
	spawner.player = player
	spawner.flying_spawn_chance = 1.0
	spawner.initial_ranged_flying_spawn_chance = 1.0
	spawner.ranged_flying_spawn_chance = 1.0
	spawner.nascent_ranged_flying_spawn_chance = 1.0
	spawner.slow_autonomous_spawn_chance = 1.0
	spawner.fast_autonomous_spawn_chance = 1.0
	spawner.bomber_spawn_chance = 0.0
	spawner.healer_spawn_chance = 0.0
	root.add_child(spawner)
	var before_unlock := _enemy(player)
	spawner.set_cultivation_level(11)
	spawner.call("_configure_enemy_variant", before_unlock, false)
	var foundation_normal := _enemy(player)
	spawner.set_cultivation_level(12)
	spawner.call("_configure_enemy_variant", foundation_normal, false)
	var early_elite := _enemy(player)
	early_elite.configure_elite(2.0, 1.2, 1.2)
	spawner.set_cultivation_level(13)
	spawner.call("_configure_enemy_variant", early_elite, true)
	var foundation_elite := _enemy(player)
	foundation_elite.configure_elite(2.0, 1.2, 1.2)
	spawner.set_cultivation_level(14)
	spawner.call("_configure_enemy_variant", foundation_elite, true)
	var golden_ranged := _enemy(player)
	spawner.set_cultivation_level(19)
	spawner.call("_configure_enemy_variant", golden_ranged, false)
	var golden_mobile_elite := _enemy(player)
	golden_mobile_elite.configure_elite(2.0, 1.2, 1.2)
	spawner.set_cultivation_level(23)
	spawner.call("_configure_enemy_variant", golden_mobile_elite, true)
	var nascent_fast := _enemy(player)
	spawner.set_cultivation_level(28)
	spawner.call("_configure_enemy_variant", nascent_fast, false)
	_check(
		not before_unlock.is_flying
		and foundation_normal.is_flying
		and not foundation_normal.uses_ranged_attack
		and not early_elite.is_flying
		and foundation_elite.is_flying
		and golden_ranged.uses_ranged_attack
		and is_equal_approx(
			golden_mobile_elite.autonomous_lateral_speed,
			spawner.slow_autonomous_speed
		)
		and is_equal_approx(
			nascent_fast.autonomous_lateral_speed,
			spawner.fast_autonomous_speed
		),
		"Realm/layer enemy flight progression did not match its thresholds."
	)

	var bomber := _enemy(player, 100)
	bomber.configure_archetype(EnemyController.EnemyArchetype.BOMBER)
	var enemy_shadow := bomber.get_node("EnemyShadow") as PlayerShadow
	var player_shadow := player.get_node("PlayerShadow") as PlayerShadow
	var flying_bomber := _enemy(player, 100)
	flying_bomber.configure_archetype(EnemyController.EnemyArchetype.BOMBER)
	flying_bomber.configure_flying(2, false, 0.0)
	var dissolve_enemy := _enemy(player, 1)
	dissolve_enemy.take_melee_damage(1)
	await _wait_physics_frames(2)
	var dissolve_material := (
		dissolve_enemy.enemy_sprite.material as ShaderMaterial
	)
	var healer := _enemy(player, 30)
	healer.configure_archetype(EnemyController.EnemyArchetype.HEALER)
	var ally := _enemy(player, 30)
	ally.take_melee_damage(10)
	healer.global_position = ally.global_position
	healer.call("_update_healing", healer.healing_interval)
	healer.configure_flying(3, true, spawner.fast_autonomous_speed)
	var rejected_elite_healer := _enemy(player, 30)
	rejected_elite_healer.configure_elite(2.0, 1.2, 1.2)
	rejected_elite_healer.configure_archetype(
		EnemyController.EnemyArchetype.HEALER
	)
	_check(
		bomber.max_health == 100
		and enemy_shadow != null
		and enemy_shadow.base_size.x < player_shadow.base_size.x
		and enemy_shadow.base_size.y < player_shadow.base_size.y
		and flying_bomber.enemy_sprite.sprite_frames.get_frame_count(&"move")
			== 9
		and flying_bomber.enemy_sprite.sprite_frames.get_frame_count(&"explode")
			== 9
		and dissolve_material != null
		and dissolve_material.shader.resource_path
			== "res://game/shaders/enemy_dissolve.gdshader"
		and ally.current_health > 20
		and healer.get_active_healing_icon_count()
			== EnemyController.HEALING_ICON_COUNT
		and not healer.is_flying
		and healer.archetype == EnemyController.EnemyArchetype.HEALER
		and rejected_elite_healer.archetype
			== EnemyController.EnemyArchetype.MELEE,
		"Bomber health or ground-only ordinary healing behavior is wrong."
	)

	resources.demote_to_realm(2, 1)
	await _wait_physics_frames(2)
	_check(
		player.character_sprite.animation == &"golden_core_fly",
		"Golden Core did not select its realm-specific flying animation."
	)
	resources.add_qi(10)
	_check(
		not player.realm_abilities.is_qi_shield_active()
		and player.realm_abilities.toggle_qi_shield()
		and player.realm_abilities.is_qi_shield_active(),
		"Golden Core Space ability did not toggle its default-off Qi shield."
	)
	var lifespan_before_shield := resources.current_lifespan
	player.take_melee_damage(4.0)
	_check(
		resources.current_qi == 6
		and is_equal_approx(
			resources.current_lifespan,
			lifespan_before_shield
		),
		"Golden Core Qi shield did not absorb damage from the Qi bar."
	)
	_check(
		player.realm_abilities.toggle_qi_shield()
		and not player.realm_abilities.is_qi_shield_active(),
		"Golden Core Qi shield did not toggle off."
	)

	var tracking_target := _enemy(player, 100)
	tracking_target.global_position = Vector2(2000.0, 2000.0)
	var seal := SEAL_SCENE.instantiate() as FantianSealProjectile
	root.add_child(seal)
	seal.global_position = tracking_target.global_position
	seal.configure(tracking_target, 6, 80.0)
	await _wait_physics_frames(2)
	tracking_target.global_position += Vector2(85.0, 30.0)
	await _wait_physics_frames(2)
	_check(
		seal.global_position.is_equal_approx(tracking_target.global_position),
		"Fantian Seal did not track the locked enemy's movement."
	)

	var change_error := change_scene_to_file(
		"res://game/scenes/gameplay/game.tscn"
	)
	_check(change_error == OK, "Gameplay scene could not open for UI checks.")
	await _wait_physics_frames(3)
	var game := current_scene
	var hud := game.get_node("GameplayHud") as GameplayHud
	var pause := game.get_node("PauseMenu")
	var game_player := game.get_node("Player") as PlayerController
	var palm_geometry_check := pause.get_node(
		"Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls/PalmGeometryCheck"
	) as CheckButton
	_check(
		not hud.cultivation_tracks_label.visible
		and hud.attack_speed_level_label.visible
		and hud.attack_speed_level_label.text.contains("Lv.")
		and not pause.is_debug_panel_visible()
		and pause.get_node_or_null(
			"Overlay/DebugPanel/DebugScroll/DebugMargin/DebugControls"
		) != null,
		"Compact fragment levels are missing or debug started unlocked."
	)
	pause.pause_game()
	for keycode in [
		KEY_UP,
		KEY_UP,
		KEY_DOWN,
		KEY_DOWN,
		KEY_LEFT,
		KEY_LEFT,
		KEY_RIGHT,
		KEY_RIGHT,
		KEY_B,
		KEY_A,
		KEY_B,
		KEY_A,
	]:
		var unlock_event := InputEventKey.new()
		unlock_event.keycode = keycode
		unlock_event.physical_keycode = keycode
		unlock_event.pressed = true
		Input.parse_input_event(unlock_event)
	await _wait_process_frames(1)
	_check(
		pause.is_debug_panel_visible(),
		"Pause debug panel did not unlock after the hidden key sequence."
	)
	palm_geometry_check.button_pressed = true
	_check(
		game_player.is_palm_debug_geometry_visible(),
		"Pause debug panel did not enable exact Palm combat geometry."
	)
	pause.resume_game()
	_check(
		not pause.is_debug_panel_visible(),
		"Pause debug panel remained visible after resuming."
	)

	if _failures.is_empty():
		print("REALM VARIANT TEST: PASS")
	else:
		print("REALM VARIANT TEST: FAIL (%d failures)" % _failures.size())
	quit()
