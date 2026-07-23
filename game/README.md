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
