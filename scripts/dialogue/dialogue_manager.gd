extends Panel
class_name DialogueManager

signal dialogue_finished
signal speaker_changed(speaker_name: String)

const TAKASHI_TALK_TEXTURE: Texture2D = preload("res://public/Takashi portrait 2 (talk).png")
const MITSUKI_TALK_TEXTURE: Texture2D = preload("res://public/Mitsuki portrait 2 (talk).png")
const MAKOTO_TALK_TEXTURE: Texture2D = preload("res://public/Makoto portrait 2 (Talk).png")
const TEXT_COLOR: Color = Color(0.9, 0.88, 0.82, 1.0)
const BUTTON_NORMAL_COLOR: Color = Color(0.035, 0.047, 0.07, 0.82)
const BUTTON_HOVER_COLOR: Color = Color(0.085, 0.105, 0.14, 0.9)
const BUTTON_PRESSED_COLOR: Color = Color(0.12, 0.1, 0.06, 0.92)
const BUTTON_BORDER_COLOR: Color = Color(0.55, 0.45, 0.26, 0.78)

@onready var speaker_name_label: Label = $DialoguePanel/SpeakerNameLabel
@onready var dialogue_text_label: Label = $DialoguePanel/DialogueTextLabel
@onready var next_button: Button = $DialoguePanel/NextButton
@onready var choices_container: VBoxContainer = $DialoguePanel/ChoicesContainer
@onready var portrait_frame: Control = $DialoguePanel/PortraitFrame
@onready var portrait_texture_rect: TextureRect = $DialoguePanel/PortraitFrame/PortraitTextureRect

var _active: bool = false
var _current_index: int = 0
var _id_to_index: Dictionary = {}

var _dialogue_entries: Array[Dictionary] = [
	{
		"id": "start",
		"speaker": "Mitsuki",
		"text": "Makoto, ada seseorang di dekat akar pohon itu."
	},
	{
		"speaker": "Makoto",
		"text": "Dia masih hidup. Tapi energinya... aneh. Seperti ada ruang kosong yang menelan mana di sekitarnya."
	},
	{
		"speaker": "Takashi",
		"text": "Di mana... aku?"
	},
	{
		"speaker": "Mitsuki",
		"text": "Kau yang harusnya menjawab. Siapa namamu?"
	},
	{
		"id": "takashi_choice",
		"speaker": "Takashi",
		"text": "Ingatan di kepalaku hanya kabut.",
		"choices": [
			{
				"text": "Aku tidak ingat apa pun.",
				"next": "memory_lost"
			},
			{
				"text": "Jangan mendekat.",
				"next": "stay_back"
			}
		]
	},
	{
		"id": "memory_lost",
		"speaker": "Makoto",
		"text": "Kalau begitu, untuk sementara kami akan membantumu.",
		"next": "memory_lost_mitsuki"
	},
	{
		"id": "memory_lost_mitsuki",
		"speaker": "Mitsuki",
		"text": "Baik. Tapi aku tetap akan mengawasimu.",
		"next": "name_takashi"
	},
	{
		"id": "stay_back",
		"speaker": "Mitsuki",
		"text": "Santai. Kalau kami mau menyerang, dari tadi kau sudah jatuh dua kali.",
		"next": "stay_back_makoto"
	},
	{
		"id": "stay_back_makoto",
		"speaker": "Makoto",
		"text": "Kami bukan musuhmu. Hutan selatan Werdonia bukan tempat aman untuk orang yang terluka.",
		"next": "name_takashi"
	},
	{
		"id": "name_takashi",
		"speaker": "Makoto",
		"text": "Kau tampak seperti pendatang dari Timur. Bagaimana kalau kami memanggilmu Takashi?"
	},
	{
		"speaker": "Takashi",
		"text": "Takashi..."
	},
	{
		"speaker": "Mitsuki",
		"text": "Tunggu. Ada sesuatu bergerak di balik pepohonan."
	},
	{
		"speaker": "Makoto",
		"text": "Abyss. Hanya fragmen kecil, tapi cukup berbahaya."
	},
	{
		"speaker": "Takashi",
		"text": "Ada tanda segitiga yang menyala di tanganku. Aku tidak tahu kenapa... tapi tubuhku tahu cara melawan."
	},
	{
		"speaker": "Mitsuki",
		"text": "Kalau begitu buktikan, Takashi."
	}
]


