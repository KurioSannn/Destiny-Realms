extends PanelContainer
class_name InteractionPrompt

const UiTokens := preload("res://scripts/ui/ui_tokens.gd")

@onready var key_label: Label = $Content/KeyBadge/KeyLabel
@onready var action_label: Label = $Content/ActionLabel

var _visibility_tween: Tween
var _current_action_text: String = ""
var _current_input_action: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.add_theme_color_override("font_color", UiTokens.DARK_NAVY)
	visible = false
	modulate.a = 0.0
	pivot_offset = size * 0.5


func show_prompt(action_text: String, input_action: String = "interact") -> void:
	var unchanged := (
		visible
		and action_text == _current_action_text
		and input_action == _current_input_action
	)
	if unchanged:
		return

	_current_action_text = action_text
	_current_input_action = input_action
	action_label.text = action_text
	key_label.text = _get_keyboard_label(input_action)
	_kill_tween()

	visible = true
	modulate.a = 0.0
	scale = Vector2(0.96, 0.96)
	pivot_offset = size * 0.5
	_visibility_tween = create_tween().set_parallel(true)
	_visibility_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visibility_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		UiTokens.MOTION_NORMAL
	)
	_visibility_tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		UiTokens.MOTION_NORMAL
	)


func hide_prompt(animated: bool = true) -> void:
	_kill_tween()
	if not visible:
		return
	if not animated:
		_finish_hide()
		return

	_visibility_tween = create_tween().set_parallel(true)
	_visibility_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_visibility_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		UiTokens.MOTION_NORMAL
	)
	_visibility_tween.tween_property(
		self,
		"scale",
		Vector2(0.98, 0.98),
		UiTokens.MOTION_NORMAL
	)
	_visibility_tween.chain().tween_callback(_finish_hide)


func get_current_action_text() -> String:
	return _current_action_text


func get_current_input_action() -> String:
	return _current_input_action


func _get_keyboard_label(input_action: String) -> String:
	if InputMap.has_action(input_action):
		for event in InputMap.action_get_events(input_action):
			if event is InputEventKey:
				var key_event := event as InputEventKey
				if key_event.unicode > 0:
					return String.chr(key_event.unicode).to_upper()
				if key_event.keycode != 0:
					return OS.get_keycode_string(key_event.keycode)
				if key_event.physical_keycode != 0:
					return OS.get_keycode_string(key_event.physical_keycode)

				var label := key_event.as_text_key_label()
				if label.is_empty() or label.to_lower().contains("unset"):
					label = key_event.as_text_physical_keycode()
				if label.is_empty() or label.to_lower().contains("unset"):
					label = key_event.as_text()
				if not label.is_empty() and not label.to_lower().contains("unset"):
					return label

	var words := input_action.replace("_", " ").strip_edges()
	if words.is_empty():
		return "?"
	return words.left(1).to_upper()


func _kill_tween() -> void:
	if _visibility_tween != null and _visibility_tween.is_valid():
		_visibility_tween.kill()


func _finish_hide() -> void:
	visible = false
	modulate.a = 0.0
	scale = Vector2.ONE
