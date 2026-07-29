# Destiny Realms UI Context Rules

## Context ownership

Only one primary gameplay context owns input at a time. Exploration, battle,
dialogue, and menus may share the global theme, but they do not share command
ownership or combat data.

## Exploration HUD

Allowed:

- Location and area name.
- Current objective.
- Interaction prompt.
- Queued notification.
- Character, Inventory, Quest, Map, and Settings shortcuts.
- Optional lightweight portrait and name when backed by real context.

Not allowed:

- Basic Attack, Skill, Ultimate, or Dodge.
- Ultimate Energy, Skill Points, or other battle-only resources.
- Turn order, enemy HP, target selector, buff, or debuff.
- Placeholder HP or level presented as final runtime data.

Current decision: `CharacterStatus` is hidden by default. Its reusable bar API
is retained and can be enabled explicitly through
`set_character_status_visible(true)` in a valid future context or isolated UI
preview.

## Battle HUD

Allowed and expected:

- Basic Attack, Skill, and Ultimate commands.
- Per-character Energy and command costs.
- Turn order and active actor.
- Player and enemy status.
- Target selector and target validity.
- Buff/debuff feedback.
- Ready-idle command feedback.
- Off-turn Ultimate availability and queued-request feedback.
- Confirm, cancel, pause, and battle outcome controls.

The battle HUD observes battle state. It may request actions but must not spend
resources, deal damage, or advance turns itself.

## Dialogue UI

Allowed:

- Speaker name.
- Portrait and expression.
- Dialogue text.
- Choices.
- Continue indicator.

Battle commands and exploration shortcuts do not own input while dialogue is
active. Exploration HUD is dimmed or hidden according to scene composition;
interaction prompts and shortcuts are always disabled.

## Menu UI

Menus own navigation while open. The underlying context is paused or input
locked without losing its state. A menu may display persistent profile data, but
must label it as profile/progression data rather than current battle state.

Closing a menu restores the exact previous context and focus owner. It must not
default blindly to exploration when opened from battle or dialogue.

## Layering

Recommended CanvasLayer order:

| Layer | Responsibility |
| --- | --- |
| `0` | World and battle stage |
| `20` | Exploration HUD |
| `30` | Battle HUD when in battle scene |
| `40` | Dialogue and scene modal |
| `60` | Pause/menu |
| `80` | Cinematic cut-in and full-screen battle presentation |
| `128` | Global scene transition |

The current Grasslands debug keeps inherited `WorldCanvas` at `40`,
`ExplorationHUD` at `20`, and global transition at `128`. A permanent migration
must audit inherited modal ownership before changing those values.

## Input ownership

| Context | Input owner | Exploration shortcuts | Combat commands |
| --- | --- | --- | --- |
| Exploration | Player controller + ExplorationHUD | Enabled | Absent |
| Dialogue | Dialogue UI | Disabled | Absent |
| Battle command | Battle flow + BattleHUD | Absent | Enabled by state |
| Battle execution | Battle flow | Absent | Locked |
| Ultimate cut-in | Battle presentation | Absent | Locked |
| Menu | Active menu | Disabled | Disabled |
| Transition | SceneTransition | Disabled | Disabled |

Signals express intent. The owning controller validates whether that intent is
legal in the current state.

## Transition rules

### Exploration to dialogue

1. Stop movement input.
2. Hide interaction prompt and shortcuts.
3. Dim or hide nonessential exploration HUD.
4. Give focus to dialogue.
5. On close, restore exploration only if no newer context has taken ownership.

### Exploration to battle

1. Set `BATTLE_TRANSITION`.
2. Fade the ExplorationHUD.
3. Lock movement and interaction.
4. Run the global scene transition.
5. Battle scene initializes its own HUD and resources.

No exploration Energy is transferred because Ultimate Energy is battle-owned.

### Battle to Ultimate presentation

1. Battle flow confirms the Ultimate and locks normal commands.
2. Target UI closes.
3. Battle HUD dims or hides for the cut-in.
4. Cut-in/presentation layer takes visual focus.
5. Recovery restores battle HUD from battle state, not cached button visuals.

### Battle to exploration

1. Victory/defeat finalizes encounter state.
2. Clear pending battle requests and temporary resources.
3. Transition to the destination scene.
4. ExplorationHUD reconstructs only exploration-owned information.

## Grasslands debug contract

- Location, quest, interaction, notification, and five menu shortcuts remain.
- `CharacterStatus` is explicitly hidden.
- No fake HP, level, or Energy is bound.
- No combat action is added.
- Dialogue, pause, and battle transitions continue to call the inherited
  Grasslands implementation.

