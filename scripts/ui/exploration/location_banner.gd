extends Control
class_name LocationBanner

const UiTokens := preload("res://scripts/ui/ui_tokens.gd")

@export_range(2.5, 4.0, 0.1) var display_duration: float = 3.2

@onready var banner_body: Control = $BannerBody
@onready var region_label: Label = $BannerBody/RegionLabel
@onready var area_label: Label = $BannerBody/AreaRow/AreaLabel
@onready var accent_line: ColorRect = $BannerBody/AreaRow/AccentLine
@onready var ornament_line: ColorRect = $BannerBody/OrnamentLine

var _sequence_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent_line.color = UiTokens.OLD_GOLD
	ornament_line.color = Color(UiTokens.MAGIC_TEAL, 0.42)
	visible = false
	modulate.a = 0.0


func show_location(region_name: String, area_name: String, duration: float = -1.0) -> void:
	_kill_sequence()

	region_label.text = region_name.to_upper()
	area_label.text = area_name
	visible = true
	modulate.a = 0.0
	banner_body.position.x = -float(UiTokens.SPACE_3)

	var hold_duration := display_duration if duration < 0.0 else clampf(duration, 2.5, 4.0)
	_sequence_tween = create_tween()
	_sequence_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sequence_tween.tween_property(self, "modulate:a", 1.0, UiTokens.MOTION_NORMAL)
	_sequence_tween.parallel().tween_property(
		banner_body,
		"position:x",
		0.0,
		UiTokens.MOTION_SLOW
	)
	_sequence_tween.tween_interval(hold_duration)
	_sequence_tween.set_ease(Tween.EASE_IN)
	_sequence_tween.tween_property(self, "modulate:a", 0.0, UiTokens.MOTION_NORMAL)
	_sequence_tween.parallel().tween_property(
		banner_body,
		"position:x",
		-float(UiTokens.SPACE_2),
		UiTokens.MOTION_NORMAL
	)
	_sequence_tween.tween_callback(_finish_sequence)


func hide_banner(animated: bool = true) -> void:
	_kill_sequence()
	if not animated:
		_finish_sequence()
		return

	_sequence_tween = create_tween()
	_sequence_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_sequence_tween.tween_property(self, "modulate:a", 0.0, UiTokens.MOTION_NORMAL)
	_sequence_tween.tween_callback(_finish_sequence)


func _kill_sequence() -> void:
	if _sequence_tween != null and _sequence_tween.is_valid():
		_sequence_tween.kill()


func _finish_sequence() -> void:
	visible = false
	modulate.a = 0.0
	banner_body.position.x = 0.0

