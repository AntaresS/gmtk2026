DO NOT update this file automatically unless the user REQUIRES an update!

# Count Down game guidance

This directory contains the playable Godot 4.7 foundation for a top-down,
forward-scrolling game. Forward is always negative world Y. Keep changes
focused on the requested system and do not add unrelated gameplay features.

# IMPORTANT CONTEXT

- 精气神 fragment and its related system is no longer in active use. Do not touch it or involve them in
the current dev. 

## Current structure

```text
game/
  AGENTS.md
  README.md
  resources/
    default_world_chunk_config.tres
    dao.tres
    flying_sword.tres
    great_strength_palm.tres
    qi_profile.tres
    qiankun_ring.tres
    summer_terrain_tileset.tres
  scenes/
    gameplay/
      enemy.tscn
      flying_sword_projectile.tscn
      game.tscn
      gameplay_hud.tscn
      heavenly_tribulation.tscn
      player.tscn
      qi_pickup.tscn
      qiankun_ring_projectile.tscn
      technique_fragment.tscn
      weapon_power_fragment.tscn
      road_fork.tscn
      run_ended_overlay.tscn
      weapon_pickup.tscn
      world_chunk.tscn
      world_chunk_preview.tscn
    menus/
      main_menu.tscn
      pause_menu.tscn
  scripts/
    gameplay/
      enemy.gd
      enemy_spawner.gd
      flying_sword_projectile.gd
      game.gd
      gameplay_hud.gd
      heavenly_tribulation.gd
      infinite_world.gd
      player.gd
      qi_density_profile.gd
      qi_pickup.gd
      qiankun_ring_projectile.gd
      realm_progress_bar.gd
      technique_fragment.gd
      weapon_power_fragment.gd
      road_fork.gd
      road_fork_spawner.gd
      run_ended_overlay.gd
      run_resources.gd
      weapon_pickup.gd
      weapon_data.gd
      world_chunk.gd
      world_chunk_config.gd
      world_chunk_preview.gd
    menus/
      main_menu.gd
      pause_menu.gd
  tests/
    foundation_smoke.gd
    gameplay_loop_smoke.gd
```

Godot-generated `.uid` companions live beside scripts. Do not edit them
manually.

## Ownership and runtime flow

- `main_menu.tscn` is the application entry point and replaces itself with
  `game.tscn` when play starts.
- `game.tscn` owns the player, vertically tracking camera, infinite-world
  controller, run resources, HUD, pause menu, run-ended flow, and optional
  debug overlay.
- `run_resources.gd` owns lifespan, qi, cultivation level, level-up recovery,
  lifespan damage routed from enemy attacks, realm-breakthrough interval and
  cap, completed-breakthrough count, and each post-tribulation lifespan
  doubling. `game.gd` only orchestrates the active tribulation scene;
  `gameplay_hud.tscn` only presents resource signals.
- `player.tscn` is a reusable `CharacterBody2D`. `player.gd` owns movement,
  speed modes, accumulated distance, lateral clamping, incoming melee damage
  signals, the best collected copy of each equipment type, direct number-key
  equipment selection,
  automatic equipment-specific attacks, per-run rolled damage, one visible
  current-attack circle, and a separate invisible collectible-attraction
  circle. Shared `WeaponData` resources provide identity, base combat tuning,
  technique scaling, and projectile scenes. Cultivation expands only
  attraction; elite technique fragments independently upgrade every weapon
  according to its distinct mechanic. Its `CharacterSprite` plays the nine PNG
  frames converted from the root `chara_fly.gif`, and cultivation increases
  trigger a short expanding aura.
- `EnemySpawner` creates bounded enemies beyond both camera edges, injects the
  player reference, owns progressive enemy qi drops and the designer-managed
  pool of droppable `WeaponData`, routes dropped qi upward, and freezes all
  enemies when the run ends. Each enemy snapshots its difficulty-, elite-,
  Trial Hell-, and rear-adjusted qi reward when spawned. It selects weapon
  definitions evenly and asks the selected resource to roll its configured
  damage. Forward enemies are slower than the player; periodic rear pursuers
  are slightly faster. Route migration removes enemies left on roads outside
  the player's newly active route.
  Unpaused elapsed time and current cultivation level jointly scale new enemy
  health, count, damage, attack frequency, and spawn frequency. Eight percent
  of new enemies become gold-labeled elites with triple health, 1.6-times
  melee range, and a larger body. Every defeated elite drops one technique
  fragment and one weapon-power fragment.
- `enemy.tscn` moves straight forward at one assigned constant speed. It never
  accelerates or steers toward the player, attacks only at close range, routes
  lifespan damage through the player signal, owns its health, and publishes
  its death position and velocity for drop generation.
- `InfiniteWorld` owns a fixed pool of `WorldChunk` instances. It recycles
  chunks by player world distance and must not instantiate or free chunks
  during ordinary movement.
- Each pooled `WorldChunk` tests one bounded, deterministic set of scattered
  and grouped candidate positions. The single `qi_profile.tres` uses a
  percentage chance to keep actual pickup generation sparse.
- Qi pickups are collected immediately when the player's body touches them and
  emit completion upward through the chunk and world. They carry a small
  description label and can be pulled by the player's shared range.
- `weapon_pickup.tscn` presents any assigned `WeaponData` enemy drop. A weapon
  keeps the defeated enemy's velocity until attracted, then passes its shared
  definition and per-drop rolled damage to the player on contact. Weaker
  same-ID copies are discarded. Only the currently equipped collected weapon
  is drawn beside the player.
