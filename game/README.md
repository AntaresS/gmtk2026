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

- `RunResources` starts at 180 seconds, decays lifespan, tracks qi and
  cultivation level, and restores lifespan on level-up. Passive decay scales
  with actual forward speed: accelerating consumes it faster and slowing down
  consumes it more slowly. Enemy melee damage uses the same lifespan resource.
- Every pooled chunk tests a deterministic, bounded mix of scattered pickup
  candidates and local clusters within the road margins.
- `qi_profile.tres` defines the only qi pickup's value, appearance, and a
  five-percent chance for each candidate position to create a real pickup.
- Qi is collected immediately when the player's body touches it; there is no
  timed absorption synchronization. A small `灵气` label follows each pickup.
- `EnemySpawner` creates slower enemies ahead of the visible screen and
  slightly faster pursuers behind it. Every enemy moves straight forward at
  one constant assigned speed, never steers or accelerates toward the player,
  and attacks only at close range. Enemies spawn within the current road and
  are removed if route migration leaves them on a road the player did not take.
  Every 20 unpaused seconds and every cultivation level above one add a full
  difficulty step: newly spawned ordinary enemies gain two health and 0.75
  damage, attack and spawn faster, and increase the simultaneous-enemy cap.
  Each spawn has an eight-percent chance to become a gold-labeled elite with
  triple health, 1.6-times melee range, and a 1.25-times larger body. Every
  defeated elite drops one cycling `精 / 气 / 神` cultivation fragment.
- Horizontal input is applied immediately with no release inertia. Forward
  speed changes remain smoothed independently.
- The player attacks automatically. The visible circle always represents only
  the current equipment's live attack range. A separate invisible attraction
  radius pulls qi and equipment and grows by 10 pixels per cultivation level.
- Every enemy drops one 15-qi pickup and has a 35-percent chance to drop one
  evenly selected `WeaponData` resource: `刀` with 2–5 damage, `飞剑` with
  4–8 damage, or `乾坤圈` with 3–7 damage. The shared resources are the
  designer-facing source of identity, damage bounds, range, cooldown,
  cultivation type, delivery tuning, and projectile scenes. Weapon labels include randomized
  damage, follow their drops, and retain the enemy's forward velocity until
  attracted.
- The player begins with `大力掌`. Only the current collected weapon is visible
  beside the player; the strongest copy of each type is kept and new upgrades
  auto-equip. Tab is captured before UI focus navigation and cycles the
  equipment library shown on the HUD. The player uses the looping nine-frame
  animation converted from `chara_fly.gif`; each cultivation increase adds a
  brief cyan-and-gold expanding aura.
- Elite cultivation fragments rotate deterministically through `精 → 气 → 神`.
  Entering their 96-pixel circle locks the displayed type and automatically
  channels while the player remains inside for 1.2 seconds, without stopping
  movement or combat. Leaving the circle cancels progress, unlocks the type,
  and resumes its prior cycle point. Each type tracks an independent level and
  `0/3` fragment progress.
- `cultivation_config.tres` owns the three repeating reward cycles, percentage
  values, caps, cap-conversion damage, colors, and optional icons. Secondary
  rewards resolve as player-global stats. Only the +10% additive damage per
  level remains affinity-specific: 刀 uses 精, 飞剑 uses 气, and 乾坤圈 uses 神.
  Untyped weapons such as 大力掌 remain neutral for that typed damage.
- `player_combat_config.tres` is the source of truth for player-global base
  combat stats, caps, and overall-level growth. Every overall cultivation level
  after level one adds one configurable flat global damage point to all current
  and future weapons before an affinity-specific damage multiplier is applied.
- Dao attacks orbit the player every 0.5 seconds over a 94-pixel radius.
  Player-wide AoE bonuses expand that primary damage circle. Flying swords
  launch 2,200-pixel-per-second sword-light projectiles every 0.9 seconds over
  a 240-pixel range. Delivery-count rewards add sequential swords to each
  volley. Swept queries prevent tunneling between physics frames. Regardless of
  weapon count, only one idle weapon accompanies the player.
- The Universe Ring homes into an enemy and then returns to the moving player.
  Delivery count adds enemy-to-enemy bounces before its return, while 神 area
  and targeting rewards expand its impact and search radii. Player-global
  projectile-speed bonuses affect its outbound, bounce, and return movement.
  While the ring is away, its idle companion is hidden.
- Advancing beyond cultivation level nine starts nine heavenly-lightning
  strikes. Each shows a labeled ground warning near the player's predicted
  position; its random offset remains inside a guaranteed-hit radius if the
  player keeps the same movement. Surviving all nine doubles maximum lifespan,
  immediately adds half of the new maximum to current lifespan, and displays
  a success message plus a larger multi-ring, light-column breakthrough aura.
- Periodic side roads appear ahead of the camera, alternating left and right.
  Branch events also alternate between normal roads and `试炼地狱`. Every
  branch is as wide as the current road and begins fully outside it. Trial Hell
  is marked by a red-black road and warning label; after entry that palette
  continues across the infinite route while enemies gain 50% health, 35%
  damage, faster attacks, a 75% higher simultaneous cap, and roughly 82% more
  frequent spawning. Entering a later normal branch clears those modifiers.
  Every committed route recenters player and camera, migrates the pooled world
  and spawners, and can recursively generate later branches.
- The HUD shows current lifespan decay, technique, active equipment damage,
  all three cultivation levels and fragment counts, fragment-channel progress
  and cancellation, level reward messages, and the complete equipment library.
  Its compact player-stat section shows live white global/final values plus
  separately color-coded 精, 气, and 神 contributions.
- `GameplayHud` listens to resource signals, while `game.gd` owns run-ended
  movement, enemy shutdown, and scene transitions.

Run the executable checks from the project root with:

```sh
godot --headless --path . --script res://game/tests/foundation_smoke.gd
godot --headless --path . --script res://game/tests/gameplay_loop_smoke.gd
godot --headless --path . --script res://game/tests/cultivation_smoke.gd
```
