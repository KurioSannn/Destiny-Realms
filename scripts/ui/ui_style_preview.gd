extends Control
class_name UiStylePreview

const UiTokens := preload("res://scripts/ui/ui_tokens.gd")

@onready var hp_bar: ProgressBar = $SafeArea/MainColumn/Content/PrimaryColumn/StatusPanel/StatusContent/HpBar
@onready var energy_bar: ProgressBar = $SafeArea/MainColumn/Content/PrimaryColumn/StatusPanel/StatusContent/EnergyBar
@onready var normal_button: Button = $SafeArea/MainColumn/Content/PrimaryColumn/ButtonsPanel/ButtonsContent/ButtonRow/NormalButton
@onready var focus_button: Button = $SafeArea/MainColumn/Content/PrimaryColumn/ButtonsPanel/ButtonsContent/ButtonRow/FocusButton
@onready var toast_button: Button = $SafeArea/MainColumn/Content/SecondaryColumn/ToastButton
@onready var toast_panel: PanelContainer = $SafeArea/MainColumn/Content/SecondaryColumn/ToastPanel

var _toast_tween: Tween


func _ready() -> void:
	resized.connect(queue_redraw)
	normal_button.pressed.connect(_show_toast)
	focus_button.pressed.connect(_show_toast)
	toast_button.pressed.connect(_show_toast)

	hp_bar.value = 0.0
	energy_bar.value = 0.0
	await get_tree().process_frame

	focus_button.grab_focus()
	toast_panel.pivot_offset = toast_panel.size * 0.5
	_animate_status_bars()
	_show_toast()
	queue_redraw()


func _draw() -> void:
	var teal := UiTokens.MAGIC_TEAL
	var gold := UiTokens.OLD_GOLD
	var muted_teal := Color(teal, 0.11)
	var muted_gold := Color(gold, 0.09)
	var viewport_size := size

	var constellation_points := PackedVector2Array([
		Vector2(viewport_size.x * 0.56, viewport_size.y * 0.12),
		Vector2(viewport_size.x * 0.68, viewport_size.y * 0.19),
		Vector2(viewport_size.x * 0.78, viewport_size.y * 0.1),
		Vector2(viewport_size.x * 0.9, viewport_size.y * 0.2)
	])
	draw_polyline(constellation_points, muted_teal, 1.0, true)
	for point in constellation_points:
		_draw_four_point_star(point, 5.0, Color(teal, 0.22))

	var circle_center := Vector2(viewport_size.x * 0.86, viewport_size.y * 0.77)
	var circle_radius := minf(viewport_size.x, viewport_size.y) * 0.19
	draw_arc(circle_center, circle_radius, 0.0, TAU, 80, muted_gold, 1.0, true)
	draw_arc(circle_center, circle_radius * 0.72, -0.8, 2.1, 48, muted_teal, 1.0, true)
	draw_line(
		circle_center + Vector2(-circle_radius, 0.0),
		circle_center + Vector2(circle_radius, 0.0),
		Color(gold, 0.05),
		1.0
	)


func _draw_four_point_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.28, -radius * 0.28),
		center + Vector2(radius, 0.0),
		center + Vector2(radius * 0.28, radius * 0.28),
		center + Vector2(0.0, radius),
		center + Vector2(-radius * 0.28, radius * 0.28),
		center + Vector2(-radius, 0.0),
		center + Vector2(-radius * 0.28, -radius * 0.28)
	])
	draw_colored_polygon(points, color)


func _animate_status_bars() -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(hp_bar, "value", 72.0, UiTokens.MOTION_SLOW)
	tween.tween_property(energy_bar, "value", 46.0, UiTokens.MOTION_SLOW)


func _show_toast() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	toast_panel.modulate.a = 0.0
	toast_panel.scale = Vector2(0.98, 0.98)
	_toast_tween = create_tween().set_parallel(true)
	_toast_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(toast_panel, "modulate:a", 1.0, UiTokens.MOTION_NORMAL)
	_toast_tween.tween_property(toast_panel, "scale", Vector2.ONE, UiTokens.MOTION_NORMAL)
	_toast_tween.set_parallel(false)
	_toast_tween.tween_interval(UiTokens.TOAST_HOLD_SECONDS)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.38, UiTokens.MOTION_SLOW)
