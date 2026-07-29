extends PanelContainer
class_name QuestTracker

const UiTokens := preload("res://scripts/ui/ui_tokens.gd")

@onready var title_label: Label = $Content/TitleRow/TitleLabel
@onready var objective_block: VBoxContainer = $Content/ObjectiveBlock
@onready var objective_label: Label = $Content/ObjectiveBlock/ObjectiveLabel
@onready var progress_label: Label = $Content/ObjectiveBlock/ProgressLabel

var _update_tween: Tween
var _visibility_tween: Tween
var _has_quest: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0


func set_quest(
	quest_title: String,
	objective_text: String,
	progress_text: String = ""
) -> void:
	title_label.text = quest_title
	_has_quest = true
	_show_tracker()
	update_objective(objective_text, progress_text, false)


func update_objective(
	objective_text: String,
	progress_text: String = "",
	animated: bool = true
) -> void:
	objective_label.text = objective_text
	progress_label.text = progress_text
	progress_label.visible = not progress_text.is_empty()

	if not animated:
		objective_block.modulate.a = 1.0
		objective_block.scale = Vector2.ONE
		return

	if _update_tween != null and _update_tween.is_valid():
		_update_tween.kill()

	objective_block.pivot_offset = objective_block.size * 0.5
	objective_block.modulate.a = UiTokens.MUTED_OPACITY
	objective_block.scale = Vector2(0.985, 0.985)
	_update_tween = create_tween().set_parallel(true)
	_update_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_update_tween.tween_property(
		objective_block,
		"modulate:a",
		1.0,
		UiTokens.MOTION_NORMAL
	)
	_update_tween.tween_property(
		objective_block,
		"scale",
		Vector2.ONE,
		UiTokens.MOTION_NORMAL
	)


func hide_tracker(animated: bool = true) -> void:
	_has_quest = false
	if _visibility_tween != null and _visibility_tween.is_valid():
		_visibility_tween.kill()

	if not animated:
		visible = false
		modulate.a = 0.0
		return

	_visibility_tween = create_tween()
	_visibility_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_visibility_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		UiTokens.MOTION_NORMAL
	)
	_visibility_tween.tween_callback(func() -> void: visible = false)


func has_quest() -> bool:
	return _has_quest


func _show_tracker() -> void:
	if _visibility_tween != null and _visibility_tween.is_valid():
		_visibility_tween.kill()
	visible = true
	modulate.a = 0.0
	_visibility_tween = create_tween()
	_visibility_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visibility_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		UiTokens.MOTION_NORMAL
	)

