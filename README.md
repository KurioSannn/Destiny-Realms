# Destiny Realms

Destiny Realms is an original Godot 4 2D vertical slice based on the world of Unmei no Ryoiki. The current prototype has a simple scene flow: a prologue dialogue scene, a side-view turn-based battle scene, and a short ending scene.

The battle direction uses clear modern turn-based readability as a high-level reference: readable turns, distinct action buttons, an ultimate energy meter, and short attack feedback. It does not copy characters, names, UI, icons, logos, animations, sounds, systems, or assets from any existing game.

## Engine Target

- Godot 4
- Main scene: `res://scenes/prologue/prologue_scene.tscn`
- Base resolution: `1280x720`
- Stretch mode: `canvas_items`
- Stretch aspect: `keep`

## Scene Flow

1. `res://scenes/prologue/prologue_scene.tscn`
2. `res://scenes/battle/battle_scene.tscn`
3. `res://scenes/ending/ending_scene.tscn`
4. Restart from battle or Back to Prologue from ending returns to `res://scenes/prologue/prologue_scene.tscn`

The project starts in `PrologueScene`. After the prologue dialogue ends, it transitions with `get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")`.
Winning the battle transitions to `res://scenes/ending/ending_scene.tscn`.
Pressing `Restart Story` or `R` from `BattleScene` returns to the prologue so the full playable loop starts over.
Pressing `Back to Prologue` from `EndingScene` returns to the prologue.

## Current Prototype Scope

- One intro dialogue scene before battle.
- Named speakers and readable dialogue text.
- Next button and Space/Enter dialogue advance.
- One Takashi dialogue choice with two options.
- Different Mitsuki/Makoto responses based on the selected choice.
- Dialogue transitions into a separate one-player, one-enemy battle scene.
- Player actions: Void Strike, Triangle Rift, and Octagram Fragment.
- Enemy turn, HP, Skill Points, ultimate energy, win, lose, and restart.
- Skill Points for skill usage.
- A short post-battle ending dialogue after victory.
- Temporary original placeholder visuals built from Godot nodes.

This is not a full RPG system. There is no exploration map, inventory, equipment, skill tree, save/load, party management, elemental weakness system, gacha system, relic system, full visual novel engine, or full story adaptation yet.

## Lore Episode Summary

The prototype starts in the southern forest of the Central Continent, near Werdonia. Mitsuki and Makoto find a confused stranger who has lost his memory. They decide to call him Takashi, a name for a traveler from the East. Before they can leave, a Lesser Abyss appears, and Takashi's strange triangle-like anti-matter power briefly flickers.

The scene only hints at Takashi's hidden identity and power. It does not reveal the full truth of Trinity or the full Octagram.

## Characters

- Takashi: A mysterious amnesiac traveler. His combat power is hinted through void and triangle-based attacks.
- Mitsuki: A cautious descendant of the Stellar bloodline with space-time potential.
- Makoto: A calm, protective figure connected to Archon Yang's faith and mana.
- Lesser Abyss: A small hostile Abyss threat used as the first battle opponent.

## Dialogue System

The prologue dialogue uses `res://scripts/dialogue/dialogue_manager.gd` inside `PrologueScene`.

It supports:

- Speaker name display.
- Dialogue text display.
- Next button.
- Space/Enter to advance when no choices are visible.
- Two clickable dialogue choices.
- Different response branches.
- A `dialogue_finished` signal that starts the battle.

The dialogue panel is intentionally placed near the bottom of the screen. The speaker name is visually separated from the dialogue text, choices appear as larger stacked buttons, and the Next button is hidden while choices are active. This keeps the prologue UI separate from the battle log UI.

After the dialogue ends, `PrologueScene` changes to `BattleScene`. The battle scene no longer contains the intro dialogue UI, so battle controls are active immediately when combat starts.

## Ending Scene

`EndingScene` plays after Takashi defeats the Lesser Abyss. Mitsuki and Makoto react to Takashi's triangle-like distortion without revealing his full identity. The scene points the group toward Werdonia and ends with `Destiny Realms: Awakening in Werdonia` and `To be continued...`.

