extends Node2D
class_name GrasslandsScene

const LOGIN_SCENE_PATH: String = "res://scenes/login/login_scene.tscn"
const OUTSKIRTS_SCENE_PATH: String = "res://scenes/world/world_scene.tscn"
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const CITY_SCENE_PATH: String = "res://scenes/city/werdonia_city_scene.tscn"

const CLOVER_MUSIC_PATH: String = "res://public/Across_the_Clover_Path.mp3"
const OLD_STONE_MUSIC_PATH: String = "res://public/Walking_Past_the_Old_Stone_Gate.mp3"

const REGION_CLOVER: StringName = &"clover_reach"
const REGION_OLD_STONE: StringName = &"old_stone_crossing"

const INTERACTION_OUTSKIRTS: StringName = &"return_outskirts"
const INTERACTION_CLOVER_STONE: StringName = &"clover_stone"
const INTERACTION_OLD_STONE: StringName = &"enter_old_stone"
const INTERACTION_CLOVER_RETURN: StringName = &"return_clover"
const INTERACTION_WAGON: StringName = &"old_wagon"
const INTERACTION_CITY_ROAD: StringName = &"city_road"

const ACTION_RETURN_OUTSKIRTS: StringName = &"return_outskirts"
const ACTION_BANDIT_NEXT: StringName = &"bandit_next"
const ACTION_START_BANDIT: StringName = &"start_bandit"
const ACTION_ENTER_CITY: StringName = &"enter_city"

const OLD_STONE_OFFSET: Vector2 = Vector2(3600.0, 0.0)
const MAP_SIZE: Vector2 = Vector2(3010.0, 1694.0)

const CLOVER_START_SPAWN: Vector2 = Vector2(240.0, 1480.0)
const CLOVER_GATE_RETURN_SPAWN: Vector2 = Vector2(2500.0, 480.0)
const OLD_STONE_ENTRY_SPAWN: Vector2 = OLD_STONE_OFFSET + Vector2(310.0, 1460.0)
const OLD_STONE_AFTER_BATTLE_SPAWN: Vector2 = OLD_STONE_OFFSET + Vector2(2050.0, 850.0)

const BANDIT_DIALOGUE: Array[Dictionary] = [
	{
		"title": "BANDIT CAPTAIN",
		"message": "Berhenti. Jalan tua ini milik Clover Company sekarang. Tinggalkan senjata dan semua bekal kalian sebagai biaya lintas."
	},
	{
		"title": "MITSUKI",
		"message": "Lencana mereka palsu. Mereka bukan penjaga Werdonia, cuma perampok yang memakai reruntuhan ini sebagai pos pemeriksaan."
	},
	{
		"title": "MAKOTO",
		"message": "Takashi, hadapi pemimpinnya. Aku dan Mitsuki akan menahan anak buahnya supaya pertarungan ini tetap seimbang."
	},
	{
		"title": "TAKASHI",
		"message": "Baik. Kita buka jalan ini dan pastikan tidak ada pelintas lain yang menjadi korban mereka."
	}
]

@onready var player: WorldPlayer = $Player
@onready var world_camera: Camera2D = $Player/WorldCamera

@onready var return_outskirts_area: Area2D = $InteractionAreas/ReturnOutskirtsArea
@onready var clover_stone_area: Area2D = $InteractionAreas/CloverStoneArea
@onready var old_stone_area: Area2D = $InteractionAreas/OldStoneArea
@onready var clover_return_area: Area2D = $InteractionAreas/CloverReturnArea
@onready var wagon_area: Area2D = $InteractionAreas/WagonArea
@onready var city_road_area: Area2D = $InteractionAreas/CityRoadArea
@onready var bandit_trigger_area: Area2D = $InteractionAreas/BanditTriggerArea

@onready var location_banner: Panel = $WorldCanvas/LocationBanner
@onready var location_title: Label = $WorldCanvas/LocationBanner/LocationTitle
@onready var location_subtitle: Label = $WorldCanvas/LocationBanner/LocationSubtitle
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
@onready var region_fade: ColorRect = $WorldCanvas/RegionFade
@onready var hud_explor: HudExplorPlaceholder = $HudExplorPlaceholder/HUDRoot

var _active_region: StringName = REGION_CLOVER
var _nearby_interactions: Array[StringName] = []
var _active_interaction: StringName = &""
var _modal_action: StringName = &""
var _bandit_dialogue_step: int = 0
var _modal_open: bool = false
var _region_transitioning: bool = false
var _entry_sequence_playing: bool = true
var _prompt_rest_position: Vector2
var _prompt_tween: Tween


