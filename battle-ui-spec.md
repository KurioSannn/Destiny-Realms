# Destiny Realms — Battle UI Design Specification

> File ini adalah spesifikasi implementasi UI BattleScene untuk project **Destiny Realms**.  
> Tujuannya supaya Codex, Claude Code, Cursor, atau AI coding agent lain tidak menebak-nebak desain UI dan bisa mengimplementasikan layout yang sudah disetujui.

---

## 1. Context

**Destiny Realms** adalah original 2D fantasy turn-based RPG yang sedang dikembangkan di Godot 4.

Scene yang sedang dikerjakan adalah battle encounter di **Southern Forest of Werdonia**, dengan komposisi:

- Player character: **Takashi**
- Enemy: **Lesser Abyss**
- Background: dark moonlit forest
- Style: chibi/anime fantasy battle
- UI direction: clean, minimal, elegant, “less is more”

Battle logic sudah ada dan harus dipertahankan. Fokus dokumen ini adalah **visual UI BattleScene**, bukan rewrite sistem battle.

---

## 2. Goal

Implementasikan BattleScene UI yang terasa:

- clean
- minimal
- readable
- premium
- modern turn-based RPG
- dark fantasy
- tidak terlalu banyak kotak
- tidak menutupi area battle
- mudah direplikasi di Godot

Desain akhir harus terasa seperti **in-game UI mockup yang sudah matang**, bukan debug UI atau placeholder prototype.

---

## 3. Design Direction

### Visual Identity

Battle UI menggunakan identitas visual:

- deep navy / black transparent overlay
- thin cyan-blue glow
- subtle gold accent
- off-white text
- circular action buttons
- slim floating status bars
- compact status panels
- minimal ornament
- no giant decorative frames

### Reference Direction

UI mengambil prinsip readability dari modern turn-based RPG seperti:

- clean command buttons
- compact character info
- visible turn order
- floating HP bars
- open battlefield

Namun desain harus tetap **original** untuk Destiny Realms dan tidak menyalin layout game lain secara langsung.

---

## 4. Current Approved Layout

BattleScene harus memiliki komponen berikut:

1. **Vertical Turn Order** di sisi kiri.
2. **Takashi** di sisi kiri/center-left battlefield.
3. **Lesser Abyss** di sisi kanan/center-right battlefield.
4. **Floating HP bar** di atas Takashi.
5. **Floating HP bar** di atas Lesser Abyss.
6. **Top-right enemy strip** berisi `Lesser Abyss` dan `x1`.
7. **Menu button** berbentuk circular hamburger icon di sebelah enemy strip.
8. **Bottom-left compact Takashi panel**.
9. **Shared SP display** di dekat action buttons.
10. **Action buttons** di bottom-right: `Attack`, `Skill`, `Ultimate`.

---

## 5. Layout Specification

Target utama: UI harus menyisakan battlefield tetap terbuka.

### 5.1 Screen Composition

Untuk target 16:9, misalnya 1280x720 atau 1920x1080:

| Area | Komponen |
|---|---|
| Far left | Vertical turn order |
| Left battlefield | Takashi |
| Right battlefield | Lesser Abyss |
| Top right | Enemy strip + menu button |
| Bottom left | Takashi compact status panel |
| Bottom center-right | Shared SP display |
| Bottom right | Attack / Skill / Ultimate buttons |

### 5.2 Priority Visual

Urutan informasi yang harus paling cepat dibaca player:

1. Siapa yang sedang turn.
2. Siapa lawannya.
3. Action yang tersedia.
4. HP player dan enemy.
5. Shared SP.

---

## 6. Components

## 6.1 Turn Order

### Position

Far left side, vertical.

### Required Content

- Text label: `TURN ORDER`
- Current actor icon: Takashi portrait
- Enemy icon: Lesser Abyss
- Future empty slots if needed

### Visual Rules

Use:

- circular portrait chips
- slim vertical line
- small star/diamond separators
- soft active glow
- dimmed inactive slots

Avoid:

- square boxes
- huge panel
- thick frames
- clutter

### Behavior

- Current turn unit should be highlighted.
- Future turns should be visible but subtle.
- This should replace the need for a large `Player Turn` box.

---

## 6.2 Takashi Battlefield Sprite

### Position

Left-center battlefield.

### Rules

- Keep Takashi visible and unobstructed.
- Do not cover his body with large UI.
- Keep scale readable but not oversized.
- Takashi faces toward the enemy.

---

## 6.3 Lesser Abyss Battlefield Sprite

### Position

