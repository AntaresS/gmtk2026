class_name PlayerController
extends CharacterBody2D

signal melee_damage_received(amount: float)
signal lifespan_decay_multiplier_changed(multiplier: float)
signal equipment_changed(
	technique_name: String,
	equipment_name: String,
	damage: int
)
signal equipment_inventory_changed(entries: Array[String], current_index: int)
signal weapon_power_upgraded(level: int, total_damage_bonus: int)
signal universal_upgrade_applied(upgrade_type: int, level: int)
## Publishes fresh read-only player-wide and current-weapon snapshots whenever
## equipment or cultivation progression changes.
signal combat_stats_changed(
	global_stats: PlayerGlobalCombatStatsResource,
	weapon_stats: WeaponCombatStatsResource
)
signal qi_shield_absorbed(
	blocked_damage: float,
	qi_spent: int,
	remaining_damage: float
)
signal spirit_projection_changed(active: bool)
signal realm_ability_state_changed(snapshot: Dictionary)
signal roll_state_changed(active: bool, cooldown_remaining: float)

const WeaponDataResource = preload(
	"res://game/scripts/gameplay/weapon_data.gd"
)
const DEFAULT_STARTING_WEAPON_DATA: WeaponDataResource = preload(
	"res://game/resources/great_strength_palm.tres"
)
const CultivationTypesResource = preload(
	"res://game/scripts/gameplay/cultivation_types.gd"
)
const PlayerGlobalCombatStatsResource = preload(
	"res://game/scripts/gameplay/player_global_combat_stats.gd"
)
const WeaponCombatStatsResource = preload(
	"res://game/scripts/gameplay/weapon_combat_stats.gd"
)
const CombatStatsResolverResource = preload(
	"res://game/scripts/gameplay/combat_stats_resolver.gd"
)
const PlayerCombatConfigResource = preload(
	"res://game/scripts/gameplay/player_combat_config.gd"
)
const AttackDamageResultResource = preload(
	"res://game/scripts/gameplay/attack_damage_result.gd"
)
const DEFAULT_PLAYER_COMBAT_CONFIG: PlayerCombatConfigResource = preload(
	"res://game/resources/player_combat_config.tres"
)
const DAO_WEAPON_TEXTURE: Texture2D = preload(
	"res://assets/player_weapons/dao_knife.png"
)
const PALM_WEAPON_TEXTURE: Texture2D = preload(
	"res://assets/player_weapons/great_strength_palm.png"
)
const FLYING_SWORD_TEXTURE: Texture2D = preload(
	"res://assets/player_weapons/flying_sword.png"
)
const FANTIAN_SEAL_TEXTURE: Texture2D = preload(
	"res://assets/player_weapons/fantian_seal.png"
)
const QIANKUN_RING_TEXTURE: Texture2D = preload(
	"res://assets/player_weapons/qiankun_ring.png"
)
const OUTLINE_SHADER: Shader = preload(
	"res://game/shaders/enemy_outline.gdshader"
)
const FLYING_SWORD_READINESS_SHADER: Shader = preload(
	"res://game/shaders/flying_sword_readiness.gdshader"
)
const DISSOLVE_SHADER: Shader = preload(
	"res://game/shaders/enemy_dissolve.gdshader"
)
const DEFAULT_PALM_EXECUTE_VFX_SCENE: PackedScene = preload(
	"res://game/scenes/gameplay/palm_execute_vfx.tscn"
)
enum PalmVisualState {
	HIDDEN,
	STRIKING,
	DISSOLVING,
	IDLE,
}
enum FantianSealVisualState {
	HIDDEN,
	SUMMONING,
	ASCENDING,
	ABSENT,
	SHADOW_DELAY,
	SHADOW_SHRINK,
}

const PALM_LAUNCH_SCALE: float = 0.035
const PALM_CHARGED_SCALE: float = 0.025
const PALM_STRIKE_SCALE: float = 0.105
const PALM_CENTER_OFFSET_PIXELS: float = 88.0
const PALM_IDLE_RADIUS: float = 68.0
const PALM_CHARGED_RADIUS: float = 24.0
const PALM_WARNING_MARGIN: float = 74.0
const PALM_STRIKE_DURATION: float = 0.13
const PALM_STRIKE_STAGGER: float = 0.14
const PALM_DISSOLVE_DURATION: float = 0.14
const PALM_COVERAGE_FLASH_DURATION: float = 0.22
const PALM_OUTLINE_TEXTURE_WIDTH: float = 20.0
const PALM_GLOW_COLOR: Color = Color("d9ffff")
const FLYING_SWORD_SCALE: float = 0.032
const FLYING_SWORD_MIN_RADIUS_RATIO: float = 1.0 / 3.0
const FLYING_SWORD_MAX_RADIUS_RATIO: float = 2.0 / 3.0
const FLYING_SWORD_RADIUS_RATIO_PER_EXTRA_SWORD: float = 1.0 / 30.0
const FLYING_SWORD_WARNING_EXPANSION_RATIO: float = 0.10
const FLYING_SWORD_WARNING_MARGIN: float = 90.0
const FLYING_SWORD_WARNING_ORBIT_SPEED: float = 0.22
const FLYING_SWORD_SUMMON_DURATION: float = 0.18
const FLYING_SWORD_SUMMON_STAGGER: float = 0.045
const FLYING_SWORD_MAX_SUMMON_WINDOW: float = 0.28
const FLYING_SWORD_REFILL_DURATION: float = 0.14
const FLYING_SWORD_OUTLINE_TEXTURE_WIDTH: float = 22.0
const FLYING_SWORD_OUTLINE_COLOR: Color = Color("f6fbff")
const QIANKUN_RING_SCALE: float = 0.036
const FANTIAN_SEAL_IDLE_SCALE: float = 0.052
const FANTIAN_SEAL_IDLE_POSITION: Vector2 = Vector2(54.0, -8.0)
const FANTIAN_SEAL_SUMMON_DURATION: float = 0.18
const FANTIAN_SEAL_ASCENT_DURATION: float = 0.48
const FANTIAN_SEAL_ASCENT_SCALE_MULTIPLIER: float = 4.65
const FANTIAN_SEAL_SWITCH_SHADOW_DELAY: float = 0.3
const FANTIAN_SEAL_SWITCH_SHADOW_DURATION: float = 0.3
const FANTIAN_SEAL_RANGE_FILL_COLOR := Color(0.055, 0.09, 0.055, 0.025)
const FANTIAN_SEAL_RANGE_EDGE_COLOR := Color(0.38, 0.72, 0.48, 0.34)
const FANTIAN_SEAL_SEQUENCE_WINDOW_RATIO: float = 0.7
const DAO_WEAPON_SCALE: float = 0.045
const DAO_WEAPON_TIP_OFFSET_PIXELS: float = 665.0
const DAO_IDLE_ORBIT_SPEED: float = 0.9
const DAO_ATTACK_ORBIT_SPEED: float = 8.5
const DAO_ATTACK_VISUAL_HOLD_DURATION: float = 0.75
const DAO_ORBIT_ACCELERATION: float = 18.0
const DAO_WARNING_MARGIN: float = 70.0
const DAO_WARNING_SHAKE_START: float = 0.38
const DAO_SUMMON_DURATION: float = 0.22
const DAO_RECALL_DURATION: float = 0.16
const DAO_AUXILIARY_STAGGER: float = 0.055
const DAO_MAX_AUXILIARY_STAGGER_WINDOW: float = 0.24
const DAO_OUTLINE_WORLD_WIDTH: float = 1.0
const DAO_OUTLINE_COLOR: Color = Color("ffd95a")
const DAO_IDLE_TRAIL_ARC: float = PI
const DAO_ATTACK_TRAIL_ARC: float = PI * 1.35
const DAO_IDLE_TRAIL_SEGMENTS: int = 28
const DAO_ATTACK_TRAIL_SEGMENTS: int = 32
const DAO_IDLE_TRAIL_COLOR: Color = Color("e5bb50")
const DAO_ATTACK_TRAIL_COLOR: Color = Color("ffc53d")
const DAO_ATTACK_TRAIL_HIGHLIGHT: Color = Color("fff1a8")
const DAO_MAX_ATTACK_TRAIL_COUNT: int = 24
const VISUAL_TARGET_REFRESH_INTERVAL: float = 0.1

@export_category("Forward Movement")
## Normal automatic forward travel speed in world pixels per second.
@export var base_forward_speed: float = 260.0
## Target forward speed, in pixels per second, while speed_up is held.
@export var boosted_forward_speed: float = 420.0
## Target forward speed, in pixels per second, while slow_down is held. Values
## at or below zero are clamped to preserve forward movement.
@export var slowed_forward_speed: float = 110.0
## Rate, in pixels per second squared, used to approach forward speed targets.
@export var forward_acceleration: float = 360.0

@export_category("Character Animation")
## Ground-running animation used during Qi Refining.
@export var qi_refining_grounded_animation: StringName = &"qi_walk"
## Ground-running animation used after reaching Foundation.
@export var grounded_animation: StringName = &"walk"
## Foundation animation used while temporary flight lifts the player.
@export var airborne_animation: StringName = &"fly"
## Golden Core animation used during the realm's continuous flight.
@export var golden_core_airborne_animation: StringName = &"golden_core_fly"
## Nascent Soul animation used for both the body and projected spirit.
@export var nascent_soul_airborne_animation: StringName = &"nascent_soul_fly"
## Lowest playback multiplier allowed while the player is moving slowly.
@export_range(0.1, 1.0, 0.05) var minimum_animation_speed_scale: float = 0.45
## Highest playback multiplier allowed while the player is accelerating.
@export_range(1.0, 4.0, 0.05) var maximum_animation_speed_scale: float = 1.8
## Elevation in pixels above which the airborne animation becomes active.
@export_range(0.0, 20.0, 0.5) var airborne_animation_threshold: float = 1.0
## Non-looping animation played during the Qi Refining invulnerable roll.
@export var roll_animation: StringName = &"flip"

@export_category("Weapon SFX")
## Audio bus used by weapon cues. Missing bus names safely fall back to Master.
@export var weapon_sfx_bus: StringName = &"SFX"
## Player-wide loudness adjustment applied after each weapon cue's own volume.
@export_range(-40.0, 12.0, 0.5) var weapon_sfx_volume_db: float = 0.0
## Maximum simultaneous weapon cues. When saturated, the oldest cue is reused
## so rapid volleys remain bounded instead of creating unlimited audio nodes.
@export_range(1, 32, 1) var maximum_weapon_sfx_voices: int = 16

@export_category("Qi Refining Roll")
## Seconds during which one roll moves, disables attacks, and grants immunity.
@export_range(0.1, 2.0, 0.05) var roll_duration: float = 0.6
## Recovery seconds after the roll finishes before another roll may begin.
@export_range(0.0, 5.0, 0.05) var roll_cooldown: float = 0.8
## Travel speed in world pixels per second during the roll.
@export_range(100.0, 1200.0, 10.0) var roll_speed: float = 520.0

@export_category("Lateral Movement")
## Immediate left/right speed in world pixels per second. Horizontal input is
## applied directly with no acceleration or release inertia.
@export var lateral_speed: float = 300.0
## Playable half-width measured from road center in world pixels. InfiniteWorld
## replaces this at startup with its shared WorldChunkConfig road width.
@export var road_half_width: float = 224.0
## Margin, in world pixels, kept between the player's center and each road edge.
@export var horizontal_clearance: float = 22.0

@export_category("Starting Technique")
## Shared definition equipped at the beginning of every run. Its display name
## is also presented as the player's cultivation technique on the HUD.
@export var starting_weapon_data: WeaponDataResource = (
	DEFAULT_STARTING_WEAPON_DATA
)

@export_category("Combat Configuration")
## Designer-authored source of truth for player-wide base combat stats and
## global safety limits. Runtime snapshots read this Resource without mutating it.
@export var combat_config: PlayerCombatConfigResource = (
	DEFAULT_PLAYER_COMBAT_CONFIG
)

@export_category("Flying Sword Readability")
## Pale energy color surrounding readied Flying Swords. The alpha channel is
## multiplied by the live warning strength and the glow intensity below.
@export var flying_sword_warning_glow_color: Color = Color("8ce6ff")
## Maximum opacity of the soft readiness glow around each sword.
@export_range(0.0, 1.0, 0.01) var flying_sword_warning_glow_strength := 0.32
## Glow reach in source-texture pixels. Because the sword texture is scaled at
## runtime, larger values widen the aura without changing combat geometry.
@export_range(16.0, 128.0, 1.0) var flying_sword_warning_glow_width := 68.0
## Fraction of glow intensity removed at the low point of its breathing pulse.
## Zero keeps the glow steady; larger values make readiness easier to notice.
@export_range(0.0, 0.8, 0.01) var flying_sword_warning_pulse_depth := 0.35
## Breathing cycles per second while a target is inside the warning margin.
## The first cycle begins bright to make target acquisition immediately clear.
@export_range(0.1, 3.0, 0.05) var flying_sword_warning_pulse_hz := 0.75
## Maximum amount the sword artwork itself shifts toward white while readied.
@export_range(0.0, 0.5, 0.01) var flying_sword_warning_brighten := 0.12
## Color and maximum opacity of the circular reload-progress cue drawn at the
## current sword-orbit radius while any spent sword is being restored.
@export var flying_sword_reload_ring_color := Color(0.55, 0.9, 1.0, 0.62)
## World-pixel width of the Flying Sword reload-progress arc.
@export_range(0.5, 8.0, 0.25) var flying_sword_reload_ring_width := 2.5
## Seconds a partial Flying Sword volley waits for another valid target before
## cancelling into reload. Zero restores immediate cancellation on target loss.
@export_range(0.0, 2.0, 0.05) var flying_sword_target_loss_grace_duration := 0.5

@export_category("Universal Upgrade Fragments")
## Additive attack-speed ratio granted by each global attack-speed fragment.
@export_range(0.0, 1.0, 0.01) var attack_speed_bonus_per_fragment: float = 0.06
## Flat damage granted to every weapon by each damage fragment.
@export_range(0, 100, 1) var damage_bonus_per_fragment: int = 1
## Horizontal speed gained from every movement fragment.
@export_range(0.0, 100.0, 1.0) var lateral_speed_per_fragment: float = 12.0
## Forward acceleration gained from every movement fragment.
@export_range(0.0, 500.0, 5.0) var forward_acceleration_per_fragment: float = 45.0
## Multiplicative damage-range ratio granted per range fragment.
@export_range(0.0, 1.0, 0.01) var range_bonus_per_fragment: float = 0.06
## Boosted forward speed gained per speed-control fragment.
@export_range(0.0, 200.0, 5.0) var boost_speed_per_control_fragment: float = 25.0
## Amount removed from slowed speed per speed-control fragment.
@export_range(0.0, 100.0, 1.0) var slow_speed_reduction_per_fragment: float = 18.0
## Lowest slowed speed reachable through repeated control fragments.
@export_range(1.0, 60.0, 1.0) var minimum_controlled_speed: float = 8.0

@export_category("Great Strength Palm Progression")
## Flat damage added to Great Strength Palm per small cultivation level.
@export_range(0.0, 10.0, 0.05) var palm_damage_per_level: float = 0.5
## Additive range ratio added to Great Strength Palm per small level.
@export_range(0.0, 0.2, 0.005) var palm_range_ratio_per_level: float = 0.025
## Additive attack-speed ratio added to Great Strength Palm per small level.
@export_range(0.0, 0.2, 0.005) var palm_speed_ratio_per_level: float = 0.025
## World-space burst shown when an eligible ordinary enemy is executed by
## Nascent Soul Palm. The spawned scene owns and cleans up its presentation.
@export var palm_execute_vfx_scene: PackedScene = (
	DEFAULT_PALM_EXECUTE_VFX_SCENE
)

@export_category("Collectible Attraction")
## Invisible starting radius, in world pixels, that attracts qi and equipment.
## It is independent from the visible attack range.
@export_range(24.0, 240.0, 1.0) var base_attraction_range: float = 72.0
## Additional invisible attraction radius gained per cultivation level.
@export_range(0.0, 64.0, 1.0) var attraction_range_increase_per_level: float = 10.0
## Speed, in world pixels per second, at which collectibles home to the player.
@export var collectible_attraction_speed: float = 360.0

@export_category("Level-up Effect")
## Duration, in seconds, of the aura shown when cultivation level increases.
@export_range(0.2, 2.0, 0.05) var level_up_effect_duration: float = 0.8
## Final radius, in world pixels, reached by the expanding level-up ring.
@export_range(36.0, 140.0, 1.0) var level_up_effect_radius: float = 76.0
## Duration, in seconds, of the yellow light pillar played after surviving any
## cultivation-realm breakthrough tribulation.
@export_range(0.5, 5.0, 0.1) var breakthrough_effect_duration: float = 2.4
## Size, in world pixels, used to derive the breakthrough pillar's height and
## soft ground glow.
@export_range(80.0, 260.0, 1.0) var breakthrough_effect_radius: float = 156.0

@export_category("Damage Feedback")
## Duration, in seconds, of the player blink, shake, direct-hit effect, and
## floating lifespan-loss number. Enemy swords substitute a crossing slash for
## the ordinary expanding burst while retaining this shared timing.
@export_range(0.2, 1.5, 0.05) var damage_feedback_duration: float = 0.55
## Final radius, in world pixels, reached by the direct-damage impact burst.
## Larger values make hits more prominent among nearby combat effects.
@export_range(36.0, 120.0, 1.0) var damage_feedback_radius: float = 68.0

@onready var combat_anchor: Node2D = $CombatAnchor
@onready var attack_area: Area2D = $CombatAnchor/AttackArea
@onready var attack_shape: CollisionShape2D = (
	$CombatAnchor/AttackArea/CollisionShape2D
)
@onready var attraction_area: Area2D = $CombatAnchor/AttractionArea
@onready var attraction_shape: CollisionShape2D = (
	$CombatAnchor/AttractionArea/CollisionShape2D
)
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var character_sprite: AnimatedSprite2D = $CharacterSprite
@onready var spirit_sprite: AnimatedSprite2D = $SpiritSprite
@onready var dao_weapon_layer: Node2D = $CombatAnchor/DaoWeapons
@onready var flying_sword_layer: Node2D = $CombatAnchor/FlyingSwordWeapons
@onready var palm_weapon: Sprite2D = $CombatAnchor/PalmWeapon
@onready var palm_echo_layer: Node2D = $CombatAnchor/PalmEchoes
@onready var fantian_seal_weapon: Sprite2D = (
	$CombatAnchor/FantianSealWeapon
)
@onready var thunder_hammer_visual: ThunderHammerVisual = (
	$CombatAnchor/ThunderHammerVisual
)
@onready var damage_taken_label: Label = $CombatAnchor/DamageTakenLabel
@onready var realm_abilities: RealmAbilityController = $RealmAbilities
@onready var golden_bell: GoldenBellController = $GoldenBell

var current_forward_speed: float = 0.0
var distance_traveled: float = 0.0
var current_attraction_range: float = 72.0
var road_center_x: float = 0.0
var current_cultivation_level: int = 1

