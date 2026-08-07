extends Node2D
class_name WorldScene

const LOGIN_SCENE_PATH: String = "res://scenes/login/login_scene.tscn"
const GRASSLANDS_SCENE_PATH: String = "res://scenes/grasslands/grasslands_scene.tscn"

const INTERACTION_GATE: StringName = &"abyss_gate"
const INTERACTION_CITY: StringName = &"werdonia_road"
const INTERACTION_MARKER: StringName = &"ancient_marker"

@onready var player: WorldPlayer = $Player
@onready var abyss_gate_area: Area2D = $InteractionAreas/AbyssGateArea
@onready var werdonia_road_area: Area2D = $InteractionAreas/WerdoniaRoadArea
@onready var ancient_marker_area: Area2D = $InteractionAreas/AncientMarkerArea
@onready var world_bgm: AudioStreamPlayer = $WorldBgm

@onready var location_banner: Panel = $WorldCanvas/LocationBanner
@onready var quest_label: Label = $WorldCanvas/QuestPanel/QuestLabel
@onready var objective_status: Label = $WorldCanvas/QuestPanel/ObjectiveStatus
@onready var interaction_prompt: Panel = $WorldCanvas/InteractionPrompt
@onready var interaction_label: Label = $WorldCanvas/InteractionPrompt/PromptText

@onready var modal_dim: ColorRect = $WorldCanvas/ModalDim
@onready var info_panel: Panel = $WorldCanvas/InfoPanel
@onready var info_title: Label = $WorldCanvas/InfoPanel/InfoTitle
@onready var info_message: Label = $WorldCanvas/InfoPanel/InfoMessage
@onready var close_info_button: Button = $WorldCanvas/InfoPanel/CloseButton
@onready var primary_info_button: Button = $WorldCanvas/InfoPanel/PrimaryButton

@onready var menu_button: Button = $WorldCanvas/MenuButton
@onready var pause_dim: ColorRect = $WorldCanvas/PauseDim
@onready var pause_panel: Panel = $WorldCanvas/PausePanel
@onready var resume_button: Button = $WorldCanvas/PausePanel/ResumeButton
@onready var restart_button: Button = $WorldCanvas/PausePanel/RestartButton
@onready var title_button: Button = $WorldCanvas/PausePanel/TitleButton
@onready var quit_button: Button = $WorldCanvas/PausePanel/QuitButton
@onready var hud_explor: HudExplorPlaceholder = $HudExplorPlaceholder/HUDRoot

var _nearby_interactions: Array[StringName] = []
var _active_interaction: StringName = &""
var _prompt_tween: Tween
var _modal_open: bool = false
var _prompt_rest_position: Vector2
var _intro_playing: bool = true
var _modal_action: StringName = &""


func _ready() -> void:
	hud_explor.show_player_marker = false
	hud_explor.set_player_status("Takashi", 10, 1897.0, 2000.0)
	hud_explor.slot_pressed.connect(_on_hud_slot_pressed)
	location_banner.visible = false
	$WorldCanvas/QuestPanel.visible = false
	menu_button.visible = false
	_sync_placeholder_hud()

	_connect_interaction_area(abyss_gate_area, INTERACTION_GATE)
	_connect_interaction_area(werdonia_road_area, INTERACTION_CITY)
	_connect_interaction_area(ancient_marker_area, INTERACTION_MARKER)

	close_info_button.pressed.connect(_close_info_panel)
	primary_info_button.pressed.connect(_on_primary_info_pressed)
	menu_button.pressed.connect(_open_pause_menu)
	resume_button.pressed.connect(_close_pause_menu)
	restart_button.pressed.connect(_restart_world)
	title_button.pressed.connect(_back_to_title)
	quit_button.pressed.connect(_quit_game)

	_prompt_rest_position = interaction_prompt.position
	interaction_prompt.visible = false
	info_panel.visible = false
	modal_dim.visible = false
	pause_panel.visible = false
	pause_dim.visible = false

	_setup_world_bgm()
	_play_location_intro()
	_play_gate_exit_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _modal_open:
		_close_info_panel()
		get_viewport().set_input_as_handled()
		return
	if (
		event.is_action_pressed("ui_cancel")
		and not _modal_open
		and not get_tree().paused
	):
		_open_pause_menu()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact") and not _modal_open and not get_tree().paused:
		_activate_current_interaction()
		get_viewport().set_input_as_handled()


