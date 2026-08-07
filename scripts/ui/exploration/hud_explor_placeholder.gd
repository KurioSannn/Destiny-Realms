extends Control
class_name HudExplorPlaceholder

signal slot_pressed(slot_name: StringName)

## Temporary, asset-free reconstruction of HUD EXPLOR.png.
## All drawing coordinates use the reference image canvas so final textures can
## replace individual semantic slots without changing the layout.

const REFERENCE_SIZE := Vector2(2048.0, 1138.0)

const ICON_EVENT: Texture2D = preload("res://public/Hud Atas/Icon Event.svg")
const ICON_BATTLE_PASS: Texture2D = preload("res://public/Hud Atas/Icon Battle Pass.svg")
const ICON_GACHA: Texture2D = preload("res://public/Hud Atas/Icon Gacha.svg")
const ICON_DAILY: Texture2D = preload("res://public/Hud Atas/Icon Daily.svg")
const ICON_BAG: Texture2D = preload("res://public/Hud Atas/Icon Bag.svg")
const ICON_CHARACTER: Texture2D = preload("res://public/Hud Atas/Icon Character.svg")

const INK := Color(0.98, 0.98, 0.93, 0.96)
const INK_SOFT := Color(0.98, 0.98, 0.93, 0.62)
const GLASS := Color(0.05, 0.08, 0.07, 0.26)
const GLASS_STRONG := Color(0.04, 0.06, 0.05, 0.46)
const GREEN := Color(0.13, 0.82, 0.37, 0.92)
const MAP_GREEN := Color(0.08, 0.62, 0.34, 0.76)
const CYAN := Color(0.22, 0.82, 0.90, 0.92)
const GOLD := Color(0.94, 0.72, 0.26, 0.95)
const ORANGE := Color(1.0, 0.56, 0.19, 0.98)

var quest_title := "Segera menuju ke kota Werdonia"
var quest_distance := "1 Km ke kanan"
var player_name := "Takashi"
var player_level := 10
var player_hp := 1897.0
var player_max_hp := 2000.0
var show_player_marker := true

var _font: Font
var _layout_scale := 1.0
var _layout_origin := Vector2.ZERO
var _hovered_slot: StringName = &""
var _slot_rects: Dictionary = {}


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build_slot_rects()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next_hover := _slot_at(_to_reference(event.position))
		if next_hover != _hovered_slot:
			_hovered_slot = next_hover
			queue_redraw()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var slot := _slot_at(_to_reference(mouse_event.position))
			if not slot.is_empty():
				slot_pressed.emit(slot)
				accept_event()


func _has_point(point: Vector2) -> bool:
	return not _slot_at(_to_reference(point)).is_empty()


func set_quest(title: String, distance_text: String) -> void:
	quest_title = title
	quest_distance = distance_text
	queue_redraw()


func set_player_status(
	character_name: String,
	level: int,
	current_hp: float,
	max_hp: float
) -> void:
	player_name = character_name
	player_level = maxi(level, 0)
	player_max_hp = maxf(max_hp, 0.0)
	player_hp = clampf(current_hp, 0.0, player_max_hp)
	queue_redraw()


func _draw() -> void:
	_update_canvas_transform()
	draw_set_transform(_layout_origin, 0.0, Vector2.ONE * _layout_scale)

	_draw_minimap()
	_draw_left_shortcuts()
	_draw_top_menu()
	_draw_quest_tracker()
	_draw_party_list()
	_draw_chat_button()
	_draw_player_status()
	_draw_action_cluster()
	if show_player_marker:
		_draw_world_player_placeholder()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _update_canvas_transform() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_layout_scale = minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	var rendered_size := REFERENCE_SIZE * _layout_scale
	_layout_origin = (size - rendered_size) * 0.5


func _to_reference(local_position: Vector2) -> Vector2:
	_update_canvas_transform()
	if _layout_scale <= 0.0:
		return Vector2.ZERO
	return (local_position - _layout_origin) / _layout_scale


