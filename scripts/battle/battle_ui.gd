extends Control
class_name BattleUI

signal attack_pressed
signal guard_pressed
signal restart_pressed
signal confirm_pressed

@onready var player_hp_label: Label = get_node_or_null("PlayerHpLabel") as Label
@onready var enemy_hp_label: Label = get_node_or_null("EnemyHpLabel") as Label
@onready var turn_label: Label = get_node_or_null("TurnLabel") as Label
@onready var battle_log_label: Label = get_node_or_null("BattleLogLabel") as Label
@onready var attack_button: Button = get_node_or_null("ActionButtons/AttackButton") as Button
@onready var guard_button: Button = get_node_or_null("ActionButtons/GuardButton") as Button
@onready var restart_button: Button = get_node_or_null("ActionButtons/RestartButton") as Button


func _ready() -> void:
	_resolve_nodes()
	if attack_button != null:
		attack_button.pressed.connect(_on_attack_button_pressed)
	if guard_button != null:
		guard_button.pressed.connect(_on_guard_button_pressed)
	if restart_button != null:
		restart_button.pressed.connect(_on_restart_button_pressed)
	set_timing_mode(false)


func _unhandled_input(event: InputEvent) -> void:
	if _is_confirm_input(event):
		confirm_pressed.emit()
		get_viewport().set_input_as_handled()
	elif _is_restart_input(event):
		restart_pressed.emit()
		get_viewport().set_input_as_handled()


func set_hp_text(player_text: String, enemy_text: String) -> void:
	_resolve_nodes()
	if player_hp_label != null:
		player_hp_label.text = player_text
	if enemy_hp_label != null:
		enemy_hp_label.text = enemy_text


func set_turn_text(text: String) -> void:
	_resolve_nodes()
	if turn_label != null:
		turn_label.text = text


func set_battle_log(text: String) -> void:
	_resolve_nodes()
	if battle_log_label != null:
		battle_log_label.text = text


func set_actions_enabled(enabled: bool) -> void:
	_resolve_nodes()
	if attack_button != null:
		attack_button.disabled = not enabled
	if guard_button != null:
		guard_button.disabled = not enabled


func set_restart_visible(show_restart: bool) -> void:
	_resolve_nodes()
	if restart_button != null:
		restart_button.visible = show_restart
		restart_button.disabled = not show_restart


func set_timing_mode(enabled: bool) -> void:
	_resolve_nodes()
	if attack_button == null or guard_button == null:
		return

	if enabled:
		attack_button.text = "Confirm"
		attack_button.disabled = false
		guard_button.disabled = true
	else:
		attack_button.text = "Attack"


func _on_attack_button_pressed() -> void:
	attack_pressed.emit()


func _on_guard_button_pressed() -> void:
	guard_pressed.emit()


func _on_restart_button_pressed() -> void:
	restart_pressed.emit()


func _resolve_nodes() -> void:
	if player_hp_label == null:
		player_hp_label = get_node_or_null("PlayerHpLabel") as Label
	if enemy_hp_label == null:
		enemy_hp_label = get_node_or_null("EnemyHpLabel") as Label
	if turn_label == null:
		turn_label = get_node_or_null("TurnLabel") as Label
	if battle_log_label == null:
		battle_log_label = get_node_or_null("BattleLogLabel") as Label
	if attack_button == null:
		attack_button = get_node_or_null("ActionButtons/AttackButton") as Button
	if guard_button == null:
		guard_button = get_node_or_null("ActionButtons/GuardButton") as Button
	if restart_button == null:
		restart_button = get_node_or_null("ActionButtons/RestartButton") as Button


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
