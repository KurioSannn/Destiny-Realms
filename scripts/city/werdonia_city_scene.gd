extends Node2D
class_name WerdoniaCityScene

const LOGIN_SCENE_PATH: String = "res://scenes/login/login_scene.tscn"
const GRASSLANDS_SCENE_PATH: String = "res://scenes/grasslands/grasslands_scene.tscn"

const GREAT_GATE_MUSIC_PATH: String = "res://public/Before_the_Great_Gates.mp3"
const SUNSTONE_MUSIC_PATH: String = "res://public/Where_Sunlight_Meets_Stone.mp3"

const REGION_GREAT_GATE: StringName = &"great_gate_approach"
const REGION_SUNSTONE: StringName = &"sunstone_quarter"

const INTERACTION_OLD_STONE: StringName = &"return_old_stone"
const INTERACTION_WALL_RECORD: StringName = &"wall_record"
const INTERACTION_SUNSTONE: StringName = &"enter_sunstone"
const INTERACTION_GATE_RETURN: StringName = &"return_great_gate"
const INTERACTION_FOUNTAIN: StringName = &"sunstone_fountain"
const INTERACTION_MARKET: StringName = &"silent_market"
const INTERACTION_TEMPLE: StringName = &"temple_road"

const ACTION_RETURN_OLD_STONE: StringName = &"return_old_stone"
const ACTION_INTRO_NEXT: StringName = &"intro_next"

const SUNSTONE_OFFSET: Vector2 = Vector2(3600.0, 0.0)
const MAP_SIZE: Vector2 = Vector2(3010.0, 1694.0)

const GREAT_GATE_START_SPAWN: Vector2 = Vector2(1250.0, 1480.0)
const GREAT_GATE_RETURN_SPAWN: Vector2 = Vector2(1760.0, 1030.0)
const SUNSTONE_ENTRY_SPAWN: Vector2 = SUNSTONE_OFFSET + Vector2(1450.0, 1480.0)

const ARRIVAL_DIALOGUE: Array[Dictionary] = [
	{
		"title": "MAKOTO",
		"message": "Gerbang Besar Werdonia. Biasanya antrean pedagang sudah memenuhi jembatan ini sebelum tengah hari."
	},
	{
		"title": "MITSUKI",
		"message": "Terlalu sunyi. Penjaga menara masih mengawasi, tetapi gerbang dibiarkan terbuka dan tidak ada pemeriksaan masuk."
	},
	{
		"title": "TAKASHI",
		"message": "Kita masuk bersama. Kalau sesuatu membuat kota ini diam, jawabannya pasti ada di balik tembok itu."
	}
]

@onready var player: WorldPlayer = $Player
@onready var world_camera: Camera2D = $Player/WorldCamera

@onready var old_stone_area: Area2D = $InteractionAreas/OldStoneArea
@onready var wall_record_area: Area2D = $InteractionAreas/WallRecordArea
@onready var sunstone_area: Area2D = $InteractionAreas/SunstoneArea
@onready var gate_return_area: Area2D = $InteractionAreas/GateReturnArea
@onready var fountain_area: Area2D = $InteractionAreas/FountainArea
@onready var market_area: Area2D = $InteractionAreas/MarketArea
@onready var temple_area: Area2D = $InteractionAreas/TempleArea

@onready var location_banner: Panel = $WorldCanvas/LocationBanner
@onready var location_title: Label = $WorldCanvas/LocationBanner/LocationTitle
@onready var location_subtitle: Label = $WorldCanvas/LocationBanner/LocationSubtitle
@onready var quest_label: Label = $WorldCanvas/QuestPanel/QuestLabel
@onready var objective_status: Label = $WorldCanvas/QuestPanel/ObjectiveStatus

@onready var interaction_prompt: Panel = $WorldCanvas/InteractionPrompt
@onready var interaction_label: Label = $WorldCanvas/InteractionPrompt/PromptText