func _build_slot_rects() -> void:
	_slot_rects = {
		&"map_journal": Rect2(333, 32, 88, 78),
		&"party_menu": Rect2(432, 35, 70, 75),
		&"quest_tracker": Rect2(72, 220, 405, 145),
		&"codex": Rect2(1372, 35, 75, 78),
		&"waypoint": Rect2(1463, 35, 75, 78),
		&"relic": Rect2(1554, 35, 75, 78),
		&"journal": Rect2(1650, 35, 75, 78),
		&"inventory": Rect2(1745, 35, 75, 78),
		&"character": Rect2(1842, 35, 75, 78),
		&"party_takashi": Rect2(1640, 160, 290, 100),
		&"party_makoto": Rect2(1640, 272, 290, 100),
		&"party_mitsuki": Rect2(1640, 384, 290, 100),
		&"chat": Rect2(122, 970, 74, 70),
		&"consumable": Rect2(1834, 770, 92, 92),
		&"action_one": Rect2(1616, 892, 142, 142),
		&"action_two": Rect2(1768, 874, 168, 168),
	}


func _slot_at(point: Vector2) -> StringName:
	for slot_name in _slot_rects:
		if (_slot_rects[slot_name] as Rect2).has_point(point):
			return slot_name
	return &""


func _slot_color(slot_name: StringName, base_color: Color = INK) -> Color:
	if _hovered_slot == slot_name:
		return CYAN
	return base_color


func _draw_minimap() -> void:
	var center := Vector2(226, 151)
	draw_circle(center, 98.0, Color(0.02, 0.05, 0.04, 0.28))
	draw_circle(center, 90.0, MAP_GREEN)
	draw_arc(center, 91.0, 0.0, TAU, 96, INK_SOFT, 2.0, true)
	draw_arc(center, 77.0, 0.0, TAU, 96, Color(1, 1, 1, 0.16), 1.0, true)

	var land := PackedVector2Array([
		Vector2(172, 113), Vector2(194, 100), Vector2(214, 82),
		Vector2(239, 91), Vector2(254, 110), Vector2(282, 111),
		Vector2(293, 133), Vector2(277, 151), Vector2(252, 156),
		Vector2(244, 181), Vector2(218, 176), Vector2(197, 194),
		Vector2(169, 181), Vector2(161, 154), Vector2(179, 138),
	])
	draw_colored_polygon(land, Color(0.95, 0.72, 0.38, 0.95))
	draw_polyline(land, INK, 2.0, true)
	draw_circle(Vector2(225, 144), 5.0, CYAN)
	draw_line(Vector2(225, 132), Vector2(225, 156), INK, 2.0, true)
	draw_line(Vector2(213, 144), Vector2(237, 144), INK, 2.0, true)
	_draw_text("N", Vector2(220, 52), 14, INK_SOFT)


func _draw_left_shortcuts() -> void:
	_draw_icon_tile(Vector2(375, 72), &"map_journal", "MAP", 34.0)
	_draw_icon_tile(Vector2(466, 74), &"party_menu", "TEAM", 31.0)


func _draw_top_menu() -> void:
	var items := [
		[Vector2(1410, 72), &"codex", ICON_EVENT],
		[Vector2(1502, 72), &"waypoint", ICON_BATTLE_PASS],
		[Vector2(1595, 72), &"relic", ICON_GACHA],
		[Vector2(1688, 72), &"journal", ICON_DAILY],
		[Vector2(1780, 72), &"inventory", ICON_BAG],
		[Vector2(1874, 72), &"character", ICON_CHARACTER],
	]
	for item in items:
		_draw_top_menu_icon(item[0], item[1], item[2])


func _draw_top_menu_icon(
	center: Vector2,
	slot_name: StringName,
	texture: Texture2D
) -> void:
	var hovered := _hovered_slot == slot_name
	if hovered:
		draw_circle(center, 38.0, Color(0.16, 0.62, 0.62, 0.22))
		draw_arc(center, 37.0, 0.0, TAU, 48, CYAN, 1.5, true)
	var icon_size := Vector2(64.0, 58.0)
	var icon_rect := Rect2(center - icon_size * 0.5, icon_size)
	draw_texture_rect(texture, icon_rect, false, CYAN if hovered else Color.WHITE)


