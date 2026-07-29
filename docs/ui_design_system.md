# Destiny Realms UI Design System

## Status dan ruang lingkup

Dokumen ini mendefinisikan fondasi visual UI Destiny Realms. Fondasi ini
terisolasi dari alur game: theme belum dipasang sebagai default theme di
`project.godot`, dan scene preview tidak terhubung ke main scene, transisi,
dialog, battle, atau `WorldProgress`.

Tujuan visualnya adalah **ancient celestial kingdom with fractured destiny**:
permukaan gelap yang tenang, emas sebagai otoritas dan tujuan, teal sebagai
sihir atau panduan aktif, serta ornamen celestial tipis yang tidak mengganggu
keterbacaan.

## File fondasi

| File | Fungsi |
| --- | --- |
| `res://themes/destiny_realms_theme.tres` | Style dan state komponen Godot |
| `res://scripts/ui/ui_tokens.gd` | Token warna, ukuran, jarak, bentuk, dan motion |
| `res://scenes/ui/ui_style_preview.tscn` | Galeri komponen terisolasi |
| `res://scripts/ui/ui_style_preview.gd` | Animasi status, toast, dan ornamen preview |
| `res://docs/images/ui_preview_1280x720.png` | Bukti visual QA 720p |
| `res://docs/images/ui_preview_1920x1080.png` | Bukti visual QA 1080p |

## Token visual

### Warna

| Peran | Nilai | Penggunaan |
| --- | --- | --- |
| Dark Navy | `#080D14` | Latar utama dan panel paling dalam |
| Navy | `#101722` | Surface interaktif dan panel |
| Ivory | `#F1EDE1` | Teks utama |
| Old Gold | `#D8B86A` | Judul area, tujuan, otoritas, aksen penting |
| Magic Teal | `#68C9C4` | Sihir, focus, prompt aktif, energi |
| Danger | `#D86C68` | HP, bahaya, dan destructive feedback |
| Muted | `#A8ADB5` | Teks sekunder dan metadata |

Gunakan warna berdasarkan makna, bukan berdasarkan dekorasi. Gold dan teal
tidak boleh dipakai sebagai warna dominan seluruh panel. Danger hanya untuk
kondisi yang benar-benar berbahaya atau merusak.

### Tipografi

Project belum memiliki font custom. Fondasi sementara memakai font default
Godot agar tidak menambahkan asset dan tidak mengubah wrapping scene lama.

| Token | Ukuran | Penggunaan |
| --- | --- | --- |
| Caption | 12 | Eyebrow, kategori, metadata ringkas |
| Small | 14 | Teks sekunder dan tooltip |
| Body | 16 | Label, tombol, prompt |
| Subtitle | 20 | Subjudul panel |
| Title | 24 | Judul area atau quest |
| Display | 32 | Judul screen yang benar-benar utama |

Hindari ukuran bebas di luar skala ini. Saat font final dipilih, audit ulang
wrapping dialog dan fixed-height panel sebelum migrasi.

### Spacing, bentuk, dan ikon

- Spacing: `4`, `8`, `16`, `24`, `32`.
- Radius: `4` untuk elemen kecil, `6` untuk panel, maksimum `8`.
- Border: `1` px default dan `2` px untuk focus.
- Ikon: `16`, `24`, atau `32` px.
- Motif: diamond, bintang empat titik, constellation line, magic circle tipis,
  dan crystal fragment.

Motif hanya menjadi aksen ber-opacity rendah. Jangan menaruh ornament di bawah
teks penting atau menjadikannya pengganti ikon fungsional.

## Komponen Theme

### Built-in types

- `Label`: Ivory, body 16.
- `Button`: state normal, hover, pressed, disabled, dan focus.
- `Panel` / `PanelContainer`: surface Navy dengan border tipis.
- `ProgressBar`: track gelap dan fill Magic Teal.
- `TooltipPanel` / `TooltipLabel`: surface ringkas dengan teks 14.

### Type variation

| Variation | Penggunaan |
| --- | --- |
| `DisplayTitle` | Judul screen utama |
| `TitleLabel` | Judul panel atau objective |
| `SubtitleLabel` | Hierarki di bawah title |
| `EyebrowLabel` | Kategori uppercase singkat |
| `MutedLabel` | Detail sekunder |
| `HudPanel` | Panel HUD ringan |
| `ElevatedPanel` | Panel menu atau detail yang terangkat |
| `QuestPanel` | Objective aktif dengan aksen Magic Teal |
| `InteractionPanel` | Prompt interaksi dunia |
| `KeyBadge` | Tombol keyboard/controller |
| `ToastPanel` | Feedback non-blocking |
| `HpBar` | ProgressBar dengan fill Danger |
| `TabButton` | Navigasi tab |

