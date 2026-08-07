# HUD EXPLOR placeholder layout

`hud_explor_placeholder.tscn` reconstructs the composition of the supplied
`HUD EXPLOR.png` reference while unfinished elements remain asset-free.
The six upper menu slots already use the supplied SVG artwork.

## Preview

Open this isolated scene in Godot:

`res://scenes/ui/exploration/hud_explor_placeholder_preview.tscn`

The layout uses the reference image's `2048x1138` coordinate system and scales
uniformly inside the viewport. It is intended for 16:9 screens and has been
prepared for capture at `1280x720` and `1920x1080`.

## Replaceable slots

- Circular minimap at the upper-left.
- Map journal and party shortcuts beside the minimap.
- Six system/menu shortcuts across the upper-right.
- Quest flag and objective tracker below the minimap.
- Three party rows on the right edge.
- Chat control at the lower-left.
- Player level and HP at the lower-center.
- Consumable and two action controls at the lower-right.
- Optional world-player marker in the center of the preview.

Every interactive region emits `slot_pressed(slot_name)` from `HUDRoot`. Final
textures can replace the drawing inside each named slot without changing its
reference-space rectangle or the overall layout.

## Upper menu SVG mapping

From left to right, the runtime HUD uses:

1. `Icon Event.svg`
2. `Icon Battle Pass.svg`
3. `Icon Gacha.svg`
4. `Icon Daily.svg`
5. `Icon Bag.svg`
6. `Icon Character.svg`

The original SVG files stay in `res://public/Hud Atas/` and are loaded directly
as Godot textures.

## Runtime integration

The placeholder HUD is instanced in all three production exploration scenes:

- `res://scenes/world/world_scene.tscn`
- `res://scenes/grasslands/grasslands_scene.tscn`
- `res://scenes/city/werdonia_city_scene.tscn`

The old location, quest, and menu controls are hidden to avoid duplicate HUDs.
Existing interaction prompts, dialogue modals, pause controls, and region fades
remain above the HUD on canvas layer `40`.
