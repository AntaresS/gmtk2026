# Gameplay Depth and Progression Recommendations

Date: 2026-07-24

Status: Design and implementation handoff

## Purpose

This document summarizes the gameplay-run review, screenshot evidence, and code
audit for the current GMTK 2026 project. Its recommendations are intended to
increase build agency, run consistency, weapon diversity, and tactical
readability without replacing the current core foundation.

The foundation to preserve is:

- Automatic aiming and attacking.
- Directional movement plus tactical acceleration and slowing.
- One realm-dependent active action on Space.
- Active-weapon selection and cycling.
- One-second commitment windows for weapon and fragment collection.
- Elite pursuit as an optional risk/reward opportunity.
- Branch selection through movement rather than menus.
- Four realms, three survivable realm transitions, and the final fatal
  breakthrough attempt that ends the run.

The project already has sufficient content for a strong vertical slice:

- Six collectible weapons and Great Strength Palm as the starting technique.
- Four cultivation realms with different movement, defense, and Space abilities.
- Multiple enemy roles and realm-gated enemy variants.
- Time- and level-driven difficulty scaling.
- Enemy, elite, rear-pursuer, and Trial Hell reward modifiers.
- Persistent branch routes, including the high-pressure Trial Hell variant.

The main constraint is no longer content quantity. The larger issue is that
rewards currently provide considerable quantity but little agency, while the
different weapon implementations convert the same upgrades at dramatically
different rates.

## Current Gameplay Assessment

The game currently reads most strongly as an auto-combat cultivation runner:
the player controls positioning, encounter commitment, route selection,
collection timing, and weapon choice while the combat system executes attacks
automatically.

This is a viable identity. More attack buttons are not necessary. Additional
depth should come from making the existing movement and timing decisions carry
clear opportunity costs:

- Which elite is worth pursuing?
- Which reward should be locked during its one-second channel?
- Which weapon should receive the next investment?
- Is the dangerous route appropriate for the current build?
- Is accelerating worth its lifespan and positioning cost?
- Should the player protect progression Qi or spend it defensively?

### Positive qualities to preserve

- The control scheme is focused and approachable.
- Movement already supports evasion, pursuit, collection, and route decisions.
- Auto-aim lets the player evaluate battlefield geometry instead of cursor
  precision.
- Weapon switching can be tactical when weapons have distinct encounter roles.
- Realm breakthroughs create readable run phases and introduce new capabilities.
- Palm supplies a dependable fallback when weapon acquisition is unfavorable.

### Current systemic risks

- Uniform random drops provide no meaningful opportunity cost: every reward
  should normally be collected.
- Weak damage conversion causes a negative feedback loop:
  slower kills lead to more incoming damage, more shield Qi expenditure, later
  levels, stronger time scaling, and even slower kills.
- Palm and Thunder Hammer structurally receive much stronger multiplicative
  scaling than the other weapons.
- Some duplicate weapon counts do not translate cleanly into combat power.
- The dangerous branch communicates little about its exact risks and rewards.
- Realm abilities vary substantially in mechanical usefulness and clarity.

## Test-Run Evidence

The supplied screenshots show that the problem is not simply insufficient elite
or weapon-drop quantity.

### `death1_under_farm.png`

Observed state:

- Qi Refining layer 9.
- 208 / 300 Qi.
- 196 maximum lifespan.
- 14 universal-upgrade fragments.
- Approximately 11 collectible weapon copies.

Interpretation:

The distribution was uneven, but the run did not receive catastrophically few
elite rewards. It still failed to convert ordinary farming and its available
weapons into the last 92 Qi before the first breakthrough.

Local evidence:
`/Users/tuti/Documents/screenshots/death1_under_farm.png`

### `death2_under_farm.png`

Observed state:

- Golden Core layer 9.
- 372 / 750 Qi.
- 352 maximum lifespan.
- 87 universal-upgrade fragments.
- Approximately 80 collectible weapon copies.

Interpretation:

This was an abundant-loot run that still failed. It is strong evidence that raw
drop quantity does not guarantee sufficient kill conversion or progression
pace. It also suggests that progression Qi lost through combat and shield use
may be contributing to the snowball.

Local evidence:
`/Users/tuti/Documents/screenshots/death2_under_farm.png`

### `death3_yuanying_bug.png`

Observed state:

- Nascent Soul layer 2.
- 740 / 800 Qi.
- 420 maximum lifespan.
- Qiankun Ring at quantity 17 while its displayed damage remained 5.
- The tested build did not grant the expected lifespan reward after re-entering
  Nascent Soul.

Interpretation:

This run exposes both Ring-growth readability/effectiveness problems and the
repeat-breakthrough reward defect.

Local evidence:
`/Users/tuti/Documents/screenshots/death3_yuanying_bug.png`

### `win1_thunder.png`

Observed state:

- Nascent Soul layer 9.
- Thunder Hammer at quantity 9.
- Effective displayed Thunder damage 34 during Spirit Projection.
- 82 universal-upgrade fragments.
- Approximately 92 collectible weapon copies.

Interpretation:

Thunder converts flat damage, quantity, range, persistent duration, AoE, and
repeated pulses multiplicatively. It is much more efficient at converting the
same reward economy than most weapons.

Local evidence:
`/Users/tuti/Documents/screenshots/win1_thunder.png`

### `win2_palm.png`

Observed state:

- Nascent Soul layer 9.
- Effective displayed Palm damage 88 during Spirit Projection.
- 78 universal-upgrade fragments.
- Approximately 100 collectible weapon copies.

Interpretation:

Palm can win independently of favorable weapon-copy distribution because it
receives bespoke damage, range, and attack-speed growth from every overall
level. Its Nascent Soul behavior also instantly kills non-elite enemies.

Local evidence:
`/Users/tuti/Documents/screenshots/win2_palm.png`

## Root Causes Identified in the Code Audit

### Player and enemy scaling are asymmetrical

`EnemySpawner` combines elapsed-time steps and every overall cultivation level
into one difficulty step. Each step can:

- Add enemy health.
- Add enemy damage.
- Reduce enemy attack intervals.
- Increase the simultaneous-enemy cap.
- Reduce spawn intervals.

However, `game/resources/player_combat_config.tres` currently sets
`global_damage_bonus_per_overall_level` to zero. Most weapons therefore do not
receive guaranteed damage growth when the player levels. Palm is the major
exception because `player.gd` gives it bespoke level-based damage, range, and
attack-speed growth.

### Progression Qi is also a defensive resource

From Foundation onward, the Qi shield automatically spends current Qi to absorb
damage. Current Qi is also the resource required to gain levels. A weak build
therefore loses both survival tempo and progression tempo when hit.

### Flat damage scales differently across weapon implementations

A flat point of damage is not equally valuable:

- Thunder applies it to every pulse of every cloud.
- Flying Sword may apply it across multiple piercing hits.
- Dao applies it once to every target within its attack.
- Ring is explicitly excluded from the ordinary flat-damage bonus and receives
  bounces instead.
- Seal and Palm have percentage-health or instant-kill behavior that can make
  ordinary damage numbers secondary.

### Duplicate weapon quantities do not have consistent value

- Thunder duplicates create more persistent clouds.
- Sword duplicates create more projectiles.
- Ring duplicates create longer projectile sequences and can extend the time
  before all Rings return.
- Dao duplicates increase the delivery/orbit count, but the live direct attack
  still damages each valid target only once.
- Bell duplicates create additional defensive contact layers.
- Seal duplicates create long sequential impact chains that may overkill the
  same encounter.

## Recommendations

## 1. Stop Defensive Damage From Destroying Progression Momentum

### Problem

The Qi shield spends the player's level-up currency. This creates a severe
negative feedback loop:

1. A weak build kills enemies slowly.
2. More enemies get attack opportunities.
3. The shield spends progression Qi.
4. The next level and realm arrive later.
5. Time-based difficulty continues growing.
6. The build falls further behind.

### Recommended behavior

Protect a progression reserve:

- The shield may only spend Qi above 20–25% of the next level requirement.
- Clearly display `护盾消耗 -N 灵气` whenever shielding occurs.
- Show the protected reserve on the Qi bar.

Possible alternative:

- The shield absorbs only 50–70% of incoming damage and never spends reserved
  Qi.

### Expected result

Evasion remains valuable, and mistakes still cost lifespan or Qi, but one weak
period cannot silently erase all progress toward the next layer.

### Relevant files

- `game/scripts/gameplay/realm_ability_controller.gd`
- `game/scripts/gameplay/run_resources.gd`
- `game/scripts/gameplay/gameplay_hud.gd`