func _ready() -> void:
	hud_explor.show_player_marker = false
	hud_explor.set_player_status("Takashi", 10, 1897.0, 2000.0)
	hud_explor.slot_pressed.connect(_on_hud_slot_pressed)
	location_banner.visible = false
	$WorldCanvas/QuestPanel.visible = false
	menu_button.visible = false

	_connect_interaction_area(return_outskirts_area, INTERACTION_OUTSKIRTS)
	_connect_interaction_area(clover_stone_area, INTERACTION_CLOVER_STONE)
	_connect_interaction_area(old_stone_area, INTERACTION_OLD_STONE)
	_connect_interaction_area(clover_return_area, INTERACTION_CLOVER_RETURN)
	_connect_interaction_area(wagon_area, INTERACTION_WAGON)
	_connect_interaction_area(city_road_area, INTERACTION_CITY_ROAD)
	bandit_trigger_area.body_entered.connect(_on_bandit_trigger_entered)

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

	var spawn_id := _get_grassland_spawn()
	match spawn_id:
		&"old_stone_entry":
			_set_region_immediate(REGION_OLD_STONE, OLD_STONE_ENTRY_SPAWN)
		&"old_stone_after_battle":
			_set_region_immediate(REGION_OLD_STONE, OLD_STONE_AFTER_BATTLE_SPAWN)
		&"clover_gate_return":
			_set_region_immediate(REGION_CLOVER, CLOVER_GATE_RETURN_SPAWN)
		_:
			_set_region_immediate(REGION_CLOVER, CLOVER_START_SPAWN)

	player.set_movement_enabled(false)
	await get_tree().process_frame
	var entry_tween := create_tween()
	entry_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	entry_tween.tween_property(region_fade, "modulate:a", 0.0, 0.55)
	await entry_tween.finished
	region_fade.visible = false
	_entry_sequence_playing = false
	player.set_movement_enabled(true)
	_play_location_intro()
	_update_interaction_prompt()

	if spawn_id == &"old_stone_after_battle" and _is_bandit_defeated():
		await get_tree().create_timer(0.35).timeout
		_open_info_panel(
			"JALAN LAMA TERBUKA",
			"Pemimpin bandit tumbang dan kelompoknya tercerai. Makoto serta Mitsuki kembali ke sisimu; jalan menuju gerbang luar Werdonia kini aman.",
			&"",
			"",
			"Lanjut"
		)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _modal_open:
		_close_info_panel()
		get_viewport().set_input_as_handled()
		return
	if (
		event.is_action_pressed("ui_cancel")
		and not _modal_open
		and not _region_transitioning
		and not get_tree().paused
	):
		_open_pause_menu()
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


func _on_bandit_trigger_entered(body: Node2D) -> void:
	if (
		body == player
		and _active_region == REGION_OLD_STONE
		and not _is_bandit_defeated()
		and not _modal_open
		and not _region_transitioning
	):
		_begin_bandit_dialogue()


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
		INTERACTION_OUTSKIRTS:
			interaction_label.text = "Kembali ke Gerbang Abyss"
		INTERACTION_CLOVER_STONE:
			interaction_label.text = "Periksa batu penanda"
		INTERACTION_OLD_STONE:
			interaction_label.text = "Lanjut ke Old Stone Crossing"
		INTERACTION_CLOVER_RETURN:
			interaction_label.text = "Kembali ke Clover Reach"
		INTERACTION_WAGON:
			interaction_label.text = "Periksa kereta terbengkalai"
		INTERACTION_CITY_ROAD:
			interaction_label.text = (
				"Masuk ke Werdonia City"
				if _is_bandit_defeated()
				else "Lihat jalan menuju Werdonia"
			)
	_set_prompt_visible(true)


