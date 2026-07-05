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
Pressing `R` from `BattleScene` returns to the prologue so the full playable loop starts over.
Pressing `Back to Prologue` from `EndingScene` returns to the prologue.

## Current Prototype Scope

- One intro dialogue scene before battle.
- Named speakers and readable dialogue text.
- Takashi, Mitsuki, and Makoto dialogue portraits loaded from `res://public/`.
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
- Takashi/Mitsuki/Makoto portrait display when those speakers are active.
- Next button.
- Space/Enter to advance when no choices are visible.
- Two clickable dialogue choices.
- Different response branches.
- A `dialogue_finished` signal that starts the battle.

The dialogue panel is intentionally placed near the bottom of the screen. The speaker name is visually separated from the dialogue text, Takashi, Mitsuki, and Makoto portraits appear in the panel when they are speaking, choices appear as larger stacked buttons, and the Next button is hidden while choices are active. This keeps the prologue UI separate from the battle log UI.

After the dialogue ends, `PrologueScene` changes to `BattleScene`. The battle scene no longer contains the intro dialogue UI, so battle controls are active immediately when combat starts.

## Prologue UI Assets

The prologue now uses visual assets from `res://public/`:

- Forest background: `res://public/BG1Forest.png`
- Takashi screen portrait: `res://public/Takashi portrait 1.png`
- Mitsuki screen portrait: `res://public/Mitsuki portrait 1.png`
- Makoto screen portrait: `res://public/Makoto portrait 1.png`
- Takashi talking portrait: `res://public/Takashi portrait 2 (talk).png`
- Mitsuki talking portrait: `res://public/Mitsuki portrait 2 (talk).png`
- Makoto talking portrait: `res://public/Makoto portrait 2 (Talk).png`

`res://public/DialogFrame.png` is available, but the current prologue UI intentionally does not use it as a full raw panel because it is too large and ornate for the 1280x720 dialogue layout.

`PrologueScene` keeps the forest and screen portraits outside `CanvasLayer`. The dialogue UI stays inside `CanvasLayer`, with a dark transparent bottom overlay, a Godot-native `StyleBoxFlat` dialogue panel, portrait frame, speaker name, dialogue text, styled Next button, and choice container.

The prologue uses two portrait layers:

- `portrait 1` assets are used as large character portraits on the screen.
- `portrait 2` talking assets are used inside the dialogue portrait frame.

Speaker portrait mapping is handled in `res://scripts/dialogue/dialogue_manager.gd`. Takashi, Mitsuki, and Makoto each use their matching talking portrait when they are the current speaker. `PrologueScene` also highlights the active speaker's screen portrait and dims the inactive screen portraits.

No custom font files are currently present in `public/`, so the prototype uses Godot's default font with explicit font sizes, colors, and button styles. Recommended future font files are Cinzel or Cormorant Garamond for speaker names, and Noto Sans or Inter for dialogue text.

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

- Click `Void Strike` for an immediate basic attack.
- Click `Triangle Rift` when you have at least `1` Skill Point.
- Click `Octagram Fragment` when Takashi Energy reaches `100/100`.
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
- `Void Strike`: deals `12` damage immediately, generates `25` Takashi Energy, and restores `1` Skill Point up to `5/5`.
- `Triangle Rift`: costs `1` Skill Point, deals `25` damage, and generates `15` Takashi Energy.
- `Octagram Fragment`: requires `100` Takashi Energy, deals `45` damage, and consumes all energy.

Skill Points and Takashi Energy are separate resources. Skill Points control whether Takashi can use `Triangle Rift`; Takashi Energy controls when `Octagram Fragment` becomes available.

Restart with `R` changes back to `PrologueScene`. Finishing the prologue again loads a fresh `BattleScene` with reset HP, Skill Points, energy, battle log, button states, positions, and camera offset.

## Battle UI Layout

The current battle UI is organized for prototype readability:

- Top left: compact Takashi status panel with `res://public/Takashi portrait 1.png`, green HP bar, Takashi Energy bar, Skill Points text, and segmented SP pips.
- Top right: compact Lesser Abyss status panel with red HP bar.
- Bottom left: turn/state label and battle log panel.
- Bottom right: compact icon-only action command panel with circular buttons.
- Battle background uses `res://public/BG1Forest.png` for the current forest combat placeholder.
- Battle entry shows a short `BATTLE START` fade overlay before normal play.

