# Count Down game guidance

This directory contains the playable Godot 4.7 foundation for a top-down,
forward-scrolling game. Forward is always negative world Y. Keep changes
focused on the requested system and do not add unrelated gameplay features.

## Current structure

```text
game/
  AGENTS.md
  README.md
  resources/
    default_world_chunk_config.tres
    qi_density_large.tres
    qi_density_medium.tres
    qi_density_small.tres
    summer_terrain_tileset.tres
  scenes/
    gameplay/
      game.tscn
      gameplay_hud.tscn
      player.tscn
      player_absorption_area.tscn
      qi_pickup.tscn
      run_ended_overlay.tscn
      world_chunk.tscn
      world_chunk_preview.tscn
    menus/
      main_menu.tscn
      pause_menu.tscn
  scripts/
    gameplay/
      game.gd
      gameplay_hud.gd
      infinite_world.gd
      player.gd
      player_absorption_area.gd
      qi_density_profile.gd
      qi_pickup.gd
      run_ended_overlay.gd
      run_resources.gd
      world_chunk.gd
      world_chunk_config.gd
      world_chunk_preview.gd
    menus/
      main_menu.gd
      pause_menu.gd
  tests/
    foundation_smoke.gd
```

Godot-generated `.uid` companions live beside scripts. Do not edit them
manually.

## Ownership and runtime flow

- `main_menu.tscn` is the application entry point and replaces itself with
  `game.tscn` when play starts.
- `game.tscn` owns the player, vertically tracking camera, infinite-world
  controller, run resources, HUD, pause menu, run-ended flow, and optional
  debug overlay.
- `run_resources.gd` owns lifespan, qi, cultivation level, and level-up
  recovery. `gameplay_hud.tscn` only presents its signals.
- `player.tscn` is a reusable `CharacterBody2D`. `player.gd` owns movement,
  speed modes, accumulated distance, and lateral clamping.
- `InfiniteWorld` owns a fixed pool of `WorldChunk` instances. It recycles
  chunks by player world distance and must not instantiate or free chunks
  during ordinary movement.
- Each pooled `WorldChunk` regenerates one bounded, deterministic mix of
  scattered and grouped pickups when configured. Density profiles define
  small, medium, and large qi value, scale, color, duration, and spawn weight.
- `player_absorption_area.tscn` owns the player's visible absorption radius.
  Pickups retain their own partial absorption progress and emit completion
  upward through the chunk and world; they never search for run state.
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

- Use typed GDScript where practical.
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