func _choose_active_interaction() -> StringName:
	var priority: Array[StringName]
	if _active_region == REGION_CLOVER:
		priority = [
			INTERACTION_OUTSKIRTS,
			INTERACTION_CLOVER_STONE,
			INTERACTION_OLD_STONE
		]
	else:
		priority = [
			INTERACTION_CLOVER_RETURN,
			INTERACTION_WAGON,
			INTERACTION_CITY_ROAD
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
		INTERACTION_OUTSKIRTS:
			_open_info_panel(
				"GERBANG ABYSS",
				"Jalan di belakang mengarah kembali ke gerbang tempat perjalanan ini dimulai. Clover Reach terbentang luas di sisi sebaliknya.",
				ACTION_RETURN_OUTSKIRTS,
				"Kembali",
				"Tetap di sini"
			)
		INTERACTION_CLOVER_STONE:
			_open_info_panel(
				"BATU PENUNJUK KUNO",
				"Ukiran semanggi pada batu ini lebih tua dari jalan kerajaan. Arah timur menunjuk ke gerbang batu lama, rute terdekat menuju Werdonia.",
				&"",
				"",
				"Tutup"
			)
		INTERACTION_OLD_STONE:
			_transition_to_region(REGION_OLD_STONE, OLD_STONE_ENTRY_SPAWN)
		INTERACTION_CLOVER_RETURN:
			_transition_to_region(REGION_CLOVER, CLOVER_GATE_RETURN_SPAWN)
		INTERACTION_WAGON:
			_open_info_panel(
				"KERETA PEDAGANG",
				"Rodanya dipatahkan dengan sengaja. Jejak sepatu mengarah ke barikade di atas jalan, tetapi tidak ada tanda para pedagang di sekitar sini.",
				&"",
				"",
				"Tutup"
			)
		INTERACTION_CITY_ROAD:
			if _is_bandit_defeated():
				_open_info_panel(
					"JALAN MENUJU WERDONIA",
					"Di balik gerbang runtuh, jalan kerajaan mendaki menuju jembatan dan tembok Werdonia. Makoto memastikan rute sudah aman untuk dilalui.",
					ACTION_ENTER_CITY,
					"Masuk Werdonia",
					"Tetap di sini"
				)
			else:
				_open_info_panel(
					"JALAN DIBLOKADE",
					"Barikade bandit menutup jalur utama. Pos ini harus dibereskan sebelum rombongan dapat melanjutkan perjalanan.",
					&"",
					"",
					"Tutup"
				)


func _transition_to_region(region_id: StringName, spawn_position: Vector2) -> void:
	if _region_transitioning:
		return

	_region_transitioning = true
	player.set_movement_enabled(false)
	_set_prompt_visible(false)
	region_fade.visible = true
	region_fade.modulate.a = 0.0

	var fade_out := create_tween()
	fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(region_fade, "modulate:a", 1.0, 0.42)
	await fade_out.finished

	_set_region_immediate(region_id, spawn_position)
	await get_tree().process_frame

	var fade_in := create_tween()
	fade_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_in.tween_property(region_fade, "modulate:a", 0.0, 0.48)
	await fade_in.finished

	region_fade.visible = false
	_region_transitioning = false
	player.set_movement_enabled(true)
	_play_location_intro()
	_update_interaction_prompt()


func _set_region_immediate(region_id: StringName, spawn_position: Vector2) -> void:
	_active_region = region_id
	_nearby_interactions.clear()
	_active_interaction = &""
	player.global_position = spawn_position

	if region_id == REGION_CLOVER:
		player.walkable_polygon = _build_clover_walkable_polygon()
		_set_camera_limits(0, 0, int(MAP_SIZE.x), int(MAP_SIZE.y))
		location_title.text = "CLOVER REACH"
		location_subtitle.text = "Padang rumput di luar Werdonia"
		quest_label.text = "JALAN PERTAMA"
		objective_status.text = "Capai gerbang batu di utara"
		_set_grassland_spawn(&"clover_gate_return" if spawn_position == CLOVER_GATE_RETURN_SPAWN else &"clover_start")
		_play_region_music(CLOVER_MUSIC_PATH)
	else:
		player.walkable_polygon = _build_old_stone_walkable_polygon()
		_set_camera_limits(
			int(OLD_STONE_OFFSET.x),
			0,
			int(OLD_STONE_OFFSET.x + MAP_SIZE.x),
			int(MAP_SIZE.y)
		)
		location_title.text = "OLD STONE CROSSING"
		location_subtitle.text = "Jalan kerajaan yang terlupakan"
		quest_label.text = "POS PEMERIKSAAN"
		if _is_bandit_defeated():
			objective_status.text = "Lanjutkan menuju Werdonia City"
			_set_grassland_spawn(&"old_stone_after_battle")
		else:
			objective_status.text = "Periksa barikade di jalan lama"
			_set_grassland_spawn(&"old_stone_entry")
		_play_region_music(OLD_STONE_MUSIC_PATH)

	world_camera.reset_smoothing()
	_sync_placeholder_hud()


func _set_camera_limits(left: int, top: int, right: int, bottom: int) -> void:
	world_camera.limit_left = left
	world_camera.limit_top = top
	world_camera.limit_right = right
	world_camera.limit_bottom = bottom


func _build_clover_walkable_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(70.0, 1650.0),
		Vector2(80.0, 1190.0),
		Vector2(190.0, 920.0),
		Vector2(390.0, 690.0),
		Vector2(720.0, 520.0),
		Vector2(1120.0, 380.0),
		Vector2(1600.0, 220.0),
		Vector2(2180.0, 90.0),
		Vector2(2940.0, 70.0),
		Vector2(2960.0, 520.0),
		Vector2(2800.0, 850.0),
		Vector2(2640.0, 1190.0),
		Vector2(2350.0, 1480.0),
		Vector2(1880.0, 1650.0),
		Vector2(790.0, 1680.0)
	])