var _movement_enabled: bool = true
var _roll_remaining: float = 0.0
var _roll_cooldown_remaining: float = 0.0
var _roll_direction: Vector2 = Vector2.UP
var _attack_cooldown_remaining: float = 0.0
var _attack_flash_remaining: float = 0.0
var _palm_attack_direction: Vector2 = Vector2.UP
var _palm_aim_target: EnemyController
var _palm_aim_refresh_remaining: float = 0.0
var _palm_visual_state: int = PalmVisualState.HIDDEN
var _palm_visual_equipped: bool = false
var _palm_visual_elapsed: float = 0.0
var _palm_visual_target: EnemyController
var _palm_attack_sprites: Array[Sprite2D] = []
var _palm_visual_directions: Array[Vector2] = []
var _palm_visual_start_positions: Array[Vector2] = []
var _palm_visual_start_scales: Array[float] = []
var _palm_visual_impact_positions: Array[Vector2] = []
var _palm_visual_hit_resolved: Array[bool] = []
var _palm_visual_launched: Array[bool] = []
var _palm_visual_skipped: Array[bool] = []
var _palm_visual_targets: Array = []
var _palm_visual_dissolve_materials: Array[ShaderMaterial] = []
var _palm_warning_strength: float = 0.0
var _palm_glow_material: ShaderMaterial
var _palm_dissolve_material: ShaderMaterial
var _palm_visual_pending_damage: int = 0
var _palm_visual_pending_critical: bool = false
var _palm_cast_direction: Vector2 = Vector2.UP
var _palm_debug_geometry_visible: bool = false
var _flying_sword_visual_sprites: Array[Sprite2D] = []
var _flying_sword_visual_visibility: Array[float] = []
var _flying_sword_visual_filled: Array[bool] = []
var _flying_sword_outline_material: ShaderMaterial
var _flying_sword_visual_equipped: bool = false
var _flying_sword_visual_summoning: bool = false
var _flying_sword_visual_elapsed: float = 0.0
var _flying_sword_orbit_phase: float = 0.0
var _flying_sword_warning_strength: float = 0.0
var _flying_sword_warning_pulse_elapsed: float = 0.0
var _flying_sword_aim_target: EnemyController
var _flying_sword_aim_refresh_remaining: float = 0.0
var _fantian_seal_visual_equipped: bool = false
var _fantian_seal_visual_state: int = FantianSealVisualState.HIDDEN
var _fantian_seal_visual_elapsed: float = 0.0
var _fantian_seal_visual_start_position: Vector2 = Vector2.ZERO
var _fantian_seal_switch_shadow_active: bool = false
var _fantian_seal_switch_shadow_elapsed: float = 0.0
var _damage_flash_remaining: float = 0.0
var _damage_feedback_is_projectile: bool = false
var _shield_flash_remaining: float = 0.0
var _last_shield_blocked_damage: float = 0.0
var _last_shield_qi_spent: int = 0
var _last_damage_amount: float = 0.0
var _character_sprite_rest_position: Vector2 = Vector2.ZERO
var _character_sprite_rest_modulate: Color = Color.WHITE
var _dao_attack_remaining: float = 0.0
var _companion_phase: float = 0.0
var _dao_weapon_sprites: Array[Sprite2D] = []
var _dao_weapon_visibility: Array[float] = []
var _dao_outline_material: ShaderMaterial
var _dao_visual_equipped: bool = false
var _dao_combat_active: bool = false
var _dao_summoning_auxiliaries: bool = false
var _dao_recalling_auxiliaries: bool = false
var _dao_transition_elapsed: float = 0.0
var _dao_orbit_phase: float = -PI * 0.5
var _dao_orbit_speed: float = 0.0
var _dao_warning_strength: float = 0.0
var _dao_attack_visual_hold_remaining: float = 0.0
var _dao_idle_trail_unit_points := PackedVector2Array()
var _dao_attack_trail_unit_points := PackedVector2Array()
var _dao_attack_highlight_unit_points := PackedVector2Array()
var _equipment_inventory: Array[Dictionary] = []
var _current_equipment_index: int = 0
var _weapon_power_level: int = 0
var _universal_upgrade_levels: Array[int] = [0, 0, 0, 0, 0]
var _temporary_lateral_bounds_enabled: bool = false
var _temporary_lateral_min_x: float = 0.0
var _temporary_lateral_max_x: float = 0.0
var _last_lifespan_decay_multiplier: float = 1.0
var _pending_flying_swords: int = 0
var _flying_sword_sequence_total: int = 0
var _flying_sword_sequence_launched: int = 0
var _flying_sword_sequence_damage: int = 1
var _flying_sword_sequence_is_critical: bool = false
var _flying_sword_sequence_timer: float = 0.0
var _flying_sword_target_loss_grace_remaining: float = 0.0
var _flying_sword_reload_active: bool = false
var _flying_sword_reload_duration: float = 0.0
var _level_up_effect_remaining: float = 0.0
var _breakthrough_effect_remaining: float = 0.0
var _pending_qiankun_rings: int = 0
var _qiankun_ring_sequence_total: int = 0
var _qiankun_ring_sequence_launched: int = 0
var _qiankun_ring_sequence_damage: int = 1
var _qiankun_ring_sequence_is_critical: bool = false
var _qiankun_ring_sequence_timer: float = 0.0
var _active_qiankun_rings: int = 0
var _pending_special_projectiles: int = 0
var _special_sequence_kind: int = -1
var _special_sequence_launched: int = 0
var _special_sequence_damage: int = 1
var _special_sequence_exact_damage: float = 1.0
var _special_sequence_is_critical: bool = false
var _special_sequence_timer: float = 0.0
var _special_sequence_interval: float = 0.01
var _special_sequence_total: int = 0
var _special_sequence_targets: Array[EnemyController] = []
var _special_sequence_direction: Vector2 = Vector2.UP
var _fantian_seal_volley_serial: int = 0
var _active_fantian_seal_volley_id: int = -1
var _weapon_sfx_voices: Array[AudioStreamPlayer] = []
var _weapon_sfx_serial: int = 0
var _cultivation_resources: RunResources
var _global_combat_stats: PlayerGlobalCombatStatsResource = (
	PlayerGlobalCombatStatsResource.new()
)
var _current_weapon_combat_stats: WeaponCombatStatsResource = (
	WeaponCombatStatsResource.new()
)


func _ready() -> void:
	_movement_enabled = true
	LanguageManager.language_changed.connect(_on_language_changed)
	_prepare_dao_trail_geometry()
	_character_sprite_rest_position = character_sprite.position
	_character_sprite_rest_modulate = character_sprite.modulate
	damage_taken_label.hide()
	realm_abilities.qi_shield_absorbed.connect(_on_qi_shield_absorbed)
	realm_abilities.spirit_projection_changed.connect(
		_on_spirit_projection_changed
	)
	realm_abilities.ability_state_changed.connect(
		_on_realm_ability_state_changed
	)
	realm_abilities.flight_elevation_changed.connect(
		_on_flight_elevation_changed
	)
	golden_bell.enemy_hit.connect(_on_golden_bell_enemy_hit)
	current_forward_speed = maxf(base_forward_speed, 1.0)
	_last_lifespan_decay_multiplier = get_lifespan_decay_multiplier()
	current_attraction_range = base_attraction_range
	if combat_config == null:
		push_error("Player combat_config must contain a PlayerCombatConfig.")
		combat_config = DEFAULT_PLAYER_COMBAT_CONFIG
	if starting_weapon_data == null or not starting_weapon_data.is_valid_definition():
		push_error("Player starting_weapon_data must contain a valid WeaponData.")
		starting_weapon_data = DEFAULT_STARTING_WEAPON_DATA
	_equipment_inventory = [
		_create_equipment(
			starting_weapon_data,
			starting_weapon_data.minimum_damage
		)
	]
	_current_equipment_index = 0
	_rebuild_combat_stats()
	_apply_attack_range()
	_apply_attraction_range()
	_refresh_palm_visual_equipment()
	_refresh_flying_sword_visual_equipment()
	_refresh_fantian_seal_visual_equipment()
	_refresh_dao_visual_equipment()
	_refresh_thunder_hammer_visual_equipment()
	_publish_equipment()
	queue_redraw()


func _process(delta: float) -> void:
	_update_visual_state(delta)


func _input(event: InputEvent) -> void:
	if (
		_movement_enabled
		and event.is_action_pressed("spirit_projection")
		and not event.is_echo()
	):
		var realm_index := _get_current_realm_index()
		var handled := false
		if realm_index == 0:
			handled = start_qi_refining_roll()
		elif realm_index == 2:
			handled = realm_abilities.toggle_qi_shield()
		if handled:
			get_viewport().set_input_as_handled()
		return
	if _movement_enabled and event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			var direct_slot := _get_direct_weapon_slot(key_event)
			if direct_slot >= 0:
				select_weapon_slot(direct_slot)
				get_viewport().set_input_as_handled()
				return
			if _is_starting_weapon_key(key_event):
				select_starting_weapon()
				get_viewport().set_input_as_handled()
				return


func _physics_process(delta: float) -> void:
	if not _movement_enabled:
		velocity = Vector2.ZERO
		return
	_roll_cooldown_remaining = maxf(_roll_cooldown_remaining - delta, 0.0)
	if _roll_remaining > 0.0:
		_roll_remaining = maxf(_roll_remaining - delta, 0.0)
		velocity = _roll_direction * maxf(roll_speed, 1.0)
		move_and_slide()
		var roll_bounds := get_active_lateral_bounds()
		global_position.x = clampf(global_position.x, roll_bounds.x, roll_bounds.y)
		distance_traveled += maxf(-velocity.y, 0.0) * delta
		_attract_collectibles(delta)
		if _roll_remaining <= 0.0:
			roll_state_changed.emit(false, get_roll_cooldown_remaining())
		return

	var lateral_input := Input.get_axis("move_left", "move_right")
	velocity.x = lateral_input * get_effective_lateral_speed()

	var target_forward_speed := _get_target_forward_speed()
	current_forward_speed = move_toward(
		current_forward_speed,
		target_forward_speed,
		_get_effective_forward_acceleration() * delta
	)
	current_forward_speed = maxf(current_forward_speed, 1.0)
	_publish_lifespan_decay_multiplier()
	velocity.y = -current_forward_speed

	move_and_slide()
	var lateral_bounds := get_active_lateral_bounds()
	global_position.x = clampf(
		global_position.x,
		lateral_bounds.x,
		lateral_bounds.y
	)
	distance_traveled += current_forward_speed * delta
	_update_weapon_attack(delta)
	_attract_collectibles(delta)


func _draw() -> void:
	draw_set_transform(combat_anchor.position)
	var attack_range := get_current_attack_range()
	var range_color := _get_current_range_color()
	var attack_kind := _get_current_weapon_data().attack_kind
	if (
		attack_kind == WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM
	):
		_draw_palm_coverage(attack_range)
	elif (
		attack_kind != WeaponDataResource.AttackKind.GOLDEN_BELL
		and attack_kind != WeaponDataResource.AttackKind.DAO
		and attack_kind != WeaponDataResource.AttackKind.FLYING_SWORD
	):
		if attack_kind == WeaponDataResource.AttackKind.FANTIAN_SEAL:
			if _fantian_seal_switch_shadow_active:
				_draw_fantian_seal_switch_shadow(attack_range)
			elif (
				_fantian_seal_visual_state
				== FantianSealVisualState.ABSENT
			):
				var attack_square := Rect2(
					Vector2.ONE * -attack_range,
					Vector2.ONE * attack_range * 2.0
				)
				draw_rect(
					attack_square,
					FANTIAN_SEAL_RANGE_FILL_COLOR,
					true
				)
				draw_rect(
					attack_square,
					FANTIAN_SEAL_RANGE_EDGE_COLOR,
					false,
					2.0
				)
		else:
			draw_circle(Vector2.ZERO, attack_range, Color(range_color, 0.035))
			draw_arc(
				Vector2.ZERO,
				attack_range,
				0.0,
				TAU,
				80,
				Color(range_color, 0.52),
				2.0,
				true
			)
	if realm_abilities.is_qi_shield_active():
		_draw_qi_shield()

	_draw_dao_trails()
	_draw_flying_sword_reload()
	_draw_weapon_companions()
	if _damage_flash_remaining > 0.0:
		_draw_damage_feedback()
	if _level_up_effect_remaining > 0.0:
		_draw_level_up_effect()
	if _breakthrough_effect_remaining > 0.0:
		_draw_breakthrough_effect()


func _draw_palm_coverage(attack_range: float) -> void:
	if not _palm_debug_geometry_visible:
		return
	_draw_palm_geometry(
		attack_range,
		_palm_attack_direction,
		Color(0.3, 0.95, 1.0, 0.13),
		Color(0.58, 1.0, 1.0, 0.32),
		2.5
	)
	if _attack_flash_remaining > 0.0:
		var flash_progress := 1.0 - clampf(
			_attack_flash_remaining / PALM_COVERAGE_FLASH_DURATION,
			0.0,
			1.0
		)
		var pulse_range := attack_range * ease(flash_progress, -1.5)
		_draw_palm_geometry(
			pulse_range,
			_palm_cast_direction,
			Color(0.42, 0.98, 1.0, (1.0 - flash_progress) * 0.16),
			Color(0.72, 1.0, 1.0, 1.0 - flash_progress),
			lerpf(7.0, 2.0, flash_progress)
		)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-42.0, -attack_range - 8.0),
		"Palm %.0f px" % attack_range,
		HORIZONTAL_ALIGNMENT_CENTER,
		84.0,
		14,
		Color(0.72, 1.0, 1.0, 0.96)
	)


func _draw_palm_geometry(
	attack_range: float,
	direction: Vector2,
	fill_color: Color,
	edge_color: Color,
	edge_width: float
) -> void:
	if attack_range <= 0.0:
		return
	if _is_palm_full_circle():
		draw_circle(Vector2.ZERO, attack_range, fill_color)
		draw_arc(
			Vector2.ZERO,
			attack_range,
			0.0,
			TAU,
			80,
			edge_color,
			edge_width,
			true
		)
		return
	var direction_count := _get_palm_direction_count()
	for direction_index in direction_count:
		var sector_direction := direction.rotated(
			TAU * float(direction_index) / float(direction_count)
		)
		_draw_palm_sector(
			attack_range,
			sector_direction,
			fill_color,
			edge_color,
			edge_width
		)


func _draw_palm_sector(
	attack_range: float,
	direction: Vector2,
	fill_color: Color,
	edge_color: Color,
	edge_width: float
) -> void:
	var half_arc := deg_to_rad(
		_get_current_weapon_data().directional_arc_degrees * 0.5
	)
	var center_angle := direction.angle()
	var points := PackedVector2Array([Vector2.ZERO])
	var segment_count := 28
	for segment_index in segment_count + 1:
		var segment_ratio := (
			float(segment_index) / float(segment_count)
		)
		points.append(
			Vector2.from_angle(
				lerpf(
					center_angle - half_arc,
					center_angle + half_arc,
					segment_ratio
				)
			) * attack_range
		)
	draw_colored_polygon(points, fill_color)
	draw_arc(
		Vector2.ZERO,
		attack_range,
		center_angle - half_arc,
		center_angle + half_arc,
		segment_count,
		edge_color,
		edge_width,
		true
	)
	draw_line(
		Vector2.ZERO,
		Vector2.from_angle(center_angle - half_arc) * attack_range,
		edge_color,
		edge_width,
		true
	)
	draw_line(
		Vector2.ZERO,
		Vector2.from_angle(center_angle + half_arc) * attack_range,
		edge_color,
		edge_width,
		true
	)


func _draw_fantian_seal_switch_shadow(attack_range: float) -> void:
	var progress := clampf(
		_fantian_seal_switch_shadow_elapsed
			/ FANTIAN_SEAL_SWITCH_SHADOW_DURATION,
		0.0,
		1.0
	)
	var viewport_size := _get_visible_world_size()
	var fullscreen_half_extent := (
		maxf(viewport_size.x, viewport_size.y) * 0.75
	)
	var eased_shrink := progress * progress * (3.0 - 2.0 * progress)
	var half_extent := lerpf(
		fullscreen_half_extent,
		attack_range,
		eased_shrink
	)
	var shadow_alpha := lerpf(0.07, 0.20, eased_shrink)
	draw_rect(
		Rect2(
			Vector2.ONE * -half_extent,
			Vector2.ONE * half_extent * 2.0
		),
		Color(0.055, 0.09, 0.055, shadow_alpha),
		true
	)


func _draw_qi_shield() -> void:
	var center := Vector2.ZERO
	var shield_capacity := get_qi_shield_capacity()
	var current_qi := (
		_cultivation_resources.current_qi
		if _cultivation_resources != null
		else 0
	)
	var required_qi := (
		_cultivation_resources.get_current_qi_requirement()
		if _cultivation_resources != null
		else 1
	)
	var qi_ratio := clampf(
		float(current_qi) / float(maxi(required_qi, 1)),
		0.0,
		1.0
	)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	var shield_radius := 56.0 + pulse * 3.0
	var has_capacity := shield_capacity > 0.0
	var base_color := (
		Color("62e8ff") if has_capacity else Color("7b8795")
	)
	draw_circle(
		center,
		shield_radius,
		Color(base_color, 0.035 + qi_ratio * 0.095)
	)
	for segment_index in 8:
		var segment_start := (
			-PI * 0.5 + float(segment_index) * TAU / 8.0 + 0.05
		)
		var segment_end := (
			-PI * 0.5 + float(segment_index + 1) * TAU / 8.0 - 0.05
		)
		var segment_filled := (
			float(segment_index + 1) / 8.0 <= qi_ratio + 0.001
		)
		draw_arc(
			center,
			shield_radius,
			segment_start,
			segment_end,
			10,
			Color(
				base_color,
				0.82 if segment_filled and has_capacity else 0.18
			),
			4.0 if segment_filled and has_capacity else 2.0,
			true
		)
	draw_arc(
		center,
		shield_radius - 7.0,
		0.0,
		TAU,
		56,
		Color(base_color, 0.2 if has_capacity else 0.08),
		2.0,
		true
	)

	var label_text := (
		LanguageManager.text("shield_capacity_short_format") % shield_capacity
		if has_capacity
		else LanguageManager.text("shield_empty_short")
	)
	var label_width := 82.0
	var label_position := center + Vector2(-label_width * 0.5, -78.0)
	draw_rect(
		Rect2(label_position, Vector2(label_width, 21.0)),
		Color(0.015, 0.04, 0.075, 0.82),
		true
	)
	draw_string(
		ThemeDB.fallback_font,
		label_position + Vector2(0.0, 16.0),
		label_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		label_width,
		14,
		Color(base_color, 1.0 if has_capacity else 0.72)
	)

	if _shield_flash_remaining <= 0.0:
		return
	var flash_ratio := clampf(_shield_flash_remaining / 0.28, 0.0, 1.0)
	draw_arc(
		center,
		shield_radius + (1.0 - flash_ratio) * 22.0,
		0.0,
		TAU,
		64,
		Color(0.72, 0.98, 1.0, flash_ratio),
		3.0 + flash_ratio * 4.0,
		true
	)
	var feedback_text := LanguageManager.text("shield_blocked_format") % [
		_last_shield_blocked_damage,
		_last_shield_qi_spent,
	]
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-72.0, -91.0 - (1.0 - flash_ratio) * 12.0),
		feedback_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		144.0,
		14,
		Color(0.72, 0.98, 1.0, flash_ratio)
	)


## Enables or stops player locomotion and combat without resetting run state.
func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
	if not _movement_enabled:
		velocity = Vector2.ZERO
		_cancel_flying_sword_sequence()
		_cancel_palm_cast()
		_cancel_qiankun_ring_sequence()
		_cancel_special_projectile_sequence()


## Returns the stable world-space center shared by the airborne body hitbox,
## weapon geometry, projectiles, and reward interactions. The road-travel root
## and shadow remain at ground level while this anchor rises after 筑基.
func get_combat_anchor_position() -> Vector2:
	if is_instance_valid(combat_anchor):
		return combat_anchor.global_position
	return global_position


## Returns the visible body's world-space center for reward interactions.
func get_reward_interaction_position() -> Vector2:
	return get_combat_anchor_position()


## Receives direct damage and reports its cultivation-adjusted amount to the
## run resource owner. Known nearby sources receive 精 close-range mitigation;
## source-less hazards preserve their authored damage.
func take_melee_damage(amount: float, source: Node2D = null) -> void:
	_receive_direct_damage(amount, source, false)


func _receive_direct_damage(
	amount: float,
	source: Node2D,
	projectile_feedback: bool
) -> void:
	if not _movement_enabled or amount <= 0.0 or is_rolling():
		return
	if (
		source is EnemyController
		and not realm_abilities.can_receive_damage_from_realm(
			(source as EnemyController).combat_realm_index
		)
	):
		return
	if golden_bell != null and golden_bell.is_damage_protection_active():
		return
	var resolved_amount := amount
	if (
		is_instance_valid(source)
		and get_combat_anchor_position().distance_to(source.global_position)
			<= _global_combat_stats.close_range_mitigation_radius
	):
		resolved_amount *= (
			1.0 - _global_combat_stats.close_range_damage_reduction
		)
	var realm_result := realm_abilities.resolve_incoming_damage(
		resolved_amount
	)
	resolved_amount = float(realm_result["remaining_damage"])
	if resolved_amount <= 0.0:
		return
	_last_damage_amount = resolved_amount
	_damage_feedback_is_projectile = projectile_feedback
	_damage_flash_remaining = maxf(damage_feedback_duration, 0.01)
	damage_taken_label.text = LanguageManager.text(
		"lifespan_damage_format"
	) % resolved_amount
	damage_taken_label.show()
	_update_damage_feedback_presentation()
	queue_redraw()
	melee_damage_received.emit(resolved_amount)


func take_enemy_damage(amount: float, source: Node2D = null) -> void:
	take_melee_damage(amount, source)


## Receives a hostile flying-sword hit with a compact crossing slash instead of
## the expanding circular burst reserved for contact and hazard damage.
func take_enemy_projectile_damage(
	amount: float,
	source: Node2D = null
) -> void:
	_receive_direct_damage(amount, source, true)


## Returns whether the player-centered direct-damage reaction is active.
func is_damage_feedback_active() -> bool:
	return _damage_flash_remaining > 0.0


## Adds a new weapon type or upgrades an existing type's delivery count without
## changing the currently equipped weapon. Duplicate pickups always add one
## copy; their damage roll only replaces the stored roll when it is stronger.
func collect_weapon(
	weapon_data: WeaponDataResource,
	damage: int
) -> bool:
	if (
		weapon_data == null
		or not weapon_data.is_valid_definition()
		or damage <= 0
	):
		return false

	var existing_index := _find_equipment_index(weapon_data.weapon_id)
	var equipment := _create_equipment(weapon_data, damage)

	if existing_index >= 0:
		var existing_damage := int(_equipment_inventory[existing_index]["damage"])
		var existing_quantity := int(
			_equipment_inventory[existing_index].get("quantity", 1)
		)
		equipment["damage"] = maxi(existing_damage, damage)
		equipment["quantity"] = existing_quantity + 1
		_equipment_inventory[existing_index] = equipment
	else:
		_equipment_inventory.append(equipment)
	if existing_index == _current_equipment_index:
		_on_current_equipment_changed()
	else:
		_publish_equipment()
	return true


## Adds flat base damage to every existing and future weapon in this run.
## Weapon definitions remain immutable; the bonus is player-owned run state.
func upgrade_all_weapons(amount: int = 1) -> void:
	apply_universal_upgrade(
		UniversalUpgradeTypes.UpgradeType.DAMAGE,
		amount
	)


