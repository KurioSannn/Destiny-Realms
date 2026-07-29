extends PanelContainer
class_name BattleCommandDebugPanel

signal confirm_requested
signal cancel_requested
signal previous_target_requested
signal next_target_requested
signal fill_energy_requested
signal invalidate_target_requested

var title_label: Label
var state_label: Label
var detail_label: Label
var message_label: Label
var confirm_button: Button
var cancel_button: Button
var previous_button: Button
var next_button: Button


func _ready() -> void:
	theme = load("res://themes/destiny_realms_theme.tres") as Theme
	anchors_preset = Control.PRESET_CENTER_TOP
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -300.0
	offset_top = 76.0
	offset_right = 300.0
	offset_bottom = 252.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_STOP

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	add_child(root)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 14)
	root.add_child(heading)

	title_label = Label.new()
	title_label.text = "COMMAND SELECT"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	heading.add_child(title_label)

	state_label = Label.new()
	state_label.text = "COMMAND_SELECT"
	state_label.add_theme_color_override(
		"font_color",
		Color(0.42, 0.9, 0.9, 1.0)
	)
	heading.add_child(state_label)

	detail_label = Label.new()
	detail_label.text = "Choose Basic, Skill, or Ultimate."
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(detail_label)

	message_label = Label.new()
	message_label.text = "No resource is spent before confirm."
	message_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.76, 0.82, 1.0)
	)
	root.add_child(message_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 7)
	root.add_child(controls)

	previous_button = _add_button(controls, "< Target")
	next_button = _add_button(controls, "Target >")
	confirm_button = _add_button(controls, "Confirm")
	cancel_button = _add_button(controls, "Cancel")

	var debug_controls := HBoxContainer.new()
	debug_controls.add_theme_constant_override("separation", 7)
	root.add_child(debug_controls)
	var fill_button := _add_button(debug_controls, "Fill Energy")
	var invalidate_button := _add_button(
		debug_controls,
		"Invalidate Target"
	)

	previous_button.pressed.connect(previous_target_requested.emit)
	next_button.pressed.connect(next_target_requested.emit)
	confirm_button.pressed.connect(confirm_requested.emit)
	cancel_button.pressed.connect(cancel_requested.emit)
	fill_button.pressed.connect(fill_energy_requested.emit)
	invalidate_button.pressed.connect(invalidate_target_requested.emit)
	set_command_select("Choose Basic, Skill, or Ultimate.", 5, 0)


func show_pending(
	state_name: String,
	command_name: String,
	cost_text: String,
	target_name: String,
	can_cycle_target: bool
) -> void:
	title_label.text = "%s SELECTED" % command_name.to_upper()
	state_label.text = state_name
	detail_label.text = "Cost: %s    Target: %s" % [cost_text, target_name]
	message_label.text = "Confirm commits once. Cancel spends nothing."
	confirm_button.disabled = false
	cancel_button.disabled = false
	previous_button.disabled = not can_cycle_target
	next_button.disabled = not can_cycle_target


func show_execution(
	state_name: String,
	command_name: String,
	message: String
) -> void:
	title_label.text = command_name.to_upper()
	state_label.text = state_name
	detail_label.text = message
	message_label.text = "Input locked. Commit token is active."
	_set_flow_controls_disabled(true)


func set_command_select(message: String, skill_points: int, energy: int) -> void:
	title_label.text = "COMMAND SELECT"
	state_label.text = "COMMAND_SELECT"
	detail_label.text = "SP: %d    Energy: %d%%" % [skill_points, energy]
	message_label.text = message
	_set_flow_controls_disabled(true)


func show_failure(reason: String) -> void:
	message_label.text = "Command rejected: %s" % reason.replace("_", " ")
	message_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.48, 0.48, 1.0)
	)


func show_outcome(victory: bool) -> void:
	title_label.text = "VICTORY" if victory else "DEFEAT"
	state_label.text = "INPUT_LOCKED"
	detail_label.text = (
		"All debug targets resolved."
		if victory
		else "Takashi can no longer act."
	)
	message_label.text = "Reload the scene to run the slice again."
	_set_flow_controls_disabled(true)


func reset_message_color() -> void:
	message_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.76, 0.82, 1.0)
	)


func _set_flow_controls_disabled(disabled: bool) -> void:
	confirm_button.disabled = disabled
	cancel_button.disabled = disabled
	previous_button.disabled = disabled
	next_button.disabled = disabled


func _add_button(parent: Control, text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(92.0, 34.0)
	parent.add_child(button)
	return button