@onready var modal_dim: ColorRect = $WorldCanvas/ModalDim
@onready var info_panel: Panel = $WorldCanvas/InfoPanel
@onready var info_eyebrow: Label = $WorldCanvas/InfoPanel/InfoEyebrow
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
@onready var region_fade: ColorRect = $WorldCanvas/RegionFade

var _active_region: StringName = REGION_GREAT_GATE
var _nearby_interactions: Array[StringName] = []
var _active_interaction: StringName = &""
var _modal_action: StringName = &""
var _intro_step: int = 0
var _modal_open: bool = false
var _region_transitioning: bool = false
var _entry_sequence_playing: bool = true
var _prompt_rest_position: Vector2
var _prompt_tween: Tween


func _ready() -> void:
	_connect_interaction_area(old_stone_area, INTERACTION_OLD_STONE)
	_connect_interaction_area(wall_record_area, INTERACTION_WALL_RECORD)
	_connect_interaction_area(sunstone_area, INTERACTION_SUNSTONE)
	_connect_interaction_area(gate_return_area, INTERACTION_GATE_RETURN)
	_connect_interaction_area(fountain_area, INTERACTION_FOUNTAIN)
	_connect_interaction_area(market_area, INTERACTION_MARKET)
	_connect_interaction_area(temple_area, INTERACTION_TEMPLE)

	close_info_button.pressed.connect(_close_info_panel)
	primary_info_button.pressed.connect(_on_primary_info_pressed)
	menu_button.pressed.connect(_open_pause_menu)
	resume_button.pressed.connect(_close_pause_menu)
	restart_button.pressed.connect(_restart_area)
	title_button.pressed.connect(_back_to_title)
	quit_button.pressed.connect(_quit_game)

	_prompt_rest_position = interaction_prompt.position
	interaction_prompt.visible = false
	modal_dim.visible = false
	info_panel.visible = false
	pause_dim.visible = false
	pause_panel.visible = false
	region_fade.visible = true
	region_fade.modulate.a = 1.0

	var spawn_id := _get_city_spawn()
	match spawn_id:
		&"sunstone_entry":
			_set_region_immediate(REGION_SUNSTONE, SUNSTONE_ENTRY_SPAWN)
		&"great_gate_return":
			_set_region_immediate(REGION_GREAT_GATE, GREAT_GATE_RETURN_SPAWN)
		_:
			_set_region_immediate(REGION_GREAT_GATE, GREAT_GATE_START_SPAWN)

	player.set_movement_enabled(false)
	await get_tree().process_frame
	var entry_tween := create_tween()
	entry_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	entry_tween.tween_property(region_fade, "modulate:a", 0.0, 0.58)
	await entry_tween.finished

	region_fade.visible = false
	_entry_sequence_playing = false
	player.set_movement_enabled(true)
	_play_location_intro()
	_update_interaction_prompt()

	if _active_region == REGION_GREAT_GATE and not _has_seen_city_arrival():
		_set_city_arrival_seen()
		await get_tree().create_timer(0.3).timeout
		_begin_arrival_dialogue()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _modal_open:
		_close_info_panel()
		get_viewport().set_input_as_handled()
		return

	if (
		event.is_action_pressed("interact")
		and not _modal_open
		and not _region_transitioning
		and not get_tree().paused
	):
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
	_active_interaction = _choose_active_interaction()
	if (
		_entry_sequence_playing
		or _region_transitioning
		or _modal_open
		or _active_interaction == &""
	):
		_set_prompt_visible(false)
		return

	match _active_interaction:
		INTERACTION_OLD_STONE:
			interaction_label.text = "Kembali ke Old Stone Crossing"
		INTERACTION_WALL_RECORD:
			interaction_label.text = "Periksa relief tembok"
		INTERACTION_SUNSTONE:
			interaction_label.text = "Masuk ke Werdonia City"
		INTERACTION_GATE_RETURN:
			interaction_label.text = "Kembali ke Gerbang Besar"
		INTERACTION_FOUNTAIN:
			interaction_label.text = "Periksa Fountain of Oaths"
		INTERACTION_MARKET:
			interaction_label.text = "Periksa pasar yang sunyi"
		INTERACTION_TEMPLE:
			interaction_label.text = "Lihat jalan menuju Temple Ward"
	_set_prompt_visible(true)


