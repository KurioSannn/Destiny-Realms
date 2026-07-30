# Battle Command Flow Implementation

## Scope

Block 5 is a vertical slice for normal player-turn commands. It proves pending
command ownership and the commit boundary while keeping every production battle
scene on the existing `BattleManager` behavior.

Block 6 integrates the new command flow into production only for Basic Attack.
Skill and Ultimate remain on the legacy `BattleManager` path.

Block 7 integrates production Skill (`Triangle Rift`) through the same command
boundary. Ultimate remains legacy; no off-turn request, interrupt queue, or
suspended context is implemented.

Block 8 integrates production on-turn Ultimate (`Octagram Fragment`) through
the same command boundary. Off-turn Ultimate request, interrupt queue, and
suspended context are still not implemented.

Block 8.5 revises production Basic Attack into a fast command with no ready
idle and no confirm/cancel step, while Skill and Ultimate keep their ready
idle and confirm/cancel steps unchanged.

Block 9A designs and characterizes the architecture for Ultimate off-turn
interrupt: safe/unsafe window audit, a `SuspendedBattleContext` skeleton, an
`UltimateInterruptRequest`/`UltimateInterruptQueue` skeleton, and three
additive stub methods on `BattleCommandFlow`. None of it is wired to
production. `begin_command()` still rejects `RequestSource.INTERRUPT_REQUEST`
unconditionally, exactly as before this block.

Block 9B wires the Block 9A `UltimateInterruptQueue` into `BattleManager`
and makes off-turn Ultimate executable in production for **safe window B
only** (after enemy action/recovery completes, before the next player
turn). Window A (mid-enemy-action interrupt) and full suspend/resume via
`SuspendedBattleContext` remain unimplemented. `begin_command()` now accepts
`RequestSource.INTERRUPT_REQUEST` only when explicitly authorized by an
additive `interrupt_authorized` parameter that defaults to `false`.

Block 9C gives the legacy enemy attack coroutine (`_enemy_attack()`) a
commit-token/duplicate-prevention guard chain equivalent to what Basic/
Skill/Ultimate already had, closing the "no guard-chain discipline at all"
gap the Block 9A audit flagged as a prerequisite for window A. This block
adds no new interrupt capability: window A is still not implemented, and
safe window B's behavior and ordering are unchanged from Block 9B.

Run the isolated scene with F6:

`res://scenes/battle/debug/battle_command_flow_debug.tscn`

## Ownership

| File | Responsibility |
| --- | --- |
| `scripts/battle/command/pending_battle_command.gd` | Immutable command identity plus mutable pending/commit lifecycle data |
| `scripts/battle/command/battle_command_flow.gd` | Battle, animation, and UI state transitions; validation and commit boundary |
| `scripts/battle/command/basic_attack_command_adapter.gd` | Production Basic Attack bridge from `BattleManager` to `BattleCommandFlow` |
| `scripts/battle/command/skill_command_adapter.gd` | Production Skill bridge from `BattleManager` to `BattleCommandFlow` |
| `scripts/battle/command/ultimate_command_adapter.gd` | Production on-turn Ultimate bridge from `BattleManager` to `BattleCommandFlow` |
| `scripts/battle/command/suspended_battle_context.gd` | Block 9A skeleton: snapshot data for a future paused turn. Still not constructed by production code — Block 9B's safe window B never suspends mid-flight state |
| `scripts/battle/command/ultimate_interrupt_request.gd` | Block 9A skeleton: off-turn Ultimate request data. Now constructed by `BattleManager.request_off_turn_ultimate()` (Block 9B) |
| `scripts/battle/command/ultimate_interrupt_queue.gd` | Block 9A skeleton: pure FIFO queue for interrupt requests. Now instantiated and owned by `BattleManager` (Block 9B), unmodified since Block 9A |
| `scripts/battle/debug/battle_command_flow_debug.gd` | Adapter to existing combatants, resources, VFX, audio, damage, and enemy turn |
| `scripts/battle/debug/battle_command_debug_panel.gd` | F6-only state readout and debug controls |
| `scenes/battle/debug/battle_command_flow_debug.tscn` | Isolated inherited battle scene; production scene is unchanged |

## Command contract

Selecting Basic, Skill, or Ultimate creates one `PendingBattleCommand`. Ready
idle and target changes do not mutate HP, Skill Points, Energy, damage, or turn
ownership. Cancel clears the pending command and restores command select.

Confirm performs final actor, target, and resource validation. A successful
commit receives a unique token and spends its quoted cost once. Execution and
resolution consume that command once; duplicate confirm, execution, or resolve
calls are rejected. A target that becomes invalid before confirm cancels safely
without a cost.

Ultimate is supported only as a normal player-turn command in this block.
`INTERRUPT_REQUEST` is rejected with `off_turn_interrupt_not_available`. No FIFO
queue, suspended turn, nested Ultimate, or resume behavior is implemented.

## States and signals

The controller exposes independent `BattleFlowState`,
`CharacterAnimationState`, and `UiInteractionState` enums. Key signals are
`command_started`, `command_ready`, `target_changed`, `command_confirmed`,
`command_committed`, `command_execution_started`, `command_resolved`,
`command_cancelled`, `command_failed`, and `flow_state_changed`.

The implemented path is:

`COMMAND_SELECT -> COMMAND_READY_IDLE -> TARGET_SELECT -> COMMAND_CONFIRM -> ACTION_EXECUTION -> DAMAGE_AND_EFFECT_RESOLUTION -> ACTION_RECOVERY`

Victory and defeat are terminal input-locked states.

## Existing presentation reuse

The debug adapter subclasses `BattleManager` and reuses existing Takashi frame
arrays, movement, Basic/Skill/Ultimate VFX, SFX, battle music, camera behavior,
floating damage, combatant hit feedback, damage constants, SP rules, Energy
rules, and legacy enemy action. The ready pose loops existing action frames;
the command model has no dependency on those textures or animation timing.

## Debug controls

- Existing Basic, Skill, and Ultimate buttons create pending commands.
- Previous/next switches between Lesser Abyss and Abyss Echo.
- Confirm commits; Cancel returns without a side effect.
- Fill Energy enables turn-owned Ultimate testing.
- Invalidate Target proves final target revalidation.
- `enemy_turn_enabled` can disable the enemy turn for deterministic capture.

## Verification

Automated contract test:

`godot --headless --path . --script res://tests/battle/test_battle_command_flow.gd`

Scene integration test:

`godot --headless --path . res://tests/battle/test_battle_command_debug_scene.tscn`

Visual capture runner:

`godot --path . res://tests/battle/capture_battle_command_flow.tscn -- --capture-size=1280x720`

Screenshots cover command select, Basic ready, target switching, confirm/cancel,
cancelled, Skill ready, Ultimate ready, execution, and recovery under
`docs/images/battle_command_flow/1280x720` and `1920x1080`.

## Migration boundary

