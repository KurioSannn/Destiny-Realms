extends Control
class_name ExplorationHudPreview

const UiTokens := preload("res://scripts/ui/ui_tokens.gd")
const ExplorationHudScript := preload("res://scripts/ui/exploration/exploration_hud.gd")

const MODE_SEQUENCE: Array[int] = [
	ExplorationHudScript.HudMode.NORMAL,
	ExplorationHudScript.HudMode.DIALOGUE,
	ExplorationHudScript.HudMode.CUTSCENE,
	ExplorationHudScript.HudMode.MENU,
	ExplorationHudScript.HudMode.BATTLE_TRANSITION,
	ExplorationHudScript.HudMode.HIDDEN,
]
const MODE_NAMES: Array[String] = [
	"NORMAL",
	"DIALOGUE",
	"CUTSCENE",
	"MENU",
	"BATTLE TRANSITION",
	"HIDDEN",
]

@onready var hud = $ExplorationHUD
@onready var preview_tint: ColorRect = $PreviewTint
@onready var mode_value: Label = $DebugPanel/Content/ModeRow/ModeValue
@onready var event_value: Label = $DebugPanel/Content/EventValue
@onready var location_button: Button = $DebugPanel/Content/Actions/Location
@onready var quest_button: Button = $DebugPanel/Content/Actions/Quest
@onready var progress_button: Button = $DebugPanel/Content/Actions/Progress
@onready var prompt_button: Button = $DebugPanel/Content/Actions/Prompt
@onready var health_button: Button = $DebugPanel/Content/Actions/Health
@onready var energy_button: Button = $DebugPanel/Content/Actions/Energy
@onready var toast_button: Button = $DebugPanel/Content/Actions/Toasts
@onready var mode_button: Button = $DebugPanel/Content/Actions/Mode
@onready var shortcuts_button: Button = $DebugPanel/Content/Actions/Shortcuts

var _health: float = 100.0
var _energy: float = 40.0
var _quest_step: int = 1
var _prompt_visible: bool = true
var _mode_index: int = 0


func _ready() -> void:
	preview_tint.color = Color(UiTokens.DARK_NAVY, 0.18)
	location_button.pressed.connect(_show_location)
	quest_button.pressed.connect(_change_quest)
	progress_button.pressed.connect(_advance_progress)
	prompt_button.pressed.connect(_toggle_prompt)
	health_button.pressed.connect(_reduce_health)
	energy_button.pressed.connect(_add_energy)
	toast_button.pressed.connect(_queue_toasts)
	mode_button.pressed.connect(_cycle_mode)
	shortcuts_button.pressed.connect(_focus_shortcuts)

	hud.character_requested.connect(_on_shortcut_requested.bind("Character"))
	hud.inventory_requested.connect(_on_shortcut_requested.bind("Inventory"))
	hud.quest_requested.connect(_on_shortcut_requested.bind("Quest"))
	hud.map_requested.connect(_on_shortcut_requested.bind("Map"))
	hud.settings_requested.connect(_on_shortcut_requested.bind("Settings"))
	hud.hud_mode_changed.connect(_on_hud_mode_changed)

	hud.set_character_status("Takashi", 1, _health, 100.0, _energy, 100.0)
	hud.set_character_status_visible(true)
	hud.set_quest(
		"Road Toward Destiny",
		"Follow the weathered stones beyond the clover field",
		"1 / 3"
	)
	hud.show_interaction("Inspect the ancient waystone", "interact")
	hud.set_shortcuts_visible(true)
	location_button.grab_focus()

	await get_tree().process_frame
	hud.show_location("CLOVER REACH", "Old Stone Crossing")
	hud.show_notification(
		"Exploration HUD ready",
		"All components are driven through the public API.",
		"default"
	)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_1:
			_show_location()
		KEY_2:
			_change_quest()
		KEY_3:
			_advance_progress()
		KEY_4:
			_toggle_prompt()
		KEY_5:
			_reduce_health()
		KEY_6:
			_add_energy()
		KEY_7:
			_queue_toasts()
		KEY_8:
			_cycle_mode()
		KEY_9:
			_focus_shortcuts()
		_:
			return

	get_viewport().set_input_as_handled()


func _show_location() -> void:
	hud.show_location("WERDONIA", "Sunstone Quarter")
	_set_event("Location banner requested")


func _change_quest() -> void:
	hud.set_quest(
		"The City That Fell Silent",
		"Find the fractured celestial seal near the old fountain"
	)
	_set_event("Quest data replaced")


func _advance_progress() -> void:
	_quest_step = (_quest_step % 3) + 1
	hud.update_quest_objective(
		"Restore the waystone fragments",
		"%d / 3" % _quest_step
	)
	_set_event("Objective progress updated")


func _toggle_prompt() -> void:
	_prompt_visible = not _prompt_visible
	if _prompt_visible:
		hud.show_interaction("Inspect the ancient waystone", "interact")
		_set_event("Interaction prompt shown")
	else:
		hud.hide_interaction()
		_set_event("Interaction prompt hidden")


func _reduce_health() -> void:
	_health -= 25.0
	if _health < 0.0:
		_health = 100.0
	hud.set_health(_health, 100.0)
	_set_event("Health set to %d" % int(_health))


func _add_energy() -> void:
	_energy += 15.0
	if _energy > 100.0:
		_energy = 0.0
	hud.set_energy(_energy, 100.0)
	_set_event("Energy set to %d" % int(_energy))


func _queue_toasts() -> void:
	hud.show_notification("Quest updated", "A new trace was discovered.", "quest", 1.2)
	hud.show_notification("Moonleaf obtained", "Added to the travel pouch.", "item", 1.2)
	hud.show_notification("Autosave complete", "", "save", 1.2)
	_set_event("Three notifications queued")


func _cycle_mode() -> void:
	_mode_index = (_mode_index + 1) % MODE_SEQUENCE.size()
	hud.set_hud_mode(MODE_SEQUENCE[_mode_index])


func _focus_shortcuts() -> void:
	var shortcut_menu = hud.shortcut_menu
	shortcut_menu.focus_first()
	_set_event("Keyboard focus moved to Character shortcut")


func _on_shortcut_requested(shortcut_name: String) -> void:
	_set_event("%s shortcut signal emitted" % shortcut_name)


func _on_hud_mode_changed(mode: int) -> void:
	var index := MODE_SEQUENCE.find(mode)
	if index >= 0:
		mode_value.text = MODE_NAMES[index]
		_set_event("HUD mode changed")


func _set_event(value: String) -> void:
	event_value.text = value