func _choose_active_interaction() -> StringName:
	var priority: Array[StringName]
	if _active_region == REGION_GREAT_GATE:
		priority = [
			INTERACTION_OLD_STONE,
			INTERACTION_WALL_RECORD,
			INTERACTION_SUNSTONE
		]
	else:
		priority = [
			INTERACTION_GATE_RETURN,
			INTERACTION_FOUNTAIN,
			INTERACTION_MARKET,
			INTERACTION_TEMPLE
		]

	for interaction_id in priority:
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
		INTERACTION_OLD_STONE:
			_open_info_panel(
				"JALAN KERAJAAN",
				"Jembatan di belakang mengarah kembali ke Old Stone Crossing. Jalan itu kini aman setelah kekalahan para bandit.",
				ACTION_RETURN_OLD_STONE,
				"Kembali",
				"Tetap di sini",
				"CATATAN PERJALANAN"
			)
		INTERACTION_WALL_RECORD:
			_open_info_panel(
				"RELIEF DUA MAHKOTA",
				"Relief tua menggambarkan dua penguasa tanpa wajah yang mengangkat kota dari batu sungai. Salah satu mahkota telah dikikis dari sejarah.",
				&"",
				"",
				"Tutup",
				"ARSIP KOTA"
			)
		INTERACTION_SUNSTONE:
			_transition_to_region(REGION_SUNSTONE, SUNSTONE_ENTRY_SPAWN)
		INTERACTION_GATE_RETURN:
			_transition_to_region(REGION_GREAT_GATE, GREAT_GATE_RETURN_SPAWN)
		INTERACTION_FOUNTAIN:
			_open_info_panel(
				"FOUNTAIN OF OATHS",
				"Airnya tetap jernih, tetapi segel batu di dasar kolam tidak lagi memantulkan cahaya. Mitsuki merasakan jejak sihir yang bergerak ke arah Temple Ward.",
				&"",
				"",
				"Tutup",
				"RELIK WERDONIA"
			)
			objective_status.text = "Selidiki jalan menuju Temple Ward"
		INTERACTION_MARKET:
			_open_info_panel(
				"PASAR SUNSTONE",
				"Tenda masih terpasang dan barang dagangan belum dibawa pulang, seolah seluruh pasar ditinggalkan dalam satu tarikan napas. Tidak ada tanda perkelahian.",
				&"",
				"",
				"Tutup",
				"CATATAN PERJALANAN"
			)
		INTERACTION_TEMPLE:
			_open_info_panel(
				"TEMPLE WARD",
				"Gerbang distrik disegel dengan lilin merah kerajaan. Dari balik tembok terdengar dentang logam yang terlalu berat untuk berasal dari bengkel biasa.",
				&"",
				"",
				"Kembali",
				"TUJUAN BERIKUTNYA"
			)
			quest_label.text = "JEJAK DI BALIK TEMBOK"
			objective_status.text = "Cari akses menuju Temple Ward"