## 2. Turn Elite Fragments Into Movement-Based Choices

### Problem

The guaranteed elite fragment currently selects one of five universal upgrades
uniformly. Every outcome is beneficial, so the normal decision is simply to
collect every fragment.

### Recommended behavior

Reuse the existing cycling `CultivationFragment`:

- The fragment cycles through Jing, Qi, and Shen.
- Entering the radius locks the currently displayed type.
- The player must remain inside for one second.
- The player can wait for the desired type, but doing so consumes time and
  creates positional risk.

Suggested weapon affinities:

- Jing: Dao and Golden Bell.
- Qi: Flying Sword and Thunder Hammer.
- Shen: Qiankun Ring and Fantian Seal.

Balance guidance:

- Prefer three fragments per cultivation-track level.
- If one fragment continues to grant one full track level, reduce the matching
  weapon damage bonus substantially from its current 10% per level.
- Universal fragments can remain as rarer Trial Hell rewards.

Alternative:

- Elites drop two visible fragments. Starting one channel removes the other.

### Expected result

Player-stat growth becomes a movement and timing choice without adding menus or
buttons. The one-second channel becomes a meaningful commitment.

### Relevant files

- `game/scripts/gameplay/cultivation_fragment.gd`
- `game/scenes/gameplay/cultivation_fragment.tscn`
- `game/resources/cultivation_config.tres`
- `game/scripts/gameplay/enemy_spawner.gd`
- `game/scripts/gameplay/weapon_power_fragment.gd`

## 3. Add Acquisition Fairness Instead of Simply Increasing Drop Quantity

### Problem

Late runs already contain very large weapon quantities. Increasing the global
drop rate would add noise without fixing run agency. Early weapon starvation or
unhelpful repetition can nevertheless determine whether the player establishes
a viable build.

### Recommended behavior

Use controlled randomness:

- Guarantee the first elite within a bounded early window.
- Guarantee that the first elite drops a weapon.
- Use a shuffled six-weapon bag so every weapon appears before unrestricted
  repetition resumes.
- Prevent the first two weapon rewards from being duplicates.
- Later elite rewards may offer two visible weapons; collecting one removes the
  other.

Optional pity rules:

- Increase effective elite chance after consecutive non-elite spawns, then reset
  it after an elite appears.
- Guarantee a weapon after a bounded number of elite weapon-drop failures.

### Expected result

Runs retain variation but do not die because the player never received a
reasonable initial tool. Additional drops create decisions rather than clutter.

### Relevant files

- `game/scripts/gameplay/enemy_spawner.gd`
- `game/scripts/gameplay/weapon_pickup.gd`
- `game/resources/weapon/`

## 4. Normalize Weapon Growth Rules

The goal is not identical DPS. Each weapon should have a distinct role while
turning comparable investment into comparable run value.

### Great Strength Palm

Current advantages:

- Guaranteed from the beginning.
- Gains flat damage every overall level.
- Gains range every overall level.
- Gains attack speed every overall level.
- Gains additional directional coverage by realm.
- Instantly kills non-elites in Nascent Soul.

Recommended changes:

- Replace the Nascent Soul instant kill with an execute threshold around
  25–30% remaining health.
- Consider realm direction counts closer to 1 / 2 / 4 / 8 instead of
  1 / 2 / 6 / 18.
- Retain dependable level growth, but reduce its simultaneous range and
  attack-speed growth.
- Palm should be a reliable fallback, not the best guaranteed endgame weapon.

### Thunder Hammer

Current advantages:

- Each cloud lasts four seconds.
- Each cloud pulses every 0.4 seconds.
- Flat damage applies to every pulse.
- Quantity creates additional clouds.
- Range upgrades enlarge every cloud.
- Overlapping persistent clouds multiply coverage and damage.

Recommended changes:

- Cap effective simultaneous clouds or delivery around five or six.
- Reduce cloud lifetime to approximately 2.5–3 seconds, or add one shared
  Thunder damage cooldown per enemy.
- Convert duplicate copies above the cap into modest duration, radius, or
  damage growth rather than another full cloud.

### Dao

Current issue:

- Duplicate count increases orbit/delivery presentation.
- The direct attack still damages each target only once.

Recommended changes:

- Each additional orbit contributes approximately 30–40% damage, or
- Each copy grants approximately 10–12% total Dao damage or useful radius.
- Cap fully represented orbits around six and convert excess copies into
  damage.

### Qiankun Ring

Current issues:

- Ring is excluded from ordinary universal flat-damage growth.
- Damage fragments add bounces instead.
- Another volley cannot begin until every Ring has returned.
- High quantity and bounce counts can create extremely long cycles without
  improving the displayed base damage.

Recommended changes:

- Give Ring partial damage-fragment scaling.
- Cap effective bounces around six to eight.
- Allow another volley after the normal attack cooldown while enforcing an
  active-Ring cap.
- Let duplicate copies improve parallel coverage instead of only extending one
  locked sequence.

### Flying Sword

Recommended changes:

- Reduce high-stack sequential launch delay.
- Later copies can launch as a small fan or short burst.
- Preserve piercing as its primary identity.
- Avoid allowing quantity to turn one volley into a long period during which
  no new attack cycle can begin.

### Fantian Seal

Recommended changes:

- Let duplicates reduce ascent delay, enlarge the impact square, or improve
  elite damage instead of only creating more sequential impacts.
- Preserve its delayed, heavy, high-commitment identity.
- Avoid long sequences that repeatedly target enemies already scheduled to die.

### Golden Bell

Recommended changes:

- Preserve its close-range defensive identity.
- Add a modest counter-pulse, execute effect, or final damage follow-up so
  equipping it does not almost completely stop Qi farming.
- Clearly display ready, flashing, and recovering layers.

### Normalize universal damage

The current flat `+1 damage` is disproportionately strong for multi-hit attacks.
A preferable long-term model is either:

- Percentage damage growth, or
- A designer-facing universal-damage coefficient per weapon.

If coefficients are used, low-base repeated-pulse weapons should receive less
flat damage per universal level than slow single-impact weapons.

### Relevant files

- `game/scripts/gameplay/player.gd`
- `game/scripts/gameplay/combat_stats_resolver.gd`
- `game/scripts/gameplay/thunder_cloud_projectile.gd`
- `game/scripts/gameplay/qiankun_ring_projectile.gd`
- `game/scripts/gameplay/flying_sword_projectile.gd`
- `game/scripts/gameplay/fantian_seal_projectile.gd`
- `game/scripts/gameplay/golden_bell_controller.gd`
- `game/resources/weapon/`

## 5. Give All Weapons Modest Guaranteed Overall-Level Growth

### Correction to earlier numeric guidance

`global_damage_bonus_per_overall_level` is currently a flat-damage field, not a
percentage. The resolver currently calculates:

```text
flat level bonus =
    (overall cultivation level - 1)
    * global_damage_bonus_per_overall_level

resolved damage =
    round(
        (rolled weapon damage + flat global bonus)
        * matching cultivation multiplier
    )
```

Therefore, setting the current field to `0.01–0.015` would be far too small:

| Flat value | Bonus at Lv.10 | Bonus at Lv.27 | Bonus at Lv.36 |
|---:|---:|---:|---:|
| 0.01 | 0.09 | 0.26 | 0.35 |
| 0.10 | 0.90 | 2.60 | 3.50 |
| 0.20 | 1.80 | 5.20 | 7.00 |
| 0.25 | 2.25 | 6.50 | 8.75 |
| 0.30 | 2.70 | 7.80 | 10.50 |
| 1.00 | 9.00 | 26.00 | 35.00 |

### Preferred recommendation

Add a separate percentage field:

```gdscript
global_damage_ratio_per_overall_level = 0.01
```

Apply it approximately as:

```text
damage =
    (weapon base damage + flat weapon upgrades)
    * (1 + ratio per level * completed levels)
    * matching cultivation multiplier
```

A 1% ratio produces:

- Level 10: +9%.
- Level 27: +26%.
- Level 36: +35%.

A 1.5% ratio produces:

- Level 10: +13.5%.
- Level 27: +39%.
- Level 36: +52.5%.

Start closer to 1% because weapon quantities and cultivation affinity add
additional scaling.

### Configuration-only fallback

If no new percentage field is added, start testing the existing flat field near
`0.2–0.3`, not `0.01`. This requires extra care because flat damage again
benefits Thunder pulses and other repeated-hit weapons disproportionately.

### Related economy adjustment

Enemy reward growth is currently modest relative to combat growth. Consider
testing:

