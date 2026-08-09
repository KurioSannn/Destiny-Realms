extends Node

const OUTPUT_PATH := "res://docs/images/hud_explor_asset_sheet_1280x720.png"
const ASSET_NAMES: Array[String] = [
	"CHAR SWIITCH 3.svg",
	"Frame 9.svg",
	"Frame 11.svg",
	"Frame 13.svg",
	"Frame 15.svg",
	"Frame 25.svg",
	"Frame 2.svg",
	"Icon Chat.svg",
	"Icon Quest.svg",
	"Icon History.svg",
	"Rectangle 90.svg",
	"Polygon 9.svg",
	"Vector 819.svg",
	"Segera menuju ke kota Werdonia.svg",
	"1 Km ke kanan.svg",
	"Icon Event.svg",
	"Icon Battle Pass.svg",
	"Icon Gacha.svg",
	"Icon Daily.svg",
	"Icon Bag.svg",
	"Icon Character.svg",
]


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("172327")
	add_child(backdrop)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(20, 16)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	backdrop.add_child(grid)

	for asset_name in ASSET_NAMES:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(298, 124)
		grid.add_child(cell)

		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(298, 94)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture = load("res://public/Hud Exsplor/%s" % asset_name) as Texture2D
		cell.add_child(preview)

		var label := Label.new()
		label.text = asset_name.trim_suffix(".svg")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("e8f4ec"))
		label.add_theme_font_size_override("font_size", 13)
		cell.add_child(label)

	for frame_index in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Could not save HUD asset sheet: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("PASS: captured HUD exploration asset sheet")
	get_tree().quit(0)