Production `BattleManager` now creates a `BasicAttackCommandAdapter` at runtime
when `use_new_basic_command_flow` is enabled. The flag defaults to true and is
read through one helper in `battle_manager.gd`; setting it false keeps the
legacy immediate Basic Attack fallback.

The adapter owns only Basic pending/commit. It provides the actor, target
candidates, final validation, and no-cost commit callback to
`BattleCommandFlow`. `BattleManager` still owns all authoritative Basic
execution: movement, frame animation, VFX, SFX, damage, hit feedback, camera
shake, SP reward, Energy gain, recovery, enemy turn, victory, return scene, and
`WorldProgress`.

> As of Block 8.5, production Basic flow no longer has a ready idle or
> confirm/cancel step. See "Block 8.5 adds a fast Basic Attack flow" below for
> the current flow; the paragraphs immediately below this note describe the
> Block 6 behavior for historical context only.

Block 6 production Basic flow was:

`PLAYER_TURN -> COMMAND_SELECT -> BASIC_READY_IDLE -> TARGET_SELECT -> CONFIRM/CANCEL -> ACTION_EXECUTION -> DAMAGE_AND_EFFECT_RESOLUTION -> ACTION_RECOVERY -> legacy turn completion`

Cancel cleared the pending command, target highlight, and confirm/cancel panel;
it restored Takashi idle and did not deal damage, grant SP, spend resources,
play impact effects, move the turn, or trigger enemy AI. Confirm validated the
actor, target, battle state, active action token, and target liveness before
commit. Execution and resolution used the controller commit token plus local
recovery/turn-completion token dictionaries to reject duplicate confirm,
execution, damage, recovery, and turn completion. All of this except the
ready-idle/confirm-panel presentation is still true after Block 8.5 — see
below.

Target selection currently uses every live production `Combatant` child under
the battle scene except the player. Lesser Abyss and Bandit Captain each expose
one live target today, so target switching is future-ready but has no alternate
production target until an encounter adds more live enemy combatants.

Block 7 adds `SkillCommandAdapter` and `use_new_skill_command_flow`. The flag
defaults to true and is read through `_uses_new_skill_command_flow()`. Setting
it false keeps the legacy Skill fallback, including the old timing where Skill
Point is spent before cast feedback.

Production Skill flow is:

`PLAYER_TURN -> COMMAND_SELECT -> SKILL_READY_IDLE -> TARGET_SELECT -> CONFIRM/CANCEL -> RESOURCE_REVALIDATION -> COMMIT/SPEND_SP -> ACTION_EXECUTION -> DAMAGE_AND_EFFECT_RESOLUTION -> ACTION_RECOVERY -> legacy turn completion`

Pressing Skill now creates one pending `SKILL` command for `triangle_rift` with
`SINGLE_ENEMY` targeting and the existing `SKILL_POINT_COST_SKILL`. Select,
ready idle, target selection, and cancel do not spend Skill Point, deal damage,
play impact VFX/SFX, move Takashi, move the turn, or trigger enemy AI. Confirm
revalidates battle state, actor liveness, target liveness, active Basic/Skill
tokens, and current SP before commit.

The commit callback is the only new-flow place that mutates Skill Point. It
spends the quoted cost exactly once, then locks confirm/cancel input. Existing
Triangle Rift execution remains authoritative for Skill cast feedback, Takashi
movement, projectile, release/impact SFX, rift VFX, camera shake, one
`SKILL_DAMAGE` hit, hit feedback, `SKILL_ENERGY` gain, victory, enemy turn,
return scene, and `WorldProgress`.

Triangle Rift is single-hit today and applies no status effect. The production
Skill path still records hit index `0` against the command token so duplicate
callbacks cannot apply the same hit twice. The model remains compatible with
future multi-hit/status actions by adding more hit indexes without changing the
commit boundary.

Command switching uses the same rule for normal commands: choosing Basic while
Skill is pending cancels Skill first, then starts Basic; choosing Skill while
Basic is pending cancels Basic first, then starts Skill. Only one pending player
command and one active committed command are allowed.

Block 8 adds `UltimateCommandAdapter` and `use_new_ultimate_command_flow`. The
flag defaults to true and is read through `_uses_new_ultimate_command_flow()`.
Setting it false keeps the legacy Ultimate fallback, including the old timing
where Energy is zeroed synchronously on button press before any cut-in,
camera, or animation starts.

Production Ultimate flow is:

`PLAYER_TURN -> COMMAND_SELECT -> ULTIMATE_READY_IDLE -> TARGET_SELECT -> CONFIRM/CANCEL -> ENERGY_REVALIDATION -> COMMIT/SPEND_ENERGY -> ULTIMATE_CUT_IN -> ULTIMATE_EXECUTION -> DAMAGE_AND_EFFECT_RESOLUTION -> ULTIMATE_RECOVERY -> legacy turn completion`

Pressing Ultimate now creates one pending `ULTIMATE` command for
`octagram_fragment` with `SINGLE_ENEMY` targeting and an Energy cost of
`MAX_ULTIMATE_ENERGY`. Select, ready idle, target selection, and cancel do not
spend Energy, start the cut-in, run the camera cinematic, deal damage, play
impact VFX/SFX, move the turn, or trigger enemy AI. Ready idle reuses the
existing static `UltiTaka.png` Ultimate pose; it does not consume the
`u1`-`u3` pre-animation frames, which remain reserved for the cut-in itself.
Confirm revalidates battle state, actor liveness, target liveness, active
Basic/Skill/Ultimate tokens, and current Energy before commit.

The commit callback is the only new-flow place that mutates Energy. It spends
`MAX_ULTIMATE_ENERGY` exactly once, then locks confirm/cancel input. This
fixes the Block 7 characterization finding that legacy Ultimate zeroed Energy
the instant the button was pressed, before the cut-in, camera zoom, or any
animation had started. Existing Octagram Fragment execution remains
authoritative for cut-in frame playback, camera zoom-in/zoom-out, Takashi
pre/post animation, FVX buildup, VFX, SFX, one `ULTIMATE_DAMAGE` hit, hit
feedback, recovery, victory, enemy turn, return scene, and `WorldProgress`.

The legacy Ultimate body (previously inline in `_on_ultimate_pressed`) was
extracted into a shared `_run_ultimate_sequence(target, command = null)`
function, following the same pattern already used for
`_resolve_basic_attack` and `_execute_triangle_rift`: the legacy fallback
calls it with `command == null` and a hardcoded `enemy` target, while the new
flow calls it with the committed command and the resolved target. Guard
checks that used to test `state != BattleState.ACTION_RESOLUTION` directly
now route through `_ultimate_execution_guard()`, which behaves identically
for the legacy path and additionally checks command/token identity for the
new path. No animation timing, camera behavior, SFX, or damage value changed.