func _transition_to_region(region_id: StringName, spawn_position: Vector2) -> void:
	if _region_transitioning:
		return

	var first_sunstone_visit := (
		region_id == REGION_SUNSTONE
		and not _has_reached_sunstone()
	)
	_region_transitioning = true
	player.set_movement_enabled(false)
	_set_prompt_visible(false)
	region_fade.visible = true
	region_fade.modulate.a = 0.0

	var fade_out := create_tween()
	fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(region_fade, "modulate:a", 1.0, 0.44)
	await fade_out.finished

	_set_region_immediate(region_id, spawn_position)
	await get_tree().process_frame

	var fade_in := create_tween()
	fade_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_in.tween_property(region_fade, "modulate:a", 0.0, 0.5)
	await fade_in.finished

	region_fade.visible = false
	_region_transitioning = false
	player.set_movement_enabled(true)
	_play_location_intro()
	_update_interaction_prompt()

	if first_sunstone_visit:
		await get_tree().create_timer(0.25).timeout
		_open_info_panel(
			"SUNSTONE QUARTER",
			"Jantung perdagangan Werdonia terbuka di hadapan mereka. Namun suara air mancur terdengar lebih keras dari kota yang seharusnya ramai.",
			&"",
			"",
			"Jelajahi",
			"WERDONIA CITY"
		)


func _set_region_immediate(region_id: StringName, spawn_position: Vector2) -> void:
	_active_region = region_id
	_nearby_interactions.clear()
	_active_interaction = &""
	player.global_position = spawn_position

	if region_id == REGION_GREAT_GATE:
		player.walkable_polygon = _build_great_gate_walkable_polygon()
		_set_camera_limits(0, 0, int(MAP_SIZE.x), int(MAP_SIZE.y))
		location_title.text = "GREAT GATE OF WERDONIA"
		location_subtitle.text = "Gerbang utara kota tua"
		quest_label.text = "KOTA YANG TERLALU SUNYI"
		objective_status.text = "Masuk melalui gerbang utama"
		_set_city_spawn(
			&"great_gate_return"
			if spawn_position == GREAT_GATE_RETURN_SPAWN
			else &"great_gate_start"
		)
		_play_region_music(GREAT_GATE_MUSIC_PATH)
	else:
		player.walkable_polygon = _build_sunstone_walkable_polygon()
		_set_camera_limits(
			int(SUNSTONE_OFFSET.x),
			0,
			int(SUNSTONE_OFFSET.x + MAP_SIZE.x),
			int(MAP_SIZE.y)
		)
		location_title.text = "SUNSTONE QUARTER"
		location_subtitle.text = "Jantung Werdonia City"
		quest_label.text = "KOTA YANG TERLALU SUNYI"
		objective_status.text = "Jelajahi alun-alun dan pasar"
		_mark_sunstone_reached()
		_play_region_music(SUNSTONE_MUSIC_PATH)

	world_camera.reset_smoothing()


func _set_camera_limits(left: int, top: int, right: int, bottom: int) -> void:
	world_camera.limit_left = left
	world_camera.limit_top = top
	world_camera.limit_right = right
	world_camera.limit_bottom = bottom


func _build_great_gate_walkable_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(450.0, 1660.0),
		Vector2(520.0, 1280.0),
		Vector2(700.0, 1040.0),
		Vector2(1000.0, 840.0),
		Vector2(1300.0, 690.0),
		Vector2(1550.0, 580.0),
		Vector2(1980.0, 570.0),
		Vector2(2310.0, 760.0),
		Vector2(2540.0, 1080.0),
		Vector2(2710.0, 1480.0),
		Vector2(2600.0, 1680.0)
	])


func _build_sunstone_walkable_polygon() -> PackedVector2Array:
	var local_points := PackedVector2Array([
		Vector2(450.0, 1660.0),
		Vector2(350.0, 1380.0),
		Vector2(610.0, 1100.0),
		Vector2(900.0, 920.0),
		Vector2(1210.0, 800.0),
		Vector2(1610.0, 750.0),
		Vector2(2020.0, 610.0),
		Vector2(2410.0, 420.0),
		Vector2(2940.0, 350.0),
		Vector2(2970.0, 920.0),
		Vector2(2710.0, 1210.0),
		Vector2(2550.0, 1620.0),
		Vector2(2100.0, 1680.0),
		Vector2(900.0, 1680.0)
	])
	var world_points := PackedVector2Array()
	for point in local_points:
		world_points.append(point + SUNSTONE_OFFSET)
	return world_points


