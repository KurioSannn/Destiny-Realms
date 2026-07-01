# Destiny Realms

Destiny Realms is a Godot 4 2D game jam prototype. The current build is a single action turn-based battle scene using plain placeholder nodes and UI.

## Current Prototype Scope

- One player and one enemy.
- Player turn and enemy turn.
- Basic attack with a small timing-bar action element.
- Basic guard that reduces the next enemy attack by 50%.
- HP labels, turn label, battle log, win state, lose state, and restart.
- Simple battle feedback: attack movement, hit flash, guard pulse, floating damage numbers, subtle camera shake, and timing bar color feedback.

This is not a full RPG system. There is no inventory, equipment, skill tree, save system, map exploration, dialogue, level system, or multi-enemy battle yet.

## Engine Target

- Godot 4
- The project currently uses the Godot 4 project format in `project.godot`.

## Controls

- Click `Attack` to start an attack timing window.
- Press `Space`, press `Enter`, or click `Confirm` during the timing window.
- Click `Guard` to reduce the next enemy attack.
- Click `Restart` after victory or defeat.
- Press `R` to restart the battle.

Input actions are defined in `project.godot`:

- `confirm_attack`: Space, Enter
- `restart`: R

The UI script also has direct key fallbacks for Space, Enter, and R so the battle scene remains usable if the input map is changed while prototyping.

## Folder Structure

- `scenes/battle/battle_scene.tscn`: playable battle scene.
- `scripts/battle/battle_manager.gd`: turn flow, HP changes, win/lose/restart state.
- `scripts/battle/combatant.gd`: small reusable HP and damage component for player/enemy nodes.
- `scripts/battle/battle_ui.gd`: labels, buttons, and keyboard input forwarding.
- `scripts/battle/timing_bar.gd`: short timing window used by the attack action.
- `scenes/Yokuni.tscn`: existing placeholder scene, left unchanged.
- `node_2d.tscn`: existing placeholder scene, left unchanged.

## How To Run

1. Open the project folder in Godot 4.
2. Open `res://scenes/battle/battle_scene.tscn`.
3. Run the project.

`project.godot` sets `res://scenes/battle/battle_scene.tscn` as the main scene, so running the project should open the battle directly.

## How To Test

1. Run the battle scene and confirm the turn label starts at `Player Turn`.
2. Click `Attack`, then press Space/Enter or click `Confirm`.
3. Confirm the timing bar turns green around the good timing zone.
4. Confirm the player moves toward the enemy and returns.
5. Confirm enemy HP decreases by 15 for normal timing or 25 for good timing.
6. Confirm a floating damage number appears above the enemy and fades out.
7. Confirm the enemy briefly flashes/reacts to damage.
8. After the player attack, confirm the enemy moves toward the player and returns.
9. Confirm player HP decreases and a floating damage number appears above the player.
10. Click `Guard` on the next player turn.
11. Confirm the player shows a short guard pulse.
12. Confirm the enemy attack is reduced from 12 damage to 6 damage.
13. Keep attacking until enemy HP reaches 0 and confirm the victory state appears.
14. Click `Restart` and confirm both HP values reset, positions reset, and the player starts first.
15. To test defeat faster, temporarily lower `PLAYER_MAX_HP` in `scripts/battle/battle_manager.gd`, run the scene, and let the enemy defeat the player.
16. Check the Godot Debugger and Output panels for errors.

## Visual Feedback

- Player attack: the player placeholder lunges toward the enemy, then returns.
- Enemy attack: the enemy placeholder lunges toward the player, then returns.
- Hit reaction: the damaged combatant flashes briefly and squashes slightly.
- Guard: the player placeholder pulses blue when guarding.
- Floating damage: damage numbers appear above the target and fade out.
- Camera shake: a subtle shake plays on hit.
- Timing bar: the bar turns green while inside the good timing range.

## Manual Setup

No manual setup should be required. If Godot does not automatically use the configured main scene, set the main scene manually to:

`res://scenes/battle/battle_scene.tscn`

## Known Limitations

- Combatants are still ColorRect placeholders, not final Destiny Realms illustrated art.
- The hit, guard, and attack feedback are simple Tween animations, not authored character animations.
- The timing bar only gives basic color feedback; it does not yet show a marked perfect zone.
- Floating damage text uses default Godot label rendering.

## Next Development Steps

- Replace the ColorRect placeholders with illustrated temporary art when ready.
- Replace Tween placeholder motion with Destiny Realms character animation once art assets exist.
- Add clearer timing-zone artwork around the good timing range.
- Add simple hit and guard animations.
- Tune HP and damage values after testing.
- Add a second player action only after the core duel loop feels good.