Right-center battlefield.

### Rules

- Keep enemy visible.
- Do not add large background panel behind enemy.
- Enemy should have clear HP info above it.

---

## 6.4 Floating HP Bar — Takashi

### Required Content

- HP text: `100/100`
- Green HP bar
- Optional small character/element icon on left of bar

### Position

Above Takashi’s head, slightly higher than before.

### Important

Remove decorative resource diamonds above Takashi.  
Do not show SP markers above the character.

---

## 6.5 Floating HP Bar — Lesser Abyss

### Required Content

- HP text: `120/120`
- Blue or red-toned HP bar, depending on current project style

### Position

Above Lesser Abyss.

### Important

Remove decorative resource diamonds above the enemy.  
Do not clutter the enemy HP area.

---

## 6.6 Top-right Enemy Strip

### Required Content

- Icon or small emblem
- Enemy name: `Lesser Abyss`
- Count: `x1`

### Position

Top-right.

### Visual

- Slim rounded rectangle
- Deep translucent navy/black
- Thin gold or cyan outline
- Clean text

### Menu Button

A small circular hamburger menu button should sit beside the enemy strip.

Rules:

- Keep only icon.
- Remove text label `Menu`.
- Button should be compact and elegant.
- No huge menu panel unless opened.

---

## 6.7 Bottom-left Takashi Status Panel

### Required Content

- Takashi portrait
- Name: `Takashi`
- HP bar
- HP text: `100/100`

### Removed Content

Do not show SP markers here.  
SP is global/shared, not per-character.

### Visual

- Compact panel
- Minimal dark transparent background or nearly frameless composition
- Thin gold/cyan accent
- Clean but fantasy-readable text

### Notes

This panel is mainly for player identity and HP, not action state.

---

## 6.8 Shared SP Display

### Purpose

SP is a **shared party resource**, not a per-character resource.

### Position

Bottom center-right, near action buttons, left of the `Attack` button cluster.

### Required Content

- Text: `SP 5/5`
- Row of exactly 5 glowing rice/padi icons underneath

### Visual Rules

- `SP 5/5` should use elegant fantasy typography.
- Text should not feel like plain system text.
- Rice/padi icons should be golden-yellow and softly glowing.
- Since value is 5/5, all 5 icons are active/lit.
- The icon row should be placed directly below the text.
- Avoid extra circular icon beside `SP 5/5` if it adds clutter.

### Layout Example

```text
       SP 5/5
   🌾 🌾 🌾 🌾 🌾
```

In implementation, do not use emoji if the project has asset icons.  
Use proper icon textures or simple custom-drawn padi shapes.

### Future Behavior

If SP becomes less than 5:

- active SP icons = glowing gold
- inactive SP icons = dim gray/dark
- text updates accordingly, e.g. `SP 3/5`

---

## 6.9 Action Buttons

### Required Buttons

- `Attack`
- `Skill`
- `Ultimate`

### Removed Button

- Remove `Restart` button from battle UI.

### Position

Bottom-right.

### Visual

Use circular icon buttons.

Recommended states:

| Button | State | Visual |
|---|---|---|
| Attack | Active | blue/cyan glow |
| Skill | Active | gold/white glow |
| Ultimate | Disabled if not ready | dim gray, low opacity |

### Rules

- No enclosing rectangle around all skill buttons.
- No square button backgrounds.
- No big box behind the command area.
- Labels below each button.
- Icons should be readable and consistent.

### Interaction

- Attack remains clickable.
- Skill remains clickable when requirements are met.
- Ultimate must reflect disabled/enabled state correctly.
- Disabled state should be clear but still stylish.

---

## 7. What Must Be Removed

Remove these from the previous UI:

- Large bottom-center `Player Turn` panel.
- Text: `A Lesser Abyss appears. Choose Takashi's first action.`
- Restart button.
- `Menu` text label beside hamburger button.
- Big rectangular skill/action panel.
- Square turn-order boxes.
- Per-character SP dots/diamonds in Takashi panel.
- Floating SP/resource diamonds above Takashi.
- Floating SP/resource diamonds above Lesser Abyss.
- Any large black box that blocks too much of the battlefield.

---

## 8. UI Style Tokens

Use these as guidance, not hardcoded mandatory values.

### Colors

```text
Background overlay: rgba(4, 10, 18, 0.55)
Panel border cyan: #7DDCFF
Panel border gold: #D8B76A
Text primary: #F4F0E6
Text secondary: #B8C7D9
Takashi HP: #35D66B
Enemy HP: #4AAFFF or #E24658
SP active gold: #F2C96B
SP inactive: #2B3442
Disabled icon: rgba(160, 170, 180, 0.35)
```

