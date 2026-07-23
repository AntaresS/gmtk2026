# Count Down foundation

`assets/seasonal sample (summer).png` is a 256×256 sprite sheet on a 16×16
grid. It arrived without a Godot `TileSet` or terrain metadata, so
`summer_terrain_tileset.tres` configures an atlas source.

`default_world_chunk_config.tres` is the designer-facing source of truth for:

- Chunk dimensions, tile size, and road width
- World seed and ground variation probability
- TileSet selection and terrain-painting mode
- Atlas source IDs and coordinates

`world_chunk.tscn` uses an `@tool` preview that reacts to config changes.
Atlas-only terrain is drawn directly on the editor canvas, independently of
the runtime `TileMapLayer`. Terrain-painting mode uses an internal transient
layer. In both cases, thousands of preview cells are not serialized into the
scene. Editor-only cyan guides show the chunk bounds, origin, and forward
direction and can be disabled from the chunk inspector.

Open `world_chunk_preview.tscn` to inspect three adjacent chunks and the player
together. The preview scene automatically repositions chunks when their
configured dimensions change.

The source sheet is a mixed terrain/sample composition rather than a dedicated
road autotile. The selected atlas coordinates therefore remain easy to change
on the shared config resource. To use a future terrain set instead, assign it
to `terrain_tileset`, enable `use_terrain_painting`, and set the terrain set,
road terrain, and ground terrain IDs. If the assigned resource is invalid, the
chunk falls back to its deterministic 16-pixel renderer rather than leaving
holes.

Pool size and recycle distance remain on `InfiniteWorld`; terrain and chunk
shape come from its shared `chunk_config`. The world applies the configured road
width to the player at startup so the visual and movement bounds stay aligned.

The minimal run loop is owned by separate gameplay systems:

- `RunResources` decays lifespan, tracks qi and cultivation level, and restores
  lifespan on level-up.
- Every pooled chunk regenerates a deterministic, bounded mix of scattered
  pickups and local clusters within the road margins.
- Small, medium, and large density resources independently define pickup size,
  color, qi value, absorption duration, and generation weight.
- The player scene owns a visible 96-pixel absorption field. Pickups show a
  progress ring and tether while absorbing, retain partial progress after the
  player leaves, and only grant qi when absorption finishes.
- `GameplayHud` listens to resource signals, while `game.gd` owns run-ended
  movement shutdown and scene transitions.

Run the executable checks from the project root with:

```sh
godot --headless --path . --script res://game/tests/foundation_smoke.gd
godot --headless --path . --script res://game/tests/gameplay_loop_smoke.gd
```
