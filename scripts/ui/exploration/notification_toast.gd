extends Control
class_name NotificationToast

const UiTokens := preload("res://scripts/ui/ui_tokens.gd")
const MAX_PENDING_NOTIFICATIONS: int = 6
const MIN_CARD_HEIGHT: float = 96.0

@onready var card: PanelContainer = $Card
@onready var accent: ColorRect = $Card/Content/Accent
@onready var symbol_label: Label = $Card/Content/Symbol
@onready var title_label: Label = $Card/Content/Copy/Title
@onready var description_label: Label = $Card/Content/Copy/Description

var _queue: Array[Dictionary] = []
var _sequence_tween: Tween
var _is_presenting: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	call_deferred("_refresh_card_size")


func push_notification(
	title: String,
	description: String = "",
	notification_type: String = "default",
	duration: float = 3.0
) -> void:
	var item := {
		"title": title,
		"description": description,
		"type": _normalize_type(notification_type),
		"duration": clampf(duration, 1.0, 8.0),
	}

	if _queue.size() >= MAX_PENDING_NOTIFICATIONS:
		_queue.pop_front()
	_queue.push_back(item)

	if not _is_presenting:
		_present_next()


func get_pending_count() -> int:
	return _queue.size()


func is_presenting() -> bool:
	return _is_presenting


func clear_notifications() -> void:
	_queue.clear()
	if _sequence_tween != null and _sequence_tween.is_valid():
		_sequence_tween.kill()
	_finish_current()


func _present_next() -> void:
	if _queue.is_empty():
		_is_presenting = false
		visible = false
		return

	_is_presenting = true
	var item: Dictionary = _queue.pop_front()
	title_label.text = str(item["title"])
	description_label.text = str(item["description"])
	description_label.visible = not description_label.text.is_empty()
	_apply_type(str(item["type"]))
	call_deferred("_refresh_card_size")

	visible = true
	modulate.a = 0.0
	card.position.x = float(UiTokens.SPACE_4)
	_sequence_tween = create_tween()
	_sequence_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sequence_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		UiTokens.MOTION_NORMAL
	)
	_sequence_tween.parallel().tween_property(
		card,
		"position:x",
		0.0,
		UiTokens.MOTION_SLOW
	)
	_sequence_tween.tween_interval(float(item["duration"]))
	_sequence_tween.set_ease(Tween.EASE_IN)
	_sequence_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		UiTokens.MOTION_NORMAL
	)
	_sequence_tween.parallel().tween_property(
		card,
		"position:x",
		float(UiTokens.SPACE_3),
		UiTokens.MOTION_NORMAL
	)
	_sequence_tween.tween_callback(_finish_current)


func _finish_current() -> void:
	visible = false
	modulate.a = 0.0
	card.position.x = 0.0
	_is_presenting = false
	if not _queue.is_empty():
		_present_next()


func _normalize_type(value: String) -> String:
	var normalized := value.to_lower()
	if normalized in ["default", "quest", "item", "location", "warning", "save"]:
		return normalized
	return "default"


func _apply_type(notification_type: String) -> void:
	var color := UiTokens.MAGIC_TEAL
	var symbol := "*"
	match notification_type:
		"quest":
			color = UiTokens.OLD_GOLD
			symbol = "<>"
		"item":
			color = UiTokens.IVORY
			symbol = "+"
		"location":
			color = UiTokens.MAGIC_TEAL
			symbol = "/"
		"warning":
			color = UiTokens.DANGER
			symbol = "!"
		"save":
			color = UiTokens.MAGIC_TEAL
			symbol = "S"
		_:
			pass

	accent.color = color
	symbol_label.text = symbol
	symbol_label.add_theme_color_override("font_color", color)


func _refresh_card_size() -> void:
	card.offset_top = 0.0
	card.offset_bottom = MIN_CARD_HEIGHT