### Radius

```text
Panel radius: 12–18 px equivalent
Circular buttons: true circle
Portrait chips: true circle
```

### Line Weight

```text
Thin border: 1–2 px
No thick decorative frames
```

### Glow

Use glow subtly:

- active button glow
- current turn glow
- lit SP icons glow

Avoid:

- heavy bloom
- huge shadow
- noisy effects

---

## 9. Typography Direction

Typography should feel:

- readable
- premium
- fantasy
- not overly decorative

Recommended approach:

- Use project font if already defined.
- If no custom font exists, use a clean readable font and style it with size/weight/color.
- Do not depend on unavailable external fonts unless already in the repository.

### Suggested Hierarchy

| Text | Treatment |
|---|---|
| `Takashi` | medium-large, white/off-white |
| `Lesser Abyss` | medium, off-white |
| `SP 5/5` | elegant, slightly larger, white/gold |
| Button labels | small-medium, readable |
| `TURN ORDER` | small uppercase, subtle |

---

## 10. Godot Implementation Guidance

### Preferred Node Structure

Exact structure can follow the existing repo, but the final hierarchy should be organized.

Example:

```text
BattleScene
├── BackgroundLayer
│   └── ForestBackground
├── Combatants
│   ├── TakashiSprite
│   ├── LesserAbyssSprite
│   ├── TakashiFloatingHp
│   └── EnemyFloatingHp
├── CanvasLayer
│   └── BattleHUD
│       ├── TurnOrderColumn
│       ├── EnemyHeader
│       │   ├── EnemyNameStrip
│       │   └── MenuButton
│       ├── PlayerStatusPanel
│       ├── SharedSpDisplay
│       │   ├── SpText
│       │   └── PadiIconRow
│       └── ActionButtons
│           ├── AttackButton
│           ├── SkillButton
│           └── UltimateButton
```

### Naming Rules

Use descriptive node names:

- `TurnOrderColumn`
- `EnemyHeader`
- `EnemyMenuButton`
- `PlayerStatusPanel`
- `SharedSpDisplay`
- `PadiIconRow`
- `AttackActionButton`
- `SkillActionButton`
- `UltimateActionButton`

Avoid vague names:

- `Panel1`
- `Button2`
- `Node3`
- `Temp`
- `TestUI`

---

## 11. Responsive / Resolution Rules

Target at least:

- 1280x720
- 1366x768
- 1920x1080

Rules:

- UI anchors should be used properly.
- Bottom-left panel stays bottom-left.
- Action buttons stay bottom-right.
- SP display stays near action buttons.
- Turn order stays left.
- Enemy strip stays top-right.
- UI should not overlap Takashi or Lesser Abyss at common 16:9 resolutions.

---

## 12. Battle Logic Preservation

Do not change:

- HP values and update logic
- SP cost logic
- Ultimate charge logic
- turn order logic
- win/lose flow
- restart/reload behavior outside UI if it exists elsewhere
- attack/skill effects
- enemy turn behavior

The task is visual/UI implementation only.

If you need to connect UI updates:

- connect to existing state variables
- do not create fake duplicate state
- do not hardcode values unless the current scene is already a static prototype and documented

---

## 13. Documentation Requirements

Update `README.md` only if relevant.

Document:

- where Battle UI scene/components live
- where SP icon assets live
- how shared SP display works
- how to replace action icons
- how to test BattleScene
- known limitations

If no setup or usage changes happen, mention that no README update was needed.

---

## 14. Quality Rules

Do:

- keep changes small and reviewable
- preserve existing working logic
- keep UI code clean
- use reusable helper/components if already present
- keep asset paths clear
- test the scene manually

Do not:

- rewrite unrelated systems
- introduce unnecessary dependencies
- add console/debug spam
- leave dead code
- add fake placeholder features
- disable lint rules to hide issues
- use random UI icons unrelated to the project
- overdecorate the UI

---

## 15. Verification Checklist

Before final response, verify:

### Visual

