# Block 11 — Abyss Forest 3D Foundation

The first playable 3D exploration area is Abyss Forest. Werdonia Outskirts begins only after the player crosses the ancient seal at the forest exit.

## Entry point (temporary development configuration)

`project.godot`'s `run/main_scene` currently points directly at `res://scenes/world_3d/abyss_forest_3d.tscn`. **This is a temporary developer convenience for Block 11 iteration, not a permanent production decision.** The login/prologue story flow still exists untouched and remains fully reachable; the game simply doesn't start there right now. Before Block 11 locks, restore `run/main_scene` to the real story entry point (or make the choice explicit and intentional) rather than letting this default silently ship.

## Production scene

- `res://scenes/world_3d/abyss_forest_3d.tscn`
- `ExplorationCamera3D` (perspective, "F2 — Exploration") follows the player by default, with an orthographic "F1 — Legacy" debug baseline (`F1`/`F2` to switch).
- `CharacterBody3D` movement with Takashi presented through `AnimatedSprite3D`.
- Dense twisted/dead tree line, ancient ruins, stone path, undergrowth, fog, fireflies, boundary rock silhouettes, and an illuminated exit seal.
- Physical ground, world boundaries, tree/rock/ruin collision, and an interaction route into the existing Werdonia Outskirts scene.
- Existing exploration HUD remains a replaceable placeholder.

## Reusable exploration camera

The camera is no longer Abyss-specific. It lives as a standalone, instanceable component:

- Scene: `res://scenes/world_3d/components/exploration_camera_3d.tscn`
- Script: `res://scripts/world_3d/exploration_camera_3d.gd` (`class_name ExplorationCamera3D`)

Abyss Forest is its first production consumer: `abyss_forest_3d.tscn` instances the component as the `ExplorationCamera` node and relies on its default `target_path = "../Player"` convention (a sibling named `Player`). Any other world scene can instance the same `.tscn`, either follow the same sibling-naming convention or call `set_target(node: Node3D)` directly, and get the same camera behavior — no per-map code duplication. The component has no hardcoded reference to Abyss Forest, the seal, or any other map-specific node.

### Architecture

The component stays a single `Camera3D`-extending script rather than a literal yaw-pivot/pitch-pivot/camera node chain. Internally it keeps yaw, pitch, and distance as three independent, directly-tunable pieces of state (a spherical coordinate system around a follow pivot), combined each frame into a position via `_spherical_offset()`. This was a deliberate call, not a shortcut: it reuses the already-proven, already-tested wrap-safe 360° yaw smoothing from the previous camera iteration instead of re-deriving it inside new pivot nodes, and it avoids a scene-graph migration for a component that other maps will soon depend on. Target follow, yaw, pitch, distance, look height/target, smoothing, and obstruction are all still fully separable concerns in the code — they just aren't separate `Node3D`s.

### Exported configuration (per-instance, no code duplication needed)

| Category | Properties |
| --- | --- |
| Target | `target_path` |
| Framing | `look_height`, `framing_lead`, `follow_damping`, `fov_degrees`, `preset_transition_seconds` |
| Orbit | `default_yaw_degrees`, `default_pitch_degrees`, `pitch_min_degrees`, `pitch_max_degrees`, `yaw_sensitivity`, `pitch_sensitivity`, `orbit_smoothing_speed` |
| Distance zoom | `distance_default`, `distance_min`, `distance_max`, `distance_step`, `distance_smoothing_speed`, `distance_preset_close/medium/wide` |
| Obstruction | `obstruction_collision_mask`, `obstruction_margin`, `obstruction_pull_in_speed`, `obstruction_restore_speed`, `obstruction_min_distance` |
| Input | `mouse_control_enabled`, `debug_label_path` |

A future, wider-open area (Werdonia Outskirts, grasslands) should instance the same component and simply raise `distance_default`/`distance_max` and widen `framing_lead`/`look_height` as needed — a configuration difference, not a new script.

### Camera controls (F2 / production preset only)

- **Mouse wheel**: physically dollies the camera closer to or farther from Takashi. FOV stays fixed at 35.5° — zoom no longer touches FOV at all. Distance range 7m (closest) – 19m (widest), default 13m, in 1m steps, smoothed continuously (never snaps between fixed levels).
- **Hold middle or right mouse button + drag**: orbit. Horizontal yaw is a full, continuous, unrestricted 360° rotation around Takashi (wrap-safe, no unbounded growth, always eases along the shortest arc — crossing the ±180° seam never spins the long way around). Pitch is clamped to an absolute downward angle of 10°–32° (default ≈14.5°), so the view can never go fully top-down, below ground, or to an unusably flat angle.
- **Release the mouse button**: the current orbit/zoom holds — no snap-back.
- **`R`**: smoothly resets yaw, pitch, and distance back to their defaults, always taking the shortest way back around on yaw.
- **`F5` / `F6` / `F7`** *(temporary debug shortcuts, not permanent controls)*: retarget distance only, to the close/medium/wide reference values (7m / 11m / 19m). Continuous scroll zoom still works normally afterward.
- Orbit distance and the look-at pivot point stay fixed while orbiting — only the viewing angle changes.
- Mouse camera input (wheel/drag/reset) is skipped whenever `ExplorationCamera3D.mouse_control_enabled` is `false` or the scene tree is paused, so a future menu/dialogue/cutscene system can gate it with `set_mouse_control_enabled(false)`. `F1`/`F2`/`F5`-`F7` are treated as always-on debug tools, matching how `F1`/`F2` already behaved.