func _connect_interaction_area(area: Area2D, interaction_id: StringName) -> void:
	area.body_entered.connect(_on_interaction_body_entered.bind(interaction_id))
	area.body_exited.connect(_on_interaction_body_exited.bind(interaction_id))


func _on_interaction_body_entered(body: Node2D, interaction_id: StringName) -> void:
	if body != player or interaction_id in _nearby_interactions:
		return
	_nearby_interactions.append(interaction_id)
	_update_interaction_prompt()


func _on_interaction_body_exited(body: Node2D, interaction_id: StringName) -> void:
	if body != player:
		return
	_nearby_interactions.erase(interaction_id)
	_update_interaction_prompt()


func _update_interaction_prompt() -> void:
	var next_interaction := _choose_active_interaction()
	_active_interaction = next_interaction

	if _intro_playing or _modal_open or next_interaction == &"":
		_set_prompt_visible(false)
		return

	match next_interaction:
		INTERACTION_GATE:
			interaction_label.text = "Lihat kembali Gerbang Abyss"
		INTERACTION_MARKER:
			interaction_label.text = "Baca batu penanda"
		INTERACTION_CITY:
			interaction_label.text = "Ikuti jalan menuju Werdonia"
	_set_prompt_visible(true)


func _choose_active_interaction() -> StringName:
	for interaction_id in [INTERACTION_GATE, INTERACTION_MARKER, INTERACTION_CITY]:
		if interaction_id in _nearby_interactions:
			return interaction_id
	return &""


func _set_prompt_visible(should_show: bool) -> void:
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()

	if should_show:
		if interaction_prompt.visible:
			interaction_prompt.modulate.a = 1.0
			interaction_prompt.position = _prompt_rest_position
			return
		interaction_prompt.visible = true
		interaction_prompt.modulate.a = 0.0
		interaction_prompt.position = _prompt_rest_position + Vector2(0.0, 8.0)
		_prompt_tween = create_tween().set_parallel(true)
		_prompt_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_prompt_tween.tween_property(interaction_prompt, "modulate:a", 1.0, 0.18)
		_prompt_tween.tween_property(interaction_prompt, "position", _prompt_rest_position, 0.18)
	elif interaction_prompt.visible:
		_prompt_tween = create_tween()
		_prompt_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_prompt_tween.tween_property(interaction_prompt, "modulate:a", 0.0, 0.14)
		_prompt_tween.tween_callback(_hide_interaction_prompt)


func _hide_interaction_prompt() -> void:
	interaction_prompt.visible = false


func _activate_current_interaction() -> void:
	match _active_interaction:
		INTERACTION_GATE:
			_open_info_panel(
				"GERBANG ABYSS",
				"Gerbang kuno itu menutup perlahan di belakang mereka. Kabut Dark Forest tertahan di balik segel, sementara cahaya Werdonia terbentang di depan."
			)
		INTERACTION_MARKER:
			_open_info_panel(
				"BATU PENANDA",
				"Ukiran yang aus menyebut dua wajah Werdonia: tanah yang menerima cahaya, dan hutan yang mengingat apa yang dilupakan manusia."
			)
		INTERACTION_CITY:
			objective_status.text = "Perjalanan menuju kota dimulai"
			_sync_placeholder_hud()
			_open_info_panel(
				"JALAN WERDONIA",
				"Jalan batu menurun menuju padang semanggi yang luas. Rute menuju Werdonia City masih panjang, melewati gerbang tua dan jalan kerajaan yang sudah lama tidak dijaga.",
				&"enter_grasslands",
				"Berangkat"
			)