- Enemy Qi increase per difficulty step: `0.5 -> 0.75`, or
- Qi requirement increase per level: `25 -> 20`.

Do not change both simultaneously before measuring the result.

### Expected result

Every weapon receives some guaranteed power from successful progression. A
player level no longer strengthens enemies while leaving most player weapons
unchanged.

### Relevant files

- `game/resources/player_combat_config.tres`
- `game/scripts/gameplay/player_combat_config.gd`
- `game/scripts/gameplay/combat_stats_resolver.gd`
- `game/scripts/gameplay/player_global_combat_stats.gd`
- `game/scripts/gameplay/enemy_spawner.gd`
- `game/scripts/gameplay/run_resources.gd`

## 6. Make Branches Explicit Build Decisions

### Current Trial Hell package

The live configuration approximately applies:

- Enemy-count multiplier: 1.75.
- Spawn-interval multiplier: 0.55.
- Enemy-health multiplier: 1.50.
- Enemy-damage multiplier: 1.35.
- Enemy-attack-interval multiplier: 0.75.
- Qi reward multiplier per enemy: 1.20.

The risk increase is much larger than the label `高压战斗区域` communicates.
Although increased enemy throughput can raise total rewards per minute, the
player cannot evaluate the expected trade without exact information.

### Recommended behavior

Make normal and dangerous routes complementary:

Safe route:

- Lower enemy density.
- Guaranteed Qi cache or modest lifespan recovery.
- Lower elite opportunity.

Trial Hell:

- Higher elite probability.
- Higher Qi multiplier.
- Cultivation-fragment or weapon-choice rewards.
- Clear route duration or a clearly marked future exit.

Suggested preview:

```text
试炼地狱
敌群 +75%
敌人生命 +50%
灵气奖励 +40%
精英概率 +10%
武器奖励二选一
```

The exact numbers require testing, but the player should see the actual contract
before committing.

### Expected result

Route selection becomes a build and recovery decision rather than a vague
choice between normal and dangerous terrain.

### Relevant files

- `game/scripts/gameplay/road_fork.gd`
- `game/scripts/gameplay/road_fork_spawner.gd`
- `game/scripts/gameplay/game.gd`
- `game/scripts/gameplay/enemy_spawner.gd`
- `game/scripts/gameplay/infinite_world.gd`

## 7. Clarify and Strengthen Realm Active Skills

### Qi Refining

Current role:

- Short directional invulnerable roll.

Recommendation:

- Preserve it.
- Give its cooldown a compact persistent icon or radial timer.

### Foundation

Current role:

- Temporary ascent, hold, and descent presentation.

Concern:

- Active elevation has limited direct mechanical consequence. Damage eligibility
  is primarily resolved from attacker and player realm tiers rather than the
  temporary flight phase.

Recommendation:

- During the flight hold, ignore ground-contact attacks and bomber explosions,
  or allow the player to pass over ground enemies.
- Clearly show ascent, hold, and descent duration.

### Golden Core

Current role:

- Summons two echoes using a portion of player health, weapon damage, range, and
  attack interval.
- Echoes can draw enemy targeting.
- Acceleration plus repeated Space presses can reduce cooldown.

Recommendation:

- Preserve the active behavior.
- Display echo health, count, and cooldown more compactly.
- Explain that accelerating allows active cooldown reduction.

### Nascent Soul

Current role:

- Toggles Spirit Projection.
- Doubles outgoing damage.
- An unabsorbed hit ends projection and demotes the player to Golden Core
  layer 9.

Recommendation:

- Persistently display the full contract:
  `伤害 x2 · 护盾破裂后受击将跌落金丹九层`.
- Show the Qi required to absorb the next expected hit.
- Add strong activation, shield-break, and demotion feedback.
- Consider a very short grace interval after activation if accidental immediate
  damage is common.

### Expected result

Every breakthrough gives the player a mechanically legible tool, not only a new
visual state.

### Relevant files

- `game/resources/realm_progression_config.tres`
- `game/scripts/gameplay/realm_ability_controller.gd`
- `game/scripts/gameplay/player.gd`
- `game/scripts/gameplay/player_echo.gd`
- `game/scripts/gameplay/gameplay_hud.gd`

## 8. Fix Nascent Soul Re-entry Without Creating a Farming Exploit

### Tested-build defect

