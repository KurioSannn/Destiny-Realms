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
- Selecting a command is not the same as executing it.
- Target selection and confirmation happen before damage and resource spending.
- Animation state, UI state, battle flow, and effect resolution are separate
  responsibilities.
- Existing damage values, enemy behavior, encounter outcomes, and cinematic
  sequences remain authoritative until an explicit balance or content pass.

## Ready idle pillar

Ready idle is a gameplay presentation state, not decoration. After a Basic
Attack, Skill, or Ultimate is selected, the actor visibly enters a pose that
communicates the pending command. The player can select a target, confirm, or
cancel without triggering damage.

Cancel returns the actor to battle idle and restores command selection without
spending resources. Confirm commits the action, locks unsafe input, and starts
execution.

## Ultimate interrupt pillar

Ultimate Energy exists only in battle. A character with enough Energy may
request an Ultimate outside their normal turn. Requests enter a duplicate-free
FIFO queue and execute only at a safe interrupt window.

The active atomic action phase finishes first. The battle then stores the
suspended context, resolves queued Ultimates without allowing an Ultimate to
interrupt another Ultimate, and restores the original turn exactly once.

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