- `technique_fragment.tscn` has no collision collection path. It draws an
  obvious recognition circle and resets its progress whenever the player
  leaves; remaining inside continuously for 1.5 seconds absorbs it and
  advances the shared weapon-upgrade level.
- `weapon_power_fragment.tscn` uses the same continuous 1.5-second recognition
  contract with a distinct orange-red presentation. Each absorbed fragment
  permanently adds one flat base-damage point to every existing and future
  weapon, including Great Strength Palm.
- Dao attacks rapidly orbit the player. The original inner path remains fixed
  and every technique fragment adds one new, persistent concentric outer path
  while expanding total damage range. Flying swords use
  `flying_sword_projectile.tscn` for straight sword-light streaks; each level
  of fragment strengthening adds one sequential projectile and slightly
  expands their range. Their 0.9-second volley interval is deliberately longer
  than dao attacks. Idle companion rendering always shows only one copy of the
  equipped weapon.
- Universe Rings use `qiankun_ring_projectile.tscn` to home into one enemy,
  gain one additional enemy-to-enemy bounce per absorbed technique fragment,
  and return to the moving player. Consecutive hits cannot target the same
  enemy, but earlier targets become eligible again so a ring can alternate
  A-B-A-B. Every completed bounce compounds the next hit by 20 percent. The
  idle companion is hidden while its ring projectile is away.
- `great_strength_palm.tres`, `dao.tres`, `flying_sword.tres`, and
  `qiankun_ring.tres` are the designer-facing sources of truth for weapon
  identity, damage bounds, attack range and interval, technique scaling, and
  projectile references. Treat these shared definitions as immutable at
  runtime; rolled damage, collection state, and upgrade levels belong to the
  player.
- `heavenly_tribulation.tscn` runs at nine realm milestones: cultivation levels
  10, 19, 28, 37, 46, 55, 64, 73, and 82. Sequences never overlap; milestones
  crossed during an active sequence are handled afterward. Each sequence warns
  nine predicted, slightly randomized ground positions before applying
  lightning damage. Surviving all strikes doubles maximum lifespan and adds
  half of that new maximum directly to current lifespan, then asks `player.gd`
  to play a larger multi-ring breakthrough effect.
- `RoadForkSpawner` periodically places `road_fork.tscn` beyond the camera on
  the active route. Events alternate between normal roads and a red-black
  `试炼地狱`, while also alternating their full-width left/right placement
  outside the current route. Entering a branch commits a new infinite route
  center for world, camera, player, enemies, and later forks, so branches can
  recursively contain further branches. Trial Hell persists its palette across
  the pooled road and raises enemy health, damage, attack frequency, spawn
  frequency, and simultaneous count until a normal branch is committed.
- `default_world_chunk_config.tres` is the shared designer-facing source of
  truth for chunk dimensions, road width, seed, TileSet, and tile selection.
  `InfiniteWorld` applies its road width to the player at startup.
- `world_chunk.tscn` is the reusable runtime chunk and has an `@tool` editor
  preview. Atlas previews draw directly on the editor canvas; runtime terrain
  uses a generated `TileMapLayer`.
- `world_chunk_preview.tscn` displays three adjacent chunks plus the player for
  seam, scale, and deterministic-variation review.
- `pause_menu.tscn` processes while paused and must unpause the tree before
  changing scenes.

Do not move configuration back into duplicated scene overrides when it already
belongs in `WorldChunkConfig`.

## Code documentation requirements

Every exported GDScript field must have an adjacent Godot documentation comment
using `##`. This is mandatory for all export forms, including `@export`,
`@export_range`, `@export_file`, exported node references, resources, and future
export annotations.

Each exported-field comment must explain, where applicable:

- The designer-facing purpose
- Units such as pixels, pixels per second, or probability
- Valid range or expected resource/node type
- Runtime ownership, synchronization, or override behavior
- Non-obvious effects of increasing, decreasing, or enabling the value

Keep the documentation comment immediately above its export annotation:

```gdscript
## Vertical camera lead in world pixels. Larger values place the player lower
## on screen and expose more road ahead.
@export var camera_forward_look_ahead: float = 180.0
```

When code has a public or designer-facing contract, add documentation where it
is needed even if the field is not exported. This includes non-obvious class
responsibilities, signals, shared resources, public cross-script methods,
coordinate conventions, editor/runtime behavior differences, and lifecycle or
ownership constraints.

Use comments to explain intent, constraints, and reasons. Do not narrate
obvious syntax or add comments that merely repeat a name. Update documentation
when behavior or authority changes; stale documentation is a defect.

## Engineering conventions

- Do not create, update, or run smoke tests. Validate requested changes with
  focused static inspection, parser checks, or other non-smoke verification.
- Use typed GDScript where practical.
- Prefer resource driven and composable driven pattern when best fit.
- Prefer direct ownership references and focused signals over broad scene-tree
  searches.
- Keep forward movement on negative Y and prevent reverse world travel.
- Keep the camera horizontally centered so generated terrain cannot be exposed
  at the sides.
- Keep chunk placement and recycling distance-based and deterministic.
- Keep editor previews non-serialized; do not save thousands of generated
  cells into `world_chunk.tscn`.
- Preserve pause processing behavior and always unpause before returning to the
  main menu.
- Avoid unnecessary autoloads and per-frame terrain generation.
- Do not leave parser warnings, runtime errors, or placeholder methods.
- Update this structure section when files or responsibilities move.
