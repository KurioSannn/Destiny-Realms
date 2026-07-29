# Destiny Realms UI Asset Audit

## Scope

Audit ini dilakukan untuk integrasi Exploration HUD pada Grasslands debug.
Folder `public/` berisi:

| Format | Jumlah |
| --- | ---: |
| PNG | 54 |
| JPG animation frames | 274 |
| SVG | 1 |
| MP3 | 11 |
| OGG | 2 |
| MP4 | 2 |

File `.import` tidak dihitung sebagai source asset. Tidak ada asset master yang
dihapus, dipindahkan, atau diganti namanya.

## Candidate assets

| Asset | Path | Ukuran | Kandidat penggunaan | Status | Optimasi |
| --- | --- | ---: | --- | --- | --- |
| Takashi portrait | `public/Takashi portrait 1.png` | 1254x1254 PNG | Character status | Master source | Ya |
| Takashi talking | `public/Takashi portrait 2 (talk).png` | 1254x1254 PNG | Dialogue portrait | Tidak dipakai HUD | Nanti bila dialogue dimigrasi |
| Attack skill | `public/AttackSkillTakashi.png` | 3919x3919 PNG | Battle skill art | Tidak dipakai | Optimalkan saat Battle UI |
| Basic skill | `public/BasicSkillTakashi.png` | 3919x3919 PNG | Battle skill art | Tidak dipakai | Optimalkan saat Battle UI |
| Ultimate skill | `public/UltimateSkillTakashi.png` | 3919x3919 PNG | Ultimate preview | Tidak dipakai | Optimalkan saat Battle UI |
| Basic attack | `public/BasicAttackTaka.png` | 2508x2508 PNG | Battle action | Tidak dipakai | Optimalkan saat Battle UI |
| Skill portrait | `public/SkillTakashi.png` | 1254x1254 PNG | Character skill preview | Tidak dipakai | Belum diperlukan |
| Skill art | `public/SkillTaka.png` | 2508x2508 PNG | Battle action | Tidak dipakai | Belum diperlukan |
| Idle character art | `public/IdleTaka.png` | 2508x2508 PNG | Character menu | Tidak dipakai HUD | Belum diperlukan |
| Dialogue frame | `public/DialogFrame.png` | 3919x3919 PNG | Dialogue frame | Tidak dipakai HUD | Terlalu ornamental |
| Celestial symbol | `public/skill_point_triangle.svg` | 24x24 SVG | Marker/focus | Kandidat | Tidak perlu resize |
| Game logo | `public/LOGO (1).png` | 2508x2508 PNG | Branding/login | Tidak relevan | Tidak dipakai HUD |

Skill art adalah ilustrasi detail dan tidak cocok sebagai ikon Exploration HUD
24-32 px. `DialogFrame.png` memiliki identitas fantasy yang sesuai, tetapi
visualnya terlalu berat untuk HUD exploration yang harus ringan.

## Grasslands runtime assets

| Asset | Path | Ukuran | Penggunaan |
| --- | --- | ---: | --- |
| Clover Reach | `public/grasslands/clover_reach.png` | 1672x941 PNG | World background existing |
| Old Stone Crossing | `public/grasslands/old_stone_crossing.png` | 1672x941 PNG | World background existing |
| Takashi idle 1-4 | `public/idle_Takashi/*.png` | 1254x1254 PNG | Existing player animation |
| Clover music | `public/Across_the_Clover_Path.mp3` | Audio | Existing region music |
| Old Stone music | `public/Walking_Past_the_Old_Stone_Gate.mp3` | Audio | Existing region music |

Asset world, player, dan music di atas dipakai oleh scene Grasslands existing.
Integrasi HUD tidak mengubah import setting atau path asset tersebut.

## Optimized derivatives

| Master | Optimized | Awal | Akhir | Penggunaan |
| --- | --- | ---: | ---: | --- |
| `public/Takashi portrait 1.png` | `public/ui/optimized/takashi_portrait_hud_256.png` | 1254x1254, 1.60 MB | 256x256, 83 KB | Character status |

Turunan dibuat dengan Lanczos resize, mempertahankan alpha, dan tidak melakukan
upscale. Master tetap menjadi source art. Tidak ada derivative lain karena
Exploration HUD tidak menggunakan skill art atau dialogue frame.
