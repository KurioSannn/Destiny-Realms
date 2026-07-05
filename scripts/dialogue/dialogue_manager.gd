extends Panel
class_name DialogueManager

signal dialogue_finished

@onready var speaker_name_label: Label = get_node_or_null("SpeakerNameLabel") as Label
@onready var dialogue_text_label: Label = get_node_or_null("DialogueTextLabel") as Label
@onready var next_button: Button = get_node_or_null("NextButton") as Button
@onready var choices_container: VBoxContainer = get_node_or_null("ChoicesContainer") as VBoxContainer

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
	if next_button != null:
		next_button.pressed.connect(_advance)
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
	if speaker_name_label != null:
		speaker_name_label.text = str(entry.get("speaker", ""))
	if dialogue_text_label != null:
		dialogue_text_label.text = str(entry.get("text", ""))

	var choices: Array = entry.get("choices", []) as Array
	if choices.is_empty():
		_set_choices_visible(false)
		if next_button != null:
			next_button.visible = true
			next_button.disabled = false
			next_button.text = "Next"
	else:
		_show_choices(choices)


func _show_choices(choices: Array) -> void:
	if next_button != null:
		next_button.visible = false
	if choices_container == null:
		return

	_clear_choices()
	choices_container.visible = true

	for choice in choices:
		var choice_data: Dictionary = choice as Dictionary
		var button: Button = Button.new()
		button.text = str(choice_data.get("text", "Choice"))
		button.custom_minimum_size = Vector2(0.0, 42.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_choice_selected.bind(str(choice_data.get("next", ""))))
		choices_container.add_child(button)


func _set_choices_visible(show_choices: bool) -> void:
	if choices_container != null:
		choices_container.visible = show_choices
		if not show_choices:
			_clear_choices()


func _clear_choices() -> void:
	if choices_container == null:
		return

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


func _is_advance_input(event: InputEvent) -> bool:
	if InputMap.has_action("confirm_attack") and event.is_action_pressed("confirm_attack"):
		return true

	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_SPACE or event.keycode == KEY_ENTER

	return false