## Applies one of the five run-wide fragment upgrades without mutating shared
## weapon resources.
func apply_universal_upgrade(upgrade_type: int, amount: int = 1) -> void:
	if (
		amount <= 0
		or upgrade_type < 0
		or upgrade_type >= UniversalUpgradeTypes.COUNT
	):
		return
	_universal_upgrade_levels[upgrade_type] += amount
	if upgrade_type == UniversalUpgradeTypes.UpgradeType.DAMAGE:
		_weapon_power_level += amount * maxi(damage_bonus_per_fragment, 0)
	if is_node_ready() and not _equipment_inventory.is_empty():
		_rebuild_combat_stats()
		_apply_attack_range()
		_publish_equipment()
		_level_up_effect_remaining = maxf(level_up_effect_duration, 0.01)
		queue_redraw()
	if upgrade_type == UniversalUpgradeTypes.UpgradeType.DAMAGE:
		weapon_power_upgraded.emit(
			_weapon_power_level,
			_weapon_power_level
		)
	universal_upgrade_applied.emit(
		upgrade_type,
		_universal_upgrade_levels[upgrade_type]
	)


## Debug-panel mutation boundary for adding or removing run-local fragments.
func debug_adjust_universal_upgrade(upgrade_type: int, delta: int) -> void:
	if upgrade_type < 0 or upgrade_type >= UniversalUpgradeTypes.COUNT:
		return
	var previous := _universal_upgrade_levels[upgrade_type]
	var next := maxi(previous + delta, 0)
	var applied_delta := next - previous
	if applied_delta == 0:
		return
	_universal_upgrade_levels[upgrade_type] = next
	if upgrade_type == UniversalUpgradeTypes.UpgradeType.DAMAGE:
		_weapon_power_level = maxi(
			_weapon_power_level
				+ applied_delta * maxi(damage_bonus_per_fragment, 0),
			0
		)
	_rebuild_combat_stats()
	_apply_attack_range()
	_publish_equipment()
	universal_upgrade_applied.emit(upgrade_type, next)


## Debug-panel mutation boundary for weapon quantity without touching resources.
func debug_adjust_weapon(
	weapon_data: WeaponDataResource,
	delta: int
) -> void:
	if weapon_data == null or delta == 0:
		return
	if delta > 0:
		for _copy in delta:
			collect_weapon(weapon_data, weapon_data.minimum_damage)
		return
	var index := _find_equipment_index(weapon_data.weapon_id)
	if index < 0:
		return
	var equipment := _equipment_inventory[index]
	var quantity := int(equipment.get("quantity", 1))
	if quantity + delta > 0:
		equipment["quantity"] = quantity + delta
		_equipment_inventory[index] = equipment
		_on_current_equipment_changed()
	elif weapon_data.weapon_id != starting_weapon_data.weapon_id:
		_equipment_inventory.remove_at(index)
		_current_equipment_index = clampi(
			_current_equipment_index,
			0,
			_equipment_inventory.size() - 1
		)
	_on_current_equipment_changed()


func debug_adjust_current_weapon_damage(delta: int) -> void:
	if _equipment_inventory.is_empty() or delta == 0:
		return
	var equipment := _get_current_equipment()
	equipment["damage"] = maxi(int(equipment["damage"]) + delta, 1)
	_equipment_inventory[_current_equipment_index] = equipment
	_rebuild_combat_stats()
	_publish_equipment()


func get_weapon_power_level() -> int:
	return _weapon_power_level


func get_universal_upgrade_level(upgrade_type: int) -> int:
	if upgrade_type < 0 or upgrade_type >= _universal_upgrade_levels.size():
		return 0
	return _universal_upgrade_levels[upgrade_type]


func get_universal_upgrade_snapshot() -> Dictionary:
	var snapshot := {}
	for upgrade_type in UniversalUpgradeTypes.COUNT:
		snapshot[UniversalUpgradeTypes.get_display_name(upgrade_type)] = (
			_universal_upgrade_levels[upgrade_type]
		)
	return snapshot


func get_effective_lateral_speed() -> float:
	return (
		lateral_speed
		+ float(
			_universal_upgrade_levels[
				UniversalUpgradeTypes.UpgradeType.MOVEMENT
			]
		) * lateral_speed_per_fragment
	)


func get_effective_forward_acceleration() -> float:
	return _get_effective_forward_acceleration()


func get_boosted_speed_target() -> float:
	return maxf(
		boosted_forward_speed
			+ float(
				_universal_upgrade_levels[
					UniversalUpgradeTypes.UpgradeType.SPEED_CONTROL
				]
			) * boost_speed_per_control_fragment,
		1.0
	)


func get_slowed_speed_target() -> float:
	return maxf(
		slowed_forward_speed
			- float(
				_universal_upgrade_levels[
					UniversalUpgradeTypes.UpgradeType.SPEED_CONTROL
				]
			) * slow_speed_reduction_per_fragment,
		maxf(minimum_controlled_speed, 1.0)
	)


## Cycles the equipped entry in collection order. Bound to Tab by default.
func cycle_equipment() -> void:
	if _equipment_inventory.size() <= 1:
		return
	for offset in range(1, _equipment_inventory.size() + 1):
		var candidate_index := (
			_current_equipment_index + offset
		) % _equipment_inventory.size()
		var candidate_data := (
			_equipment_inventory[candidate_index]["data"]
			as WeaponDataResource
		)
		if not realm_abilities.is_weapon_allowed(candidate_data):
			continue
		_current_equipment_index = candidate_index
		_on_current_equipment_changed()
		return


## Equips one of the six collectible weapon slots in acquisition order.
## Slot zero maps to keyboard 1; unavailable or empty slots are ignored.
func select_weapon_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= 6:
		return false
	var collectible_index := 0
	for inventory_index in _equipment_inventory.size():
		var candidate_data := (
			_equipment_inventory[inventory_index]["data"]
			as WeaponDataResource
		)
		if candidate_data.weapon_id == starting_weapon_data.weapon_id:
			continue
		if collectible_index != slot_index:
			collectible_index += 1
			continue
		if not realm_abilities.is_weapon_allowed(candidate_data):
			return false
		if _current_equipment_index != inventory_index:
			_current_equipment_index = inventory_index
			_on_current_equipment_changed()
		return true
	return false


## Equips the initial Great Strength Palm entry. Bound to the backtick key.
func select_starting_weapon() -> bool:
	var starting_index := _find_equipment_index(starting_weapon_data.weapon_id)
	if starting_index < 0:
		return false
	if _current_equipment_index != starting_index:
		_current_equipment_index = starting_index
		_on_current_equipment_changed()
	return true


func get_technique_name() -> String:
	return (
		starting_weapon_data.display_name
		if starting_weapon_data != null
		else ""
	)


func get_weapon_name() -> String:
	return _get_current_weapon_data().display_name


func get_current_weapon_damage() -> int:
	return maxi(
		roundi(
			float(_current_weapon_combat_stats.resolved_damage)
				* realm_abilities.get_outgoing_damage_multiplier()
		),
		1
	)


func get_current_attack_range() -> float:
	return _current_weapon_combat_stats.attack_range


## Returns the latest player-wide read-only combat snapshot.
func get_global_combat_stats() -> PlayerGlobalCombatStatsResource:
	return _global_combat_stats


## Returns the latest read-only snapshot for the equipped weapon.
func get_current_weapon_combat_stats() -> WeaponCombatStatsResource:
	return _current_weapon_combat_stats


## Connects final weapon-stat calculation to the existing run-state owner.
## Progression remains in RunResources; this class only consumes snapshots.
func bind_cultivation(resources: RunResources) -> void:
	if (
		_cultivation_resources != null
		and _cultivation_resources.cultivation_stats_changed.is_connected(
			_on_cultivation_stats_changed
		)
	):
		_cultivation_resources.cultivation_stats_changed.disconnect(
			_on_cultivation_stats_changed
		)
	_cultivation_resources = resources
	realm_abilities.bind_resources(resources)
	if _cultivation_resources != null:
		_cultivation_resources.cultivation_stats_changed.connect(
			_on_cultivation_stats_changed
		)
	_on_cultivation_stats_changed(
		CultivationTypesResource.CultivationType.JING,
		0
	)


func get_current_attack_interval() -> float:
	return _current_weapon_combat_stats.attack_interval


func get_current_projectile_speed_multiplier() -> float:
	return _current_weapon_combat_stats.projectile_speed_multiplier


## Returns the equipped weapon count accumulated from same-type pickups.
func get_current_delivery_count() -> int:
	return _current_weapon_combat_stats.delivery_count


func get_current_aoe_radius() -> float:
	return _current_weapon_combat_stats.aoe_radius


## Returns the immutable shared definition for the currently equipped weapon.
func get_current_weapon_data() -> WeaponDataResource:
	return _get_current_weapon_data()


## Dao levels occupy persistent concentric combat orbits up to the weapon's
## configured range-level cap. Later duplicate levels strengthen damage
## without creating overlapping blades beyond the outermost path.
func get_dao_orbit_count() -> int:
	if not _is_dao_equipped():
		return 0
	return mini(
		get_current_delivery_count(),
		maxi(_get_current_weapon_data().attack_range_level_cap, 1)
	)


## Returns the displayed Dao distance from sprite center to blade tip in pixels.
func get_dao_weapon_tip_length() -> float:
	return DAO_WEAPON_TIP_OFFSET_PIXELS * DAO_WEAPON_SCALE


## Returns the blade-center radius for one Dao path. Authored concentric
## boundaries are scaled to the final resolved attack range so universal range
## fragments, cultivation bonuses, collision, and the outer blade tip agree.
func get_dao_orbit_radius(orbit_index: int) -> float:
	var weapon_data := _get_current_weapon_data()
	var orbit_count := maxi(get_dao_orbit_count(), 1)
	var capped_level := mini(
		maxi(orbit_index + 1, 1),
		orbit_count
	)
	var authored_ring_boundary := (
		maxf(weapon_data.attack_range, 0.0)
		+ float(capped_level - 1)
			* maxf(weapon_data.attack_range_increase_per_level, 0.0)
	)
	var authored_outer_boundary := (
		maxf(weapon_data.attack_range, 0.0)
		+ float(orbit_count - 1)
			* maxf(weapon_data.attack_range_increase_per_level, 0.0)
	)
	return maxf(
		authored_ring_boundary
			* (
				maxf(get_current_attack_range(), 0.0)
				/ maxf(authored_outer_boundary, 1.0)
			)
			- get_dao_weapon_tip_length(),
		28.0
	)


## Returns the number of projectiles launched by one flying-sword volley.
func get_flying_sword_projectile_count() -> int:
	return get_current_delivery_count()


## Returns two base bounces plus one per universal damage fragment.
func get_qiankun_ring_bounce_count() -> int:
	return maxi(
		_get_current_weapon_data().base_bounce_count
			+ _universal_upgrade_levels[
				UniversalUpgradeTypes.UpgradeType.DAMAGE
			],
		0
	)


## Returns Universe Rings launched sequentially by one automatic attack.
func get_qiankun_ring_projectile_count() -> int:
	return get_current_delivery_count()


func is_qiankun_ring_in_flight() -> bool:
	return _active_qiankun_rings > 0 or _pending_qiankun_rings > 0


## Returns Universe Rings waiting in the current sequential launch.
func get_pending_qiankun_ring_count() -> int:
	return _pending_qiankun_rings


## Returns Universe Rings currently moving through the world.
func get_active_qiankun_ring_count() -> int:
	return _active_qiankun_rings


## Returns swords still waiting to launch in the current sequential volley.
func get_pending_flying_sword_count() -> int:
	return _pending_flying_swords


## Reports whether spent Flying Swords are waiting for their shared magazine
## reload. Attack-speed bonuses shorten this reload, not the firing interval.
func is_flying_sword_reloading() -> bool:
	return _flying_sword_reload_active


## Returns seconds remaining before a targetless partial volley cancels into
## reload. Reacquiring any valid target clears this grace immediately.
func get_flying_sword_target_loss_grace_remaining() -> float:
	return _flying_sword_target_loss_grace_remaining


## Returns normalized Flying Sword reload completion. A fully ready magazine
## reports 1.0, including while Flying Sword is not currently equipped.
func get_flying_sword_reload_progress() -> float:
	if (
		not _flying_sword_reload_active
		or _flying_sword_reload_duration <= 0.0
	):
		return 1.0
	return 1.0 - clampf(
		_attack_cooldown_remaining / _flying_sword_reload_duration,
		0.0,
		1.0
	)


## Returns the number of idle weapons visibly accompanying the player.
## Equipped weapons always use one companion regardless of upgrade level.
func get_visible_companion_weapon_count() -> int:
	var attack_kind := _get_current_weapon_data().attack_kind
	if (
		attack_kind == WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM
		or attack_kind == WeaponDataResource.AttackKind.GOLDEN_BELL
		or attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING
			and is_qiankun_ring_in_flight()
	):
		return 0
	return 1


func is_level_up_effect_active() -> bool:
	return _level_up_effect_remaining > 0.0


## Starts the restrained yellow RPG-style pillar reserved for a successful
## realm breakthrough.
func play_breakthrough_effect() -> void:
	_breakthrough_effect_remaining = maxf(
		breakthrough_effect_duration,
		0.01
	)
	queue_redraw()


func is_breakthrough_effect_active() -> bool:
	return _breakthrough_effect_remaining > 0.0


func get_attraction_range() -> float:
	return current_attraction_range


## Returns lifespan-decay scaling from actual forward speed relative to normal
## speed. Boosting raises it, while slowing never reduces baseline decay.
func get_lifespan_decay_multiplier() -> float:
	return 1.0
	#return maxf(
		#current_forward_speed / maxf(base_forward_speed, 1.0),
		#1.0
	#)


func get_equipment_inventory_entries() -> Array[String]:
	var entries: Array[String] = []
	for index in _equipment_inventory.size():
		var equipment := _equipment_inventory[index]
		var weapon_data := equipment["data"] as WeaponDataResource
		var marker := "▶ " if index == _current_equipment_index else "  "
		var lock_suffix := (
			LanguageManager.text("equipment_locked_suffix")
			if not realm_abilities.is_weapon_allowed(weapon_data)
			else ""
		)
		entries.append(
			LanguageManager.text("equipment_entry_format") % [
				marker,
				LanguageManager.get_weapon_name(
					weapon_data.weapon_id,
					weapon_data.display_name
				),
				int(equipment.get("quantity", 1)),
				_get_equipment_damage(equipment),
				lock_suffix,
			]
		)
	return entries


func _on_language_changed(_locale: String) -> void:
	if damage_taken_label.visible:
		damage_taken_label.text = LanguageManager.text(
			"lifespan_damage_format"
		) % _last_damage_amount
	queue_redraw()


## Returns read-only inventory snapshots for the HUD. Dictionaries preserve
## acquisition order and never expose the mutable player-owned entries.
func get_equipment_inventory_snapshot() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for index in _equipment_inventory.size():
		var equipment := _equipment_inventory[index]
		var weapon_data := equipment["data"] as WeaponDataResource
		snapshots.append({
			"data": weapon_data,
			"inventory_index": index,
			"quantity": int(equipment.get("quantity", 1)),
			"damage": _get_equipment_damage(equipment),
			"available": realm_abilities.is_weapon_allowed(weapon_data),
		})
	return snapshots


## Returns the player-owned inventory index currently used for attacks.
func get_current_equipment_index() -> int:
	return _current_equipment_index


## Temporarily replaces the main-road horizontal clamp while the player is
## alongside an exterior branch road.
func set_temporary_lateral_bounds(minimum_x: float, maximum_x: float) -> void:
	_temporary_lateral_min_x = minf(minimum_x, maximum_x)
	_temporary_lateral_max_x = maxf(minimum_x, maximum_x)
	_temporary_lateral_bounds_enabled = true


## Removes temporary connector bounds and restores the active-route clamp.
func clear_temporary_lateral_bounds() -> void:
	_temporary_lateral_bounds_enabled = false


## Moves the normal infinite-road clamp to a newly committed branch center.
func set_road_center_x(value: float) -> void:
	road_center_x = value
	_temporary_lateral_bounds_enabled = false


func get_active_lateral_bounds() -> Vector2:
	if _temporary_lateral_bounds_enabled:
		return Vector2(
			_temporary_lateral_min_x,
			_temporary_lateral_max_x
		)
	return Vector2(
		road_center_x - road_half_width + horizontal_clearance,
		road_center_x + road_half_width - horizontal_clearance
	)


## Starts the grounded Qi Refining dodge using current directional input.
func start_qi_refining_roll() -> bool:
	if (
		not _movement_enabled
		or _get_current_realm_index() != 0
		or _roll_remaining > 0.0
		or _roll_cooldown_remaining > 0.0
	):
		return false
	var lateral_input := Input.get_axis("move_left", "move_right")
	_roll_direction = Vector2(lateral_input, -1.0).normalized()
	if _roll_direction.is_zero_approx():
		_roll_direction = Vector2.UP
	_roll_remaining = maxf(roll_duration, 0.01)
	_roll_cooldown_remaining = (
		_roll_remaining + maxf(roll_cooldown, 0.0)
	)
	if (
		is_instance_valid(character_sprite)
		and character_sprite.sprite_frames.has_animation(roll_animation)
	):
		character_sprite.play(roll_animation)
		character_sprite.speed_scale = 1.0
	_cancel_flying_sword_sequence()
	_cancel_palm_cast()
	_cancel_qiankun_ring_sequence()
	_cancel_special_projectile_sequence()
	roll_state_changed.emit(true, get_roll_cooldown_remaining())
	return true


func is_rolling() -> bool:
	return _roll_remaining > 0.0


## Returns only post-roll recovery time; active roll duration is excluded.
func get_roll_cooldown_remaining() -> float:
	return maxf(_roll_cooldown_remaining - _roll_remaining, 0.0)


## Returns one presentation-neutral snapshot for the realm's Space-key ability.
## The HUD may poll this lightweight view without owning cooldown state.
func get_active_ability_snapshot() -> Dictionary:
	var realm_snapshot := realm_abilities.get_debug_snapshot()
	var realm_id := StringName(realm_snapshot.get("realm_id", &""))
	match realm_id:
		&"qi_refining":
			var roll_recovery := get_roll_cooldown_remaining()
			var roll_duration_safe := maxf(roll_cooldown, 0.01)
			return {
				"ability_id": &"roll",
				"active": is_rolling(),
				"ready": not is_rolling() and roll_recovery <= 0.0,
				"cooldown_remaining": roll_recovery,
				"cooldown_duration": roll_duration_safe,
				"progress": clampf(
					1.0 - roll_recovery / roll_duration_safe,
					0.0,
					1.0
				),
			}
		&"foundation":
			var flight_active := bool(
				realm_snapshot.get("temporary_flight_active", false)
			)
			return {
				"ability_id": &"temporary_flight",
				"active": flight_active,
				"ready": not flight_active,
				"cooldown_remaining": 0.0,
				"cooldown_duration": 0.0,
				"progress": float(
					realm_snapshot.get("temporary_flight_progress", 1.0)
				),
				"phase": StringName(
					realm_snapshot.get(
						"temporary_flight_phase",
						&"grounded"
					)
				),
			}
		&"golden_core":
			var shield_active := realm_abilities.is_qi_shield_active()
			return {
				"ability_id": &"qi_shield",
				"active": shield_active,
				"ready": true,
				"cooldown_remaining": 0.0,
				"cooldown_duration": 0.0,
				"progress": 1.0,
			}
		&"nascent_soul":
			var projection_active := (
				realm_abilities.is_spirit_projection_active()
			)
			return {
				"ability_id": &"spirit_projection",
				"active": projection_active,
				"ready": true,
				"cooldown_remaining": 0.0,
				"cooldown_duration": 0.0,
				"progress": 1.0,
			}
	return {
		"ability_id": &"none",
		"active": false,
		"ready": false,
		"cooldown_remaining": 0.0,
		"cooldown_duration": 0.0,
		"progress": 0.0,
	}


## Returns the current amount of lifespan damage the Qi shield can absorb.
func get_qi_shield_capacity() -> float:
	if (
		not realm_abilities.is_qi_shield_active()
		or _cultivation_resources == null
	):
		return 0.0
	return (
		float(_cultivation_resources.current_qi)
		* realm_abilities.get_qi_shield_damage_per_qi()
	)


func is_qi_shield_feedback_active() -> bool:
	return _shield_flash_remaining > 0.0


## Overall Qi cultivation continues to expand collectible attraction. The
## independent 精/气/神 tracks are consumed through bind_cultivation().
func apply_cultivation_level(level: int) -> void:
	var previous_level := current_cultivation_level
	current_cultivation_level = maxi(level, 1)
	current_attraction_range = (
		base_attraction_range
		+ float(current_cultivation_level - 1)
			* attraction_range_increase_per_level
	)
	_apply_attraction_range()
	if is_node_ready() and not _equipment_inventory.is_empty():
		_rebuild_combat_stats()
		_apply_attack_range()
		_publish_equipment()
	if current_cultivation_level > previous_level:
		_level_up_effect_remaining = maxf(level_up_effect_duration, 0.01)
	queue_redraw()