Action buttons use skill icons from `res://public/` without visible description text:

- `Void Strike`: basic action, restores `1` Skill Point, and generates Takashi Energy.
- `Triangle Rift`: skill action, costs `1` Skill Point.
- `Octagram Fragment`: ultimate action, requires `100/100` Takashi Energy.
Disabled action buttons are dimmed when unavailable. When Takashi Energy reaches `100/100`, `Octagram Fragment` uses a highlighted ready border.

Battle skill icon mapping:

- `Void Strike`: `res://public/BasicSkillTakashi.png`
- `Triangle Rift`: `res://public/AttackSkillTakashi.png`
- `Octagram Fragment`: `res://public/UltimateSkillTakashi.png`

## Temporary Placeholder Visuals

The current character visuals are temporary original placeholders built directly in Godot scenes with `Polygon2D` nodes.

They are simple shape silhouettes for prototype readability:

- Takashi/player placeholder on the left.
- Lesser Abyss/enemy placeholder on the right.
- Takashi, Mitsuki, and Makoto screen portraits and dialogue portraits in the prologue.
- Mitsuki and Makoto temporary scene placeholders in the prologue and ending scenes.
- A simple Godot-node forest background behind the characters.

These are not final Destiny Realms art, not AI-generated external images, and not copied from any existing game.

The battle scene uses these assets:

- `res://public/BG1Forest.png`
- `res://public/Takashi portrait 1.png`
- `res://public/BasicSkillTakashi.png`
- `res://public/AttackSkillTakashi.png`
- `res://public/UltimateSkillTakashi.png`

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
- `scripts/battle/timing_bar.gd`: unused optional timing bar helper kept for later experiments.

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
2. Confirm Takashi HP, Energy, and Skill Points are readable in the top-left panel.
3. Confirm Lesser Abyss HP is readable in the top-right panel.
4. Confirm HP bars and Energy bar are visible.
5. Confirm Skill Point pips match the Skill Points text.
6. Confirm the three action buttons show their skill icons.
7. Click `Void Strike`.
8. Confirm Lesser Abyss HP decreases, Takashi Energy increases by `25`, and Skill Points increase by `1` up to `5/5`.
9. Click `Triangle Rift` and confirm it spends `1` Skill Point, deals `25` damage, and generates `15` energy.
10. Confirm `Triangle Rift` is disabled only when Skill Points are below `1` or it is not the player turn.
11. Confirm `Octagram Fragment` is disabled below `100/100` energy.
12. Build energy to `100/100`, then confirm `Octagram Fragment` becomes usable and displays `[READY]`.
13. Click `Octagram Fragment` and confirm it deals `45` damage and resets energy to `0/100`.
14. Defeat the Lesser Abyss and confirm the scene transitions to `EndingScene`.
15. Confirm lose state still stays in `BattleScene`.
16. Press `R` during battle or after loss and confirm it returns to `PrologueScene`.
17. Confirm Godot Output and Debugger show no runtime errors.

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
- Takashi, Mitsuki, and Makoto use temporary dialogue portraits plus simple scene placeholders.
- Dialogue currently uses active talking portraits inside the frame and dimmed neutral portraits on screen.
- The generated `DialogFrame.png` is kept in `public/` but not used as the main prologue panel until it can be cropped or redesigned for a smaller UI layout.
- Octagram Fragment is only a small power hint for the prototype.
- Enemy behavior is deterministic and has no AI variation.
- Floating damage text uses default Godot label rendering.
- The old timing bar helper is kept but not used by the current basic attack flow.
- The current battle model uses Skill Points for skill usage and energy for Ultimate access.
- EndingScene is a short cliffhanger, not a full chapter ending system.
- UI styling is cleaned up for readability, but it is still prototype UI rather than final Destiny Realms interface art.

## Next Steps

- Replace placeholders with final Destiny Realms illustrated character assets.
- Add a main menu before the prologue.
- Expand the ending scene later if the comic chapter needs a longer closing beat.
- Replace temporary dialogue portraits with final Destiny Realms portrait art when ready.
- Add authored hit, skill, and ultimate animations.
- Add SFX/BGM.
- Continue refining UI styling while keeping it original.
- Expand dialogue data only after the current vertical slice remains stable.
- Tune HP, damage, Skill Points, and energy values after playtesting.
- Export a Windows prototype build.
