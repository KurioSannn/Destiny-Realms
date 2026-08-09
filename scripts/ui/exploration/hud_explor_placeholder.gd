extends Control
class_name HudExplorPlaceholder

signal slot_pressed(slot_name: StringName)

## Exploration HUD reconstructed on the original 2048x1138 reference canvas.
## Authored SVGs are only scaled uniformly so no HUD element is stretched.

const REFERENCE_SIZE := Vector2(2048.0, 1138.0)

const ICON_EVENT: Texture2D = preload("res://public/Hud Exsplor/Icon Event.svg")
const ICON_BATTLE_PASS: Texture2D = preload("res://public/Hud Exsplor/Icon Battle Pass.svg")
const ICON_GACHA: Texture2D = preload("res://public/Hud Exsplor/Icon Gacha.svg")
const ICON_DAILY: Texture2D = preload("res://public/Hud Exsplor/Icon Daily.svg")
const ICON_BAG: Texture2D = preload("res://public/Hud Exsplor/Icon Bag.svg")
const ICON_CHARACTER: Texture2D = preload("res://public/Hud Exsplor/Icon Character.svg")
const ICON_QUEST: Texture2D = preload("res://public/Hud Exsplor/Icon Quest.svg")
const ICON_HISTORY: Texture2D = preload("res://public/Hud Exsplor/Icon History.svg")
const ICON_PARTY: Texture2D = preload("res://public/Hud Exsplor/Frame 25.svg")
const ICON_CHAT: Texture2D = preload("res://public/Hud Exsplor/Icon Chat.svg")
const QUEST_GLOW: Texture2D = preload("res://public/Hud Exsplor/Rectangle 90.svg")
const QUEST_POINTER: Texture2D = preload("res://public/Hud Exsplor/Polygon 9.svg")
const QUEST_DIVIDER: Texture2D = preload("res://public/Hud Exsplor/Vector 819.svg")
const QUEST_TITLE_ART: Texture2D = preload("res://public/Hud Exsplor/Segera menuju ke kota Werdonia.svg")
const QUEST_DISTANCE_ART: Texture2D = preload("res://public/Hud Exsplor/1 Km ke kanan.svg")
const PLAYER_STATUS_ART: Texture2D = preload("res://public/Hud Exsplor/Frame 2.svg")
const STATUS_CHIPS_ART: Texture2D = preload("res://public/Hud Exsplor/Frame 15.svg")
const SKILL_ATTACK_ART: Texture2D = preload("res://public/Hud Exsplor/Frame 11.svg")
const BASIC_ATTACK_ART: Texture2D = preload("res://public/Hud Exsplor/Frame 9.svg")
const CONSUMABLE_ART: Texture2D = preload("res://public/Hud Exsplor/Frame 13.svg")
const TAKASHI_ROW_ART: Texture2D = preload("res://public/Hud Exsplor/CHAR SWIITCH 3.svg")
const TAKASHI_SKILL_ART: Texture2D = preload(
	"res://public/Hud Exsplor/generated/char_switch_3_image_0.png"
)
const TAKASHI_CHARACTER_ART: Texture2D = preload(
	"res://public/Hud Exsplor/generated/char_switch_3_image_1.png"
)

const MAKOTO_PORTRAIT: Texture2D = preload("res://public/Makoto portrait 1.png")
const MITSUKI_PORTRAIT: Texture2D = preload("res://public/Mitsuki portrait 1.png")

const PC_ACTION_SCALE := 0.86
const PC_MINOR_CONTROL_SCALE := 0.88

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
var interaction_prompt_text := ""
## Block 14.5 Part I: reflects ExplorationCharacterController3D's real
## cooldown/enabled state on the Basic/Skill action icons (action_two/
## action_one) -- true means "ready to use," not "on cooldown."
var basic_action_ready := true
var skill_action_ready := true

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


## Contextual interaction prompt (e.g. "[E] Interact"). Pass an empty string
## to hide it. Intended to be driven by whatever currently owns nearest-
## interactable resolution (the exploration character controller today).
func set_interaction_prompt(text: String) -> void:
	if interaction_prompt_text == text:
		return
	interaction_prompt_text = text
	queue_redraw()


func clear_interaction_prompt() -> void:
	set_interaction_prompt("")


