extends "res://scripts/grasslands/grasslands_scene.gd"
class_name GrasslandsHudDebug

const UiTokens := preload("res://scripts/ui/ui_tokens.gd")

@onready var hud = $ExplorationHUD

var _hud_adapter_ready: bool = false


func _ready() -> void:
	_hide_legacy_exploration_ui()
	_connect_hud_signals()
	hud.set_character_status_visible(false)
	await super()

	_hud_adapter_ready = true
	_sync_quest_from_existing_ui()
	hud.show_notification(
		"Area discovered",
		_get_debug_area_name(),
		"location",
		1.8
	)
	hud.show_notification(
		"Objective linked",
		"Quest text is provided by the Grasslands scene.",
		"quest",
		1.8
	)


func _unhandled_input(event: InputEvent) -> void:
	var modal_was_open := _modal_open
	super(event)
	if (
		event.is_action_pressed("ui_cancel")
		and not modal_was_open
		and not _modal_open
		and not _region_transitioning
		and not get_tree().paused
	):
		_open_pause_menu()
		get_viewport().set_input_as_handled()


func _set_region_immediate(
	region_id: StringName,
	spawn_position: Vector2
) -> void:
	super(region_id, spawn_position)
	_sync_quest_from_existing_ui()
	if _hud_adapter_ready:
		hud.show_notification(
			"Objective updated",
			objective_status.text,
			"quest",
			1.8
		)


func _play_location_intro() -> void:
	_sync_quest_from_existing_ui()
	if _active_region == REGION_OLD_STONE:
		hud.show_location("CLOVER REACH", "Old Stone Crossing")
	else:
		hud.show_location(location_title.text, location_subtitle.text)

	if _hud_adapter_ready:
		hud.show_notification(
			"Area discovered",
			_get_debug_area_name(),
			"location",
			1.8
		)


func _set_prompt_visible(should_show: bool) -> void:
	interaction_prompt.visible = false
	if should_show:
		hud.show_interaction(interaction_label.text, "interact")
	else:
		hud.hide_interaction()


func _open_info_panel(
	title: String,
	message: String,
	action: StringName,
	primary_text: String,
	close_text: String
) -> void:
	hud.set_hud_mode(hud.HudMode.DIALOGUE)
	super(title, message, action, primary_text, close_text)


func _close_info_panel() -> void:
	var completed_title := info_title.text
	await super()
	hud.set_hud_mode(hud.HudMode.NORMAL)
	hud.show_notification(
		"Interaction complete",
		completed_title,
		"default",
		1.8
	)


func _open_pause_menu() -> void:
	hud.set_hud_mode(hud.HudMode.MENU)
	hud.set_hud_visible(false, false)
	super()


func _close_pause_menu() -> void:
	super()
	hud.set_hud_mode(hud.HudMode.NORMAL)


func _start_bandit_battle() -> void:
	hud.set_hud_mode(hud.HudMode.BATTLE_TRANSITION)
	await get_tree().create_timer(UiTokens.MOTION_NORMAL).timeout
	super()


func _hide_legacy_exploration_ui() -> void:
	location_banner.visible = false
	$WorldCanvas/QuestPanel.visible = false
	interaction_prompt.visible = false
	menu_button.visible = false


func _sync_quest_from_existing_ui() -> void:
	if not is_instance_valid(hud):
		return
	hud.set_quest(
		quest_label.text,
		objective_status.text
	)


func _get_debug_area_name() -> String:
	if _active_region == REGION_OLD_STONE:
		return "Old Stone Crossing"
	return location_title.text


func _connect_hud_signals() -> void:
	hud.character_requested.connect(
		_on_shortcut_requested.bind("Character")
	)
	hud.inventory_requested.connect(
		_on_shortcut_requested.bind("Inventory")
	)
	hud.quest_requested.connect(
		_on_shortcut_requested.bind("Quest")
	)
	hud.map_requested.connect(
		_on_shortcut_requested.bind("Map")
	)
	hud.settings_requested.connect(_on_settings_requested)


func _on_shortcut_requested(shortcut_name: String) -> void:
	print("Grasslands HUD debug shortcut requested: %s" % shortcut_name)
	hud.show_notification(
		"%s shortcut" % shortcut_name,
		"Placeholder only; no gameplay menu was created.",
		"default",
		1.8
	)


func _on_settings_requested() -> void:
	_open_pause_menu()
