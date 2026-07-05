extends Node2D
class_name EndingScene

const PROLOGUE_SCENE_PATH: String = "res://scenes/prologue/prologue_scene.tscn"
const BASE_VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)

@onready var sky: Polygon2D = get_node_or_null("Background/Sky") as Polygon2D
@onready var forest_line: Polygon2D = get_node_or_null("Background/ForestLine") as Polygon2D
@onready var ground: Polygon2D = get_node_or_null("Background/Ground") as Polygon2D
@onready var takashi_visual: Node2D = get_node_or_null("CharacterLayer/TakashiVisual") as Node2D
@onready var mitsuki_visual: Node2D = get_node_or_null("CharacterLayer/MitsukiVisual") as Node2D
@onready var makoto_visual: Node2D = get_node_or_null("CharacterLayer/MakotoVisual") as Node2D
@onready var speaker_name_label: Label = get_node_or_null("CanvasLayer/DialoguePanel/SpeakerNameLabel") as Label
@onready var dialogue_text_label: Label = get_node_or_null("CanvasLayer/DialoguePanel/DialogueTextLabel") as Label
@onready var next_button: Button = get_node_or_null("CanvasLayer/DialoguePanel/NextButton") as Button
@onready var final_panel: Panel = get_node_or_null("CanvasLayer/FinalPanel") as Panel
@onready var back_button: Button = get_node_or_null("CanvasLayer/FinalPanel/BackButton") as Button

var _current_index: int = 0
var _dialogue_entries: Array[Dictionary] = [
	{
		"speaker": "Mitsuki",
		"text": "Itu tadi... bukan sihir biasa."
	},
	{
		"speaker": "Takashi",
		"text": "Aku juga tidak tahu apa yang baru saja kulakukan."
	},
	{
		"speaker": "Makoto",
		"text": "Energinya seperti menghapus sesuatu dari dunia ini."
	},
	{
		"speaker": "Mitsuki",
		"text": "Segitiga itu muncul lagi di matamu."
	},
	{
		"speaker": "Takashi",
		"text": "Segitiga?"
	},
	{
		"speaker": "Makoto",
		"text": "Kita tidak aman di sini. Werdonia punya orang-orang yang bisa membantu."
	},
	{
		"speaker": "Mitsuki",
		"text": "Untuk sementara, ikut kami, Takashi."
	},
	{
		"speaker": "Takashi",
		"text": "Takashi... baiklah. Aku ikut."
	}
]


func _ready() -> void:
	if next_button != null:
		next_button.pressed.connect(_advance)
	if back_button != null:
		back_button.pressed.connect(_back_to_prologue)
	if final_panel != null:
		final_panel.visible = false

	await get_tree().process_frame
	_apply_runtime_layout()
	_show_current_entry()


func _unhandled_input(event: InputEvent) -> void:
	if final_panel != null and final_panel.visible:
		return

	if _is_advance_input(event):
		_advance()
		get_viewport().set_input_as_handled()


func _apply_runtime_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_VIEWPORT_SIZE

	if sky != null:
		sky.polygon = PackedVector2Array([
			Vector2.ZERO,
			Vector2(viewport_size.x, 0.0),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])
	if forest_line != null:
		forest_line.polygon = PackedVector2Array([
			Vector2(0.0, viewport_size.y * 0.32),
			Vector2(viewport_size.x * 0.12, viewport_size.y * 0.2),
			Vector2(viewport_size.x * 0.28, viewport_size.y * 0.36),
			Vector2(viewport_size.x * 0.46, viewport_size.y * 0.2),
			Vector2(viewport_size.x * 0.64, viewport_size.y * 0.34),
			Vector2(viewport_size.x * 0.82, viewport_size.y * 0.22),
			Vector2(viewport_size.x, viewport_size.y * 0.3),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])
	if ground != null:
		ground.polygon = PackedVector2Array([
			Vector2(0.0, viewport_size.y * 0.68),
			Vector2(viewport_size.x, viewport_size.y * 0.65),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])

	if takashi_visual != null:
		takashi_visual.position = Vector2(viewport_size.x * 0.3, viewport_size.y * 0.67)
	if mitsuki_visual != null:
		mitsuki_visual.position = Vector2(viewport_size.x * 0.54, viewport_size.y * 0.66)
	if makoto_visual != null:
		makoto_visual.position = Vector2(viewport_size.x * 0.7, viewport_size.y * 0.66)


func _show_current_entry() -> void:
	if _current_index >= _dialogue_entries.size():
		_show_final_panel()
		return

	var entry: Dictionary = _dialogue_entries[_current_index]
	if speaker_name_label != null:
		speaker_name_label.text = str(entry.get("speaker", ""))
	if dialogue_text_label != null:
		dialogue_text_label.text = str(entry.get("text", ""))


func _advance() -> void:
	_current_index += 1
	_show_current_entry()


func _show_final_panel() -> void:
	if final_panel != null:
		final_panel.visible = true
	if next_button != null:
		next_button.disabled = true
		next_button.visible = false
	if speaker_name_label != null:
		speaker_name_label.text = ""
	if dialogue_text_label != null:
		dialogue_text_label.text = ""


func _back_to_prologue() -> void:
	get_tree().change_scene_to_file(PROLOGUE_SCENE_PATH)


func _is_advance_input(event: InputEvent) -> bool:
	if InputMap.has_action("confirm_attack") and event.is_action_pressed("confirm_attack"):
		return true

	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_SPACE or event.keycode == KEY_ENTER

	return false
