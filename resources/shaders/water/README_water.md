# Water: SSR shader

Water shader ported from the "Godot SSR Water" asset you downloaded
(`transparent-ssr-water-shader/`), by Marcel Bankmann, MIT license (see
`LICENSE_water_shader.md`). Supports screen-space reflection, transparency,
3D waves, coastal foam, and fake refraction -- no external texture files
needed, the wave/normal detail comes from procedural noise baked into
`water_material.tres`.

## Cara pakai

1. Drag `scenes/world_3d/components/water_plane_3d.tscn` ke scene manapun
   (Abyss Forest, Werdonia, dll) seperti node biasa.
2. Posisikan dan resize `WaterPlane3D` (ubah `Mesh > Size` di Inspector ke
   ukuran area air kamu -- misal sungai kecil 4x12, atau danau 20x20).
   Perbesar `Subdivide Width/Depth` sebanding kalau areanya jauh lebih besar
   dari 10x10 default (butuh cukup banyak vertex biar gelombang 3D-nya
   kelihatan, bukan cuma miring di 4 sudut).
3. Klik material-nya di Inspector (`Surface Material Override` atau lewat
   mesh resource) buat tuning look-nya. Yang paling sering diubah duluan:
   - `wave_height_scale` -- defaultnya sekarang udah saya turunin ke 0.08
     (pas buat kolam/sungai kecil). Naikin lagi (mis. 0.3-1.0) kalau kamu
     bikin danau/laut yang beneran luas dan mau gelombang lebih dramatis.
   - `color_shallow` / `color_deep` -- warna air.
   - `transparency` -- makin tinggi makin bisa keliatan dasar air.
   - `ssr_mix_strength` -- kekuatan refleksi permukaan (matiin `ssr_max_travel`
     ke 0 kalau performa jadi berat).
4. Nggak perlu registrasi apa pun -- ini murni node visual, plug-and-play.

## File asli

Demo project lengkapnya (dengan contoh scene "Pier" dan shader dasar danau
tambahan `bottom.gdshader`) masih ada di folder
`transparent-ssr-water-shader/` di root project -- itu project Godot
terpisah, bukan bagian dari Destiny Realms, cuma referensi/sumber asalnya.
