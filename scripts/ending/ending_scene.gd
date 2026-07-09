extends Node2D
class_name EndingScene

const PROLOGUE_SCENE_PATH: String = "res://scenes/prologue/prologue_scene.tscn"
const BASE_VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)
const TAKASHI_TALK_TEXTURE: Texture2D = preload("res://public/Takashi portrait 2 (talk).png")
const MITSUKI_TALK_TEXTURE: Texture2D = preload("res://public/Mitsuki portrait 2 (talk).png")
const MAKOTO_TALK_TEXTURE: Texture2D = preload("res://public/Makoto portrait 2 (Talk).png")
const WERDONIA_TEXTURE: Texture2D = preload("res://public/Werdonia.png")
const LOGO_TEXTURE: Texture2D = preload("res://public/LOGO (1).png")
const EPILOG_FRAME_COUNT: int = 186
const EPILOG_FRAME_RATE: float = 15.0
const EPILOG_FRAME_PATH_FORMAT: String = "res://public/epilog_frames/epilog_%03d.jpg"
const EPILOG_AUDIO_PATH: String = "res://public/EpilogAudio.ogg"
const FINAL_BGM_PATH: String = "res://public/Gates_of_Werdonia.mp3"

@onready var forest_background: Sprite2D = get_node_or_null("Background/ForestBackground") as Sprite2D
@onready var sky: Polygon2D = get_node_or_null("Background/Sky") as Polygon2D
@onready var forest_line: Polygon2D = get_node_or_null("Background/ForestLine") as Polygon2D
@onready var ground: Polygon2D = get_node_or_null("Background/Ground") as Polygon2D
@onready var dark_forest_bgm: AudioStreamPlayer = get_node_or_null("DarkForestBgm") as AudioStreamPlayer
@onready var character_layer: Node2D = get_node_or_null("CharacterLayer") as Node2D
@onready var takashi_visual: Node2D = get_node_or_null("CharacterLayer/TakashiVisual") as Node2D
@onready var mitsuki_visual: Node2D = get_node_or_null("CharacterLayer/MitsukiVisual") as Node2D
@onready var makoto_visual: Node2D = get_node_or_null("CharacterLayer/MakotoVisual") as Node2D
@onready var bottom_overlay: ColorRect = get_node_or_null("CanvasLayer/BottomOverlay") as ColorRect
@onready var speaker_name_label: Label = get_node_or_null("CanvasLayer/DialoguePanel/SpeakerNameLabel") as Label
@onready var dialogue_text_label: Label = get_node_or_null("CanvasLayer/DialoguePanel/DialogueTextLabel") as Label
@onready var portrait_frame: Control = get_node_or_null("CanvasLayer/DialoguePanel/PortraitFrame") as Control
@onready var portrait_texture_rect: TextureRect = get_node_or_null("CanvasLayer/DialoguePanel/PortraitFrame/PortraitTextureRect") as TextureRect
@onready var next_button: Button = get_node_or_null("CanvasLayer/DialoguePanel/NextButton") as Button
@onready var dialogue_panel: Panel = get_node_or_null("CanvasLayer/DialoguePanel") as Panel
@onready var final_panel: Panel = get_node_or_null("CanvasLayer/FinalPanel") as Panel
@onready var final_logo_texture: TextureRect = get_node_or_null("CanvasLayer/FinalPanel/LogoTexture") as TextureRect
@onready var final_scrim: ColorRect = get_node_or_null("CanvasLayer/FinalScrim") as ColorRect
@onready var back_button: Button = get_node_or_null("CanvasLayer/FinalPanel/BackButton") as Button
@onready var epilog_frame_player: TextureRect = get_node_or_null("CanvasLayer/EpilogFramePlayer") as TextureRect
@onready var epilog_audio_player: AudioStreamPlayer = get_node_or_null("CanvasLayer/EpilogAudioPlayer") as AudioStreamPlayer
@onready var world_portraits: Dictionary = {
	"Takashi": get_node_or_null("CharacterLayer/WorldTakashiPortrait") as Sprite2D,
	"Mitsuki": get_node_or_null("CharacterLayer/WorldMitsukiPortrait") as Sprite2D,
	"Makoto": get_node_or_null("CharacterLayer/WorldMakotoPortrait") as Sprite2D
}
@onready var world_name_labels: Array[Label] = [
	get_node_or_null("CharacterLayer/TakashiVisual/TakashiLabel") as Label,
	get_node_or_null("CharacterLayer/MitsukiVisual/MitsukiLabel") as Label,
	get_node_or_null("CharacterLayer/MakotoVisual/MakotoLabel") as Label
]