func _draw_icon_tile(
	center: Vector2,
	slot_name: StringName,
	caption: String,
	radius: float
) -> void:
	var color := _slot_color(slot_name)
	draw_circle(center, radius, Color(0.03, 0.05, 0.04, 0.17))
	draw_arc(center, radius - 5.0, 0.0, TAU, 32, color, 2.0, true)
	draw_line(center + Vector2(-12, -9), center + Vector2(12, 9), color, 2.0, true)
	draw_line(center + Vector2(-12, 9), center + Vector2(12, -9), color, 2.0, true)
	_draw_text(caption, center + Vector2(-34, radius + 17), 11, color, 68.0, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_quest_tracker() -> void:
	var quest_color := _slot_color(&"quest_tracker")
	var flag := PackedVector2Array([
		Vector2(76, 236), Vector2(145, 228), Vector2(139, 263),
		Vector2(146, 279), Vector2(75, 286), Vector2(82, 262),
	])
	draw_colored_polygon(flag, Color(0.98, 0.98, 0.93, 0.91))
	draw_polyline(flag, quest_color, 2.0, true)
	draw_dashed_line(Vector2(91, 258), Vector2(131, 246), Color(0.35, 0.38, 0.34, 0.70), 2.0, 5.0)

	var marker_center := Vector2(143, 312)
	var diamond := PackedVector2Array([
		marker_center + Vector2(0, -13), marker_center + Vector2(13, 0),
		marker_center + Vector2(0, 13), marker_center + Vector2(-13, 0),
	])
	draw_colored_polygon(diamond, ORANGE)
	draw_polyline(diamond, Color(1.0, 0.78, 0.46, 0.95), 2.0, true)
	_draw_text(quest_title, Vector2(162, 320), 21, quest_color)
	draw_line(Vector2(161, 327), Vector2(466, 327), Color(GOLD, 0.72), 1.0, true)
	var pointer := PackedVector2Array([
		Vector2(168, 333), Vector2(184, 341), Vector2(168, 349),
	])
	draw_colored_polygon(pointer, quest_color)
	_draw_text(quest_distance, Vector2(190, 348), 19, GOLD)


func _draw_party_list() -> void:
	_draw_party_row(Vector2(1784, 211), &"party_takashi", "Takashi", "T", CYAN, 0.92)
	_draw_party_row(Vector2(1784, 323), &"party_makoto", "Makoto", "M", Color(0.77, 0.83, 0.31, 0.92), 0.86)
	_draw_party_row(Vector2(1784, 435), &"party_mitsuki", "Mitsuki", "M", Color(0.35, 0.54, 0.58, 0.82), 0.72)


func _draw_party_row(
	center: Vector2,
	slot_name: StringName,
	character_name: String,
	initial: String,
	accent: Color,
	health_ratio: float
) -> void:
	var color := _slot_color(slot_name)
	var portrait_center := center + Vector2(29, 0)
	var skill_center := center + Vector2(91, 0)
	_draw_text(character_name, center + Vector2(-128, 22), 20, color, 105.0, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_rect(Rect2(center + Vector2(-122, 28), Vector2(112, 4)), Color(0.03, 0.05, 0.04, 0.45), true)
	draw_rect(Rect2(center + Vector2(-122, 28), Vector2(112.0 * health_ratio, 4)), GREEN, true)

	draw_circle(portrait_center, 39.0, GLASS_STRONG)
	draw_arc(portrait_center, 39.0, 0.0, TAU, 48, color, 2.0, true)
	draw_circle(portrait_center + Vector2(0, -9), 10.0, Color(color, 0.72))
	draw_arc(portrait_center + Vector2(0, 20), 22.0, PI, TAU, 24, Color(color, 0.72), 8.0, true)
	_draw_text(initial, portrait_center + Vector2(-8, 7), 14, GLASS_STRONG)

	draw_circle(skill_center, 37.0, Color(accent, 0.52))
	draw_arc(skill_center, 37.0, 0.0, TAU, 48, Color(color, 0.45), 2.0, true)
	_draw_diamond_glyph(skill_center, 18.0, color)


func _draw_chat_button() -> void:
	var color := _slot_color(&"chat")
	var center := Vector2(156, 1002)
	draw_circle(center + Vector2(5, 6), 27.0, GLASS_STRONG)
	draw_circle(center, 24.0, Color(0.98, 0.98, 0.95, 0.94))
	for x in [-8.0, 0.0, 8.0]:
		draw_circle(center + Vector2(x, 2), 2.7, Color(0.20, 0.24, 0.23, 0.96))
	draw_arc(center, 25.0, 0.0, TAU, 36, color, 1.5, true)


func _draw_player_status() -> void:
	var base := Vector2(819, 1044)
	_draw_text("Lv. %d" % player_level, base + Vector2(0, 20), 18, INK)
	var bar_rect := Rect2(base + Vector2(67, 5), Vector2(343, 17))
	draw_rect(bar_rect, Color(0.02, 0.05, 0.03, 0.48), true)
	draw_rect(bar_rect, Color(0.89, 0.88, 0.64, 0.50), false, 1.5, true)
	var hp_ratio := 0.0 if player_max_hp <= 0.0 else player_hp / player_max_hp
	draw_rect(Rect2(bar_rect.position + Vector2(3, 3), Vector2((bar_rect.size.x - 6.0) * hp_ratio, 11)), GREEN, true)
	_draw_text("%d/%d" % [roundi(player_hp), roundi(player_max_hp)], base + Vector2(164, 20), 16, INK)
	_draw_text(player_name, base + Vector2(67, 42), 12, INK_SOFT)

	var chip_colors := [CYAN, Color(0.82, 0.84, 0.22, 0.95), Color(0.76, 0.27, 0.25, 0.95)]
	for index in chip_colors.size():
		var center := base + Vector2(332 + index * 32, -18)
		draw_circle(center, 13.0, chip_colors[index])
		draw_arc(center, 13.0, 0.0, TAU, 24, INK, 1.0, true)


func _draw_action_cluster() -> void:
	var food_color := _slot_color(&"consumable")
	var food_center := Vector2(1874, 816)
	draw_circle(food_center + Vector2(5, 6), 38.0, GLASS_STRONG)
	draw_circle(food_center, 31.0, Color(0.98, 0.98, 0.94, 0.93))
	draw_arc(food_center, 31.0, 0.0, TAU, 36, food_color, 2.0, true)
	draw_arc(food_center, 16.0, PI + 0.2, TAU - 0.2, 18, GOLD, 9.0, true)
	_draw_text("10", food_center + Vector2(17, 31), 13, food_color)

	_draw_action_button(Vector2(1683, 968), 63.0, &"action_one", "ACT-1")
	_draw_action_button(Vector2(1842, 956), 74.0, &"action_two", "ACT-2")
	for index in 6:
		var angle := lerpf(PI * 0.86, PI * 1.35, float(index) / 5.0)
		var center := Vector2(1683, 968) + Vector2(cos(angle), sin(angle)) * 77.0
		_draw_small_diamond(center, 9.0, ORANGE)


func _draw_action_button(
	center: Vector2,
	radius: float,
	slot_name: StringName,
	caption: String
) -> void:
	var color := _slot_color(slot_name)
	draw_circle(center, radius, Color(0.09, 0.10, 0.07, 0.38))
	draw_circle(center, radius - 8.0, Color(0.45, 0.44, 0.31, 0.24))
	draw_arc(center, radius, 0.0, TAU, 64, Color(color, 0.48), 2.0, true)
	_draw_diamond_glyph(center, radius * 0.43, color)
	_draw_text(caption, center + Vector2(-38, radius + 20), 11, color, 76.0, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_world_player_placeholder() -> void:
	var center := Vector2(1026, 466)
	var outline := Color(1.0, 1.0, 0.96, 0.70)
	draw_circle(center + Vector2(0, -70), 34.0, Color(0.07, 0.08, 0.08, 0.50))
	draw_arc(center + Vector2(0, -70), 34.0, 0.0, TAU, 48, outline, 2.0, true)
	draw_line(center + Vector2(-29, -38), center + Vector2(-43, 68), outline, 6.0, true)
	draw_line(center + Vector2(29, -38), center + Vector2(43, 68), outline, 6.0, true)
	draw_line(center + Vector2(-28, -28), center + Vector2(28, -28), outline, 4.0, true)
	draw_line(center + Vector2(-26, -27), center + Vector2(-18, 70), outline, 5.0, true)
	draw_line(center + Vector2(26, -27), center + Vector2(18, 70), outline, 5.0, true)
	draw_circle(center + Vector2(0, 8), 52.0, Color(0.03, 0.04, 0.04, 0.16))
	_draw_text("PLAYER", center + Vector2(-49, 96), 13, INK_SOFT, 98.0, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_diamond_glyph(center: Vector2, radius: float, color: Color) -> void:
	var diamond := PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius * 0.72, 0),
		center + Vector2(0, radius), center + Vector2(-radius * 0.72, 0),
		center + Vector2(0, -radius),
	])
	draw_polyline(diamond, color, 3.0, true)
	draw_line(center + Vector2(-radius * 0.46, 0), center + Vector2(radius * 0.46, 0), color, 2.0, true)
	draw_line(center + Vector2(0, -radius * 0.64), center + Vector2(0, radius * 0.64), color, 2.0, true)


func _draw_small_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0),
	])
	draw_colored_polygon(points, color)


func _draw_text(
	text: String,
	position: Vector2,
	font_size: int,
	color: Color,
	width: float = -1.0,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	if _font == null:
		return
	draw_string(_font, position, text, alignment, width, font_size, color)
