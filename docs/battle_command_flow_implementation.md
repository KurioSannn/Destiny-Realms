# Battle Command Flow Implementation

## Scope

Block 5 is a vertical slice for normal player-turn commands. It proves pending
command ownership and the commit boundary while keeping every production battle
scene on the existing `BattleManager` behavior.

Block 6 integrates the new command flow into production only for Basic Attack.
Skill and Ultimate remain on the legacy `BattleManager` path.

Run the isolated scene with F6:

`res://scenes/battle/debug/battle_command_flow_debug.tscn`

## Ownership

| File | Responsibility |
| --- | --- |
| `scripts/battle/command/pending_battle_command.gd` | Immutable command identity plus mutable pending/commit lifecycle data |
| `scripts/battle/command/battle_command_flow.gd` | Battle, animation, and UI state transitions; validation and commit boundary |
| `scripts/battle/command/basic_attack_command_adapter.gd` | Production Basic Attack bridge from `BattleManager` to `BattleCommandFlow` |
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

Skill and Ultimate remain legacy in Block 6. If Skill or Ultimate is selected
while Basic is pending, Basic is cancelled safely first, then the legacy command
continues if its existing resource check passes. No Skill ready idle, Ultimate
ready idle, Ultimate queue, off-turn Ultimate, or suspended context exists yet.

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

Next migration step: characterize Skill resource timing and presentation in
production, then migrate Skill through the same adapter boundary without
changing damage, SP cost, Energy gain, enemy AI, story, `WorldProgress`,
`MusicDirector`, or `SceneTransition`.
