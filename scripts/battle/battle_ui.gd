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
const TEXT_COLOR: Color = Color(0.9, 0.94, 1.0, 1.0)
const MUTED_TEXT_COLOR: Color = Color(0.5, 0.58, 0.68, 1.0)
const READY_TEXT_COLOR: Color = Color(1.0, 0.88, 0.36, 1.0)
const BUTTON_NORMAL_COLOR: Color = Color(0.018, 0.032, 0.055, 0.92)
const BUTTON_HOVER_COLOR: Color = Color(0.06, 0.12, 0.18, 0.96)
const BUTTON_PRESSED_COLOR: Color = Color(0.08, 0.14, 0.18, 0.98)
const BUTTON_DISABLED_COLOR: Color = Color(0.015, 0.02, 0.03, 0.76)
const BUTTON_BORDER_COLOR: Color = Color(0.36, 0.58, 0.72, 0.86)
const BUTTON_READY_BORDER_COLOR: Color = Color(0.98, 0.78, 0.28, 1.0)

@onready var energy_label: Label = $PlayerStatusPanel/EnergyLabel
@onready var energy_bar: ProgressBar = $PlayerStatusPanel/EnergyBar
@onready var status_hp_label: Label = $PlayerStatusPanel/StatusHpValueLabel
@onready var status_hp_bar: ProgressBar = $PlayerStatusPanel/StatusHpBar
@onready var skill_points_label: Label = $SharedSpDisplay/SkillPointsLabel
@onready var skill_point_pips: HBoxContainer = $SharedSpDisplay/SkillPointPips
@onready var attack_button: Button = $ActionPanel/ActionButtons/AttackButton
@onready var skill_button: Button = $ActionPanel/ActionButtons/SkillButton
@onready var ultimate_button: Button = $ActionPanel/ActionButtons/UltimateButton
@onready var attack_caption: Label = $ActionPanel/ActionCaptions/AttackCaption
@onready var skill_caption: Label = $ActionPanel/ActionCaptions/SkillCaption
@onready var ultimate_caption: Label = $ActionPanel/ActionCaptions/UltimateCaption
@onready var menu_button: Button = $MenuButton
@onready var menu_popup: Panel = $MenuPopup
@onready var start_button: Button = $MenuPopup/StartButton
@onready var turn_banner_label: Label = $TurnBannerLabel
@onready var turn_chip_player: Panel = $TurnOrderStrip/TurnChipPlayer
@onready var turn_chip_enemy: Panel = $TurnOrderStrip/TurnChipEnemy
@onready var turn_chip_player_next: Panel = $TurnOrderStrip/TurnChipPlayerNext
@onready var turn_chip_enemy_next: Panel = $TurnOrderStrip/TurnChipEnemyNext

var battle_input_enabled: bool = true
var current_energy: int = 0
var current_max_energy: int = 100
var turn_highlight_tween: Tween
var turn_banner_tween: Tween
var turn_order_slots: Array[Panel] = []
var turn_order_labels: Array[Label] = []
var turn_order_profiles: Array[TextureRect] = []
var turn_player_style: StyleBox
var turn_enemy_style: StyleBox
var turn_dim_style: StyleBox