Octagram Fragment is single-hit today and applies no status effect. The
production Ultimate path still records hit index `0` against the command
token so duplicate callbacks cannot apply the same hit twice. The
`_play_enemy_octagram_impact()` VFX helper remains hardcoded to the `enemy`
node (as it was pre-migration) rather than an arbitrary resolved target;
since Lesser Abyss and Bandit Captain each expose exactly one live enemy
target today, this is behaviorally identical to using the selected target.

Command switching uses the same rule as Basic/Skill: choosing Ultimate while
Basic or Skill is pending cancels the old pending command first, then starts
Ultimate; choosing Basic or Skill while Ultimate is pending cancels Ultimate
first, then starts the new command. Only one pending player command and one
active committed command are allowed across all three command types.

`PendingBattleCommand.RequestSource.INTERRUPT_REQUEST` is rejected by the
shared `BattleCommandFlow.begin_command()` with
`off_turn_interrupt_not_available` regardless of command type. Block 8 does
not implement any off-turn Ultimate request, FIFO interrupt queue, or
suspended battle context; `UltimateCommandAdapter.begin_ultimate()` accepts an
explicit `request_source` parameter (defaulting to `TURN_COMMAND`) purely so
Block 9 can add an off-turn caller without changing the command model.

## Block 8.5 adds a fast Basic Attack flow

`BattleCommandFlow.begin_command()` gained three optional trailing
parameters: `requires_ready_idle`, `requires_confirm`, and
`auto_commit_on_target_selected` (defaults `true`, `true`, `false`). They are
copied onto the `PendingBattleCommand` instance itself, so the rest of the
controller reads a per-command pacing rule instead of branching on command
type anywhere else. `BasicAttackCommandAdapter.begin_basic()` is the only
call site that passes `false, false, true`; `SkillCommandAdapter` and
`UltimateCommandAdapter` pass no extra arguments and are unaffected.

Inside `begin_command()`:

- `COMMAND_READY_IDLE` is entered (and `command_ready` emitted) only when
  `requires_ready_idle` is true. Basic Attack skips straight from
  `command_started` to target handling.
- After a `SINGLE_ENEMY`/`SINGLE_ALLY` command auto-preselects its first
  candidate and enters `TARGET_SELECT`, if `auto_commit_on_target_selected`
  is true and there is at most one live candidate, `begin_command()` calls
  `confirm_pending_command()` itself before returning — this is the single
  live enemy path, fully synchronous with the button press.
- `set_pending_target()` and `set_pending_targets()` each call
  `confirm_pending_command()` immediately after a successful selection when
  `auto_commit_on_target_selected` is true — this is what makes multi-enemy
  target selection commit the instant a target is chosen, whether selection
  came from a mouse click, the existing keyboard target-cycle helpers, or the
  shared confirm/interact key.

This keeps the "when does Basic commit" decision in exactly two places inside
`battle_command_flow.gd`, rather than special-casing Basic anywhere in
`battle_manager.gd`. Every existing Basic target-selection call site
(`_cycle_basic_target`, `_select_basic_target_at_position`,
`_repair_basic_pending_target`) needed zero changes — they already called
`basic_command_adapter.select_target(...)`, which now auto-commits
transparently.

`battle_manager.gd` changes for Basic:

- Removed: the Basic ready-idle texture switch (`_start_basic_ready_idle`),
  its signal handler (`_on_basic_command_ready`, and the now-unreachable
  `basic_ready` signal connection), and the entire Basic confirm/cancel panel
  — construction, style, visibility toggle, and label/target-text update
  functions, plus their four `Control` node variables
  (`basic_command_panel`, `basic_ready_label`, `basic_target_label`,
  `basic_confirm_button`, `basic_cancel_button`).
- Unchanged: `basic_target_highlight` and its create/show/hide/sync
  functions, now used only for the multi-enemy target-selection window;
  `_confirm_basic_attack_command()` and `_cancel_basic_attack_command()`,
  which remain reachable through the shared `_on_confirm_pressed()` router
  and `ui_cancel` input respectively — the former now only matters as a
  keyboard/interact shortcut to commit the currently-cycled target during
  multi-enemy selection, since there is no confirm panel to click.
- `_on_basic_command_target_changed` now only shows the target highlight and
  a `"Select target"` battle-log line when `command.candidate_targets.size()
  > 1`; for a single live enemy it is a no-op, since the command has already
  committed by the time the signal fires.
- `_execute_committed_basic_attack` and the entire authoritative Basic
  execution path (`_resolve_basic_attack` and everything it calls) are
  unchanged: movement, VFX, SFX, damage, hit feedback, camera shake, SP
  reward, recovery, victory, enemy turn, return scene, and `WorldProgress`.

Command switching rules are unchanged in wording (selecting any command
while another is pending cancels the old pending command first, then starts
the new one) — Block 8.5 required no new code for this, because a committed
Basic command already fails `cancel_pending_command()`'s state guard
(`battle_state` is `ACTION_EXECUTION`, not one of the cancellable states),
and the existing `_has_pending_basic_command() and not
_cancel_basic_attack_command(): return` guards in `_on_skill_pressed()` and
`_on_ultimate_pressed()` already handle "Basic already committed, block the
switch" correctly. The only place Basic's pending window is long enough to
switch away from is multi-enemy target selection.

Lesser Abyss and Bandit Captain each still expose exactly one live enemy, so
the multi-enemy path is covered by `BasicAttackCommandAdapter`/
`BattleCommandFlow` logic and a test-only mock second `Combatant` (spawned by
the automated tests and the visual-capture script), not by live production
encounter data.

## Block 6 Verification

Automated tests:

`godot --headless --disable-crash-handler --log-file godot-command-flow.log --path . --script res://tests/battle/test_battle_command_flow.gd`

`godot --headless --disable-crash-handler --log-file godot-production-basic.log --path . --scene res://tests/battle/test_production_basic_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-debug-scene.log --path . --scene res://tests/battle/test_battle_command_debug_scene.tscn`

`godot --headless --disable-crash-handler --log-file godot-bandit-startup.log --path . --scene res://tests/battle/test_bandit_battle_startup.tscn`

Startup smoke tests also passed for Login, Prologue, and Lesser Abyss battle
scenes with `--quit-after`.

Visual capture runner:

`godot --disable-crash-handler --log-file godot-capture-1280.log --resolution 1280x720 --windowed --path . --scene res://tests/battle/capture_production_basic_command_flow.tscn -- --capture-size=1280x720`

`godot --disable-crash-handler --log-file godot-capture-1920.log --resolution 1920x1080 --windowed --path . --scene res://tests/battle/capture_production_basic_command_flow.tscn -- --capture-size=1920x1080`

Production screenshots are stored under
`docs/images/battle_command_flow/production_basic/1280x720` and `1920x1080`.
They cover Lesser Abyss command select, Basic ready, target select,
confirm/cancel, cancelled, action execution, Bandit target select, and Basic
victory.

Known limitations:

- Headless capture cannot read a viewport texture with Godot's dummy renderer;
  visual capture requires windowed Godot.
- Godot on this Windows machine needs `--log-file` to avoid a `user://logs`
  startup crash in headless mode.
- Existing Godot tests report ObjectDB/resource leak warnings on exit. They are
  present in Block 5 scene tests too and are not caused by Basic command
  assertions.
- Production Bandit currently has one live enemy target, so multi-target
  switching remains adapter-ready but not visually demonstrated by encounter
  data.

Block 6 migration target is complete in Block 7: production Skill now uses the
same adapter boundary without changing damage, SP cost, Energy gain, enemy AI,
story, `WorldProgress`, `MusicDirector`, or `SceneTransition`.

## Block 7 Verification

Automated tests:

`godot --headless --disable-crash-handler --log-file godot-command-flow.log --path . --script res://tests/battle/test_battle_command_flow.gd`

`godot --headless --disable-crash-handler --log-file godot-production-basic.log --path . --scene res://tests/battle/test_production_basic_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-production-skill.log --path . --scene res://tests/battle/test_production_skill_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-debug-scene.log --path . --scene res://tests/battle/test_battle_command_debug_scene.tscn`

`godot --headless --disable-crash-handler --log-file godot-bandit-startup.log --path . --scene res://tests/battle/test_bandit_battle_startup.tscn`

Startup smoke tests should continue to cover Login, Prologue, Lesser Abyss, and
Bandit Captain startup with `--quit-after`.

Visual capture runner:

`godot --disable-crash-handler --log-file godot-skill-capture-1280.log --resolution 1280x720 --windowed --path . --scene res://tests/battle/capture_production_skill_command_flow.tscn -- --capture-size=1280x720`

`godot --disable-crash-handler --log-file godot-skill-capture-1920.log --resolution 1920x1080 --windowed --path . --scene res://tests/battle/capture_production_skill_command_flow.tscn -- --capture-size=1920x1080`

Production Skill screenshots are stored under
`docs/images/battle_command_flow/production_skill/1280x720` and `1920x1080`.
They cover Lesser Abyss command select, Skill ready, target select,
confirm/cancel, cancelled, action execution, damage resolution, recovery, Bandit
Skill target selection, and Bandit victory.

Known Block 7 limitations:

- Production Skill currently has one live target in Lesser Abyss and Bandit
  Captain, so target cycling is covered by the adapter but not visually
  differentiated by encounter data.
- Triangle Rift is characterized as single-hit with no status effect. The hit
  guard is ready for additional hit indexes but no multi-hit/status migration is
  needed yet.
- Ultimate remains the highest-risk migration because it owns camera,
  full-screen cinematic state, Energy spend timing, and return-to-battle UI
  restoration in one await chain.

Next migration step: Block 8 should add broader characterization around the
legacy on-turn Ultimate path, then migrate only on-turn Ultimate to the command
boundary before considering any off-turn interrupt queue.

## Block 8 characterization of legacy Ultimate

Before migration, the legacy `_on_ultimate_pressed()` path was characterized
as follows (all preserved unchanged in the legacy fallback):

- Energy maximum: `MAX_ULTIMATE_ENERGY = 100`. Ultimate cost: all current
  Energy (only usable at exactly 100).
- Energy is zeroed synchronously the instant the button is pressed, before
  the cut-in, camera zoom, or any animation starts. This is the primary
  characterized bug that Block 8 fixes for the new flow only.
- The button is enabled only when `state == PLAYER_TURN` and
  `ultimate_energy >= MAX_ULTIMATE_ENERGY` (via `_update_action_buttons`).
- Target: always the single `enemy` combatant; no target selection UI existed.
- Damage: `ULTIMATE_DAMAGE = 45`, single hit, no status effect.
- Cut-in: camera zoom-in, Takashi Ultimate FVX glow intro, `u1`-`u3`
  pre-animation frames, remaining zoom wait, then the full 88-frame
  `takashi_ultimate_%03d.jpg` sequence (`ULTIMATE_FRAME_RATE = 15`) played
  full-screen over `UltimateFramePlayer`.
- Camera: dedicated zoom-in/zoom-out tweens plus a second zoom-in/zoom-out
  pair around the enemy octagram impact.
- Character movement: `player.play_skill_movement(enemy)` reused from Skill.
- Animation: `u4`-`u7` post-animation frames, plus Takashi ultimate pose
  texture (`UltiTaka.png`).
- VFX/SFX: shatter, glass burst, cring noise, deep boom, zoom whoosh, charge
  rumble, octagram wind/chime, enemy hit stingers, screen flash, camera shake.
- Hit feedback: `enemy.play_hit_feedback()` after damage.
- Recovery: return to battle idle via `_finish_player_action`.
- Turn completion: shared `_finish_player_action()`, same as Basic/Skill.
- Victory handling: shared `_win()` / `_lose()`, same as Basic/Skill.
- UI: `_set_battle_ui_for_ultimate()` hides the whole `BattleUI` node during
  the cinematic and restores it afterward via a `battle_ui_visible_before_ultimate`
  flag; command buttons disabled during the whole sequence.
- Lesser Abyss vs. Bandit Captain: no Ultimate-specific difference beyond the
  `enemy` combatant identity/HP/background already configured by
  `_configure_encounter()`.

Characterized legacy problems (all fixed only for the new flow, not the
legacy fallback):

- Energy reduced far too early (on press, not on commit).
- No ready idle before cut-in; button press went straight into camera/FVX.
- No confirm/cancel; pressing the button was irreversible.
- No target revalidation (target was never selectable to begin with).
- No interrupt queue or suspended context (unchanged; out of scope for Block 8).

## Block 8 Verification

Automated tests:

`godot --headless --disable-crash-handler --log-file godot-command-flow.log --path . --script res://tests/battle/test_battle_command_flow.gd`

`godot --headless --disable-crash-handler --log-file godot-production-basic.log --path . --scene res://tests/battle/test_production_basic_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-production-skill.log --path . --scene res://tests/battle/test_production_skill_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-production-ultimate.log --path . --scene res://tests/battle/test_production_ultimate_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-debug-scene.log --path . --scene res://tests/battle/test_battle_command_debug_scene.tscn`

`godot --headless --disable-crash-handler --log-file godot-bandit-startup.log --path . --scene res://tests/battle/test_bandit_battle_startup.tscn`

Startup smoke tests continue to cover Login, Prologue, Lesser Abyss, and
Bandit Captain startup with `--quit-after`.

Visual capture runner:

`godot --disable-crash-handler --log-file godot-ultimate-capture-1280.log --resolution 1280x720 --windowed --path . --scene res://tests/battle/capture_production_ultimate_command_flow.tscn -- --capture-size=1280x720`

`godot --disable-crash-handler --log-file godot-ultimate-capture-1920.log --resolution 1920x1080 --windowed --path . --scene res://tests/battle/capture_production_ultimate_command_flow.tscn -- --capture-size=1920x1080`