The supplied Nascent Soul death showed that re-entering the realm after Spirit
Projection demotion did not grant the expected lifespan restoration.

### Current in-progress working-tree behavior

At the time of this audit, uncommitted `RunResources` changes were being added
to grant a complete breakthrough reward on every repeated resource-driven realm
transition.

That restores:

- The per-transition maximum-lifespan increase.
- The configured percentage of maximum lifespan.
- Another increment to completed breakthroughs.

This fixes the missing reward but creates a possible exploit:

1. Activate Spirit Projection.
2. Intentionally take an unabsorbed hit.
3. Fall to Golden Core layer 9.
4. Farm the re-entry Qi.
5. Complete another tribulation.
6. Gain another permanent maximum-lifespan increase.
7. Repeat until reaching the lifespan cap.

### Recommended state model

Separate first-clear progression from repeat recovery:

- Track `highest_realm_reached` or first-clear state independently.
- First clear of a realm:
  - Grant the permanent maximum-lifespan increase.
  - Restore the normal breakthrough percentage.
  - Increment permanent breakthrough progress.
- Repeat re-entry:
  - Restore approximately 25–35% of current maximum lifespan.
  - Do not increase maximum lifespan again.
  - Do not increment permanent breakthrough count.

Optional anti-frustration rule:

- Retain a portion of the re-entry Qi after demotion rather than always resetting
  it to zero.

### Expected result

Re-entering Nascent Soul feels like a successful recovery rather than a bug, but
intentional demotion cannot generate unlimited permanent lifespan.

### Relevant files

- `game/scripts/gameplay/run_resources.gd`
- `game/scripts/gameplay/realm_ability_controller.gd`
- `game/scripts/gameplay/game.gd`
- `game/tests/gameplay_loop_smoke.gd`

## Readability and Balance-Instrumentation Improvements

The weapon-slot HUD work in the current working tree is directionally useful.
The most useful next information is decision support rather than additional raw
statistics.

### In-run information

- Current weapon effective damage.
- Current attack interval.
- Effective attack and AoE range.
- A concise role tag:
  - Single target.
  - Crowd control.
  - Elite killer.
  - Defense.
- Exact effect of collecting the visible pickup.
- New weapon highlight until selected once.
- Elite direction marker when an elite is just off-screen.
- Locked fragment name and channel progress.
- Exact branch risk/reward preview.
- Qi consumed by shielding.
- Space ability state and cooldown.

### Death and victory recap

Record and display:

- Run duration.
- Final realm and layer.
- Total Qi earned.
- Qi spent by the shield.
- World Qi collected.
- Enemies and elites killed.
- Elites encountered but missed.
- Weapon drops collected and missed.
- Fragment categories collected.
- Time spent with each equipped weapon.
- Damage or passive-decay cause of death.
- Branches selected.
- Effective pity counters.

These metrics will distinguish:

- Genuine bad acquisition luck.
- Poor player route or weapon choices.
- Shield-driven Qi loss.
- A weapon failing to convert investment.
- A global progression curve that is too demanding.

## Recommended Implementation Order

### Phase 1: Correctness and run-state safety

1. Implement first-clear versus repeat-reentry breakthrough state.
2. Add focused coverage for repeat Nascent Soul re-entry.
3. Ensure repeat re-entry restores lifespan without permanent reward farming.
4. Decide and restore the intended relationship between speed and lifespan
   consumption.

Speed note:

`PlayerController.get_lifespan_decay_multiplier()` was forced to return `1.0`
during the audit. The gameplay-loop smoke test consequently failed because
accelerating did not increase lifespan consumption and the HUD rate did not
change.

Do not restore the full speed penalty blindly before stabilizing the economy. A
milder curve can preserve the choice:

```text
lifespan multiplier =
    lerp(1.0, current speed / base speed, 0.5–0.7)
```

Slowing can remain unable to reduce decay below the baseline.

### Phase 2: Stabilize the economy floor

1. Protect a Qi reserve from automatic shield spending.
2. Add shield-spend feedback and telemetry.
3. Add first-elite and first-weapon guarantees.
4. Add the shuffled weapon bag or another bounded-random acquisition model.
5. Measure progression using ordinary enemies without assuming elite luck.

Target behavior:

- Ordinary combat should make completing a run possible.
- Elites should shorten the run or improve the build meaningfully.
- Missing a few elites should not make the run mathematically dead.