Contoh penggunaan di scene:

```text
theme = ExtResource("destiny_realms_theme")
theme_type_variation = &"QuestPanel"
```

Contoh penggunaan token di script:

```gdscript
const UiTokens := preload("res://scripts/ui/ui_tokens.gd")

panel.add_theme_constant_override("margin_left", UiTokens.SPACE_3)
tween.tween_property(control, "modulate:a", 1.0, UiTokens.MOTION_NORMAL)
```

## Motion

- Fast: `0.12` detik untuk hover atau feedback kecil.
- Normal: `0.20` detik untuk toast, prompt, dan pergantian state.
- Slow: `0.36` detik untuk bar atau panel masuk.
- Toast hold: `2.60` detik.

Gunakan `TRANS_QUAD` + `EASE_OUT` untuk elemen masuk. Transisi page sebaiknya
fade/slide pendek dan tidak memblokir input lebih lama dari yang dibutuhkan.
Hormati state input selama tween agar klik ganda tidak memicu transisi ganda.

## Responsive layout

- Target minimum preview: `960x540`.
- Safe margin desktop: horizontal `32`, vertical `24`.
- Gunakan `Container`, anchors, dan size flags untuk layout baru.
- Jangan mengubah ukuran font berdasarkan lebar viewport.
- HUD mempertahankan ukuran baca; ruang ekstra diberikan kembali ke world view.
- Teks panjang wajib memakai wrapping atau minimum width yang terukur.
- Uji minimal pada `1280x720` dan `1920x1080`.

## Audit UI existing

Audit menemukan tujuh scene UI utama:

| Area | Temuan utama |
| --- | --- |
| Login | Style input, button, checkbox, dan panel berdiri sendiri |
| Prologue | Dialogue panel, portrait, pilihan, skip, dan popup |
| Battle | Status, action, turn order, timing UI, dan banyak override runtime |
| Ending | Struktur dialogue mirip prologue dengan style terpisah |
| World | Location banner, quest, prompt, modal info, dan pause menu |
| Grasslands | Banyak pola World diulang |
| Werdonia City | Banyak pola World diulang |

Angka audit statis:

- `158` deklarasi `StyleBoxFlat` langsung di scene.
- `649` properti absolute offset.
- Sekitar `6` penggunaan container pada seluruh scene UI lama.
- Ukuran font tersebar dari `11` sampai `38`.
- Tidak ditemukan `.ttf`, `.otf`, atau `FontFile` custom.
- World, Grasslands, dan Werdonia City mengulang komponen serta style sejenis.
- Prologue dan Ending mengulang struktur dialogue.
- Battle memiliki `56` deklarasi `StyleBoxFlat` dan override runtime paling padat.

Script World, Grasslands, dan City masih mengubah `position` serta `size` secara
runtime. Dialogue dan Battle juga membuat atau mengganti style secara dinamis.
Karena itu migrasi langsung ke container/global theme berisiko mengubah tween,
hit area, wrapping, ukuran bar, dan node path.

## Backlog migrasi yang disarankan

1. Ekstrak komponen pasif: `LocationBanner`, `QuestTracker`,
   `InteractionPrompt`, `Toast`, dan `PausePanel`.
2. Migrasikan satu scene exploration terlebih dahulu, mulai dari Grasslands.
3. Pertahankan nama node, signal, dan public API script saat mengganti style.
4. Pindahkan nilai visual runtime ke `UiTokens`; jangan pindahkan state logic.
5. Setelah tiga scene exploration stabil, satukan dialogue Prologue/Ending.
6. Migrasikan Battle terakhir karena blast radius dan override-nya paling besar.
7. Baru pertimbangkan default theme di `project.godot` setelah regression test.

## Exploration HUD architecture

`res://scenes/ui/exploration/exploration_hud.tscn` adalah facade reusable
berbasis `CanvasLayer`. Scene ini tidak membaca player, map, `WorldProgress`,
Battle Manager, atau singleton lain. Scene dunia menjadi pemilik data dan
mengirim snapshot tampilan melalui API.