func _play_region_music(track_path: String) -> void:
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.call("play_track", track_path, -12.0, 1.2)


func _play_location_intro() -> void:
	location_banner.visible = true
	location_banner.modulate.a = 0.0
	location_banner.position.x = 28.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(location_banner, "modulate:a", 1.0, 0.42)
	tween.tween_property(location_banner, "position:x", 46.0, 0.42)
	tween.set_parallel(false)
	tween.tween_interval(2.35)
	tween.tween_property(location_banner, "modulate:a", 0.0, 0.45)


func _begin_arrival_dialogue() -> void:
	_intro_step = 0
	_show_arrival_dialogue_step()


func _show_arrival_dialogue_step() -> void:
	var dialogue: Dictionary = ARRIVAL_DIALOGUE[_intro_step]
	var is_last_step := _intro_step == ARRIVAL_DIALOGUE.size() - 1
	_open_info_panel(
		String(dialogue["title"]),
		String(dialogue["message"]),
		ACTION_INTRO_NEXT,
		"Mulai menjelajah" if is_last_step else "Lanjut",
		"Lewati",
		"DI DEPAN GERBANG"
	)


func _open_info_panel(
	title: String,
	message: String,
	action: StringName,
	primary_text: String,
	close_text: String,
	eyebrow: String
) -> void:
	_modal_open = true
	_modal_action = action
	player.set_movement_enabled(false)
	_set_prompt_visible(false)

	info_eyebrow.text = eyebrow
	info_title.text = title
	info_message.text = message
	close_info_button.text = close_text
	primary_info_button.text = primary_text
	primary_info_button.visible = action != &""
	if primary_info_button.visible:
		close_info_button.position.x = 30.0
		close_info_button.size.x = 245.0
		primary_info_button.position.x = 295.0
		primary_info_button.size.x = 275.0
	else:
		close_info_button.position.x = 177.0
		close_info_button.size.x = 246.0

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
	match _modal_action:
		ACTION_RETURN_OLD_STONE:
			var progress := _get_world_progress()
			if progress != null:
				progress.set("grassland_spawn", &"old_stone_after_battle")
			SceneTransition.change_to_file(GRASSLANDS_SCENE_PATH)
		ACTION_INTRO_NEXT:
			_intro_step += 1
			if _intro_step < ARRIVAL_DIALOGUE.size():
				_show_arrival_dialogue_step()
			else:
				_close_info_panel()


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


func _open_pause_menu() -> void:
	if _modal_open or _region_transitioning:
		return
	pause_dim.visible = true
	pause_panel.visible = true
	resume_button.grab_focus()
	get_tree().paused = true


func _close_pause_menu() -> void:
	get_tree().paused = false
	pause_dim.visible = false
	pause_panel.visible = false


func _restart_area() -> void:
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


func _get_world_progress() -> Node:
	return get_node_or_null("/root/WorldProgress")


func _get_city_spawn() -> StringName:
	var progress := _get_world_progress()
	if progress == null:
		return &"great_gate_start"
	return StringName(progress.get("city_spawn"))


func _set_city_spawn(spawn_id: StringName) -> void:
	var progress := _get_world_progress()
	if progress != null:
		progress.set("city_spawn", spawn_id)


func _has_seen_city_arrival() -> bool:
	var progress := _get_world_progress()
	return progress != null and bool(progress.get("city_arrival_seen"))


func _set_city_arrival_seen() -> void:
	var progress := _get_world_progress()
	if progress != null:
		progress.set("city_arrival_seen", true)


func _has_reached_sunstone() -> bool:
	var progress := _get_world_progress()
	return progress != null and bool(progress.get("sunstone_reached"))


func _mark_sunstone_reached() -> void:
	var progress := _get_world_progress()
	if progress != null:
		progress.call("reach_sunstone_quarter")