## Block 14.5 Part I: drives the Basic/Skill action icon dim state. Intended
## to be polled each frame by whatever owns the player controller (today,
## the world scene), matching how set_player_status() etc. are already
## pushed in rather than pulled.
func set_exploration_actions_ready(basic_ready: bool, skill_ready: bool) -> void:
	if basic_action_ready == basic_ready and skill_action_ready == skill_ready:
		return
	basic_action_ready = basic_ready
	skill_action_ready = skill_ready
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
	if not interaction_prompt_text.is_empty():
		_draw_interaction_prompt()

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
		&"map_journal": Rect2(342, 42, 66, 62),
		&"party_menu": Rect2(435, 43, 62, 62),
		&"quest_tracker": Rect2(72, 220, 405, 145),
		&"codex": Rect2(1375, 39, 70, 66),
		&"waypoint": Rect2(1467, 39, 70, 66),
		&"relic": Rect2(1560, 39, 70, 66),
		&"journal": Rect2(1653, 39, 70, 66),
		&"inventory": Rect2(1745, 39, 70, 66),
		&"character": Rect2(1839, 39, 70, 66),
		&"party_takashi": Rect2(1659, 161, 290, 100),
		&"party_makoto": Rect2(1659, 274, 290, 96),
		&"party_mitsuki": Rect2(1659, 386, 290, 96),
		&"chat": Rect2(132, 978, 48, 48),
		&"consumable": Rect2(1841, 783, 66, 66),
		&"action_one": Rect2(1636, 921, 95, 95),
		&"action_two": Rect2(1785, 899, 115, 115),
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
	_draw_asset_slot(Vector2(375, 72), &"map_journal", ICON_HISTORY)
	_draw_asset_slot(Vector2(466, 74), &"party_menu", ICON_PARTY)


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
	_draw_texture_centered(texture, center, 1.0, CYAN if hovered else Color.WHITE)


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
	_draw_texture_centered(ICON_QUEST, Vector2(108, 255), 1.0, quest_color)

	var marker_center := Vector2(143, 312)
	_draw_texture_centered(QUEST_GLOW, marker_center, 1.0)
	var diamond := PackedVector2Array([
		marker_center + Vector2(0, -13), marker_center + Vector2(13, 0),
		marker_center + Vector2(0, 13), marker_center + Vector2(-13, 0),
	])
	draw_colored_polygon(diamond, ORANGE)
	draw_polyline(diamond, Color(1.0, 0.78, 0.46, 0.95), 2.0, true)
	if quest_title == "Segera menuju ke kota Werdonia":
		draw_texture(QUEST_TITLE_ART, Vector2(164, 304), Color(0.0, 0.0, 0.0, 0.58))
		draw_texture(QUEST_TITLE_ART, Vector2(162, 302), quest_color)
	else:
		_draw_text(quest_title, Vector2(162, 320), 21, quest_color)
	draw_texture(QUEST_DIVIDER, Vector2(161, 322), Color(GOLD, 0.72))
	_draw_texture_centered(QUEST_POINTER, Vector2(176, 341), 0.86, quest_color)
	if quest_distance == "1 Km ke kanan":
		draw_texture(QUEST_DISTANCE_ART, Vector2(192, 332), Color(0.0, 0.0, 0.0, 0.58))
		draw_texture(QUEST_DISTANCE_ART, Vector2(190, 330), Color.WHITE)
	else:
		_draw_text(quest_distance, Vector2(190, 348), 19, GOLD)


func _draw_party_list() -> void:
	_draw_authored_takashi_row(Vector2(1784, 211))
	_draw_party_row(Vector2(1784, 323), &"party_makoto", "Makoto", MAKOTO_PORTRAIT, Color(0.77, 0.83, 0.31, 0.92), 0.86)
	_draw_party_row(Vector2(1784, 435), &"party_mitsuki", "Mitsuki", MITSUKI_PORTRAIT, Color(0.35, 0.54, 0.58, 0.82), 0.72)


func _draw_authored_takashi_row(center: Vector2) -> void:
	const ROW_SCALE := 0.88
	const ROW_SIZE := Vector2(329.0, 113.0)
	var row_origin := center - ROW_SIZE * ROW_SCALE * 0.5
	var row_modulate := CYAN if _hovered_slot == &"party_takashi" else Color.WHITE
	_draw_texture_centered(TAKASHI_ROW_ART, center, ROW_SCALE, row_modulate)

	# Godot's SVG importer does not render embedded data-URI images. These are
	# the two untouched PNGs from the authored SVG, placed back into its exact
	# pattern rectangles so the final row matches the source artwork.
	var skill_rect := Rect2(
		row_origin + Vector2(249.795, 31.7249) * ROW_SCALE,
		Vector2(47.4091, 47.4091) * ROW_SCALE
	)
	draw_texture_rect(TAKASHI_SKILL_ART, skill_rect, false)

	var portrait_rect := Rect2(
		row_origin + Vector2(185.334, 20.207) * ROW_SCALE,
		Vector2(86.945, 86.945) * ROW_SCALE
	)
	var portrait_region := Rect2(304.45, 0.54, 308.08, 307.47)
	draw_texture_rect_region(TAKASHI_CHARACTER_ART, portrait_rect, portrait_region)