```text
ExplorationHUD (CanvasLayer)
`-- HUDRoot (Control, global theme)
    |-- LocationSlot
    |   `-- LocationBanner
    |-- TopRight (VBoxContainer)
    |   |-- QuestTracker
    |   `-- NotificationToast
    |-- CharacterSlot
    |   `-- CharacterStatus
    |-- InteractionSlot (CenterContainer)
    |   `-- InteractionPrompt
    `-- ShortcutSlot
        `-- ShortcutMenu
```

### Component responsibilities

| Komponen | Tanggung jawab |
| --- | --- |
| `LocationBanner` | Mengganti request lama, masuk/keluar otomatis, tidak menumpuk |
| `QuestTracker` | Menampilkan title, objective, dan progress dari luar |
| `InteractionPrompt` | Membaca key keyboard dari InputMap dan memberi fallback |
| `CharacterStatus` | Komponen reusable portrait, level, HP, energy, dan low-HP hint; hidden by default di exploration |
| `NotificationToast` | Satu toast terlihat, antrean maksimum enam pending |
| `ShortcutMenu` | Fokus keyboard dan signal permintaan menu, tanpa membuka scene |
| `ExplorationHUD` | Delegasi API, visibility intent, forwarding signal, HUD mode |

Semua komponen menggunakan `destiny_realms_theme.tres` dan `ui_tokens.gd`.
Tidak ada StyleBox gameplay baru atau override warna lokal pada component scene.

### Public API

```gdscript
show_location(region_name: String, area_name: String)
set_quest(quest_title: String, objective_text: String, progress_text := "")
update_quest_objective(objective_text: String, progress_text := "")
hide_quest_tracker()
show_interaction(action_text: String, input_action := "interact")
hide_interaction()
set_character_status(name: String, level: int, hp: float, max_hp: float,
        energy: float, max_energy: float)
set_health(current_hp: float, max_hp: float)
set_energy(current_energy: float, max_energy: float)
set_portrait(texture: Texture2D)
set_character_status_visible(value: bool)
show_notification(title: String, description := "", type := "default",
        duration := UiTokens.TOAST_HOLD_SECONDS)
set_shortcuts_visible(value: bool)
set_hud_visible(value: bool, animated := true)
set_hud_mode(mode: int)
get_hud_mode() -> int
```

Nilai HP dan energy selalu di-clamp. Maximum `0` menghasilkan bar `0%`, bukan
pembagian dengan nol. UI tidak menyimpan stat sebagai source of truth.

### Signals

```gdscript
signal character_requested
signal inventory_requested
signal quest_requested
signal map_requested
signal settings_requested
signal hud_mode_changed(mode: int)
```

Shortcut hanya mengirim signal. Inventory, quest journal, world map, settings
screen, dan progression tidak dibuat pada tahap ini.

### HUD mode

| Mode | Perilaku |
| --- | --- |
| `NORMAL` | Memulihkan quest, character status, shortcut, dan prompt aktif |
| `DIALOGUE` | Menyembunyikan quest/prompt/shortcut dan meredupkan status |
| `CUTSCENE` | Fade seluruh exploration HUD |
| `MENU` | Fade seluruh exploration HUD |
| `BATTLE_TRANSITION` | Fade seluruh exploration HUD |
| `HIDDEN` | Menyembunyikan seluruh exploration HUD |

Mode hanya mengatur presentasi. Dialogue, menu, battle transition, dan input
dunia tetap harus diatur oleh sistem pemiliknya.

### Animation rules

- Location: fade + slide, tampil `2.5-4.0` detik, request baru kill tween lama.
- Quest update: pulse opacity/scale ringan.
- Interaction: fade + scale kecil; teks sama tidak mengulang animasi.
- HP/energy: tween `MOTION_SLOW`, tween lama dibatalkan.
- Toast: slide + fade, durasi dapat diatur, queue tidak memblokir gameplay.
- HUD root: fade `MOTION_NORMAL`.
- Tidak ada camera motion, shader, bounce besar, atau perpetual flashing.

### Responsive rules

- Safe margin horizontal `32` dan vertical `24`.
- Quest/toast berada dalam satu `VBoxContainer` kanan atas.
- Interaction memakai `CenterContainer` bawah.
- Corner component mempertahankan ukuran baca, bukan mengikuti global scale.
- Teks quest dan toast wrap dengan lebar maksimum `348`.
- Toast dibatasi satu title line dan dua description lines.
- Minimum preview `960x540`; QA wajib `1280x720`, `1600x900`, `1920x1080`.

### Integration example

```gdscript
@onready var hud: ExplorationHUD = $ExplorationHUD