Production Ultimate screenshots are stored under
`docs/images/battle_command_flow/production_ultimate/1280x720` and
`1920x1080`. They cover Lesser Abyss command select, Ultimate ready, target
select, confirm/cancel, cancelled, cut-in, full-screen Ultimate execution,
damage resolution, recovery, Bandit Ultimate ready/target select, and Bandit
victory.

Known Block 8 limitations:

- The full Ultimate cut-in and execution sequence is unchanged from legacy
  and takes roughly 10-15 seconds of real time (88-frame full-screen sequence
  at 15 FPS plus camera/FVX/SFX steps), so tests and captures that run it to
  completion are correspondingly slow; this is a pre-existing characteristic
  of the legacy cinematic, not something Block 8 introduced.
- Production Ultimate currently has one live target in Lesser Abyss and
  Bandit Captain, so target cycling is covered by the adapter but not
  visually differentiated by encounter data, matching the existing Basic and
  Skill limitation.
- `_play_enemy_octagram_impact()` remains hardcoded to the `enemy` node
  rather than an arbitrary resolved target (see above); this matches
  pre-migration behavior and is safe only because there is one live enemy
  target per encounter today.
- The "bandit victory" screenshot capture (for Basic, Skill, and now
  Ultimate) is taken at the instant `state == WIN` is first observed, which
  is visually similar to the pre-victory frame in this codebase's existing
  capture harness; this is a pre-existing characteristic of the capture
  script, not a Block 8 regression.

Block 8 does not implement off-turn Ultimate interrupt, a FIFO queue, or a
suspended battle context. `INTERRUPT_REQUEST` continues to be rejected with
`off_turn_interrupt_not_available`. Next migration step: Block 9 should design
the safe-interrupt-window detection and FIFO queue described in
`docs/battle_system_spec.md`, using the `request_source` parameter already
threaded through all three command adapters.

## Block 8.5 Verification

Automated tests:

`godot --headless --disable-crash-handler --log-file godot-command-flow.log --path . --script res://tests/battle/test_battle_command_flow.gd`

`godot --headless --disable-crash-handler --log-file godot-production-basic.log --path . --scene res://tests/battle/test_production_basic_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-production-skill.log --path . --scene res://tests/battle/test_production_skill_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-production-ultimate.log --path . --scene res://tests/battle/test_production_ultimate_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-debug-scene.log --path . --scene res://tests/battle/test_battle_command_debug_scene.tscn`

`godot --headless --disable-crash-handler --log-file godot-bandit-startup.log --path . --scene res://tests/battle/test_bandit_battle_startup.tscn`

Startup smoke tests continue to cover Login, Prologue, and Lesser Abyss
startup with `--quit-after`.

`test_production_basic_command_flow.gd` now covers: single-enemy auto-target
commits with no ready idle/confirm wait, a committed single-enemy Basic
cannot be cancelled, no-valid-target fails safely, spamming Basic/Skill/
Ultimate presses in a row still deals exactly one hit, a mocked two-enemy
scene enters target selection and shows a highlight, selecting one of the two
targets commits immediately and only damages that target, and cancel before
a target is chosen clears the pending command cleanly. The legacy fallback,
Skill regression, and Ultimate regression tests from Block 8 are unchanged.
`test_production_skill_command_flow.gd`'s and
`test_production_ultimate_command_flow.gd`'s Basic-switching tests were
updated to spawn the same mocked second enemy, since a single-enemy Basic
command now commits before there is anything to switch away from.

Visual capture runner:

`godot --disable-crash-handler --log-file godot-basic-capture-1280.log --resolution 1280x720 --windowed --path . --scene res://tests/battle/capture_production_basic_command_flow.tscn -- --capture-size=1280x720`

`godot --disable-crash-handler --log-file godot-basic-capture-1920.log --resolution 1920x1080 --windowed --path . --scene res://tests/battle/capture_production_basic_command_flow.tscn -- --capture-size=1920x1080`

Production Basic screenshots are stored under
`docs/images/battle_command_flow/production_basic_fast/1280x720` and
`1920x1080` (the Block 6 `production_basic/` screenshots are left in place as
a historical record of the pre-Block-8.5 ready-idle/confirm UI). They cover
Lesser Abyss command select, the frame immediately after pressing Basic
(already executing, no dialog), mid-execution, damage resolution, recovery,
Bandit command select, Bandit execution, Bandit victory, and a mocked
two-enemy scene's command select / target-select-with-highlight / target-
selected-immediate-execution frames. The mock second enemy uses a simple
colored placeholder polygon (no new character art) purely so the capture is
legible; it is not used by the automated test assertions, which only need
`Combatant.setup()`/`take_damage()`/`is_defeated()`.

Known Block 8.5 limitations:

- Basic Attack's multi-enemy target-selection path has no live production
  encounter to exercise it; it is verified only through adapter/flow logic,
  automated tests, and visual capture against a mocked second `Combatant`,
  matching the same limitation already noted for Basic/Skill/Ultimate target
  cycling in Blocks 6-8.
- Any target selection during multi-enemy Basic selection — mouse click,
  keyboard cycle, or the shared confirm/interact key — commits immediately.
  There is no "browse without committing" mode for keyboard cycling; each
  cycle step attacks the newly highlighted target. This was a deliberate
  reading of "Basic harus terasa cepat dan langsung" over building a second,
  separate confirm-only-for-keyboard path, which would have reintroduced the
  confirm step Basic is meant to no longer have.
- `_begin_basic_attack_command()` and `_begin_skill_command()` still only
  check `_has_pending_basic_command() or _has_pending_skill_command()`
  before starting (not Ultimate); this is unchanged from Block 8 and is
  harmless in practice because the router-level guards in `_on_attack_pressed()`
  and `_on_skill_pressed()` already cancel any pending Ultimate before
  reaching these functions. Not fixed here since fixing it would also touch
  `_begin_skill_command()`, and Block 8.5 must not change Skill.

Block 8.5 does not touch Skill or Ultimate flow, off-turn Ultimate interrupt,
damage formulas, SP/Energy cost or gain, AI, encounter data, story,
`WorldProgress`, `MusicDirector`, or `SceneTransition`. Next migration step:
Block 9 should design the safe-interrupt-window detection and FIFO queue
described in `docs/battle_system_spec.md`, using the `request_source`
parameter already threaded through all three command adapters.

## Block 9A: off-turn interrupt architecture (not wired to production)

Block 9A adds three new skeleton classes and three additive stub methods.
Nothing in this block changes what `battle_manager.gd`, any of the three
production adapters, or `BattleCommandFlow`'s existing methods actually do
at runtime. See `docs/battle_system_spec.md`, "Block 9A implementation
status" for the full design (characterization, safe/unsafe windows,
suspended context field table, validation layers, UI readiness, known
risks). This section covers only what changed in code.