var _current_index: int = 0
var _is_playing_epilog: bool = false
var _epilog_frames: Array[Texture2D] = []
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
	_setup_dark_forest_bgm()
	if next_button != null:
		next_button.pressed.connect(_advance)
	if back_button != null:
		back_button.pressed.connect(_back_to_prologue)
	if final_panel != null:
		final_panel.visible = false
	if final_scrim != null:
		final_scrim.visible = false
	if final_logo_texture != null:
		final_logo_texture.texture = LOGO_TEXTURE
	if epilog_frame_player != null:
		epilog_frame_player.visible = false
	if epilog_audio_player != null:
		epilog_audio_player.stream = load(EPILOG_AUDIO_PATH) as AudioStream
	_hide_world_name_labels()
	_load_epilog_frames()

	await get_tree().process_frame
	_apply_runtime_layout()
	_show_current_entry()


func _unhandled_input(event: InputEvent) -> void:
	if _is_playing_epilog:
		return
	if final_panel != null and final_panel.visible:
		return

	if _is_advance_input(event):
		_advance()
		get_viewport().set_input_as_handled()


func _apply_runtime_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_VIEWPORT_SIZE

	if forest_background != null and forest_background.texture != null:
		var texture_size: Vector2 = forest_background.texture.get_size()
		var cover_scale: float = maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
		forest_background.position = Vector2.ZERO
		forest_background.scale = Vector2(cover_scale, cover_scale)

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
	_layout_world_portraits(viewport_size)


func _show_current_entry() -> void:
	if _current_index >= _dialogue_entries.size():
		_show_final_panel()
		return

	var entry: Dictionary = _dialogue_entries[_current_index]
	if speaker_name_label != null:
		speaker_name_label.text = str(entry.get("speaker", ""))
	if dialogue_text_label != null:
		dialogue_text_label.text = str(entry.get("text", ""))
	var speaker_name: String = str(entry.get("speaker", ""))
	_update_dialogue_portrait(speaker_name)
	_highlight_world_speaker(speaker_name)


func _advance() -> void:
	_current_index += 1
	_show_current_entry()


func _show_final_panel() -> void:
	if _is_playing_epilog:
		return
	_is_playing_epilog = true
	if final_panel != null:
		final_panel.visible = false
	if dialogue_panel != null:
		dialogue_panel.visible = false
	if next_button != null:
		next_button.disabled = true
		next_button.visible = false
	if speaker_name_label != null:
		speaker_name_label.text = ""
	if dialogue_text_label != null:
		dialogue_text_label.text = ""
	if dark_forest_bgm != null:
		dark_forest_bgm.stop()
	for character_name in world_portraits.keys():
		var portrait: Sprite2D = world_portraits[character_name] as Sprite2D
		if portrait != null:
			portrait.modulate = Color(0.72, 0.76, 0.84, 0.82)
	await _play_epilog_sequence()
	_show_werdonia_final_backdrop()
	_is_playing_epilog = false
	if final_panel != null:
		final_panel.visible = true


func _show_werdonia_final_backdrop() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_VIEWPORT_SIZE

	if forest_background != null:
		forest_background.texture = WERDONIA_TEXTURE
		if forest_background.texture != null:
			var texture_size: Vector2 = forest_background.texture.get_size()
			var cover_scale: float = maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
			forest_background.position = Vector2.ZERO
			forest_background.scale = Vector2(cover_scale, cover_scale)

	if sky != null:
		sky.visible = false
	if forest_line != null:
		forest_line.visible = false
	if ground != null:
		ground.visible = false
	if character_layer != null:
		character_layer.visible = false
	if bottom_overlay != null:
		bottom_overlay.visible = false
	if final_scrim != null:
		final_scrim.visible = true
	_play_final_bgm()