func _ready() -> void:
	attack_button.pressed.connect(_on_attack_button_pressed)
	skill_button.pressed.connect(_on_skill_button_pressed)
	ultimate_button.pressed.connect(_on_ultimate_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	_setup_turn_order_slots()
	_apply_action_button_style(attack_button, false, false)
	_apply_action_button_style(skill_button, false, false)
	_apply_action_button_style(ultimate_button, false, false)
	set_restart_visible(false)
	set_timing_mode(false)
	set_turn_order_highlight(true)


func _unhandled_input(event: InputEvent) -> void:
	if not battle_input_enabled:
		return

	if _is_confirm_input(event):
		confirm_pressed.emit()
		get_viewport().set_input_as_handled()
	elif _is_restart_input(event):
		restart_pressed.emit()
		get_viewport().set_input_as_handled()


func set_turn_text(text: String) -> void:
	if text == "Player Turn":
		_play_turn_banner("Takashi Turn", Color(0.74, 0.92, 1.0, 1.0))
	elif text == "Enemy Turn":
		_play_turn_banner("Enemy Turn", Color(1.0, 0.48, 0.58, 1.0))


func set_battle_log(_text: String) -> void:
	pass


func set_player_status_hp(current_hp: int, max_hp: int) -> void:
	status_hp_label.text = "%d/%d" % [current_hp, max_hp]
	status_hp_bar.max_value = max_hp
	status_hp_bar.value = current_hp


func set_energy(energy: int, max_energy: int) -> void:
	current_energy = energy
	current_max_energy = max_energy
	var percent: int = 0
	if max_energy > 0:
		percent = int(round(100.0 * float(energy) / float(max_energy)))
	energy_label.text = "BURST  %d%%" % percent
	energy_bar.max_value = max_energy
	energy_bar.value = energy


func set_turn_order_highlight(is_player_turn: bool) -> void:
	_refresh_turn_order_slots(is_player_turn)
	if not turn_order_slots.is_empty():
		_play_turn_chip_feedback(turn_order_slots[0])


func set_skill_points(skill_points: int, max_skill_points: int) -> void:
	skill_points_label.text = "SP  %d/%d" % [skill_points, max_skill_points]
	for index in range(skill_point_pips.get_child_count()):
		var pip: CanvasItem = skill_point_pips.get_child(index) as CanvasItem
		if pip == null:
			continue
		if index < skill_points:
			pip.modulate = Color(1.0, 0.82, 0.34, 1.0)
		else:
			pip.modulate = Color(0.35, 0.36, 0.42, 0.48)


func set_battle_input_enabled(enabled: bool) -> void:
	battle_input_enabled = enabled


func set_actions_enabled(enabled: bool, ultimate_ready: bool = false, skill_ready: bool = true) -> void:
	attack_button.disabled = not enabled
	attack_button.text = ""
	attack_button.tooltip_text = ""
	_apply_action_button_style(attack_button, enabled, false)
	attack_caption.add_theme_color_override("font_color", TEXT_COLOR if enabled else MUTED_TEXT_COLOR)

	skill_button.disabled = not enabled or not skill_ready
	skill_button.text = ""
	skill_button.tooltip_text = ""
	_apply_action_button_style(skill_button, enabled and skill_ready, false)
	skill_caption.add_theme_color_override("font_color", TEXT_COLOR if enabled and skill_ready else MUTED_TEXT_COLOR)

	ultimate_button.disabled = not enabled or not ultimate_ready
	ultimate_button.text = ""
	ultimate_button.tooltip_text = ""
	if ultimate_ready and enabled:
		_apply_action_button_style(ultimate_button, true, true)
	elif ultimate_ready:
		_apply_action_button_style(ultimate_button, false, true)
	else:
		_apply_action_button_style(ultimate_button, false, false)
	ultimate_caption.add_theme_color_override("font_color", READY_TEXT_COLOR if enabled and ultimate_ready else MUTED_TEXT_COLOR)


func set_restart_visible(_show_restart: bool) -> void:
	pass


func set_timing_mode(enabled: bool) -> void:
	if enabled:
		attack_button.text = ""
		attack_button.disabled = false
		_apply_action_button_style(attack_button, true, false)
		skill_button.disabled = true
		skill_button.text = ""
		_apply_action_button_style(skill_button, false, false)
		ultimate_button.disabled = true
		ultimate_button.text = ""
		_apply_action_button_style(ultimate_button, false, false)
	else:
		attack_button.text = ""


func play_skill_cast_feedback() -> void:
	skill_button.pivot_offset = skill_button.size * 0.5
	skill_button.scale = Vector2.ONE
	var original_modulate: Color = skill_button.modulate
	var tween: Tween = create_tween()
	tween.tween_property(skill_button, "scale", Vector2(1.16, 1.16), 0.12)
	tween.parallel().tween_property(skill_button, "modulate", Color(0.75, 0.95, 1.0, 1.0), 0.12)
	tween.tween_property(skill_button, "scale", Vector2(0.94, 0.94), 0.08)
	tween.tween_property(skill_button, "scale", Vector2.ONE, 0.14)
	tween.parallel().tween_property(skill_button, "modulate", original_modulate, 0.14)
	await tween.finished


func _on_attack_button_pressed() -> void:
	attack_pressed.emit()


func _on_skill_button_pressed() -> void:
	skill_pressed.emit()


func _on_ultimate_button_pressed() -> void:
	ultimate_pressed.emit()


func _on_menu_button_pressed() -> void:
	menu_popup.visible = not menu_popup.visible


func _on_start_button_pressed() -> void:
	menu_popup.visible = false
	restart_pressed.emit()


func _apply_action_button_style(button: Button, enabled: bool, ready: bool) -> void:
	var font_color: Color = READY_TEXT_COLOR if ready else TEXT_COLOR
	if not enabled and not ready:
		font_color = MUTED_TEXT_COLOR

	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", MUTED_TEXT_COLOR)
	button.add_theme_font_size_override("font_size", 1)
	button.add_theme_stylebox_override("normal", _make_button_style(BUTTON_NORMAL_COLOR, ready))
	button.add_theme_stylebox_override("hover", _make_button_style(BUTTON_HOVER_COLOR, ready))
	button.add_theme_stylebox_override("pressed", _make_button_style(BUTTON_PRESSED_COLOR, ready))
	button.add_theme_stylebox_override("disabled", _make_button_style(BUTTON_DISABLED_COLOR, ready))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(0.0, 0.0, 0.0, 0.0), ready))
	button.modulate = Color(1.0, 1.0, 1.0, 1.0) if enabled or ready else Color(0.48, 0.5, 0.56, 0.88)