**`suspended_battle_context.gd`** (`SuspendedBattleContext`, `RefCounted`).
Plain data snapshot plus two guard methods: `mark_resumed()` returns `true`
exactly once, `false` on every subsequent call and after `discard()`;
`discard()` is permanent. Nothing constructs one from live `BattleManager`
state yet.

**`ultimate_interrupt_request.gd`** (`UltimateInterruptRequest`,
`RefCounted`). Plain data holder for one off-turn request:
actor/action/cost/timestamps plus a `ValidationStatus` enum
(`PENDING`/`ACCEPTED`/`REJECTED`/`EXPIRED`) and `reject_reason`.
Constructing one never touches Energy or battle state.

**`ultimate_interrupt_queue.gd`** (`UltimateInterruptQueue`, `RefCounted`).
Pure FIFO queue over `UltimateInterruptRequest`. `configure()` takes three
`Callable`s (`energy_lookup`, `battle_over_lookup`, `ultimate_active_lookup`)
so the queue never reaches into `BattleManager` directly — the same
dependency-injection shape `BattleCommandFlow.configure_resource_callbacks()`
already uses. `request_ultimate()` validates and enqueues/rejects
synchronously (request-time validation); `revalidate()` re-runs the same
checks against an already-queued request (process-time validation, not
called by anything yet); `dequeue_next()`/`peek_next()` preserve FIFO;
`cancel_request_for(actor)` removes a still-queued request. No method on
this class can mutate Energy, HP, or turn state — it only reads through the
configured lookups.

**`battle_command_flow.gd` additions** — three methods appended after
`is_token_consumed()`, none of them called anywhere:
- `can_process_interrupt_now() -> bool` — always `false`. Documented inline
  as deliberately *not* a real implementation even in a future block,
  because real safe-window detection needs `BattleManager`-level state
  (whose turn it is, whether the enemy await chain is mid-flight) that this
  per-command controller does not have.
- `queue_ultimate_interrupt(request: UltimateInterruptRequest) -> bool` —
  always `false`. No queue is wired to this controller.
- `begin_interrupt_request(actor, action_id, target_rule, candidate_targets,
  energy_cost) -> bool` — always `false`. `begin_command()` remains the only
  way to start a pending command, and its first line is still the
  unconditional `if request_source == RequestSource.INTERRUPT_REQUEST:
  _fail(...); return false` check from Block 5, byte-for-byte unchanged.

No enum values were added to `BattleFlowState`, `CharacterAnimationState`,
or `UiInteractionState` — see "BattleCommandFlow impact" in
`docs/battle_system_spec.md` for why a battle-wide suspended state does not
belong on this per-command enum.

### Block 9A Verification

Automated tests:

`godot --headless --disable-crash-handler --log-file godot-command-flow.log --path . --script res://tests/battle/test_battle_command_flow.gd`

`godot --headless --disable-crash-handler --log-file godot-production-basic.log --path . --scene res://tests/battle/test_production_basic_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-production-skill.log --path . --scene res://tests/battle/test_production_skill_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-production-ultimate.log --path . --scene res://tests/battle/test_production_ultimate_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-debug-scene.log --path . --scene res://tests/battle/test_battle_command_debug_scene.tscn`

`godot --headless --disable-crash-handler --log-file godot-bandit-startup.log --path . --scene res://tests/battle/test_bandit_battle_startup.tscn`

New in Block 9A:

`godot --headless --disable-crash-handler --log-file godot-interrupt-queue.log --path . --scene res://tests/battle/test_ultimate_interrupt_queue.tscn`

`test_ultimate_interrupt_queue.gd` exercises `UltimateInterruptQueue` in
total isolation — no `BattleManager`, no scene tree beyond a couple of fake
`Node`s standing in for combatants. It covers: valid request accepted, a
second request from the same actor rejected as duplicate, insufficient
Energy rejected, a dead actor rejected, a request while the battle is
already over rejected, a request while another Ultimate is active rejected,
FIFO ordering across two actors, enqueue never spending Energy, cancel
clearing a still-queued request, and `revalidate()` catching an actor that
died after its request was already queued.

Startup smoke tests continue to cover Login, Prologue, and Lesser Abyss
startup with `--quit-after`.

Known Block 9A limitations:

- Off-turn Ultimate cannot be requested, queued, or executed through any
  production input. This is intentional — Block 9A is architecture and
  characterization only.
- The enemy turn (`_enemy_attack()`) has no guard-chain discipline
  comparable to Basic/Skill/Ultimate. Adding it is a prerequisite for any
  real interrupt window inside the enemy turn, and is explicitly deferred
  to Block 9B since it would change enemy-turn behavior, which this block
  may not do.
- `SuspendedBattleContext.camera_state` is a `Dictionary` with no
  populate/restore implementation yet; the actual camera tweens in
  `_run_ultimate_sequence()` are not wired to it.
- `ultimate_energy` is currently a single `BattleManager`-level variable,
  not actor-scoped. This has not mattered because only one character
  (Takashi) can use Ultimate today; Block 9B must confirm the scoping model
  before assuming any other actor could hold a queued request.

Block 9A does not touch Basic, Skill, Ultimate on-turn, damage formulas,
SP/Energy cost or balance, AI, encounter data, story, `WorldProgress`,
`MusicDirector`, or `SceneTransition`. `INTERRUPT_REQUEST` is still rejected
in the one place it always was. Next step: Block 9B should decide how
`BattleManager` instantiates and drains an `UltimateInterruptQueue`, add the
missing enemy-turn guard chain, and give `can_process_interrupt_now()` (or
its real replacement, likely `BattleManager`-owned) an actual
implementation — starting with window B (after enemy recovery, before next
turn), the least architecturally risky of the three candidate windows.

## Block 9B: off-turn interrupt wired to production (safe window B only)

Block 9B makes the Block 9A skeletons load-bearing. It does not rewrite
`battle_manager.gd`; every change is either a new function, an additive
optional trailing parameter with a default that preserves prior behavior
exactly, or a single-line tail replacement inside one existing function
(`_enemy_attack()`). See `docs/battle_system_spec.md`, "Block 9B
implementation status" for the full design writeup (request lifecycle,
safe window B mechanics, execution-path reuse, resume policy, known
limitations, explicit confirmations). This section covers only what
changed in code and how to verify it.

**Files changed:**

- `scripts/battle/command/battle_command_flow.gd` — `begin_command()`
  gained a 14th parameter, `interrupt_authorized: bool = false`. The
  Block 5 rejection of `RequestSource.INTERRUPT_REQUEST` now only fires
  `if ... and not interrupt_authorized`. Every existing on-turn caller
  omits the new argument and is unaffected.
- `scripts/battle/command/ultimate_command_adapter.gd` — `begin_ultimate()`
  gained a matching `interrupt_authorized: bool = false` parameter,
  forwarded positionally into `flow.begin_command()`.