func _play_final_bgm() -> void:
	if dark_forest_bgm == null:
		return

	dark_forest_bgm.stop()
	dark_forest_bgm.stream = load(FINAL_BGM_PATH) as AudioStream
	dark_forest_bgm.volume_db = -10.0
	if dark_forest_bgm.stream != null:
		dark_forest_bgm.play()


func _back_to_prologue() -> void:
	get_tree().change_scene_to_file(PROLOGUE_SCENE_PATH)


func _is_advance_input(event: InputEvent) -> bool:
	if InputMap.has_action("confirm_attack") and event.is_action_pressed("confirm_attack"):
		return true

	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_SPACE or event.keycode == KEY_ENTER

	return false


func _update_dialogue_portrait(speaker_name: String) -> void:
	if portrait_texture_rect == null or portrait_frame == null:
		return

	match speaker_name:
		"Takashi":
			portrait_texture_rect.texture = TAKASHI_TALK_TEXTURE
		"Mitsuki":
			portrait_texture_rect.texture = MITSUKI_TALK_TEXTURE
		"Makoto":
			portrait_texture_rect.texture = MAKOTO_TALK_TEXTURE
		_:
			portrait_texture_rect.texture = null

	var has_texture: bool = portrait_texture_rect.texture != null
	portrait_texture_rect.visible = has_texture
	portrait_frame.visible = has_texture


func _highlight_world_speaker(speaker_name: String) -> void:
	for character_name in world_portraits.keys():
		var portrait: Sprite2D = world_portraits[character_name] as Sprite2D
		if portrait == null:
			continue

		if character_name == speaker_name:
			portrait.modulate = Color(1.0, 1.0, 1.0, 1.0)
			portrait.z_index = 4
		else:
			portrait.modulate = Color(0.52, 0.56, 0.64, 0.72)
			portrait.z_index = 2


func _layout_world_portraits(viewport_size: Vector2) -> void:
	var positions: Dictionary = {
		"Takashi": Vector2(viewport_size.x * 0.2, viewport_size.y * 0.52),
		"Makoto": Vector2(viewport_size.x * 0.65, viewport_size.y * 0.515),
		"Mitsuki": Vector2(viewport_size.x * 0.8, viewport_size.y * 0.51)
	}

	for character_name in world_portraits.keys():
		var portrait: Sprite2D = world_portraits[character_name] as Sprite2D
		if portrait == null:
			continue

		portrait.position = positions[character_name]
		portrait.scale = Vector2(0.24, 0.24)


func _hide_world_name_labels() -> void:
	for label in world_name_labels:
		if label != null:
			label.visible = false


func _load_epilog_frames() -> void:
	_epilog_frames.clear()
	for frame_index in range(1, EPILOG_FRAME_COUNT + 1):
		var frame_path: String = EPILOG_FRAME_PATH_FORMAT % frame_index
		var frame_texture: Texture2D = load(frame_path) as Texture2D
		if frame_texture != null:
			_epilog_frames.append(frame_texture)


func _play_epilog_sequence() -> void:
	if epilog_frame_player == null or _epilog_frames.is_empty():
		return

	epilog_frame_player.visible = true
	epilog_frame_player.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if epilog_audio_player != null and epilog_audio_player.stream != null:
		epilog_audio_player.stop()
		epilog_audio_player.play()

	var frame_duration: float = 1.0 / EPILOG_FRAME_RATE
	for frame_texture in _epilog_frames:
		epilog_frame_player.texture = frame_texture
		await get_tree().create_timer(frame_duration).timeout

	if epilog_audio_player != null:
		epilog_audio_player.stop()
	epilog_frame_player.texture = null
	epilog_frame_player.visible = false


func _setup_dark_forest_bgm() -> void:
	if dark_forest_bgm == null:
		return

	if not dark_forest_bgm.finished.is_connected(_restart_dark_forest_bgm):
		dark_forest_bgm.finished.connect(_restart_dark_forest_bgm)
	if not dark_forest_bgm.playing:
		dark_forest_bgm.play()


func _restart_dark_forest_bgm() -> void:
	if dark_forest_bgm != null:
		dark_forest_bgm.play()