func _ready() -> void:
	_build_id_lookup()
	next_button.pressed.connect(_advance)
	_apply_button_style(next_button)
	visible = false
	_set_choices_visible(false)


func start_dialogue() -> void:
	_active = true
	_current_index = 0
	visible = true
	_show_current_entry()


func is_dialogue_active() -> bool:
	return _active


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if choices_container != null and choices_container.visible:
		return

	if _is_advance_input(event):
		_advance()
		get_viewport().set_input_as_handled()


func _build_id_lookup() -> void:
	_id_to_index.clear()
	for index in range(_dialogue_entries.size()):
		var entry: Dictionary = _dialogue_entries[index]
		if entry.has("id"):
			_id_to_index[entry["id"]] = index


func _show_current_entry() -> void:
	if _current_index < 0 or _current_index >= _dialogue_entries.size():
		_finish_dialogue()
		return

	var entry: Dictionary = _dialogue_entries[_current_index]
	var speaker_name: String = str(entry.get("speaker", ""))
	speaker_name_label.text = speaker_name
	dialogue_text_label.text = str(entry.get("text", ""))
	_update_portrait(speaker_name)
	speaker_changed.emit(speaker_name)

	var choices: Array = entry.get("choices", []) as Array
	if choices.is_empty():
		_set_choices_visible(false)
		dialogue_text_label.offset_bottom = 132.0
		next_button.visible = true
		next_button.disabled = false
		next_button.text = "Next >"
	else:
		dialogue_text_label.offset_bottom = 98.0
		_show_choices(choices)


func _show_choices(choices: Array) -> void:
	next_button.visible = false

	_clear_choices()
	choices_container.visible = true

	for choice in choices:
		var choice_data: Dictionary = choice as Dictionary
		var button: Button = Button.new()
		button.text = str(choice_data.get("text", "Choice"))
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_apply_button_style(button)
		button.pressed.connect(_on_choice_selected.bind(str(choice_data.get("next", ""))))
		choices_container.add_child(button)


func _set_choices_visible(show_choices: bool) -> void:
	choices_container.visible = show_choices
	if not show_choices:
		_clear_choices()


func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()


func _advance() -> void:
	if not _active:
		return

	var entry: Dictionary = _dialogue_entries[_current_index]
	if entry.has("next"):
		_show_entry_id(str(entry["next"]))
	else:
		_current_index += 1
		_show_current_entry()


func _on_choice_selected(next_id: String) -> void:
	if not _active:
		return
	if next_id.is_empty():
		_finish_dialogue()
		return

	_show_entry_id(next_id)


func _show_entry_id(entry_id: String) -> void:
	if not _id_to_index.has(entry_id):
		_finish_dialogue()
		return

	_current_index = int(_id_to_index[entry_id])
	_show_current_entry()


func _finish_dialogue() -> void:
	_active = false
	visible = false
	_set_choices_visible(false)
	dialogue_finished.emit()


func _update_portrait(speaker_name: String) -> void:
	match speaker_name:
		"Takashi":
			portrait_texture_rect.texture = TAKASHI_TALK_TEXTURE
			portrait_texture_rect.visible = true
			portrait_frame.visible = true
		"Mitsuki":
			portrait_texture_rect.texture = MITSUKI_TALK_TEXTURE
			portrait_texture_rect.visible = true
			portrait_frame.visible = true
		"Makoto":
			portrait_texture_rect.texture = MAKOTO_TALK_TEXTURE
			portrait_texture_rect.visible = true
			portrait_frame.visible = true
		_:
			portrait_texture_rect.visible = false
			portrait_frame.visible = false


func _apply_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_stylebox_override("normal", _make_button_style(BUTTON_NORMAL_COLOR))
	button.add_theme_stylebox_override("hover", _make_button_style(BUTTON_HOVER_COLOR))
	button.add_theme_stylebox_override("pressed", _make_button_style(BUTTON_PRESSED_COLOR))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(0.0, 0.0, 0.0, 0.0)))


func _make_button_style(background_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = BUTTON_BORDER_COLOR
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _is_advance_input(event: InputEvent) -> bool:
	if InputMap.has_action("confirm_attack") and event.is_action_pressed("confirm_attack"):
		return true

	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_SPACE or event.keycode == KEY_ENTER

	return false