- `scripts/battle/battle_ui.gd` — `set_actions_enabled()` gained a 4th
  parameter, `ultimate_interactable_override: bool = false`, letting the
  Ultimate button stay clickable during enemy turn without touching Basic
  or Skill button logic.
- `scripts/battle/battle_manager.gd` — new fields
  (`ultimate_interrupt_queue`, `is_processing_interrupt_queue`,
  `active_interrupt_request`, `interrupt_resume_token`,
  `_processed_interrupt_request_ids`), queue setup/reset wired into
  `_ready()`, `_exit_tree()`, `_reset_ultimate_command_runtime()`,
  `_win()`, `_lose()`; new functions `_setup_ultimate_interrupt_queue()`,
  `_reset_ultimate_interrupt_queue()`, `_interrupt_energy_lookup()`,
  `_is_ultimate_active_or_processing()`,
  `_can_request_off_turn_ultimate_input()`, `request_off_turn_ultimate()`,
  `_interrupt_request_failure_message()`,
  `_process_interrupt_queue_at_safe_window()`, `_begin_queued_ultimate()`,
  `_finish_interrupt_ultimate_action()`, `_is_interrupt_sourced()`,
  `_resume_after_enemy_action()`; `_enemy_attack()`'s tail call changed
  from `_begin_player_turn(log_text)` to
  `await _resume_after_enemy_action(log_text)` (only line changed in that
  function); `_on_ultimate_pressed()` now checks
  `state != BattleState.PLAYER_TURN` first and routes to
  `request_off_turn_ultimate(player)`; `_on_ultimate_command_cancelled()`
  and `_on_ultimate_command_failed()` each gained an interrupt-sourced
  branch ahead of their unchanged on-turn branch;
  `_finish_ultimate_command_resolution()` gained an `is_interrupt: bool =
  false` parameter controlling the final `_finish_interrupt_ultimate_action`
  vs `_finish_player_action` branch; `_update_action_buttons()` passes
  `_can_request_off_turn_ultimate_input()` as the new 4th argument to
  `ui.set_actions_enabled()`.

No changes to `basic_attack_command_adapter.gd`, `skill_command_adapter.gd`,
`pending_battle_command.gd`, `suspended_battle_context.gd`, damage
formulas, SP/Energy balance constants, AI, encounter data, story,
`WorldProgress`, `MusicDirector`, or `SceneTransition`.

### Block 9B Verification

Automated tests (all pre-existing suites re-run with zero modifications
required, plus one new suite):

`godot --headless --disable-crash-handler --log-file godot-command-flow.log --path . --script res://tests/battle/test_battle_command_flow.gd`

`godot --headless --disable-crash-handler --log-file godot-production-basic.log --path . --scene res://tests/battle/test_production_basic_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-production-skill.log --path . --scene res://tests/battle/test_production_skill_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-production-ultimate.log --path . --scene res://tests/battle/test_production_ultimate_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-basic-fast-flow.log --path . --scene res://tests/battle/test_basic_attack_fast_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-debug-scene.log --path . --scene res://tests/battle/test_battle_command_debug_scene.tscn`

`godot --headless --disable-crash-handler --log-file godot-bandit-startup.log --path . --scene res://tests/battle/test_bandit_battle_startup.tscn`

`godot --headless --disable-crash-handler --log-file godot-interrupt-queue.log --path . --scene res://tests/battle/test_ultimate_interrupt_queue.tscn`

New in Block 9B:

`godot --headless --disable-crash-handler --log-file godot-interrupt-integration.log --path . --scene res://tests/battle/test_ultimate_off_turn_interrupt.tscn`

`test_ultimate_off_turn_interrupt.gd` covers, against both the Lesser Abyss
and Bandit Captain encounters: off-turn request enqueues with zero side
effects; duplicate off-turn request rejected; insufficient-Energy request
rejected; dead-actor request rejected; queue clears on victory; a request
that goes stale (Energy spent elsewhere / actor state changed) between
enqueue and safe window B is discarded rather than executed; a request from
an actor that becomes invalid before window B is discarded; safe window B
cancel returns cleanly to player turn with Energy unchanged; a full safe
window B confirm flow (ready idle through recovery) with each
`BattleCommandFlow` signal firing exactly once; the same cancel-flow
regression against the Bandit Captain encounter.

Visual QA: `tests/battle/capture_ultimate_off_turn_interrupt.gd` (+
`.tscn`) captures 10 screenshots per resolution (1280x720 and 1920x1080) to
`docs/images/battle_command_flow/ultimate_off_turn_interrupt/{1280x720,1920x1080}/`:
command select, enemy turn with Ultimate queued, ready idle immediately
after enemy recovery, queued target select, queued confirm/cancel, queued
cut-in, queued execution, queued damage resolution, queued recovery, and
player turn resumed.

`godot --headless --disable-crash-handler --log-file godot-capture-interrupt.log --path . --scene res://tests/battle/capture_ultimate_off_turn_interrupt.tscn -- --capture-size=1280x720`

`godot --headless --disable-crash-handler --log-file godot-capture-interrupt.log --path . --scene res://tests/battle/capture_ultimate_off_turn_interrupt.tscn -- --capture-size=1920x1080`

Known Block 9B limitations:

- Window A (mid-enemy-action interrupt) is not implemented; a request made
  the instant enemy turn begins still waits for that enemy turn to fully
  finish before it can process.
- At most one queued request is processed per safe window B; a
  hypothetical second queued request (not reachable today — only Takashi
  has Ultimate, and duplicate requests per actor are rejected) would wait
  for the next window B.
- `ultimate_energy` remains `BattleManager`-scoped, not actor-scoped —
  unresolved carry-over from Block 9A, still not exercised by a second
  Ultimate-capable actor.
- `SuspendedBattleContext` remains unintegrated; not needed for window B,
  would be needed for window A.
- Camera/VFX state is not snapshotted around the interrupt boundary — not
  observable today since window B never interrupts a mid-flight animation.

Block 9B does not touch Basic, Skill, or on-turn Ultimate behavior beyond
the minimal reuse changes listed above; does not implement window A; does
not implement suspend/resume; does not change damage formulas, SP/Energy
balance, AI, encounter data, story, `WorldProgress`, `MusicDirector`, or
`SceneTransition`; does not overhaul battle UI. Next step: Block 9C should
decide whether window A is worth the enemy-turn guard-chain work the
Block 9A audit flagged, and whether multi-request-per-window or
actor-scoped Energy are needed before any second Ultimate-capable
character is added.

## Block 9C: enemy attack guard chain & interrupt state cleanup

