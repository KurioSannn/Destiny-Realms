# Destiny Realms Battle Asset Audit

## Scope and method

Paths and dimensions were read from the current `public` tree. Existing assets
were not moved, renamed, deleted, or re-exported. "Optimize" means a future
runtime derivative or import-setting pass is recommended; the source master
should remain intact.

## Audit table

| File | Path | Dimensions | Format | Category | Candidate use | Optimize | Notes |
| --- | --- | ---: | --- | --- | --- | --- | --- |
| AttackSkillTakashi | `public/AttackSkillTakashi.png` | 3919x3919 | PNG | Battle icon | Current Skill button | Yes | Strong triangle motif; oversized for a button |
| BasicSkillTakashi | `public/BasicSkillTakashi.png` | 3919x3919 | PNG | Battle icon | Current Basic button | Yes | Name is ambiguous; current scene mapping is authoritative |
| UltimateSkillTakashi | `public/UltimateSkillTakashi.png` | 3919x3919 | PNG | Battle icon | Current Ultimate button | Yes | Needs icon-size derivative and contrast check |
| skill_point_triangle | `public/skill_point_triangle.svg` | 24x24 viewBox | SVG | UI ornament | Skill Point pip | No | Crisp, cheap, and consistent with Takashi motif |
| IdleTaka | `public/IdleTaka.png` | 2508x2508 | PNG | Ready idle | Fallback battle idle | Yes | Large master; frame sequence is preferred at runtime |
| idle Takashi frames | `public/idle_Takashi/1.png` ... `4.png` | 1254x1254 each | PNG x4 | Ready idle | Current normal battle idle | Yes | 4.18 MiB total; consistent compact Takashi art |
| BasicAttackTaka | `public/BasicAttackTaka.png` | 2508x2508 | PNG | Action animation | Fallback Basic pose | Yes | Current manager uses frame sequence first |
| Basic ready/action frames | `public/idleattack/a1.png` ... `a4.png` | 1254x1254 each | PNG x4 | Ready idle / action | Current Basic loop; future Basic ready pose | Yes | 4.24 MiB total; must split ready hold from execution |
| SkillTaka | `public/SkillTaka.png` | 2508x2508 | PNG | Action animation | Fallback Skill pose | Yes | Large master |
| SkillTakashi | `public/SkillTakashi.png` | 1254x1254 | PNG | Action animation | Alternate Skill art | Yes | Not referenced by current battle scene/manager |
| Skill ready/action frames | `public/idleskill/s1.png` ... `s4.png` | 1254x1254 each | PNG x4 | Ready idle / action | Current Skill sequence; future Skill ready idle | Yes | 4.88 MiB total; `s1` is a strong ready-idle candidate |
| UltiTaka | `public/UltiTaka.png` | 2508x2508 | PNG | Action animation | Ultimate fallback pose | Yes | Current fallback texture |
| ultimatetakasshi | `public/ultimatetakasshi.png` | 1254x1254 | PNG | Action animation | Alternate Ultimate art | Yes | Not referenced by current manager |
| Ultimate pre frames | `public/ultiidle/u1.png` ... `u3.png` | 1254x1254 each | PNG x3 | Ready idle | Ultimate ready/charge | Yes | Suitable basis for `ULTIMATE_READY_IDLE` |
| Ultimate post frames | `public/ultiidle/u4.png` ... `u7.png` | 1254x1254 each | PNG x4 | Action recovery | Current Ultimate recovery | Yes | Whole `ultiidle` folder is 8.63 MiB |
| Ultimate cinematic frames | `public/ultimate_frames/takashi_ultimate_001.jpg` ... `088.jpg` | 1280x720 each | JPG x88 | Ultimate cut-in | Current full-screen Ultimate sequence | Review | 4.75 MiB total; already screen-sized, but 88 resources/load calls need profiling |
| TakashiUltimate video | `public/TakashiUltimate.mp4` | Not imported by scene | MP4 | Unused/candidate | Source cinematic candidate | Review | Godot path currently uses extracted JPG frames and OGG |
| TakashiUltimateAudio | `public/TakashiUltimateAudio.ogg` | Audio | OGG | Ultimate cut-in | Current Ultimate audio | No | Referenced directly by manager |
| FVX frames | `public/fvx/FVX1.png` ... `FVX3.png` | 1254x1254 each | PNG x3 | Action animation | Current Ultimate field effect | Yes | 1.99 MiB total; spelling retained because path is live |
| slash | `public/effects/slash.png` | 1254x1254 | PNG | Action animation | Current Basic/enemy slash VFX | Yes | Large for transient effect |
| Splash | `public/effects/Splash.png` | 1254x1254 | PNG | Action animation | Current hit splash | Yes | Large for transient effect |
| Particle Efect | `public/effects/Particle Efect.png` | 1254x1254 | PNG | Action animation | Current projectile/particles | Yes | Filename typo is live; do not rename casually |
| Takashi portrait 1 | `public/Takashi portrait 1.png` | 1254x1254 | PNG | Character portrait | Current battle profile/turn chip | Yes | Runtime UI does not need master resolution |
| Takashi portrait 2 | `public/Takashi portrait 2 (talk).png` | 1254x1254 | PNG | Character portrait | Dialogue expression | Yes | Dialogue asset, not a battle command icon |
| Makoto portrait 1 | `public/Makoto portrait 1.png` | 1254x1254 | PNG | Character portrait | Future party battle profile | Yes | No battle combatant implementation yet |
| Mitsuki portrait 1 | `public/Mitsuki portrait 1.png` | 1254x1254 | PNG | Character portrait | Future party battle profile | Yes | No battle combatant implementation yet |
| HUD Takashi derivative | `public/ui/optimized/takashi_portrait_hud_256.png` | 256x256 | PNG | Character portrait | Exploration/UI preview | No | Existing optimized derivative |
| Bandit Captain | `public/bandits/bandit_captain.png` | 1024x1536 | PNG | Enemy art | Current Bandit Captain encounter | Review | Realistic proportion/detail differs from compact Takashi |
| Lesser Abyss | `scenes/battle/battle_scene.tscn` polygon nodes | Procedural | Scene geometry | Enemy art | Current default enemy | N/A | No external enemy sprite; visual is a placeholder |
| BG1Forest | `public/BG1Forest.png` | 1672x941 | PNG | Battle background | Current Lesser Abyss battle | Review | Good 16:9-ish stage source; 1.63 MiB |
| Old Stone Crossing | `public/grasslands/old_stone_crossing.png` | 1672x941 | PNG | Battle background | Current Bandit Captain battle | Review | Shared with exploration; 2.88 MiB |
| DialogFrame | `public/DialogFrame.png` | 3919x3919 | PNG | UI ornament | Dialogue frame only | Yes | Not a current battle UI frame; too large for HUD use |
| Battle panel styles | `scenes/battle/battle_scene.tscn` subresources | Vector/style data | Godot resource | UI ornament | Current battle HUD frames | No | Current battle UI is StyleBox-based, not image-frame based |
| Iron and Ivy | `public/Iron_and_Ivy.mp3` | Audio | MP3 | Battle audio | Current Lesser Abyss BGM | No | Referenced by battle scene |
| The Clover Clash | `public/The_Clover_Clash.mp3` | Audio | MP3 | Battle audio | Current Bandit encounter BGM | No | Manager path is the version without `(1)` |
| The Clover Clash duplicate | `public/The_Clover_Clash (1).mp3` | Audio | MP3 | Unused/duplicate | None currently | Review | Same byte size as live file; verify hash before future cleanup |
| Generated battle SFX | `scripts/battle/battle_sfx.gd` | Runtime generated | GDScript audio | Battle audio | Current Basic/Skill/Ultimate impacts | Profile | No separate SFX files; CPU-generated streams |