func _update_weapon_attack(delta: float) -> void:
	_attack_cooldown_remaining = maxf(
		_attack_cooldown_remaining - delta,
		0.0
	)
	if _flying_sword_reload_active:
		queue_redraw()
		if _attack_cooldown_remaining > 0.0:
			return
		_complete_flying_sword_reload()
	if _pending_flying_swords > 0:
		if _flying_sword_target_loss_grace_remaining > 0.0:
			if not _get_attack_targets().is_empty():
				_flying_sword_target_loss_grace_remaining = 0.0
				_launch_next_flying_sword()
			else:
				_flying_sword_target_loss_grace_remaining = maxf(
					_flying_sword_target_loss_grace_remaining - delta,
					0.0
				)
				if _flying_sword_target_loss_grace_remaining <= 0.0:
					_cancel_flying_sword_sequence()
			return
		_flying_sword_sequence_timer -= delta
		if _flying_sword_sequence_timer <= 0.0:
			_launch_next_flying_sword()
		return
	if _pending_qiankun_rings > 0:
		_qiankun_ring_sequence_timer -= delta
		if _qiankun_ring_sequence_timer <= 0.0:
			_launch_next_qiankun_ring()
		return
	if _pending_special_projectiles > 0:
		_special_sequence_timer -= delta
		if _special_sequence_timer <= 0.0:
			_launch_next_special_projectile()
		return
	if _attack_cooldown_remaining > 0.0:
		return

	var weapon_data := _get_current_weapon_data()
	if (
		weapon_data.attack_kind
			== WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM
		and (
			_palm_visual_state == PalmVisualState.STRIKING
			or _palm_visual_state == PalmVisualState.DISSOLVING
		)
	):
		return
	if weapon_data.attack_kind == WeaponDataResource.AttackKind.GOLDEN_BELL:
		return
	var targets := _get_attack_targets()
	if targets.is_empty():
		return
	var attack_kind := weapon_data.attack_kind
	if (
		attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING
		and is_qiankun_ring_in_flight()
	):
		return
	var attack_damage := _roll_current_attack_damage()

	if attack_kind == WeaponDataResource.AttackKind.DAO:
		_play_weapon_activation_sfx(weapon_data)
		_dao_attack_visual_hold_remaining = maxf(
			_dao_attack_visual_hold_remaining,
			DAO_ATTACK_VISUAL_HOLD_DURATION
		)
		_dao_orbit_speed = DAO_ATTACK_ORBIT_SPEED
		for enemy in targets:
			enemy.take_melee_damage(
				attack_damage.damage,
				attack_damage.is_critical,
				weapon_data.weapon_id
			)
		_dao_attack_remaining = 0.28
	elif attack_kind == WeaponDataResource.AttackKind.FLYING_SWORD:
		_begin_flying_sword_sequence(attack_damage)
	elif attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING:
		_begin_qiankun_ring_sequence(attack_damage)
	elif (
		attack_kind == WeaponDataResource.AttackKind.THUNDER_HAMMER
		or attack_kind == WeaponDataResource.AttackKind.FANTIAN_SEAL
	):
		_begin_special_projectile_sequence(attack_kind, attack_damage)
	else:
		_begin_palm_cast(targets[0], attack_damage)

	if (
		attack_kind != WeaponDataResource.AttackKind.FLYING_SWORD
		and attack_kind != WeaponDataResource.AttackKind.THUNDER_HAMMER
		and attack_kind != WeaponDataResource.AttackKind.FANTIAN_SEAL
	):
		_attack_cooldown_remaining = get_current_attack_interval()
	queue_redraw()


func _begin_flying_sword_sequence(
	attack_damage: AttackDamageResultResource
) -> void:
	_refill_flying_sword_visual_slots()
	_flying_sword_sequence_total = get_flying_sword_projectile_count()
	_pending_flying_swords = _flying_sword_sequence_total
	_flying_sword_sequence_launched = 0
	_flying_sword_sequence_damage = maxi(attack_damage.damage, 1)
	_flying_sword_sequence_is_critical = attack_damage.is_critical
	_flying_sword_sequence_timer = 0.0
	_flying_sword_target_loss_grace_remaining = 0.0
	_launch_next_flying_sword()


func _launch_next_flying_sword() -> void:
	if _pending_flying_swords <= 0:
		return
	var targets := _get_attack_targets()
	if targets.is_empty():
		_flying_sword_target_loss_grace_remaining = maxf(
			flying_sword_target_loss_grace_duration,
			0.0
		)
		if _flying_sword_target_loss_grace_remaining <= 0.0:
			_cancel_flying_sword_sequence()
		return
	_flying_sword_target_loss_grace_remaining = 0.0
	var target := targets[
		_flying_sword_sequence_launched % targets.size()
	]
	_launch_flying_sword(
		target,
		_flying_sword_sequence_damage,
		_flying_sword_sequence_is_critical,
		_flying_sword_sequence_launched,
		_flying_sword_sequence_total
	)
	_flying_sword_sequence_launched += 1
	_pending_flying_swords -= 1
	if _pending_flying_swords <= 0:
		_start_flying_sword_reload()
		return
	var weapon_data := _get_current_weapon_data()
	_flying_sword_sequence_timer = maxf(
		weapon_data.projectile_sequence_interval,
		0.01
	)


func _cancel_flying_sword_sequence() -> void:
	var spent_any_sword := _flying_sword_sequence_launched > 0
	_pending_flying_swords = 0
	_flying_sword_sequence_total = 0
	_flying_sword_sequence_launched = 0
	_flying_sword_sequence_is_critical = false
	_flying_sword_sequence_timer = 0.0
	_flying_sword_target_loss_grace_remaining = 0.0
	if spent_any_sword and not _flying_sword_reload_active:
		_start_flying_sword_reload()


func _start_flying_sword_reload() -> void:
	_flying_sword_sequence_total = 0
	_flying_sword_sequence_launched = 0
	_flying_sword_sequence_is_critical = false
	_flying_sword_sequence_timer = 0.0
	_flying_sword_target_loss_grace_remaining = 0.0
	_flying_sword_reload_duration = maxf(
		get_current_attack_interval(),
		0.01
	)
	_attack_cooldown_remaining = _flying_sword_reload_duration
	_flying_sword_reload_active = true
	queue_redraw()


func _complete_flying_sword_reload() -> void:
	_flying_sword_reload_active = false
	_flying_sword_reload_duration = 0.0
	_attack_cooldown_remaining = 0.0
	_refill_flying_sword_visual_slots()
	_flying_sword_warning_pulse_elapsed = 0.0
	queue_redraw()


func _release_great_strength_palm(
	primary_target: EnemyController,
	attack_damage: AttackDamageResultResource
) -> void:
	_begin_palm_cast(primary_target, attack_damage)


func _begin_palm_cast(
	primary_target: EnemyController,
	attack_damage: AttackDamageResultResource
) -> void:
	if not is_instance_valid(primary_target):
		return
	_play_weapon_activation_sfx(_get_current_weapon_data())
	_palm_cast_direction = get_combat_anchor_position().direction_to(
		primary_target.global_position
	).normalized()
	if _palm_cast_direction.is_zero_approx():
		_palm_cast_direction = Vector2.UP
	_palm_attack_direction = _palm_cast_direction
	if _palm_visual_equipped:
		_begin_palm_visual_strike(primary_target, attack_damage)
	else:
		_apply_palm_damage(primary_target, attack_damage)


func _get_nearest_palm_target() -> EnemyController:
	var nearest_target: EnemyController
	var nearest_distance_squared := INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		if not enemy.is_combat_active():
			continue
		var target_radius := _get_enemy_target_radius(enemy)
		var distance_squared := get_combat_anchor_position().distance_squared_to(
			enemy.global_position
		)
		var maximum_distance := get_current_attack_range() + target_radius
		if (
			distance_squared <= maximum_distance * maximum_distance
			and distance_squared < nearest_distance_squared
		):
			nearest_target = enemy
			nearest_distance_squared = distance_squared
	return nearest_target


func _is_enemy_in_palm_coverage(
	enemy: EnemyController,
	direction: Vector2
) -> bool:
	return _is_offset_in_palm_coverage(
		enemy.global_position - get_combat_anchor_position(),
		direction,
		_get_enemy_target_radius(enemy)
	)


func _get_enemy_target_radius(enemy: EnemyController) -> float:
	var collision_shape := enemy.get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return 0.0
	var scale_multiplier := maxf(
		absf(collision_shape.global_scale.x),
		absf(collision_shape.global_scale.y)
	)
	if collision_shape.shape is CircleShape2D:
		return (
			(collision_shape.shape as CircleShape2D).radius
			* scale_multiplier
		)
	if collision_shape.shape is RectangleShape2D:
		return (
			(collision_shape.shape as RectangleShape2D).size.length()
			* 0.5
			* scale_multiplier
		)
	return 0.0


func _is_offset_in_palm_coverage(
	offset: Vector2,
	direction: Vector2,
	target_radius: float = 0.0
) -> bool:
	var safe_target_radius := maxf(target_radius, 0.0)
	var target_distance := offset.length()
	if target_distance > get_current_attack_range() + safe_target_radius:
		return false
	if _is_palm_full_circle():
		return true
	if target_distance <= safe_target_radius:
		return true
	var half_arc := deg_to_rad(
		_get_current_weapon_data().directional_arc_degrees * 0.5
	)
	half_arc += asin(
		clampf(
			safe_target_radius / maxf(target_distance, 0.001),
			0.0,
			1.0
		)
	)
	var minimum_dot := cos(minf(half_arc, PI))
	var offset_direction := offset.normalized()
	var safe_direction := direction.normalized()
	for direction_index in _get_palm_direction_count():
		var sector_direction := safe_direction.rotated(
			TAU
				* float(direction_index)
				/ float(_get_palm_direction_count())
		)
		if sector_direction.dot(offset_direction) >= minimum_dot:
			return true
	return false


func _apply_palm_damage(
	enemy: EnemyController,
	attack_damage: AttackDamageResultResource
) -> void:
	if not is_instance_valid(enemy) or not enemy.is_combat_active():
		return
	var realm_index := _get_current_realm_index()
	var weapon_data := _get_current_weapon_data()
	if realm_index >= 1 and weapon_data.palm_knockback_speed > 0.0:
		enemy.apply_knockback(
			get_combat_anchor_position().direction_to(enemy.global_position),
			weapon_data.palm_knockback_speed,
			weapon_data.palm_knockback_recovery
		)
	var health_ratio := (
		float(enemy.current_health) / float(maxi(enemy.max_health, 1))
	)
	if (
		realm_index >= 3
		and not enemy.is_elite_enemy()
		and health_ratio < weapon_data.palm_execute_health_threshold_ratio
		and randf() < weapon_data.palm_execute_chance
	):
		_spawn_palm_execute_vfx(enemy)
		enemy.take_melee_damage(
			maxi(enemy.current_health, 1),
			false,
			weapon_data.weapon_id
		)
		return
	var resolved_damage := attack_damage.damage
	if (
		realm_index >= 2
		and health_ratio > weapon_data.palm_high_health_threshold_ratio
	):
		resolved_damage = maxi(
			roundi(
				float(resolved_damage)
					* weapon_data.palm_high_health_damage_multiplier
			),
			1
		)
	enemy.take_melee_damage(
		resolved_damage,
		attack_damage.is_critical,
		weapon_data.weapon_id
	)


func _spawn_palm_execute_vfx(enemy: EnemyController) -> void:
	if palm_execute_vfx_scene == null or enemy.get_parent() == null:
		return
	var execute_vfx := palm_execute_vfx_scene.instantiate() as Node2D
	if execute_vfx == null:
		return
	enemy.get_parent().add_child(execute_vfx)
	execute_vfx.global_position = enemy.global_position
	if execute_vfx.has_method("play"):
		execute_vfx.call("play")


func _get_palm_direction_count() -> int:
	return 1


func _is_palm_full_circle() -> bool:
	return false


func _get_current_realm_index() -> int:
	return (
		_cultivation_resources.get_current_realm_index()
		if _cultivation_resources != null
		else 0
	)


func _cancel_palm_cast() -> void:
	_palm_visual_pending_damage = 0
	_palm_visual_pending_critical = false
	_palm_visual_target = null
	_palm_visual_targets.clear()
	_palm_visual_launched.clear()
	_palm_visual_skipped.clear()
	if is_instance_valid(palm_weapon):
		_show_palm_idle()


func _begin_qiankun_ring_sequence(
	attack_damage: AttackDamageResultResource
) -> void:
	_qiankun_ring_sequence_total = get_qiankun_ring_projectile_count()
	_pending_qiankun_rings = _qiankun_ring_sequence_total
	_qiankun_ring_sequence_launched = 0
	_qiankun_ring_sequence_damage = maxi(attack_damage.damage, 1)
	_qiankun_ring_sequence_is_critical = attack_damage.is_critical
	_qiankun_ring_sequence_timer = 0.0
	_launch_next_qiankun_ring()


func _launch_next_qiankun_ring() -> void:
	if _pending_qiankun_rings <= 0:
		return
	var targets := _get_attack_targets()
	if targets.is_empty():
		_cancel_qiankun_ring_sequence()
		return
	var target := targets[
		_qiankun_ring_sequence_launched % targets.size()
	]
	var attack_damage := AttackDamageResultResource.new()
	attack_damage.damage = _qiankun_ring_sequence_damage
	attack_damage.is_critical = _qiankun_ring_sequence_is_critical
	_launch_qiankun_ring(target, attack_damage)
	_qiankun_ring_sequence_launched += 1
	_pending_qiankun_rings -= 1
	_qiankun_ring_sequence_timer = maxf(
		_get_current_weapon_data().projectile_sequence_interval,
		0.01
	)


func _cancel_qiankun_ring_sequence() -> void:
	_pending_qiankun_rings = 0
	_qiankun_ring_sequence_total = 0
	_qiankun_ring_sequence_launched = 0
	_qiankun_ring_sequence_is_critical = false
	_qiankun_ring_sequence_timer = 0.0


func _begin_special_projectile_sequence(
	attack_kind: int,
	attack_damage: AttackDamageResultResource
) -> void:
	_special_sequence_kind = attack_kind
	_special_sequence_total = get_current_delivery_count()
	_pending_special_projectiles = _special_sequence_total
	_special_sequence_launched = 0
	_special_sequence_damage = maxi(attack_damage.damage, 1)
	_special_sequence_exact_damage = maxf(attack_damage.exact_damage, 1.0)
	_special_sequence_is_critical = attack_damage.is_critical
	_special_sequence_timer = 0.0
	_special_sequence_targets = _get_attack_targets()
	_special_sequence_direction = Vector2.UP
	if (
		attack_kind == WeaponDataResource.AttackKind.THUNDER_HAMMER
		and not _special_sequence_targets.is_empty()
	):
		_special_sequence_direction = get_combat_anchor_position().direction_to(
			_special_sequence_targets[0].global_position
		).normalized()
		if _special_sequence_direction.is_zero_approx():
			_special_sequence_direction = Vector2.UP
	_special_sequence_interval = _resolve_special_sequence_interval(
		attack_kind,
		_special_sequence_total
	)
	if attack_kind == WeaponDataResource.AttackKind.FANTIAN_SEAL:
		_fantian_seal_volley_serial += 1
		_active_fantian_seal_volley_id = _fantian_seal_volley_serial
	else:
		_active_fantian_seal_volley_id = -1
	_launch_next_special_projectile()


func _launch_next_special_projectile() -> void:
	if _pending_special_projectiles <= 0:
		return
	var weapon_data := _get_current_weapon_data()
	if weapon_data.projectile_scene == null:
		_cancel_special_projectile_sequence()
		return
	if _special_sequence_kind == WeaponDataResource.AttackKind.THUNDER_HAMMER:
		var cloud := (
			weapon_data.projectile_scene.instantiate()
			as ThunderCloudProjectile
		)
		if cloud != null:
			get_parent().add_child(cloud)
			cloud.global_position = get_combat_anchor_position()
			cloud.configure(
				_special_sequence_direction,
				_special_sequence_exact_damage,
				maxf(get_current_aoe_radius(), 48.0),
				_special_sequence_is_critical,
				self,
				get_current_projectile_speed_multiplier(),
				_special_sequence_launched
			)
			_play_weapon_activation_sfx(weapon_data)
			if is_instance_valid(thunder_hammer_visual):
				thunder_hammer_visual.play_discharge(
					_special_sequence_direction,
					_special_sequence_is_critical
				)
	elif _special_sequence_kind == WeaponDataResource.AttackKind.FANTIAN_SEAL:
		var target := _get_next_special_sequence_target()
		if target == null:
			_cancel_special_projectile_sequence()
			return
		var seal := (
			weapon_data.projectile_scene.instantiate()
			as FantianSealProjectile
		)
		if seal != null:
			get_parent().add_child(seal)
			seal.global_position = target.global_position
			seal.configure(
				target,
				_special_sequence_damage,
				maxf(get_current_aoe_radius(), 48.0),
				_special_sequence_is_critical,
				get_combat_anchor_position(),
				get_current_attack_range(),
				_active_fantian_seal_volley_id
			)
			seal.impact_landed.connect(
				_on_fantian_seal_impact_landed.bind(weapon_data)
			)
			_play_weapon_activation_sfx(weapon_data)
			if get_parent().has_method("request_camera_shake"):
				seal.impact_landed.connect(
					Callable(get_parent(), "request_camera_shake")
				)
	_special_sequence_launched += 1
	_pending_special_projectiles -= 1
	_special_sequence_timer = _special_sequence_interval
	if (
		(
			_special_sequence_kind == WeaponDataResource.AttackKind.THUNDER_HAMMER
			or _special_sequence_kind == WeaponDataResource.AttackKind.FANTIAN_SEAL
		)
		and _pending_special_projectiles <= 0
	):
		_attack_cooldown_remaining = get_current_attack_interval()


## Resolves one readable duplicate-launch gap while ensuring a Fantian Seal
## volley finishes inside 70% of its attack-speed-adjusted cooldown.
func _resolve_special_sequence_interval(
	attack_kind: int,
	delivery_count: int
) -> float:
	var authored_interval := maxf(
		_get_current_weapon_data().projectile_sequence_interval,
		0.01
	)
	if (
		attack_kind != WeaponDataResource.AttackKind.FANTIAN_SEAL
		or delivery_count <= 1
	):
		return authored_interval
	var available_window := (
		get_current_attack_interval()
		* FANTIAN_SEAL_SEQUENCE_WINDOW_RATIO
	)
	return maxf(
		minf(
			authored_interval,
			available_window / float(delivery_count - 1)
		),
		0.01
	)


## Returns the next stable volley target. Duplicates advance through the
## acquisition snapshot before wrapping, so they spread across distinct enemies
## whenever enough valid targets remain.
func _get_next_special_sequence_target() -> EnemyController:
	if not _special_sequence_targets.is_empty():
		var target_count := _special_sequence_targets.size()
		for offset in target_count:
			var target_index := (
				_special_sequence_launched + offset
			) % target_count
			var candidate := _special_sequence_targets[target_index]
			if is_instance_valid(candidate) and candidate.is_combat_active():
				return candidate
	var live_targets := _get_attack_targets()
	if live_targets.is_empty():
		return null
	return live_targets[_special_sequence_launched % live_targets.size()]


func _cancel_special_projectile_sequence() -> void:
	_pending_special_projectiles = 0
	_special_sequence_kind = -1
	_special_sequence_launched = 0
	_special_sequence_exact_damage = 1.0
	_special_sequence_is_critical = false
	_special_sequence_timer = 0.0
	_special_sequence_interval = 0.01
	_special_sequence_total = 0
	_special_sequence_targets.clear()
	_special_sequence_direction = Vector2.UP
	_active_fantian_seal_volley_id = -1


func _get_attack_targets() -> Array[EnemyController]:
	var targets: Array[EnemyController] = []
	for body in attack_area.get_overlapping_bodies():
		if body is EnemyController and body.is_combat_active():
			targets.append(body as EnemyController)
	targets.sort_custom(
		func(a: EnemyController, b: EnemyController) -> bool:
			return get_combat_anchor_position().distance_squared_to(
				a.global_position
			) < (
				get_combat_anchor_position().distance_squared_to(
					b.global_position
				)
			)
	)
	return targets


func _launch_flying_sword(
	target: EnemyController,
	damage: int,
	is_critical: bool,
	projectile_index: int,
	projectile_count: int
) -> void:
	var weapon_data := _get_current_weapon_data()
	if weapon_data.projectile_scene == null:
		return
	var projectile := (
		weapon_data.projectile_scene.instantiate()
		as FlyingSwordProjectile
	)
	if projectile == null:
		push_error(
			"Flying Sword WeaponData projectile_scene must create "
			+ "FlyingSwordProjectile."
		)
		return
	var spawn_position := _consume_flying_sword_visual(
		projectile_index,
		projectile_count
	)
	var direction := spawn_position.direction_to(target.global_position)
	get_parent().add_child(projectile)
	projectile.global_position = spawn_position
	projectile.configure(
		direction,
		damage,
		get_current_attack_range(),
		get_current_projectile_speed_multiplier(),
		is_critical
	)
	_play_weapon_activation_sfx(weapon_data)


func _launch_qiankun_ring(
	target: EnemyController,
	attack_damage: AttackDamageResultResource
) -> void:
	var weapon_data := _get_current_weapon_data()
	if weapon_data.projectile_scene == null:
		return
	var projectile := (
		weapon_data.projectile_scene.instantiate()
		as QiankunRingProjectile
	)
	if projectile == null:
		push_error(
			"Universe Ring WeaponData projectile_scene must create "
			+ "QiankunRingProjectile."
		)
		return
	projectile.enemy_hit.connect(
		_on_qiankun_ring_enemy_hit.bind(weapon_data)
	)
	get_parent().add_child(projectile)
	projectile.global_position = get_combat_anchor_position()
	projectile.configure(
		self,
		target,
		attack_damage.damage,
		get_qiankun_ring_bounce_count(),
		_current_weapon_combat_stats.secondary_targeting_range,
		get_current_aoe_radius(),
		get_current_projectile_speed_multiplier(),
		attack_damage.is_critical
	)
	_play_weapon_activation_sfx(weapon_data)
	projectile.tree_exited.connect(_on_qiankun_ring_returned, CONNECT_ONE_SHOT)
	_active_qiankun_rings += 1
	queue_redraw()