func _ready() -> void:
	hud.set_character_status(
		"Takashi",
		1,
		100.0,
		100.0,
		40.0,
		100.0
	)
	hud.show_location("WERDONIA", "Sunstone Quarter")
	hud.set_quest(
		"Jalan Menuju Takdir",
		"Pergi ke Temple Ward"
	)

func _on_interactable_entered(action_text: String) -> void:
	hud.show_interaction(action_text, "interact")

func _on_interactable_exited() -> void:
	hud.hide_interaction()

func _on_objective_changed(text: String, progress: String) -> void:
	hud.update_quest_objective(text, progress)
	hud.show_notification("Quest diperbarui", text, "quest")

func _on_dialogue_started() -> void:
	hud.set_hud_mode(ExplorationHUD.HudMode.DIALOGUE)

func _on_dialogue_finished() -> void:
	hud.set_hud_mode(ExplorationHUD.HudMode.NORMAL)

func _on_cutscene_started() -> void:
	hud.set_hud_mode(ExplorationHUD.HudMode.CUTSCENE)

func _connect_shortcuts() -> void:
	hud.inventory_requested.connect(_on_inventory_requested)
	hud.map_requested.connect(_on_map_requested)
```

### Preview

`exploration_hud_preview.tscn` adalah debug harness terisolasi. Tombol atau key
`1-9` menguji banner, quest, progress, prompt, HP, energy, queue toast, HUD mode,
dan focus shortcut. `Tab` menavigasi control yang sedang fokus. Preview tidak
masuk ke main flow.

### Migration notes

1. Integrasikan lebih dulu pada salinan/debug Grasslands, bukan map produksi.
2. Hubungkan data dari script map melalui API; jangan pindahkan state ke HUD.
3. Jangan biarkan HUD lama dan `ExplorationHUD` aktif bersamaan.
4. Audit layer Canvas (`20`) terhadap dialogue dan transition overlay.
5. Panggil mode dari hook dialogue/cutscene yang sudah ada tanpa mengubah flow.
6. Setelah satu map lolos regression, terapkan pola yang sama ke World dan City.

## Grasslands debug integration

Scene `res://scenes/grasslands/grasslands_hud_debug.tscn` mewarisi
`grasslands_scene.tscn`. Script adapter
`res://scripts/grasslands/grasslands_hud_debug.gd` extends script Grasslands
existing dan hanya mengganti hook presentasi. Scene utama dan script utama tidak
diubah.

### CanvasLayer decision

| Layer | Isi |
| ---: | --- |
| `0` | World art, interaction area, player, dan camera |
| `20` | Reusable `ExplorationHUD` |
| `40` | `WorldCanvas` debug: modal, pause, dim, dan region fade existing |
| `128` | Global `SceneTransition` fade |

Location, quest, interaction prompt, dan menu button lama disembunyikan hanya
pada inherited debug scene. Modal dialogue, pause panel, dan region fade tetap
dipakai. Layer `40` memastikan modal/dim dapat menutup HUD; transition layer
`128` tetap paling atas.

### Data binding

- Location memakai `_active_region`, `location_title`, dan `location_subtitle`
  yang sudah diisi Grasslands.
- Quest memakai teks `quest_label` dan `objective_status` existing.
- Prompt memakai `_active_interaction` dan hasil mapping label existing.
- Input key diambil dari action `interact` melalui InputMap.
- Portrait memakai derivative asset existing.
- `CharacterStatus` disembunyikan karena exploration belum memiliki runtime
  source untuk level/HP dan Ultimate Energy hanya dimiliki battle.
- Tidak ada polling `_process`; binding terjadi hanya saat state berubah.

### Dialogue and battle hooks

`_open_info_panel()` mengatur mode `DIALOGUE`, lalu menjalankan implementasi
parent. `_close_info_panel()` menunggu modal existing selesai dan memulihkan
`NORMAL`. Interaction result dan dialogue content tidak diubah.