The ending has a `Back to Prologue` button that returns to `res://scenes/prologue/prologue_scene.tscn`.

## Controls

Dialogue:

- Click `Next` to advance dialogue.
- Press `Space` or `Enter` to advance dialogue when no choices are visible.
- Click one of the choice buttons when choices appear.

Ending:

- Click `Next` to advance the ending dialogue.
- Press `Space` or `Enter` to advance ending dialogue.
- Click `Back to Prologue` after `To be continued...` appears.

Battle:

- Click `Void Strike`, then press `Space`, press `Enter`, or click `Confirm` during the timing window.
- Click `Triangle Rift` when you have at least `1` Skill Point.
- Click `Octagram Fragment` when Takashi Energy reaches `100/100`.
- Click `Restart Story` to return to the prologue.
- Press `R` in BattleScene to return to the prologue.

Input actions in `project.godot`:

- `confirm_attack`: Space, Enter
- `restart`: R

## Battle Rules

- Takashi HP starts at `100`.
- Lesser Abyss HP starts at `120`.
- Lesser Abyss attack deals `14` damage.
- Lesser Abyss acts after each player action unless defeated.

Player actions:

- Skill Points start at `3/5`.
- `Void Strike`: deals `12` damage, or `18` with good timing, generates `25` Takashi Energy, and restores `1` Skill Point up to `5/5`.
- `Triangle Rift`: costs `1` Skill Point, deals `25` damage, and generates `15` Takashi Energy.
- `Octagram Fragment`: requires `100` Takashi Energy, deals `45` damage, and consumes all energy.

Skill Points and Takashi Energy are separate resources. Skill Points control whether Takashi can use `Triangle Rift`; Takashi Energy controls when `Octagram Fragment` becomes available.

Restart changes back to `PrologueScene`. Finishing the prologue again loads a fresh `BattleScene` with reset HP, Skill Points, energy, battle log, button states, positions, timing bar, and camera offset.

## Battle UI Layout

The current battle UI is organized for prototype readability:

- Top left: Takashi status panel with HP, Takashi Energy, energy bar, and Skill Points.
- Top right: Lesser Abyss status panel with HP.
- Bottom left: turn/state label and battle log panel.
- Bottom right: action command panel.
- Timing bar: appears above the bottom log panel only during Void Strike timing.

Action buttons use two-line labels:

- `Void Strike`: basic action, restores `1` Skill Point, and generates Takashi Energy.
- `Triangle Rift`: skill action, costs `1` Skill Point.
- `Octagram Fragment`: ultimate action, requires `100/100` Takashi Energy.
- `Restart Story`: returns to the prologue.

Disabled action buttons explain why they are unavailable, such as waiting for the turn, needing `1` Skill Point, or missing Takashi Energy. When Takashi Energy reaches `100/100`, `Octagram Fragment` changes to a clear `[READY]` state.

## Temporary Placeholder Visuals

The current character visuals are temporary original placeholders built directly in Godot scenes with `Polygon2D` nodes.

They are simple shape silhouettes for prototype readability:

- Takashi/player placeholder on the left.
- Lesser Abyss/enemy placeholder on the right.
- Mitsuki and Makoto placeholder figures in the prologue and ending scenes.
- A simple Godot-node forest background behind the characters.

These are not final Destiny Realms art, not AI-generated external images, and not copied from any existing game.

The battle scene applies a small runtime layout pass when it starts. Takashi is placed around 25% of the viewport width and 68% of the viewport height, while the Lesser Abyss is placed around 72% width and 68% height. This keeps both placeholders visible when the project is run, even if the editor window size differs from the base resolution.

## Folder Structure

- `scenes/prologue/prologue_scene.tscn`: short story intro before combat.
- `scenes/battle/battle_scene.tscn`: playable battle scene.
- `scenes/ending/ending_scene.tscn`: short post-battle ending scene.
- `scripts/prologue/prologue_scene.gd`: prologue layout and transition to battle.
- `scripts/ending/ending_scene.gd`: ending dialogue and return to prologue.
- `scripts/dialogue/dialogue_manager.gd`: intro dialogue flow, choices, branching, input, and completion signal.
- `scripts/battle/battle_manager.gd`: turn flow, action rules, HP, Skill Points, energy, win/lose/restart.
- `scripts/battle/combatant.gd`: combatant HP and simple movement/feedback helpers.
- `scripts/battle/battle_ui.gd`: labels, buttons, energy UI, and keyboard input forwarding.
- `scripts/battle/timing_bar.gd`: optional Void Strike timing window.