func _on_qiankun_ring_returned() -> void:
	_active_qiankun_rings = maxi(_active_qiankun_rings - 1, 0)
	queue_redraw()


func _on_qiankun_ring_enemy_hit(
	_enemy: EnemyController,
	weapon_data: WeaponDataResource
) -> void:
	_play_weapon_impact_sfx(weapon_data)


func _on_fantian_seal_impact_landed(
	_strength: float,
	weapon_data: WeaponDataResource
) -> void:
	_play_weapon_impact_sfx(weapon_data)


func _on_golden_bell_enemy_hit(_enemy: EnemyController) -> void:
	_play_weapon_impact_sfx(_get_current_weapon_data())


func _play_weapon_activation_sfx(
	weapon_data: WeaponDataResource
) -> void:
	if weapon_data == null:
		return
	_play_weapon_sfx(
		weapon_data.activation_sfx,
		weapon_data.activation_sfx_start_time,
		weapon_data.activation_sfx_end_time,
		weapon_data.activation_sfx_volume_db,
		weapon_data.activation_sfx_pitch_scale
	)


func _play_weapon_impact_sfx(weapon_data: WeaponDataResource) -> void:
	if weapon_data == null:
		return
	_play_weapon_sfx(
		weapon_data.impact_sfx,
		weapon_data.impact_sfx_start_time,
		weapon_data.impact_sfx_end_time,
		weapon_data.impact_sfx_volume_db,
		weapon_data.impact_sfx_pitch_scale
	)


## Plays one bounded section of a weapon stream. Each cue acquires an
## independent voice so sequential projectiles and rapid hits can overlap.
func _play_weapon_sfx(
	stream: AudioStream,
	start_time: float,
	end_time: float,
	volume_db: float,
	pitch_scale: float
) -> void:
	if stream == null:
		return
	var voice := _acquire_weapon_sfx_voice()
	var safe_pitch := clampf(pitch_scale, 0.25, 4.0)
	var stream_length := maxf(stream.get_length(), 0.0)
	var safe_start := maxf(start_time, 0.0)
	if stream_length > 0.0:
		safe_start = minf(safe_start, stream_length)
	var safe_end := maxf(end_time, 0.0)
	if stream_length > 0.0:
		safe_end = minf(safe_end, stream_length)
	_weapon_sfx_serial += 1
	var playback_serial := _weapon_sfx_serial
	voice.set_meta("weapon_sfx_serial", playback_serial)
	voice.stop()
	voice.stream = stream
	voice.bus = (
		weapon_sfx_bus
		if AudioServer.get_bus_index(weapon_sfx_bus) >= 0
		else &"Master"
	)
	voice.volume_db = clampf(
		weapon_sfx_volume_db + volume_db,
		-80.0,
		24.0
	)
	voice.pitch_scale = safe_pitch
	voice.play(safe_start)
	if safe_end <= safe_start:
		return
	var playback_duration := (safe_end - safe_start) / safe_pitch
	get_tree().create_timer(playback_duration, false).timeout.connect(
		_stop_weapon_sfx_voice.bind(voice, playback_serial)
	)


func _acquire_weapon_sfx_voice() -> AudioStreamPlayer:
	for voice in _weapon_sfx_voices:
		if not voice.playing:
			return voice
	if _weapon_sfx_voices.size() < maxi(maximum_weapon_sfx_voices, 1):
		var new_voice := AudioStreamPlayer.new()
		new_voice.name = "WeaponSfxVoice%d" % _weapon_sfx_voices.size()
		add_child(new_voice)
		_weapon_sfx_voices.append(new_voice)
		return new_voice
	var oldest_voice := _weapon_sfx_voices[0]
	var oldest_serial := int(
		oldest_voice.get_meta("weapon_sfx_serial", 0)
	)
	for voice_index in range(1, _weapon_sfx_voices.size()):
		var voice := _weapon_sfx_voices[voice_index]
		var voice_serial := int(voice.get_meta("weapon_sfx_serial", 0))
		if voice_serial < oldest_serial:
			oldest_voice = voice
			oldest_serial = voice_serial
	return oldest_voice


func _stop_weapon_sfx_voice(
	voice: AudioStreamPlayer,
	playback_serial: int
) -> void:
	if (
		not is_instance_valid(voice)
		or int(voice.get_meta("weapon_sfx_serial", -1))
			!= playback_serial
	):
		return
	voice.stop()


func _attract_collectibles(delta: float) -> void:
	for area in attraction_area.get_overlapping_areas():
		if area.has_method("attract_to_player"):
			area.call(
				"attract_to_player",
				self,
				maxf(collectible_attraction_speed, 1.0),
				delta
			)


func _update_visual_state(delta: float) -> void:
	if _should_animate_qiankun_companion():
		_companion_phase = fmod(_companion_phase + delta * 1.6, TAU)
	_attack_flash_remaining = maxf(_attack_flash_remaining - delta, 0.0)
	_damage_flash_remaining = maxf(_damage_flash_remaining - delta, 0.0)
	_shield_flash_remaining = maxf(_shield_flash_remaining - delta, 0.0)
	_dao_attack_remaining = maxf(_dao_attack_remaining - delta, 0.0)
	_palm_aim_refresh_remaining = maxf(
		_palm_aim_refresh_remaining - delta,
		0.0
	)
	_flying_sword_aim_refresh_remaining = maxf(
		_flying_sword_aim_refresh_remaining - delta,
		0.0
	)
	_level_up_effect_remaining = maxf(
		_level_up_effect_remaining - delta,
		0.0
	)
	_breakthrough_effect_remaining = maxf(
		_breakthrough_effect_remaining - delta,
		0.0
	)
	_update_palm_aim()
	_update_palm_weapon_visual(delta)
	_update_flying_sword_visuals(delta)
	_update_fantian_seal_visual(delta)
	_update_dao_weapon_visuals(delta)
	_update_thunder_hammer_visual(delta)
	_update_character_animation()
	_update_damage_feedback_presentation()
	if _has_continuous_custom_drawing():
		queue_redraw()


func _should_animate_qiankun_companion() -> bool:
	return (
		not _equipment_inventory.is_empty()
		and _get_current_weapon_data().attack_kind
			== WeaponDataResource.AttackKind.QIANKUN_RING
		and not is_qiankun_ring_in_flight()
	)


func _has_continuous_custom_drawing() -> bool:
	if (
		_damage_flash_remaining > 0.0
		or _level_up_effect_remaining > 0.0
		or _breakthrough_effect_remaining > 0.0
		or _fantian_seal_switch_shadow_active
		or realm_abilities.is_qi_shield_active()
	):
		return true
	if _palm_debug_geometry_visible and _is_palm_equipped():
		return true
	if _equipment_inventory.is_empty():
		return false
	match _get_current_weapon_data().attack_kind:
		WeaponDataResource.AttackKind.DAO:
			return true
		WeaponDataResource.AttackKind.FLYING_SWORD:
			return _flying_sword_reload_active
		WeaponDataResource.AttackKind.QIANKUN_RING:
			return not is_qiankun_ring_in_flight()
	return false


func _is_dao_equipped() -> bool:
	return (
		not _equipment_inventory.is_empty()
		and _get_current_weapon_data().attack_kind
			== WeaponDataResource.AttackKind.DAO
	)


func _is_thunder_hammer_equipped() -> bool:
	return (
		not _equipment_inventory.is_empty()
		and _get_current_weapon_data().attack_kind
			== WeaponDataResource.AttackKind.THUNDER_HAMMER
	)


func _refresh_thunder_hammer_visual_equipment() -> void:
	if not is_instance_valid(thunder_hammer_visual):
		return
	thunder_hammer_visual.set_equipped(_is_thunder_hammer_equipped())


func _update_thunder_hammer_visual(delta: float) -> void:
	if (
		not is_instance_valid(thunder_hammer_visual)
		or not _is_thunder_hammer_equipped()
	):
		return
	thunder_hammer_visual.position = thunder_hammer_visual.equipped_offset
	var targets := _get_attack_targets()
	var target_available := not targets.is_empty()
	var aim_direction := Vector2.UP
	if target_available:
		aim_direction = get_combat_anchor_position().direction_to(
			targets[0].global_position
		).normalized()
	var active_thunder_volley := (
		_special_sequence_kind == WeaponDataResource.AttackKind.THUNDER_HAMMER
		and _pending_special_projectiles > 0
	)
	if active_thunder_volley:
		aim_direction = _special_sequence_direction
	thunder_hammer_visual.update_combat_state(
		delta,
		_attack_cooldown_remaining,
		get_current_attack_interval(),
		_special_sequence_launched if active_thunder_volley else 0,
		_special_sequence_total if active_thunder_volley else 0,
		target_available,
		aim_direction
	)


## Returns whether the dedicated Thunder Hammer companion is currently shown.
func is_thunder_hammer_visual_equipped() -> bool:
	return (
		is_instance_valid(thunder_hammer_visual)
		and thunder_hammer_visual.is_equipped_visual()
	)


## Returns normalized Thunder Hammer charge for HUD and focused visual tests.
func get_thunder_hammer_charge_ratio() -> float:
	return (
		thunder_hammer_visual.get_charge_ratio()
		if is_instance_valid(thunder_hammer_visual)
		else 0.0
	)


## Returns whether Thunder Hammer is charged with a valid target in range.
func is_thunder_hammer_target_ready() -> bool:
	return (
		is_instance_valid(thunder_hammer_visual)
		and thunder_hammer_visual.is_target_ready()
	)


## Returns the active cloud-launch lightning flash strength.
func get_thunder_hammer_discharge_strength() -> float:
	return (
		thunder_hammer_visual.get_discharge_flash_strength()
		if is_instance_valid(thunder_hammer_visual)
		else 0.0
	)


func _refresh_dao_visual_equipment() -> void:
	if not is_instance_valid(dao_weapon_layer):
		return
	if not _is_dao_equipped():
		_dao_visual_equipped = false
		_dao_combat_active = false
		_dao_warning_strength = 0.0
		_dao_attack_visual_hold_remaining = 0.0
		for weapon_index in _dao_weapon_sprites.size():
			_dao_weapon_visibility[weapon_index] = 0.0
			_dao_weapon_sprites[weapon_index].hide()
		return
	var switching_to_dao := not _dao_visual_equipped
	_dao_visual_equipped = true
	_ensure_dao_weapon_count(get_dao_orbit_count())
	if not switching_to_dao:
		return
	_dao_attack_visual_hold_remaining = 0.0
	for weapon_index in _dao_weapon_sprites.size():
		_dao_weapon_visibility[weapon_index] = 0.0
		_dao_weapon_sprites[weapon_index].hide()
	_dao_combat_active = (
		_get_nearest_dao_enemy_distance()
		<= get_current_attack_range()
	)
	_dao_transition_elapsed = 0.0
	_dao_summoning_auxiliaries = _dao_combat_active
	_dao_recalling_auxiliaries = false
	_dao_orbit_speed = (
		DAO_ATTACK_ORBIT_SPEED
		if _dao_combat_active
		else 0.0
	)


func _ensure_dao_weapon_count(required_count: int) -> void:
	var safe_count := maxi(required_count, 1)
	if _dao_outline_material == null:
		_dao_outline_material = ShaderMaterial.new()
		_dao_outline_material.shader = OUTLINE_SHADER
		_dao_outline_material.set_shader_parameter(
			&"outline_width",
			DAO_OUTLINE_WORLD_WIDTH / DAO_WEAPON_SCALE
		)
		_dao_outline_material.set_shader_parameter(
			&"outline_color",
			Color.TRANSPARENT
		)
	while _dao_weapon_sprites.size() < safe_count:
		var weapon_index := _dao_weapon_sprites.size()
		var weapon_sprite := Sprite2D.new()
		weapon_sprite.name = "DaoWeapon%d" % (weapon_index + 1)
		weapon_sprite.texture = DAO_WEAPON_TEXTURE
		weapon_sprite.material = _dao_outline_material
		weapon_sprite.scale = Vector2.ONE * DAO_WEAPON_SCALE
		weapon_sprite.z_index = weapon_index
		weapon_sprite.hide()
		dao_weapon_layer.add_child(weapon_sprite)
		_dao_weapon_sprites.append(weapon_sprite)
		_dao_weapon_visibility.append(0.0)
	while _dao_weapon_sprites.size() > safe_count:
		var removed_sprite: Sprite2D = _dao_weapon_sprites.pop_back()
		_dao_weapon_visibility.pop_back()
		removed_sprite.queue_free()


func _get_nearest_dao_enemy_distance() -> float:
	var nearest_distance := INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		if not enemy.is_combat_active():
			continue
		nearest_distance = minf(
			nearest_distance,
			get_combat_anchor_position().distance_to(enemy.global_position)
		)
	return nearest_distance


func _get_dao_spawn_position(weapon_index: int, weapon_count: int) -> Vector2:
	var spawn_angle := (
		-PI * 0.5
		+ TAU * float(weapon_index) / float(maxi(weapon_count, 1))
	)
	return Vector2.from_angle(spawn_angle) * 22.0


func _get_dao_orbit_index(weapon_index: int, weapon_count: int) -> int:
	if weapon_index == 0:
		return maxi(weapon_count - 1, 0)
	return weapon_index - 1


func _get_dao_transition_delay(
	weapon_index: int,
	weapon_count: int
) -> float:
	var auxiliary_index := maxi(weapon_index - 1, 0)
	var final_auxiliary_index := maxi(weapon_count - 2, 1)
	var effective_stagger := minf(
		DAO_AUXILIARY_STAGGER,
		DAO_MAX_AUXILIARY_STAGGER_WINDOW
			/ float(final_auxiliary_index)
	)
	return float(auxiliary_index) * effective_stagger


func _set_dao_outline(strength: float) -> void:
	if _dao_outline_material == null:
		return
	_dao_outline_material.set_shader_parameter(
		&"outline_color",
		Color(
			DAO_OUTLINE_COLOR,
			clampf(strength, 0.0, 1.0)
		)
	)


func _draw_dao_trails() -> void:
	if not _dao_visual_equipped or not _is_dao_equipped():
		return
	var weapon_count := _dao_weapon_sprites.size()
	var trail_points := PackedVector2Array()
	var glow_colors := PackedColorArray()
	var core_colors := PackedColorArray()
	var highlight_points := PackedVector2Array()
	var highlight_colors := PackedColorArray()
	var attack_trail_stride := maxi(
		ceili(
			float(weapon_count)
			/ float(DAO_MAX_ATTACK_TRAIL_COUNT)
		),
		1
	)
	for weapon_index in weapon_count:
		var visibility := _dao_weapon_visibility[weapon_index]
		if visibility <= 0.04:
			continue
		if (
			_dao_combat_active
			and weapon_index % attack_trail_stride != 0
		):
			continue
		var orbit_angle := (
			_dao_orbit_phase
			+ TAU * float(weapon_index) / float(maxi(weapon_count, 1))
		)
		var orbit_radius := get_dao_orbit_radius(
			_get_dao_orbit_index(weapon_index, weapon_count)
		)
		if _dao_combat_active:
			var trail_visibility := smoothstep(0.12, 0.82, visibility)
			_append_dao_trail_segments(
				trail_points,
				glow_colors,
				orbit_radius,
				orbit_angle,
				_dao_attack_trail_unit_points,
				DAO_ATTACK_TRAIL_COLOR,
				0.16 * trail_visibility
			)
			_append_dao_trail_segments(
				highlight_points,
				highlight_colors,
				orbit_radius,
				orbit_angle,
				_dao_attack_highlight_unit_points,
				DAO_ATTACK_TRAIL_HIGHLIGHT,
				0.88 * trail_visibility
			)
		elif weapon_index == 0:
			_append_dao_trail_segments(
				trail_points,
				glow_colors,
				orbit_radius,
				orbit_angle,
				_dao_idle_trail_unit_points,
				DAO_IDLE_TRAIL_COLOR,
				0.10 * visibility
			)
	if trail_points.size() > 1:
		var glow_width := 13.0 if _dao_combat_active else 7.0
		var core_width := 4.8 if _dao_combat_active else 2.5
		var core_alpha_scale := 4.5 if _dao_combat_active else 3.8
		core_colors.resize(glow_colors.size())
		for color_index in glow_colors.size():
			var glow_color := glow_colors[color_index]
			core_colors[color_index] = Color(
				glow_color,
				glow_color.a * core_alpha_scale
			)
		draw_multiline_colors(
			trail_points,
			glow_colors,
			glow_width,
			true
		)
		draw_multiline_colors(
			trail_points,
			core_colors,
			core_width,
			true
		)
	if highlight_points.size() > 1:
		draw_multiline_colors(
			highlight_points,
			highlight_colors,
			1.8,
			true
		)


func _prepare_dao_trail_geometry() -> void:
	_dao_idle_trail_unit_points = _build_dao_trail_unit_points(
		DAO_IDLE_TRAIL_ARC,
		DAO_IDLE_TRAIL_SEGMENTS
	)
	_dao_attack_trail_unit_points = _build_dao_trail_unit_points(
		DAO_ATTACK_TRAIL_ARC,
		DAO_ATTACK_TRAIL_SEGMENTS
	)
	_dao_attack_highlight_unit_points = _build_dao_trail_unit_points(
		DAO_ATTACK_TRAIL_ARC * 0.48,
		DAO_ATTACK_TRAIL_SEGMENTS >> 1
	)


