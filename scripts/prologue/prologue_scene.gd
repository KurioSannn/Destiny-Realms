extends Node2D
class_name PrologueScene

const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const BASE_VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)

@onready var dialogue_manager: DialogueManager = get_node_or_null("CanvasLayer/DialogueUI") as DialogueManager
@onready var sky: Polygon2D = get_node_or_null("Background/Sky") as Polygon2D
@onready var forest_line: Polygon2D = get_node_or_null("Background/ForestLine") as Polygon2D
@onready var ground: Polygon2D = get_node_or_null("Background/Ground") as Polygon2D
@onready var takashi_visual: Node2D = get_node_or_null("CharacterLayer/TakashiVisual") as Node2D
@onready var mitsuki_visual: Node2D = get_node_or_null("CharacterLayer/MitsukiVisual") as Node2D
@onready var makoto_visual: Node2D = get_node_or_null("CharacterLayer/MakotoVisual") as Node2D


func _ready() -> void:
	if dialogue_manager != null:
		dialogue_manager.dialogue_finished.connect(_on_dialogue_finished)

	await get_tree().process_frame
	_apply_runtime_layout()
	if dialogue_manager != null:
		dialogue_manager.start_dialogue()


func _apply_runtime_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_VIEWPORT_SIZE

	if sky != null:
		sky.polygon = PackedVector2Array([
			Vector2.ZERO,
			Vector2(viewport_size.x, 0.0),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])
	if forest_line != null:
		forest_line.polygon = PackedVector2Array([
			Vector2(0.0, viewport_size.y * 0.32),
			Vector2(viewport_size.x * 0.1, viewport_size.y * 0.22),
			Vector2(viewport_size.x * 0.22, viewport_size.y * 0.38),
			Vector2(viewport_size.x * 0.35, viewport_size.y * 0.2),
			Vector2(viewport_size.x * 0.52, viewport_size.y * 0.36),
			Vector2(viewport_size.x * 0.68, viewport_size.y * 0.21),
			Vector2(viewport_size.x * 0.84, viewport_size.y * 0.35),
			Vector2(viewport_size.x, viewport_size.y * 0.24),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])
	if ground != null:
		ground.polygon = PackedVector2Array([
			Vector2(0.0, viewport_size.y * 0.68),
			Vector2(viewport_size.x, viewport_size.y * 0.65),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])

	if takashi_visual != null:
		takashi_visual.position = Vector2(viewport_size.x * 0.28, viewport_size.y * 0.67)
	if mitsuki_visual != null:
		mitsuki_visual.position = Vector2(viewport_size.x * 0.52, viewport_size.y * 0.66)
	if makoto_visual != null:
		makoto_visual.position = Vector2(viewport_size.x * 0.68, viewport_size.y * 0.66)


func _on_dialogue_finished() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