## Category summary

### Battle icon

The three 3919-square command images are used by the current battle scene. They
need small runtime derivatives or import-size limits before a production HUD
pass.

### Ready idle

Normal idle, `idleattack`, `idleskill`, and Ultimate pre-frames already provide
the visual material needed for command-ready poses. Their playback currently
starts as part of action resolution, so the missing work is state ownership,
not asset creation.

### Action animation

Basic, Skill, Ultimate post, FVX, slash, splash, and particle sources are wired
into the current manager. Preserve their paths during the architecture pass.

### Ultimate cut-in

The current implementation uses 88 JPG frames plus
`TakashiUltimateAudio.ogg`. This is a usable baseline. Profile resource loading
and memory before deciding whether to retain frames, use a sprite sheet, or
adopt a supported video pipeline.

### Character portrait

Takashi, Makoto, and Mitsuki have 1254-square portraits. Only Takashi is wired
into battle. The existing 256-square Takashi derivative demonstrates the
preferred UI-size approach.

### Enemy art

Bandit Captain has a finished external sprite. Lesser Abyss remains procedural
placeholder geometry. Bandit Captain is closer to realistic/full anime anatomy,
so future enemy art should be aligned with the official stylized compact anime
direction.

### UI ornament

The triangle SVG is production-friendly. `DialogFrame.png` is dialogue-specific
and oversized. Current battle framing is built from Godot StyleBox resources.

### Unused or uncertain

`SkillTakashi.png`, `ultimatetakasshi.png`, the MP4/probe files, and the
parenthesized Clover Clash copy are not part of the active battle path found in
this audit. Keep them until provenance and intended use are confirmed.

## Optimization priorities

1. Limit command icon import/runtime size to the actual button requirement.
2. Produce or import-size-limit 1254-square animation frames after visual QA.
3. Profile the 88-frame Ultimate loading path and generated SFX cost.
4. Create party/enemy portraits only when their battle implementations exist.
5. Align future enemy proportions and rendering with compact Takashi assets.

