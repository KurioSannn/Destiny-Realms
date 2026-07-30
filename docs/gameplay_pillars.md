# Destiny Realms Gameplay Pillars

## Official identity

Destiny Realms is a cinematic turn-based fantasy RPG with connected 2D/2.5D
exploration areas, stylized compact anime characters, command-ready idle poses,
and energy-based off-turn Ultimates.

It is not a real-time action RPG. References to other games are used only to
discuss general principles. Their assets, layouts, characters, animations,
icons, system names, and code are not part of Destiny Realms.

## Core loop

```text
Exploration
  -> dialogue or interaction
  -> instanced cinematic turn-based battle
  -> reward and progression
  -> return to exploration
```

Each context has a distinct job. Exploration establishes place, story, and
discovery. Battle owns combat resources and tactical decisions. Dialogue owns
conversation and choices. Transitions must make the change of context legible.

## Exploration identity

- Connected 2D/2.5D areas with readable traversal and interaction.
- Ancient European fantasy, old stone roads, broad grasslands, and the Abyss
  forest; no modern London objects or technology.
- World UI stays light: location, objective, prompt, notification, and menu
  shortcuts.
- Exploration does not expose combat commands, turn order, target selection, or
  Ultimate Energy.
- HP or level may appear only after a real exploration mechanic or progression
  source owns those values.

## Battle identity

- Instanced, turn-based, and cinematic.
- Core commands are Basic Attack, Skill, and Ultimate.
- Basic Attack is a fast command: it executes immediately after an automatic
  or player-chosen target, with no ready idle or confirm step.
- Skill and Ultimate are deliberate commands: selecting one is not the same
  as executing it. Target selection and confirmation happen before damage
  and resource spending.
- Animation state, UI state, battle flow, and effect resolution are separate
  responsibilities.
- Existing damage values, enemy behavior, encounter outcomes, and cinematic
  sequences remain authoritative until an explicit balance or content pass.

## Command pacing pillar

Not every command earns the same ceremony. Basic Attack is the action players
reach for every turn, so it must feel instant and keep battle moving. Skill
and Ultimate are heavier, more strategic choices with a real resource cost, so
they earn a ready idle and an explicit confirm/cancel step before anything
happens. All three share the same underlying pending-command architecture
(actor, target, commit token, resolution, recovery); only their player-facing
pacing differs.

**Basic Attack** — fast command:
- No ready idle.
- No confirm/cancel step.
- A single live enemy is targeted automatically and the attack executes
  immediately.
- Multiple live enemies enter a brief target-select step; choosing a target
  commits immediately, with no separate confirm.

**Skill** — deliberate command:
- Ready idle.
- Target selection.
- Confirm/cancel.
- Commits its Skill Point cost, then executes.

**Ultimate** — deliberate command:
- Ready idle.
- Target selection.
- Confirm/cancel.
- Commits its Energy cost, then plays a cut-in, then executes.

For Skill and Ultimate, cancel returns the actor to battle idle and restores
command selection without spending resources; confirm commits the action,
locks unsafe input, and starts execution. Basic Attack has no cancel step
once a single live enemy is targeted, since selection and commit happen in
the same instant; with multiple live enemies, cancel is only available before
a target is chosen.

## Ultimate interrupt pillar

Ultimate Energy exists only in battle. A character with enough Energy may
request an Ultimate outside their normal turn. Requests enter a duplicate-free
FIFO queue and execute only at a safe interrupt window.

The active atomic action phase finishes first. The battle then stores the
suspended context, resolves queued Ultimates without allowing an Ultimate to
interrupt another Ultimate, and restores the original turn exactly once.

This pillar is partially reality as of Block 9B. Requesting Ultimate during
the enemy's turn is now possible from the production Ultimate button: the
request joins the FIFO queue with no immediate effect, and is resolved
automatically the moment the enemy's action and recovery finish — before
the player would otherwise regain control. The queued Ultimate reuses the
exact on-turn ready idle/target/confirm/cancel/cut-in experience Skill and
Ultimate already have; off-turn changes *when* an Ultimate can begin, never
what pressing it feels like once the safe window arrives.

What remains player-facing intent, not yet reality: interrupting *during*
the enemy's action itself (rather than waiting for it to finish), and true
suspend/resume of a mid-flight atomic phase. Block 9A's
`SuspendedBattleContext` skeleton still exists but is unused — the one safe
window implemented so far (after enemy recovery, before the next turn)
never needs to suspend anything mid-flight, since nothing is in progress at
that instant. See `docs/battle_system_spec.md`, "Block 9B implementation
status" for the current design, what changed since Block 9A, and what
remains for later blocks.

Block 9C changes nothing a player can see or feel — it gave the enemy's
attack the same internal duplicate-prevention guarantees the player's
commands already had, as groundwork for someday interrupting *during* an
enemy action rather than only after it finishes. See
`docs/battle_system_spec.md`, "Block 9C implementation status".

## Visual character direction

- Stylized compact anime proportions.
- Semi-deformed anime proportions.
- Head slightly larger than realistic anatomy, but not extreme chibi.
- Clear silhouette, readable expression, and compact stage footprint.
- Player and enemy art should share comparable proportions, line treatment,
  lighting, and detail density.

## Not part of Destiny Realms

- Real-time action combat in exploration.
- Permanent exploration Attack, Skill, Ultimate, Dodge, Energy, target, or turn
  controls.
- Modern technology or literal modern London landmarks.
- Extreme chibi or fully realistic character anatomy.
- Unconfirmed resource spending or button-press damage.
- Mid-frame or mid-damage Ultimate interruption.
- Copying a reference game's visual or technical implementation.

