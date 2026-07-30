extends Control
class_name LoginScene

const PROLOGUE_SCENE_PATH: String = "res://scenes/prologue/prologue_scene.tscn"
const BUMPER_FRAME_COUNT: int = 209
const BUMPER_FRAME_RATE: float = 15.0
const BUMPER_FRAME_PATH_FORMAT: String = "res://public/login_bumper/frame_%03d.jpg"

@onready var splash_layer: Control = $SplashLayer
@onready var splash_logo: TextureRect = $SplashLayer/DestinyLogo
@onready var splash_title: Label = get_node_or_null("SplashLayer/SplashTitle")
@onready var partner_row: HBoxContainer = $SplashLayer/PartnerLogoRow
@onready var login_layer: Control = $LoginLayer
@onready var username_input: LineEdit = $LoginLayer/UsernameInput
@onready var password_input: LineEdit = $LoginLayer/PasswordInput
@onready var start_button: Button = $LoginLayer/StartButton
@onready var guest_button: Button = $LoginLayer/GuestButton
@onready var error_label: Label = $LoginLayer/ErrorLabel
@onready var login_bgm: AudioStreamPlayer = $LoginBgm
@onready var login_bumper: TextureRect = $LoginBumper

var bumper_frames: Array[Texture2D] = []
var bumper_frame_index: int = 0
var bumper_frame_elapsed: float = 0.0


func _ready() -> void:
	start_button.pressed.connect(_start_game)
	guest_button.pressed.connect(_start_game)
	login_bgm.finished.connect(_on_login_bgm_finished)
	_load_bumper_frames()
	await _play_intro_sequence()


func _on_login_bgm_finished() -> void:
	login_bgm.play()


func _process(delta: float) -> void:
	_advance_bumper_frame(delta)


func _load_bumper_frames() -> void:
	bumper_frames.clear()
	for frame_index in range(1, BUMPER_FRAME_COUNT + 1):
		var frame_path: String = BUMPER_FRAME_PATH_FORMAT % frame_index
		var frame_texture: Texture2D = load(frame_path) as Texture2D
		if frame_texture != null:
			bumper_frames.append(frame_texture)
	if not bumper_frames.is_empty():
		login_bumper.texture = bumper_frames[0]


func _advance_bumper_frame(delta: float) -> void:
	if bumper_frames.size() < 2:
		return
	bumper_frame_elapsed += delta
	var frame_duration: float = 1.0 / BUMPER_FRAME_RATE
	if bumper_frame_elapsed < frame_duration:
		return
	bumper_frame_elapsed -= frame_duration
	bumper_frame_index = wrapi(bumper_frame_index + 1, 0, bumper_frames.size())
	login_bumper.texture = bumper_frames[bumper_frame_index]


func _unhandled_input(event: InputEvent) -> void:
	if not login_layer.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_start_game()


func _play_intro_sequence() -> void:
	login_layer.visible = false
	splash_layer.visible = true
	splash_layer.modulate = Color(1.0, 1.0, 1.0, 0.0)
	splash_logo.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if splash_title != null:
		splash_title.modulate = Color(1.0, 1.0, 1.0, 1.0)
	partner_row.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tween: Tween = create_tween()
	tween.tween_property(splash_layer, "modulate:a", 1.0, 0.45)
	tween.tween_interval(1.0)
	tween.tween_property(splash_logo, "modulate:a", 0.0, 0.35)
	if splash_title != null:
		tween.parallel().tween_property(splash_title, "modulate:a", 0.0, 0.35)
	tween.tween_property(partner_row, "modulate:a", 1.0, 0.45)
	tween.tween_interval(1.0)
	tween.tween_property(splash_layer, "modulate:a", 0.0, 0.4)
	await tween.finished

	splash_layer.visible = false
	login_layer.visible = true
	login_layer.modulate = Color(1.0, 1.0, 1.0, 0.0)
	login_bgm.play()
	var login_tween: Tween = create_tween()
	login_tween.tween_property(login_layer, "modulate:a", 1.0, 0.45)
	await login_tween.finished
	username_input.grab_focus()


func _start_game() -> void:
	error_label.text = ""
	var progress := get_node_or_null("/root/WorldProgress")
	if progress != null:
		progress.call("reset_story")
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.call("stop_music", 0.25)
	SceneTransition.change_to_file(PROLOGUE_SCENE_PATH)