Block 9C is prerequisite hardening, not a new capability. It gives
`_enemy_attack()` — previously a single ad hoc coroutine with exactly one
guard check across its whole body — the same commit-token/duplicate-
prevention discipline Basic/Skill/Ultimate already have, so a stray double
callback can never apply enemy damage twice, call `_lose()` twice, or call
`_resume_after_enemy_action()` twice. See `docs/battle_system_spec.md`,
"Block 9C implementation status" for the full design writeup (token model
table, guard predicates, guard-point placement, technical-debt decision on
the `state = PLAYER_TURN` bridge). This section covers only what changed
in code and how to verify it.

**Files changed:**

- `scripts/battle/battle_manager.gd` — new fields
  (`active_enemy_attack_token`, `enemy_hit_tokens`, `enemy_recovery_tokens`,
  `enemy_turn_completion_tokens`, `enemy_action_in_progress`,
  `_enemy_attack_token_sequence`); new guard/consume/reset functions
  (`_is_committed_enemy_attack`, `_enemy_attack_guard`,
  `_enemy_recovery_guard`, `_enemy_turn_completion_guard`,
  `_consume_enemy_hit`, `_consume_enemy_recovery`,
  `_consume_enemy_turn_completion`, `_clear_enemy_attack_token`,
  `_reset_enemy_attack_runtime`); `_enemy_attack()` rewritten internally to
  generate a token and check/consume it at four points (movement complete,
  hit-feedback complete, before `_lose()`, before
  `_resume_after_enemy_action()`) — damage value, movement calls, SFX/VFX
  calls, and await ordering are unchanged; `_exit_tree()`,
  `_reset_battle_values()`, `_win()`, `_lose()` each gained one call to
  `_reset_enemy_attack_runtime()`; `_process_interrupt_queue_at_safe_window()`
  gained one additional defensive condition
  (`or enemy_action_in_progress`) alongside its existing
  `is_processing_interrupt_queue` check.

No changes to `battle_command_flow.gd`, any command adapter,
`pending_battle_command.gd`, `suspended_battle_context.gd`,
`ultimate_interrupt_queue.gd`, `ultimate_interrupt_request.gd`,
`battle_ui.gd`, damage formulas, enemy damage/balance, AI, encounter data,
story, `WorldProgress`, `MusicDirector`, or `SceneTransition`. Basic,
Skill, on-turn Ultimate, and Block 9B's safe-window-B behavior are
unchanged — verified by full regression below, not just by inspection.

### Block 9C Verification

Automated tests (all pre-existing suites re-run with zero modifications
required, plus one new suite):

`godot --headless --disable-crash-handler --log-file godot-production-basic.log --path . --scene res://tests/battle/test_production_basic_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-production-skill.log --path . --scene res://tests/battle/test_production_skill_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-production-ultimate.log --path . --scene res://tests/battle/test_production_ultimate_command_flow.tscn`

`godot --headless --disable-crash-handler --log-file godot-interrupt-queue.log --path . --scene res://tests/battle/test_ultimate_interrupt_queue.tscn`

`godot --headless --disable-crash-handler --log-file godot-interrupt-integration.log --path . --scene res://tests/battle/test_ultimate_off_turn_interrupt.tscn`

`godot --headless --disable-crash-handler --log-file godot-debug-scene.log --path . --scene res://tests/battle/test_battle_command_debug_scene.tscn`

`godot --headless --disable-crash-handler --log-file godot-bandit-startup.log --path . --scene res://tests/battle/test_bandit_battle_startup.tscn`

New in Block 9C:

`godot --headless --disable-crash-handler --log-file godot-enemy-guard.log --path . --scene res://tests/battle/test_enemy_attack_guard_chain.tscn`

`test_enemy_attack_guard_chain.gd` covers, mostly by driving the new
guard/consume helpers directly (the same style existing suites already use
to poke at private state via `.call()`): hit token consumed exactly once;
recovery guard requires a prior hit consumption and is itself consumed
exactly once; turn completion guard requires a prior recovery consumption
and is itself consumed exactly once; a stale token (superseded by a newer
attack) fails all three guards even though its own hit/recovery history is
still present; victory/defeat/`restart_battle()` each invalidate the token
and clear the relevant token dictionary; and one full real-attack
integration run (`_begin_enemy_turn()` through to `PLAYER_TURN`) proving
the guard chain changes nothing observable about the normal path.

Startup smoke tests continue to cover Login, Prologue, and Lesser Abyss
battle scene startup with `--quit-after`.

Visual QA capture script (new):
`tests/battle/capture_enemy_attack_guard_chain.gd` (+ `.tscn`), intended to
capture 4 screenshots per resolution to
`docs/images/battle_command_flow/enemy_attack_guard_chain/{1280x720,1920x1080}/`
(normal enemy attack with no queue, enemy attack with a queued Ultimate,
queued Ultimate ready idle after enemy recovery, player turn resumed after
the queued Ultimate finishes). **Could not be captured this session** — see
"Known limitations" below.

`godot --headless --disable-crash-handler --log-file godot-capture-enemy-guard.log --path . --scene res://tests/battle/capture_enemy_attack_guard_chain.tscn -- --capture-size=1280x720`

`godot --headless --disable-crash-handler --log-file godot-capture-enemy-guard.log --path . --scene res://tests/battle/capture_enemy_attack_guard_chain.tscn -- --capture-size=1920x1080`

Known Block 9C limitations:

- Window A is still not implemented; this block only made the enemy attack
  safe to eventually interrupt, it did not add an interrupt point inside
  it.
- The `state = PLAYER_TURN` bridge in `_begin_queued_ultimate()` (Block 9B)
  remains, kept deliberately per the user's explicit allowance — see
  `docs/battle_system_spec.md`'s "Temporary PLAYER_TURN bridge" section for
  why removing it is riskier than keeping it, and what a future block
  needs before it can be removed.
- Visual QA screenshots for this block were not captured: the headless
  screenshot pipeline failed with a persistent `texture_2d_get: Parameter
  "t" is null` / dummy-rendering-backend error. This was confirmed
  environmental rather than a Block 9C regression by reproducing the
  identical failure against the pre-existing, previously-working Block
  8/9B capture scripts (`capture_production_ultimate_command_flow.gd`,
  `capture_ultimate_off_turn_interrupt.gd`) in the same session, and by
  trying an explicit `--rendering-driver opengl3` override with no change
  in outcome. All non-visual verification (automated tests, full
  regression, startup smoke) passed cleanly in the same session, both
  before and after this failure was encountered, confirming the engine
  itself was otherwise healthy. The capture script and output directory
  are ready to run once headless screenshot capture recovers.

Block 9C does not touch Basic, Skill, or on-turn Ultimate behavior; does
not implement window A; does not implement mid-action suspend/resume; does
not change damage formulas, enemy damage/balance, AI, encounter data,
story, `WorldProgress`, `MusicDirector`, or `SceneTransition`; does not
overhaul battle UI; does not rewrite `battle_manager.gd`. Next step: Block
9D should decide whether window A is now worth attempting given the guard
chain this block added, or whether further hardening (e.g. giving the
enemy attack its own `PendingBattleCommand`) should come first.
