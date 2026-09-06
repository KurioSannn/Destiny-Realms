# Template Arena: Werdonia Outskirts

File ini panduan buat kamu ngedit `battle_arena_werdonia_outskirts.tscn` manual di
Godot editor. Nggak ada kode procedural di sini — murni scene yang kamu susun
sendiri, sama seperti bikin scene 3D biasa.

## Cara pakai

1. Buka `battle_arena_werdonia_outskirts.tscn` di Godot editor.
2. Node `_ReadmeAndGuides` isinya cuma `Marker3D` penanda posisi — PAKAI buat
   acuan penempatan asset, JANGAN dihapus dulu sampai kamu selesai nempatin
   ground/props. Kalau sudah yakin komposisinya pas, boleh dihapus (marker ini
   tidak dibaca kode apa pun, murni alat bantu visual).
3. Node `PlaceholderGround` itu plane hijau polos — ganti/timpa dengan asset
   tanah/jalan asli kamu, atau hapus kalau ground kamu sendiri sudah cukup.
4. Tambahkan pohon/rumput/props manual pakai asset yang SUDAH ada di project
   (jangan import baru dulu, ini semua sudah lengkap):
   - `Asset 3d/Stylized Nature MegaKit[Standard]/glTF/` — pohon, rumput, batu, jamur
   - `Asset 3d/Medieval Village MegaKit[Standard]/Medieval Village MegaKit[Standard]/glTF/` — reruntuhan, dinding, pagar
   - `Asset 3d/Fantasy Props MegaKit[Standard]/Exports/glTF/` — obor, lentera, peti
5. Simpan. Nggak perlu registrasi manual lain — sudah saya daftarkan otomatis
   (lihat bagian "Wiring" di bawah).

## Kenapa areanya harus di posisi segini?

Kamera battle (`battle_camera_3d.gd`) POSISINYA FIXED, sama untuk semua arena
(belum per-area, itu future work). Jadi supaya panggungmu kelihatan pas di
kamera, taruh ground/props di sekitar titik-titik guide ini:

| Guide Marker | Posisi (X, Y, Z) | Fungsi |
|---|---|---|
| `Guide_ArenaCenter` | (0, 0, 0) | Titik tengah panggung |
| `Guide_PartySlot0_Takashi` | (-2.3, 0, 1.1) | Takashi berdiri di sini |
| `Guide_PartySlot1/2` | (-3.5, 0, 0) / (-4.5, 0, -1.1) | Slot party masa depan (Mitsuki/Makoto) |
| `Guide_EnemySlot0/1/2` | (2.3, 0, 0.5) / (4.8, 0, -2) / (6.4, 0, -4.4) | Musuh berdiri di sini |
| `Guide_CameraIdle` | (-1.4, 4.0, 8.6) | Kira-kira posisi kamera saat idle |

Area yang PALING PENTING buat diisi props/ground: sekitar X -6 sampai +8,
Z -6 sampai +2 (itu yang kelihatan kamera). Di luar itu boleh kosong atau
buat backdrop jauh (pohon/gunung latar belakang).

## Wiring (sudah saya siapkan, jangan diubah kecuali paham)

- `resources/battle_arenas/werdonia_outskirts_arena_profile.tres` — data
  profile, `area_id = &"werdonia_outskirts"`, nunjuk ke scene ini.
- `battle_environment_registry.gd` — saya daftarkan profile ini di
  `_load_built_in_profiles()`, sama kayak Abyss.
- Encounter mana pun yang `EncounterContext.source_area_id`-nya
  `"werdonia_outskirts"` bakal otomatis pakai arena ini. Kalau belum ada
  musuh/encounter yang di-tag area ini, arena ini belum kepakai di
  gameplay manapun — aman disiapkan duluan tanpa mempengaruhi apa pun yang
  sudah jalan sekarang.
