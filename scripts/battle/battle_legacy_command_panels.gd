extends RefCounted
class_name BattleLegacyCommandPanels

## BattleLegacyCommandPanels
## Factory and updater for legacy Block 9 runtime command confirmation/cancellation
## panels. While Block 9E makes these hidden during gameplay, they are preserved
## for test assertions and backwards compatibility.

static func create_skill_command_panel(
	canvas_layer: CanvasLayer,
	confirm_callback: Callable,
	cancel_callback: Callable
) -> Dictionary:
	if canvas_layer == null:
		return {}

	var panel := Panel.new()
	panel.name = "SkillCommandPanel"
	panel.visible = false
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -170.0
	panel.offset_right = 170.0
	panel.offset_top = -254.0
	panel.offset_bottom = -116.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_skill_panel_style())
	canvas_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	margin.add_child(rows)

	var ready_label := Label.new()
	ready_label.text = "Triangle Rift Ready"
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.add_theme_font_size_override("font_size", 15)
	ready_label.add_theme_color_override("font_color", Color(0.72, 0.98, 1.0, 1.0))
	rows.add_child(ready_label)

	var cost_label := Label.new()
	cost_label.text = "Cost: -"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.74, 1.0))
	rows.add_child(cost_label)

	var target_label := Label.new()
	target_label.text = "Target: -"
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.add_theme_font_size_override("font_size", 13)
	target_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0, 1.0))
	rows.add_child(target_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	rows.add_child(buttons)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(104.0, 32.0)
	if confirm_callback.is_valid():
		confirm_btn.pressed.connect(confirm_callback)
	buttons.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(104.0, 32.0)
	if cancel_callback.is_valid():
		cancel_btn.pressed.connect(cancel_callback)
	buttons.add_child(cancel_btn)

	return {
		"panel": panel,
		"ready_label": ready_label,
		"cost_label": cost_label,
		"target_label": target_label,
		"confirm_button": confirm_btn,
		"cancel_button": cancel_btn
	}


static func create_ultimate_command_panel(
	canvas_layer: CanvasLayer,
	confirm_callback: Callable,
	cancel_callback: Callable
) -> Dictionary:
	if canvas_layer == null:
		return {}

	var panel := Panel.new()
	panel.name = "UltimateCommandPanel"
	panel.visible = false
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -180.0
	panel.offset_right = 180.0
	panel.offset_top = -258.0
	panel.offset_bottom = -120.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_ultimate_panel_style())
	canvas_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	margin.add_child(rows)

	var ready_label := Label.new()
	ready_label.text = "Octagram Fragment Ready"
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.add_theme_font_size_override("font_size", 15)
	ready_label.add_theme_color_override("font_color", Color(0.72, 0.95, 1.0, 1.0))
	rows.add_child(ready_label)

	var cost_label := Label.new()
	cost_label.text = "Energy: -"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.74, 1.0))
	rows.add_child(cost_label)

	var target_label := Label.new()
	target_label.text = "Target: -"
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.add_theme_font_size_override("font_size", 13)
	target_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0, 1.0))
	rows.add_child(target_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	rows.add_child(buttons)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(104.0, 32.0)
	if confirm_callback.is_valid():
		confirm_btn.pressed.connect(confirm_callback)
	buttons.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(104.0, 32.0)
	if cancel_callback.is_valid():
		cancel_btn.pressed.connect(cancel_callback)
	buttons.add_child(cancel_btn)

	return {
		"panel": panel,
		"ready_label": ready_label,
		"cost_label": cost_label,
		"target_label": target_label,
		"confirm_button": confirm_btn,
		"cancel_button": cancel_btn
	}


static func update_skill_panel(
	labels: Dictionary,
	confirm_button: Button,
	target: Combatant,
	command: PendingBattleCommand,
	skill_points: int,
	max_skill_points: int
) -> void:
	var target_label := labels.get("target") as Label
	if target_label != null:
		var target_name := target.combatant_name if target != null else "-"
		target_label.text = "Target: %s" % target_name
	var cost_label := labels.get("cost") as Label
	if cost_label != null and command != null:
		cost_label.text = "Cost: %d SP | SP %d/%d" % [
			command.skill_point_cost,
			skill_points,
			max_skill_points
		]
	if confirm_button != null:
		confirm_button.disabled = target == null


static func update_ultimate_panel(
	labels: Dictionary,
	confirm_button: Button,
	target: Combatant,
	command: PendingBattleCommand,
	ultimate_energy: int,
	max_ultimate_energy: int
) -> void:
	var target_label := labels.get("target") as Label
	if target_label != null:
		var target_name := target.combatant_name if target != null else "-"
		target_label.text = "Target: %s" % target_name
	var cost_label := labels.get("cost") as Label
	if cost_label != null:
		cost_label.text = "Energy: %d/%d" % [
			ultimate_energy,
			max_ultimate_energy
		]
	if confirm_button != null:
		confirm_button.disabled = target == null


static func _make_skill_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.04, 0.058, 0.94)
	style.border_color = Color(0.42, 0.96, 1.0, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style


static func _make_ultimate_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.06, 0.94)
	style.border_color = Color(0.72, 0.95, 1.0, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style