## How To Run

1. Open the project folder in Godot 4.
2. Run the project from the configured main scene.

`project.godot` sets `res://scenes/prologue/prologue_scene.tscn` as the main scene.

## How To Test Dialogue

1. Run the project.
2. Confirm the intro dialogue appears before battle actions can be used.
3. Confirm speaker names appear for Mitsuki, Makoto, and Takashi.
4. Click `Next` through the first dialogue lines.
5. Confirm `Space` or `Enter` advances dialogue when no choices are visible.
6. Confirm two Takashi choices appear.
7. Pick each choice in separate runs and confirm Mitsuki/Makoto gives a different response.
8. Confirm the dialogue mentions Takashi's amnesia, the name Takashi, the Lesser Abyss, and the triangle power hint.
9. Confirm the scene transitions to `BattleScene` after the final line.
10. Confirm no duplicate intro dialogue appears inside `BattleScene`.

## How To Test Battle

1. After the prologue transition, confirm the turn label starts at `Player Turn`.
2. Click `Void Strike`, then press Space/Enter or click `Confirm`.
3. Confirm Lesser Abyss HP decreases, Takashi Energy increases by `25`, and Skill Points increase by `1` up to `5/5`.
4. Click `Triangle Rift` and confirm it spends `1` Skill Point, deals `25` damage, and generates `15` energy.
5. Confirm `Triangle Rift` is disabled only when Skill Points are below `1` or it is not the player turn.
6. Confirm `Octagram Fragment` is disabled below `100/100` energy.
7. Build energy to `100/100`, then confirm `Octagram Fragment` becomes usable.
8. Click `Octagram Fragment` and confirm it deals `45` damage and resets energy to `0/100`.
9. Defeat the Lesser Abyss and confirm the scene transitions to `EndingScene`.
10. Confirm lose state still stays in `BattleScene`.
11. Click `Restart Story` during battle or after loss and confirm it returns to `PrologueScene`.
12. Confirm Godot Output and Debugger show no runtime errors.

## How To Test Ending

1. Defeat the Lesser Abyss.
2. Confirm `EndingScene` appears.
3. Confirm Takashi, Mitsuki, and Makoto ending dialogue appears.
4. Click `Next` or press Space/Enter to advance.
5. Confirm `Destiny Realms: Awakening in Werdonia` and `To be continued...` appear.
6. Click `Back to Prologue` and confirm the prologue starts again.

## Known Limitations

- Dialogue content is a short intro scene, not a full visual novel system.
- Placeholder visuals are temporary prototype art, not final Destiny Realms art.
- Mitsuki and Makoto use simple temporary scene placeholders, not final portraits.
- Octagram Fragment is only a small power hint for the prototype.
- Enemy behavior is deterministic and has no AI variation.
- Floating damage text uses default Godot label rendering.
- The timing bar only uses simple color feedback for the good timing range.
- The current battle model uses Skill Points for skill usage and energy for Ultimate access.
- EndingScene is a short cliffhanger, not a full chapter ending system.
- UI styling is cleaned up for readability, but it is still prototype UI rather than final Destiny Realms interface art.

## Next Steps

- Replace placeholders with final Destiny Realms illustrated character assets.
- Add a main menu before the prologue.
- Expand the ending scene later if the comic chapter needs a longer closing beat.
- Add simple Mitsuki and Makoto portraits during dialogue.
- Add authored hit, skill, and ultimate animations.
- Add SFX/BGM.
- Continue refining UI styling while keeping it original.
- Expand dialogue data only after the current vertical slice remains stable.
- Tune HP, damage, Skill Points, and energy values after playtesting.
- Export a Windows prototype build.