func _make_button_style(background_color: Color, ready: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = BUTTON_READY_BORDER_COLOR if ready else BUTTON_BORDER_COLOR
	style.border_width_left = 2 if ready else 1
	style.border_width_top = 2 if ready else 1
	style.border_width_right = 2 if ready else 1
	style.border_width_bottom = 2 if ready else 1
	style.corner_radius_top_left = 36
	style.corner_radius_top_right = 36
	style.corner_radius_bottom_right = 36
	style.corner_radius_bottom_left = 36
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


func _setup_turn_order_slots() -> void:
	turn_order_slots = [
		turn_chip_player,
		turn_chip_enemy,
		turn_chip_player_next,
		turn_chip_enemy_next
	]
	turn_order_labels = [
		turn_chip_player.get_node("Label") as Label,
		turn_chip_enemy.get_node("Label") as Label,
		turn_chip_player_next.get_node("Label") as Label,
		turn_chip_enemy_next.get_node("Label") as Label
	]
	turn_order_profiles = [
		turn_chip_player.get_node("ProfileTexture") as TextureRect,
		turn_chip_enemy.get_node("ProfileTexture") as TextureRect,
		turn_chip_player_next.get_node("ProfileTexture") as TextureRect,
		turn_chip_enemy_next.get_node("ProfileTexture") as TextureRect
	]
	turn_player_style = turn_chip_player.get_theme_stylebox("panel")
	turn_enemy_style = turn_chip_enemy.get_theme_stylebox("panel")
	turn_dim_style = turn_chip_player_next.get_theme_stylebox("panel")


func _refresh_turn_order_slots(is_player_turn: bool) -> void:
	if turn_order_slots.is_empty():
		_setup_turn_order_slots()

	var actors: Array[String] = ["player", "enemy", "player", "enemy"]
	if not is_player_turn:
		actors = ["enemy", "player", "enemy", "player"]
	for index in range(turn_order_slots.size()):
		_set_turn_slot(index, actors[index], index == 0)


func _set_turn_slot(index: int, actor: String, active: bool) -> void:
	var chip: Panel = turn_order_slots[index]
	var label: Label = turn_order_labels[index]
	var profile: TextureRect = turn_order_profiles[index]
	var is_player: bool = actor == "player"

	chip.scale = Vector2.ONE
	chip.modulate = Color(1.0, 1.0, 1.0, 1.0) if active else Color(1.0, 1.0, 1.0, 0.58)
	if active:
		chip.add_theme_stylebox_override("panel", turn_player_style if is_player else turn_enemy_style)
	else:
		chip.add_theme_stylebox_override("panel", turn_dim_style)

	profile.visible = is_player
	label.visible = not is_player
	label.text = "A" if not is_player else "T"
	label.add_theme_color_override("font_color", Color(0.9, 0.36, 0.46, 1.0) if active else Color(0.62, 0.48, 0.54, 0.92))


func _play_turn_chip_feedback(chip: Control) -> void:
	if turn_highlight_tween != null and turn_highlight_tween.is_running():
		turn_highlight_tween.kill()

	for slot in turn_order_slots:
		slot.scale = Vector2.ONE
	chip.pivot_offset = chip.size * 0.5
	turn_highlight_tween = create_tween()
	turn_highlight_tween.tween_property(chip, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	turn_highlight_tween.tween_property(chip, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_turn_banner(text: String, color: Color) -> void:
	if turn_banner_tween != null and turn_banner_tween.is_running():
		turn_banner_tween.kill()

	turn_banner_label.visible = true
	turn_banner_label.text = text
	turn_banner_label.add_theme_color_override("font_color", color)
	turn_banner_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	turn_banner_label.scale = Vector2(0.94, 0.94)
	turn_banner_label.pivot_offset = turn_banner_label.size * 0.5

	turn_banner_tween = create_tween()
	turn_banner_tween.tween_property(turn_banner_label, "modulate:a", 1.0, 0.12)
	turn_banner_tween.parallel().tween_property(turn_banner_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	turn_banner_tween.tween_interval(0.55)
	turn_banner_tween.tween_property(turn_banner_label, "modulate:a", 0.0, 0.22)
	turn_banner_tween.tween_callback(Callable(turn_banner_label, "hide"))


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