func _build_dao_trail_unit_points(
	arc_length: float,
	segment_count: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segment_count := maxi(segment_count, 1)
	points.resize(safe_segment_count * 2)
	for segment_index in safe_segment_count:
		var start_ratio := (
			float(segment_index) / float(safe_segment_count)
		)
		var end_ratio := (
			float(segment_index + 1) / float(safe_segment_count)
		)
		points[segment_index * 2] = Vector2.from_angle(
			-arc_length * (1.0 - start_ratio)
		)
		points[segment_index * 2 + 1] = Vector2.from_angle(
			-arc_length * (1.0 - end_ratio)
		)
	return points


func _append_dao_trail_segments(
	points: PackedVector2Array,
	primary_colors: PackedColorArray,
	radius: float,
	head_angle: float,
	unit_points: PackedVector2Array,
	color: Color,
	primary_alpha: float
) -> void:
	var safe_segment_count := unit_points.size() >> 1
	var rotation_transform := Transform2D(head_angle, Vector2.ZERO)
	for segment_index in safe_segment_count:
		var end_ratio := (
			float(segment_index + 1) / float(safe_segment_count)
		)
		var end_fade := end_ratio * end_ratio
		var point_offset := segment_index * 2
		points.append(
			rotation_transform * (unit_points[point_offset] * radius)
		)
		points.append(
			rotation_transform * (unit_points[point_offset + 1] * radius)
		)
		primary_colors.append(
			Color(color, primary_alpha * end_fade)
		)


func _update_dao_weapon_visuals(delta: float) -> void:
	if not _dao_visual_equipped or not _is_dao_equipped():
		return
	_ensure_dao_weapon_count(get_dao_orbit_count())
	_dao_attack_visual_hold_remaining = maxf(
		_dao_attack_visual_hold_remaining - delta,
		0.0
	)
	var nearest_distance := _get_nearest_dao_enemy_distance()
	var attack_range := get_current_attack_range()
	var next_combat_active := (
		nearest_distance <= attack_range
		or _dao_attack_visual_hold_remaining > 0.0
	)
	if next_combat_active != _dao_combat_active:
		_dao_combat_active = next_combat_active
		_dao_transition_elapsed = 0.0
		_dao_summoning_auxiliaries = next_combat_active
		_dao_recalling_auxiliaries = not next_combat_active
	else:
		_dao_transition_elapsed += delta
	var target_speed := (
		DAO_ATTACK_ORBIT_SPEED
		if _dao_combat_active
		else DAO_IDLE_ORBIT_SPEED
	)
	_dao_orbit_speed = move_toward(
		_dao_orbit_speed,
		target_speed,
		DAO_ORBIT_ACCELERATION * delta
	)
	_dao_orbit_phase = fmod(
		_dao_orbit_phase + _dao_orbit_speed * delta,
		TAU
	)
	if nearest_distance <= attack_range + DAO_WARNING_MARGIN:
		_dao_warning_strength = 1.0 - clampf(
			(nearest_distance - attack_range) / DAO_WARNING_MARGIN,
			0.0,
			1.0
		)
	else:
		_dao_warning_strength = 0.0
	_set_dao_outline(
		1.0 if _dao_combat_active else _dao_warning_strength
	)

	var weapon_count := _dao_weapon_sprites.size()
	for weapon_index in weapon_count:
		var transition_delay := _get_dao_transition_delay(
			weapon_index,
			weapon_count
		)
		var target_visibility := 1.0 if weapon_index == 0 else 0.0
		if weapon_index > 0 and _dao_combat_active:
			target_visibility = (
				1.0
				if (
					not _dao_summoning_auxiliaries
					or _dao_transition_elapsed >= transition_delay
				)
				else 0.0
			)
		elif weapon_index > 0 and _dao_recalling_auxiliaries:
			target_visibility = (
				0.0
				if _dao_transition_elapsed >= transition_delay
				else 1.0
			)
		var transition_duration := (
			DAO_SUMMON_DURATION
			if target_visibility > _dao_weapon_visibility[weapon_index]
			else DAO_RECALL_DURATION
		)
		_dao_weapon_visibility[weapon_index] = move_toward(
			_dao_weapon_visibility[weapon_index],
			target_visibility,
			delta / transition_duration
		)
		_update_one_dao_weapon(
			weapon_index,
			weapon_count,
			_dao_weapon_visibility[weapon_index]
		)
	var final_auxiliary_delay := _get_dao_transition_delay(
		maxi(weapon_count - 1, 0),
		weapon_count
	)
	if (
		_dao_transition_elapsed
		>= final_auxiliary_delay
			+ maxf(DAO_SUMMON_DURATION, DAO_RECALL_DURATION)
	):
		_dao_summoning_auxiliaries = false
		_dao_recalling_auxiliaries = false


func _update_one_dao_weapon(
	weapon_index: int,
	weapon_count: int,
	visibility: float
) -> void:
	var weapon_sprite := _dao_weapon_sprites[weapon_index]
	if visibility <= 0.0:
		weapon_sprite.hide()
		return
	weapon_sprite.show()
	var orbit_angle := (
		_dao_orbit_phase
		+ TAU * float(weapon_index) / float(maxi(weapon_count, 1))
	)
	var orbit_index := _get_dao_orbit_index(
		weapon_index,
		weapon_count
	)
	var orbit_position := (
		Vector2.from_angle(orbit_angle)
		* get_dao_orbit_radius(orbit_index)
	)
	var summon_position := _get_dao_spawn_position(
		weapon_index,
		weapon_count
	)
	var eased_visibility := (
		visibility * visibility * (3.0 - 2.0 * visibility)
	)
	weapon_sprite.position = summon_position.lerp(
		orbit_position,
		eased_visibility
	)
	weapon_sprite.rotation = orbit_angle + PI
	if (
		weapon_index == 0
		and not _dao_combat_active
		and _dao_warning_strength > DAO_WARNING_SHAKE_START
	):
		var shake_strength := clampf(
			(
				_dao_warning_strength - DAO_WARNING_SHAKE_START
			) / (1.0 - DAO_WARNING_SHAKE_START),
			0.0,
			1.0
		)
		weapon_sprite.position += Vector2(
			sin(_companion_phase * 47.0),
			cos(_companion_phase * 41.0)
		) * (5.0 * shake_strength)
		weapon_sprite.rotation += (
			sin(_companion_phase * 59.0) * 0.14 * shake_strength
		)
	var summon_scale := (
		lerpf(0.52, 1.0, visibility)
		+ sin(visibility * PI) * 0.2
	)
	weapon_sprite.scale = (
		Vector2.ONE * DAO_WEAPON_SCALE * summon_scale
	)
	weapon_sprite.modulate = Color(1.0, 1.0, 1.0, visibility)


## Returns whether Dao visuals currently use the high-speed combat orbit.
func is_dao_combat_visual_active() -> bool:
	return _dao_visual_equipped and _dao_combat_active


## Returns the number of Dao sprites currently visible, including blades that
## are still flying between the player and their assigned orbit.
func get_visible_dao_weapon_count() -> int:
	var visible_count := 0
	for weapon_sprite in _dao_weapon_sprites:
		if is_instance_valid(weapon_sprite) and weapon_sprite.visible:
			visible_count += 1
	return visible_count


## Returns the nearest-enemy Dao warning intensity from zero to one.
func get_dao_warning_strength() -> float:
	return _dao_warning_strength


func _is_palm_equipped() -> bool:
	return (
		not _equipment_inventory.is_empty()
		and _get_current_weapon_data().attack_kind
			== WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM
	)


func _refresh_palm_visual_equipment() -> void:
	if not is_instance_valid(palm_weapon):
		return
	if _palm_glow_material == null:
		_palm_glow_material = ShaderMaterial.new()
		_palm_glow_material.shader = OUTLINE_SHADER
		_palm_glow_material.set_shader_parameter(
			&"outline_width",
			PALM_OUTLINE_TEXTURE_WIDTH
		)
	if _palm_dissolve_material == null:
		_palm_dissolve_material = _create_palm_dissolve_material()
	palm_weapon.texture = PALM_WEAPON_TEXTURE
	if _palm_attack_sprites.is_empty():
		_palm_attack_sprites.append(palm_weapon)
	if not _is_palm_equipped():
		_palm_visual_equipped = false
		_palm_visual_state = PalmVisualState.HIDDEN
		_palm_visual_target = null
		_palm_aim_target = null
		_palm_warning_strength = 0.0
		_palm_visual_pending_damage = 0
		_palm_visual_pending_critical = false
		for attack_sprite in _palm_attack_sprites:
			attack_sprite.hide()
		return
	_palm_visual_equipped = true
	_palm_visual_elapsed = 0.0
	_palm_visual_target = null
	_show_palm_idle()


func _show_palm_idle() -> void:
	if not _palm_visual_equipped or not _is_palm_equipped():
		_palm_visual_state = PalmVisualState.HIDDEN
		for attack_sprite in _palm_attack_sprites:
			attack_sprite.hide()
		return
	_hide_palm_attack_echoes()
	_palm_visual_state = PalmVisualState.IDLE
	palm_weapon.material = _palm_glow_material
	palm_weapon.position = _get_palm_idle_position()
	palm_weapon.rotation = _get_palm_rotation(_palm_attack_direction)
	palm_weapon.scale = Vector2.ONE * _get_palm_idle_scale()
	_set_palm_glow(_palm_warning_strength)
	palm_weapon.show()


func _ensure_palm_attack_sprite_count(required_count: int) -> void:
	if _palm_attack_sprites.is_empty():
		_palm_attack_sprites.append(palm_weapon)
	if _palm_visual_dissolve_materials.is_empty():
		_palm_visual_dissolve_materials.append(_palm_dissolve_material)
	while _palm_attack_sprites.size() < maxi(required_count, 1):
		var echo_sprite := Sprite2D.new()
		echo_sprite.texture = PALM_WEAPON_TEXTURE
		echo_sprite.material = _palm_glow_material
		echo_sprite.hide()
		palm_echo_layer.add_child(echo_sprite)
		_palm_attack_sprites.append(echo_sprite)
		_palm_visual_dissolve_materials.append(
			_create_palm_dissolve_material()
		)
	for sprite_index in range(
		maxi(required_count, 1),
		_palm_attack_sprites.size()
	):
		_palm_attack_sprites[sprite_index].hide()


func _create_palm_dissolve_material() -> ShaderMaterial:
	var dissolve_material := ShaderMaterial.new()
	dissolve_material.shader = DISSOLVE_SHADER
	dissolve_material.set_shader_parameter(
		&"edge_color",
		Color("78f7ff")
	)
	return dissolve_material


func _hide_palm_attack_echoes() -> void:
	for sprite_index in range(1, _palm_attack_sprites.size()):
		var echo_sprite := _palm_attack_sprites[sprite_index]
		echo_sprite.material = _palm_glow_material
		echo_sprite.hide()


func _get_palm_visual_direction_count() -> int:
	match _get_current_realm_index():
		1:
			return 2
		2:
			return 6
		3:
			return 8
		_:
			return 1


func _get_palm_visual_directions() -> Array[Vector2]:
	var directions: Array[Vector2] = []
	for _strike_index in _get_palm_visual_direction_count():
		directions.append(_palm_cast_direction)
	return directions


func _get_palm_rotation(direction: Vector2) -> float:
	var safe_direction := direction.normalized()
	if safe_direction.is_zero_approx():
		safe_direction = Vector2.UP
	return safe_direction.angle() + PI * 0.5


func _get_palm_idle_position() -> Vector2:
	var direction := _palm_attack_direction.normalized()
	if is_instance_valid(_palm_aim_target):
		direction = get_combat_anchor_position().direction_to(
			_palm_aim_target.global_position
		).normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	return direction * lerpf(
		PALM_IDLE_RADIUS,
		PALM_CHARGED_RADIUS,
		_palm_warning_strength
	)


func _get_palm_idle_scale() -> float:
	return lerpf(
		PALM_LAUNCH_SCALE,
		PALM_CHARGED_SCALE,
		_palm_warning_strength
	)


func _set_palm_glow(strength: float, alpha: float = 1.0) -> void:
	var safe_strength := clampf(strength, 0.0, 1.0)
	var safe_alpha := clampf(alpha, 0.0, 1.0)
	var brightness := lerpf(1.0, 1.42, safe_strength)
	palm_weapon.modulate = Color(
		brightness,
		brightness,
		brightness,
		safe_alpha
	)
	if _palm_glow_material != null:
		_palm_glow_material.set_shader_parameter(
			&"outline_color",
			Color(
				PALM_GLOW_COLOR,
				safe_strength * safe_alpha
			)
		)


func _set_palm_attack_glow(strength: float, alpha: float = 1.0) -> void:
	_set_palm_glow(strength, alpha)
	var safe_strength := clampf(strength, 0.0, 1.0)
	var safe_alpha := clampf(alpha, 0.0, 1.0)
	var brightness := lerpf(1.0, 1.42, safe_strength)
	for sprite_index in range(1, _palm_attack_sprites.size()):
		var attack_sprite := _palm_attack_sprites[sprite_index]
		if attack_sprite.visible:
			attack_sprite.modulate = Color(
				brightness,
				brightness,
				brightness,
				safe_alpha
			)


func _get_palm_impact_position(
	impact_global_position: Vector2,
	direction: Vector2,
	scale_value: float
) -> Vector2:
	var rotation := _get_palm_rotation(direction)
	var palm_center_offset := (
		Vector2.DOWN.rotated(rotation)
		* PALM_CENTER_OFFSET_PIXELS
		* scale_value
	)
	return combat_anchor.to_local(impact_global_position) - palm_center_offset


func _begin_palm_visual_strike(
	target: EnemyController,
	attack_damage: AttackDamageResultResource
) -> void:
	if not _palm_visual_equipped or not is_instance_valid(target):
		return
	_palm_visual_target = target
	_palm_visual_pending_damage = maxi(attack_damage.damage, 1)
	_palm_visual_pending_critical = attack_damage.is_critical
	_palm_visual_directions = _get_palm_visual_directions()
	_ensure_palm_attack_sprite_count(_palm_visual_directions.size())
	_palm_visual_start_positions.clear()
	_palm_visual_start_scales.clear()
	_palm_visual_impact_positions.clear()
	_palm_visual_hit_resolved.clear()
	_palm_visual_launched.clear()
	_palm_visual_skipped.clear()
	_palm_visual_targets.clear()
	_palm_visual_elapsed = 0.0
	_palm_visual_state = PalmVisualState.STRIKING
	for sprite_index in _palm_visual_directions.size():
		var attack_sprite := _palm_attack_sprites[sprite_index]
		_palm_visual_start_positions.append(Vector2.ZERO)
		_palm_visual_start_scales.append(PALM_CHARGED_SCALE)
		_palm_visual_hit_resolved.append(false)
		_palm_visual_launched.append(false)
		_palm_visual_skipped.append(false)
		_palm_visual_targets.append(null)
		_palm_visual_impact_positions.append(Vector2.ZERO)
		attack_sprite.material = _palm_glow_material
		attack_sprite.hide()
	_launch_palm_visual_strike(0, target)
	_set_palm_attack_glow(1.0)


func _launch_palm_visual_strike(
	strike_index: int,
	fallback_target: EnemyController = null
) -> void:
	if (
		strike_index < 0
		or strike_index >= _palm_visual_directions.size()
		or _palm_visual_launched[strike_index]
	):
		return
	_palm_visual_launched[strike_index] = true
	var target := _get_nearest_palm_target()
	if target == null and is_instance_valid(fallback_target):
		if fallback_target.is_combat_active():
			target = fallback_target
	if target == null:
		_palm_visual_hit_resolved[strike_index] = true
		_palm_visual_skipped[strike_index] = true
		return
	var attack_direction := get_combat_anchor_position().direction_to(
		target.global_position
	).normalized()
	if attack_direction.is_zero_approx():
		attack_direction = Vector2.UP
	_palm_visual_targets[strike_index] = target
	_palm_visual_directions[strike_index] = attack_direction
	_palm_cast_direction = attack_direction
	_palm_attack_direction = attack_direction
	var attack_sprite := _palm_attack_sprites[strike_index]
	var start_position := (
		palm_weapon.position
		if strike_index == 0
		else attack_direction * PALM_CHARGED_RADIUS
	)
	var start_scale := (
		palm_weapon.scale.x
		if strike_index == 0
		else PALM_CHARGED_SCALE
	)
	_palm_visual_start_positions[strike_index] = start_position
	_palm_visual_start_scales[strike_index] = start_scale
	_palm_visual_impact_positions[strike_index] = _get_palm_impact_position(
		target.global_position,
		attack_direction,
		PALM_STRIKE_SCALE
	)
	attack_sprite.material = _palm_glow_material
	attack_sprite.position = start_position
	attack_sprite.rotation = _get_palm_rotation(attack_direction)
	attack_sprite.scale = Vector2.ONE * start_scale
	attack_sprite.show()


func _resolve_palm_visual_hit(strike_index: int) -> void:
	var attack_damage := AttackDamageResultResource.new(
		_palm_visual_pending_damage,
		_palm_visual_pending_critical
	)
	var target: EnemyController
	if is_instance_valid(_palm_visual_targets[strike_index]):
		target = _palm_visual_targets[strike_index] as EnemyController
	if not is_instance_valid(target) or not target.is_combat_active():
		target = _get_nearest_palm_target()
	if is_instance_valid(target) and target.is_combat_active():
		_apply_palm_damage(target, attack_damage)
	_attack_flash_remaining = PALM_COVERAGE_FLASH_DURATION


func _update_palm_attack_sequence() -> void:
	var sequence_complete := true
	for sprite_index in _palm_visual_directions.size():
		var attack_sprite := _palm_attack_sprites[sprite_index]
		var local_elapsed := (
			_palm_visual_elapsed
			- float(sprite_index) * PALM_STRIKE_STAGGER
		)
		if local_elapsed < 0.0:
			attack_sprite.hide()
			sequence_complete = false
			continue
		if not _palm_visual_launched[sprite_index]:
			_launch_palm_visual_strike(sprite_index)
		if not _palm_visual_launched[sprite_index]:
			sequence_complete = false
			continue
		if _palm_visual_skipped[sprite_index]:
			attack_sprite.hide()
			continue
		attack_sprite.show()
		if local_elapsed < PALM_STRIKE_DURATION:
			sequence_complete = false
			var strike_progress := clampf(
				local_elapsed / PALM_STRIKE_DURATION,
				0.0,
				1.0
			)
			var strike_eased := 1.0 - pow(1.0 - strike_progress, 3.0)
			var strike_scale := lerpf(
				_palm_visual_start_scales[sprite_index],
				PALM_STRIKE_SCALE,
				strike_eased
			)
			strike_scale *= 1.0 + sin(strike_progress * PI) * 0.12
			attack_sprite.material = _palm_glow_material
			attack_sprite.position = (
				_palm_visual_start_positions[sprite_index].lerp(
					_palm_visual_impact_positions[sprite_index],
					strike_eased
				)
			)
			attack_sprite.scale = Vector2.ONE * strike_scale
			attack_sprite.rotation = _get_palm_rotation(
				_palm_visual_directions[sprite_index]
			)
			var brightness := lerpf(1.42, 1.1, strike_eased)
			attack_sprite.modulate = Color(
				brightness,
				brightness,
				brightness,
				1.0
			)
			continue
		if not _palm_visual_hit_resolved[sprite_index]:
			_palm_visual_hit_resolved[sprite_index] = true
			_resolve_palm_visual_hit(sprite_index)
			_palm_visual_state = PalmVisualState.DISSOLVING
			attack_sprite.material = (
				_palm_visual_dissolve_materials[sprite_index]
			)
			attack_sprite.modulate = Color.WHITE
		var dissolve_progress := clampf(
			(local_elapsed - PALM_STRIKE_DURATION)
				/ PALM_DISSOLVE_DURATION,
			0.0,
			1.0
		)
		var dissolve_material := (
			_palm_visual_dissolve_materials[sprite_index]
		)
		dissolve_material.set_shader_parameter(
			&"dissolve_amount",
			dissolve_progress
		)
		attack_sprite.scale = (
			Vector2.ONE
			* lerpf(
				PALM_STRIKE_SCALE,
				PALM_STRIKE_SCALE * 1.12,
				dissolve_progress
			)
		)
		if dissolve_progress < 1.0:
			sequence_complete = false
		else:
			attack_sprite.hide()
	if sequence_complete:
		_palm_visual_pending_damage = 0
		_palm_visual_pending_critical = false
		_palm_visual_target = null
		_palm_visual_targets.clear()
		_palm_visual_launched.clear()
		_palm_visual_skipped.clear()
		_palm_visual_elapsed = 0.0
		_show_palm_idle()


func _update_palm_warning() -> void:
	if not is_instance_valid(_palm_aim_target):
		_palm_warning_strength = 0.0
		return
	var nearest_distance := get_combat_anchor_position().distance_to(
		_palm_aim_target.global_position
	)
	var attack_range := get_current_attack_range()
	if nearest_distance > attack_range + PALM_WARNING_MARGIN:
		_palm_warning_strength = 0.0
		return
	_palm_warning_strength = 1.0 - clampf(
		(nearest_distance - attack_range) / PALM_WARNING_MARGIN,
		0.0,
		1.0
	)


func _update_palm_weapon_visual(delta: float) -> void:
	if not _palm_visual_equipped or not _is_palm_equipped():
		return
	_update_palm_warning()
	if _palm_visual_state == PalmVisualState.HIDDEN:
		palm_weapon.hide()
		return
	_palm_visual_elapsed += delta
	match _palm_visual_state:
		PalmVisualState.IDLE:
			var aim_direction := _palm_attack_direction
			if is_instance_valid(_palm_aim_target):
				aim_direction = get_combat_anchor_position().direction_to(
					_palm_aim_target.global_position
				).normalized()
			var follow_weight := 1.0 - exp(-14.0 * delta)
			palm_weapon.position = palm_weapon.position.lerp(
				_get_palm_idle_position(),
				follow_weight
			)
			var next_scale := lerpf(
				palm_weapon.scale.x,
				_get_palm_idle_scale(),
				follow_weight
			)
			palm_weapon.scale = Vector2.ONE * next_scale
			palm_weapon.rotation = lerp_angle(
				palm_weapon.rotation,
				_get_palm_rotation(aim_direction),
				1.0 - exp(-20.0 * delta)
			)
			_set_palm_glow(_palm_warning_strength)
			palm_weapon.show()
		PalmVisualState.STRIKING:
			_update_palm_attack_sequence()
		PalmVisualState.DISSOLVING:
			_update_palm_attack_sequence()


func get_palm_visual_state() -> int:
	return _palm_visual_state


## Returns every currently visible Palm sprite. Idle presentation reports one;
## Foundation and later casts report their synchronized visual echo count.
func get_visible_palm_sprite_count() -> int:
	var visible_count := 0
	for attack_sprite in _palm_attack_sprites:
		if is_instance_valid(attack_sprite) and attack_sprite.visible:
			visible_count += 1
	return visible_count


func get_palm_warning_strength() -> float:
	return _palm_warning_strength


## Enables the exact Great Strength Palm combat geometry used by the pause
## debug panel. The setting persists after gameplay resumes.
func debug_set_palm_geometry_visible(visible: bool) -> void:
	_palm_debug_geometry_visible = visible
	queue_redraw()


func is_palm_debug_geometry_visible() -> bool:
	return _palm_debug_geometry_visible


func _is_flying_sword_equipped() -> bool:
	return (
		not _equipment_inventory.is_empty()
		and _get_current_weapon_data().attack_kind
			== WeaponDataResource.AttackKind.FLYING_SWORD
	)


func _refresh_flying_sword_visual_equipment() -> void:
	if not is_instance_valid(flying_sword_layer):
		return
	if not _is_flying_sword_equipped():
		_flying_sword_visual_equipped = false
		_flying_sword_visual_summoning = false
		_flying_sword_warning_strength = 0.0
		_flying_sword_warning_pulse_elapsed = 0.0
		_flying_sword_aim_target = null
		_flying_sword_aim_refresh_remaining = 0.0
		for sword_sprite in _flying_sword_visual_sprites:
			sword_sprite.hide()
		_set_flying_sword_readiness(0.0, 0.0)
		return
	var switching_to_sword := not _flying_sword_visual_equipped
	_flying_sword_visual_equipped = true
	_flying_sword_aim_refresh_remaining = 0.0
	_ensure_flying_sword_visual_count(
		get_flying_sword_projectile_count()
	)
	if not switching_to_sword:
		return
	_flying_sword_orbit_phase = 0.0
	_flying_sword_visual_elapsed = 0.0
	_flying_sword_visual_summoning = true
	for sword_index in _flying_sword_visual_sprites.size():
		if not _flying_sword_reload_active:
			_flying_sword_visual_filled[sword_index] = true
		_flying_sword_visual_visibility[sword_index] = 0.0
		_flying_sword_visual_sprites[sword_index].hide()


func _ensure_flying_sword_visual_count(required_count: int) -> void:
	var safe_count := maxi(required_count, 1)
	if _flying_sword_outline_material == null:
		_flying_sword_outline_material = ShaderMaterial.new()
		_flying_sword_outline_material.shader = (
			FLYING_SWORD_READINESS_SHADER
		)
		_flying_sword_outline_material.set_shader_parameter(
			&"outline_width",
			FLYING_SWORD_OUTLINE_TEXTURE_WIDTH
		)
		_flying_sword_outline_material.set_shader_parameter(
			&"outline_color",
			FLYING_SWORD_OUTLINE_COLOR
		)
		_flying_sword_outline_material.set_shader_parameter(
			&"glow_color",
			flying_sword_warning_glow_color
		)
		_flying_sword_outline_material.set_shader_parameter(
			&"glow_width",
			flying_sword_warning_glow_width
		)
		_flying_sword_outline_material.set_shader_parameter(
			&"glow_strength",
			flying_sword_warning_glow_strength
		)
		_flying_sword_outline_material.set_shader_parameter(
			&"sword_brighten",
			flying_sword_warning_brighten
		)
		_set_flying_sword_readiness(0.0, 0.0)
	var previous_count := _flying_sword_visual_sprites.size()
	while _flying_sword_visual_sprites.size() < safe_count:
		var sword_index := _flying_sword_visual_sprites.size()
		var sword_sprite := Sprite2D.new()
		sword_sprite.name = "FlyingSword%d" % (sword_index + 1)
		sword_sprite.texture = FLYING_SWORD_TEXTURE
		sword_sprite.material = _flying_sword_outline_material
		sword_sprite.scale = Vector2.ONE * FLYING_SWORD_SCALE
		sword_sprite.z_index = sword_index
		sword_sprite.hide()
		flying_sword_layer.add_child(sword_sprite)
		_flying_sword_visual_sprites.append(sword_sprite)
		_flying_sword_visual_visibility.append(0.0)
		_flying_sword_visual_filled.append(
			not _flying_sword_reload_active
		)
	while _flying_sword_visual_sprites.size() > safe_count:
		var removed_sprite: Sprite2D = (
			_flying_sword_visual_sprites.pop_back()
		)
		_flying_sword_visual_visibility.pop_back()
		_flying_sword_visual_filled.pop_back()
		removed_sprite.queue_free()
	if previous_count < safe_count and _flying_sword_visual_equipped:
		_flying_sword_visual_summoning = true
		_flying_sword_visual_elapsed = 0.0


func _set_flying_sword_readiness(
	strength: float,
	warning_energy: float
) -> void:
	if _flying_sword_outline_material == null:
		return
	_flying_sword_outline_material.set_shader_parameter(
		&"readiness_strength",
		clampf(strength, 0.0, 1.0)
	)
	_flying_sword_outline_material.set_shader_parameter(
		&"warning_energy",
		clampf(warning_energy, 0.0, 1.0)
	)


func _get_flying_sword_summon_delay(
	sword_index: int,
	sword_count: int
) -> float:
	var final_index := maxi(sword_count - 1, 1)
	var effective_stagger := minf(
		FLYING_SWORD_SUMMON_STAGGER,
		FLYING_SWORD_MAX_SUMMON_WINDOW / float(final_index)
	)
	return float(sword_index) * effective_stagger


func _get_flying_sword_slot_angle(
	sword_index: int,
	sword_count: int
) -> float:
	return (
		-PI * 0.5
		+ _flying_sword_orbit_phase
		+ TAU * float(sword_index) / float(maxi(sword_count, 1))
	)


func _get_flying_sword_slot_position(
	sword_index: int,
	sword_count: int
) -> Vector2:
	var attack_range := get_current_attack_range()
	var minimum_radius := (
		attack_range * FLYING_SWORD_MIN_RADIUS_RATIO
	)
	var maximum_radius := (
		attack_range * FLYING_SWORD_MAX_RADIUS_RATIO
	)
	var idle_radius := clampf(
		minimum_radius
			+ attack_range
				* FLYING_SWORD_RADIUS_RATIO_PER_EXTRA_SWORD
				* float(maxi(sword_count - 1, 0)),
		minimum_radius,
		maximum_radius
	)
	var radius := minf(
		idle_radius
			+ attack_range
				* FLYING_SWORD_WARNING_EXPANSION_RATIO
				* _flying_sword_warning_strength,
		maximum_radius
	)
	return (
		Vector2.from_angle(
			_get_flying_sword_slot_angle(sword_index, sword_count)
		)
		* radius
	)


func _get_nearest_flying_sword_target() -> EnemyController:
	var nearest_target: EnemyController
	var nearest_distance_squared := INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		if not enemy.is_combat_active():
			continue
		var distance_squared := get_combat_anchor_position().distance_squared_to(
			enemy.global_position
		)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_target = enemy
	return nearest_target


func _refill_flying_sword_visual_slots() -> void:
	for sword_index in _flying_sword_visual_filled.size():
		if _flying_sword_visual_filled[sword_index]:
			continue
		_flying_sword_visual_filled[sword_index] = true
		_flying_sword_visual_visibility[sword_index] = 0.0


func _consume_flying_sword_visual(
	projectile_index: int,
	projectile_count: int
) -> Vector2:
	if not _flying_sword_visual_equipped:
		return global_position
	_ensure_flying_sword_visual_count(projectile_count)
	if _flying_sword_visual_sprites.is_empty():
		return global_position
	var sword_index := (
		projectile_index % _flying_sword_visual_sprites.size()
	)
	var sword_sprite := _flying_sword_visual_sprites[sword_index]
	var launch_position := flying_sword_layer.to_global(
		sword_sprite.position
	)
	_flying_sword_visual_filled[sword_index] = false
	_flying_sword_visual_visibility[sword_index] = 0.0
	sword_sprite.hide()
	return launch_position


func _update_flying_sword_visuals(delta: float) -> void:
	if (
		not _flying_sword_visual_equipped
		or not _is_flying_sword_equipped()
	):
		return
	_ensure_flying_sword_visual_count(
		get_flying_sword_projectile_count()
	)
	if (
		not is_instance_valid(_flying_sword_aim_target)
		or not _flying_sword_aim_target.is_combat_active()
		or _flying_sword_aim_refresh_remaining <= 0.0
	):
		_flying_sword_aim_target = _get_nearest_flying_sword_target()
		_flying_sword_aim_refresh_remaining = (
			VISUAL_TARGET_REFRESH_INTERVAL
		)
	var nearest_distance := INF
	var aim_direction := Vector2.UP
	if is_instance_valid(_flying_sword_aim_target):
		nearest_distance = get_combat_anchor_position().distance_to(
			_flying_sword_aim_target.global_position
		)
	var attack_range := get_current_attack_range()
	var previous_warning_strength := _flying_sword_warning_strength
	if nearest_distance <= attack_range + FLYING_SWORD_WARNING_MARGIN:
		_flying_sword_warning_strength = 1.0 - clampf(
			(nearest_distance - attack_range)
				/ FLYING_SWORD_WARNING_MARGIN,
			0.0,
			1.0
		)
	else:
		_flying_sword_warning_strength = 0.0
	if _flying_sword_warning_strength > 0.0:
		if previous_warning_strength <= 0.0:
			_flying_sword_warning_pulse_elapsed = 0.0
		else:
			_flying_sword_warning_pulse_elapsed += delta
		aim_direction = get_combat_anchor_position().direction_to(
			_flying_sword_aim_target.global_position
		).normalized()
		_flying_sword_orbit_phase = fmod(
			_flying_sword_orbit_phase
				+ FLYING_SWORD_WARNING_ORBIT_SPEED
					* _flying_sword_warning_strength
					* delta,
			TAU
		)
	else:
		_flying_sword_warning_pulse_elapsed = 0.0
		_flying_sword_orbit_phase = lerp_angle(
			_flying_sword_orbit_phase,
			0.0,
			1.0 - exp(-4.0 * delta)
		)
	var pulse_wave := (
		0.5
		+ 0.5
			* cos(
				_flying_sword_warning_pulse_elapsed
					* TAU
					* flying_sword_warning_pulse_hz
			)
	)
	var pulse_multiplier := lerpf(
		1.0 - flying_sword_warning_pulse_depth,
		1.0,
		pulse_wave
	)
	_set_flying_sword_readiness(
		_flying_sword_warning_strength,
		_flying_sword_warning_strength * pulse_multiplier
	)
	if (
		_attack_cooldown_remaining <= 0.0
		and _pending_flying_swords <= 0
	):
		_refill_flying_sword_visual_slots()
	if _flying_sword_visual_summoning:
		_flying_sword_visual_elapsed += delta
	var sword_count := _flying_sword_visual_sprites.size()
	for sword_index in sword_count:
		var target_visibility := (
			1.0 if _flying_sword_visual_filled[sword_index] else 0.0
		)
		if (
			_flying_sword_visual_summoning
			and _flying_sword_visual_elapsed
				< _get_flying_sword_summon_delay(
					sword_index,
					sword_count
				)
		):
			target_visibility = 0.0
		var duration := (
			FLYING_SWORD_SUMMON_DURATION
			if _flying_sword_visual_summoning
			else FLYING_SWORD_REFILL_DURATION
		)
		_flying_sword_visual_visibility[sword_index] = move_toward(
			_flying_sword_visual_visibility[sword_index],
			target_visibility,
			delta / duration
		)
		var visibility := _flying_sword_visual_visibility[sword_index]
		var sword_sprite := _flying_sword_visual_sprites[sword_index]
		if visibility <= 0.0:
			sword_sprite.hide()
			continue
		sword_sprite.show()
		var slot_position := _get_flying_sword_slot_position(
			sword_index,
			sword_count
		)
		var spawn_position := (
			slot_position.normalized() * 12.0
			if not slot_position.is_zero_approx()
			else Vector2.UP * 12.0
		)
		var eased_visibility := (
			visibility * visibility * (3.0 - 2.0 * visibility)
		)
		sword_sprite.position = spawn_position.lerp(
			slot_position,
			eased_visibility
		)
		sword_sprite.rotation = _get_palm_rotation(aim_direction)
		var summon_scale := (
			lerpf(0.38, 1.0, visibility)
			+ sin(visibility * PI) * 0.16
		)
		sword_sprite.scale = (
			Vector2.ONE * FLYING_SWORD_SCALE * summon_scale
		)
		sword_sprite.modulate = Color(1.0, 1.0, 1.0, visibility)
	var final_summon_delay := _get_flying_sword_summon_delay(
		maxi(sword_count - 1, 0),
		sword_count
	)
	if (
		_flying_sword_visual_summoning
		and _flying_sword_visual_elapsed
			>= final_summon_delay + FLYING_SWORD_SUMMON_DURATION
	):
		_flying_sword_visual_summoning = false


func get_flying_sword_visual_filled_count() -> int:
	var filled_count := 0
	for is_filled in _flying_sword_visual_filled:
		if is_filled:
			filled_count += 1
	return filled_count


func get_flying_sword_warning_strength() -> float:
	return _flying_sword_warning_strength


func _is_fantian_seal_equipped() -> bool:
	return (
		not _equipment_inventory.is_empty()
		and _get_current_weapon_data().attack_kind
			== WeaponDataResource.AttackKind.FANTIAN_SEAL
	)


func _refresh_fantian_seal_visual_equipment() -> void:
	if not is_instance_valid(fantian_seal_weapon):
		return
	fantian_seal_weapon.texture = FANTIAN_SEAL_TEXTURE
	if not _is_fantian_seal_equipped():
		_fantian_seal_visual_equipped = false
		_fantian_seal_visual_state = FantianSealVisualState.HIDDEN
		_fantian_seal_switch_shadow_active = false
		fantian_seal_weapon.hide()
		return
	if _fantian_seal_visual_equipped:
		return
	_fantian_seal_visual_equipped = true
	_fantian_seal_visual_state = FantianSealVisualState.SUMMONING
	_fantian_seal_visual_elapsed = 0.0
	_fantian_seal_switch_shadow_active = false
	_fantian_seal_switch_shadow_elapsed = 0.0
	_fantian_seal_visual_start_position = Vector2(14.0, 2.0)
	fantian_seal_weapon.position = _fantian_seal_visual_start_position
	fantian_seal_weapon.rotation = 0.0
	fantian_seal_weapon.scale = (
		Vector2.ONE * FANTIAN_SEAL_IDLE_SCALE * 0.32
	)
	fantian_seal_weapon.modulate = Color(1.0, 1.0, 1.0, 0.0)
	fantian_seal_weapon.show()


func _update_fantian_seal_visual(delta: float) -> void:
	if (
		not _fantian_seal_visual_equipped
		or not _is_fantian_seal_equipped()
	):
		return
	_fantian_seal_visual_elapsed += delta
	match _fantian_seal_visual_state:
		FantianSealVisualState.SUMMONING:
			var progress := clampf(
				_fantian_seal_visual_elapsed
					/ FANTIAN_SEAL_SUMMON_DURATION,
				0.0,
				1.0
			)
			var eased := progress * progress * (3.0 - 2.0 * progress)
			fantian_seal_weapon.position = (
				_fantian_seal_visual_start_position.lerp(
					FANTIAN_SEAL_IDLE_POSITION,
					eased
				)
			)
			var summon_scale := (
				FANTIAN_SEAL_IDLE_SCALE
				* (lerpf(0.32, 1.0, eased) + sin(progress * PI) * 0.12)
			)
			fantian_seal_weapon.scale = Vector2.ONE * summon_scale
			fantian_seal_weapon.rotation = 0.0
			fantian_seal_weapon.modulate = Color(
				1.0,
				1.0,
				1.0,
				eased
			)
			if progress >= 1.0:
				_fantian_seal_visual_state = (
					FantianSealVisualState.ASCENDING
				)
				_fantian_seal_visual_elapsed = 0.0
				_fantian_seal_visual_start_position = (
					fantian_seal_weapon.position
				)
		FantianSealVisualState.ASCENDING:
			var progress := clampf(
				_fantian_seal_visual_elapsed
					/ FANTIAN_SEAL_ASCENT_DURATION,
				0.0,
				1.0
			)
			var ascent_eased := progress * progress
			var ascent_target := Vector2(
				FANTIAN_SEAL_IDLE_POSITION.x,
				-_get_visible_world_size().y * 0.78
			)
			fantian_seal_weapon.position = (
				_fantian_seal_visual_start_position.lerp(
					ascent_target,
					ascent_eased
				)
			)
			fantian_seal_weapon.scale = Vector2.ONE * lerpf(
				FANTIAN_SEAL_IDLE_SCALE,
				(
					FANTIAN_SEAL_IDLE_SCALE
					* FANTIAN_SEAL_ASCENT_SCALE_MULTIPLIER
				),
				ascent_eased
			)
			fantian_seal_weapon.rotation = 0.0
			fantian_seal_weapon.modulate = Color(
				1.0,
				1.0,
				1.0,
				1.0 - smoothstep(0.68, 1.0, progress)
			)
			if progress >= 1.0:
				_fantian_seal_visual_state = (
					FantianSealVisualState.SHADOW_DELAY
				)
				_fantian_seal_visual_elapsed = 0.0
				fantian_seal_weapon.hide()
		FantianSealVisualState.SHADOW_DELAY:
			fantian_seal_weapon.hide()
			if (
				_fantian_seal_visual_elapsed
				>= FANTIAN_SEAL_SWITCH_SHADOW_DELAY
			):
				_fantian_seal_visual_state = (
					FantianSealVisualState.SHADOW_SHRINK
				)
				_fantian_seal_visual_elapsed = 0.0
				_fantian_seal_switch_shadow_elapsed = 0.0
				_fantian_seal_switch_shadow_active = true
				queue_redraw()
		FantianSealVisualState.SHADOW_SHRINK:
			fantian_seal_weapon.hide()
			_fantian_seal_switch_shadow_elapsed = (
				_fantian_seal_visual_elapsed
			)
			if (
				_fantian_seal_visual_elapsed
				>= FANTIAN_SEAL_SWITCH_SHADOW_DURATION
			):
				_fantian_seal_visual_state = (
					FantianSealVisualState.ABSENT
				)
				_fantian_seal_switch_shadow_active = false
				queue_redraw()
		FantianSealVisualState.ABSENT:
			fantian_seal_weapon.hide()


func get_fantian_seal_visual_state() -> int:
	return _fantian_seal_visual_state


func is_fantian_seal_switch_shadow_active() -> bool:
	return _fantian_seal_switch_shadow_active


func _update_character_animation() -> void:
	if is_rolling():
		if (
			character_sprite.sprite_frames != null
			and character_sprite.sprite_frames.has_animation(roll_animation)
		):
			if character_sprite.animation != roll_animation:
				character_sprite.play(roll_animation)
			elif not character_sprite.is_playing():
				character_sprite.play()
			character_sprite.speed_scale = 1.0
		return
	var animation_speed := clampf(
		current_forward_speed / maxf(base_forward_speed, 1.0),
		minimum_animation_speed_scale,
		maximum_animation_speed_scale
	)
	var is_airborne := (
		realm_abilities.get_current_flight_elevation()
		> maxf(airborne_animation_threshold, 0.0)
	)
	var realm_airborne_animation := _get_realm_airborne_animation()
	var grounded_target := grounded_animation
	if (
		_cultivation_resources == null
		or _cultivation_resources.get_current_realm_index() == 0
	):
		grounded_target = qi_refining_grounded_animation
	var target_animation := (
		realm_airborne_animation if is_airborne else grounded_target
	)
	if (
		character_sprite.sprite_frames != null
		and character_sprite.sprite_frames.has_animation(target_animation)
	):
		if character_sprite.animation != target_animation:
			character_sprite.play(target_animation)
		elif not character_sprite.is_playing():
			character_sprite.play()
	character_sprite.speed_scale = animation_speed
	if (
		spirit_sprite.sprite_frames != null
		and spirit_sprite.sprite_frames.has_animation(
			realm_airborne_animation
		)
	):
		if spirit_sprite.animation != realm_airborne_animation:
			spirit_sprite.play(realm_airborne_animation)
		elif not spirit_sprite.is_playing():
			spirit_sprite.play()
		spirit_sprite.speed_scale = animation_speed


func _get_realm_airborne_animation() -> StringName:
	var realm_index := _get_current_realm_index()
	if realm_index >= 3:
		return nascent_soul_airborne_animation
	if realm_index == 2:
		return golden_core_airborne_animation
	return airborne_animation


func _get_visible_world_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var active_camera := get_viewport().get_camera_2d()
	if not is_instance_valid(active_camera):
		return viewport_size
	return Vector2(
		viewport_size.x / maxf(absf(active_camera.zoom.x), 0.01),
		viewport_size.y / maxf(absf(active_camera.zoom.y), 0.01)
	)


func _update_palm_aim() -> void:
	if (
		_equipment_inventory.is_empty()
		or _get_current_weapon_data().attack_kind
			!= WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM
	):
		return
	if (
		is_instance_valid(_palm_aim_target)
		and _palm_aim_target.is_combat_active()
		and _palm_aim_refresh_remaining > 0.0
	):
		return
	_palm_aim_refresh_remaining = VISUAL_TARGET_REFRESH_INTERVAL
	var nearest_target: EnemyController = null
	var nearest_distance_squared := INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		if not enemy.is_combat_active():
			continue
		var distance_squared := get_combat_anchor_position().distance_squared_to(
			enemy.global_position
		)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_target = enemy
	_palm_aim_target = nearest_target
	if is_instance_valid(nearest_target):
		_palm_attack_direction = get_combat_anchor_position().direction_to(
			nearest_target.global_position
		).normalized()


## Returns the live Great Strength Palm aim used by range presentation and
## debug panels, including while the weapon is not currently attacking.
func get_palm_attack_direction() -> Vector2:
	return _palm_attack_direction


func _update_damage_feedback_presentation() -> void:
	if _damage_flash_remaining <= 0.0:
		character_sprite.position = _character_sprite_rest_position
		character_sprite.modulate = _character_sprite_rest_modulate
		damage_taken_label.hide()
		return
	var duration := maxf(damage_feedback_duration, 0.01)
	var progress := 1.0 - clampf(
		_damage_flash_remaining / duration,
		0.0,
		1.0
	)
	var shake_strength := (1.0 - progress) * 6.0
	character_sprite.position = (
		_character_sprite_rest_position
		+ Vector2(
			sin(progress * TAU * 7.0),
			cos(progress * TAU * 5.0)
		) * shake_strength
	)
	var blink_on := int(progress * 12.0) % 2 == 0
	character_sprite.modulate = (
		Color(1.0, 0.18, 0.16, 1.0)
		if blink_on
		else Color(1.0, 0.92, 0.72, 1.0)
	)
	damage_taken_label.position = Vector2(-52.0, lerpf(-70.0, -102.0, progress))
	damage_taken_label.modulate = Color(
		1.0,
		lerpf(0.78, 0.22, progress),
		0.18,
		1.0 - pow(progress, 2.0)
	)


func _draw_damage_feedback() -> void:
	var duration := maxf(damage_feedback_duration, 0.01)
	var progress := 1.0 - clampf(
		_damage_flash_remaining / duration,
		0.0,
		1.0
	)
	var alpha := 1.0 - progress
	if _damage_feedback_is_projectile:
		_draw_projectile_damage_feedback(progress, alpha)
		return
	var burst_radius := lerpf(26.0, damage_feedback_radius, progress)
	draw_circle(
		Vector2.ZERO,
		burst_radius * 0.82,
		Color(1.0, 0.03, 0.02, alpha * 0.2)
	)
	draw_arc(
		Vector2.ZERO,
		burst_radius,
		0.0,
		TAU,
		56,
		Color(1.0, 0.18, 0.08, alpha * 0.95),
		lerpf(8.0, 3.0, progress),
		true
	)
	draw_arc(
		Vector2.ZERO,
		burst_radius * 0.64,
		-progress * TAU,
		TAU - progress * TAU,
		40,
		Color(1.0, 0.9, 0.62, alpha * 0.9),
		3.0,
		true
	)
	for ray_index in 8:
		var ray_angle := float(ray_index) / 8.0 * TAU + progress * 0.5
		var ray_direction := Vector2.from_angle(ray_angle)
		draw_line(
			ray_direction * (burst_radius * 0.78),
			ray_direction * (burst_radius + 12.0 + _last_damage_amount * 0.4),
			Color(1.0, 0.34, 0.12, alpha * 0.9),
			3.0
		)


func _draw_projectile_damage_feedback(
	progress: float,
	alpha: float
) -> void:
	var half_length := lerpf(16.0, 38.0, progress)
	var diagonal_a := Vector2(1.0, 1.0).normalized() * half_length
	var diagonal_b := Vector2(1.0, -1.0).normalized() * half_length
	var red := Color(1.0, 0.04, 0.08, alpha * 0.94)
	var white := Color(1.0, 0.88, 0.94, alpha)
	draw_line(-diagonal_a, diagonal_a, red, 9.0, true)
	draw_line(-diagonal_b, diagonal_b, red, 9.0, true)
	draw_line(-diagonal_a, diagonal_a, white, 2.5, true)
	draw_line(-diagonal_b, diagonal_b, white, 2.5, true)


func _draw_level_up_effect() -> void:
	var duration := maxf(level_up_effect_duration, 0.01)
	var progress := 1.0 - _level_up_effect_remaining / duration
	var effect_radius := lerpf(28.0, level_up_effect_radius, progress)
	var alpha := 1.0 - progress
	draw_circle(
		Vector2.ZERO,
		effect_radius * 0.72,
		Color(0.35, 0.95, 1.0, alpha * 0.11)
	)
	draw_arc(
		Vector2.ZERO,
		effect_radius,
		0.0,
		TAU,
		64,
		Color(0.55, 0.96, 1.0, alpha),
		4.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		effect_radius * 0.62,
		-progress * TAU,
		TAU - progress * TAU,
		48,
		Color(1.0, 0.88, 0.38, alpha * 0.9),
		3.0,
		true
	)
	for ray_index in 8:
		var ray_angle := float(ray_index) / 8.0 * TAU + progress
		var ray_direction := Vector2.from_angle(ray_angle)
		draw_line(
			ray_direction * (effect_radius * 0.72),
			ray_direction * (effect_radius + 12.0),
			Color(0.75, 1.0, 1.0, alpha * 0.8),
			2.0
		)


func _draw_breakthrough_effect() -> void:
	var duration := maxf(breakthrough_effect_duration, 0.01)
	var progress := clampf(
		1.0 - _breakthrough_effect_remaining / duration,
		0.0,
		1.0
	)
	var fade := minf(
		clampf(progress / 0.1, 0.0, 1.0),
		clampf((1.0 - progress) / 0.2, 0.0, 1.0)
	)
	var beam_height := breakthrough_effect_radius * 2.25
	var beam_bottom := breakthrough_effect_radius * 0.42
	var pulse := 0.96 + sin(progress * TAU * 2.0) * 0.04
	var outer_width := 58.0 * pulse
	_draw_fading_pillar_layer(
		outer_width,
		beam_height,
		beam_bottom,
		Color(1.0, 0.72, 0.08, fade * 0.16)
	)
	_draw_fading_pillar_layer(
		36.0 * pulse,
		beam_height,
		beam_bottom,
		Color(1.0, 0.88, 0.28, fade * 0.34)
	)
	_draw_fading_pillar_layer(
		14.0 * pulse,
		beam_height,
		beam_bottom,
		Color(1.0, 0.98, 0.72, fade * 0.62)
	)


func _draw_fading_pillar_layer(
	width: float,
	height: float,
	bottom: float,
	color: Color
) -> void:
	var safe_width := maxf(width, 1.0)
	var safe_height := maxf(height, 1.0)
	var cap_radius := safe_width * 0.5
	var cap_center_y := bottom - cap_radius
	var fade_height := safe_height * 0.44
	var fade_bottom := -safe_height + fade_height
	const FADE_STEP_COUNT: int = 48
	for step_index in FADE_STEP_COUNT:
		var step_start := float(step_index) / float(FADE_STEP_COUNT)
		var step_end := float(step_index + 1) / float(FADE_STEP_COUNT)
		var step_alpha := step_end * step_end
		var strip_top := lerpf(-safe_height, fade_bottom, step_start)
		var strip_bottom := lerpf(-safe_height, fade_bottom, step_end)
		draw_rect(
			Rect2(
				Vector2(-safe_width * 0.5, strip_top),
				Vector2(safe_width, strip_bottom - strip_top + 0.5)
			),
			Color(color, color.a * step_alpha)
		)
	draw_rect(
		Rect2(
			Vector2(-safe_width * 0.5, fade_bottom),
			Vector2(safe_width, cap_center_y - fade_bottom)
		),
		color
	)
	var cap_points := PackedVector2Array()
	cap_points.append(Vector2(-cap_radius, cap_center_y))
	cap_points.append(Vector2(cap_radius, cap_center_y))
	const CAP_SEGMENT_COUNT: int = 24
	for segment_index in CAP_SEGMENT_COUNT + 1:
		var angle := (
			float(segment_index) / float(CAP_SEGMENT_COUNT) * PI
		)
		cap_points.append(
			Vector2(
				cos(angle) * cap_radius,
				cap_center_y + sin(angle) * cap_radius
			)
		)
	draw_colored_polygon(cap_points, color)


func _publish_lifespan_decay_multiplier() -> void:
	var multiplier := get_lifespan_decay_multiplier()
	if absf(multiplier - _last_lifespan_decay_multiplier) < 0.002:
		return
	_last_lifespan_decay_multiplier = multiplier
	lifespan_decay_multiplier_changed.emit(multiplier)


func _draw_flying_sword_reload() -> void:
	if not _is_flying_sword_equipped() or not _flying_sword_reload_active:
		return
	var sword_count := maxi(get_flying_sword_projectile_count(), 1)
	var orbit_radius := maxf(
		_get_flying_sword_slot_position(0, sword_count).length(),
		24.0
	)
	var progress := get_flying_sword_reload_progress()
	var ring_color := flying_sword_reload_ring_color
	draw_arc(
		Vector2.ZERO,
		orbit_radius,
		0.0,
		TAU,
		64,
		Color(ring_color, ring_color.a * 0.16),
		maxf(flying_sword_reload_ring_width * 0.65, 0.5),
		true
	)
	if progress <= 0.001:
		return
	var start_angle := -PI * 0.5
	var end_angle := start_angle + TAU * progress
	draw_arc(
		Vector2.ZERO,
		orbit_radius,
		start_angle,
		end_angle,
		maxi(ceili(64.0 * progress), 2),
		ring_color,
		maxf(flying_sword_reload_ring_width, 0.5),
		true
	)
	draw_circle(
		Vector2.from_angle(end_angle) * orbit_radius,
		maxf(flying_sword_reload_ring_width * 1.15, 1.0),
		Color(ring_color, minf(ring_color.a + 0.22, 1.0))
	)


func _draw_weapon_companions() -> void:
	var attack_kind := _get_current_weapon_data().attack_kind
	if (
		attack_kind == WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM
		or attack_kind == WeaponDataResource.AttackKind.GOLDEN_BELL
		or attack_kind == WeaponDataResource.AttackKind.DAO
		or attack_kind == WeaponDataResource.AttackKind.FLYING_SWORD
		or attack_kind == WeaponDataResource.AttackKind.THUNDER_HAMMER
		or attack_kind == WeaponDataResource.AttackKind.FANTIAN_SEAL
	):
		return
	if (
		attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING
		and is_qiankun_ring_in_flight()
	):
		return
	var angle := _companion_phase
	var ring_position := Vector2.from_angle(angle) * 40.0
	draw_circle(
		ring_position,
		15.0,
		Color(1.0, 0.35, 0.82, 0.16)
	)
	_draw_qiankun_ring(ring_position)


func _draw_qiankun_ring(position: Vector2) -> void:
	var texture_size := QIANKUN_RING_TEXTURE.get_size()
	draw_set_transform(
		position,
		_companion_phase * 2.2,
		Vector2.ONE * QIANKUN_RING_SCALE
	)
	draw_texture(QIANKUN_RING_TEXTURE, -texture_size * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _create_equipment(
	weapon_data: WeaponDataResource,
	damage: int
) -> Dictionary:
	return {
		"data": weapon_data,
		"damage": damage,
		"quantity": 1,
	}


func _find_equipment_index(equipment_id: StringName) -> int:
	for index in _equipment_inventory.size():
		var weapon_data := (
			_equipment_inventory[index]["data"] as WeaponDataResource
		)
		if weapon_data.weapon_id == equipment_id:
			return index
	return -1


func _get_direct_weapon_slot(event: InputEventKey) -> int:
	var key_values: Array[int] = [
		int(event.physical_keycode),
		int(event.keycode),
		event.unicode,
	]
	for key_value in key_values:
		if key_value >= 49 and key_value <= 54:
			return key_value - 49
	return -1


func _is_starting_weapon_key(event: InputEventKey) -> bool:
	return (
		event.physical_keycode == KEY_Q
		or event.keycode == KEY_Q
		or event.unicode == 113
		or event.unicode == 81
	)


func _get_current_equipment() -> Dictionary:
	return _equipment_inventory[_current_equipment_index]


func _get_current_weapon_data() -> WeaponDataResource:
	return _get_current_equipment()["data"] as WeaponDataResource


func _get_equipment_damage(equipment: Dictionary) -> int:
	return _resolve_equipment_combat_stats(equipment).resolved_damage


func _get_equipment_base_damage(equipment: Dictionary) -> int:
	var weapon_data := equipment["data"] as WeaponDataResource
	if weapon_data.attack_kind == WeaponDataResource.AttackKind.QIANKUN_RING:
		return int(equipment["damage"])
	return int(equipment["damage"]) + _weapon_power_level


func _resolve_equipment_combat_stats(
	equipment: Dictionary
) -> WeaponCombatStatsResource:
	var weapon_data := equipment["data"] as WeaponDataResource
	var snapshot := CombatStatsResolverResource.resolve_weapon(
		weapon_data,
		_get_equipment_base_damage(equipment),
		_cultivation_resources,
		_global_combat_stats
	)
	var weapon_level := maxi(int(equipment.get("quantity", 1)), 1)
	var range_level_cap := maxi(weapon_data.attack_range_level_cap, 1)
	var range_growth_levels := mini(weapon_level, range_level_cap) - 1
	snapshot.attack_range += (
		float(range_growth_levels)
		* maxf(weapon_data.attack_range_increase_per_level, 0.0)
	)
	var excess_damage_levels := maxi(weapon_level - range_level_cap, 0)
	if excess_damage_levels > 0:
		var post_cap_damage_multiplier := (
			1.0
			+ float(excess_damage_levels)
				* maxf(
					weapon_data.damage_ratio_per_level_above_range_cap,
					0.0
				)
		)
		if (
			weapon_data.attack_kind
			== WeaponDataResource.AttackKind.THUNDER_HAMMER
		):
			snapshot.resolved_damage_exact = maxf(
				snapshot.resolved_damage_exact * post_cap_damage_multiplier,
				1.0
			)
			snapshot.resolved_damage = maxi(
				roundi(snapshot.resolved_damage_exact),
				1
			)
		else:
			snapshot.resolved_damage = maxi(
				roundi(
					float(snapshot.resolved_damage)
						* post_cap_damage_multiplier
				),
				1
			)
			snapshot.resolved_damage_exact = float(snapshot.resolved_damage)
	return snapshot


func _rebuild_combat_stats() -> void:
	_global_combat_stats = CombatStatsResolverResource.resolve_global(
		_cultivation_resources,
		combat_config
	)
	if _equipment_inventory.is_empty():
		_current_weapon_combat_stats = WeaponCombatStatsResource.new()
	else:
		var equipment := _get_current_equipment()
		_current_weapon_combat_stats = _resolve_equipment_combat_stats(equipment)
		var weapon_data := equipment["data"] as WeaponDataResource
		var delivery_count := maxi(
			weapon_data.base_delivery_count
				+ int(equipment.get("quantity", 1))
				- 1,
			1
		)
		delivery_count = mini(
			delivery_count,
			maxi(weapon_data.delivery_count_cap, 1)
		)
		_current_weapon_combat_stats.delivery_count = delivery_count
		var attack_speed_level := _universal_upgrade_levels[
			UniversalUpgradeTypes.UpgradeType.ATTACK_SPEED
		]
		var range_level := _universal_upgrade_levels[
			UniversalUpgradeTypes.UpgradeType.DAMAGE_RANGE
		]
		_current_weapon_combat_stats.attack_interval = maxf(
			_current_weapon_combat_stats.attack_interval
				/ (
					1.0
					+ float(attack_speed_level)
						* maxf(attack_speed_bonus_per_fragment, 0.0)
				),
			_global_combat_stats.minimum_attack_interval
		)
		var range_multiplier := (
			1.0
			+ float(range_level) * maxf(range_bonus_per_fragment, 0.0)
		)
		_current_weapon_combat_stats.attack_range *= range_multiplier
		_current_weapon_combat_stats.secondary_targeting_range *= range_multiplier
		if weapon_data.bonuses_scale_aoe_radius:
			_current_weapon_combat_stats.aoe_radius *= range_multiplier
		if (
			(equipment["data"] as WeaponDataResource).attack_kind
			== WeaponDataResource.AttackKind.GREAT_STRENGTH_PALM
		):
			var completed_small_levels := maxi(current_cultivation_level - 1, 0)
			_current_weapon_combat_stats.resolved_damage += roundi(
				float(completed_small_levels) * palm_damage_per_level
			)
			_current_weapon_combat_stats.resolved_damage_exact = float(
				_current_weapon_combat_stats.resolved_damage
			)
			_current_weapon_combat_stats.attack_range *= (
				1.0
				+ float(completed_small_levels)
					* palm_range_ratio_per_level
			)
			_current_weapon_combat_stats.attack_interval = maxf(
				_current_weapon_combat_stats.attack_interval
					/ (
						1.0
						+ float(completed_small_levels)
							* palm_speed_ratio_per_level
					),
				_global_combat_stats.minimum_attack_interval
			)
	if golden_bell != null:
		var golden_bell_equipped := (
			not _equipment_inventory.is_empty()
			and _get_current_weapon_data().attack_kind
				== WeaponDataResource.AttackKind.GOLDEN_BELL
		)
		golden_bell.configure_weapon(
			golden_bell_equipped,
			(
				get_current_delivery_count()
				if golden_bell_equipped
				else 0
			),
			(
				get_current_weapon_damage()
				if golden_bell_equipped
				else 1
			)
		)
	combat_stats_changed.emit(
		_global_combat_stats,
		_current_weapon_combat_stats
	)


func _roll_current_attack_damage() -> AttackDamageResultResource:
	var outgoing_multiplier := realm_abilities.get_outgoing_damage_multiplier()
	var damage := maxi(
		roundi(
			float(_current_weapon_combat_stats.resolved_damage)
				* outgoing_multiplier
		),
		1
	)
	var uses_exact_repeated_damage := (
		_get_current_weapon_data().attack_kind
		== WeaponDataResource.AttackKind.THUNDER_HAMMER
	)
	var exact_damage := (
		maxf(
			_current_weapon_combat_stats.resolved_damage_exact
				* outgoing_multiplier,
			1.0
		)
		if uses_exact_repeated_damage
		else float(damage)
	)
	var is_critical := (
		randf() < _current_weapon_combat_stats.critical_chance
	)
	if is_critical:
		var critical_multiplier := maxf(
			_current_weapon_combat_stats.critical_damage_multiplier,
			1.0
		)
		damage = maxi(roundi(float(damage) * critical_multiplier), 1)
		exact_damage = (
			exact_damage * critical_multiplier
			if uses_exact_repeated_damage
			else float(damage)
		)
	if uses_exact_repeated_damage:
		damage = maxi(roundi(exact_damage), 1)
	return AttackDamageResultResource.new(damage, is_critical, exact_damage)


func _on_cultivation_stats_changed(
	_cultivation_type: int,
	_level: int
) -> void:
	if not is_node_ready() or _equipment_inventory.is_empty():
		return
	_rebuild_combat_stats()
	_apply_attack_range()
	_level_up_effect_remaining = maxf(level_up_effect_duration, 0.01)
	_publish_equipment()
	queue_redraw()


func _on_realm_ability_state_changed(snapshot: Dictionary) -> void:
	if not is_node_ready():
		return
	_character_sprite_rest_position.y = -float(
		snapshot.get("current_flight_elevation", 0.0)
	)
	if _equipment_inventory.is_empty():
		realm_ability_state_changed.emit(snapshot)
		return
	if not realm_abilities.is_weapon_allowed(_get_current_weapon_data()):
		_current_equipment_index = _find_first_allowed_equipment_index()
	_rebuild_combat_stats()
	_apply_attack_range()
	_publish_equipment()
	realm_ability_state_changed.emit(snapshot)
	queue_redraw()


func _on_flight_elevation_changed(elevation: float) -> void:
	_character_sprite_rest_position.y = -maxf(elevation, 0.0)
	var anchor_position := Vector2(
		0.0,
		_character_sprite_rest_position.y
	)
	combat_anchor.position = anchor_position
	body_shape.position = anchor_position
	golden_bell.position = anchor_position


func _find_first_allowed_equipment_index() -> int:
	for index in _equipment_inventory.size():
		var weapon_data := (
			_equipment_inventory[index]["data"] as WeaponDataResource
		)
		if realm_abilities.is_weapon_allowed(weapon_data):
			return index
	return 0


func _on_qi_shield_absorbed(
	blocked_damage: float,
	qi_spent: int,
	remaining_damage: float
) -> void:
	_shield_flash_remaining = 0.28
	_last_shield_blocked_damage = blocked_damage
	_last_shield_qi_spent = qi_spent
	queue_redraw()
	qi_shield_absorbed.emit(blocked_damage, qi_spent, remaining_damage)


func _on_spirit_projection_changed(active: bool) -> void:
	_character_sprite_rest_modulate = (
		Color(0.72, 0.9, 1.0, 0.72)
		if active
		else Color.WHITE
	)
	if is_node_ready() and not _equipment_inventory.is_empty():
		_publish_equipment()
	spirit_projection_changed.emit(active)


func get_debug_snapshot() -> Dictionary:
	return {
		"position": global_position,
		"forward_speed": current_forward_speed,
		"distance_traveled": distance_traveled,
		"current_weapon": _get_current_weapon_data().weapon_id,
		"current_weapon_quantity": get_current_delivery_count(),
		"current_damage": get_current_weapon_damage(),
		"weapon_power_level": _weapon_power_level,
		"universal_upgrades": get_universal_upgrade_snapshot(),
		"attack_interval": get_current_attack_interval(),
		"attack_range": get_current_attack_range(),
		"aoe_radius": get_current_aoe_radius(),
		"lateral_speed": get_effective_lateral_speed(),
		"forward_acceleration": get_effective_forward_acceleration(),
		"boosted_speed_target": get_boosted_speed_target(),
		"slowed_speed_target": get_slowed_speed_target(),
		"rolling": is_rolling(),
		"roll_cooldown": get_roll_cooldown_remaining(),
		"realm_abilities": realm_abilities.get_debug_snapshot(),
	}


func _on_current_equipment_changed() -> void:
	_cancel_flying_sword_sequence()
	_cancel_palm_cast()
	_cancel_qiankun_ring_sequence()
	_cancel_special_projectile_sequence()
	_rebuild_combat_stats()
	_apply_attack_range()
	_refresh_palm_visual_equipment()
	_refresh_flying_sword_visual_equipment()
	_refresh_fantian_seal_visual_equipment()
	_refresh_dao_visual_equipment()
	_refresh_thunder_hammer_visual_equipment()
	_publish_equipment()
	queue_redraw()


func _publish_equipment() -> void:
	var weapon_data := _get_current_weapon_data()
	equipment_changed.emit(
		get_technique_name(),
		weapon_data.display_name,
		get_current_weapon_damage()
	)
	equipment_inventory_changed.emit(
		get_equipment_inventory_entries(),
		_current_equipment_index
	)


func _apply_attack_range() -> void:
	var next_shape: Shape2D
	if (
		not _equipment_inventory.is_empty()
		and _get_current_weapon_data().attack_kind
			== WeaponDataResource.AttackKind.FANTIAN_SEAL
	):
		var square := RectangleShape2D.new()
		square.size = Vector2.ONE * get_current_attack_range() * 2.0
		next_shape = square
	else:
		var circle := CircleShape2D.new()
		circle.radius = get_current_attack_range()
		next_shape = circle
	if Engine.is_in_physics_frame():
		attack_shape.set_deferred(&"shape", next_shape)
	else:
		attack_shape.shape = next_shape


func _apply_attraction_range() -> void:
	if attraction_shape.shape is CircleShape2D:
		(attraction_shape.shape as CircleShape2D).radius = current_attraction_range


func _get_current_range_color() -> Color:
	return _get_current_weapon_data().display_color


func _get_target_forward_speed() -> float:
	var speeding_up := Input.is_action_pressed("speed_up")
	var slowing_down := Input.is_action_pressed("slow_down")
	if speeding_up == slowing_down:
		return maxf(base_forward_speed, 1.0)
	if speeding_up:
		return get_boosted_speed_target()
	return get_slowed_speed_target()


func _get_effective_forward_acceleration() -> float:
	return (
		forward_acceleration
		+ float(
			_universal_upgrade_levels[
				UniversalUpgradeTypes.UpgradeType.MOVEMENT
			]
		) * forward_acceleration_per_fragment
		+ float(
			_universal_upgrade_levels[
				UniversalUpgradeTypes.UpgradeType.SPEED_CONTROL
			]
		) * forward_acceleration_per_fragment
	)