func _open_info_panel(
	title: String,
	message: String,
	action: StringName = &"",
	primary_text: String = ""
) -> void:
	_modal_open = true
	_modal_action = action
	player.set_movement_enabled(false)
	_set_prompt_visible(false)

	info_title.text = title
	info_message.text = message
	close_info_button.text = "Tutup"
	primary_info_button.text = primary_text
	primary_info_button.visible = action != &""
	if primary_info_button.visible:
		close_info_button.position.x = 30.0
		close_info_button.size.x = 230.0
		primary_info_button.position.x = 300.0
		primary_info_button.size.x = 230.0
	else:
		close_info_button.position.x = 172.0
		close_info_button.size.x = 216.0

	modal_dim.visible = true
	info_panel.visible = true
	modal_dim.modulate.a = 0.0
	info_panel.modulate.a = 0.0
	info_panel.scale = Vector2(0.97, 0.97)

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(modal_dim, "modulate:a", 1.0, 0.18)
	tween.tween_property(info_panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(info_panel, "scale", Vector2.ONE, 0.22)

	if primary_info_button.visible:
		primary_info_button.grab_focus()
	else:
		close_info_button.grab_focus()


func _on_primary_info_pressed() -> void:
	if _modal_action != &"enter_grasslands":
		return
	var progress := get_node_or_null("/root/WorldProgress")
	if progress != null:
		progress.set("grassland_spawn", &"clover_start")
	player.set_movement_enabled(false)
	SceneTransition.change_to_file(GRASSLANDS_SCENE_PATH)


func _close_info_panel() -> void:
	if not _modal_open:
		return

	_modal_open = false
	_modal_action = &""
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(modal_dim, "modulate:a", 0.0, 0.14)
	tween.tween_property(info_panel, "modulate:a", 0.0, 0.14)
	await tween.finished

	modal_dim.visible = false
	info_panel.visible = false
	player.set_movement_enabled(true)
	_update_interaction_prompt()


func _play_gate_exit_intro() -> void:
	player.set_movement_enabled(false)
	player.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "modulate:a", 1.0, 0.3)
	tween.tween_property(player, "position", Vector2(1710.0, 675.0), 0.9)
	await tween.finished

	_intro_playing = false
	player.set_movement_enabled(true)
	_update_interaction_prompt()


func _play_location_intro() -> void:
	location_banner.visible = false
	_sync_placeholder_hud()


func _sync_placeholder_hud() -> void:
	if not is_instance_valid(hud_explor):
		return
	hud_explor.set_quest(objective_status.text, quest_label.text)


func _on_hud_slot_pressed(slot_name: StringName) -> void:
	# Visual slots are active; their destination screens are still placeholders.
	print("Exploration HUD slot requested: %s" % slot_name)


func _setup_world_bgm() -> void:
	if not world_bgm.finished.is_connected(_restart_world_bgm):
		world_bgm.finished.connect(_restart_world_bgm)
	if not world_bgm.playing:
		world_bgm.play()


func _restart_world_bgm() -> void:
	world_bgm.play()


func _open_pause_menu() -> void:
	if _modal_open:
		return
	pause_dim.visible = true
	pause_panel.visible = true
	resume_button.grab_focus()
	get_tree().paused = true


func _close_pause_menu() -> void:
	get_tree().paused = false
	pause_dim.visible = false
	pause_panel.visible = false


func _restart_world() -> void:
	get_tree().paused = false
	SceneTransition.reload_current()


func _back_to_title() -> void:
	get_tree().paused = false
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.call("stop_music", 0.3)
	SceneTransition.change_to_file(LOGIN_SCENE_PATH)


func _quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()
