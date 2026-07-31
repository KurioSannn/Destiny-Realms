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
  as executing it. Ready idle and target selection happen before damage
  and resource spending — committing (pressing the command again or
  clicking the target) is a distinct, deliberate second input, but as of
  Block 9E that commit is not gated behind a separate confirm/cancel panel.
- Animation state, UI state, battle flow, and effect resolution are separate
  responsibilities.
- Existing damage values, enemy behavior, encounter outcomes, and cinematic
  sequences remain authoritative until an explicit balance or content pass.

## Command pacing pillar

Not every command earns the same ceremony. Basic Attack is the action players
reach for every turn, so it must feel instant and keep battle moving. Skill
and Ultimate are heavier, more strategic choices with a real resource cost, so
they earn a ready idle and a target-selection step before anything happens.
As of Block 9E, none of the three commands gate their commit behind a
separate confirm/cancel panel — committing is always either an immediate
auto-commit (Basic, single enemy), a target click, or pressing the same
command a second time. All three share the same underlying pending-command
architecture (actor, target, commit token, resolution, recovery); only
their player-facing pacing differs.

**Basic Attack** — fast command:
- No ready idle.
- A single live enemy is targeted automatically and the attack executes
  immediately.
- Multiple live enemies enter a brief target-select step; choosing a target
  commits immediately.

**Skill** — deliberate command:
- Ready idle, with a target already auto-selected.
- Pressing Skill again, or clicking the target, commits its Skill Point
  cost, then executes.
- No confirm/cancel panel.

**Ultimate** — deliberate command:
- Ready idle, with a target already auto-selected. Identical whether
  reached on-turn or via an off-turn queued request resolving at safe
  window B.
- Pressing Ultimate again, or clicking the target, commits its Energy
  cost, then plays a cut-in, then executes.
- No confirm/cancel panel.

For Skill and Ultimate, pressing a *different* command (or Escape/Back)
while one is pending cancels it — returning the actor to battle idle and
default command selection without spending resources — but does **not**
also start the newly-pressed command in that same input; the player must
press it again. Once committed, a command cannot be cancelled and a
different command is ignored until recovery completes. Basic Attack has no
cancel step once a single live enemy is targeted, since selection and
commit happen in the same instant; with multiple live enemies, cancel is
only available before a target is chosen.

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
exact on-turn ready idle/target/commit/cut-in experience Skill and
Ultimate already have (as of Block 9E, with no confirm/cancel panel
either); off-turn changes *when* an Ultimate can begin, never what
pressing it feels like once the safe window arrives.

What remains player-facing intent, not yet reality: interrupting *during*
the enemy's action itself — while it is actually moving, striking, or
resolving damage (rather than only before it starts, or after it fully
finishes) — and true suspend/resume of a mid-flight atomic phase. Block
9A's `SuspendedBattleContext` skeleton still exists but is unused — none
of the safe windows implemented so far ever need to suspend anything
mid-flight, since each one sits at a boundary between phases, not inside
one. See `docs/battle_system_spec.md`, "Block 9B implementation status"
for the current design, what changed since Block 9A, and what remains for
later blocks.

Block 9C changes nothing a player can see or feel — it gave the enemy's
attack the same internal duplicate-prevention guarantees the player's
commands already had, as groundwork for someday interrupting *during* an
enemy action rather than only after it finishes. See
`docs/battle_system_spec.md`, "Block 9C implementation status".

Block 9D also changes nothing a player can see or feel. It is the
stabilization pass that locks everything above as production-ready: the
off-turn Ultimate request, the safe-window-B queue, and the return to a
normal player turn afterward all behave exactly as already described in
this pillar, now with an internal audit confirming there is no path where
a queued Ultimate resolves twice, leaves stray state behind, or skips the
player's next turn. See `docs/battle_system_spec.md`, "Block 9D
implementation status" for the audit and "Final Block 9 feature boundary"
for the complete, current scope of this pillar.

Block 9E changes something small but real here: the queued Ultimate's
ready idle at safe window B no longer shows a confirm/cancel panel,
matching on-turn Ultimate's revised UX exactly (see "Command pacing
pillar" above). Pressing Ultimate again or clicking the target commits;
pressing Basic/Skill or Escape/Back cancels and resumes a normal player
turn. The resume policy itself (queued Ultimate never taking the next
player turn) is unchanged from Block 9B/9D. See
`docs/battle_system_spec.md`, "Block 9E implementation status".

Block 9F is the first real expansion of this pillar since Block 9B: a
queued Ultimate can now resolve *before* the enemy's own attack starts
(safe window A1), not only after it finishes (safe window B). A
well-timed off-turn request can beat the enemy to the punch entirely —
if it defeats the enemy, the enemy's attack never happens at all; if the
enemy survives, its attack still proceeds normally right afterward,
exactly as if nothing had been queued. The ready idle/target/commit/
cut-in experience is identical whichever window the request resolves at
— no confirm/cancel panel either way, unchanged from Block 9E. What still
remains player-facing intent, not yet reality, narrows further: only
interrupting the enemy *while it is actually acting* (mid-movement or
mid-damage) is left. See `docs/battle_system_spec.md`, "Block 9F
implementation status".

Block 9G changes nothing a player can see or feel today — no shipped
encounter has two live enemies yet. It is a hardening pass proving that
*when* a multi-enemy encounter exists, Basic/Skill/Ultimate targeting,
resource spending, and victory detection already behave correctly: each
command hits only the enemy actually chosen, a dying target is never
silently swapped for another, and defeating one of several enemies
correctly does not end the battle early. See
`docs/battle_system_spec.md`, "Block 9G implementation status".

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

