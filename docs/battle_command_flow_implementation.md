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

Run the isolated scene with F6:

`res://scenes/battle/debug/battle_command_flow_debug.tscn`

## Ownership

| File | Responsibility |
| --- | --- |
| `scripts/battle/command/pending_battle_command.gd` | Immutable command identity plus mutable pending/commit lifecycle data |
| `scripts/battle/command/battle_command_flow.gd` | Battle, animation, and UI state transitions; validation and commit boundary |
| `scripts/battle/command/basic_attack_command_adapter.gd` | Production Basic Attack bridge from `BattleManager` to `BattleCommandFlow` |
| `scripts/battle/command/skill_command_adapter.gd` | Production Skill bridge from `BattleManager` to `BattleCommandFlow` |
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

The adapter owns only Basic pending/confirm/cancel/commit. It provides the
actor, target candidates, final validation, and no-cost commit callback to
`BattleCommandFlow`. `BattleManager` still owns all authoritative Basic
execution: movement, frame animation, VFX, SFX, damage, hit feedback, camera
shake, SP reward, Energy gain, recovery, enemy turn, victory, return scene, and
`WorldProgress`.

Production Basic flow is:

`PLAYER_TURN -> COMMAND_SELECT -> BASIC_READY_IDLE -> TARGET_SELECT -> CONFIRM/CANCEL -> ACTION_EXECUTION -> DAMAGE_AND_EFFECT_RESOLUTION -> ACTION_RECOVERY -> legacy turn completion`

Cancel clears the pending command, target highlight, and confirm/cancel panel;
it restores Takashi idle and does not deal damage, grant SP, spend resources,
play impact effects, move the turn, or trigger enemy AI. Confirm validates the
actor, target, battle state, active action token, and target liveness before
commit. Execution and resolution use the controller commit token plus local
recovery/turn-completion token dictionaries to reject duplicate confirm,
execution, damage, recovery, and turn completion.

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

Ultimate is still legacy in Block 7. Choosing Ultimate while Skill is pending
cancels Skill first, then starts the existing Ultimate path if Energy is full.
Energy timing, Ultimate animation, Ultimate damage, and Ultimate scene behavior
are unchanged. There is still no Ultimate ready idle, off-turn Ultimate request,
FIFO interrupt queue, or suspended battle context.

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
