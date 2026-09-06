 # Template Open-World: Werdonia Outskirts

`werdonia_outskirts_3d.tscn` -- ini scene EXPLORATION (jalan-jalan beneran),
bukan battle arena. Beda sama `battle_arena_werdonia_outskirts.tscn` yang
cuma diorama pas lagi berantem. Udah tersambung nyata ke gameplay: keluar
dari Abyss Forest (interact di segel) sekarang beneran masuk ke sini,
bukan ke scene 2D lama lagi.

## Yang sudah jalan (jangan disentuh kecuali paham)

- Player (Takashi), kamera eksplorasi, HUD, BGM ("Gates of Werdonia") --
  sama persis sistemnya kayak Abyss Forest.
- `ReturnToAbyssArea` -- area di dekat titik spawn (Z=14.5), interact (E)
  di situ balik ke Abyss Forest. Geser posisinya kalau kamu pindahin
  spawn point.
- `DefaultSpawnPoint` -- titik spawn default (Z=10). Kalau nanti mau lebih
  dari satu titik masuk (misal dari peta lain juga), tinggal duplikat
  Marker3D ini dan kasih `spawn_id` unik.
- 1 contoh `GrassField_Clearing` (rumput GPU-instanced) sudah ada di Z=-8,
  tinggal duplikat/geser/resize. Tingginya sekarang diatur lewat
  `target_height` (meter asli, default 0.26m) bukan skala sembarangan --
  gede-kecilin itu kalau mau rumput lebih pendek/tinggi.

## Cara pakai (sama kayak battle arena kemarin)

1. Buka scene ini di Godot editor.
2. `_ReadmeAndGuides` isinya Marker3D penanda (`Guide_ClearingCenter`,
   `Guide_FarBoundary` di Z=-55, `Guide_ReturnToAbyss`) -- murni visual,
   aman digeser/dihapus kapan saja, tidak dibaca kode apa pun.
3. `Ground` sekarang PlaneMesh polos ukuran 120x120 (udah diperbesar dari
   60x60 semula) -- ganti/timpa dengan ground asli kamu, atau perbesar lagi
   kalau areanya mau lebih luas dari itu.
4. Tambah pohon/rumput/props manual pakai asset yang sudah ada di project
   (sama seperti sebelumnya):
   - `Asset 3d/Stylized Nature MegaKit[Standard]/glTF/`
   - `Asset 3d/Medieval Village MegaKit[Standard]/Medieval Village MegaKit[Standard]/glTF/`
   - `Asset 3d/Fantasy Props MegaKit[Standard]/Exports/glTF/`
   - Rumput: duplikat node `GrassField_Clearing` (lihat instruksi rumput).
   - Air (kalau butuh sungai/kolam): `scenes/world_3d/components/water_plane_3d.tscn`.
5. Musuh eksplorasi belum ada di scene ini -- kalau mau nambahin, contek
   struktur `ExplorationEnemy3D` + `PatrolRoute3D` dari `abyss_forest_3d.tscn`
   (node `TestEnemyStationary`/`TestEnemyPatrol`/`PatrolRoute`), tapi ini
   AGAK BEDA dari Abyss karena itu testbed debug -- untuk encounter battle
   asli, tinggal set `source_area_id = "werdonia_outskirts"` di
   `EncounterContext` biar otomatis masuk `battle_arena_werdonia_outskirts.tscn`
   yang udah kamu dekorasi.

## Kenapa areanya harus di posisi segini?

Sama seperti battle arena: kamera eksplorasi (`exploration_camera_3d.gd`)
posisinya generic/ngikutin player, jadi bebas kamu susun ground/props di
mana saja asal masih di sekitar path yang bisa dilewati player berjalan
dari spawn point (Z=10) ke arah manapun kamu mau.
