extends CanvasLayer
class_name ExplorationHUD

signal character_requested
signal inventory_requested
signal quest_requested
signal map_requested
signal settings_requested
signal hud_mode_changed(mode: int)

const UiTokens := preload("res://scripts/ui/ui_tokens.gd")

enum HudMode {
	NORMAL,
	DIALOGUE,
	CUTSCENE,
	MENU,
	BATTLE_TRANSITION,
	HIDDEN,
}

@onready var hud_root: Control = $HUDRoot
@onready var location_banner = $HUDRoot/LocationSlot/LocationBanner
@onready var quest_tracker = $HUDRoot/TopRight/QuestTracker
@onready var notification_toast = $HUDRoot/TopRight/NotificationToast
@onready var character_status = $HUDRoot/CharacterSlot/CharacterStatus
@onready var interaction_prompt = $HUDRoot/InteractionSlot/InteractionPrompt
@onready var shortcut_menu = $HUDRoot/ShortcutSlot/ShortcutMenu

var _hud_mode: int = HudMode.NORMAL
var _hud_tween: Tween
var _quest_requested_visible: bool = false
var _interaction_requested_visible: bool = false
var _shortcuts_requested_visible: bool = true
var _character_status_requested_visible: bool = false
var _interaction_text: String = ""
var _interaction_input_action: String = "interact"


func _ready() -> void:
	shortcut_menu.character_requested.connect(character_requested.emit)
	shortcut_menu.inventory_requested.connect(inventory_requested.emit)
	shortcut_menu.quest_requested.connect(quest_requested.emit)
	shortcut_menu.map_requested.connect(map_requested.emit)
	shortcut_menu.settings_requested.connect(settings_requested.emit)
	_apply_mode(false)


func show_location(region_name: String, area_name: String) -> void:
	location_banner.show_location(region_name, area_name)


func set_quest(
	quest_title: String,
	objective_text: String,
	progress_text: String = ""
) -> void:
	_quest_requested_visible = true
	quest_tracker.set_quest(quest_title, objective_text, progress_text)
	if _hud_mode != HudMode.NORMAL:
		quest_tracker.visible = false


func update_quest_objective(
	objective_text: String,
	progress_text: String = ""
) -> void:
	quest_tracker.update_objective(objective_text, progress_text)


func hide_quest_tracker() -> void:
	_quest_requested_visible = false
	quest_tracker.hide_tracker()


func show_interaction(
	action_text: String,
	input_action: String = "interact"
) -> void:
	_interaction_requested_visible = true
	_interaction_text = action_text
	_interaction_input_action = input_action
	if _hud_mode == HudMode.NORMAL:
		interaction_prompt.show_prompt(action_text, input_action)


func hide_interaction() -> void:
	_interaction_requested_visible = false
	interaction_prompt.hide_prompt()


func set_character_status(
	character_name: String,
	level: int,
	current_hp: float,
	max_hp: float,
	current_energy: float,
	max_energy: float
) -> void:
	character_status.set_character_name(character_name)
	character_status.set_level(level)
	character_status.set_health(current_hp, max_hp, false)
	character_status.set_energy(current_energy, max_energy, false)


func set_health(current_hp: float, max_hp: float) -> void:
	character_status.set_health(current_hp, max_hp)


func set_energy(current_energy: float, max_energy: float) -> void:
	character_status.set_energy(current_energy, max_energy)


func set_portrait(texture: Texture2D) -> void:
	character_status.set_portrait(texture)


func set_character_status_visible(value: bool) -> void:
	_character_status_requested_visible = value
	character_status.visible = (
		value
		and _hud_mode in [HudMode.NORMAL, HudMode.DIALOGUE]
	)


func show_notification(
	title: String,
	description: String = "",
	notification_type: String = "default",
	duration: float = UiTokens.TOAST_HOLD_SECONDS
) -> void:
	notification_toast.push_notification(
		title,
		description,
		notification_type,
		duration
	)


func set_shortcuts_visible(value: bool) -> void:
	_shortcuts_requested_visible = value
	shortcut_menu.visible = value and _hud_mode == HudMode.NORMAL


func set_hud_visible(value: bool, animated: bool = true) -> void:
	if _hud_tween != null and _hud_tween.is_valid():
		_hud_tween.kill()

	if not animated:
		hud_root.visible = value
		hud_root.modulate.a = 1.0 if value else 0.0
		return

	if value:
		hud_root.visible = true
		hud_root.modulate.a = 0.0
		_hud_tween = create_tween()
		_hud_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hud_tween.tween_property(
			hud_root,
			"modulate:a",
			1.0,
			UiTokens.MOTION_NORMAL
		)
	else:
		_hud_tween = create_tween()
		_hud_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_hud_tween.tween_property(
			hud_root,
			"modulate:a",
			0.0,
			UiTokens.MOTION_NORMAL
		)
		_hud_tween.tween_callback(_finish_hud_hide)


func set_hud_mode(mode: int) -> void:
	if mode < HudMode.NORMAL or mode > HudMode.HIDDEN:
		push_warning("ExplorationHUD received an invalid HUD mode: %d" % mode)
		return
	if _hud_mode == mode:
		return

	_hud_mode = mode
	_apply_mode(true)
	hud_mode_changed.emit(_hud_mode)


func get_hud_mode() -> int:
	return _hud_mode


func _apply_mode(animated: bool) -> void:
	match _hud_mode:
		HudMode.NORMAL:
			set_hud_visible(true, animated)
			quest_tracker.visible = _quest_requested_visible
			character_status.visible = _character_status_requested_visible
			character_status.modulate.a = 1.0
			shortcut_menu.visible = _shortcuts_requested_visible
			if _interaction_requested_visible:
				interaction_prompt.show_prompt(
					_interaction_text,
					_interaction_input_action
				)
			else:
				interaction_prompt.hide_prompt(false)
		HudMode.DIALOGUE:
			set_hud_visible(true, animated)
			location_banner.hide_banner()
			quest_tracker.visible = false
			interaction_prompt.hide_prompt()
			shortcut_menu.visible = false
			character_status.visible = _character_status_requested_visible
			character_status.modulate.a = UiTokens.MUTED_OPACITY
		HudMode.CUTSCENE, HudMode.MENU, HudMode.BATTLE_TRANSITION, HudMode.HIDDEN:
			set_hud_visible(false, animated)


func _finish_hud_hide() -> void:
	hud_root.visible = false
	hud_root.modulate.a = 0.0