- [ ] Battle background is still visible.
- [ ] Takashi is visible and unobstructed.
- [ ] Lesser Abyss is visible and unobstructed.
- [ ] Turn order is slim and vertical on the left.
- [ ] Enemy strip appears top-right.
- [ ] Menu icon appears beside enemy strip.
- [ ] There is no `Menu` text label.
- [ ] Bottom-left Takashi panel is compact.
- [ ] Takashi panel has no SP dots/diamonds.
- [ ] Shared SP appears near action buttons.
- [ ] `SP 5/5` text is visible and styled.
- [ ] Five glowing padi icons are directly below `SP 5/5`.
- [ ] Attack, Skill, Ultimate are circular buttons.
- [ ] Ultimate disabled state is visually clear.
- [ ] No Restart button appears.
- [ ] No large Player Turn panel appears.
- [ ] No large boxed skill panel appears.
- [ ] No clutter diamonds appear above characters.
- [ ] Floating HP bars are positioned well.

### Functionality

- [ ] Attack still works.
- [ ] Skill still works.
- [ ] Ultimate availability still works.
- [ ] HP updates still work.
- [ ] SP updates still work.
- [ ] Turn order display updates correctly.
- [ ] Enemy turn still works.
- [ ] Win flow still works.
- [ ] Lose flow still works if implemented.
- [ ] No runtime errors in Godot debugger.

### Commands

Run available commands where applicable:

- [ ] install, if needed
- [ ] lint, if available
- [ ] typecheck, if available
- [ ] test, if available
- [ ] build/export check, if available

If a command is unavailable, state it clearly.

---

## 16. Acceptance Criteria

Implementation is accepted only if:

- UI matches the approved less-is-more direction.
- Battlefield is not blocked by large UI boxes.
- Shared SP is no longer per-character.
- Shared SP display shows `SP 5/5`.
- Five glowing padi icons are under `SP 5/5`.
- Action buttons are floating circular icons.
- Restart button is removed.
- Player Turn message panel is removed.
- Menu text is removed but hamburger icon remains.
- Turn order remains readable on the left.
- HP bars remain visible and clean.
- Existing battle logic still works.
- No unnecessary dependencies are added.
- No unrelated systems are modified.

---

## 17. Prompt for Coding Agent

Use this prompt after placing this file in the repository.

```text
Context

Read `battle-ui-spec.md` first and treat it as the source of truth for the BattleScene UI redesign.

This is a Godot 4 2D turn-based RPG project called Destiny Realms. The BattleScene already works, but the UI needs to be redesigned according to the approved minimal dark fantasy battle HUD spec.

Goal

Implement the BattleScene UI according to `battle-ui-spec.md`.

Scope

Only modify the BattleScene UI and necessary supporting UI scripts/assets. Preserve existing battle logic.

Technical Requirements

Before editing:
- inspect the repository structure
- inspect project.godot
- inspect BattleScene node hierarchy
- inspect existing battle scripts
- inspect existing assets and action icons
- inspect README.md

Implement:
- slim vertical turn order on far left
- top-right enemy strip with `Lesser Abyss` and `x1`
- circular hamburger menu button beside enemy strip, without `Menu` text
- compact Takashi panel bottom-left
- floating HP bars above Takashi and Lesser Abyss
- shared SP display near action buttons
- `SP 5/5` text with five glowing padi icons directly below it
- circular action buttons: Attack, Skill, Ultimate
- Ultimate disabled state
- no Restart button
- no large Player Turn panel
- no boxed skill panel
- no per-character SP markers

UI/UX Requirements

The UI must feel clean, premium, minimal, dark fantasy, readable, and “less is more”.
Do not cover the battlefield with bulky panels.
Do not add unnecessary decoration.

Documentation Requirements

Update README.md only if UI structure, assets, scene path, setup, or usage changes need documentation.

Quality Rules

Do not rewrite the battle system.
Do not add unnecessary dependencies.
Do not add debug spam.
Do not leave dead code.
Do not fake unfinished features.
Keep changes small and reviewable.

Verification

Run the project and test BattleScene manually.
Verify Attack, Skill, Ultimate, HP, SP, and turn order still work.
Run lint/typecheck/test/build if available.
If unavailable, state clearly.

Acceptance Criteria

The implementation must satisfy every checklist item in `battle-ui-spec.md`.

Final Response

Return:
1. Summary of changes
2. Files changed
3. How the Battle UI is structured
4. What was removed from the old UI
5. How shared SP is implemented
6. Verification results
7. Lint/typecheck/test/build results
8. Remaining risks or next steps
```

---

## 18. Notes for Future Expansion

Later, when the game has more party members:

- Bottom-left panel should update based on selected/current active character.
- Shared SP remains global.
- Turn order column should support multiple party/enemy portraits.
- Action buttons may change per character.
- Enemy strip can support multiple enemy count or selected enemy name.
- Padi icons should dynamically update based on SP value.
- Ultimate can become active when resource is full.