func _build_old_stone_walkable_polygon() -> PackedVector2Array:
	var local_points := PackedVector2Array([
		Vector2(60.0, 1650.0),
		Vector2(80.0, 1180.0),
		Vector2(300.0, 850.0),
		Vector2(650.0, 640.0),
		Vector2(1020.0, 470.0),
		Vector2(1420.0, 350.0),
		Vector2(1830.0, 240.0),
		Vector2(2240.0, 100.0),
		Vector2(2930.0, 70.0),
		Vector2(2960.0, 470.0),
		Vector2(2720.0, 790.0),
		Vector2(2320.0, 990.0),
		Vector2(1830.0, 1220.0),
		Vector2(1310.0, 1460.0),
		Vector2(700.0, 1660.0)
	])
	var world_points := PackedVector2Array()
	for point in local_points:
		world_points.append(point + OLD_STONE_OFFSET)
	return world_points


func _play_region_music(track_path: String) -> void:
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.call("play_track", track_path, -12.0, 1.15)


func _play_location_intro() -> void:
	location_banner.visible = false
	_sync_placeholder_hud()


func _sync_placeholder_hud() -> void:
	if not is_instance_valid(hud_explor):
		return
	hud_explor.set_quest(objective_status.text, quest_label.text)


func _on_hud_slot_pressed(slot_name: StringName) -> void:
	# The art slots are live in-game now. Destination menus stay placeholders
	# until their individual screens are ready.
	print("Exploration HUD slot requested: %s" % slot_name)


func _begin_bandit_dialogue() -> void:
	_bandit_dialogue_step = 0
	_show_bandit_dialogue_step()


func _show_bandit_dialogue_step() -> void:
	var dialogue: Dictionary = BANDIT_DIALOGUE[_bandit_dialogue_step]
	var is_last_step := _bandit_dialogue_step == BANDIT_DIALOGUE.size() - 1
	_open_info_panel(
		String(dialogue["title"]),
		String(dialogue["message"]),
		ACTION_START_BANDIT if is_last_step else ACTION_BANDIT_NEXT,
		"Hadapi Bandit" if is_last_step else "Lanjut",
		"Mundur"
	)


func _open_info_panel(
	title: String,
	message: String,
	action: StringName,
	primary_text: String,
	close_text: String
) -> void:
	_modal_open = true
	_modal_action = action
	player.set_movement_enabled(false)
	_set_prompt_visible(false)

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
		ACTION_RETURN_OUTSKIRTS:
			_set_grassland_spawn(&"clover_start")
			var music_director := get_node_or_null("/root/MusicDirector")
			if music_director != null:
				music_director.call("stop_music", 0.35)
			SceneTransition.change_to_file(OUTSKIRTS_SCENE_PATH)
		ACTION_BANDIT_NEXT:
			_bandit_dialogue_step += 1
			_show_bandit_dialogue_step()
		ACTION_START_BANDIT:
			_start_bandit_battle()
		ACTION_ENTER_CITY:
			var progress := _get_world_progress()
			if progress != null:
				progress.call("enter_werdonia_city")
			player.set_movement_enabled(false)
			SceneTransition.change_to_file(CITY_SCENE_PATH)


func _start_bandit_battle() -> void:
	var progress := _get_world_progress()
	if progress != null:
		progress.call("begin_bandit_encounter")
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.call("stop_music", 0.4)
	player.set_movement_enabled(false)
	SceneTransition.change_to_file(BATTLE_SCENE_PATH)


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


func _get_grassland_spawn() -> StringName:
	var progress := _get_world_progress()
	if progress == null:
		return &"clover_start"
	return StringName(progress.get("grassland_spawn"))


func _set_grassland_spawn(spawn_id: StringName) -> void:
	var progress := _get_world_progress()
	if progress != null:
		progress.set("grassland_spawn", spawn_id)


func _is_bandit_defeated() -> bool:
	var progress := _get_world_progress()
	return progress != null and bool(progress.get("bandit_defeated"))