### Phase 3: Add growth decisions through existing movement

1. Reconnect or repurpose the cycling cultivation fragment.
2. Map all six weapons to an affinity.
3. Require a movement/timing commitment to choose the track.
4. Decide whether universal fragments remain in Trial Hell or another rarer
   reward pool.

### Phase 4: Correct weapon conversion

Implement the most objective defects first:

1. Give Dao duplicates a real combat effect.
2. Give Ring coherent damage growth and prevent return-lock scaling collapse.
3. Cap or normalize Thunder cloud multiplication.
4. Replace Palm's Nascent Soul instant kill with an execute threshold.
5. Reduce high-quantity sequence dilution for Sword and Seal.
6. Improve Bell's contribution to farming without removing its defense role.

### Phase 5: Add shared weapon progression

1. Prefer a new percentage-based overall-level damage field.
2. Start near 1% per completed overall level.
3. Reduce Palm's bespoke scaling at the same time.
4. Avoid using a large flat bonus until repeated-hit coefficients are
   normalized.
5. Retest every weapon at representative early, middle, and late quantities.

### Phase 6: Make branches strategic

1. Show exact Trial Hell modifiers before commitment.
2. Give the safe branch a recovery or guaranteed-progression identity.
3. Give Trial Hell a targeted build reward, not only more enemies.
4. Ensure dangerous-route rewards scale with the actual risk.

### Phase 7: Readability and run analysis

1. Complete the compact weapon-slot presentation.
2. Add effective role and collection-change information.
3. Add active ability state and risk text.
4. Add branch forecasts.
5. Add death/victory recap and balance telemetry.

### Phase 8: Tune exact values

Tune only after the behavioral rules are stable.

Recommended comparison matrix:

- Each weapon at quantity 1, 3, 6, and 10.
- Levels 1, 10, 19, 28, and 36.
- Average universal-fragment distribution.
- Low, median, and high acquisition luck.
- Normal route versus Trial Hell.
- With and without shield Qi expenditure.
- Normal and Spirit Projection states.

## Suggested Success Criteria

### Run consistency

- A low-luck but competently played run remains recoverable.
- Early weapon repetition changes the strategy without declaring the run dead.
- Ordinary enemy farming alone can support baseline progression.
- Elite pursuit provides a meaningful advantage rather than mandatory access to
  viability.

### Build agency

- At least one meaningful growth choice appears before the first breakthrough.
- The player can intentionally favor a weapon or stat family.
- Dangerous branches appeal to particular builds rather than universally strong
  builds only.

### Weapon diversity

- At least four of the seven total combat options can complete a representative
  run.
- No weapon requires extreme quantity luck to become functional.
- Palm remains viable but no longer dominates purely through guaranteed
  progression.
- Thunder remains a persistent AoE specialist without scaling through
  unbounded overlapping clouds.

### Readability

- The player can state why a pickup matters before collecting it.
- The player can state why a route is dangerous and what it rewards.
- The player can see whether Qi loss came from leveling, shielding, or another
  system.
- A death recap distinguishes poor decisions, bad luck, and systemic imbalance.

## Validation Checklist

Run focused tests after each relevant phase:

```sh
/Users/tuti/.local/bin/godot --headless --path . \
  --script game/tests/latest_weapon_design_smoke.gd

/Users/tuti/.local/bin/godot --headless --path . \
  --script game/tests/cultivation_smoke.gd

/Users/tuti/.local/bin/godot --headless --path . \
  --script game/tests/foundation_smoke.gd

/Users/tuti/.local/bin/godot --headless --path . \
  --script game/tests/gameplay_loop_smoke.gd
```

Relevant current audit results:

- `LATEST WEAPON TEST: PASS`
- `GAMEPLAY LOOP TEST: FAIL (2 failures)`
  - Accelerating did not increase lifespan consumption.
  - The HUD did not display accelerated lifespan consumption.

Because the working tree was changing during the audit, rerun all relevant tests
against the exact implementation commit before using these results as current
release evidence.

## Scope Discipline

These recommendations intentionally do not require:

- Manual aiming.
- Additional combat buttons.
- Replacing automatic attacks.
- Removing speed controls.
- Removing weapon cycling.
- Removing elite pursuit.
- Removing procedural branches.
- Rebuilding the realm system.

The desired result is deeper decision-making through the systems that already
define the game.