`_start_bandit_battle()` mengatur `BATTLE_TRANSITION`, menunggu
`UiTokens.MOTION_NORMAL`, lalu memanggil implementation parent yang sama.
`SceneTransition`, WorldProgress encounter state, dan battle path tidak diubah.

Pause existing dipakai sebagai placeholder Settings. Saat pause terbuka HUD
masuk `MENU`; tombol Resume existing memulihkan `NORMAL`. Shortcut lain hanya
menulis log dan mengirim notification.

### Visual QA findings

- `1280x720`, `1600x900`, dan `1920x1080`: overflow `0`, primary overlap `0`.
- Player tetap berada di area visual utama dan tidak tertutup prompt.
- Quest dan toast memiliki hierarki jelas serta tidak bertabrakan.
- Modal existing tampil di atas HUD; shortcut dan prompt nonaktif saat dialogue.
- Battle transition menyembunyikan HUD sebelum transition overlay.
- Panel cukup kontras pada grassland terang tanpa menutup world secara dominan.
- Shortcut menu tetap prototype signal-only; tidak ada combat command.

### Permanent migration risks

- Menyalakan HUD baru tanpa mematikan HUD lama akan menghasilkan duplikasi.
- `WorldCanvas` utama masih menggabungkan exploration UI, modal, pause, dan fade.
- Hook mode harus tetap memanggil parent agar movement/dialogue tidak terkunci.
- Canvas layer perlu diaudit ulang jika dialogue dipisah ke layer baru.
- Runtime level/HP exploration belum tersedia; Ultimate Energy tetap battle-only.

Sebelum migrasi permanen, review screenshot dan mainkan debug scene terlebih
dahulu. Setelah disetujui, Blok 4 sebaiknya mengekstrak adapter reusable atau
menambah signal presentasi kecil pada map tanpa memindahkan gameplay state.

### Known limitations

- Input prompt baru memilih event keyboard pertama; controller glyph belum ada.
- Shortcut masih placeholder berbasis teks dan hanya mengirim signal.
- Portrait default memakai asset Takashi existing dan belum memiliki variant.
- Satu toast terlihat pada satu waktu; pending queue dibatasi enam.
- HUD baru terintegrasi pada inherited Grasslands debug, belum pada map utama.
- Resolusi di bawah `960x540` dan layout mobile belum menjadi target.
- Tidak ada minimap, inventory, QuestManager, save system, EXP, atau leveling.

## QA

- Theme dan preview berhasil diparse dan dijalankan pada Godot `4.7-stable`.
- Visual QA `1280x720`: root `1280x720`, minimum `960x540`, overflow `0`.
- Visual QA `1920x1080`: root `1920x1080`, minimum `960x540`, overflow `0`.
- Screenshot diperiksa untuk hierarchy, keterbacaan, focus, panel, bar, prompt,
  dan toast.
- Smoke test load/instantiate lulus untuk delapan scene: Login, Prologue,
  Battle, Ending, World, Grasslands, Werdonia City, dan UI Style Preview.
- Main scene Login berhasil startup headless tanpa error project.
- Exploration HUD behavioral QA lulus untuk zero maximum, InputMap fallback,
  bounded/drained notification queue, mode restore, shortcut signal, dan
  replacement tween.
- Exploration HUD responsive QA:
  - `1280x720`: overflow `0`, primary overlap `0`.
  - `1600x900`: overflow `0`, primary overlap `0`.
  - `1920x1080`: overflow `0`, primary overlap `0`.
- Final smoke test load/instantiate lulus untuk `16` scene: delapan scene
  existing dan delapan scene Exploration UI.
- Screenshot tersedia sebagai `docs/images/exploration_hud_*.png`.
- Grasslands debug functional QA lulus untuk movement, trigger enter/exit,
  InputMap prompt, modal dialogue, mode restore, pause/menu input blocking,
  shortcut signal, notification queue, layer order, dan optimized portrait.
- Blok 3 smoke test load/instantiate lulus untuk `17/17` scene, termasuk scene
  Grasslands utama dan inherited Grasslands HUD debug.
- Main scene Login tetap berhasil startup headless.
- Gameplay screenshot tersedia sebagai `docs/images/grasslands_debug_*.png`.
- Pesan Windows tentang certificate store tidak berhubungan dengan resource UI.

Fondasi ini tidak mengubah gameplay, battle logic, dialogue flow, scene
transition, `WorldProgress`, background, karakter, atau scene game existing.