func _draw_party_row(
	center: Vector2,
	slot_name: StringName,
	character_name: String,
	portrait_texture: Texture2D,
	accent: Color,
	health_ratio: float
) -> void:
	var color := _slot_color(slot_name)
	var portrait_center := center + Vector2(29, 0)
	var skill_center := center + Vector2(87, 0)
	_draw_text(character_name, center + Vector2(-121, 20), 18, color, 98.0, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_rect(Rect2(center + Vector2(-112, 26), Vector2(101, 4)), Color(0.03, 0.05, 0.04, 0.45), true)
	draw_rect(Rect2(center + Vector2(-112, 26), Vector2(101.0 * health_ratio, 4)), GREEN, true)

	draw_circle(portrait_center, 34.0, GLASS_STRONG)
	var longest_portrait_side := maxf(portrait_texture.get_width(), portrait_texture.get_height())
	var portrait_scale := 68.0 / longest_portrait_side
	_draw_texture_centered(portrait_texture, portrait_center, portrait_scale)
	draw_arc(portrait_center, 34.0, 0.0, TAU, 48, color, 2.0, true)

	draw_circle(skill_center, 32.0, Color(accent, 0.52))
	draw_arc(skill_center, 32.0, 0.0, TAU, 48, Color(color, 0.45), 2.0, true)
	_draw_diamond_glyph(skill_center, 15.0, color)


func _draw_chat_button() -> void:
	var color := _slot_color(&"chat")
	_draw_texture_centered(ICON_CHAT, Vector2(156, 1002), PC_MINOR_CONTROL_SCALE, color)


func _draw_player_status() -> void:
	var status_center := Vector2(1024, 1056)
	if player_level == 10 and roundi(player_hp) == 1897 and roundi(player_max_hp) == 2000:
		_draw_texture_centered(PLAYER_STATUS_ART, status_center, 1.0)
	else:
		_draw_dynamic_player_status(status_center)
	_draw_texture_centered(STATUS_CHIPS_ART, Vector2(1183, 1026), PC_MINOR_CONTROL_SCALE)
	_draw_text(player_name, Vector2(870, 1088), 10, INK_SOFT)


func _draw_action_cluster() -> void:
	_draw_asset_slot(Vector2(1874, 816), &"consumable", CONSUMABLE_ART, PC_MINOR_CONTROL_SCALE)
	_draw_asset_slot(Vector2(1683, 968), &"action_one", SKILL_ATTACK_ART, PC_ACTION_SCALE, skill_action_ready)
	_draw_asset_slot(Vector2(1842, 956), &"action_two", BASIC_ATTACK_ART, PC_ACTION_SCALE, basic_action_ready)


func _draw_dynamic_player_status(center: Vector2) -> void:
	var base := center - Vector2(173.5, 11.0)
	_draw_text("Lv. %d" % player_level, base + Vector2(0, 18), 15, INK)
	var bar_rect := Rect2(base + Vector2(58, 3), Vector2(289, 17))
	draw_rect(bar_rect, Color(0.02, 0.05, 0.03, 0.48), true)
	draw_rect(bar_rect, Color(0.89, 0.88, 0.64, 0.50), false, 1.5, true)
	var hp_ratio := 0.0 if player_max_hp <= 0.0 else player_hp / player_max_hp
	draw_rect(
		Rect2(bar_rect.position + Vector2(3, 3), Vector2((bar_rect.size.x - 6.0) * hp_ratio, 11)),
		GREEN,
		true
	)
	_draw_text(
		"%d/%d" % [roundi(player_hp), roundi(player_max_hp)],
		base + Vector2(145, 18),
		14,
		INK
	)


func _draw_asset_slot(
	center: Vector2,
	slot_name: StringName,
	texture: Texture2D,
	uniform_scale: float = 1.0,
	ready: bool = true
) -> void:
	var color := CYAN if _hovered_slot == slot_name else Color.WHITE
	if not ready:
		color = Color(color, 0.4)
	_draw_texture_centered(texture, center, uniform_scale, color)


func _draw_texture_centered(
	texture: Texture2D,
	center: Vector2,
	uniform_scale: float = 1.0,
	modulate: Color = Color.WHITE
) -> void:
	if texture == null:
		return
	var texture_size := texture.get_size() * uniform_scale
	draw_texture_rect(texture, Rect2(center - texture_size * 0.5, texture_size), false, modulate)


func _draw_interaction_prompt() -> void:
	var pill_size := Vector2(420, 66)
	var pill_position := Vector2(REFERENCE_SIZE.x * 0.5 - pill_size.x * 0.5, 760)
	var pill_rect := Rect2(pill_position, pill_size)
	draw_rect(pill_rect, GLASS_STRONG, true)
	draw_rect(pill_rect, Color(GOLD, 0.7), false, 2.0, true)
	_draw_text(
		interaction_prompt_text,
		pill_position + Vector2(0, 43),
		22,
		INK,
		pill_size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)


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