### Camera obstruction (new)

A raycast from the follow pivot toward the desired camera position checks a dedicated physics layer (bit 2). If solid geometry blocks the path, the camera pulls in quickly (so it never clips through a wall/rock for even a frame) and eases back out slowly once the obstruction clears. Trees are deliberately **excluded** from this layer — they keep using the existing transparency fade instead of push-in, per design intent ("foliage fades, solids push the camera in"). `abyss_forest_3d.gd`'s `_add_box_collider`/`_add_cylinder_collider` now take an `obstructs_camera` flag (default `true`); only the twisted/dead tree trunk colliders pass `false`. Player movement collision is unaffected — every collider keeps its original layer-1 membership.

### Known limitation: billboard sprite under full orbit

Takashi is an `AnimatedSprite3D` with `billboard` enabled, so the sprite always turns to face the camera no matter where the camera orbits to. Viewing Takashi from the front, side, or back all show the *same* facing artwork — there is no directional sprite (front/back/side facings) yet. This is expected, pre-existing, temporarily-accepted technical debt with the current 2D-sprite-in-3D-world architecture, not a bug introduced by the camera work, and no attempt was made to fake directional art or mirror-hack it. A production-quality result under free orbit will need a directional-sprite (or full 3D model) system for Takashi later.

## World scale audit

Takashi's `AnimatedSprite3D` renders at `pixel_size = 0.00162` with a 1254px-tall source texture, i.e. a reference visual height of **≈2.03m**. Sampling native glTF bounds (accessor min/max in each asset's `.gltf` JSON) against that reference:

| Asset | Native height | Old scale range | Old ratio to Takashi | New scale range | New ratio to Takashi |
| --- | --- | --- | --- | --- | --- |
| TwistedTree (major tree) | ~16.7m | 0.68–1.03 | ~5.6–8.5x | 1.05–1.60 | ~8.6–13.2x |
| DeadTree (ordinary tree) | ~9.5m | 0.68–1.03 | ~3.2–4.8x | 1.05–1.60 | ~4.9–7.5x |
| Background pine | ~7.3m | 0.82–0.98 | ~3.0–3.5x | 1.3–1.6 | ~4.7–5.8x |
| Rock_Medium | ~2.26m | 0.72–1.08 (4 fixed steps) | ~0.8–1.2x | 0.65–2.05 (5-step cycle) | ~0.7–2.3x (small rock to real boulder variety) |
| Ruin wall (UnevenBrick) | ~3.0m | 0.85–1.05 | ~1.25–1.55x | 1.4–1.9 | ~2.1–2.8x |
| Boundary silhouette rocks (new) | ~2.26m native | n/a (new) | n/a | 7.0–8.8 | ~7.9–10x |

Colliders that were hardcoded independent of the visual scale (ruin wall box, rock cylinder Y-offset) now scale proportionally with the same multiplier used for the mesh, so collision keeps matching the (now larger) visuals. Tree trunk colliders already scaled with `tree_scale` and needed no change.

This was a **targeted** adjustment: only the scale *ranges* for trees, rocks, and ruin walls changed, plus one new decorative function (`_build_boundary_silhouettes`, 9 large rocks placed just outside the existing invisible boundary walls for a "world edge" silhouette). Nothing was globally rescaled, no existing placements were moved, and no new collision was added beyond the boundary walls that already existed — the 9 silhouette rocks are purely decorative, sitting outside the collision boundary that already stops the player at that Z coordinate. Terrain itself (the flat ground plane) was intentionally left unmodified: reshaping it (slopes/terraces) could not be visually verified in this environment and risked the playable route, so it was judged out of the safe-to-attempt set for this pass — see Remaining Technical Debt.

## World order

1. Abyss Forest 3D
2. Ancient forest seal
3. Werdonia Outskirts
4. Grasslands and Werdonia City

## Asset policy

- Runtime source: `.gltf` with its `.bin` and texture dependencies.
- The scene currently references only the CC0 Quaternius nature, village, and fantasy-prop packs.
- Monster assets remain out of the production scene until their release license is verified.

## Controls

- Move: `WASD` or arrow keys
- Cross the forest seal: `E`
- Return to title while testing: `Esc`
- Zoom camera (physical distance): mouse wheel (F2 only)
- Orbit camera (full 360° yaw, clamped pitch): hold middle or right mouse button and drag (F2 only)
- Reset camera framing: `R` (F2 only)
- Debug distance shortcuts (temporary): `F5` close / `F6` medium / `F7` wide (F2 only)
- Swap camera debug preset: `F1` / `F2`

## Migrating another scene onto ExplorationCamera3D (e.g. Werdonia Outskirts)

1. Instance `res://scenes/world_3d/components/exploration_camera_3d.tscn` as a child of the world root.
2. Either name the player node `Player` as a sibling of the camera (matches the default `target_path`), or call `exploration_camera.set_target(player)` from the world script's `_ready()`.
3. Tune the exported distance/pitch/framing values for that area's scale (e.g. wider `distance_default`/`distance_max` for open grassland) directly on the instanced node — no script changes.
4. If the area has solid obstruction geometry the camera should push in around, make sure those colliders carry the same camera-obstruction physics layer bit (2) that `abyss_forest_3d.gd` uses; foliage-only obstructions should rely on a transparency fade instead, same as Abyss Forest's tree occluder system.
5. No Abyss-specific node names, paths, or scripts need to be touched or referenced.
