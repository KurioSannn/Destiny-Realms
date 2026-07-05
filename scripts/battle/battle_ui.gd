extends Control
class_name BattleUI

signal attack_pressed
signal skill_pressed
signal ultimate_pressed
signal restart_pressed
signal confirm_pressed

const ATTACK_LABEL: String = "Void Strike"
const SKILL_LABEL: String = "Triangle Rift"
const ULTIMATE_LABEL: String = "Octagram Fragment"

@onready var player_hp_label: Label = $PlayerStatusPanel/PlayerHpLabel
@onready var enemy_hp_label: Label = $EnemyStatusPanel/EnemyHpLabel
@onready var turn_label: Label = $LogPanel/TurnLabel
@onready var battle_log_label: Label = $LogPanel/BattleLogLabel
@onready var energy_label: Label = $PlayerStatusPanel/EnergyLabel
@onready var energy_bar: ProgressBar = $PlayerStatusPanel/EnergyBar
@onready var skill_points_label: Label = $PlayerStatusPanel/SkillPointsLabel
@onready var attack_button: Button = $ActionPanel/ActionButtons/AttackButton
@onready var skill_button: Button = $ActionPanel/ActionButtons/SkillButton
@onready var ultimate_button: Button = $ActionPanel/ActionButtons/UltimateButton
@onready var restart_button: Button = $ActionPanel/ActionButtons/RestartButton

var battle_input_enabled: bool = true
var current_energy: int = 0
var current_max_energy: int = 100


func _ready() -> void:
	attack_button.pressed.connect(_on_attack_button_pressed)
	skill_button.pressed.connect(_on_skill_button_pressed)
	ultimate_button.pressed.connect(_on_ultimate_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	set_timing_mode(false)


func _unhandled_input(event: InputEvent) -> void:
	if not battle_input_enabled:
		return

	if _is_confirm_input(event):
		confirm_pressed.emit()
		get_viewport().set_input_as_handled()
	elif _is_restart_input(event):
		restart_pressed.emit()
		get_viewport().set_input_as_handled()


func set_hp_text(player_text: String, enemy_text: String) -> void:
	player_hp_label.text = player_text
	enemy_hp_label.text = enemy_text


func set_turn_text(text: String) -> void:
	turn_label.text = text


func set_battle_log(text: String) -> void:
	battle_log_label.text = text


func set_energy(energy: int, max_energy: int) -> void:
	current_energy = energy
	current_max_energy = max_energy
	energy_label.text = "Takashi Energy: %d/%d" % [energy, max_energy]
	energy_bar.max_value = max_energy
	energy_bar.value = energy


func set_skill_points(skill_points: int, max_skill_points: int) -> void:
	skill_points_label.text = "Skill Points: %d/%d" % [skill_points, max_skill_points]


func set_battle_input_enabled(enabled: bool) -> void:
	battle_input_enabled = enabled


func set_actions_enabled(enabled: bool, ultimate_ready: bool = false, skill_ready: bool = true) -> void:
	attack_button.disabled = not enabled
	if enabled:
		attack_button.text = "%s\nBasic | +1 SP | +Energy" % ATTACK_LABEL
	else:
		attack_button.text = "%s\nWaiting for turn" % ATTACK_LABEL

	skill_button.disabled = not enabled or not skill_ready
	if not enabled:
		skill_button.text = "%s\nWaiting for turn" % SKILL_LABEL
	elif not skill_ready:
		skill_button.text = "%s\nNeed 1 Skill Point" % SKILL_LABEL
	else:
		skill_button.text = "%s\nSkill | Cost 1 SP" % SKILL_LABEL

	ultimate_button.disabled = not enabled or not ultimate_ready
	if ultimate_ready and enabled:
		ultimate_button.text = "[READY] %s\nUltimate | 100 Energy" % ULTIMATE_LABEL
		ultimate_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35, 1.0))
		ultimate_button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.58, 1.0))
		ultimate_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.8, 0.25, 1.0))
	elif ultimate_ready:
		ultimate_button.text = "[READY] %s\nWaiting for turn" % ULTIMATE_LABEL
		ultimate_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35, 1.0))
		ultimate_button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.58, 1.0))
		ultimate_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.8, 0.25, 1.0))
	else:
		ultimate_button.text = "%s\nEnergy %d/%d" % [ULTIMATE_LABEL, current_energy, current_max_energy]
		ultimate_button.remove_theme_color_override("font_color")
		ultimate_button.remove_theme_color_override("font_hover_color")
		ultimate_button.remove_theme_color_override("font_pressed_color")


func set_restart_visible(show_restart: bool) -> void:
	restart_button.visible = show_restart
	restart_button.disabled = not show_restart
	restart_button.text = "Restart Story"


func set_timing_mode(enabled: bool) -> void:
	if enabled:
		attack_button.text = "Confirm\nVoid Strike timing"
		attack_button.disabled = false
		skill_button.disabled = true
		skill_button.text = "%s\nTiming active" % SKILL_LABEL
		ultimate_button.disabled = true
		ultimate_button.text = "%s\nTiming active" % ULTIMATE_LABEL
	else:
		attack_button.text = "%s\nBasic | +1 SP | +Energy" % ATTACK_LABEL


func _on_attack_button_pressed() -> void:
	attack_pressed.emit()


func _on_skill_button_pressed() -> void:
	skill_pressed.emit()


func _on_ultimate_button_pressed() -> void:
	ultimate_pressed.emit()


func _on_restart_button_pressed() -> void:
	restart_pressed.emit()


func _is_confirm_input(event: InputEvent) -> bool:
	if InputMap.has_action("confirm_attack") and event.is_action_pressed("confirm_attack"):
		return true

	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_SPACE or event.keycode == KEY_ENTER

	return false


func _is_restart_input(event: InputEvent) -> bool:
	if InputMap.has_action("restart") and event.is_action_pressed("restart"):
		return true

	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_R

	return false
